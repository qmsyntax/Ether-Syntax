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
var _wound_seq := 0
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

var _wound_cd := 0.0                 # seconds until another blow can wound
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
var _dash_pass: Dictionary = {}      # the dash's on_pass payload, while one is under way
var _dash_pass_radius := 1.0
var _dash_tags: Array = []
var _dash_passed: Array = []         # enemies already touched by this dash
var _dash_from := Vector3.ZERO       # where the dash was at the last check
var _dash_start := Vector3.ZERO      # where the dash began (a trail runs from here)
var _dash_trail: Dictionary = {}     # the strip of ground this dash leaves behind, if any
var _dash_stops := false             # this dash does not carry you through a body
var _dash_color := Color(1, 1, 1)
var _recover_t := 0.0                # no striking or casting until this runs out
var _ranged_cd := 0.0                # until the ranged weapon can loose again
## Enemies holding one of the places in striking range of you (design/05 6.2, the slot ring).
var _ring: Array = []
## Your own footing. Only heavy blows touch it; at zero you are staggered for a moment.
var poise := 100.0
var _stagger_t := 0.0                # staggered: no moving, striking or casting
var _winded_t := 0.0                 # a second movement skill inside this costs double
## Slipstream (wind only): pips earned by moving and lost by standing; wind skills spend them.
var pips := 0
var _pip_dist := 0.0                 # metres travelled toward the next pip
var _still_t := 0.0                  # how long you have been standing
var _pip_decay_t := 0.0
var _last_pos := Vector3.ZERO
var _moving := false                 # moved this step (for wind's reflux rule)
## Standing stone this character has raised (earth), oldest first.
var stones: Array = []
## A skill that has been paid for and is waiting on its wind-up (see cast_ability).
var _windup: Dictionary = {}
var _windup_t := 0.0
var _windup_total := 0.0
var _shoved_left := 0.0              # metres still to slide from an enemy's shove
var _shoved_dir := Vector3.ZERO
## Where the cursor is taken to be when set: a test or a bot pointing with no mouse.
var cursor_fixed: Variant = null
## True while the ranged stance is held with a ranged weapon equipped: the strike button shoots.
var ranged_stance := false
var _range_ring: MeshInstance3D
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
	body = Body.new(float(_p["health"]))
	body.min_max_frac = 1.0 - float(GameData.balance["wounds"]["max_cut_frac"])
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
	var wound_up: bool = _charging or _windup_t > 0.0
	if wound_up != _shown_windup:
		_shown_windup = wound_up
		_rig.set_windup(wound_up)
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


## "+16 health", "reflux sheds 32% faster" ... what a technique gives at `stage`.
func temper_effect_text(id: String, stage: int) -> String:
	var eff: Dictionary = GameData.technique(id).get("effect", {})
	var per: float = float(eff.get("per_stage", 0.0))
	var amount: float
	if str(eff.get("stat", "")).begins_with("max_"):
		amount = per * float(stage)
	else:
		amount = absf(pow(per, float(stage)) - 1.0) * 100.0
	return str(eff.get("text", "%d")) % int(round(amount))


## What one session strains the body by: taken off the health bar's maximum until it is mended.
func temper_session_damage(id: String) -> float:
	var s: Dictionary = GameData.tempering_session()
	return float(s["strain_base"]) + float(s["strain_per_stage"]) * float(int((tempering[id] as Dictionary)["stage"]))


func temper_session_progress(id: String) -> float:
	var s: Dictionary = GameData.tempering_session()
	return float(s["progress_base"]) * pow(float(s["progress_falloff_per_stage"]), float(int((tempering[id] as Dictionary)["stage"])))


## Why a session cannot be trained right now, or "" if it can.
func cannot_temper_reason(id: String) -> String:
	if not tempering.has(id):
		return "You do not know it."
	if int((tempering[id] as Dictionary)["stage"]) >= temper_stage_cap():
		return "Needs another star."
	if body.max_cut() + temper_session_damage(id) > body.max_hp * float(GameData.tempering_session()["max_cut_frac"]):
		return "Your body cannot take it. Mend first."
	return ""


## One training session: it costs bone and moves the technique along; a full bar is a new stage.
## Returns false if the session could not be trained.
func temper_session(id: String) -> bool:
	if cannot_temper_reason(id) != "":
		return false
	var st: Dictionary = tempering[id]
	var strain: float = temper_session_damage(id)
	body.add_wound("temper_strain", str(GameData.balance["wounds"]["temper"]["name"]), strain, strain, true, true)
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
	if stat != "max_health" or stages == 0:
		return
	var add: float = float(eff["per_stage"]) * float(stages)
	body.max_hp = maxf(1.0, body.max_hp + add)
	body.hp = clampf(body.hp + add, 0.0, body.total_max())


