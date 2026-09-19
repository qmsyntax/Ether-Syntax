extends CharacterBody3D
## Player archhuman: three-layer body, essence tank + satellite, reflux heat,
## hidden latent aura, and the talent hooks for the six prototype talents.

signal died

const FloatText := preload("res://scripts/float_text.gd")
const Projectile := preload("res://scripts/projectile.gd")

const ISO_YAW := deg_to_rad(45.0)
const MOVE_SPEED := 6.5
const MELEE_DAMAGE := 60.0
const MELEE_RANGE := 2.3
const MELEE_ARC := deg_to_rad(75.0)
const MELEE_COOLDOWN := 0.45
const CHARGE_MAX := 2.0
const BOLT_COST := 12.0
const BOLT_DAMAGE := 90.0
const HEAL_PRICES := {"catastrophic": 300, "structural": 60, "superficial": 15}

var body := Body.new(60.0, 30.0, 10.0)
var talent_id := ""
var talent: Dictionary = {}
var stars := 1
var essence := 100.0
var essence_max := 100.0
var satellite_rate := 1.0
var reflux := 0.0
var reflux_locked := false
var money := 0
var in_combat := false
var fight_time := 0.0
var meditating := false
var active := false
var dead := false
var heal_points_total := 0.0
var discoveries: Array[String] = []
var log_lines: Array[String] = []

# Hidden from the player on purpose: the notebook only ever gives a vague read.
var _latent_aura := 0.0
var _aura_threshold := 100.0

var _facing := Vector3.FORWARD
var _melee_cd := 0.0
var _charge := 0.0
var _charging := false
var _meditate_block := 0.0
var _pending: Array[Dictionary] = []      # Debt of Pain queue
var _hits_taken_from: Dictionary = {}     # Grudge
var _hit_counts: Dictionary = {}          # Tenth Strike
var _mat: StandardMaterial3D


func _ready() -> void:
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	mesh.mesh = capsule
	mesh.position.y = 0.9
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.15, 0.45, 0.75)
	mesh.material_override = _mat
	add_child(mesh)

	var nose := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.18, 0.18, 0.7)
	nose.mesh = box
	nose.position = Vector3(0, 1.2, -0.55)
	add_child(nose)

	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	col.shape = shape
	col.position.y = 0.9
	add_child(col)

	# Layer 2 = player; collide with the world only (see enemy.gd).
	collision_layer = 2
	collision_mask = 1


func set_talent(id: String) -> void:
	talent_id = id
	talent = TalentDB.get_talent(id)
	note("Embraced: %s" % str(talent.get("name", id)))


func _physics_process(delta: float) -> void:
	if not active or dead:
		return

	_melee_cd -= delta
	_meditate_block -= delta
	if in_combat:
		fight_time += delta

	essence = minf(essence_max, essence + satellite_rate * delta)
	_process_pending(delta)
	_update_aim()

	var want_meditate: bool = Input.is_physical_key_pressed(KEY_M) and _meditate_block <= 0.0
	meditating = want_meditate and not _charging

	# The body sheds reflux on its own; meditation purges it much faster.
	var shed: float = 6.0 if meditating else (0.5 if in_combat else 1.5)
	reflux = maxf(0.0, reflux - shed * delta)
	if reflux_locked and reflux < 60.0:
		reflux_locked = false
		note("Water affinity unlocks.")

	var rmb: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if rmb and not meditating:
		_charging = true
		_charge = minf(CHARGE_MAX, _charge + delta)
	elif _charging:
		_release_overcharge()

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _melee_cd <= 0.0 and not meditating and not _charging:
		_swing(1.0, MELEE_RANGE)
		_melee_cd = MELEE_COOLDOWN

	var input := Vector2.ZERO
	if not meditating:
		if Input.is_physical_key_pressed(KEY_W):
			input.y -= 1.0
		if Input.is_physical_key_pressed(KEY_S):
			input.y += 1.0
		if Input.is_physical_key_pressed(KEY_A):
			input.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D):
			input.x += 1.0
	var dir := Vector3(input.x, 0.0, input.y).normalized().rotated(Vector3.UP, ISO_YAW)
	var speed: float = MOVE_SPEED * (0.45 if _charging else 1.0)
	velocity = dir * speed
	move_and_slide()

	rotation.y = atan2(-_facing.x, -_facing.z)
	var glow: float = _charge / CHARGE_MAX
	_mat.albedo_color = Color(0.15 + glow * 0.8, 0.45, 0.75 - glow * 0.5)
	if meditating:
		_mat.albedo_color = Color(0.55, 0.85, 0.95)


# --- dealing damage -----------------------------------------------------------

