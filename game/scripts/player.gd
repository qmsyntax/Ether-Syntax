extends CharacterBody3D
## Player archhuman: three-layer body, essence tank + satellite, reflux heat, hidden latent aura.
## Talents (and later items, summons, techniques) are TalentEffect objects hooked into the damage
## pipeline: deal_damage() and take_hit() build a HitContext and run it through every effect.
## Tuning numbers come from GameData (game/data/balance.json).

signal died
## The body was hurt while the soul was out of it.
signal disturbed

const FloatText := preload("res://scripts/float_text.gd")
const Projectile := preload("res://scripts/projectile.gd")
const TALENT_SCRIPT_DIR := "res://scripts/talents/"
const ISO_YAW := deg_to_rad(45.0)

var body: Body
var talent_id := ""
## Who this is (character creation). `look` is a CharacterLook dictionary of option ids.
var char_name := ""
var identity := ""
var look: Dictionary = {}
## Tempering techniques known: id -> {"stage": int, "progress": 0..100}. All of them work at once.
var tempering: Dictionary = {}
## Affinities the prime vestige came with; abilities outside them cannot be learned.
var affinities: Array[String] = []
var talent: Dictionary = {}
var effects: Array[TalentEffect] = []
var stars := 1
var essence := 100.0
var essence_max := 100.0
var satellite_rate := 1.0
## Reflux is heat left behind by casting, kept per affinity (design/01 LAW: "tracked per affinity").
## Overheat one and only that one locks. `reflux` / `reflux_locked` read and write the first
## affinity, for callers that only care about a single-affinity character.
var reflux_by: Dictionary = {}       # affinity -> 0..
var locked_by: Dictionary = {}       # affinity -> true while locked
var reflux: float:
	get:
		return reflux_of(primary_affinity())
	set(value):
		reflux_by[primary_affinity()] = value
var reflux_locked: bool:
	get:
		return is_locked(primary_affinity())
	set(value):
		locked_by[primary_affinity()] = value
var money := 0
var in_combat := false
var fight_time := 0.0
var meditating := false
var active := false
var dead := false
var heal_points_total := 0.0
var arm_right := 100.0            # striking arm integrity; overcharging spends it
var arm_right_lost := false
var discoveries: Array[String] = []
var log_lines: Array[String] = []
## Counts every note() ever written, so the HUD can tell which lines are new.
var log_serial := 0
## Set by the game while the cursor is over a HUD panel: a click there is not an attack order.
var ui_blocked := false
## True while the soul is out in the Netherecho: the body sits and meditates and takes no orders.
var projecting := false
## Learned abilities: [{id, stage, progress}]. Hotbar slot i casts abilities[hotbar[i]].
var abilities: Array = []
var hotbar: Array[int] = []
## Each star's capacity, 1..99 %. The essence tank is the sum of full_tank x capacity (Brent 2026-09-23).
var star_pct: Array[float] = []
## Constructs carried, waiting to be bound: [{tier, concept}]. Placeholder source: enemy drops.
var constructs: Array = []
var rng := RandomNumberGenerator.new()
## Diablo-style click targeting (Brent 2026-09-23): the thing you clicked, and where you clicked.
var attack_target: Node3D = null
var move_goal := Vector3.ZERO
var has_move_goal := false
var _strike_once := false
## What is under the cursor right now (highlighted). Picked in screen space, so clicking any
## part of a drawn body counts - not just its footprint on the floor (Brent 2026-09-23).
var hovered: Node3D = null
## What the character carries and wears (backpack, satellite, trinket, loot).
var inventory: Inventory
## An item on the ground you clicked: walk to it and pick it up.
var pickup_target: Node3D = null

# Headless test driver only (see main.gd --bot-dungeon): steers toward bot_goal, swings at
# anything in reach, hits absurdly hard and cannot be hurt. Never enabled in normal play.
var bot := false
var bot_goal := Vector3.ZERO
var bot_damage_mult := 25.0
var _bot_dir := Vector3.ZERO

# Hidden from the player on purpose: the notebook only ever gives a vague read.
var _latent_aura := 0.0
var _aura_threshold := 100.0

var _arm_regrow := 0.0
var _facing := Vector3.FORWARD
var _melee_cd := 0.0
var _charge := 0.0
var _charging := false
var _meditate_block := 0.0
var _shown_weapon := ""
var _sitting := false                # holding meditate: rooted, but not yet settled
var _sit_t := 0.0
var _dash_time := 0.0
var _dash_vel := Vector3.ZERO
var _rig: ModelRig
var _strike_t := 0.0
var _shown_arm_lost := false
var _shown_glow := 0
var _shown_windup := false

# Tuning (GameData).
var _p: Dictionary
var _arm: Dictionary
var _reflux_cfg: Dictionary
var _heal_cfg: Dictionary
var _natural: Dictionary
var melee_range := 2.3
var melee_arc := deg_to_rad(75.0)


func _init() -> void:
	_p = GameData.balance["player"]
	_arm = GameData.balance["arm"]
	_reflux_cfg = GameData.balance["reflux"]
	_heal_cfg = GameData.balance["healer"]
	_natural = GameData.balance["natural_healing"]
	body = Body.new(float(_p["body_superficial"]), float(_p["body_structural"]), float(_p["body_catastrophic"]))
	rng.randomize()
	star_pct = [GameData.num("stars", "first_star_start_pct")]
	_recompute_essence_max()
	essence = essence_max
	inventory = Inventory.new()
	refresh_gear()
	_aura_threshold = float(_p["aura_threshold"])
	arm_right = float(_arm["max"])
	melee_range = float(_p["melee_range"])
	melee_arc = deg_to_rad(float(_p["melee_arc_deg"]))
	var slots: int = GameData.inum("abilities", "hotbar_slots")
	for i: int in slots:
		hotbar.append(-1)
	affinities = GameData.default_affinities()
	_reset_loadout()
	_reset_tempering()


func _ready() -> void:
	_build_model()

	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	col.shape = shape
	col.position.y = 0.9
	add_child(col)

	# Layer 2 = player; collide with the world only (see enemy.gd).
	collision_layer = 2
	collision_mask = 1


## (Re)build the visible body. Called at start and after a revive, because the dead look is permanent.
func _build_model() -> void:
	if _rig != null:
		_rig.queue_free()
	_rig = CharacterLook.build(look)
	add_child(_rig)
	_shown_arm_lost = false
	_shown_glow = 0
	_shown_windup = false
	_rig.set_part_visible("arm_right", not arm_right_lost)
	_shown_arm_lost = arm_right_lost
	_shown_weapon = ""
	if inventory != null:
		_show_weapon()


## Keep the model in step with the character: lost arm, overcharge wind-up, meditation glow, walk.
func _update_model(delta: float) -> void:
	if _rig == null:
		return
	_strike_t -= delta
	if arm_right_lost != _shown_arm_lost:
		_shown_arm_lost = arm_right_lost
		_rig.set_part_visible("arm_right", not arm_right_lost)
	if _charging != _shown_windup:
		_shown_windup = _charging
		_rig.set_windup(_charging)
	var glow: int = 2 if meditating else 0
	if glow != _shown_glow:
		_shown_glow = glow
		_rig.set_highlight(glow)
	_rig.animate(delta, velocity.length(), _strike_t > 0.0)


