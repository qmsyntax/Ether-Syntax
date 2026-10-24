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
var _shove_dir := Vector3.ZERO
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
var _aim_locked := false
var _vantage: Variant = null         # ranged: a spot it is walking to because it can shoot from there
var _vantage_t := 0.0                # ranged: until it looks for a better one
var _retreat_side := 1.0             # ranged: which way it turned the last time its back was to a wall
var phase := 1                       # commander: 1 duel, 2 reinforcements and the sweep, 3 the charge
var _special := ""                   # commander: "sweep" or "charge" while that is being wound up
var _special_cd := {"sweep": 0.0, "charge": 0.0, "counter": 0.0}
var _charge_left := 0.0              # commander: metres of charge still to run
var _charge_dir := Vector3.ZERO
var _charge_hit := false
var _pulse_t := 0.0                  # support: until it strengthens those near it again
var _turned_t := 0.0                 # hauled round: it cannot turn back until this runs out
var _leap_left := 0.0                # pouncer: metres of leap still to cover
var _leap_hit := false
var _retreat_t := 0.0                # pouncer: how long the player has been running from the pack
var _circle_sign := 1.0
var _burn_t := 0.0                   # alight: time toward the next tick of burning
var _spread_t := 0.0                 # alight: how long someone has stood close enough to catch
var _walk_dir := Vector3.ZERO        # the way to walk to reach the player: along its path
var _router: Node
var _nav: LevelNav                   # the level's navigation, once it has been baked (see LevelNav)
var _chase := NavPath.new()          # its path to the player
var _errand := NavPath.new()         # its path somewhere else: an archer's vantage, a drummer's spot
var _flash := 0.0
## Who it fights when nothing lures it away (the player); `target` may be a lure for a while.
var _player: Node3D
var _lured := false
## Its death burst was snuffed out (Wickpinch): it no longer bursts when it dies.
var quelled := false
var _retch_t := 0.0                  # Sick: until the next retch
var _held_t := 0.0                   # Sick: standing still after a retch
var _base_color := Color(0.75, 0.2, 0.2)
var _label: Label3D
var _rig: ModelRig
var _strike_t := 0.0
var _shown_highlight := 0
var _shown_windup := false
var _shown_down := false
## The spawn's strength factor (hp and damage were scaled by it); a beast's other blows use it too.
var _strength := 1.0


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

	# The look: a real body when real bodies are on (Models.enemy), else a procedural model.
	# Gameplay size still comes from data.
	_rig = Models.enemy(enemy_kind)
	add_child(_rig)

	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = height
	col.shape = shape
	col.position.y = height * 0.5
	add_child(col)

	if d.has("aura_ring"):
		# a ring on the ground at the distance that matters for this one (design/05 6.1)
		var ring_def: Dictionary = d["aura_ring"]
		var rc: Array = ring_def.get("color", [1.0, 1.0, 1.0])
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.outer_radius = float(ring_def["radius"])
		torus.inner_radius = float(ring_def["radius"]) - 0.07
		torus.rings = 48
		torus.ring_segments = 6
		ring.mesh = torus
		var ring_mat := StandardMaterial3D.new()
		ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mat.albedo_color = Color(float(rc[0]), float(rc[1]), float(rc[2]), 0.4)
		ring.material_override = ring_mat
		ring.position.y = 0.06
		ring.scale.y = 0.2
		add_child(ring)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 36
	_label.outline_size = 10
	_label.pixel_size = 0.01
	_label.position.y = height + 0.5
	_label.visible = false          # health is shown by the HUD's floating bars and target frame
	add_child(_label)
	_refresh_label()

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


# --- being hit ------------------------------------------------------------------------------

## True if `point` is within the back arc: a hit from there is a rear hit. An Exposed body is all back.
func is_behind(point: Vector3) -> bool:
	if _st_any("counts_rear"):
		return true
	var from: Vector3 = point - global_position
	from.y = 0.0
	if from.length() < 0.05:
		return false
	return (-facing).angle_to(from.normalized()) <= deg_to_rad(float(_cfg["rear_arc_deg"]) * 0.5)


## True if `point` is within the front arc (the same width as the back one).
func is_in_front(point: Vector3) -> bool:
	var from: Vector3 = point - global_position
	from.y = 0.0
	if from.length() < 0.05:
		return true
	return facing.angle_to(from.normalized()) <= deg_to_rad(float(_cfg["rear_arc_deg"]) * 0.5)


## `tags` are the hit's (HitContext tags): "through" passes the front guard; a status's
## damage_taken_except / damage_taken_from read them.
func take_hit(amount: float, _heavy: bool, source: Node, tags: Array = []) -> float:
	var mult := 1.0
	for id: String in statuses:
		var def: Dictionary = _sdef(id)
		var excepted := false
		for t: Variant in def.get("damage_taken_except", []):
			if tags.has(t):
				excepted = true
		if not excepted:
			mult *= float(def.get("damage_taken_mult", 1.0))
		var from_aff: Dictionary = def.get("damage_taken_from", {})
		for aff: String in from_aff:
			if tags.has(aff):
				mult *= float(from_aff[aff])
	# hide, plate or a shield in front: it shrugs off part of anything that does not come round the side
	if source is Node3D and not tags.has("through") and guards_front((source as Node3D).global_position):
		mult *= 1.0 - front_armour()
		_answer_block()
	var want: float = amount * mult
	# Spared: nothing takes it below its floor
	var floor_hp: float = 0.0
	for id: String in statuses:
		floor_hp = maxf(floor_hp, float(_sdef(id).get("floor_health", 0.0)))
	if floor_hp > 0.0:
		want = minf(want, maxf(0.0, body.total() - floor_hp))
	var winding: bool = _windup >= 0.0
	var applied: float = body.apply_damage(want)
	_flash = 0.12
	if _rig != null:
		_rig.flash(0.12)
	_refresh_label()
	if applied > 0.0:
		hurt.emit(self, source)                 # its camp wakes; a herd answers (FieldCamps)
	if applied > 0.0 and not body.is_dead():
		_after_hurt(applied, winding)
		for id: String in statuses.keys():
			if statuses.has(id) and bool(_sdef(id).get("ends_on_source_hit", false)) and (statuses[id] as Dictionary).get("by") == source and source != null:
				statuses.erase(id)                     # Charmed: a hit from whoever charmed it snaps it out
	if body.is_dead():
		_release_slot()
		telegraph = {}
		var quiet: bool = _st_any("no_death_effects")
		if _def.has("death_burst") and str((_def["death_burst"] as Dictionary).get("kind", "")) == "scald" and is_inside_tree() and not quiet:
			ScaldBurst.leave(get_parent(), global_position, _def["death_burst"], _strength, _player)
		elif _def.has("death_burst") and is_inside_tree() and not quelled and not quiet and not _in_zone_flag("no_heal"):
			var cfg: Dictionary = _def["death_burst"]
			var burst := CenserBurst.new()
			burst.radius = float(cfg.get("radius", 4.0))
			burst.delay = float(cfg.get("delay", 0.8))
			burst.heal_frac = float(cfg.get("heal_frac", 0.4))
			burst.status = str(cfg.get("status", "frenzied"))
			get_parent().add_child(burst)
			burst.global_position = global_position
		if not quiet:
			_death_effects()
		_leave_fallen()
		remove_from_group("hittable")
		remove_from_group("enemies")
		killed.emit(self)
		if _rig != null and _rig.has_method("lie_and_fade") and get_parent() != null:
			var at: Transform3D = _rig.global_transform
			remove_child(_rig)
			get_parent().add_child(_rig)
			_rig.global_transform = at
			_rig.call("lie_and_fade", GameData.num("combat", "corpse_lie_s"))
			_rig = null
		queue_free()
		return applied
	# a pouncer struck while it is crouched or in the air comes down hard
	if behaviour == "pouncer" and applied > 0.0 and (_windup >= 0.0 or _leap_left > 0.0):
		_knock_down()
	return applied


## Take poise damage. At zero the enemy is Staggered: its attack is lost and it stands open.
## Returns true if this broke it.
func take_poise(amount: float) -> bool:
	if body.is_dead() or amount <= 0.0 or has_status("staggered"):
		return false
	_poise_idle = 0.0
	for id: String in statuses:
		amount /= float(GameData.status(id).get("poise_mult", 1.0))      # a drum behind it steadies it
	poise = maxf(0.0, poise - amount)
	if poise > 0.0:
		return false
	stagger(float(_def.get("stagger_s", GameData.status("staggered").get("lasts", 1.5))))
	return true


## True if a hit from `point` meets this enemy's guard: it has front armour, the hit comes from
## its front arc, it is on its feet, and (for a commander) it is still in the phase where it blocks.
## A status with front_block_off (Exposed, Stripped, Seeped) takes the guard away.
func guards_front(point: Vector3) -> bool:
	if float(_def.get("front_armour", 0.0)) <= 0.0 or has_status("staggered") or has_status("stunned") or _st_any("front_block_off"):
		return false
	if _def.has("front_armour_until_frac") and body.total() / body.total_max() <= float(_def["front_armour_until_frac"]):
		return false
	return is_in_front(point)


## True if a shot coming from `point` stops on this enemy's shield instead of passing through.
func blocks_shot(point: Vector3) -> bool:
	return bool(_def.get("blocks_shots", false)) and guards_front(point)


