class_name Stone
extends StaticBody3D
## Standing stone - earth's signature (design/05 2.3). A slab the caster raised out of the floor.
## It takes `rise_s` to come up; anything standing there takes the `on_rise` payload and is pushed
## off it; then it is solid: it blocks movement and shots, theirs and the caster's, for `life`
## seconds or until `hp` is gone. An earth skill that hits it shatters it (see shatter()).
## The node sits on the ground with its local X across the slab and -Z pointing away from the caster.

const FloatText := preload("res://scripts/float_text.gd")

var caster: Node
var size := Vector3(3.0, 1.8, 0.6)          # across, tall, thick
var hp := 150.0
var life := 12.0
var rise_s := 0.35
var on_rise: Dictionary = {}
var tags: Array = []
var stage_mult := 1.0
var color := Color(0.43, 0.39, 0.34)

var _age := 0.0
var _risen := false
var _solid := false
var _gone := false
var _look: Node3D


func _ready() -> void:
	add_to_group("stones")
	collision_layer = 0                      # nothing to walk into until it is up
	collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = Vector3(0.0, size.y * 0.5, 0.0)
	add_child(col)
	_look = Node3D.new()
	add_child(_look)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	var slab := MeshInstance3D.new()
	slab.mesh = MeshKit.bevel_box(size, 0.09, Vector2(0.93, 0.72))
	slab.material_override = mat
	slab.position = Vector3(0.0, size.y * 0.5, 0.0)
	_look.add_child(slab)
	# torn-up ground along its foot, so it reads as raised and not placed
	var dark := StandardMaterial3D.new()
	dark.albedo_color = color.darkened(0.3)
	dark.roughness = 1.0
	var spots: Array = [Vector3(-0.38, 0.0, 0.42), Vector3(0.1, 0.0, -0.45), Vector3(0.4, 0.0, 0.4), Vector3(-0.15, 0.0, -0.4), Vector3(0.0, 0.0, 0.46)]
	for i: int in spots.size():
		var lump := MeshInstance3D.new()
		lump.mesh = EnvKit.rock_mesh(0.2 + 0.05 * float(i % 3), 31 + i * 7)
		lump.material_override = dark
		lump.position = Vector3((spots[i] as Vector3).x * size.x, 0.08, (spots[i] as Vector3).z)
		lump.scale = Vector3(1.0, 0.6, 1.0)
		_look.add_child(lump)
	_look.position.y = -size.y


func _physics_process(delta: float) -> void:
	tick(delta)


## One step of its life. Public so a test can run it by hand.
func tick(delta: float) -> void:
	if _gone:
		return
	_age += delta
	if not _risen:
		_look.position.y = -size.y * (1.0 - clampf(_age / maxf(rise_s, 0.01), 0.0, 1.0))
		if _age >= rise_s:
			_risen = true
			_look.position.y = 0.0
			_rise_hit()
	# solid a moment after it is up, so what it pushed off has left before there is a wall there
	if _risen and not _solid and _age >= rise_s + GameData.num("stone", "solid_delay_s"):
		_solid = true
		collision_layer = 1
	if _age >= rise_s + life:
		crumble()


## True once it blocks things.
func is_up() -> bool:
	return _solid and not _gone


## A world point in the slab's own frame, flat: x across it, y through it (negative = far side).
func local_flat(point: Vector3) -> Vector2:
	var l: Vector3 = to_local(Vector3(point.x, global_position.y, point.z))
	return Vector2(l.x, l.z)


func _rise_hit() -> void:
	if on_rise.is_empty() or not is_instance_valid(caster) or not caster.has_method("apply_hit"):
		return
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Node3D
		if e == null or bool(e.call("is_dead")):
			continue
		var l: Vector2 = local_flat(e.global_position)
		var r: float = float(e.get("radius"))
		if absf(l.x) > size.x * 0.5 + r or absf(l.y) > size.z * 0.5 + r:
			continue
		# off the face it is nearer to; dead centre goes to the far side, away from the caster
		var side: float = 1.0 if l.y > 0.0 else -1.0
		caster.call("apply_hit", e, on_rise, tags, stage_mult, global_transform.basis.z * side)


