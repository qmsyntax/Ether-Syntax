class_name SkillTimer
extends Node
## Something a skill does later, on game time: `what` after `delay` seconds, then `repeats` more
## times every `every` seconds (a delayed smite, the beats of a heart). It is
## a node in the level so it is cleared with the level and stepped by the physics frame - a test
## can step it by hand with tick(). The callable gets the count of the call (0, 1, ...).

var delay := 0.5
var every := 0.5
var repeats := 0
var what: Callable

var _t := 0.0
var _done := 0


static func after(parent: Node, seconds: float, fn: Callable, more: int = 0, gap: float = 0.5) -> SkillTimer:
	var t := SkillTimer.new()
	t.delay = seconds
	t.what = fn
	t.repeats = more
	t.every = gap
	parent.add_child(t)
	return t


func _physics_process(delta: float) -> void:
	tick(delta)


## One step. Public so a test can run it by hand.
func tick(delta: float) -> void:
	_t += delta
	var due: float = delay + every * float(_done)
	while _t >= due and _done <= repeats:
		if what.is_valid():
			what.call(_done)
		_done += 1
		due = delay + every * float(_done)
	if _done > repeats:
		queue_free()
