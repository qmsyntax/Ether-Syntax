class_name Pick
extends RefCounted
## Screen-space picking shared by anything that clicks on things in the world.


## The node in any of `groups` whose drawn body (base-to-top segment, widened by its radius and
## `margin` pixels) contains `screen_pos`; the one closest to the cursor wins. Nodes need
## `radius`, `height` and `is_dead()`.
static func screen(tree: SceneTree, groups: Array, screen_pos: Vector2, cam: Camera3D, margin: float) -> Node3D:
	if cam == null:
		return null
	var best: Node3D = null
	var best_d := INF
	for group: String in groups:
		for node: Node in tree.get_nodes_in_group(group):
			var t := node as Node3D
			if t == null or bool(t.call("is_dead")) or cam.is_position_behind(t.global_position):
				continue
			var h: float = float(t.get("height")) if t.get("height") != null else 1.0
			var r: float = float(t.get("radius")) if t.get("radius") != null else 0.4
			var base: Vector2 = cam.unproject_position(t.global_position)
			var top: Vector2 = cam.unproject_position(t.global_position + Vector3.UP * h)
			var side: Vector2 = cam.unproject_position(t.global_position + cam.global_transform.basis.x * r)
			var d: float = Geometry2D.get_closest_point_to_segment(screen_pos, base, top).distance_to(screen_pos)
			if d <= base.distance_to(side) + margin and d < best_d:
				best = t
				best_d = d
	return best


## Where a screen point meets the horizontal plane at height `y`.
static func ground(cam: Camera3D, screen_pos: Vector2, y: float) -> Vector3:
	var origin: Vector3 = cam.project_ray_origin(screen_pos)
	var normal: Vector3 = cam.project_ray_normal(screen_pos)
	if absf(normal.y) < 0.0001:
		return Vector3(origin.x, y, origin.z)
	return origin + normal * ((y - origin.y) / normal.y)