## A blocked hit is answered: a quick swing, if whoever struck is still in reach.
func _answer_block() -> void:
	if not _def.has("counter") or _windup >= 0.0 or _special != "" or _charge_left > 0.0 or float(_special_cd["counter"]) > 0.0:
		return
	if not is_instance_valid(target) or global_position.distance_to(target.global_position) > _reach + radius + 0.5:
		return
	var cfg: Dictionary = _def["counter"]
	_windup = float(cfg.get("windup", 0.25))
	_special_cd["counter"] = float(cfg.get("cooldown", 2.5))
	_update_melee_telegraph()


## Cannot act for `seconds` and takes more damage; a bare strike on it is an Opening.
func stagger(seconds: float) -> void:
	interrupt()
	_leap_left = 0.0
	_stuck_t = 0.0
	statuses["staggered"] = {"stacks": 1, "t": maxf(seconds, float((statuses.get("staggered", {}) as Dictionary).get("t", 0.0)))}
	poise = poise_max                       # it gets its footing back when it gets up


func _knock_down() -> void:
	stagger(float(_def.get("knockdown_s", 2.0)))
	_attack_cd = _cooldown


# --- statuses, stun, shove ----------------------------------------------------------------

# --- the status engine (statuses.json: generic keys, read here and nowhere else) -----------------

## A status's definition, following alias_of (rooted is pinned).
func _sdef(id: String) -> Dictionary:
	var def: Dictionary = GameData.status(id)
	if def.has("alias_of"):
		return GameData.status(str(def["alias_of"]))
	return def


## The id a status is kept under (an alias is kept under what it stands for).
func _canon(id: String) -> String:
	var def: Dictionary = GameData.status(id)
	return str(def.get("alias_of", id))


## True if any status on it carries flag `key`.
func _st_any(key: String) -> bool:
	for id: String in statuses:
		if bool(_sdef(id).get(key, false)):
			return true
	return false


## The product of a number every status on it may carry (1 if none does). `alt` is an older name
## for the same key (speed_mult for move_mult, attack_rate_mult for attack_speed_mult).
func _st_mult(key: String, alt: String = "") -> float:
	var out := 1.0
	for id: String in statuses:
		var def: Dictionary = _sdef(id)
		out *= float(def.get(key, def.get(alt, 1.0)) if alt != "" else def.get(key, 1.0))
	return out


## Add `stacks` of a status (capped at its maximum) and refresh how long it lasts. `by` is who
## applied it: a status that does damage does it in their name. `opts` (a skill's payload) may set
## "lasts" (seconds), "time_mult", and "data" (numbers the status reads from the skill, such as
## Dripping's nudge, or where a Commanded body walks). Returns the stacks it now has.
func add_status(id: String, stacks: int = 1, by: Node = null, opts: Dictionary = {}) -> int:
	id = _canon(id)
	var def: Dictionary = _sdef(id)
	if def.is_empty() or body.is_dead() or bool(def.get("derived", "") != ""):
		return 0
	if bool(def.get("living_only", false)) and not is_living:
		return 0
	if bool(def.get("elites_immune", false)) and bool(_def.get("elite", false)):
		return 0                                   # Exiled: an elite only takes the hit's shove
	# what is on it, or the ground it stands on, may refuse the status
	for other: String in statuses:
		if (_sdef(other).get("blocks", []) as Array).has(id):
			return 0
	if _in_zone_list("blocks_status", id):
		return 0
	# an elite shrugs some holds off into something lesser; a sleep needs a daze first; Wakeful refuses sleep
	if bool(_def.get("elite", false)) and str(def.get("elite_status", "")) != "" and str(def["elite_status"]) != id:
		return add_status(str(def["elite_status"]), 1, by, opts)
	for blocker: Variant in def.get("blocked_by", []):
		if has_status(str(blocker)):
			return add_status(str(def.get("needs_first", "dazed")), 1, by) if def.has("needs_first") else 0
	if def.has("needs_first") and not has_status(str(def["needs_first"])):
		return add_status(str(def["needs_first"]), 1, by)
	if id == "aloft":
		if _shove_class() < 1.0:
			take_poise(float(def.get("heavy_poise", 50.0)))    # too heavy to leave the ground: it loses its footing instead
			return 0
		interrupt()
		_leap_left = 0.0
	var cap: int = int(def.get("stacks", 1))
	for other: String in statuses:
		cap = maxi(cap, int((_sdef(other).get("cap_raise", {}) as Dictionary).get(id, 0)))
	var had: Dictionary = statuses.get(id, {})
	var now: int = mini(cap, int(had.get("stacks", 0)) + stacks)
	var who: Node = by if by != null else (had.get("by") as Node)
	var lasts: float = float(opts.get("lasts", def.get("lasts", 1.0)))
	lasts *= float(opts.get("time_mult", 1.0))
	if heavy and def.has("heavy_lasts_mult"):
		lasts *= float(def["heavy_lasts_mult"])
	if bool(def.get("no_refresh", false)) and not had.is_empty():
		lasts = float(had["t"])                  # Dosed: more doses, the same clock
	var entry: Dictionary = {"stacks": now, "t": maxf(lasts, 0.01), "by": who}
	var data: Dictionary = (had.get("data", {}) as Dictionary).duplicate()
	data.merge(opts.get("data", {}), true)
	if not data.is_empty():
		entry["data"] = data
	if had.has("taken"):
		entry["taken"] = had["taken"]
	statuses[id] = entry
	if had.is_empty():
		# the first time only: it changes another status's clock (Steeped: the dose clock runs longer, once)
		var more: Dictionary = def.get("adds_time", {})
		for other_id: String in more:
			if statuses.has(_canon(other_id)):
				var o: Dictionary = statuses[_canon(other_id)]
				o["t"] = float(o["t"]) + float(data.get("clock_add", more[other_id]))
		# turned round, its back to whoever did it (Turning Palm, Blowout, Deflect)
		if bool(def.get("turn_away", false)) and who is Node3D and is_instance_valid(who):
			turn_away_from((who as Node3D).global_position, float(entry["t"]))
	for gone: Variant in def.get("ends", []):
		if str(gone) != id:
			clear_status(str(gone))
	if bool(def.get("control", false)) or bool(def.get("cannot_act", false)) or bool(def.get("cannot_attack", false)):
		interrupt()                               # a hold breaks off whatever it was winding up
		_leap_left = 0.0 if bool(def.get("cannot_act", false)) else _leap_left
	# a status that fills up turns into another (Chill, at five, is Frozen)
	var on_cap: Dictionary = def.get("on_cap", {})
	if not on_cap.is_empty() and now >= int(def.get("stacks", 1)):
		if bool(on_cap.get("clear", false)):
			statuses.erase(id)
		var next: String = str(on_cap.get("elite_status", "")) if bool(_def.get("elite", false)) and on_cap.has("elite_status") else str(on_cap.get("status", ""))
		if next != "":
			add_status(next, 1, who)
		return now
	return now


func status_stacks(id: String) -> int:
	id = _canon(id)
	if statuses.has(id):
		return int((statuses[id] as Dictionary).get("stacks", 0))
	return 1 if has_status(id) else 0


## True if it carries the status, or one that counts as it (Waterlogged is Soaked, Frozen is
## Brittle), or - for a derived one - its health says so (Dying below half, Hale above).
func has_status(id: String) -> bool:
	id = _canon(id)
	if statuses.has(id):
		return true
	var def: Dictionary = _sdef(id)
	match str(def.get("derived", "")):
		"below_half":
			return is_living and body.total() < body.total_max() * 0.5
		"above_half":
			return is_living and body.total() > body.total_max() * 0.5
	for other: String in statuses:
		if (_sdef(other).get("counts_as", []) as Array).has(id):
			return true
	return false


func clear_status(id: String) -> void:
	statuses.erase(_canon(id))
	_end_with(_canon(id))


## Statuses that end with `id` (ends_with: a barb pulled when its doses are spent or paid).
func _end_with(id: String) -> void:
	for other: String in statuses.keys():
		if (_sdef(other).get("ends_with", []) as Array).has(id):
			statuses.erase(other)


## The sum of number `key` over the statuses on it that `who` put there (Tithed's heal, Leeched's drain for
## whoever applied it); 0 if none.
func status_sum_by(key: String, who: Node) -> float:
	var out := 0.0
	for id: String in statuses:
		var s: Dictionary = statuses[id]
		if s.get("by") == who and is_instance_valid(who):
			out += float(_sdef(id).get(key, 0.0))
	return out


## A status of its put there by `who` (or by a summon of theirs) carrying `key`, as [id, entry], or [].
func status_from(key: String, who: Node) -> Array:
	for id: String in statuses:
		var s: Dictionary = statuses[id]
		var by: Variant = s.get("by")
		if _sdef(id).has(key) and by != null and is_instance_valid(by) and (by == who or (who != null and who.get("caster") == by)):
			return [id, s]
	return []


## The data a skill left with a status (Dripping's nudge, a Commanded walk's goal), or {}.
func status_data(id: String) -> Dictionary:
	return (statuses.get(_canon(id), {}) as Dictionary).get("data", {})


