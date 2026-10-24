extends Node
## The game menu click test (windowed run only - needs real GUI hit-testing):
##   godot --path game res://tests/game_menu_probe.tscn
## Drives the real menu with the real Esc key and clicks: a real (non-test) character in town -
## Esc opens the menu and pauses; Save writes slot 1; Load lists the slots; Load and Quit game ask
## first and Esc / Cancel back out; the arena and a passage open the menu with Save disabled and
## the reason; New game -> Fire asks (a real character would be left) and starts a fire test
## character; Esc -> New game -> Ice starts an ice one without asking (a test character is never
## saved) with every ice skill; Settings -> a nearer starting zoom -> Controls -> Esc -> Esc;
## the test character saved to slot 2 in town; the field (Save disabled) and the Netherecho; Load
## slot 1 from the field brings the real character back; Esc closes an open screen before the menu
## opens; Resume. Saves go to user://probe_saves/ and settings to user://probe_settings.cfg, never
## the real ones. Prints "GAMEMENU: PASS" / "GAMEMENU: FAIL" and exits 0/1.

const SAVE_DIR := "user://probe_saves/"
const TIMEOUT_MS := 180000

var main: Node
var results: Array[String] = []
var failed := false
var _errors: ErrorCatcher
var _steps: Array[Callable] = []
var _step := 0
var _wait := 0                     # frames before the next step may run
var _replaced := 0                 # how many times main was replaced by a fresh game
var _started_ms := 0
var _done := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_errors = ErrorCatcher.install()
	_started_ms = Time.get_ticks_msec()
	SaveGame.test_dir = SAVE_DIR
	for slot: int in SaveGame.SLOTS + 1:
		SaveGame.delete(SaveGame.slot_path(slot))
	GameSettings.use_path("user://probe_settings.cfg")
	if FileAccess.file_exists(GameSettings.path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.path))
	_adopt((load("res://scenes/main.tscn") as PackedScene).instantiate())
	main.set("_test_mode", true)
	main.process_mode = Node.PROCESS_MODE_PAUSABLE      # as in the game: the menu's pause stops it
	add_child(main)
	_build_steps()
	_wait = 60


func _adopt(m: Node) -> void:
	main = m
	main.connect("replaced", _on_replaced)


func _on_replaced(fresh: Node) -> void:
	_replaced += 1
	_adopt(fresh)


# --- input ------------------------------------------------------------------------------------

func _esc() -> void:
	var ev: InputEvent = (InputMap.action_get_events("settings")[0] as InputEvent).duplicate()
	(ev as InputEventKey).pressed = true
	get_viewport().push_input(ev)
	var up: InputEvent = ev.duplicate()
	(up as InputEventKey).pressed = false
	get_viewport().push_input(up)


func _key(action: String) -> void:
	var ev: InputEvent = (InputMap.action_get_events(action)[0] as InputEvent).duplicate()
	(ev as InputEventKey).pressed = true
	get_viewport().push_input(ev)
	var up: InputEvent = ev.duplicate()
	(up as InputEventKey).pressed = false
	get_viewport().push_input(up)


func _click(c: Control) -> bool:
	if c == null or not c.is_visible_in_tree():
		return false
	var at: Vector2 = c.get_global_rect().get_center()
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	get_viewport().push_input(mv)
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		get_viewport().push_input(ev)
	return true


## Click the control named `n` under main, and say so if it is not there to click.
func _press(n: String) -> void:
	var c: Control = main.find_child(n, true, false) as Control
	_expect("there is a %s to click" % n, _click(c), "missing or hidden")


# --- what is open -------------------------------------------------------------------------------

func _screen() -> Node:
	return main.get("screen")


func _menu_view() -> String:
	var s: Node = _screen()
	return str(s.get("view")) if s is GameMenu else ""


func _dialog() -> Node:
	return main.find_child("ConfirmDialog", true, false)


## Whether the open question's text has `word` in it.
func _dialog_says(word: String) -> bool:
	var d: Node = _dialog()
	if d == null:
		return false
	for l: Node in d.find_children("*", "Label", true, false):
		if (l as Label).text.contains(word):
			return true
	return false


func _player() -> Node:
	return main.get("player")


