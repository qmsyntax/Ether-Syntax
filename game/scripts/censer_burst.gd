class_name CenserBurst
extends Node3D
## What a Censer-Bearer leaves when it dies (design/05 6.1): the censer flares for `delay`
## seconds, then bursts - every enemy within `radius` at that moment is healed `heal_frac` of its
## full health and takes `status` (frenzied). The delay is the player's window: shove the pack
## away, or have killed it somewhere else.

var radius := 4.0
var delay := 0.8
var heal_frac := 0.4
var status := "frenzied"
var color := Color(1.0, 0.95, 0.85)

var _ring: MeshInstance3D
var _mat: StandardMaterial3D
var _t := 0.0
var _done := false


func _ready() -> void:
	add_to_group("censer_bursts")
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.14
	torus.outer_radius = radius
	torus.rings = 48
	torus.ring_segments = 6
	_ring.mesh = torus
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(color, 0.5)
	_ring.material_override = _mat
	_ring.position.y = 0.08
	_ring.scale.y = 0.2
	add_child(_ring)


func _physics_process(delta: float) -> void:
	tick(delta)


## One step. Public so a test can run it by hand.
func tick(delta: float) -> void:
	if _done:
		return
	_t += delta
	# flares brighter and faster as it comes due
	_mat.albedo_color = Color(color, 0.45 + 0.5 * absf(sin(_t * (10.0 + 20.0 * _t / maxf(delay, 0.01)))))
	if _t < delay:
		return
	_done = true
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Node3D
		if e == null or bool(e.call("is_dead")):
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		if to.length() > radius + float(e.get("radius")):
			continue
		var b: Body = e.get("body")
		if not (e.has_method("blocks_heal") and bool(e.call("blocks_heal"))):
			b.heal(b.total_max() * heal_frac)
		e.call("add_status", status)
	queue_free()
