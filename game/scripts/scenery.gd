extends Node3D
## Living scenery. It is alive, so it counts for talents that care about harming the living.

var body: Body
var is_living := true
var is_scenery := true
var radius := 0.4
var aura_value := 0.0
var bounty := 0

var _mesh: MeshInstance3D


func setup(kind: String) -> void:
	_mesh = MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	if kind == "bush":
		body = Body.new(GameData.num("scenery", "bush_hp"))
		radius = 0.7
		var sphere := SphereMesh.new()
		sphere.radius = 0.65
		sphere.height = 1.1
		_mesh.mesh = sphere
		_mesh.position.y = 0.5
		mat.albedo_color = Color(0.16, 0.38, 0.14)
	else:
		body = Body.new(GameData.num("scenery", "grass_hp"))
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.22
		cone.height = 0.8
		_mesh.mesh = cone
		_mesh.position.y = 0.4
		mat.albedo_color = Color(0.35, 0.62, 0.2)
	_mesh.material_override = mat
	add_child(_mesh)
	add_to_group("hittable")


func is_dead() -> bool:
	return body.is_dead()


func take_hit(amount: float, _heavy: bool, _source: Node) -> float:
	var applied: float = body.apply_damage(amount)
	var frac: float = body.total() / body.total_max()
	_mesh.scale = Vector3.ONE * maxf(0.3, frac)
	if body.is_dead():
		remove_from_group("hittable")
		queue_free()
	return applied