## Start over with the kits of the current affinities, on the bar in order.
func _reset_loadout() -> void:
	drop_stones()
	_windup = {}
	_windup_t = 0.0
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
		var a_def: Dictionary = GameData.affinity(aff)
		var rate: float = float(a_def.get("reflux_shed_mult_combat", 1.0)) if in_combat else 1.0
		if in_combat and a_def.has("reflux_shed_mult_moving"):
			# wind: its heat blows off while you run and sits while you stand
			rate = float(a_def["reflux_shed_mult_moving"]) if _moving else float(a_def.get("reflux_shed_mult_standing", 1.0))
		rate *= float(a_def.get("reflux_shed_mult", 1.0))       # earth keeps what little it makes
		reflux_by[aff] = maxf(0.0, float(reflux_by[aff]) - shed * rate)
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
	_recover_t -= delta
	_ranged_cd -= delta
	_winded_t -= delta
	_stagger_t -= delta
	_meditate_block -= delta
	if in_combat:
		fight_time += delta

	essence = minf(essence_max, essence + satellite_rate * delta)
	_wound_cd -= delta
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
	if _windup_t > 0.0:
		_tick_windup(delta)

	# Meditation is sitting still: it roots you at once, and only counts once you have settled.
	_sitting = Input.is_action_pressed("meditate") and _meditate_block <= 0.0 and not _charging and _windup_t <= 0.0
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
		body.heal(float(_natural["health_per_s"]) * delta)      # the bar only - never a wound
		if not arm_right_lost:
			arm_right = minf(float(_arm["max"]), arm_right + float(_natural["arm_per_s"]) * delta)

	var charging_input: bool = Input.is_action_pressed("overcharge") and not arm_right_lost
	if charging_input and not _sitting and _windup_t <= 0.0:
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
	var was_stance: bool = ranged_stance
	ranged_stance = not bot and not _sitting and not ui_blocked and Input.is_action_pressed("ranged_stance") and not ranged_weapon().is_empty()
	if ranged_stance != was_stance:
		_show_range_ring(ranged_stance)
	if ranged_stance:
		# feet stay where they are: no walking to a click, no closing to strike
		attack_target = null
		pickup_target = null
		has_move_goal = false
		if Input.is_action_pressed("strike"):
			fire_ranged(_ranged_aim())
	if not bot and not ranged_stance and Input.is_action_just_pressed("strike") and not _sitting and not ui_blocked:
		_click_cursor()
	if not bot and not ranged_stance and Input.is_action_pressed("strike") and attack_target == null and has_move_goal:
		move_goal = _cursor_ground()          # holding on the ground keeps steering

	var input := Vector2.ZERO
	if not _sitting and _stagger_t <= 0.0 and _windup_t <= 0.0:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _stagger_t > 0.0:
		# off your feet: nowhere to go and nothing to swing until it passes
		has_move_goal = false
		attack_target = null
		pickup_target = null
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
			if bot:
				# a person steers through a doorway by hand; the bot has to be told where it is
				var router: Node = get_tree().get_first_node_in_group("router")
				if router != null:
					var way: Vector3 = (router.call("route", global_position, attack_target.global_position, 0.4) as Vector3) - global_position
					way.y = 0.0
					if way.length() > 0.05:
						dir = way.normalized()
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
	if ranged_stance:
		speed *= GameData.num("ranged", "stance_move_factor")
	if pips >= GameData.inum("slipstream", "speed_pips"):
		speed *= GameData.num("slipstream", "speed_mult")
	if _windup_t > 0.0:
		dir = Vector3.ZERO                       # set: you do not move until it goes off
	velocity = dir * speed
	if _shoved_left > 0.0:
		# knocked back: an exact distance, and nothing you were doing with your feet survives it
		var push: float = minf(_shoved_left, GameData.num("combat", "player_shove_speed") * delta)
		_shoved_left -= push
		velocity = Vector3.ZERO
		if move_and_collide(_shoved_dir * push) != null:
			_shoved_left = 0.0
	elif _dash_time > 0.0:
		# A dash covers an exact distance: it is moved by hand, not by velocity, whose time step
		# the engine chooses (that made a 4.2 m dash travel 23 m in a test, and would on a hitch).
		var step_t: float = minf(delta, _dash_time)
		var step: Vector3 = _dash_vel * step_t
		_dash_time -= step_t
		velocity = Vector3.ZERO
		if _dash_stops and _body_ahead(_dash_vel.normalized(), step.length()):
			_dash_time = 0.0                     # this one does not go through people
		elif move_and_collide(step) != null:
			_dash_time = 0.0                     # a wall
		_dash_touch()
		if _dash_time <= 0.0:
			_end_dash()
			_dash_pass = {}
	else:
		move_and_slide()

	_tick_slipstream(delta)
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

	# Heat (design/05 2.2): for an affinity with damage_per_reflux, its own reflux multiplies its damage
	for aff: String in affinities:
		if ctx.has_tag(aff):
			var per: float = float(GameData.affinity(aff).get("damage_per_reflux", 0.0))
			if per > 0.0:
				ctx.mult *= heat_mult(aff)
	var pos: Vector3 = (target as Node3D).global_position
	var combat: Dictionary = GameData.balance["combat"]
	var bare_strike: bool = ctx.has_tag("melee") and not ctx.has_tag("ability")
	var from_behind: bool = ctx.has_tag("rear") or (target.has_method("is_behind") and bool(target.call("is_behind", global_position)))
	if from_behind:
		# Lee (wind): a hit from this affinity on a back does more again
		for aff: String in affinities:
			if ctx.has_tag(aff):
				ctx.mult *= 1.0 + float(GameData.affinity(aff).get("rear_bonus", 0.0))
	var opening: bool = bare_strike and target.has_method("has_status") and bool(target.call("has_status", "staggered"))
	if from_behind:
		ctx.mult *= float(combat["rear_mult"])           # where you stand matters, for every affinity
	if opening:
		ctx.mult *= float(combat["opening_mult"])        # the reason to click one enemy instead of casting again
	ctx.applied = target.call("take_hit", ctx.amount(), ctx.heavy, self)
	if ctx.applied <= 0.0:
		return ctx
	if not ctx.is_scenery:
		FloatText.spawn(get_parent(), pos, "%d" % int(ctx.applied), Color(1, 0.86, 0.45) if opening else (Color(0.75, 0.95, 1.0) if from_behind else Color(1, 1, 1)))
		if opening:
			FloatText.spawn(get_parent(), pos + Vector3.UP * 0.5, "OPENING", Color(1, 0.86, 0.45))
		elif from_behind:
			FloatText.spawn(get_parent(), pos + Vector3.UP * 0.5, "back", Color(0.75, 0.95, 1.0))
	ctx.killed = bool(target.call("is_dead"))
	if bare_strike and not ctx.is_scenery:
		# working it off: every strike that lands bleeds a little heat from your hottest affinity
		var hottest := ""
		for aff: String in reflux_by:
			if hottest == "" or float(reflux_by[aff]) > float(reflux_by[hottest]):
				hottest = aff
		if hottest != "":
			reflux_by[hottest] = maxf(0.0, float(reflux_by[hottest]) - float(combat["strike_sheds_reflux"]))
		if not ctx.killed and target.has_method("take_poise"):
			target.call("take_poise", float(combat["strike_poise"]) * (2.0 if ctx.has_tag("overcharge") else 1.0))

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
	# What the body and what it wears take off the blow comes first, so every talent works on
	# the same reduced number - including one that swallows the hit and delivers it later.
	ctx.base = amount * temper_stat("incoming_mult") * (1.0 - armour() / 100.0)
	var braced: bool = is_braced()
	if braced:
		ctx.base *= GameData.num("braced", "damage_taken_mult")
	ctx.heavy = heavy
	if projecting:
		disturbed.emit()             # pain drags the soul back before the blow is even counted
	_meditate_block = 1.0
	meditating = false
	for e: TalentEffect in effects:
		e.on_incoming(ctx)
	if ctx.cancelled:
		return 0.0
	if heavy and not braced:                 # set for an earth skill: nothing knocks you off it
		var combat: Dictionary = GameData.balance["combat"]
		poise -= float(combat["heavy_poise_damage"])
		if poise <= 0.0:
			poise = float(combat["player_poise"])
			_stagger_t = float(combat["player_stagger_s"])
			_dash_time = 0.0
			_windup = {}                          # whatever you were winding up is lost
			_windup_t = 0.0
			_float("STAGGERED", Color(1, 0.7, 0.3))
	return _apply_damage(ctx.amount(), heavy)


## --- wind-ups, Braced and standing stone (earth, design/05 2.3) ---------------------------------

## An enemy's blow throws you `metres` along `dir`. Not if you are Braced.
func shove(dir: Vector3, metres: float) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if dead or bot or is_braced() or flat.length() < 0.001 or metres <= 0.0:
		return
	_shoved_dir = flat.normalized()
	_shoved_left = metres
	_dash_time = 0.0
	has_move_goal = false


## True while you are set for a braced skill: you take less and cannot be staggered.
func is_braced() -> bool:
	return _windup_t > 0.0 and bool(_windup.get("braced", false))


## How far through a wind-up you are, 0 to 1; -1 when you are not winding anything up.
func windup_frac() -> float:
	if _windup_t <= 0.0 or _windup_total <= 0.0:
		return -1.0
	return clampf(1.0 - _windup_t / _windup_total, 0.0, 1.0)


