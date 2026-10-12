extends Node3D
## A thrown ability, tinted by its affinity. Damage is routed through the shooter so talent hooks apply.

var dir := Vector3.FORWARD
var speed := 20.0
var damage := 90.0
var shooter: Node
var life := 1.5
var color := Color(0.3, 0.7, 1.0)


func _ready() -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.lightened(0.25)
	mat.emission_enabled = true
	mat.emission = color
	mesh.material_override = mat
	add_child(mesh)


func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	global_position += dir * speed * delta
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as Node3D
		if enemy == null:
			continue
		var reach: float = 0.6 + float(enemy.get("radius"))
		if global_position.distance_to(enemy.global_position + Vector3.UP * 0.9) <= reach + 0.6:
			if is_instance_valid(shooter):
				shooter.deal_damage(enemy, damage, ["projectile"])
			queue_free()
			return
