class_name Lure
extends Node3D
## A thing enemies take for you (2026-10-22 drafts: Dream's phantom, Death's grave-dust likeness):
## while it stands, every enemy within `lure_radius` that is fighting turns on it instead of the
## player (enemy.gd _pick_target): melee walk to it and strike it, archers aim at it. It has `hp`
## and breaks after `breaks_on_hits` blows (0 = only when the health is gone), or when `life` runs
## out. When it breaks, `collapse` (a hit payload) lands on everyone within `collapse_radius`
## through the caster. It blocks nothing.

var caster: Node
var life := 3.0
var hp := 1.0
var lure_radius := 8.0
var breaks_on_hits := 1
var collapse: Dictionary = {}
var collapse_radius := 0.0
var color := Color(0.9, 0.7, 1.0)
var tags: Array = []
var dead := false
var radius := 0.4
var is_scenery := false
var is_living := false

var _hits := 0
var _mesh: MeshInstance3D


func _ready() -> void:
	add_to_group("lures")
	_mesh = MeshInstance3D.new()
	var body := CapsuleMesh.new()
	body.radius = 0.35
	body.height = 1.75
	_mesh.mesh = body
	_mesh.position.y = 0.9
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color, 0.45)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.8
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh.material_override = mat
	add_child(_mesh)


func _physics_process(delta: float) -> void:
	tick(delta)


## One step. Public so a test can run it by hand.
func tick(delta: float) -> void:
	if dead:
		return
	life -= delta
	if life <= 0.0:
		_break()


func is_dead() -> bool:
	return dead


## An enemy's blow lands on it instead of on you.
func take_hit(amount: float, _heavy: bool, _source: Node, _tags: Array = []) -> float:
	if dead:
		return 0.0
	hp -= amount
	_hits += 1
	if hp <= 0.0 or (breaks_on_hits > 0 and _hits >= breaks_on_hits):
		_break()
	return amount


## It holds the slots round it like a player does: anyone who comes for it may strike.
func claim_slot(_enemy: Node) -> bool:
	return true


func release_slot(_enemy: Node) -> void:
	pass


func shove(_dir: Vector3, _metres: float) -> void:
	pass


func _break() -> void:
	if dead:
		return
	dead = true
	remove_from_group("lures")
	if collapse_radius > 0.0 and not collapse.is_empty() and is_instance_valid(caster) and is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group("enemies"):
			var e := node as Node3D
			if e != null and not bool(e.call("is_dead")) and Vector2(e.global_position.x - global_position.x, e.global_position.z - global_position.z).length() <= collapse_radius + float(e.get("radius")):
				caster.call("apply_hit", e, collapse, tags + ["collapse"])
	queue_free()
