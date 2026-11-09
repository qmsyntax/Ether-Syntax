class_name EnemyRangedBrain
extends EnemyBrain
## The ranged brain (the archer): hold its distance, find somewhere to shoot from when the line is
## blocked, aim along a line that leads you and locks just before release, back off when you close.

const ShotScript := preload("res://scripts/enemy_shot.gd")

var _aim_locked := false
var _vantage: Variant = null         # ranged: a spot it is walking to because it can shoot from there
var _vantage_t := 0.0                # ranged: until it looks for a better one
var _retreat_side := 1.0             # ranged: which way it turned the last time its back was to a wall


func think(delta: float, dir: Vector3, dist: float) -> void:
	if enemy._windup >= 0.0 and enemy._no_attack():
		enemy._windup = -1.0                          # it cannot see to aim any more: the shot is dropped
		enemy.telegraph = {}
	if enemy._windup >= 0.0:
		enemy._windup -= delta
		var lock_at: float = float(GameData.opt(enemy._def, "enemy", "aim_lock"))
		if not _aim_locked:
			# it leads you: where you will be if you keep going as you are
			var shot_speed: float = float(GameData.opt(enemy._def, "enemy", "shot_speed"))
			var lead: float = lock_at + dist / shot_speed
			var tv: Vector3 = (enemy.target as CharacterBody3D).velocity if enemy.target is CharacterBody3D else Vector3.ZERO
			tv.y = 0.0
			enemy._aim = enemy.target.global_position + tv * lead
			var aim_dir: Vector3 = enemy._aim - enemy.global_position
			aim_dir.y = 0.0
			enemy.motion_part._turn_toward(aim_dir.normalized(), delta)
			if enemy._windup <= lock_at:
				_aim_locked = true            # from here a late change of direction beats it
		enemy.telegraph = {"kind": "line", "to": enemy._aim, "locked": _aim_locked, "frac": 1.0 - maxf(0.0, enemy._windup) / maxf(0.001, enemy._windup_time)}
		if enemy._windup < 0.0:
			_loose()
		return
	enemy.telegraph = {}
	enemy.motion_part._turn_toward(dir, delta)
	var sees: bool = enemy.motion_part._sees_target()
	var cornered := false
	if dist < float(GameData.opt(enemy._def, "enemy", "back_off_within")):
		# helpless up close: it only backs away - round the wall behind it if there is one
		var back: Vector3 = _retreat_dir(dir)
		if back != Vector3.ZERO:
			enemy.velocity = back * enemy.speed
			return
		cornered = true                         # nowhere left to go: it shoots where it stands
	if cornered:
		pass
	elif not sees:
		enemy.velocity = _seek_line(delta) * enemy.speed    # something in the way: find somewhere to shoot from
	elif dist > float(GameData.opt(enemy._def, "enemy", "keep_range_max")):
		_vantage = null
		enemy.velocity = enemy._walk_dir * enemy.speed            # too far: come closer
	elif dist < float(GameData.opt(enemy._def, "enemy", "keep_range_min")):
		_vantage = null
		enemy.velocity = _retreat_dir(dir) * enemy.speed * 0.5
	else:
		_vantage = null
	if enemy._attack_cd <= 0.0 and dist <= float(GameData.opt(enemy._def, "enemy", "shot_range")) and sees and not enemy._no_attack():
		enemy._windup = enemy._windup_len()
		_aim_locked = false
		enemy._aim = enemy.target.global_position


func _loose() -> void:
	enemy.telegraph = {}
	enemy._attack_cd = enemy._cooldown
	enemy._strike_t = 0.22
	var shot_dir: Vector3 = enemy._aim - enemy.global_position
	shot_dir.y = 0.0
	if shot_dir.length() < 0.1 or not enemy.is_inside_tree():
		return
	var shot: Node3D = ShotScript.new()
	shot.set("dir", shot_dir.normalized())
	shot.set("speed", float(GameData.opt(enemy._def, "enemy", "shot_speed")))
	shot.set("left", float(GameData.opt(enemy._def, "enemy", "shot_range")))
	shot.set("damage", enemy._blow(enemy.damage))
	shot.set("heavy", enemy.heavy and not enemy.status_part._st_any("no_poise_damage"))
	shot.set("hit_radius", float(GameData.opt(enemy._def, "enemy", "shot_radius")))
	shot.set("target", enemy.target)
	shot.set("shooter", enemy)
	shot.position = enemy.get_parent().to_local(enemy.global_position + Vector3.UP * 1.1 + shot_dir.normalized() * 0.6) if enemy.get_parent() is Node3D else enemy.global_position
	enemy.get_parent().add_child(shot)


