class_name NetherArt
extends RefCounted
## Looks for the Netherecho's inhabitants. Uses the procedural models in scripts/art when they
## provide a builder for the thing asked for, and falls back to a plain glowing shape when they
## do not - so gameplay never depends on which art pass has landed.

const MODELS_PATH := "res://scripts/art/models.gd"

static var _models: GDScript
static var _methods: Dictionary = {}


static func _has(method: String) -> bool:
	if _models == null:
		_models = load(MODELS_PATH)
		for m: Dictionary in _models.get_script_method_list():
			_methods[str(m["name"])] = true
	return _methods.has(method)


static func projection() -> Node3D:
	if _has("projection"):
		return _models.call("projection")
	return _glow_shape(1.0, 0.3, Color(0.5, 0.95, 1.0), true)


static func wisp(affinity: String) -> Node3D:
	if _has("wisp"):
		return _models.call("wisp", affinity)
	var n: Node3D = _glow_shape(0.26, 0.13, Color(0.3, 0.6, 1.0) if affinity == "water" else Color(0.9, 0.9, 1.0), false)
	(n.get_child(0) as Node3D).position.y = 0.7
	return n


static func construct(tier: String, concept: String, height: float, radius: float) -> Node3D:
	if _has("construct"):
		return _models.call("construct", tier, concept)
	var hues := {"acceleration": 0.12, "piercing": 0.0, "compression": 0.75, "tension": 0.9, "reach": 0.45, "stillness": 0.58}
	return _glow_shape(height, radius, Color.from_hsv(float(hues.get(concept, 0.6)), 0.6, 1.0), true)


static func _glow_shape(height: float, radius: float, color: Color, tall: bool) -> Node3D:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	if tall:
		var cap := CapsuleMesh.new()
		cap.radius = radius
		cap.height = height
		mesh.mesh = cap
		mesh.position.y = height * 0.5
	else:
		var ball := SphereMesh.new()
		ball.radius = radius
		ball.height = radius * 2.0
		mesh.mesh = ball
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.4
	mesh.material_override = mat
	root.add_child(mesh)
	return root


## Call a look method on a model if it has it (ModelRig does; the fallback shape does not).
static func look(model: Node, method: String, arg: Variant = null) -> void:
	if model != null and model.has_method(method):
		if arg == null:
			model.call(method)
		else:
			model.call(method, arg)
