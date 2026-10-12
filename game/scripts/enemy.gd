extends CharacterBody3D
## Realm invader. Kinds and numbers come from game/data/enemies.json; the rules they follow are
## design/05 section 6 (balance.json "combat"). Three behaviours:
##   melee   - takes one of the slots around the player, winds up, strikes; waits its turn otherwise
##   ranged  - holds its distance, aims along a line that locks just before release, backs off
##   pouncer - circles and does nothing until the player runs from the pack, then leaps
## All of them turn at a limited rate (so they have a back), have poise (so they can be
## staggered), and can be shoved, stunned and interrupted.

signal killed(enemy: Node)
## Emitted when a shove ends against something with distance still to go.
signal crushed(enemy: Node, metres_left: float, hit: Node)

const ShotScript := preload("res://scripts/enemy_shot.gd")

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
var _leap_left := 0.0                # pouncer: metres of leap still to cover
var _leap_hit := false
var _retreat_t := 0.0                # pouncer: how long the player has been running from the pack
var _circle_sign := 1.0
var _burn_t := 0.0                   # alight: time toward the next tick of burning
var _spread_t := 0.0                 # alight: how long someone has stood close enough to catch
var _walk_dir := Vector3.ZERO        # the way to walk to reach the player: through a doorway if need be
var _router: Node
var _flash := 0.0
var _base_color := Color(0.75, 0.2, 0.2)
var _label: Label3D
var _rig: ModelRig
var _strike_t := 0.0
var _shown_highlight := 0
var _shown_windup := false
var _shown_down := false


## `strength` scales health and damage - dungeon stages past the midpoint hit harder.
func setup(enemy_kind: String, player: Node3D, strength: float = 1.0) -> void:
	kind = enemy_kind
	target = player
	_cfg = GameData.balance["combat"]
	var d: Dictionary = GameData.enemy(enemy_kind)
	_def = d
	behaviour = str(d.get("behaviour", "melee"))
	height = float(d.get("height", 1.6))
	display_name = str(d.get("name", enemy_kind.capitalize()))
	radius = float(d.get("radius", 0.5))
	speed = float(d.get("speed", 3.4))
	damage = float(d.get("damage", 10.0)) * strength
	heavy = bool(d.get("heavy", false))
	aura_value = float(d.get("aura_value", 4.0))
	bounty = int(d.get("bounty", 150))
	_cooldown = float(d.get("attack_cooldown", 1.3))
	_windup_time = float(d.get("windup", 0.45))
	_reach = float(d.get("reach", 2.3))
	shove_resist = float(d.get("shove_resist", 1.0))
	poise_max = float(d.get("poise", 40.0))
	poise = poise_max
	_turn_rate = deg_to_rad(float(d.get("turn_rate_deg", _cfg["turn_rate_deg"])))
	_circle_sign = 1.0 if randf() < 0.5 else -1.0
	var c: Array = d.get("color", [0.75, 0.2, 0.2])
	_base_color = Color(float(c[0]), float(c[1]), float(c[2]))
	body = Body.new(float(d.get("hp", 240.0)) * strength)

	# The look is a procedural low-poly model (scripts/art). Gameplay size still comes from data.
	_rig = Models.enemy(enemy_kind)
	add_child(_rig)

	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = height
	col.shape = shape
	col.position.y = height * 0.5
	add_child(col)

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

## True if `point` is within the back arc: a hit from there is a rear hit.
func is_behind(point: Vector3) -> bool:
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


func take_hit(amount: float, _heavy: bool, source: Node) -> float:
	var mult := 1.0
	if has_status("staggered"):
		mult *= float(GameData.status("staggered").get("damage_taken_mult", 1.0))
	if has_status("aloft"):
		mult *= float(GameData.status("aloft").get("damage_taken_mult", 1.0))
	# hide and plate in front: it shrugs off part of anything that does not come round the side
	var armour: float = float(_def.get("front_armour", 0.0))
	if armour > 0.0 and source is Node3D and not has_status("staggered") and is_in_front((source as Node3D).global_position):
		mult *= 1.0 - armour
	var applied: float = body.apply_damage(amount * mult)
	_flash = 0.12
	if _rig != null:
		_rig.flash(0.12)
	_refresh_label()
	if body.is_dead():
		_release_slot()
		telegraph = {}
		if statuses.has("alight"):
			var heir: Node3D = _nearest_enemy_within(float(GameData.status("alight").get("spread_radius", 1.2)))
			if heir != null:
				var lit: Variant = (statuses["alight"] as Dictionary).get("by")
				heir.call("add_status", "alight", 1, lit if (lit != null and is_instance_valid(lit)) else null)
		remove_from_group("hittable")
		remove_from_group("enemies")
		killed.emit(self)
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
	poise = maxf(0.0, poise - amount)
	if poise > 0.0:
		return false
	stagger(float(GameData.status("staggered").get("lasts", 1.5)))
	return true


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

