extends UiScreen
## The ethercosm: the inner space of the soul (design/01 LAW 2, LAW 4c).
##   centre      - your stars. Each is an essence tank; its size and ring show its capacity.
##   in orbit    - your satellite, if you wear one.
##   around them - your abilities. Each sits inside a ring of runes: the runechain that defines
##                 it. Runes light as the ability grows; a completed stage closes into a solid
##                 ring with the bound construct set into it as a gem; a full ring waiting for a
##                 construct pulses.
##   below       - the three sockets for spirit abilities (not obtainable yet).
## Click an ability to see it, bind a construct into it, or assign it to a skill slot.
##
## The ring glyphs are original marks generated per ability - they are not the books' alphabet.
##
## "Set runes" opens the rune-setting view of the selected skill (design/14 section 7): the word
## built in it, drawn by RuneBoard, beside the runes the character may set. Everything the view
## shows about a word - what may be added or joined and why not, sockets, link kinds, whether the
## word is closed - comes from the rule set in force (Runes.active()); the view draws it.

const RUNES_PER_STAGE := 16

var selected := 0
## The rune-setting view is open on the selected skill.
var rune_mode := false
## The rune picked on the board (-1 = none): the next rune set is joined to it, and clicking a
## second rune joins or parts the two.
var picked := -1
var _cosmos: Cosmos
var _detail: VBoxContainer
var _board: RuneBoard
var _rune_status: VBoxContainer
var _chips: Array[Control] = []
var _rune_msg := ""
var _rune_msg_bad := false


func backdrop() -> float:
	return 0.9


func close_actions() -> Array[String]:
	return ["ethercosm", "settings"]


func hud_hides() -> Array[String]:
	return HUD_MENU


func build(root: Control) -> void:
	var abilities: Array = player.get("abilities")
	selected = clampi(selected, 0, maxi(0, abilities.size() - 1))
	if rune_mode and not abilities.is_empty():
		_build_runes(root)
		return

	_cosmos = Cosmos.new(self)
	_cosmos.anchor_left = 0.02
	_cosmos.anchor_top = 0.03
	_cosmos.anchor_right = 0.66
	_cosmos.anchor_bottom = 0.97
	_cosmos.offset_left = 0
	_cosmos.offset_top = 0
	_cosmos.offset_right = 0
	_cosmos.offset_bottom = 0
	root.add_child(_cosmos)

	_detail = framed(root, 0.67, 0.03, 0.98, 0.97)
	_detail.add_theme_constant_override("separation", 7)
	_build_detail()


func select(index: int) -> void:
	selected = index
	for c: Node in _detail.get_children():
		c.queue_free()
	_build_detail()


# --- the rune-setting view ----------------------------------------------------------------

func open_runes() -> void:
	rune_mode = true
	picked = -1
	_rune_msg = ""
	rebuild()


func close_runes() -> void:
	rune_mode = false
	picked = -1
	rebuild()


## The word being set, and what the rules may know about its skill (read by the board).
func current_word() -> Dictionary:
	return player.call("ability_word", selected)


func current_context() -> RuneContext:
	return player.call("rune_context", selected)


## A click on the board: pick a rune, drop the pick (-1), or - with one picked - join or part the two.
func pick_node(i: int) -> void:
	if i < 0 or i == picked:
		picked = -1
	elif picked < 0:
		picked = i
	else:
		var a: int = picked
		var before: Dictionary = current_word()
		var names: Array = [RuneRules.rune_name(before, a), RuneRules.rune_name(before, i)]
		var r: Dictionary = player.call("word_toggle_link", selected, a, i)
		picked = -1
		if not bool(r["ok"]):
			_say("%s and %s cannot be joined: %s" % [names[0], names[1], str(r["text"])], true)
		else:
			var word: Dictionary = current_word()
			if RuneWord.linked(word, a, i):
				_say("Joined: %s." % str(Runes.active().describe_link(word, a, i, current_context()).get("text", "")), false)
			else:
				_say("Parted %s and %s." % [RuneRules.rune_name(word, a), RuneRules.rune_name(word, i)], false)
			game.call("save_now")
	_refresh_runes()


