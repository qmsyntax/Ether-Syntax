class_name RuneBoard
extends Control
## The rune-setting view's drawn word (design/14 section 7): the skill's anchor rune at the centre
## and every rune set into it around it, joined by their links. It draws whatever the rule set in
## force says - sockets, link colours, flags, badges - and knows nothing of valence or chemistry.
## Clicks go to the screen: left-click a rune to pick it (a second rune joins or parts the two),
## right-click a rune to take it out, left-click empty space to drop the pick.

## Colour keys a rule set may use for a link (RuneRules.describe_link "colour"). A key not listed
## draws in TEXT_DIM.
const LINK_COLOURS := {
	"even": Color("8fc3ff"),
	"polar": Color("d2ab52"),
	"ionic": Color("e2632a"),
	"problem": Color("d2553f"),
	"plain": Color("a69b84"),
}
const NODE_R := 28.0
const ANCHOR_R := 36.0

var screen: Control
var _time := 0.0
var _pos: Array[Vector2] = []
var _hover := -1


func _init(owner_screen: Control) -> void:
	screen = owner_screen
	name = "RuneBoard"
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS


## Where rune `i` of the word is drawn, in global (viewport) coordinates; for tests.
func node_global(i: int) -> Vector2:
	_layout_now()
	return get_global_transform() * _pos[i] if i >= 0 and i < _pos.size() else Vector2(-1, -1)


func _process(delta: float) -> void:
	_time += delta
	_hover = _node_at(get_local_mouse_position())
	queue_redraw()


func _node_at(p: Vector2) -> int:
	for i: int in _pos.size():
		if p.distance_to(_pos[i]) <= (ANCHOR_R if i == 0 else NODE_R) + 4.0:
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	_layout_now()
	var at: int = _node_at(mb.position)
	if mb.button_index == MOUSE_BUTTON_LEFT:
		screen.call("pick_node", at)
		accept_event()
	elif mb.button_index == MOUSE_BUTTON_RIGHT and at >= 0:
		screen.call("remove_node", at)
		accept_event()


func _word() -> Dictionary:
	return screen.call("current_word")


func _layout_now() -> void:
	_pos = _layout(_word())


## A radial tree from the anchor: each rune joined to the word sits one ring further out than the
## rune it hangs from, inside that rune's share of the circle. Runes joined to nothing that reaches
## the anchor wait in a row along the bottom.
func _layout(word: Dictionary) -> Array[Vector2]:
	var n: int = RuneWord.size(word)
	var out: Array[Vector2] = []
	out.resize(n)
	if n == 0:
		return out
	var c: Vector2 = _centre()
	var kids: Array = []
	var depth: Array[int] = []
	for i: int in n:
		kids.append([])
		depth.append(-1)
	depth[0] = 0
	var queue: Array[int] = [0]
	var max_depth := 0
	while not queue.is_empty():
		var at: int = queue.pop_front()
		var next: Array[int] = RuneWord.neighbours(word, at)
		next.sort()
		for k: int in next:
			if depth[k] < 0:
				depth[k] = depth[at] + 1
				max_depth = maxi(max_depth, depth[k])
				(kids[at] as Array).append(k)
				queue.append(k)
	var ring: float = minf(175.0, minf(size.x, size.y) * 0.36 / float(maxi(1, max_depth)))
	out[0] = c
	_place(0, -PI / 2.0 - PI, -PI / 2.0 + PI, kids, depth, ring, c, out)
	var loose: Array[int] = []
	for i: int in n:
		if depth[i] < 0:
			loose.append(i)
	for k: int in loose.size():
		out[loose[k]] = Vector2(size.x - 70.0 - float(k % 6) * 92.0, size.y - 70.0 - float(floori(float(k) / 6.0)) * 96.0)
	return out


func _place(node: int, a0: float, a1: float, kids: Array, depth: Array[int], ring: float, c: Vector2, out: Array[Vector2]) -> void:
	var children: Array = kids[node]
	if children.is_empty():
		return
	var total := 0.0
	for ch: int in children:
		total += _leaves(ch, kids)
	var a: float = a0
	for ch: int in children:
		var span: float = (a1 - a0) * _leaves(ch, kids) / total
		var mid: float = a + span * 0.5
		out[ch] = c + Vector2(cos(mid), sin(mid)) * ring * float(depth[ch])
		_place(ch, a, a + span, kids, depth, ring, c, out)
		a += span


