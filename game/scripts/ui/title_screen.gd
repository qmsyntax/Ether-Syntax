extends UiScreen
## Character creation: choose the talent your prime vestige carries. Each card shows the talent's
## name, the cryptic line the vestige speaks, and its plain rule (most fine print is visible up
## front - Brent 2026-09-19).


func backdrop() -> float:
	return 0.86


func build(root: Control) -> void:
	var box: VBoxContainer = framed(root, 0.08, 0.05, 0.92, 0.95)
	box.add_theme_constant_override("separation", 10)

	var title := UiTheme.heading("ETHER SYNTAX", 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := UiTheme.body("A prime vestige waits. Ask it what power it holds - you may only ever hold one.", 17, UiTheme.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(UiTheme.rule())

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	var choices: Array = game.get("TALENT_CHOICES")
	for i: int in choices.size():
		grid.add_child(_card(i, TalentDB.get_talent(str(choices[i]))))

	box.add_child(UiTheme.rule())
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 14)
	box.add_child(foot)
	var save: Dictionary = SaveGame.read()
	if not save.is_empty() and str(save.get("talent_id", "")) != "":
		var who: String = str(TalentDB.get_talent(str(save["talent_id"])).get("name", "?"))
		foot.add_child(UiWidgets.small_button("Continue  -  %s, day %d" % [who, int(save.get("day", 1))], func() -> void: game.call("continue_game")))
	for slot: int in range(1, SaveGame.SLOTS + 1):
		if SaveGame.exists(SaveGame.slot_path(slot)):
			foot.add_child(UiWidgets.small_button("Load a saved character", func() -> void: game.call("open_saves")))
			break
	var hardcore: bool = bool(game.get("hardcore"))
	foot.add_child(UiWidgets.small_button("Hardcore: %s" % ("ON - death is permanent" if hardcore else "off - death leaves you in debt"),
		func() -> void:
			game.call("toggle_hardcore")
			rebuild()))
	foot.add_child(UiWidgets.small_button("Controls", func() -> void: game.call("open_settings")))


func _card(index: int, t: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 180)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void: game.call("start_new_character", index))
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 16
	col.offset_right = -16
	col.offset_top = 12
	col.offset_bottom = -12
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)

	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var name_label := UiTheme.heading(str(t.get("name", "?")), 22)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(name_label)
	var tag := UiTheme.body(str(t.get("category", "")), 13, UiTheme.TEXT_FAINT)
	tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(tag)

	var verse := UiTheme.body("\"%s\"" % str(t.get("verse", "")), 15, UiTheme.STAR)
	verse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(verse)
	var rule_text := UiTheme.body(str(t.get("rule", "")), 14, UiTheme.TEXT)
	rule_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(rule_text)

	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)
	var line := UiTheme.rule()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(line)
	var evolve := UiTheme.body("At two stars:  %s" % str(t.get("evolve_2", "unknown")), 13, UiTheme.TEXT_DIM)
	evolve.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(evolve)
	var unknowns: Array = t.get("hidden", [])
	if not unknowns.is_empty():
		var q := UiTheme.body("Still to be proven:  %s" % str(unknowns[0]), 13, UiTheme.TEXT_FAINT)
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(q)
	var wired: bool = ResourceLoader.exists("res://scripts/talents/%s.gd" % str(t.get("id", "")))
	if not wired:
		var w := UiTheme.body("(not yet playable)", 13, UiTheme.BAD)
		w.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(w)
	return b
