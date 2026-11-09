class_name EnemyMotion
extends RefCounted
## Where it goes and what it can see. A part of the enemy (docs/architecture/enemy-split.md): who it
## goes for (lures, taunts, charms), the statuses that move it on their own (fleeing, a commanded walk,
## a leash), routing on the level's navigation mesh (NavPath) and round standing stone (Stone.way_round),
## the old steering where there is no mesh, turning at its turn rate, and lines of sight.

var enemy: Enemy
var _nav: LevelNav                   # the level's navigation, once it has been baked (see LevelNav)
var _chase := NavPath.new()          # its path to the player
var _lured := false


func _init(of: Enemy) -> void:
	enemy = of


## Leashed: it cannot go further than leash_m from whoever leashed it - a step beyond is undone, as a wall would
## stop it (the leash length may come from the skill, status data "leash_m").
func _keep_leash() -> void:
	for id: String in enemy.statuses:
		var s: Dictionary = enemy.statuses[id]
		var m: float = float((s.get("data", {}) as Dictionary).get("leash_m", GameData.opt(enemy.status_part._sdef(id), "status", "leash_m")))
		var by: Variant = s.get("by")
		if m <= 0.0 or not (by is Node3D) or not is_instance_valid(by):
			continue
		var off: Vector3 = enemy.global_position - (by as Node3D).global_position
		off.y = 0.0
		if off.length() > m:
			var back: Vector3 = (by as Node3D).global_position + off.normalized() * m
			enemy.global_position = Vector3(back.x, enemy.global_position.y, back.z)


## Who it goes for: the player, unless a lure stands within its reach (a phantom, a death mask, a
## thrall, a friend wearing your face) - then that, until it breaks. An enemy with no target (a
## test's dummy) is never lured.
func _pick_target() -> void:
	if not enemy.is_inside_tree():
		return
	if not _lured and enemy.target == null:
		return
	# Taunted: whoever taunted it, and nobody else (no lure, decoy or thrall draws it)
	var forced: Node3D = _forced_target()
	if forced != null:
		if enemy.target != forced:
			enemy.hits_part.interrupt()
		enemy.target = forced
		_lured = forced != enemy._player
		return
	# Charmed: it fights for whoever charmed it - the nearest of its old friends
	if enemy.status_part._st_any("fights_for_source"):
		var foe: Node3D = null
		for node2: Enemy in enemy.get_tree().get_nodes_in_group("enemies"):
			var o: Enemy = node2
			if o == null or o == enemy or bool(o.is_dead()) or bool(o._charmed()):
				continue
			if foe == null or o.global_position.distance_to(enemy.global_position) < foe.global_position.distance_to(enemy.global_position):
				foe = o
		if foe != null:
			if enemy.target != foe:
				enemy.hits_part.interrupt()
			enemy.target = foe
			_lured = true
			return
	var best: Node3D = null
	var best_d := INF
	for node: Node in enemy.get_tree().get_nodes_in_group("lures"):
		var l := node as Node3D
		if l == null or l == enemy or bool(l.call("is_dead")):
			continue
		var d: float = l.global_position.distance_to(enemy.global_position)
		if d <= float(l.get("lure_radius")) and d < best_d:
			best = l
			best_d = d
	if best == null:
		# a friend that draws it (Masked wears your face; a Charmed one has turned on them): any status with lure_radius
		for node: Enemy in enemy.get_tree().get_nodes_in_group("enemies"):
			var m: Enemy = node
			if m == null or m == enemy:
				continue
			var draw: float = float(m.lure_reach())
			var d2: float = m.global_position.distance_to(enemy.global_position)
			if draw > 0.0 and d2 <= draw and d2 < best_d:
				best = m
				best_d = d2
	if best != null:
		if enemy.target != best:
			enemy.hits_part.interrupt()
		enemy.target = best
		_lured = true
	elif _lured:
		_lured = false
		enemy.target = enemy._player if is_instance_valid(enemy._player) else null
		enemy.hits_part.interrupt()


## Whoever a forced_target status on it names (Taunted: whoever put it there), if they still stand; else null.
func _forced_target() -> Node3D:
	for id: String in enemy.statuses:
		if str(enemy.status_part._sdef(id).get("forced_target", "")) != "source":
			continue
		var by: Variant = (enemy.statuses[id] as Dictionary).get("by")
		if by is Node3D and is_instance_valid(by) and not Enemy._gone(by as Node):
			return by as Node3D
	return null


