class_name LevelNav
extends Node3D
## Pathfinding for one level: navigation meshes baked at runtime from the level's own colliders.
##
## main.gd adds one to every level it builds (passage, arena, town) as a child of the level node,
## at the level's origin. It parses the static colliders under its parent (layer 1: floor, walls,
## dividing walls, sealed doorways, blocking props, the arena's blocks) and bakes TWO meshes from
## the same geometry, each on its own navigation map: one eroded by the common walker's radius and
## one by the big walkers' (balance.json "navigation"). Nothing walks on a mesh baked for a thinner
## body than its own, so a brute never tries a gap only a grunt fits through.
##
## It watches its parent: when a static body is added or removed there (a doorway sealed, a
## barrier opened) it re-parses and rebakes in the background and swaps the new meshes in when they
## are done; until the first bake lands, is_ready() is false and walkers fall back to Route.
## Standing stone is NOT baked in (it lives 12 s and moves nothing else; see Stone.way_round()).
##
## Paths are asked for with path(); walkers follow them with NavPath.

## Emitted when a new pair of meshes is live.
signal baked

## Bumped every time new meshes go live, so a walker knows its path may be out of date.
var version := 0
## How long the last parse (main thread) and bake (worker thread, both meshes) took, in ms.
var parse_ms := 0.0
var bake_ms := 0.0
## False in tests that bake by hand (bake_now) and do not want a rebake behind their back.
var auto_rebake := true

var _maps: Array[RID] = []
var _regions: Array[RID] = []
var _meshes: Array[NavigationMesh] = [null, null]
var _ready_flag := false
var _dirty := 0                      # frames to wait before rebaking (lets queued frees finish)
var _serial := 0                     # the latest bake asked for; older ones are thrown away
var _landed := 0                     # which of the latest bake's meshes are in (bit per size)
var _started_us := 0
var _bounds := AABB()                # of the parsed geometry, in the parent's frame
var _debug: MeshInstance3D


func _ready() -> void:
	add_to_group("level_nav")
	process_mode = Node.PROCESS_MODE_ALWAYS          # a bake finishes even behind a paused screen
	var cell: float = GameData.num("navigation", "cell_size")
	for i: int in 2:
		var map: RID = NavigationServer3D.map_create()
		NavigationServer3D.map_set_up(map, Vector3.UP)
		NavigationServer3D.map_set_cell_size(map, cell)
		NavigationServer3D.map_set_cell_height(map, GameData.num("navigation", "cell_height"))
		NavigationServer3D.map_set_use_async_iterations(map, false)    # a forced update is live at once
		NavigationServer3D.map_set_active(map, true)
		var region: RID = NavigationServer3D.region_create()
		NavigationServer3D.region_set_use_async_iterations(region, false)
		NavigationServer3D.region_set_map(region, map)
		_maps.append(map)
		_regions.append(region)
	var parent: Node = get_parent()
	if auto_rebake and parent != null:
		parent.child_entered_tree.connect(_on_parent_changed)
		parent.child_exiting_tree.connect(_on_parent_changed)
		_dirty = 1


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for rid: RID in _regions:
			NavigationServer3D.free_rid(rid)
		for rid: RID in _maps:
			NavigationServer3D.free_rid(rid)
		_regions.clear()
		_maps.clear()


func _process(_delta: float) -> void:
	if _dirty > 0:
		_dirty -= 1
		if _dirty == 0:
			rebake(true)


func _on_parent_changed(node: Node) -> void:
	if node is StaticBody3D and not node is Stone:
		_dirty = 2


## True once a mesh exists to walk on.
func is_ready() -> bool:
	return _ready_flag and not is_queued_for_deletion()


## True if `point` (world) lies over this level's walkable geometry, give or take a metre.
func covers(point: Vector3) -> bool:
	if not is_ready() or not is_inside_tree():
		return false
	var local: Vector3 = _frame().affine_inverse() * point
	var b: AABB = _bounds.grow(1.0)
	return local.x >= b.position.x and local.x <= b.end.x and local.z >= b.position.z and local.z <= b.end.z


## The navigation map for a walker of `radius`.
func map_for(radius: float) -> RID:
	return _maps[1 if radius > GameData.num("navigation", "large_from_radius") else 0]


## The way from `from` to `to` (world), corner to corner, for a walker of `radius`. Its last point
## is the reachable point nearest `to`; it is empty if there is no mesh.
func path(from: Vector3, to: Vector3, radius: float) -> PackedVector3Array:
	if not is_ready():
		return PackedVector3Array()
	return NavigationServer3D.map_get_path(map_for(radius), from, to, true)


## The walkable point nearest `point` for a walker of `radius`.
func closest(point: Vector3, radius: float) -> Vector3:
	return NavigationServer3D.map_get_closest_point(map_for(radius), point)


## True if a walker of `radius` could stand at `point` (it is within `slack` of the mesh, flat).
func standable(point: Vector3, radius: float, slack: float = 0.3) -> bool:
	if not is_ready():
		return false
	var c: Vector3 = closest(point, radius)
	return Vector2(c.x - point.x, c.z - point.z).length() <= slack and absf(c.y - point.y) < 1.0


