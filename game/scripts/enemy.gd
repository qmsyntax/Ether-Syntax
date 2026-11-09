class_name Enemy
extends CharacterBody3D
## Realm invader. Kinds and numbers come from game/data/enemies.json; the rules they follow are
## design/05 section 6 (balance.json "combat"). Three behaviours:
##   melee   - takes one of the slots around the player, winds up, strikes; waits its turn otherwise
##   ranged  - holds its distance, aims along a line that locks just before release, backs off
##   pouncer - circles and does nothing until the player runs from the pack, then leaps
##   support - never attacks: stands behind the line, strengthens allies near it, rouses one
##   commander - melee that answers a blocked hit, and changes with its health (see _think_commander)
## All of them turn at a limited rate (so they have a back), have poise (so they can be
## staggered), and can be shoved, stunned and interrupted.
## Split by concern (docs/architecture/enemy-split.md): this node keeps the signals, the lifecycle, the
## state that is shared or read from outside, the hooks Beast overrides and one-line forwarders; the
## logic is in the parts in scripts/enemy/ (the status engine, hits, motion, looks, one brain per behaviour).

signal killed(enemy: Node)
## Emitted when a shove ends against something with distance still to go.
signal crushed(enemy: Node, metres_left: float, hit: Node)
## It called for help: whoever owns the level should bring these kinds in beside it.
signal reinforcements(enemy: Node, kinds: Array)
## It took damage (from `source`, which may be null): its camp wakes, a herd answers (FieldCamps).
signal hurt(enemy: Node, source: Node)

const ShotScript := preload("res://scripts/enemy_shot.gd")
const FloatText := preload("res://scripts/float_text.gd")

var body: Body
var kind := "grunt"
var behaviour := "melee"
var is_living := true
var is_scenery := false
var radius := 0.5
var speed := 3.4
var damage := 10.0
var heavy := false
var aura_value := 4.0
var bounty := 150
var target: Node3D
var height := 1.6
var display_name := "Enemy"
## 0 = none, 1 = hovered by the cursor, 2 = the player's locked attack target.
var highlight := 0
## Statuses on this enemy: id -> {"stacks": int, "t": seconds left}. Rules are in statuses.json.
var statuses: Dictionary = {}
## How far a shove moves this enemy, as a share of the stated distance (1 light .. 0.25 elite).
var shove_resist := 1.0
## Whoever shoved it last; told when the shove ends in a crush (on_crush).
var shover: Node
## The way it is facing, flat. It turns toward what it wants at turn_rate, never instantly.
var facing := Vector3(0, 0, 1)
var poise := 40.0
var poise_max := 40.0
## What the HUD should draw on the ground for the attack being wound up, or {}:
##   {"kind": "circle", "radius", "frac" 0..1, "interruptible"}  or
##   {"kind": "line", "to": Vector3, "locked": bool, "frac"}
var telegraph: Dictionary = {}

var _def: Dictionary = {}
var _cfg: Dictionary = {}
var _shove_left := 0.0
var _attack_cd := 0.6
var _cooldown := 1.3
var _windup_time := 0.45
var _reach := 2.3
var _windup := -1.0
var _stuck_t := 0.0                  # standing open after a miss
var _poise_idle := 0.0               # seconds since poise was last hit
var _turn_rate := deg_to_rad(240.0)
var _aim := Vector3.ZERO             # ranged: where the shot will go; pouncer: where the leap goes
var phase := 1                       # commander: 1 duel, 2 reinforcements and the sweep, 3 the charge
var _special := ""                   # commander: "sweep" or "charge" while that is being wound up
var _special_cd := {"sweep": 0.0, "charge": 0.0, "counter": 0.0}
var _charge_left := 0.0              # commander: metres of charge still to run
var _charge_dir := Vector3.ZERO
var _charge_hit := false
var _turned_t := 0.0                 # hauled round: it cannot turn back until this runs out
var _leap_left := 0.0                # pouncer: metres of leap still to cover
var _leap_hit := false
var _retreat_t := 0.0                # pouncer: how long the player has been running from the pack
var _circle_sign := 1.0
var _walk_dir := Vector3.ZERO        # the way to walk to reach the player: along its path
var _router: Main
var _errand := NavPath.new()         # its path somewhere else: an archer's vantage, a drummer's spot
var _flash := 0.0
## Who it fights when nothing lures it away (the player); `target` may be a lure for a while.
var _player: Node3D
## Its death burst was snuffed out (Wickpinch): it no longer bursts when it dies.
var quelled := false
var _held_t := 0.0                   # Sick: standing still after a retch
var _base_color := Color(0.75, 0.2, 0.2)
var _rig: ModelRig
var _strike_t := 0.0
## The spawn's strength factor (hp and damage were scaled by it); a beast's other blows use it too.
var _strength := 1.0

