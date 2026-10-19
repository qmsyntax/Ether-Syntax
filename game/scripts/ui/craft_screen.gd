class_name CraftScreen
extends UiScreen
## Working at a crafting station, or on a field kit (design/12). Left: the station's recipes -
## learned and in reach, learned but beyond you yet (greyed: below the attempt window), and not
## learned. Right: the chosen recipe - what goes in (have / need), the tool, the fee, the chance,
## what comes out - and Combine. The rules are scripts/crafting.gd; main.gd decides where you may
## combine (`ctx`: {station, grade, kit}).

var ctx: Dictionary = {}
var selected := ""
var _last := ""                 # what the last combine did, in words
var _last_good := true


func _init(game_node: Node, context: Dictionary) -> void:
	super(game_node)
	ctx = context


func backdrop() -> float:
	return 0.55


func close_actions() -> Array[String]:
	return ["settings", "interact"]


func hud_hides() -> Array[String]:
	return HUD_MENU


func build(root: Control) -> void:
	var st: Dictionary = Crafting.station(str(ctx.get("station", "")))
	var skill: String = str(st.get("skill", ""))
	var ids: Array[String] = Crafting.recipes_at(str(ctx.get("station", "")))
	if selected == "" or not ids.has(selected):
		selected = _first_open(ids)

	var left: VBoxContainer = framed(root, 0.02, 0.04, 0.40, 0.775)
	left.add_theme_constant_override("separation", 4)
	var kit: String = str(ctx.get("kit", ""))
	left.add_child(UiTheme.heading(str(GameData.item(kit).get("name", "")) if kit != "" else str(st.get("name", "Station")), 28))
	var lvl := UiTheme.body("%s  %d / %d" % [Crafting.skill_name(skill), Crafting.skill_of(player, skill), int(Crafting.rule("skill_max"))], 16, UiTheme.STAR)
	lvl.name = "SkillLabel"
	left.add_child(lvl)
	if kit != "":
		left.add_child(UiTheme.body("A field kit: no fee, but a failed combine leaves nothing to use again.", 13, UiTheme.TEXT_DIM))
	left.add_child(UiTheme.rule())
	var list: VBoxContainer = scroller(left)
	list.add_theme_constant_override("separation", 3)
	for rid: String in ids:
		list.add_child(_row(rid))
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	left.add_child(foot)
	foot.add_child(UiWidgets.small_button("Done  (%s)" % Keybinds.binding_text("interact"), func() -> void: game.call("close_screen")))

	var right: VBoxContainer = framed(root, 0.41, 0.04, 0.985, 0.775)
	right.add_theme_constant_override("separation", 6)
	if selected != "":
		_detail(right, selected)


func _first_open(ids: Array[String]) -> String:
	for rid: String in ids:
		if Crafting.knows(player, rid) and Crafting.in_window(player, rid):
			return rid
	return ids[0] if not ids.is_empty() else ""


## One recipe in the list: the item and its trivial; dim when beyond you or not learned.
func _row(rid: String) -> Button:
	var r: Dictionary = Crafting.recipe(rid)
	var known: bool = Crafting.knows(player, rid)
	var reach: bool = Crafting.in_window(player, rid)
	var b := Button.new()
	b.name = "Recipe_" + rid
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	var n: int = int(r.get("makes", 1))
	b.text = "%s%s      trivial %d%s" % [str(GameData.item(str(r["output"])).get("name", r["output"])), "" if n == 1 else " x%d" % n,
		int(r.get("trivial", 0)), "" if known else "   - not learned"]
	var col: Color = UiTheme.TEXT if known and reach else (UiTheme.TEXT_FAINT if not known else UiTheme.TEXT_DIM)
	b.add_theme_color_override("font_color", col)
	if rid == selected:
		b.add_theme_stylebox_override("normal", UiTheme.box(Color("3a3024"), UiTheme.GOLD, 2, 4, 8))
	b.pressed.connect(func() -> void:
		selected = rid
		rebuild())
	return b