## A click on a rune in the palette: set it, joined to the picked rune if there is one.
func add_rune(rune_id: String) -> void:
	var host: int = picked
	var r: Dictionary = player.call("word_add", selected, rune_id, host)
	var nm: String = str(GameData.rune(rune_id).get("name", rune_id))
	if bool(r["ok"]):
		_say(("Set %s, joined to %s." % [nm, RuneRules.rune_name(current_word(), host)]) if host >= 0 else ("Set %s. Pick it and another rune to join them." % nm), false)
		game.call("save_now")
	else:
		_say("%s cannot be set: %s" % [nm, str(r["text"])], true)
	_refresh_runes()


## Take rune i out of the word.
func remove_node(i: int) -> void:
	var word: Dictionary = current_word()
	var nm: String = RuneRules.rune_name(word, i)
	var r: Dictionary = player.call("word_remove", selected, i)
	if bool(r["ok"]):
		picked = -1 if picked == i else (picked - 1 if picked > i else picked)
		_say("Took %s out." % nm, false)
		game.call("save_now")
	else:
		_say(str(r["text"]), true)
	_refresh_runes()


func clear_word() -> void:
	player.call("word_clear", selected)
	picked = -1
	_say("The word is cleared back to its anchor.", false)
	game.call("save_now")
	_refresh_runes()


## For a palette chip: whether the rules would take that rune now, and its sockets.
func chip_state(rune_id: String) -> Dictionary:
	var ctx: RuneContext = current_context()
	var rules: RuneRules = Runes.active()
	var r: Dictionary = rules.can_add(current_word(), rune_id, ctx, picked)
	return {"ok": bool(r["ok"]), "text": str(r["text"]), "sockets": int(rules.describe_rune(rune_id, ctx).get("sockets", -1))}


func _say(text: String, bad: bool) -> void:
	_rune_msg = text
	_rune_msg_bad = bad


func _build_runes(root: Control) -> void:
	var rules: RuneRules = Runes.active()
	var ctx: RuneContext = current_context()
	var st: Dictionary = (player.get("abilities") as Array)[selected]
	var ab: Dictionary = GameData.ability(str(st["id"]))

	_board = RuneBoard.new(self)
	_board.anchor_left = 0.02
	_board.anchor_top = 0.03
	_board.anchor_right = 0.62
	_board.anchor_bottom = 0.97
	root.add_child(_board)

	var box: VBoxContainer = framed(root, 0.63, 0.03, 0.98, 0.97)
	box.add_theme_constant_override("separation", 6)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := UiTheme.heading("Runes", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var back: Button = UiWidgets.small_button("Back to the ethercosm", close_runes)
	back.name = "RunesBackButton"
	head.add_child(back)
	head.add_child(UiWidgets.small_button("Close  (%s)" % Keybinds.binding_text("ethercosm"), func() -> void: game.call("close_screen")))

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	box.add_child(name_row)
	name_row.add_child(UiWidgets.Icon.new(str(ab.get("icon", "drop")), GameData.affinity_color(str(ab.get("affinity", ""))).lightened(0.3), 44.0))
	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.add_theme_constant_override("separation", 1)
	name_row.add_child(name_col)
	name_col.add_child(UiTheme.heading("%s   level %d" % [str(ab.get("name", "?")), ctx.stage], 20))
	var anchor: Dictionary = GameData.rune(ctx.anchor)
	name_col.add_child(UiTheme.body(("Built on %s: %s." % [str(anchor.get("name", "?")), str(anchor.get("meaning", ""))]) if not anchor.is_empty()
		else "This skill has no anchor rune in the data yet.", 13, UiTheme.STAR))
	box.add_child(UiTheme.body("Rules: %s" % rules.title(), 12, UiTheme.TEXT_FAINT))

	_rune_status = VBoxContainer.new()
	_rune_status.add_theme_constant_override("separation", 4)
	box.add_child(_rune_status)

	box.add_child(UiTheme.section("Runes you can set  -  test loadout"))
	box.add_child(UiTheme.body("Until rune acquisition is designed: every base rune of the affinities you hold, and every universal rune.", 12, UiTheme.TEXT_FAINT))
	var list: VBoxContainer = scroller(box)
	_chips.clear()
	var palette: Array[String] = player.call("rune_palette")
	var group := ""
	var flow: HFlowContainer = null
	for rid: String in palette:
		var aff: String = str(GameData.rune(rid).get("affinity", ""))
		var g: String = aff.capitalize() if aff != "" else "Universal"
		if g != group:
			group = g
			list.add_child(UiTheme.body(g, 13, GameData.affinity_color(aff).lightened(0.3) if aff != "" else UiTheme.STAR))
			flow = HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 4)
			flow.add_theme_constant_override("v_separation", 4)
			list.add_child(flow)
		var chip := RuneBoard.Chip.new(self, rid)
		var lines: Array = rules.describe_rune(rid, ctx).get("lines", [])
		chip.tooltip_text = "%s %s\n%s%s" % [str(GameData.rune(rid).get("name", rid)), str(GameData.rune(rid).get("character", "")),
			str(GameData.rune(rid).get("meaning", "")), ("\n" + "\n".join(PackedStringArray(lines))) if not lines.is_empty() else ""]
		flow.add_child(chip)
		_chips.append(chip)
	for n: String in rules.notes():
		box.add_child(UiTheme.body(n, 12, UiTheme.TEXT_FAINT))
	_refresh_runes()


