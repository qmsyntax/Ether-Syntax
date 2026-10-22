class_name GrowthPatch
extends Node3D
## A patch of a Nature caster's growth (2026-10-22 drafts): one `kind` (bramble or snarevine, rules
## in affinities.json nature.growth), `radius` across, that ages - sprout, grown, bloom (growth.ages
## seconds) - and works growth.age_mult harder with each age. Every growth.spread_every seconds a
## grown or blooming patch puts out a sprout beside it, while the caster has fewer than growth.max.
## Its payload lands through the caster (bramble: on whoever moves inside, every tick; snarevine: on
## whoever comes in, once every tick_s per enemy). A patch stays until it is cut, wilted or the
## level is left. Not built: burning away, soil rules, enemies routing round it.

var caster: Node
var kind := "bramble"
var radius := 1.0
var age_t := 0.0
## Greening: everything works this much harder until boost_t runs out.
var boost := 1.0
var boost_t := 0.0
var color := Color(0.3, 0.68, 0.35)

var _tick := 0.0
var _spread_t := 0.0
var _last: Dictionary = {}            # snarevine: enemy instance id -> seconds since it was held
var _mesh: MeshInstance3D


func _ready() -> void:
	add_to_group("growth")
	_mesh = MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.darkened(0.2) if kind == "bramble" else color.lightened(0.1), 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh.material_override = mat
	_mesh.position.y = 0.05
	add_child(_mesh)
	_resize()


func _cfg() -> Dictionary:
	return GameData.affinity("nature").get("growth", {})


## 0 sprout, 1 grown, 2 bloom.
func age() -> int:
	var ages: Array = _cfg().get("ages", [5.0, 15.0])
	if age_t >= float(ages[1]):
		return 2
	if age_t >= float(ages[0]):
		return 1
	return 0


## How hard it works: its age's multiplier, and Greening's while it lasts.
func mult() -> float:
	var m: Array = _cfg().get("age_mult", [1.0, 1.5, 2.0])
	return float(m[age()]) * (boost if boost_t > 0.0 else 1.0)


## Grow `ages` ages at once (Greening).
func grow(ages: int) -> void:
	var steps: Array = _cfg().get("ages", [5.0, 15.0])
	for i: int in ages:
		var a: int = age()
		if a < steps.size():
			age_t = float(steps[a])
	_resize()


## Cut back to a sprout (Reaping Sweep): the roots stay.
func cut_back() -> void:
	age_t = 0.0
	_resize()


func _resize() -> void:
	if _mesh == null:
		return
	var disc := CylinderMesh.new()
	disc.top_radius = radius * (0.7 + 0.15 * float(age()))
	disc.bottom_radius = disc.top_radius
	disc.height = 0.1 + 0.1 * float(age())
	disc.radial_segments = 14
	_mesh.mesh = disc


func _physics_process(delta: float) -> void:
	tick(delta)


## One step. Public so a test can run it by hand.
func tick(delta: float) -> void:
	var was: int = age()
	age_t += delta
	boost_t -= delta
	if age() != was:
		_resize()
	var cfg: Dictionary = _cfg()
	var rule: Dictionary = cfg.get(kind, {})
	var every: float = float(rule.get("tick_s", 1.0))
	for k: Variant in _last.keys():
		_last[k] = float(_last[k]) + delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = every if kind == "bramble" else 0.25
		for e: Node3D in inside():
			var key: int = e.get_instance_id()
			if kind == "snarevine":
				if _last.has(key) and float(_last[key]) < every:
					continue
				_last[key] = 0.0
			elif (e as CharacterBody3D) != null and (e as CharacterBody3D).velocity.length() < 0.1:
				continue                     # brambles only bite what moves
			var payload: Dictionary = (rule.get("payload", {}) as Dictionary).duplicate()
			if payload.has("damage"):
				payload["damage"] = float(payload["damage"]) * every * mult()
			payload["status_time_mult"] = mult()
			if is_instance_valid(caster):
				caster.call("apply_hit", e, payload, ["nature", "growth", "dot"])
	if age() >= 1:
		_spread_t += delta
		if _spread_t >= float(cfg.get("spread_every", 5.0)):
			_spread_t = 0.0
			spread()


## Put out one new sprout beside it, if the caster has room for another patch.
func spread() -> void:
	if not is_instance_valid(caster) or not is_inside_tree():
		return
	var a: float = randf() * TAU
	var at: Vector3 = global_position + Vector3(cos(a), 0.0, sin(a)) * radius * 1.8
	caster.call("plant_growth", at, {"kind": kind, "radius": radius})


func has_point(point: Vector3, margin: float = 0.0) -> bool:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length() <= radius + margin


func inside() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if not is_inside_tree():
		return out
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Node3D
		if e != null and not bool(e.call("is_dead")) and has_point(e.global_position, float(e.get("radius"))):
			out.append(e)
	return out


## Gone for good (Sere Ground, a new place).
func wilt() -> void:
	remove_from_group("growth")
	queue_free()