## The affinities the character's prime came with. They decide which skills can be learned; a
## new set starts the character over with those affinities' starter kits.
func set_affinities(list: Array) -> void:
	var next: Array[String] = []
	for a: Variant in list:
		if not GameData.affinity(str(a)).is_empty() and not next.has(str(a)):
			next.append(str(a))
	if next.is_empty():
		next = GameData.default_affinities()
	affinities = next
	_reset_loadout()
	clear_reflux()
	_reset_tempering()


# --- tempering ------------------------------------------------------------------------

## The techniques a new character knows: the plain one, and one for each affinity it holds.
## Any health they had added is taken back out first.
func _reset_tempering() -> void:
	for id: String in tempering:
		_apply_temper_health(id, -int((tempering[id] as Dictionary)["stage"]))
	tempering.clear()
	for id: String in GameData.technique_ids():
		var aff: String = str(GameData.technique(id).get("affinity", ""))
		if aff == "" or affinities.has(aff):
			tempering[id] = {"stage": 0, "progress": 0.0}


## Stages may not outrun the soul: star count + 1, as for abilities.
func temper_stage_cap() -> int:
	return stars + 1


## A multiplier from everything tempered so far ("reflux_shed_mult", "incoming_mult",
## "move_speed_mult", "melee_cooldown_mult"): each stage multiplies it in once more.
func temper_stat(stat: String) -> float:
	var v := 1.0
	for id: String in tempering:
		var eff: Dictionary = GameData.technique(id).get("effect", {})
		if str(eff.get("stat", "")) == stat:
			v *= pow(float(eff["per_stage"]), float(int((tempering[id] as Dictionary)["stage"])))
	return v


## "+16 superficial health", "reflux sheds 32% faster" ... what a technique gives at `stage`.
func temper_effect_text(id: String, stage: int) -> String:
	var eff: Dictionary = GameData.technique(id).get("effect", {})
	var per: float = float(eff.get("per_stage", 0.0))
	var amount: float
	if str(eff.get("stat", "")).begins_with("max_"):
		amount = per * float(stage)
	else:
		amount = absf(pow(per, float(stage)) - 1.0) * 100.0
	return str(eff.get("text", "%d")) % int(round(amount))


func temper_session_damage(id: String) -> float:
	var s: Dictionary = GameData.tempering_session()
	return float(s["damage_base"]) + float(s["damage_per_stage"]) * float(int((tempering[id] as Dictionary)["stage"]))


func temper_session_progress(id: String) -> float:
	var s: Dictionary = GameData.tempering_session()
	return float(s["progress_base"]) * pow(float(s["progress_falloff_per_stage"]), float(int((tempering[id] as Dictionary)["stage"])))


## Why a session cannot be trained right now, or "" if it can.
func cannot_temper_reason(id: String) -> String:
	if not tempering.has(id):
		return "You do not know it."
	if int((tempering[id] as Dictionary)["stage"]) >= temper_stage_cap():
		return "Needs another star."
	if float(body.hp["structural"]) - temper_session_damage(id) < float(GameData.tempering_session()["min_structural_left"]):
		return "Your body cannot take it. Mend first."
	return ""


## One training session: it costs bone and moves the technique along; a full bar is a new stage.
## Returns false if the session could not be trained.
func temper_session(id: String) -> bool:
	if cannot_temper_reason(id) != "":
		return false
	var st: Dictionary = tempering[id]
	body.damage_layer("structural", temper_session_damage(id))
	st["progress"] = float(st["progress"]) + temper_session_progress(id)
	if float(st["progress"]) >= 99.999:
		st["progress"] = 0.0
		st["stage"] = int(st["stage"]) + 1
		_apply_temper_health(id, 1)
		note("%s reaches stage %d: %s." % [str(GameData.technique(id).get("name", id)), int(st["stage"]), temper_effect_text(id, int(st["stage"]))])
	return true


## Techniques that add health change the body itself, `stages` stages' worth (negative to undo).
func _apply_temper_health(id: String, stages: int) -> void:
	var eff: Dictionary = GameData.technique(id).get("effect", {})
	var stat: String = str(eff.get("stat", ""))
	if not stat.begins_with("max_") or stages == 0:
		return
	var layer: String = stat.trim_prefix("max_")
	var add: float = float(eff["per_stage"]) * float(stages)
	body.max_hp[layer] = maxf(1.0, float(body.max_hp[layer]) + add)
	body.hp[layer] = clampf(float(body.hp[layer]) + add, 0.0, float(body.max_hp[layer]))


## Start over with the kits of the current affinities, on the bar in order.
func _reset_loadout() -> void:
	abilities.clear()
	for i: int in hotbar.size():
		hotbar[i] = -1
	var loadout: Array = GameData.ability_loadout(affinities)
	for i: int in loadout.size():
		abilities.append({"id": str(loadout[i]), "stage": 0, "progress": 0.0})
		if i < hotbar.size():
			hotbar[i] = i


func primary_affinity() -> String:
	return affinities[0] if not affinities.is_empty() else "water"


func reflux_of(aff: String) -> float:
	return float(reflux_by.get(aff, 0.0))


func is_locked(aff: String) -> bool:
	return bool(locked_by.get(aff, false))


## The affinity whose reflux just hit the cap (valid inside TalentEffect.on_reflux_cap).
var capping_affinity := ""


## Drop the capping affinity's reflux to `value` (a talent venting it).
func vent_reflux(value: float) -> void:
	reflux_by[capping_affinity if capping_affinity != "" else primary_affinity()] = value


func clear_reflux() -> void:
	reflux_by.clear()
	locked_by.clear()


## Every affinity cools at once; one that drops far enough unlocks.
func _shed_reflux(amount: float) -> void:
	var shed: float = amount * inventory.stat("reflux_shed_mult", true) * temper_stat("reflux_shed_mult")
	for aff: String in reflux_by:
		reflux_by[aff] = maxf(0.0, float(reflux_by[aff]) - shed)
		if is_locked(aff) and float(reflux_by[aff]) < float(_reflux_cfg["unlock_below"]):
			locked_by[aff] = false
			note("%s affinity unlocks." % str(GameData.affinity(aff).get("label", aff)))


## Change what the character looks like and rebuild the model to match.
func set_look(new_look: Dictionary) -> void:
	look = CharacterLook.normalize(new_look)
	_build_model()


## Embrace a talent: its rules live in res://scripts/talents/<id>.gd, if that file exists.
## A talent says nothing about affinities - those come with the prime separately (set_affinities).
func set_talent(id: String) -> void:
	talent_id = id
	talent = TalentDB.get_talent(id)
	effects.clear()
	var path: String = TALENT_SCRIPT_DIR + id + ".gd"
	if ResourceLoader.exists(path):
		var script: GDScript = load(path)
		var effect: TalentEffect = script.new()
		effect.setup(self, id)
		effects.append(effect)
	else:
		note("(no effect script for %s - the talent does nothing yet)" % id)
	note("Embraced: %s" % str(talent.get("name", id)))


