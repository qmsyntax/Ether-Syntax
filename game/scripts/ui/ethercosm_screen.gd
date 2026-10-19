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
## The rune glyphs are original marks generated per ability - they are not the books' alphabet.

const RUNES_PER_STAGE := 16

var selected := 0
var _cosmos: Cosmos
var _detail: VBoxContainer


func backdrop() -> float:
	return 0.9


func close_actions() -> Array[String]:
	return ["ethercosm", "settings"]


func build(root: Control) -> void:
	var abilities: Array = player.get("abilities")
	selected = clampi(selected, 0, maxi(0, abilities.size() - 1))

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
		draw_rect(Rect2(Vector2.ZERO, size), Color("070608"))
		draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BRONZE_DIM, false, 1.0)
		# faint dust, fixed per position so it does not swim
		var rng := RandomNumberGenerator.new()
		rng.seed = 9173
		for i: int in 110:
			var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
			var tw: float = 0.25 + 0.2 * sin(_time * (0.5 + rng.randf()) + rng.randf() * TAU)
			draw_circle(p, 0.6 + rng.randf() * 1.1, Color(0.8, 0.8, 1.0, tw * 0.5))
		for k: int in 5:
			draw_circle(c, 240.0 - k * 40.0, Color(0.25, 0.28, 0.5, 0.025))

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
		draw_set_transform(at, angle, Vector2.ONE)
		var cell := 3.6
		var last := Vector2i(rng.randi_range(0, 2), rng.randi_range(0, 2))
		for k: int in rng.randi_range(2, 4):
			var nxt := Vector2i(rng.randi_range(0, 2), rng.randi_range(0, 2))
			if nxt == last:
				nxt = Vector2i((last.x + 1) % 3, (last.y + 2) % 3)
			draw_line(Vector2(last.x - 1, last.y - 1) * cell, Vector2(nxt.x - 1, nxt.y - 1) * cell, col, 1.6 if lit else 1.0, true)
			last = nxt
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _draw_spirit_sockets(at: Vector2) -> void:
		for i: int in 3:
			var p := at + Vector2((float(i) - 1.0) * 70.0, 0.0)
			draw_arc(p, 18.0, 0, TAU, 32, UiTheme.BRONZE_DIM, 1.5, true)
			draw_arc(p, 12.0, 0, TAU, 24, Color(1, 1, 1, 0.05), 1.0, true)
		UiDraw.text(self, Vector2(at.x - 300.0, at.y + 36.0), "Spirit abilities  -  none held. Each one compresses your latent aura by a third.", 12, UiTheme.TEXT_FAINT, HORIZONTAL_ALIGNMENT_CENTER, 600.0)
