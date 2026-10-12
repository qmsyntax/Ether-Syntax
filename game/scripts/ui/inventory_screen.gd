extends UiScreen
## Inventory and character sheet in one: what you wear, what you carry, your abilities and the
## constructs waiting to be bound into them. This is also where you choose WHICH ability a
## construct goes into (the Bind key only takes the first match).

const SLOT_LABELS := {"weapon": "Weapon", "back": "Back", "satellite": "Satellite", "trinket": "Trinket"}


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
# Three ways to equip, so nobody has to hunt for it: click the item, right-click it, or drag it
# onto a slot. Slots that would accept the item being dragged light up.

func _build_gear(box: VBoxContainer, inv: Inventory) -> void:
	box.add_child(UiTheme.heading("Worn", 24))
	box.add_child(UiTheme.body("Click gear in your pack to equip it, or drag it onto a slot.", 13, UiTheme.TEXT_DIM))
	box.add_child(UiTheme.rule())
	for slot: String in Inventory.SLOTS:
		box.add_child(SlotPanel.new(self, slot, inv))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	box.add_child(UiTheme.rule())
	box.add_child(UiWidgets.stat_row("Purse", UiTheme.money_text(int(player.get("money"))), UiTheme.BAD if int(player.get("money")) < 0 else UiTheme.GOLD))
	var rate: float = float(player.get("satellite_rate"))
	box.add_child(UiWidgets.stat_row("Essence from satellite", ("+%d / s" % int(rate)) if rate > 0.0 else "none"))
	box.add_child(UiWidgets.small_button("Close  (%s)" % Keybinds.binding_text("inventory"), func() -> void: game.call("close_screen")))


## Equip an item from the pack and say why not if it fails.
func equip_item(id: String) -> void:
	var inv: Inventory = player.get("inventory")
	var result: String = inv.equip(id)
	if result == "equipped":
		player.call("note", "Equipped %s." % str(GameData.item(id).get("name", id)))
	else:
		player.call("note", "Cannot equip that: %s." % result)
	player.call("refresh_gear")
	game.call("save_now")
	rebuild()


func unequip_slot(slot: String) -> void:
	var inv: Inventory = player.get("inventory")
	var result: String = inv.unequip(slot)
	if result != "unequipped":
		player.call("note", "Cannot take that off: %s." % result)
	player.call("refresh_gear")
	game.call("save_now")
	rebuild()


## One equipment slot. Shows what is in it, and accepts a dragged item that fits.
class SlotPanel extends PanelContainer:
	var screen: Control
	var slot := ""
	var _lit := false

	func _init(owner_screen: Control, slot_name: String, inv: Inventory) -> void:
		screen = owner_screen
		slot = slot_name
		custom_minimum_size = Vector2(0, 68)
		_style(false)
		var id: String = str(inv.equipped.get(slot, ""))
		var def: Dictionary = GameData.item(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(row)
		var empty_icon: String = {"weapon": "blade", "back": "pack", "satellite": "mote", "trinket": "charm"}[slot]
		row.add_child(UiWidgets.Icon.new(UiDraw.item_icon(def) if id != "" else empty_icon, UiTheme.GOLD if id != "" else Color(0.3, 0.28, 0.25), 48.0))
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 1)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(col)
		col.add_child(UiTheme.body(str(SLOT_LABELS[slot]).to_upper(), 12, UiTheme.TEXT_FAINT))
		if id != "":
			col.add_child(UiTheme.body(str(def.get("name", id)), 17, UiTheme.TEXT))
			var useless: bool = slot == "weapon" and bool((screen.get("player") as Node).get("arm_right_lost"))
			col.add_child(UiTheme.body("no arm to hold it - does nothing" if useless else UiWidgets.item_stats_text(def), 13, UiTheme.BAD if useless else UiTheme.GOOD))
			row.add_child(UiWidgets.small_button("Take off", func() -> void: screen.call("unequip_slot", slot)))
		else:
			col.add_child(UiTheme.body("Empty", 17, UiTheme.TEXT_FAINT))
			var hint: String = {"weapon": "bare fists - a weapon goes here", "back": "a backpack goes here", "satellite": "a satellite goes here - buy one from the merchant", "trinket": "a charm or coil goes here"}[slot]
			col.add_child(UiTheme.body(hint, 12, UiTheme.TEXT_FAINT))

	func _style(lit: bool) -> void:
		_lit = lit
		add_theme_stylebox_override("panel", UiTheme.box(Color("2f2a1c") if lit else UiTheme.PANEL_HI, UiTheme.GOLD if lit else UiTheme.BRONZE_DIM, 2 if lit else 1, 4, 8))

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		var ok: bool = typeof(data) == TYPE_DICTIONARY and str(GameData.item(str((data as Dictionary).get("item", ""))).get("slot", "")) == slot
		if ok != _lit:
			_style(ok)
		return ok

	func _drop_data(_at: Vector2, data: Variant) -> void:
		screen.call("equip_item", str((data as Dictionary)["item"]))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT:
			if _lit:
				_style(false)


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
	# stack identical items so twelve tusks are one row; gear first, loot after
	var counts: Dictionary = {}
	var gear: Array[String] = []
	var loot: Array[String] = []
	for id: String in inv.bag:
		if not counts.has(id):
			counts[id] = 0
			if str(GameData.item(id).get("slot", "")) != "":
				gear.append(id)
			else:
				loot.append(id)
		counts[id] = int(counts[id]) + 1
	if not gear.is_empty():
		list.add_child(UiTheme.body("GEAR  -  click to equip", 13, UiTheme.GOLD))
		for id: String in gear:
			list.add_child(_bag_row(id, int(counts[id]), true))
	if not loot.is_empty():
		if not gear.is_empty():
			list.add_child(Control.new())
		list.add_child(UiTheme.body("LOOT  -  only good for selling", 13, UiTheme.TEXT_DIM))
		for id: String in loot:
			list.add_child(_bag_row(id, int(counts[id]), false))