## Something hit it that was not meant to break it (an enemy's shot).
func take_damage(amount: float) -> void:
	if _gone:
		return
	hp -= amount
	if hp <= 0.0:
		crumble()


## It falls apart and is gone: its time ran out, it was worn down, or a newer stone replaced it.
func crumble() -> void:
	if _gone:
		return
	_gone = true
	collision_layer = 0
	remove_from_group("stones")
	if is_instance_valid(caster) and caster.has_method("stone_gone"):
		caster.call("stone_gone", self)
	queue_free()


## Break it into shrapnel flying along `dir`: every enemy within the shrapnel's range of the slab,
## on the side `dir` points to, takes the shrapnel hit through `by` (the caster unless given).
## The spray leaves every part of the slab along `dir` and fans out by half the cone at its ends.
## Returns how many it hit.
func shatter(dir: Vector3, by: Node = null) -> int:
	if _gone:
		return 0
	var who: Node = by if is_instance_valid(by) else caster
	var cfg: Dictionary = GameData.balance["stone"]["shrapnel"]
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.001:
		flat = -global_transform.basis.z
	flat = flat.normalized()
	var f := Vector2(flat.x, flat.z)
	var c := Vector2(global_position.x, global_position.z)
	var across: Vector3 = global_transform.basis.x
	var u := Vector2(across.x, across.z).normalized()
	var half_w: float = size.x * 0.5
	var half_cone: float = deg_to_rad(float(cfg["cone_deg"]) * 0.5)
	var reach: float = float(cfg["range"])
	var payload: Dictionary = {"damage": float(cfg["damage"]), "poise": float(cfg["poise"])}
	var hit := 0
	if is_instance_valid(who) and who.has_method("apply_hit") and is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group("enemies"):
			var e := node as Node3D
			if e == null or bool(e.call("is_dead")):
				continue
			var p := Vector2(e.global_position.x, e.global_position.z)
			# the point of the slab this enemy's shrapnel left from: straight back along dir
			var s: float = 0.0
			var denom: float = u.cross(f)
			if absf(denom) > 0.05:
				s = clampf((p - c).cross(f) / denom, -half_w, half_w)
			else:
				s = clampf((p - c).dot(u), -half_w, half_w)       # struck end-on: from the nearer end
			var to: Vector2 = p - (c + u * s)
			var dist: float = to.length()
			if dist > reach + float(e.get("radius")):
				continue
			if dist > 0.05 and absf(f.angle_to(to / dist)) > half_cone:
				continue
			who.call("apply_hit", e, payload, ["ability", "earth", "shrapnel"], 1.0, flat)
			hit += 1
		if who.has_method("_line_visual"):
			for i: int in 5:
				var from: Vector3 = global_position + across * (half_w * (float(i) - 2.0) / 2.0) + Vector3.UP * 0.9
				var spread: Vector3 = flat.rotated(Vector3.UP, half_cone * (float(i) - 2.0) / 2.0)
				who.call("_line_visual", from, from + spread * reach, color.lightened(0.35))
		FloatText.spawn(get_parent(), global_position + Vector3.UP * 1.6, "SHATTER", color.lightened(0.5))
	crumble()
	return hit


## Where a walker should head to get round the slab on its way from `from` to `to`, or null if the
## slab is not in the way (or the walker is already past its end and can simply go).
func way_round(from: Vector3, to: Vector3, walker_radius: float) -> Variant:
	if not is_up():
		return null
	var a: Vector2 = local_flat(from)
	var b: Vector2 = local_flat(to)
	if absf(a.y) < 0.01 or a.y * b.y > 0.0:
		return null                                  # same side: nothing to go round
	var half_w: float = size.x * 0.5 + walker_radius
	if absf(a.x) > half_w:
		return null
	var cross_x: float = a.x + (b.x - a.x) * (a.y / (a.y - b.y))
	if absf(cross_x) > half_w:
		return null                                  # the straight line clears the end
	var end: float = half_w + 0.6
	if absf(a.x + end) + absf(b.x + end) < absf(a.x - end) + absf(b.x - end):
		end = -end
	return to_global(Vector3(end, 0.0, signf(a.y) * (size.z * 0.5 + walker_radius + 0.3)))