func _physics_process(delta: float) -> void:
	if not active or dead:
		return

	_melee_cd -= delta
	_meditate_block -= delta
	if in_combat:
		fight_time += delta

	essence = minf(essence_max, essence + satellite_rate * delta)
	for e: TalentEffect in effects:
		e.on_tick(delta)
	if projecting:
		# The body is an empty, meditating shell: it sheds reflux and gathers, and nothing else.
		meditating = true
		attack_target = null
		pickup_target = null
		has_move_goal = false
		_shed_reflux(float(_reflux_cfg["shed_meditating"]) * delta)
		_meditate_gather(delta)
		grow_star(GameData.num("stars", "growth_pct_per_s_meditating") * delta)
		velocity = Vector3.ZERO
		_update_model(delta)
		return
	if bot:
		_bot_think()
	else:
		_update_aim()

	# Meditation is sitting still: it roots you at once, and only counts once you have settled.
	_sitting = Input.is_action_pressed("meditate") and _meditate_block <= 0.0 and not _charging
	_sit_t = _sit_t + delta if _sitting else 0.0
	meditating = _sitting and _sit_t >= GameData.num("meditation", "settle_s")
	if _sitting:
		has_move_goal = false
		attack_target = null
		pickup_target = null

	# The body sheds reflux on its own; meditation purges it much faster.
	var shed: float = float(_reflux_cfg["shed_meditating"]) if meditating else (
		float(_reflux_cfg["shed_in_combat"]) if in_combat else float(_reflux_cfg["shed_resting"]))
	_shed_reflux(shed * delta)
	_meditate_gather(delta)
	if meditating:
		grow_star(GameData.num("stars", "growth_pct_per_s_meditating") * delta)

	# The body mends itself between fights - but only what a body can mend.
	if not in_combat:
		body.heal_layer("superficial", float(_natural["superficial_per_s"]) * delta)
		body.heal_layer("structural", float(_natural["structural_per_s"]) * delta)
		if not arm_right_lost:
			arm_right = minf(float(_arm["max"]), arm_right + float(_natural["arm_per_s"]) * delta)

	var charging_input: bool = Input.is_action_pressed("overcharge") and not arm_right_lost
	if charging_input and not _sitting:
		_charging = true
		_charge = minf(float(_p["charge_max"]), _charge + delta)
	elif _charging:
		_release_overcharge()

	# Diablo-style: click something to walk to it and hit it; click ground to walk there.
	if bot:
		attack_target = _nearest_enemy()
		_strike_once = false
	else:
		_update_hover()
	if not bot and Input.is_action_just_pressed("strike") and not _sitting and not ui_blocked:
		_click_cursor()
	if not bot and Input.is_action_pressed("strike") and attack_target == null and has_move_goal:
		move_goal = _cursor_ground()          # holding on the ground keeps steering

	var input := Vector2.ZERO
	if not _sitting:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir := Vector3(input.x, 0.0, input.y).normalized().rotated(Vector3.UP, ISO_YAW)
	if input != Vector2.ZERO:
		has_move_goal = false                  # WASD takes over from click-to-move
		if not Input.is_action_pressed("strike"):
			attack_target = null
			pickup_target = null

	if attack_target != null and (not is_instance_valid(attack_target) or bool(attack_target.call("is_dead"))):
		attack_target = null
	if attack_target != null and not meditating and not _charging:
		var to: Vector3 = attack_target.global_position - global_position
		to.y = 0.0
		var reach: float = reach_now() + float(attack_target.get("radius"))
		if to.length() > 0.2:
			_facing = to.normalized()
		if to.length() <= reach:
			dir = Vector3.ZERO if input == Vector2.ZERO else dir
			if _melee_cd <= 0.0:
				_strike_target(attack_target, float(_p["off_hand_factor"]) if arm_right_lost else 1.0, ["melee"])
				_melee_cd = float(_p["melee_cooldown"]) * weapon_stat("melee_cooldown_mult", true) * temper_stat("melee_cooldown_mult")
				if _strike_once and not Input.is_action_pressed("strike"):
					attack_target = null
		elif input == Vector2.ZERO:
			dir = to.normalized()                  # walk into reach
	elif pickup_target != null and is_instance_valid(pickup_target) and not pickup_target.is_queued_for_deletion():
		var to_item: Vector3 = pickup_target.global_position - global_position
		to_item.y = 0.0
		if to_item.length() <= GameData.num("player", "pickup_reach"):
			take_pickup(pickup_target)
			pickup_target = null
		elif input == Vector2.ZERO:
			dir = to_item.normalized()
			_facing = dir
	elif has_move_goal and input == Vector2.ZERO:
		var to_goal: Vector3 = move_goal - global_position
		to_goal.y = 0.0
		if to_goal.length() < 0.3:
			has_move_goal = false
		else:
			dir = to_goal.normalized()
			_facing = dir

	if bot:
		dir = _bot_dir if attack_target == null else dir
	var speed: float = float(_p["move_speed"]) * temper_stat("move_speed_mult") * (float(_p["charge_move_factor"]) if _charging else 1.0)
	velocity = dir * speed
	if _dash_time > 0.0:
		_dash_time -= delta
		velocity = _dash_vel
	move_and_slide()

	rotation.y = atan2(-_facing.x, -_facing.z)
	_update_model(delta)


# --- the damage pipeline --------------------------------------------------------

## Deal damage to a hittable node. Every effect sees the hit before and after it lands.
func deal_damage(target: Node, base: float, tags: Array = []) -> HitContext:
	var ctx := HitContext.new()
	ctx.source = self
	ctx.target = target
	ctx.base = base
	for t: String in tags:
		ctx.tags.append(t)
	if not is_instance_valid(target) or bool(target.call("is_dead")):
		ctx.cancelled = true
		return ctx
	ctx.is_living = bool(target.get("is_living"))
	ctx.is_scenery = bool(target.get("is_scenery"))

	for e: TalentEffect in effects:
		e.on_outgoing(ctx)
	if bot:
		ctx.mult *= bot_damage_mult

	var pos: Vector3 = (target as Node3D).global_position
	ctx.applied = target.call("take_hit", ctx.amount(), ctx.heavy, self)
	if ctx.applied <= 0.0:
		return ctx
	if not ctx.is_scenery:
		FloatText.spawn(get_parent(), pos, "%d" % int(ctx.applied), Color(1, 1, 1))
	ctx.killed = bool(target.call("is_dead"))

	for e: TalentEffect in effects:
		e.on_dealt(ctx)
	if ctx.killed:
		_on_kill(target)
	return ctx


## Receive a hit. Effects may scale it or swallow it (ctx.cancelled).
func take_hit(amount: float, heavy: bool, source: Node) -> float:
	if dead or bot:
		return 0.0
	var ctx := HitContext.new()
	ctx.source = source
	ctx.target = self
	ctx.base = amount
	ctx.heavy = heavy
	if projecting:
		disturbed.emit()             # pain drags the soul back before the blow is even counted
	_meditate_block = 1.0
	meditating = false
	for e: TalentEffect in effects:
		e.on_incoming(ctx)
	if ctx.cancelled:
		return 0.0
	return _apply_damage(ctx.amount() * temper_stat("incoming_mult"), heavy)


## Damage that has passed the pipeline (or comes from an effect's own timer).
func _apply_damage(amount: float, heavy: bool) -> float:
	var applied: float = body.apply_damage(amount, heavy)
	if _rig != null and applied > 0.0:
		_rig.flash(0.1)
	_float("-%d" % int(applied), Color(1, 0.25, 0.25))
	_check_death()
	return applied