func _leaves(node: int, kids: Array) -> float:
	var children: Array = kids[node]
	if children.is_empty():
		return 1.0
	var t := 0.0
	for ch: int in children:
		t += _leaves(ch, kids)
	return t


func _centre() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.47)


func _draw() -> void:
	var word: Dictionary = _word()
	var rules: RuneRules = Runes.active()
	var ctx: RuneContext = screen.call("current_context")
	_pos = _layout(word)
	UiDraw.void_field(self, size, _centre(), _time)
	UiDraw.text(self, Vector2(14.0, 24.0), "Click a rune below to set it - joined to the rune you have picked here, if any.", 13, UiTheme.TEXT_FAINT)
	UiDraw.text(self, Vector2(14.0, 42.0), "Click two runes here to join or part them. Right-click one to take it out.", 13, UiTheme.TEXT_FAINT)

	for l: Dictionary in RuneWord.links(word):
		var a: int = int(l["a"])
		var b: int = int(l["b"])
		_draw_link(rules.describe_link(word, a, b, ctx), _pos[a], _pos[b])
	var picked: int = int(screen.get("picked"))
	for i: int in RuneWord.size(word):
		_draw_node(word, i, rules.describe_node(word, i, ctx), i == picked)
	_draw_legend(rules.legend())


func _draw_link(d: Dictionary, pa: Vector2, pb: Vector2) -> void:
	var col: Color = LINK_COLOURS.get(str(d.get("colour", "plain")), UiTheme.TEXT_DIM)
	var flags: Array = d.get("flags", [])
	var dir: Vector2 = (pb - pa).normalized()
	var from: Vector2 = pa + dir * (NODE_R - 2.0)
	var to: Vector2 = pb - dir * (NODE_R - 2.0)
	draw_line(from, to, Color(0, 0, 0, 0.6), 7.0, true)
	if flags.has("weakened"):
		draw_dashed_line(from, to, col, 3.0, 9.0, true, true)
	else:
		draw_line(from, to, col, 3.0, true)
	var caption: String = str(d.get("kind", ""))
	for f: Variant in flags:
		caption += "  -  " + str(f)
	# beside the line, on its upper side, far enough out that the words clear it
	var w: float = UiDraw.text_width(caption, 12)
	var side := Vector2(-dir.y, dir.x)
	if side.y > 0.0:
		side = -side
	var at: Vector2 = (pa + pb) * 0.5 + side * (9.0 + absf(side.x) * (w * 0.5 + 4.0))
	UiDraw.outlined(self, at + Vector2(-w * 0.5 - 2.0, 4.0), caption, 12, col.lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER, w + 4.0)


