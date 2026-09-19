extends CharacterBody3D
## Placeholder realm invader: chase, telegraph, strike.

signal killed(enemy: Node)

var body: Body
var is_living := true
var is_scenery := false
var radius := 0.5
var speed := 3.4
var damage := 10.0
var heavy := false
var aura_value := 4.0
var bounty := 150
var target: Node3D

var _attack_cd := 0.6
var _windup := -1.0
var _flash := 0.0
var _base_color := Color(0.75, 0.2, 0.2)
var _mat: StandardMaterial3D
var _label: Label3D


func setup(kind: String, player: Node3D) -> void:
	target = player
	var height := 1.6
	if kind == "brute":
		body = Body.new(700.0)
		radius = 0.8
		speed = 2.3
		damage = 22.0
		heavy = true
		aura_value = 12.0
		bounty = 500
		height = 2.4
		_base_color = Color(0.5, 0.1, 0.3)
	else:
		body = Body.new(240.0)

	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = height
	mesh.mesh = capsule
	mesh.position.y = height * 0.5
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = _base_color
	mesh.material_override = _mat
	add_child(mesh)

	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = height
	col.shape = shape
	col.position.y = height * 0.5
	add_child(col)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 36
	_label.outline_size = 10
	_label.pixel_size = 0.01
	_label.position.y = height + 0.5
	add_child(_label)
	_refresh_label()

	# Layer 1 = world, 2 = player, 3 = enemies. Enemies block each other and the
	# world, but never physically touch the player (hits are distance checks).
	collision_layer = 4
	collision_mask = 1 | 4

	add_to_group("hittable")
	add_to_group("enemies")


func is_dead() -> bool:
	return body.is_dead()


func take_hit(amount: float, _heavy: bool, _source: Node) -> float:
	var applied: float = body.apply_damage(amount)
	_flash = 0.12
	_refresh_label()
	if body.is_dead():
		remove_from_group("hittable")
		remove_from_group("enemies")
		killed.emit(self)
		queue_free()
	return applied


func _physics_process(delta: float) -> void:
	if body.is_dead() or not is_instance_valid(target):
		return
	_attack_cd -= delta
	_flash -= delta

	var to: Vector3 = target.global_position - global_position
	to.y = 0.0
	var dist: float = to.length()
	var target_dead: bool = bool(target.get("dead"))

	if _windup >= 0.0:
		_windup -= delta
		velocity = Vector3.ZERO
		if _windup < 0.0:
			if dist <= 2.3 + radius and not target_dead:
				target.take_hit(damage, heavy, self)
			_attack_cd = 1.3
	elif target_dead:
		velocity = Vector3.ZERO
	elif dist > 1.5 + radius:
		var dir: Vector3 = to / maxf(dist, 0.001)
		velocity = dir * speed
	else:
		velocity = Vector3.ZERO
		if _attack_cd <= 0.0:
			_windup = 0.45

	move_and_slide()

	if _flash > 0.0:
		_mat.albedo_color = Color(1, 1, 1)
	elif _windup >= 0.0:
		_mat.albedo_color = Color(1.0, 0.75, 0.2)
	else:
		_mat.albedo_color = _base_color


func _refresh_label() -> void:
	_label.text = "%d" % int(ceil(body.total()))
