extends UiScreen
## Inventory and character sheet in one: what you wear, what you carry, your abilities and the
## constructs waiting to be bound into them. This is also where you choose WHICH ability a
## construct goes into (the Bind key only takes the first match).

const SLOT_LABELS := {"back": "Back", "satellite": "Satellite", "trinket": "Trinket"}


func backdrop() -> float:
	return 0.65


func close_actions() -> Array[String]:
	return ["inventory", "settings"]


func build(root: Control) -> void:
	var inv: Inventory = player.get("inventory")
	_build_gear(framed(root, 0.03, 0.05, 0.30, 0.775), inv)
	_build_bag(framed(root, 0.31, 0.05, 0.65, 0.775), inv)
	_build_soul(framed(root, 0.66, 0.05, 0.97, 0.775))


# --- worn ------------------------------------------------------------------------------

func _build_gear(box: VBoxContainer, inv: Inventory) -> void:
	box.add_child(UiTheme.heading("Worn", 24))
	box.add_child(UiTheme.rule())
	for slot: String in Inventory.SLOTS:
		var id: String = str(inv.equipped.get(slot, ""))
		var def: Dictionary = GameData.item(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		box.add_child(row)
		row.add_child(UiWidgets.Icon.new(UiDraw.item_icon(def) if id != "" else "crate", UiTheme.GOLD if id != "" else UiTheme.TEXT_FAINT, 48.0))
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 1)
		row.add_child(col)
		col.add_child(UiTheme.body(str(SLOT_LABELS[slot]), 12, UiTheme.TEXT_FAINT))
		col.add_child(UiTheme.body(str(def.get("name", "- empty -")) if id != "" else "- empty -", 17, UiTheme.TEXT if id != "" else UiTheme.TEXT_FAINT))
		if id != "":
			col.add_child(UiTheme.body(UiWidgets.item_stats_text(def), 13, UiTheme.GOOD))
			row.add_child(UiWidgets.small_button("Take off", func() -> void:
				var result: String = inv.unequip(slot)
				if result != "unequipped":
					player.call("note", "Cannot take that off: %s." % result)
				player.call("refresh_gear")
				rebuild()))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	box.add_child(UiTheme.rule())
	box.add_child(UiWidgets.stat_row("Purse", UiTheme.money_text(int(player.get("money"))), UiTheme.BAD if int(player.get("money")) < 0 else UiTheme.GOLD))
	var rate: float = float(player.get("satellite_rate"))
	box.add_child(UiWidgets.stat_row("Essence from satellite", ("+%d / s" % int(rate)) if rate > 0.0 else "none"))
	box.add_child(UiWidgets.small_button("Close  (%s)" % Keybinds.binding_text("inventory"), func() -> void: game.call("close_screen")))


# --- carried ---------------------------------------------------------------------------

func _build_bag(box: VBoxContainer, inv: Inventory) -> void:
	box.add_child(UiTheme.heading("Pack", 24))
	var w: float = inv.weight()
	var cap: float = maxf(1.0, inv.capacity())
	box.add_child(UiWidgets.Bar.new(w / cap, UiTheme.BAD if w > cap * 0.9 else UiTheme.BRONZE,
		"%d of %d kg      loot worth $%d" % [int(w), int(cap), inv.loot_value()], 20.0))
	box.add_child(UiTheme.rule())
	var list: VBoxContainer = scroller(box)
	if inv.bag.is_empty():
		list.add_child(UiTheme.body("Your pack is empty.", 15, UiTheme.TEXT_FAINT))
		return
	# stack identical items so twelve tusks are one row
	var counts: Dictionary = {}
	var order: Array[String] = []
	for id: String in inv.bag:
		if not counts.has(id):
			counts[id] = 0
			order.append(id)
		counts[id] = int(counts[id]) + 1
	for id: String in order:
		list.add_child(_bag_row(id, int(counts[id]), inv))


