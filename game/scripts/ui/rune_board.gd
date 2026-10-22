class_name RuneBoard
extends Control
## The rune-setting view's drawn word (design/14 section 7), in the ethercosm's space.
##   the skill    a glowing core in its affinity's colour at the centre, its icon inside, its own
##                rune as a watermark, a slowly turning tick ring, and its sockets as motes.
##   the runes    seals on concentric orbits by bonds from the skill (ring 1 bonded to it, ring 2
##                one further...), laid out so bonded runes sit near each other; runes joined to
##                nothing that reaches the skill wait bottom-right.
##   the bonds    curved luminous arcs: thickness by strength, colour by kind, energy flowing from
##                the rune with less pull to the one with more (even bonds shimmer both ways); a
##                weakened bond flickers.
##   the chain    once the word is closed - and fully once it is locked - its glyphs run round the
##                skill as a chain, copy after copy. Locking plays: the runes draw in, the chain
##                duplicates outward round the circle, a flash.
## Everything it shows about a word comes from the rule set in force; it knows no chemistry.
## Clicks go to the screen: left-click a rune to pick it (a second rune joins or parts the two),
## right-click a rune to take it out, left-click empty space to drop the pick.

## Colour keys a rule set may use for a link (RuneRules.describe_link "colour").
const LINK_COLOURS := {
	"even": Color("8fd0ff"),
	"polar": Color("e8c062"),
	"ionic": Color("ff7a3c"),
	"problem": Color("d2553f"),
	"plain": Color("b9b0d8"),
}
const CORE_R := 44.0
const SEAL_R := 23.0
const LOCK_ANIM_S := 1.6
const CHAIN_SPACING := 30.0

var screen: Control
var _time := 0.0
var _pos: Array[Vector2] = []
var _hover := -1
var _lock_t := -1.0          # seconds into the lock animation; < 0 when none is playing
var _chain_r := 200.0


func _init(owner_screen: Control) -> void:
	screen = owner_screen
	name = "RuneBoard"
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS


## Play the lock: the runes draw in and the chain duplicates outward with a flash.
func play_lock() -> void:
	_lock_t = 0.0


## Where rune `i` of the word is drawn, in global (viewport) coordinates; for tests.
func node_global(i: int) -> Vector2:
	_pos = _layout(_word())
	return get_global_transform() * _pos[i] if i >= 0 and i < _pos.size() else Vector2(-1, -1)


func _process(delta: float) -> void:
	_time += delta
	if _lock_t >= 0.0:
		_lock_t += delta
		if _lock_t > LOCK_ANIM_S:
			_lock_t = -1.0
	_hover = _node_at(get_local_mouse_position())
	queue_redraw()


func _node_at(p: Vector2) -> int:
	for i: int in _pos.size():
		if p.distance_to(_pos[i]) <= (CORE_R if i == 0 else SEAL_R + 6.0):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	_pos = _layout(_word())
	var at: int = _node_at(mb.position)
	if mb.button_index == MOUSE_BUTTON_LEFT:
		screen.call("pick_node", at)
		accept_event()
	elif mb.button_index == MOUSE_BUTTON_RIGHT and at >= 0:
		screen.call("remove_node", at)
		accept_event()


func _word() -> Dictionary:
	return screen.call("current_word")


func _centre() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.5 + 8.0)


# --- layout ---------------------------------------------------------------------------------