## Its front armour after what is on it (Lit, Rotting, Rusting halve it; Corroded takes a third a stack).
func front_armour() -> float:
	var a: float = float(_def.get("front_armour", 0.0)) * _st_mult("armour_mult")
	for id: String in statuses:
		var per: float = float(_sdef(id).get("armour_mult_per_stack", 1.0))
		if per != 1.0:
			a *= pow(per, float(int((statuses[id] as Dictionary)["stacks"])))
	return a


## How much metal it wears: 0 bare, 1 mailed, 2 plated (enemies.json "metal"); Stripped is bare.
func metal_class() -> int:
	return 0 if _st_any("metal_class_off") else int(_def.get("metal", 0))


## The share of it not under worn armour (enemies.json "flesh"), raised by Corroded.
func flesh() -> float:
	var f: float = float(_def.get("flesh", 1.0))
	for id: String in statuses:
		f += float(_sdef(id).get("flesh_per_stack", 0.0)) * float(int((statuses[id] as Dictionary)["stacks"]))
	return clampf(f, 0.0, 1.0)


func is_elite() -> bool:
	return bool(_def.get("elite", false))


## Nothing heals it (Arrested; standing in Clean Air).
func blocks_heal() -> bool:
	return _st_any("no_heal") or _in_zone_flag("no_heal")


## Lightning does not pass into or out of it (Insulated): no conducted marks.
func no_conduct() -> bool:
	return _st_any("no_conduct")


## How far a shove moves it: one weight class lighter while Waterlogged or Dwindled.
func _shove_class() -> float:
	if _st_any("lighter_class"):
		return 1.0 if shove_resist >= 0.5 else 0.5
	return shove_resist


## Light it gives off (Alight, Lit): Light.level_at reads it.
func light_radius() -> float:
	var r := 0.0
	for id: String in statuses:
		r = maxf(r, float(_sdef(id).get("light_radius", 0.0)))
	return r


## True if it can see `point`: in its front arc, nothing solid between, not blinded past its sight.
## Asleep sees nothing (Dream reads that apart). Mindless kinds (enemies.json "mindless") see no mind.
func sees_point(point: Vector3) -> bool:
	if body.is_dead() or bool(_def.get("mindless", false)):
		return false
	if not is_in_front(point):
		return false
	var blind: Dictionary = _blinded()
	if not blind.is_empty() and Vector2(point.x - global_position.x, point.z - global_position.z).length() > float(blind.get("sight", 2.0)):
		return false
	if not is_inside_tree():
		return true
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, point + Vector3.UP, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _blinded() -> Dictionary:
	for id: String in statuses:
		var b: Variant = _sdef(id).get("blinded")
		if b is Dictionary:
			return b
	return {}


## The product of the ground zones under it that tick status `id` harder (dps_mult {id: x}).
func _zone_dps_mult(id: String) -> float:
	var m := 1.0
	if not is_inside_tree():
		return m
	for z: Node in get_tree().get_nodes_in_group("ground_zones"):
		var dm: Variant = z.get("dps_mult")
		if dm is Dictionary and (dm as Dictionary).has(id) and bool(z.call("has_point", global_position, radius)):
			m *= float((dm as Dictionary)[id])
	return m


## The largest bill bonus of the ground zones under it (Clean Air's dose_bonus).
func _zone_bill_bonus() -> float:
	var b := 0.0
	if not is_inside_tree():
		return b
	for z: Node in get_tree().get_nodes_in_group("ground_zones"):
		if float(z.get("bill_bonus")) > 0.0 and bool(z.call("has_point", global_position, radius)):
			b = maxf(b, float(z.get("bill_bonus")))
	return b


## A ground zone of the caster's under it carries this flag (no_heal: Clean Air).
func _in_zone_flag(key: String) -> bool:
	if not is_inside_tree():
		return false
	for z: Node in get_tree().get_nodes_in_group("ground_zones"):
		if bool(z.get(key)) and bool(z.call("has_point", global_position, radius)):
			return true
	return false


## A ground zone under it lists `id` under `key` (blocks_status).
func _in_zone_list(key: String, id: String) -> bool:
	if not is_inside_tree():
		return false
	for z: Node in get_tree().get_nodes_in_group("ground_zones"):
		var list: Variant = z.get(key)
		if list is Array and (list as Array).has(id) and bool(z.call("has_point", global_position, radius)):
			return true
	return false


## Anyone can claim a place by it (a masked enemy is a lure for its friends).
func claim_slot(_enemy: Node) -> bool:
	return true


func release_slot(_enemy: Node) -> void:
	pass


## It was hurt (and lives): what its statuses do about that.
func _after_hurt(applied: float, was_winding: bool) -> void:
	for id: String in statuses.keys():
		if not statuses.has(id):
			continue
		var def: Dictionary = _sdef(id)
		var s: Dictionary = statuses[id]
		if bool(def.get("wakes_on_hit", false)):
			statuses.erase(id)
			if str(def.get("then_status", "")) != "":
				add_status(str(def["then_status"]), 1, s.get("by") as Node)
			continue
		if def.has("ends_after_damage"):
			s["taken"] = float(s.get("taken", 0.0)) + applied
			if float(s["taken"]) >= float(def["ends_after_damage"]):
				_expire(id)
	if was_winding and _st_any("staggers_in_windup"):
		stagger(float(_cfg["interrupt_stagger_s"]))


## A status ran out: what it leaves behind (Frozen leaves Chill; Dosed pays its bill; a hold that
## carries a release shove throws it away from whoever put it there).
func _expire(id: String) -> void:
	var s: Dictionary = statuses.get(id, {})
	statuses.erase(id)
	if s.is_empty() or body.is_dead():
		return
	var def: Dictionary = _sdef(id)
	var by: Variant = s.get("by")
	var who: Node = by if (by != null and is_instance_valid(by)) else null
	var ex: Dictionary = def.get("on_expire", {})
	if ex.has("status"):
		add_status(str(ex["status"]), int(ex.get("stacks", 1)), who)
	if ex.has("damage_per_stack"):
		var dmg: float = float(ex["damage_per_stack"]) * float(int(s.get("stacks", 1)))
		for other: String in statuses:
			var os: Dictionary = statuses[other]
			# Steeped: a bigger bill (the skill's own bill_mult, in its data, else the status's)
			var bm: Dictionary = _sdef(other).get("bill_mult", {})
			if bm.has(id):
				dmg *= float((os.get("data", {}) as Dictionary).get("bill_mult", bm[id]))
		dmg *= 1.0 + _zone_bill_bonus()                  # Clean Air: a bill paid inside costs more
		dmg *= float((s.get("data", {}) as Dictionary).get("bill_mult", 1.0))      # Venom Spur: this bill only
		if who != null and who.has_method("deal_damage"):
			who.call("deal_damage", self, dmg, ex.get("tags", ["dot"]))
		else:
			take_hit(dmg, false, null)
		if is_inside_tree() and not body.is_dead():
			FloatText.spawn(get_parent(), global_position + Vector3.UP * (height + 0.3), str(def.get("label", id)).to_upper(), Color(str(def.get("color", "ffffff"))))
	var data: Dictionary = s.get("data", {})
	if float(data.get("release_shove", 0.0)) > 0.0 and who is Node3D:
		shover = who
		shove(global_position - (who as Node3D).global_position, float(data["release_shove"]))
	_end_with(id)
	# a status that raised another's cap is gone: what is above the plain cap falls away (Contained's Infected)
	for other: String in statuses.keys():
		var cap: int = int(_sdef(other).get("stacks", 1))
		for o2: String in statuses:
			cap = maxi(cap, int((_sdef(o2).get("cap_raise", {}) as Dictionary).get(other, 0)))
		if int((statuses[other] as Dictionary).get("stacks", 1)) > cap:
			(statuses[other] as Dictionary)["stacks"] = cap


## What its statuses leave when it dies: a burning that jumps, a pool of blood, a sick cloud.
func _death_effects() -> void:
	for id: String in statuses:
		var def: Dictionary = _sdef(id)
		var s: Dictionary = statuses[id]
		var by: Variant = s.get("by")
		var who: Node = by if (by != null and is_instance_valid(by)) else null
		if bool(def.get("jumps_on_death", false)):
			var heir: Node3D = _nearest_enemy_within(float(def.get("spread_radius", 1.2)))
			if heir != null:
				heir.call("add_status", id, 1, who)
		var od: Dictionary = def.get("on_death", {})
		if od.is_empty() or who == null:
			continue
		if bool(od.get("pool", false)) and who.has_method("spill_blood"):
			who.call("spill_blood", global_position, int(GameData.affinity("blood").get("pool", {}).get("death_measures", 3)), true)
		if int(od.get("held_blood", 0)) > 0 and who.has_method("gain_blood"):
			who.call("gain_blood", int(od["held_blood"]))
		if od.has("cloud") and who.has_method("lay_cloud"):
			who.call("lay_cloud", global_position, od["cloud"], ["disease", "cloud"])


## Where it fell stays a body for a while, for Death's skills (Fallen).
func _leave_fallen() -> void:
	if not is_inside_tree():
		return
	var f := Fallen.new()
	f.kind = kind
	var lie: float = GameData.num("combat", "corpse_lie_s")
	if is_instance_valid(_player) and _player.has_method("corpse_lie_s"):
		lie = float(_player.call("corpse_lie_s"))
	f.life = lie
	get_parent().add_child(f)
	f.global_position = global_position


