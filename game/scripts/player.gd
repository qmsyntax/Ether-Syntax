extends CharacterBody3D
## Player archhuman: three-layer body, essence tank + satellite, reflux heat, hidden latent aura.
## Talents (and later items, summons, techniques) are TalentEffect objects hooked into the damage
## pipeline: deal_damage() and take_hit() build a HitContext and run it through every effect.
## Tuning numbers come from GameData (game/data/balance.json).

signal died
## The body was hurt while the soul was out of it.
signal disturbed
## A rune became known (design/14 section 8): its id and where it was found.
signal rune_discovered(rune_id: String, source: String)

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
## Runes this character has discovered (Brent 2026-10-23): permanent knowledge, usable in any seal.
## A test character knows every rune (knows_rune) whatever is listed here.
var known_runes: Array[String] = []
## Rune stones already read, by id: each reveals its rune once.
var read_inscriptions: Array[String] = []
## The last rune discovered, {id, source}, for the HUD's card.
var last_rune: Dictionary = {}
## The seal being drafted while the seal screen is open (not saved): {index, word, construct, mode}
## - mode "bind" (a construct is being bound and the next ring formed) or "test" (a test
## character's free edit).
var seal_draft: Dictionary = {}
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
## Unspent skill points (design/08): earned by star growth and ascension, spent at a trainer.
var skill_points := 0
## Star growth (percentage points) banked toward the next skill point.
var skill_growth := 0.0
## Crafting (design/12, rules in scripts/crafting.gd): skill per craft 0-300, recipes learned,
## recipes made at least once (the first success always teaches), uses left on the tool in use.
var craft_skill: Dictionary = {}
var craft_known: Array = []
var craft_made: Array = []
var tool_uses: Dictionary = {}
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
var _bot_path := NavPath.new()

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
## Skills that sit on you for a while: buff id -> {"t": seconds left, ...its own numbers}.
var buffs: Dictionary = {}
## Bodies you died in and have not recovered: {id, where, chamber, pos, equipped, bag}.
var corpses: Array = []
var _corpse_seq := 0
## What you have seen of each overland zone: zone id -> FogMap.to_text().
var explored: Dictionary = {}
var rod: Node3D                      # the one Ground Rod standing, if any
var _bare_strikes := 0               # counted for skills that pay on every other strike
var _dash_braced := false
var _dash_on_stop: Dictionary = {}
var _dash_heavy_poise := 0.0
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
## Blood's held blood (2026-10-22): measures carried outside your own veins, 0..held_blood_max.
## Filled by drinking, spent by blood skills. It is never health and never heals.
var held_blood := 0
var _blood_thin_t := 0.0
## What a skill fills and another spends: "swallowed" (Dark's swallowed light) -> {"n": int, "t": s}.
var stores: Dictionary = {}
## A held skill under way (channel or charge_release): see _start_held / _tick_held.
var _held: Dictionary = {}
## Braced through a skill's cast and recovery (a braced skill with no wind-up, or a braced word).
var _brace_t := 0.0
## Your next hit counts as from behind until this runs out (Shadow Slip).
var _rear_window_t := 0.0
## Striking or casting shows you for a moment even where you would be unseen.
var _unseen_reveal_t := 0.0
## A dash's arrival (Burrow, a grapple) and what it leaves (a phantom, a cloud, a patch).
var _dash_on_arrive: Dictionary = {}
var _dash_arrive_radius := 1.5
var _dash_pass_armoured := false
var _dash_ab: Dictionary = {}
var _dash_stage_mult := 1.0
## The hotbar action a skill was cast from while it is still held down (a held skill reads it).
var _cast_action := ""
## A test character (the title screen's "Test characters"): every skill of one affinity, stages
## high enough for big rune words. Never saved over the real save; marked in a save as such.
var test_character := false
## Test characters only: which six of the learned skills the bar shows (next page).
var hotbar_page := 0

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
	skill_points = int((GameData.skill_tree.get("points", {}) as Dictionary).get("start", 0))


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
	if _rig.has_method("set_activity"):
		_rig.call("set_activity", "meditate" if (meditating or _sitting) else "")
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
	known_runes.clear()
	read_inscriptions.clear()
	seal_draft = {}
	_grant_start_runes()


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
	buffs.clear()
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
			# wind: its heat blows off while you run and sits while you stand (unless you stand in Dead Air)
			rate = float(a_def["reflux_shed_mult_moving"]) if (_moving or _zone_flag("shed_standing")) else float(a_def.get("reflux_shed_mult_standing", 1.0))
		rate *= float(a_def.get("reflux_shed_mult", 1.0))       # earth keeps what little it makes
		rate *= buff_num("shed_mult")                            # Long Breath
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
	_brace_t -= delta
	_rear_window_t -= delta
	_unseen_reveal_t -= delta
	_tick_buffs(delta)
	_tick_stores(delta)
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
		_bot_think(delta)
	else:
		_update_aim()
	if _windup_t > 0.0:
		_tick_windup(delta)
	if not _held.is_empty():
		_tick_held(delta)

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
	if not in_combat and not _heal_blocked():
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
			if bot and _bot_dir != Vector3.ZERO:
				dir = _bot_dir                     # a person steers round things by hand; the bot follows its path
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
	var speed: float = float(_p["move_speed"]) * temper_stat("move_speed_mult") * (float(_p["charge_move_factor"]) if _charging else 1.0) * buff_num("move_speed_mult") * _zone_num("caster_speed_mult")
	if not _held.is_empty():
		speed *= float((_held["ab"] as Dictionary).get("move_factor", 1.0))     # holding a skill: you walk slowly, or not at all
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
		var met: Node3D = _body_ahead(_dash_vel.normalized(), step.length()) if _dash_stops else null
		if met != null:
			_dash_time = 0.0                     # this one does not go through people
			_dash_met(met)
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
			if per > 0.0 and not ctx.has_tag("cold"):       # a skill that spends the heat does not also ride it
				ctx.mult *= heat_mult(aff)
	_affinity_rules(ctx, target)
	if ctx.cancelled:
		return ctx
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
	ctx.applied = target.call("take_hit", ctx.amount(), ctx.heavy, self, Array(ctx.tags))
	if not ctx.has_tag("dot"):
		_after_landing(ctx, target)
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
			target.call("take_poise", float(combat["strike_poise"]) * (2.0 if ctx.has_tag("overcharge") else 1.0) * buff_num("strike_poise_mult"))
		if not ctx.killed and target.has_method("add_status"):
			for bid: String in buffs:
				if str((buffs[bid] as Dictionary).get("strike_status", "")) != "":
					target.call("add_status", str(buffs[bid]["strike_status"]), 1, self)      # Stoke: your hands are lit
			_try_shatter(target, INF)                                  # a bare strike is a hard hit
			if buffs.has("static_coat"):
				_bare_strikes += 1
				if _bare_strikes % int((buffs["static_coat"] as Dictionary).get("strikes_per_mark", 2)) == 0:
					_add_marks(target, 1, true)

	for e: TalentEffect in effects:
		e.on_dealt(ctx)
	if ctx.killed:
		_on_kill(target)
	return ctx


## Receive a hit. Effects may scale it or swallow it (ctx.cancelled).
func take_hit(amount: float, heavy: bool, source: Node, _tags: Array = []) -> float:
	if dead or bot:
		return 0.0
	var ctx := HitContext.new()
	ctx.source = source
	ctx.target = self
	# What the body and what it wears take off the blow comes first, so every talent works on
	# the same reduced number - including one that swallows the hit and delivers it later.
	ctx.base = amount * temper_stat("incoming_mult") * (1.0 - armour() / 100.0) * buff_num("incoming_mult") * _inured_mult()
	var braced: bool = is_braced()
	if braced:
		ctx.base *= GameData.num("braced", "damage_taken_mult")
	# a blow thrown from arm's length, as against a shot that left its owner far behind
	var melee_from: Node3D = source as Node3D if (source is Node3D and (source as Node).is_in_group("enemies") and (source as Node3D).global_position.distance_to(global_position) <= 4.5) else null
	if melee_from != null and buffs.has("backwash"):
		var wash: Dictionary = buffs["backwash"]
		ctx.base *= float(wash.get("melee_taken_mult", 0.5))
		# the splash: whoever threw the blow, and everyone close to you, takes the payload
		var splash: Dictionary = wash.get("on_hit", {"shove": float(wash.get("shove", 3.0)), "status": "soaked"})
		var wet: Array[Node3D] = _enemies_near(global_position, float(wash.get("radius", 0.0)))
		if not wet.has(melee_from):
			wet.append(melee_from)
		for e: Node3D in wet:
			apply_hit(e, splash, ["ability", "water", "backwash"], 1.0, e.global_position - global_position)
		wash["hits"] = int(wash.get("hits", 1)) - 1
		if int(wash["hits"]) <= 0:
			buffs.erase("backwash")
	if melee_from != null:
		for bid: String in buffs.keys():
			var b: Dictionary = buffs[bid]
			if str(b.get("attacker_status", "")) != "" and is_instance_valid(melee_from):
				melee_from.call("add_status", str(b["attacker_status"]), 1, self, {"lasts": float(b.get("attacker_status_s", 3.0))})
	if melee_from != null and buffs.has("static_coat"):
		deal_damage(melee_from, float((buffs["static_coat"] as Dictionary).get("retaliate", 25.0)), ["ability", "lightning", "static_coat"])
		if is_instance_valid(melee_from) and not bool(melee_from.call("is_dead")):
			_add_marks(melee_from, 1, true)
	ctx.heavy = heavy
	if projecting:
		disturbed.emit()             # pain drags the soul back before the blow is even counted
	_meditate_block = 1.0
	meditating = false
	if not _held.is_empty() and bool((_held["ab"] as Dictionary).get("breaks_on_hit", false)):
		_end_held()
	for e: TalentEffect in effects:
		e.on_incoming(ctx)
	if ctx.cancelled:
		return 0.0
	# a shell of ice takes the blow first; when it is used up it bursts
	for bid: String in buffs.keys():
		var shell: Dictionary = buffs[bid]
		if float(shell.get("absorb", 0.0)) <= 0.0:
			continue
		var took: float = minf(float(shell["absorb"]), ctx.amount())
		shell["absorb"] = float(shell["absorb"]) - took
		ctx.base = maxf(0.0, ctx.base - took / maxf(ctx.mult, 0.0001))
		if float(shell["absorb"]) <= 0.0:
			buffs.erase(bid)
			_burst_at(global_position, shell.get("on_break", {}), ["ability", str(shell.get("affinity", "")), "shell"])
		if ctx.amount() <= 0.0:
			return 0.0
	if heavy and not braced:                 # set for an earth skill: nothing knocks you off it
		var combat: Dictionary = GameData.balance["combat"]
		poise -= float(combat["heavy_poise_damage"]) * buff_num("poise_loss_mult") / maxf(0.01, buff_num("poise_mult"))
		if poise <= 0.0:
			poise = float(combat["player_poise"])
			_stagger_t = float(combat["player_stagger_s"])
			_dash_time = 0.0
			_windup = {}                          # whatever you were winding up is lost
			_windup_t = 0.0
			_float("STAGGERED", Color(1, 0.7, 0.3))
	return _apply_damage(ctx.amount(), heavy)


# --- zones, buffs, the rod (design/05 step 5b) -------------------------------------------------

## A number from whichever buffs are on you, multiplied together (1 if none carries it).
func buff_num(key: String) -> float:
	var out := 1.0
	for id: String in buffs:
		out *= float((buffs[id] as Dictionary).get(key, 1.0))
	return out


func _tick_buffs(delta: float) -> void:
	for id: String in buffs.keys():
		var b: Dictionary = buffs[id]
		b["t"] = float(b["t"]) - delta
		# Knit: health a second, up to the ceiling your wounds allow; then a trickle into the oldest wound
		if float(b.get("heal_per_s", 0.0)) > 0.0 and not _heal_blocked():
			var pts: float = float(b["heal_per_s"]) * delta
			var used: float = body.heal(pts)
			if pts - used > 0.0:
				var filled: Dictionary = body.fill_sinks((pts - used) * float(b.get("overflow_to_sink", 0.0)))
				_wounds_closed(filled["closed"])
		if float(b["t"]) <= 0.0:
			buffs.erase(id)


## self_buff: the skill's own numbers ride on you for its duration. Some do something at once too:
## breathe out held blood (Long Breath), light every enemy near you (Clear Eye), shake off what
## holds you (Fever Break).
func _take_buff(ab: Dictionary) -> void:
	var b: Dictionary = ab.duplicate(true)
	b["t"] = float(ab.get("duration", 5.0))
	buffs[str(ab.get("buff", ab.get("name", "buff")))] = b
	if float(ab.get("add_reflux", 0.0)) > 0.0:
		var aff: String = str(ab.get("affinity", ""))
		reflux_by[aff] = reflux_of(aff) + float(ab["add_reflux"])
	if ab.has("spend_blood") and float(ab.get("shed_per_blood", 0.0)) > 0.0:
		var spent: int = spend_blood(int(ab["spend_blood"]))
		_vent_hottest(float(ab["shed_per_blood"]) * float(spent))
		poise = float(GameData.num("combat", "player_poise"))
	if float(ab.get("reveal_radius", 0.0)) > 0.0:
		for e: Node3D in _enemies_near(global_position, float(ab["reveal_radius"])):
			e.call("add_status", "lit", 1, self)
	if bool(ab.get("cleanse", false)):
		_stagger_t = 0.0
		_winded_t = 0.0
		_shoved_left = 0.0
	_bare_strikes = 0
	_float(str(ab.get("name", "")).to_lower(), GameData.affinity_color(str(ab.get("affinity", ""))).lightened(0.3))


## True while enemy shots turn aside from you.
func deflects_shots() -> bool:
	return buffs.has("veil")


## A number from the zones of your own you are standing in (1 if none).
func _zone_num(key: String) -> float:
	var out := 1.0
	if not is_inside_tree():
		return out
	for zone: Node in get_tree().get_nodes_in_group("ground_zones"):
		if zone.get("caster") == self and float(zone.get(key)) != 1.0 and bool(zone.call("has_point", global_position)):
			out *= float(zone.get(key))
	return out


## ground_zone: a pool at the aimed point, or a lane from your feet along your aim. A zone may last
## longer for your heat (life_per_heat) or for the pips you spend; drift; hold the dark; block sight.
func _lay_zone(point: Vector3, ab: Dictionary, stage_mult: float, tags: Array) -> Node3D:
	var cfg: Dictionary = ab.get("zone", {})
	var zone := GroundZone.new()
	zone.shape = str(cfg.get("shape", "circle"))
	zone.radius = float(cfg.get("radius", 3.0))
	zone.width = float(cfg.get("width", 2.0))
	zone.life = float(cfg.get("life", 6.0))
	zone.tick_s = float(cfg.get("tick_s", 1.0))
	if cfg.has("life_per_heat"):
		zone.life = minf(float(cfg.get("life_max", 99.0)), zone.life + float(cfg["life_per_heat"]) * reflux_of(str(ab.get("affinity", ""))))
	if float(ab.get("pip_seconds", 0.0)) > 0.0 and has_slipstream():
		var burned: int = spend_pips(-1 if bool(ab.get("spend_all_pips", false)) else int(ab.get("spend_pips", 0)))
		zone.life += float(ab["pip_seconds"]) * float(burned)
	var payload: Dictionary = (cfg.get("payload", {}) as Dictionary).duplicate()
	if payload.has("damage"):
		payload["damage"] = float(payload["damage"]) * stage_mult
	zone.payload = payload
	zone.on_enter = cfg.get("on_enter", {})
	zone.pull_per_s = float(cfg.get("pull_per_s", 0.0))
	zone.kind = str(cfg.get("kind", "dark_ground" if bool(cfg.get("dark", false)) else ""))
	zone.dark = bool(cfg.get("dark", false))
	zone.dark_extra_ticks = int(cfg.get("dark_extra_ticks", 0))
	zone.blocks_sight = bool(cfg.get("blocks_sight", false))
	zone.hides = bool(cfg.get("hides", false))
	zone.banks = str(cfg.get("banks", ""))
	zone.no_heal = bool(cfg.get("no_heal", false))
	zone.blocks_status = cfg.get("blocks_status", [])
	zone.ends_status = cfg.get("ends_status", [])
	zone.kill_projectiles = bool(cfg.get("kill_projectiles", false))
	zone.freeze_pips = bool(cfg.get("freeze_pips", false))
	zone.shed_standing = bool(cfg.get("shed_standing", false))
	zone.ends_if_left = bool(cfg.get("ends_if_left", false))
	zone.overrun_at = int(cfg.get("overrun_at", 0))
	if bool(zone.bright) and bool(cfg.get("bright", false)):
		zone.light_radius = zone.radius
	if float(cfg.get("drift_speed", 0.0)) > 0.0:
		var way: Vector3 = velocity if str(cfg.get("drift", "")) == "caster_motion" else (Vector3(point.x, 0, point.z) - Vector3(global_position.x, 0, global_position.z))
		way.y = 0.0
		if way.length() > 0.05:
			zone.drift_vel = way.normalized() * float(cfg["drift_speed"])
	# a status that sends them out of the zone needs to know where the zone is
	if payload.has("status") and str(GameData.status(str(payload["status"])).get("flees", "")) == "zone":
		var data: Dictionary = (payload.get("status_data", {}) as Dictionary).duplicate()
		data["from"] = Vector3(point.x, global_position.y, point.z)
		payload["status_data"] = data
	zone.extra_status = str(cfg.get("extra_status", ""))
	zone.shove_mult = float(cfg.get("shove_mult", 1.0))
	zone.push_per_s = float(cfg.get("push_per_s", 0.0))
	zone.caster_speed_mult = float(cfg.get("caster_speed_mult", 1.0))
	zone.pip_gain_mult = float(cfg.get("pip_gain_mult", 1.0))
	zone.bright = bool(cfg.get("bright", false))
	zone.tags = tags + ["zone"]
	zone.caster = self
	zone.color = GameData.affinity_color(str(ab.get("affinity", "")))
	if str(ab.get("at", "point")) == "feet":
		zone.from = global_position
		zone.to = global_position + _facing * float(cfg.get("length", 10.0))
	else:
		zone.from = Vector3(point.x, global_position.y, point.z)
		zone.to = zone.from
	get_parent().add_child(zone)
	_strike_t = 0.2
	return zone


## rod: the one Ground Rod. A new one replaces the old.
func _plant_rod(point: Vector3, ab: Dictionary) -> void:
	if is_instance_valid(rod):
		rod.queue_free()
	var r := GroundRod.new()
	r.life = float(ab.get("life", 10.0))
	r.set_meta("relay", ab)
	get_parent().add_child(r)
	r.global_position = Vector3(point.x, global_position.y, point.z)
	rod = r
	_strike_t = 0.2


## A lightning skill was cast near the rod: the rod answers with an arc of its own.
func _rod_relay(aff: String, stage_mult: float) -> void:
	if aff != "lightning" or not is_instance_valid(rod) or rod.is_queued_for_deletion():
		return
	var ab: Dictionary = rod.get_meta("relay", {})
	if rod.global_position.distance_to(global_position) > float(ab.get("relay_radius", 8.0)):
		return
	var pick: Node3D = null
	for e: Node3D in _enemies_near(rod.global_position, float(ab.get("relay_range", 5.0))):
		if pick == null or e.global_position.distance_to(rod.global_position) < pick.global_position.distance_to(rod.global_position):
			pick = e
	if pick == null:
		return
	_line_visual(rod.global_position + Vector3.UP * 2.0, pick.global_position + Vector3.UP, GameData.affinity_color("lightning"))
	apply_hit(pick, ab.get("relay_hit", {}), ["ability", "lightning", "ground_rod"], stage_mult)


## A dash that does not pass through people has met one: it is thrown, or - if it is heavy - it
## holds, and only loses its footing.
func _dash_met(e: Node3D) -> void:
	if _dash_on_stop.is_empty():
		return
	if float(e.get("shove_resist")) < 1.0 and _dash_heavy_poise > 0.0:
		e.call("take_poise", _dash_heavy_poise)
		return
	apply_hit(e, _dash_on_stop, _dash_tags, 1.0, _dash_vel.normalized())


# --- learning skills (design/05 step 5: scrolls) ----------------------------------------------

func knows(ability_id: String) -> bool:
	for st: Dictionary in abilities:
		if str(st["id"]) == ability_id:
			return true
	return false


## Why this character cannot learn that skill, or "" if they can.
func can_learn(ability_id: String) -> String:
	var ab: Dictionary = GameData.ability(ability_id)
	if ab.is_empty():
		return "That is not a skill."
	if knows(ability_id):
		return "You already know %s." % str(ab.get("name", ability_id))
	var aff: String = str(ab.get("affinity", ""))
	if not affinities.has(aff):
		return "You have no %s affinity: the words mean nothing to you." % str(GameData.affinity(aff).get("label", aff)).to_lower()
	return ""


