class_name RuneBoard
extends Control
## The seal screen's drawn word (design/14 sections 7-8), in the ethercosm's space.
##   the skill    a glowing core in its affinity's colour at the centre, its icon inside, its own
##                rune as a watermark, a slowly turning tick ring, and its sockets as motes.
##   the rings    concentric, one per level, stacking outward (Brent 2026-10-23): sealed rings glow
##                as gold bands, the ring being formed at a binding shimmers, open places are small
##                sockets (click one to put the next rune on that ring).
##   the runes    seals in their ring's places, each set beside the runes it bonds to.
##   the shape    a closed ring glows as a band, a great ring gets a halo, a spoke is a beam out
##                along its chain, a branch rune wears a three-rayed star, a balanced word steadies
##                the core.
##   the bonds    curved luminous arcs: thickness by strength, colour by kind, energy flowing from
##                the rune with less pull to the one with more (even bonds shimmer both ways); a
##                weakened bond flickers.
##   the chain    once the word is closed - and fully once it is sealed - its glyphs run round the
##                skill as a chain just outside the outermost sealed ring, copy after copy. Sealing
##                plays: the runes draw in, the chain duplicates outward round the circle, a flash.
## Everything it shows about a word comes from the rule set in force; it knows no chemistry.
## Clicks go to the screen: left-click a rune to pick it (a second rune joins or parts the two),
## left-click an empty place to aim the next rune at its ring, right-click a rune to take it out,
## left-click empty space to drop the pick.

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
const SLOT_HIT := 16.0

var screen: Control
var _time := 0.0
var _pos: Array[Vector2] = []
var _hover := -1
var _lock_t := -1.0          # seconds into the seal animation; < 0 when none is playing
var _chain_r := 200.0
## Every place on every open ring: [{ring, pos, angle, node (-1 = empty)}], for drawing and clicks.
var _slots: Array[Dictionary] = []
## Each ring's radius, by ring number (index 0 is the core).
var _ring_r: Array[float] = [0.0]
## [text, colour] per ring, for the list top-left (filled while the rings are drawn).
var _ring_labels: Array = []


func _init(owner_screen: Control) -> void:
	screen = owner_screen
	name = "RuneBoard"
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS


## Play the seal forming: the runes draw in and the chain duplicates outward with a flash.
func play_lock() -> void:
	_lock_t = 0.0


## Where rune `i` of the word is drawn, in global (viewport) coordinates; for tests.
func node_global(i: int) -> Vector2:
	_pos = _layout(_word())
	return get_global_transform() * _pos[i] if i >= 0 and i < _pos.size() else Vector2(-1, -1)


## Where the first empty place on ring k is drawn, in global coordinates (-1, -1 if none); for tests.
func empty_slot_global(k: int) -> Vector2:
	_pos = _layout(_word())
	for s: Dictionary in _slots:
		if int(s["ring"]) == k and int(s["node"]) < 0:
			return get_global_transform() * (s["pos"] as Vector2)
	return Vector2(-1, -1)


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


## The ring of the empty place under `p`, or -1.
func _slot_at(p: Vector2) -> int:
	for s: Dictionary in _slots:
		if int(s["node"]) < 0 and p.distance_to(s["pos"]) <= SLOT_HIT:
			return int(s["ring"])
	return -1


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	_pos = _layout(_word())
	var at: int = _node_at(mb.position)
	if mb.button_index == MOUSE_BUTTON_LEFT:
		var ring: int = _slot_at(mb.position) if at < 0 else -1
		if ring > 0:
			screen.call("pick_ring", ring)
		else:
			screen.call("pick_node", at)
		accept_event()
	elif mb.button_index == MOUSE_BUTTON_RIGHT and at >= 0:
		screen.call("remove_node", at)
		accept_event()


func _word() -> Dictionary:
	return screen.call("current_word")


func _mode() -> String:
	return str(screen.call("seal_view"))


func _centre() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.5 + 8.0)


# --- layout ---------------------------------------------------------------------------------

