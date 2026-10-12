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
var display_name := "Enemy"
## 0 = none, 1 = hovered by the cursor, 2 = the player's locked attack target.
var highlight := 0

var _attack_cd := 0.6
var _cooldown := 1.3
var _windup_time := 0.45
var _reach := 2.3
var _windup := -1.0
var _flash := 0.0
var _base_color := Color(0.75, 0.2, 0.2)
var _label: Label3D
var _rig: ModelRig
var _strike_t := 0.0
var _shown_highlight := 0
var _shown_windup := false


## `strength` scales health and damage - dungeon stages past the midpoint hit harder.
func setup(enemy_kind: String, player: Node3D, strength: float = 1.0) -> void:
	kind = enemy_kind
	target = player
	var d: Dictionary = GameData.enemy(enemy_kind)
	height = float(d.get("height", 1.6))
	display_name = str(d.get("name", enemy_kind.capitalize()))
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

	# The look is a procedural low-poly model (scripts/art). Gameplay size still comes from data.
	_rig = Models.enemy(enemy_kind)
	add_child(_rig)

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
	_label.visible = false          # health is shown by the HUD's floating bars and target frame
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
	if _rig != null:
		_rig.flash(0.12)
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
			_strike_t = 0.22
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

	# Look: face the target, telegraph the wind-up, glow when hovered or targeted, and animate.
	_strike_t -= delta
	if dist > 0.1:
		_rig.rotation.y = lerp_angle(_rig.rotation.y, atan2(-to.x, -to.z), minf(1.0, delta * 12.0))
	var winding: bool = _windup >= 0.0
	if winding != _shown_windup:
		_shown_windup = winding
		_rig.set_windup(winding)
	if highlight != _shown_highlight:
		_shown_highlight = highlight
		_rig.set_highlight(highlight)
	_rig.animate(delta, velocity.length(), _strike_t > 0.0)


func _refresh_label() -> void:
	_label.text = "%d" % int(ceil(body.total()))
