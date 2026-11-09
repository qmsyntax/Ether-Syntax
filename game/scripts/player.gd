class_name Player
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
## A star ascended; `ascension_pending` holds its offer and boosts until resolve_ascension.
signal ascended(star: int)

const FloatText := preload("res://scripts/float_text.gd")
const Projectile := preload("res://scripts/projectile.gd")
## The rune engine's path helpers (get_path_value, is_numeric), shared so a patch and a preview read paths alike.
const _Fx := preload("res://scripts/runes/interactions/effects_v1.gd")
const TALENT_SCRIPT_DIR := "res://scripts/talents/"
const ISO_YAW := deg_to_rad(45.0)

## The player's parts, one per concern (docs/architecture/player-split.md). Each holds that concern's
## logic and its private state, with a typed back-reference to this node; shared and saved state stays
## here, and the forwarders at the end of this file keep every outside caller unchanged.
var save_part: PlayerSave
var bot_part: PlayerBot
var economy_part: PlayerEconomy
var progress_part: PlayerProgression
var runes_part: PlayerRunes
var motion_part: PlayerMotion
var combat_part: PlayerCombat
var hits_part: PlayerHits
var casting_part: PlayerCasting

var body: Body
var talent_id := ""
## Who this is (character creation). `look` is a CharacterLook dictionary of option ids.
var char_name := ""
## Which character this is, across all its saves (SaveGame.new_char_id; given on its first save).
## A hardcore death removes every save carrying it (SaveGame.clear_character).
var char_id := ""
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
		return casting_part.reflux_of(casting_part.primary_affinity())
	set(value):
		reflux_by[casting_part.primary_affinity()] = value
var reflux_locked: bool:
	get:
		return casting_part.is_locked(casting_part.primary_affinity())
	set(value):
		locked_by[casting_part.primary_affinity()] = value
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
## - mode "bind": the skill's next level lock, its ring built and a construct chosen on the seal
## screen (construct -1: none chosen yet). There is no other mode since Brent 2026-10-23.
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
## The ascension not yet settled (saved): {star, offer: [affinity ids], skills: [{index, id, stage,
## amount}]}; {} when there is none. See _begin_ascension / resolve_ascension.
var ascension_pending: Dictionary = {}
## Constructs carried, waiting to be bound: [{tier, concept}] - "concept" is the word it carries (a rune id
## for a vestige, an authored word id above; constructs.json words, ConstructWords). Source: the Netherecho.
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
## The ward pool (v2: Holy, Water's Crush, Ice Shell, Black Shroud - one pool, balance.json "ward" cap): each part
## {amount, t, from, on_break, expire_heal_frac, no_stagger}, the oldest first. See add_ward / _ward_takes.
var ward_parts: Array = []


## Ambush (Dark's rule): the cast you started while Unseen keeps that for its own hits a moment (casting shows you).
var _cast_hidden_t := 0.0
## Edge Heat (Metal's rule): stacks on the one enemy your metal blows keep landing on; see _edge_heat.
var focus := 0
var _focus_target: Node = null
var _focus_t := 0.0
var _focus_fill_next := false
## Bodies you died in and have not recovered: {id, where, chamber, pos, equipped, bag}.
var corpses: Array = []
## What you have seen of each overland zone: zone id -> FogMap.to_text().
var explored: Dictionary = {}
var rod: Node3D                      # the one Ground Rod standing, if any
var _dash_braced := false
var _dash_on_stop: Dictionary = {}
var _dash_heavy_poise := 0.0
## Where the cursor is taken to be when set: a test or a bot pointing with no mouse.
var cursor_fixed: Variant = null
## True while the ranged stance is held with a ranged weapon equipped: the strike button shoots.
var ranged_stance := false
var _rig: ModelRig
var _strike_t := 0.0
var _shown_arm_lost := false
var _shown_glow := 0
var _router: Node                          # main, read for where the body stands (_stance_place)
var _shown_windup := false
## Blood's held blood (2026-10-22): measures carried outside your own veins, 0..held_blood_max.
## Filled by drinking, spent by blood skills. It is never health and never heals.
var held_blood := 0
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
# The feel of the controls (balance.json "feel", the "# --- feel" block at the end of this file).
var _buffered_slot := -1             # a hotbar key pressed while busy, cast when you are free
var _strike_credit := 0              # clicks on the attack target not yet swung
var _face_hold_t := 0.0              # after a cast you keep facing where it went
var _face_dir := Vector3.ZERO
var _snap_body := true
var _motion_started := false         # the wind-up already started the cast's motion
## A landed hit, for whatever wants to answer it (a sound, later): strength 0 light, 1 heavy, 2 taken.
signal impact(strength: int, at: Vector3)

# Tuning (GameData).
var _p: Dictionary
var _arm: Dictionary
var _reflux_cfg: Dictionary
var _heal_cfg: Dictionary
var _natural: Dictionary
var melee_range := 2.3
var melee_arc := deg_to_rad(75.0)


func _init() -> void:
	save_part = PlayerSave.new(self)
	bot_part = PlayerBot.new(self)
	economy_part = PlayerEconomy.new(self)
	progress_part = PlayerProgression.new(self)
	runes_part = PlayerRunes.new(self)
	motion_part = PlayerMotion.new(self)
	combat_part = PlayerCombat.new(self)
	hits_part = PlayerHits.new(self)
	casting_part = PlayerCasting.new(self)
	_p = GameData.balance["player"]
	_arm = GameData.balance["arm"]
	_reflux_cfg = GameData.balance["reflux"]
	_heal_cfg = GameData.balance["healer"]
	_natural = GameData.balance["natural_healing"]
	body = Body.new(float(_p["health"]))
	body.min_max_frac = 1.0 - float(GameData.balance["wounds"]["max_cut_frac"])
	RngSeed.apply(rng, "player")
	star_pct = [GameData.num("stars", "first_star_start_pct")]
	progress_part._recompute_essence_max()
	essence = essence_max
	inventory = Inventory.new()
	economy_part.refresh_gear()
	_aura_threshold = float(_p["aura_threshold"])
	arm_right = float(_arm["max"])
	melee_range = float(_p["melee_range"])
	melee_arc = deg_to_rad(float(_p["melee_arc_deg"]))
	var slots: int = GameData.inum("abilities", "hotbar_slots")
	for i: int in slots:
		hotbar.append(-1)
	affinities = GameData.default_affinities()
	casting_part._reset_loadout()
	progress_part._reset_tempering()
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
		economy_part._show_weapon()


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
	if _rig.has_method("set_stance"):          # relaxed in town, the guard in the field (wardrobe "stances")
		_rig.call("set_stance", _stance_place())
	motion_part._feel_model(delta)
	_rig.animate(delta, velocity.length(), _strike_t > 0.0)


## Where the body is, for its still loop: main.state ("town", "field", "dungeon", ...), "" without a game.
func _stance_place() -> String:
	if _router == null or not is_instance_valid(_router):
		_router = get_tree().get_first_node_in_group("router")
	return str(_router.get("state")) if _router != null else ""


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
	ascension_pending = {}
	casting_part._reset_loadout()
	casting_part.clear_reflux()
	progress_part._reset_tempering()
	known_runes.clear()
	read_inscriptions.clear()
	seal_draft = {}
	runes_part._grant_start_runes()


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
	motion_part._tick_endurance(delta)
	_brace_t -= delta
	_rear_window_t -= delta
	_unseen_reveal_t -= delta
	casting_part._tick_buffs(delta)
	combat_part._tick_ward(delta)
	combat_part._tick_regen(delta)
	_focus_t -= delta
	_cast_hidden_t -= delta
	hits_part._tick_roles(delta)
	if _focus_t <= 0.0 and focus > 0:
		focus = 0                                # Edge Heat cools when no metal blow lands for focus_cools_s
	hits_part._tick_stores(delta)
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
		casting_part._shed_reflux(float(_reflux_cfg["shed_meditating"]) * delta)
		progress_part._meditate_gather(delta)
		progress_part.grow_star(GameData.num("stars", "growth_pct_per_s_meditating") * delta)
		velocity = Vector3.ZERO
		_update_model(delta)
		return
	if bot:
		bot_part._bot_think(delta)
	else:
		motion_part._update_aim()
	if _windup_t > 0.0:
		casting_part._tick_windup(delta)
	if not _held.is_empty():
		_tick_held(delta)
	motion_part._tick_buffer(delta)
	motion_part._tick_step_buffer(delta)

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
	casting_part._shed_reflux(shed * delta)
	progress_part._meditate_gather(delta)
	if meditating:
		progress_part.grow_star(GameData.num("stars", "growth_pct_per_s_meditating") * delta)

	# The body mends itself between fights - but only what a body can mend.
	if not in_combat and not hits_part._heal_blocked():
		body.heal(float(_natural["health_per_s"]) * delta)      # the bar only - never a wound
		if not arm_right_lost:
			arm_right = minf(float(_arm["max"]), arm_right + float(_natural["arm_per_s"]) * delta)

	var charging_input: bool = Input.is_action_pressed("overcharge") and not arm_right_lost
	if charging_input and not _sitting and _windup_t <= 0.0:
		_charging = true
		_charge = minf(float(_p["charge_max"]), _charge + delta)
	elif _charging:
		combat_part._release_overcharge()

	motion_part._tick_move(delta)


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
		zone.life = minf(float(cfg.get("life_max", 99.0)), zone.life + float(cfg["life_per_heat"]) * casting_part.reflux_of(str(ab.get("affinity", ""))))
	if float(ab.get("pip_seconds", 0.0)) > 0.0 and motion_part.has_slipstream():
		var burned: int = motion_part.spend_pips(-1 if bool(ab.get("spend_all_pips", false)) else int(ab.get("spend_pips", 0)))
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
	zone.dps_mult = cfg.get("dps_mult", {})
	zone.bill_bonus = float(cfg.get("dose_bonus", 0.0))
	zone.ally_payload = cfg.get("ally_payload", {})
	if cfg.has("lit_bonus"):
		zone.bonus_vs = {"lit": float(cfg["lit_bonus"])}
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
	for e: Node3D in casting_part._enemies_near(rod.global_position, float(ab.get("relay_range", 5.0))):
		if pick == null or e.global_position.distance_to(rod.global_position) < pick.global_position.distance_to(rod.global_position):
			pick = e
	if pick == null:
		return
	casting_part._line_visual(rod.global_position + Vector3.UP * 2.0, pick.global_position + Vector3.UP, GameData.affinity_color("lightning"))
	hits_part.apply_hit(pick, ab.get("relay_hit", {}), ["ability", "lightning", "ground_rod"], stage_mult)


## A dash that does not pass through people has met one: it is thrown, or - if it is heavy - it
## holds, and only loses its footing.
func _dash_met(e: Node3D) -> void:
	if _dash_on_stop.is_empty():
		return
	if float(e.get("shove_resist")) < 1.0 and _dash_heavy_poise > 0.0:
		e.call("take_poise", _dash_heavy_poise)
		return
	hits_part.apply_hit(e, _dash_on_stop, _dash_tags, 1.0, _dash_vel.normalized())


