extends Node3D
## Something an enemy loosed at the player: it flies straight along the line it was aimed on,
## stops on walls and blocks, and hurts the player only if its path passes close enough. It does
## not home - the aim was locked before it left, so a late change of direction beats it.

var dir := Vector3.FORWARD
var speed := 30.0
var left := 16.0                  # metres of flight still to go
var damage := 18.0
var heavy := false
var hit_radius := 0.7
var target: Node3D
var shooter: Node


func _ready() -> void:
	var mesh := MeshInstance3D.new()
	var shaft := BoxMesh.new()
	shaft.size = Vector3(0.06, 0.06, 0.9)
	mesh.mesh = shaft
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.86, 0.8, 0.62)
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.75, 0.4)
	mat.emission_energy_multiplier = 0.6
	mesh.material_override = mat
	add_child(mesh)
	if dir.length() > 0.01:
		look_at(global_position + dir, Vector3.UP)


func _physics_process(delta: float) -> void:
	tick(delta)


## One step of flight, by exact distance. Checks the whole stretch covered, not just its end.
func tick(delta: float) -> void:
	var step: float = minf(left, speed * delta)
	var from: Vector3 = global_position
	var to: Vector3 = from + dir * step
	if is_inside_tree():
		var q := PhysicsRayQueryParameters3D.create(from, to, 1)
		var wall: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
		if not wall.is_empty():
			to = wall["position"]
			left = 0.0
			if wall["collider"] is Stone:
				(wall["collider"] as Stone).take_damage(damage)      # standing stone wears down
	if is_instance_valid(target) and not bool(target.get("dead")):
		var a := Vector2(from.x, from.z)
		var b := Vector2(to.x, to.z)
		var p := Vector2(target.global_position.x, target.global_position.z)
		if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= hit_radius:
			target.call("take_hit", damage, heavy, shooter if is_instance_valid(shooter) else null)
			queue_free()
			return
	global_position = to
	left -= step
	if left <= 0.0:
		queue_free()
