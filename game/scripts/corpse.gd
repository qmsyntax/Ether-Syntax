extends Node3D
## Your own body, lying where you died (Brent 2026-10-18: corpse runs). Everything you wore and
## carried is on it. Click it to walk over and take it all back. It answers to the same calls as
## a ground item (scripts/pickup.gd), so clicking and highlighting work the same way.

var corpse_id := ""
var item_id := ""                     # empty: this is not an item, see Player.take_pickup
var radius := 0.6
var height := 0.4
var highlight := 0
var is_scenery := false
var is_pickup := true

var _rig: ModelRig
var _label: Label3D


func setup(id: String, look: Dictionary) -> void:
	corpse_id = id
	_rig = CharacterLook.build(look)
	_rig.rotation_degrees = Vector3(-90.0, 30.0, 0.0)       # face down where it fell
	_rig.position = Vector3(0.0, 0.18, 0.7)
	add_child(_rig)
	if _rig.has_method("set_dead_look"):
		_rig.set_dead_look()
	_label = Label3D.new()
	_label.text = "Your corpse"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 32
	_label.outline_size = 8
	_label.pixel_size = 0.01
	_label.position.y = 1.0
	_label.modulate = Color(1.0, 0.8, 0.7, 0.85)
	add_child(_label)
	add_to_group("pickups")
	add_to_group("corpses")


func is_dead() -> bool:
	return is_queued_for_deletion()


func set_highlight(level: int) -> void:
	highlight = level
	_label.font_size = 38 if level > 0 else 32
	if _rig != null:
		_rig.set_highlight(level)


func take() -> void:
	remove_from_group("pickups")
	remove_from_group("corpses")
	queue_free()
