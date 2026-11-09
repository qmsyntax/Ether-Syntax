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
var moves_part: PlayerSkillMoves
var world_part: PlayerSkillWorld

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
	moves_part = PlayerSkillMoves.new(self)
	world_part = PlayerSkillWorld.new(self)
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
		moves_part._tick_held(delta)
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
## Overboard (displace mode throw_target): the one enemy in reach is lifted and thrown toward where you aim, up to
## `throw` m (a heavy one half as far, by its shove class; an elite only staggers). It travels as a shove, so a wall,
## stone or body it meets is a Crush; where it stops, on_land hits every other enemy within its radius.
var _landings: Dictionary = {}
var _clock := 0.0                         # game time, for how recent a death is
## One drain (drain_frac): you are healed that share of the harm the hit dealt, the most one cast heals drain_cap.
## The healing order is the hit's affinity's: drain_heals "bar" (Unholy: the bar only, banked as stolen life), else
## Life's order (Lifeline). Unliving targets give nothing.
var _drain_cast := 0.0


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


# --- forwarded to PlayerSkillMoves (scripts/player/player_skill_moves.gd) ------------------------------------------
# Outside callers (main.gd, the HUD, the screens, the tests, talents) still call these on the player.
func _burst(ab: Dictionary, stage_mult: float, tags: Array) -> void: moves_part._burst(ab, stage_mult, tags)
func _tick_held(delta: float) -> void: moves_part._tick_held(delta)
func projectile_landed(from: Vector3, at: Vector3, ab: Dictionary, tags: Array) -> void: moves_part.projectile_landed(from, at, ab, tags)
func projectile_hit_corpse(f: Fallen, ab: Dictionary, tags: Array, stage_mult: float) -> void: moves_part.projectile_hit_corpse(f, ab, tags, stage_mult)


# --- forwarded to PlayerSkillWorld (scripts/player/player_skill_world.gd) ------------------------------------------
# Outside callers (main.gd, the HUD, the screens, the tests, talents) still call these on the player.
func _zone_num(key: String) -> float: return world_part._zone_num(key)
func _rod_relay(aff: String, stage_mult: float) -> void: world_part._rod_relay(aff, stage_mult)
func land_blast(at: Vector3, ab: Dictionary, stage_mult: float, tags: Array) -> void: world_part.land_blast(at, ab, stage_mult, tags)
func status_death(id: String, at: Vector3) -> void: world_part.status_death(id, at)
func has_stone() -> bool: return world_part.has_stone()
func stone_count() -> int: return world_part.stone_count()
func stone_gone(s: Node) -> void: world_part.stone_gone(s)
func drop_stones() -> void: world_part.drop_stones()
func raise_stone(at: Vector3, away: Vector3, ab: Dictionary, stage_mult: float = 1.0, tags: Array = []) -> Node3D: return world_part.raise_stone(at, away, ab, stage_mult, tags)
func summons_near(at: Vector3, radius: float) -> Array[Node3D]: return world_part.summons_near(at, radius)
func summon_heals(from: Node3D, points: float, radius: float) -> void: world_part.summon_heals(from, points, radius)
