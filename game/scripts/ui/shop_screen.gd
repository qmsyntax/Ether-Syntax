extends UiScreen
## The merchant. Hard prices, honest ones: what you see is what it costs (Pillar 4).


func backdrop() -> float:
	return 0.6


func hud_hides() -> Array[String]:
	return HUD_MENU


func build(root: Control) -> void:
	var inv: Inventory = player.get("inventory")
	var money: int = int(player.get("money"))
	var box: VBoxContainer = framed(root, 0.2, 0.05, 0.8, 0.775)

	var head := HBoxContainer.new()
	box.add_child(head)
	var title := UiTheme.heading("Merchant", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var purse := UiTheme.body("Purse  %s      Pack  %d / %d kg" % [UiTheme.money_text(money), int(inv.weight()), int(inv.capacity())], 16,
		UiTheme.BAD if money < 0 else UiTheme.GOLD)
	purse.autowrap_mode = TextServer.AUTOWRAP_OFF
	purse.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(purse)
	box.add_child(UiTheme.rule())

	var list: VBoxContainer = scroller(box)
	for id: Variant in GameData.items_file.get("shop", []):
		list.add_child(_row(str(id), inv))
	# scrolls: only the ones this character could read, and does not already own
	for id: Variant in GameData.items_file.get("shop_scrolls", []):
		if str(player.call("can_learn", str(GameData.item(str(id)).get("teaches", "")))) == "" and not inv.bag.has(str(id)):
			list.add_child(_row(str(id), inv))

	box.add_child(UiTheme.rule())
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(foot)
	foot.add_child(UiWidgets.small_button("Back to town", func() -> void: game.call("close_screen")))


func _row(id: String, inv: Inventory) -> Control:
	var def: Dictionary = GameData.item(id)
	var price: int = int(def.get("value", 0))
	var afford: bool = bool(player.call("can_afford", price))
	var carry: bool = inv.can_add(id)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL_HI, UiTheme.BRONZE_DIM, 1, 4, 10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	row.add_child(UiWidgets.Icon.new(UiDraw.item_icon(def), UiTheme.GOLD, 52.0))

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	var name_label := UiTheme.body(str(def.get("name", id)), 19, UiTheme.TEXT)
	col.add_child(name_label)
	var stats: String = UiWidgets.item_stats_text(def)
	if stats != "":
		col.add_child(UiTheme.body(stats, 14, UiTheme.GOOD))
	col.add_child(UiTheme.body("%s   %.1f kg" % [str(def.get("desc", "")), float(def.get("weight", 0.0))], 13, UiTheme.TEXT_DIM))

	var buy_col := VBoxContainer.new()
	buy_col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(buy_col)
	var price_label := UiTheme.body("$%d" % price, 18, UiTheme.GOLD if afford else UiTheme.BAD)
	price_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	buy_col.add_child(price_label)
	var why: String = "Buy" if afford and carry else ("No credit" if not afford else "Too heavy")
	buy_col.add_child(UiWidgets.small_button(why, func() -> void:
		game.call("town_buy", id)
		rebuild(), afford and carry))
	return panel