func _draw_node(word: Dictionary, i: int, d: Dictionary, is_picked: bool) -> void:
	var rid: String = RuneWord.node_id(word, i)
	var rune: Dictionary = GameData.rune(rid)
	var p: Vector2 = _pos[i]
	var r: float = ANCHOR_R if i == 0 else NODE_R
	var aff: String = str(rune.get("affinity", ""))
	var tint: Color = GameData.affinity_color(aff).lightened(0.25) if aff != "" else UiTheme.STAR
	if is_picked:
		var pulse: float = 0.5 + 0.5 * sin(_time * 5.0)
		draw_circle(p, r + 16.0, Color(UiTheme.GOLD, 0.10 + 0.08 * pulse))
	draw_circle(p, r + 3.0, Color(0, 0, 0, 0.75))
	draw_circle(p, r, UiTheme.PANEL_HI if not is_picked else Color("3a3024"))
	draw_arc(p, r, 0, TAU, 48, tint if not (is_picked or _hover == i) else UiTheme.GOLD, 2.0 if is_picked else 1.5, true)
	if i == 0:
		draw_arc(p, r + 6.0, 0, TAU, 56, UiTheme.GOLD.darkened(0.2), 1.5, true)
		UiDraw.outlined(self, p + Vector2(-60.0, -r - 24.0), "anchor", 12, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 120.0)
	UiDraw.rune_glyph(self, p, rid, str(rune.get("character", "")), 28 if i == 0 else 24, tint.lightened(0.35))

	# sockets: one dot per link it can take, filled while taken; any beyond its sockets in red
	var sockets: int = int(d.get("sockets", -1))
	var used_n: int = int(d.get("used", 0))
	if sockets >= 0:
		var shown: int = maxi(sockets, used_n)
		for k: int in shown:
			var a: float = -PI / 2.0 + (float(k) - float(shown - 1) * 0.5) * 0.42
			var sp: Vector2 = p + Vector2(cos(a), sin(a)) * (r + 9.0)
			if k >= sockets:
				draw_circle(sp, 4.5, UiTheme.BAD)
			elif k < used_n:
				draw_circle(sp, 4.5, UiTheme.GOLD)
			else:
				draw_circle(sp, 4.5, Color(0, 0, 0, 0.8))
				draw_arc(sp, 4.0, 0, TAU, 14, UiTheme.GOLD.darkened(0.1), 1.3, true)

	var label: String = str(rune.get("name", rid))
	UiDraw.outlined(self, p + Vector2(-80.0, r + 20.0), label, 14, UiTheme.TEXT if not is_picked else UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 160.0)
	var badges: Array = d.get("badges", [])
	if not badges.is_empty():
		UiDraw.outlined(self, p + Vector2(-80.0, r + 35.0), ", ".join(PackedStringArray(badges)), 12, UiTheme.BAD if badges.has("over") else UiTheme.TEXT_FAINT, HORIZONTAL_ALIGNMENT_CENTER, 160.0)


func _draw_legend(entries: Array[Dictionary]) -> void:
	var y: float = size.y - 18.0 - 18.0 * float(entries.size() - 1)
	for e: Dictionary in entries:
		var key: String = str(e.get("colour", "plain"))
		var a := Vector2(16.0, y - 5.0)
		var b := Vector2(46.0, y - 5.0)
		if key == "weakened":
			draw_dashed_line(a, b, UiTheme.TEXT_DIM, 3.0, 7.0, true, true)
		else:
			draw_line(a, b, LINK_COLOURS.get(key, UiTheme.TEXT_DIM), 3.0, true)
		UiDraw.text(self, Vector2(54.0, y), str(e.get("label", key)), 12, UiTheme.TEXT_DIM)
		y += 18.0


## A rune in the palette: its glyph, name and sockets, dimmed when the rules would not take it now
## (it stays clickable, so the screen can say why).
class Chip extends Button:
	var screen: Control
	var rune_id := ""

	func _init(owner_screen: Control, id: String) -> void:
		screen = owner_screen
		rune_id = id
		name = "Rune_%s" % id
		text = ""
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(68, 64)
		pressed.connect(func() -> void: screen.call("add_rune", rune_id))

	func _draw() -> void:
		var st: Dictionary = screen.call("chip_state", rune_id)
		var rune: Dictionary = GameData.rune(rune_id)
		var aff: String = str(rune.get("affinity", ""))
		var tint: Color = GameData.affinity_color(aff).lightened(0.3) if aff != "" else UiTheme.STAR
		var live: bool = bool(st.get("ok", true))
		if not live:
			tint = tint.darkened(0.55)
		UiDraw.rune_glyph(self, Vector2(size.x * 0.5, 22.0), rune_id, str(rune.get("character", "")), 22, tint)
		UiDraw.text(self, Vector2(0.0, size.y - 9.0), str(rune.get("name", rune_id)), 12, UiTheme.TEXT if live else UiTheme.TEXT_FAINT, HORIZONTAL_ALIGNMENT_CENTER, size.x, false)
		var sockets: int = int(st.get("sockets", -1))
		for k: int in maxi(0, sockets):
			draw_arc(Vector2(size.x - 8.0, 8.0 + float(k) * 8.0), 2.6, 0, TAU, 10, UiTheme.GOLD.darkened(0.2 if live else 0.6), 1.2, true)
