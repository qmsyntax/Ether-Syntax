class_name ScaldBurst
extends Node3D
## What a Kettle Beetle leaves when it dies (enemies.json death_burst kind "scald"): its shell
## splits and, after `delay` seconds, bursts in scalding steam - anyone within `radius` at that
## moment takes `damage`. A ring on the ground fills as it comes due; the delay is the player's
## window to step out of it (or to have killed the beetle somewhere better). Hurts the player only:
## the other beasts are not the beetle's concern.

var radius := 2.6
var delay := 1.1
var damage := 22.0
var color := Color(1.0, 0.78, 0.6)
## Whom it can scald (the player the beetle was fighting).
var victim: Node3D

var _ring: MeshInstance3D
var _fill: MeshInstance3D
var _mat: StandardMaterial3D
var _fill_mat: StandardMaterial3D
var _t := 0.0
var _done := false


## Leave one at `at` (world) under `parent`, from a death_burst definition; damage scales with the
## beetle's strength factor. `who` is the one it can hurt.
static func leave(parent: Node, at: Vector3, cfg: Dictionary, strength: float, who: Node3D) -> ScaldBurst:
	var b := ScaldBurst.new()
	b.victim = who
	b.radius = float(cfg.get("radius", 2.6))
	b.delay = float(cfg.get("delay", 1.1))
	b.damage = float(cfg.get("damage", 22.0)) * strength
	var c: Array = cfg.get("color", [1.0, 0.78, 0.6])
	b.color = Color(float(c[0]), float(c[1]), float(c[2]))
	parent.add_child(b)
	b.global_position = Vector3(at.x, at.y, at.z)
	return b


func _ready() -> void:
	add_to_group("scald_bursts")
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(color, 0.7)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.12
	torus.outer_radius = radius
	torus.rings = 48
	torus.ring_segments = 6
	_ring.mesh = torus
	_ring.material_override = _mat
	_ring.position.y = 0.08
	_ring.scale.y = 0.2
	add_child(_ring)
	_fill_mat = StandardMaterial3D.new()
	_fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fill_mat.albedo_color = Color(color, 0.18)
	_fill = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.02
	disc.radial_segments = 40
	_fill.mesh = disc
	_fill.material_override = _fill_mat
	_fill.position.y = 0.05
	_fill.scale = Vector3(0.05, 1.0, 0.05)
	add_child(_fill)


func _physics_process(delta: float) -> void:
	tick(delta)


## One step. Public so a test can run it by hand.
func tick(delta: float) -> void:
	if _done:
		return
	_t += delta
	var frac: float = clampf(_t / maxf(delay, 0.01), 0.0, 1.0)
	_fill.scale = Vector3(maxf(0.05, frac), 1.0, maxf(0.05, frac))
	_mat.albedo_color = Color(color, 0.5 + 0.45 * absf(sin(_t * (8.0 + 18.0 * frac))))
	if _t < delay:
		return
	_done = true
	if is_inside_tree():
		if victim != null and is_instance_valid(victim):
			_scald(victim)
		FloatText.spawn(get_parent(), global_position + Vector3.UP * 0.8, "SCALD", color)
	queue_free()


func _scald(who: Node3D) -> void:
	if who == null or not who.has_method("take_hit") or bool(who.get("dead")):
		return
	var to: Vector3 = who.global_position - global_position
	to.y = 0.0
	if to.length() <= radius:
		who.call("take_hit", damage, false, self)


const FloatText := preload("res://scripts/float_text.gd")