func _button(n: String) -> Button:
	return main.find_child(n, true, false) as Button


# --- the steps ----------------------------------------------------------------------------------

## Each step runs once and returns how many frames to wait before the next; a step that returns -1
## is a wait: it runs again next frame until it returns something else.
func _build_steps() -> void:
	_steps = [
		func() -> int:
			_expect("the game starts on the title", str(main.get("state")) == "select")
			main.call("start_new_character", 0)
			_player().set("char_name", "Probe")
			return 20,
		func() -> int:
			_expect("a real character stands in town", str(main.get("state")) == "town" and not bool(_player().get("test_character")))
			_esc()
			return 8,
		# 1. Esc opens it, and it pauses
		func() -> int:
			_expect("Esc in town opens the game menu", _menu_view() == "main", str(_screen()))
			_expect("and the game is paused", get_tree().paused and not main.can_process())
			for n: String in ["Menu_Resume", "Menu_NewGame", "Menu_Save", "Menu_Load", "Menu_Settings", "Menu_QuitTitle", "Menu_QuitGame"]:
				_expect("it has %s" % n.trim_prefix("Menu_"), _button(n) != null and _button(n).is_visible_in_tree())
			_expect("Save is offered in town", _button("Menu_Save") != null and not _button("Menu_Save").disabled)
			_expect("Load is not: there are no saves yet", _button("Menu_Load") != null and _button("Menu_Load").disabled)
			_press("Menu_Save")
			return 8,
		# 6. Save works in town
		func() -> int:
			_expect("Save opens the register to save", _screen() is SavesScreen and str(_screen().get("mode")) == "save")
			_expect("with no Load buttons in it", main.find_child("Load_1", true, false) == null)
			_press("Save_1")
			return 8,
		func() -> int:
			var d: Dictionary = SaveGame.read(SaveGame.slot_path(1))
			_expect("Save here writes slot 1 (in the probe's folder)", str(d.get("name", "")) == "Probe" and not bool(d.get("test_character", true)), str(d))
			_esc()
			return 8,
		func() -> int:
			_expect("Esc on the register goes back to the menu, not the game", _menu_view() == "main" and get_tree().paused)
			_press("Menu_Load")
			return 8,
		# 7. Load lists the slots
		func() -> int:
			_expect("Load opens the register to load", _screen() is SavesScreen and str(_screen().get("mode")) == "load")
			var rows: int = 0
			for slot: int in SaveGame.SLOTS + 1:
				if main.find_child("Slot_%d" % slot, true, false) != null:
					rows += 1
			_expect("it lists the autosave and every slot (%d)" % (SaveGame.SLOTS + 1), rows == SaveGame.SLOTS + 1, str(rows))
			_expect("slot 1 can be loaded, an empty slot cannot, and nothing can be saved", _button("Load_1") != null and _button("Load_3") == null
				and main.find_child("Save_1", true, false) == null)
			_press("Load_1")
			return 8,
		# 8. the question, where it should be
		func() -> int:
			_expect("loading over a real character asks first", _dialog() != null and _dialog().is_visible_in_tree())
			_esc()
			return 8,
		func() -> int:
			_expect("Esc closes the question first and the register stays", _dialog() == null and _screen() is SavesScreen and _replaced == 0)
			_esc()
			return 8,
		func() -> int:
			_expect("the next Esc goes back to the menu", _menu_view() == "main")
			_press("Menu_QuitGame")
			return 8,
		func() -> int:
			_expect("Quit game asks first for a real character", _dialog() != null)
			_press("ConfirmNo")
			return 8,
		func() -> int:
			_expect("Cancel leaves the game running with the menu open", _dialog() == null and _menu_view() == "main" and is_inside_tree())
			_press("Menu_Resume")
			return 8,
		func() -> int:
			_expect("Resume closes the menu and the game runs again", _screen() == null and not get_tree().paused)
			main.call("enter_arena")
			return 20,
		# the arena and a passage
		func() -> int:
			_esc()
			return 8,
		func() -> int:
			_expect("Esc in the arena opens the menu", _menu_view() == "main" and get_tree().paused, str(main.get("state")))
			var save: Button = _button("Menu_Save")
			_expect("Save is disabled there, with the reason", save != null and save.disabled and save.tooltip_text.contains("in town"), save.tooltip_text if save != null else "")
			_press("Menu_Resume")
			return 8,
		func() -> int:
			main.call("_enter_dungeon")
			return 20,
		func() -> int:
			_esc()
			return 8,
		func() -> int:
			_expect("Esc in a passage opens the menu", _menu_view() == "main" and str(main.get("state")) == "dungeon")
			_expect("Save is disabled in a passage", _button("Menu_Save").disabled and _button("Menu_Save").tooltip_text.contains("passage"))
			_press("Menu_QuitTitle")
			return 8,
		func() -> int:
			_expect("Quit to title from a passage asks, and says the run is lost", _dialog_says("passage"))
			_esc()
			return 8,
		# 2. New game -> a test character (fire)
		func() -> int:
			_expect("Esc backs out of the question", _dialog() == null and _menu_view() == "main")
			_press("Menu_NewGame")
			return 8,
		func() -> int:
			_expect("New game shows the test characters", _menu_view() == "new" and main.find_child("TestCharacters", true, false) != null
				and GameData.affinity_ids().all(func(a: String) -> bool: return main.find_child("Test_" + a, true, false) != null))
			_press("Test_fire")
			return 8,
		func() -> int:
			_expect("leaving a real character for a test one asks first", _dialog() != null and _replaced == 0)
			_press("ConfirmYes")
			return 4,
		func() -> int:
			if _replaced < 1 or str(main.get("state")) != "town":
				return -1
			var p: Node = _player()
			_expect("Yes: a fresh game with a fire test character in town", bool(p.get("test_character")) and (p.get("affinities") as Array) == ["fire"])
			_expect("not paused, no menu", not get_tree().paused and _screen() == null)
			return 20,
		# 3. Esc -> New game -> another test character (ice)
		func() -> int:
			_esc()
			return 8,
		func() -> int:
			_press("Menu_NewGame")
			return 8,
		func() -> int:
			_press("Test_ice")
			return 4,
		func() -> int:
			_expect("leaving a test character does not ask", _dialog() == null)
			return 0,
		func() -> int:
			return -1 if _replaced < 2 or str(main.get("state")) != "town" else 20,
		# 4. it is ice, with its skills
		func() -> int:
			var p: Node = _player()
			var want: Array = GameData.abilities.keys().filter(func(id: Variant) -> bool: return str(GameData.ability(str(id)).get("affinity", "")) == "ice")
			var have: Array = (p.get("abilities") as Array).map(func(a: Dictionary) -> String: return str(a["id"]))
			_expect("the second test character is ice", bool(p.get("test_character")) and (p.get("affinities") as Array) == ["ice"] and str(p.get("char_name")) == "Test: Ice")
			_expect("with every ice skill (%d) and nothing else" % want.size(), have.size() == want.size() and want.all(func(id: Variant) -> bool: return have.has(str(id))), str(have))
			_expect("its bar holds ice skills", int((p.get("hotbar") as Array)[0]) >= 0)
			_esc()
			return 8,
		# 5. Settings and back
		func() -> int:
			_press("Menu_Settings")
			return 8,
		func() -> int:
			_expect("Settings opens its view", _menu_view() == "settings" and _button("Set_Fullscreen") != null and _button("Zoom_In") != null)
			_press("Zoom_In")
			return 8,
		func() -> int:
			var want: float = clampf(GameData.num("camera", "zoom_default") + GameData.num("camera", "zoom_step"), 0.0, 1.0)
			_expect("Nearer saves a nearer starting zoom and moves the camera", is_equal_approx(GameSettings.zoom_start(), want)
				and is_equal_approx(float(main.get("cam_zoom")), want), "%s %s" % [GameSettings.zoom_start(), main.get("cam_zoom")])
			_press("Zoom_Default")
			return 8,
		func() -> int:
			_expect("Default puts it back", is_equal_approx(GameSettings.zoom_start(), GameData.num("camera", "zoom_default")))
			_press("Menu_Controls")
			return 8,
		func() -> int:
			_expect("Controls opens the controls menu over it", main.get("settings_menu") != null)
			_esc()
			return 8,
		func() -> int:
			_expect("Esc closes the controls menu first; Settings stays", main.get("settings_menu") == null and _menu_view() == "settings" and get_tree().paused)
			_esc()
			return 8,
		func() -> int:
			_expect("the next Esc goes back to the menu", _menu_view() == "main")
			_expect("Save is offered to a test character in town", not _button("Menu_Save").disabled)
			_press("Menu_Save")
			return 8,
		func() -> int:
			_press("Save_2")
			return 8,
		func() -> int:
			var d: Dictionary = SaveGame.read(SaveGame.slot_path(2))
			_expect("a test character saved to slot 2 is kept marked as one", bool(d.get("test_character", false)) and (d.get("affinities", []) as Array) == ["ice"])
			_expect("and the autosave is untouched", SaveGame.read(SaveGame.slot_path(0)).is_empty())
			_esc()
			return 8,
		func() -> int:
			_press("Menu_Resume")
			return 8,
		# the field and the Netherecho
		func() -> int:
			main.call("walk_out")
			return 20,
		func() -> int:
			_esc()
			return 8,
		func() -> int:
			_expect("Esc in the field opens the menu", _menu_view() == "main" and str(main.get("state")) == "field")
			var save: Button = _button("Menu_Save")
			_expect("Save is disabled in the field, with the reason", save.disabled and save.tooltip_text.contains("in town"), save.tooltip_text)
			_click(save)
			return 8,
		func() -> int:
			_expect("clicking the disabled Save does nothing", _menu_view() == "main")
			_press("Menu_Resume")
			return 8,
		func() -> int:
			main.call("toggle_projection")
			return 10,
		func() -> int:
			_expect("the soul is out in the Netherecho", (main.get("nether") as Netherecho).active)
			_esc()
			return 8,
		func() -> int:
			_expect("Esc in the Netherecho opens the menu, paused", _menu_view() == "main" and get_tree().paused
				and str(main.call("menu_where")).begins_with("The Netherecho"))
			_press("Menu_Load")
			return 8,
		func() -> int:
			_press("Load_1")
			return 4,
		func() -> int:
			if _replaced < 3 or str(main.get("state")) == "select":
				return -1
			var p: Node = _player()
			_expect("Load slot 1 (no question: a test character) brings the real character back", str(p.get("char_name")) == "Probe"
				and not bool(p.get("test_character")) and str(main.get("state")) == "town")
			return 20,
		# Esc closes an open screen before the menu
		func() -> int:
			_key("inventory")
			return 8,
		func() -> int:
			_expect("the inventory is open", _screen() != null and (_screen().get_script() as Script).resource_path.ends_with("inventory_screen.gd"))
			_esc()
			return 8,
		func() -> int:
			_expect("Esc closes the inventory and does not open the menu", _screen() == null)
			_esc()
			return 8,
		# 9. Resume
		func() -> int:
			_expect("the next Esc opens the menu", _menu_view() == "main")
			_esc()
			return 8,
		func() -> int:
			_expect("and Esc on the menu resumes", _screen() == null and not get_tree().paused)
			return 0,
	]


func _process(_delta: float) -> void:
	if _done:
		return
	if Time.get_ticks_msec() - _started_ms > TIMEOUT_MS:
		_expect("finished in time", false, "stuck at step %d" % _step)
		_finish()
		return
	if _wait > 0:
		_wait -= 1
		return
	if _step >= _steps.size():
		_finish()
		return
	var r: int = int((_steps[_step] as Callable).call())
	if r < 0:
		return
	_step += 1
	_wait = r


func _expect(label: String, ok: bool, detail: String = "") -> void:
	results.append("%s %s %s" % ["ok  " if ok else "FAIL", label, "" if ok else detail])
	if not ok:
		failed = true


func _finish() -> void:
	_done = true
	_expect("no script errors", _errors.count() == 0, _errors.first())
	for line: String in results:
		print(line)
	for slot: int in SaveGame.SLOTS + 1:
		SaveGame.delete(SaveGame.slot_path(slot))
	SaveGame.test_dir = ""
	print("GAMEMENU: %s" % ("FAIL" if failed else "PASS"))
	get_tree().quit(1 if failed else 0)