## Terrified (from whoever frightened it) or Dreading (out of the zone): it walks away and does not
## attack. Returns true while it is running.
func _flee(_delta: float) -> bool:
	for id: String in enemy.statuses:
		# Exiled: it will not come within keeps_away of whoever cast it out (outside it, it fights - and shoots - as it will)
		var keep: float = float(GameData.opt(enemy.status_part._sdef(id), "status", "keeps_away"))
		var kby: Variant = (enemy.statuses[id] as Dictionary).get("by")
		if keep > 0.0 and kby is Node3D and is_instance_valid(kby):
			var off: Vector3 = enemy.global_position - (kby as Node3D).global_position
			off.y = 0.0
			if off.length() < keep:
				enemy._windup = -1.0
				enemy.facing = (off if off.length() > 0.05 else -enemy.facing).normalized()
				enemy.velocity = enemy.facing * enemy.speed
				return true
		var how: String = str(enemy.status_part._sdef(id).get("flees", ""))
		if how == "":
			continue
		var from := Vector3.INF
		var s: Dictionary = enemy.statuses[id]
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
		var away: Vector3 = enemy.global_position - from
		away.y = 0.0
		if away.length() < 0.05:
			away = -enemy.facing
		enemy._windup = -1.0
		enemy.facing = away.normalized()
		enemy.velocity = away.normalized() * enemy.speed
		return true
	return false


## Commanded: it walks to the point it was given and stands there, starting nothing.
func _walk_to_goal(_delta: float) -> bool:
	for id: String in enemy.statuses:
		if not bool(enemy.status_part._sdef(id).get("goes_to_goal", false)):
			continue
		var goal: Variant = enemy.status_part.status_data(id).get("goal")
		if not (goal is Vector3):
			return true
		var to: Vector3 = (goal as Vector3) - enemy.global_position
		to.y = 0.0
		enemy._windup = -1.0
		if to.length() > 0.4:
			enemy.facing = to.normalized()
			enemy.velocity = to.normalized() * enemy.speed
		return true
	return false


## The direction to walk in order to reach the player: along its path on the level's navigation
## mesh (round walls, blocks, props and corners, through doorways), stepping round standing stone,
## which is not in the mesh. Where there is no mesh yet (or none at all: a unit test's little
## world), the old steering: round stone, through the passage's doorway (Route), else `straight`.
## Zero when the player cannot be reached and it already stands as near as it can get.
func _route_dir(straight: Vector3, delta: float = 0.0) -> Vector3:
	var nav: LevelNav = _level_nav()
	if nav == null:
		return _fallback_dir(straight)
	var way: Vector3 = _chase.steer(nav, enemy.global_position, enemy.target.global_position, enemy.radius, delta)
	return _round_stone(nav, _chase.next_point(enemy.target.global_position), way)


## The level's navigation where it stands, or null.
func _level_nav() -> LevelNav:
	if not enemy.is_inside_tree():
		return null
	if _nav == null or not is_instance_valid(_nav) or not _nav.covers(enemy.global_position):
		_nav = LevelNav.find(enemy.get_tree(), enemy.global_position)
	return _nav


## Walking `way` toward `next` (a corner of its path): if standing stone is in the way, head for
## the end of it that can be walked to instead. Stone is not baked into the mesh - it stands 12 s
## and Stone.way_round() already knows its one corner; this only checks the end is walkable.
func _round_stone(nav: LevelNav, next: Vector3, way: Vector3) -> Vector3:
	for node: Node in enemy.get_tree().get_nodes_in_group("stones"):
		var s := node as Stone
		if s == null:
			continue
		var detour: Variant = s.way_round(enemy.global_position, next, enemy.radius)
		if detour == null:
			continue
		var spot: Vector3 = detour as Vector3
		if not nav.standable(spot, enemy.radius, enemy.radius):
			# that end is against a wall: try the other one
			var across: Vector3 = s.global_transform.basis.x
			across.y = 0.0
			across = across.normalized()
			spot -= across * 2.0 * across.dot(spot - s.global_position)
			if not nav.standable(spot, enemy.radius, enemy.radius):
				continue                         # it closes the way: walk on and press against it
		var side: Vector3 = spot - enemy.global_position
		side.y = 0.0
		if side.length() > 0.05:
			return side.normalized()
	return way


