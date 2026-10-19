class_name TemperingScreen
extends UiScreen
## The tempering yard. Every technique the character knows runs all the time; what happens here
## is the training - a session strains the body (a wound that rest mends) and moves that
## technique's stage along.


func backdrop() -> float:
	return 0.6


func hud_hides() -> Array[String]:
	return HUD_MENU


func build(root: Control) -> void:
	var b: Body = player.get("body")
	var box: VBoxContainer = framed(root, 0.2, 0.05, 0.8, 0.775)

	var head := HBoxContainer.new()
	box.add_child(head)
	var title := UiTheme.heading("Tempering yard", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var state := UiTheme.body("health  %d of %d%s" % [int(b.total_max()), int(b.max_hp), "   -   strained" if b.has_wound("temper_strain") else ""], 16,
		UiTheme.BAD if b.max_cut() > 0.0 else UiTheme.TEXT)
	state.autowrap_mode = TextServer.AUTOWRAP_OFF
	state.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(state)
	box.add_child(UiTheme.body("A body is made tougher by being broken a little, on purpose, and mending. Everything you have tempered works at once, always. A session strains you: it takes a slice off your health until a night's rest or the healer mends it.", 14, UiTheme.TEXT_DIM))
	box.add_child(UiTheme.rule())

	var list: VBoxContainer = scroller(box)
	var known: Dictionary = player.get("tempering")
	if known.is_empty():
		list.add_child(UiTheme.body("You know no tempering techniques.", 15, UiTheme.TEXT_FAINT))
	for id: String in known:
		list.add_child(_row(id))

	box.add_child(UiTheme.rule())
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(foot)
	foot.add_child(UiWidgets.small_button("Back to town", func() -> void: game.call("close_screen")))


func _row(id: String) -> Control:
	var def: Dictionary = GameData.technique(id)
	var st: Dictionary = (player.get("tempering") as Dictionary)[id]
	var stage: int = int(st["stage"])
	var cap: int = int(player.call("temper_stage_cap"))
	var why: String = str(player.call("cannot_temper_reason", id))
	var aff: String = str(def.get("affinity", ""))

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL_HI, UiTheme.BRONZE_DIM, 1, 4, 10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	row.add_child(col)
	var name_row := HBoxContainer.new()
	col.add_child(name_row)
	var name_label := UiTheme.body(str(def.get("name", id)), 19, UiTheme.TEXT)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_row.add_child(name_label)
	var tag := UiTheme.body(("%s tempering" % str(GameData.affinity(aff).get("label", aff)).to_lower()) if aff != "" else "body tempering", 13,
		GameData.affinity_color(aff).lightened(0.3) if aff != "" else UiTheme.TEXT_FAINT)
	tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_row.add_child(tag)
	col.add_child(UiTheme.body("\"%s\"" % str(def.get("verse", "")), 13, UiTheme.STAR))
	col.add_child(UiWidgets.Bar.new(float(st["progress"]) / 100.0, UiTheme.GOLD,
		"stage %d   -   %d%%" % [stage, int(float(st["progress"]))] if stage < cap else "stage %d   -   as far as %d star%s will carry it" % [stage, int(player.get("stars")), "" if int(player.get("stars")) == 1 else "s"], 20.0))
	var now_text: String = str(player.call("temper_effect_text", id, stage))
	var next_text: String = str(player.call("temper_effect_text", id, stage + 1))
	col.add_child(UiTheme.body(("Now:  %s" % now_text) if stage > 0 else "Now:  nothing yet", 14, UiTheme.GOOD if stage > 0 else UiTheme.TEXT_DIM))
	if stage < cap:
		col.add_child(UiTheme.body("At stage %d:  %s" % [stage + 1, next_text], 14, UiTheme.TEXT_DIM))

	var side := VBoxContainer.new()
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(side)
	var train := UiWidgets.small_button("Train", func() -> void:
		player.call("temper_session", id)
		game.call("save_now")
		rebuild(), why == "")
	train.set_meta("technique", id)
	train.custom_minimum_size = Vector2(120, 44)
	side.add_child(train)
	var cost := UiTheme.body(why if why != "" else "strains you by %d   +%d%%" % [int(round(float(player.call("temper_session_damage", id)))), int(round(float(player.call("temper_session_progress", id))))],
		12, UiTheme.BAD if why != "" else UiTheme.TEXT_DIM)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.custom_minimum_size = Vector2(170, 0)
	side.add_child(cost)
	return panel