## Redraw what changes when the word does: the status block and the palette's dimming.
func _refresh_runes() -> void:
	if _rune_status == null or not is_instance_valid(_rune_status):
		return
	for c: Node in _rune_status.get_children():
		_rune_status.remove_child(c)          # out at once, so the new rows keep their names
		c.queue_free()
	var rules: RuneRules = Runes.active()
	var ctx: RuneContext = current_context()
	var word: Dictionary = current_word()
	var cap: int = rules.capacity(ctx)
	var used_n: int = rules.used(word, ctx)
	var cap_bar := UiWidgets.Bar.new(float(used_n) / float(cap) if cap > 0 else 0.0, UiTheme.STAR.darkened(0.55),
		("%d of %d runes   -   level %d holds %d" % [used_n, cap, ctx.stage, cap]) if cap >= 0 else "%d runes   -   no limit under these rules" % used_n, 22.0)
	cap_bar.name = "RuneCapacity"
	_rune_status.add_child(cap_bar)
	var ws: Dictionary = rules.word_state(word, ctx)
	var state_line := UiTheme.body(str(ws.get("label", "")), 16, UiTheme.GOOD if bool(ws.get("closed", false)) else UiTheme.GOLD)
	state_line.name = "WordState"
	_rune_status.add_child(state_line)
	for p: Variant in ws.get("problems", []):
		_rune_status.add_child(UiTheme.body(str(p), 13, UiTheme.BAD))
	for l: Variant in ws.get("lines", []):
		_rune_status.add_child(UiTheme.body(str(l), 13, UiTheme.TEXT_DIM))
	if _rune_msg != "":
		var msg := UiTheme.body(_rune_msg, 14, UiTheme.BAD if _rune_msg_bad else UiTheme.TEXT)
		msg.name = "RuneMessage"
		_rune_status.add_child(msg)
	var row := HBoxContainer.new()
	_rune_status.add_child(row)
	if picked >= 0 and picked < RuneWord.size(word):
		var rid: String = RuneWord.node_id(word, picked)
		var d: Dictionary = rules.describe_node(word, picked, ctx)
		var sockets: int = int(d.get("sockets", -1))
		var pl := UiTheme.body("Picked: %s%s" % [RuneRules.rune_name(word, picked),
			("   (%d of %d joined)" % [int(d.get("used", 0)), sockets]) if sockets >= 0 else ""], 14, UiTheme.GOLD)
		pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(pl)
		if picked > 0:
			var rm: Button = UiWidgets.small_button("Take it out", func() -> void: remove_node.call_deferred(picked))
			rm.name = "RemoveRuneButton"
			row.add_child(rm)
		_rune_status.add_child(UiTheme.body(str(GameData.rune(rid).get("meaning", "")), 13, UiTheme.TEXT_DIM))
	else:
		var hint := UiTheme.body("Nothing picked.", 14, UiTheme.TEXT_FAINT)
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(hint)
	var clear: Button = UiWidgets.small_button("Clear the word", func() -> void: clear_word.call_deferred(), RuneWord.size(word) > 1)
	clear.name = "ClearWordButton"
	row.add_child(clear)
	for chip: Control in _chips:
		chip.queue_redraw()


# --- right-hand panel --------------------------------------------------------------------

