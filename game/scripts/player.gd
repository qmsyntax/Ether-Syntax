extends CharacterBody3D
## Player archhuman: three-layer body, essence tank + satellite, reflux heat, hidden latent aura.
## Talents (and later items, summons, techniques) are TalentEffect objects hooked into the damage
## pipeline: deal_damage() and take_hit() build a HitContext and run it through every effect.
## Tuning numbers come from GameData (game/data/balance.json).

signal died

const FloatText := preload("res://scripts/float_text.gd")
const Projectile := preload("res://scripts/projectile.gd")
const TALENT_SCRIPT_DIR := "res://scripts/talents/"
const ISO_YAW := deg_to_rad(45.0)

var body: Body
var talent_id := ""
var talent: Dictionary = {}
var effects: Array[TalentEffect] = []
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
var arm_right := 100.0            # striking arm integrity; overcharging spends it
var arm_right_lost := false
var discoveries: Array[String] = []
var log_lines: Array[String] = []

# Headless test driver only (see main.gd --bot-dungeon): steers toward bot_goal, swings at
# anything in reach, hits absurdly hard and cannot be hurt. Never enabled in normal play.
var bot := false
var bot_goal := Vector3.ZERO
var bot_damage_mult := 25.0
var _bot_dir := Vector3.ZERO

# Hidden from the player on purpose: the notebook only ever gives a vague read.
var _latent_aura := 0.0
var _aura_threshold := 100.0

var _arm_regrow := 0.0
var _facing := Vector3.FORWARD
var _melee_cd := 0.0
var _charge := 0.0
var _charging := false
var _meditate_block := 0.0
var _mat: StandardMaterial3D

# Tuning (GameData).
var _p: Dictionary
var _arm: Dictionary
var _reflux_cfg: Dictionary
var _heal_cfg: Dictionary
var _natural: Dictionary
var melee_range := 2.3
var melee_arc := deg_to_rad(75.0)


func _init() -> void:
	_p = GameData.balance["player"]
	_arm = GameData.balance["arm"]
	_reflux_cfg = GameData.balance["reflux"]
	_heal_cfg = GameData.balance["healer"]
	_natural = GameData.balance["natural_healing"]
	body = Body.new(float(_p["body_superficial"]), float(_p["body_structural"]), float(_p["body_catastrophic"]))
	essence_max = float(_p["essence_max"])
	essence = essence_max
	satellite_rate = float(_p["starter_satellite_rate"])   # placeholder until satellites are items
	_aura_threshold = float(_p["aura_threshold"])
	arm_right = float(_arm["max"])
	melee_range = float(_p["melee_range"])
	melee_arc = deg_to_rad(float(_p["melee_arc_deg"]))


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


## Embrace a talent: its rules live in res://scripts/talents/<id>.gd, if that file exists.
func set_talent(id: String) -> void:
	talent_id = id
	talent = TalentDB.get_talent(id)
	effects.clear()
	var path: String = TALENT_SCRIPT_DIR + id + ".gd"
	if ResourceLoader.exists(path):
		var script: GDScript = load(path)
		var effect: TalentEffect = script.new()
		effect.setup(self, id)
		effects.append(effect)
	else:
		note("(no effect script for %s - the talent does nothing yet)" % id)
	note("Embraced: %s" % str(talent.get("name", id)))