## The parts (docs/architecture/enemy-split.md): each concern is a RefCounted that reaches the node
## through its `enemy` back-reference. Outside code keeps calling the node (the forwarders at the end).
var status_part: EnemyStatuses
var hits_part: EnemyHits
var motion_part: EnemyMotion
var looks_part: EnemyLooks
var melee_brain: EnemyMeleeBrain
var ranged_brain: EnemyRangedBrain
var pouncer_brain: EnemyPouncerBrain
var support_brain: EnemySupportBrain
var commander_brain: EnemyCommanderBrain


func _init() -> void:
	status_part = EnemyStatuses.new(self)
	hits_part = EnemyHits.new(self)
	motion_part = EnemyMotion.new(self)
	looks_part = EnemyLooks.new(self)
	melee_brain = EnemyMeleeBrain.new(self)
	ranged_brain = EnemyRangedBrain.new(self)
	pouncer_brain = EnemyPouncerBrain.new(self)
	support_brain = EnemySupportBrain.new(self)
	commander_brain = EnemyCommanderBrain.new(self)


## `strength` scales health and damage - dungeon stages past the midpoint hit harder.
func setup(enemy_kind: String, player: Node3D, strength: float = 1.0) -> void:
	kind = enemy_kind
	target = player
	_player = player
	_cfg = GameData.balance["combat"]
	var d: Dictionary = GameData.enemy(enemy_kind)
	_def = d
	behaviour = str(d.get("behaviour", "melee"))
	height = float(d.get("height", 1.6))
	display_name = str(d.get("name", enemy_kind.capitalize()))
	radius = float(d.get("radius", 0.5))
	speed = float(d.get("speed", 3.4))
	damage = float(d.get("damage", 10.0)) * strength
	_strength = strength
	heavy = bool(d.get("heavy", false))
	aura_value = float(d.get("aura_value", 4.0))
	bounty = int(d.get("bounty", 150))
	_cooldown = float(d.get("attack_cooldown", 1.3))
	_windup_time = float(d.get("windup", 0.45))
	_reach = float(d.get("reach", 2.3))
	shove_resist = float(d.get("shove_resist", 1.0))
	is_living = bool(d.get("living", true))
	poise_max = float(d.get("poise", 40.0))
	poise = poise_max
	_turn_rate = deg_to_rad(float(d.get("turn_rate_deg", _cfg["turn_rate_deg"])))
	_circle_sign = 1.0 if randf() < 0.5 else -1.0
	if behaviour == "support":
		_attack_cd = _cooldown * 0.5           # the first roll comes half way through its count
	var c: Array = d.get("color", [0.75, 0.2, 0.2])
	_base_color = Color(float(c[0]), float(c[1]), float(c[2]))
	body = Body.new(float(d.get("hp", 240.0)) * strength)

	looks_part.build(d)

	# Layer 1 = world, 2 = player, 3 = enemies. Enemies block each other and the
	# world, but never physically touch the player (hits are distance checks).
	collision_layer = 4
	collision_mask = 1 | 4

	add_to_group("hittable")
	add_to_group("enemies")


func _ready() -> void:
	# start out looking at the player, so nobody's back is turned by accident
	if is_instance_valid(target):
		var to: Vector3 = target.global_position - global_position
		to.y = 0.0
		if to.length() > 0.1:
			facing = to.normalized()
	_apply_facing()


func is_dead() -> bool:
	return body.is_dead()


func is_elite() -> bool:
	return bool(_def.get("elite", false))


## Anyone can claim a place by it (a masked enemy is a lure for its friends).
func claim_slot(_enemy: Node) -> bool:
	return true


func release_slot(_enemy: Node) -> void:
	pass


# --- the slot ring --------------------------------------------------------------------------

func _has_slot() -> bool:
	return is_instance_valid(target) and target.has_method("claim_slot") and bool(target.call("claim_slot", self))


func _release_slot() -> void:
	if is_instance_valid(target) and target.has_method("release_slot"):
		target.call("release_slot", self)


