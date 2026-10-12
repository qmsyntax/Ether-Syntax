extends Node3D
## Living scenery. It is alive, so it counts for talents that care about harming the living.

var body: Body
var is_living := true
var is_scenery := true
var radius := 0.4
var height := 0.8
var highlight := 0
var aura_value := 0.0
var bounty := 0

var _rig: ModelRig


func setup(kind: String) -> void:
	if kind == "bush":
		body = Body.new(GameData.num("scenery", "bush_hp"))
		radius = 0.7
		height = 1.1
	else:
		body = Body.new(GameData.num("scenery", "grass_hp"))
		height = 0.8
	_rig = Models.scenery(kind) as ModelRig
	add_child(_rig)
	add_to_group("hittable")


func is_dead() -> bool:
	return body.is_dead()


func take_hit(amount: float, _heavy: bool, _source: Node) -> float:
	var applied: float = body.apply_damage(amount)
	var frac: float = body.total() / body.total_max()
	_rig.scale = Vector3.ONE * maxf(0.3, frac)
	_rig.flash(0.08)
	if body.is_dead():
		remove_from_group("hittable")
		queue_free()
	return applied


## Called by the player's hover logic; scenery has no per-frame update of its own.
func set_highlight(level: int) -> void:
	highlight = level
	if _rig != null:
		_rig.set_highlight(level)
