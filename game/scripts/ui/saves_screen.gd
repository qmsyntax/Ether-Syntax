class_name SavesScreen
extends UiScreen
## Save slots. The autosave is written whenever something changes in town; the numbered slots are
## only written when you ask, so a character can be parked at a point worth coming back to.
## Opened from town (save and load) or from the title (load only).


func backdrop() -> float:
	return 0.86


func close_actions() -> Array[String]:
	return ["settings"]


func hud_hides() -> Array[String]:
	return HUD_MENU


func build(root: Control) -> void:
	var can_save: bool = str(game.get("state")) == "town"
	var box: VBoxContainer = framed(root, 0.27, 0.1, 0.73, 0.86)
	box.add_theme_constant_override("separation", 10)
	var title := UiTheme.heading("Saved characters", UiTheme.FS_TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := UiTheme.body("The autosave follows you. A numbered slot keeps a character exactly as it is until you overwrite it."
		if can_save else "Pick a character to carry on with.", 15, UiTheme.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(UiTheme.rule())

	var list: VBoxContainer = scroller(box)
	list.add_theme_constant_override("separation", 8)
	for slot: int in SaveGame.SLOTS + 1:
		list.add_child(_row(slot, can_save))

	box.add_child(UiTheme.rule())
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(foot)
	foot.add_child(UiWidgets.small_button("Back", func() -> void: game.call("close_screen")))


func _row(slot: int, can_save: bool) -> Control:
	var data: Dictionary = SaveGame.read(SaveGame.slot_path(slot))
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.frame("panel_plain", 12.0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	text.add_child(UiTheme.heading("Autosave" if slot == 0 else "Slot %d" % slot, UiTheme.FS_HEAD - 1, UiTheme.GOLD if not data.is_empty() else UiTheme.TEXT_DIM))
	text.add_child(UiTheme.body(SaveGame.describe(data), UiTheme.FS_SMALL, UiTheme.TEXT_FAINT if data.is_empty() else UiTheme.TEXT))
	if can_save and slot > 0:
		var save: Button = UiWidgets.small_button("Save here" if data.is_empty() else "Overwrite", func() -> void:
			game.call("save_to_slot", slot)
			rebuild())
		save.custom_minimum_size = Vector2(128, 40)
		save.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(save)
	if not data.is_empty():
		var load_b: Button = UiWidgets.small_button("Load", func() -> void: game.call("load_slot", slot))
		load_b.custom_minimum_size = Vector2(96, 40)
		load_b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(load_b)
	return card