## Cannot move or act for `seconds`; whatever it was doing is lost.
func stun(seconds: float) -> void:
	interrupt()
	_leap_left = 0.0
	statuses["stunned"] = {"stacks": 1, "t": maxf(seconds, float((statuses.get("stunned", {}) as Dictionary).get("t", 0.0)))}


## Break off a wind-up. The attack is spent, not postponed.
func interrupt() -> void:
	if _windup >= 0.0:
		_windup = -1.0
		_attack_cd = _cooldown
	_special = ""
	_charge_left = 0.0
	telegraph = {}


## A skill that interrupts landed. Any wind-up is broken; an attack flagged interruptible (the
## one shown with a white flash, or any attack of a Read enemy) also leaves its owner staggered.
## Returns true if it staggered.
func interrupt_attack() -> bool:
	if _special == "charge" or _charge_left > 0.0:
		return false                            # only a stun or a poise break stops the charge
	var was_winding: bool = _windup >= 0.0
	var flagged: bool = bool(_def.get("interruptible", false)) or _st_any("makes_interruptible")
	interrupt()
	if was_winding and flagged:
		stagger(float(_cfg["interrupt_stagger_s"]))
		return true
	return false


## True while it is winding up an attack that an interrupting skill would punish.
func is_interruptible() -> bool:
	return _windup >= 0.0 and (bool(_def.get("interruptible", false)) or _st_any("makes_interruptible"))


## True while it is moving itself in an attack: a charge, a pounce, a leap (Headwind stops those).
func is_lunging() -> bool:
	return _charge_left > 0.0 or _leap_left > 0.0 or _special == "charge"


## Throw this enemy `metres` along `dir`. Heavier enemies go less far; Soaked ones go farther.
## It slides at the shove speed until the distance is spent or it meets something (see crushed).
func shove(dir: Vector3, metres: float) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.001 or metres <= 0.0 or body.is_dead():
		return
	if _special == "charge" or _charge_left > 0.0 or _st_any("immovable"):
		return                                  # nothing moves it once it has set itself to charge
	var mult: float = _shove_class()
	if has_status("soaked"):
		mult *= float(GameData.status("soaked").get("shove_mult", 1.0))
	for id: String in statuses.keys():
		var def: Dictionary = _sdef(id)
		if id != "soaked" and def.has("shove_mult"):
			mult *= float(def["shove_mult"])
			if bool(def.get("ends_on_shove", false)):
				statuses.erase(id)              # Stilled: the next shove goes twice as far, once
	if is_inside_tree():
		for zone: Node in get_tree().get_nodes_in_group("ground_zones"):
			if float(zone.get("shove_mult")) != 1.0 and bool(zone.call("has_point", global_position, radius)):
				mult *= float(zone.get("shove_mult"))            # standing water: everything slides farther
	_shove_dir = flat.normalized()
	_shove_left = metres * mult
	_leap_left = 0.0
	interrupt()


## Drag this enemy toward `point`: at most `metres` (heavier ones come less far), stopping `keep`
## short of it. The same slide as a shove, so it can end in a Crush.
func pull_toward(point: Vector3, metres: float, keep: float = 0.3) -> void:
	var to: Vector3 = point - global_position
	to.y = 0.0
	var go: float = minf(metres * _shove_class(), to.length() - keep)
	if go <= 0.05 or body.is_dead() or _special == "charge" or _charge_left > 0.0 or _st_any("immovable"):
		return
	_shove_dir = to.normalized()
	_shove_left = go
	_leap_left = 0.0
	interrupt()


## Moved a little by something on the ground (a lane of wind). It does not interrupt anything.
func nudge(step: Vector3) -> void:
	if body.is_dead() or _shove_left > 0.0 or _charge_left > 0.0 or _leap_left > 0.0 or _st_any("immovable"):
		return
	move_and_collide(Vector3(step.x, 0.0, step.z))


## Face directly away from `point` and stay that way for `seconds`.
func turn_away_from(point: Vector3, seconds: float) -> void:
	var away: Vector3 = global_position - point
	away.y = 0.0
	if away.length() < 0.05:
		return
	facing = away.normalized()
	_turned_t = seconds
	_apply_facing()


func is_shoved() -> bool:
	return _shove_left > 0.0


## Every status's clock and what it does each tick: damage over time in the name of whoever put it
## there, spreading to whoever stands close, nudging, dripping blood, retching.
func _tick_statuses(delta: float) -> void:
	var frozen_by: Array = []
	var frozen_all := ""
	for id: String in statuses:
		var fz: Array = _sdef(id).get("freezes", [])
		frozen_by.append_array(fz)
		if fz.has("all"):
			frozen_all = id                       # Stasis: nothing else on it runs down
	for id: String in statuses.keys():
		if not statuses.has(id):
			continue
		var s: Dictionary = statuses[id]
		if frozen_by.has(id) or _in_zone_banking(id) or (frozen_all != "" and id != frozen_all):
			continue                              # Arrested, or banked in a pall of smoke: it does not run down
		s["t"] = float(s["t"]) - delta
		if float(s["t"]) <= 0.0:
			_expire(id)
	for id: String in statuses.keys():
		if not statuses.has(id) or body.is_dead():
			continue
		_tick_status(id, delta)
	if not statuses.has("alight"):
		_burn_t = 0.0
		_spread_t = 0.0


## True if a ground zone it stands in banks this status (Smokepall: burns do not run down inside).
func _in_zone_banking(id: String) -> bool:
	if not is_inside_tree():
		return false
	for z: Node in get_tree().get_nodes_in_group("ground_zones"):
		if str(z.get("banks")) == id and bool(z.call("has_point", global_position, radius)):
			return true
	return false


func _tick_status(id: String, delta: float) -> void:
	var def: Dictionary = _sdef(id)
	var s: Dictionary = statuses[id]
	var by: Variant = s.get("by")
	var who: Node = by if (by != null and is_instance_valid(by)) else null
	var data: Dictionary = s.get("data", {})
	# spread: one stack jumps to an enemy that has stood close for long enough
	if def.has("spread_radius") and not _st_any("no_death_effects"):
		var near: Node3D = _nearest_enemy_within(float(def.get("spread_radius", 1.2)))
		s["spread"] = float(s.get("spread", 0.0)) + delta if near != null else 0.0
		if near != null and float(s["spread"]) >= float(def.get("spread_time", 1.0)):
			s["spread"] = 0.0
			near.call("add_status", id, 1, who)
	var dps: float = float(def.get("dps_per_stack", 0.0)) * float(int(s["stacks"]))
	dps += float(def.get("dps_per_metal_class", 0.0)) * float(metal_class())
	if dps > 0.0:
		s["acc"] = float(s.get("acc", 0.0)) + delta
		var every: float = float(def.get("tick_s", 0.5))
		while float(s["acc"]) >= every and statuses.has(id) and not body.is_dead():
			s["acc"] = float(s["acc"]) - every
			var dmg: float = dps * every
			if def.has("moving_mult") and (velocity.length() > 0.2 or _windup >= 0.0):
				dmg *= float(def["moving_mult"])          # Bleeding: twice as fast while it moves or swings
			if bool(def.get("times_flesh", false)):
				dmg *= flesh()
			for other: String in statuses:
				dmg *= float((_sdef(other).get("dps_mult", {}) as Dictionary).get(id, 1.0))
			dmg *= _zone_dps_mult(id)                    # Smokepall: the burning ticks harder in the smoke
			if who != null and who.has_method("deal_damage"):
				var dot: Variant = who.call("deal_damage", self, dmg, def.get("dot_tags", ["dot"]))
				# Tormented: part of every tick feeds whoever put it there
				if float(def.get("drain_frac", 0.0)) > 0.0 and dot is HitContext and who.has_method("drain_heal"):
					who.call("drain_heal", (dot as HitContext).applied * float(def["drain_frac"]), self, false)
			else:
				take_hit(dmg, false, null, def.get("dot_tags", ["dot"]))
		if id == "alight":
			_burn_t = float(s.get("acc", 0.0))
	if body.is_dead() or not statuses.has(id):
		return
	# Barbed: it works another status in every so often, in the name of whoever put it there
	var adds: Variant = def.get("adds_status")
	if adds is Dictionary:
		s["add_t"] = float(s.get("add_t", 0.0)) + delta
		if float(s["add_t"]) >= float(data.get("every", (adds as Dictionary).get("every", 1.0))):
			s["add_t"] = 0.0
			add_status(str((adds as Dictionary).get("status", "")), int((adds as Dictionary).get("stacks", 1)), who)
	# Bleeding drips a pool every so often
	if def.has("drips_pool_s") and who != null and who.has_method("spill_blood"):
		s["drip"] = float(s.get("drip", 0.0)) + delta
		if float(s["drip"]) >= float(def["drips_pool_s"]):
			s["drip"] = 0.0
			who.call("spill_blood", global_position, 1, false)
	# Dripping: nudged away from the caster and losing footing, a little every second
	var nudge_per: float = float(data.get("nudge_per_s", def.get("nudge_per_s", 0.0)))
	if nudge_per > 0.0 and who is Node3D:
		var away: Vector3 = global_position - (who as Node3D).global_position
		away.y = 0.0
		if away.length() > 0.05:
			nudge(away.normalized() * nudge_per * delta)
	var poise_per: float = float(data.get("poise_per_s", def.get("poise_per_s", 0.0)))
	if poise_per > 0.0:
		s["pacc"] = float(s.get("pacc", 0.0)) + delta
		if float(s["pacc"]) >= 1.0:
			s["pacc"] = 0.0
			take_poise(poise_per)
	# Sick: every so often it retches, loses what it was doing and stands still
	var retch_every: float = float(data.get("retch_every", def.get("retch_every", 0.0)))
	if retch_every > 0.0:
		_retch_t += delta
		if _retch_t >= retch_every:
			_retch_t = 0.0
			interrupt()
			_held_t = float(data.get("retch_s", def.get("retch_s", 0.5)))