## displace: move enemies instead of hurting them. See abilities.json for the three modes.
func _displace(point: Vector3, target: Node3D, ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var color: Color = GameData.affinity_color(str(ab.get("affinity", "")))
	var chest: Vector3 = global_position + Vector3.UP
	_strike_t = 0.2
	if str(ab.get("mode", "")) == "throw_target":
		_throw(target, point, ab, stage_mult, tags)
		return
	if str(ab.get("mode", "")) == "pull_target":
		if target == null:
			return
		casting_part._line_visual(chest, target.global_position + Vector3.UP, color)
		hits_part.apply_hit(target, hits_part._payload(ab, "on_hit"), tags, stage_mult)
		if is_instance_valid(target) and not bool(target.call("is_dead")):
			target.set("shover", self)
			target.call("pull_toward", global_position, float(ab.get("pull", 10.0)), float(ab.get("keep", 1.5)) + float(target.get("radius")))
			target.call("turn_away_from", global_position, float(ab.get("turn_s", 1.0)))
		return
	casting_part._line_visual(chest, point + Vector3.UP * 0.3, color)
	var burned: int = motion_part.spend_pips(int(ab["spend_pips"])) if ab.has("spend_pips") else 0
	var from_point: bool = str((ab.get("on_hit", {}) as Dictionary).get("shove_dir", "")) == "from_point"
	for e: Node3D in casting_part._enemies_near(point, float(ab.get("radius", 3.0))):
		hits_part.apply_hit(e, hits_part._payload(ab, "on_hit"), tags, stage_mult, (e.global_position - point) if from_point else Vector3.ZERO)
		if not is_instance_valid(e) or bool(e.call("is_dead")):
			continue
		if str(ab.get("mode", "")) == "pull_area":
			e.set("shover", self)
			e.call("pull_toward", point, float(ab.get("pull", 4.0)))
		elif burned > 0 and bool(e.call("has_status", "aloft")):
			var up: Dictionary = (e.get("statuses") as Dictionary)["aloft"]
			up["t"] = float(up["t"]) + float(ab.get("pip_seconds", 0.2)) * float(burned)


## Overboard (displace mode throw_target): the one enemy in reach is lifted and thrown toward where you aim, up to
## `throw` m (a heavy one half as far, by its shove class; an elite only staggers). It travels as a shove, so a wall,
## stone or body it meets is a Crush; where it stops, on_land hits every other enemy within its radius.
var _landings: Dictionary = {}

func _throw(target: Node3D, point: Vector3, ab: Dictionary, stage_mult: float, tags: Array) -> void:
	if target == null or not is_instance_valid(target):
		return
	casting_part._line_visual(global_position + Vector3.UP, target.global_position + Vector3.UP * 1.5, GameData.affinity_color(str(ab.get("affinity", ""))))
	hits_part.apply_hit(target, hits_part._payload(ab, "on_hit"), tags, stage_mult)
	if not is_instance_valid(target) or bool(target.call("is_dead")):
		return
	if target.has_method("is_elite") and bool(target.call("is_elite")):
		target.call("stagger", float(GameData.status("staggered").get("lasts", 1.5)))
		return
	if point == Vector3.ZERO:
		point = motion_part._cursor_ground()                 # a targeted cast has no aimed point of its own: where you point
	var way: Vector3 = point - target.global_position
	way.y = 0.0
	if way.length() < 0.3:
		way = _facing
	var land: Dictionary = (ab.get("on_land", {}) as Dictionary).duplicate()
	if not land.is_empty():
		land["burst_radius"] = float(land.get("radius", 1.5))
		_landings[target.get_instance_id()] = {"payload": land, "tags": tags, "stage_mult": stage_mult}
	target.set("shover", self)
	target.call("shove", way, minf(float(ab.get("throw", 6.0)), way.length()))


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
	if bool(ab.get("follows_lit", false)):
		# Burning Glass: cast on a Lit enemy it tracks it, landing where that enemy is when the delay ends
		var lit_t: Node3D = casting_part._nearest_enemy_to(point, 1.5)
		if lit_t != null and bool(lit_t.call("has_status", "lit")):
			blast.follow = lit_t
	_strike_t = 0.2


## A delayed blast goes off at `at` (called by the DelayedBlast). It may leave a cloud or a patch.
func land_blast(at: Vector3, ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var radius: float = float(ab.get("radius", 2.0))
	for e: Node3D in casting_part._enemies_near(at, radius):
		var marked: bool = ab.has("bonus_vs_status") and bool(e.call("has_status", str(ab["bonus_vs_status"])))
		hits_part.apply_hit(e, hits_part._payload(ab, "on_hit"), tags, stage_mult)
		if marked and is_instance_valid(e) and not bool(e.call("is_dead")):
			combat_part.deal_damage(e, float(ab.get("bonus_damage", 0.0)) * stage_mult, tags + ["bonus"])
	if ab.has("leave_zone"):
		hits_part.lay_cloud(at, ab["leave_zone"], tags + ["cloud"])
	if ab.has("leave_growth"):
		hits_part.plant_growth(at, ab["leave_growth"])
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
	if ab.has("clock_to"):
		_spur(ab)
		return
	if bool(ab.get("consume_thralls", false)):
		# Bone Burst: every thrall of yours in range ends at once, each bursting for damage + hp_frac of its health
		for s: Node3D in summons_near(global_position, float(ab.get("range", 12.0))):
			var burst: Dictionary = hits_part._payload(ab, "on_hit")
			burst["damage"] = (float(ab.get("damage", 70.0)) + float(ab.get("hp_frac", 0.0)) * float(s.get("hp"))) * stage_mult
			burst["burst_radius"] = float(ab.get("burst_radius", 2.5))
			casting_part._line_visual(global_position + Vector3.UP, s.global_position + Vector3.UP, color)
			hits_part._burst_at(s.global_position, burst, tags + ["burst"])
			s.call("_fall")
		return
	if int(ab.get("max_sites", 0)) > 0:
		_exhume(ab, stage_mult, tags)
		return
	var ids: Array = ab["consume_status"] if ab.get("consume_status") is Array else [str(ab.get("consume_status", ""))]
	var status: String = str(ids[0])
	var carrying: Array = []
	for e: Node3D in casting_part._enemies_near(global_position, float(ab.get("range", 10.0))):
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
		if bool(ab.get("needs_clear_line", false)) and not casting_part._ray(global_position + Vector3.UP, where + Vector3.UP).is_empty():
			continue                             # no clear line home: its light stays where it is
		casting_part._line_visual(global_position + Vector3.UP, where + Vector3.UP, color)
		refund += float(ab.get("refund_per_stack", 0.0)) * float(stacks)
		if ab.has("per_stack_damage") and is_instance_valid(carrier):
			combat_part.deal_damage(carrier, float(ab["per_stack_damage"]) * float(stacks) * stage_mult, tags + ["burst"])
		if int(ab.get("stagger_at", 0)) > 0 and stacks >= int(ab["stagger_at"]) and is_instance_valid(carrier) and not bool(carrier.call("is_dead")):
			carrier.call("stagger", float(GameData.status("staggered").get("lasts", 1.5)))     # Crisis: a full fever breaks it
		if ab.has("per_target_damage") and is_instance_valid(carrier):
			combat_part.deal_damage(carrier, (float(ab["per_target_damage"]) + (float(ab.get("bonus_vs_asleep", 0.0)) if bool(row[3]) else 0.0)) * stage_mult, tags + ["burst"])
		if ab.has("on_hit") and is_instance_valid(carrier) and not bool(carrier.call("is_dead")):
			if ab.has("burst_radius"):
				hits_part._burst_at(where, hits_part._payload(ab, "on_hit").merged({"burst_radius": float(ab["burst_radius"])}, true), tags + ["burst"], stage_mult, carrier)
			else:
				hits_part.apply_hit(carrier, hits_part._payload(ab, "on_hit"), tags, stage_mult)
		if str(ab.get("after_status", "")) != "" and is_instance_valid(carrier) and not bool(carrier.call("is_dead")):
			carrier.call("add_status", str(ab["after_status"]), 1, self)
		if float(ab.get("ray_damage", 0.0)) > 0.0:
			_home_ray(where, carrier, float(ab["ray_damage"]) * stage_mult, tags)
		if ab.has("per_stack_burst"):
			for near: Node3D in casting_part._enemies_near(where, float(ab.get("burst_radius", 2.0))):
				combat_part.deal_damage(near, float(ab["per_stack_burst"]) * float(stacks) * stage_mult, tags + ["burst"])
		if ab.has("overload_fracs"):
			var fracs: Array = ab["overload_fracs"]
			var frac: float = float(fracs[mini(stacks, fracs.size()) - 1])
			var live: Dictionary = GameData.status("live")
			var e: Node3D = row[0]
			if is_instance_valid(e) and not bool(e.call("is_dead")):
				FloatText.spawn(get_parent(), where + Vector3.UP * 0.6, "OVERLOAD", Color(0.85, 0.78, 1.0))
				combat_part.deal_damage(e, float(live.get("overload_damage", 150.0)) * frac * stage_mult, tags + ["overload"])
				if is_instance_valid(e) and not bool(e.call("is_dead")):
					e.call("stun", float(live.get("stun", 1.0)) * frac)
	if refund > 0.0:
		essence = minf(essence_max, essence + minf(refund, float(ab.get("cost", 0.0))))
	if ab.has("decoy_burst"):
		var db: Dictionary = ab["decoy_burst"]
		for l: Node in get_tree().get_nodes_in_group("lures"):
			if l is Lure and (l as Lure).caster == self and (l as Node3D).global_position.distance_to(global_position) <= float(ab.get("range", 10.0)):
				hits_part._burst_at((l as Node3D).global_position, {"damage": float(db.get("damage", 40.0)), "burst_radius": float(db.get("radius", 2.0))}, tags + ["burst"], stage_mult)
				(l as Lure).call("_break")


## Exhume: every corpse in range (spent if spends_corpse) and every point where an Infected enemy died within
## recent_infected_death_s count as sites, nearest first, up to max_sites; each bursts on_hit and leaves leave_zone.
var _death_sites: Dictionary = {}         # status id -> [{at, t}]: where bodies died carrying it (enemy.gd, status_death)
var _clock := 0.0                         # game time, for how recent a death is

func status_death(id: String, at: Vector3) -> void:
	var list: Array = _death_sites.get(id, [])
	list.append({"at": at, "t": _clock})
	_death_sites[id] = list


func _exhume(ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var sites: Array = []
	var now: float = _clock
	var site_status: String = str(hits_part._payload(ab, "on_hit").get("status", "infected"))
	for node: Node in get_tree().get_nodes_in_group("fallen"):
		var f := node as Fallen
		if f != null and not f.spent and f.global_position.distance_to(global_position) <= float(ab.get("range", 10.0)):
			sites.append([f.global_position.distance_to(global_position), f.global_position, f])
	var deaths: Array = _death_sites.get(site_status, [])
	for d: Dictionary in deaths.duplicate():
		if now - float(d["t"]) > float(ab.get("recent_infected_death_s", 15.0)):
			deaths.erase(d)
		elif (d["at"] as Vector3).distance_to(global_position) <= float(ab.get("range", 10.0)):
			sites.append([(d["at"] as Vector3).distance_to(global_position), d["at"], null])
	sites.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for i: int in mini(sites.size(), int(ab.get("max_sites", 4))):
		var at: Vector3 = sites[i][1]
		if sites[i][2] != null and bool(ab.get("spends_corpse", true)):
			(sites[i][2] as Fallen).spend()
		var burst: Dictionary = hits_part._payload(ab, "on_hit")
		burst["burst_radius"] = float(ab.get("burst_radius", 2.5))
		hits_part._burst_at(at, burst, tags + ["burst"], stage_mult)
		if ab.get("leave_zone") is Dictionary:
			hits_part.lay_cloud(at, ab["leave_zone"], tags + ["cloud"])


## Venom Spur (clock_to): every enemy in range carrying needs_status has that status's time cut to clock_to (never
## lengthened), and what its on_expire pays is x bill_mult this once (status data, read by the status engine).
func _spur(ab: Dictionary) -> void:
	var sid: String = str(ab.get("needs_status", "dosed"))
	for e: Node3D in casting_part._enemies_near(global_position, float(ab.get("range", 8.0))):
		var entry: Dictionary = (e.get("statuses") as Dictionary).get(sid, {})
		if entry.is_empty():
			continue
		entry["t"] = minf(float(entry["t"]), float(ab["clock_to"]))
		var data: Dictionary = entry.get("data", {})
		data["bill_mult"] = float(ab.get("bill_mult", 1.0))
		entry["data"] = data
		casting_part._line_visual(global_position + Vector3.UP, e.global_position + Vector3.UP, GameData.affinity_color(str(ab.get("affinity", ""))))


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
		casting_part._line_visual(from, target.global_position + Vector3.UP, color)
		hits_part.apply_hit(target, ab.get("first_hit", hits_part._payload(ab, "on_hit")), tags, stage_mult)
		for gen: int in int(ab.get("depth", 2)):
			var next_wave: Array = []
			for w: Variant in wave:
				if not is_instance_valid(w):
					continue
				var from_dying: bool = int(ab.get("dying_stacks", 0)) > 0 and bool((w as Node).call("has_status", "dying"))
				for e: Node3D in casting_part._enemies_near((w as Node3D).global_position, float(ab.get("jump_radius", 3.0))):
					if struck.has(e) or struck.size() > int(ab.get("jumps", 7)):
						continue
					struck.append(e)
					next_wave.append(e)
					casting_part._line_visual((w as Node3D).global_position + Vector3.UP, e.global_position + Vector3.UP, color)
					var jp: Dictionary = hits_part._payload(ab, "on_hit")
					if from_dying:
						jp["stacks"] = int(ab["dying_stacks"])      # Contagion: the Dying pass on more
					hits_part.apply_hit(e, jp, tags, stage_mult)
			wave = next_wave
		return
	var hit_tags: Array = tags + (["rear"] if bool(ab.get("force_rear", false)) else [])
	for jump: int in int(ab.get("jumps", 3)) + 1:
		var at: Vector3 = cur.global_position
		if bool(ab.get("carries_caster", false)):
			# Forked Path takes you with it: you appear behind each one as it is struck; a wall or stone between ends it
			if jump > 0 and not casting_part._ray(global_position + Vector3.UP, at + Vector3.UP).is_empty():
				return
			var back: Vector3 = -(cur.get("facing") as Vector3) if cur.get("facing") is Vector3 else (at - global_position).normalized()
			back.y = 0.0
			var spot: Vector3 = at + back.normalized() * (float(cur.get("radius")) + 0.9)
			global_position = Vector3(spot.x, global_position.y, spot.z)
			var face: Vector3 = at - global_position
			face.y = 0.0
			if face.length() > 0.1:
				_facing = face.normalized()
			has_move_goal = false
		struck.append(cur)
		casting_part._line_visual(from, at + Vector3.UP, color)
		from = at + Vector3.UP
		hits_part.apply_hit(cur, hits_part._payload(ab, "on_hit"), hit_tags, stage_mult)
		var next: Node3D = null
		for e: Node3D in casting_part._enemies_near(at, float(ab.get("jump_radius", 5.0))):
			if not struck.has(e) and (next == null or e.global_position.distance_to(at) < next.global_position.distance_to(at)):
				next = e
		if next == null:
			return
		cur = next


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
	if str(ab.get("shape", "")) == "ice_wall":
		# Rime Wall: a stone of ice - as long as its length, melting when its life is out, bursting if broken early
		s.size.x = float(ab.get("length", s.size.x))
		s.shatter_burst = ab.get("shatter_burst", {})
		s.color = GameData.affinity_color(str(ab.get("affinity", ""))).darkened(0.2)
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
	var want: Vector3 = motion_part._cursor_ground() - global_position
	want.y = 0.0
	if want.length() < 0.5:
		want = _facing * reach                    # no cursor to speak of (bot, headless): straight ahead
	var dist: float = clampf(want.length(), near, reach)
	var dir: Vector3 = want.normalized()
	var chest: Vector3 = global_position + Vector3.UP
	var wall: Dictionary = casting_part._ray(chest, chest + dir * (dist + 0.6))
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
## One drain (drain_frac): you are healed that share of the harm the hit dealt, the most one cast heals drain_cap.
## The healing order is the hit's affinity's: drain_heals "bar" (Unholy: the bar only, banked as stolen life), else
## Life's order (Lifeline). Unliving targets give nothing.
var _drain_cast := 0.0


# --- skill behaviours (design/05 Appendix A) ---------------------------------------------------

## melee_burst: everything in the arc takes the payload at once, shoved straight away from you.
## It may first draw them in (pull_before_blast), spend something you carry (held blood, swallowed
## light, pips) for more, spend a status on each target (consume_status), throw spall off armour,
## cut your growth back for more, put fires out, blow clouds and shots away, and leave ground behind.
func _burst(ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var reach: float = melee_range + float(ab.get("reach_bonus", 0.0))
	var half: float = deg_to_rad(float(ab["arc_deg"]) * 0.5) if ab.has("arc_deg") else melee_arc
	_strike_t = 0.25
	combat_part._swing_visual(reach, true, false)
	var payload: Dictionary = hits_part._payload(ab, "on_hit")
	if ab.has("damage_from_heat"):
		# the heat is the damage, and it is spent: what you carry above the floor goes into the blow
		var own: String = str(ab["affinity"])
		var carried: float = casting_part.reflux_of(own)
		var floor_at: float = float(ab.get("heat_floor", 0.0))
		payload["damage"] = float(ab["damage_from_heat"]) * maxf(0.0, carried - floor_at)
		reflux_by[own] = minf(carried, floor_at)
		tags = tags + ["cold"]
	# a store spent for more: held blood (Outpour), swallowed light (Night Spill)
	var store: String = str(ab.get("consume", ""))
	if store != "":
		var n: int = hits_part.spend_blood(-1 if str(ab.get("spend_blood", "all")) == "all" else int(ab.get("spend_blood", 0))) if store == "held_blood" else hits_part.store_take(store)
		payload["damage"] = float(payload.get("damage", ab.get("damage", 0.0))) + float(ab.get("per_stack_damage", 0.0)) * float(n)
		if float(ab.get("per_stack_poise", 0.0)) > 0.0:
			var extra: float = float(ab["per_stack_poise"]) * float(n)
			if ab.has("poise_max"):
				extra = minf(extra, float(ab["poise_max"]))          # Black Reckoning: that much poise too, up to 60
			payload["poise"] = float(payload.get("poise", GameData.num("combat", "skill_poise"))) + extra
		if ab.has("daze_at") and n >= int(ab["daze_at"]):
			var dazes: Array = (payload.get("statuses", []) as Array).duplicate()
			dazes.append({"id": "dazed", "stacks": 1})
			payload["statuses"] = dazes
		if int(ab.get("pools_per_two_spent", 0)) > 0:
			for i: int in int(n / 2) * int(ab["pools_per_two_spent"]):
				hits_part.spill_blood(global_position + _facing.rotated(Vector3.UP, randf_range(-half, half)) * randf_range(1.0, reach), 1)
	# pips spent for more (Blowout)
	if ab.has("spend_pips") and motion_part.has_slipstream():
		var burned: int = motion_part.spend_pips(int(ab["spend_pips"]))
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
		if float(ab.get("per_patch_heal", 0.0)) > 0.0 and cut > 0:
			combat_part.heal_over(float(ab["per_patch_heal"]) * float(cut), 2.0)                # Reaping Sweep regrows you
	# drawn in first (Backdraft)
	if bool(ab.get("pull_before_blast", false)) and float(ab.get("pull", 0.0)) > 0.0:
		for e: Node3D in casting_part._enemies_near(global_position, reach + 2.0):
			e.set("shover", self)
			e.call("pull_toward", global_position, float(ab["pull"]), float(e.get("radius")) + 0.6)
	var hits := 0
	var gained := 0
	for t: Node3D in combat_part._in_arc(reach, half):
		if bool(ab.get("needs_clear_line", false)) and not casting_part._ray(global_position + Vector3.UP, t.global_position + Vector3.UP).is_empty():
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
		if hits_part.apply_hit(t, p, tags, stage_mult) != null or p.has("status") or p.has("statuses"):
			hits += 1
		if ab.has("spall") and metal > 0:
			var sp: Dictionary = ab["spall"]
			for o: Node3D in casting_part._enemies_near(where, float(sp.get("radius", 2.5))):
				if o != t:
					combat_part.deal_damage(o, float(sp.get("damage_per_class", 30.0)) * float(metal) * stage_mult, tags + ["spall"])
	if hits > 0:
		if float(ab.get("heal_per_target", 0.0)) > 0.0:
			# Wearying Sweep: you regrow for every living one it wearies
			combat_part.heal_over(float(ab["heal_per_target"]) * float(mini(hits, int(ab.get("heal_targets_max", 99)))), float(ab.get("heal_over_s", 3.0)))
		if float(ab.get("essence_per_hit", 0.0)) > 0.0:
			essence = minf(essence_max, essence + float(ab["essence_per_hit"]) * float(mini(hits, int(ab.get("essence_max_hits", 99)))))
		if int(ab.get("swallow_per_hit", 0)) > 0:
			hits_part.store_add("swallowed", int(ab["swallow_per_hit"]) * hits + gained, 5, 12.0)
		if int(ab.get("gain_pips_per_hit", 0)) > 0 and motion_part.has_slipstream():
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
		hits_part.lay_cloud(global_position, ab["leave_zone"], tags + ["cloud"])
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
		for e: Node3D in casting_part._enemies_near(global_position, _dash_arrive_radius):
			hits_part.apply_hit(e, _dash_on_arrive, _dash_tags, _dash_stage_mult)
		if bool(_dash_ab.get("shatters_stone", false)):
			for s: Variant in stones.duplicate():
				if is_instance_valid(s) and (s as Stone).global_position.distance_to(global_position) <= _dash_arrive_radius + 1.5:
					(s as Stone).shatter((s as Stone).global_position - global_position, self)
		_dash_on_arrive = {}
	if _dash_ab.has("leave_growth"):
		hits_part.plant_growth(global_position, _dash_ab["leave_growth"])
	if float(_dash_ab.get("arrive_ward", 0.0)) > 0.0:
		combat_part.add_ward(float(_dash_ab["arrive_ward"]), -1.0, {"from": str(_dash_ab.get("name", "dash"))})     # Zealous Charge
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
	zone.dark = bool(_dash_trail.get("dark", false))      # Night Charge: the ground you crossed stays Dark
	if zone.dark:
		zone.kind = "dark_ground"
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
			hits_part.apply_hit(e, _dash_pass, _dash_tags, _dash_stage_mult, way)


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
		hits_part._arc_on(first, hits_part._payload(ab, "on_hit"), tags + ["arc"], stage_mult, int(ab["jumps"]), float(ab.get("jump_radius", 4.0)))


## One straight stretch of a beam: {length, end, normal (where it met a wall, or null), first}.
func _beam_leg(origin: Vector3, dir: Vector3, reach_in: float, ab: Dictionary, stage_mult: float, color: Color, tags: Array) -> Dictionary:
	var reach: float = reach_in
	var normal: Variant = null
	# your own standing stone lets your beam through (combat review R4c) unless the skill asks to stop at it, or
	# glances off stone (bounces)
	var own_through: bool = not bool(ab.get("stops_at_own_stone", false)) and int(ab.get("bounces", 0)) <= 0
	var wall: Dictionary = casting_part._ray(origin, origin + dir * reach, own_through)
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
		hits_part.apply_hit(t2, hits_part._payload(ab, "on_hit"), tags, stage_mult, dir)
		if not bool(ab.get("pierce", false)) or (t2.has_method("blocks_shot") and bool(t2.call("blocks_shot", origin))):
			stop = float(row[0])
			normal = null
			break
	_strike_t = 0.2
	casting_part._line_visual(origin, origin + dir * stop, color)
	return {"length": stop, "end": origin + dir * stop, "normal": normal, "first": first}


## Where a blink would land: toward the cursor, at most `reach` away. Null if that spot is off
## the floor, inside a wall or block, or has one in the way.
func _blink_point(reach: float) -> Variant:
	var want: Vector3 = motion_part._cursor_ground() - global_position
	want.y = 0.0
	if want.length() < 0.5:
		want = _facing * reach                    # no cursor to speak of (bot, headless): straight ahead
	if want.length() > reach:
		want = want.normalized() * reach
	var spot: Vector3 = global_position + want
	var floor_hit: Dictionary = casting_part._ray(spot + Vector3.UP * 4.0, spot + Vector3.DOWN * 2.0)
	if floor_hit.is_empty() or (floor_hit["position"] as Vector3).y > global_position.y + 0.5:
		return null
	if not casting_part._ray(global_position + Vector3.UP, spot + Vector3.UP).is_empty():
		return null
	return spot


## blink: you are simply there. Everything beside where you land takes the arrival payload.
## Arriving behind an enemy (Shadow Slip) you face its back, and your next hit is from behind.
var _swap_with: Node3D = null

func _blink(spot: Vector3, ab: Dictionary, stage_mult: float, color: Color, tags: Array) -> void:
	var from: Vector3 = global_position
	if _swap_with != null and is_instance_valid(_swap_with):
		_swap_with.global_position = Vector3(from.x, _swap_with.global_position.y, from.z)
		_swap_with.call("heal", float(ab.get("swap_heal", 0.0)))
		_swap_with.set("hp", minf(float(_swap_with.get("hp_max")), float(_swap_with.get("hp")) + float(ab.get("swap_heal", 0.0))))
	_swap_with = null
	casting_part._line_visual(from + Vector3.UP, spot + Vector3.UP, color)
	var step: Vector3 = spot - from
	step.y = 0.0
	if step.length() > 0.2:
		_facing = step.normalized()
	if float(ab.get("rear_window", 0.0)) > 0.0:
		_rear_window_t = float(ab["rear_window"])
	var foe: Node3D = casting_part._nearest_enemy_to(spot, 2.0)
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
			hits_part.apply_hit(e, payload, tags, stage_mult)


func _fire_projectile(ab: Dictionary, stage_mult: float, color: Color, tags: Array = ["projectile"]) -> void:
	var bolt: Node3D = Projectile.new()
	bolt.set("color", color)
	bolt.set("tags", tags)
	var payload: Dictionary = hits_part._payload(ab, "on_hit")
	if ab.has("spend_pips") and payload.has("damage"):
		payload["damage"] = float(payload["damage"]) + float(ab.get("pip_damage", 0.0)) * float(motion_part.spend_pips(int(ab["spend_pips"])))
	if payload.has("damage"):
		payload["damage"] = float(payload["damage"]) * stage_mult        # carried on the bolt, already scaled
	if ab.has("on_hit"):
		bolt.set("payload", payload)
	bolt.set("pierce", bool(ab.get("pierce", false)))
	bolt.set("shatters_stone", bool(ab.get("shatters_stone", false)))
	bolt.set("hit_radius", maxf(0.35, float(ab.get("width", 0.0)) * 0.5))
	bolt.set("ab", ab)
	bolt.set("stage_mult", stage_mult)
	bolt.set("dir", casting_part.lead_aim(ab, _facing))          # a slow shot leads its foe a little (combat review R4b)
	bolt.set("damage", float(ab["damage"]) * stage_mult)
	bolt.set("speed", float(ab["speed"]))
	bolt.set("life", float(ab["life"]))
	if bool(ab.get("shot", false)):
		# a shot (poison.json): loosed from your ranged weapon when one is worn - its damage on the dart, a ranged
		# shot for the coat - and it flies as far as your shots do (Bitter Tonic's shot_range_mult)
		bolt.set("tags", tags + ["ranged"])
		bolt.set("life", float(ab["life"]) * casting_part.buff_num("shot_range_mult"))
		if not combat_part.ranged_weapon().is_empty():
			var rm: float = combat_part.ranged_stat("ranged_damage_mult", 1.0)
			bolt.set("damage", float(bolt.get("damage")) * rm)
			if payload.has("damage"):
				payload["damage"] = float(payload["damage"]) * rm
				bolt.set("payload", payload)
	bolt.set("shooter", self)
	get_parent().add_child(bolt)
	bolt.global_position = casting_part._muzzle()


## Where a movement skill lands when it has a special landing: onto a corpse further off
## (Gravestep's corpse_range), or into the shadow behind an enemy (Shadow Slip). Null otherwise.
func _special_landing(ab: Dictionary) -> Variant:
	var cursor: Vector3 = motion_part._cursor_ground()
	if bool(ab.get("swap_thrall", false)):
		# Gravestep: a point on one of your thralls swaps the two of you (it lands where you stood)
		for s: Node3D in summons_near(cursor, 1.5):
			if s.global_position.distance_to(global_position) <= float(ab.get("thrall_range", 14.0)):
				_swap_with = s
				return Vector3(s.global_position.x, global_position.y, s.global_position.z)
	if float(ab.get("corpse_range", 0.0)) > 0.0:
		var f: Fallen = Fallen.nearest(get_tree(), cursor, 1.5)
		if f != null and f.global_position.distance_to(global_position) <= float(ab["corpse_range"]):
			return Vector3(f.global_position.x, global_position.y, f.global_position.z)
	if bool(ab.get("arrive_behind", false)):
		var foe: Node3D = casting_part._nearest_enemy_to(cursor, 1.5)
		if foe == null:
			foe = casting_part._skill_target(float(ab.get("range", 10.0)))
		if foe != null and foe.global_position.distance_to(global_position) <= float(ab.get("range", 10.0)) + 1.0:
			var back: Vector3 = -(foe.get("facing") as Vector3) if foe.get("facing") is Vector3 else (foe.global_position - global_position).normalized()
			var spot: Vector3 = foe.global_position + back.normalized() * (float(foe.get("radius")) + 1.0)
			spot.y = global_position.y
			if casting_part._ray(foe.global_position + Vector3.UP, spot + Vector3.UP).is_empty():
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
	if l.breaks_on_hits > 0:
		for bid: String in buffs:
			l.breaks_on_hits += int((buffs[bid] as Dictionary).get("phantom_extra_hits", 0))      # Lucid: your phantoms last longer
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
	var payload: Dictionary = hits_part._payload(ab, "on_hit")
	if bool(ab.get("nearest_to_point", false)):
		var data: Dictionary = (payload.get("status_data", {}) as Dictionary).duplicate()
		data["goal"] = Vector3(point.x, target.global_position.y, point.z)
		payload["status_data"] = data
		# Errand: long enough to walk there, then stand stand_s
		var walk: float = Vector2(point.x - target.global_position.x, point.z - target.global_position.z).length() / maxf(0.5, float(target.get("speed")))
		payload["status_s"] = walk + float(data.get("stand_s", 2.0))
	_strike_t = 0.2
	var from_sky: bool = bool(payload.get("through", false))
	casting_part._line_visual((target.global_position + Vector3.UP * 7.0) if from_sky else (global_position + Vector3.UP), target.global_position + Vector3.UP, color)
	if str(ab.get("on_death_growth", "")) != "":
		var kind_g: String = str(ab["on_death_growth"])
		target.tree_exiting.connect(func() -> void:
			if is_instance_valid(self) and bool(target.call("is_dead")):
				hits_part.plant_growth(target.global_position, {"kind": kind_g}))
	# Brushfire (spread_stacks): every enemy near the target gains as many stacks as the target carries, up to spread_max
	if str(ab.get("spread_stacks", "")) != "":
		var sid: String = str(ab["spread_stacks"])
		var n: int = int(target.call("status_stacks", sid)) if bool(target.call("has_status", sid)) else 0
		if n > 0:
			for e: Node3D in casting_part._enemies_near(target.global_position, float(ab.get("spread_radius", 4.0))):
				if e != target:
					casting_part._line_visual(target.global_position + Vector3.UP, e.global_position + Vector3.UP, color)
					var sopts: Dictionary = {"lasts": float(ab["status_s"])} if ab.has("status_s") else {}
					e.call("add_status", sid, mini(n, int(ab.get("spread_max", n))), self, sopts)
	if float(ab.get("command_radius", 0.0)) > 0.0:
		# Unleash the Pack: every summon of yours within command_radius leaps to the target, lands summon_hit, and is Unleashed
		for s: Node3D in summons_near(global_position, float(ab["command_radius"])):
			var to_t: Vector3 = target.global_position - s.global_position
			to_t.y = 0.0
			var land: Vector3 = target.global_position - to_t.normalized() * (float(target.get("radius")) + 0.8)
			casting_part._line_visual(s.global_position + Vector3.UP, land + Vector3.UP, color)
			s.global_position = Vector3(land.x, s.global_position.y, land.z)
			if ab.get("summon_hit") is Dictionary:
				hits_part.apply_hit(target, ab["summon_hit"], tags + ["thrall"], stage_mult)
			if ab.get("summon_buff") is Dictionary:
				var sb: Dictionary = (ab["summon_buff"] as Dictionary).duplicate()
				sb["t"] = float(sb.get("duration", 6.0))
				(s.get("buffs") as Dictionary)[str(sb.get("buff", "unleashed"))] = sb
	var delay: float = float(ab.get("delay", 0.0))
	if delay > 0.0:
		var mark := target
		SkillTimer.after(get_parent(), delay, func(_i: int) -> void:
			if is_instance_valid(mark) and not bool(mark.call("is_dead")):
				hits_part.apply_hit(mark, payload, tags, stage_mult))
		return
	hits_part.apply_hit(target, payload, tags, stage_mult)


## summon: the body at the point gets up and fights for you (a Thrall). A body is spent; the
## oldest of more than max_count falls.
func _summon(at: Vector3, ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var needs: String = str(ab.get("needs", ""))
	var scale := 1.0
	var count := 1
	if needs.begins_with("corpse"):
		var f: Fallen = Fallen.nearest(get_tree(), at, 1.5)
		if f != null:
			f.spend()
	elif needs == "growth":
		# Call the Brake: a beast out of your growth - stronger for an older patch, two from a bloom; the patch is cut back
		var g: GrowthPatch = _growth_at(at, 1.5)
		if g != null:
			var age_name: String = ["sprout", "grown", "bloom"][g.age()]
			scale = float((ab.get("age_scales", {}) as Dictionary).get(age_name, 1.0))
			if g.age() >= 2:
				count = int(ab.get("bloom_count", 1))
			if bool(ab.get("spends_patch_age", false)):
				g.cut_back()
			at = g.global_position
	elif needs == "":
		at = global_position + _facing * 1.2           # Heartseed: at your side
	var cap: int = int(ab.get("max_count", 2))
	var from_aff: String = str(ab.get("max_count_from", ""))
	if from_aff.begins_with("affinity."):
		cap = int(GameData.affinity(str(ab.get("affinity", ""))).get(from_aff.get_slice(".", 1), cap))     # Death's thrall_cap
	var cfg: Dictionary = ab.get("thrall", {})
	for i: int in count:
		var mine: Array = get_tree().get_nodes_in_group("thralls").filter(func(t: Node) -> bool: return t.get("caster") == self and str(t.get("skill")) == str(ab.get("name", "")))
		while mine.size() >= cap:
			var old: Node = mine.pop_front()
			old.call("_fall")
		var t := Thrall.new()
		t.caster = self
		t.skill = str(ab.get("name", ""))
		t.life = float(ab.get("duration", 15.0))
		t.hp = float(cfg.get("hp", 120.0)) * scale
		t.hp_max = t.hp
		t.damage = float(cfg.get("damage", 15.0)) * stage_mult * scale
		t.attack_s = float(cfg.get("attack_s", 1.2))
		t.speed = float(cfg.get("speed", 5.0))
		t.is_living = bool(cfg.get("living", false))
		t.behaviour = str(cfg.get("behaviour", "fight"))
		t.model = str(cfg.get("model", "grunt"))
		t.on_hit = cfg.get("on_hit", {})
		t.heal_per_s = float(cfg.get("heal_per_s", 0.0))
		t.heal_per_hit = float(cfg.get("heal_per_hit", 0.0))
		t.heal_radius = float(ab.get("radius", 6.0))
		t.strikable_within = float(cfg.get("strikable_within", -1.0))
		t.tags = tags
		var off := Vector3(0.7 * float(i), 0.0, 0.0)
		t.position = Vector3(at.x, global_position.y, at.z) + off
		get_parent().add_child(t)
	casting_part._line_visual(global_position + Vector3.UP, at + Vector3.UP, GameData.affinity_color(str(ab.get("affinity", ""))))


## A body for a Death skill near `point`: a corpse, or - Last Mercy's captures - a Spared enemy of yours that kneels
## (not an elite), which is killed at once for it (the kill is yours) and leaves its body.
func _corpse_near(point: Vector3, reach: float) -> Fallen:
	var f: Fallen = Fallen.nearest(get_tree(), point, reach)
	if f != null:
		return f
	for e: Node3D in casting_part._enemies_near(point, reach):
		if e.has_method("is_elite") and bool(e.call("is_elite")):
			continue
		var st: Array = e.call("status_from", "kneels_below", self)
		if st.is_empty() or not bool(e.call("_kneeling")):
			continue
		e.call("clear_status", str(st[0]))
		var b: Body = e.get("body")
		combat_part.deal_damage(e, b.total() * 10.0 + 1.0, ["ability", "death", "execute", "captured"])
		return Fallen.nearest(get_tree(), point, reach + 1.0)
	return null


## Your growth patch nearest `at`, within `reach`, or null.
func _growth_at(at: Vector3, reach: float) -> GrowthPatch:
	var best: GrowthPatch = null
	for node: Node in get_tree().get_nodes_in_group("growth"):
		var g := node as GrowthPatch
		if g == null or g.caster != self:
			continue
		var d: float = Vector2(g.global_position.x - at.x, g.global_position.z - at.z).length()
		if d <= reach + g.radius and (best == null or d < Vector2(best.global_position.x - at.x, best.global_position.z - at.z).length()):
			best = g
	return best


## Your summons (any kind) within `radius` of `at`.
func summons_near(at: Vector3, radius: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	if not is_inside_tree():
		return out
	for node: Node in get_tree().get_nodes_in_group("thralls"):
		var t := node as Node3D
		if t != null and t.get("caster") == self and not bool(t.call("is_dead")) and t.global_position.distance_to(at) <= radius:
			out.append(t)
	return out


## A summon of yours heals (Heartseed's heal_per_s): you, and your living summons within its radius.
func summon_heals(from: Node3D, points: float, radius: float) -> void:
	if from.global_position.distance_to(global_position) <= radius:
		combat_part.life_heal(points)
	for s: Node3D in summons_near(from.global_position, radius):
		if s != from:
			s.call("heal", points)


## A self buff with a radius is shared with your summons within it (Life, Nature, Holy, Death's thrall_ keys,
## Dream's buff_targets: one mechanic): each gets the buff for the same time; an affinity with shares_living_only
## shares with living summons only. A summon_ward goes over each too.
func _share_buff(ab: Dictionary, bid: String, lasts: float) -> void:
	var aff: Dictionary = GameData.affinity(str(ab.get("affinity", "")))
	var shares: bool = bool(aff.get("shares_buffs", false)) or (ab.get("buff_targets", []) as Array).has("summons")
	if not shares or float(ab.get("radius", 0.0)) <= 0.0:
		return
	for s: Node3D in summons_near(global_position, float(ab["radius"])):
		if bool(aff.get("shares_living_only", false)) and not bool(s.get("is_living")):
			continue
		var copy: Dictionary = ab.duplicate(true)
		copy["t"] = lasts
		(s.get("buffs") as Dictionary)[bid] = copy
		if float(ab.get("summon_ward", 0.0)) > 0.0:
			s.call("add_ward", float(ab["summon_ward"]), lasts)


## seed: hidden seeds spread round the point, each bursting when stepped on or after a while.
func _sow(at: Vector3, ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var n: int = int(ab.get("seeds", 5))
	var spread: float = float(ab.get("radius", 2.5))
	for i: int in n:
		var a: float = TAU * float(i) / float(n)
		var r: float = spread * (0.35 + 0.65 * float(i % 2))
		var s := SeedTrap.new()
		s.caster = self
		s.payload = hits_part._payload(ab, "on_hit")
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
	casting_part._line_visual(global_position + Vector3.UP, to + Vector3.UP, GameData.affinity_color(str(ab.get("affinity", ""))))
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
	var wall: Dictionary = casting_part._ray(from + Vector3.UP, from + Vector3.UP + dir * (reach + 0.5))
	if not wall.is_empty():
		reach = maxf(0.0, (from + Vector3.UP).distance_to(wall["position"]) - 0.6)
	var a := Vector2(from.x, from.z)
	var passed: Array = []
	for e: Node3D in casting_part._enemies_near(from, reach + 1.0):
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
	casting_part._line_visual(from + Vector3.UP, end + Vector3.UP, GameData.affinity_color(str(ab.get("affinity", ""))))
	global_position = end
	velocity = Vector3.ZERO
	has_move_goal = false
	for row: Array in passed:
		if float(row[0]) <= reach:
			hits_part.apply_hit(row[1], ab.get("on_pass", {}), tags, stage_mult, dir)


## field_pulse: acts on your own field pieces - corpses (Lay to Rest) or growth patches (Sere
## Ground wilts them for a burst each; Greening grows them on).
func _field_pulse(at: Vector3, ab: Dictionary, stage_mult: float, tags: Array) -> void:
	_strike_t = 0.25
	var centre: Vector3 = at if ab.has("range") else global_position
	var radius: float = float(ab.get("radius", 6.0))
	var color: Color = GameData.affinity_color(str(ab.get("affinity", "")))
	if ab.has("max_take"):
		# Deep Draught: every blood pool within pool_radius and a Bleeding stack from every bleeder within radius, one
		# measure each (blood_per_take), at most max_take; the bleeders take on_hit
		var took := 0
		var cap_t: int = int(ab["max_take"])
		for node: Node in get_tree().get_nodes_in_group("blood_pools").duplicate():
			if took >= cap_t:
				break
			if (node as Node3D).global_position.distance_to(global_position) <= float(ab.get("pool_radius", 4.0)):
				took += int(node.call("drink"))
		var hit: Dictionary = hits_part._payload(ab, "on_hit")
		var take: Dictionary = hit.get("consume_stacks", {})
		hit.erase("consume_stacks")
		for e: Node3D in casting_part._enemies_near(global_position, radius):
			if took >= cap_t:
				break
			for st: String in take:
				if bool(e.call("has_status", st)):
					var entry: Dictionary = (e.get("statuses") as Dictionary).get(st, {})
					var left: int = int(e.call("status_stacks", st)) - int(take[st])
					if left <= 0:
						e.call("clear_status", st)
					elif not entry.is_empty():
						entry["stacks"] = left
					took += int(take[st])
					casting_part._line_visual(e.global_position + Vector3.UP, global_position + Vector3.UP, color)
					hits_part.apply_hit(e, hit, tags, stage_mult)
		hits_part.gain_blood(mini(took, cap_t) * int(ab.get("blood_per_take", 1)))
		return
	if ab.has("max_corpses"):
		var n := 0
		for node: Node in get_tree().get_nodes_in_group("fallen").duplicate():
			var f := node as Fallen
			if f == null or f.spent or f.global_position.distance_to(centre) > radius or n >= int(ab["max_corpses"]):
				continue
			n += 1
			casting_part._line_visual(global_position + Vector3.UP, f.global_position + Vector3.UP * 0.3, color)
			essence = minf(essence_max, essence + float(ab.get("per_corpse_essence", 0.0)))
			var aff: String = str(ab.get("affinity", ""))
			reflux_by[aff] = maxf(0.0, casting_part.reflux_of(aff) - float(ab.get("per_corpse_reflux", 0.0)))
			for e: Node3D in casting_part._enemies_near(f.global_position, float(ab.get("drag_radius", 2.0))):
				hits_part.apply_hit(e, hits_part._payload(ab, "on_hit"), tags, stage_mult)
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
			if ab.has("green_heal_mult") or ab.has("green_damage_mult"):
				buffs["greening"] = {"t": float(ab.get("duration", 6.0)), "green_heal_mult": float(ab.get("green_heal_mult", 1.0)),
					"green_damage_mult": float(ab.get("green_damage_mult", 1.0)), "affinity": ab.get("affinity", "")}
			continue
		var p: Dictionary = hits_part._payload(ab, "on_hit")
		p["damage"] = float(ab.get("per_stack_damage", 30.0)) * (g.mult() if bool(ab.get("age_scales", false)) else 1.0)
		for e: Node3D in g.inside():
			hits_part.apply_hit(e, p, tags + ["growth"], stage_mult)
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
	reflux_by[aff] = casting_part.reflux_of(aff) + pay * float(ab.get("reflux_per_cost", 1.0))
	casting_part._advance(h["state"], pay)
	if float(ab.get("pip_cost_per_s", 0.0)) > 0.0:
		h["pip_t"] = float(h["pip_t"]) + delta * float(ab["pip_cost_per_s"])
		while float(h["pip_t"]) >= 1.0:
			h["pip_t"] = float(h["pip_t"]) - 1.0
			if motion_part.spend_pips(1) < 1:
				_end_held()                      # Spindrift runs on your pips
				return
	h["tick"] = float(h["tick"]) - delta
	h["paused"] = float(h.get("paused", 0.0)) - delta
	if float(h["tick"]) <= 0.0:
		h["tick"] = float(ab.get("tick", 0.5))
		if float(h["paused"]) <= 0.0:
			_channel_pulse()


## One tick of a channel, along its shape.
func _channel_pulse() -> void:
	var h: Dictionary = _held
	var ab: Dictionary = h["ab"]
	var tags: Array = h["tags"]
	var stage_mult: float = float(h["stage_mult"])
	var payload: Dictionary = hits_part._payload(ab, "on_hit")
	var memo: Dictionary = h["memo"]
	var color: Color = GameData.affinity_color(str(h["aff"]))
	_strike_t = 0.15
	match str(ab.get("shape", "self")):
		"line":
			var origin: Vector3 = global_position + Vector3.UP * 0.9
			var reach: float = float(ab.get("range", 8.0))
			var wall: Dictionary = casting_part._ray(origin, origin + _facing * reach)
			if not wall.is_empty():
				reach = origin.distance_to(wall["position"])
			var best: Node3D = null
			for e: Node3D in casting_part._enemies_near(global_position, reach + 1.0):
				var to: Vector3 = e.global_position - global_position
				to.y = 0.0
				var along: float = to.dot(_facing)
				if along >= 0.0 and along <= reach and (to - _facing * along).length() <= float(ab.get("width", 1.0)) * 0.5 + float(e.get("radius")):
					if best == null or along < (best.global_position - global_position).dot(_facing):
						best = e
			casting_part._line_visual(origin, (best.global_position + Vector3.UP * 0.9) if best != null else origin + _facing * reach, color)
			if best != null:
				hits_part.apply_hit(best, payload, tags, stage_mult, _facing, memo)
		"cone":
			var half: float = deg_to_rad(float(ab.get("arc_deg", 60.0)) * 0.5)
			combat_part._swing_visual(float(ab.get("range", 5.0)), false, false)
			for e: Node3D in combat_part._in_arc(float(ab.get("range", 5.0)), half):
				hits_part.apply_hit(e, payload, tags, stage_mult, Vector3.ZERO, memo)
		"nearest":
			var near: Node3D = casting_part._nearest_enemy_to(global_position, float(ab.get("radius", 3.0)))
			if near != null:
				casting_part._line_visual(global_position + Vector3.UP, near.global_position + Vector3.UP, color)
				hits_part.apply_hit(near, payload, tags, stage_mult, Vector3.ZERO, memo)
		"tether":
			var t: Variant = h["target"]
			if t == null or not is_instance_valid(t) or bool((t as Node).call("is_dead")) \
					or (t as Node3D).global_position.distance_to(global_position) > float(ab.get("break_range", 9.0)) \
					or not casting_part._ray(global_position + Vector3.UP, (t as Node3D).global_position + Vector3.UP).is_empty():
				_held = {}
				return
			casting_part._line_visual(global_position + Vector3.UP, (t as Node3D).global_position + Vector3.UP, color)
			hits_part.apply_hit(t, payload, tags, stage_mult, Vector3.ZERO, memo)
		_:
			# self: everything round you (Deep Draught draws blood out; Regrowth mends you)
			if float(ab.get("summon_heal_per_s", 0.0)) > 0.0:
				for s: Node3D in summons_near(global_position, float(ab.get("radius", 6.0))):
					s.call("heal", float(ab["summon_heal_per_s"]) * float(ab.get("tick", 0.5)))      # Regrowth mends your living summons
			if float(ab.get("sink_per_s", 0.0)) > 0.0:
				var pts: float = float(ab["sink_per_s"]) * float(ab.get("tick", 0.5))
				var filled: Dictionary = body.fill_sinks(pts, true)
				combat_part._wounds_closed(filled["closed"])
				if body.has_wound("lost_arm") and float(ab.get("arm_rate", 0.0)) > 0.0:
					var arm_fill: Dictionary = body.fill_one("lost_arm", pts * float(ab["arm_rate"]))     # a lost arm mends too, slower
					combat_part._wounds_closed(arm_fill["closed"])
				return
			var taken := 0
			for e: Node3D in casting_part._enemies_near(global_position, float(ab.get("radius", 5.0))):
				var take: Dictionary = payload.get("consume_stacks", {})
				var had := true
				for st: String in take:
					had = had and bool(e.call("has_status", st))
				if not had:
					continue
				casting_part._line_visual(e.global_position + Vector3.UP, global_position + Vector3.UP, color)
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
				hits_part.apply_hit(e, p2, tags, stage_mult, Vector3.ZERO, memo)
			for i: int in int(ab.get("pools_per_tick", 0)):
				var pool: BloodPool = null
				for node: Node in get_tree().get_nodes_in_group("blood_pools"):
					if (node as Node3D).global_position.distance_to(global_position) <= float(ab.get("radius", 5.0)):
						pool = node as BloodPool
						break
				if pool == null:
					break
				taken += pool.drink()
			hits_part.gain_blood(taken * int(ab.get("blood_per_take", 1)))


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
	if bool(ab.get("focus_spend", false)) and focus > 0:
		# Whetted Cut: every stack of Edge Heat spent adds per_focus_mult to its damage_mult
		var add: float = float(ab.get("per_focus_mult", 0.0)) * float(focus)
		ab["damage_mult"] = float(ab.get("damage_mult", 1.0)) + add
		if ab.has("damage_mult_min"):
			ab["damage_mult_min"] = float(ab["damage_mult_min"]) + add
		_float("edge spent x%d" % focus, Color(1.0, 0.7, 0.4))
		focus = 0
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
			_start_blast(casting_part._aim_point(float(ab.get("range", 12.0))), ab, stage_mult, tags)
		"beam":
			ab["width"] = float(ab.get("line_width", ab.get("width", 1.0)))
			_fire_beam(ab, stage_mult, GameData.affinity_color(str(h["aff"])), tags)
		"streak":
			# Stored Bolt: you cross range_min at a tap to range at a full hold, in an instant, through bodies
			ab["range"] = lerpf(float(ab.get("range_min", ab.get("range", 6.0))), float(ab.get("range", 8.0)), frac)
			var pass_hit: Dictionary = (ab.get("on_pass", {}) as Dictionary).duplicate()
			if not pass_hit.has("damage") and ab.has("damage"):
				pass_hit["damage"] = float(ab["damage"])
			if (ab.get("on_hit", {}) as Dictionary).has("marks"):
				pass_hit["marks"] = int((ab["on_hit"] as Dictionary)["marks"])      # marks by charge
			ab["on_pass"] = pass_hit
			_streak(ab, stage_mult, tags)
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
			hits_part.apply_hit(e, hits_part._payload(ab, "on_hit"), tags, stage_mult)
		z.end()


## Pour every other dosed enemy's doses into one (Funnel).
func _gather(target: Node3D, ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var id: String = str(ab.get("consume_status", "dosed"))
	var total := 0
	for e: Node3D in casting_part._enemies_near(target.global_position, float(ab.get("gather_radius", 6.0))):
		if e == target or not bool(e.call("has_status", id)):
			continue
		total += int(e.call("status_stacks", id))
		e.call("clear_status", id)
		casting_part._line_visual(e.global_position + Vector3.UP, target.global_position + Vector3.UP, GameData.affinity_color(str(ab.get("affinity", ""))))
	var cap: int = int(ab.get("gather_cap", 20))
	var have: int = int(target.call("status_stacks", id)) if bool(target.call("has_status", id)) else 0
	var add: int = mini(total, cap - have)
	if add > 0:
		target.call("add_status", id, 0, self)
		var entry: Dictionary = (target.get("statuses") as Dictionary).get(id, {})
		if not entry.is_empty():
			entry["stacks"] = have + add            # above the usual cap: gathered doses may go to gather_cap
	if ab.has("on_hit"):
		hits_part.apply_hit(target, hits_part._payload(ab, "on_hit"), tags, stage_mult)


## The heart hammers: `beats` times, beat_s apart, every enemy near you carrying the status pays
## per stack it holds then, and the stacks stay (Hammering Heart).
func _beats(ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var id: String = str(ab.get("needs_status", ab.get("consume_status", "bleeding")))
	var reach: float = float(ab.get("range", 10.0))
	SkillTimer.after(get_parent(), 0.0, func(_i: int) -> void:
		if not is_instance_valid(self):
			return
		for e: Node3D in casting_part._enemies_near(global_position, reach):
			var n: int = int(e.call("status_stacks", id)) if bool(e.call("has_status", id)) else 0
			if n <= 0:
				continue
			combat_part.deal_damage(e, float(ab.get("per_stack_damage", 8.0)) * float(n) * stage_mult, tags + ["beat"])
			if is_instance_valid(e) and not bool(e.call("is_dead")) and ab.has("on_hit"):
				hits_part.apply_hit(e, ab["on_hit"], tags, stage_mult)
			if int(ab.get("pool_per_beat", 0)) > 0 and is_instance_valid(e):
				hits_part.spill_blood(e.global_position, int(ab["pool_per_beat"])), int(ab.get("beats", 3)) - 1, float(ab.get("beat_s", 0.5)))


## The light comes home (Gathered Light): every other enemy on the straight line from it to you
## takes the ray; walls and stone end it.
func _home_ray(from: Vector3, skip: Node3D, damage: float, tags: Array) -> void:
	var to: Vector3 = global_position
	var hit: Dictionary = casting_part._ray(from + Vector3.UP, to + Vector3.UP)
	if not hit.is_empty():
		return
	casting_part._line_visual(from + Vector3.UP, to + Vector3.UP, GameData.affinity_color("light"))
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	for e: Node3D in casting_part._enemies_near((from + to) * 0.5, from.distance_to(to) * 0.5 + 1.0):
		if e == skip:
			continue
		var p := Vector2(e.global_position.x, e.global_position.z)
		if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= 0.6 + float(e.get("radius")):
			combat_part.deal_damage(e, damage, tags + ["ray"])


## prop: a slab of stone (raise_stone), or a lamp, or a likeness of you that draws enemies.
func _raise_prop(at: Vector3, ab: Dictionary, stage_mult: float, tags: Array) -> void:
	match str(ab.get("shape", "")):
		"echo":
			# Stray Echo: an unseen sound - every enemy within lure_radius turns to it and walks to it (a Lure); it cracks
			# on those right beside it as it is set
			var echo: Lure = _leave_lure(at, {"life": float(ab.get("turn_s", ab.get("life", 3.0))), "hp": 9999.0,
				"lure_radius": float(ab.get("lure_radius", 8.0)), "breaks_on_hits": 1}, str(ab.get("affinity", "")), tags)
			echo.visible = false
			for e: Node3D in casting_part._enemies_near(at, float(ab.get("crack_radius", 1.5))):
				hits_part.apply_hit(e, hits_part._payload(ab, "on_hit"), tags, stage_mult)
			return
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
			lamp.sear_bonus = float(ab.get("sear_bonus", 0.0))
			lamp.tags = tags
			lamp.color = GameData.affinity_color(str(ab.get("affinity", "")))
			get_parent().add_child(lamp)
			lamp.global_position = Vector3(at.x, global_position.y, at.z)
			return
	if ab.has("collapse_radius") or (ab.has("blocks") and not bool(ab["blocks"])):
		# a likeness of you: enemies within radius turn on it, and it falls apart when it breaks. Raised from a corpse
		# (Death Mask) it stands longer and tougher, and its collapse leaves collapse_status
		var life_l: float = float(ab.get("life", 5.0))
		var hp_l: float = float(ab.get("hp", 150.0))
		var collapse: Dictionary = {"damage": float(ab.get("damage", 40.0)) * stage_mult}
		if str(ab.get("collapse_status", "")) != "":
			collapse["status"] = str(ab["collapse_status"])
		var body_f: Fallen = Fallen.nearest(get_tree(), at, 1.5) if str(ab.get("needs", "")).begins_with("corpse") else null
		if body_f != null:
			body_f.spend()
			life_l = float(ab.get("corpse_life", life_l))
			hp_l *= float(ab.get("corpse_hp_mult", 1.0))
		_leave_lure(at, {"life": life_l, "hp": hp_l, "radius": float(ab.get("radius", 6.0)),
			"breaks_on_hits": 0, "collapse": collapse, "collapse_radius": float(ab.get("collapse_radius", 3.0))}, str(ab.get("affinity", "")), tags)
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
	if float(ab.get("decoy_s", 0.0)) > 0.0:
		# Heartwood: for decoy_s after it rises, enemies within decoy_radius go for it instead of you
		_leave_lure(at, {"life": float(ab["decoy_s"]), "hp": float(ab.get("hp", 300.0)), "lure_radius": float(ab.get("decoy_radius", 5.0)),
			"breaks_on_hits": 0}, str(ab.get("affinity", "")), tags).visible = false
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
				hits_part.plant_growth(stone.global_position + _facing * 1.2, {"kind": kind_g}), int(ab.get("life", 30.0)), 1.0)


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
	if ab.get("split") is Dictionary:
		# Prism Bolt: where it ends it splits into count straight lines of light fanned over arc_deg round its flight
		var sp: Dictionary = ab["split"]
		var fly: Vector3 = at - from
		fly.y = 0.0
		fly = fly.normalized() if fly.length() > 0.05 else _facing
		var n: int = int(sp.get("count", 3))
		var arc: float = deg_to_rad(float(sp.get("arc_deg", 60.0)))
		var line: Dictionary = {"width": float(sp.get("width", 0.4)), "on_hit": (sp.get("on_hit", {}) as Dictionary).duplicate(), "affinity": ab.get("affinity", "")}
		(line["on_hit"] as Dictionary)["damage"] = float(sp.get("damage", 20.0))
		var origin: Vector3 = Vector3(at.x, global_position.y + 0.9, at.z) + fly * 0.9
		for i: int in n:
			var ang: float = -arc * 0.5 + arc * (float(i) / maxf(1.0, float(n - 1)))
			_beam_leg(origin, fly.rotated(Vector3.UP, ang), float(sp.get("range", 7.0)), line, 1.0, GameData.affinity_color(str(ab.get("affinity", ""))), tags + ["split"])
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
	hits_part._burst_at(at, burst, tags + ["corpse"], stage_mult)


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
## Sidesteps taken, for tests and the combat-review probe.
var sidesteps := 0
signal sidestepped(dir: Vector3)
var endurance := -1.0                # -1 until first read: full
var _casting_slot := -1              # the hotbar slot cast_slot is casting from, -1 otherwise
## The last refusal: {serial, slot, reason, text} - reason is no_affinity | locked | essence | heat |
## no_target | out_of_reach | no_line | needs_status | no_landing | winded | endurance (the sidestep); slot is -1 when it was not a
## hotbar slot (the sidestep, a test's cast_ability). The HUD shows a new serial once.
var last_refusal: Dictionary = {}
signal cast_refused(slot: int, reason: String, text: String)
var _forced_target: Node3D = null    # the foe a walked-in cast walked to (_skill_candidate takes it first)


# --- forwarded to PlayerSave (scripts/player/player_save.gd) ------------------------------------------
# Outside callers (main.gd, the HUD, the screens, the tests, talents) still call these on the player.
func to_save() -> Dictionary: return save_part.to_save()
func from_save(d: Dictionary) -> void: save_part.from_save(d)


# --- forwarded to PlayerBot (scripts/player/player_bot.gd) ------------------------------------------
# Outside callers (main.gd, the HUD, the screens, the tests, talents) still call these on the player.
func make_test_character(aff: String) -> void: bot_part.make_test_character(aff)
func _bot_way(goal: Vector3, delta: float) -> Vector3: return bot_part._bot_way(goal, delta)


# --- forwarded to PlayerEconomy (scripts/player/player_economy.gd) ------------------------------------------
# Outside callers (main.gd, the HUD, the screens, the tests, talents) still call these on the player.
func weapon_stat(stat_name: String, multiplicative: bool = false) -> float: return economy_part.weapon_stat(stat_name, multiplicative)
func reach_now() -> float: return economy_part.reach_now()
func refresh_gear() -> void: economy_part.refresh_gear()
func _roll_loot(target: Node) -> void: economy_part._roll_loot(target)
static func spawn_pickup(parent: Node, item_id: String, at: Vector3) -> Node3D: return PlayerEconomy.spawn_pickup(parent, item_id, at)
func take_pickup(drop: Node3D) -> bool: return economy_part.take_pickup(drop)
func charge(amount: int) -> void: economy_part.charge(amount)
func can_afford(cost: int) -> bool: return economy_part.can_afford(cost)
func next_healing() -> Dictionary: return economy_part.next_healing()
func buy_healing() -> void: economy_part.buy_healing()
func respawn_naked() -> void: economy_part.respawn_naked()
func die_to_corpse(where: String, chamber: int, local_pos: Vector3) -> Dictionary: return economy_part.die_to_corpse(where, chamber, local_pos)
func recover_corpse(id: String) -> bool: return economy_part.recover_corpse(id)
func corpse_fee() -> int: return economy_part.corpse_fee()
func buy_corpse_retrieval() -> String: return economy_part.buy_corpse_retrieval()
func rest_night() -> void: economy_part.rest_night()
static func remains_of(kind: String) -> Array[String]: return PlayerEconomy.remains_of(kind)
func use_consumable(item_id: String) -> String: return economy_part.use_consumable(item_id)


# --- forwarded to PlayerProgression (scripts/player/player_progression.gd) ------------------------------------------
# Outside callers (main.gd, the HUD, the screens, the tests, talents) still call these on the player.
func temper_stage_cap() -> int: return progress_part.temper_stage_cap()
func temper_stat(stat: String) -> float: return progress_part.temper_stat(stat)
func temper_effect_text(id: String, stage: int) -> String: return progress_part.temper_effect_text(id, stage)
func temper_session_damage(id: String) -> float: return progress_part.temper_session_damage(id)
func temper_session_progress(id: String) -> float: return progress_part.temper_session_progress(id)
func cannot_temper_reason(id: String) -> String: return progress_part.cannot_temper_reason(id)
func temper_session(id: String) -> bool: return progress_part.temper_session(id)
func knows(ability_id: String) -> bool: return progress_part.knows(ability_id)
func can_learn(ability_id: String) -> String: return progress_part.can_learn(ability_id)
func learn(ability_id: String) -> bool: return progress_part.learn(ability_id)
func read_scroll(item_id: String) -> String: return progress_part.read_scroll(item_id)
func scroll_for_me() -> String: return progress_part.scroll_for_me()
func start_with_skills(ids: Array) -> String: return progress_part.start_with_skills(ids)
func default_start_skills() -> Array[String]: return progress_part.default_start_skills()
func skill_cost(ability_id: String) -> Dictionary: return progress_part.skill_cost(ability_id)
func skill_unlocked(ability_id: String) -> bool: return progress_part.skill_unlocked(ability_id)
func cannot_train_reason(ability_id: String) -> String: return progress_part.cannot_train_reason(ability_id)
func train_skill(ability_id: String) -> String: return progress_part.train_skill(ability_id)
func cannot_drill_reason(ability_id: String) -> String: return progress_part.cannot_drill_reason(ability_id)
func drill_skill(ability_id: String) -> String: return progress_part.drill_skill(ability_id)
func add_aura(amount: float) -> void: progress_part.add_aura(amount)
func _recompute_essence_max() -> void: progress_part._recompute_essence_max()
func grow_star(pct: float) -> void: progress_part.grow_star(pct)
func _meditate_gather(delta: float) -> void: progress_part._meditate_gather(delta)
func aura_read() -> String: return progress_part.aura_read()
func try_ascend() -> void: progress_part.try_ascend()
func _begin_ascension() -> void: progress_part._begin_ascension()
func add_affinity(id: String) -> String: return progress_part.add_affinity(id)
func resolve_ascension(affinity: String, aspects: Dictionary = {}) -> String: return progress_part.resolve_ascension(affinity, aspects)
func ascension_aspect(index: int, wanted: String) -> String: return progress_part.ascension_aspect(index, wanted)
func ascension_preview(index: int, aspect: String, amount: float) -> Array[Dictionary]: return progress_part.ascension_preview(index, aspect, amount)
func ascension_summary(index: int) -> String: return progress_part.ascension_summary(index)
func kill_aura_mult(target: Node) -> float: return progress_part.kill_aura_mult(target)


# --- forwarded to PlayerRunes (scripts/player/player_runes.gd) ------------------------------------------
# Outside callers (main.gd, the HUD, the screens, the tests, talents) still call these on the player.
func ability_stats(state: Dictionary, draft_word: Dictionary = {}) -> Dictionary: return runes_part.ability_stats(state, draft_word)
static func apply_rune_patch(ab: Dictionary, patch: Array) -> void: PlayerRunes.apply_rune_patch(ab, patch)
func preview_bind(state: Dictionary, concept: String) -> Array[Dictionary]: return runes_part.preview_bind(state, concept)
func _preview_row(out: Array[Dictionary], label: String, before: float, after: float, fmt: String, more_is_better: bool) -> void: runes_part._preview_row(out, label, before, after, fmt, more_is_better)
func construct_groups(tier: String = "") -> Array[Dictionary]: return runes_part.construct_groups(tier)
func construct_fits(tier: String, concept: String) -> Dictionary: return runes_part.construct_fits(tier, concept)
func construct_fit_counts(tier: String) -> Dictionary: return runes_part.construct_fit_counts(tier)
func _bind_construct(ability_index: int, construct_index: int, roll: float = -1.0) -> String: return runes_part._bind_construct(ability_index, construct_index, roll)
func rune_context(index: int) -> RuneContext: return runes_part.rune_context(index)
func ability_word(index: int) -> Dictionary: return runes_part.ability_word(index)
func _sealed_word(index: int) -> Dictionary: return runes_part._sealed_word(index)
func sealing_index() -> int: return runes_part.sealing_index()
func seal_mode() -> String: return runes_part.seal_mode()
func seal_construct() -> int: return runes_part.seal_construct()
func can_undo() -> bool: return runes_part.can_undo()
func can_redo() -> bool: return runes_part.can_redo()
func draft_undo() -> bool: return runes_part.draft_undo()
func draft_redo() -> bool: return runes_part.draft_redo()
func can_open_seal(index: int) -> Dictionary: return runes_part.can_open_seal(index)
func open_seal(index: int, construct_index: int = -1) -> Dictionary: return runes_part.open_seal(index, construct_index)
func seal_keystone() -> Dictionary: return runes_part.seal_keystone()
func choose_seal_construct(construct_index: int) -> Dictionary: return runes_part.choose_seal_construct(construct_index)
func close_seal() -> void: runes_part.close_seal()
func draft_reset() -> void: runes_part.draft_reset()
func draft_changed() -> bool: return runes_part.draft_changed()
func can_bind_seal() -> Dictionary: return runes_part.can_bind_seal()
func bind_seal(roll: float = -1.0) -> String: return runes_part.bind_seal(roll)
func word_add(index: int, rune_id: String, to_node: int = -1, ring: int = -1, place: int = -1) -> Dictionary: return runes_part.word_add(index, rune_id, to_node, ring, place)
func word_toggle_link(index: int, a: int, b: int) -> Dictionary: return runes_part.word_toggle_link(index, a, b)
func word_link(index: int, a: int, b: int) -> Dictionary: return runes_part.word_link(index, a, b)
func word_unlink(index: int, a: int, b: int) -> Dictionary: return runes_part.word_unlink(index, a, b)
func word_remove(index: int, node: int) -> Dictionary: return runes_part.word_remove(index, node)
func word_clear(index: int) -> void: runes_part.word_clear(index)
func word_locked(index: int) -> bool: return runes_part.word_locked(index)
func rune_preview(index: int) -> Dictionary: return runes_part.rune_preview(index)
func _stat_rows(before: Dictionary, after: Dictionary, fields: Array, stage_mult: float) -> Array[Dictionary]: return runes_part._stat_rows(before, after, fields, stage_mult)
static func _stat_text(v: float, f: Dictionary) -> String: return PlayerRunes._stat_text(v, f)
func skill_details(index: int) -> Dictionary: return runes_part.skill_details(index)
func rune_summary(index: int) -> Array: return runes_part.rune_summary(index)
func rune_palette() -> Array[String]: return runes_part.rune_palette()
func knows_rune(rune_id: String) -> bool: return runes_part.knows_rune(rune_id)
func can_use_rune(rune_id: String) -> bool: return runes_part.can_use_rune(rune_id)
func discover_rune(rune_id: String, source: String = "") -> bool: return runes_part.discover_rune(rune_id, source)
func _know(rune_id: String) -> void: runes_part._know(rune_id)
func reveal_rune(base: Array, universal: Array, universal_chance: float, source: String, any_base: bool = false) -> String: return runes_part.reveal_rune(base, universal, universal_chance, source, any_base)
func on_construct_subdued(tier: String, concept: String) -> Array[String]: return runes_part.on_construct_subdued(tier, concept)
func _roll_kill_rune(target: Node) -> void: runes_part._roll_kill_rune(target)
func read_inscription(id: String, pool: String, stone_name: String = "the stone") -> String: return runes_part.read_inscription(id, pool, stone_name)


# --- forwarded to PlayerMotion (scripts/player/player_motion.gd) ------------------------------------------
# Outside callers (main.gd, the HUD, the screens, the tests, talents) still call these on the player.
func walk_speed() -> float: return motion_part.walk_speed()
func has_slipstream() -> bool: return motion_part.has_slipstream()
func _tick_slipstream(delta: float) -> void: motion_part._tick_slipstream(delta)
func spend_pips(want: int) -> int: return motion_part.spend_pips(want)
func _click_cursor() -> void: motion_part._click_cursor()
func _click(point: Vector3) -> void: motion_part._click(point)
func pick_screen(screen_pos: Vector2, cam: Camera3D) -> Node3D: return motion_part.pick_screen(screen_pos, cam)
func _update_hover() -> void: motion_part._update_hover()
func _refresh_highlights() -> void: motion_part._refresh_highlights()
func pick_at(point: Vector3) -> Node3D: return motion_part.pick_at(point)
func press_slot(slot: int) -> void: motion_part.press_slot(slot)
func _strike_clicked() -> void: motion_part._strike_clicked()
func _kick(dir: Vector3, metres: float, from: Variant) -> void: motion_part._kick(dir, metres, from)
func camera_kick() -> Vector3: return motion_part.camera_kick()
func press_sidestep() -> void: motion_part.press_sidestep()
func stepping() -> bool: return motion_part.stepping()
func sidestep() -> String: return motion_part.sidestep()
func endurance_max() -> float: return motion_part.endurance_max()
func endurance_now() -> float: return motion_part.endurance_now()
func spend_endurance(amount: float) -> bool: return motion_part.spend_endurance(amount)
func refill_endurance() -> void: motion_part.refill_endurance()
func _walk_in(index: int, reach: float) -> bool: return motion_part._walk_in(index, reach)
func walking_to_cast() -> bool: return motion_part.walking_to_cast()
func cancel_walk_cast() -> void: motion_part.cancel_walk_cast()


# --- forwarded to PlayerCombat (scripts/player/player_combat.gd) ------------------------------------------
# Outside callers (main.gd, the HUD, the screens, the tests, talents) still call these on the player.
func deal_damage(target: Node, base: float, tags: Array = [], opts: Dictionary = {}) -> HitContext: return combat_part.deal_damage(target, base, tags, opts)
func take_hit(amount: float, heavy: bool, source: Node, _tags: Array = []) -> float: return combat_part.take_hit(amount, heavy, source, _tags)
func _focus_max() -> int: return combat_part._focus_max()
func ward() -> float: return combat_part.ward()
func add_ward(amount: float, lasts: float = -1.0, opts: Dictionary = {}) -> float: return combat_part.add_ward(amount, lasts, opts)
func heal_over(points: float, seconds: float) -> void: combat_part.heal_over(points, seconds)
func _tick_regen(delta: float) -> void: combat_part._tick_regen(delta)
func drain_heal(amount: float, _from: Node = null, _capped: bool = true) -> float: return combat_part.drain_heal(amount, _from, _capped)
func deflect_radius() -> float: return combat_part.deflect_radius()
func shot_deflected() -> void: combat_part.shot_deflected()
func shove(dir: Vector3, metres: float) -> void: combat_part.shove(dir, metres)
func is_staggered() -> bool: return combat_part.is_staggered()
func claim_slot(enemy: Node) -> bool: return combat_part.claim_slot(enemy)
func release_slot(enemy: Node) -> void: combat_part.release_slot(enemy)
func armour() -> float: return combat_part.armour()
func ranged_weapon() -> Dictionary: return combat_part.ranged_weapon()
func ranged_damage() -> float: return combat_part.ranged_damage()
func ranged_interval() -> float: return combat_part.ranged_interval()
func fire_ranged(toward: Vector3) -> bool: return combat_part.fire_ranged(toward)
func _apply_damage(amount: float, heavy: bool) -> float: return combat_part._apply_damage(amount, heavy)
func take_wound(id: String, wound_name: String, sink: float, cut: float, natural: bool = true, merge: bool = false) -> void: combat_part.take_wound(id, wound_name, sink, cut, natural, merge)
func _spend_heal_points(points: float) -> float: return combat_part._spend_heal_points(points)
func _strike_target(target: Node3D, multiplier: float, tags: Array) -> void: combat_part._strike_target(target, multiplier, tags)
func strike_damage() -> float: return combat_part.strike_damage()
func conjured() -> Dictionary: return combat_part.conjured()
func strike_rate_mult() -> float: return combat_part.strike_rate_mult()
func _release_overcharge() -> void: combat_part._release_overcharge()
func _check_death() -> void: combat_part._check_death()
func start_fight() -> void: combat_part.start_fight()
func end_fight() -> void: combat_part.end_fight()


# --- forwarded to PlayerHits (scripts/player/player_hits.gd) ------------------------------------------
# Outside callers (main.gd, the HUD, the screens, the tests, talents) still call these on the player.
func _tick_roles(delta: float) -> void: hits_part._tick_roles(delta)
func in_the_green() -> bool: return hits_part.in_the_green()
func heat_mult(aff: String) -> float: return hits_part.heat_mult(aff)
func _payload(ab: Dictionary, key: String) -> Dictionary: return hits_part._payload(ab, key)
func apply_hit(target: Node, payload: Dictionary, tags: Array = [], stage_mult: float = 1.0, dir: Vector3 = Vector3.ZERO, once: Variant = null) -> HitContext: return hits_part.apply_hit(target, payload, tags, stage_mult, dir, once)
func cleanse(list: String) -> int: return hits_part.cleanse(list)
func zone_ally_tick(zone: GroundZone) -> void: hits_part.zone_ally_tick(zone)
func ally_zone_mult(who: Node3D) -> float: return hits_part.ally_zone_mult(who)
func _burst_at(at: Vector3, payload: Dictionary, tags: Array, stage_mult: float = 1.0, skip: Node = null) -> void: hits_part._burst_at(at, payload, tags, stage_mult, skip)
func _hidden() -> bool: return hits_part._hidden()
func hush_radius() -> float: return hits_part.hush_radius()
func unseen_from(from: Vector3) -> bool: return hits_part.unseen_from(from)
func corpse_lie_s() -> float: return hits_part.corpse_lie_s()
func held_blood_max() -> int: return hits_part.held_blood_max()
func gain_blood(n: int) -> void: hits_part.gain_blood(n)
func spend_blood(n: int) -> int: return hits_part.spend_blood(n)
func spill_blood(at: Vector3, measures: int = 1, big: bool = false) -> void: hits_part.spill_blood(at, measures, big)
func lay_cloud(at: Vector3, cfg: Dictionary, tags: Array) -> Node3D: return hits_part.lay_cloud(at, cfg, tags)
func plant_growth(at: Vector3, cfg: Dictionary) -> Node3D: return hits_part.plant_growth(at, cfg)
func on_shove_ended(e: Node) -> void: hits_part.on_shove_ended(e)
func store_add(id: String, n: int, cap: int, life: float) -> void: hits_part.store_add(id, n, cap, life)
func store_count(id: String) -> int: return hits_part.store_count(id)
func on_crush(enemy: Node, metres_left: float, hit: Node) -> void: hits_part.on_crush(enemy, metres_left, hit)
func _add_marks(target: Node, marks: int, conduct: bool) -> void: hits_part._add_marks(target, marks, conduct)


# --- forwarded to PlayerCasting (scripts/player/player_casting.gd) ------------------------------------------
# Outside callers (main.gd, the HUD, the screens, the tests, talents) still call these on the player.
func reflux_of(aff: String) -> float: return casting_part.reflux_of(aff)
func is_locked(aff: String) -> bool: return casting_part.is_locked(aff)
func vent_reflux(value: float) -> void: casting_part.vent_reflux(value)
func clear_reflux() -> void: casting_part.clear_reflux()
func _shed_reflux(amount: float) -> void: casting_part._shed_reflux(amount)
func buff_num(key: String) -> float: return casting_part.buff_num(key)
func _tick_buffs(delta: float) -> void: casting_part._tick_buffs(delta)
func is_braced() -> bool: return casting_part.is_braced()
func _buff_flag(key: String) -> bool: return casting_part._buff_flag(key)
func held_frac() -> float: return casting_part.held_frac()
func windup_frac() -> float: return casting_part.windup_frac()
func _tick_windup(delta: float) -> void: casting_part._tick_windup(delta)
func _ray(from: Vector3, to: Vector3, past_own_stone: bool = false) -> Dictionary: return casting_part._ray(from, to, past_own_stone)
func _line_visual(from: Vector3, to: Vector3, color: Color) -> void: casting_part._line_visual(from, to, color)
func cast_slot(slot: int) -> void: casting_part.cast_slot(slot)
func next_hotbar_page() -> void: casting_part.next_hotbar_page()
func cast_ability(index: int) -> void: casting_part.cast_ability(index)
func _perform_cast(ab: Dictionary, kind: String, aff: String, stage_mult: float, tags: Array, strike_target: Node3D, blink_to: Vector3) -> void: casting_part._perform_cast(ab, kind, aff, stage_mult, tags, strike_target, blink_to)
func assign_slot(slot: int, ability_index: int) -> void: casting_part.assign_slot(slot, ability_index)
func unassign_ability(ability_index: int) -> void: casting_part.unassign_ability(ability_index)
func ability_damage_mult(stage: int) -> float: return casting_part.ability_damage_mult(stage)
func pending_tier(state: Dictionary) -> String: return casting_part.pending_tier(state)
func lead_aim(ab: Dictionary, aim: Vector3) -> Vector3: return casting_part.lead_aim(ab, aim)
