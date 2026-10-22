class_name SeedTrap
extends Node3D
## A hidden seed (Nature's Scatter Seed, kind 'seed'): it lies in the ground until an enemy comes
## within `trigger_radius`, or `delay` passes, then bursts - `payload` to every enemy within
## `burst_radius` through the caster, and a growth patch of `growth` where it stood. Unsprouted
## seeds wither after `life`.

var caster: Node
var payload: Dictionary = {}
var tags: Array = []
var stage_mult := 1.0
var trigger_radius := 0.6
var burst_radius := 1.2
var delay := 6.0
var life := 20.0
var growth: Dictionary = {}
var color := Color(0.4, 0.8, 0.4)

var _t := 0.0
var _done := false


func _ready() -> void:
	add_to_group("seeds")
	var mesh := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.08
	s.height = 0.12
	mesh.mesh = s
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = mat
	mesh.position.y = 0.04
	add_child(mesh)


func _physics_process(delta: float) -> void:
	tick(delta)


## One step. Public so a test can run it by hand.
func tick(delta: float) -> void:
	if _done:
		return
	_t += delta
	if _t >= life:
		_done = true
		queue_free()
		return
	var due: bool = _t >= delay
	if not due and is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group("enemies"):
			var e := node as Node3D
			if e != null and not bool(e.call("is_dead")) and Vector2(e.global_position.x - global_position.x, e.global_position.z - global_position.z).length() <= trigger_radius + float(e.get("radius")):
				due = true
				break
	if due:
		_burst()


func _burst() -> void:
	_done = true
	if is_instance_valid(caster) and is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group("enemies"):
			var e := node as Node3D
			if e != null and not bool(e.call("is_dead")) and Vector2(e.global_position.x - global_position.x, e.global_position.z - global_position.z).length() <= burst_radius + float(e.get("radius")):
				caster.call("apply_hit", e, payload, tags, stage_mult)
		if not growth.is_empty():
			caster.call("plant_growth", global_position, growth)
	queue_free()
