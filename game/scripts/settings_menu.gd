extends Control
## Controls menu: click an action, press the key or mouse button you want. Esc cancels a capture
## or closes the menu. Runs while the tree is paused.

signal closed

## The controls in groups, two columns of them. An action not named here (a new one) is listed
## under "Other", so nothing bindable is ever missing from the menu.
const GROUPS: Array = [
	["Movement", ["move_up", "move_down", "move_left", "move_right"], 0],
	["Combat", ["strike", "overcharge", "ranged_stance"], 0],
	["Skills", ["ability_1", "ability_2", "ability_3", "ability_4", "ability_5", "ability_6"], 0],
	["Soul", ["meditate", "ascend", "bind", "project"], 1],
	["Screens", ["inventory", "ethercosm", "settings"], 1],
	["Town and passage", ["interact", "healer", "rest", "go_now", "restart"], 1],
]

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
	panel.anchor_left = 0.17
	panel.anchor_right = 0.83
	panel.anchor_top = 0.06
	panel.anchor_bottom = 0.94
	panel.offset_left = 0
	panel.offset_right = 0
	panel.offset_top = 0
	panel.offset_bottom = 0
	add_child(panel)
	var outer := VBoxContainer.new()
	panel.add_child(outer)
	outer.add_child(UiTheme.heading("Controls", UiTheme.FS_TITLE))
	outer.add_child(UiTheme.body("Click a key, then press the key or mouse button you want for it. Esc cancels, or closes this menu.", UiTheme.FS_SMALL, UiTheme.TEXT_DIM))
	outer.add_child(UiTheme.rule())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var cols := HBoxContainer.new()
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 40)
	scroll.add_child(cols)
	var column: Array[VBoxContainer] = []
	for i: int in 2:
		var c := VBoxContainer.new()
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.add_theme_constant_override("separation", 4)
		cols.add_child(c)
		column.append(c)

	var listed: Dictionary = {}
	var groups: Array = GROUPS.duplicate(true)
	var other: Array = []
	for action: String in Keybinds.action_names():
		var found := false
		for g: Array in groups:
			if (g[1] as Array).has(action):
				found = true
		if not found:
			other.append(action)
	if not other.is_empty():
		groups.append(["Other", other, 1])
	for g: Array in groups:
		var box: VBoxContainer = column[int(g[2])]
		if box.get_child_count() > 0:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 8)
			box.add_child(gap)
		box.add_child(UiTheme.section(str(g[0])))
		for action: String in g[1]:
			if not Keybinds.action_names().has(action) or listed.has(action):
				continue
			listed[action] = true
			var row := HBoxContainer.new()
			var name := UiTheme.body(Keybinds.label_for(action), UiTheme.FS_BODY, UiTheme.TEXT)
			name.autowrap_mode = TextServer.AUTOWRAP_OFF
			name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(name)
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(132, 32)
			btn.focus_mode = Control.FOCUS_NONE
			btn.add_theme_font_size_override("font_size", UiTheme.FS_BODY)
			btn.pressed.connect(_begin_capture.bind(action))
			row.add_child(btn)
			box.add_child(row)
			_rows[action] = btn

	outer.add_child(UiTheme.rule())
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	outer.add_child(foot)
	_status = Label.new()
	_status.add_theme_color_override("font_color", UiTheme.GOLD)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot.add_child(_status)
	var reset := Button.new()
	reset.text = "Reset to defaults"
	reset.pressed.connect(_reset)
	foot.add_child(reset)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(110, 0)
	close.pressed.connect(_close)
	foot.add_child(close)

	_refresh()


func _refresh() -> void:
	for action: String in _rows:
		var btn: Button = _rows[action]
		btn.text = "press a key..." if action == _capturing else Keybinds.binding_text(action)
		btn.add_theme_color_override("font_color", UiTheme.GOLD if action == _capturing else UiTheme.TEXT)


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