## The skill is yours: it goes on the first empty key, or waits in the soul screen if the bar is full.
func learn(ability_id: String) -> bool:
	if can_learn(ability_id) != "":
		return false
	abilities.append({"id": ability_id, "stage": 0, "progress": 0.0})
	for i: int in hotbar.size():
		if hotbar[i] < 0:
			hotbar[i] = abilities.size() - 1
			break
	_know(GameData.skill_anchor(ability_id))          # a skill's own rune comes with it [MODEL]
	return true


## Read a scroll out of the pack. Returns "" if it taught its skill (and is gone), else why not.
func read_scroll(item_id: String) -> String:
	var def: Dictionary = GameData.item(item_id)
	if str(def.get("kind", "")) != "scroll" or not inventory.bag.has(item_id):
		return "That is not something you can read."
	var why: String = can_learn(str(def.get("teaches", "")))
	if why != "":
		return why
	inventory.remove(item_id)
	learn(str(def["teaches"]))
	var ab: Dictionary = GameData.ability(str(def["teaches"]))
	note("You read the scroll. %s is yours%s." % [str(ab.get("name", "?")), "" if hotbar.has(abilities.size() - 1) else " - the bar is full; place it from the soul screen"])
	_float("LEARNED", GameData.affinity_color(str(ab.get("affinity", ""))).lightened(0.3))
	return ""


## A scroll this character could read and does not already carry, picked at random; "" if none.
func scroll_for_me() -> String:
	var pool: Array[String] = []
	var items: Dictionary = GameData.items_file.get("items", {})
	for id: String in items:
		var def: Dictionary = items[id]
		if str(def.get("kind", "")) == "scroll" and can_learn(str(def.get("teaches", ""))) == "" and not inventory.bag.has(id):
			pool.append(id)
	return pool[rng.randi() % pool.size()] if not pool.is_empty() else ""


# --- the skill tree (design/08) -----------------------------------------------------------
# No skill is given (Brent 2026-10-18): a new character picks two root skills, and the rest are
# trained in town for skill points and money. The trainer is main.gd's business (train_skill only
# goes through there); scrolls (read_scroll) still teach anywhere and skip the tree's rules.

## Start the character over with exactly these skills, on the bar in order. They must be
## `start_picks` different root skills of affinities the character holds. Returns "" or why not.
func start_with_skills(ids: Array) -> String:
	var want: int = int(GameData.skill_tree.get("start_picks", 2))
	var roots: Array[String] = GameData.skill_roots(affinities)
	var picked: Array[String] = []
	for id: Variant in ids:
		if not roots.has(str(id)):
			return "%s is not a starting skill of your affinities." % str(GameData.ability(str(id)).get("name", id))
		if picked.has(str(id)):
			return "The same skill twice."
		picked.append(str(id))
	if picked.size() != want:
		return "Pick %d starting skills." % want
	drop_stones()
	buffs.clear()
	abilities.clear()
	for i: int in hotbar.size():
		hotbar[i] = -1
	for id: String in picked:
		learn(id)
	known_runes.clear()
	_grant_start_runes()
	return ""


## The first `start_picks` root skills - only for quick starts in tests (start_new_character).
func default_start_skills() -> Array[String]:
	var roots: Array[String] = GameData.skill_roots(affinities)
	return roots.slice(0, int(GameData.skill_tree.get("start_picks", 2)))


## What learning a node costs at a trainer: {points, price}.
func skill_cost(ability_id: String) -> Dictionary:
	var node: Dictionary = GameData.skill_node(ability_id)
	var tier: Dictionary = (GameData.skill_tree.get("tiers", {}) as Dictionary).get(str(int(node.get("tier", 1))), {})
	return {"points": int(tier.get("points", 1)), "price": int(tier.get("price", 0))}


## A node's prerequisites are met: it has none, or the character knows any one of them.
func skill_unlocked(ability_id: String) -> bool:
	var needs: Array = GameData.skill_node(ability_id).get("requires", [])
	if needs.is_empty():
		return true
	for id: Variant in needs:
		if knows(str(id)):
			return true
	return false


## Why a trainer could not teach this skill now, or "" if they could.
func cannot_train_reason(ability_id: String) -> String:
	var why: String = can_learn(ability_id)
	if why != "":
		return why
	if GameData.skill_node(ability_id).is_empty():
		return "No trainer teaches that; it is not on any tree."
	if not skill_unlocked(ability_id):
		var names: Array[String] = []
		for id: Variant in GameData.skill_node(ability_id).get("requires", []):
			names.append(str(GameData.ability(str(id)).get("name", id)))
		return "Learn %s first." % " or ".join(names)
	var cost: Dictionary = skill_cost(ability_id)
	if skill_points < int(cost["points"]):
		return _points_short(int(cost["points"]))
	if not can_afford(int(cost["price"])):
		return "Nobody trains on that much debt."
	return ""


func _points_short(need: int) -> String:
	return "Needs %d skill point%s; you have %d." % [need, "" if need == 1 else "s", skill_points]


## Be taught a skill: the points and the fee are spent and the skill is yours. Only main.gd calls
## this, and only while you are talking to a trainer. Returns "" or why not.
func train_skill(ability_id: String) -> String:
	var why: String = cannot_train_reason(ability_id)
	if why != "":
		return why
	var cost: Dictionary = skill_cost(ability_id)
	skill_points -= int(cost["points"])
	charge(int(cost["price"]))
	learn(ability_id)
	var ab: Dictionary = GameData.ability(ability_id)
	note("Trained: %s%s." % [str(ab.get("name", ability_id)), "" if hotbar.has(abilities.size() - 1) else " - the bar is full; place it from the soul screen"])
	return ""


## Why a trainer could not drill this skill now, or "" if they could.
func cannot_drill_reason(ability_id: String) -> String:
	var st: Dictionary = {}
	for a: Dictionary in abilities:
		if str(a["id"]) == ability_id:
			st = a
	if st.is_empty():
		return "You do not know that skill."
	if float(st["progress"]) >= 100.0:
		return "Its bar is full. Only a bound construct takes it further."
	var cfg: Dictionary = GameData.skill_tree.get("drill", {})
	if skill_points < int(cfg.get("points", 1)):
		return _points_short(int(cfg.get("points", 1)))
	if not can_afford(int(cfg.get("price", 0))):
		return "Nobody trains on that much debt."
	return ""


## Drill a known skill: its stage progress moves on (capped at 100 - the stage still needs a
## bound construct, Brent 2026-09-23). Only main.gd calls this, at a trainer.
func drill_skill(ability_id: String) -> String:
	var why: String = cannot_drill_reason(ability_id)
	if why != "":
		return why
	var cfg: Dictionary = GameData.skill_tree.get("drill", {})
	skill_points -= int(cfg.get("points", 1))
	charge(int(cfg.get("price", 0)))
	for a: Dictionary in abilities:
		if str(a["id"]) == ability_id:
			a["progress"] = minf(100.0, float(a["progress"]) + float(cfg.get("progress", 0.0)))
	note("You drill %s until your hands know it better." % str(GameData.ability(ability_id).get("name", ability_id)))
	return ""


## Star growth banks toward skill points: one per `points.per_star_pct` percentage points grown.
func _earn_skill_points(grown: float) -> void:
	var per: float = float((GameData.skill_tree.get("points", {}) as Dictionary).get("per_star_pct", 10.0))
	if grown <= 0.0 or per <= 0.0:
		return
	skill_growth += grown
	while skill_growth >= per:
		skill_growth -= per
		skill_points += 1
		note("A skill point. A trainer in town can spend it (%s shows the tree)." % Keybinds.binding_text("skills"))


# --- more skill behaviours (design/05 Appendix A) -------------------------------------------------

## The spot a point-aimed skill lands on: toward the cursor, at most `reach` away.
func _aim_point(reach: float) -> Vector3:
	var want: Vector3 = _cursor_ground() - global_position
	want.y = 0.0
	if want.length() < 0.5:
		want = _facing * reach                    # no cursor to speak of (bot, headless): straight ahead
	if want.length() > reach:
		want = want.normalized() * reach
	return global_position + want