func _detail(box: VBoxContainer, rid: String) -> void:
	var r: Dictionary = Crafting.recipe(rid)
	var out_id: String = str(r["output"])
	var def: Dictionary = GameData.item(out_id)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)
	head.add_child(UiWidgets.Icon.new(UiDraw.item_icon(def), UiTheme.GOLD, 52.0))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(col)
	col.add_child(UiTheme.heading(str(def.get("name", out_id)), 22))
	col.add_child(UiTheme.body(str(def.get("desc", "")), 13, UiTheme.TEXT_DIM))
	var stats: String = UiWidgets.item_stats_text(def)
	if stats != "":
		box.add_child(UiTheme.body(stats, 14, UiTheme.GOOD))
	box.add_child(UiTheme.rule())

	var skill: String = str(r.get("skill", ""))
	box.add_child(UiWidgets.stat_row("Skill", "%s %d   -   trivial %d, can try from %d" % [Crafting.skill_name(skill), Crafting.skill_of(player, skill),
		int(r.get("trivial", 0)), int(r.get("min_skill", 0))]))
	var p: float = Crafting.chance(player, rid, ctx)
	var chance_row := UiWidgets.stat_row("Chance", "certain" if p >= 1.0 else "%d%%" % int(round(p * 100.0)), UiTheme.GOOD if p >= 0.7 else (UiTheme.GOLD if p >= 0.4 else UiTheme.BAD))
	chance_row.name = "ChanceRow"
	box.add_child(chance_row)
	box.add_child(UiWidgets.stat_row("Station fee", "$%d" % Crafting.fee(rid, ctx), UiTheme.GOLD))
	var t: Dictionary = r.get("tool", {})
	var tool_id: String = Crafting.best_tool(player, str(t.get("kind", "")))
	var tool_name: String = str(((GameData.crafting.get("tools", {}) as Dictionary).get(str(t.get("kind", "")), {}) as Dictionary).get("name", t.get("kind", "")))
	box.add_child(UiWidgets.stat_row("Tool", ("%s - %d uses left" % [tool_name, Crafting.tool_uses_left(player, tool_id)]) if tool_id != "" else "%s (tier %d) - you have none" % [tool_name, int(t.get("tier", 1))],
		UiTheme.TEXT if tool_id != "" else UiTheme.BAD))
	box.add_child(UiWidgets.stat_row("Takes", "%d hours of work" % int(r.get("hours", 1)), UiTheme.TEXT_DIM))

	box.add_child(UiTheme.heading("In", 17))
	var ins: Dictionary = r.get("inputs", {})
	for id: String in ins:
		var have: int = Crafting.count(player, id)
		box.add_child(UiWidgets.stat_row("   %s" % str(GameData.item(id).get("name", id)), "%d / %d" % [have, int(ins[id])], UiTheme.GOOD if have >= int(ins[id]) else UiTheme.BAD))
	box.add_child(UiTheme.heading("Out", 17))
	var outs: Dictionary = Crafting.outputs(rid)
	for id: String in outs:
		box.add_child(UiWidgets.stat_row("   %s" % str(GameData.item(id).get("name", id)), "x%d   ($%d each)" % [int(outs[id]), int(GameData.item(id).get("value", 0))]))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	if _last != "":
		var said := UiTheme.body(_last, 15, UiTheme.GOOD if _last_good else UiTheme.BAD)
		said.name = "ResultLabel"
		box.add_child(said)
	var why: String = Crafting.why_not(player, rid, ctx)
	if why != "":
		box.add_child(UiTheme.body(why, 14, UiTheme.BAD))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(row)
	var purse := UiTheme.body("Purse  %s" % UiTheme.money_text(int(player.get("money"))), 15, UiTheme.GOLD)
	purse.autowrap_mode = TextServer.AUTOWRAP_OFF          # a wrapping label in a row collapses to one letter wide
	purse.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	purse.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(purse)
	var go := UiWidgets.small_button("Combine", func() -> void: combine(rid), why == "")
	go.name = "CombineButton"
	go.add_theme_color_override("font_color", UiTheme.GOLD)
	row.add_child(go)


## Try the recipe once, through main.gd, and say what happened.
func combine(rid: String) -> void:
	var res: Dictionary = game.call("craft", rid, ctx)
	if not bool(res.get("ok", false)):
		_last = str(res.get("why", ""))
		_last_good = false
	elif bool(res.get("success", false)):
		var bits: Array[String] = []
		for id: String in (res["made"] as Dictionary):
			bits.append("%s x%d" % [str(GameData.item(id).get("name", id)), int(res["made"][id])])
		_last = "Made: %s.%s" % [", ".join(bits), "  Skill +%d." % int(res["skill_up"]) if int(res["skill_up"]) > 0 else ""]
		_last_good = true
	else:
		var back: int = 0
		for id: String in (res["returned"] as Dictionary):
			back += int(res["returned"][id])
		_last = "Spoiled. %d of the inputs can be used again.%s" % [back, "  Skill +%d." % int(res["skill_up"]) if int(res["skill_up"]) > 0 else ""]
		_last_good = false
	if str(res.get("broke", "")) != "":
		_last += "  Your tool broke."
	rebuild()
