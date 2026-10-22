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
## How far either side of its line it touches a body (a wave of water is wide).
var hit_radius := 0.35
## The skill it was thrown as: what it leaves where it lands (a trail, dark ground), whether it
## strikes corpses (Player.projectile_landed / projectile_hit_corpse).
var ab: Dictionary = {}
var stage_mult := 1.0
var _struck: Array = []
var _start := Vector3.INF


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
	if _start == Vector3.INF:
		_start = from
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
		if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= hit_radius + float(enemy.get("radius")):
			in_path.append(enemy)
	in_path.sort_custom(func(x: Node3D, y: Node3D) -> bool: return x.global_position.distance_squared_to(from) < y.global_position.distance_squared_to(from))
	# a bolt that strikes corpses meets the first one in its path like a body (Rotting Bolt)
	if bool(ab.get("hits_corpses", false)) and is_inside_tree() and is_instance_valid(shooter):
		for node: Node in get_tree().get_nodes_in_group("fallen"):
			var f := node as Node3D
			var fp := Vector2(f.global_position.x, f.global_position.z)
			if Geometry2D.get_closest_point_to_segment(fp, a, b).distance_to(fp) <= hit_radius + 0.5 \
					and (in_path.is_empty() or f.global_position.distance_squared_to(from) < (in_path[0] as Node3D).global_position.distance_squared_to(from)):
				shooter.call("projectile_hit_corpse", f, ab, tags, stage_mult)
				_land(f.global_position)
				return
	for enemy: Node3D in in_path:
		_struck.append(enemy)
		if is_instance_valid(shooter):
			if payload.is_empty():
				shooter.deal_damage(enemy, damage, tags)
			else:
				shooter.apply_hit(enemy, payload, tags, 1.0, dir)      # shoved the way it was flying
		if not pierce or (enemy.has_method("blocks_shot") and bool(enemy.call("blocks_shot", from)) and not payload.get("through", false)):
			_land(enemy.global_position)
			return
	global_position = to
	if stopped and shatters_stone and hit_wall is Stone:
		(hit_wall as Stone).shatter(dir, shooter if is_instance_valid(shooter) else null)
	if stopped or life <= 0.0:
		_land(global_position)


## It has stopped: whatever the skill leaves where it lands, then it is gone.
func _land(at: Vector3) -> void:
	if is_instance_valid(shooter) and shooter.has_method("projectile_landed") and not ab.is_empty():
		shooter.call("projectile_landed", _start, at, ab, tags)
	queue_free()