func _physics_process(delta: float) -> void:
	if not active or dead:
		return

	_melee_cd -= delta
	_meditate_block -= delta
	if in_combat:
		fight_time += delta

	essence = minf(essence_max, essence + satellite_rate * delta)
	for e: TalentEffect in effects:
		e.on_tick(delta)
	var bot_swing := false
	if bot:
		bot_swing = _bot_think()
	else:
		_update_aim()

	var want_meditate: bool = Input.is_action_pressed("meditate") and _meditate_block <= 0.0
	meditating = want_meditate and not _charging

	# The body sheds reflux on its own; meditation purges it much faster.
	var shed: float = float(_reflux_cfg["shed_meditating"]) if meditating else (
		float(_reflux_cfg["shed_in_combat"]) if in_combat else float(_reflux_cfg["shed_resting"]))
	reflux = maxf(0.0, reflux - shed * delta)
	if reflux_locked and reflux < float(_reflux_cfg["unlock_below"]):
		reflux_locked = false
		note("Water affinity unlocks.")

	# The body mends itself between fights - but only what a body can mend.
	if not in_combat:
		body.heal_layer("superficial", float(_natural["superficial_per_s"]) * delta)
		body.heal_layer("structural", float(_natural["structural_per_s"]) * delta)
		if not arm_right_lost:
			arm_right = minf(float(_arm["max"]), arm_right + float(_natural["arm_per_s"]) * delta)

	var charging_input: bool = Input.is_action_pressed("overcharge") and not arm_right_lost
	if charging_input and not meditating:
		_charging = true
		_charge = minf(float(_p["charge_max"]), _charge + delta)
	elif _charging:
		_release_overcharge()

	if (Input.is_action_pressed("strike") or bot_swing) and _melee_cd <= 0.0 and not meditating and not _charging:
		_swing(float(_p["off_hand_factor"]) if arm_right_lost else 1.0, melee_range, ["melee"])
		_melee_cd = float(_p["melee_cooldown"])

	var input := Vector2.ZERO
	if not meditating:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir := Vector3(input.x, 0.0, input.y).normalized().rotated(Vector3.UP, ISO_YAW)
	if bot:
		dir = _bot_dir
	var speed: float = float(_p["move_speed"]) * (float(_p["charge_move_factor"]) if _charging else 1.0)
	velocity = dir * speed
	move_and_slide()

	rotation.y = atan2(-_facing.x, -_facing.z)
	var glow: float = _charge / float(_p["charge_max"])
	_mat.albedo_color = Color(0.15 + glow * 0.8, 0.45, 0.75 - glow * 0.5)
	if meditating:
		_mat.albedo_color = Color(0.55, 0.85, 0.95)


# --- the damage pipeline --------------------------------------------------------

## Deal damage to a hittable node. Every effect sees the hit before and after it lands.
func deal_damage(target: Node, base: float, tags: Array = []) -> HitContext:
	var ctx := HitContext.new()
	ctx.source = self
	ctx.target = target
	ctx.base = base
	for t: String in tags:
		ctx.tags.append(t)
	if not is_instance_valid(target) or bool(target.call("is_dead")):
		ctx.cancelled = true
		return ctx
	ctx.is_living = bool(target.get("is_living"))
	ctx.is_scenery = bool(target.get("is_scenery"))

	for e: TalentEffect in effects:
		e.on_outgoing(ctx)
	if bot:
		ctx.mult *= bot_damage_mult

	var pos: Vector3 = (target as Node3D).global_position
	ctx.applied = target.call("take_hit", ctx.amount(), ctx.heavy, self)
	if ctx.applied <= 0.0:
		return ctx
	if not ctx.is_scenery:
		FloatText.spawn(get_parent(), pos, "%d" % int(ctx.applied), Color(1, 1, 1))
	ctx.killed = bool(target.call("is_dead"))

	for e: TalentEffect in effects:
		e.on_dealt(ctx)
	if ctx.killed:
		_on_kill(target)
	return ctx


## Receive a hit. Effects may scale it or swallow it (ctx.cancelled).
func take_hit(amount: float, heavy: bool, source: Node) -> float:
	if dead or bot:
		return 0.0
	var ctx := HitContext.new()
	ctx.source = source
	ctx.target = self
	ctx.base = amount
	ctx.heavy = heavy
	_meditate_block = 1.0
	meditating = false
	for e: TalentEffect in effects:
		e.on_incoming(ctx)
	if ctx.cancelled:
		return 0.0
	return _apply_damage(ctx.amount(), heavy)


## Damage that has passed the pipeline (or comes from an effect's own timer).
func _apply_damage(amount: float, heavy: bool) -> float:
	var applied: float = body.apply_damage(amount, heavy)
	_float("-%d" % int(applied), Color(1, 0.25, 0.25))
	_check_death()
	return applied


## Talent healing: worst first. A lost limb is catastrophic-class, so it is always 1 point per
## unit even at Dynamic quality - this is the one thing natural healing can never do.
func _spend_heal_points(points: float) -> float:
	var left: float = points
	left -= body.heal(minf(left, body.missing("catastrophic")), false)
	if arm_right_lost and left > 0.0:
		var need: float = float(_arm["regrow_heal_points"])
		var into_arm: float = minf(left, need - _arm_regrow)
		_arm_regrow += into_arm
		left -= into_arm
		if _arm_regrow >= need:
			arm_right_lost = false
			arm_right = float(_arm["max"]) * float(_arm["regrown_by_talent_integrity"])
			_float("ARM REGROWN", Color(0.4, 1, 0.5))
			discover("Regrows lost limbs: YES")
	if left > 0.0:
		left -= body.heal(left, stars >= 2)
	return points - left


