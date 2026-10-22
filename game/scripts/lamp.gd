class_name Lamp
extends Node3D
## A steady light hung at a point (Light's Still Lamp, prop shape 'lamp'): it blocks nothing,
## makes a Lit circle of `light_radius` (it is a light source for Light.level_at), and every `tick_s`
## applies `payload` to each enemy within that radius with a clear line to it. One at a time.

var caster: Node
var life := 12.0
var light_radius := 5.0
var tick_s := 0.5
var payload: Dictionary = {}
var tags: Array = []
var color := Color(1.0, 0.85, 0.4)

var _t := 0.0


func _ready() -> void:
	add_to_group("light_sources")
	add_to_group("lamps")
	var bulb := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.22
	s.height = 0.44
	bulb.mesh = s
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	bulb.material_override = mat
	bulb.position.y = 2.2
	add_child(bulb)
	var glow := OmniLight3D.new()
	glow.light_color = color
	glow.omni_range = light_radius
	glow.light_energy = 1.6
	glow.position.y = 2.2
	add_child(glow)


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = tick_s
	if not is_instance_valid(caster) or not is_inside_tree():
		return
	var from: Vector3 = global_position + Vector3.UP * 2.2
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Node3D
		if e == null or bool(e.call("is_dead")):
			continue
		if Vector2(e.global_position.x - global_position.x, e.global_position.z - global_position.z).length() > light_radius + float(e.get("radius")):
			continue
		var q := PhysicsRayQueryParameters3D.create(from, e.global_position + Vector3.UP, 1)
		if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			continue
		caster.call("apply_hit", e, payload, tags + ["lamp"])
