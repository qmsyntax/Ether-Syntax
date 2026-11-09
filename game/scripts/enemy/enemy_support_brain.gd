class_name EnemySupportBrain
extends EnemyBrain
## The support brain (the War Drummer): never attacks. Its drum makes those near it quicker and
## steadier; every so often a roll (interruptible) rouses one fighter. It keeps behind the line of its
## fighters; with no fighter left it stands where it is.

const FloatText := preload("res://scripts/float_text.gd")

var _pulse_t := 0.0                  # support: until it strengthens those near it again


## Living allies of this enemy within `reach`, not counting itself.
func _allies_within(reach: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	if not enemy.is_inside_tree():
		return out
	for node: Enemy in enemy.get_tree().get_nodes_in_group("enemies"):
		var e: Enemy = node
		if e == null or e == enemy or bool(e.is_dead()):
			continue
		if e.global_position.distance_to(enemy.global_position) <= reach:
			out.append(e)
	return out


## Never attacks. Everything near it is quicker and steadier while it lives; every so often it
## raises its sticks (interruptible) and rouses one fighter, whose next blow is heavy. It keeps
## the line between itself and the player; with no line left it stands where it is.
func think(delta: float, dir: Vector3, _dist: float) -> void:
	var reach: float = float(GameData.opt(enemy._def, "enemy", "aura_radius"))
	var near: Array[Node3D] = _allies_within(reach)
	_pulse_t -= delta
	if enemy.status_part._st_any("no_call"):
		enemy.telegraph = {}
		return                                  # Shut or Muted: no drum
	if _pulse_t <= 0.0:
		_pulse_t = 0.4
		for ally: Node3D in near:
			ally.call("add_status", str(enemy._def.get("aura_status", "drummed")))
	enemy.motion_part._turn_toward(dir, delta)
	if enemy._windup >= 0.0:
		enemy._windup -= delta
		enemy.telegraph = {"kind": "swing", "interruptible": true}
		if enemy._windup < 0.0:
			_drum_roll(near)
		return
	enemy.telegraph = {}
	var fighters: Array[Node3D] = []
	for ally: Node3D in _allies_within(14.0):
		if str(ally.get("behaviour")) == "melee" or str(ally.get("behaviour")) == "commander":
			fighters.append(ally)
	if enemy._attack_cd <= 0.0 and not fighters.is_empty() and not enemy._no_attack():
		enemy._windup = enemy._windup_len()
		return
	if fighters.is_empty():
		return
	var centre := Vector3.ZERO
	for ally: Node3D in fighters:
		centre += ally.global_position
	centre /= float(fighters.size())
	var back: Vector3 = centre - enemy.target.global_position
	back.y = 0.0
	var goal: Vector3 = centre + (back.normalized() if back.length() > 0.1 else -dir) * float(GameData.opt(enemy._def, "enemy", "stand_behind"))
	var to: Vector3 = goal - enemy.global_position
	to.y = 0.0
	if to.length() <= 1.0:
		return
	var nav: LevelNav = enemy.motion_part._level_nav()
	if nav != null:
		enemy.velocity = enemy.motion_part._round_stone(nav, enemy._errand.next_point(goal), enemy._errand.steer(nav, enemy.global_position, goal, enemy.radius, delta)) * enemy.speed
	elif enemy.motion_part._clear(enemy.global_position + Vector3.UP, enemy.global_position + Vector3.UP + to.normalized() * (enemy.radius + 0.8)):
		enemy.velocity = to.normalized() * enemy.speed


## The roll lands: the fighter nearest the player, of those in the ring, is roused.
func _drum_roll(near: Array[Node3D]) -> void:
	enemy.telegraph = {}
	enemy._attack_cd = enemy._cooldown
	enemy._strike_t = 0.3
	var pick: Node3D = null
	for ally: Node3D in near:
		if str(ally.get("behaviour")) != "melee" or bool(ally.get("heavy")):
			continue
		if pick == null or ally.global_position.distance_to(enemy.target.global_position) < pick.global_position.distance_to(enemy.target.global_position):
			pick = ally
	if pick != null:
		pick.call("add_status", str(enemy._def.get("roll_status", "roused")))
		if enemy.is_inside_tree():
			FloatText.spawn(enemy.get_parent(), pick.global_position + Vector3.UP * 0.6, "ROUSED", Color(1, 1, 1))