## Orbits by bonds from the skill: each rune one ring further out than the rune it hangs from, inside
## that rune's share of the circle, so bonded runes sit together. Also sets the chain's radius.
func _layout(word: Dictionary) -> Array[Vector2]:
	var n: int = RuneWord.size(word)
	var out: Array[Vector2] = []
	out.resize(n)
	var c: Vector2 = _centre()
	var outer: float = minf(size.x, size.y) * 0.5 - 44.0
	if n == 0:
		_chain_r = outer
		return out
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
	var r1: float = CORE_R + 108.0
	var step: float = clampf((outer - 64.0 - r1) / float(maxi(1, max_depth - 1)), 50.0, 118.0)
	var radii: Array[float] = [0.0]
	for d: int in range(1, max_depth + 1):
		radii.append(r1 + float(d - 1) * step)
	_chain_r = minf(outer, radii[max_depth] + 66.0) if max_depth > 0 else minf(outer, r1 + 40.0)
	out[0] = c
	_place(0, -PI / 2.0 - PI, -PI / 2.0 + PI, kids, depth, radii, c, out)
	var loose: Array[int] = []
	for i: int in n:
		if depth[i] < 0:
			loose.append(i)
	for k: int in loose.size():
		out[loose[k]] = Vector2(size.x - 56.0 - float(k % 6) * 74.0, size.y - 64.0 - float(floori(float(k) / 6.0)) * 84.0)
	# locking: everything draws in toward the skill, then settles back
	if _lock_t >= 0.0:
		var pull: float = 0.42 * sin(PI * clampf(_lock_t / 0.9, 0.0, 1.0))
		for i: int in range(1, n):
			out[i] = c + (out[i] - c) * (1.0 - pull)
	return out


func _place(node: int, a0: float, a1: float, kids: Array, depth: Array[int], radii: Array[float], c: Vector2, out: Array[Vector2]) -> void:
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
		out[ch] = c + Vector2(cos(mid), sin(mid)) * radii[depth[ch]]
		_place(ch, a, a + span, kids, depth, radii, c, out)
		a += span


func _leaves(node: int, kids: Array) -> float:
	var children: Array = kids[node]
	if children.is_empty():
		return 1.0
	var t := 0.0
	for ch: int in children:
		t += _leaves(ch, kids)
	return t


# --- drawing --------------------------------------------------------------------------------

