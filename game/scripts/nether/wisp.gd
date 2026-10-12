extends Node3D
## A drifting mote of attuned ether. Touch it with the projection to gather it.

var affinity := "plain"
var _t := 0.0
var _home := Vector3.ZERO


func setup(wisp_affinity: String) -> void:
	affinity = wisp_affinity
	add_child(NetherArt.wisp(affinity))
	add_to_group("nether_wisps")
	_t = randf() * 10.0


func _ready() -> void:
	_home = position


func _process(delta: float) -> void:
	_t += delta
	position = _home + Vector3(sin(_t * 0.7) * 0.5, 0.0, cos(_t * 0.5) * 0.5)


func gather() -> void:
	remove_from_group("nether_wisps")
	queue_free()