## Length of a path, flat.
static func length_of(points: PackedVector3Array) -> float:
	var total := 0.0
	for i: int in range(1, points.size()):
		total += Vector2(points[i].x - points[i - 1].x, points[i].z - points[i - 1].z).length()
	return total


## The level's navigation for a walker standing at `at`, or null if there is none (yet): a unit
## test's little world, or a level whose first bake has not landed.
static func find(tree: SceneTree, at: Vector3) -> LevelNav:
	if tree == null:
		return null
	for node: Node in tree.get_nodes_in_group("level_nav"):
		var nav := node as LevelNav
		if nav != null and nav.covers(at):
			return nav
	return null


## Parse the parent's colliders and bake both meshes. In the background (`async`) the old meshes
## stay in use until the new ones land; otherwise this returns with them live (tests, timing).
func rebake(async: bool = true) -> void:
	var parent: Node = get_parent()
	if parent == null or not is_inside_tree():
		return
	_dirty = 0
	var t0: int = Time.get_ticks_usec()
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(_new_mesh(GameData.num("navigation", "agent_radius_small")), source, parent)
	_bounds = source.get_bounds()
	_started_us = Time.get_ticks_usec()
	parse_ms = float(_started_us - t0) / 1000.0
	_serial += 1
	_landed = 0
	var radii: Array[float] = [GameData.num("navigation", "agent_radius_small"), GameData.num("navigation", "agent_radius_large")]
	for i: int in 2:
		var mesh: NavigationMesh = _new_mesh(radii[i])
		if async:
			NavigationServer3D.bake_from_source_geometry_data_async(mesh, source, _on_baked.bind(_serial, i, mesh))
		else:
			NavigationServer3D.bake_from_source_geometry_data(mesh, source)
			_apply(_serial, i, mesh)


## Rebake now, on this thread, and return when the meshes are live.
func bake_now() -> void:
	rebake(false)


func _new_mesh(radius: float) -> NavigationMesh:
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1                  # the world layer: walls, blocks, props, barriers
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	mesh.cell_size = GameData.num("navigation", "cell_size")
	mesh.cell_height = GameData.num("navigation", "cell_height")
	mesh.agent_radius = radius
	mesh.agent_height = GameData.num("navigation", "agent_height")
	mesh.agent_max_climb = GameData.num("navigation", "agent_max_climb")
	return mesh


## Called when a background bake is done (possibly not on the main thread): hand it over.
func _on_baked(serial: int, index: int, mesh: NavigationMesh) -> void:
	call_deferred("_apply", serial, index, mesh)


func _apply(serial: int, index: int, mesh: NavigationMesh) -> void:
	if serial != _serial or _regions.is_empty():
		return                                        # a newer bake was asked for since
	_meshes[index] = mesh
	NavigationServer3D.region_set_transform(_regions[index], _frame())
	NavigationServer3D.region_set_navigation_mesh(_regions[index], mesh)
	NavigationServer3D.map_force_update(_maps[index])
	_landed |= 1 << index
	if _landed != 3:
		return
	bake_ms = float(Time.get_ticks_usec() - _started_us) / 1000.0
	_ready_flag = true
	version += 1
	if OS.get_cmdline_user_args().has("--nav-timing"):
		print("NAV: %s baked v%d: parse %.1f ms, bake %.1f ms, %d + %d polygons" % [
			str(get_parent().name), version, parse_ms, bake_ms, _meshes[0].get_polygon_count(), _meshes[1].get_polygon_count()])
	if _debug != null:
		show_debug(true)
	baked.emit()


## The frame the geometry was parsed in: the parent's.
func _frame() -> Transform3D:
	var parent := get_parent() as Node3D
	return parent.global_transform if parent != null else global_transform


## Draw the common walker's mesh on the ground (screenshots only).
func show_debug(on: bool) -> void:
	if _debug != null:
		_debug.queue_free()
		_debug = null
	if not on:
		return
	_debug = MeshInstance3D.new()
	add_child(_debug)
	_debug.top_level = true
	_debug.global_transform = _frame()
	var mesh: NavigationMesh = _meshes[0]
	if mesh == null:
		return
	var fill := ImmediateMesh.new()
	var verts: PackedVector3Array = mesh.get_vertices()
	var lift := Vector3.UP * 0.08
	fill.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for p: int in mesh.get_polygon_count():
		var poly: PackedInt32Array = mesh.get_polygon(p)
		for k: int in range(1, poly.size() - 1):
			fill.surface_add_vertex(verts[poly[0]] + lift)
			fill.surface_add_vertex(verts[poly[k]] + lift)
			fill.surface_add_vertex(verts[poly[k + 1]] + lift)
	fill.surface_end()
	fill.surface_begin(Mesh.PRIMITIVE_LINES)
	for p: int in mesh.get_polygon_count():
		var poly: PackedInt32Array = mesh.get_polygon(p)
		for k: int in poly.size():
			fill.surface_add_vertex(verts[poly[k]] + lift * 1.2)
			fill.surface_add_vertex(verts[poly[(k + 1) % poly.size()]] + lift * 1.2)
	fill.surface_end()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 0.75, 1.0, 0.35)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	fill.surface_set_material(0, mat)
	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = Color(0.6, 0.95, 1.0)
	fill.surface_set_material(1, line_mat)
	_debug.mesh = fill
