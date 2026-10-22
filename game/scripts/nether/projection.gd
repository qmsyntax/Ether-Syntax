extends Node3D
## The soul projected out of the body. Small, fast, and fragile: if it is destroyed, you die.
## Controls mirror the body's (WASD, click to move, click a construct to strike it) so nothing
## has to be relearned. It has no abilities - only a plain soul strike.

signal destroyed

const ISO_YAW := deg_to_rad(45.0)

var hp := 12.0
var hp_max := 12.0
var stars := 1
var anchor := Vector3.ZERO          # where the body sits
var leash := 13.0
var attack_target: Node3D = null
var hovered: Node3D = null
var move_goal := Vector3.ZERO
var has_move_goal := false
## Set by the controller: when true, real mouse and keyboard input is ignored (tests, UI open).
var input_blocked := false
var at_leash := false

var _model: Node3D
var _cd := 0.0
var _strike_t := 0.0
var _strike_once := false
var _cfg: Dictionary
var _facing := Vector3.FORWARD


func setup(body_position: Vector3, star_count: int) -> void:
	_cfg = GameData.balance["nether"]
	stars = star_count
	anchor = body_position
	hp_max = float(_cfg["projection_hp"])
	hp = hp_max
	leash = float(_cfg["leash_base"]) + float(_cfg["leash_per_star"]) * float(stars)
	_model = NetherArt.projection()
	add_child(_model)


func strike_damage() -> float:
	return float(_cfg["strike_damage"]) + float(_cfg["strike_damage_per_star"]) * float(stars - 1)


func take_hit(amount: float, _heavy: bool, _source: Node, _tags: Array = []) -> float:
	if hp <= 0.0:
		return 0.0
	var applied: float = minf(amount, hp)
	hp -= applied
	NetherArt.look(_model, "flash", 0.15)
	if hp <= 0.0:
		destroyed.emit()
	return applied


## Click at the cursor: strike the hovered construct, or walk to the floor point.
func click(ground_point: Vector3) -> void:
	if hovered != null and is_instance_valid(hovered) and not bool(hovered.call("is_dead")):
		attack_target = hovered
		has_move_goal = false
		_strike_once = true
	else:
		attack_target = null
		move_goal = ground_point
		has_move_goal = true


func tick(delta: float, cam: Camera3D) -> void:
	_cd -= delta
	_strike_t -= delta
	var input := Vector2.ZERO
	if not input_blocked:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if cam != null:
			hovered = Pick.screen(get_tree(), ["nether_hittable"], get_viewport().get_mouse_position(), cam, GameData.num("player", "pick_margin_px"))
			if Input.is_action_just_pressed("strike"):
				click(Pick.ground(cam, get_viewport().get_mouse_position(), global_position.y))
	var dir := Vector3(input.x, 0.0, input.y).normalized().rotated(Vector3.UP, ISO_YAW)
	if input != Vector2.ZERO:
		has_move_goal = false
		if input_blocked or not Input.is_action_pressed("strike"):
			attack_target = null

	if attack_target != null and (not is_instance_valid(attack_target) or bool(attack_target.call("is_dead"))):
		attack_target = null
	if attack_target != null:
		var to: Vector3 = attack_target.global_position - global_position
		to.y = 0.0
		if to.length() > 0.2:
			_facing = to.normalized()
		if to.length() <= float(_cfg["strike_reach"]) + float(attack_target.get("radius")):
			if input == Vector2.ZERO:
				dir = Vector3.ZERO
			if _cd <= 0.0:
				attack_target.call("take_hit", strike_damage(), false, self)
				_cd = float(_cfg["strike_cooldown"])
				_strike_t = 0.18
				if _strike_once and (input_blocked or not Input.is_action_pressed("strike")):
					attack_target = null
		elif input == Vector2.ZERO:
			dir = to.normalized()
	elif has_move_goal and input == Vector2.ZERO:
		var tg: Vector3 = move_goal - global_position
		tg.y = 0.0
		if tg.length() < 0.3:
			has_move_goal = false
		else:
			dir = tg.normalized()

	if dir != Vector3.ZERO and attack_target == null:
		_facing = dir
	var next: Vector3 = global_position + dir * float(_cfg["projection_speed"]) * delta
	# the leash: a soul can only stray so far from its body
	var off: Vector3 = next - anchor
	off.y = 0.0
	at_leash = off.length() >= leash - 0.05
	if off.length() > leash:
		next = anchor + off.normalized() * leash
		has_move_goal = false
	global_position = next
	_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-_facing.x, -_facing.z), minf(1.0, delta * 14.0))
	if _model.has_method("animate"):
		_model.call("animate", delta, dir.length() * float(_cfg["projection_speed"]), _strike_t > 0.0)