## Burning: kept for old callers; the status engine burns every status with dps_per_stack.
func _tick_alight(delta: float) -> void:
	if statuses.has("alight"):
		_tick_status("alight", delta)


## The closest other living enemy within `reach` of this one, or null.
func _nearest_enemy_within(reach: float) -> Node3D:
	if not is_inside_tree():
		return null
	var best: Node3D = null
	var best_d: float = reach
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Node3D
		if e == null or e == self or bool(e.call("is_dead")):
			continue
		var d: float = e.global_position.distance_to(global_position) - float(e.get("radius")) - radius
		if d <= best_d:
			best_d = d
			best = e
	return best


## One physics step of a shove. The body is moved an exact distance (not by velocity, whose time
## step the engine chooses), so the budget and the ground covered always agree. Meeting anything
## solid ends the shove; if distance was still owed, that is a crush.
func _tick_shove(delta: float) -> void:
	var cfg: Dictionary = GameData.balance["shove"]
	var step: float = minf(_shove_left, float(cfg["speed"]) * delta)
	velocity = Vector3.ZERO
	var col: KinematicCollision3D = move_and_collide(_shove_dir * step)
	if col == null:
		_shove_left -= step
		return
	var left: float = _shove_left - col.get_travel().length()
	_shove_left = 0.0
	_shove_ended()
	if left >= float(cfg["min_left"]):
		var hit: Node = col.get_collider() as Node
		crushed.emit(self, left, hit)
		if is_instance_valid(shover) and shover.has_method("on_crush"):
			shover.call("on_crush", self, left, hit)


## A shove or a pull is over: whoever did it may mark that (Water's Adrift, for Siltfall).
func _shove_ended() -> void:
	if is_instance_valid(shover) and shover.has_method("on_shove_ended"):
		shover.call("on_shove_ended", self)


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
		match "melee" if _st_any("closes_in") else behaviour:       # Taunted: an archer or a drummer walks in to fight
			"ranged":
				_think_ranged(delta, dir, dist)
			"pouncer":
				_think_pouncer(delta, dir, dist)
			"support":
				_think_support(delta, dir)
			"commander":
				_think_commander(delta, dir, dist)
			_:
				_think_behaviour(delta, dir, dist)

	velocity *= pace
	if _leap_left <= 0.0 and _charge_left <= 0.0:
		move_and_slide()
	_keep_leash()
	if not winding_before and _windup >= 0.0:
		_attack_started()
	_look(delta)


## Leashed: it cannot go further than leash_m from whoever leashed it - a step beyond is undone, as a wall would
## stop it (the leash length may come from the skill, status data "leash_m").
func _keep_leash() -> void:
	for id: String in statuses:
		var s: Dictionary = statuses[id]
		var m: float = float((s.get("data", {}) as Dictionary).get("leash_m", _sdef(id).get("leash_m", 0.0)))
		var by: Variant = s.get("by")
		if m <= 0.0 or not (by is Node3D) or not is_instance_valid(by):
			continue
		var off: Vector3 = global_position - (by as Node3D).global_position
		off.y = 0.0
		if off.length() > m:
			var back: Vector3 = (by as Node3D).global_position + off.normalized() * m
			global_position = Vector3(back.x, global_position.y, back.z)


## Who it goes for: the player, unless a lure stands within its reach (a phantom, a death mask, a
## thrall, a friend wearing your face) - then that, until it breaks. An enemy with no target (a
## test's dummy) is never lured.
func _pick_target() -> void:
	if not is_inside_tree():
		return
	if not _lured and target == null:
		return
	# Taunted: whoever taunted it, and nobody else (no lure, decoy or thrall draws it)
	var forced: Node3D = _forced_target()
	if forced != null:
		if target != forced:
			interrupt()
		target = forced
		_lured = forced != _player
		return
	# Charmed: it fights for whoever charmed it - the nearest of its old friends
	if _st_any("fights_for_source"):
		var foe: Node3D = null
		for node2: Node in get_tree().get_nodes_in_group("enemies"):
			var o := node2 as Node3D
			if o == null or o == self or bool(o.call("is_dead")) or bool(o.call("_charmed")):
				continue
			if foe == null or o.global_position.distance_to(global_position) < foe.global_position.distance_to(global_position):
				foe = o
		if foe != null:
			if target != foe:
				interrupt()
			target = foe
			_lured = true
			return
	var best: Node3D = null
	var best_d := INF
	for node: Node in get_tree().get_nodes_in_group("lures"):
		var l := node as Node3D
		if l == null or l == self or bool(l.call("is_dead")):
			continue
		var d: float = l.global_position.distance_to(global_position)
		if d <= float(l.get("lure_radius")) and d < best_d:
			best = l
			best_d = d
	if best == null:
		# a friend that draws it (Masked wears your face; a Charmed one has turned on them): any status with lure_radius
		for node: Node in get_tree().get_nodes_in_group("enemies"):
			var m := node as Node3D
			if m == null or m == self:
				continue
			var draw: float = float(m.call("lure_reach"))
			var d2: float = m.global_position.distance_to(global_position)
			if draw > 0.0 and d2 <= draw and d2 < best_d:
				best = m
				best_d = d2
	if best != null:
		if target != best:
			interrupt()
		target = best
		_lured = true
	elif _lured:
		_lured = false
		target = _player if is_instance_valid(_player) else null
		interrupt()


## Whoever a forced_target status on it names (Taunted: whoever put it there), if they still stand; else null.
func _forced_target() -> Node3D:
	for id: String in statuses:
		if str(_sdef(id).get("forced_target", "")) != "source":
			continue
		var by: Variant = (statuses[id] as Dictionary).get("by")
		if by is Node3D and is_instance_valid(by) and not _gone(by as Node):
			return by as Node3D
	return null


## True if a body (an enemy, a thrall, a lure: is_dead(); the player: dead) is down or gone.
static func _gone(n: Node) -> bool:
	if not is_instance_valid(n):
		return true
	return bool(n.call("is_dead")) if n.has_method("is_dead") else bool(n.get("dead"))


## True while it fights for someone else (Charmed).
func _charmed() -> bool:
	return _st_any("fights_for_source")


## How far its friends are drawn to it (Masked, Charmed: the largest lure_radius on it), 0 if none.
func lure_reach() -> float:
	var r := 0.0
	for id: String in statuses:
		r = maxf(r, float(_sdef(id).get("lure_radius", 0.0)))
	return r


## Spared and Dying: it kneels and does nothing.
func _kneeling() -> bool:
	for id: String in statuses:
		var below: float = float(_sdef(id).get("kneels_below", 0.0))
		if below > 0.0 and body.total() < body.total_max() * below:
			return true
	return false


## Terrified (from whoever frightened it) or Dreading (out of the zone): it walks away and does not
## attack. Returns true while it is running.
func _flee(_delta: float) -> bool:
	for id: String in statuses:
		# Exiled: it will not come within keeps_away of whoever cast it out (outside it, it fights - and shoots - as it will)
		var keep: float = float(_sdef(id).get("keeps_away", 0.0))
		var kby: Variant = (statuses[id] as Dictionary).get("by")
		if keep > 0.0 and kby is Node3D and is_instance_valid(kby):
			var off: Vector3 = global_position - (kby as Node3D).global_position
			off.y = 0.0
			if off.length() < keep:
				_windup = -1.0
				facing = (off if off.length() > 0.05 else -facing).normalized()
				velocity = facing * speed
				return true
		var how: String = str(_sdef(id).get("flees", ""))
		if how == "":
			continue
		var from := Vector3.INF
		var s: Dictionary = statuses[id]
		if how == "source" and s.get("by") is Node3D and is_instance_valid(s.get("by")):
			from = (s["by"] as Node3D).global_position
		elif how == "zone":
			var at: Variant = (s.get("data", {}) as Dictionary).get("from")
			if at is Vector3:
				from = at
			elif s.get("by") is Node3D and is_instance_valid(s.get("by")):
				from = (s["by"] as Node3D).global_position
		if from == Vector3.INF:
			continue
		var away: Vector3 = global_position - from
		away.y = 0.0
		if away.length() < 0.05:
			away = -facing
		_windup = -1.0
		facing = away.normalized()
		velocity = away.normalized() * speed
		return true
	return false


## Commanded: it walks to the point it was given and stands there, starting nothing.
func _walk_to_goal(_delta: float) -> bool:
	for id: String in statuses:
		if not bool(_sdef(id).get("goes_to_goal", false)):
			continue
		var goal: Variant = status_data(id).get("goal")
		if not (goal is Vector3):
			return true
		var to: Vector3 = (goal as Vector3) - global_position
		to.y = 0.0
		_windup = -1.0
		if to.length() > 0.4:
			facing = to.normalized()
			velocity = to.normalized() * speed
		return true
	return false


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


