class_name SavesScreen
extends UiScreen
## Save slots. The autosave is written whenever something changes in town; the numbered slots are
## only written when you ask, so a character can be parked at a point worth coming back to.
## Opened from town (save and load) or from the title (load only).


func backdrop() -> float:
	return 0.86


func close_actions() -> Array[String]:
	return ["settings"]


func build(root: Control) -> void:
	var can_save: bool = str(game.get("state")) == "town"
	var box: VBoxContainer = framed(root, 0.24, 0.14, 0.76, 0.86)
	box.add_theme_constant_override("separation", 10)
	var title := UiTheme.heading("SAVED CHARACTERS", 30)
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
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(UiTheme.heading("Autosave" if slot == 0 else "Slot %d" % slot, 19))
	text.add_child(UiTheme.body(SaveGame.describe(data), 14, UiTheme.TEXT_DIM if data.is_empty() else UiTheme.TEXT))
	if can_save and slot > 0:
		row.add_child(UiWidgets.small_button("Save here" if data.is_empty() else "Overwrite", func() -> void:
			game.call("save_to_slot", slot)
			rebuild()))
	if not data.is_empty():
		row.add_child(UiWidgets.small_button("Load", func() -> void: game.call("load_slot", slot)))
	return row
