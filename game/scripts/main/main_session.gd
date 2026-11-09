class_name MainSession
extends RefCounted
## The character in play: the title (state "select"), starting a character (the creation screen's spec, the quick
## start for tests and bots, the test characters), the autosave and the numbered slots, loading back into the place
## a save was made, dropping an item, and dying (a corpse run, or hardcore's end). Moved out of main.gd as it was
## (docs/architecture/main-split.md).

var main: Main


func _init(of: Main) -> void:
	main = of


func _show_select() -> void:
	main.state = "select"
	main._show_screen(CreationScreen.new(main), false)


func _select_talent(index: int) -> void:
	main.player.call("set_talent", Main.TALENT_CHOICES[index])


## Quick start with a default look (tests and bots); the creation screen uses begin_character.
## The two starting skills are the first two roots - a test convenience; a player always picks.
func start_new_character(index: int) -> void:
	main.player.call("set_affinities", GameData.default_affinities())
	begin_character({"talent_id": Main.TALENT_CHOICES[index], "skills": main.player.call("default_start_skills")})


## Start the character described by the creation screen: {name, identity, look, talent_id,
## affinities, skills}. The talent and the affinities are the prime that was picked from the
## rolled offers; `skills` are the two starting skills the player picked (design/08) - nothing is
## given that was not picked. Returns "" or why the character could not begin.
func begin_character(spec: Dictionary) -> String:
	var talent: String = str(spec.get("talent_id", Main.TALENT_CHOICES[0]))
	main.player.call("set_talent", talent if Main.TALENT_CHOICES.has(talent) else Main.TALENT_CHOICES[0])
	main.player.call("set_affinities", spec.get("affinities", []))
	var why: String = main.player.call("start_with_skills", spec.get("skills", []))
	if why != "":
		main.player.call("note", why)
		return why
	main.player.set("char_name", str(spec.get("name", "")).strip_edges().left(int(GameData.creation["name_max_length"])))
	main.player.set("identity", str(spec.get("identity", "")))
	main.player.call("set_look", spec.get("look", {}))
	main.player.set("money", GameData.inum("town", "starting_money"))
	main._enter_town()
	return ""


## The title screen's "Test characters" (Brent 2026-10-22): one character with this one affinity
## and every skill of it learned, at a stage high enough for big rune words, a full tank and the
## test rune palette, starting in town (the arena gate is a short walk). Marked as a test
## character: never autosaved over the real save, and only it can turn the bar to the next page.
func start_test_character(aff: String) -> void:
	main.player.call("set_talent", Main.TALENT_CHOICES[0])
	main.player.call("make_test_character", aff)
	main.player.set("char_name", "Test: %s" % str(GameData.affinity(aff).get("label", aff)))
	main.player.set("identity", str((GameData.creation.get("identities", [{}]) as Array)[0].get("id", "")) if not (GameData.creation.get("identities", []) as Array).is_empty() else "")
	main.player.call("set_look", {})
	main.player.set("money", GameData.inum("town", "starting_money"))
	main._enter_town()


func toggle_hardcore() -> void:
	main.hardcore = not main.hardcore


func new_character() -> void:
	main.restart_game()


# --- saving ------------------------------------------------------------------------

## The autosave.
func save_now() -> void:
	if main._bot_mode or main._shot_mode or main._test_mode or bool(main.player.get("test_character")):
		return                            # a test character never writes over the real autosave
	save_to_slot(0)


## Write the character as it stands to a slot (0 = autosave). Only meaningful in town.
func save_to_slot(slot: int) -> bool:
	if str(main.player.get("talent_id")) == "":
		return false
	if str(main.player.get("char_id")) == "":
		main.player.set("char_id", SaveGame.new_char_id())   # one id for every save of this character
	var data: Dictionary = main.player.call("to_save")
	data["day"] = main.day
	data["delves"] = main.delves
	data["hardcore"] = main.hardcore
	data["place"] = main._place_for_save()
	var ok: bool = SaveGame.write(data, SaveGame.slot_path(slot))
	var said: String = SaveGame.take_note()   # a displaced autosave kept, or a newer save not written over
	if said != "":
		main.player.call("note", said)
	if slot > 0:
		main.player.call("note", "Saved to slot %d." % slot if ok else "Could not write slot %d." % slot)
	elif not ok and said == "":
		main.player.call("note", "The autosave could not be written (see the log); your last save is unchanged.")
	return ok


## Load the autosave into town. Returns false if there is nothing usable to load.
func continue_game() -> bool:
	return load_slot(0)


## Load a slot into town; the loaded character becomes the autosave too.
func load_slot(slot: int) -> bool:
	var data: Dictionary = SaveGame.read(SaveGame.slot_path(slot))
	var said: String = SaveGame.take_note()       # recovered from a backup copy, or refused as newer
	if data.is_empty() or str(data.get("talent_id", "")) == "":
		if said != "":
			main.player.call("note", said)
		return false
	main.player.call("from_save", data)
	if said != "":
		main.player.call("note", said)
	main.day = int(data.get("day", 1))
	main.delves = int(data.get("delves", 0))
	main.hardcore = bool(data.get("hardcore", false))
	if not main._resume_place(data.get("place", {})):
		main._enter_town()
	main.screens_part.open_ascension()                       # an ascension left unsettled when it was saved
	return true


## Drop one item from the bag. In the field it lands at your feet; in town it is simply gone.
func drop_item(item_id: String) -> void:
	var inv: Inventory = main.player.get("inventory")
	if not inv.remove(item_id):
		return
	var item_name: String = str(GameData.item(item_id).get("name", item_id))
	if main.state == "town":
		main.player.call("note", "You leave the %s behind." % item_name)
		save_now()
	else:
		Main.PlayerScript.spawn_pickup(main.level, item_id, main.player.global_position + Vector3(0.9, 0.0, 0.4))
		main.player.call("note", "Dropped %s." % item_name)


func _on_player_died() -> void:
	if main.hardcore:
		main.state = "dead"
		# permadeath: every save of this character goes - the autosave, any slot, every backup copy
		# (a test or bot run is sandboxed, so this only ever reaches the player's files in play)
		if main._plays() or SaveGame.test_dir != "":
			SaveGame.clear_character(str(main.player.get("char_id")))
		main._prompt = ""
		main._show_screen(Main.MessageScreen.new(main, "YOU DIED", "Hardcore: that was the only life this character had.", "Begin again", new_character), false)
		return
	var lost: int = main.bank if main.state == "dungeon" else 0
	main._bot_died = true
	main._bot_finished = main._bot_mode
	# a corpse run (Brent 2026-10-18): the body stays where it fell with everything on it
	var where: String = "passage" if main.state == "dungeon" else ("arena" if main.state.begins_with("arena") else (main.zone_id if main.state == "field" else ""))
	main._return_to = {}
	if where != "" and main.level != null:
		var at: Vector3 = main.level.to_local(main.player.global_position)
		main.player.call("die_to_corpse", where, Route.chamber_of(at, main.ch_len) if where == "passage" else 0, at)
	main.player.call("respawn_naked")
	if lost > 0:
		main.player.call("note", "The spoils of the walls you cleared stayed in the passage.")
	main._last_payout = 0
	main._enter_town()
