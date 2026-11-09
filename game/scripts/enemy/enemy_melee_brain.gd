class_name EnemyMeleeBrain
extends EnemyBrain
## The melee brain: take one of the slots round the player, close in, wind up and strike; with no
## slot free, hold a few metres out and drift round the ring. The commander and most beasts fall back
## on it. Reached through the node's `_think_melee`.



func think(delta: float, dir: Vector3, dist: float) -> void:
	if enemy._windup >= 0.0:
		# committed: it does not track you, so stepping round it or out of the circle works
		enemy._windup -= delta
		enemy.looks_part._update_melee_telegraph()
		if enemy._windup < 0.0:
			_land_melee(dist)
		return
	enemy.motion_part._turn_toward(enemy._walk_dir, delta)
	var strike_dist: float = 1.5 + enemy.radius
	if enemy.target == enemy._player and is_instance_valid(enemy._player) and enemy._player.has_method("unseen_from") and bool(enemy._player.call("unseen_from", enemy.global_position)):
		return                                  # it has lost you: it holds where it is
	if dist > strike_dist:
		if enemy._has_slot():
			enemy.velocity = enemy._walk_dir * enemy.speed
		else:
			# no room at the front: hold a few metres out and drift round the ring
			var wait: float = float(enemy._cfg["ring_wait_distance"])
			var side := Vector3(-dir.z, 0.0, dir.x) * enemy._circle_sign
			if dist > wait + 0.6:
				enemy.velocity = enemy._walk_dir * enemy.speed
			elif dist < wait - 0.6:
				enemy.velocity = -dir * enemy.speed * 0.6
			else:
				enemy.velocity = side * enemy.speed * 0.35
	elif enemy._has_slot() and enemy._attack_cd <= 0.0 and not enemy._no_attack():
		enemy._windup = enemy._windup_len()
		enemy.looks_part._update_melee_telegraph()


## The wind-up is over: does the blow find anyone?
func _land_melee(dist: float) -> void:
	enemy.telegraph = {}
	var hit := false
	if str(enemy._def.get("attack_shape", "single")) == "circle":
		hit = dist <= float(GameData.opt(enemy._def, "enemy", "attack_radius"))
	else:
		# a swing only reaches what is in front of it - get behind and it finds nothing; blinded, only close in front
		var reach: float = enemy._reach * enemy.status_part._st_mult("reach_mult")
		var blind: Dictionary = enemy.status_part._blinded()
		if not blind.is_empty():
			reach = minf(reach, float(GameData.opt(blind, "status.blinded", "melee_reach")))
		hit = dist <= reach + enemy.radius and enemy.hits_part.is_in_front(enemy.target.global_position) and enemy.motion_part._sees_target()      # not through a wall or stone
	if hit:
		# a drum roll made this one count: the blow is heavy, whoever throws it
		enemy._strike(enemy.damage, enemy.heavy or enemy.status_part.has_status("roused"))
		if float(GameData.opt(enemy._def, "enemy", "attack_shove")) > 0.0 and enemy.target.has_method("shove"):
			enemy.target.call("shove", enemy.facing, float(enemy._def["attack_shove"]))
		enemy.status_part.clear_status("roused")
	elif float(GameData.opt(enemy._def, "enemy", "stuck_after_miss")) > 0.0:
		enemy._stuck_t = float(enemy._def["stuck_after_miss"])
	enemy._attack_cd = enemy._cooldown
	enemy._strike_t = 0.22
