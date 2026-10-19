class_name TalkScreen
extends UiScreen
## Talking to someone in town (design/08 section 3): who they are and what they do for you on the
## left, your ledger on the right. These are the old town menu's services, one person each; the
## role (data/town.json "folk") decides which. Walk away, press the interact key or Done to stop.

var role := ""


func _init(game_node: Node, who: String) -> void:
	super(game_node)
	role = who


func backdrop() -> float:
	return 0.2


## The ledger on the right repeats the HUD's plate and log.
func hud_hides() -> Array[String]:
	return HUD_MENU


func build(root: Control) -> void:
	var f: Dictionary = GameData.town_folk(role)
	var box: VBoxContainer = framed(root, 0.24, 0.06, 0.62, 0.56)
	box.add_theme_constant_override("separation", 6)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := UiTheme.heading(str(f.get("name", role)), 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var what := UiTheme.body(str(f.get("title", "")), 16, UiTheme.TEXT_DIM)
	what.autowrap_mode = TextServer.AUTOWRAP_OFF
	what.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(what)
	box.add_child(UiTheme.rule())
	box.add_child(UiTheme.body("\"%s\"" % str(f.get("line", "")), 15, UiTheme.TEXT_DIM))
	box.add_child(Control.new())

	match role:
		"healer":
			_healer(box)
		"merchant":
			_merchant(box)
		"innkeeper":
			_innkeeper(box)
		"trainer":
			_trainer(box)
		"passage_clerk":
			_passage(box)
		"tempering":
			box.add_child(UiWidgets.service_button("Train in the yard", "Break the body a little, on purpose. It comes back harder.", "",
				func() -> void: game.call("open_tempering")))
		"corpse_clerk":
			_corpses(box)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	box.add_child(UiTheme.rule())
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(foot)
	var done := UiWidgets.small_button("Done  (%s)" % Keybinds.binding_text("interact"), func() -> void: game.call("close_screen"))
	done.name = "DoneButton"
	foot.add_child(done)
	_ledger(root)


func _healer(box: VBoxContainer) -> void:
	var heal: Dictionary = player.call("next_healing")
	box.add_child(UiWidgets.service_button("Be seen to", str(heal["desc"]),
		("$%d" % int(heal["cost"])) if int(heal["cost"]) > 0 else "",
		func() -> void:
			player.call("buy_healing")
			game.call("save_now")
			rebuild(), int(heal["cost"]) > 0 and bool(player.call("can_afford", int(heal["cost"])))))


func _merchant(box: VBoxContainer) -> void:
	box.add_child(UiWidgets.service_button("See the wares", "Satellites, packs, trinkets and scrolls. Credit extended, to a point.", "",
		func() -> void: game.call("open_shop")))
	var inv: Inventory = player.get("inventory")
	var loot: int = inv.loot_value()
	box.add_child(UiWidgets.service_button("Sell your loot", "Everything in your pack that is not gear." if loot > 0 else "Nothing in your pack that anyone wants.",
		("+$%d" % loot) if loot > 0 else "", func() -> void:
			game.call("town_sell_loot")
			rebuild(), loot > 0))
	box.add_child(UiTheme.body("Gear you no longer want sells one piece at a time from your pack (%s)." % Keybinds.binding_text("inventory"), 13, UiTheme.TEXT_FAINT))


func _innkeeper(box: VBoxContainer) -> void:
	box.add_child(UiWidgets.service_button("A room for the night", "A night's sleep. Cuts close and bones knit a little. What is gone stays gone.",
		"room  $%d" % int(game.get("night_rent")), func() -> void:
			game.call("town_rest_night")
			rebuild()))
	box.add_child(UiWidgets.service_button("The register", "Write your name in the book, or find an older entry: save and load.", "",
		func() -> void: game.call("open_saves")))
	box.add_child(UiWidgets.service_button("Someone else", "Leave this life on the shelf and begin a new character.", "",
		func() -> void: game.call("new_character")))


func _trainer(box: VBoxContainer) -> void:
	var pts: int = int(player.get("skill_points"))
	box.add_child(UiWidgets.service_button("Training", "Learn a skill on your affinities' trees, or drill one you know. Points come as your star grows.",
		"%d point%s" % [pts, "" if pts == 1 else "s"], func() -> void: game.call("open_skill_tree", true)))


func _passage(box: VBoxContainer) -> void:
	var ticket: int = int(game.get("ticket_price"))
	var mult: float = float(game.call("repeat_mult"))
	box.add_child(UiWidgets.service_button("A ticket into the assault passage",
		"Owned: ticket and meter. %d of %d walls for an exit; carry spoils out. x%.2f" % [
			int(game.get("gate_at")), int(game.get("chambers")), mult],
		"ticket  $%d" % ticket, func() -> void: game.call("enter_passage"), bool(player.call("can_afford", ticket))))


func _corpses(box: VBoxContainer) -> void:
	var bodies: Array = player.get("corpses")
	if bodies.is_empty():
		box.add_child(UiTheme.body("No body of yours lies out there. Come back when one does.", 15, UiTheme.TEXT_DIM))
		return
	var fee: int = int(player.call("corpse_fee"))
	box.add_child(UiWidgets.service_button("Corpse retrieval",
		"Your body lies %s with everything you had on it. Walk back for it, or pay the collectors to bring it.%s" % [
			_where_name(str((bodies.back() as Dictionary).get("where", ""))),
			"" if bodies.size() == 1 else "  (%d bodies; this brings the newest.)" % bodies.size()],
		"$%d" % fee, func() -> void:
			var why: String = player.call("buy_corpse_retrieval")
			if why != "":
				player.call("note", why)
			game.call("save_now")
			rebuild(), bool(player.call("can_afford", fee))))


## Where a corpse lies, in words.
func _where_name(where: String) -> String:
	if where == "passage":
		return "in the passage"
	if where == "arena":
		return "in the arena"
	return "out in %s" % str(GameData.zone(where).get("name", where))


## Your state while you decide: purse, pack, condition, soul (the old town menu's right half).
func _ledger(root: Control) -> void:
	var inv: Inventory = player.get("inventory")
	var body: Body = player.get("body")
	var money: int = int(player.get("money"))
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
	right.add_child(UiWidgets.stat_row("Skill points", str(int(player.get("skill_points"))), UiTheme.STAR))

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
	right.add_child(UiTheme.body(str(player.call("aura_read")), 14, UiTheme.STAR))
	var rate: float = float(player.get("satellite_rate"))
	right.add_child(UiTheme.body(("Satellite: +%d essence per second." % int(rate)) if rate > 0.0 else "No satellite. Essence returns only when you meditate.", 14, UiTheme.TEXT_DIM))