func _draw() -> void:
	var word: Dictionary = _word()
	var rules: RuneRules = Runes.active()
	var ctx: RuneContext = screen.call("current_context")
	var ab: Dictionary = GameData.ability(ctx.ability_id) if GameData.abilities.has(ctx.ability_id) else {}
	var aff_col: Color = GameData.affinity_color(str(ab.get("affinity", "")))
	var c: Vector2 = _centre()
	_pos = _layout(word)
	var n: int = RuneWord.size(word)
	var locked: bool = RuneWord.is_locked(word)
	var closed: bool = bool(rules.word_state(word, ctx).get("closed", false))

	UiDraw.void_field(self, size, c, _time)
	_draw_nebula(c, aff_col)
	_draw_orbits(c, word)
	if n > 1 and (closed or locked):
		_draw_chain(word, c, locked)
	for l: Dictionary in RuneWord.links(word):
		var a: int = int(l["a"])
		var b: int = int(l["b"])
		_draw_bond(rules.describe_link(word, a, b, ctx), a, b)
	var picked: int = int(screen.get("picked"))
	if n > 0:
		_draw_core(c, ab, aff_col, word, rules.describe_node(word, 0, ctx), picked == 0)
	for i: int in range(1, n):
		_draw_seal(word, i, rules.describe_node(word, i, ctx), i == picked)
	_draw_flash(c, aff_col)

	var hint: String = "Locked. Unlock it in the panel to change the word." if locked \
		else "Click a rune in the panel to set it - joined to the rune picked here, if any."
	UiDraw.text(self, Vector2(16.0, 26.0), hint, 13, UiTheme.TEXT_FAINT)
	if not locked:
		UiDraw.text(self, Vector2(16.0, 44.0), "Click two runes here to join or part them. Right-click one to take it out.", 13, UiTheme.TEXT_FAINT)
	if locked:
		var pulse: float = 0.75 + 0.25 * sin(_time * 2.0)
		UiDraw.outlined(self, Vector2(16.0, 74.0), "L O C K E D", 18, Color(UiTheme.GOLD, pulse), HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
	elif closed and n > 1:
		UiDraw.outlined(self, Vector2(16.0, 74.0), "CLOSED  -  ready to lock", 14, Color(UiTheme.STAR, 0.9), HORIZONTAL_ALIGNMENT_LEFT, -1.0)
	_draw_callout(word, rules, ctx)
	_draw_legend(rules.legend())


## A soft cloud of the skill's colour behind everything, drifting slowly.
func _draw_nebula(c: Vector2, col: Color) -> void:
	var deep: Color = col.lerp(UiTheme.NETHER, 0.45)
	for k: int in 9:
		var drift := Vector2(cos(_time * 0.05 + float(k) * 1.9), sin(_time * 0.04 + float(k) * 2.7)) * (36.0 + float(k) * 9.0)
		draw_circle(c + drift, 300.0 - float(k) * 24.0, Color(deep if k % 2 == 0 else col, 0.034))
	for k: int in 6:
		draw_circle(c, 170.0 - float(k) * 22.0, Color(col, 0.04))


## Faint orbit lines at the rings in use.
func _draw_orbits(c: Vector2, word: Dictionary) -> void:
	var seen: Dictionary = {}
	for i: int in range(1, _pos.size()):
		var r: float = snappedf(_pos[i].distance_to(c), 1.0)
		if r > _chain_r - 20.0 or seen.has(r):
			continue
		seen[r] = true
		var segs := 72
		for s: int in segs:
			if s % 2 == 0:
				var a0: float = TAU * float(s) / float(segs) + _time * 0.01
				draw_arc(c, r, a0, a0 + TAU / float(segs), 4, Color(UiTheme.STAR, 0.07), 1.0, true)
	if RuneWord.size(word) <= 1:
		draw_arc(c, CORE_R + 108.0, 0.0, TAU, 96, Color(UiTheme.STAR, 0.05), 1.0, true)


func _draw_core(c: Vector2, ab: Dictionary, col: Color, word: Dictionary, d: Dictionary, is_picked: bool) -> void:
	for g: int in 7:
		draw_circle(c, CORE_R * (2.9 - float(g) * 0.3), Color(col, 0.03 + float(g) * 0.013))
	if is_picked:
		draw_circle(c, CORE_R + 22.0, Color(UiTheme.GOLD, 0.10 + 0.06 * sin(_time * 5.0)))
	draw_circle(c, CORE_R + 4.0, Color(0, 0, 0, 0.85))
	draw_circle(c, CORE_R, col.darkened(0.78))
	for k: int in 8:
		draw_circle(c, CORE_R * (1.0 - float(k) * 0.11), Color(col.lerp(Color(1, 1, 1), float(k) * 0.05), 0.10))
	var anchor: Dictionary = GameData.rune(RuneWord.node_id(word, 0))
	UiDraw.rune_glyph(self, c, RuneWord.node_id(word, 0), str(anchor.get("character", "")), 70, Color(col.lightened(0.55), 0.16))
	UiDraw.icon(self, str(ab.get("icon", "drop")), c, 40.0, col.lightened(0.5))
	# the tick ring, turning
	var rot: float = _time * 0.12
	for t: int in 60:
		var a: float = rot + TAU * float(t) / 60.0
		var long: bool = t % 5 == 0
		var dir := Vector2(cos(a), sin(a))
		draw_line(c + dir * (CORE_R + 7.0), c + dir * (CORE_R + (14.0 if long else 10.0)), Color(col.lightened(0.4), 0.55 if long else 0.28), 1.4 if long else 1.0, true)
	draw_arc(c, CORE_R + 1.5, 0.0, TAU, 64, UiTheme.GOLD if (is_picked or _hover == 0) else Color(col.lightened(0.3), 0.8), 2.0, true)
	_draw_motes(c, CORE_R + 22.0, 0, d, col)
	UiDraw.outlined(self, c + Vector2(-90.0, CORE_R + 40.0), str(anchor.get("name", "")), 14, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 180.0)


## A rune as a seal: halo, body, glyph, a thin turning ring, its motes and its name.
func _draw_seal(word: Dictionary, i: int, d: Dictionary, is_picked: bool) -> void:
	var rid: String = RuneWord.node_id(word, i)
	var rune: Dictionary = GameData.rune(rid)
	var p: Vector2 = _pos[i]
	var aff: String = str(rune.get("affinity", ""))
	var col: Color = GameData.affinity_color(aff).lightened(0.15) if aff != "" else UiTheme.STAR
	var hot: bool = is_picked or _hover == i
	for k: int in 5:
		draw_circle(p, SEAL_R + 24.0 - float(k) * 4.8, Color(col, 0.022 + float(k) * 0.016 + (0.02 if hot else 0.0)))
	if is_picked:
		draw_circle(p, SEAL_R + 16.0, Color(UiTheme.GOLD, 0.12 + 0.08 * sin(_time * 5.0)))
	draw_circle(p, SEAL_R + 2.0, Color(0, 0, 0, 0.88))
	draw_circle(p, SEAL_R, Color("130f18"))
	draw_circle(p, SEAL_R - 3.0, Color(col, 0.10))
	UiDraw.rune_glyph(self, p, rid, str(rune.get("character", "")), 22, col.lightened(0.45))
	var rot: float = _time * (0.55 if i % 2 == 0 else -0.45) + float(i)
	for j: int in 3:
		var a0: float = rot + TAU * float(j) / 3.0
		draw_arc(p, SEAL_R + 5.0, a0, a0 + 1.25, 14, UiTheme.GOLD if hot else Color(col.lightened(0.2), 0.75), 1.4, true)
	_draw_motes(p, SEAL_R + 11.0, i, d, col)
	UiDraw.outlined(self, p + Vector2(-70.0, SEAL_R + 27.0), str(rune.get("name", rid)), 13, UiTheme.GOLD if is_picked else UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 140.0)
	if d.has("strength"):
		var sv: float = float(d["strength"])
		UiDraw.outlined(self, p + Vector2(-70.0, SEAL_R + 41.0), ("x%.2f" % sv) if sv > 0.0 else "not joined", 12, Color(UiTheme.GOLD, 0.8) if sv > 0.0 else UiTheme.TEXT_FAINT, HORIZONTAL_ALIGNMENT_CENTER, 140.0)
	var badges: Array = d.get("badges", [])
	if badges.has("over") or (hot and not badges.is_empty()):
		UiDraw.outlined(self, p + Vector2(-70.0, SEAL_R + 55.0), ", ".join(PackedStringArray(badges)), 12, UiTheme.BAD if badges.has("over") else UiTheme.TEXT_FAINT, HORIZONTAL_ALIGNMENT_CENTER, 140.0)


## Sockets as motes: taken ones bright, set toward the rune they bond to and streaming into it;
## open ones dim, circling; any past the rune's sockets red.
func _draw_motes(p: Vector2, r: float, i: int, d: Dictionary, col: Color) -> void:
	var sockets: int = int(d.get("sockets", -1))
	if sockets < 0:
		return
	var word: Dictionary = _word()
	var partners: Array[int] = RuneWord.neighbours(word, i)
	for k: int in partners.size():
		if partners[k] >= _pos.size():
			continue
		var dir: Vector2 = (_pos[partners[k]] - p).normalized()
		var at: Vector2 = p + dir * r
		var over: bool = k >= sockets
		var mc: Color = UiTheme.BAD if over else col.lightened(0.6)
		draw_circle(at, 6.0, Color(mc, 0.20))
		draw_circle(at, 3.2, mc)
		var flick: float = fmod(_time * 1.6 + float(k) * 0.37, 1.0)
		draw_line(at + dir * 4.0, at + dir * (4.0 + 10.0 * flick), Color(mc, 0.6 * (1.0 - flick)), 1.6, true)
	var open: int = sockets - partners.size()
	for k: int in maxi(0, open):
		var a: float = _time * 0.8 + TAU * float(k) / float(maxi(1, open)) + float(i) * 1.3
		var at2: Vector2 = p + Vector2(cos(a), sin(a)) * r
		draw_circle(at2, 3.4, Color(0, 0, 0, 0.8))
		draw_arc(at2, 3.2, 0.0, TAU, 12, Color(col.lightened(0.3), 0.55), 1.2, true)


## A bond: a luminous arc bowing away from the skill, energy flowing along it. A polar or ionic
## bond is drawn from its weaker end to its dominant end (the rune with more pull): it swells and
## brightens toward the dominant rune, its energy runs into it, a chevron points at it and the
## rune glows where the bond lands; an ionic bond fades almost to nothing at the weaker end (a full
## hand-over). An even bond stays symmetric and shimmers both ways.
func _draw_bond(d: Dictionary, a: int, b: int) -> void:
	if a >= _pos.size() or b >= _pos.size():
		return
	var col: Color = LINK_COLOURS.get(str(d.get("colour", "plain")), UiTheme.TEXT_DIM)
	var flags: Array = d.get("flags", [])
	var strength: float = clampf(float(d.get("strength", 0.5)), 0.0, 1.5)
	var width: float = 1.9 + 2.6 * strength / 1.5
	var flow: int = int(d.get("flow", 0))
	var kind: String = str(d.get("kind", ""))
	# points run from the weaker end to the dominant end
	var pts: PackedVector2Array = _bond_points(b, a) if flow < 0 else _bond_points(a, b)
	if pts.size() < 2:
		return
	var dom: int = -1 if flow == 0 else (a if flow < 0 else b)
	var fl := 1.0
	if flags.has("weakened") or flags.has("refused"):
		fl = 0.3 + 0.7 * (0.5 + 0.5 * sin(_time * 17.0 + float(a) * 3.1 + float(b) * 1.7)) * (0.65 + 0.35 * sin(_time * 4.3 + float(b)))
	# how thick and bright each end is: [weak end, dominant end]
	var w_ends := Vector2(1.0, 1.0)
	var a_ends := Vector2(1.0, 1.0)
	if flow != 0:
		w_ends = Vector2(0.12, 1.75) if kind == "ionic" else Vector2(0.5, 1.45)
		a_ends = Vector2(0.06, 1.0) if kind == "ionic" else Vector2(0.4, 1.0)
	var last: int = pts.size() - 1
	for s: int in last:
		var t: float = (float(s) + 0.5) / float(last)
		var wk: float = lerpf(w_ends.x, w_ends.y, t)
		var ak: float = lerpf(a_ends.x, a_ends.y, t) * fl
		var dashed_gap: bool = flags.has("weakened") and s % 2 == 1
		draw_line(pts[s], pts[s + 1], Color(col, 0.10 * ak), width * 6.5 * wk, true)
		draw_line(pts[s], pts[s + 1], Color(col, 0.30 * ak), width * 2.4 * wk, true)
		if not dashed_gap:
			draw_line(pts[s], pts[s + 1], Color(col.lightened(0.35), 0.95 * ak), width * wk, true)
	# particles: into the dominant rune (both ways on an even bond)
	var count: int = 3 + int(_length(pts) / 44.0)
	var speed: float = 0.30 + 0.25 * strength
	for k: int in count:
		var u: float = fmod(_time * speed + float(k) / float(count), 1.0)
		var us: Array[float] = [u]
		if flow == 0:
			us.append(1.0 - fmod(u + 0.5 / float(count), 1.0))
		for v: float in us:
			var at: Vector2 = _sample(pts, v)
			var fade: float = sin(PI * v) if flow == 0 else lerpf(a_ends.x, 1.0, v) * minf(1.0, (1.0 - v) * 6.0 + 0.2)
			var pr: float = 1.9 if flow == 0 else lerpf(1.2, 2.6, v)
			draw_circle(at, pr * 2.4, Color(col, 0.16 * fade * fl))
			draw_circle(at, pr, Color(col.lightened(0.7), 0.95 * fade * fl))
	if flow == 0:
		return
	# the chevron at the dominant end, and the glow where the bond lands
	var tip: Vector2 = pts[last]
	var dir: Vector2 = (pts[last] - pts[maxi(0, last - 2)]).normalized()
	var side := Vector2(-dir.y, dir.x)
	var size_c: float = 7.0 + width * (1.2 if kind == "ionic" else 0.9)
	var back: Vector2 = tip - dir * size_c * 1.25
	var pulse: float = 0.75 + 0.25 * sin(_time * 4.0 + float(dom))
	draw_circle(tip, size_c * 1.9, Color(col, 0.16 * pulse * fl))
	draw_circle(tip, size_c * 0.9, Color(col.lightened(0.5), 0.35 * pulse * fl))
	draw_colored_polygon(PackedVector2Array([tip + dir * 2.0, back + side * size_c * 0.75, back + dir * size_c * 0.35, back - side * size_c * 0.75]),
		Color(col.lightened(0.55), 0.95 * fl))
	if dom >= 0 and dom < _pos.size():
		var rim: float = CORE_R if dom == 0 else SEAL_R
		draw_arc(_pos[dom], rim + 3.0, dir.angle() + PI - 0.6, dir.angle() + PI + 0.6, 16, Color(col.lightened(0.4), 0.85 * pulse * fl), 3.0, true)


## The bond in words, beside it, for the bonds of the picked or hovered rune.
## The picked (or hovered) rune's bonds in words, in a small panel in the top-right corner, each
## naming its dominant side ("polar: Settle dominates Surge").
func _draw_callout(word: Dictionary, rules: RuneRules, ctx: RuneContext) -> void:
	var picked: int = int(screen.get("picked"))
	var focus: int = picked if picked >= 0 else _hover
	if focus < 0 or focus >= RuneWord.size(word):
		return
	var lines: Array = []
	for k: int in RuneWord.neighbours(word, focus):
		var d: Dictionary = rules.describe_link(word, focus, k, ctx)
		var flags: Array = d.get("flags", [])
		var t: String = str(d.get("label", ""))
		if not flags.is_empty():
			t += "  (%s)" % ", ".join(PackedStringArray(flags.map(func(v: Variant) -> String: return str(v))))
		lines.append([t, LINK_COLOURS.get(str(d.get("colour", "plain")), UiTheme.TEXT_DIM)])
	var title: String = RuneRules.rune_name(word, focus) + ("  -  no bonds yet" if lines.is_empty() else "")
	var w: float = UiDraw.text_width(title, 14, true)
	for l: Array in lines:
		w = maxf(w, UiDraw.text_width(str(l[0]), 13) + 22.0)
	var box := Rect2(size.x - w - 34.0, 16.0, w + 20.0, 34.0 + 18.0 * float(lines.size()))
	draw_rect(box, Color(0.03, 0.025, 0.05, 0.82))
	draw_rect(box, Color(UiTheme.GOLD, 0.35), false, 1.0)
	UiDraw.text(self, box.position + Vector2(10.0, 20.0), title, 14, UiTheme.GOLD)
	var y: float = box.position.y + 40.0
	for l: Array in lines:
		var col: Color = l[1]
		draw_line(box.position + Vector2(10.0, y - 5.0), box.position + Vector2(22.0, y - 5.0), col.lightened(0.3), 2.5, true)
		UiDraw.text(self, box.position + Vector2(28.0, y), str(l[0]), 13, col.lightened(0.4), HORIZONTAL_ALIGNMENT_LEFT, -1.0, false)
		y += 18.0


func _bond_points(a: int, b: int) -> PackedVector2Array:
	var pa: Vector2 = _pos[a]
	var pb: Vector2 = _pos[b]
	var c: Vector2 = _centre()
	var mid: Vector2 = (pa + pb) * 0.5
	var nrm := Vector2(-(pb - pa).y, (pb - pa).x).normalized()
	if (mid + nrm * 10.0 - c).length() < (mid - c).length():
		nrm = -nrm
	var ctrl: Vector2 = mid + nrm * pa.distance_to(pb) * 0.16
	var ra: float = (CORE_R if a == 0 else SEAL_R) + 4.0
	var rb: float = (CORE_R if b == 0 else SEAL_R) + 4.0
	var out := PackedVector2Array()
	for s: int in 29:
		var t: float = float(s) / 28.0
		var q: Vector2 = pa.lerp(ctrl, t).lerp(ctrl.lerp(pb, t), t)
		if q.distance_to(pa) >= ra and q.distance_to(pb) >= rb:
			out.append(q)
	return out


func _length(pts: PackedVector2Array) -> float:
	var t := 0.0
	for s: int in range(1, pts.size()):
		t += pts[s].distance_to(pts[s - 1])
	return t


func _sample(pts: PackedVector2Array, u: float) -> Vector2:
	var f: float = clampf(u, 0.0, 1.0) * float(pts.size() - 1)
	var k: int = mini(int(f), pts.size() - 2)
	return pts[k].lerp(pts[k + 1], f - float(k))


## The word's glyphs round the skill, copy after copy, each linked to the next, slowly turning.
func _draw_chain(word: Dictionary, c: Vector2, locked: bool) -> void:
	var seq: Array = RuneWord.nodes(word)
	var L: int = seq.size()
	var per_copy: int = maxi(1, int(TAU * _chain_r / CHAIN_SPACING) / L)
	var total: int = per_copy * L
	var alpha: float = 1.0 if locked else 0.3
	var shown: int = total
	if _lock_t >= 0.0:
		var e: float = clampf((_lock_t - 0.3) / 1.0, 0.0, 1.0)
		shown = L + int(round(float(total - L) * (1.0 - pow(1.0 - e, 3.0))))
		alpha = 0.3 + 0.7 * clampf(_lock_t / 0.5, 0.0, 1.0)
	var rot: float = _time * (0.035 if locked else 0.015)
	draw_arc(c, _chain_r - 15.0, 0.0, TAU, 128, Color(UiTheme.GOLD, 0.10 * alpha), 1.0, true)
	draw_arc(c, _chain_r + 15.0, 0.0, TAU, 128, Color(UiTheme.GOLD, 0.10 * alpha), 1.0, true)
	var gap: float = 9.5 / _chain_r
	for j: int in shown:
		var ang: float = -PI / 2.0 + rot + TAU * float(j) / float(total)
		var rid: String = str(seq[j % L])
		var rune: Dictionary = GameData.rune(rid)
		var aff: String = str(rune.get("affinity", ""))
		var col: Color = GameData.affinity_color(aff).lightened(0.35) if aff != "" else UiTheme.STAR
		var at: Vector2 = c + Vector2(cos(ang), sin(ang)) * _chain_r
		draw_circle(at, 10.0, Color(col, 0.10 * alpha))
		UiDraw.rune_glyph(self, at, rid, str(rune.get("character", "")), 15, Color(col, alpha))
		if j + 1 < shown or shown == total:
			var nxt: float = -PI / 2.0 + rot + TAU * float(j + 1) / float(total)
			var join: Color = Color(UiTheme.GOLD.lightened(0.2), 0.55 * alpha) if j % L == L - 1 else Color(col, 0.38 * alpha)
			draw_arc(c, _chain_r, ang + gap, nxt - gap, 6, join, 1.3, true)
			if j % L == L - 1:
				var mid: Vector2 = c + Vector2(cos((ang + nxt) * 0.5), sin((ang + nxt) * 0.5)) * _chain_r
				draw_circle(mid, 2.4, Color(UiTheme.GOLD, 0.8 * alpha))


## The lock's flash: a ring of light running out from the skill to the chain.
func _draw_flash(c: Vector2, col: Color) -> void:
	if _lock_t < 0.25 or _lock_t > 1.25:
		return
	var f: float = (_lock_t - 0.25) / 1.0
	var r: float = lerpf(CORE_R, _chain_r + 40.0, f)
	draw_circle(c, CORE_R * (1.0 + 1.6 * f), Color(col.lightened(0.6), 0.28 * (1.0 - f)))
	draw_arc(c, r, 0.0, TAU, 128, Color(1.0, 0.97, 0.85, 0.85 * (1.0 - f)), 2.0 + 8.0 * (1.0 - f), true)
	draw_arc(c, r * 0.92, 0.0, TAU, 128, Color(col.lightened(0.4), 0.4 * (1.0 - f)), 3.0, true)


func _draw_legend(entries: Array[Dictionary]) -> void:
	var y: float = size.y - 18.0 - 18.0 * float(entries.size() - 1)
	for e: Dictionary in entries:
		var key: String = str(e.get("colour", "plain"))
		var a := Vector2(16.0, y - 5.0)
		var b := Vector2(46.0, y - 5.0)
		if key == "weakened":
			var fl: float = 0.3 + 0.7 * (0.5 + 0.5 * sin(_time * 17.0))
			draw_line(a, b, Color(UiTheme.TEXT_DIM, fl), 3.0, true)
		elif key == "polar" or key == "ionic":
			# tapered toward the dominant end, with its chevron
			var col2: Color = LINK_COLOURS.get(key, UiTheme.TEXT_DIM)
			var w0: float = 0.3 if key == "ionic" else 1.2
			for s: int in 6:
				var t0: float = float(s) / 6.0
				var t1: float = float(s + 1) / 6.0
				draw_line(a.lerp(b, t0), a.lerp(b, t1), Color(col2.lightened(0.3), lerpf(0.15 if key == "ionic" else 0.45, 1.0, t1)), lerpf(w0, 3.4, t1), true)
			draw_colored_polygon(PackedVector2Array([b + Vector2(6, 0), b + Vector2(-2, -5), b + Vector2(0, 0), b + Vector2(-2, 5)]), col2.lightened(0.5))
		else:
			var col: Color = LINK_COLOURS.get(key, UiTheme.TEXT_DIM)
			draw_line(a, b, Color(col, 0.25), 7.0, true)
			draw_line(a, b, col.lightened(0.3), 2.5, true)
		UiDraw.text(self, Vector2(58.0, y), str(e.get("label", key)), 12, UiTheme.TEXT_DIM)
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
		custom_minimum_size = Vector2(62, 60)
		pressed.connect(func() -> void: screen.call("add_rune", rune_id))

	func _draw() -> void:
		var st: Dictionary = screen.call("chip_state", rune_id)
		var rune: Dictionary = GameData.rune(rune_id)
		var aff: String = str(rune.get("affinity", ""))
		var tint: Color = GameData.affinity_color(aff).lightened(0.3) if aff != "" else UiTheme.STAR
		var live: bool = bool(st.get("ok", true))
		if not live:
			tint = tint.darkened(0.55)
		draw_circle(Vector2(size.x * 0.5, 22.0), 15.0, Color(tint, 0.08))
		UiDraw.rune_glyph(self, Vector2(size.x * 0.5, 22.0), rune_id, str(rune.get("character", "")), 21, tint)
		UiDraw.text(self, Vector2(0.0, size.y - 8.0), str(rune.get("name", rune_id)), 12, UiTheme.TEXT if live else UiTheme.TEXT_FAINT, HORIZONTAL_ALIGNMENT_CENTER, size.x, false)
		var sockets: int = int(st.get("sockets", -1))
		for k: int in maxi(0, sockets):
			draw_circle(Vector2(size.x - 7.0, 7.0 + float(k) * 7.0), 2.2, UiTheme.GOLD.darkened(0.15 if live else 0.6))
