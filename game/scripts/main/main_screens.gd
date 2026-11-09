class_name MainScreens
extends RefCounted
## The screens over the game: showing one (and whether it pauses), closing back to whoever opened it, the panels
## the keys and the townsfolk open (inventory, ethercosm, skill tree, shop, tempering, the register), the seal
## screen at a level lock, the ascension, the controls menu, and the game menu with what it asks of the game
## (the save rule, the warning before leaving, its settings). Each screen holds the node and calls these through
## its forwarders. Moved out of main.gd as it was (docs/architecture/main-split.md).

var main: Main


func _init(of: Main) -> void:
	main = of


var _screen_paused := false


## The open screen was opened from the game menu, so closing it goes back to the menu.
var _menu_return := false


func _show_screen(new_screen: Control, pause: bool) -> void:
	if main.screen != null:
		main.screen.queue_free()
	main.screen = new_screen
	_screen_paused = pause and new_screen != null
	if new_screen != null:
		main.ui_root.add_child(new_screen)
		if main.settings_menu != null:
			main.ui_root.move_child(main.settings_menu, -1)
	main.get_tree().paused = _screen_paused or main.settings_menu != null


## Close the open screen. In town, a screen someone showed you goes back to talking to them, and
## closing that leaves you standing in the street.
func close_screen() -> void:
	if _menu_return and main.screen != null and not (main.screen is GameMenu):
		_show_screen(GameMenu.new(main), true)      # opened from the game menu: back to it
		_menu_return = false
		return
	_menu_return = false
	if main.state == "town":
		if main._talking_to != "" and not (main.screen is TalkScreen):
			_show_screen(TalkScreen.new(main, main._talking_to), false)
		else:
			main._talking_to = ""
			_show_screen(null, false)
	elif main.state == "select":
		_show_screen(CreationScreen.new(main), false)
	else:
		_show_screen(null, false)


func _open_settings() -> void:
	if main.settings_menu != null:
		return
	main.settings_menu = Main.SettingsMenuScript.new()
	main.settings_menu.connect("closed", main._on_settings_closed)     # the node's handler, as before
	main.ui_root.add_child(main.settings_menu)
	main.get_tree().paused = true


func _on_settings_closed() -> void:
	main.settings_menu = null
	main.get_tree().paused = _screen_paused
	if main.screen != null and main.screen.has_method("rebuild"):
		main.screen.call("rebuild")          # key names on screen may have changed


func open_settings() -> void:
	_open_settings()


func open_shop() -> void:
	if main.state == "town":
		_show_screen(Main.ShopScreen.new(main), false)


func open_tempering() -> void:
	if main.state == "town":
		_show_screen(TemperingScreen.new(main), false)


## Toggle the inventory. Out in the field it pauses the game.
func open_inventory() -> void:
	if main.screen is Main.InventoryScreen:
		close_screen()
	elif main.state != "select" and main.state != "dead":
		_show_screen(Main.InventoryScreen.new(main), main.state != "town")


## Toggle the ethercosm - the view of your soul. Out in the field it pauses the game.
func open_ethercosm() -> void:
	if main.screen is Main.EthercosmScreen:
		close_screen()
	elif main.state != "select" and main.state != "dead":
		_show_screen(Main.EthercosmScreen.new(main), main.state != "town")


func open_saves() -> void:
	if main.state == "town" or main.state == "select":
		_show_screen(SavesScreen.new(main), false)


## The skill tree. From the trainer (`at_trainer`, only while talking to them in town) its Learn
## and Drill buttons work; opened anywhere else it is for looking. Out of town it pauses the game.
func open_skill_tree(at_trainer: bool = false) -> void:
	if main.screen is SkillTreeScreen and not at_trainer:
		close_screen()
		return
	if main.state == "select" or main.state == "dead":
		return
	var teaching: bool = at_trainer and main.state == "town" and main._talking_to == "trainer"
	_show_screen(SkillTreeScreen.new(main, teaching), main.state != "town")