## A wind-up holds you where you stood and where you aimed; when it ends, the skill goes off.
func _tick_windup(delta: float) -> void:
	_facing = _windup.get("facing", _facing)
	has_move_goal = false
	attack_target = null
	pickup_target = null
	_windup_t -= delta
	if _windup_t > 0.0:
		return
	var w: Dictionary = _windup
	_windup = {}
	_windup_t = 0.0
	if not bool(w.get("release", false)):
		return
	var target: Node3D = w["target"] if is_instance_valid(w["target"]) else null
	_perform_cast(w["ab"], str(w["kind"]), str(w["aff"]), float(w["stage_mult"]), w["tags"], target, w["point"])


## True if the character holds an affinity that raises standing stone.
func has_stone() -> bool:
	for aff: String in affinities:
		if bool(GameData.affinity(aff).get("stone", false)):
			return true
	return false


## How many of your stones are standing (or rising).
func stone_count() -> int:
	for s: Variant in stones.duplicate():
		if not is_instance_valid(s) or (s as Node).is_queued_for_deletion():
			stones.erase(s)
	return stones.size()


## A stone of yours fell (called by the stone).
func stone_gone(s: Node) -> void:
	stones.erase(s)


## Every stone of yours crumbles: a new character, or a new place.
func drop_stones() -> void:
	for s: Variant in stones.duplicate():
		if is_instance_valid(s):
			(s as Stone).crumble()
	stones.clear()


## Raise a slab at `at`, lying across `away` (the way you are looking at it). You keep only so
## many: one more crumbles the oldest.
func raise_stone(at: Vector3, away: Vector3, ab: Dictionary, stage_mult: float = 1.0, tags: Array = []) -> Node3D:
	var cfg: Dictionary = GameData.balance["stone"]
	stone_count()
	while stones.size() >= int(cfg["max_count"]):
		var old: Variant = stones.pop_front()
		if is_instance_valid(old):
			(old as Stone).crumble()
	var s := Stone.new()
	s.caster = self
	s.size = Vector3(float(ab.get("width", 3.0)), float(ab.get("height", 1.8)), float(ab.get("thickness", 0.6)))
	s.hp = float(ab.get("hp", cfg["hp"]))
	s.life = float(ab.get("life", cfg["life_s"]))
	s.rise_s = float(ab.get("rise_time", 0.35))
	s.on_rise = ab.get("on_rise", {})
	s.tags = tags
	s.stage_mult = stage_mult
	get_parent().add_child(s)
	s.global_position = Vector3(at.x, global_position.y, at.z)
	var flat := Vector3(away.x, 0.0, away.z)
	if flat.length() > 0.01:
		s.rotation.y = atan2(-flat.x, -flat.z)
	stones.append(s)
	return s


## Where a slab would stand: toward the cursor, no nearer than the skill's `min_range` (so it does
## not come up under you) and no farther than its `range`; short of a wall if one is in the way.
## Null if there is no room at all.
func _prop_point(ab: Dictionary) -> Variant:
	var reach: float = float(ab.get("range", 8.0))
	var near: float = float(ab.get("min_range", 1.5))
	var want: Vector3 = _cursor_ground() - global_position
	want.y = 0.0
	if want.length() < 0.5:
		want = _facing * reach                    # no cursor to speak of (bot, headless): straight ahead
	var dist: float = clampf(want.length(), near, reach)
	var dir: Vector3 = want.normalized()
	var chest: Vector3 = global_position + Vector3.UP
	var wall: Dictionary = _ray(chest, chest + dir * (dist + 0.6))
	if not wall.is_empty():
		dist = chest.distance_to(wall["position"]) - 0.6
		if dist < near:
			return null
	return global_position + dir * dist


## True if any part of the slab lies inside a swing of `reach` and `half_angle` from where you face.
func _stone_in_arc(s: Stone, reach: float, half_angle: float) -> bool:
	var across: Vector3 = s.global_transform.basis.x * (s.size.x * 0.5)
	for i: int in 5:
		var to: Vector3 = s.global_position + across * ((float(i) - 2.0) / 2.0) - global_position
		to.y = 0.0
		var dist: float = to.length()
		if dist <= reach + s.size.z * 0.5 and (dist < 0.3 or _facing.angle_to(to / dist) <= half_angle):
			return true
	return false


## Where a shot leaves you: a little ahead, unless something solid is closer than that.
func _muzzle() -> Vector3:
	var chest: Vector3 = global_position + Vector3.UP * 1.0
	var out: Vector3 = chest + _facing * 0.8
	return chest if not _ray(chest, out).is_empty() else out


## True if the character holds an affinity that runs on Slipstream.
func has_slipstream() -> bool:
	for aff: String in affinities:
		if bool(GameData.affinity(aff).get("slipstream", false)):
			return true
	return false


## Slipstream: a pip for every stretch travelled, by whatever means; they drain once you stand.
func _tick_slipstream(delta: float) -> void:
	var moved: Vector3 = global_position - _last_pos
	moved.y = 0.0
	_last_pos = global_position
	var dist: float = moved.length()
	if dist > 50.0:
		dist = 0.0                               # placed somewhere new (a level change), not travelled
	_moving = dist > 0.001
	if not has_slipstream():
		pips = 0
		return
	var cfg: Dictionary = GameData.balance["slipstream"]
	if _moving:
		_still_t = 0.0
		_pip_decay_t = 0.0
		_pip_dist += dist
		var per: float = float(cfg["metres_per_pip"])
		while _pip_dist >= per:
			_pip_dist -= per
			pips = mini(int(cfg["max"]), pips + 1)
	else:
		_still_t += delta
		if _still_t >= float(cfg["still_delay_s"]):
			_pip_decay_t += delta
			if _pip_decay_t >= float(cfg["decay_s"]):
				_pip_decay_t -= float(cfg["decay_s"])
				pips = maxi(0, pips - 1)


## Take up to `want` pips (all of them if negative). Returns how many were spent.
func spend_pips(want: int) -> int:
	var n: int = pips if want < 0 else mini(pips, want)
	pips -= n
	return n


## How much an affinity's own reflux multiplies its damage right now (1.0 for most affinities).
func heat_mult(aff: String) -> float:
	return 1.0 + float(GameData.affinity(aff).get("damage_per_reflux", 0.0)) * reflux_of(aff) / 100.0


## True while a heavy blow has you off your feet: you cannot move, strike or cast.
func is_staggered() -> bool:
	return _stagger_t > 0.0


# --- the slot ring (design/05 6.2) ----------------------------------------------------------

## An enemy asks for one of the places in striking range of you. Granted if it already has one
## or one is free; the rest must wait their turn a few metres out.
func claim_slot(enemy: Node) -> bool:
	for i: int in range(_ring.size() - 1, -1, -1):
		var held: Variant = _ring[i]
		if not is_instance_valid(held) or bool((held as Node).call("is_dead")):
			_ring.remove_at(i)
	if _ring.has(enemy):
		return true
	if _ring.size() >= GameData.inum("combat", "ring_slots"):
		return false
	_ring.append(enemy)
	return true


func release_slot(enemy: Node) -> void:
	_ring.erase(enemy)


## The percent of each hit your worn armour takes off, capped so gear stays below the body.
func armour() -> float:
	return clampf(inventory.stat("armour"), 0.0, GameData.num("gear", "armour_cap"))