func deal_damage(target: Node, base: float) -> void:
	if not is_instance_valid(target) or bool(target.call("is_dead")):
		return
	var id: int = target.get_instance_id()
	var mult := 1.0
	match talent_id:
		"tenth_strike":
			var count: int = int(_hit_counts.get(id, 0)) + 1
			_hit_counts[id] = count
			if count % 10 == 0:
				mult *= 5.0
				_text(target, "TENTH", Color(1, 0.85, 0.2))
		"grudge":
			mult *= 1.0 + 0.02 * float(_hits_taken_from.get(id, 0))
		"glass_hour":
			if in_combat and fight_time < 6.0:
				mult *= 3.0

	var pos: Vector3 = (target as Node3D).global_position
	var scenery: bool = bool(target.get("is_scenery"))
	var applied: float = target.call("take_hit", base * mult, false, self)
	if applied <= 0.0:
		return
	if not scenery:
		FloatText.spawn(get_parent(), pos, "%d" % int(applied), Color(1, 1, 1))

	if talent_id == "one_percent_lifesteal" and bool(target.get("is_living")):
		var points: float = applied * 0.01
		heal_points_total += points
		var used: float = body.heal(points, stars >= 2)
		if used > 0.0:
			discover("Pays on plants: YES" if scenery else "Pays on monsters: YES")

	if bool(target.call("is_dead")):
		_on_kill(target)


func _on_kill(target: Node) -> void:
	money += int(target.get("bounty"))
	var hurt: float = 1.0 - body.total() / body.total_max()
	var risk: float = 1.0 + hurt * 2.0
	_latent_aura += float(target.get("aura_value")) * risk


func _swing(multiplier: float, reach: float) -> void:
	_swing_visual(reach, multiplier > 1.0)
	for node: Node in get_tree().get_nodes_in_group("hittable"):
		var t := node as Node3D
		if t == null:
			continue
		var to: Vector3 = t.global_position - global_position
		to.y = 0.0
		var dist: float = to.length()
		if dist > reach + float(t.get("radius")):
			continue
		if dist > 0.3 and _facing.angle_to(to / dist) > MELEE_ARC:
			continue
		deal_damage(t, MELEE_DAMAGE * multiplier)


func _release_overcharge() -> void:
	var c: float = _charge
	_charging = false
	_charge = 0.0
	if c < 0.25:
		return
	# Health as ammunition: the blow lands harder than the arm can bear.
	var self_cost: float = 4.0 + c * 6.0
	var applied: float = body.apply_self_harm(self_cost)
	FloatText.spawn(get_parent(), global_position, "arm -%d" % int(applied), Color(1, 0.4, 0.3))
	_swing(1.0 + c * 2.5, MELEE_RANGE + 0.5)
	_melee_cd = MELEE_COOLDOWN * 1.5
	_check_death()


func cast_bolt() -> void:
	if not active or dead or meditating:
		return
	if reflux_locked:
		note("Water affinity is locked by reflux. Meditate (hold M).")
		return
	var cost: float = BOLT_COST * (1.25 if reflux >= 50.0 else 1.0)
	if essence < cost:
		note("Not enough essence.")
		return
	if reflux >= 80.0:
		var burn: float = body.apply_self_harm(4.0)
		FloatText.spawn(get_parent(), global_position, "reflux -%d" % int(burn), Color(1, 0.5, 0.2))
	essence -= cost
	reflux += cost

	var bolt: Node3D = Projectile.new()
	bolt.set("dir", _facing)
	bolt.set("damage", BOLT_DAMAGE)
	bolt.set("shooter", self)
	get_parent().add_child(bolt)
	bolt.global_position = global_position + Vector3.UP * 1.0 + _facing * 0.8

	if reflux >= 100.0:
		if talent_id == "furnace_gut":
			_vent()
		else:
			reflux_locked = true
			note("Reflux at 100 - water affinity LOCKED.")
	_check_death()


func _vent() -> void:
	FloatText.spawn(get_parent(), global_position, "VENT", Color(1, 0.6, 0.1))
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Node3D
		if e != null and e.global_position.distance_to(global_position) <= 4.5:
			deal_damage(e, 150.0)
	reflux = 50.0
	body.apply_self_harm(8.0)
	discover("Vent counts as your own damage: YES")


# --- taking damage ------------------------------------------------------------

