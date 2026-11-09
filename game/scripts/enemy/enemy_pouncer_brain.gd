class_name EnemyPouncerBrain
extends EnemyBrain
## The pouncer brain (the harrier): circle at a distance and wait for you to run from the pack, then
## crouch (interruptible) and leap where you were. Alone, it simply comes.



func think(delta: float, dir: Vector3, dist: float) -> void:
	if enemy._leap_left > 0.0:
		_tick_leap(delta)
		return
	if enemy._windup >= 0.0:
		enemy._windup -= delta                       # crouched, eyes lit: the moment to hit it
		enemy.telegraph = {"kind": "swing", "interruptible": true}
		if enemy._windup < 0.0:
			enemy.telegraph = {}
			enemy._leap_left = float(enemy._def.get("pounce_range", 8.0))
			enemy._leap_hit = false
		return
	enemy.telegraph = {}
	enemy.motion_part._turn_toward(dir, delta)
	# circle at a distance, doing nothing
	var want: float = float(enemy._def.get("circle_distance", 7.0))
	var side := Vector3(-dir.z, 0.0, dir.x) * enemy._circle_sign
	if dist > want + 1.0:
		enemy.velocity = enemy._walk_dir * enemy.speed
	elif dist < want - 1.0:
		enemy.velocity = -dir * enemy.speed * 0.6
	else:
		enemy.velocity = side * enemy.speed * 0.45

	# It waits for you to run from the pack. Alone, it has nothing to wait for and simply comes.
	var pack: Vector3 = _pack_centre()
	var alone: bool = pack == Vector3.INF
	if alone:
		enemy._retreat_t += delta
	else:
		var tv: Vector3 = (enemy.target as CharacterBody3D).velocity if enemy.target is CharacterBody3D else Vector3.ZERO
		tv.y = 0.0
		var away: Vector3 = enemy.target.global_position - pack
		away.y = 0.0
		var fleeing: bool = away.length() > 0.5 and tv.dot(away.normalized()) >= float(enemy._def.get("retreat_speed", 2.0))
		enemy._retreat_t = enemy._retreat_t + delta if fleeing else 0.0
	if enemy._retreat_t >= float(enemy._def.get("pounce_after_retreat_s", 1.5)) and enemy._attack_cd <= 0.0 and dist <= float(enemy._def.get("pounce_range", 8.0)) + 1.0 and not enemy._no_attack():
		enemy._retreat_t = 0.0
		enemy._windup = enemy._windup_len()
		enemy.velocity = Vector3.ZERO
		enemy._aim = dir                              # it leaps where you were when it crouched
		enemy.facing = dir


## The middle of the enemies that are not pouncers, or Vector3.INF if there are none.
func _pack_centre() -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for node: Enemy in enemy.get_tree().get_nodes_in_group("enemies"):
		if node != enemy and str(node.behaviour) != "pouncer":
			sum += (node as Node3D).global_position
			n += 1
	return sum / float(n) if n > 0 else Vector3.INF


func _tick_leap(delta: float) -> void:
	var step: float = minf(enemy._leap_left, float(enemy._def.get("pounce_speed", 20.0)) * delta)
	var from: Vector3 = enemy.global_position
	var col: KinematicCollision3D = enemy.move_and_collide(enemy._aim * step)
	enemy._leap_left -= step
	if col != null:
		enemy._leap_left = 0.0
	if not enemy._leap_hit:
		var a := Vector2(from.x, from.z)
		var b := Vector2(enemy.global_position.x, enemy.global_position.z)
		var p := Vector2(enemy.target.global_position.x, enemy.target.global_position.z)
		if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= float(enemy._def.get("pounce_hit_radius", 1.3)):
			enemy._leap_hit = true
			enemy._leap_left = 0.0
			enemy._strike(enemy.damage, enemy.heavy)
	if enemy._leap_left <= 0.0:
		enemy._attack_cd = enemy._cooldown
		if not enemy._leap_hit:
			enemy._stuck_t = float(enemy._def.get("stuck_after_miss", 1.0))
