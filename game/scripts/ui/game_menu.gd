class_name GameMenu
extends UiScreen
## The game menu: Esc (the `settings` action) in play - the town, the field, a passage, the arena
## and the Netherecho. The game is paused while it is open. Resume, New game (create a character,
## or a test character of any affinity in one click: Brent 2026-10-24, for cycling through them),
## Save, Load, Settings, Quit to title and Quit game. Every item calls main.gd; the menu owns no
## game state. Save and Load open the register (SavesScreen, "save" / "load") and come back here;
## Settings is a view of its own with the controls menu (settings_menu.gd) one click further.
## Anything that would leave a real character asks first (UiScreen.confirm_leave). Esc closes the
## topmost thing first: a question, then a view, then the menu.

## "main", "new" (new game and the test characters) or "settings".
var view := "main"


func _init(game_node: Node, start_view: String = "main") -> void:
	super(game_node)
	view = start_view


func backdrop() -> float:
	return 0.72


func hud_hides() -> Array[String]:
	return HUD_MENU


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_action_pressed("settings"):
		return
	get_viewport().set_input_as_handled()
	back()


## Esc or Back: a view goes back to the menu, the menu back to the game.
func back() -> void:
	if view != "main":
		show_view("main")
	else:
		game.call("close_screen")


func show_view(which: String) -> void:
	view = which
	rebuild()


## A framed panel centred on the screen that grows to fit what is in it.
func _centred(root: Control, width_frac: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = "GameMenuPanel"
	panel.anchor_left = 0.5 - width_frac * 0.5
	panel.anchor_right = 0.5 + width_frac * 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	return box


func _header(box: VBoxContainer, title: String) -> void:
	var t := UiTheme.heading(title, UiTheme.FS_TITLE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var sub := UiTheme.body("%s   -   %s   -   paused" % [str(game.call("character_label")), str(game.call("menu_where"))], UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(UiTheme.rule())


func _item(box: VBoxContainer, id: String, title: String, desc: String, on_press: Callable, enabled: bool = true) -> Button:
	var b: Button = UiWidgets.service_button(title, desc, "", on_press, enabled)
	b.name = "Menu_" + id
	b.custom_minimum_size.y = 62
	if not enabled:
		b.tooltip_text = desc
	box.add_child(b)
	return b


func _back_row(box: VBoxContainer) -> void:
	box.add_child(UiTheme.rule())
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(foot)
	var b: Button = UiWidgets.small_button("Back  (%s)" % Keybinds.binding_text("settings"), back)
	b.name = "Menu_Back"
	foot.add_child(b)


func build(root: Control) -> void:
	match view:
		"new":
			_build_new(root)
		"settings":
			_build_settings(root)
		_:
			_build_main(root)


func _build_main(root: Control) -> void:
	var box: VBoxContainer = _centred(root, 0.34)
	_header(box, "Game menu")
	_item(box, "Resume", "Resume", "Back to the game.", func() -> void: game.call("close_screen"))
	_item(box, "NewGame", "New game", "Make a character, or start a test character of any affinity in one click.",
		show_view.bind("new"))
	var block: String = str(game.call("slot_save_block_reason"))
	_item(box, "Save", "Save", "Write this character to a numbered slot." if block == "" else block,
		func() -> void: game.call("menu_open_saves", "save"), block == "")
	var any: bool = bool(game.call("has_saves"))
	_item(box, "Load", "Load", "Carry on as a saved character." if any else "There are no saved characters yet.",
		func() -> void: game.call("menu_open_saves", "load"), any)
	_item(box, "Settings", "Settings", "The window, the camera, and the controls.", show_view.bind("settings"))
	_item(box, "QuitTitle", "Quit to title", "Back to character creation and the test characters.",
		func() -> void: confirm_leave("Quit to title", func() -> void: game.call("quit_to_title")))
	_item(box, "QuitGame", "Quit game", "Close Ether Syntax.",
		func() -> void: confirm_leave("Quit the game", func() -> void: game.call("quit_game")))


func _build_new(root: Control) -> void:
	var box: VBoxContainer = _centred(root, 0.4)
	_header(box, "New game")
	_item(box, "Create", "Create a character", "Character creation: origin, look, prime and two skills.",
		func() -> void: confirm_leave("Start a new character", func() -> void: game.call("quit_to_title")))
	box.add_child(UiTheme.section("Test characters"))
	box.add_child(UiTheme.body("Every skill of one affinity, ready to try, starting in town. Never saved over your character.",
		UiTheme.FS_SMALL, UiTheme.TEXT_FAINT))
	box.add_child(UiWidgets.test_character_grid(func(aff: String) -> void:
		var label: String = str(GameData.affinity(aff).get("label", aff))
		confirm_leave("Start Test: %s" % label, func() -> void: game.call("menu_test_character", aff))))
	_back_row(box)


func _build_settings(root: Control) -> void:
	var box: VBoxContainer = _centred(root, 0.4)
	_header(box, "Settings")

	box.add_child(UiTheme.section("Window"))
	var full: bool = GameSettings.fullscreen()
	var win := HBoxContainer.new()
	box.add_child(win)
	var wl := UiTheme.body("Show the game", UiTheme.FS_BODY, UiTheme.TEXT)
	wl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	win.add_child(wl)
	for opt: Array in [["Windowed", false], ["Fullscreen", true]]:
		var on: bool = bool(opt[1]) == full
		var b: Button = UiWidgets.small_button(str(opt[0]), func() -> void:
			game.call("set_fullscreen", bool(opt[1]))
			rebuild())
		b.name = "Set_" + str(opt[0])
		b.custom_minimum_size = Vector2(120, 0)
		b.add_theme_color_override("font_color", UiTheme.GOLD if on else UiTheme.TEXT_DIM)
		win.add_child(b)

	box.add_child(UiTheme.section("Camera"))
	var z: float = float(game.call("zoom_start"))
	var cam := HBoxContainer.new()
	box.add_child(cam)
	var zl := UiTheme.body("Zoom a game starts at:  %d%%" % roundi(z * 100.0), UiTheme.FS_BODY, UiTheme.TEXT)
	zl.name = "ZoomValue"
	zl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cam.add_child(zl)
	var step: float = GameData.num("camera", "zoom_step")
	for opt: Array in [["Farther", "Zoom_Out", -step], ["Nearer", "Zoom_In", step], ["Default", "Zoom_Default", 0.0]]:
		var delta_z: float = float(opt[2])
		var b: Button = UiWidgets.small_button(str(opt[0]), func() -> void:
			game.call("set_zoom_start", -1.0 if delta_z == 0.0 else clampf(z + delta_z, 0.0, 1.0))
			rebuild())
		b.name = str(opt[1])
		cam.add_child(b)
	box.add_child(UiTheme.body("0% is far and high over the fight, 100% low behind the shoulder. The camera moves there now; the mouse wheel still zooms in play.",
		UiTheme.FS_SMALL, UiTheme.TEXT_FAINT))

	box.add_child(UiTheme.section("Controls"))
	_item(box, "Controls", "Controls", "Rebind any key or mouse button.", func() -> void: game.call("open_settings"))
	_back_row(box)