## The direction to walk in order to reach the player: along its path on the level's navigation
## mesh (round walls, blocks, props and corners, through doorways), stepping round standing stone,
## which is not in the mesh. Where there is no mesh yet (or none at all: a unit test's little
## world), the old steering: round stone, through the passage's doorway (Route), else `straight`.
## Zero when the player cannot be reached and it already stands as near as it can get.
func _route_dir(straight: Vector3, delta: float = 0.0) -> Vector3:
	var nav: LevelNav = _level_nav()
	if nav == null:
		return _fallback_dir(straight)
	var way: Vector3 = _chase.steer(nav, global_position, target.global_position, radius, delta)
	return _round_stone(nav, _chase.next_point(target.global_position), way)


## The level's navigation where it stands, or null.
func _level_nav() -> LevelNav:
	if not is_inside_tree():
		return null
	if _nav == null or not is_instance_valid(_nav) or not _nav.covers(global_position):
		_nav = LevelNav.find(get_tree(), global_position)
	return _nav


## Walking `way` toward `next` (a corner of its path): if standing stone is in the way, head for
## the end of it that can be walked to instead. Stone is not baked into the mesh - it stands 12 s
## and Stone.way_round() already knows its one corner; this only checks the end is walkable.
func _round_stone(nav: LevelNav, next: Vector3, way: Vector3) -> Vector3:
	for node: Node in get_tree().get_nodes_in_group("stones"):
		var s := node as Stone
		if s == null:
			continue
		var detour: Variant = s.way_round(global_position, next, radius)
		if detour == null:
			continue
		var spot: Vector3 = detour as Vector3
		if not nav.standable(spot, radius, radius):
			# that end is against a wall: try the other one
			var across: Vector3 = s.global_transform.basis.x
			across.y = 0.0
			across = across.normalized()
			spot -= across * 2.0 * across.dot(spot - s.global_position)
			if not nav.standable(spot, radius, radius):
				continue                         # it closes the way: walk on and press against it
		var side: Vector3 = spot - global_position
		side.y = 0.0
		if side.length() > 0.05:
			return side.normalized()
	return way


## The old steering, for where there is no navigation mesh: round standing stone, else through
## the passage's doorway (see Route), else `straight`.
func _fallback_dir(straight: Vector3) -> Vector3:
	if is_inside_tree():
		for s: Node in get_tree().get_nodes_in_group("stones"):
			var detour: Variant = s.call("way_round", global_position, target.global_position, radius)
			if detour != null:
				var side: Vector3 = (detour as Vector3) - global_position
				side.y = 0.0
				if side.length() > 0.05:
					return side.normalized()
	return _door_dir(straight)


## The way through the passage's dividing walls (see Route), or `straight` where there are none.
func _door_dir(straight: Vector3) -> Vector3:
	if not is_inside_tree():
		return straight
	if _router == null or not is_instance_valid(_router):
		_router = get_tree().get_first_node_in_group("router")
	if _router == null:
		return straight
	var next: Vector3 = _router.call("route", global_position, target.global_position, radius)
	var way: Vector3 = next - global_position
	way.y = 0.0
	return way.normalized() if way.length() > 0.05 else straight


## Turn toward `want` at the turn rate. Nothing turns while it is committed to an attack.
func _turn_toward(want: Vector3, delta: float) -> void:
	if want.length() < 0.001 or _turned_t > 0.0:
		return
	var from: float = atan2(facing.x, facing.z)
	var goal: float = atan2(want.x, want.z)
	var step: float = clampf(wrapf(goal - from, -PI, PI), -_turn_rate * delta, _turn_rate * delta)
	facing = Vector3(sin(from + step), 0.0, cos(from + step))


func _think_melee(delta: float, dir: Vector3, dist: float) -> void:
	if _windup >= 0.0:
		# committed: it does not track you, so stepping round it or out of the circle works
		_windup -= delta
		_update_melee_telegraph()
		if _windup < 0.0:
			_land_melee(dist)
		return
	_turn_toward(_walk_dir, delta)
	var strike_dist: float = 1.5 + radius
	if target == _player and is_instance_valid(_player) and _player.has_method("unseen_from") and bool(_player.call("unseen_from", global_position)):
		return                                  # it has lost you: it holds where it is
	if dist > strike_dist:
		if _has_slot():
			velocity = _walk_dir * speed
		else:
			# no room at the front: hold a few metres out and drift round the ring
			var wait: float = float(_cfg["ring_wait_distance"])
			var side := Vector3(-dir.z, 0.0, dir.x) * _circle_sign
			if dist > wait + 0.6:
				velocity = _walk_dir * speed
			elif dist < wait - 0.6:
				velocity = -dir * speed * 0.6
			else:
				velocity = side * speed * 0.35
	elif _has_slot() and _attack_cd <= 0.0 and not _no_attack():
		_windup = _windup_len()
		_update_melee_telegraph()


# --- support: the War Drummer -------------------------------------------------------------------