## Add `stacks` of a status (capped at its maximum) and refresh how long it lasts. `by` is who
## applied it: a status that does damage does it in their name. Returns the stacks it now has.
func add_status(id: String, stacks: int = 1, by: Node = null) -> int:
	var def: Dictionary = GameData.status(id)
	if def.is_empty() or body.is_dead():
		return 0
	if id == "aloft":
		if shove_resist < 1.0:
			take_poise(float(def.get("heavy_poise", 50.0)))    # too heavy to leave the ground: it loses its footing instead
			return 0
		interrupt()
		_leap_left = 0.0
	var now: int = mini(int(def.get("stacks", 1)), status_stacks(id) + stacks)
	var who: Node = by if by != null else ((statuses.get(id, {}) as Dictionary).get("by") as Node)
	statuses[id] = {"stacks": now, "t": float(def.get("lasts", 1.0)), "by": who}
	return now


func status_stacks(id: String) -> int:
	return int((statuses.get(id, {}) as Dictionary).get("stacks", 0))


func has_status(id: String) -> bool:
	return statuses.has(id)


func clear_status(id: String) -> void:
	statuses.erase(id)


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
	telegraph = {}


## A skill that interrupts landed. Any wind-up is broken; an attack flagged interruptible (the
## one shown with a white flash) also leaves its owner staggered. Returns true if it staggered.
func interrupt_attack() -> bool:
	var was_winding: bool = _windup >= 0.0
	var flagged: bool = bool(_def.get("interruptible", false))
	interrupt()
	if was_winding and flagged:
		stagger(float(_cfg["interrupt_stagger_s"]))
		return true
	return false


## True while it is winding up an attack that an interrupting skill would punish.
func is_interruptible() -> bool:
	return _windup >= 0.0 and bool(_def.get("interruptible", false))


## Throw this enemy `metres` along `dir`. Heavier enemies go less far; Soaked ones go farther.
## It slides at the shove speed until the distance is spent or it meets something (see crushed).
func shove(dir: Vector3, metres: float) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.001 or metres <= 0.0 or body.is_dead():
		return
	var mult: float = shove_resist
	if has_status("soaked"):
		mult *= float(GameData.status("soaked").get("shove_mult", 1.0))
	_shove_dir = flat.normalized()
	_shove_left = metres * mult
	_leap_left = 0.0
	interrupt()


func is_shoved() -> bool:
	return _shove_left > 0.0


func _tick_statuses(delta: float) -> void:
	for id: String in statuses.keys():
		var s: Dictionary = statuses[id]
		s["t"] = float(s["t"]) - delta
		if float(s["t"]) <= 0.0:
			statuses.erase(id)
	if statuses.has("alight"):
		_tick_alight(delta)
	else:
		_burn_t = 0.0
		_spread_t = 0.0


## Burning: damage every tick in the name of whoever lit it, and it catches on whoever stands close.
func _tick_alight(delta: float) -> void:
	var def: Dictionary = GameData.status("alight")
	var s: Dictionary = statuses["alight"]
	var by: Variant = s.get("by")
	var lit_by: Node = by if (by != null and is_instance_valid(by)) else null
	# spread: one stack jumps to an enemy that has stood close for long enough
	var near: Node3D = _nearest_enemy_within(float(def.get("spread_radius", 1.2)))
	_spread_t = _spread_t + delta if near != null else 0.0
	if near != null and _spread_t >= float(def.get("spread_time", 1.0)):
		_spread_t = 0.0
		near.call("add_status", "alight", 1, lit_by)
	_burn_t += delta
	var every: float = float(def.get("tick_s", 0.5))
	if _burn_t < every:
		return
	_burn_t -= every
	var dmg: float = float(def.get("dps_per_stack", 8.0)) * float(int(s["stacks"])) * every
	if lit_by != null and lit_by.has_method("deal_damage"):
		lit_by.call("deal_damage", self, dmg, ["dot", "fire", "alight"])
	else:
		take_hit(dmg, false, null)


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
	if left >= float(cfg["min_left"]):
		var hit: Node = col.get_collider() as Node
		crushed.emit(self, left, hit)
		if is_instance_valid(shover) and shover.has_method("on_crush"):
			shover.call("on_crush", self, left, hit)


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
	_attack_cd -= delta
	_flash -= delta
	_poise_idle += delta
	if poise < poise_max and _poise_idle >= float(_cfg["poise_regen_delay_s"]):
		poise = minf(poise_max, poise + float(_cfg["poise_regen_per_s"]) * delta)
	if not is_instance_valid(target):
		return

	var to: Vector3 = target.global_position - global_position
	to.y = 0.0
	var dist: float = to.length()
	var dir: Vector3 = to / maxf(dist, 0.001)
	var target_dead: bool = bool(target.get("dead"))
	velocity = Vector3.ZERO
	_walk_dir = _route_dir(dir)

	if has_status("stunned") or has_status("staggered") or has_status("aloft"):
		telegraph = {}
	elif _stuck_t > 0.0:
		_stuck_t -= delta                       # it missed, and stands there with its back open
	elif target_dead:
		telegraph = {}
	else:
		match behaviour:
			"ranged":
				_think_ranged(delta, dir, dist)
			"pouncer":
				_think_pouncer(delta, dir, dist)
			_:
				_think_melee(delta, dir, dist)

	if _leap_left <= 0.0:
		move_and_slide()
	_look(delta)