# --- thinking ---------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if body.is_dead():
		return
	_tick_statuses(delta)
	if body.is_dead():
		return                                  # the burning finished it
	if _shove_left > 0.0:
		_tick_shove(delta)
		return
	# its own recovery does not depend on having someone to fight
	var rate: float = _st_mult("attack_speed_mult", "attack_rate_mult")
	var pace: float = _st_mult("move_mult", "speed_mult")
	for id: String in statuses:
		var per: float = float(_sdef(id).get("move_mult_per_stack", 1.0))
		if per != 1.0:
			pace *= pow(per, float(int((statuses[id] as Dictionary)["stacks"])))
	if _st_any("cannot_move") or _held_t > 0.0:
		pace = 0.0
	_held_t -= delta
	_attack_cd -= delta * rate
	_flash -= delta
	_turned_t -= delta
	for key: String in _special_cd:
		_special_cd[key] = float(_special_cd[key]) - delta
	_poise_idle += delta
	var top: float = poise_max * _st_mult("poise_max_mult")
	poise = minf(poise, top)
	if poise < top and _poise_idle >= float(_cfg["poise_regen_delay_s"]) and not _st_any("poise_regen_off"):
		poise = minf(top, poise + float(_cfg["poise_regen_per_s"]) * delta)
	if _field_tick(delta, pace):
		return                                  # asleep in its camp, walking home, or a beast's own state
	_pick_target()
	if not is_instance_valid(target):
		return

	var to: Vector3 = target.global_position - global_position
	to.y = 0.0
	var dist: float = to.length()
	var dir: Vector3 = to / maxf(dist, 0.001)
	var target_dead: bool = bool(target.get("dead"))
	velocity = Vector3.ZERO
	_walk_dir = _route_dir(dir, delta)

	var winding_before: bool = _windup >= 0.0
	if _st_any("cannot_act") or _kneeling():
		telegraph = {}
	elif _stuck_t > 0.0:
		_stuck_t -= delta                       # it missed, and stands there with its back open
	elif target_dead:
		telegraph = {}
	elif _flee(delta) or _walk_to_goal(delta):
		telegraph = {}                          # running from you, or walking where it was told
	else:
		var brain: EnemyBrain = _brain_for("melee" if _st_any("closes_in") else behaviour)      # Taunted: an archer or a drummer walks in to fight
		if brain != null:
			brain.think(delta, dir, dist)
		else:
			_think_behaviour(delta, dir, dist)

	velocity *= pace
	if _leap_left <= 0.0 and _charge_left <= 0.0:
		ExactSlide.slide(self, delta)
	_keep_leash()
	if not winding_before and _windup >= 0.0:
		_attack_started()
	_look(delta)


## True if a body (an enemy, a thrall, a lure: is_dead(); the player: dead) is down or gone.
static func _gone(n: Node) -> bool:
	if not is_instance_valid(n):
		return true
	return bool(n.call("is_dead")) if n.has_method("is_dead") else bool(n.get("dead"))


## True while a status keeps it from starting an attack (Shackled, Choked, Soothed...).
func _no_attack() -> bool:
	return _st_any("cannot_attack") or (behaviour == "ranged" and not _blinded().is_empty())


## Its wind-up for an attack, lengthened by what is on it (Sluggish, Blighted).
func _windup_len() -> float:
	return _windup_time * _st_mult("windup_mult")


## What its blow does, after what is on it (Dulled, Wasted, Sapped).
func _blow(amount: float) -> float:
	return amount * _st_mult("deals_mult")


## Hit whoever it is fighting. Dulled blows do not stagger you.
func _strike(amount: float, is_heavy: bool) -> void:
	var mult := 1.0
	for id: String in statuses:
		var by: Variant = (statuses[id] as Dictionary).get("by")
		if _sdef(id).has("deals_mult_vs_source") and by != null and is_instance_valid(by) and (target == by or target.get("caster") == by):
			mult *= float(_sdef(id)["deals_mult_vs_source"])          # Penitent: softer on you and yours
	target.take_hit(_blow(amount) * mult, is_heavy and not _st_any("no_poise_damage"), self)