func _bag_row(id: String, count: int, inv: Inventory) -> Control:
	var def: Dictionary = GameData.item(id)
	var equippable: bool = str(def.get("slot", "")) != ""
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(UiWidgets.Icon.new(UiDraw.item_icon(def), UiTheme.GOLD if equippable else UiTheme.TEXT_DIM, 40.0))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	col.add_child(UiTheme.body("%s%s" % [str(def.get("name", id)), ("  x%d" % count) if count > 1 else ""], 16, UiTheme.TEXT))
	var detail: String = UiWidgets.item_stats_text(def) if equippable else "worth $%d each" % int(def.get("value", 0))
	col.add_child(UiTheme.body("%s   %.1f kg" % [detail, float(def.get("weight", 0.0))], 12, UiTheme.GOOD if equippable else UiTheme.TEXT_DIM))
	if equippable:
		row.add_child(UiWidgets.small_button("Wear", func() -> void:
			var result: String = inv.equip(id)
			if result != "equipped":
				player.call("note", "Cannot wear that: %s." % result)
			player.call("refresh_gear")
			rebuild()))
	row.add_child(UiWidgets.small_button("Drop", func() -> void:
		game.call("drop_item", id)
		rebuild()))
	return row


# --- soul: abilities and constructs ------------------------------------------------------

func _build_soul(box: VBoxContainer) -> void:
	box.add_child(UiTheme.heading("Abilities", 24))
	box.add_child(UiTheme.rule())
	var abilities: Array = player.get("abilities")
	var held: Array = player.get("constructs")
	var list: VBoxContainer = scroller(box)
	for ai: int in abilities.size():
		var st: Dictionary = abilities[ai]
		var ab: Dictionary = player.call("ability_stats", st)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		list.add_child(head)
		head.add_child(UiWidgets.Icon.new(str(ab.get("icon", "drop")), UiTheme.ESSENCE.lightened(0.35), 40.0))
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)
		head.add_child(col)
		col.add_child(UiTheme.body("%s   -   stage %d" % [str(ab.get("name", "?")), int(st["stage"])], 16, UiTheme.TEXT))
		var need: String = str(player.call("pending_tier", st))
		col.add_child(UiWidgets.Bar.new(float(st["progress"]) / 100.0, UiTheme.GOLD if need != "" else UiTheme.ESSENCE,
			("FULL - needs a %s" % need) if need != "" else "%d%%   costs %d essence" % [int(float(st["progress"])), int(round(float(ab.get("cost", 0.0))))], 22.0))
		var bound: Array = st.get("bound", [])
		if not bound.is_empty():
			var names: Array[String] = []
			for up: Dictionary in bound:
				names.append("%s of %s" % [str(up["tier"]), str(GameData.concept(str(up["concept"])).get("label", up["concept"]))])
			col.add_child(UiTheme.body("Bound: " + ", ".join(names), 12, UiTheme.STAR))
		if need != "":
			for ci: int in held.size():
				if str(held[ci]["tier"]) == need:
					var label: String = str(GameData.concept(str(held[ci]["concept"])).get("label", held[ci]["concept"]))
					col.add_child(UiWidgets.small_button("Bind the %s of %s  (irreversible, may fail)" % [need, label], func() -> void:
						player.call("bind_construct", ai, ci)
						rebuild()))
		list.add_child(UiTheme.rule())

	box.add_child(UiTheme.heading("Constructs carried", 18))
	if held.is_empty():
		box.add_child(UiTheme.body("None. For now they come from the strongest things you kill.", 13, UiTheme.TEXT_FAINT))
	else:
		var names2: Array[String] = []
		for c: Dictionary in held:
			names2.append("%s of %s" % [str(c["tier"]), str(GameData.concept(str(c["concept"])).get("label", c["concept"]))])
		box.add_child(UiTheme.body(", ".join(names2), 14, UiTheme.GOLD))
	var proven: Array = player.get("discoveries")
	if not proven.is_empty():
		box.add_child(UiTheme.heading("Proven about your talent", 18))
		for line: String in proven:
			box.add_child(UiTheme.body(line, 13, UiTheme.TEXT_DIM))
