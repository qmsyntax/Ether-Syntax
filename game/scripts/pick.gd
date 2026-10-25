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
			if t == null or bool(t.call("is_dead")):
				continue
			var h: float = float(t.get("height")) if t.get("height") != null else 1.0
			if not standing_in_view(cam, t.global_position, h):
				continue
			var r: float = float(t.get("radius")) if t.get("radius") != null else 0.4
			var base: Vector2 = cam.unproject_position(t.global_position)
			var top: Vector2 = cam.unproject_position(t.global_position + Vector3.UP * h)
			var side: Vector2 = cam.unproject_position(t.global_position + cam.global_transform.basis.x * r)
			var d: float = Geometry2D.get_closest_point_to_segment(screen_pos, base, top).distance_to(screen_pos)
			if d <= base.distance_to(side) + margin and d < best_d:
				best = t
				best_d = d
	return best


## True when a body standing at `base`, `height` tall, is wholly in front of the camera, so its
## base-to-top segment can be drawn on the screen. One that straddles the camera's plane (base just
## in front, top behind - something beside or under a low camera) unprojects to a mirrored segment
## thousands of pixels long that passes through every cursor: before this check it caught every
## click, and the player ran to it whatever was clicked (Brent 2026-10-24, the Stubble).
static func standing_in_view(cam: Camera3D, base: Vector3, height: float) -> bool:
	return not cam.is_position_behind(base) and not cam.is_position_behind(base + Vector3.UP * height)


## Where a screen point meets the horizontal plane at height `y`. A ray that never comes down in
## front of the camera (above the horizon, the top of the screen zoomed in) has no such point: it
## gives the far point straight out along the ray's ground direction instead, so a click there
## still means "that way". (Solving the plane for it gave a point behind the camera, and the
## player ran the opposite way.)
static func ground(cam: Camera3D, screen_pos: Vector2, y: float) -> Vector3:
	var origin: Vector3 = cam.project_ray_origin(screen_pos)
	var normal: Vector3 = cam.project_ray_normal(screen_pos)
	if normal.y < -0.0001:
		var hit: Vector3 = origin + normal * ((y - origin.y) / normal.y)
		if Vector2(hit.x - origin.x, hit.z - origin.z).length() <= cam.far:
			return hit
	var flat: Vector2 = Vector2(normal.x, normal.z).normalized() * cam.far
	return Vector3(origin.x + flat.x, y, origin.z + flat.y)
