extends Node
## Autoload: every rebindable control is an InputMap action with exactly one binding.
## Defaults live here; the player's overrides are saved to user://keybinds.cfg.
## Menu choices (number keys on the talent/town screens) are not actions and are not rebindable.

const SAVE_PATH := "user://keybinds.cfg"

## action -> [label, default event]. Order is the order the settings screen lists them.
const ACTIONS: Array = [
	["move_up", "Move up", "key", KEY_W],
	["move_down", "Move down", "key", KEY_S],
	["move_left", "Move left", "key", KEY_A],
	["move_right", "Move right", "key", KEY_D],
	["strike", "Strike", "mouse", MOUSE_BUTTON_LEFT],
	["overcharge", "Overcharge (hold)", "mouse", MOUSE_BUTTON_RIGHT],
	["ability_1", "Ability slot 1", "key", KEY_1],
	["ability_2", "Ability slot 2", "key", KEY_2],
	["ability_3", "Ability slot 3", "key", KEY_3],
	["ability_4", "Ability slot 4", "key", KEY_4],
	["ability_5", "Ability slot 5", "key", KEY_5],
	["ability_6", "Ability slot 6", "key", KEY_6],
	["meditate", "Meditate (hold)", "key", KEY_M],
	["ascend", "Ascend", "key", KEY_T],
	["bind", "Bind a construct", "key", KEY_B],
	["inventory", "Inventory", "key", KEY_I],
	["ethercosm", "Ethercosm (soul)", "key", KEY_K],
	["project", "Project into the Netherecho", "key", KEY_N],
	["interact", "Use exit / leave", "key", KEY_F],
	["healer", "Healer", "key", KEY_H],
	["rest", "Rest", "key", KEY_E],
	["go_now", "Skip the rest", "key", KEY_SPACE],
	["restart", "Start over", "key", KEY_R],
	["settings", "Controls menu", "key", KEY_ESCAPE],
]

signal changed


func _enter_tree() -> void:
	for a: Array in ACTIONS:
		var action: String = a[0]
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		_set_binding(action, _default_event(a))
	_load()


func action_names() -> Array[String]:
	var out: Array[String] = []
	for a: Array in ACTIONS:
		out.append(a[0])
	return out


func label_for(action: String) -> String:
	for a: Array in ACTIONS:
		if a[0] == action:
			return a[1]
	return action


## Human-readable name of the current binding, e.g. "W", "Space", "LMB".
func binding_text(action: String) -> String:
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	if events.is_empty():
		return "(none)"
	return describe(events[0])


static func describe(event: InputEvent) -> String:
	var key := event as InputEventKey
	if key != null:
		# Show the key as the user's layout labels it; headless has no layout to ask.
		var code: Key = key.physical_keycode
		if DisplayServer.get_name() != "headless":
			var mapped: Key = DisplayServer.keyboard_get_keycode_from_physical(key.physical_keycode)
			if mapped != KEY_NONE:
				code = mapped
		return OS.get_keycode_string(code)
	var mouse := event as InputEventMouseButton
	if mouse != null:
		match mouse.button_index:
			MOUSE_BUTTON_LEFT: return "LMB"
			MOUSE_BUTTON_RIGHT: return "RMB"
			MOUSE_BUTTON_MIDDLE: return "MMB"
			MOUSE_BUTTON_WHEEL_UP: return "Wheel up"
			MOUSE_BUTTON_WHEEL_DOWN: return "Wheel down"
			_: return "Mouse %d" % mouse.button_index
	return "?"


## Bind `event` to `action`. If another action held that event, it is left unbound and returned
## so the menu can say so. Returns "" when nothing was displaced.
func rebind(action: String, event: InputEvent) -> String:
	var displaced := ""
	var clean: InputEvent = _clean(event)
	for other: String in action_names():
		if other == action:
			continue
		for e: InputEvent in InputMap.action_get_events(other):
			if e.is_match(clean):
				InputMap.action_erase_events(other)
				displaced = other
	_set_binding(action, clean)
	_save()
	changed.emit()
	return displaced


func reset_defaults() -> void:
	for a: Array in ACTIONS:
		_set_binding(a[0], _default_event(a))
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	changed.emit()


func _set_binding(action: String, event: InputEvent) -> void:
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)


static func _default_event(a: Array) -> InputEvent:
	return _make(a[2], int(a[3]))


static func _make(kind: String, code: int) -> InputEvent:
	if kind == "mouse":
		var m := InputEventMouseButton.new()
		m.button_index = code as MouseButton
		return m
	var k := InputEventKey.new()
	k.physical_keycode = code as Key
	return k


## Strip modifiers/position so the stored event matches on the key or button alone.
static func _clean(event: InputEvent) -> InputEvent:
	var key := event as InputEventKey
	if key != null:
		return _make("key", key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode)
	var mouse := event as InputEventMouseButton
	if mouse != null:
		return _make("mouse", mouse.button_index)
	return event


func _save() -> void:
	var cfg := ConfigFile.new()
	for action: String in action_names():
		var events: Array[InputEvent] = InputMap.action_get_events(action)
		if events.is_empty():
			cfg.set_value("binds", action, "none")
			continue
		var key := events[0] as InputEventKey
		if key != null:
			cfg.set_value("binds", action, "key:%d" % key.physical_keycode)
		else:
			cfg.set_value("binds", action, "mouse:%d" % (events[0] as InputEventMouseButton).button_index)
	cfg.save(SAVE_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for action: String in action_names():
		var raw: String = str(cfg.get_value("binds", action, ""))
		if raw == "":
			continue
		if raw == "none":
			InputMap.action_erase_events(action)
			continue
		var parts: PackedStringArray = raw.split(":")
		if parts.size() == 2 and (parts[0] == "key" or parts[0] == "mouse"):
			_set_binding(action, _make(parts[0], int(parts[1])))