## Living allies of this enemy within `reach`, not counting itself.
func _allies_within(reach: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	if not is_inside_tree():
		return out
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Node3D
		if e == null or e == self or bool(e.call("is_dead")):
			continue
		if e.global_position.distance_to(global_position) <= reach:
			out.append(e)
	return out


## Never attacks. Everything near it is quicker and steadier while it lives; every so often it
## raises its sticks (interruptible) and rouses one fighter, whose next blow is heavy. It keeps
## the line between itself and the player; with no line left it stands where it is.
func _think_support(delta: float, dir: Vector3) -> void:
	var reach: float = float(_def.get("aura_radius", 6.0))
	var near: Array[Node3D] = _allies_within(reach)
	_pulse_t -= delta
	if _st_any("no_call"):
		telegraph = {}
		return                                  # Shut or Muted: no drum
	if _pulse_t <= 0.0:
		_pulse_t = 0.4
		for ally: Node3D in near:
			ally.call("add_status", str(_def.get("aura_status", "drummed")))
	_turn_toward(dir, delta)
	if _windup >= 0.0:
		_windup -= delta
		telegraph = {"kind": "swing", "interruptible": true}
		if _windup < 0.0:
			_drum_roll(near)
		return
	telegraph = {}
	var fighters: Array[Node3D] = []
	for ally: Node3D in _allies_within(14.0):
		if str(ally.get("behaviour")) == "melee" or str(ally.get("behaviour")) == "commander":
			fighters.append(ally)
	if _attack_cd <= 0.0 and not fighters.is_empty() and not _no_attack():
		_windup = _windup_len()
		return
	if fighters.is_empty():
		return
	var centre := Vector3.ZERO
	for ally: Node3D in fighters:
		centre += ally.global_position
	centre /= float(fighters.size())
	var back: Vector3 = centre - target.global_position
	back.y = 0.0
	var goal: Vector3 = centre + (back.normalized() if back.length() > 0.1 else -dir) * float(_def.get("stand_behind", 6.0))
	var to: Vector3 = goal - global_position
	to.y = 0.0
	if to.length() <= 1.0:
		return
	var nav: LevelNav = _level_nav()
	if nav != null:
		velocity = _round_stone(nav, _errand.next_point(goal), _errand.steer(nav, global_position, goal, radius, delta)) * speed
	elif _clear(global_position + Vector3.UP, global_position + Vector3.UP + to.normalized() * (radius + 0.8)):
		velocity = to.normalized() * speed


## The roll lands: the fighter nearest the player, of those in the ring, is roused.
func _drum_roll(near: Array[Node3D]) -> void:
	telegraph = {}
	_attack_cd = _cooldown
	_strike_t = 0.3
	var pick: Node3D = null
	for ally: Node3D in near:
		if str(ally.get("behaviour")) != "melee" or bool(ally.get("heavy")):
			continue
		if pick == null or ally.global_position.distance_to(target.global_position) < pick.global_position.distance_to(target.global_position):
			pick = ally
	if pick != null:
		pick.call("add_status", str(_def.get("roll_status", "roused")))
		if is_inside_tree():
			FloatText.spawn(get_parent(), pick.global_position + Vector3.UP * 0.6, "ROUSED", Color(1, 1, 1))


# --- the Wall Commander ---------------------------------------------------------------------

## Phase 1 (above phase2_at of its health): a duel - it blocks from the front and answers a blocked
## hit (take_hit). Phase 2: it calls its reinforcements once, and adds a wide sweep. Phase 3 (under
## phase3_at): it charges along a line it marks first; ending that charge in a wall or in standing
## stone leaves it dazed.
func _think_commander(delta: float, dir: Vector3, dist: float) -> void:
	var frac: float = body.total() / body.total_max()
	if phase < 2 and frac <= float(_def.get("phase2_at", 0.6)) and not _st_any("no_call"):
		phase = 2
		reinforcements.emit(self, _def.get("calls", []))
		if is_inside_tree():
			FloatText.spawn(get_parent(), global_position + Vector3.UP * (height + 0.4), "TO ME!", Color(1.0, 0.85, 0.4))
	if phase < 3 and frac <= float(_def.get("phase3_at", 0.3)):
		phase = 3
		_special_cd["charge"] = 0.0
	if _charge_left > 0.0:
		_tick_charge(delta)
		return
	if _special != "":
		_windup -= delta
		var cfg: Dictionary = _def[_special]
		var filled: float = 1.0 - maxf(0.0, _windup) / maxf(0.001, float(cfg["windup"]))
		if _special == "sweep":
			telegraph = {"kind": "cone", "radius": float(cfg["radius"]), "arc_deg": float(cfg["arc_deg"]), "dir": facing, "frac": filled}
			if _windup < 0.0:
				_land_sweep(dist)
		else:
			telegraph = {"kind": "lane", "to": global_position + _charge_dir * float(cfg["length"]), "width": float(cfg["width"]), "frac": filled}
			if _windup < 0.0:
				_special = ""
				telegraph = {}
				_charge_left = float(cfg["length"])
				_charge_hit = false
		return
	if _windup < 0.0 and not _no_attack():
		var charge: Dictionary = _def.get("charge", {})
		var sweep: Dictionary = _def.get("sweep", {})
		if phase >= 3 and not charge.is_empty() and float(_special_cd["charge"]) <= 0.0 and dist >= float(charge["min_dist"]) and _sees_target():
			_release_slot()
			_special = "charge"
			_windup = float(charge["windup"])
			_special_cd["charge"] = float(charge["cooldown"])
			_charge_dir = dir
			facing = dir
			return
		if phase >= 2 and not sweep.is_empty() and float(_special_cd["sweep"]) <= 0.0 and dist <= float(sweep["within"]):
			_special = "sweep"
			_windup = float(sweep["windup"])
			_special_cd["sweep"] = float(sweep["cooldown"])
			facing = dir
			return
	_think_melee(delta, dir, dist)


func _land_sweep(dist: float) -> void:
	var cfg: Dictionary = _def["sweep"]
	_special = ""
	telegraph = {}
	_attack_cd = _cooldown
	_strike_t = 0.3
	var to: Vector3 = target.global_position - global_position
	to.y = 0.0
	if dist <= float(cfg["radius"]) and (dist < 0.3 or facing.angle_to(to.normalized()) <= deg_to_rad(float(cfg["arc_deg"]) * 0.5)):
		_strike(float(cfg["damage"]), true)


## The charge itself: an exact distance along the marked line. It hits the player once if the
## line passes over them. A wall or standing stone ends it badly; running out of room does not.
func _tick_charge(delta: float) -> void:
	var cfg: Dictionary = _def["charge"]
	var step: float = minf(_charge_left, float(cfg["speed"]) * delta)
	var from: Vector3 = global_position
	velocity = Vector3.ZERO
	facing = _charge_dir
	var col: KinematicCollision3D = move_and_collide(_charge_dir * step)
	_charge_left -= step
	if not _charge_hit and is_instance_valid(target) and not bool(target.get("dead")):
		var a := Vector2(from.x, from.z)
		var b := Vector2(global_position.x, global_position.z)
		var p := Vector2(target.global_position.x, target.global_position.z)
		if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= float(cfg["width"]) * 0.5 + 0.4:
			_charge_hit = true
			_strike(float(cfg["damage"]), true)
	if col != null:
		_charge_left = 0.0
		if col.get_collider() is StaticBody3D:
			# it ran into the wall, or into stone someone put there
			stun(float(cfg["crash_stun_s"]))
			add_status(str(cfg.get("crash_status", "dazed")))
			if is_inside_tree():
				FloatText.spawn(get_parent(), global_position + Vector3.UP * (height + 0.4), "CRASH", Color(1, 0.95, 0.6))
			return
	if _charge_left <= 0.0:
		_stuck_t = float(cfg.get("stuck_s", 1.0))
		_attack_cd = _cooldown


func _update_melee_telegraph() -> void:
	if _windup < 0.0:
		telegraph = {}
	elif str(_def.get("attack_shape", "single")) == "circle":
		telegraph = {"kind": "circle", "radius": float(_def.get("attack_radius", 3.0)), "frac": 1.0 - _windup / maxf(0.001, _windup_time),
			"interruptible": bool(_def.get("interruptible", false))}
	else:
		telegraph = {"kind": "swing", "interruptible": bool(_def.get("interruptible", false))}


## The wind-up is over: does the blow find anyone?
func _land_melee(dist: float) -> void:
	telegraph = {}
	var hit := false
	if str(_def.get("attack_shape", "single")) == "circle":
		hit = dist <= float(_def.get("attack_radius", 3.0))
	else:
		# a swing only reaches what is in front of it - get behind and it finds nothing; blinded, only close in front
		var reach: float = _reach * _st_mult("reach_mult")
		var blind: Dictionary = _blinded()
		if not blind.is_empty():
			reach = minf(reach, float(blind.get("melee_reach", 1.5)))
		hit = dist <= reach + radius and is_in_front(target.global_position) and _sees_target()      # not through a wall or stone
	if hit:
		# a drum roll made this one count: the blow is heavy, whoever throws it
		_strike(damage, heavy or has_status("roused"))
		if float(_def.get("attack_shove", 0.0)) > 0.0 and target.has_method("shove"):
			target.call("shove", facing, float(_def["attack_shove"]))
		clear_status("roused")
	elif float(_def.get("stuck_after_miss", 0.0)) > 0.0:
		_stuck_t = float(_def["stuck_after_miss"])
	_attack_cd = _cooldown
	_strike_t = 0.22


func _think_ranged(delta: float, dir: Vector3, dist: float) -> void:
	if _windup >= 0.0 and _no_attack():
		_windup = -1.0                          # it cannot see to aim any more: the shot is dropped
		telegraph = {}
	if _windup >= 0.0:
		_windup -= delta
		var lock_at: float = float(_def.get("aim_lock", 0.3))
		if not _aim_locked:
			# it leads you: where you will be if you keep going as you are
			var shot_speed: float = float(_def.get("shot_speed", 30.0))
			var lead: float = lock_at + dist / shot_speed
			var tv: Vector3 = (target as CharacterBody3D).velocity if target is CharacterBody3D else Vector3.ZERO
			tv.y = 0.0
			_aim = target.global_position + tv * lead
			var aim_dir: Vector3 = _aim - global_position
			aim_dir.y = 0.0
			_turn_toward(aim_dir.normalized(), delta)
			if _windup <= lock_at:
				_aim_locked = true            # from here a late change of direction beats it
		telegraph = {"kind": "line", "to": _aim, "locked": _aim_locked, "frac": 1.0 - maxf(0.0, _windup) / maxf(0.001, _windup_time)}
		if _windup < 0.0:
			_loose()
		return
	telegraph = {}
	_turn_toward(dir, delta)
	var sees: bool = _sees_target()
	var cornered := false
	if dist < float(_def.get("back_off_within", 4.0)):
		# helpless up close: it only backs away - round the wall behind it if there is one
		var back: Vector3 = _retreat_dir(dir)
		if back != Vector3.ZERO:
			velocity = back * speed
			return
		cornered = true                         # nowhere left to go: it shoots where it stands
	if cornered:
		pass
	elif not sees:
		velocity = _seek_line(delta) * speed    # something in the way: find somewhere to shoot from
	elif dist > float(_def.get("keep_range_max", 12.0)):
		_vantage = null
		velocity = _walk_dir * speed            # too far: come closer
	elif dist < float(_def.get("keep_range_min", 9.0)):
		_vantage = null
		velocity = _retreat_dir(dir) * speed * 0.5
	else:
		_vantage = null
	if _attack_cd <= 0.0 and dist <= float(_def.get("shot_range", 16.0)) and sees and not _no_attack():
		_windup = _windup_len()
		_aim_locked = false
		_aim = target.global_position


func _loose() -> void:
	telegraph = {}
	_attack_cd = _cooldown
	_strike_t = 0.22
	var shot_dir: Vector3 = _aim - global_position
	shot_dir.y = 0.0
	if shot_dir.length() < 0.1 or not is_inside_tree():
		return
	var shot: Node3D = ShotScript.new()
	shot.set("dir", shot_dir.normalized())
	shot.set("speed", float(_def.get("shot_speed", 30.0)))
	shot.set("left", float(_def.get("shot_range", 16.0)))
	shot.set("damage", _blow(damage))
	shot.set("heavy", heavy and not _st_any("no_poise_damage"))
	shot.set("hit_radius", float(_def.get("shot_radius", 0.7)))
	shot.set("target", target)
	shot.set("shooter", self)
	shot.position = get_parent().to_local(global_position + Vector3.UP * 1.1 + shot_dir.normalized() * 0.6) if get_parent() is Node3D else global_position
	get_parent().add_child(shot)


## Nothing solid on the straight line between two points (walls, blocks, stone - not bodies).
func _clear(from: Vector3, to: Vector3) -> bool:
	if not is_inside_tree():
		return true
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## True if there is ground to stand on at `spot`.
func _has_floor(spot: Vector3) -> bool:
	if not is_inside_tree():
		return true
	var q := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 0.5, spot + Vector3.DOWN * 1.5, 1)
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Which way to back off from the player: straight back if that is open, otherwise the nearest
## turn that is, keeping to the side it turned last time so it does not dither. Zero if it is
## boxed in. `dir` points at the player.
func _retreat_dir(dir: Vector3) -> Vector3:
	var chest: Vector3 = global_position + Vector3.UP
	for turn: float in [0.0, 45.0, -45.0, 90.0, -90.0, 125.0, -125.0]:
		var way: Vector3 = (-dir).rotated(Vector3.UP, deg_to_rad(turn * _retreat_side))
		var ahead: Vector3 = global_position + way * (radius + 1.6)
		if _clear(chest, ahead + Vector3.UP) and _has_floor(ahead):
			if turn != 0.0:
				_retreat_side *= signf(turn)
			return way
	return Vector3.ZERO