func _build_detail() -> void:
	var box: VBoxContainer = _detail
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := UiTheme.heading("Ethercosm", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UiWidgets.small_button("Skill tree  (%s)" % Keybinds.binding_text("skills"), func() -> void: game.call("open_skill_tree", false)))
	head.add_child(UiWidgets.small_button("Close  (%s)" % Keybinds.binding_text("ethercosm"), func() -> void: game.call("close_screen")))
	box.add_child(UiTheme.body("The inner space of your soul.", 14, UiTheme.TEXT_DIM))
	box.add_child(UiTheme.rule())

	# the soul at a glance
	var t: Dictionary = player.get("talent")
	box.add_child(UiWidgets.stat_row("Talent", str(t.get("name", "?")), UiTheme.GOLD))
	var pcts: Array = player.get("star_pct")
	for i: int in pcts.size():
		box.add_child(UiWidgets.Bar.new(float(pcts[i]) / 99.0, UiTheme.STAR.darkened(0.25),
			"star %d   %d%% capacity   %d essence" % [i + 1, int(float(pcts[i])), int(GameData.num("stars", "full_tank") * float(pcts[i]) / 100.0)], 22.0))
	box.add_child(UiTheme.body(str(player.call("aura_read")), 14, UiTheme.STAR))
	var rate: float = float(player.get("satellite_rate"))
	box.add_child(UiTheme.body(("A satellite orbits your star: +%d essence a second." % int(rate)) if rate > 0.0
		else "Nothing orbits your star. Essence returns only when you meditate.", 13, UiTheme.TEXT_DIM))
	box.add_child(UiTheme.rule())

	var abilities: Array = player.get("abilities")
	if abilities.is_empty():
		box.add_child(UiTheme.body("You know no abilities.", 15, UiTheme.TEXT_FAINT))
		return
	var st: Dictionary = abilities[selected]
	var ab: Dictionary = player.call("ability_stats", st)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	box.add_child(name_row)
	name_row.add_child(UiWidgets.Icon.new(str(ab.get("icon", "drop")), GameData.affinity_color(str(ab.get("affinity", ""))).lightened(0.3), 52.0))
	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.add_theme_constant_override("separation", 1)
	name_row.add_child(name_col)
	name_col.add_child(UiTheme.heading(str(ab.get("name", "?")), 22))
	name_col.add_child(UiTheme.body("\"%s\"" % str(ab.get("verse", "")), 14, UiTheme.STAR))
	if str(ab.get("summary", "")) != "":
		box.add_child(UiTheme.body(str(ab["summary"]), 14, UiTheme.TEXT))

	var need: String = str(player.call("pending_tier", st))
	box.add_child(UiWidgets.Bar.new(float(st["progress"]) / 100.0, UiTheme.GOLD if need != "" else UiTheme.ESSENCE,
		("stage %d   -   runechain complete, needs a %s" % [int(st["stage"]), need]) if need != ""
		else "stage %d   -   %d of %d runes lit" % [int(st["stage"]), int(float(st["progress"]) / 100.0 * RUNES_PER_STAGE), RUNES_PER_STAGE], 22.0))
	box.add_child(UiWidgets.stat_row("Essence cost", "%d" % int(round(float(ab.get("cost", 0.0))))))
	box.add_child(UiWidgets.stat_row("Reflux left behind", "%d" % int(round(float(ab.get("cost", 0.0)) * float(ab.get("reflux_per_cost", 1.0))))))
	box.add_child(UiTheme.body("It grows by essence spent through it - fastest when something is trying to kill you.", 13, UiTheme.TEXT_FAINT))

	var bound: Array = st.get("bound", [])
	for up: Dictionary in bound:
		var c: Dictionary = GameData.concept(str(up["concept"]))
		box.add_child(UiTheme.body("Bound at stage %d:  %s of %s" % [int(up["stage"]), str(up["tier"]), str(c.get("label", up["concept"]))], 14, UiTheme.STAR))

	# binding
	var held: Array = player.get("constructs")
	if need != "":
		var any := false
		for ci: int in held.size():
			if str(held[ci]["tier"]) == need:
				any = true
				var label: String = str(GameData.concept(str(held[ci]["concept"])).get("label", held[ci]["concept"]))
				box.add_child(UiWidgets.small_button("Bind the %s of %s   (irreversible, may fail)" % [need, label], func() -> void:
					player.call("bind_construct", selected, ci)
					rebuild()))
				box.add_child(_bind_preview(st, str(held[ci]["concept"])))
		if not any:
			box.add_child(UiTheme.body("You carry no %s to bind." % need, 13, UiTheme.BAD))

	# the word built in it
	box.add_child(UiTheme.rule())
	var word: Dictionary = player.call("ability_word", selected)
	var ctx: RuneContext = player.call("rune_context", selected)
	var rules: RuneRules = Runes.active()
	var cap: int = rules.capacity(ctx)
	var runes_row := HBoxContainer.new()
	box.add_child(runes_row)
	var runes_line := UiTheme.body("Runes  %d%s   -   %s" % [rules.used(word, ctx), (" of %d" % cap) if cap >= 0 else "",
		str(rules.word_state(word, ctx).get("label", ""))], 14, UiTheme.STAR)
	runes_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	runes_row.add_child(runes_line)
	var rb: Button = UiWidgets.small_button("Set runes", open_runes)
	rb.name = "RunesButton"
	runes_row.add_child(rb)

	# hotbar assignment
	box.add_child(UiTheme.rule())
	box.add_child(UiTheme.body("Skill slot", 13, UiTheme.TEXT_DIM))
	var hotbar: Array = player.get("hotbar")
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 6)
	box.add_child(slots)
	for i: int in hotbar.size():
		var here: bool = int(hotbar[i]) == selected
		var b: Button = UiWidgets.small_button(Keybinds.binding_text("ability_%d" % (i + 1)), func() -> void:
			player.call("assign_slot", i, selected)
			game.call("save_now")
			rebuild())
		b.custom_minimum_size = Vector2(44, 40)
		if here:
			b.add_theme_stylebox_override("normal", UiTheme.box(Color("3a3024"), UiTheme.GOLD, 2, 4, 10))
			b.add_theme_color_override("font_color", UiTheme.GOLD)
		slots.add_child(b)
	slots.add_child(UiWidgets.small_button("clear", func() -> void:
		player.call("unassign_ability", selected)
		game.call("save_now")
		rebuild()))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	if not held.is_empty():
		var names: Array[String] = []
		for c2: Dictionary in held:
			names.append("%s of %s" % [str(c2["tier"]), str(GameData.concept(str(c2["concept"])).get("label", c2["concept"]))])
		box.add_child(UiTheme.body("Constructs carried:  " + ", ".join(names), 13, UiTheme.GOLD))