# --- the ranged weapon (design/06 3.2) -------------------------------------------------------

## The equipped ranged weapon's definition, or {} with none.
func ranged_weapon() -> Dictionary:
	var id: String = str(inventory.equipped.get("ranged", ""))
	return GameData.item(id) if id != "" else {}


func ranged_stat(key: String, fallback: float) -> float:
	return float((ranged_weapon().get("stats", {}) as Dictionary).get(key, fallback))


## What one shot does.
func ranged_damage() -> float:
	var cfg: Dictionary = GameData.balance["ranged"]
	return float(cfg["ranged_damage"]) * ranged_stat("ranged_damage_mult", 1.0) * (float(cfg["off_arm_damage_factor"]) if arm_right_lost else 1.0)


## Seconds between shots: the weapon's own interval, shortened by worn gear (a quiver belt).
func ranged_interval() -> float:
	return ranged_stat("ranged_interval", GameData.num("ranged", "default_interval")) * inventory.stat("ranged_interval_mult", true)


## Loose the ranged weapon toward a point on the ground. Costs nothing but the time between
## shots. Returns false if there is no weapon, it is not ready, or you are mid-skill.
func fire_ranged(toward: Vector3) -> bool:
	if ranged_weapon().is_empty() or _ranged_cd > 0.0 or _recover_t > 0.0 or not active or dead or meditating:
		return false
	var cfg: Dictionary = GameData.balance["ranged"]
	var aim: Vector3 = toward - global_position
	aim.y = 0.0
	if aim.length() > 0.2:
		_facing = aim.normalized()
	var speed: float = float(cfg["projectile_speed"])
	var shot: Node3D = Projectile.new()
	shot.set("color", Color(0.74, 0.72, 0.68))
	shot.set("tags", ["ranged"])
	shot.set("dir", _facing)
	shot.set("damage", ranged_damage())
	shot.set("speed", speed)
	shot.set("life", ranged_stat("ranged_range", float(cfg["default_range"])) / speed)
	shot.set("shooter", self)
	get_parent().add_child(shot)
	shot.global_position = _muzzle()
	_ranged_cd = ranged_interval()
	_strike_t = 0.18
	return true


## Where a shot is aimed: at the enemy under the cursor if there is one, else the ground there.
func _ranged_aim() -> Vector3:
	if hovered != null and is_instance_valid(hovered) and hovered.is_in_group("enemies"):
		return hovered.global_position
	return _cursor_ground()


## A thin ring on the ground showing how far a shot carries, while the stance is held.
func _show_range_ring(on: bool) -> void:
	if on and _range_ring == null and is_inside_tree():
		_range_ring = MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.985
		ring.outer_radius = 1.0
		ring.rings = 96
		ring.ring_segments = 4
		_range_ring.mesh = ring
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.9, 0.86, 0.7, 0.5)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_range_ring.material_override = mat
		_range_ring.position.y = 0.06
		add_child(_range_ring)
	if _range_ring != null:
		_range_ring.visible = on
		if on:
			var r: float = ranged_stat("ranged_range", GameData.num("ranged", "default_range"))
			_range_ring.scale = Vector3(r, 1.0, r)


## Damage that has passed the pipeline (or comes from an effect's own timer).
func _apply_damage(amount: float, heavy: bool) -> float:
	var applied: float = body.apply_damage(amount, heavy)
	if _rig != null and applied > 0.0:
		_rig.flash(0.1)
	_float("-%d" % int(applied), Color(1, 0.25, 0.25))
	_maybe_wound(applied)
	_check_death()
	return applied


# --- wounds -----------------------------------------------------------------------------

## A heavy enough blow, or one that leaves you nearly dead, leaves a wound behind.
func _maybe_wound(applied: float) -> void:
	var w: Dictionary = GameData.balance["wounds"]
	if applied <= 0.0 or body.is_dead() or _wound_cd > 0.0:
		return
	var big: bool = applied >= body.max_hp * float(w["big_hit_frac"])
	var low: bool = body.hp <= body.max_hp * float(w["low_health_frac"])
	if not big and not low:
		return
	var names: Array = w["names_big_hit"] if big else w["names_low"]
	var wound_name: String = str(names[rng.randi() % names.size()])
	_wound_seq += 1
	take_wound("hit_%d" % _wound_seq, wound_name, maxf(float(w["sink_min"]), applied * float(w["sink_per_damage"])), body.max_hp * float(w["cut_frac"]))
	_wound_cd = float(w["wound_cooldown_s"])


## Add a wound. Tempering can make every wound shallower. `merge` deepens an existing one.
func take_wound(id: String, wound_name: String, sink: float, cut: float, natural: bool = true, merge: bool = false) -> void:
	body.add_wound(id, wound_name, sink * temper_stat("wound_sink_mult"), cut, natural, merge)
	_float(wound_name.to_upper(), Color(1, 0.35, 0.2))
	note("%s. It will not close on its own." % wound_name if not natural else "%s. Rest alone will not close it in the field." % wound_name)


## Wounds that closed: tell the player, and a regrown arm comes back weak.
func _wounds_closed(ids: Array) -> void:
	for id: String in ids:
		if id == "lost_arm":
			arm_right_lost = false
			arm_right = float(_arm["max"]) * float(_arm["regrown_by_talent_integrity"])
			_float("ARM REGROWN", Color(0.4, 1, 0.5))
			discover("Regrows lost limbs: YES")
		else:
			_float("WOUND CLOSED", Color(0.5, 1, 0.6))


## Talent healing (Brent 2026-10-11). Supreme quality, one star: the wounds' hidden sinks first,
## then the health bar. Dynamic, two stars: the bar up to half, then the sinks, then the rest of
## the bar. A lost limb is a wound like any other here - this is what natural healing cannot do.
func _spend_heal_points(points: float) -> float:
	var left: float = points
	if stars >= 2:
		# Dynamic: keep the body on its feet first - the bar to half - then mend what is broken.
		left -= body.heal(left, body.total_max() * float(GameData.balance["talent_healing"]["dynamic_health_first_frac"]))
	if left > 0.0:
		var filled: Dictionary = body.fill_sinks(left)
		left -= float(filled["used"])
		_wounds_closed(filled["closed"])
	if left > 0.0:
		left -= body.heal(left)
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
	for t: Node3D in _in_arc(reach, melee_arc):
		deal_damage(t, strike_damage() * multiplier, tags)


## What one bare strike does, before any skill or stage multiplies it.
func strike_damage() -> float:
	return float(_p["melee_damage"]) * weapon_stat("melee_damage_mult", true)