## Talent healing: worst first. A lost limb is catastrophic-class, so it is always 1 point per
## unit even at Dynamic quality - this is the one thing natural healing can never do.
func _spend_heal_points(points: float) -> float:
	var left: float = points
	left -= body.heal(minf(left, body.missing("catastrophic")), false)
	if arm_right_lost and left > 0.0:
		var need: float = float(_arm["regrow_heal_points"])
		var into_arm: float = minf(left, need - _arm_regrow)
		_arm_regrow += into_arm
		left -= into_arm
		if _arm_regrow >= need:
			arm_right_lost = false
			arm_right = float(_arm["max"]) * float(_arm["regrown_by_talent_integrity"])
			_float("ARM REGROWN", Color(0.4, 1, 0.5))
			discover("Regrows lost limbs: YES")
	if left > 0.0:
		left -= body.heal(left, stars >= 2)
	return points - left


## Latent aura from a deed that was not a kill (subduing a construct, for one).
func add_aura(amount: float) -> void:
	_latent_aura += amount


func _on_kill(target: Node) -> void:
	money += int(target.get("bounty"))
	var hurt: float = 1.0 - body.total() / body.total_max()
	var risk: float = 1.0 + hurt * float(_p["aura_hurt_risk_bonus"])
	_latent_aura += float(target.get("aura_value")) * risk
	grow_star(float(target.get("aura_value")) * GameData.num("stars", "growth_pct_per_aura"))
	_roll_drops(target)
	_roll_loot(target)


# --- click targeting ------------------------------------------------------------

## Click at the cursor: the hovered thing if there is one, otherwise the floor under the cursor.
func _click_cursor() -> void:
	if hovered != null and is_instance_valid(hovered) and not bool(hovered.call("is_dead")):
		has_move_goal = false
		if hovered.get("is_pickup") != null:
			pickup_target = hovered
			attack_target = null
		else:
			attack_target = hovered
			pickup_target = null
			_strike_once = true
	else:
		pickup_target = null
		_click(_cursor_ground())
	_refresh_highlights()


## Handle a click at a ground point: a hittable there becomes the attack target (enemies win
## over scenery), otherwise the point becomes a walk goal.
func _click(point: Vector3) -> void:
	var hit: Node3D = pick_at(point)
	if hit != null:
		attack_target = hit
		has_move_goal = false
		_strike_once = true
	else:
		attack_target = null
		move_goal = point
		has_move_goal = true


## Screen-space pick: the hittable whose drawn body (base-to-top segment, widened by its radius
## and a margin) contains `screen_pos`. Enemies win over scenery; closest to the cursor wins.
func pick_screen(screen_pos: Vector2, cam: Camera3D) -> Node3D:
	if cam == null:
		return null
	var margin: float = GameData.num("player", "pick_margin_px")
	var best: Node3D = null
	var best_d := INF
	var best_rank := -1
	var candidates: Array[Node] = get_tree().get_nodes_in_group("hittable")
	candidates.append_array(get_tree().get_nodes_in_group("pickups"))
	for node: Node in candidates:
		var t := node as Node3D
		if t == null or bool(t.call("is_dead")):
			continue
		if cam.is_position_behind(t.global_position):
			continue
		var h: float = float(t.get("height")) if t.get("height") != null else 1.0
		var r: float = float(t.get("radius"))
		var base: Vector2 = cam.unproject_position(t.global_position)
		var top: Vector2 = cam.unproject_position(t.global_position + Vector3.UP * h)
		var side: Vector2 = cam.unproject_position(t.global_position + cam.global_transform.basis.x * r)
		var r_px: float = base.distance_to(side)
		var d: float = Geometry2D.get_closest_point_to_segment(screen_pos, base, top).distance_to(screen_pos)
		# enemies beat loot, loot beats scenery
		var rank: int = 0 if bool(t.get("is_scenery")) else (1 if t.get("is_pickup") != null else 2)
		if d > r_px + (margin * 0.4 if rank == 0 else margin):
			continue
		if rank > best_rank or (rank == best_rank and d < best_d):
			best = t
			best_d = d
			best_rank = rank
	return best


func _update_hover() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var now: Node3D = pick_screen(get_viewport().get_mouse_position(), cam) if cam != null else null
	if now != hovered:
		hovered = now
	_refresh_highlights()


## Hovered = bright, locked attack target = dimmer; everything else plain.
func _refresh_highlights() -> void:
	var nodes: Array[Node] = get_tree().get_nodes_in_group("hittable")
	nodes.append_array(get_tree().get_nodes_in_group("pickups"))
	for node: Node in nodes:
		var level := 0
		if node == hovered:
			level = 1
		elif node == attack_target or node == pickup_target:
			level = 2
		if node.has_method("set_highlight"):
			if int(node.get("highlight")) != level:
				node.call("set_highlight", level)
		elif node.get("highlight") != null:
			node.set("highlight", level)