## The direction to walk in order to reach the player. Usually straight at them; in the passage,
## with a dividing wall in the way, toward the doorway first (see Route).
func _route_dir(straight: Vector3) -> Vector3:
	# standing stone in the way: head for the end of it (nothing pathfinds; this is one corner)
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
	if want.length() < 0.001:
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
	elif _has_slot() and _attack_cd <= 0.0:
		_windup = _windup_time
		_update_melee_telegraph()


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
		# a swing only reaches what is in front of it - get behind and it finds nothing
		hit = dist <= _reach + radius and is_in_front(target.global_position) and _sees_target()      # not through a wall or stone
	if hit:
		target.take_hit(damage, heavy, self)
	elif float(_def.get("stuck_after_miss", 0.0)) > 0.0:
		_stuck_t = float(_def["stuck_after_miss"])
	_attack_cd = _cooldown
	_strike_t = 0.22


func _think_ranged(delta: float, dir: Vector3, dist: float) -> void:
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
	if _attack_cd <= 0.0 and dist <= float(_def.get("shot_range", 16.0)) and sees:
		_windup = _windup_time
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
	shot.set("damage", damage)
	shot.set("heavy", heavy)
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


## The way to walk when the player is out of sight. Through a doorway if they are in another
## chamber; otherwise to the nearest spot it can walk straight to and see them from. Nothing
## here pathfinds: if no such spot is within reach it simply closes in, as before.
func _seek_line(delta: float) -> Vector3:
	_vantage_t -= delta
	if _router != null and is_instance_valid(_router):
		var next: Vector3 = _router.call("route", global_position, target.global_position, radius)
		if Vector2(next.x - target.global_position.x, next.z - target.global_position.z).length() > 0.5:
			_vantage = null
			return _walk_dir                     # a dividing wall: the doorway comes first
	var reached: bool = _vantage != null and Vector2((_vantage as Vector3).x - global_position.x, (_vantage as Vector3).z - global_position.z).length() < 0.3
	if _vantage == null or reached or _vantage_t <= 0.0:
		_vantage = _find_vantage()
		_vantage_t = 1.0
	if _vantage == null:
		return _walk_dir
	var to: Vector3 = (_vantage as Vector3) - global_position
	to.y = 0.0
	return to.normalized() if to.length() > 0.05 else Vector3.ZERO


## Looks round itself for somewhere to shoot from: a spot it can reach in a straight line, with
## ground under it and a clear line to the player, not too close to them. The nearest wins, with
## a preference for its usual shooting distance. Null if there is none within 8 m.
func _find_vantage() -> Variant:
	var chest: Vector3 = global_position + Vector3.UP
	var mark: Vector3 = target.global_position + Vector3.UP
	var want: float = (float(_def.get("keep_range_min", 9.0)) + float(_def.get("keep_range_max", 12.0))) * 0.5
	var too_close: float = float(_def.get("back_off_within", 4.0)) + 1.0
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
			# room for its body on the way, not just a hair's width
			if not _clear(chest, spot + Vector3.UP + way * (radius + 0.2)) or not _has_floor(spot):
				continue
			if not _clear(spot + Vector3.UP, mark):
				continue
			best = spot
			best_cost = cost
	return best


## Nothing solid between it and the player.
func _sees_target() -> bool:
	if not is_inside_tree():
		return true
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
	if _retreat_t >= float(_def.get("pounce_after_retreat_s", 1.5)) and _attack_cd <= 0.0 and dist <= float(_def.get("pounce_range", 8.0)) + 1.0:
		_retreat_t = 0.0
		_windup = _windup_time
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
			target.take_hit(damage, heavy, self)
	if _leap_left <= 0.0:
		_attack_cd = _cooldown
		if not _leap_hit:
			_stuck_t = float(_def.get("stuck_after_miss", 1.0))


# --- looks ------------------------------------------------------------------------------------

func _apply_facing() -> void:
	if _rig != null:
		_rig.rotation.y = atan2(-facing.x, -facing.z)


func _look(delta: float) -> void:
	_strike_t -= delta
	_apply_facing()
	var winding: bool = _windup >= 0.0
	if winding != _shown_windup:
		_shown_windup = winding
		_rig.set_windup(winding)
	var down: bool = has_status("staggered") or has_status("stunned") or has_status("aloft")
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