## How many rings to draw: the ones the skill may hold, and any a word holds beyond them.
func _ring_count(word: Dictionary) -> int:
	var ctx: RuneContext = screen.call("current_context")
	return maxi(1, maxi(ctx.rings, RuneWord.outer_ring(word)))


## How many places ring k has: what the rules give it (never fewer than the runes on it).
func _ring_places(word: Dictionary, k: int) -> int:
	var rules: RuneRules = Runes.active()
	var on: int = RuneWord.ring_nodes(word, k).size()
	if rules.has_method("ring_capacity"):
		return maxi(on, int(rules.call("ring_capacity", k)))
	return maxi(on, 1)


## Concentric rings, one per level (Brent 2026-10-23): ring k's runes sit in its places, each set
## at the free place nearest the runes it is bonded to that are already placed (inner rings first),
## so bonded runes sit together and a ring's own bonds run round it. Also sets the chain's radius.
func _layout(word: Dictionary) -> Array[Vector2]:
	var n: int = RuneWord.size(word)
	var out: Array[Vector2] = []
	out.resize(n)
	_slots.clear()
	var c: Vector2 = _centre()
	var outer: float = minf(size.x, size.y) * 0.5 - 46.0
	var rings_n: int = _ring_count(word)
	var r1: float = CORE_R + 96.0
	var step: float = clampf((outer - 40.0 - r1) / float(maxi(1, rings_n - 1)), 58.0, 132.0) if rings_n > 1 else 0.0
	_ring_r = [0.0]
	for k: int in range(1, rings_n + 1):
		_ring_r.append(r1 + float(k - 1) * step)
	var sealed_n: int = int(screen.call("sealed_rings"))
	_chain_r = minf(outer + 26.0, _ring_r[clampi(sealed_n if sealed_n > 0 else rings_n, 1, rings_n)] + 36.0)
	if n == 0:
		return out
	out[0] = c
	var rs: Array[int] = RuneWord.rings(word)
	var angle: Array[float] = []
	var placed: Array[bool] = []
	for i: int in n:
		angle.append(0.0)
		placed.append(i == 0)
	for k: int in range(1, rings_n + 1):
		var places: int = _ring_places(word, k)
		var off: float = -PI / 2.0 + (PI / float(places) if k % 2 == 0 else 0.0)
		var slot_angle: Array[float] = []
		var taken: Array[int] = []
		for j: int in places:
			slot_angle.append(off + TAU * float(j) / float(places))
			taken.append(-1)
		var todo: Array[int] = RuneWord.ring_nodes(word, k)
		while not todo.is_empty():
			# the rune with the most placed partners goes next
			var best_i := -1
			var best_n := -1
			for i: int in todo:
				var m := 0
				for p: int in RuneWord.neighbours(word, i):
					if placed[p]:
						m += 1
				if m > best_n:
					best_n = m
					best_i = i
			todo.erase(best_i)
			var sx := 0.0
			var sy := 0.0
			for p: int in RuneWord.neighbours(word, best_i):
				if placed[p] and p != 0:
					sx += cos(angle[p])
					sy += sin(angle[p])
			var want: float = atan2(sy, sx) if (absf(sx) + absf(sy)) > 0.0001 else slot_angle[0]
			var pick := -1
			var pick_d := INF
			for j: int in places:
				if taken[j] >= 0:
					continue
				var d: float = absf(angle_difference(want, slot_angle[j]))
				if d < pick_d - 0.0001:
					pick_d = d
					pick = j
			if pick < 0:
				continue
			taken[pick] = best_i
			angle[best_i] = slot_angle[pick]
			placed[best_i] = true
			out[best_i] = c + Vector2(cos(slot_angle[pick]), sin(slot_angle[pick])) * _ring_r[k]
		for j: int in places:
			_slots.append({"ring": k, "angle": slot_angle[j], "pos": c + Vector2(cos(slot_angle[j]), sin(slot_angle[j])) * _ring_r[k], "node": taken[j]})
	for i: int in range(1, n):
		if rs[i] < 1 or rs[i] > rings_n:
			out[i] = Vector2(size.x - 56.0, size.y - 64.0)          # a ring the board does not draw
	# sealing: everything draws in toward the skill, then settles back
	if _lock_t >= 0.0:
		var pull: float = 0.42 * sin(PI * clampf(_lock_t / 0.9, 0.0, 1.0))
		for i: int in range(1, n):
			out[i] = c + (out[i] - c) * (1.0 - pull)
	return out


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
	var mode: String = _mode()
	var sealed: bool = mode == "view" and RuneWord.is_locked(word)
	var ws: Dictionary = rules.word_state(word, ctx)
	var closed: bool = bool(ws.get("closed", false))
	var traits: Array = []
	if rules.has_method("shape_traits"):
		traits = rules.call("shape_traits", word)

	UiDraw.void_field(self, size, c, _time)
	_draw_nebula(c, aff_col)
	_draw_rings(c, word, ctx, aff_col)
	_draw_traits(c, word, traits, aff_col)
	if n > 1 and (sealed or closed):
		_draw_chain(word, c, sealed)
	_draw_slots(word)
	for l: Dictionary in RuneWord.links(word):
		var a: int = int(l["a"])
		var b: int = int(l["b"])
		_draw_bond(rules.describe_link(word, a, b, ctx), a, b)
	var picked: int = int(screen.get("picked"))
	if n > 0:
		_draw_core(c, ab, aff_col, word, rules.describe_node(word, 0, ctx), picked == 0)
	for i: int in range(1, n):
		_draw_seal(word, i, rules.describe_node(word, i, ctx), i == picked)
	_draw_branch_marks(traits)
	_draw_flash(c, aff_col)

	var hint: String = {"bind": "Click a rune in the panel to set it: one ring out from the rune picked here, or on the ring you click.",
		"test": "Click a rune in the panel to set it: one ring out from the rune picked here, or on the ring you click.",
		"view": "The seal of this skill. It is reworked when the next construct is bound into it."}.get(mode, "")
	UiDraw.text(self, Vector2(16.0, 26.0), hint, 13, UiTheme.TEXT_FAINT)
	if mode != "view":
		UiDraw.text(self, Vector2(16.0, 44.0), "Click two runes to join or part them. Right-click one to take it out.", 13, UiTheme.TEXT_FAINT)
	var pulse: float = 0.75 + 0.25 * sin(_time * 2.0)
	if mode == "bind":
		UiDraw.outlined(self, Vector2(16.0, 74.0), "F O R M I N G   R I N G   %d" % ctx.forming, 18, Color(UiTheme.STAR.lightened(0.2), pulse), HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
	elif mode == "test":
		UiDraw.outlined(self, Vector2(16.0, 74.0), "FREE EDIT  -  TEST CHARACTER", 16, Color(UiTheme.BAD.lightened(0.25), pulse), HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
	elif sealed:
		UiDraw.outlined(self, Vector2(16.0, 74.0), "S E A L E D", 18, Color(UiTheme.GOLD, pulse), HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
	else:
		UiDraw.outlined(self, Vector2(16.0, 74.0), "NO WORD YET", 15, Color(UiTheme.TEXT_DIM, 0.9), HORIZONTAL_ALIGNMENT_LEFT, -1.0)
	var ty := 100.0
	if mode != "view" and closed and n > 1:
		UiDraw.outlined(self, Vector2(16.0, ty), "CLOSED  -  ready to seal", 14, Color(UiTheme.GOOD, 0.9), HORIZONTAL_ALIGNMENT_LEFT, -1.0)
		ty += 20.0
	ty += 6.0
	for rl: Array in _ring_labels:
		UiDraw.text(self, Vector2(16.0, ty), str(rl[0]), 12, Color(rl[1] as Color, 0.9))
		ty += 16.0
	ty += 8.0
	for t: Dictionary in traits:
		UiDraw.outlined(self, Vector2(16.0, ty), "%s%s" % [str(t["label"]).to_upper(), ("  ring %d" % int(t["ring"])) if t.has("ring") else (("  %d rings" % int(t["rings"])) if t.has("rings") else "")],
			13, _trait_colour(str(t["id"]), aff_col), HORIZONTAL_ALIGNMENT_LEFT, -1.0)
		ty += 18.0
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


## The rings, stacking outward: sealed rings glow as gold bands; the ring being formed shimmers,
## dashed and turning; a ring open but not yet sealed is a faint dotted line. Each is labelled.
func _draw_rings(c: Vector2, word: Dictionary, ctx: RuneContext, col: Color) -> void:
	var sealed_n: int = int(screen.call("sealed_rings"))
	var mode: String = _mode()
	var target: int = int(screen.get("target_ring"))
	_ring_labels.clear()
	for k: int in range(1, _ring_r.size()):
		var r: float = _ring_r[k]
		var is_sealed: bool = k <= sealed_n
		var forming: bool = mode == "bind" and k == ctx.forming
		var label := "ring %d" % k
		if forming:
			var shim: float = 0.55 + 0.45 * sin(_time * 3.0)
			draw_arc(c, r, 0.0, TAU, 160, Color(UiTheme.STAR, 0.06 + 0.05 * shim), 18.0, true)
			var segs := 48
			var rot: float = _time * 0.35
			for s: int in segs:
				if s % 2 == 0:
					var a0: float = rot + TAU * float(s) / float(segs)
					draw_arc(c, r, a0, a0 + TAU / float(segs), 6, Color(UiTheme.STAR.lightened(0.3), 0.45 + 0.4 * shim), 2.0, true)
			# motes gathering into the forming ring
			for m: int in 10:
				var u: float = fmod(_time * 0.25 + float(m) * 0.1, 1.0)
				var am: float = TAU * float(m) / 10.0 + _time * 0.1
				var rr: float = lerpf(r + 40.0, r, u)
				draw_circle(c + Vector2(cos(am), sin(am)) * rr, 2.0, Color(UiTheme.STAR.lightened(0.4), 0.7 * sin(PI * u)))
			label = "ring %d  -  forming" % k
		elif is_sealed:
			var gold: Color = UiTheme.GOLD.lerp(col.lightened(0.3), 0.25)
			var dim: float = 0.7 if mode == "bind" else 1.0
			draw_arc(c, r, 0.0, TAU, 160, Color(gold, 0.15 * dim), 14.0, true)
			draw_arc(c, r - 7.0, 0.0, TAU, 160, Color(gold, 0.5 * dim), 1.2, true)
			draw_arc(c, r + 7.0, 0.0, TAU, 160, Color(gold, 0.5 * dim), 1.2, true)
			for t: int in 72:
				var at: float = TAU * float(t) / 72.0 - _time * 0.02 * (1.0 if k % 2 == 1 else -1.0)
				var dir := Vector2(cos(at), sin(at))
				draw_line(c + dir * (r - 7.0), c + dir * (r - (4.0 if t % 6 == 0 else 5.5)), Color(gold, 0.45 * dim), 1.0, true)
			label = "ring %d  -  sealed%s" % [k, ", can be reworked" if mode == "bind" else ""]
		else:
			var segs2 := 96
			for s2: int in segs2:
				if s2 % 3 == 0:
					var a1: float = TAU * float(s2) / float(segs2) + _time * 0.01
					draw_arc(c, r, a1, a1 + TAU / float(segs2), 3, Color(UiTheme.STAR, 0.16), 1.0, true)
			if mode == "test":
				label = "ring %d  -  open" % k
		if target == k:
			draw_arc(c, r, 0.0, TAU, 160, Color(UiTheme.GOLD, 0.18 + 0.1 * sin(_time * 5.0)), 4.0, true)
		# the ring's number on its left side, and its line in the list top-left
		var tag_col: Color = UiTheme.STAR if forming else (UiTheme.GOLD if is_sealed else UiTheme.TEXT_FAINT)
		var tp: Vector2 = c + Vector2(-r, 0.0)
		draw_circle(tp, 10.0, Color(0.02, 0.02, 0.04, 0.95))
		draw_arc(tp, 10.0, 0.0, TAU, 20, Color(tag_col, 0.8), 1.2, true)
		UiDraw.text(self, tp + Vector2(-10.0, 5.0), str(k), 12, tag_col, HORIZONTAL_ALIGNMENT_CENTER, 20.0, false)
		_ring_labels.append([label, tag_col])


## The empty places on the open rings: small hollow sockets (bright on the ring the next rune goes to).
func _draw_slots(_word_d: Dictionary) -> void:
	var mode: String = _mode()
	var target: int = int(screen.get("target_ring"))
	var ctx: RuneContext = screen.call("current_context")
	for s: Dictionary in _slots:
		if int(s["node"]) >= 0:
			continue
		var k: int = int(s["ring"])
		var p: Vector2 = s["pos"]
		var hot: bool = k == target or (mode == "bind" and k == ctx.forming and target < 0)
		var a: float = 0.55 if hot else 0.25
		if mode == "view":
			a = 0.14
		draw_circle(p, 9.0, Color(0, 0, 0, 0.55))
		draw_arc(p, 9.0, 0.0, TAU, 20, Color(UiTheme.GOLD if k == target else UiTheme.STAR, a + (0.2 * sin(_time * 4.0) if k == target else 0.0)), 1.3, true)
		draw_circle(p, 2.0, Color(UiTheme.STAR, a * 0.8))


func _trait_colour(id: String, col: Color) -> Color:
	match id:
		"closed_ring":
			return col.lightened(0.45)
		"great_ring":
			return UiTheme.GOLD.lightened(0.25)
		"spoke":
			return Color("9fe0ff")
		"branch":
			return Color("e8c062")
		"balanced":
			return UiTheme.GOOD.lightened(0.2)
	return UiTheme.STAR


## The shapes the word has, drawn on the board: a closed ring glows as a band, a great ring gets a
## second halo, a spoke is a beam of light out along its chain, a balanced word steadies the core.
## (Branch runes get their mark after the seals are drawn.)
func _draw_traits(c: Vector2, _word_d: Dictionary, traits: Array, col: Color) -> void:
	for t: Dictionary in traits:
		var id: String = str(t["id"])
		var tc: Color = _trait_colour(id, col)
		match id:
			"closed_ring":
				var k: int = int(t["ring"])
				if k < _ring_r.size():
					var r: float = _ring_r[k]
					draw_arc(c, r, 0.0, TAU, 180, Color(tc, 0.10), 30.0, true)
					draw_arc(c, r, 0.0, TAU, 180, Color(tc, 0.22), 12.0, true)
					draw_arc(c, r - 15.0, 0.0, TAU, 180, Color(tc.lightened(0.3), 0.55), 1.5, true)
					draw_arc(c, r + 15.0, 0.0, TAU, 180, Color(tc.lightened(0.3), 0.55), 1.5, true)
					for m: int in 24:
						var am: float = TAU * float(m) / 24.0 + _time * 0.4
						draw_circle(c + Vector2(cos(am), sin(am)) * r, 2.2, Color(tc.lightened(0.6), 0.8))
			"great_ring":
				var k2: int = int(t["ring"])
				if k2 < _ring_r.size():
					var pulse: float = 0.6 + 0.4 * sin(_time * 2.2)
					draw_arc(c, _ring_r[k2] + 24.0, 0.0, TAU, 180, Color(tc, 0.35 * pulse), 2.5, true)
					draw_arc(c, _ring_r[k2] - 24.0, 0.0, TAU, 180, Color(tc, 0.35 * pulse), 2.5, true)
			"spoke":
				var nodes: Array = t.get("nodes", [])
				var pts := PackedVector2Array([c])
				for i: Variant in nodes:
					if int(i) < _pos.size():
						pts.append(_pos[int(i)])
				if pts.size() >= 2:
					var tip: Vector2 = pts[pts.size() - 1]
					var dir: Vector2 = (tip - c).normalized()
					pts.append(tip + dir * 46.0)
					for s: int in pts.size() - 1:
						draw_line(pts[s], pts[s + 1], Color(tc, 0.10), 26.0, true)
						draw_line(pts[s], pts[s + 1], Color(tc, 0.22), 9.0, true)
					for m2: int in 8:
						var u: float = fmod(_time * 0.35 + float(m2) / 8.0, 1.0)
						var at: Vector2 = _along(pts, u)
						draw_circle(at, 3.0, Color(tc.lightened(0.5), 0.9 * sin(PI * u)))
			"balanced":
				var p2: float = 0.8 + 0.2 * sin(_time * 1.5)
				draw_arc(c, CORE_R + 30.0, 0.0, TAU, 96, Color(tc, 0.5 * p2), 2.0, true)
				draw_arc(c, CORE_R + 36.0, 0.0, TAU, 96, Color(tc, 0.25 * p2), 1.0, true)


## A branch rune: a three-rayed star of light round its seal.
func _draw_branch_marks(traits: Array) -> void:
	for t: Dictionary in traits:
		if str(t["id"]) != "branch":
			continue
		for i: Variant in t.get("nodes", []):
			if int(i) >= _pos.size():
				continue
			var p: Vector2 = _pos[int(i)]
			var rot: float = _time * 0.5
			for j: int in 3:
				var a: float = rot + TAU * float(j) / 3.0
				var d := Vector2(cos(a), sin(a))
				draw_line(p + d * (SEAL_R + 13.0), p + d * (SEAL_R + 24.0), Color(_trait_colour("branch", Color.WHITE), 0.85), 2.2, true)
				draw_circle(p + d * (SEAL_R + 25.0), 2.4, Color(_trait_colour("branch", Color.WHITE).lightened(0.4), 0.9))


## The point a fraction u of the way along a polyline.
func _along(pts: PackedVector2Array, u: float) -> Vector2:
	var total := 0.0
	for s: int in range(1, pts.size()):
		total += pts[s].distance_to(pts[s - 1])
	var want: float = total * clampf(u, 0.0, 1.0)
	for s: int in range(1, pts.size()):
		var seg: float = pts[s].distance_to(pts[s - 1])
		if want <= seg:
			return pts[s - 1].lerp(pts[s], want / maxf(seg, 0.0001))
		want -= seg
	return pts[pts.size() - 1]


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
	# two runes on the same ring: the bond runs round the ring, the shorter way
	var word: Dictionary = _word()
	var ka: int = RuneWord.ring(word, a)
	if ka >= 1 and ka == RuneWord.ring(word, b) and _lock_t < 0.0:
		var r: float = (pa - c).length()
		var a0: float = (pa - c).angle()
		var span: float = angle_difference(a0, (pb - c).angle())
		for s2: int in 41:
			var q2: Vector2 = c + Vector2.from_angle(a0 + span * float(s2) / 40.0) * r
			if q2.distance_to(pa) >= ra and q2.distance_to(pb) >= rb:
				out.append(q2)
		return out
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
		if not bool(st.get("known", true)):
			# not discovered yet: a grey "?" in a dim socket
			draw_circle(Vector2(size.x * 0.5, 22.0), 15.0, Color(1, 1, 1, 0.03))
			draw_arc(Vector2(size.x * 0.5, 22.0), 15.0, 0.0, TAU, 24, Color(UiTheme.TEXT_FAINT, 0.35), 1.0, true)
			UiDraw.text(self, Vector2(0.0, 30.0), "?", 22, Color(UiTheme.TEXT_FAINT, 0.7), HORIZONTAL_ALIGNMENT_CENTER, size.x, false)
			UiDraw.text(self, Vector2(0.0, size.y - 8.0), "?", 12, Color(UiTheme.TEXT_FAINT, 0.6), HORIZONTAL_ALIGNMENT_CENTER, size.x, false)
			return
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
