extends Node3D
## A thrown ability, tinted by its affinity. Damage is routed through the shooter so talent hooks apply.

var dir := Vector3.FORWARD
var speed := 20.0
var damage := 90.0
var shooter: Node
var life := 1.5
var color := Color(0.3, 0.7, 1.0)
## What it does to the first enemy it meets (see Player.apply_hit). Empty = plain damage.
var payload: Dictionary = {}
var tags: Array = ["projectile"]
## Passes through every enemy in its line instead of stopping at the first.
var pierce := false
## An earth bolt: if what stops it is the shooter's own stone, the stone shatters along its flight.
var shatters_stone := false
var _struck: Array = []


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
	tick(delta)


## One step of flight. The whole stretch covered is checked, so a fast shot cannot step over a
## body, and it stops on walls and blocks. Public so a test can fly it by hand.
func tick(delta: float) -> void:
	var step: float = minf(life, delta) * speed
	life -= delta
	var from: Vector3 = global_position
	var to: Vector3 = from + dir * step
	var stopped := false
	var hit_wall: Object = null
	if is_inside_tree():
		var q := PhysicsRayQueryParameters3D.create(from, to, 1)
		var wall: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
		if not wall.is_empty():
			to = wall["position"]
			stopped = true
			hit_wall = wall["collider"]
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	# nearest first, so a shot that stops at the first body stops at the right one
	var in_path: Array = []
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as Node3D
		if enemy == null or _struck.has(enemy) or bool(enemy.call("is_dead")):
			continue
		var p := Vector2(enemy.global_position.x, enemy.global_position.z)
		if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= 0.35 + float(enemy.get("radius")):
			in_path.append(enemy)
	in_path.sort_custom(func(x: Node3D, y: Node3D) -> bool: return x.global_position.distance_squared_to(from) < y.global_position.distance_squared_to(from))
	for enemy: Node3D in in_path:
		_struck.append(enemy)
		if is_instance_valid(shooter):
			if payload.is_empty():
				shooter.deal_damage(enemy, damage, tags)
			else:
				shooter.apply_hit(enemy, payload, tags, 1.0, dir)      # shoved the way it was flying
		if not pierce:
			queue_free()
			return
	global_position = to
	if stopped and shatters_stone and hit_wall is Stone:
		(hit_wall as Stone).shatter(dir, shooter if is_instance_valid(shooter) else null)
	if stopped or life <= 0.0:
		queue_free()
