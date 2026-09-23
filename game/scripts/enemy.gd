extends CharacterBody3D
## Realm invader: chase, telegraph, strike. Kinds and numbers come from game/data/enemies.json.

signal killed(enemy: Node)

var body: Body
var kind := "grunt"
var is_living := true
var is_scenery := false
var radius := 0.5
var speed := 3.4
var damage := 10.0
var heavy := false
var aura_value := 4.0
var bounty := 150
var target: Node3D
var height := 1.6
## 0 = none, 1 = hovered by the cursor, 2 = the player's locked attack target.
var highlight := 0

var _attack_cd := 0.6
var _cooldown := 1.3
var _windup_time := 0.45
var _reach := 2.3
var _windup := -1.0
var _flash := 0.0
var _base_color := Color(0.75, 0.2, 0.2)
var _mat: StandardMaterial3D
var _label: Label3D


## `strength` scales health and damage - dungeon stages past the midpoint hit harder.
func setup(enemy_kind: String, player: Node3D, strength: float = 1.0) -> void:
	kind = enemy_kind
	target = player
	var d: Dictionary = GameData.enemy(enemy_kind)
	height = float(d.get("height", 1.6))
	radius = float(d.get("radius", 0.5))
	speed = float(d.get("speed", 3.4))
	damage = float(d.get("damage", 10.0)) * strength
	heavy = bool(d.get("heavy", false))
	aura_value = float(d.get("aura_value", 4.0))
	bounty = int(d.get("bounty", 150))
	_cooldown = float(d.get("attack_cooldown", 1.3))
	_windup_time = float(d.get("windup", 0.45))
	_reach = float(d.get("reach", 2.3))
	var c: Array = d.get("color", [0.75, 0.2, 0.2])
	_base_color = Color(float(c[0]), float(c[1]), float(c[2]))
	body = Body.new(float(d.get("hp", 240.0)) * strength)

	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = height
	mesh.mesh = capsule
	mesh.position.y = height * 0.5
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = _base_color
	_mat.emission_enabled = true
	_mat.emission = Color(0, 0, 0)
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
			if dist <= _reach + radius and not target_dead:
				target.take_hit(damage, heavy, self)
			_attack_cd = _cooldown
	elif target_dead:
		velocity = Vector3.ZERO
	elif dist > 1.5 + radius:
		var dir: Vector3 = to / maxf(dist, 0.001)
		velocity = dir * speed
	else:
		velocity = Vector3.ZERO
		if _attack_cd <= 0.0:
			_windup = _windup_time

	move_and_slide()

	if _flash > 0.0:
		_mat.albedo_color = Color(1, 1, 1)
	elif _windup >= 0.0:
		_mat.albedo_color = Color(1.0, 0.75, 0.2)
	elif highlight > 0:
		_mat.albedo_color = _base_color.lightened(0.45 if highlight == 1 else 0.3)
	else:
		_mat.albedo_color = _base_color
	# A warm glow marks what the cursor is on (bright) and what you are attacking (dimmer).
	if highlight > 0 and _flash <= 0.0:
		_mat.emission = Color(0.9, 0.8, 0.3) * (0.55 if highlight == 1 else 0.35)
	else:
		_mat.emission = Color(0, 0, 0)


func _refresh_label() -> void:
	_label.text = "%d" % int(ceil(body.total()))
