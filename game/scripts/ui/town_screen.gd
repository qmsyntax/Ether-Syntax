extends UiScreen
## Town: services on the left, your ledger on the right. The orbs and action bar stay visible
## underneath so you can see your state while you decide.


func backdrop() -> float:
	return 0.45


func build(root: Control) -> void:
	var inv: Inventory = player.get("inventory")
	var body: Body = player.get("body")
	var money: int = int(player.get("money"))

	# --- services ---------------------------------------------------------------
	var left: VBoxContainer = framed(root, 0.24, 0.04, 0.66, 0.775)
	left.add_theme_constant_override("separation", 7)
	var head := HBoxContainer.new()
	left.add_child(head)
	var title := UiTheme.heading("TOWN", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var day_label := UiTheme.body("day %d%s" % [int(game.get("day")), "   -   hardcore" if bool(game.get("hardcore")) else ""], 16, UiTheme.TEXT_DIM)
	day_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	day_label.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(day_label)
	left.add_child(UiTheme.rule())

	var ticket: int = int(game.get("ticket_price"))
	var mult: float = float(game.call("repeat_mult"))
	left.add_child(UiWidgets.service_button("Enter the assault passage",
		"Owned: a ticket, and a meter while inside. Clear %d of %d walls to open an exit; carry the spoils out to keep them. Pays x%.2f." % [
			int(game.get("gate_at")), int(game.get("chambers")), mult],
		"ticket  $%d" % ticket, func() -> void: game.call("enter_passage"), bool(player.call("can_afford", ticket))))
	left.add_child(UiWidgets.service_button("Practice arena", "Free. Whatever you kill leaves something to sell.",
		"free", func() -> void: game.call("enter_arena")))
	left.add_child(UiWidgets.service_button("A room at the inn", "A night's sleep. Cuts close and bones knit a little. What is gone stays gone.",
		"room  $%d" % int(game.get("night_rent")), func() -> void:
			game.call("town_rest_night")
			rebuild()))
	var bodies: Array = player.get("corpses")
	if not bodies.is_empty():
		var fee: int = int(player.call("corpse_fee"))
		left.add_child(UiWidgets.service_button("Corpse retrieval",
			"Your body lies %s with everything you had on it. Walk back for it, or pay the collectors to bring it.%s" % [
				"in the passage" if str((bodies.back() as Dictionary).get("where", "")) == "passage" else "in the arena",
				"" if bodies.size() == 1 else "  (%d bodies; this brings the newest.)" % bodies.size()],
			"$%d" % fee, func() -> void:
				var why: String = player.call("buy_corpse_retrieval")
				if why != "":
					player.call("note", why)
				game.call("save_now")
				rebuild(), bool(player.call("can_afford", fee))))
	var heal: Dictionary = player.call("next_healing")
	left.add_child(UiWidgets.service_button("Healer", str(heal["desc"]),
		("$%d" % int(heal["cost"])) if int(heal["cost"]) > 0 else "",
		func() -> void:
			player.call("buy_healing")
			game.call("save_now")
			rebuild(), int(heal["cost"]) > 0 and bool(player.call("can_afford", int(heal["cost"])))))
	left.add_child(UiWidgets.service_button("Tempering yard", "Break the body a little, on purpose. It comes back harder.", "",
		func() -> void: game.call("open_tempering")))
	left.add_child(UiWidgets.service_button("Merchant", "Satellites, packs and trinkets. Credit extended, to a point.", "",
		func() -> void: game.call("open_shop")))
	var loot: int = inv.loot_value()
	left.add_child(UiWidgets.service_button("Sell your loot", "Everything in your pack that is not gear." if loot > 0 else "Nothing in your pack that anyone wants.",
		("+$%d" % loot) if loot > 0 else "", func() -> void:
			game.call("town_sell_loot")
			rebuild(), loot > 0))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	left.add_child(UiTheme.rule())
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	left.add_child(foot)
	foot.add_child(UiWidgets.small_button("Ethercosm  (%s)" % Keybinds.binding_text("ethercosm"), func() -> void: game.call("open_ethercosm")))
	foot.add_child(UiWidgets.small_button("Inventory  (%s)" % Keybinds.binding_text("inventory"), func() -> void: game.call("open_inventory")))
	foot.add_child(UiWidgets.small_button("Save / load", func() -> void: game.call("open_saves")))
	foot.add_child(UiWidgets.small_button("Controls", func() -> void: game.call("open_settings")))
	foot.add_child(UiWidgets.small_button("New character", func() -> void: game.call("new_character")))

	# --- ledger ------------------------------------------------------------------
	var right: VBoxContainer = framed(root, 0.67, 0.04, 0.985, 0.775)
	right.add_theme_constant_override("separation", 6)
	right.add_child(UiTheme.heading("Ledger", 22))
	right.add_child(UiTheme.rule())
	right.add_child(UiWidgets.stat_row("Purse", UiTheme.money_text(money), UiTheme.BAD if money < 0 else UiTheme.GOLD))
	var last: int = int(game.get("_last_payout"))
	if last > 0:
		right.add_child(UiWidgets.stat_row("Last delve carried out", "$%d" % last))
	right.add_child(UiWidgets.stat_row("Delves made", str(int(game.get("delves")))))
	right.add_child(UiWidgets.stat_row("Pack", "%d of %d kg" % [int(inv.weight()), int(inv.capacity())]))

	right.add_child(Control.new())
	right.add_child(UiTheme.heading("Condition", 18))
	right.add_child(UiTheme.rule())
	right.add_child(UiWidgets.Bar.new(body.total() / body.total_max(), UiTheme.HEALTH_SUPERFICIAL,
		"health  %d / %d" % [int(ceil(body.total())), int(body.total_max())], 20.0))
	if body.wounds.is_empty():
		right.add_child(UiTheme.body("No wounds.", 14, UiTheme.TEXT_DIM))
	for w: Dictionary in body.wounds:
		right.add_child(UiTheme.body("%s  -  costs you %d health  -  %s" % [str(w["name"]), int(round(float(w["max_cut"]))), Body.wound_state(w)], 14, Color("ff8a5c")))
	if bool(player.get("arm_right_lost")):
		right.add_child(UiTheme.body("Striking arm: LOST. Rest will not bring it back.", 14, UiTheme.BAD))
	else:
		right.add_child(UiWidgets.Bar.new(float(player.get("arm_right")) / 100.0, Color(0.72, 0.74, 0.82), "striking arm  %d%%" % int(float(player.get("arm_right"))), 20.0))

	right.add_child(Control.new())
	right.add_child(UiTheme.heading("Soul", 18))
	right.add_child(UiTheme.rule())
	var pcts: Array = player.get("star_pct")
	for i: int in pcts.size():
		right.add_child(UiWidgets.Bar.new(float(pcts[i]) / 99.0, UiTheme.STAR.darkened(0.25), "star %d   %d%%" % [i + 1, int(float(pcts[i]))], 20.0))
	var aura := UiTheme.body(str(player.call("aura_read")), 14, UiTheme.STAR)
	right.add_child(aura)
	var rate: float = float(player.get("satellite_rate"))
	right.add_child(UiTheme.body(("Satellite: +%d essence per second." % int(rate)) if rate > 0.0 else "No satellite. Essence returns only when you meditate.", 14, UiTheme.TEXT_DIM))