## Living enemies whose bodies reach within `radius` of `point`.
func _enemies_near(point: Vector3, radius: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	if not is_inside_tree():
		return out
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Node3D
		if e == null or bool(e.call("is_dead")):
			continue
		var to: Vector3 = e.global_position - point
		to.y = 0.0
		if to.length() <= radius + float(e.get("radius")):
			out.append(e)
	return out


## displace: move enemies instead of hurting them. See abilities.json for the three modes.
func _displace(point: Vector3, target: Node3D, ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var color: Color = GameData.affinity_color(str(ab.get("affinity", "")))
	var chest: Vector3 = global_position + Vector3.UP
	_strike_t = 0.2
	if str(ab.get("mode", "")) == "pull_target":
		if target == null:
			return
		_line_visual(chest, target.global_position + Vector3.UP, color)
		apply_hit(target, _payload(ab, "on_hit"), tags, stage_mult)
		if is_instance_valid(target) and not bool(target.call("is_dead")):
			target.set("shover", self)
			target.call("pull_toward", global_position, float(ab.get("pull", 10.0)), float(ab.get("keep", 1.5)) + float(target.get("radius")))
			target.call("turn_away_from", global_position, float(ab.get("turn_s", 1.0)))
		return
	_line_visual(chest, point + Vector3.UP * 0.3, color)
	var burned: int = spend_pips(int(ab["spend_pips"])) if ab.has("spend_pips") else 0
	var from_point: bool = str((ab.get("on_hit", {}) as Dictionary).get("shove_dir", "")) == "from_point"
	for e: Node3D in _enemies_near(point, float(ab.get("radius", 3.0))):
		apply_hit(e, _payload(ab, "on_hit"), tags, stage_mult, (e.global_position - point) if from_point else Vector3.ZERO)
		if not is_instance_valid(e) or bool(e.call("is_dead")):
			continue
		if str(ab.get("mode", "")) == "pull_area":
			e.set("shover", self)
			e.call("pull_toward", point, float(ab.get("pull", 4.0)))
		elif burned > 0 and bool(e.call("has_status", "aloft")):
			var up: Dictionary = (e.get("statuses") as Dictionary)["aloft"]
			up["t"] = float(up["t"]) + float(ab.get("pip_seconds", 0.2)) * float(burned)


## delayed_blast: mark the ground now; land_blast() does the rest when the mark comes due.
func _start_blast(point: Vector3, ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var blast := DelayedBlast.new()
	blast.caster = self
	blast.ab = ab
	blast.stage_mult = stage_mult
	blast.tags = tags
	blast.radius = float(ab.get("radius", 2.0))
	blast.delay = float(ab.get("delay", 0.5))
	blast.color = GameData.affinity_color(str(ab.get("affinity", ""))).lightened(0.3)
	get_parent().add_child(blast)
	blast.global_position = Vector3(point.x, global_position.y, point.z)
	_strike_t = 0.2


## A delayed blast goes off at `at` (called by the DelayedBlast). It may leave a cloud or a patch.
func land_blast(at: Vector3, ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var radius: float = float(ab.get("radius", 2.0))
	for e: Node3D in _enemies_near(at, radius):
		var marked: bool = ab.has("bonus_vs_status") and bool(e.call("has_status", str(ab["bonus_vs_status"])))
		apply_hit(e, _payload(ab, "on_hit"), tags, stage_mult)
		if marked and is_instance_valid(e) and not bool(e.call("is_dead")):
			deal_damage(e, float(ab.get("bonus_damage", 0.0)) * stage_mult, tags + ["bonus"])
	if ab.has("leave_zone"):
		lay_cloud(at, ab["leave_zone"], tags + ["cloud"])
	if ab.has("leave_growth"):
		plant_growth(at, ab["leave_growth"])
	if bool(ab.get("kill_projectiles", false)):
		for node: Node in get_tree().get_nodes_in_group("enemy_shots"):
			var shot := node as Node3D
			if shot != null and Vector2(shot.global_position.x - at.x, shot.global_position.z - at.z).length() <= radius:
				shot.queue_free()
	if bool(ab.get("shatters_stone", false)):
		for s: Variant in stones.duplicate():
			if is_instance_valid(s) and Vector2((s as Stone).global_position.x - at.x, (s as Stone).global_position.z - at.z).length() <= radius + (s as Stone).size.x * 0.5:
				(s as Stone).shatter((s as Stone).global_position - at, self)
	if ab.has("leave_prop"):
		var away: Vector3 = at - global_position
		raise_stone(at, away if away.length() > 0.1 else _facing, ab["leave_prop"], stage_mult, tags)


## detonate: everything near you carrying the status loses it, and pays for it. A status list
## wakes every spell of yours at once; consume_zone lifts your own dark ground instead; keep_stacks
## reads the stacks without spending them, on every beat; gather_into pours them all into one target.
func _detonate(ab: Dictionary, stage_mult: float, tags: Array, strike_target: Node3D = null) -> void:
	var color: Color = GameData.affinity_color(str(ab.get("affinity", "")))
	_strike_t = 0.25
	if str(ab.get("consume_zone", "")) != "":
		_lift_zones(ab, stage_mult, tags)
		return
	if str(ab.get("gather_into", "")) == "target" and strike_target != null:
		_gather(strike_target, ab, stage_mult, tags)
		return
	if bool(ab.get("keep_stacks", false)) and int(ab.get("beats", 0)) > 0:
		_beats(ab, stage_mult, tags)
		return
	var ids: Array = ab["consume_status"] if ab.get("consume_status") is Array else [str(ab.get("consume_status", ""))]
	var status: String = str(ids[0])
	var carrying: Array = []
	for e: Node3D in _enemies_near(global_position, float(ab.get("range", 10.0))):
		var n := 0
		var asleep: bool = bool(e.call("has_status", "asleep"))
		for id: Variant in ids:
			var counts: int = int(e.call("status_stacks", str(id))) if bool(e.call("has_status", str(id))) else 0
			if counts > 0:
				n += counts
				e.call("clear_status", str(id))
		if n > 0:
			carrying.append([e, n, e.global_position, asleep])
	var refund := 0.0
	for row: Array in carrying:
		var stacks: int = row[1]
		var where: Vector3 = row[2]
		var carrier: Node3D = row[0]
		if bool(ab.get("needs_clear_line", false)) and not _ray(global_position + Vector3.UP, where + Vector3.UP).is_empty():
			continue                             # no clear line home: its light stays where it is
		_line_visual(global_position + Vector3.UP, where + Vector3.UP, color)
		refund += float(ab.get("refund_per_stack", 0.0)) * float(stacks)
		if ab.has("per_stack_damage") and is_instance_valid(carrier):
			deal_damage(carrier, float(ab["per_stack_damage"]) * float(stacks) * stage_mult, tags + ["burst"])
		if ab.has("per_target_damage") and is_instance_valid(carrier):
			deal_damage(carrier, (float(ab["per_target_damage"]) + (float(ab.get("bonus_vs_asleep", 0.0)) if bool(row[3]) else 0.0)) * stage_mult, tags + ["burst"])
		if ab.has("on_hit") and is_instance_valid(carrier) and not bool(carrier.call("is_dead")):
			if ab.has("burst_radius"):
				_burst_at(where, _payload(ab, "on_hit").merged({"burst_radius": float(ab["burst_radius"])}, true), tags + ["burst"], stage_mult, carrier)
			else:
				apply_hit(carrier, _payload(ab, "on_hit"), tags, stage_mult)
		if str(ab.get("after_status", "")) != "" and is_instance_valid(carrier) and not bool(carrier.call("is_dead")):
			carrier.call("add_status", str(ab["after_status"]), 1, self)
		if float(ab.get("ray_damage", 0.0)) > 0.0:
			_home_ray(where, carrier, float(ab["ray_damage"]) * stage_mult, tags)
		if ab.has("per_stack_burst"):
			for near: Node3D in _enemies_near(where, float(ab.get("burst_radius", 2.0))):
				deal_damage(near, float(ab["per_stack_burst"]) * float(stacks) * stage_mult, tags + ["burst"])
		if ab.has("overload_fracs"):
			var fracs: Array = ab["overload_fracs"]
			var frac: float = float(fracs[mini(stacks, fracs.size()) - 1])
			var live: Dictionary = GameData.status("live")
			var e: Node3D = row[0]
			if is_instance_valid(e) and not bool(e.call("is_dead")):
				FloatText.spawn(get_parent(), where + Vector3.UP * 0.6, "OVERLOAD", Color(0.85, 0.78, 1.0))
				deal_damage(e, float(live.get("overload_damage", 150.0)) * frac * stage_mult, tags + ["overload"])
				if is_instance_valid(e) and not bool(e.call("is_dead")):
					e.call("stun", float(live.get("stun", 1.0)) * frac)
	if refund > 0.0:
		essence = minf(essence_max, essence + minf(refund, float(ab.get("cost", 0.0))))
	if ab.has("decoy_burst"):
		var db: Dictionary = ab["decoy_burst"]
		for l: Node in get_tree().get_nodes_in_group("lures"):
			if l is Lure and (l as Lure).caster == self and (l as Node3D).global_position.distance_to(global_position) <= float(ab.get("range", 10.0)):
				_burst_at((l as Node3D).global_position, {"damage": float(db.get("damage", 40.0)), "burst_radius": float(db.get("radius", 2.0))}, tags + ["burst"], stage_mult)
				(l as Lure).call("_break")


## chain: the target, then the nearest enemy to it not yet struck, and on, `jumps` times. A chain
## that fans (Contagion) jumps from each body to every unstruck enemy near it, `depth` generations.
func _chain(target: Node3D, ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var color: Color = GameData.affinity_color(str(ab.get("affinity", "")))
	var struck: Array = []
	var from: Vector3 = global_position + Vector3.UP
	var cur: Node3D = target
	_strike_t = 0.2
	if bool(ab.get("fan", false)):
		var wave: Array = [target]
		struck.append(target)
		_line_visual(from, target.global_position + Vector3.UP, color)
		apply_hit(target, ab.get("first_hit", _payload(ab, "on_hit")), tags, stage_mult)
		for gen: int in int(ab.get("depth", 2)):
			var next_wave: Array = []
			for w: Variant in wave:
				if not is_instance_valid(w):
					continue
				for e: Node3D in _enemies_near((w as Node3D).global_position, float(ab.get("jump_radius", 3.0))):
					if struck.has(e) or struck.size() > int(ab.get("jumps", 7)):
						continue
					struck.append(e)
					next_wave.append(e)
					_line_visual((w as Node3D).global_position + Vector3.UP, e.global_position + Vector3.UP, color)
					apply_hit(e, _payload(ab, "on_hit"), tags, stage_mult)
			wave = next_wave
		return
	for jump: int in int(ab.get("jumps", 3)) + 1:
		var at: Vector3 = cur.global_position
		struck.append(cur)
		_line_visual(from, at + Vector3.UP, color)
		from = at + Vector3.UP
		apply_hit(cur, _payload(ab, "on_hit"), tags, stage_mult)
		var next: Node3D = null
		for e: Node3D in _enemies_near(at, float(ab.get("jump_radius", 5.0))):
			if not struck.has(e) and (next == null or e.global_position.distance_to(at) < next.global_position.distance_to(at)):
				next = e
		if next == null:
			return
		cur = next


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
	return (_windup_t > 0.0 and bool(_windup.get("braced", false))) or buffs.has("stonehide") or (_dash_time > 0.0 and _dash_braced) \
		or _brace_t > 0.0 or (not _held.is_empty() and bool((_held["ab"] as Dictionary).get("braced", false)))


## How far through a held skill you are (a channel's hold, a charge), 0 to 1; -1 when holding nothing.
func held_frac() -> float:
	if _held.is_empty():
		return -1.0
	var ab: Dictionary = _held["ab"]
	var full: float = float(ab.get("charge_max", ab.get("duration", GameData.num("skills", "channel_max_s"))))
	return clampf(float(_held["t"]) / maxf(0.01, full), 0.0, 1.0)


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
		_pip_dist += dist * _zone_num("pip_gain_mult")
		var per: float = float(cfg["metres_per_pip"])
		while _pip_dist >= per:
			_pip_dist -= per
			pips = mini(int(cfg["max"]), pips + 1)
	elif not buffs.has("veil") and not _zone_flag("freeze_pips"):     # behind the veil (or in dead air) the wind stays with you
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
	_rig_action("throw")
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
	var floor_hp: float = 0.0
	for bid: String in buffs:
		floor_hp = maxf(floor_hp, float((buffs[bid] as Dictionary).get("floor_health", 0.0)))
	if floor_hp > 0.0:
		amount = minf(amount, maxf(0.0, body.hp - floor_hp))    # Embalm: you cannot die while it lasts
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
	# Tourniquet: held blood closes the wound before it opens
	for bid: String in buffs:
		var need: int = int((buffs[bid] as Dictionary).get("blood_per_wound", 0))
		if need > 0 and held_blood >= need:
			held_blood -= need
			_float("staunched", GameData.affinity_color("blood").lightened(0.3))
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
	var hurt: float = 1.0 - body.total() / body.total_max()
	var risk: float = 1.0 + hurt * float(_p["aura_hurt_risk_bonus"])
	_latent_aura += float(target.get("aura_value")) * risk
	grow_star(float(target.get("aura_value")) * GameData.num("stars", "growth_pct_per_aura"))
	_roll_drops(target)
	_roll_loot(target)
	_roll_kill_rune(target)


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


## Everything a skill does to one target, in one place: what it spends on the target first
## (`consume`), damage (through the talent pipeline), then statuses, stun, poise (and a Shatter),
## interrupts, turning, shove or pull, Live marks, and arcs on to more enemies (`jumps`). `dir` is
## the way a shove goes; zero means straight away from you. Scenery only takes the damage. `once`
## is a ticking payload's memo (a zone, a channel, a cloud, a growth patch): through it a hold (a
## status marked control, a stun, an interrupt) lands at most once per target per cast.
## The affinities' rules gate it first: Life does nothing to the unliving, Dream nothing to a mind
## that cannot see you (unless it sleeps).
func apply_hit(target: Node, payload: Dictionary, tags: Array = [], stage_mult: float = 1.0, dir: Vector3 = Vector3.ZERO, once: Variant = null) -> HitContext:
	var ctx: HitContext = null
	if not is_instance_valid(target) or bool(target.call("is_dead")):
		return ctx
	if not _affinity_reaches(target, tags):
		return ctx
	var memo: Variant = once if once is Dictionary else null
	var key: int = target.get_instance_id()
	var held_before: bool = memo != null and (memo as Dictionary).has(key)
	if bool(payload.get("through", false)):
		tags = tags + ["through"]
	if payload.has("consume") and target.has_method("status_stacks"):
		_consume_on(target, payload["consume"], tags, stage_mult)
		if not is_instance_valid(target) or bool(target.call("is_dead")):
			return ctx
	# bonus_vs {status: fraction}: more damage to a target that already carries that status
	var bonus := 1.0
	var flat := 0.0
	if target.has_method("has_status"):
		for st: String in (payload.get("bonus_vs", {}) as Dictionary):
			if bool(target.call("has_status", st)):
				bonus += float((payload["bonus_vs"] as Dictionary)[st])
		for st2: String in (payload.get("bonus_flat_vs", {}) as Dictionary):
			if bool(target.call("has_status", st2)):
				flat = maxf(flat, float((payload["bonus_flat_vs"] as Dictionary)[st2]))
	if payload.has("unliving_mult") and not bool(target.get("is_living")):
		bonus *= float(payload["unliving_mult"])
	if payload.has("damage"):
		ctx = deal_damage(target, (float(payload["damage"]) + flat) * stage_mult * bonus, tags)
	elif payload.has("damage_mult"):
		ctx = deal_damage(target, (strike_damage() * float(payload["damage_mult"]) + flat) * stage_mult * bonus, tags)
	elif flat > 0.0:
		ctx = deal_damage(target, flat * stage_mult * bonus, tags)
	if not is_instance_valid(target) or bool(target.call("is_dead")) or not target.has_method("add_status"):
		return ctx
	if payload.has("execute_below") and target.get("body") is Body:
		var b: Body = target.get("body")
		var excluded: bool = (payload.get("execute_excludes", []) as Array).has("elite") and target.has_method("is_elite") and bool(target.call("is_elite"))
		if not excluded and b.total() < b.total_max() * float(payload["execute_below"]):
			FloatText.spawn(get_parent(), (target as Node3D).global_position + Vector3.UP * 0.7, "ENDED", Color(0.9, 0.86, 0.72))
			deal_damage(target, b.total() * 10.0 + 1.0, tags + ["execute"])
			if not is_instance_valid(target) or bool(target.call("is_dead")):
				return ctx
	var stun_marks: int = int(target.call("status_stacks", "live")) if payload.has("stun_per_mark") else 0
	var opts: Dictionary = _status_opts(target, payload, tags)
	if not bool(payload.get("needs_facing", false)) or bool(target.call("is_in_front", global_position)):
		var time_of: Dictionary = payload.get("status_time_of", {})
		if payload.has("status"):
			_give_status(target, str(payload["status"]), int(payload.get("stacks", 1)), _status_time(opts, time_of, str(payload["status"]), {}), memo, held_before)
		# further statuses, as a list [{id, stacks, lasts?}] (rune words add them here)
		for extra: Variant in payload.get("statuses", []):
			var e: Dictionary = extra as Dictionary
			_give_status(target, str(e.get("id", "")), int(e.get("stacks", 1)), _status_time(opts, time_of, str(e.get("id", "")), e), memo, held_before)
		if bool(payload.get("blind_if_dark", false)) and Light.is_dark(get_tree(), (target as Node3D).global_position):
			_give_status(target, "blinded", 1, opts, memo, held_before)
	if not is_instance_valid(target) or bool(target.call("is_dead")):
		return ctx
	if payload.has("stun_per_mark") and not held_before:
		var secs: float = float(payload["stun_per_mark"]) * float(stun_marks) if stun_marks > 0 else float(payload.get("stun_min", 0.2))
		if target.has_method("is_elite") and bool(target.call("is_elite")):
			secs *= float(payload.get("elite_stun_mult", 0.5))
		target.call("stun", secs)
	var poise_hit: float = 0.0
	if target.has_method("take_poise") and (payload.has("damage") or payload.has("damage_mult") or payload.has("poise") or flat > 0.0):
		poise_hit = float(payload.get("poise", GameData.num("combat", "skill_poise")))
		for st3: String in (payload.get("poise_vs", {}) as Dictionary):
			if bool(target.call("has_status", st3)):
				poise_hit = maxf(poise_hit, float((payload["poise_vs"] as Dictionary)[st3]))
		target.call("take_poise", poise_hit)
	_try_shatter(target, poise_hit, float(payload.get("shatter_radius", -1.0)))
	if not is_instance_valid(target) or bool(target.call("is_dead")):
		return ctx
	if not held_before:
		if bool(payload.get("hard_interrupt", false)):
			target.call("interrupt")
			FloatText.spawn(get_parent(), (target as Node3D).global_position + Vector3.UP * 0.5, "SNUFFED", Color(1, 1, 1))
		elif bool(payload.get("interrupts_moving", false)):
			if target.has_method("is_lunging") and bool(target.call("is_lunging")):
				target.call("interrupt")
				FloatText.spawn(get_parent(), (target as Node3D).global_position + Vector3.UP * 0.5, "STALLED", Color(1, 1, 1))
		elif bool(payload.get("interrupts", false)):
			if bool(target.call("interrupt_attack")):
				FloatText.spawn(get_parent(), (target as Node3D).global_position + Vector3.UP * 0.5, "INTERRUPTED", Color(1, 1, 1))
		if memo != null:
			if bool(payload.get("interrupts", false)) or bool(payload.get("hard_interrupt", false)) or payload.has("stun_per_mark"):
				(memo as Dictionary)[key] = true
	if float(payload.get("turn_s", 0.0)) > 0.0 and target.has_method("turn_away_from"):
		target.call("turn_away_from", global_position, float(payload["turn_s"]))
	if bool(payload.get("quells_censer", false)):
		target.set("quelled", true)
	# a shove pushes away; a pull is a shove toward you. Both on one hit: the difference wins.
	var push: float = float(payload.get("shove", 0.0)) - float(payload.get("pull", 0.0))
	if push > 0.0:
		var away: Vector3 = dir
		if away.length() < 0.001:
			away = (target as Node3D).global_position - global_position
		away.y = 0.0
		if away.length() < 0.001:
			away = _facing
		target.set("shover", self)
		target.call("shove", away, push)
	elif push < 0.0 and target.has_method("pull_toward"):
		target.call("pull_toward", global_position, -push)
	if int(payload.get("marks", 0)) > 0:
		_add_marks(target, int(payload["marks"]), true)
	# jumps (2026-10-22): the hit arcs on to that many more enemies, for less
	if int(payload.get("jumps", 0)) > 0 and is_instance_valid(target):
		var arc: Dictionary = payload.duplicate()
		arc.erase("jumps")
		var cut: float = GameData.num("skills", "jump_damage_mult")
		for k: String in ["damage", "damage_mult"]:
			if arc.has(k):
				arc[k] = float(arc[k]) * cut
		_arc_on(target as Node3D, arc, tags + ["arc"], stage_mult, int(payload["jumps"]), GameData.num("skills", "jump_radius"))
	return ctx


## One status's own timing on a hit (2026-10-23, rune strength): the payload's `status_time_of`
## {id: multiple} lengthens that status alone; a `statuses` entry with its own "lasts" lasts exactly
## that (a silence's seconds), whatever the payload's other statuses do. Data only - no ids here.
static func _status_time(opts: Dictionary, time_of: Dictionary, id: String, entry: Dictionary) -> Dictionary:
	var m: float = float(time_of.get(id, 1.0))
	if not entry.has("lasts") and absf(m - 1.0) < 0.000001:
		return opts
	var o: Dictionary = opts.duplicate()
	if entry.has("lasts"):
		o["lasts"] = float(entry["lasts"])
		o.erase("time_mult")
	if absf(m - 1.0) >= 0.000001:
		o["time_mult"] = float(o.get("time_mult", 1.0)) * m
	return o


## A status from a hit: once per target per cast through a ticking payload if it is a hold.
func _give_status(target: Node, id: String, stacks: int, opts: Dictionary, memo: Variant, held_before: bool) -> void:
	if id == "":
		return
	var def: Dictionary = GameData.status(id)
	if def.has("alias_of"):
		def = GameData.status(str(def["alias_of"]))
	var hold: bool = bool(def.get("control", false))
	if hold and held_before:
		return
	# a buff of yours may set how long one of your statuses runs (Bitter Tonic: doses come due sooner)
	for bid: String in buffs:
		var sl: Dictionary = (buffs[bid] as Dictionary).get("status_lasts", {})
		if sl.has(id):
			opts = opts.duplicate()
			opts["lasts"] = float(sl[id])
	target.call("add_status", id, stacks, self, opts)
	if hold and memo != null:
		(memo as Dictionary)[target.get_instance_id()] = true


## How long and with what a payload's statuses land: its own status_s (more per metal class worn,
## more per point of heat, longer in the Dark, shorter unless the target already has something),
## its time multiplier (the rune Duration), the affinity's longer hold on some targets (Dream on the
## Dazed and the Asleep), and the data the status reads from the skill.
func _status_opts(target: Node, payload: Dictionary, tags: Array) -> Dictionary:
	var opts: Dictionary = {}
	if payload.has("status_s"):
		var lasts: float = float(payload["status_s"])
		if payload.has("status_s_per_class") and target.has_method("metal_class"):
			lasts += float(payload["status_s_per_class"]) * float(int(target.call("metal_class")))
		if payload.has("status_s_per_heat"):
			var heat := 0.0
			for aff: String in affinities:
				if tags.has(aff):
					heat = maxf(heat, reflux_of(aff))
			lasts = minf(float(payload.get("status_s_max", 99.0)), lasts + float(payload["status_s_per_heat"]) * heat)
		opts["lasts"] = lasts
	if payload.has("dark_status_s") and Light.is_dark(get_tree(), (target as Node3D).global_position):
		opts["lasts"] = float(payload["dark_status_s"])
	if payload.has("status_s_if_not"):
		var cond: Dictionary = payload["status_s_if_not"]
		if not bool(target.call("has_status", str(cond.get("status", "")))):
			opts["lasts"] = float(opts.get("lasts", GameData.status(str(payload.get("status", ""))).get("lasts", 1.0))) * float(cond.get("frac", 1.0))
	var mult: float = float(payload.get("status_time_mult", 1.0))
	for aff2: String in affinities:
		if not tags.has(aff2):
			continue
		var vs: Dictionary = GameData.affinity(aff2).get("status_time_vs", {})
		for st: String in vs:
			if bool(target.call("has_status", st)):
				mult *= float(vs[st])
	if mult != 1.0:
		opts["time_mult"] = mult
	var data: Dictionary = (payload.get("status_data", {}) as Dictionary).duplicate()
	if payload.has("release_shove"):
		data["release_shove"] = payload["release_shove"]
	if not data.is_empty():
		opts["data"] = data
	return opts


## Spend what is already on the target (consume: {status, per_stack_damage, per_stack_poise,
## stun_per_stack, stun_max, counts {status: stacks it counts as}, vent_per_stack}).
func _consume_on(target: Node, c: Dictionary, tags: Array, stage_mult: float) -> int:
	var id: String = str(c.get("status", ""))
	var n: int = int(target.call("status_stacks", id)) if bool(target.call("has_status", id)) else 0
	var counts: Dictionary = c.get("counts", {})
	for alt: String in counts:
		if bool(target.call("has_status", alt)):
			n = maxi(n, int(counts[alt]))
			target.call("clear_status", alt)
	if n <= 0:
		return 0
	target.call("clear_status", id)
	if float(c.get("per_stack_damage", 0.0)) > 0.0:
		deal_damage(target, float(c["per_stack_damage"]) * float(n) * stage_mult, tags + ["burst"])
	if is_instance_valid(target) and not bool(target.call("is_dead")):
		if float(c.get("per_stack_poise", 0.0)) > 0.0:
			target.call("take_poise", float(c["per_stack_poise"]) * float(n))
		if float(c.get("stun_per_stack", 0.0)) > 0.0:
			target.call("stun", minf(float(c.get("stun_max", 99.0)), float(c["stun_per_stack"]) * float(n)))
	if float(c.get("vent_per_stack", 0.0)) > 0.0:
		for aff: String in affinities:
			if tags.has(aff):
				reflux_by[aff] = maxf(0.0, reflux_of(aff) - float(c["vent_per_stack"]) * float(n))
	return n


## The hit arcs on from `from`: to the nearest enemy not yet struck within `reach`, `n` times.
func _arc_on(from: Node3D, payload: Dictionary, tags: Array, stage_mult: float, n: int, reach: float) -> void:
	var struck: Array = [from]
	var cur: Node3D = from
	for i: int in n:
		if not is_instance_valid(cur):
			return
		var at: Vector3 = cur.global_position
		var next: Node3D = null
		for e: Node3D in _enemies_near(at, reach):
			if not struck.has(e) and (next == null or e.global_position.distance_to(at) < next.global_position.distance_to(at)):
				next = e
		if next == null:
			return
		struck.append(next)
		_line_visual(at + Vector3.UP, next.global_position + Vector3.UP, Color(0.9, 0.9, 1.0))
		apply_hit(next, payload, tags, stage_mult)
		cur = next


## A hard hit on something Brittle (or Frozen, which counts as Brittle) Shatters it: the shatter's
## damage, not halved, and shards on everyone near it (statuses.json brittle.shatter).
func _try_shatter(target: Node, poise_hit: float, radius_override: float = -1.0) -> void:
	if not is_instance_valid(target) or not target.has_method("has_status") or bool(target.call("is_dead")):
		return
	if not bool(target.call("has_status", "brittle")):
		return
	var cfg: Dictionary = GameData.status("brittle").get("shatter", {})
	if poise_hit < float(cfg.get("hard_poise", 40.0)):
		return
	var at: Vector3 = (target as Node3D).global_position
	for id: Variant in cfg.get("ends", ["frozen", "brittle"]):
		target.call("clear_status", str(id))
	FloatText.spawn(get_parent(), at + Vector3.UP * 0.8, "SHATTER", Color(0.85, 0.97, 1.0))
	deal_damage(target, float(cfg.get("damage", 100.0)), ["ice", "shatter", "ability"])
	var r: float = radius_override if radius_override > 0.0 else float(cfg.get("radius", 2.5))
	for e: Node3D in _enemies_near(at, r):
		if e != target:
			apply_hit(e, cfg.get("shard", {}), ["ice", "shatter", "ability", "shard"])


## A payload on everyone within its burst_radius (or radius) of `at`.
func _burst_at(at: Vector3, payload: Dictionary, tags: Array, stage_mult: float = 1.0, skip: Node = null) -> void:
	if payload.is_empty():
		return
	var p: Dictionary = payload.duplicate()
	var r: float = float(p.get("burst_radius", p.get("radius", 2.0)))
	p.erase("burst_radius")
	p.erase("radius")
	for e: Node3D in _enemies_near(at, r):
		if e != skip:
			apply_hit(e, p, tags, stage_mult)


# --- affinity rules as data (2026-10-22) ---------------------------------------------------------

## True if the hit can touch this target at all: Life does nothing to the unliving; Dream needs
## a mind that sees you - in its front arc, a clear line, not blinded - or one that is asleep.
func _affinity_reaches(target: Node, tags: Array) -> bool:
	for aff: String in affinities:
		if not tags.has(aff):
			continue
		var a: Dictionary = GameData.affinity(aff)
		if bool(a.get("living_only", false)) and not bool(target.get("is_living")):
			return false
		if bool(a.get("needs_seen", false)) and target.has_method("sees_point"):
			if not bool(target.call("has_status", "asleep")) and not bool(target.call("sees_point", global_position)):
				return false
	return true


## Attacker-side affinity rules on one hit, by the affinities it is tagged with: Dark by the light
## where the target stands; Metal by the metal it wears; Life on the hale, Death on the dying; Dream
## on the dazed and asleep; Disease by flesh; those that go through guards; then the buffs that change
## a hit (an unaware target, a first hit from behind, gaps in Lit armour, corded muscle).
func _affinity_rules(ctx: HitContext, target: Node) -> void:
	var at: Vector3 = (target as Node3D).global_position
	for aff: String in affinities:
		if not ctx.has_tag(aff):
			continue
		var a: Dictionary = GameData.affinity(aff)
		if a.has("light_mult") and is_inside_tree():
			ctx.mult *= float((a["light_mult"] as Dictionary).get(Light.level_at(get_tree(), at), 1.0))
		if float(a.get("per_metal_class", 0.0)) > 0.0 and target.has_method("metal_class"):
			ctx.mult *= 1.0 + float(a["per_metal_class"]) * float(int(target.call("metal_class")))
		if bool(a.get("through", false)) and not ctx.has_tag("through"):
			ctx.tags.append("through")
		if bool(a.get("living_only", false)) and not bool(target.get("is_living")):
			ctx.cancelled = true
			return
		if a.has("hale_mult") and target.has_method("has_status") and bool(target.call("has_status", "hale")):
			ctx.mult *= float(a["hale_mult"])
		if a.has("dying_mult") and target.has_method("has_status") and bool(target.call("has_status", "dying")):
			ctx.mult *= float(a["dying_mult"])
		if bool(a.get("times_flesh", false)) and target.has_method("flesh"):
			ctx.mult *= float(target.call("flesh"))
		if target.has_method("has_status"):
			for st: String in (a.get("bonus_vs_status", {}) as Dictionary):
				if bool(target.call("has_status", st)):
					ctx.mult *= 1.0 + float(a["bonus_vs_status"][st])
	if ctx.has_tag("dot"):
		return
	for bid: String in buffs:
		var b: Dictionary = buffs[bid]
		if b.has("unaware_mult") and target.has_method("is_in_front") and not bool(target.call("is_in_front", global_position)):
			ctx.mult *= float(b["unaware_mult"])
		if bool(b.get("first_hit_rear", false)) and not ctx.has_tag("rear"):
			ctx.tags.append("rear")
		if b.has("lit_front_armour_mult") and target.has_method("has_status") and bool(target.call("has_status", "lit")) and not ctx.has_tag("through"):
			ctx.tags.append("through")
	if _rear_window_t > 0.0 and not ctx.has_tag("rear"):
		ctx.tags.append("rear")
	if ctx.has_tag("melee") and not ctx.has_tag("ability"):
		ctx.mult *= buff_num("strike_mult")


## After a hit has landed (not a burn): you are seen for a moment; a buff that ends on your first
## hit ends; Festering Hands adds to an infected wound.
func _after_landing(ctx: HitContext, target: Node) -> void:
	var cfg: Dictionary = GameData.affinity("dark")
	var muffled := false
	for bid: String in buffs.keys():
		var b: Dictionary = buffs[bid]
		if b.has("unaware_mult"):
			muffled = true
		if bool(b.get("ends_on_hit", false)):
			buffs.erase(bid)
		elif b.has("on_infected_hit") and is_instance_valid(target) and target.has_method("has_status") and bool(target.call("has_status", "infected")) and not ctx.has_tag("festering"):
			for extra: Variant in (b["on_infected_hit"] as Dictionary).get("statuses", []):
				target.call("add_status", str((extra as Dictionary)["id"]), int((extra as Dictionary).get("stacks", 1)), self)
	_rear_window_t = 0.0
	if not muffled:
		_unseen_reveal_t = float(cfg.get("reveal_s", 1.0))


## True if no enemy at `from` can see you: Bent Light hides you beyond its reach; Dark hides you
## beyond its own while you stand in the Dark - unless you struck or cast a moment ago.
func unseen_from(from: Vector3) -> bool:
	if _unseen_reveal_t > 0.0 or not is_inside_tree():
		return false
	var d: float = Vector2(from.x - global_position.x, from.z - global_position.z).length()
	for bid: String in buffs:
		if (buffs[bid] as Dictionary).has("unseen_beyond") and d > float(buffs[bid]["unseen_beyond"]):
			return true
	for aff: String in affinities:
		var a: Dictionary = GameData.affinity(aff)
		if bool(a.get("unseen_in_dark", false)) and d > float(a.get("unseen_beyond", 4.0)) and Light.is_dark(get_tree(), global_position):
			return true
	return false


## How long a body lies for you: longer if you hold Death.
func corpse_lie_s() -> float:
	var out: float = GameData.num("combat", "corpse_lie_s")
	for aff: String in affinities:
		out = maxf(out, float(GameData.affinity(aff).get("corpse_lie_s", 0.0)))
	return out


## True if you hold an affinity with this rule key set.
func holds_rule(key: String) -> bool:
	for aff: String in affinities:
		if bool(GameData.affinity(aff).get(key, false)):
			return true
	return false


## The most held blood you can carry (0 without Blood).
func held_blood_max() -> int:
	return int(GameData.affinity("blood").get("held_blood_max", 10)) if holds_rule("held_blood") else 0


## Held blood comes in (drinking, a bleeding kill). Never health.
func gain_blood(n: int) -> void:
	if held_blood_max() <= 0 or n <= 0:
		return
	held_blood = mini(held_blood_max(), held_blood + n)
	_blood_thin_t = 0.0


## Spend up to `n` held blood (n < 0: all of it). Returns how much was spent.
func spend_blood(n: int) -> int:
	var took: int = held_blood if n < 0 else mini(held_blood, n)
	held_blood -= took
	return took


## Blood spills on the floor at `at` (a bleeding body, a beat of the heart, Outpour).
func spill_blood(at: Vector3, measures: int = 1, big: bool = false) -> void:
	if is_inside_tree():
		BloodPool.spill(get_parent(), at, measures, big)


## A sick cloud at `at` (a body that died Infected): a GroundZone of kind "cloud".
func lay_cloud(at: Vector3, cfg: Dictionary, tags: Array) -> Node3D:
	if not is_inside_tree():
		return null
	var zone := GroundZone.new()
	zone.shape = "circle"
	zone.kind = "cloud"
	zone.radius = float(cfg.get("radius", 2.0))
	zone.life = float(cfg.get("life", 4.0))
	zone.tick_s = float(cfg.get("tick_s", 1.0))
	zone.payload = cfg.get("payload", {"status": "infected"})
	zone.tags = tags + ["zone"]
	zone.caster = self
	zone.bright = false
	zone.color = GameData.affinity_color("disease")
	zone.from = Vector3(at.x, global_position.y, at.z)
	zone.to = zone.from
	var drift: float = float(cfg.get("drift_speed", 0.0))
	if drift > 0.0:
		var way: Vector3 = zone.from - global_position
		if str(cfg.get("drift_dir", "away")) == "aim":
			way = _facing
		way.y = 0.0
		zone.drift_vel = (way.normalized() if way.length() > 0.05 else _facing) * drift
	get_parent().add_child(zone)
	return zone


## A patch of your growth at `at` (Nature): {kind, radius}. You keep growth.max of them.
func plant_growth(at: Vector3, cfg: Dictionary) -> Node3D:
	if not is_inside_tree():
		return null
	var gcfg: Dictionary = GameData.affinity("nature").get("growth", {})
	var mine: Array = get_tree().get_nodes_in_group("growth").filter(func(g: Node) -> bool: return g.get("caster") == self)
	if mine.size() >= int(gcfg.get("max", 12)):
		return null
	var patch := GrowthPatch.new()
	patch.caster = self
	patch.kind = str(cfg.get("kind", "bramble"))
	patch.radius = float(cfg.get("radius", gcfg.get("radius", 1.0)))
	patch.color = GameData.affinity_color("nature")
	get_parent().add_child(patch)
	patch.global_position = Vector3(at.x, global_position.y, at.z)
	return patch


## A water shove or pull you started has ended on `e`: it is Adrift for a moment (Siltfall).
func on_shove_ended(e: Node) -> void:
	if holds_rule("marks_adrift") and is_instance_valid(e) and not bool(e.call("is_dead")):
		e.call("add_status", "adrift", 1, self)


## A zone of yours you stand in carries this flag (freeze_pips, shed_standing).
func _zone_flag(key: String) -> bool:
	if not is_inside_tree():
		return false
	for zone: Node in get_tree().get_nodes_in_group("ground_zones"):
		if zone.get("caster") == self and bool(zone.get(key)) and bool(zone.call("has_point", global_position)):
			return true
	return false


## True while healing is refused (Embalm).
func _heal_blocked() -> bool:
	for bid: String in buffs:
		if bool((buffs[bid] as Dictionary).get("blocks_healing", false)):
			return true
	return false


## Inured Blood: less damage for each Infected enemy near you.
func _inured_mult() -> float:
	var out := 1.0
	for bid: String in buffs:
		var b: Dictionary = buffs[bid]
		if float(b.get("dr_per_infected", 0.0)) <= 0.0:
			continue
		var n := 0
		for e: Node3D in _enemies_near(global_position, float(b.get("radius", 8.0))):
			if bool(e.call("has_status", "infected")):
				n += 1
		out *= 1.0 - minf(float(b.get("dr_max", 0.3)), float(b["dr_per_infected"]) * float(n))
	return out


## Take `amount` off your hottest affinity's reflux (Long Breath).
func _vent_hottest(amount: float) -> void:
	var hottest := ""
	for aff: String in reflux_by:
		if hottest == "" or float(reflux_by[aff]) > float(reflux_by[hottest]):
			hottest = aff
	if hottest != "":
		reflux_by[hottest] = maxf(0.0, float(reflux_by[hottest]) - amount)


## Stores run down: swallowed light after a while; held blood thins out of a fight.
func _tick_stores(delta: float) -> void:
	for id: String in stores.keys():
		var s: Dictionary = stores[id]
		s["t"] = float(s["t"]) - delta
		if float(s["t"]) <= 0.0:
			stores.erase(id)
	if held_blood > 0 and not in_combat:
		_blood_thin_t += delta
		if _blood_thin_t >= float(GameData.affinity("blood").get("held_blood_thin_s", 5.0)):
			_blood_thin_t = 0.0
			held_blood -= 1


## Add to a store (`swallowed`): up to `cap`, lasting `life` from the last gain.
func store_add(id: String, n: int, cap: int, life: float) -> void:
	var s: Dictionary = stores.get(id, {"n": 0, "t": 0.0})
	s["n"] = mini(cap, int(s["n"]) + n)
	s["t"] = life
	stores[id] = s


## Take everything in a store. Returns how much there was.
func store_take(id: String) -> int:
	var n: int = int((stores.get(id, {}) as Dictionary).get("n", 0))
	stores.erase(id)
	return n


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
	if conduct and bool(target.call("has_status", "soaked")) and not (target.has_method("no_conduct") and bool(target.call("no_conduct"))):
		for node: Node in get_tree().get_nodes_in_group("enemies"):
			if node != target and bool(node.call("has_status", "soaked")) and not (node.has_method("no_conduct") and bool(node.call("no_conduct"))) \
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
## It may first draw them in (pull_before_blast), spend something you carry (held blood, swallowed
## light, pips) for more, spend a status on each target (consume_status), throw spall off armour,
## cut your growth back for more, put fires out, blow clouds and shots away, and leave ground behind.
func _burst(ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var reach: float = melee_range + float(ab.get("reach_bonus", 0.0))
	var half: float = deg_to_rad(float(ab["arc_deg"]) * 0.5) if ab.has("arc_deg") else melee_arc
	_strike_t = 0.25
	_swing_visual(reach, true, false)
	var payload: Dictionary = _payload(ab, "on_hit")
	if ab.has("damage_from_heat"):
		# the heat is the damage, and it is spent: what you carry above the floor goes into the blow
		var own: String = str(ab["affinity"])
		var carried: float = reflux_of(own)
		var floor_at: float = float(ab.get("heat_floor", 0.0))
		payload["damage"] = float(ab["damage_from_heat"]) * maxf(0.0, carried - floor_at)
		reflux_by[own] = minf(carried, floor_at)
		tags = tags + ["cold"]
	# a store spent for more: held blood (Outpour), swallowed light (Night Spill)
	var store: String = str(ab.get("consume", ""))
	if store != "":
		var n: int = spend_blood(-1 if str(ab.get("spend_blood", "all")) == "all" else int(ab.get("spend_blood", 0))) if store == "held_blood" else store_take(store)
		payload["damage"] = float(payload.get("damage", ab.get("damage", 0.0))) + float(ab.get("per_stack_damage", 0.0)) * float(n)
		if ab.has("daze_at") and n >= int(ab["daze_at"]):
			var dazes: Array = (payload.get("statuses", []) as Array).duplicate()
			dazes.append({"id": "dazed", "stacks": 1})
			payload["statuses"] = dazes
		if int(ab.get("pools_per_two_spent", 0)) > 0:
			for i: int in int(n / 2) * int(ab["pools_per_two_spent"]):
				spill_blood(global_position + _facing.rotated(Vector3.UP, randf_range(-half, half)) * randf_range(1.0, reach), 1)
	# pips spent for more (Blowout)
	if ab.has("spend_pips") and has_slipstream():
		var burned: int = spend_pips(int(ab["spend_pips"]))
		payload["damage"] = float(payload.get("damage", 0.0)) + float(ab.get("pip_damage", 0.0)) * float(burned)
		payload["shove"] = float(payload.get("shove", 0.0)) + float(ab.get("pip_shove", 0.0)) * float(burned)
	# your growth in the arc is cut back to a sprout, each patch adding to the blow (Reaping Sweep)
	if float(ab.get("patch_bonus", 0.0)) > 0.0:
		var cut := 0
		for g: Node in get_tree().get_nodes_in_group("growth"):
			var patch := g as GrowthPatch
			if patch == null or patch.caster != self:
				continue
			var to_g: Vector3 = patch.global_position - global_position
			to_g.y = 0.0
			if to_g.length() <= reach + patch.radius and (to_g.length() < 0.3 or _facing.angle_to(to_g.normalized()) <= half):
				patch.cut_back()
				cut += 1
		var more: float = minf(float(ab.get("patch_bonus_max", 0.6)), float(ab["patch_bonus"]) * float(cut))
		if payload.has("damage_mult"):
			payload["damage_mult"] = float(payload["damage_mult"]) * (1.0 + more)
		elif payload.has("damage"):
			payload["damage"] = float(payload["damage"]) * (1.0 + more)
		essence = minf(essence_max, essence + float(ab.get("per_patch_essence", 0.0)) * float(cut))
	# drawn in first (Backdraft)
	if bool(ab.get("pull_before_blast", false)) and float(ab.get("pull", 0.0)) > 0.0:
		for e: Node3D in _enemies_near(global_position, reach + 2.0):
			e.set("shover", self)
			e.call("pull_toward", global_position, float(ab["pull"]), float(e.get("radius")) + 0.6)
	var hits := 0
	var gained := 0
	for t: Node3D in _in_arc(reach, half):
		if bool(ab.get("needs_clear_line", false)) and not _ray(global_position + Vector3.UP, t.global_position + Vector3.UP).is_empty():
			continue
		if bool(ab.get("douses", false)) and bool(t.call("has_status", "alight")):
			t.call("clear_status", "alight")
			gained += 1
		var p: Dictionary = payload
		if ab.has("consume_status"):
			# each target's own stacks are spent on it (Clotblade)
			var c_id: String = str(ab["consume_status"])
			var n2: int = int(t.call("status_stacks", c_id)) if bool(t.call("has_status", c_id)) else 0
			if n2 > 0:
				t.call("clear_status", c_id)
				p = payload.duplicate()
				p["damage"] = float(p.get("damage", 0.0)) + float(ab.get("per_stack_damage", 0.0)) * float(n2)
				p["poise"] = float(p.get("poise", GameData.num("combat", "skill_poise"))) + float(ab.get("per_stack_poise", 0.0)) * float(n2)
		var metal: int = int(t.call("metal_class")) if t.has_method("metal_class") else 0
		var where: Vector3 = t.global_position
		if apply_hit(t, p, tags, stage_mult) != null or p.has("status") or p.has("statuses"):
			hits += 1
		if ab.has("spall") and metal > 0:
			var sp: Dictionary = ab["spall"]
			for o: Node3D in _enemies_near(where, float(sp.get("radius", 2.5))):
				if o != t:
					deal_damage(o, float(sp.get("damage_per_class", 30.0)) * float(metal) * stage_mult, tags + ["spall"])
	if hits > 0:
		if float(ab.get("essence_per_hit", 0.0)) > 0.0:
			essence = minf(essence_max, essence + float(ab["essence_per_hit"]) * float(mini(hits, int(ab.get("essence_max_hits", 99)))))
		if int(ab.get("swallow_per_hit", 0)) > 0:
			store_add("swallowed", int(ab["swallow_per_hit"]) * hits + gained, 5, 12.0)
		if int(ab.get("gain_pips_per_hit", 0)) > 0 and has_slipstream():
			pips = mini(GameData.inum("slipstream", "max"), pips + mini(int(ab.get("gain_pips_max", 99)), int(ab["gain_pips_per_hit"]) * hits))
	if bool(ab.get("douses", false)):
		for z: Node in get_tree().get_nodes_in_group("ground_zones"):
			if bool(z.get("bright")) and z.get("caster") == self and bool(z.call("has_point", global_position, reach)):
				z.call("end")
	if bool(ab.get("clears_clouds", false)):
		for z2: Node in get_tree().get_nodes_in_group("ground_zones"):
			if str(z2.get("kind")) == "cloud" and bool(z2.call("has_point", global_position, reach)):
				z2.call("end")
	if bool(ab.get("kill_projectiles", false)):
		for node: Node in get_tree().get_nodes_in_group("enemy_shots"):
			var shot := node as Node3D
			if shot != null and shot.global_position.distance_to(global_position) <= reach:
				shot.queue_free()
	if ab.has("zone"):
		_lay_ground(ab["zone"], reach, ab, tags)
	if ab.has("leave_zone"):
		lay_cloud(global_position, ab["leave_zone"], tags + ["cloud"])
	if bool(ab.get("shatters_all_stone", false)):
		for s: Variant in stones.duplicate():
			if is_instance_valid(s):
				(s as Stone).shatter((s as Stone).global_position - global_position, self)
	if bool(ab.get("shatters_stone", false)):
		for s: Variant in stones.duplicate():
			if is_instance_valid(s) and _stone_in_arc(s as Stone, reach, half):
				(s as Stone).shatter(_facing, self)


## True if the next `step` metres along `dir` would run into an enemy. A dash that punches through
## armour (Breakthrough) is only stopped by a bare body.
func _body_ahead(dir: Vector3, step: float) -> Node3D:
	if not is_inside_tree():
		return null
	var a := Vector2(global_position.x, global_position.z)
	var b: Vector2 = a + Vector2(dir.x, dir.z) * step
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Node3D
		if e == null or bool(e.call("is_dead")):
			continue
		if _dash_pass_armoured and e.has_method("metal_class") and int(e.call("metal_class")) >= 1:
			continue
		var p := Vector2(e.global_position.x, e.global_position.z)
		# only bodies in front count - one you are already past or beside does not stop you
		if (p - a).dot(Vector2(dir.x, dir.z)) > 0.0 and Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= 0.4 + float(e.get("radius")):
			return e
	return null


## A dash is over: what it does where it arrives (Burrow, a grapple), and the trail it leaves.
func _end_dash() -> void:
	if not is_inside_tree():
		return
	if not _dash_on_arrive.is_empty():
		for e: Node3D in _enemies_near(global_position, _dash_arrive_radius):
			apply_hit(e, _dash_on_arrive, _dash_tags, _dash_stage_mult)
		if bool(_dash_ab.get("shatters_stone", false)):
			for s: Variant in stones.duplicate():
				if is_instance_valid(s) and (s as Stone).global_position.distance_to(global_position) <= _dash_arrive_radius + 1.5:
					(s as Stone).shatter((s as Stone).global_position - global_position, self)
		_dash_on_arrive = {}
	if _dash_ab.has("leave_growth"):
		plant_growth(global_position, _dash_ab["leave_growth"])
	_dash_ab = {}
	_dash_pass_armoured = false
	if _dash_trail.is_empty():
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
			if _dash_pass_armoured and int(e.call("metal_class")) < 1:
				continue                          # a bare body stops it instead (on_stop)
			# a shove "along" goes the way the dash goes, not away from you
			var way: Vector3 = _dash_vel.normalized() if str(_dash_pass.get("shove_dir", "")) == "along" else Vector3.ZERO
			apply_hit(e, _dash_pass, _dash_tags, _dash_stage_mult, way)


## beam: an instant line along the facing. Walls and blocks stop it; it lands on the first enemy,
## or on every enemy along it if it pierces. It may jump on from the first (Arc Lash) and glance off
## walls and stone (bounces).
func _fire_beam(ab: Dictionary, stage_mult: float, color: Color, tags: Array) -> void:
	var origin: Vector3 = global_position + Vector3.UP * 0.9
	var dir: Vector3 = _facing
	var left: float = float(ab.get("range", 9.0))
	var legs: int = int(ab.get("bounces", 0)) + 1
	var first: Node3D = null
	for leg: int in legs:
		var hit: Dictionary = _beam_leg(origin, dir, left, ab, stage_mult, color, tags)
		if first == null and hit.get("first") != null:
			first = hit["first"]
		left -= float(hit["length"])
		if hit.get("normal") == null or left <= 0.2 or leg == legs - 1:
			break
		var n: Vector3 = hit["normal"]
		n.y = 0.0
		if n.length() < 0.01:
			break
		origin = (hit["end"] as Vector3) + n.normalized() * 0.05
		dir = dir.bounce(n.normalized())
		dir.y = 0.0
		dir = dir.normalized()
	if first != null and int(ab.get("jumps", 0)) > 0:
		_arc_on(first, _payload(ab, "on_hit"), tags + ["arc"], stage_mult, int(ab["jumps"]), float(ab.get("jump_radius", 4.0)))


## One straight stretch of a beam: {length, end, normal (where it met a wall, or null), first}.
func _beam_leg(origin: Vector3, dir: Vector3, reach_in: float, ab: Dictionary, stage_mult: float, color: Color, tags: Array) -> Dictionary:
	var reach: float = reach_in
	var normal: Variant = null
	var wall: Dictionary = _ray(origin, origin + dir * reach)
	if not wall.is_empty():
		reach = origin.distance_to(wall["position"])
		normal = wall["normal"]
	var on_line: Array = []
	for node: Node in get_tree().get_nodes_in_group("hittable"):
		var t := node as Node3D
		if t == null or bool(t.get("is_scenery")):
			continue
		var to: Vector3 = t.global_position - origin
		to.y = 0.0
		var along: float = to.dot(dir)
		var r: float = float(t.get("radius"))
		if along < 0.0 or along > reach + r:
			continue
		if (to - dir * along).length() <= float(ab.get("width", ab.get("line_width", 0.6))) * 0.5 + r:
			on_line.append([along, t])
	on_line.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var first: Node3D = null
	var stop: float = reach
	for row: Array in on_line:
		var t2: Node3D = row[1]
		if first == null:
			first = t2
		apply_hit(t2, _payload(ab, "on_hit"), tags, stage_mult, dir)
		if not bool(ab.get("pierce", false)) or (t2.has_method("blocks_shot") and bool(t2.call("blocks_shot", origin))):
			stop = float(row[0])
			normal = null
			break
	_strike_t = 0.2
	_line_visual(origin, origin + dir * stop, color)
	return {"length": stop, "end": origin + dir * stop, "normal": normal, "first": first}


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
## Arriving behind an enemy (Shadow Slip) you face its back, and your next hit is from behind.
func _blink(spot: Vector3, ab: Dictionary, stage_mult: float, color: Color, tags: Array) -> void:
	var from: Vector3 = global_position
	_line_visual(from + Vector3.UP, spot + Vector3.UP, color)
	var step: Vector3 = spot - from
	step.y = 0.0
	if step.length() > 0.2:
		_facing = step.normalized()
	if float(ab.get("rear_window", 0.0)) > 0.0:
		_rear_window_t = float(ab["rear_window"])
	var foe: Node3D = _nearest_enemy_to(spot, 2.0)
	if bool(ab.get("arrive_behind", false)) and foe != null:
		var to_foe: Vector3 = foe.global_position - spot
		to_foe.y = 0.0
		if to_foe.length() > 0.1:
			_facing = to_foe.normalized()
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
	_rig_action("heavy")
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
	var action: String = "ability_%d" % (slot + 1)
	_cast_action = action if InputMap.has_action(action) and Input.is_action_pressed(action) else ""
	cast_ability(hotbar[slot])
	_cast_action = ""


## Test characters only: show the next six learned skills on the bar (a test-only "next page").
func next_hotbar_page() -> void:
	if not test_character or abilities.is_empty():
		return
	var per: int = hotbar.size()
	var pages: int = int(ceil(float(abilities.size()) / float(per)))
	hotbar_page = (hotbar_page + 1) % maxi(1, pages)
	for i: int in per:
		var idx: int = hotbar_page * per + i
		hotbar[i] = idx if idx < abilities.size() else -1
	note("Skill bar: page %d of %d." % [hotbar_page + 1, pages])


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
	if not _held.is_empty():
		_end_held()                              # a new cast lets go of what you were holding
		return
	var heat: float = reflux_of(aff)
	var cost: float = float(ab["cost"]) * (float(_reflux_cfg["pain_cost_mult"]) if heat >= float(_reflux_cfg["pain_at"]) else 1.0)
	# Winded: the dash is not free. A second movement skill too soon costs double, in essence and heat.
	var kind: String = str(ab["kind"])
	var movement: bool = kind == "dash" or kind == "blink" or kind == "grapple" or kind == "streak"
	var winded: bool = movement and _winded_t > 0.0 and not bool(ab.get("clears_winded", false))
	if winded:
		cost *= GameData.num("combat", "winded_cost_mult")
	var per_second: bool = bool(ab.get("cost_per_s", false)) or kind == "channel"
	if per_second:
		cost = 0.0                               # a channel pays as it is held (see _tick_held)
	if essence < cost or (per_second and essence < float(ab["cost"]) * 0.25):
		note("Not enough essence for %s." % str(ab["name"]))
		return
	if float(ab.get("heat_cost", 0.0)) > 0.0 and heat < float(ab["heat_cost"]):
		note("%s needs %d heat." % [str(ab["name"]), int(ab["heat_cost"])])
		return
	# Some skills need something to point at; find out before anything is spent.
	var strike_target: Node3D = null
	var blink_to := Vector3.ZERO
	var reach: float = float(ab["range"]) if ab.has("range") else reach_now() + float(ab.get("range_bonus", 0.0))
	if kind == "targeted_strike" or kind == "chain" or (kind == "displace" and str(ab.get("mode", "")) == "pull_target") \
			or (kind == "smite" and not bool(ab.get("nearest_to_point", false))) or (kind == "channel" and str(ab.get("shape", "")) == "tether") \
			or (kind == "detonate" and str(ab.get("gather_into", "")) == "target"):
		strike_target = _skill_target(reach)
		if strike_target != null and kind == "smite" and GameData.balance["skills"].get("smite_needs_line", true) \
				and not bool((ab.get("on_hit", {}) as Dictionary).get("through", false)) \
				and not _ray(global_position + Vector3.UP, strike_target.global_position + Vector3.UP).is_empty():
			strike_target = null                 # a wall or stone stands between
		if strike_target == null:
			note("%s needs someone within reach." % str(ab["name"]))
			return
	elif kind == "smite":
		blink_to = _aim_point(reach)
		strike_target = _nearest_enemy_to(blink_to, reach)
		if strike_target == null:
			note("%s needs someone near where you point." % str(ab["name"]))
			return
	elif kind == "blink" or kind == "grapple":
		var spot: Variant = _blink_point(float(ab.get("range", 6.0)))
		var special: Variant = _special_landing(ab)
		if special != null:
			spot = special
		elif bool(ab.get("needs_shadow", false)) and spot != null and not Light.is_dark(get_tree(), spot):
			note("There is no shadow there to rise from.")
			return
		if spot == null:
			note("There is no way through to there.")
			return
		blink_to = spot
	elif kind == "prop" and str(ab.get("shape", "")) == "":
		var where: Variant = _prop_point(ab)
		if where == null:
			note("There is no room to raise stone there.")
			return
		blink_to = where
	elif kind == "displace" or kind == "delayed_blast" or kind == "ground_zone" or kind == "rod" or kind == "prop" or kind == "seed" \
			or kind == "summon" or (kind == "field_pulse" and ab.has("range")) or (kind == "charge_release" and str(ab.get("release", "")) == "delayed_blast"):
		blink_to = _aim_point(float(ab.get("range", 8.0)))
	if kind == "summon" or str(ab.get("needs", "")).begins_with("corpse"):
		var body_at: Fallen = Fallen.nearest(get_tree(), blink_to, float(GameData.num("skills", "jump_radius")))
		if body_at == null:
			note("%s needs a body where you point." % str(ab["name"]))
			return
		blink_to = body_at.global_position
	essence -= cost
	if float(ab.get("heat_cost", 0.0)) > 0.0:
		reflux_by[aff] = heat - float(ab["heat_cost"])          # paid in heat, not essence (Wickpinch)
	else:
		reflux_by[aff] = heat + cost * float(ab["reflux_per_cost"])
	if float(ab.get("vent_reflux", 0.0)) > 0.0:
		reflux_by[aff] = maxf(0.0, reflux_of(aff) - float(ab["vent_reflux"]))
	_advance(state, maxf(cost, float(ab["cost"]) * 0.5))
	if movement:
		if winded:
			_float("winded", Color(0.8, 0.8, 0.9))
		if bool(ab.get("clears_winded", false)):
			_winded_t = 0.0
		if not bool(ab.get("never_winds", false)):
			_winded_t = GameData.num("combat", "winded_s")
	if not _cast_is_quiet():
		_unseen_reveal_t = float(GameData.affinity("dark").get("reveal_s", 1.0))     # casting shows you for a moment

	var stage_mult: float = ability_damage_mult(int(state["stage"])) * float(ab.get("damage_all", 1.0))
	var tags: Array = ["ability", aff, str(state["id"])]
	var windup: float = float(ab.get("windup", 0.0))
	if kind == "prop" or kind == "delayed_blast" or kind == "ground_zone" or kind == "rod" or kind == "seed" or kind == "summon" \
			or (kind == "displace" and strike_target == null) or (kind == "smite" and strike_target != null):
		var to_spot: Vector3 = (strike_target.global_position if (kind == "smite" and strike_target != null) else blink_to) - global_position
		to_spot.y = 0.0
		if to_spot.length() > 0.2:
			_facing = to_spot.normalized()
	if bool(ab.get("breaks_aim", false)):
		for node: Node in get_tree().get_nodes_in_group("enemies"):
			if str(node.get("behaviour")) == "ranged" and float(node.get("_windup")) >= 0.0:
				node.call("interrupt")           # everyone aiming at you loses the aim
	if bool(ab.get("frees_caster", false)):
		_stagger_t = 0.0
		_shoved_left = 0.0
	# held skills start now and do their work while held
	if kind == "channel" or kind == "charge_release":
		_start_held(ab, kind, aff, stage_mult, tags, strike_target, blink_to, state)
	# Stone starts rising at once; everything else with a wind-up goes off when it ends.
	elif windup <= 0.0 or kind == "prop" or kind == "delayed_blast":
		_perform_cast(ab, kind, aff, stage_mult, tags, strike_target, blink_to)
	if kind != "rod":
		_rod_relay(aff, stage_mult)
	if windup > 0.0:
		_windup_t = windup
		_windup_total = windup
		_windup = {"ab": ab, "kind": kind, "aff": aff, "stage_mult": stage_mult, "tags": tags, "target": strike_target, "point": blink_to,
			"facing": _facing, "braced": bool(ab.get("braced", false)), "release": kind != "prop" and kind != "delayed_blast"}
		has_move_goal = false
		attack_target = null
		pickup_target = null
		if bool(ab.get("braced", false)):
			_float("braced", GameData.affinity_color(aff).lightened(0.3))

	# A skill takes a moment to finish; running hot makes that moment longer (it no longer hurts).
	var recovery: float = float(ab.get("recovery", GameData.num("abilities", "cast_recovery"))) * buff_num("recovery_mult")
	if heat >= float(_reflux_cfg["burn_at"]):
		recovery = recovery * float(_reflux_cfg["burn_recovery_mult"]) + float(_reflux_cfg["burn_recovery_add"])
		_float("seizing", Color(1, 0.5, 0.2))
	if movement:
		# the recovery starts when the movement ends, so the dash itself is not eaten by it
		recovery = maxf(recovery, float(ab.get("dash_time", 0.0)) + (0.0 if bool(ab.get("no_recovery", false)) else GameData.num("combat", "dash_recovery_s")))
	_recover_t = windup + recovery
	_melee_cd = maxf(_melee_cd, windup + recovery)
	# Braced on any skill (a braced word, or a braced skill with no wind-up): for the cast and its recovery
	if bool(ab.get("braced", false)) and windup <= 0.0 and kind != "dash":
		_brace_t = recovery
	if str(ab.get("self_status", "")) != "":
		_take_state(str(ab["self_status"]), float(ab.get("self_status_s", 2.0)))

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
	if (kind == "targeted_strike" or kind == "chain") and strike_target == null:
		return                                   # whoever it was meant for is gone
	if _rig != null and _rig.has_method("play_action"):
		# a real body plays the motion that fits; a strike is left to animate(), which swings
		var motion: String = {"dash": "dodge", "blink": "dodge", "detonate": "cast_area", "self_buff": "cast_area"}.get(kind, "cast")
		if kind == "melee_burst" and float(ab.get("arc_deg", 0.0)) >= 360.0:
			motion = "cast_area"
		if kind != "targeted_strike" and not (kind == "melee_burst" and motion == "cast"):
			_rig.call("play_action", motion)
	match kind:
		"projectile":
			_fire_projectile(ab, stage_mult, GameData.affinity_color(aff), tags + ["projectile"])
		"melee_burst":
			if float(ab.get("self_harm", 0.0)) > 0.0:     # only a build that earns it; no ability has it by default
				var hurt: float = body.apply_self_harm(float(ab["self_harm"]))
				_float("-%d" % int(hurt), Color(1, 0.4, 0.3))
			_burst(ab, stage_mult, tags if bool(ab.get("not_melee", false)) else tags + ["melee"])
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
			_dash_braced = bool(ab.get("braced", false))
			_dash_on_stop = ab.get("on_stop", {})
			_dash_heavy_poise = float(ab.get("heavy_poise", 0.0))
			_dash_color = GameData.affinity_color(aff)
			_dash_on_arrive = ab.get("on_arrive", {})
			_dash_arrive_radius = float(ab.get("arrive_radius", 1.5))
			_dash_pass_armoured = bool(ab.get("pass_armoured", false))
			_dash_ab = ab
			_dash_stage_mult = stage_mult
			if bool(ab.get("pass_armoured", false)):
				_dash_stops = true                     # bare bodies stop it; armoured ones it punches through (_body_ahead)
			# blood pools along the way carry you further (Thinblood Rush)
			if float(ab.get("pool_bonus_m", 0.0)) > 0.0:
				var crossed: int = _pools_along(global_position, global_position + dir * float(ab["dash_speed"]) * float(ab["dash_time"]))
				crossed = mini(crossed, int(ab.get("pool_bonus_max", 2)))
				_dash_time += float(ab["pool_bonus_m"]) * float(crossed) / float(ab["dash_speed"])
			# what it leaves where it started: a phantom of you, a little cloud
			if ab.has("leave_decoy"):
				_leave_lure(global_position, ab["leave_decoy"], aff, tags)
			if ab.has("leave_zone") and str((ab["leave_zone"] as Dictionary).get("at", "start")) == "start":
				lay_cloud(global_position, ab["leave_zone"], tags + ["cloud"])
			if float(ab.get("after_speed_mult", 0.0)) > 0.0:
				buffs["after_" + str(ab.get("name", "dash")).to_lower()] = {"t": float(ab.get("duration", 2.0)) + float(ab["dash_time"]), "move_speed_mult": float(ab["after_speed_mult"])}
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
				spent = int(strike_target.call("status_stacks", str(ab["consume_status"]))) if bool(strike_target.call("has_status", str(ab["consume_status"]))) else 0
				for alt: String in (ab.get("consume_counts", {}) as Dictionary):
					if bool(strike_target.call("has_status", alt)):
						spent = maxi(spent, int(ab["consume_counts"][alt]))     # Waterlogged counts as two Soaks
						strike_target.call("clear_status", alt)
				if spent > 0:
					strike_target.call("clear_status", str(ab["consume_status"]))
					deal_damage(strike_target, float(ab.get("per_stack_damage", 0.0)) * float(spent) * stage_mult, tags + ["melee", "burst"])
			if is_instance_valid(strike_target) and not bool(strike_target.call("is_dead")):
				apply_hit(strike_target, strike_payload, strike_tags, stage_mult)
			if (spent > 0 or bool(ab.get("burst_always", false))) and ab.has("burst"):
				var centre: Vector3 = strike_target.global_position if is_instance_valid(strike_target) else global_position + _facing * 1.5
				for node: Node in get_tree().get_nodes_in_group("enemies"):
					var near := node as Node3D
					var self_too: bool = bool(ab.get("burst_always", false))      # Thunderclap's crack takes the target too
					if near != null and (near != strike_target or self_too) and near.global_position.distance_to(centre) <= float(ab.get("burst_radius", 2.0)) + float(near.get("radius")):
						apply_hit(near, ab["burst"], tags + ["burst"], stage_mult)
			if spent > 0 and ab.has("burst_zone"):
				var bz: Dictionary = (ab["burst_zone"] as Dictionary).duplicate()
				bz["payload"] = bz.get("payload", {"status": "infected"})
				lay_cloud(strike_target.global_position if is_instance_valid(strike_target) else global_position, bz, tags + ["cloud"])
			_melee_cd = float(_p["melee_cooldown"])
		"blink":
			_blink(blink_to, ab, stage_mult, GameData.affinity_color(aff), tags)
		"prop":
			_raise_prop(blink_to, ab, stage_mult, tags)
		"displace":
			_displace(blink_to, strike_target, ab, stage_mult, tags)
		"delayed_blast":
			_start_blast(blink_to, ab, stage_mult, tags)
		"detonate":
			_detonate(ab, stage_mult, tags, strike_target)
		"ground_zone":
			_lay_zone(blink_to, ab, stage_mult, tags)
		"self_buff":
			_take_buff(ab)
		"rod":
			_plant_rod(blink_to, ab)
		"chain":
			_chain(strike_target, ab, stage_mult, tags)
		"smite":
			_smite(strike_target, blink_to, ab, stage_mult, tags)
		"summon":
			_summon(blink_to, ab, stage_mult, tags)
		"seed":
			_sow(blink_to, ab, stage_mult, tags)
		"grapple":
			_grapple(blink_to, ab, stage_mult, tags)
		"streak":
			_streak(ab, stage_mult, tags)
		"field_pulse":
			_field_pulse(blink_to, ab, stage_mult, tags)
	_repeat_cast(ab, kind, aff, stage_mult, tags, strike_target, blink_to)


## A sealed word's great ring (design/14 section 8) makes the skill come round again: the same cast,
## at "mult" of its strength, "delay_s" later ("times" in all). Generic: it is the rune patch's
## "rune_repeat" field, read here for any skill; which kinds may repeat is the rule set's data.
func _repeat_cast(ab: Dictionary, kind: String, aff: String, stage_mult: float, tags: Array, strike_target: Node3D, blink_to: Vector3) -> void:
	var rep: Variant = ab.get("rune_repeat")
	if typeof(rep) != TYPE_DICTIONARY or not is_inside_tree() or get_parent() == null:
		return
	var echo: Dictionary = ab.duplicate(true)
	echo.erase("rune_repeat")                    # the echo itself does not repeat
	var mult: float = float((rep as Dictionary).get("mult", 0.0))
	var delay: float = float((rep as Dictionary).get("delay_s", 0.4))
	var times: int = maxi(1, int((rep as Dictionary).get("times", 1)))
	var target: Node3D = strike_target
	SkillTimer.after(get_parent(), delay, func(n: int) -> void:
		if dead or not is_inside_tree():
			return
		var t: Node3D = target if target != null and is_instance_valid(target) and not bool(target.call("is_dead")) else null
		_perform_cast(echo, kind, aff, stage_mult * pow(mult, float(n + 1)), tags, t, blink_to), times - 1, delay)


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
	# a locked rune word reshapes the skill (design/14 section 7; the rule set's effects patch)
	if state.has("word"):
		apply_rune_patch(ab, Runes.active().locked_effects(state["word"], RuneContext.of(state, affinities)).get("patch", []))
	ab["cost"] = float(ab["cost"]) * inventory.stat("cost_mult", true)
	return ab


## Apply a rune effects patch to an ability dictionary, op by op: {op, path ("a.b" for nested), value}.
## mul / mul_round / min only touch numbers that are there; add, set and append create what they
## need. The patch format is the rule sets' (RuneInteraction.on_effects); nothing here knows runes.
static func apply_rune_patch(ab: Dictionary, patch: Array) -> void:
	for p: Dictionary in patch:
		var keys: PackedStringArray = str(p.get("path", "")).split(".")
		var last: String = keys[keys.size() - 1]
		var holder: Dictionary = ab
		var make: bool = str(p["op"]) in ["add", "set", "append", "max"]
		var ok := true
		for k: int in keys.size() - 1:
			if not holder.has(keys[k]) or typeof(holder[keys[k]]) != TYPE_DICTIONARY:
				if not make:
					ok = false
					break
				holder[keys[k]] = {}
			holder = holder[keys[k]]
		if not ok:
			continue
		var cur: Variant = holder.get(last)
		var is_num: bool = typeof(cur) == TYPE_FLOAT or typeof(cur) == TYPE_INT
		match str(p["op"]):
			"mul":
				if is_num:
					holder[last] = float(cur) * float(p["value"])
			"mul_round":
				if is_num:
					holder[last] = int(round(float(cur) * float(p["value"])))
			"mul_gap":
				# a multiplier's distance from 1 scales: 0.75 at x1.2 is 0.70, 1.4 at x1.2 is 1.48
				if is_num:
					holder[last] = 1.0 + (float(cur) - 1.0) * float(p["value"])
			"min":
				if is_num:
					holder[last] = minf(float(cur), float(p["value"]))
			"max":
				# the larger of what is there and the value (creates it when absent)
				holder[last] = maxf(float(cur), float(p["value"])) if is_num else float(p["value"])
			"add":
				if typeof(p["value"]) == TYPE_INT and (cur == null or typeof(cur) == TYPE_INT):
					holder[last] = (int(cur) if cur != null else 0) + int(p["value"])
				else:
					holder[last] = (float(cur) if is_num else 0.0) + float(p["value"])
			"set":
				holder[last] = p["value"]
			"erase":
				holder.erase(last)
			"append":
				if typeof(cur) != TYPE_ARRAY:
					holder[last] = []
				(holder[last] as Array).append(p["value"])


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


# --- rune words and seals (design/14 sections 7-8) -------------------------------------------
# A skill's word is saved on its ability state as "word" (RuneWord: nodes on rings + links, no rules
# in it). Brent 2026-10-23: a skill just levels until its bar is full; binding a construct into it
# is when its runes are SEALED, one ring per level. Before the first binding a skill has no word.
# The seal is drafted on a copy (seal_draft) while the seal screen is open - inner rings may be
# reworked and the new ring added - and becomes the skill's word only if the bind takes; a failed
# bind forms no seal. A test character has a free edit instead: any rune, any time.
# Whether a change is allowed, and what the word is, is asked of the rule set in force
# (Runes.active()).

## What the rule set may know about ability `index` - the draft's context while it is being sealed.
func rune_context(index: int) -> RuneContext:
	if index < 0 or index >= abilities.size():
		return RuneContext.of({}, affinities)
	var drafting: bool = sealing_index() == index
	var c: RuneContext = RuneContext.of(abilities[index], affinities, drafting and seal_mode() == "bind")
	if drafting and seal_mode() == "test":
		c.free_edit = true
		c.rings = maxi(1, c.stage)
	return c


## The word of ability `index`: the draft while it is being sealed, else its sealed word, else a word
## holding just the skill's own rune (no word yet).
func ability_word(index: int) -> Dictionary:
	if index < 0 or index >= abilities.size():
		return RuneWord.make("")
	if sealing_index() == index:
		return seal_draft["word"]
	return _sealed_word(index)


## The skill's own word, never the draft.
func _sealed_word(index: int) -> Dictionary:
	var st: Dictionary = abilities[index]
	if st.has("word"):
		return st["word"]
	return RuneWord.make(GameData.skill_anchor(str(st["id"])), Runes.active().id)


## The ability being sealed (-1: none).
func sealing_index() -> int:
	return int(seal_draft.get("index", -1)) if not seal_draft.is_empty() else -1


## "bind", "test", or "" when no seal is being drafted.
func seal_mode() -> String:
	return str(seal_draft.get("mode", ""))


## The construct a "bind" draft will bind (-1: none).
func seal_construct() -> int:
	return int(seal_draft.get("construct", -1))


## A fresh draft of ability `index`: its sealed word, unsealed, its rings made explicit.
func _draft_from(index: int) -> Dictionary:
	var w: Dictionary = _sealed_word(index).duplicate(true)
	for key: String in ["sealed", "locked", "free_edit"]:
		w.erase(key)
	w["rings"] = RuneWord.rings(w)
	w["made_under"] = Runes.active().id
	return w


## Open the seal of ability `index` for binding construct `construct_index` into it: the draft starts
## as the sealed word, with room for one more ring. Returns {ok, reason, text}.
func open_seal(index: int, construct_index: int) -> Dictionary:
	if index < 0 or index >= abilities.size():
		return RuneRules.no("no_skill", "No such skill.")
	var need: String = pending_tier(abilities[index])
	if need == "":
		return RuneRules.no("not_ready", "%s is not ready for a binding: its bar is not full." % str(GameData.ability(str(abilities[index]["id"])).get("name", "?")))
	if construct_index < 0 or construct_index >= constructs.size():
		return RuneRules.no("no_construct", "You carry no such construct.")
	if str(constructs[construct_index]["tier"]) != need:
		return RuneRules.no("wrong_tier", "It needs a %s." % need)
	seal_draft = {"index": index, "construct": construct_index, "mode": "bind", "word": _draft_from(index)}
	return RuneRules.ok()


## A test character's free edit of ability `index`: every rune, any time, sealed when it says so.
func open_free_edit(index: int) -> Dictionary:
	if index < 0 or index >= abilities.size():
		return RuneRules.no("no_skill", "No such skill.")
	if not test_character:
		return RuneRules.no("not_test", "Only a test character can edit a word freely; runes are sealed at a binding.")
	seal_draft = {"index": index, "construct": -1, "mode": "test", "word": _draft_from(index)}
	return RuneRules.ok()


func close_seal() -> void:
	seal_draft = {}


## Put the draft back as the sealed word was.
func draft_reset() -> void:
	if not seal_draft.is_empty():
		seal_draft["word"] = _draft_from(sealing_index())


## The draft differs from the skill's sealed word.
func draft_changed() -> bool:
	if seal_draft.is_empty():
		return false
	return RuneWord.shape_key(seal_draft["word"]) != RuneWord.shape_key(_draft_from(sealing_index()))


## May the open draft be bound? Unchanged (the word stays as it is) or a seal the rules accept.
## {ok, reason, text, unchanged}.
func can_bind_seal() -> Dictionary:
	if seal_mode() != "bind":
		return RuneRules.no("not_sealing", "No binding is being prepared.")
	var c: int = seal_construct()
	if c < 0 or c >= constructs.size() or pending_tier(abilities[sealing_index()]) != str(constructs[c]["tier"]):
		return RuneRules.no("no_construct", "The construct is no longer here to bind.")
	if not draft_changed():
		var r: Dictionary = RuneRules.ok()
		r["unchanged"] = true
		return r
	return Runes.active().can_seal(seal_draft["word"], rune_context(sealing_index()))


## Bind the draft's construct and, if the bind takes, seal the draft as the skill's word (one ring per
## level). A failed bind (the existing roll) forms no seal: the word stays as it was. Returns what
## bind_construct returns ("bound", "failed", ...) or why it could not be tried.
func bind_seal(roll: float = -1.0) -> String:
	var check: Dictionary = can_bind_seal()
	if not bool(check["ok"]):
		return str(check["text"])
	var index: int = sealing_index()
	var draft: Dictionary = (seal_draft["word"] as Dictionary).duplicate(true)
	var changed: bool = not bool(check.get("unchanged", false))
	var result: String = bind_construct(index, seal_construct(), roll)
	close_seal()
	var st: Dictionary = abilities[index]
	var skill: String = str(GameData.ability(str(st["id"])).get("name", "?"))
	if result == "bound" and changed:
		var after: RuneContext = RuneContext.of(st, affinities)
		var r: Dictionary = Runes.active().seal(draft, after, int(st["stage"]))
		if bool(r["ok"]):
			st["word"] = draft
			note("The seal forms: %s now holds %d ring%s." % [skill, int(st["stage"]), "" if int(st["stage"]) == 1 else "s"])
	elif result == "bound":
		note("%s binds. The word stays as it was%s." % [skill, "" if st.has("word") else " - it has no word yet"])
	elif result == "failed":
		note("No seal forms. The word of %s stays as it was." % skill)
	return result


## A test character's free edit: seal the draft now (it need not be closed). The draft stays open.
func seal_now() -> Dictionary:
	if seal_mode() != "test":
		return RuneRules.no("not_test", "Only a test character's free edit seals without a binding.")
	var index: int = sealing_index()
	var ctx: RuneContext = rune_context(index)
	var w: Dictionary = (seal_draft["word"] as Dictionary).duplicate(true)
	var r: Dictionary = Runes.active().seal(w, ctx, ctx.rings)
	if bool(r["ok"]):
		(abilities[index] as Dictionary)["word"] = w
	return r


## The draft of ability `index` if it is being sealed, else {}.
func _draft_for(index: int) -> Dictionary:
	return seal_draft["word"] if sealing_index() == index else {}


func _not_sealing(index: int) -> Dictionary:
	if test_character:
		return RuneRules.no("not_sealing", "Open the free edit to change the word.")
	var st: Dictionary = abilities[index] if index >= 0 and index < abilities.size() else {}
	var need: String = pending_tier(st) if not st.is_empty() else ""
	return RuneRules.no("not_sealing", ("Runes are sealed when a construct is bound: bind a %s into it to form the seal." % need) if need != ""
		else "Runes are sealed when a construct is bound into the skill: fill its bar first.")


## Set a rune into the draft of ability `index`, joined to node `to_node` when that is >= 0, on ring
## `ring` when that is >= 0. Returns the rules' check: {ok, reason, text}.
func word_add(index: int, rune_id: String, to_node: int = -1, ring: int = -1) -> Dictionary:
	if index < 0 or index >= abilities.size():
		return RuneRules.no("no_skill", "No such skill.")
	var w: Dictionary = _draft_for(index)
	if w.is_empty():
		return _not_sealing(index)
	if not can_use_rune(rune_id):
		return RuneRules.no("not_yours", "%s belongs to an affinity you do not hold." % str(GameData.rune(rune_id).get("name", rune_id)))
	if not knows_rune(rune_id):
		return RuneRules.no("unknown", "You have not discovered that rune yet: runes are found in the Netherecho, in fights and on old stones.")
	return Runes.active().add(w, rune_id, rune_context(index), to_node, ring)


## Join two runes of the draft, or part them if they are joined.
func word_toggle_link(index: int, a: int, b: int) -> Dictionary:
	if index < 0 or index >= abilities.size():
		return RuneRules.no("no_skill", "No such skill.")
	var w: Dictionary = _draft_for(index)
	if w.is_empty():
		return _not_sealing(index)
	return Runes.active().toggle_link(w, a, b, rune_context(index))


## Take a rune (not the skill's own) out of the draft.
func word_remove(index: int, node: int) -> Dictionary:
	if index < 0 or index >= abilities.size():
		return RuneRules.no("no_skill", "No such skill.")
	var w: Dictionary = _draft_for(index)
	if w.is_empty():
		return _not_sealing(index)
	return Runes.active().remove(w, node, rune_context(index))


## Clear the draft back to the skill's own rune alone.
func word_clear(index: int) -> void:
	if sealing_index() == index:
		var w: Dictionary = RuneWord.make(GameData.skill_anchor(str(abilities[index]["id"])), Runes.active().id)
		seal_draft["word"] = w


## The skill uses a sealed word.
func word_locked(index: int) -> bool:
	return index >= 0 and index < abilities.size() and RuneWord.is_locked(_sealed_word(index))


## What the word in ability `index` (the draft, while sealing) does - or would do once sealed - to
## its skill: {rows: [{label, before, after, better}], lines, runes, anchor, groups, traits,
## transfers}. `before` is the skill without the word, `after` with it. Numbers are formatted.
func rune_preview(index: int) -> Dictionary:
	if index < 0 or index >= abilities.size():
		return {}
	var state: Dictionary = abilities[index]
	var bare: Dictionary = state.duplicate(true)
	bare.erase("word")
	var before: Dictionary = ability_stats(bare)
	var word: Dictionary = ability_word(index).duplicate(true)
	var fx: Dictionary = Runes.active().effects(word, rune_context(index))
	var after: Dictionary = before.duplicate(true)
	apply_rune_patch(after, fx.get("patch", []))
	# the rule set names the fields worth showing: [{path, group, label, lower_is_better, unit}]
	var rows: Array[Dictionary] = []
	var stage_mult: float = ability_damage_mult(int(state["stage"])) * float(before.get("damage_all", 1.0))
	for f: Dictionary in fx.get("fields", []):
		var path: String = str(f["path"])
		var b: Variant = _path_value(before, path)
		var a: Variant = _path_value(after, path)
		if not (typeof(b) == TYPE_FLOAT or typeof(b) == TYPE_INT) or not (typeof(a) == TYPE_FLOAT or typeof(a) == TYPE_INT):
			continue
		var scale: float = stage_mult if bool(f.get("scaled_by_stage", false)) else 1.0
		var shown_b: float = float(b) * scale
		var shown_a: float = float(a) * scale
		var whole: bool = absf(shown_b) >= 10.0
		var unit: String = str(f.get("unit", ""))
		rows.append({"label": str(f["label"]), "group": str(f["group"]),
			"before": (("%d" % int(round(shown_b))) if whole else ("%.2f" % shown_b).rstrip("0").rstrip(".")) + unit,
			"after": (("%d" % int(round(shown_a))) if whole else ("%.2f" % shown_a).rstrip("0").rstrip(".")) + unit,
			"changed": absf(shown_a - shown_b) > 0.0001, "better": (shown_a < shown_b) == bool(f.get("lower_is_better", false))})
	if after.has("rune_repeat"):
		var rep: Dictionary = after["rune_repeat"]
		rows.append({"label": "Repeats", "group": "power", "before": "no", "after": "x%d at %d%%" % [int(rep.get("times", 1)), int(round(float(rep.get("mult", 0.0)) * 100.0))],
			"changed": true, "better": true})
	return {"rows": rows, "lines": fx.get("lines", []), "runes": fx.get("runes", []), "anchor": fx.get("anchor", {}),
		"groups": fx.get("groups", {}), "traits": fx.get("traits", []), "effect_lines": fx.get("effect_lines", fx.get("lines", [])), "transfers": fx.get("transfers", []), "before": before, "after": after}


## Short lines on what a SEALED word does to ability `index` ([] if it has none), for tooltips and
## the ethercosm.
func rune_summary(index: int) -> Array:
	if not word_locked(index):
		return []
	return Runes.active().locked_effects(_sealed_word(index), RuneContext.of(abilities[index], affinities)).get("summary", [])


static func _path_value(d: Dictionary, path: String) -> Variant:
	var cur: Variant = d
	for key: String in path.split("."):
		if typeof(cur) != TYPE_DICTIONARY or not (cur as Dictionary).has(key):
			return null
		cur = (cur as Dictionary)[key]
	return cur


## Every rune this character could set - its affinities' base runes and the universal ones, in
## workbook order - known or not (the screen shows the unknown ones as "?").
func rune_palette() -> Array[String]:
	return Runes.usable(affinities)


# --- rune discovery (Brent 2026-10-23, design/14 section 8) -----------------------------------
# A discovered rune is permanent knowledge. Runes are found by subduing constructs (a rune of the
# construct's concept), by kills (a small chance of a rune of the enemy's nature) and at rune
# stones; universal runes are rarer and come from deeper sources. Pools and chances are
# data/rune_discovery.json; only runes this character can use and does not know are revealed.

func knows_rune(rune_id: String) -> bool:
	return test_character or known_runes.has(rune_id)


## A base rune of an affinity held, or a universal rune.
func can_use_rune(rune_id: String) -> bool:
	var r: Dictionary = GameData.rune(rune_id)
	if r.is_empty():
		return false
	var aff: String = str(r.get("affinity", ""))
	return aff == "" or affinities.has(aff)


## Learn a rune: a message, the HUD's card (rune_discovered). False if it was known or is no rune.
func discover_rune(rune_id: String, source: String = "") -> bool:
	if rune_id == "" or GameData.rune(rune_id).is_empty() or known_runes.has(rune_id):
		return false
	known_runes.append(rune_id)
	last_rune = {"id": rune_id, "source": source}
	note("Rune discovered: %s%s" % [str(GameData.rune(rune_id).get("name", rune_id)), (" - " + source) if source != "" else ""])
	rune_discovered.emit(rune_id, source)
	return true


## Know a rune without a fanfare (a starting rune, a learned skill's own rune).
func _know(rune_id: String) -> void:
	if rune_id != "" and not GameData.rune(rune_id).is_empty() and not known_runes.has(rune_id):
		known_runes.append(rune_id)


## What a new character knows: the runes of the skills it holds, and a couple of each affinity's
## runes (rune_discovery.json "start").
func _grant_start_runes() -> void:
	for st: Dictionary in abilities:
		_know(GameData.skill_anchor(str(st["id"])))
	var start: Dictionary = (GameData.rune_discovery.get("start", {}) as Dictionary).get("affinity_runes", {})
	for a: String in affinities:
		for rid: Variant in start.get(a, []):
			_know(str(rid))


func _unknown_usable(pool: Array) -> Array[String]:
	var out: Array[String] = []
	for rid: Variant in pool:
		if can_use_rune(str(rid)) and not knows_rune(str(rid)) and not out.has(str(rid)):
			out.append(str(rid))
	return out


## Every base rune of the affinities held, then every universal rune (for stones).
func _all_base() -> Array:
	return Runes.usable(affinities).filter(func(id: String) -> bool: return str(GameData.rune(id).get("affinity", "")) != "")


func _all_universal() -> Array:
	return (GameData.runes.get("universal_runes", {}) as Dictionary).keys()


## Reveal one rune: universal with `universal_chance` (else from `base`); a universal wish that finds
## nothing falls back to base, never the other way (universal runes are the rarer). With
## `any_base`, a base pool with nothing new falls back to any base rune of the affinities held.
## Returns the rune id, or "" if there was nothing new to find.
func reveal_rune(base: Array, universal: Array, universal_chance: float, source: String, any_base: bool = false) -> String:
	var picks: Array[String] = []
	if universal_chance > 0.0 and rng.randf() < universal_chance:
		picks = _unknown_usable(universal)
	if picks.is_empty():
		picks = _unknown_usable(base)
	if picks.is_empty() and any_base:
		picks = _unknown_usable(_all_base())
	if picks.is_empty():
		return ""
	var rid: String = picks[rng.randi() % picks.size()]
	discover_rune(rid, source)
	return rid


## A construct subdued in the Netherecho reveals runes of its concept. Returns the ids revealed.
func on_construct_subdued(tier: String, concept: String) -> Array[String]:
	var cfg: Dictionary = GameData.rune_discovery.get("construct", {})
	var by_tier: Dictionary = (cfg.get("by_tier", {}) as Dictionary).get(tier, {})
	var entry: Dictionary = (cfg.get("concepts", {}) as Dictionary).get(concept, {})
	var base: Array = []
	for a: String in affinities:
		base.append_array((entry.get("base", {}) as Dictionary).get(a, []))
	var label: String = str(GameData.concept(concept).get("label", concept.capitalize()))
	var out: Array[String] = []
	for n: int in int(by_tier.get("reveals", 0)):
		var rid: String = reveal_rune(base, entry.get("universal", []), float(by_tier.get("universal_chance", 0.0)), "from the %s of %s you subdued" % [tier, label])
		if rid != "":
			out.append(rid)
	return out


## A kill may reveal a rune of the enemy's nature.
func _roll_kill_rune(target: Node) -> void:
	var kind_v: Variant = target.get("kind")
	if kind_v == null or str(kind_v) == "":
		return
	var cfg: Dictionary = GameData.rune_discovery.get("kills", {})
	var chance: float = float((cfg.get("chance_by_kind", {}) as Dictionary).get(str(kind_v), cfg.get("chance", 0.0)))
	if rng.randf() >= chance:
		return
	kill_reveals(str(kind_v))


## The rune a kill of `kind` reveals (the chance already rolled). Public for tests.
func kill_reveals(kind: String) -> String:
	var cfg: Dictionary = GameData.rune_discovery.get("kills", {})
	var entry: Dictionary = (cfg.get("by_kind", {}) as Dictionary).get(kind, {})
	var base: Array = []
	for a: String in affinities:
		base.append_array((entry.get("base", {}) as Dictionary).get(a, []))
	return reveal_rune(base, entry.get("universal", []), float(cfg.get("universal_chance", 0.0)), "from the %s you killed" % kind)


## Read a rune stone: once per stone, a rune of one of your affinities ("base") or a universal one.
## Returns the rune revealed, or "".
func read_inscription(id: String, pool: String, stone_name: String = "the stone") -> String:
	if read_inscriptions.has(id):
		note("You have read %s; it holds nothing more for you." % stone_name.to_lower())
		return ""
	read_inscriptions.append(id)
	var fallback: bool = bool((GameData.rune_discovery.get("inscriptions", {}) as Dictionary).get("base_fallback", true))
	var rid: String = reveal_rune(_all_base(), _all_universal(), 1.0 if pool == "universal" else 0.0, "read from %s" % stone_name.to_lower(), fallback)
	if rid == "":
		note("%s holds only runes you already know." % stone_name)
	return rid


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
	if _rig.has_method("set_outfit"):
		_rig.call("set_outfit", inventory.equipped)       # a real body wears what is equipped
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
	# every kill leaves something to sell: the kind's remains (nothing pays cash - Brent 2026-10-18)
	var remains: String = str(GameData.enemy(str(kind_v)).get("remains", ""))
	if remains != "" and not bool(target.get("is_scenery")):
		spawn_pickup(parent, remains, (target as Node3D).global_position)
	for entry: Dictionary in GameData.enemy(str(kind_v)).get("loot", []):
		if rng.randf() < float(entry["chance"]):
			if bool(entry.get("learnable", false)):
				var scroll: String = scroll_for_me()
				if scroll != "":
					spawn_pickup(parent, scroll, (target as Node3D).global_position + Vector3(rng.randf_range(-0.8, 0.8), 0.0, rng.randf_range(-0.8, 0.8)))
				continue
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
	if drop.get("corpse_id") != null:
		var back: bool = recover_corpse(str(drop.get("corpse_id")))
		if back:
			drop.call("take")
		return back
	var id: String = str(drop.get("item_id"))
	var item_name: String = str(GameData.item(id).get("name", id))
	if not inventory.add(id):
		note("%s is too heavy - you are carrying %d of %d kg." % [item_name, int(inventory.weight()), int(inventory.capacity())])
		return false
	drop.call("take")
	_rig_action("pickup")
	note("Picked up %s." % item_name)
	return true


## Everything that must survive between sessions.
## A test character (title screen "Test characters"): this one affinity, and every skill of it
## learned in tree order (any not on the tree after), each at balance.skills.test_stage. TEST
## OVERRIDE: the stage cap is stars + 1, so it is given balance.skills.test_stars full stars - a
## full tank. The first six skills are on the bar; the hotbar_page key shows the next six.
func make_test_character(aff: String) -> void:
	set_affinities([aff])
	test_character = true
	hotbar_page = 0
	var n: int = GameData.inum("skills", "test_stars")
	stars = n
	star_pct.clear()
	for i: int in n:
		star_pct.append(GameData.num("stars", "max_pct"))
	_recompute_essence_max()
	essence = essence_max
	var ids: Array[String] = []
	for id: String in GameData.skill_tree_of(aff):
		ids.append(id)
	for id: String in GameData.abilities:
		if str(GameData.ability(id).get("affinity", "")) == aff and not ids.has(id):
			ids.append(id)
	abilities.clear()
	for i: int in hotbar.size():
		hotbar[i] = -1
	var stage: int = mini(GameData.inum("skills", "test_stage"), stars + 1)
	for id: String in ids:
		abilities.append({"id": id, "stage": stage, "progress": 0.0})
	for i: int in mini(hotbar.size(), abilities.size()):
		hotbar[i] = i
	note("TEST CHARACTER: every %s skill, stage %d. %s turns the skill bar to the next six." % [str(GameData.affinity(aff).get("label", aff)).to_lower(), stage, Keybinds.binding_text("hotbar_page")])


func to_save() -> Dictionary:
	return {
		"test_character": test_character,
		"name": char_name, "identity": identity, "look": look.duplicate(), "affinities": affinities.duplicate(),
		"tempering": tempering.duplicate(true),
		"talent_id": talent_id, "stars": stars, "star_pct": star_pct.duplicate(), "money": money,
		"essence": essence, "latent_aura": _latent_aura,
		"body": body.to_dict(),
		"arm_right": arm_right, "arm_right_lost": arm_right_lost,
		"abilities": abilities.duplicate(true), "hotbar": hotbar.duplicate(),
		"skill_points": skill_points, "skill_growth": skill_growth,
		"craft_skill": craft_skill.duplicate(), "craft_known": craft_known.duplicate(), "craft_made": craft_made.duplicate(),
		"tool_uses": tool_uses.duplicate(),
		"constructs": constructs.duplicate(true), "discoveries": discoveries.duplicate(),
		"known_runes": known_runes.duplicate(), "read_inscriptions": read_inscriptions.duplicate(),
		"heal_points_total": heal_points_total, "inventory": inventory.to_dict(), "corpses": corpses.duplicate(true), "explored": explored.duplicate(),
	}


func from_save(d: Dictionary) -> void:
	set_talent(str(d.get("talent_id", "")))
	test_character = bool(d.get("test_character", false))
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
			if a.has("word"):
				# rule-free data: read back as it was; the rules in force report what no longer fits.
				# No seal outlasts its skill's level (a word locked before seals, on a stage-0 skill,
				# comes back unsealed: before the first binding a skill has no word).
				var w: Dictionary = RuneWord.normalize(a["word"], GameData.skill_anchor(str(a.get("id", ""))))
				if RuneWord.sealed(w) > int(a["stage"]):
					w["sealed"] = int(a["stage"])
				if RuneWord.sealed(w) <= 0:
					w.erase("sealed")
				a["word"] = w
			abilities.append(a)
	var saved_hotbar: Array = d.get("hotbar", [])
	for i: int in mini(saved_hotbar.size(), hotbar.size()):
		hotbar[i] = int(saved_hotbar[i])
	skill_points = int(d.get("skill_points", 0))
	skill_growth = float(d.get("skill_growth", 0.0))
	craft_skill.clear()
	var saved_craft: Dictionary = d.get("craft_skill", {})
	for s: String in saved_craft:
		craft_skill[s] = int(saved_craft[s])
	craft_known = (d.get("craft_known", []) as Array).map(func(v: Variant) -> String: return str(v))
	craft_made = (d.get("craft_made", []) as Array).map(func(v: Variant) -> String: return str(v))
	tool_uses.clear()
	var saved_uses: Dictionary = d.get("tool_uses", {})
	for t: String in saved_uses:
		tool_uses[t] = int(saved_uses[t])
	constructs.clear()
	for c: Variant in d.get("constructs", []):
		constructs.append(c)
	discoveries.clear()
	for line: Variant in d.get("discoveries", []):
		discoveries.append(str(line))
	seal_draft = {}
	known_runes.clear()
	if d.has("known_runes"):
		for rid: Variant in d["known_runes"]:
			if not GameData.rune(str(rid)).is_empty() and not known_runes.has(str(rid)):
				known_runes.append(str(rid))
	else:
		_grant_start_runes()              # a save from before discovery: what a new character knows
	read_inscriptions.clear()
	for sid: Variant in d.get("read_inscriptions", []):
		read_inscriptions.append(str(sid))
	heal_points_total = float(d.get("heal_points_total", 0.0))
	corpses = (d.get("corpses", []) as Array).duplicate(true)
	explored = (d.get("explored", {}) as Dictionary).duplicate()
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
		_earn_skill_points(star_pct[i] - before)
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
	bolt.set("hit_radius", maxf(0.35, float(ab.get("width", 0.0)) * 0.5))
	bolt.set("ab", ab)
	bolt.set("stage_mult", stage_mult)
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
## You wake in town with nothing (Brent 2026-10-18: corpse runs). Patched up, not healed: enough
## to stand, and nothing lost comes back. What you had is on your corpse (die_to_corpse).
func respawn_naked() -> void:
	var town: Dictionary = GameData.balance["town"]
	dead = false
	in_combat = false
	meditating = false
	effects.clear()
	set_talent(talent_id)
	_charging = false
	_charge = 0.0
	clear_reflux()
	buffs.clear()
	body.hp = maxf(body.hp, body.total_max() * float(town["revive_health_frac"]))
	_build_model()
	refresh_gear()
	note("You wake on a cot in town with nothing on you. Your body is where you fell.")


## Everything worn and carried stays with the body, where it fell: `where` is "passage" or "arena",
## `chamber` and `local_pos` place it in that level's own frame. Returns the corpse, or {} if
## there was nothing on you to leave.
func die_to_corpse(where: String, chamber: int, local_pos: Vector3) -> Dictionary:
	if inventory.equipped.is_empty() and inventory.bag.is_empty():
		return {}
	_corpse_seq += 1
	var c: Dictionary = {"id": "corpse_%d_%d" % [Time.get_unix_time_from_system(), _corpse_seq], "where": where, "chamber": chamber,
		"pos": [local_pos.x, local_pos.y, local_pos.z], "equipped": inventory.equipped.duplicate(), "bag": inventory.bag.duplicate()}
	corpses.append(c)
	inventory.equipped.clear()
	inventory.bag.clear()
	refresh_gear()
	return c


## Take back everything on one of your corpses. What you are wearing now stays on; anything that
## would have gone in a taken slot goes in the pack. It all comes back, however heavy.
func recover_corpse(id: String) -> bool:
	for i: int in corpses.size():
		var c: Dictionary = corpses[i]
		if str(c["id"]) != id:
			continue
		var gear: Dictionary = c.get("equipped", {})
		for slot: String in gear:
			if inventory.equipped.has(slot):
				inventory.bag.append(str(gear[slot]))
			else:
				inventory.equipped[slot] = str(gear[slot])
		for item: Variant in c.get("bag", []):
			inventory.bag.append(str(item))
		corpses.remove_at(i)
		refresh_gear()
		note("You take back everything that was on your corpse.")
		_float("RECOVERED", Color(0.9, 0.85, 0.7))
		return true
	return false


## The price to have one corpse brought to you: flat, by how many stars you have.
func corpse_fee() -> int:
	return GameData.inum("town", "corpse_fee_per_star") * stars


## Pay to have the most recent corpse brought back. Returns "" or why not.
func buy_corpse_retrieval() -> String:
	if corpses.is_empty():
		return "You have no corpse lying anywhere."
	var fee: int = corpse_fee()
	if not can_afford(fee):
		return "The collectors will not go out on that much debt."
	money -= fee
	recover_corpse(str((corpses.back() as Dictionary)["id"]))
	return ""


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
func _bot_think(delta: float = 0.0) -> bool:
	var near: Node3D = _nearest_enemy()
	var goal: Vector3 = near.global_position if near != null else bot_goal
	var to: Vector3 = goal - global_position
	to.y = 0.0
	var dist: float = to.length()
	_bot_dir = _bot_way(goal, delta) if dist > 0.6 else Vector3.ZERO
	if dist > 0.2:
		_facing = to / dist
	if near == null:
		return false
	return dist <= reach_now() + float(near.get("radius"))


## Test bot: the way to walk to `goal` - along the level's navigation mesh, or where there is
## none yet through the passage's doorway (Route, via the `router` group), else straight.
func _bot_way(goal: Vector3, delta: float) -> Vector3:
	var nav: LevelNav = LevelNav.find(get_tree(), global_position)
	if nav != null:
		var way: Vector3 = _bot_path.steer(nav, global_position, goal, 0.4, delta)
		if way != Vector3.ZERO or _bot_path.blocked:
			return way
	var next: Vector3 = goal
	var router: Node = get_tree().get_first_node_in_group("router")
	if router != null:
		next = router.call("route", global_position, goal, 0.4)
	var flat := Vector3(next.x - global_position.x, 0.0, next.z - global_position.z)
	return flat.normalized() if flat.length() > 0.05 else Vector3.ZERO


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


## A one-off motion on a real body (RealCharacter.play_action); the procedural body has none.
func _rig_action(motion: String) -> void:
	if _rig != null and _rig.has_method("play_action"):
		_rig.call("play_action", motion)


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
	skill_points += int((GameData.skill_tree.get("points", {}) as Dictionary).get("on_ascend", 0))
	for e: TalentEffect in effects:
		e.on_ascend(stars)
	_rig_action("power_up")
	note("ASCENDED. A second star splits off - tiny, for now.")
	note("Talent evolves: %s" % str(talent.get("evolve_2", "?")))
	if talent_id != "one_percent_lifesteal":
		note("(this talent's evolution is not wired into the prototype yet)")


# --- the 2026-10-22 skill kinds (build brief: smite, channel, charge_release, summon, seed, grapple,
# streak, field_pulse; clouds and lures). Every effect on an enemy still goes through apply_hit. ---

## True while a buff keeps your casting and striking quiet (Muffle).
func _cast_is_quiet() -> bool:
	for bid: String in buffs:
		if (buffs[bid] as Dictionary).has("unaware_mult"):
			return true
	return false


## One of your own short states (statuses.json player_states: Quickened), as a buff.
func _take_state(id: String, seconds: float) -> void:
	var def: Dictionary = GameData.player_state(id)
	var b: Dictionary = def.duplicate()
	b["t"] = seconds
	buffs[id] = b
	_float(str(def.get("label", id)).to_lower(), Color(0.95, 0.95, 1.0))


## The living enemy nearest `point`, within `reach` of it; null if none.
func _nearest_enemy_to(point: Vector3, reach: float) -> Node3D:
	var best: Node3D = null
	for e: Node3D in _enemies_near(point, reach):
		if best == null or Vector2(e.global_position.x - point.x, e.global_position.z - point.z).length() < Vector2(best.global_position.x - point.x, best.global_position.z - point.z).length():
			best = e
	return best


## Where a movement skill lands when it has a special landing: onto a corpse further off
## (Gravestep's corpse_range), or into the shadow behind an enemy (Shadow Slip). Null otherwise.
func _special_landing(ab: Dictionary) -> Variant:
	var cursor: Vector3 = _cursor_ground()
	if float(ab.get("corpse_range", 0.0)) > 0.0:
		var f: Fallen = Fallen.nearest(get_tree(), cursor, 1.5)
		if f != null and f.global_position.distance_to(global_position) <= float(ab["corpse_range"]):
			return Vector3(f.global_position.x, global_position.y, f.global_position.z)
	if bool(ab.get("arrive_behind", false)):
		var foe: Node3D = _nearest_enemy_to(cursor, 1.5)
		if foe == null:
			foe = _skill_target(float(ab.get("range", 10.0)))
		if foe != null and foe.global_position.distance_to(global_position) <= float(ab.get("range", 10.0)) + 1.0:
			var back: Vector3 = -(foe.get("facing") as Vector3) if foe.get("facing") is Vector3 else (foe.global_position - global_position).normalized()
			var spot: Vector3 = foe.global_position + back.normalized() * (float(foe.get("radius")) + 1.0)
			spot.y = global_position.y
			if _ray(foe.global_position + Vector3.UP, spot + Vector3.UP).is_empty():
				return spot
	return null


## How many blood pools lie along the stretch a-b.
func _pools_along(a: Vector3, b: Vector3) -> int:
	var n := 0
	if not is_inside_tree():
		return n
	var pa := Vector2(a.x, a.z)
	var pb := Vector2(b.x, b.z)
	for node: Node in get_tree().get_nodes_in_group("blood_pools"):
		var p := node as BloodPool
		var c := Vector2(p.global_position.x, p.global_position.z)
		if Geometry2D.get_closest_point_to_segment(c, pa, pb).distance_to(c) <= p.radius + 0.4:
			n += 1
	return n


## A phantom or likeness of you that enemies take for you (a Lure).
func _leave_lure(at: Vector3, cfg: Dictionary, aff: String, tags: Array) -> Lure:
	var l := Lure.new()
	l.caster = self
	l.life = float(cfg.get("life", 3.0))
	l.hp = float(cfg.get("hp", 1.0))
	l.lure_radius = float(cfg.get("lure_radius", cfg.get("radius", 8.0)))
	l.breaks_on_hits = int(cfg.get("breaks_on_hits", 0))
	l.collapse = cfg.get("collapse", {})
	l.collapse_radius = float(cfg.get("collapse_radius", 0.0))
	l.color = GameData.affinity_color(aff).lightened(0.25)
	l.tags = tags
	get_parent().add_child(l)
	l.global_position = Vector3(at.x, global_position.y, at.z)
	return l


## smite (hex, seize, gaze): an instant effect on one enemy - no travel. It may go off a moment
## later wherever the target has moved (delay), send it walking to where you pointed (Errand), or
## leave growth when it dies (Dwindling Gall).
func _smite(target: Node3D, point: Vector3, ab: Dictionary, stage_mult: float, tags: Array) -> void:
	if target == null or not is_instance_valid(target):
		return
	var color: Color = GameData.affinity_color(str(ab.get("affinity", "")))
	var payload: Dictionary = _payload(ab, "on_hit")
	if bool(ab.get("nearest_to_point", false)):
		var data: Dictionary = (payload.get("status_data", {}) as Dictionary).duplicate()
		data["goal"] = Vector3(point.x, target.global_position.y, point.z)
		payload["status_data"] = data
		# Errand: long enough to walk there, then stand stand_s
		var walk: float = Vector2(point.x - target.global_position.x, point.z - target.global_position.z).length() / maxf(0.5, float(target.get("speed")))
		payload["status_s"] = walk + float(data.get("stand_s", 2.0))
	_strike_t = 0.2
	var from_sky: bool = bool(payload.get("through", false))
	_line_visual((target.global_position + Vector3.UP * 7.0) if from_sky else (global_position + Vector3.UP), target.global_position + Vector3.UP, color)
	if str(ab.get("on_death_growth", "")) != "":
		var kind_g: String = str(ab["on_death_growth"])
		target.tree_exiting.connect(func() -> void:
			if is_instance_valid(self) and bool(target.call("is_dead")):
				plant_growth(target.global_position, {"kind": kind_g}))
	var delay: float = float(ab.get("delay", 0.0))
	if delay > 0.0:
		var mark := target
		SkillTimer.after(get_parent(), delay, func(_i: int) -> void:
			if is_instance_valid(mark) and not bool(mark.call("is_dead")):
				apply_hit(mark, payload, tags, stage_mult))
		return
	apply_hit(target, payload, tags, stage_mult)


## summon: the body at the point gets up and fights for you (a Thrall). A body is spent; the
## oldest of more than max_count falls.
func _summon(at: Vector3, ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var f: Fallen = Fallen.nearest(get_tree(), at, 1.5)
	if f != null:
		f.spend()
	var mine: Array = get_tree().get_nodes_in_group("thralls").filter(func(t: Node) -> bool: return t.get("caster") == self)
	while mine.size() >= int(ab.get("max_count", 2)):
		var old: Node = mine.pop_front()
		old.call("_fall")
	var cfg: Dictionary = ab.get("thrall", {})
	var t := Thrall.new()
	t.caster = self
	t.life = float(ab.get("duration", 15.0))
	t.hp = float(cfg.get("hp", 120.0))
	t.damage = float(cfg.get("damage", 15.0)) * stage_mult
	t.attack_s = float(cfg.get("attack_s", 1.2))
	t.speed = float(cfg.get("speed", 5.0))
	t.tags = tags
	get_parent().add_child(t)
	t.global_position = Vector3(at.x, global_position.y, at.z)
	_line_visual(global_position + Vector3.UP, at + Vector3.UP, GameData.affinity_color(str(ab.get("affinity", ""))))


## seed: hidden seeds spread round the point, each bursting when stepped on or after a while.
func _sow(at: Vector3, ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var n: int = int(ab.get("seeds", 5))
	var spread: float = float(ab.get("radius", 2.5))
	for i: int in n:
		var a: float = TAU * float(i) / float(n)
		var r: float = spread * (0.35 + 0.65 * float(i % 2))
		var s := SeedTrap.new()
		s.caster = self
		s.payload = _payload(ab, "on_hit")
		s.tags = tags
		s.stage_mult = stage_mult
		s.trigger_radius = float(ab.get("trigger_radius", 0.6))
		s.burst_radius = float(ab.get("burst_radius", 1.2))
		s.delay = float(ab.get("delay", 6.0))
		s.life = float(ab.get("duration", 20.0))
		s.growth = ab.get("leave_growth", {})
		s.color = GameData.affinity_color(str(ab.get("affinity", "")))
		get_parent().add_child(s)
		s.global_position = Vector3(at.x + cos(a) * r, global_position.y, at.z + sin(a) * r)
	_strike_t = 0.2


## grapple: hauled to the point by exact distance at dash_speed (a dash for recovery and Winded);
## what is beside you when you land takes the arrival payload.
func _grapple(to: Vector3, ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var way: Vector3 = to - global_position
	way.y = 0.0
	if way.length() < 0.2:
		return
	_line_visual(global_position + Vector3.UP, to + Vector3.UP, GameData.affinity_color(str(ab.get("affinity", ""))))
	_facing = way.normalized()
	var speed: float = float(ab.get("dash_speed", 24.0))
	_dash_vel = way.normalized() * speed
	_dash_time = way.length() / speed
	_dash_pass = {}
	_dash_tags = tags
	_dash_passed.clear()
	_dash_from = global_position
	_dash_start = global_position
	_dash_trail = {}
	_dash_stops = false
	_dash_braced = false
	_dash_on_stop = {}
	_dash_on_arrive = ab.get("on_arrive", {})
	_dash_arrive_radius = float(ab.get("arrive_radius", 1.5))
	_dash_ab = ab
	_dash_stage_mult = stage_mult
	_dash_color = GameData.affinity_color(str(ab.get("affinity", "")))


## streak: along your aim in one step, up to range, through bodies (on_pass to each by the line),
## stopping short of the first wall, stone or raised shield.
func _streak(ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var from: Vector3 = global_position
	var dir: Vector3 = _facing
	var reach: float = float(ab.get("range", 7.0))
	var wall: Dictionary = _ray(from + Vector3.UP, from + Vector3.UP + dir * (reach + 0.5))
	if not wall.is_empty():
		reach = maxf(0.0, (from + Vector3.UP).distance_to(wall["position"]) - 0.6)
	var a := Vector2(from.x, from.z)
	var passed: Array = []
	for e: Node3D in _enemies_near(from, reach + 1.0):
		var to: Vector3 = e.global_position - from
		to.y = 0.0
		var along: float = to.dot(dir)
		if along < 0.0 or along > reach:
			continue
		if (to - dir * along).length() > float(ab.get("pass_radius", 1.1)) + float(e.get("radius")):
			continue
		if e.has_method("blocks_shot") and bool(e.call("blocks_shot", from)):
			reach = minf(reach, maxf(0.0, along - float(e.get("radius")) - 0.6))      # a raised shield stops you short
			continue
		passed.append([along, e])
	var b: Vector2 = a + Vector2(dir.x, dir.z) * reach
	var end := Vector3(b.x, from.y, b.y)
	_line_visual(from + Vector3.UP, end + Vector3.UP, GameData.affinity_color(str(ab.get("affinity", ""))))
	global_position = end
	velocity = Vector3.ZERO
	has_move_goal = false
	for row: Array in passed:
		if float(row[0]) <= reach:
			apply_hit(row[1], ab.get("on_pass", {}), tags, stage_mult, dir)


## field_pulse: acts on your own field pieces - corpses (Lay to Rest) or growth patches (Sere
## Ground wilts them for a burst each; Greening grows them on).
func _field_pulse(at: Vector3, ab: Dictionary, stage_mult: float, tags: Array) -> void:
	_strike_t = 0.25
	var centre: Vector3 = at if ab.has("range") else global_position
	var radius: float = float(ab.get("radius", 6.0))
	var color: Color = GameData.affinity_color(str(ab.get("affinity", "")))
	if ab.has("max_corpses"):
		var n := 0
		for node: Node in get_tree().get_nodes_in_group("fallen").duplicate():
			var f := node as Fallen
			if f == null or f.spent or f.global_position.distance_to(centre) > radius or n >= int(ab["max_corpses"]):
				continue
			n += 1
			_line_visual(global_position + Vector3.UP, f.global_position + Vector3.UP * 0.3, color)
			essence = minf(essence_max, essence + float(ab.get("per_corpse_essence", 0.0)))
			var aff: String = str(ab.get("affinity", ""))
			reflux_by[aff] = maxf(0.0, reflux_of(aff) - float(ab.get("per_corpse_reflux", 0.0)))
			for e: Node3D in _enemies_near(f.global_position, float(ab.get("drag_radius", 2.0))):
				apply_hit(e, _payload(ab, "on_hit"), tags, stage_mult)
			f.spend()
		return
	for node: Node in get_tree().get_nodes_in_group("growth").duplicate():
		var g := node as GrowthPatch
		if g == null or g.caster != self or g.global_position.distance_to(centre) > radius:
			continue
		if int(ab.get("ages_added", 0)) > 0:
			g.grow(int(ab["ages_added"]))
			for i: int in int(ab.get("spreads", 0)):
				g.spread()
			g.boost = float(ab.get("effect_mult", 1.0))
			g.boost_t = float(ab.get("duration", 6.0))
			continue
		var p: Dictionary = _payload(ab, "on_hit")
		p["damage"] = float(ab.get("per_stack_damage", 30.0)) * (g.mult() if bool(ab.get("age_scales", false)) else 1.0)
		for e: Node3D in g.inside():
			apply_hit(e, p, tags + ["growth"], stage_mult)
		g.wilt()


## A held skill begins: a channel does its work every tick while held; a charge builds while held.
## Held from a key, it ends when the key is let go; started any other way (a click on the bar, a
## test, the bot) it runs its duration, or skills.channel_max_s, or its full charge.
func _start_held(ab: Dictionary, kind: String, aff: String, stage_mult: float, tags: Array, target: Node3D, point: Vector3, state: Dictionary) -> void:
	_held = {"ab": ab, "kind": kind, "aff": aff, "stage_mult": stage_mult, "tags": tags, "target": target, "point": point,
		"t": 0.0, "tick": 0.0, "action": _cast_action, "memo": {}, "state": state, "pip_t": 0.0}
	_float("hold" if kind == "channel" else "charging", GameData.affinity_color(aff).lightened(0.3))
	if kind == "channel":
		_channel_pulse()


func _tick_held(delta: float) -> void:
	var h: Dictionary = _held
	var ab: Dictionary = h["ab"]
	h["t"] = float(h["t"]) + delta
	var action: String = str(h["action"])
	var let_go: bool = action != "" and not Input.is_action_pressed(action)
	if _stagger_t > 0.0 or dead:
		_held = {}
		return
	if str(h["kind"]) == "charge_release":
		if let_go or float(h["t"]) >= float(ab.get("charge_max", 1.0)):
			_release_charge()
		return
	var max_t: float = float(ab.get("duration", GameData.num("skills", "channel_max_s")))
	var pay: float = float(ab.get("cost", 0.0)) * delta
	if let_go or float(h["t"]) >= max_t or essence < pay:
		_end_held()
		return
	essence -= pay
	var aff: String = str(h["aff"])
	reflux_by[aff] = reflux_of(aff) + pay * float(ab.get("reflux_per_cost", 1.0))
	_advance(h["state"], pay)
	if float(ab.get("pip_cost_per_s", 0.0)) > 0.0:
		h["pip_t"] = float(h["pip_t"]) + delta * float(ab["pip_cost_per_s"])
		while float(h["pip_t"]) >= 1.0:
			h["pip_t"] = float(h["pip_t"]) - 1.0
			if spend_pips(1) < 1:
				_end_held()                      # Spindrift runs on your pips
				return
	h["tick"] = float(h["tick"]) - delta
	if float(h["tick"]) <= 0.0:
		h["tick"] = float(ab.get("tick", 0.5))
		_channel_pulse()


## One tick of a channel, along its shape.
func _channel_pulse() -> void:
	var h: Dictionary = _held
	var ab: Dictionary = h["ab"]
	var tags: Array = h["tags"]
	var stage_mult: float = float(h["stage_mult"])
	var payload: Dictionary = _payload(ab, "on_hit")
	var memo: Dictionary = h["memo"]
	var color: Color = GameData.affinity_color(str(h["aff"]))
	_strike_t = 0.15
	match str(ab.get("shape", "self")):
		"line":
			var origin: Vector3 = global_position + Vector3.UP * 0.9
			var reach: float = float(ab.get("range", 8.0))
			var wall: Dictionary = _ray(origin, origin + _facing * reach)
			if not wall.is_empty():
				reach = origin.distance_to(wall["position"])
			var best: Node3D = null
			for e: Node3D in _enemies_near(global_position, reach + 1.0):
				var to: Vector3 = e.global_position - global_position
				to.y = 0.0
				var along: float = to.dot(_facing)
				if along >= 0.0 and along <= reach and (to - _facing * along).length() <= float(ab.get("width", 1.0)) * 0.5 + float(e.get("radius")):
					if best == null or along < (best.global_position - global_position).dot(_facing):
						best = e
			_line_visual(origin, (best.global_position + Vector3.UP * 0.9) if best != null else origin + _facing * reach, color)
			if best != null:
				apply_hit(best, payload, tags, stage_mult, _facing, memo)
		"cone":
			var half: float = deg_to_rad(float(ab.get("arc_deg", 60.0)) * 0.5)
			_swing_visual(float(ab.get("range", 5.0)), false, false)
			for e: Node3D in _in_arc(float(ab.get("range", 5.0)), half):
				apply_hit(e, payload, tags, stage_mult, Vector3.ZERO, memo)
		"nearest":
			var near: Node3D = _nearest_enemy_to(global_position, float(ab.get("radius", 3.0)))
			if near != null:
				_line_visual(global_position + Vector3.UP, near.global_position + Vector3.UP, color)
				apply_hit(near, payload, tags, stage_mult, Vector3.ZERO, memo)
		"tether":
			var t: Variant = h["target"]
			if t == null or not is_instance_valid(t) or bool((t as Node).call("is_dead")) \
					or (t as Node3D).global_position.distance_to(global_position) > float(ab.get("break_range", 9.0)) \
					or not _ray(global_position + Vector3.UP, (t as Node3D).global_position + Vector3.UP).is_empty():
				_held = {}
				return
			_line_visual(global_position + Vector3.UP, (t as Node3D).global_position + Vector3.UP, color)
			apply_hit(t, payload, tags, stage_mult, Vector3.ZERO, memo)
		_:
			# self: everything round you (Deep Draught draws blood out; Regrowth mends you)
			if float(ab.get("sink_per_s", 0.0)) > 0.0:
				var pts: float = float(ab["sink_per_s"]) * float(ab.get("tick", 0.5))
				var filled: Dictionary = body.fill_sinks(pts, true)
				_wounds_closed(filled["closed"])
				if body.has_wound("lost_arm") and float(ab.get("arm_rate", 0.0)) > 0.0:
					var arm_fill: Dictionary = body.fill_one("lost_arm", pts * float(ab["arm_rate"]))     # a lost arm mends too, slower
					_wounds_closed(arm_fill["closed"])
				return
			var taken := 0
			for e: Node3D in _enemies_near(global_position, float(ab.get("radius", 5.0))):
				var take: Dictionary = payload.get("consume_stacks", {})
				var had := true
				for st: String in take:
					had = had and bool(e.call("has_status", st))
				if not had:
					continue
				_line_visual(e.global_position + Vector3.UP, global_position + Vector3.UP, color)
				for st2: String in take:
					var left: int = int(e.call("status_stacks", st2)) - int(take[st2])
					var entry: Dictionary = (e.get("statuses") as Dictionary).get(st2, {})
					if left <= 0:
						e.call("clear_status", st2)
					elif not entry.is_empty():
						entry["stacks"] = left
					taken += int(take[st2])
				var p2: Dictionary = payload.duplicate()
				p2.erase("consume_stacks")
				apply_hit(e, p2, tags, stage_mult, Vector3.ZERO, memo)
			for i: int in int(ab.get("pools_per_tick", 0)):
				var pool: BloodPool = null
				for node: Node in get_tree().get_nodes_in_group("blood_pools"):
					if (node as Node3D).global_position.distance_to(global_position) <= float(ab.get("radius", 5.0)):
						pool = node as BloodPool
						break
				if pool == null:
					break
				taken += pool.drink()
			gain_blood(taken * int(ab.get("blood_per_take", 1)))


## Let go of a held skill: a charge goes off; a channel simply stops.
func _end_held() -> void:
	if _held.is_empty():
		return
	if str(_held["kind"]) == "charge_release":
		_release_charge()
		return
	_held = {}
	_recover_t = maxf(_recover_t, GameData.num("abilities", "cast_recovery"))


## A charge is let go: the longer it was held, the harder it lands (damage toward damage_full, or
## from damage_min; damage_mult from damage_mult_min; more marks by charge).
func _release_charge() -> void:
	var h: Dictionary = _held
	_held = {}
	var ab: Dictionary = (h["ab"] as Dictionary).duplicate(true)
	var frac: float = clampf(float(h["t"]) / maxf(0.01, float(ab.get("charge_max", 1.0))), 0.0, 1.0)
	if ab.has("damage_full"):
		ab["damage"] = lerpf(float(ab["damage"]), float(ab["damage_full"]), frac)
	elif ab.has("damage_min"):
		ab["damage"] = lerpf(float(ab["damage_min"]), float(ab["damage"]), frac)
	if ab.has("damage_mult_min"):
		ab["damage_mult"] = lerpf(float(ab["damage_mult_min"]), float(ab["damage_mult"]), frac)
	if ab.has("marks_by_charge"):
		var steps: Array = ab["marks_by_charge"]
		var hit: Dictionary = (ab.get("on_hit", {}) as Dictionary).duplicate()
		hit["marks"] = int(steps[clampi(int(frac * float(steps.size()) - 0.001), 0, steps.size() - 1)])
		ab["on_hit"] = hit
	var stage_mult: float = float(h["stage_mult"])
	var tags: Array = h["tags"]
	_float("release", GameData.affinity_color(str(h["aff"])).lightened(0.3))
	match str(ab.get("release", "")):
		"delayed_blast":
			if ab.has("on_hit") and not (ab["on_hit"] as Dictionary).has("damage"):
				var hit2: Dictionary = (ab["on_hit"] as Dictionary).duplicate()
				hit2["damage"] = float(ab["damage"])
				ab["on_hit"] = hit2
			_start_blast(_aim_point(float(ab.get("range", 12.0))), ab, stage_mult, tags)
		"beam":
			ab["width"] = float(ab.get("line_width", ab.get("width", 1.0)))
			_fire_beam(ab, stage_mult, GameData.affinity_color(str(h["aff"])), tags)
		_:
			_burst(ab, stage_mult, tags + ["melee"])
	_recover_t = maxf(_recover_t, GameData.num("abilities", "cast_recovery"))


## Lift every zone of yours of that kind in range (Daybreak): on_hit to everyone standing in one.
func _lift_zones(ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var want: String = str(ab["consume_zone"])
	for node: Node in get_tree().get_nodes_in_group("ground_zones").duplicate():
		var z := node as GroundZone
		if z == null or z.caster != self or z.kind != want or z.from.distance_to(global_position) > float(ab.get("range", 12.0)):
			continue
		for e: Node3D in z.inside():
			apply_hit(e, _payload(ab, "on_hit"), tags, stage_mult)
		z.end()


## Pour every other dosed enemy's doses into one (Funnel).
func _gather(target: Node3D, ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var id: String = str(ab.get("consume_status", "dosed"))
	var total := 0
	for e: Node3D in _enemies_near(target.global_position, float(ab.get("gather_radius", 6.0))):
		if e == target or not bool(e.call("has_status", id)):
			continue
		total += int(e.call("status_stacks", id))
		e.call("clear_status", id)
		_line_visual(e.global_position + Vector3.UP, target.global_position + Vector3.UP, GameData.affinity_color(str(ab.get("affinity", ""))))
	var cap: int = int(ab.get("gather_cap", 20))
	var have: int = int(target.call("status_stacks", id)) if bool(target.call("has_status", id)) else 0
	var add: int = mini(total, cap - have)
	if add > 0:
		target.call("add_status", id, 0, self)
		var entry: Dictionary = (target.get("statuses") as Dictionary).get(id, {})
		if not entry.is_empty():
			entry["stacks"] = have + add            # above the usual cap: gathered doses may go to gather_cap
	if ab.has("on_hit"):
		apply_hit(target, _payload(ab, "on_hit"), tags, stage_mult)


## The heart hammers: `beats` times, beat_s apart, every enemy near you carrying the status pays
## per stack it holds then, and the stacks stay (Hammering Heart).
func _beats(ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var id: String = str(ab.get("needs_status", ab.get("consume_status", "bleeding")))
	var reach: float = float(ab.get("range", 10.0))
	SkillTimer.after(get_parent(), 0.0, func(_i: int) -> void:
		if not is_instance_valid(self):
			return
		for e: Node3D in _enemies_near(global_position, reach):
			var n: int = int(e.call("status_stacks", id)) if bool(e.call("has_status", id)) else 0
			if n <= 0:
				continue
			deal_damage(e, float(ab.get("per_stack_damage", 8.0)) * float(n) * stage_mult, tags + ["beat"])
			if is_instance_valid(e) and not bool(e.call("is_dead")) and ab.has("on_hit"):
				apply_hit(e, ab["on_hit"], tags, stage_mult)
			if int(ab.get("pool_per_beat", 0)) > 0 and is_instance_valid(e):
				spill_blood(e.global_position, int(ab["pool_per_beat"])), int(ab.get("beats", 3)) - 1, float(ab.get("beat_s", 0.5)))


## The light comes home (Gathered Light): every other enemy on the straight line from it to you
## takes the ray; walls and stone end it.
func _home_ray(from: Vector3, skip: Node3D, damage: float, tags: Array) -> void:
	var to: Vector3 = global_position
	var hit: Dictionary = _ray(from + Vector3.UP, to + Vector3.UP)
	if not hit.is_empty():
		return
	_line_visual(from + Vector3.UP, to + Vector3.UP, GameData.affinity_color("light"))
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	for e: Node3D in _enemies_near((from + to) * 0.5, from.distance_to(to) * 0.5 + 1.0):
		if e == skip:
			continue
		var p := Vector2(e.global_position.x, e.global_position.z)
		if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= 0.6 + float(e.get("radius")):
			deal_damage(e, damage, tags + ["ray"])


## prop: a slab of stone (raise_stone), or a lamp, or a likeness of you that draws enemies.
func _raise_prop(at: Vector3, ab: Dictionary, stage_mult: float, tags: Array) -> void:
	match str(ab.get("shape", "")):
		"lamp":
			for l: Node in get_tree().get_nodes_in_group("lamps"):
				if l.get("caster") == self:
					l.queue_free()                   # one lamp at a time
			var lamp := Lamp.new()
			lamp.caster = self
			lamp.life = float(ab.get("life", 12.0))
			lamp.light_radius = float(ab.get("light_radius", 5.0))
			lamp.tick_s = float(ab.get("tick_s", 0.5))
			lamp.payload = ab.get("payload", {})
			lamp.tags = tags
			lamp.color = GameData.affinity_color(str(ab.get("affinity", "")))
			get_parent().add_child(lamp)
			lamp.global_position = Vector3(at.x, global_position.y, at.z)
			return
	if ab.has("collapse_radius") or (ab.has("blocks") and not bool(ab["blocks"])):
		# a likeness of you: enemies within radius turn on it, and it falls apart when it breaks
		_leave_lure(at, {"life": float(ab.get("life", 5.0)), "hp": float(ab.get("hp", 150.0)), "radius": float(ab.get("radius", 6.0)),
			"breaks_on_hits": 0, "collapse": {"damage": float(ab.get("damage", 40.0)) * stage_mult},
			"collapse_radius": float(ab.get("collapse_radius", 3.0))}, str(ab.get("affinity", "")), tags)
		return
	# heartwood: a growing stone that only one may stand of, and that puts out growth
	if int(ab.get("max_count", 0)) > 0:
		var count := 0
		for s: Variant in stones.duplicate():
			if is_instance_valid(s) and (s as Stone).get_meta("ability", "") == str(ab.get("name", "")):
				count += 1
				if count >= int(ab["max_count"]):
					(s as Stone).crumble()
	var stone: Node3D = raise_stone(at, _facing, ab, stage_mult, tags)
	stone.set_meta("ability", str(ab.get("name", "")))
	if float(ab.get("hp_per_s", 0.0)) > 0.0 or float(ab.get("spread_every", 0.0)) > 0.0:
		var grow_t := [0.0]
		var kind_g: String = str(ab.get("spread_kind", "bramble"))
		var every: float = float(ab.get("spread_every", 5.0))
		var per_s: float = float(ab.get("hp_per_s", 0.0))
		SkillTimer.after(get_parent(), 1.0, func(_i: int) -> void:
			if not is_instance_valid(stone) or stone.is_queued_for_deletion():
				return
			stone.set("hp", float(stone.get("hp")) + per_s)
			grow_t[0] = float(grow_t[0]) + 1.0
			if every > 0.0 and float(grow_t[0]) >= every:
				grow_t[0] = 0.0
				plant_growth(stone.global_position + _facing * 1.2, {"kind": kind_g}), int(ab.get("life", 30.0)), 1.0)


## Ground a burst leaves under you: dark ground round you (Hungry Dark), or along the cone (Night Spill).
func _lay_ground(cfg: Dictionary, reach: float, ab: Dictionary, tags: Array) -> void:
	var zone := GroundZone.new()
	zone.caster = self
	zone.dark = bool(cfg.get("dark", false))
	zone.kind = "dark_ground" if zone.dark else str(cfg.get("kind", ""))
	zone.life = float(cfg.get("life", 5.0))
	zone.bright = false
	zone.tags = tags + ["zone"]
	zone.color = GameData.affinity_color(str(ab.get("affinity", "")))
	if str(cfg.get("shape", "circle")) == "cone":
		zone.shape = "strip"
		zone.from = global_position
		zone.to = global_position + _facing * reach
		zone.width = reach * 0.8
	else:
		zone.shape = "circle"
		zone.radius = float(cfg.get("radius", 3.0))
		zone.from = global_position
		zone.to = global_position
	get_parent().add_child(zone)


## A bolt has stopped (a wall, its range, its last body): what it leaves there - a trail behind it,
## dark ground, a burst on a corpse it struck.
func projectile_landed(from: Vector3, at: Vector3, ab: Dictionary, tags: Array) -> void:
	if not is_inside_tree() or ab.is_empty():
		return
	if ab.has("trail"):
		var cfg: Dictionary = ab["trail"]
		var zone := GroundZone.new()
		zone.from = Vector3(from.x, global_position.y, from.z)
		zone.to = Vector3(at.x, global_position.y, at.z)
		zone.width = float(cfg.get("width", 1.0))
		zone.life = float(cfg.get("life", 3.0))
		zone.tick_s = float(cfg.get("tick_s", 1.0))
		zone.payload = cfg.get("payload", {})
		zone.tags = tags + ["zone"]
		zone.caster = self
		zone.bright = false
		zone.color = GameData.affinity_color(str(ab.get("affinity", "")))
		get_parent().add_child(zone)
	if ab.has("zone"):
		var cfg2: Dictionary = ab["zone"]
		var dz := GroundZone.new()
		dz.shape = "circle"
		dz.caster = self
		dz.dark = bool(cfg2.get("dark", false))
		dz.kind = "dark_ground" if dz.dark else ""
		dz.radius = float(cfg2.get("radius", 2.5))
		dz.life = float(cfg2.get("life", 6.0))
		dz.bright = false
		dz.tags = tags + ["zone"]
		dz.color = GameData.affinity_color(str(ab.get("affinity", "")))
		dz.from = Vector3(at.x, global_position.y, at.z)
		dz.to = dz.from
		get_parent().add_child(dz)


## A bolt that may strike corpses met one (Rotting Bolt): it bursts and is spent.
func projectile_hit_corpse(f: Fallen, ab: Dictionary, tags: Array, stage_mult: float) -> void:
	if f == null or f.spent:
		return
	var at: Vector3 = f.global_position
	f.spend()
	FloatText.spawn(get_parent(), at + Vector3.UP * 0.5, "BURST", GameData.affinity_color(str(ab.get("affinity", ""))))
	var burst: Dictionary = (ab.get("corpse_burst", {}) as Dictionary).duplicate()
	burst["burst_radius"] = float(burst.get("radius", 2.5))
	_burst_at(at, burst, tags + ["corpse"], stage_mult)


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
	# the strike's reach is not drawn (Brent 2026-10-18: "a hit box on attack that is visible ...
	# needs to be invisible"); the body's own swing shows it. --show-reach brings the box back to debug.
	if not is_inside_tree() or not OS.get_cmdline_user_args().has("--show-reach"):
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