func _bag_row(id: String, count: int, equippable: bool) -> Control:
	var def: Dictionary = GameData.item(id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var item := ItemButton.new(self, id, equippable)
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(item)

	var inner := HBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 8
	inner.offset_right = -10
	inner.offset_top = 4
	inner.offset_bottom = -4
	inner.add_theme_constant_override("separation", 10)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(inner)
	inner.add_child(UiWidgets.Icon.new(UiDraw.item_icon(def), UiTheme.GOLD if equippable else UiTheme.TEXT_DIM, 40.0))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(col)
	var name_label := UiTheme.body("%s%s" % [str(def.get("name", id)), ("  x%d" % count) if count > 1 else ""], 16, UiTheme.TEXT)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_label)
	var detail: String = UiWidgets.item_stats_text(def) if equippable else "worth $%d each" % int(def.get("value", 0))
	var detail_label := UiTheme.body("%s   %.1f kg" % [detail, float(def.get("weight", 0.0))], 12, UiTheme.GOOD if equippable else UiTheme.TEXT_DIM)
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(detail_label)
	if equippable:
		var tag := UiTheme.body("EQUIP", 14, UiTheme.GOLD)
		tag.autowrap_mode = TextServer.AUTOWRAP_OFF
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(tag)

	if str(game.get("state")) == "town":
		var inv: Inventory = player.get("inventory")
		row.add_child(UiWidgets.small_button("Sell $%d" % inv.sale_price(id), func() -> void:
			game.call("town_sell_item", id)
			rebuild()))
	else:
		row.add_child(UiWidgets.small_button("Drop", func() -> void:
			game.call("drop_item", id)
			rebuild()))
	return row


## A pack item as one big button. Gear equips on a left or right click and can be dragged onto
## a slot; loot does nothing when clicked (it is only for selling).
class ItemButton extends Button:
	var screen: Control
	var item_id := ""
	var equippable := false

	func _init(owner_screen: Control, id: String, can_equip: bool) -> void:
		screen = owner_screen
		item_id = id
		equippable = can_equip
		custom_minimum_size = Vector2(0, 52)
		focus_mode = Control.FOCUS_NONE
		button_mask = MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT
		tooltip_text = str(GameData.item(id).get("desc", ""))
		if equippable:
			add_theme_stylebox_override("normal", UiTheme.box(UiTheme.PANEL_HI, UiTheme.BRONZE, 1, 4, 10))
			pressed.connect(func() -> void: screen.call("equip_item", item_id))
		else:
			mouse_default_cursor_shape = Control.CURSOR_ARROW
			add_theme_stylebox_override("normal", UiTheme.box(Color("1a1713"), Color("2c261f"), 1, 4, 10))
			add_theme_stylebox_override("hover", UiTheme.box(Color("1f1b16"), UiTheme.BRONZE_DIM, 1, 4, 10))
			add_theme_stylebox_override("pressed", UiTheme.box(Color("1f1b16"), UiTheme.BRONZE_DIM, 1, 4, 10))

	func _get_drag_data(_at: Vector2) -> Variant:
		if not equippable:
			return null
		var ghost := Label.new()
		ghost.text = str(GameData.item(item_id).get("name", item_id))
		ghost.add_theme_color_override("font_color", UiTheme.GOLD)
		ghost.add_theme_font_size_override("font_size", 18)
		set_drag_preview(ghost)
		return {"item": item_id}


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