## The old steering, for where there is no navigation mesh: round standing stone, else through
## the passage's doorway (see Route), else `straight`.
func _fallback_dir(straight: Vector3) -> Vector3:
	if enemy.is_inside_tree():
		for s: Node in enemy.get_tree().get_nodes_in_group("stones"):
			var detour: Variant = s.call("way_round", enemy.global_position, enemy.target.global_position, enemy.radius)
			if detour != null:
				var side: Vector3 = (detour as Vector3) - enemy.global_position
				side.y = 0.0
				if side.length() > 0.05:
					return side.normalized()
	return _door_dir(straight)


## The way through the passage's dividing walls (see Route), or `straight` where there are none.
func _door_dir(straight: Vector3) -> Vector3:
	if not enemy.is_inside_tree():
		return straight
	if enemy._router == null or not is_instance_valid(enemy._router):
		enemy._router = enemy.get_tree().get_first_node_in_group("router")
	if enemy._router == null:
		return straight
	var next: Vector3 = enemy._router.route(enemy.global_position, enemy.target.global_position, enemy.radius)
	var way: Vector3 = next - enemy.global_position
	way.y = 0.0
	return way.normalized() if way.length() > 0.05 else straight


## Turn toward `want` at the turn rate. Nothing turns while it is committed to an attack.
func _turn_toward(want: Vector3, delta: float) -> void:
	if want.length() < 0.001 or enemy._turned_t > 0.0:
		return
	var from: float = atan2(enemy.facing.x, enemy.facing.z)
	var goal: float = atan2(want.x, want.z)
	var step: float = clampf(wrapf(goal - from, -PI, PI), -enemy._turn_rate * delta, enemy._turn_rate * delta)
	enemy.facing = Vector3(sin(from + step), 0.0, cos(from + step))


## True if it can see `point`: in its front arc, nothing solid between, not blinded past its sight.
## Asleep sees nothing (Dream reads that apart). Mindless kinds (enemies.json "mindless") see no mind.
func sees_point(point: Vector3) -> bool:
	if enemy.body.is_dead() or bool(enemy._def.get("mindless", false)):
		return false
	if not enemy.hits_part.is_in_front(point):
		return false
	var blind: Dictionary = enemy.status_part._blinded()
	if not blind.is_empty() and Vector2(point.x - enemy.global_position.x, point.z - enemy.global_position.z).length() > float(GameData.opt(blind, "status.blinded", "sight")):
		return false
	if not enemy.is_inside_tree():
		return true
	var q := PhysicsRayQueryParameters3D.create(enemy.global_position + Vector3.UP, point + Vector3.UP, 1)
	return enemy.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Nothing solid on the straight line between two points (walls, blocks, stone - not bodies).
func _clear(from: Vector3, to: Vector3) -> bool:
	if not enemy.is_inside_tree():
		return true
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	return enemy.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## True if there is ground to stand on at `spot`.
func _has_floor(spot: Vector3) -> bool:
	if not enemy.is_inside_tree():
		return true
	var q := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 0.5, spot + Vector3.DOWN * 1.5, 1)
	return not enemy.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Nothing solid between it and the player; not blinded past its sight; not looking into or through
## a zone that blocks sight (a pall, smoke); and the player not unseen from here.
func _sees_target() -> bool:
	if not enemy.is_inside_tree():
		return true
	var blind: Dictionary = enemy.status_part._blinded()
	if not blind.is_empty() and enemy.global_position.distance_to(enemy.target.global_position) > float(GameData.opt(blind, "status.blinded", "sight")):
		return false
	if enemy.target == enemy._player and enemy._player.has_method("unseen_from") and bool(enemy._player.call("unseen_from", enemy.global_position)):
		return false
	for z: Node in enemy.get_tree().get_nodes_in_group("ground_zones"):
		if (bool(z.get("blocks_sight")) or bool(z.get("hides"))) and bool(z.call("crosses", enemy.global_position, enemy.target.global_position)):
			# Lit bodies show through a hiding zone
			if bool(z.get("hides")) and enemy.target.has_method("has_status") and bool(enemy.target.call("has_status", "lit")):
				continue
			return false
	var q := PhysicsRayQueryParameters3D.create(enemy.global_position + Vector3.UP, enemy.target.global_position + Vector3.UP, 1)
	return enemy.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