func take_hit(amount: float, heavy: bool, source: Node) -> float:
	if dead:
		return 0.0
	var amt: float = amount
	if talent_id == "glass_hour" and in_combat and fight_time < 6.0:
		amt *= 3.0
	if is_instance_valid(source):
		var id: int = source.get_instance_id()
		_hits_taken_from[id] = int(_hits_taken_from.get(id, 0)) + 1
	_meditate_block = 1.0
	meditating = false

	if talent_id == "debt_of_pain":
		_pending.append({"t": 5.0, "amount": amt * 0.8, "heavy": heavy})
		FloatText.spawn(get_parent(), global_position, "later...", Color(0.7, 0.7, 1))
		return 0.0
	return _apply(amt, heavy)


func _apply(amount: float, heavy: bool) -> float:
	var applied: float = body.apply_damage(amount, heavy)
	FloatText.spawn(get_parent(), global_position, "-%d" % int(applied), Color(1, 0.25, 0.25))
	_check_death()
	return applied


func _process_pending(delta: float) -> void:
	if _pending.is_empty():
		return
	var still: Array[Dictionary] = []
	for p: Dictionary in _pending:
		p["t"] = float(p["t"]) - delta
		if float(p["t"]) <= 0.0:
			_apply(float(p["amount"]), bool(p["heavy"]))
		else:
			still.append(p)
	_pending = still


func pending_damage() -> float:
	var sum := 0.0
	for p: Dictionary in _pending:
		sum += float(p["amount"])
	return sum


func _check_death() -> void:
	if not dead and body.is_dead():
		dead = true
		_mat.albedo_color = Color(0.2, 0.2, 0.2)
		died.emit()


# --- between fights -----------------------------------------------------------

func buy_healing() -> void:
	for layer: String in Body.ORDER_HEAL:
		var gap: float = body.missing(layer)
		if gap <= 0.0:
			continue
		var amount: float = minf(10.0, gap)
		var cost: int = int(ceil(amount * float(HEAL_PRICES[layer])))
		if money < cost:
			note("Healer: %s work costs $%d. You have $%d." % [layer, cost, money])
			return
		money -= cost
		body.heal_layer(layer, amount)
		note("Healer: -$%d for %d %s HP." % [cost, int(amount), layer])
		return
	note("Healer: nothing to mend.")


func start_fight() -> void:
	in_combat = true
	fight_time = 0.0


func end_fight() -> void:
	in_combat = false


func aura_read() -> String:
	var frac: float = _latent_aura / _aura_threshold
	if stars >= 2:
		return "Two stars turn in the dark."
	if frac < 0.25:
		return "The star is quiet."
	if frac < 0.6:
		return "The star stirs."
	if frac < 1.0:
		return "The star feels heavy."
	return "The star strains against itself.  [T] to ascend"


func try_ascend() -> void:
	if stars >= 2 or _latent_aura < _aura_threshold:
		note("Nothing happens. The star is not ready.")
		return
	_latent_aura -= _aura_threshold
	stars = 2
	essence_max = 200.0
	essence = essence_max
	satellite_rate = 2.0
	body.scale_max(1.3)
	reflux = 0.0
	reflux_locked = false
	note("ASCENDED to two stars. A second tank; satellite 2/s.")
	note("Talent evolves: %s" % str(talent.get("evolve_2", "?")))
	if talent_id != "one_percent_lifesteal":
		note("(this talent's evolution is not wired into the prototype yet)")


# --- helpers ------------------------------------------------------------------

func discover(line: String) -> void:
	if not discoveries.has(line):
		discoveries.append(line)
		note("Proven - %s" % line)


func note(line: String) -> void:
	log_lines.append(line)
	while log_lines.size() > 5:
		log_lines.remove_at(0)


func _text(target: Node, txt: String, color: Color) -> void:
	FloatText.spawn(get_parent(), (target as Node3D).global_position + Vector3.UP * 0.6, txt, color)


func _update_aim() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var origin: Vector3 = cam.project_ray_origin(mouse)
	var normal: Vector3 = cam.project_ray_normal(mouse)
	if absf(normal.y) < 0.0001:
		return
	var t: float = (global_position.y - origin.y) / normal.y
	var point: Vector3 = origin + normal * t
	var to: Vector3 = point - global_position
	to.y = 0.0
	if to.length() > 0.2:
		_facing = to.normalized()


func _swing_visual(reach: float, heavy: bool) -> void:
	var arc := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(reach * 1.4, 0.08, reach)
	arc.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.5, 0.2, 0.6) if heavy else Color(1, 1, 1, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arc.material_override = mat
	get_parent().add_child(arc)
	arc.global_position = global_position + _facing * (reach * 0.5) + Vector3.UP * 0.9
	arc.rotation.y = rotation.y
	var tween: Tween = arc.create_tween()
	tween.tween_property(arc, "scale", Vector3(1.1, 1.0, 1.1), 0.12)
	tween.tween_callback(arc.queue_free)
