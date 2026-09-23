extends Control
## Controls menu: click an action, press the key or mouse button you want. Esc cancels a capture
## or closes the menu. Runs while the tree is paused.

signal closed

var _rows: Dictionary = {}          # action -> Button
var _capturing := ""
var _armed_ms := 0
var _status: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.position = Vector2(480, 80)
	panel.custom_minimum_size = Vector2(620, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.09, 0.11, 1.0)
	style.border_color = Color(0.35, 0.35, 0.4)
	style.set_border_width_all(1)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var title := Label.new()
	title.text = "CONTROLS"
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Click an action, then press the key or mouse button you want. Esc closes."
	sub.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	box.add_child(sub)

	for action: String in Keybinds.action_names():
		var row := HBoxContainer.new()
		var name := Label.new()
		name.text = Keybinds.label_for(action)
		name.custom_minimum_size = Vector2(300, 0)
		row.add_child(name)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(200, 30)
		btn.pressed.connect(_begin_capture.bind(action))
		row.add_child(btn)
		box.add_child(row)
		_rows[action] = btn

	_status = Label.new()
	_status.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	box.add_child(_status)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	var reset := Button.new()
	reset.text = "Reset to defaults"
	reset.pressed.connect(_reset)
	buttons.add_child(reset)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(_close)
	buttons.add_child(close)
	box.add_child(buttons)

	_refresh()


func _refresh() -> void:
	for action: String in _rows:
		var btn: Button = _rows[action]
		btn.text = "press a key..." if action == _capturing else Keybinds.binding_text(action)


func _begin_capture(action: String) -> void:
	_capturing = action
	_armed_ms = Time.get_ticks_msec()
	_status.text = ""
	_refresh()


func _input(event: InputEvent) -> void:
	if _capturing == "":
		var key := event as InputEventKey
		if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_ESCAPE:
			_close()
			get_viewport().set_input_as_handled()
		return
	# Ignore the click that opened the capture and any motion.
	if Time.get_ticks_msec() - _armed_ms < 200:
		return
	var key := event as InputEventKey
	var mouse := event as InputEventMouseButton
	if key != null and key.pressed and not key.echo:
		if key.physical_keycode == KEY_ESCAPE:
			_capturing = ""
			_status.text = "Cancelled."
		else:
			_apply(key)
		get_viewport().set_input_as_handled()
	elif mouse != null and mouse.pressed:
		_apply(mouse)
		get_viewport().set_input_as_handled()


func _apply(event: InputEvent) -> void:
	var action: String = _capturing
	_capturing = ""
	var displaced: String = Keybinds.rebind(action, event)
	_status.text = "%s is now %s." % [Keybinds.label_for(action), Keybinds.describe(event)]
	if displaced != "":
		_status.text += "  %s is now unbound - give it a key." % Keybinds.label_for(displaced)
	_refresh()


func _reset() -> void:
	Keybinds.reset_defaults()
	_capturing = ""
	_status.text = "Defaults restored."
	_refresh()


func _close() -> void:
	closed.emit()
	queue_free()