## Open the seal screen of ability `ability_index` at its next level lock (design/14 sections 8 and
## 11): the ring is built and the construct chosen and bound there - the only place a construct is
## bound (Brent 2026-10-23), and only with the bar full and a construct of the tier carried (Brent
## 2026-10-24). `construct_index` < 0: the keystone is chosen on the screen.
func open_seal(ability_index: int, construct_index: int = -1) -> void:
	if not (main.screen is Main.EthercosmScreen):
		if main.state == "select" or main.state == "dead":
			return
		_show_screen(Main.EthercosmScreen.new(main), main.state != "town")
	main.screen.call("select", ability_index)
	main.screen.call("open_seal", construct_index)


## The B key ("bind"): opens the seal screen of the first skill whose level lock can open - its bar
## full and a construct of its tier carried (Brent 2026-10-24). With none, it says what the first full
## skill is missing. It binds nothing itself.
func open_seal_first_ready() -> void:
	var abilities: Array = main.player.abilities
	var missing := ""
	for ai: int in abilities.size():
		var lock: Dictionary = main.player.can_open_seal(ai)
		if bool(lock["ok"]):
			open_seal(ai)
			return
		if missing == "" and str(lock["reason"]) == "no_construct":
			missing = "%s: %s" % [str(GameData.ability(str(abilities[ai]["id"])).get("name", "?")), str(lock["text"])]
	main.player.note(missing if missing != "" else "No skill is ready for its level lock: a skill's bar fills as you use it.")


## A star ascended (Brent 2026-10-24): the ascension screen offers its affinities and boosts.
func _on_ascended(_star: int) -> void:
	open_ascension()


## Show the pending ascension's screen (an affinity to choose, then each skill's boost). It pauses
## and holds the keys until it is settled; a save made meanwhile keeps it, and loading reopens it.
func open_ascension() -> void:
	if (main.player.ascension_pending as Dictionary).is_empty() or main.state == "select" or main.state == "dead":
		return
	_show_screen(Main.AscensionScreen.new(main), true)


## Settle the pending ascension with the screen's choices (Player.resolve_ascension), then save and
## close. Returns "" or why not.
func resolve_ascension(affinity: String, aspects: Dictionary) -> String:
	var why: String = str(main.player.resolve_ascension(affinity, aspects))
	if why != "":
		return why
	main.save_now()
	close_screen()
	return ""


# --- the game menu (Esc in play) ------------------------------------------------------------

## The game menu: Resume, New game (and the test characters), Save, Load, Settings, Quit to title,
## Quit game. Pauses the game in every state it opens in (town, field, passage, arena, the
## Netherecho); not on the title or the hardcore death notice, which have their own buttons.
func open_game_menu(view: String = "main") -> void:
	if main.state == "select" or main.state == "dead":
		return
	_menu_return = false
	main._talking_to = ""
	main._walk_to = null
	_show_screen(GameMenu.new(main, view), true)


## The register (SavesScreen) from the game menu, as "save" or "load"; closing it comes back to the menu.
func menu_open_saves(mode: String) -> void:
	if mode == "save" and slot_save_block_reason() != "":
		return
	_show_screen(SavesScreen.new(main, mode), true)
	_menu_return = true


## Why the character cannot be written to a numbered slot now, or "" if it can. The rule is the one
## the register already had (SavesScreen offered Save only in town; save_to_slot is "only
## meaningful in town"): slots are written in town. A test character may be written to a slot: the
## slot keeps it marked as one (Player.to_save), so loading it is still never autosaved. Nothing
## writes a test character to the autosave (save_now).
func slot_save_block_reason() -> String:
	if main.state == "select" or str(main.player.talent_id) == "":
		return "There is no character to save."
	if main.state == "dead":
		return "This character is dead."
	if main.state == "town":
		return ""
	var test: bool = bool(main.player.test_character)
	match main.state:
		"field":
			if test:
				return "Saving to a slot is done in town, as at the inn's register. A test character is never autosaved."
			return "Saving to a slot is done in town, as at the inn's register. Out here the autosave keeps your place every %d s." % int(
				float(GameData.opt((GameData.balance.get("camps", {}) as Dictionary), "balance.camps", "field_autosave_s")))
		"dungeon":
			return "Saving to a slot is done in town. Nothing is saved inside a passage; the last autosave is from before you went in."
	return "Saving to a slot is done in town. Nothing is saved in the arena; the last autosave is from town."