## The way to walk when the player is out of sight: to the nearest spot it can get to and see
## them from (by path where the level has a navigation mesh, so round a corner if need be);
## if there is none within reach it simply closes in along its path. Without a mesh: through a
## doorway if they are in another chamber, otherwise only to spots it can walk straight to.
func _seek_line(delta: float) -> Vector3:
	_vantage_t -= delta
	var nav: LevelNav = _level_nav()
	if nav == null and _router != null and is_instance_valid(_router):
		var next: Vector3 = _router.call("route", global_position, target.global_position, radius)
		if Vector2(next.x - target.global_position.x, next.z - target.global_position.z).length() > 0.5:
			_vantage = null
			return _walk_dir                     # a dividing wall: the doorway comes first
	var reached: bool = _vantage != null and Vector2((_vantage as Vector3).x - global_position.x, (_vantage as Vector3).z - global_position.z).length() < 0.3
	if _vantage == null or reached or _vantage_t <= 0.0:
		_vantage = _find_vantage()
		_vantage_t = 1.0
		_errand.reset()
	if _vantage == null:
		return _walk_dir
	if nav != null:
		var way: Vector3 = _errand.steer(nav, global_position, _vantage as Vector3, radius, delta)
		return _round_stone(nav, _errand.next_point(_vantage as Vector3), way)
	var to: Vector3 = (_vantage as Vector3) - global_position
	to.y = 0.0
	return to.normalized() if to.length() > 0.05 else Vector3.ZERO


## Looks round itself for somewhere to shoot from: a spot with ground under it and a clear line to
## the player, not too close to them, that it can get to - by path on the navigation mesh (at most
## vantage_max_path metres of walking), or without one only in a straight line. The nearest walk
## wins, with a preference for its usual shooting distance. Null if there is none within 8 m.
func _find_vantage() -> Variant:
	var chest: Vector3 = global_position + Vector3.UP
	var mark: Vector3 = target.global_position + Vector3.UP
	var want: float = (float(_def.get("keep_range_min", 9.0)) + float(_def.get("keep_range_max", 12.0))) * 0.5
	var too_close: float = float(_def.get("back_off_within", 4.0)) + 1.0
	var nav: LevelNav = _level_nav()
	var max_walk: float = GameData.num("navigation", "vantage_max_path")
	var best: Variant = null
	var best_cost: float = INF
	for ring: float in [2.0, 4.0, 6.0, 8.0]:
		for k: int in 12:
			var way := Vector3(cos(TAU * float(k) / 12.0), 0.0, sin(TAU * float(k) / 12.0))
			var spot: Vector3 = global_position + way * ring
			var from_player: float = Vector2(spot.x - target.global_position.x, spot.z - target.global_position.z).length()
			if from_player < too_close:
				continue
			var cost: float = ring + absf(from_player - want) * 0.4
			if cost >= best_cost:
				continue
			if nav != null:
				if not nav.standable(spot, radius):
					continue                       # inside a wall or a block
				spot = nav.closest(spot, radius)
				if not _clear(spot + Vector3.UP, mark):
					continue
				var route: PackedVector3Array = nav.path(global_position, spot, radius)
				if route.is_empty() or NavPath.flat(route[route.size() - 1], spot) > 0.3:
					continue                       # it cannot get there
				var walk: float = LevelNav.length_of(route)
				if walk > max_walk:
					continue
				cost = walk + absf(from_player - want) * 0.4
				if cost >= best_cost:
					continue
			else:
				# room for its body on the way, not just a hair's width
				if not _clear(chest, spot + Vector3.UP + way * (radius + 0.2)) or not _has_floor(spot):
					continue
				if not _clear(spot + Vector3.UP, mark):
					continue
			best = spot
			best_cost = cost
	return best


## Nothing solid between it and the player; not blinded past its sight; not looking into or through
## a zone that blocks sight (a pall, smoke); and the player not unseen from here.
func _sees_target() -> bool:
	if not is_inside_tree():
		return true
	var blind: Dictionary = _blinded()
	if not blind.is_empty() and global_position.distance_to(target.global_position) > float(blind.get("sight", 2.0)):
		return false
	if target == _player and _player.has_method("unseen_from") and bool(_player.call("unseen_from", global_position)):
		return false
	for z: Node in get_tree().get_nodes_in_group("ground_zones"):
		if (bool(z.get("blocks_sight")) or bool(z.get("hides"))) and bool(z.call("crosses", global_position, target.global_position)):
			# Lit bodies show through a hiding zone
			if bool(z.get("hides")) and target.has_method("has_status") and bool(target.call("has_status", "lit")):
				continue
			return false
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, target.global_position + Vector3.UP, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _think_pouncer(delta: float, dir: Vector3, dist: float) -> void:
	if _leap_left > 0.0:
		_tick_leap(delta)
		return
	if _windup >= 0.0:
		_windup -= delta                       # crouched, eyes lit: the moment to hit it
		telegraph = {"kind": "swing", "interruptible": true}
		if _windup < 0.0:
			telegraph = {}
			_leap_left = float(_def.get("pounce_range", 8.0))
			_leap_hit = false
		return
	telegraph = {}
	_turn_toward(dir, delta)
	# circle at a distance, doing nothing
	var want: float = float(_def.get("circle_distance", 7.0))
	var side := Vector3(-dir.z, 0.0, dir.x) * _circle_sign
	if dist > want + 1.0:
		velocity = _walk_dir * speed
	elif dist < want - 1.0:
		velocity = -dir * speed * 0.6
	else:
		velocity = side * speed * 0.45

	# It waits for you to run from the pack. Alone, it has nothing to wait for and simply comes.
	var pack: Vector3 = _pack_centre()
	var alone: bool = pack == Vector3.INF
	if alone:
		_retreat_t += delta
	else:
		var tv: Vector3 = (target as CharacterBody3D).velocity if target is CharacterBody3D else Vector3.ZERO
		tv.y = 0.0
		var away: Vector3 = target.global_position - pack
		away.y = 0.0
		var fleeing: bool = away.length() > 0.5 and tv.dot(away.normalized()) >= float(_def.get("retreat_speed", 2.0))
		_retreat_t = _retreat_t + delta if fleeing else 0.0
	if _retreat_t >= float(_def.get("pounce_after_retreat_s", 1.5)) and _attack_cd <= 0.0 and dist <= float(_def.get("pounce_range", 8.0)) + 1.0 and not _no_attack():
		_retreat_t = 0.0
		_windup = _windup_len()
		velocity = Vector3.ZERO
		_aim = dir                              # it leaps where you were when it crouched
		facing = dir


## The middle of the enemies that are not pouncers, or Vector3.INF if there are none.
func _pack_centre() -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if node != self and str(node.get("behaviour")) != "pouncer":
			sum += (node as Node3D).global_position
			n += 1
	return sum / float(n) if n > 0 else Vector3.INF


func _tick_leap(delta: float) -> void:
	var step: float = minf(_leap_left, float(_def.get("pounce_speed", 20.0)) * delta)
	var from: Vector3 = global_position
	var col: KinematicCollision3D = move_and_collide(_aim * step)
	_leap_left -= step
	if col != null:
		_leap_left = 0.0
	if not _leap_hit:
		var a := Vector2(from.x, from.z)
		var b := Vector2(global_position.x, global_position.z)
		var p := Vector2(target.global_position.x, target.global_position.z)
		if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= float(_def.get("pounce_hit_radius", 1.3)):
			_leap_hit = true
			_leap_left = 0.0
			_strike(damage, heavy)
	if _leap_left <= 0.0:
		_attack_cd = _cooldown
		if not _leap_hit:
			_stuck_t = float(_def.get("stuck_after_miss", 1.0))


# --- looks ------------------------------------------------------------------------------------

func _apply_facing() -> void:
	if _rig != null and is_instance_valid(_rig):
		_rig.rotation.y = atan2(-facing.x, -facing.z)


func _look(delta: float) -> void:
	if _rig == null:
		return                                      # the body has been handed to the world to lie
	_strike_t -= delta
	_apply_facing()
	var winding: bool = _windup >= 0.0
	if winding != _shown_windup:
		_shown_windup = winding
		_rig.set_windup(winding)
	var down: bool = _st_any("cannot_act") or _kneeling()
	if down != _shown_down:
		_shown_down = down
		if _rig.has_method("set_staggered"):
			_rig.set_staggered(down)                # slumped, head down: the moment for a bare strike
	if highlight != _shown_highlight:
		_shown_highlight = highlight
		_rig.set_highlight(highlight)
	_rig.animate(delta, velocity.length(), _strike_t > 0.0)


func _refresh_label() -> void:
	_label.text = "%d" % int(ceil(body.total()))


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
	move_and_slide()
	_look(delta)


## Home again after walking back: sleep (a beast may do something else).
func _arrived_home() -> void:
	asleep = true


## What it does in a fight, by behaviour: the base kinds are handled in _physics_process; anything
## else fights as melee here. Beast overrides this for the beasts' own behaviours.
func _think_behaviour(delta: float, dir: Vector3, dist: float) -> void:
	_think_melee(delta, dir, dist)