## Everything hittable within `reach` and within `half_angle` (radians) of where you face.
func _in_arc(reach: float, half_angle: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node: Node in get_tree().get_nodes_in_group("hittable"):
		var t := node as Node3D
		if t == null:
			continue
		var to: Vector3 = t.global_position - global_position
		to.y = 0.0
		var dist: float = to.length()
		if dist > reach + float(t.get("radius")):
			continue
		if dist > 0.3 and _facing.angle_to(to / dist) > half_angle:
			continue
		out.append(t)
	return out


# --- the hit payload (design/05 Appendix B) ---------------------------------------------------

## A skill's payload for one of its touches ("on_hit", "on_pass", "on_arrive"), with the skill's
## own damage folded in when the payload does not carry any.
func _payload(ab: Dictionary, key: String) -> Dictionary:
	var p: Dictionary = (ab.get(key, {}) as Dictionary).duplicate()
	if key == "on_hit" and not p.has("damage") and not p.has("damage_mult"):
		if ab.has("damage"):
			p["damage"] = ab["damage"]
		elif ab.has("damage_mult"):
			p["damage_mult"] = ab["damage_mult"]
	return p


## Everything a skill does to one target, in one place: damage (through the talent pipeline),
## then status, Live marks, shove and interrupt. `dir` is the way a shove goes; zero means
## straight away from you. Scenery only takes the damage.
func apply_hit(target: Node, payload: Dictionary, tags: Array = [], stage_mult: float = 1.0, dir: Vector3 = Vector3.ZERO) -> HitContext:
	var ctx: HitContext = null
	if not is_instance_valid(target) or bool(target.call("is_dead")):
		return ctx
	if payload.has("damage"):
		ctx = deal_damage(target, float(payload["damage"]) * stage_mult, tags)
	elif payload.has("damage_mult"):
		ctx = deal_damage(target, strike_damage() * float(payload["damage_mult"]) * stage_mult, tags)
	if not is_instance_valid(target) or bool(target.call("is_dead")) or not target.has_method("add_status"):
		return ctx
	if payload.has("status"):
		target.call("add_status", str(payload["status"]), int(payload.get("stacks", 1)), self)
	if target.has_method("take_poise") and (payload.has("damage") or payload.has("damage_mult") or payload.has("poise")):
		target.call("take_poise", float(payload.get("poise", GameData.num("combat", "skill_poise"))))
	if bool(payload.get("interrupts", false)):
		if bool(target.call("interrupt_attack")):
			FloatText.spawn(get_parent(), (target as Node3D).global_position + Vector3.UP * 0.5, "INTERRUPTED", Color(1, 1, 1))
	if float(payload.get("shove", 0.0)) > 0.0:
		var away: Vector3 = dir
		if away.length() < 0.001:
			away = (target as Node3D).global_position - global_position
		away.y = 0.0
		if away.length() < 0.001:
			away = _facing
		target.set("shover", self)
		target.call("shove", away, float(payload["shove"]))
	if int(payload.get("marks", 0)) > 0:
		_add_marks(target, int(payload["marks"]), true)
	return ctx


## A shove ended against something with `metres_left` still to go (water's Crush): the shoved
## body takes base + per-metre, and a body it ran into takes a share. Both lose what they were doing.
func on_crush(enemy: Node, metres_left: float, hit: Node) -> void:
	var cfg: Dictionary = GameData.balance["shove"]
	var dmg: float = float(cfg["crush_base"]) + float(cfg["crush_per_m"]) * metres_left
	if is_instance_valid(enemy) and not bool(enemy.call("is_dead")):
		FloatText.spawn(get_parent(), (enemy as Node3D).global_position + Vector3.UP * 0.4, "CRUSH", Color(0.55, 0.8, 1.0))
		deal_damage(enemy, dmg, ["crush", "water"])
		if is_instance_valid(enemy) and not bool(enemy.call("is_dead")):
			enemy.call("interrupt")
	if is_instance_valid(hit) and hit.is_in_group("enemies") and not bool(hit.call("is_dead")):
		deal_damage(hit, dmg * float(cfg["crush_other_frac"]), ["crush", "water"])
		if is_instance_valid(hit) and not bool(hit.call("is_dead")):
			hit.call("interrupt")


## Lightning's Live marks. The third is an Overload. A hit on a Soaked target also marks every
## other Soaked enemy nearby (wet things conduct) - but conducted marks do not conduct again.
func _add_marks(target: Node, marks: int, conduct: bool) -> void:
	var live: Dictionary = GameData.status("live")
	var soaked: Dictionary = GameData.status("soaked")
	var others: Array[Node] = []
	if conduct and bool(target.call("has_status", "soaked")):
		for node: Node in get_tree().get_nodes_in_group("enemies"):
			if node != target and bool(node.call("has_status", "soaked")) \
					and (node as Node3D).global_position.distance_to((target as Node3D).global_position) <= float(soaked.get("conduct_radius", 4.0)):
				others.append(node)
	if int(target.call("add_status", "live", marks)) >= int(live.get("stacks", 3)):
		_overload(target)
	for node: Node in others:
		if is_instance_valid(node) and not bool(node.call("is_dead")):
			_add_marks(node, int(soaked.get("conduct_marks", 1)), false)


## The third mark: the target takes the big hit and is stunned, every other marked enemy in range
## takes the arc, and your lightning reflux is grounded a little. The others keep their marks.
func _overload(target: Node) -> void:
	var live: Dictionary = GameData.status("live")
	var at: Vector3 = (target as Node3D).global_position
	var arc_to: Array[Node] = []
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if node != target and int(node.call("status_stacks", "live")) > 0 \
				and (node as Node3D).global_position.distance_to(at) <= float(live.get("arc_radius", 12.0)):
			arc_to.append(node)
	target.call("clear_status", "live")
	FloatText.spawn(get_parent(), at + Vector3.UP * 0.6, "OVERLOAD", Color(0.85, 0.78, 1.0))
	deal_damage(target, float(live.get("overload_damage", 150.0)), ["overload", "lightning"])
	if is_instance_valid(target) and not bool(target.call("is_dead")):
		target.call("stun", float(live.get("stun", 1.0)))
	for node: Node in arc_to:
		if is_instance_valid(node) and not bool(node.call("is_dead")):
			_line_visual(at + Vector3.UP, (node as Node3D).global_position + Vector3.UP, Color(0.85, 0.78, 1.0))
			deal_damage(node, float(live.get("arc_damage", 60.0)), ["overload", "arc", "lightning"])
	if affinities.has("lightning"):
		reflux_by["lightning"] = maxf(0.0, reflux_of("lightning") - float(live.get("grounds", 0.0)))


# --- skill behaviours (design/05 Appendix A) ---------------------------------------------------

## melee_burst: everything in the arc takes the payload at once, shoved straight away from you.
func _burst(ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var reach: float = melee_range + float(ab.get("reach_bonus", 0.0))
	var half: float = deg_to_rad(float(ab["arc_deg"]) * 0.5) if ab.has("arc_deg") else melee_arc
	_strike_t = 0.25
	_swing_visual(reach, true, false)
	var payload: Dictionary = _payload(ab, "on_hit")
	for t: Node3D in _in_arc(reach, half):
		apply_hit(t, payload, tags, stage_mult)
	if bool(ab.get("shatters_stone", false)):
		for s: Variant in stones.duplicate():
			if is_instance_valid(s) and _stone_in_arc(s as Stone, reach, half):
				(s as Stone).shatter(_facing, self)


## True if the next `step` metres along `dir` would run into an enemy.
func _body_ahead(dir: Vector3, step: float) -> bool:
	if not is_inside_tree():
		return false
	var a := Vector2(global_position.x, global_position.z)
	var b: Vector2 = a + Vector2(dir.x, dir.z) * step
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Node3D
		if e == null or bool(e.call("is_dead")):
			continue
		var p := Vector2(e.global_position.x, e.global_position.z)
		# only bodies in front count - one you are already past or beside does not stop you
		if (p - a).dot(Vector2(dir.x, dir.z)) > 0.0 and Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= 0.4 + float(e.get("radius")):
			return true
	return false


## A dash is over: leave its trail on the ground, if it has one.
func _end_dash() -> void:
	if _dash_trail.is_empty() or not is_inside_tree():
		return
	var zone := GroundZone.new()
	zone.from = _dash_start
	zone.to = global_position
	zone.width = float(_dash_trail.get("width", 1.0))
	zone.life = float(_dash_trail.get("life", 3.0))
	zone.tick_s = float(_dash_trail.get("tick_s", 1.0))
	zone.payload = _dash_trail.get("payload", {})
	zone.tags = _dash_tags + ["zone"]
	zone.caster = self
	zone.color = _dash_color
	get_parent().add_child(zone)
	_dash_trail = {}


## dash: touch each enemy the dash passes, once. The whole stretch covered since the last check
## counts, not just where you ended up - a long step must not jump clean over someone.
func _dash_touch() -> void:
	if _dash_pass.is_empty() or not is_inside_tree():
		return
	var from := Vector2(_dash_from.x, _dash_from.z)
	var to := Vector2(global_position.x, global_position.z)
	_dash_from = global_position
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Node3D
		if e == null or _dash_passed.has(e):
			continue
		var at := Vector2(e.global_position.x, e.global_position.z)
		if Geometry2D.get_closest_point_to_segment(at, from, to).distance_to(at) <= _dash_pass_radius + float(e.get("radius")):
			_dash_passed.append(e)
			apply_hit(e, _dash_pass, _dash_tags)


## beam: an instant line along the facing. Walls and blocks stop it; it lands on the first enemy.
func _fire_beam(ab: Dictionary, stage_mult: float, color: Color, tags: Array) -> void:
	var origin: Vector3 = global_position + Vector3.UP * 0.9
	var reach: float = float(ab.get("range", 9.0))
	var wall: Dictionary = _ray(origin, origin + _facing * reach)
	if not wall.is_empty():
		reach = origin.distance_to(wall["position"])
	var best: Node3D = null
	var best_along := INF
	for node: Node in get_tree().get_nodes_in_group("hittable"):
		var t := node as Node3D
		if t == null or bool(t.get("is_scenery")):
			continue
		var to: Vector3 = t.global_position - global_position
		to.y = 0.0
		var along: float = to.dot(_facing)
		var r: float = float(t.get("radius"))
		if along < 0.0 or along > reach + r:
			continue
		if (to - _facing * along).length() <= float(ab.get("width", 0.6)) * 0.5 + r and along < best_along:
			best = t
			best_along = along
	_strike_t = 0.2
	_line_visual(origin, origin + _facing * (minf(reach, best_along) if best != null else reach), color)
	if best != null:
		apply_hit(best, _payload(ab, "on_hit"), tags, stage_mult, _facing)


## The enemy a single-target skill would land on, if it is within `reach`: the one under the
## cursor if you are pointing at one - and only that one, never a nearer bystander - else the one
## you are fighting, else the nearest.
func _skill_target(reach: float) -> Node3D:
	var pick: Node3D = null
	for c: Variant in [hovered, attack_target, _nearest_enemy()]:
		if c != null and is_instance_valid(c) and (c as Node).is_in_group("enemies") and not bool((c as Node).call("is_dead")):
			pick = c
			break
	if pick == null:
		return null
	var to: Vector3 = pick.global_position - global_position
	to.y = 0.0
	return pick if to.length() <= reach + float(pick.get("radius")) else null


## Where a blink would land: toward the cursor, at most `reach` away. Null if that spot is off
## the floor, inside a wall or block, or has one in the way.
func _blink_point(reach: float) -> Variant:
	var want: Vector3 = _cursor_ground() - global_position
	want.y = 0.0
	if want.length() < 0.5:
		want = _facing * reach                    # no cursor to speak of (bot, headless): straight ahead
	if want.length() > reach:
		want = want.normalized() * reach
	var spot: Vector3 = global_position + want
	var floor_hit: Dictionary = _ray(spot + Vector3.UP * 4.0, spot + Vector3.DOWN * 2.0)
	if floor_hit.is_empty() or (floor_hit["position"] as Vector3).y > global_position.y + 0.5:
		return null
	if not _ray(global_position + Vector3.UP, spot + Vector3.UP).is_empty():
		return null
	return spot


## blink: you are simply there. Everything beside where you land takes the arrival payload.
func _blink(spot: Vector3, ab: Dictionary, stage_mult: float, color: Color, tags: Array) -> void:
	var from: Vector3 = global_position
	_line_visual(from + Vector3.UP, spot + Vector3.UP, color)
	var step: Vector3 = spot - from
	step.y = 0.0
	if step.length() > 0.2:
		_facing = step.normalized()
	global_position = Vector3(spot.x, from.y, spot.z)
	velocity = Vector3.ZERO
	has_move_goal = false
	var payload: Dictionary = ab.get("on_arrive", {})
	if payload.is_empty():
		return
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Node3D
		if e == null:
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		if to.length() <= float(ab.get("arrive_radius", 1.5)) + float(e.get("radius")):
			apply_hit(e, payload, tags, stage_mult)


## First thing in the world (walls, blocks, floor - not bodies) between two points, or {}.
func _ray(from: Vector3, to: Vector3) -> Dictionary:
	if not is_inside_tree():
		return {}
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(q)


## A bright line that fades: beams, arcs and the trail of a blink.
func _line_visual(from: Vector3, to: Vector3, color: Color) -> void:
	if not is_inside_tree() or from.distance_to(to) < 0.05:
		return
	var line := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.12, from.distance_to(to))
	line.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color, 0.9)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line.material_override = mat
	get_parent().add_child(line)
	line.global_position = (from + to) * 0.5
	line.look_at(to, Vector3.UP if absf((to - from).normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT)
	var tween: Tween = line.create_tween()
	tween.tween_property(line, "scale", Vector3(0.1, 0.1, 1.0), 0.14)
	tween.tween_callback(line.queue_free)


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
		var arm_wound: Dictionary = GameData.balance["wounds"]["lost_arm"]
		body.remove_wound("lost_arm")
		body.add_wound("lost_arm", str(arm_wound["name"]), float(_arm["regrow_heal_points"]), float(arm_wound["cut"]), false)
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
	if _recover_t > 0.0 or _stagger_t > 0.0:
		return                                   # still finishing the last one, or off your feet
	var heat: float = reflux_of(aff)
	var cost: float = float(ab["cost"]) * (float(_reflux_cfg["pain_cost_mult"]) if heat >= float(_reflux_cfg["pain_at"]) else 1.0)
	# Winded: the dash is not free. A second movement skill too soon costs double, in essence and heat.
	var movement: bool = str(ab["kind"]) == "dash" or str(ab["kind"]) == "blink"
	var winded: bool = movement and _winded_t > 0.0
	if winded:
		cost *= GameData.num("combat", "winded_cost_mult")
	if essence < cost:
		note("Not enough essence for %s." % str(ab["name"]))
		return
	# Some skills need something to point at; find out before anything is spent.
	var kind: String = str(ab["kind"])
	var strike_target: Node3D = null
	var blink_to := Vector3.ZERO
	if kind == "targeted_strike":
		strike_target = _skill_target(float(ab["range"]) if ab.has("range") else reach_now() + float(ab.get("range_bonus", 0.0)))
		if strike_target == null:
			note("%s needs someone within reach." % str(ab["name"]))
			return
	elif kind == "blink":
		var spot: Variant = _blink_point(float(ab.get("range", 6.0)))
		if spot == null:
			note("There is no way through to there.")
			return
		blink_to = spot
	elif kind == "prop":
		var where: Variant = _prop_point(ab)
		if where == null:
			note("There is no room to raise stone there.")
			return
		blink_to = where
	essence -= cost
	reflux_by[aff] = heat + cost * float(ab["reflux_per_cost"])
	_advance(state, cost)
	if movement:
		if winded:
			_float("winded", Color(0.8, 0.8, 0.9))
		_winded_t = GameData.num("combat", "winded_s")

	var stage_mult: float = ability_damage_mult(int(state["stage"])) * float(ab.get("damage_all", 1.0))
	var tags: Array = ["ability", aff, str(state["id"])]
	var windup: float = float(ab.get("windup", 0.0))
	if kind == "prop":
		var to_spot: Vector3 = blink_to - global_position
		to_spot.y = 0.0
		if to_spot.length() > 0.2:
			_facing = to_spot.normalized()
	# Stone starts rising at once; everything else with a wind-up goes off when it ends.
	if windup <= 0.0 or kind == "prop":
		_perform_cast(ab, kind, aff, stage_mult, tags, strike_target, blink_to)
	if windup > 0.0:
		_windup_t = windup
		_windup_total = windup
		_windup = {"ab": ab, "kind": kind, "aff": aff, "stage_mult": stage_mult, "tags": tags, "target": strike_target, "point": blink_to,
			"facing": _facing, "braced": bool(ab.get("braced", false)), "release": kind != "prop"}
		has_move_goal = false
		attack_target = null
		pickup_target = null
		if bool(ab.get("braced", false)):
			_float("braced", GameData.affinity_color(aff).lightened(0.3))

	# A skill takes a moment to finish; running hot makes that moment longer (it no longer hurts).
	var recovery: float = float(ab.get("recovery", GameData.num("abilities", "cast_recovery")))
	if heat >= float(_reflux_cfg["burn_at"]):
		recovery = recovery * float(_reflux_cfg["burn_recovery_mult"]) + float(_reflux_cfg["burn_recovery_add"])
		_float("seizing", Color(1, 0.5, 0.2))
	if movement:
		# the recovery starts when the movement ends, so the dash itself is not eaten by it
		recovery = maxf(recovery, float(ab.get("dash_time", 0.0)) + (0.0 if bool(ab.get("no_recovery", false)) else GameData.num("combat", "dash_recovery_s")))
	_recover_t = windup + recovery
	_melee_cd = maxf(_melee_cd, windup + recovery)

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


## What a skill does when it goes off: at once, or when its wind-up ends (see _tick_windup).
## `blink_to` is the point the skill was aimed at, for the kinds that have one.
func _perform_cast(ab: Dictionary, kind: String, aff: String, stage_mult: float, tags: Array, strike_target: Node3D, blink_to: Vector3) -> void:
	if kind == "targeted_strike" and strike_target == null:
		return                                   # whoever it was meant for is gone
	match kind:
		"projectile":
			_fire_projectile(ab, stage_mult, GameData.affinity_color(aff), tags + ["projectile"])
		"melee_burst":
			if float(ab.get("self_harm", 0.0)) > 0.0:     # only a build that earns it; no ability has it by default
				var hurt: float = body.apply_self_harm(float(ab["self_harm"]))
				_float("-%d" % int(hurt), Color(1, 0.4, 0.3))
			_burst(ab, stage_mult, tags + ["melee"])
			_melee_cd = float(_p["melee_cooldown"]) * float(_p["overcharge_cooldown_factor"])
		"dash":
			var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
			var dir := Vector3(input.x, 0.0, input.y).normalized().rotated(Vector3.UP, ISO_YAW)
			if dir == Vector3.ZERO:
				dir = _facing
			_dash_vel = dir * float(ab["dash_speed"])
			_dash_time = float(ab["dash_time"])
			_dash_pass = ab.get("on_pass", {})
			_dash_pass_radius = float(ab.get("pass_radius", 1.0))
			_dash_tags = tags
			_dash_passed.clear()
			_dash_from = global_position
			_dash_start = global_position
			_dash_trail = ab.get("trail", {})
			_dash_stops = bool(ab.get("stops_at_bodies", false))
			_dash_color = GameData.affinity_color(aff)
			if has_slipstream():
				pips = mini(GameData.inum("slipstream", "max"), pips + int(ab.get("gain_pips", 0)))
		"beam":
			_fire_beam(ab, stage_mult, GameData.affinity_color(aff), tags)
		"targeted_strike":
			var to_t: Vector3 = strike_target.global_position - global_position
			to_t.y = 0.0
			if to_t.length() > 0.2:
				_facing = to_t.normalized()
			_strike_t = 0.25
			_swing_visual(to_t.length() + 0.4, true, true)
			var strike_payload: Dictionary = _payload(ab, "on_hit")
			var strike_tags: Array = tags + ["melee"]
			if bool(ab.get("force_rear", false)):
				strike_tags.append("rear")              # it lands on the back whichever way they were facing
			if ab.has("pip_mult"):
				var burned: int = spend_pips(-1 if bool(ab.get("spend_all_pips", false)) else int(ab.get("spend_pips", 0)))
				strike_payload["damage_mult"] = float(strike_payload.get("damage_mult", 1.0)) * (1.0 + float(ab["pip_mult"]) * float(burned))
			if bool(ab.get("through", false)):
				# cut through: you end up behind them, unless something solid is there
				var beyond: Vector3 = strike_target.global_position + _facing * (float(ab.get("through_dist", 2.0)) + float(strike_target.get("radius")))
				beyond.y = global_position.y
				var blocked: Dictionary = _ray(global_position + Vector3.UP, beyond + Vector3.UP)
				_line_visual(global_position + Vector3.UP, (blocked["position"] if not blocked.is_empty() else beyond + Vector3.UP), GameData.affinity_color(aff))
				if blocked.is_empty():
					global_position = beyond
				has_move_goal = false
				attack_target = null
			var spent: int = 0
			if ab.has("consume_status") and strike_target.has_method("status_stacks"):
				# cash in what is already on the target: each stack spent adds to the blow, and it bursts
				spent = int(strike_target.call("status_stacks", str(ab["consume_status"])))
				if spent > 0:
					strike_target.call("clear_status", str(ab["consume_status"]))
					deal_damage(strike_target, float(ab.get("per_stack_damage", 0.0)) * float(spent) * stage_mult, tags + ["melee", "burst"])
			if is_instance_valid(strike_target) and not bool(strike_target.call("is_dead")):
				apply_hit(strike_target, strike_payload, strike_tags, stage_mult)
			if spent > 0 and ab.has("burst"):
				var centre: Vector3 = strike_target.global_position if is_instance_valid(strike_target) else global_position + _facing * 1.5
				for node: Node in get_tree().get_nodes_in_group("enemies"):
					var near := node as Node3D
					if near != null and near != strike_target and near.global_position.distance_to(centre) <= float(ab.get("burst_radius", 2.0)) + float(near.get("radius")):
						apply_hit(near, ab["burst"], tags + ["burst"], stage_mult)
			_melee_cd = float(_p["melee_cooldown"])
		"blink":
			_blink(blink_to, ab, stage_mult, GameData.affinity_color(aff), tags)
		"prop":
			raise_stone(blink_to, _facing, ab, stage_mult, tags)


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
	var ab: Dictionary = GameData.ability(str(state["id"])).duplicate(true)      # deep: payloads are changed below
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
			for part: String in ["on_hit", "on_pass", "on_arrive", "on_rise"]:
				if ab.has(part) and (ab[part] as Dictionary).has(key):
					(ab[part] as Dictionary)[key] = float((ab[part] as Dictionary)[key]) * float(mods[key])
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
	if now.has("range"):
		_preview_row(out, "Range", float(now["range"]), float(then["range"]), "%.1f m", true)
	for part: String in ["on_hit", "on_pass", "on_arrive", "on_rise"]:
		if now.has(part) and (now[part] as Dictionary).has("shove"):
			_preview_row(out, "Shove", float((now[part] as Dictionary)["shove"]), float((then[part] as Dictionary)["shove"]), "%.1f m", true)
	if str(now.get("kind", "")) == "prop":
		_preview_row(out, "Stone stands for", float(now["life"]), float(then["life"]), "%d s", true)
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
		var burn_wound: Dictionary = GameData.balance["wounds"]["bind_fail"]
		_wound_seq += 1
		take_wound("bind_%d" % _wound_seq, str(burn_wound["name"]), float(burn_wound["sink"]), float(burn_wound["cut"]))
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
		"body": body.to_dict(),
		"arm_right": arm_right, "arm_right_lost": arm_right_lost,
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
	# older saves kept three wound layers; their totals become the bar
	body.from_dict(d.get("body", {}), d.get("body_hp", {}), d.get("body_max", {}))
	arm_right = float(d.get("arm_right", arm_right))
	arm_right_lost = bool(d.get("arm_right_lost", false))
	if arm_right_lost and not body.has_wound("lost_arm"):
		var arm_wound: Dictionary = GameData.balance["wounds"]["lost_arm"]
		body.add_wound("lost_arm", str(arm_wound["name"]), maxf(1.0, float(_arm["regrow_heal_points"]) - float(d.get("arm_regrow", 0.0))), float(arm_wound["cut"]), false)
	_wound_seq = body.wounds.size()
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


func _fire_projectile(ab: Dictionary, stage_mult: float, color: Color, tags: Array = ["projectile"]) -> void:
	var bolt: Node3D = Projectile.new()
	bolt.set("color", color)
	bolt.set("tags", tags)
	var payload: Dictionary = _payload(ab, "on_hit")
	if ab.has("spend_pips") and payload.has("damage"):
		payload["damage"] = float(payload["damage"]) + float(ab.get("pip_damage", 0.0)) * float(spend_pips(int(ab["spend_pips"])))
	if payload.has("damage"):
		payload["damage"] = float(payload["damage"]) * stage_mult        # carried on the bolt, already scaled
	if ab.has("on_hit"):
		bolt.set("payload", payload)
	bolt.set("pierce", bool(ab.get("pierce", false)))
	bolt.set("shatters_stone", bool(ab.get("shatters_stone", false)))
	bolt.set("dir", _facing)
	bolt.set("damage", float(ab["damage"]) * stage_mult)
	bolt.set("speed", float(ab["speed"]))
	bolt.set("life", float(ab["life"]))
	bolt.set("shooter", self)
	get_parent().add_child(bolt)
	bolt.global_position = _muzzle()


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
	var w: Dictionary = _healer_wound()
	if not w.is_empty():
		var work: float = minf(float(_heal_cfg["sink_per_visit"]), float(w["sink"]))
		return {"desc": "Work on your %s (%s). Slow, careful, and not cheap." % [str(w["name"]).to_lower(), Body.wound_state(w)],
			"cost": int(ceil(work * float(_heal_cfg["price_per_sink_point"])))}
	var gap: float = body.missing()
	if gap > 0.5:
		var amount: float = minf(float(_heal_cfg["health_per_visit"]), gap)
		return {"desc": "Patch you up: %d health now. A night's rest does it for the price of a bed." % int(ceil(amount)),
			"cost": int(ceil(amount * float(_heal_cfg["price_per_health_point"])))}
	return {"desc": "Nothing to mend. You are whole.", "cost": 0}


## The wound the healer would work on next: the oldest that is not a lost limb.
func _healer_wound() -> Dictionary:
	for w: Dictionary in body.wounds:
		if str(w["id"]) != "lost_arm":
			return w
	return {}


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
		body.remove_wound("lost_arm")
		note("Healer: -$%d, arm regrown." % price)
		return
	var next: Dictionary = next_healing()
	var cost: int = int(next["cost"])
	if cost <= 0:
		note("Healer: nothing to mend.")
		return
	if not _can_afford(cost):
		note("Healer: that is $%d. You have $%d and no more credit." % [cost, money])
		return
	money -= cost
	var w: Dictionary = _healer_wound()
	if not w.is_empty():
		var wound_name: String = str(w["name"])
		var work: float = minf(float(_heal_cfg["sink_per_visit"]), float(w["sink"]))
		w["sink"] = float(w["sink"]) - work
		if float(w["sink"]) <= 0.0001:
			body.remove_wound(str(w["id"]))
			note("Healer: -$%d. Your %s is closed." % [cost, wound_name.to_lower()])
		else:
			note("Healer: -$%d of work on your %s. It is %s." % [cost, wound_name.to_lower(), Body.wound_state(w)])
		return
	var healed: float = body.heal(float(_heal_cfg["health_per_visit"]))
	note("Healer: -$%d, patched up %d health." % [cost, int(round(healed))])


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
	body.hp = maxf(body.hp, body.total_max() * float(town["revive_health_frac"]))
	_build_model()
	note("You wake on a cot. Someone dragged you out. The bill is $%d." % fee)


## A night in town: the body does what bodies do. Rent for the night is charged by the caller.
func rest_night() -> void:
	var night: Dictionary = GameData.balance["night"]
	var mended: Dictionary = body.fill_sinks(float(night["sink_healed"]), true)      # never a lost limb
	_wounds_closed(mended["closed"])
	body.heal(body.total_max())
	if not arm_right_lost:
		arm_right = minf(float(_arm["max"]), arm_right + float(night["arm_restored"]))
	clear_reflux()
	essence = essence_max
	note("You sleep. The body refills; wounds knit a little. What is gone stays gone.")


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
	if cursor_fixed != null:
		return cursor_fixed
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
