class_name GroundZone
extends Node3D
## A patch of ground that does something to enemies standing in it: a line of flame, a pool, a
## lane of wind. A "strip" runs from `from` to `to`, `width` across; a "circle" is `radius` round
## `from`. It lasts `life` seconds. Every `tick_s` it applies `payload` (a hit payload, see
## Player.apply_hit) and `extra_status` to each enemy inside, through `caster`, so that talents and
## affinity rules see it as the caster's doing. Every frame it pushes them `push_per_s` along the
## strip. The rest is read by others: `shove_mult` by an enemy being shoved from inside it, and
## `caster_speed_mult` / `pip_gain_mult` by the caster standing in it.

var shape := "strip"
var from := Vector3.ZERO
var to := Vector3.ZERO
var width := 1.0
var radius := 0.0
var life := 3.0
var tick_s := 1.0
var payload: Dictionary = {}
var extra_status := ""
var shove_mult := 1.0
var push_per_s := 0.0
var caster_speed_mult := 1.0
var pip_gain_mult := 1.0
var tags: Array = []
var caster: Node
var color := Color(1.0, 0.5, 0.2)
## Drawn hot (fire) or as a faint wash (water, wind).
var bright := true

var _tick := 0.0
var _mesh: MeshInstance3D


func _ready() -> void:
	add_to_group("ground_zones")
	_mesh = MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color, 0.55 if bright else 0.3)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.6 if bright else 0.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh.material_override = mat
	if shape == "circle":
		var disc := CylinderMesh.new()
		disc.top_radius = radius
		disc.bottom_radius = radius
		disc.height = 0.06
		disc.radial_segments = 40
		_mesh.mesh = disc
		add_child(_mesh)
		global_position = from + Vector3.UP * 0.04
		return
	var length: float = from.distance_to(to)
	if length < 0.05:
		return
	var box := BoxMesh.new()
	box.size = Vector3(width, 0.06, length)
	_mesh.mesh = box
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
	if push_per_s != 0.0 and shape == "strip":
		var along: Vector3 = to - from
		along.y = 0.0
		if along.length() > 0.05:
			for e: Node3D in inside():
				e.call("nudge", along.normalized() * push_per_s * delta)
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = tick_s
	for e: Node3D in inside():
		if extra_status != "":
			e.call("add_status", extra_status)
		if not payload.is_empty() and is_instance_valid(caster) and caster.has_method("apply_hit"):
			caster.call("apply_hit", e, payload, tags)


## True if a body of radius `margin` at `point` touches the zone.
func has_point(point: Vector3, margin: float = 0.0) -> bool:
	var p := Vector2(point.x, point.z)
	var a := Vector2(from.x, from.z)
	if shape == "circle":
		return p.distance_to(a) <= radius + margin
	return Geometry2D.get_closest_point_to_segment(p, a, Vector2(to.x, to.z)).distance_to(p) <= width * 0.5 + margin


## The enemies standing in it right now.
func inside() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if not is_inside_tree():
		return out
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Node3D
		if e == null or bool(e.call("is_dead")):
			continue
		if has_point(e.global_position, float(e.get("radius"))):
			out.append(e)
	return out
