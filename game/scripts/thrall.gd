class_name Thrall
extends CharacterBody3D
## A corpse raised to fight for its caster (Death's Rise Again, 2026-10-22 drafts) - a simple
## allied fighter: it walks to the nearest enemy and strikes it every `attack_s` for `damage`,
## through the caster's apply_hit (so its kills are the caster's, with every on-kill rule). Enemies
## close to it may turn on it (it is a lure with a short reach, see Lure / enemy._pick_target);
## it has `hp` and falls apart when that or its `life` runs out. It is not living.

var caster: Node
var life := 15.0
var hp := 120.0
var damage := 15.0
var attack_s := 1.2
var speed := 5.0
var reach := 1.6
var lure_radius := 2.5
var tags: Array = []
var dead := false
var radius := 0.45
var is_scenery := false
var is_living := false

var _cd := 0.0
var _rig: ModelRig


func _ready() -> void:
	add_to_group("lures")
	add_to_group("thralls")
	collision_layer = 0
	collision_mask = 1
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.7
	col.shape = shape
	col.position.y = 0.85
	add_child(col)
	_rig = Models.enemy("grunt")
	add_child(_rig)
	if _rig.has_method("set_dead_look"):
		_rig.set_dead_look()


func _physics_process(delta: float) -> void:
	tick(delta)


## One step. Public so a test can run it by hand.
func tick(delta: float) -> void:
	if dead:
		return
	life -= delta
	_cd -= delta
	if life <= 0.0 or hp <= 0.0:
		_fall()
		return
	var foe: Node3D = _nearest_enemy()
	velocity = Vector3.ZERO
	if foe != null:
		var to: Vector3 = foe.global_position - global_position
		to.y = 0.0
		if to.length() > 0.05:
			rotation.y = atan2(-to.x, -to.z)
		if to.length() > reach + float(foe.get("radius")):
			move_and_collide(to.normalized() * minf(speed * delta, to.length()))
		elif _cd <= 0.0 and is_instance_valid(caster):
			_cd = attack_s
			caster.call("apply_hit", foe, {"damage": damage}, tags + ["thrall"])
	if _rig != null:
		_rig.animate(delta, speed if foe != null else 0.0, _cd > attack_s - 0.25)


func is_dead() -> bool:
	return dead


func take_hit(amount: float, _heavy: bool, _source: Node, _tags: Array = []) -> float:
	if dead:
		return 0.0
	hp -= amount
	if _rig != null:
		_rig.flash(0.1)
	if hp <= 0.0:
		_fall()
	return amount


func claim_slot(_enemy: Node) -> bool:
	return true


func release_slot(_enemy: Node) -> void:
	pass


func shove(_dir: Vector3, _metres: float) -> void:
	pass


func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Node3D
		if e == null or bool(e.call("is_dead")):
			continue
		if best == null or e.global_position.distance_to(global_position) < best.global_position.distance_to(global_position):
			best = e
	return best


func _fall() -> void:
	dead = true
	remove_from_group("lures")
	remove_from_group("thralls")
	queue_free()