## Which way to back off from the player: straight back if that is open, otherwise the nearest
## turn that is, keeping to the side it turned last time so it does not dither. Zero if it is
## boxed in. `dir` points at the player.
func _retreat_dir(dir: Vector3) -> Vector3:
	var chest: Vector3 = enemy.global_position + Vector3.UP
	for turn: float in [0.0, 45.0, -45.0, 90.0, -90.0, 125.0, -125.0]:
		var way: Vector3 = (-dir).rotated(Vector3.UP, deg_to_rad(turn * _retreat_side))
		var ahead: Vector3 = enemy.global_position + way * (enemy.radius + 1.6)
		if enemy.motion_part._clear(chest, ahead + Vector3.UP) and enemy.motion_part._has_floor(ahead):
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
	var nav: LevelNav = enemy.motion_part._level_nav()
	if nav == null and enemy._router != null and is_instance_valid(enemy._router):
		var next: Vector3 = enemy._router.route(enemy.global_position, enemy.target.global_position, enemy.radius)
		if Vector2(next.x - enemy.target.global_position.x, next.z - enemy.target.global_position.z).length() > 0.5:
			_vantage = null
			return enemy._walk_dir                     # a dividing wall: the doorway comes first
	var reached: bool = _vantage != null and Vector2((_vantage as Vector3).x - enemy.global_position.x, (_vantage as Vector3).z - enemy.global_position.z).length() < 0.3
	if _vantage == null or reached or _vantage_t <= 0.0:
		_vantage = _find_vantage()
		_vantage_t = 1.0
		enemy._errand.reset()
	if _vantage == null:
		return enemy._walk_dir
	if nav != null:
		var way: Vector3 = enemy._errand.steer(nav, enemy.global_position, _vantage as Vector3, enemy.radius, delta)
		return enemy.motion_part._round_stone(nav, enemy._errand.next_point(_vantage as Vector3), way)
	var to: Vector3 = (_vantage as Vector3) - enemy.global_position
	to.y = 0.0
	return to.normalized() if to.length() > 0.05 else Vector3.ZERO


## Looks round itself for somewhere to shoot from: a spot with ground under it and a clear line to
## the player, not too close to them, that it can get to - by path on the navigation mesh (at most
## vantage_max_path metres of walking), or without one only in a straight line. The nearest walk
## wins, with a preference for its usual shooting distance. Null if there is none within 8 m.
func _find_vantage() -> Variant:
	var chest: Vector3 = enemy.global_position + Vector3.UP
	var mark: Vector3 = enemy.target.global_position + Vector3.UP
	var want: float = (float(GameData.opt(enemy._def, "enemy", "keep_range_min")) + float(GameData.opt(enemy._def, "enemy", "keep_range_max"))) * 0.5
	var too_close: float = float(GameData.opt(enemy._def, "enemy", "back_off_within")) + 1.0
	var nav: LevelNav = enemy.motion_part._level_nav()
	var max_walk: float = GameData.num("navigation", "vantage_max_path")
	var best: Variant = null
	var best_cost: float = INF
	for ring: float in [2.0, 4.0, 6.0, 8.0]:
		for k: int in 12:
			var way := Vector3(cos(TAU * float(k) / 12.0), 0.0, sin(TAU * float(k) / 12.0))
			var spot: Vector3 = enemy.global_position + way * ring
			var from_player: float = Vector2(spot.x - enemy.target.global_position.x, spot.z - enemy.target.global_position.z).length()
			if from_player < too_close:
				continue
			var cost: float = ring + absf(from_player - want) * 0.4
			if cost >= best_cost:
				continue
			if nav != null:
				if not nav.standable(spot, enemy.radius):
					continue                       # inside a wall or a block
				spot = nav.closest(spot, enemy.radius)
				if not enemy.motion_part._clear(spot + Vector3.UP, mark):
					continue
				var route: PackedVector3Array = nav.path(enemy.global_position, spot, enemy.radius)
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
				if not enemy.motion_part._clear(chest, spot + Vector3.UP + way * (enemy.radius + 0.2)) or not enemy.motion_part._has_floor(spot):
					continue
				if not enemy.motion_part._clear(spot + Vector3.UP, mark):
					continue
			best = spot
			best_cost = cost
	return best
