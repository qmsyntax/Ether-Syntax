class_name EnemyCommanderBrain
extends EnemyBrain
## The commander brain (the Wall Commander): a melee duel that changes with its health - phase 2 calls
## its reinforcements and adds a sweep, phase 3 charges along a marked line. The charge itself
## (`_tick_charge`) is shared with the charging beasts, which reach it through the node.

const FloatText := preload("res://scripts/float_text.gd")



## Phase 1 (above phase2_at of its health): a duel - it blocks from the front and answers a blocked
## hit (take_hit). Phase 2: it calls its reinforcements once, and adds a wide sweep. Phase 3 (under
## phase3_at): it charges along a line it marks first; ending that charge in a wall or in standing
## stone leaves it dazed.
func think(delta: float, dir: Vector3, dist: float) -> void:
	var frac: float = enemy.body.total() / enemy.body.total_max()
	if enemy.phase < 2 and frac <= float(enemy._def.get("phase2_at", 0.6)) and not enemy.status_part._st_any("no_call"):
		enemy.phase = 2
		enemy.reinforcements.emit(enemy, enemy._def.get("calls", []))
		if enemy.is_inside_tree():
			FloatText.spawn(enemy.get_parent(), enemy.global_position + Vector3.UP * (enemy.height + 0.4), "TO ME!", Color(1.0, 0.85, 0.4))
	if enemy.phase < 3 and frac <= float(enemy._def.get("phase3_at", 0.3)):
		enemy.phase = 3
		enemy._special_cd["charge"] = 0.0
	if enemy._charge_left > 0.0:
		_tick_charge(delta)
		return
	if enemy._special != "":
		enemy._windup -= delta
		var cfg: Dictionary = enemy._def[enemy._special]
		var filled: float = 1.0 - maxf(0.0, enemy._windup) / maxf(0.001, float(cfg["windup"]))
		if enemy._special == "sweep":
			enemy.telegraph = {"kind": "cone", "radius": float(cfg["radius"]), "arc_deg": float(cfg["arc_deg"]), "dir": enemy.facing, "frac": filled}
			if enemy._windup < 0.0:
				_land_sweep(dist)
		else:
			enemy.telegraph = {"kind": "lane", "to": enemy.global_position + enemy._charge_dir * float(cfg["length"]), "width": float(cfg["width"]), "frac": filled}
			if enemy._windup < 0.0:
				enemy._special = ""
				enemy.telegraph = {}
				enemy._charge_left = float(cfg["length"])
				enemy._charge_hit = false
		return
	if enemy._windup < 0.0 and not enemy._no_attack():
		var charge: Dictionary = enemy._def.get("charge", {})
		var sweep: Dictionary = enemy._def.get("sweep", {})
		if enemy.phase >= 3 and not charge.is_empty() and float(enemy._special_cd["charge"]) <= 0.0 and dist >= float(charge["min_dist"]) and enemy.motion_part._sees_target():
			enemy._release_slot()
			enemy._special = "charge"
			enemy._windup = float(charge["windup"])
			enemy._special_cd["charge"] = float(charge["cooldown"])
			enemy._charge_dir = dir
			enemy.facing = dir
			return
		if enemy.phase >= 2 and not sweep.is_empty() and float(enemy._special_cd["sweep"]) <= 0.0 and dist <= float(sweep["within"]):
			enemy._special = "sweep"
			enemy._windup = float(sweep["windup"])
			enemy._special_cd["sweep"] = float(sweep["cooldown"])
			enemy.facing = dir
			return
	enemy.melee_brain.think(delta, dir, dist)


func _land_sweep(dist: float) -> void:
	var cfg: Dictionary = enemy._def["sweep"]
	enemy._special = ""
	enemy.telegraph = {}
	enemy._attack_cd = enemy._cooldown
	enemy._strike_t = 0.3
	var to: Vector3 = enemy.target.global_position - enemy.global_position
	to.y = 0.0
	if dist <= float(cfg["radius"]) and (dist < 0.3 or enemy.facing.angle_to(to.normalized()) <= deg_to_rad(float(cfg["arc_deg"]) * 0.5)):
		enemy._strike(float(cfg["damage"]), true)


## The charge itself: an exact distance along the marked line. It hits the player once if the
## line passes over them. A wall or standing stone ends it badly; running out of room does not.
func _tick_charge(delta: float) -> void:
	var cfg: Dictionary = enemy._def["charge"]
	var step: float = minf(enemy._charge_left, float(cfg["speed"]) * delta)
	var from: Vector3 = enemy.global_position
	enemy.velocity = Vector3.ZERO
	enemy.facing = enemy._charge_dir
	var col: KinematicCollision3D = enemy.move_and_collide(enemy._charge_dir * step)
	enemy._charge_left -= step
	if not enemy._charge_hit and is_instance_valid(enemy.target) and not bool(enemy.target.get("dead")):
		var a := Vector2(from.x, from.z)
		var b := Vector2(enemy.global_position.x, enemy.global_position.z)
		var p := Vector2(enemy.target.global_position.x, enemy.target.global_position.z)
		if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= float(cfg["width"]) * 0.5 + 0.4:
			enemy._charge_hit = true
			enemy._strike(float(cfg["damage"]), true)
	if col != null:
		enemy._charge_left = 0.0
		if col.get_collider() is StaticBody3D:
			# it ran into the wall, or into stone someone put there
			enemy.hits_part.stun(float(cfg["crash_stun_s"]))
			enemy.status_part.add_status(str(cfg.get("crash_status", "dazed")))
			if enemy.is_inside_tree():
				FloatText.spawn(enemy.get_parent(), enemy.global_position + Vector3.UP * (enemy.height + 0.4), "CRASH", Color(1, 0.95, 0.6))
			return
	if enemy._charge_left <= 0.0:
		enemy._stuck_t = float(cfg.get("stuck_s", 1.0))
		enemy._attack_cd = enemy._cooldown
