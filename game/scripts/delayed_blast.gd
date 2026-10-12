class_name DelayedBlast
extends Node3D
## A marked circle on the ground that goes off after `delay` (design/05 Appendix A, delayed_blast):
## the mark is the warning - for the enemy, and for you. When it is due the caster's land_blast()
## does the work, so talents and affinity rules see it as the caster's doing.

var caster: Node
var ab: Dictionary = {}
var stage_mult := 1.0
var tags: Array = []
var radius := 2.0
var delay := 0.5
var color := Color(1.0, 0.9, 0.7)

var _t := 0.0
var _done := false
var _mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("blasts")
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.outer_radius = radius
	torus.inner_radius = maxf(0.05, radius - 0.1)
	torus.rings = 40
	torus.ring_segments = 6
	ring.mesh = torus
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(color, 0.6)
	ring.material_override = _mat
	ring.position.y = 0.07
	ring.scale.y = 0.2
	add_child(ring)


func _physics_process(delta: float) -> void:
	tick(delta)


## One step. Public so a test can run it by hand.
func tick(delta: float) -> void:
	if _done:
		return
	_t += delta
	_mat.albedo_color = Color(color, 0.4 + 0.6 * clampf(_t / maxf(delay, 0.01), 0.0, 1.0))
	if _t < delay:
		return
	_done = true
	if is_instance_valid(caster) and caster.has_method("land_blast"):
		caster.call("land_blast", global_position, ab, stage_mult, tags)
	queue_free()