## It has just started an attack: a status that punishes that answers (Penitent's on_attack_damage, through
## whoever put it there).
func _attack_started() -> void:
	for id: String in statuses.keys():
		if not statuses.has(id):
			continue
		var hurt_by: float = float(_sdef(id).get("on_attack_damage", 0.0))
		var by: Variant = (statuses[id] as Dictionary).get("by")
		if hurt_by > 0.0 and by != null and is_instance_valid(by) and (by as Node).has_method("deal_damage"):
			(by as Node).call("deal_damage", self, hurt_by, ["ability", "holy", "through", "penance"])
			if body.is_dead():
				return


# --- the field: camps, sleep, leash, walk home (design/07 3.5) --------------------------------------

## The camp it belongs to out in a zone (FieldCamps), or "".
var camp := ""
## Where it stands while its camp sleeps (world space).
var home := Vector3.ZERO
## A sleeping camp member: it stands about at home and ignores you until the camp wakes.
var asleep := false
var _going_home := false


## Sleep at `spot` (world): standing about, ignoring you. The camp wakes it.
func sleep_at(spot: Vector3) -> void:
	home = spot
	asleep = true
	_going_home = false
	telegraph = {}
	interrupt()
	_release_slot()


## The camp is awake: go for `who`.
func wake(who: Node3D) -> void:
	asleep = false
	_going_home = false
	target = who
	_player = who


## Past the leash: give up, walk home and mend there (then sleep).
func go_home() -> void:
	if body.is_dead():
		return
	_going_home = true
	asleep = false
	interrupt()
	_release_slot()
	telegraph = {}


func is_going_home() -> bool:
	return _going_home


## One frame of the field's own states. Returns true when it used the frame (asleep, walking home,
## or a beast's state of its own - see Beast), so the fighting logic is skipped.
func _field_tick(delta: float, pace: float) -> bool:
	if _going_home:
		_walk_home(delta, pace)
		return true
	if asleep:
		velocity = Vector3.ZERO
		telegraph = {}
		_look(delta)
		return true
	return false


## Walk the path home; there it mends to full and sleeps.
func _walk_home(delta: float, pace: float) -> void:
	telegraph = {}
	var to: Vector3 = home - global_position
	to.y = 0.0
	if to.length() <= float((GameData.balance.get("camps", {}) as Dictionary).get("home_reached", 1.5)):
		_going_home = false
		body.heal(body.total_max())
		poise = poise_max
		statuses.clear()
		_refresh_label()
		_arrived_home()
		velocity = Vector3.ZERO
		_look(delta)
		return
	var way: Vector3 = to.normalized()
	var nav: LevelNav = _level_nav()
	if nav != null:
		var stepped: Vector3 = _errand.steer(nav, global_position, home, radius, delta)
		if stepped != Vector3.ZERO:
			way = stepped
	_turn_toward(way, delta)
	velocity = way * speed * pace
	ExactSlide.slide(self, delta)
	_look(delta)


## Home again after walking back: sleep (a beast may do something else).
func _arrived_home() -> void:
	asleep = true


## The brain that thinks for behaviour `name` (enemies.json "behaviour"): ranged, pouncer, support and
## commander have one each; anything else - melee, and a beast's own behaviours - is null, and the hook
## below (_think_behaviour) decides.
func _brain_for(name: String) -> EnemyBrain:
	match name:
		"ranged":
			return ranged_brain
		"pouncer":
			return pouncer_brain
		"support":
			return support_brain
		"commander":
			return commander_brain
	return null


## What it does in a fight when no brain of the node's own is chosen (_brain_for): melee here. Beast
## overrides this for the beasts' own behaviours, and falls back on the melee brain for the rest.
func _think_behaviour(delta: float, dir: Vector3, dist: float) -> void:
	_think_melee(delta, dir, dist)


# --- public readers (docs/architecture/typed-calls.md) ---------------------------------------------------
# Outside code (the harness, the player's skills) reaches these private fields and helpers through a public name, so
# its calls stay typed. Each is a plain alias: the private name is untouched, so the parts and the tests that name it
# by string read and write the same thing.

## Seconds left on the wind-up of the attack being readied, below 0 when none is (`_windup`).
var windup_left: float:
	get: return _windup
	set(value): _windup = value
## Seconds it has stood open after a miss (`_stuck_t`).
var stuck_left: float:
	get: return _stuck_t
## A pouncer's metres of leap still to cover (`_leap_left`).
var leap_left: float:
	get: return _leap_left
## A pouncer: how long the player has been running from the pack (`_retreat_t`).
var retreat_time: float:
	get: return _retreat_t