## What leaving the character in play would lose, for the game menu's question; "" when there is
## nothing to lose (no character, or a test character: never saved anyway). The game keeps no
## record of what has changed since the last save, so a real character is always asked about.
func leave_warning() -> String:
	if main.state == "select" or main.state == "dead" or str(main.player.talent_id) == "" or bool(main.player.test_character):
		return ""
	var lines: Array[String] = []
	match main.state:
		"town":
			lines.append("Anything since the last autosave is lost. In town the autosave is written each time something changes; the game does not track what has changed since, so it asks every time.")
		"field":
			lines.append("Out here the autosave runs every %d s; whatever happened since the last one is lost." % int(
				float(GameData.opt((GameData.balance.get("camps", {}) as Dictionary), "balance.camps", "field_autosave_s"))))
		"dungeon":
			lines.append("Nothing is saved inside a passage: this run, its spoils and anything picked up since you went in are lost.")
		_:
			lines.append("Nothing is saved in the arena: anything since you left town is lost.")
	if main.nether.active:
		lines.append("Your soul is out in the Netherecho.")
	return "\n".join(lines)


## The character's name for the menu ("Test: Fire", "Maren"), or its talent if it has none.
func character_label() -> String:
	var n: String = str(main.player.char_name)
	if n != "":
		return n
	var t: String = str(main.player.talent_id)
	return str(TalentDB.get_talent(t).get("name", "no character")) if t != "" else "no character"


## Where the character is, for the menu's header.
func menu_where() -> String:
	var w: String = main._where()
	if w == "":
		w = main.state
	return ("The Netherecho of " + w.get_slice("  -  ", 0)) if main.nether.active else w


## Whether any slot (the autosave or a numbered one) holds a character.
func has_saves() -> bool:
	for slot: int in SaveGame.SLOTS + 1:
		if not SaveGame.read(SaveGame.slot_path(slot)).is_empty():
			return true
	return false


## The game menu's Load: a fresh game that loads this slot (restart_game). The menu asked first.
func load_from_menu(slot: int) -> void:
	if SaveGame.read(SaveGame.slot_path(slot)).is_empty():
		return
	main.restart_game({"load": slot})


## The game menu's test characters: a fresh game that starts this one in town at once.
func menu_test_character(aff: String) -> void:
	if GameData.affinity(aff).is_empty():
		return
	main.restart_game({"test": aff})


## Back to the title (character creation and the test characters), as at the first start.
func quit_to_title() -> void:
	main.restart_game()


func quit_game() -> void:
	main.get_tree().quit()


## Settings (the game menu's): the window, and the zoom a game starts at (-1 = the data's default).
## A new starting zoom moves the camera there now too.
func set_fullscreen(on: bool) -> void:
	GameSettings.set_fullscreen(on)


func zoom_start() -> float:
	return GameSettings.zoom_start()


func set_zoom_start(z: float) -> void:
	if z < 0.0:
		GameSettings.reset_zoom_start()
	else:
		GameSettings.set_zoom_start(z)
	main._cam_zoom_target = GameSettings.zoom_start()
	main.cam_zoom = main._cam_zoom_target
	var focus: Vector3 = main.nether.projection.global_position if (main.nether.active and main.nether.projection != null) else main.player.global_position
	main._place_camera(focus, 0.0)                   # paused under the menu: move it now, so it shows