func _on_kill(target: Node) -> void:
	money += int(target.get("bounty"))
	var hurt: float = 1.0 - body.total() / body.total_max()
	var risk: float = 1.0 + hurt * float(_p["aura_hurt_risk_bonus"])
	_latent_aura += float(target.get("aura_value")) * risk


func _swing(multiplier: float, reach: float, tags: Array) -> void:
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
		if dist > 0.3 and _facing.angle_to(to / dist) > melee_arc:
			continue
		deal_damage(t, float(_p["melee_damage"]) * multiplier, tags)


func _release_overcharge() -> void:
	var c: float = _charge
	_charging = false
	_charge = 0.0
	if c < float(_p["overcharge_min_charge"]):
		return
	# Health as ammunition: the blow lands harder than the arm can bear.
	var self_cost: float = float(_p["overcharge_self_cost_base"]) + c * float(_p["overcharge_self_cost_per_charge"])
	var applied: float = body.apply_self_harm(self_cost)
	_float("arm -%d" % int(applied), Color(1, 0.4, 0.3))
	_swing(1.0 + c * float(_p["overcharge_damage_per_charge"]), melee_range + float(_p["overcharge_reach_bonus"]), ["melee", "overcharge"])
	_melee_cd = float(_p["melee_cooldown"]) * float(_p["overcharge_cooldown_factor"])

	arm_right -= self_cost * float(_arm["cost_per_self_harm"])
	if arm_right <= 0.0:
		arm_right = 0.0
		arm_right_lost = true
		_arm_regrow = 0.0
		body.damage_layer("catastrophic", float(_arm["loss_catastrophic_damage"]))
		FloatText.spawn(get_parent(), global_position + Vector3.UP * 0.6, "ARM LOST", Color(1, 0.1, 0.1))
		note("Your striking arm is destroyed. Rest will not bring it back.")
	_check_death()


func cast_bolt() -> void:
	if not active or dead or meditating:
		return
	if reflux_locked:
		note("Water affinity is locked by reflux. Meditate (hold %s)." % Keybinds.binding_text("meditate"))
		return
	var ab: Dictionary = GameData.ability("water_bolt")
	var cost: float = float(ab["cost"]) * (float(_reflux_cfg["pain_cost_mult"]) if reflux >= float(_reflux_cfg["pain_at"]) else 1.0)
	if essence < cost:
		note("Not enough essence.")
		return
	if reflux >= float(_reflux_cfg["burn_at"]):
		var burn: float = body.apply_self_harm(float(_reflux_cfg["burn_self_damage"]))
		_float("reflux -%d" % int(burn), Color(1, 0.5, 0.2))
	essence -= cost
	reflux += cost * float(ab["reflux_per_cost"])

	var bolt: Node3D = Projectile.new()
	bolt.set("dir", _facing)
	bolt.set("damage", float(ab["damage"]))
	bolt.set("speed", float(ab["speed"]))
	bolt.set("life", float(ab["life"]))
	bolt.set("shooter", self)
	get_parent().add_child(bolt)
	bolt.global_position = global_position + Vector3.UP * 1.0 + _facing * 0.8

	if reflux >= float(_reflux_cfg["lock_at"]):
		var handled := false
		for e: TalentEffect in effects:
			if e.on_reflux_cap():
				handled = true
				break
		if not handled:
			reflux_locked = true
			note("Reflux at %d - water affinity LOCKED." % int(_reflux_cfg["lock_at"]))
	_check_death()


func _check_death() -> void:
	if not dead and body.is_dead():
		dead = true
		_mat.albedo_color = Color(0.2, 0.2, 0.2)
		died.emit()


# --- between fights -----------------------------------------------------------

## Rent keeps ticking while you rest. Money may go negative: that is debt.
func charge(amount: int) -> void:
	money -= amount


func _can_afford(cost: int) -> bool:
	return money - cost >= int(_p["debt_limit"])


## Public form for the town: will anyone extend this much credit?
func can_afford(cost: int) -> bool:
	return _can_afford(cost)


