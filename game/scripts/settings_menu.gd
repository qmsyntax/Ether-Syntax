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
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.3
	panel.anchor_right = 0.7
	panel.anchor_top = 0.04
	panel.anchor_bottom = 0.96
	panel.offset_left = 0
	panel.offset_right = 0
	panel.offset_top = 0
	panel.offset_bottom = 0
	add_child(panel)
	var outer := VBoxContainer.new()
	panel.add_child(outer)
	outer.add_child(UiTheme.heading("Controls", 30))
	outer.add_child(UiTheme.body("Click an action, then press the key or mouse button you want. Esc closes.", 14, UiTheme.TEXT_DIM))
	outer.add_child(UiTheme.rule())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	scroll.add_child(box)

	for action: String in Keybinds.action_names():
		var row := HBoxContainer.new()
		var name := Label.new()
		name.text = Keybinds.label_for(action)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(190, 30)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_begin_capture.bind(action))
		row.add_child(btn)
		box.add_child(row)
		_rows[action] = btn

	outer.add_child(UiTheme.rule())
	_status = Label.new()
	_status.add_theme_color_override("font_color", UiTheme.GOLD)
	outer.add_child(_status)

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
	outer.add_child(buttons)

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