## A commander's special being wound up, "sweep" or "charge", else "" (`_special`).
var special_move: String:
	get: return _special
## The model rig (`_rig`).
var model_rig: ModelRig:
	get: return _rig


## Turn the rig to `facing` now (`_apply_facing`).
func apply_facing() -> void: looks_part._apply_facing()
## Redraw the melee wind-up's telegraph (`_update_melee_telegraph`).
func update_melee_telegraph() -> void: looks_part._update_melee_telegraph()


# --- forwarders: outside code (the player, projectiles, zones, the HUD, Beast, the tests) calls the
# node by name; each part's functions answer here (docs/architecture/enemy-split.md)

# EnemyStatuses (status_part): the status engine
func _sdef(id: String) -> Dictionary: return status_part._sdef(id)
func _canon(id: String) -> String: return status_part._canon(id)
func _st_any(key: String) -> bool: return status_part._st_any(key)
func _st_mult(key: String, alt: String = "") -> float: return status_part._st_mult(key, alt)
func add_status(id: String, stacks: int = 1, by: Node = null, opts: Dictionary = {}) -> int: return status_part.add_status(id, stacks, by, opts)
func status_stacks(id: String) -> int: return status_part.status_stacks(id)
func purge_boons() -> void: status_part.purge_boons()
func has_status(id: String) -> bool: return status_part.has_status(id)
func clear_status(id: String) -> void: status_part.clear_status(id)
func _end_with(id: String) -> void: status_part._end_with(id)
func status_sum_by(key: String, who: Node) -> float: return status_part.status_sum_by(key, who)
func status_from(key: String, who: Node) -> Array: return status_part.status_from(key, who)
func status_data(id: String) -> Dictionary: return status_part.status_data(id)
func front_armour() -> float: return status_part.front_armour()
func metal_class() -> int: return status_part.metal_class()
func flesh() -> float: return status_part.flesh()
func blocks_heal() -> bool: return status_part.blocks_heal()
func no_conduct() -> bool: return status_part.no_conduct()
func _shove_class() -> float: return status_part._shove_class()
func light_radius() -> float: return status_part.light_radius()
func _blinded() -> Dictionary: return status_part._blinded()
func _zone_dps_mult(id: String) -> float: return status_part._zone_dps_mult(id)
func _zone_bill_bonus() -> float: return status_part._zone_bill_bonus()
func _in_zone_flag(key: String) -> bool: return status_part._in_zone_flag(key)
func _in_zone_list(key: String, id: String) -> bool: return status_part._in_zone_list(key, id)
func _after_hurt(applied: float, was_winding: bool) -> void: status_part._after_hurt(applied, was_winding)
func _expire(id: String) -> void: status_part._expire(id)
func _death_effects() -> void: status_part._death_effects()
func _tick_statuses(delta: float) -> void: status_part._tick_statuses(delta)
func _in_zone_banking(id: String) -> bool: return status_part._in_zone_banking(id)
func _tick_status(id: String, delta: float) -> void: status_part._tick_status(id, delta)
func _tick_alight(delta: float) -> void: status_part._tick_alight(delta)
func _nearest_enemy_within(reach: float) -> Node3D: return status_part._nearest_enemy_within(reach)
func lure_reach() -> float: return status_part.lure_reach()
func _charmed() -> bool: return status_part._charmed()
func _kneeling() -> bool: return status_part._kneeling()

# EnemyHits (hits_part): taking hits and poise
func is_behind(point: Vector3) -> bool: return hits_part.is_behind(point)
func is_in_front(point: Vector3) -> bool: return hits_part.is_in_front(point)
func take_hit(amount: float, _heavy: bool, source: Node, tags: Array = []) -> float: return hits_part.take_hit(amount, _heavy, source, tags)
func take_poise(amount: float) -> bool: return hits_part.take_poise(amount)
func guards_front(point: Vector3) -> bool: return hits_part.guards_front(point)
func blocks_shot(point: Vector3) -> bool: return hits_part.blocks_shot(point)
func _answer_block() -> void: hits_part._answer_block()
func stagger(seconds: float) -> void: hits_part.stagger(seconds)
func _knock_down() -> void: hits_part._knock_down()
func _leave_fallen() -> void: hits_part._leave_fallen()
func stun(seconds: float) -> void: hits_part.stun(seconds)
func interrupt() -> void: hits_part.interrupt()
func interrupt_attack() -> bool: return hits_part.interrupt_attack()
func is_interruptible() -> bool: return hits_part.is_interruptible()
func is_lunging() -> bool: return hits_part.is_lunging()
func shove(dir: Vector3, metres: float) -> void: hits_part.shove(dir, metres)
func pull_toward(point: Vector3, metres: float, keep: float = 0.3) -> void: hits_part.pull_toward(point, metres, keep)
func nudge(step: Vector3) -> void: hits_part.nudge(step)
func turn_away_from(point: Vector3, seconds: float) -> void: hits_part.turn_away_from(point, seconds)
func is_shoved() -> bool: return hits_part.is_shoved()
func _tick_shove(delta: float) -> void: hits_part._tick_shove(delta)
func _shove_ended() -> void: hits_part._shove_ended()

