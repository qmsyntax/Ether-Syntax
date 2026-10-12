class_name EnvGate
extends Node3D
## The barrier that seals a chamber, in a biome's own language (see Biomes.gate). The frame
## stays; set_open() moves the barrier out of the way (a portcullis rises, an ice wall sinks,
## a rockfall drops away) and hides it once it has gone.

## The part that blocks the way.
var barrier: Node3D
## Where the barrier travels to when open, relative to its closed position.
var open_shift := Vector3(0, 3, 0)
## Seconds the move takes.
var travel_time: float = 0.6
## Clear width between the frame's posts, in metres.
var width: float = 4.0

var _closed_at := Vector3.ZERO
var _open: bool = false
var _t: float = 0.0


func _ready() -> void:
	if barrier != null:
		_closed_at = barrier.position
	_apply()
	set_process(false)


## Opens (true) or seals (false) the gate. `instant` skips the animation.
func set_open(open: bool, instant: bool = false) -> void:
	_open = open
	if instant or not is_inside_tree():
		_t = 1.0 if open else 0.0
		_apply()
		return
	set_process(true)


## True once the gate has been told to open.
func is_open() -> bool:
	return _open


func _process(delta: float) -> void:
	_t = move_toward(_t, 1.0 if _open else 0.0, delta / maxf(travel_time, 0.01))
	_apply()
	if _t == (1.0 if _open else 0.0):
		set_process(false)


func _apply() -> void:
	if barrier == null:
		return
	barrier.visible = _t < 0.999
	barrier.position = _closed_at + open_shift * smoothstep(0.0, 1.0, _t)