# --- the drawn soul --------------------------------------------------------------------------

## What that bind would do to the ability: one "label  before -> after" line per number that moves.
func _bind_preview(st: Dictionary, concept: String) -> Control:
	var col := VBoxContainer.new()
	col.name = "BindPreview"
	col.add_theme_constant_override("separation", 4)
	var rows: Array[Dictionary] = player.call("preview_bind", st, concept)
	for r: Dictionary in rows:
		var line := HBoxContainer.new()
		col.add_child(line)
		var name_label := UiTheme.body("      %s" % str(r["label"]), 13, UiTheme.TEXT_DIM)
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		var change := UiTheme.body("%s  ->  %s" % [str(r["before"]), str(r["after"])], 13, UiTheme.GOOD if bool(r["better"]) else UiTheme.BAD)
		change.autowrap_mode = TextServer.AUTOWRAP_OFF
		line.add_child(change)
	col.add_child(UiTheme.body("      %d%% chance it takes. A failed bind destroys the construct and wounds you." % int(round(GameData.num("binding", "success_chance") * 100.0)), 12, UiTheme.TEXT_FAINT))
	return col


class Cosmos extends Control:
	var screen: Control
	var _time := 0.0
	var _nodes: Array = []          # [{pos, r, index}] for click testing
	var _hover := -1

	func _init(owner_screen: Control) -> void:
		screen = owner_screen
		mouse_filter = Control.MOUSE_FILTER_STOP
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(delta: float) -> void:
		_time += delta
		var m: Vector2 = get_local_mouse_position()
		_hover = -1
		for n: Dictionary in _nodes:
			if m.distance_to(n["pos"]) <= float(n["r"]):
				_hover = int(n["index"])
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _hover >= 0:
			screen.call("select", _hover)
			accept_event()

	func _draw() -> void:
		var player: Node = screen.get("player")
		var c: Vector2 = size * 0.5 + Vector2(0, -20.0)
		_draw_void(c)

		var abilities: Array = player.get("abilities")
		var orbit: float = minf(size.x, size.y) * 0.34
		_nodes.clear()
		# channels first, so nodes sit on top of them
		for i: int in abilities.size():
			var a: float = -PI / 2.0 + TAU * float(i) / float(maxi(1, abilities.size()))
			var p: Vector2 = c + Vector2(cos(a), sin(a)) * orbit
			draw_line(c, p, Color(UiTheme.ESSENCE, 0.18), 2.0, true)
			var t: float = fmod(_time * 0.35 + float(i) * 0.37, 1.0)
			draw_circle(c.lerp(p, t), 2.5, Color(UiTheme.ESSENCE.lightened(0.4), 0.7 * sin(t * PI)))

		_draw_stars(player, c)
		_draw_satellite(player, c)

		for i: int in abilities.size():
			var a2: float = -PI / 2.0 + TAU * float(i) / float(maxi(1, abilities.size()))
			var p2: Vector2 = c + Vector2(cos(a2), sin(a2)) * orbit
			_draw_ability(player, abilities[i], i, p2)
			_nodes.append({"pos": p2, "r": 66.0, "index": i})

		_draw_spirit_sockets(Vector2(c.x, size.y - 46.0))
		UiDraw.text(self, Vector2(14.0, 24.0), "Click an ability to inspect it.", 13, UiTheme.TEXT_FAINT)

	func _draw_void(c: Vector2) -> void:
		UiDraw.void_field(self, size, c, _time)

	func _draw_stars(player: Node, c: Vector2) -> void:
		var pcts: Array = player.get("star_pct")
		var n: int = pcts.size()
		for i: int in n:
			var off := Vector2((float(i) - float(n - 1) * 0.5) * 124.0, 0.0)
			var p: Vector2 = c + off
			var frac: float = float(pcts[i]) / 99.0
			var r: float = 16.0 + 26.0 * sqrt(frac)          # a baby star is visibly small
			var pulse: float = 1.0 + 0.04 * sin(_time * 2.0 + float(i))
			for g: int in 5:
				draw_circle(p, r * pulse * (2.2 - g * 0.25), Color(UiTheme.STAR, 0.035 + g * 0.012))
			draw_circle(p, r * pulse, Color("f4efff"))
			draw_circle(p, r * pulse * 0.72, Color(1, 1, 1))
			UiDraw.ring(self, p, r + 12.0, frac, UiTheme.STAR)
			UiDraw.text(self, Vector2(p.x - 60.0, p.y + r + 34.0), "star %d   %d%%" % [i + 1, int(float(pcts[i]))], 13, UiTheme.STAR, HORIZONTAL_ALIGNMENT_CENTER, 120.0)
		var t: Dictionary = player.get("talent")
		UiDraw.text(self, Vector2(c.x - 200.0, c.y - 78.0), str(t.get("name", "")), 16, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 400.0)

	func _draw_satellite(player: Node, c: Vector2) -> void:
		var rate: float = float(player.get("satellite_rate"))
		if rate <= 0.0:
			return
		var rx := 118.0 + 62.0 * float((player.get("star_pct") as Array).size() - 1)
		var ry := 46.0
		var prev := c + Vector2(rx, 0.0)
		for i: int in range(1, 49):
			var a: float = TAU * float(i) / 48.0
			var p := c + Vector2(cos(a) * rx, sin(a) * ry)
			draw_line(prev, p, Color(UiTheme.GOLD, 0.22), 1.0, true)
			prev = p
		var a2: float = _time * 0.9
		var s := c + Vector2(cos(a2) * rx, sin(a2) * ry)
		draw_circle(s, 9.0, Color(UiTheme.GOLD, 0.25))
		draw_circle(s, 5.0, UiTheme.GOLD.lightened(0.3))
		UiDraw.text(self, s + Vector2(10.0, -8.0), "+%d/s" % int(rate), 12, UiTheme.GOLD)

	func _draw_ability(player: Node, st: Dictionary, index: int, p: Vector2) -> void:
		var ab: Dictionary = player.call("ability_stats", st)
		var is_selected: bool = index == int(screen.get("selected"))
		var need: String = str(player.call("pending_tier", st))
		var stage: int = int(st["stage"])
		var lit: int = int(float(st["progress"]) / 100.0 * RUNES_PER_STAGE)
		var ring_r := 52.0

		# completed stages: solid rings, each with its bound construct set in as a gem
		var bound: Array = st.get("bound", [])
		for s: int in stage:
			var rr: float = ring_r + 12.0 + s * 9.0
			draw_arc(p, rr, 0, TAU, 64, UiTheme.GOLD.darkened(0.25), 2.0, true)
			if s < bound.size():
				var ga: float = -PI / 2.0 + s * 0.5
				UiDraw.icon(self, "gem", p + Vector2(cos(ga), sin(ga)) * rr, 13.0, UiTheme.STAR if str(bound[s]["tier"]) != "vestige" else UiTheme.GOLD)

		# the current runechain
		draw_arc(p, ring_r, 0, TAU, 64, Color(1, 1, 1, 0.06), 12.0, true)
		var rng := RandomNumberGenerator.new()
		for i: int in RUNES_PER_STAGE:
			var a: float = -PI / 2.0 + TAU * float(i) / float(RUNES_PER_STAGE)
			var on: bool = i < lit
			var col: Color = (UiTheme.GOLD if need != "" else UiTheme.ESSENCE.lightened(0.45)) if on else Color(0.32, 0.3, 0.3)
			if need != "":
				col = col.lerp(Color(1, 1, 1), 0.25 + 0.25 * sin(_time * 4.0 + float(i) * 0.4))
			rng.seed = hash(str(st["id"])) + stage * 977 + i * 31
			_draw_rune(p + Vector2(cos(a), sin(a)) * ring_r, a + PI / 2.0, rng, col, on)

		# the ability itself
		draw_circle(p, 36.0, Color(0, 0, 0, 0.7))
		draw_circle(p, 33.0, UiTheme.PANEL_HI if not is_selected else Color("3a3024"))
		draw_arc(p, 33.0, 0, TAU, 48, UiTheme.GOLD if (is_selected or _hover == index) else UiTheme.BRONZE, 2.0 if is_selected else 1.5, true)
		UiDraw.icon(self, str(ab.get("icon", "drop")), p, 34.0, GameData.affinity_color(str(ab.get("affinity", ""))).lightened(0.3))
		UiDraw.text(self, Vector2(p.x - 110.0, p.y + ring_r + 30.0 + stage * 9.0), str(ab.get("name", "?")), 15, UiTheme.TEXT if not is_selected else UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 220.0)
		var sub: String = ("needs a %s" % need) if need != "" else "stage %d" % stage
		UiDraw.text(self, Vector2(p.x - 110.0, p.y + ring_r + 47.0 + stage * 9.0), sub, 12, UiTheme.GOLD if need != "" else UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, 220.0)
		# which skill slot it sits in
		var hotbar: Array = player.get("hotbar")
		var slot: int = hotbar.find(index)
		if slot >= 0:
			var kp := p + Vector2(26.0, -26.0)
			draw_circle(kp, 11.0, UiTheme.INSET)
			draw_arc(kp, 11.0, 0, TAU, 20, UiTheme.GOLD, 1.5, true)
			UiDraw.text(self, Vector2(kp.x - 11.0, kp.y + 5.0), Keybinds.binding_text("ability_%d" % (slot + 1)), 13, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 22.0)

	## One original glyph: a few strokes between points of a 3x3 grid, rotated to face outward.
	func _draw_rune(at: Vector2, angle: float, rng: RandomNumberGenerator, col: Color, lit: bool) -> void:
		UiDraw.rune_strokes(self, at, angle, rng, col, lit)

	func _draw_spirit_sockets(at: Vector2) -> void:
		for i: int in 3:
			var p := at + Vector2((float(i) - 1.0) * 70.0, 0.0)
			draw_arc(p, 18.0, 0, TAU, 32, UiTheme.BRONZE_DIM, 1.5, true)
			draw_arc(p, 12.0, 0, TAU, 24, Color(1, 1, 1, 0.05), 1.0, true)
		UiDraw.text(self, Vector2(at.x - 300.0, at.y + 36.0), "Spirit abilities  -  none held. Each one compresses your latent aura by a third.", 12, UiTheme.TEXT_FAINT, HORIZONTAL_ALIGNMENT_CENTER, 600.0)
