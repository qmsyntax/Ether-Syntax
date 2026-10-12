class_name GroundZone
extends Node3D
## A strip of ground that does something to enemies standing in it: a line of flame, for now.
## It runs from `from` to `to`, `width` across, for `life` seconds, and every `tick_s` applies
## `payload` (a hit payload, see Player.apply_hit) to each enemy inside, through `caster` so that
## talents and affinity rules see it as the caster's doing.

var from := Vector3.ZERO
var to := Vector3.ZERO
var width := 1.0
var life := 3.0
var tick_s := 1.0
var payload: Dictionary = {}
var tags: Array = []
var caster: Node
var color := Color(1.0, 0.5, 0.2)

var _tick := 0.0
var _mesh: MeshInstance3D


func _ready() -> void:
	add_to_group("ground_zones")
	var length: float = from.distance_to(to)
	if length < 0.05:
		return
	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, 0.06, length)
	_mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color, 0.55)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.6
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh.material_override = mat
	add_child(_mesh)
	global_position = (from + to) * 0.5 + Vector3.UP * 0.04
	look_at(Vector3(to.x, global_position.y, to.z), Vector3.UP)


func _physics_process(delta: float) -> void:
	tick(delta)


## One step of the zone's life. Public so a test can run it by hand.
func tick(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = tick_s
	for e: Node3D in inside():
		if is_instance_valid(caster) and caster.has_method("apply_hit"):
			caster.call("apply_hit", e, payload, tags)


## The enemies standing in the strip right now.
func inside() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if not is_inside_tree():
		return out
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Node3D
		if e == null or bool(e.call("is_dead")):
			continue
		var p := Vector2(e.global_position.x, e.global_position.z)
		if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= width * 0.5 + float(e.get("radius")):
			out.append(e)
	return out