# EnemyMotion (motion_part): movement, routing and sight
func _keep_leash() -> void: motion_part._keep_leash()
func _pick_target() -> void: motion_part._pick_target()
func _forced_target() -> Node3D: return motion_part._forced_target()
func _flee(_delta: float) -> bool: return motion_part._flee(_delta)
func _walk_to_goal(_delta: float) -> bool: return motion_part._walk_to_goal(_delta)
func _route_dir(straight: Vector3, delta: float = 0.0) -> Vector3: return motion_part._route_dir(straight, delta)
func _level_nav() -> LevelNav: return motion_part._level_nav()
func _round_stone(nav: LevelNav, next: Vector3, way: Vector3) -> Vector3: return motion_part._round_stone(nav, next, way)
func _fallback_dir(straight: Vector3) -> Vector3: return motion_part._fallback_dir(straight)
func _door_dir(straight: Vector3) -> Vector3: return motion_part._door_dir(straight)
func _turn_toward(want: Vector3, delta: float) -> void: motion_part._turn_toward(want, delta)
func sees_point(point: Vector3) -> bool: return motion_part.sees_point(point)
func _clear(from: Vector3, to: Vector3) -> bool: return motion_part._clear(from, to)
func _has_floor(spot: Vector3) -> bool: return motion_part._has_floor(spot)
func _sees_target() -> bool: return motion_part._sees_target()

# EnemyLooks (looks_part): telegraphs and the rig
func _update_melee_telegraph() -> void: looks_part._update_melee_telegraph()
func _apply_facing() -> void: looks_part._apply_facing()
func _look(delta: float) -> void: looks_part._look(delta)
func _refresh_label() -> void: looks_part._refresh_label()

# EnemyMeleeBrain (melee_brain): the melee brain
func _think_melee(delta: float, dir: Vector3, dist: float) -> void: melee_brain.think(delta, dir, dist)
func _land_melee(dist: float) -> void: melee_brain._land_melee(dist)

# EnemyRangedBrain (ranged_brain): the ranged brain
func _think_ranged(delta: float, dir: Vector3, dist: float) -> void: ranged_brain.think(delta, dir, dist)
func _loose() -> void: ranged_brain._loose()
func _retreat_dir(dir: Vector3) -> Vector3: return ranged_brain._retreat_dir(dir)
func _seek_line(delta: float) -> Vector3: return ranged_brain._seek_line(delta)
func _find_vantage() -> Variant: return ranged_brain._find_vantage()

# EnemyPouncerBrain (pouncer_brain): the pouncer brain
func _think_pouncer(delta: float, dir: Vector3, dist: float) -> void: pouncer_brain.think(delta, dir, dist)
func _pack_centre() -> Vector3: return pouncer_brain._pack_centre()
func _tick_leap(delta: float) -> void: pouncer_brain._tick_leap(delta)

# EnemySupportBrain (support_brain): the support brain
func _allies_within(reach: float) -> Array[Node3D]: return support_brain._allies_within(reach)
func _think_support(delta: float, dir: Vector3) -> void: support_brain.think(delta, dir, 0.0)
func _drum_roll(near: Array[Node3D]) -> void: support_brain._drum_roll(near)

# EnemyCommanderBrain (commander_brain): the commander brain
func _think_commander(delta: float, dir: Vector3, dist: float) -> void: commander_brain.think(delta, dir, dist)
func _land_sweep(dist: float) -> void: commander_brain._land_sweep(dist)
func _tick_charge(delta: float) -> void: commander_brain._tick_charge(delta)