## The healer sells speed, and the one thing rest cannot do: regrowth. Credit is extended to a limit.
func buy_healing() -> void:
	if arm_right_lost:
		var price: int = int(_arm["regrow_price"])
		if not _can_afford(price):
			note("Healer: regrowing an arm is $%d. Your credit won't stretch that far." % price)
			return
		money -= price
		arm_right_lost = false
		arm_right = float(_arm["max"])
		_arm_regrow = 0.0
		note("Healer: -$%d, arm regrown." % price)
		return
	for layer: String in Body.ORDER_HEAL:
		var gap: float = body.missing(layer)
		if gap <= 0.0:
			continue
		var amount: float = minf(float(_heal_cfg["hp_per_visit"]), gap)
		var cost: int = int(ceil(amount * float(_heal_cfg["price_" + layer])))
		if not _can_afford(cost):
			note("Healer: %s work costs $%d. You have $%d and no more credit." % [layer, cost, money])
			return
		money -= cost
		body.heal_layer(layer, amount)
		note("Healer: -$%d for %d %s HP." % [cost, int(amount), layer])
		return
	note("Healer: nothing to mend.")


## Standard-mode death (design/03 section 7b): dragged out, patched up, and billed for it.
## The fee is charged with no credit check - this is how a character ends up in debt.
func revive_in_debt(fee: int) -> void:
	var town: Dictionary = GameData.balance["town"]
	dead = false
	in_combat = false
	meditating = false
	effects.clear()
	set_talent(talent_id)
	_charging = false
	_charge = 0.0
	reflux = 0.0
	reflux_locked = false
	money -= fee
	# Patched up, not healed: enough to stand, and nothing lost comes back.
	body.hp["superficial"] = maxf(float(body.hp["superficial"]), float(body.max_hp["superficial"]) * float(town["revive_superficial_frac"]))
	body.hp["structural"] = maxf(float(body.hp["structural"]), float(body.max_hp["structural"]) * float(town["revive_structural_frac"]))
	body.hp["catastrophic"] = maxf(float(body.hp["catastrophic"]), float(town["revive_catastrophic_min"]))
	note("You wake on a cot. Someone dragged you out. The bill is $%d." % fee)


## A night in town: the body does what bodies do. Rent for the night is charged by the caller.
func rest_night() -> void:
	var night: Dictionary = GameData.balance["night"]
	body.heal_layer("superficial", float(body.max_hp["superficial"]))
	body.heal_layer("structural", float(night["structural_healed"]))
	if not arm_right_lost:
		arm_right = minf(float(_arm["max"]), arm_right + float(night["arm_restored"]))
	reflux = 0.0
	reflux_locked = false
	essence = essence_max
	note("You sleep. Cuts close; bones knit a little. What is gone stays gone.")


func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Node3D
		if e == null or bool(e.call("is_dead")):
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


## Test bot: returns true when it wants to swing.
func _bot_think() -> bool:
	var near: Node3D = _nearest_enemy()
	var goal: Vector3 = near.global_position if near != null else bot_goal
	var to: Vector3 = goal - global_position
	to.y = 0.0
	var dist: float = to.length()
	_bot_dir = to / dist if dist > 0.6 else Vector3.ZERO
	if dist > 0.2:
		_facing = to / dist
	if near == null:
		return false
	return dist <= melee_range + float(near.get("radius"))


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
	return "The star strains against itself.  %s to ascend" % Keybinds.binding_text("ascend")


func try_ascend() -> void:
	if stars >= 2 or _latent_aura < _aura_threshold:
		note("Nothing happens. The star is not ready.")
		return
	var asc: Dictionary = GameData.balance["ascension_2"]
	_latent_aura -= _aura_threshold
	stars = 2
	essence_max = float(asc["essence_max"])
	essence = essence_max
	satellite_rate = float(asc["satellite_rate"])   # placeholder: satellites become items (Brent 2026-09-23)
	body.scale_max(float(asc["body_scale"]))
	reflux = 0.0
	reflux_locked = false
	for e: TalentEffect in effects:
		e.on_ascend(stars)
	note("ASCENDED to two stars. A second tank.")
	note("Talent evolves: %s" % str(talent.get("evolve_2", "?")))
	if talent_id != "one_percent_lifesteal":
		note("(this talent's evolution is not wired into the prototype yet)")


# --- helpers ------------------------------------------------------------------

## Extra notebook lines contributed by effects (e.g. damage still owed).
func status_lines() -> Array[String]:
	var out: Array[String] = []
	for e: TalentEffect in effects:
		out.append_array(e.status_lines())
	return out


func discover(line: String) -> void:
	if not discoveries.has(line):
		discoveries.append(line)
		note("Proven - %s" % line)


func note(line: String) -> void:
	log_lines.append(line)
	while log_lines.size() > 5:
		log_lines.remove_at(0)


func _float(txt: String, color: Color) -> void:
	if is_inside_tree():
		FloatText.spawn(get_parent(), global_position, txt, color)


func _text(target: Node, txt: String, color: Color) -> void:
	if is_inside_tree():
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