## The hittable whose footprint contains `point`, preferring enemies over scenery.
func pick_at(point: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	var best_is_enemy := false
	for node: Node in get_tree().get_nodes_in_group("hittable"):
		var t := node as Node3D
		if t == null or bool(t.call("is_dead")):
			continue
		var d: Vector3 = t.global_position - point
		d.y = 0.0
		var dist: float = d.length()
		if dist > float(t.get("radius")) + 0.45:
			continue
		var is_enemy: bool = not bool(t.get("is_scenery"))
		if (is_enemy and not best_is_enemy) or (is_enemy == best_is_enemy and dist < best_d):
			best = t
			best_d = dist
			best_is_enemy = is_enemy
	return best


## One blow on one target (Brent 2026-09-23: base attacks are single target).
func _strike_target(target: Node3D, multiplier: float, tags: Array) -> void:
	_strike_t = 0.2
	_swing_visual(reach_now(), multiplier > 1.0, true)
	deal_damage(target, float(_p["melee_damage"]) * weapon_stat("melee_damage_mult", true) * multiplier, tags)


## The overcharged blow lands on the clicked target, else whatever is under the cursor, else the
## nearest enemy in front of you - but only within reach.
func _overcharge_target(reach: float) -> Node3D:
	var candidates: Array[Node3D] = []
	if attack_target != null and is_instance_valid(attack_target):
		candidates.append(attack_target)
	if not bot and is_inside_tree():
		var under: Node3D = hovered
		if under != null:
			candidates.append(under)
	var near: Node3D = _nearest_enemy()
	if near != null:
		candidates.append(near)
	for t: Node3D in candidates:
		var to: Vector3 = t.global_position - global_position
		to.y = 0.0
		if to.length() <= reach + float(t.get("radius")):
			return t
	return null


## Area melee - used by skills such as Tsunami Strike, never by the base attack.
func _swing(multiplier: float, reach: float, tags: Array) -> void:
	_strike_t = 0.25
	_swing_visual(reach, multiplier > 1.0, false)
	for node: Node in get_tree().get_nodes_in_group("hittable"):
		var t := node as Node3D
		if t == null:
			continue
		var to: Vector3 = t.global_position - global_position
		to.y = 0.0
		var dist: float = to.length()
		if dist > reach + float(t.get("radius")):
			continue
		if dist > 0.3 and _facing.angle_to(to / dist) > melee_arc:
			continue
		deal_damage(t, float(_p["melee_damage"]) * weapon_stat("melee_damage_mult", true) * multiplier, tags)


func _release_overcharge() -> void:
	var c: float = _charge
	_charging = false
	_charge = 0.0
	if c < float(_p["overcharge_min_charge"]):
		return
	# Health as ammunition: the blow lands harder than the arm can bear.
	var self_cost: float = float(_p["overcharge_self_cost_base"]) + c * float(_p["overcharge_self_cost_per_charge"])
	var applied: float = body.apply_self_harm(self_cost)
	_float("arm -%d" % int(applied), Color(1, 0.4, 0.3))
	var heavy_target: Node3D = _overcharge_target(reach_now() + float(_p["overcharge_reach_bonus"]))
	if heavy_target != null:
		_strike_target(heavy_target, 1.0 + c * float(_p["overcharge_damage_per_charge"]), ["melee", "overcharge"])
	else:
		_swing_visual(melee_range, true, true)
	_melee_cd = float(_p["melee_cooldown"]) * float(_p["overcharge_cooldown_factor"])

	arm_right -= self_cost * float(_arm["cost_per_self_harm"])
	if arm_right <= 0.0:
		arm_right = 0.0
		arm_right_lost = true
		_arm_regrow = 0.0
		body.damage_layer("catastrophic", float(_arm["loss_catastrophic_damage"]))
		FloatText.spawn(get_parent(), global_position + Vector3.UP * 0.6, "ARM LOST", Color(1, 0.1, 0.1))
		note("Your striking arm is destroyed. Rest will not bring it back.")
	_check_death()


# --- abilities --------------------------------------------------------------------

## Cast whatever ability sits in hotbar slot `slot` (0-based).
func cast_slot(slot: int) -> void:
	if slot < 0 or slot >= hotbar.size() or hotbar[slot] < 0:
		return
	cast_ability(hotbar[slot])


func cast_ability(index: int) -> void:
	if not active or dead or meditating or index < 0 or index >= abilities.size():
		return
	var state: Dictionary = abilities[index]
	var ab: Dictionary = ability_stats(state)
	if ab.is_empty():
		return
	var aff: String = str(ab.get("affinity", ""))
	var aff_name: String = str(GameData.affinity(aff).get("label", aff))
	if not affinities.has(aff):
		note("You have no %s affinity." % aff_name.to_lower())
		return
	if is_locked(aff):
		note("%s affinity is locked by reflux. Meditate (hold %s)." % [aff_name, Keybinds.binding_text("meditate")])
		return
	var heat: float = reflux_of(aff)
	var cost: float = float(ab["cost"]) * (float(_reflux_cfg["pain_cost_mult"]) if heat >= float(_reflux_cfg["pain_at"]) else 1.0)
	if essence < cost:
		note("Not enough essence for %s." % str(ab["name"]))
		return
	if heat >= float(_reflux_cfg["burn_at"]):
		var burn: float = body.apply_self_harm(float(_reflux_cfg["burn_self_damage"]))
		_float("reflux -%d" % int(burn), Color(1, 0.5, 0.2))
	essence -= cost
	reflux_by[aff] = heat + cost * float(ab["reflux_per_cost"])
	_advance(state, cost)

	var stage_mult: float = ability_damage_mult(int(state["stage"])) * float(ab.get("damage_all", 1.0))
	match str(ab["kind"]):
		"projectile":
			_fire_projectile(ab, stage_mult, GameData.affinity_color(aff))
		"melee_burst":
			if float(ab.get("self_harm", 0.0)) > 0.0:     # only a build that earns it; no ability has it by default
				var hurt: float = body.apply_self_harm(float(ab["self_harm"]))
				_float("-%d" % int(hurt), Color(1, 0.4, 0.3))
			_swing(float(ab["damage_mult"]) * stage_mult, melee_range + float(ab["reach_bonus"]), ["melee", "ability", str(state["id"])])
			_melee_cd = float(_p["melee_cooldown"]) * float(_p["overcharge_cooldown_factor"])
		"dash":
			var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
			var dir := Vector3(input.x, 0.0, input.y).normalized().rotated(Vector3.UP, ISO_YAW)
			if dir == Vector3.ZERO:
				dir = _facing
			_dash_vel = dir * float(ab["dash_speed"])
			_dash_time = float(ab["dash_time"])

	if reflux_of(aff) >= float(_reflux_cfg["lock_at"]):
		capping_affinity = aff
		var handled := false
		for e: TalentEffect in effects:
			if e.on_reflux_cap():
				handled = true
				break
		if not handled:
			locked_by[aff] = true
			note("Reflux at %d - %s affinity LOCKED." % [int(_reflux_cfg["lock_at"]), aff_name.to_lower()])
	_check_death()


## Put an ability on a skill slot. An ability lives on one slot at a time; whatever was in the
## target slot swaps to the slot the ability came from (or leaves the bar if it had none).
func assign_slot(slot: int, ability_index: int) -> void:
	if slot < 0 or slot >= hotbar.size() or ability_index < 0 or ability_index >= abilities.size():
		return
	var from: int = hotbar.find(ability_index)
	var displaced: int = hotbar[slot]
	hotbar[slot] = ability_index
	if from >= 0 and from != slot:
		hotbar[from] = displaced


## Take an ability off the skill bar.
func unassign_ability(ability_index: int) -> void:
	var at: int = hotbar.find(ability_index)
	if at >= 0:
		hotbar[at] = -1


## Damage multiplier an ability gets from its stage.
func ability_damage_mult(stage: int) -> float:
	return 1.0 + GameData.num("abilities", "stage_damage_bonus") * float(stage)


## Progress is bought with essence spent through the ability, and counts for more when
## something is actually trying to kill you (Brent 2026-09-23). The bar stops at 100: the stage
## only advances when a construct of the matching tier is bound into it (Brent 2026-09-23).
func _advance(state: Dictionary, essence_spent: float) -> void:
	var was_full: bool = float(state["progress"]) >= 100.0
	var use_mult: float = GameData.num("abilities", "use_mult_monster") if _enemy_nearby() else GameData.num("abilities", "use_mult_nothing")
	var gain: float = essence_spent * GameData.num("abilities", "progress_per_essence") * use_mult
	state["progress"] = minf(100.0, float(state["progress"]) + gain)
	if not was_full and float(state["progress"]) >= 100.0:
		note("%s is full. It needs a %s bound into it to advance." % [
			str(GameData.ability(str(state["id"])).get("name", "?")), GameData.tier_for_stage(int(state["stage"]))])


## What an ability needs next: "" if its bar is not full (or it is at the stage cap);
## otherwise the construct tier that advances it.
func pending_tier(state: Dictionary) -> String:
	if float(state["progress"]) < 100.0 or int(state["stage"]) >= stars + 1:
		return ""
	return GameData.tier_for_stage(int(state["stage"]))


## An ability's numbers after every bound construct's concept has shaped it.
func ability_stats(state: Dictionary) -> Dictionary:
	var ab: Dictionary = GameData.ability(str(state["id"])).duplicate()
	if ab.is_empty():
		return ab
	var damage_all := 1.0
	for up: Dictionary in state.get("bound", []):
		var c: Dictionary = GameData.concept(str(up["concept"]))
		var mods: Dictionary = c.get("mods", {})
		var applied := false
		for key: String in mods:
			if ab.has(key):
				ab[key] = float(ab[key]) * float(mods[key])
				applied = true
		if not applied:
			damage_all *= float((c.get("fallback", {}) as Dictionary).get("damage_all", 1.0))
	ab["damage_all"] = damage_all
	ab["cost"] = float(ab["cost"]) * inventory.stat("cost_mult", true)
	return ab


## What binding a construct of `concept` into this ability would change, for showing before the
## (irreversible) bind: [{"label", "before", "after", "better"}], numbers already formatted.
func preview_bind(state: Dictionary, concept: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var now: Dictionary = ability_stats(state)
	var trial: Dictionary = state.duplicate(true)
	if not trial.has("bound"):
		trial["bound"] = []
	(trial["bound"] as Array).append({"concept": concept, "tier": "", "stage": int(state["stage"])})
	var then: Dictionary = ability_stats(trial)
	if now.is_empty():
		return out
	var strike: float = float(_p["melee_damage"]) * weapon_stat("melee_damage_mult", true)
	var stage: int = int(state["stage"])
	var mult_now: float = ability_damage_mult(stage) * float(now.get("damage_all", 1.0))
	var mult_then: float = ability_damage_mult(stage + 1) * float(then.get("damage_all", 1.0))
	out.append({"label": "Stage", "before": str(stage), "after": str(stage + 1), "better": true})
	if now.has("damage"):
		_preview_row(out, "Damage", float(now["damage"]) * mult_now, float(then["damage"]) * mult_then, "%d", true)
	if now.has("damage_mult"):
		_preview_row(out, "Damage per target", strike * float(now["damage_mult"]) * mult_now, strike * float(then["damage_mult"]) * mult_then, "%d", true)
	if now.has("speed"):
		_preview_row(out, "Bolt speed", float(now["speed"]), float(then["speed"]), "%d", true)
		_preview_row(out, "Range", float(now["speed"]) * float(now["life"]), float(then["speed"]) * float(then["life"]), "%d m", true)
	if now.has("reach_bonus"):
		_preview_row(out, "Reach", melee_range + float(now["reach_bonus"]), melee_range + float(then["reach_bonus"]), "%.1f m", true)
	if now.has("dash_speed"):
		_preview_row(out, "Dash distance", float(now["dash_speed"]) * float(now["dash_time"]), float(then["dash_speed"]) * float(then["dash_time"]), "%.1f m", true)
		_preview_row(out, "Dash speed", float(now["dash_speed"]), float(then["dash_speed"]), "%d", true)
	if now.has("self_harm"):
		_preview_row(out, "Harm to yourself", float(now["self_harm"]), float(then["self_harm"]), "%.1f", false)
	_preview_row(out, "Essence cost", float(now["cost"]), float(then["cost"]), "%d", false)
	_preview_row(out, "Reflux left behind", float(now["cost"]) * float(now["reflux_per_cost"]), float(then["cost"]) * float(then["reflux_per_cost"]), "%d", false)
	return out


## Add a row only when the number actually moves. `more_is_better` decides its colour.
func _preview_row(out: Array[Dictionary], label: String, before: float, after: float, fmt: String, more_is_better: bool) -> void:
	var a: String = fmt % ([int(round(before))] if fmt.begins_with("%d") else [before])
	var b: String = fmt % ([int(round(after))] if fmt.begins_with("%d") else [after])
	if a == b:
		return
	out.append({"label": label, "before": a, "after": b, "better": (after > before) == more_is_better})


## Bind a carried construct into an ability. Irreversible; can fail, and failure hurts
## (Brent 2026-09-23). `roll` < 0 means roll randomly (tests pass a fixed roll).
func bind_construct(ability_index: int, construct_index: int, roll: float = -1.0) -> String:
	if ability_index < 0 or ability_index >= abilities.size() or construct_index < 0 or construct_index >= constructs.size():
		return "nothing to bind"
	var state: Dictionary = abilities[ability_index]
	var con: Dictionary = constructs[construct_index]
	var need: String = pending_tier(state)
	if need == "":
		return "not ready"
	if need != str(con["tier"]):
		return "needs a %s" % need
	constructs.remove_at(construct_index)
	var r: float = rng.randf() if roll < 0.0 else roll
	var ab_name: String = str(GameData.ability(str(state["id"])).get("name", "?"))
	var label: String = str(GameData.concept(str(con["concept"])).get("label", con["concept"]))
	if r >= GameData.num("binding", "success_chance"):
		var hurt: float = body.apply_self_harm(GameData.num("binding", "fail_self_harm"))
		_float("-%d" % int(hurt), Color(1, 0.3, 0.6))
		note("The %s of %s tears free. The bind fails and it is gone." % [con["tier"], label])
		_check_death()
		return "failed"
	var bound: Array = state.get("bound", [])
	bound.append({"stage": int(state["stage"]), "tier": con["tier"], "concept": con["concept"]})
	state["bound"] = bound
	state["stage"] = int(state["stage"]) + 1
	state["progress"] = 0.0
	note("%s binds a %s of %s. Now stage %d." % [ab_name, con["tier"], label, int(state["stage"])])
	return "bound"


## Placeholder binding flow until the ethercosm screen exists: bind the first carried construct
## into the first ability that is full and waiting for that tier.
func bind_first_ready() -> void:
	if constructs.is_empty():
		note("You carry no constructs.")
		return
	for ci: int in constructs.size():
		for ai: int in abilities.size():
			if pending_tier(abilities[ai]) == str(constructs[ci]["tier"]):
				bind_construct(ai, ci)
				return
	note("No ability is full and waiting for what you carry.")


## PLACEHOLDER source of constructs until the Netherecho exists: some enemies leave one behind.
func _roll_drops(target: Node) -> void:
	var kind_v: Variant = target.get("kind")
	if kind_v == null or str(kind_v) == "":
		return
	var drops: Dictionary = GameData.enemy(str(kind_v)).get("drops", {})
	for tier: String in drops:
		if rng.randf() < float(drops[tier]):
			var ids: Array = GameData.concept_ids()
			var concept_id: String = str(ids[rng.randi() % ids.size()])
			constructs.append({"tier": tier, "concept": concept_id})
			note("It leaves a %s of %s behind." % [tier, str(GameData.concept(concept_id).get("label", concept_id))])


# --- gear, loot, saving ----------------------------------------------------------

## A stat of the weapon in hand. A weapon is held in the striking arm, so with that arm lost it
## counts for nothing (neutral value) until the arm is regrown.
func weapon_stat(stat_name: String, multiplicative: bool = false) -> float:
	var neutral: float = 1.0 if multiplicative else 0.0
	if arm_right_lost:
		return neutral
	var stats: Dictionary = GameData.item(str(inventory.equipped.get("weapon", ""))).get("stats", {})
	return float(stats.get(stat_name, neutral))


## How far a base strike reaches right now.
func reach_now() -> float:
	return melee_range + weapon_stat("melee_range_bonus")


## Re-read what equipment grants. Call after anything is equipped or removed.
func refresh_gear() -> void:
	satellite_rate = float(_p["starter_satellite_rate"]) + inventory.stat("satellite_rate")
	_show_weapon()


## Put the equipped weapon in the model's hand (or take it away).
func _show_weapon() -> void:
	if _rig == null:
		return
	var id: String = str(inventory.equipped.get("weapon", ""))
	if id == _shown_weapon:
		return
	_shown_weapon = id
	_rig.set_weapon(Models.weapon(id) if id != "" else null)


## Kills leave items on the ground where the enemy fell.
func _roll_loot(target: Node) -> void:
	var kind_v: Variant = target.get("kind")
	if kind_v == null or str(kind_v) == "" or not is_inside_tree():
		return
	var parent: Node = target.get_parent()
	if parent == null:
		return
	for entry: Dictionary in GameData.enemy(str(kind_v)).get("loot", []):
		if rng.randf() < float(entry["chance"]):
			var at: Vector3 = (target as Node3D).global_position + Vector3(rng.randf_range(-0.8, 0.8), 0.0, rng.randf_range(-0.8, 0.8))
			spawn_pickup(parent, str(entry["item"]), at)


static func spawn_pickup(parent: Node, item_id: String, at: Vector3) -> Node3D:
	var script: GDScript = load("res://scripts/pickup.gd")
	var drop: Node3D = script.new()
	drop.call("setup", item_id)
	parent.add_child(drop)
	drop.global_position = Vector3(at.x, 0.0, at.z)
	return drop


## Put a ground item in the bag, if there is room to carry it.
func take_pickup(drop: Node3D) -> bool:
	var id: String = str(drop.get("item_id"))
	var item_name: String = str(GameData.item(id).get("name", id))
	if not inventory.add(id):
		note("%s is too heavy - you are carrying %d of %d kg." % [item_name, int(inventory.weight()), int(inventory.capacity())])
		return false
	drop.call("take")
	note("Picked up %s." % item_name)
	return true


## Everything that must survive between sessions.
func to_save() -> Dictionary:
	return {
		"name": char_name, "identity": identity, "look": look.duplicate(), "affinities": affinities.duplicate(),
		"tempering": tempering.duplicate(true),
		"talent_id": talent_id, "stars": stars, "star_pct": star_pct.duplicate(), "money": money,
		"essence": essence, "latent_aura": _latent_aura,
		"body_hp": body.hp.duplicate(), "body_max": body.max_hp.duplicate(),
		"arm_right": arm_right, "arm_right_lost": arm_right_lost, "arm_regrow": _arm_regrow,
		"abilities": abilities.duplicate(true), "hotbar": hotbar.duplicate(),
		"constructs": constructs.duplicate(true), "discoveries": discoveries.duplicate(),
		"heal_points_total": heal_points_total, "inventory": inventory.to_dict(),
	}


func from_save(d: Dictionary) -> void:
	set_talent(str(d.get("talent_id", "")))
	char_name = str(d.get("name", ""))
	identity = str(d.get("identity", ""))
	# a save keeps the affinities it was made with; saves from before affinities were all water
	affinities.clear()
	for a: Variant in d.get("affinities", ["water"]):
		affinities.append(str(a))
	clear_reflux()
	_reset_loadout()                  # the kit for those affinities, unless the save lists abilities below
	# tempering: what the save has, on top of what such a character starts knowing. The health it
	# added is already in the saved body_max, so stages are set here without applying it again.
	tempering.clear()
	for id: String in GameData.technique_ids():
		var t_aff: String = str(GameData.technique(id).get("affinity", ""))
		if t_aff == "" or affinities.has(t_aff):
			tempering[id] = {"stage": 0, "progress": 0.0}
	var saved_temper: Dictionary = d.get("tempering", {})
	for id: String in saved_temper:
		if not GameData.technique(id).is_empty():
			tempering[id] = {"stage": int((saved_temper[id] as Dictionary).get("stage", 0)), "progress": float((saved_temper[id] as Dictionary).get("progress", 0.0))}
	set_look(d.get("look", {}))
	stars = int(d.get("stars", 1))
	star_pct.clear()
	for pct: Variant in d.get("star_pct", [GameData.num("stars", "first_star_start_pct")]):
		star_pct.append(float(pct))
	_recompute_essence_max()
	money = int(d.get("money", 0))
	essence = minf(essence_max, float(d.get("essence", essence_max)))
	_latent_aura = float(d.get("latent_aura", 0.0))
	var hp: Dictionary = d.get("body_hp", {})
	var mx: Dictionary = d.get("body_max", {})
	for layer: String in body.hp:
		if mx.has(layer):
			body.max_hp[layer] = float(mx[layer])
		if hp.has(layer):
			body.hp[layer] = float(hp[layer])
	arm_right = float(d.get("arm_right", arm_right))
	arm_right_lost = bool(d.get("arm_right_lost", false))
	_arm_regrow = float(d.get("arm_regrow", 0.0))
	var saved_abilities: Array = d.get("abilities", [])
	if not saved_abilities.is_empty():
		abilities.clear()
		for a: Dictionary in saved_abilities:
			a["stage"] = int(a.get("stage", 0))
			a["progress"] = float(a.get("progress", 0.0))
			abilities.append(a)
	var saved_hotbar: Array = d.get("hotbar", [])
	for i: int in mini(saved_hotbar.size(), hotbar.size()):
		hotbar[i] = int(saved_hotbar[i])
	constructs.clear()
	for c: Variant in d.get("constructs", []):
		constructs.append(c)
	discoveries.clear()
	for line: Variant in d.get("discoveries", []):
		discoveries.append(str(line))
	heal_points_total = float(d.get("heal_points_total", 0.0))
	inventory.from_dict(d.get("inventory", {}))
	refresh_gear()


# --- stars ----------------------------------------------------------------------

func _recompute_essence_max() -> void:
	var total := 0.0
	for pct: float in star_pct:
		total += GameData.num("stars", "full_tank") * pct / 100.0
	essence_max = total


## Grow the newest star's capacity by `pct` points, capped at max_pct.
func grow_star(pct: float) -> void:
	if star_pct.is_empty():
		return
	var i: int = star_pct.size() - 1
	var before: float = star_pct[i]
	var cap: float = GameData.num("stars", "max_pct")
	star_pct[i] = minf(cap, star_pct[i] + pct)
	if star_pct[i] != before:
		_recompute_essence_max()
		if before < cap and star_pct[i] >= cap:
			note("Your newest star is full. It will grow no further without ascending.")


func _enemy_nearby() -> bool:
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if not bool(node.call("is_dead")):
			return true
	return false


func _fire_projectile(ab: Dictionary, stage_mult: float, color: Color) -> void:
	var bolt: Node3D = Projectile.new()
	bolt.set("color", color)
	bolt.set("dir", _facing)
	bolt.set("damage", float(ab["damage"]) * stage_mult)
	bolt.set("speed", float(ab["speed"]))
	bolt.set("life", float(ab["life"]))
	bolt.set("shooter", self)
	get_parent().add_child(bolt)
	bolt.global_position = global_position + Vector3.UP * 1.0 + _facing * 0.8


## Meditation gathers wisps and refills essence (Brent 2026-09-23).
func _meditate_gather(delta: float) -> void:
	if meditating:
		essence = minf(essence_max, essence + GameData.num("meditation", "gather_per_s") * delta)


func _check_death() -> void:
	if not dead and body.is_dead():
		dead = true
		if _rig != null:
			_rig.set_dead_look()
		died.emit()


# --- between fights -----------------------------------------------------------

## Rent keeps ticking while you rest. Money may go negative: that is debt.
func charge(amount: int) -> void:
	money -= amount


func _can_afford(cost: int) -> bool:
	return money - cost >= int(_p["debt_limit"])


## Public form for the town: will anyone extend this much credit?
func can_afford(cost: int) -> bool:
	return _can_afford(cost)


## What the healer would do next and what it would cost - for the town screen.
func next_healing() -> Dictionary:
	if arm_right_lost:
		return {"desc": "Regrow your striking arm. The only way without a talent.", "cost": int(_arm["regrow_price"])}
	for layer: String in Body.ORDER_HEAL:
		var gap: float = body.missing(layer)
		if gap > 0.0:
			var amount: float = minf(float(_heal_cfg["hp_per_visit"]), gap)
			return {"desc": "Mend %d points of %s damage. Fast, and priced by how deep the wound is." % [int(ceil(amount)), layer],
				"cost": int(ceil(amount * float(_heal_cfg["price_" + layer])))}
	return {"desc": "Nothing to mend. You are whole.", "cost": 0}


## The healer sells speed, and the one thing rest cannot do: regrowth. Credit is extended to a limit.
func buy_healing() -> void:
	if arm_right_lost:
		var price: int = int(_arm["regrow_price"])
		if not _can_afford(price):
			note("Healer: regrowing an arm is $%d. Your credit won't stretch that far." % price)
			return
		money -= price
		arm_right_lost = false
		arm_right = float(_arm["max"])
		_arm_regrow = 0.0
		note("Healer: -$%d, arm regrown." % price)
		return
	for layer: String in Body.ORDER_HEAL:
		var gap: float = body.missing(layer)
		if gap <= 0.0:
			continue
		var amount: float = minf(float(_heal_cfg["hp_per_visit"]), gap)
		var cost: int = int(ceil(amount * float(_heal_cfg["price_" + layer])))
		if not _can_afford(cost):
			note("Healer: %s work costs $%d. You have $%d and no more credit." % [layer, cost, money])
			return
		money -= cost
		body.heal_layer(layer, amount)
		note("Healer: -$%d for %d %s HP." % [cost, int(amount), layer])
		return
	note("Healer: nothing to mend.")


## Standard-mode death (design/03 section 7b): dragged out, patched up, and billed for it.
## The fee is charged with no credit check - this is how a character ends up in debt.
func revive_in_debt(fee: int) -> void:
	var town: Dictionary = GameData.balance["town"]
	dead = false
	in_combat = false
	meditating = false
	effects.clear()
	set_talent(talent_id)
	_charging = false
	_charge = 0.0
	clear_reflux()
	money -= fee
	# Patched up, not healed: enough to stand, and nothing lost comes back.
	body.hp["superficial"] = maxf(float(body.hp["superficial"]), float(body.max_hp["superficial"]) * float(town["revive_superficial_frac"]))
	body.hp["structural"] = maxf(float(body.hp["structural"]), float(body.max_hp["structural"]) * float(town["revive_structural_frac"]))
	body.hp["catastrophic"] = maxf(float(body.hp["catastrophic"]), float(town["revive_catastrophic_min"]))
	_build_model()
	note("You wake on a cot. Someone dragged you out. The bill is $%d." % fee)


## A night in town: the body does what bodies do. Rent for the night is charged by the caller.
func rest_night() -> void:
	var night: Dictionary = GameData.balance["night"]
	body.heal_layer("superficial", float(body.max_hp["superficial"]))
	body.heal_layer("structural", float(night["structural_healed"]))
	if not arm_right_lost:
		arm_right = minf(float(_arm["max"]), arm_right + float(night["arm_restored"]))
	clear_reflux()
	essence = essence_max
	note("You sleep. Cuts close; bones knit a little. What is gone stays gone.")


func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Node3D
		if e == null or bool(e.call("is_dead")):
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


## Test bot: returns true when it wants to swing.
func _bot_think() -> bool:
	var near: Node3D = _nearest_enemy()
	var goal: Vector3 = near.global_position if near != null else bot_goal
	var to: Vector3 = goal - global_position
	to.y = 0.0
	var dist: float = to.length()
	_bot_dir = to / dist if dist > 0.6 else Vector3.ZERO
	if dist > 0.2:
		_facing = to / dist
	if near == null:
		return false
	return dist <= reach_now() + float(near.get("radius"))


func start_fight() -> void:
	in_combat = true
	fight_time = 0.0


func end_fight() -> void:
	in_combat = false


func aura_read() -> String:
	var frac: float = _latent_aura / _aura_threshold
	if stars >= 2:
		return "Two stars turn in the dark."
	if frac < 0.25:
		return "The star is quiet."
	if frac < 0.6:
		return "The star stirs."
	if frac < 1.0 or star_pct.back() < GameData.num("stars", "max_pct"):
		return "The star feels heavy." if frac >= 0.6 else "The star stirs."
	return "The star strains against itself.  %s to ascend" % Keybinds.binding_text("ascend")


func try_ascend() -> void:
	var full: bool = star_pct.back() >= GameData.num("stars", "max_pct")
	if stars >= 2 or not full or _latent_aura < _aura_threshold:
		note("Nothing happens. The star is not ready.")
		return
	var asc: Dictionary = GameData.balance["ascension_2"]
	_latent_aura -= _aura_threshold
	stars = 2
	# A new star is born tiny (Brent 2026-09-23) and grows from here.
	star_pct.append(GameData.num("stars", "new_star_start_pct"))
	_recompute_essence_max()
	essence = essence_max
	body.scale_max(float(asc["body_scale"]))
	clear_reflux()
	for e: TalentEffect in effects:
		e.on_ascend(stars)
	note("ASCENDED. A second star splits off - tiny, for now.")
	note("Talent evolves: %s" % str(talent.get("evolve_2", "?")))
	if talent_id != "one_percent_lifesteal":
		note("(this talent's evolution is not wired into the prototype yet)")


# --- helpers ------------------------------------------------------------------

## Extra notebook lines contributed by effects (e.g. damage still owed).
func status_lines() -> Array[String]:
	var out: Array[String] = []
	for e: TalentEffect in effects:
		out.append_array(e.status_lines())
	return out


func discover(line: String) -> void:
	if not discoveries.has(line):
		discoveries.append(line)
		note("Proven - %s" % line)


func note(line: String) -> void:
	log_serial += 1
	log_lines.append(line)
	while log_lines.size() > 5:
		log_lines.remove_at(0)


func _float(txt: String, color: Color) -> void:
	if is_inside_tree():
		FloatText.spawn(get_parent(), global_position, txt, color)


func _text(target: Node, txt: String, color: Color) -> void:
	if is_inside_tree():
		FloatText.spawn(get_parent(), (target as Node3D).global_position + Vector3.UP * 0.6, txt, color)


## Where the mouse cursor meets the floor the player stands on.
func _cursor_ground() -> Vector3:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return global_position
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var origin: Vector3 = cam.project_ray_origin(mouse)
	var normal: Vector3 = cam.project_ray_normal(mouse)
	if absf(normal.y) < 0.0001:
		return global_position
	var t: float = (global_position.y - origin.y) / normal.y
	return origin + normal * t


func _update_aim() -> void:
	if attack_target != null or has_move_goal:
		return                                 # facing follows the click target / walk goal
	var to: Vector3 = _cursor_ground() - global_position
	to.y = 0.0
	if to.length() > 0.2:
		_facing = to.normalized()


func _swing_visual(reach: float, heavy: bool, narrow: bool) -> void:
	if not is_inside_tree():
		return
	var arc := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5 if narrow else reach * 1.4, 0.08, reach)
	arc.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.5, 0.2, 0.6) if heavy else Color(1, 1, 1, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arc.material_override = mat
	get_parent().add_child(arc)
	arc.global_position = global_position + _facing * (reach * 0.5) + Vector3.UP * 0.9
	arc.rotation.y = rotation.y
	var tween: Tween = arc.create_tween()
	tween.tween_property(arc, "scale", Vector3(1.1, 1.0, 1.1), 0.12)
	tween.tween_callback(arc.queue_free)
