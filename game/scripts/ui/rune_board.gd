class_name RuneBoard
extends Control
## The seal screen's drawn word (design/14 sections 7-8), in the ethercosm's space.
##   the skill    a glowing core in its affinity's colour at the centre, its icon inside, its own
##                rune as a watermark, a slowly turning tick ring, and its sockets as motes.
##   the rings    concentric, one per level, stacking outward (Brent 2026-10-23): sealed rings glow
##                as gold bands, the ring being formed at a binding shimmers, open places are small
##                sockets.
##   the runes    seals in their ring's places. A rune keeps the place it was set in (RuneWord
##                "places"): bonding never moves it.
##   the shape    a closed ring glows as a band, a great ring gets a halo, a spoke is a beam out
##                along its chain, a branch rune wears a three-rayed star, a balanced word steadies
##                the core.
##   the bonds    curved luminous arcs: thickness by strength, colour by kind, energy flowing from
##                the rune with less pull to the one with more (even bonds shimmer both ways); a
##                weakened bond flickers. Two runes of one ring that are not neighbours bond across
##                the ring, never along it through the rune between them.
##   the chain    once the word is closed - and fully once it is sealed - its glyphs run round the
##                skill as a chain just outside the outermost sealed ring, copy after copy. Sealing
##                plays: the runes draw in, the chain duplicates outward round the circle, a flash.
## Everything it shows about a word comes from the rule set in force; it knows no chemistry.
##
## Building (Brent 2026-10-23: "make the bonds selectable for deletion and allow click and drag to
## create the bonds"). The screen owns the selection and makes every change; the board only reads the
## mouse:
##   place a rune   drag it from the palette onto an empty place (the chip carries it: carry_at /
##                  drop_at), or click it in the palette and then click the place. While a rune is
##                  in hand the places that take it glow; the others are marked, and say why when
##                  pointed at.
##   bond           press on a rune (or the skill's core) and drag: a live line follows the cursor. Over
##                  a rune that would take the bond it shows the bond's kind and dominant side; runes
##                  that would take it glow, the others dim with the reason. Let go on one to bond,
##                  anywhere else to cancel; Esc cancels.
##   select         click a rune or a bond (hit along its curve, generously); a selected bond shows a
##                  small x that deletes it. Right-click deletes a rune or a bond. Empty space
##                  deselects. Hover lights what is under the cursor.
## A press only becomes a drag after DRAG_START pixels, so a click on a rune selects it.

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
## How far from an empty place's centre a click or a drop still lands on it.
const SLOT_HIT := 18.0
## Added to a rune's radius for clicks, hover and the end of a bond drag.
const NODE_HIT := 7.0
## How far from a bond's curve a click still selects it.
const BOND_HIT := 11.0
## How far a press on a rune must move before it is a bond drag rather than a click.
const DRAG_START := 7.0
## The radius of a selected bond's delete button.
const CROSS_R := 10.0
## Short words for why a bond or a place is refused, by the rules' reason code (the full text shows
## where the cursor is).
const SHORT_REASON := {
	"valence_full": "full", "rings_apart": "not an adjacent ring", "refused": "alignment refuses",
	"already_linked": "already bonded", "ring_full": "ring full", "ring": "ring not open", "capacity": "word full",
	"no_rings": "no ring yet", "unknown": "not discovered", "not_yours": "not your affinity", "locked": "sealed",
	"repeat": "already in the word", "ring_unformed": "inner ring not formed",
}

var screen: Control
var _time := 0.0
var _pos: Array[Vector2] = []
var _hover := -1                           # the rune under the cursor
var _hover_bond := Vector2i(-1, -1)        # the bond under the cursor (a < b)
var _hover_slot := -1                      # the empty place under the cursor (index into _slots)
var _hover_cross := false                  # the cursor is on the selected bond's x
var _mouse := Vector2(-100000, -100000)    # the cursor, in the board's coordinates
var _lock_t := -1.0          # seconds into the seal animation; < 0 when none is playing
var _chain_r := 200.0
## Every place on every open ring: [{ring, place, angle, pos, node (-1 = empty)}], for drawing and clicks.
var _slots: Array[Dictionary] = []
## Each ring's radius, by ring number (index 0 is the core).
var _ring_r: Array[float] = [0.0]
## [text, colour] per ring, for the list top-left (filled while the rings are drawn).
var _ring_labels: Array = []
## Each bond's drawn curve from the last layout: Vector2i(a, b) (a < b) -> points.
var _bond_pts: Dictionary = {}
## A press on a rune, and the bond being dragged out of it.
var _press_node := -1
var _press_pos := Vector2.ZERO
var _dragging := false
## node -> the rules' answer to "may the dragged bond end here?" ({ok, reason, text}).
var _drag_checks: Dictionary = {}
## A rune carried from the palette by drag and drop ("" when none).
var _carry_rune := ""
## "rune|ring" -> the rules' answer to "may this rune be set on that ring?" (for the word drawn).
var _slot_checks: Dictionary = {}
var _slot_checks_key := ""
## A shot set the cursor: the real mouse is ignored from then on.
var _cursor_pinned := false


func _init(owner_screen: Control) -> void:
	screen = owner_screen
	name = "RuneBoard"
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	focus_mode = Control.FOCUS_NONE


## Play the seal forming: the runes draw in and the chain duplicates outward with a flash.
func play_lock() -> void:
	_lock_t = 0.0


# --- for tests and shots -----------------------------------------------------------------------

## Where rune `i` of the word is drawn, in global (viewport) coordinates.
func node_global(i: int) -> Vector2:
	_pos = _layout(_word())
	return get_global_transform() * _pos[i] if i >= 0 and i < _pos.size() else Vector2(-1, -1)


## Where the n-th empty place on ring k is drawn, in global coordinates (-1, -1 if none).
func empty_slot_global(k: int, nth: int = 0) -> Vector2:
	_pos = _layout(_word())
	var seen := 0
	for s: Dictionary in _slots:
		if int(s["ring"]) == k and int(s["node"]) < 0:
			if seen == nth:
				return get_global_transform() * (s["pos"] as Vector2)
			seen += 1
	return Vector2(-1, -1)


## The place index of the n-th empty place on ring k (-1 if none).
func empty_place(k: int, nth: int = 0) -> int:
	_pos = _layout(_word())
	var seen := 0
	for s: Dictionary in _slots:
		if int(s["ring"]) == k and int(s["node"]) < 0:
			if seen == nth:
				return int(s["place"])
			seen += 1
	return -1


## A point on bond a-b's drawn curve (its middle), in global coordinates.
func bond_global(a: int, b: int) -> Vector2:
	_pos = _layout(_word())
	var pts: PackedVector2Array = _bond_points(mini(a, b), maxi(a, b))
	if pts.size() < 2:
		return Vector2(-1, -1)
	return get_global_transform() * _sample(pts, 0.5)


## The selected bond's delete button, in global coordinates (-1, -1 when no bond is selected).
func cross_global() -> Vector2:
	_pos = _layout(_word())
	var at: Vector2 = _cross_at()
	return get_global_transform() * at if at.x > -9999.0 else Vector2(-1, -1)


func is_dragging() -> bool:
	return _dragging


func drag_source() -> int:
	return _press_node if _dragging else -1


## Show a bond being dragged from `from` with the cursor at `at` (board-global), for a screenshot.
func show_drag(from: int, at: Vector2) -> void:
	_pos = _layout(_word())
	_press_node = from
	_press_pos = _pos[from] if from < _pos.size() else Vector2.ZERO
	_mouse = get_global_transform().affine_inverse() * at
	_cursor_pinned = true
	_begin_drag(from)
	_update_hover()


## Point the cursor at `at` (board-global), for a screenshot of hover states.
func show_cursor(at: Vector2) -> void:
	_pos = _layout(_word())
	_mouse = get_global_transform().affine_inverse() * at
	_cursor_pinned = true
	_update_hover()


## Esc: drop a bond being dragged. Returns true if one was.
func cancel_drag() -> bool:
	if not _dragging and _press_node < 0:
		return false
	var was: bool = _dragging
	_end_drag()
	return was


# --- input ---------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	if _lock_t >= 0.0:
		_lock_t += delta
		if _lock_t > LOCK_ANIM_S:
			_lock_t = -1.0
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and not _dragging and _carry_rune == "" and not _cursor_pinned:
		_mouse = Vector2(-100000, -100000)
		_update_hover()


func _editable() -> bool:
	return _mode() != "view"


func _gui_input(event: InputEvent) -> void:
	if _cursor_pinned:
		return
	var mm := event as InputEventMouseMotion
	if mm != null:
		_mouse = mm.position
		if _press_node >= 0 and not _dragging and _editable() and _mouse.distance_to(_press_pos) > DRAG_START:
			_begin_drag(_press_node)
		_update_hover()
		if _dragging:
			accept_event()
		return
	var mb := event as InputEventMouseButton
	if mb == null:
		return
	_mouse = mb.position
	_pos = _layout(_word())
	_update_hover()
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_left_press()
		else:
			_left_release()
		accept_event()
	elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		if _dragging:
			_end_drag()
		elif _hover >= 0:
			screen.call("remove_node", _hover)
		elif _hover_bond.x >= 0:
			screen.call("delete_bond", _hover_bond.x, _hover_bond.y)
		else:
			screen.call("deselect")
		accept_event()


func _left_press() -> void:
	if _hover_cross:
		var sel: Vector2i = screen.get("picked_bond")
		screen.call("delete_bond", sel.x, sel.y)
	elif _hover >= 0:
		_press_node = _hover
		_press_pos = _mouse
	elif _hover_bond.x >= 0:
		screen.call("select_bond", _hover_bond.x, _hover_bond.y)
	elif _hover_slot >= 0:
		var s: Dictionary = _slots[_hover_slot]
		screen.call("click_slot", int(s["ring"]), int(s["place"]))
	else:
		screen.call("deselect")


func _left_release() -> void:
	if _dragging:
		var src: int = _press_node
		var target: int = _hover if _hover != src else -1
		_end_drag()
		screen.call("finish_bond", src, target)
	elif _press_node >= 0:
		var i: int = _press_node
		_press_node = -1
		screen.call("select_node", i)


func _begin_drag(from: int) -> void:
	_dragging = true
	_drag_checks.clear()
	var word: Dictionary = _word()
	var rules: RuneRules = Runes.active()
	var ctx: RuneContext = screen.call("current_context")
	for k: int in RuneWord.size(word):
		if k != from:
			_drag_checks[k] = rules.can_link(word, from, k, ctx)


func _end_drag() -> void:
	_dragging = false
	_press_node = -1
	_drag_checks.clear()


## What is under the cursor: a rune first (the nearest), then the selected bond's x, a bond (the
## nearest within BOND_HIT of its curve), an empty place.
func _update_hover() -> void:
	_hover = _node_at(_mouse)
	_hover_cross = false
	_hover_bond = Vector2i(-1, -1)
	_hover_slot = -1
	if _hover >= 0 or _dragging:
		return
	var cx: Vector2 = _cross_at()
	if cx.x > -9999.0 and _mouse.distance_to(cx) <= CROSS_R + 4.0:
		_hover_cross = true
		return
	_hover_bond = _bond_at(_mouse)
	if _hover_bond.x >= 0:
		return
	_hover_slot = _slot_index_at(_mouse)


## The rune nearest `p` within its radius + NODE_HIT, or -1 (the nearest, not the first by index).
func _node_at(p: Vector2) -> int:
	var best := -1
	var best_d := INF
	for i: int in _pos.size():
		var d: float = p.distance_to(_pos[i])
		if d <= (CORE_R if i == 0 else SEAL_R) + NODE_HIT and d < best_d:
			best = i
			best_d = d
	return best


## The bond whose drawn curve passes nearest `p`, within BOND_HIT; (-1, -1) if none.
func _bond_at(p: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d: float = BOND_HIT
	for key: Vector2i in _bond_pts:
		var pts: PackedVector2Array = _bond_pts[key]
		for s: int in range(1, pts.size()):
			var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, pts[s - 1], pts[s])
			var d: float = p.distance_to(q)
			if d < best_d:
				best_d = d
				best = key
	return best


## The empty place under `p` (index into _slots), or -1.
func _slot_index_at(p: Vector2) -> int:
	var best := -1
	var best_d: float = SLOT_HIT
	for k: int in _slots.size():
		var s: Dictionary = _slots[k]
		if int(s["node"]) < 0 and p.distance_to(s["pos"]) <= best_d:
			best_d = p.distance_to(s["pos"])
			best = k
	return best


## Where the selected bond's x is drawn: beside the middle of its curve, on the side away from the
## skill (-99999, -99999 when no bond is selected).
func _cross_at() -> Vector2:
	var sel: Vector2i = screen.get("picked_bond")
	if sel.x < 0 or not _bond_pts.has(sel):
		return Vector2(-99999, -99999)
	var pts: PackedVector2Array = _bond_pts[sel]
	if pts.size() < 2:
		return Vector2(-99999, -99999)
	var mid: Vector2 = _sample(pts, 0.5)
	var along: Vector2 = (_sample(pts, 0.55) - _sample(pts, 0.45)).normalized()
	var nrm := Vector2(-along.y, along.x)
	if (mid + nrm - _centre()).length() < (mid - _centre()).length():
		nrm = -nrm
	return mid + nrm * 17.0


# --- a rune carried from the palette ---------------------------------------------------------------
# The palette chip (Chip) owns the press, so it gets every move until the button is let go; it hands
# the cursor here (in global coordinates) and the board lights the places, draws the rune at the
# cursor and takes the drop. (Godot's own drag and drop reads the system cursor at the drop, not the
# event, so it cannot be driven by the click tests - this can.)

## A palette rune is being carried, the cursor at `at` (global).
func carry_at(rune_id: String, at: Vector2) -> void:
	if not _editable():
		return
	_carry_rune = rune_id
	_pos = _layout(_word())
	_mouse = get_global_transform().affine_inverse() * at
	_update_hover()


## The carried rune let go at `at` (global): set on the empty place there, if there is one.
func drop_at(rune_id: String, at: Vector2) -> void:
	_carry_rune = ""
	if not _editable():
		return
	_pos = _layout(_word())
	_mouse = get_global_transform().affine_inverse() * at
	_update_hover()
	var inside: bool = Rect2(Vector2.ZERO, size).has_point(_mouse)
	var k: int = _slot_index_at(_mouse)
	if k >= 0:
		screen.call("place_rune", rune_id, int(_slots[k]["ring"]), int(_slots[k]["place"]))
	elif inside:
		screen.call("drop_missed", rune_id)
	else:
		screen.call("carry_cancelled", rune_id)


func is_carrying() -> bool:
	return _carry_rune != ""


## The rune in hand: carried from the palette, or picked there and waiting for a place.
func _in_hand() -> String:
	return _carry_rune if _carry_rune != "" else str(screen.get("armed_rune"))


## May rune `rid` be set on ring k? (Cached for the word drawn.)
func _slot_check(rid: String, k: int) -> Dictionary:
	var key: String = RuneWord.shape_key(_word())
	if key != _slot_checks_key:
		_slot_checks.clear()
		_slot_checks_key = key
	var ck: String = "%s|%d" % [rid, k]
	if not _slot_checks.has(ck):
		_slot_checks[ck] = screen.call("place_check", rid, k)
	return _slot_checks[ck]


## The rules in force as ring rules (null under rules without rings).
func rules_ring() -> RingRules:
	return Runes.active() as RingRules


func _word() -> Dictionary:
	return screen.call("current_word")


func _mode() -> String:
	return str(screen.call("seal_view"))


func _centre() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.5 + 8.0)


static func short_reason(r: Dictionary) -> String:
	return str(SHORT_REASON.get(str(r.get("reason", "")), "refused"))


# --- layout ---------------------------------------------------------------------------------

## How many rings to draw: the ones the skill may hold, and any a word holds beyond them.
func _ring_count(word: Dictionary) -> int:
	var ctx: RuneContext = screen.call("current_context")
	return maxi(1, maxi(ctx.rings, RuneWord.outer_ring(word)))


## Concentric rings, one per level (Brent 2026-10-23). Each rune sits at its stored place on its
## ring (RuneWord "places"); a rune without one gets the free place nearest the runes it is bonded to
## (RuneWord.layout_places). Also sets the chain's radius and the empty places.
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
	var counts: Dictionary = Runes.place_counts(word, screen.call("current_context"))
	var places: Array[int] = RuneWord.layout_places(word, counts)
	var rs: Array[int] = RuneWord.rings(word)
	for k: int in range(1, rings_n + 1):
		var count: int = int(counts.get(k, 1))
		var taken: Array[int] = []
		for j: int in count:
			taken.append(-1)
		for i: int in RuneWord.ring_nodes(word, k):
			if places[i] >= 0 and places[i] < count:
				taken[places[i]] = i
				out[i] = c + Vector2.from_angle(RuneWord.place_angle(k, places[i], count)) * _ring_r[k]
		for j: int in count:
			var a: float = RuneWord.place_angle(k, j, count)
			_slots.append({"ring": k, "place": j, "angle": a, "pos": c + Vector2.from_angle(a) * _ring_r[k], "node": taken[j]})
	for i: int in range(1, n):
		if rs[i] < 1 or rs[i] > rings_n or places[i] < 0:
			out[i] = Vector2(size.x - 56.0, size.y - 64.0)          # a ring the board does not draw
	# sealing: everything draws in toward the skill, then settles back
	if _lock_t >= 0.0:
		var pull: float = 0.42 * sin(PI * clampf(_lock_t / 0.9, 0.0, 1.0))
		for i: int in range(1, n):
			out[i] = c + (out[i] - c) * (1.0 - pull)
	# each bond's curve, for drawing and hit tests
	_pos = out
	_bond_pts.clear()
	for l: Dictionary in RuneWord.links(word):
		var key := Vector2i(mini(int(l["a"]), int(l["b"])), maxi(int(l["a"]), int(l["b"])))
		_bond_pts[key] = _bond_points(key.x, key.y)
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
	if not _dragging:
		_update_hover()
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
	_draw_slots(ctx)
	var sel: Vector2i = screen.get("picked_bond")
	for l: Dictionary in RuneWord.links(word):
		var key := Vector2i(mini(int(l["a"]), int(l["b"])), maxi(int(l["a"]), int(l["b"])))
		_draw_bond(rules.describe_link(word, key.x, key.y, ctx), key.x, key.y, 2 if key == sel else (1 if key == _hover_bond else 0))
	var picked: int = int(screen.get("picked"))
	if n > 0:
		_draw_core(c, ab, aff_col, word, rules.describe_node(word, 0, ctx), picked == 0)
	for i: int in range(1, n):
		_draw_seal(word, i, rules.describe_node(word, i, ctx), i == picked)
	_draw_branch_marks(traits)
	if _dragging:
		_draw_drag(word, rules, ctx)
	_draw_cross()
	_draw_flash(c, aff_col)
	if _carry_rune != "" and Rect2(Vector2.ZERO, size).has_point(_mouse):
		_draw_carried(_carry_rune, _mouse)

	# what the controls are, top left; then the mode, the rings and the shape
	var hint := "The seal of this skill. It is reworked when the next construct is bound into it."
	var hint2 := "Click a rune or a bond to read it."
	if mode != "view":
		hint = "Drag a rune from the panel onto an empty place (or click it, then the place)."
		hint2 = "Drag rune to rune to bond. %s or right-click deletes; %s undoes." % [
			Keybinds.binding_text("seal_delete"), Keybinds.binding_text("seal_undo")]
	UiDraw.text(self, Vector2(16.0, 26.0), hint, 13, UiTheme.TEXT_FAINT)
	UiDraw.text(self, Vector2(16.0, 44.0), hint2, 13, UiTheme.TEXT_FAINT)
	var doing: String = _doing_line(word)
	if doing != "":
		UiDraw.outlined(self, Vector2(16.0, 64.0), doing, 14, UiTheme.GOLD.lightened(0.25), HORIZONTAL_ALIGNMENT_LEFT, -1.0)
	var pulse: float = 0.75 + 0.25 * sin(_time * 2.0)
	var ty := 96.0
	if mode == "bind":
		var first_new: int = int(screen.call("sealed_rings")) + 1
		var forming_t: String = ("F O R M I N G   R I N G   %d" % ctx.forming) if first_new >= ctx.forming else "F O R M I N G   R I N G S   %d - %d" % [first_new, ctx.forming]
		UiDraw.outlined(self, Vector2(16.0, ty), "L E V E L   %d   L O C K   -   %s" % [ctx.stage + 1, forming_t], 18,
			Color(UiTheme.STAR.lightened(0.2), pulse), HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
	elif sealed:
		UiDraw.outlined(self, Vector2(16.0, ty), "S E A L E D", 18, Color(UiTheme.GOLD, pulse), HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
	else:
		UiDraw.outlined(self, Vector2(16.0, ty), "NO WORD YET", 15, Color(UiTheme.TEXT_DIM, 0.9), HORIZONTAL_ALIGNMENT_LEFT, -1.0)
	ty += 24.0
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
	_draw_tip(word)


## The line under the controls saying what is happening now: a rune in hand, a bond being dragged.
func _doing_line(word: Dictionary) -> String:
	if _dragging and _press_node >= 0:
		return "Bonding from %s: let go on a glowing rune to bond it - anywhere else, or %s, cancels." % [
			RuneRules.rune_name(word, _press_node), Keybinds.binding_text("settings")]
	var hand: String = _in_hand()
	if hand != "" and _mode() != "view":
		return "Setting %s: the glowing places take it. %s puts it down." % [str(GameData.rune(hand).get("name", hand)),
			"Let go over one" if _carry_rune != "" else "Click one; %s" % Keybinds.binding_text("settings")]
	return ""


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
func _draw_rings(c: Vector2, word_d: Dictionary, ctx: RuneContext, col: Color) -> void:
	var sealed_n: int = int(screen.call("sealed_rings"))
	var mode: String = _mode()
	_ring_labels.clear()
	for k: int in range(1, _ring_r.size()):
		var r: float = _ring_r[k]
		var is_sealed: bool = k <= sealed_n
		# the ring this lock forms - and, for an old save bound before rings locked with each level, the
		# inner rings it must form first (design/14 section 11)
		var forming: bool = mode == "bind" and k > sealed_n and k <= ctx.forming
		var waits: int = (rules_ring().unformed_below(word_d, k) if rules_ring() != null else 0) if forming else 0
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
			label = ("ring %d  -  forming" % k) if waits == 0 else "ring %d  -  waits for ring %d" % [k, waits]
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
		# the ring's number where no place sits (between the places at the left), and its line top-left
		var tag_col: Color = UiTheme.STAR if forming else (UiTheme.GOLD if is_sealed else UiTheme.TEXT_FAINT)
		var tp: Vector2 = c + Vector2.from_angle(_tag_angle(k)) * r
		draw_circle(tp, 10.0, Color(0.02, 0.02, 0.04, 0.95))
		draw_arc(tp, 10.0, 0.0, TAU, 20, Color(tag_col, 0.8), 1.2, true)
		UiDraw.text(self, tp + Vector2(-10.0, 5.0), str(k), 12, tag_col, HORIZONTAL_ALIGNMENT_CENTER, 20.0, false)
		_ring_labels.append([label, tag_col])


## Where ring k's number sits: on its left, halfway between the two places nearest the left, so it
## never lies under a rune.
func _tag_angle(k: int) -> float:
	var angs: Array[float] = []
	for s: Dictionary in _slots:
		if int(s["ring"]) == k:
			angs.append(fposmod(float(s["angle"]), TAU))
	if angs.size() < 2:
		return PI
	angs.sort()
	var best: float = PI
	var best_d := INF
	for j: int in angs.size():
		var a0: float = angs[j]
		var a1: float = angs[(j + 1) % angs.size()] + (TAU if j == angs.size() - 1 else 0.0)
		var mid: float = (a0 + a1) * 0.5
		var d: float = absf(angle_difference(mid, PI))
		if d < best_d:
			best_d = d
			best = mid
	return best


## The empty places on the open rings. With a rune in hand (carried, or picked in the palette) the
## places that would take it glow and pulse; the others are marked with a red cross and, pointed at,
## say why. Otherwise small hollow sockets, brighter on the ring being formed and under the cursor.
func _draw_slots(ctx: RuneContext) -> void:
	var mode: String = _mode()
	var hand: String = _in_hand() if mode != "view" else ""
	for idx: int in _slots.size():
		var s: Dictionary = _slots[idx]
		if int(s["node"]) >= 0:
			continue
		var k: int = int(s["ring"])
		var p: Vector2 = s["pos"]
		var hov: bool = idx == _hover_slot
		if hand != "":
			var ok: bool = bool(_slot_check(hand, k)["ok"])
			if ok:
				var pul: float = 0.6 + 0.4 * sin(_time * 5.0 + float(idx))
				draw_circle(p, 17.0 + (4.0 if hov else 0.0), Color(UiTheme.GOLD, 0.10 + 0.08 * pul))
				draw_circle(p, 10.0, Color(0, 0, 0, 0.6))
				draw_arc(p, 11.0 + (2.0 if hov else 0.0), 0.0, TAU, 24, Color(UiTheme.GOLD.lightened(0.2), 0.7 + 0.3 * pul), 2.0 if hov else 1.6, true)
				draw_circle(p, 3.0, Color(UiTheme.GOLD.lightened(0.4), 0.9))
			else:
				draw_circle(p, 9.0, Color(0, 0, 0, 0.55))
				draw_arc(p, 9.0, 0.0, TAU, 20, Color(UiTheme.BAD, 0.55 if hov else 0.32), 1.3, true)
				var d := 3.5
				draw_line(p + Vector2(-d, -d), p + Vector2(d, d), Color(UiTheme.BAD, 0.6), 1.3, true)
				draw_line(p + Vector2(-d, d), p + Vector2(d, -d), Color(UiTheme.BAD, 0.6), 1.3, true)
			continue
		var hot: bool = mode == "bind" and k == ctx.forming and (rules_ring() == null or rules_ring().unformed_below(_word(), k) == 0)
		var a: float = 0.55 if hot else 0.25
		if mode == "view":
			a = 0.14
		if hov and mode != "view":
			a = 0.85
		draw_circle(p, 9.0, Color(0, 0, 0, 0.55))
		draw_arc(p, 9.0, 0.0, TAU, 20, Color(UiTheme.STAR, a), 1.3, true)
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


## While a bond is dragged: the rune it starts from, and whether rune i would take it - glowing in
## the colour of the bond it would make, or dimmed. Returns [state, colour]: "source", "ok", "no", "".
func _drag_state(word: Dictionary, i: int) -> Array:
	if not _dragging:
		return ["", Color.WHITE]
	if i == _press_node:
		return ["source", UiTheme.GOLD]
	var chk: Dictionary = _drag_checks.get(i, {})
	if not bool(chk.get("ok", false)):
		return ["no", UiTheme.BAD]
	var kind: String = (Runes.active() as RuneRules).call("bond_kind", RuneWord.node_id(word, _press_node), RuneWord.node_id(word, i)) if Runes.active().has_method("bond_kind") else "plain"
	return ["ok", LINK_COLOURS.get(kind, LINK_COLOURS["plain"])]


func _draw_core(c: Vector2, ab: Dictionary, col: Color, word: Dictionary, d: Dictionary, is_picked: bool) -> void:
	var ds: Array = _drag_state(word, 0)
	for g: int in 7:
		draw_circle(c, CORE_R * (2.9 - float(g) * 0.3), Color(col, 0.03 + float(g) * 0.013))
	if is_picked:
		draw_circle(c, CORE_R + 22.0, Color(UiTheme.GOLD, 0.14 + 0.08 * sin(_time * 5.0)))
		draw_arc(c, CORE_R + 19.0, 0.0, TAU, 64, Color(UiTheme.GOLD, 0.9), 2.5, true)
	if str(ds[0]) == "ok" or str(ds[0]) == "source":
		draw_circle(c, CORE_R + 20.0, Color(ds[1] as Color, 0.16 + 0.1 * sin(_time * 6.0)))
		draw_arc(c, CORE_R + 17.0, 0.0, TAU, 64, Color(ds[1] as Color, 0.9), 2.5, true)
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
	draw_arc(c, CORE_R + 1.5, 0.0, TAU, 64, UiTheme.GOLD if (is_picked or _hover == 0) else Color(col.lightened(0.3), 0.8), 2.0 if not _hover == 0 else 3.0, true)
	_draw_motes(c, CORE_R + 22.0, 0, d, col)
	if str(ds[0]) == "no":
		draw_circle(c, CORE_R + 3.0, Color(0, 0, 0, 0.55))
	var name_col: Color = UiTheme.GOLD
	UiDraw.outlined(self, c + Vector2(-90.0, CORE_R + 40.0), str(anchor.get("name", "")), 14, name_col, HORIZONTAL_ALIGNMENT_CENTER, 180.0)
	if str(ds[0]) == "no":
		UiDraw.outlined(self, c + Vector2(-90.0, CORE_R + 55.0), short_reason(_drag_checks.get(0, {})), 12, UiTheme.BAD.lightened(0.2), HORIZONTAL_ALIGNMENT_CENTER, 180.0)


## A rune as a seal: halo, body, glyph, a thin turning ring, its motes, its name and its strength.
## Selected: a gold ring round it. Under the cursor: brighter. While a bond is dragged: glowing in
## the colour of the bond it would take, or dimmed with the reason it would not.
func _draw_seal(word: Dictionary, i: int, d: Dictionary, is_picked: bool) -> void:
	var rid: String = RuneWord.node_id(word, i)
	var rune: Dictionary = GameData.rune(rid)
	var p: Vector2 = _pos[i]
	var aff: String = str(rune.get("affinity", ""))
	var col: Color = GameData.affinity_color(aff).lightened(0.15) if aff != "" else UiTheme.STAR
	var hot: bool = is_picked or _hover == i
	var ds: Array = _drag_state(word, i)
	for k: int in 5:
		draw_circle(p, SEAL_R + 24.0 - float(k) * 4.8, Color(col, 0.022 + float(k) * 0.016 + (0.02 if hot else 0.0)))
	if is_picked:
		draw_circle(p, SEAL_R + 16.0, Color(UiTheme.GOLD, 0.14 + 0.08 * sin(_time * 5.0)))
		draw_arc(p, SEAL_R + 11.0, 0.0, TAU, 40, Color(UiTheme.GOLD, 0.95), 2.4, true)
	if str(ds[0]) == "ok" or str(ds[0]) == "source":
		var pul: float = 0.6 + 0.4 * sin(_time * 6.0 + float(i))
		draw_circle(p, SEAL_R + 15.0 + (4.0 if _hover == i else 0.0), Color(ds[1] as Color, 0.14 + 0.1 * pul))
		draw_arc(p, SEAL_R + 9.0, 0.0, TAU, 40, Color((ds[1] as Color).lightened(0.2), 0.75 + 0.25 * pul), 2.2, true)
	draw_circle(p, SEAL_R + 2.0, Color(0, 0, 0, 0.88))
	draw_circle(p, SEAL_R, Color("130f18"))
	draw_circle(p, SEAL_R - 3.0, Color(col, 0.10 if _hover != i else 0.2))
	UiDraw.rune_glyph(self, p, rid, str(rune.get("character", "")), 22, col.lightened(0.45))
	var rot: float = _time * (0.55 if i % 2 == 0 else -0.45) + float(i)
	for j: int in 3:
		var a0: float = rot + TAU * float(j) / 3.0
		draw_arc(p, SEAL_R + 5.0, a0, a0 + 1.25, 14, UiTheme.GOLD if hot else Color(col.lightened(0.2), 0.75), 1.4, true)
	_draw_motes(p, SEAL_R + 11.0, i, d, col)
	if str(ds[0]) == "no":
		draw_circle(p, SEAL_R + 3.0, Color(0, 0, 0, 0.6))
	# its name and strength go on the side away from the skill, so they never cover a bond inward
	var below: bool = (p - _centre()).y >= -SEAL_R
	var y0: float = SEAL_R + 27.0 if below else -SEAL_R - 30.0
	var dy: float = 14.0 if below else -14.0
	UiDraw.outlined(self, p + Vector2(-70.0, y0), str(rune.get("name", rid)), 13, UiTheme.GOLD if is_picked else UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 140.0)
	if str(ds[0]) == "no":
		UiDraw.outlined(self, p + Vector2(-70.0, y0 + dy), short_reason(_drag_checks.get(i, {})), 12, UiTheme.BAD.lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER, 140.0)
		return
	if str(ds[0]) == "ok":
		UiDraw.outlined(self, p + Vector2(-70.0, y0 + dy), _kind_tag(word, _press_node, i), 12, (ds[1] as Color).lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER, 140.0)
		return
	if d.has("strength"):
		var sv: float = float(d["strength"])
		var st_text: String = ("x%.2f" % sv) if sv > 0.0 else "not joined"
		if float(d.get("converted", 0.0)) > 0.0:
			st_text = "x%.2f (+%.2f)" % [sv, float(d["converted"])]
		UiDraw.outlined(self, p + Vector2(-80.0, y0 + dy), st_text, 12, Color(UiTheme.GOLD, 0.85) if sv > 0.0 else UiTheme.TEXT_FAINT, HORIZONTAL_ALIGNMENT_CENTER, 160.0)
	var badges: Array = d.get("badges", [])
	if badges.has("over") or (hot and not badges.is_empty()):
		UiDraw.outlined(self, p + Vector2(-70.0, y0 + dy * 2.0), ", ".join(PackedStringArray(badges)), 12, UiTheme.BAD if badges.has("over") else UiTheme.TEXT_FAINT, HORIZONTAL_ALIGNMENT_CENTER, 140.0)


## The bond a drag from `a` would make with `b`, in two words: its kind and who would dominate.
func _kind_tag(word: Dictionary, a: int, b: int) -> String:
	var rules: RuneRules = Runes.active()
	if not rules.has_method("bond_kind"):
		return "bonds"
	var ra: String = RuneWord.node_id(word, a)
	var rb: String = RuneWord.node_id(word, b)
	var kind: String = str(rules.call("bond_kind", ra, rb))
	if kind == "even":
		return "even"
	var more: String = RuneRules.rune_name(word, a) if BondRules.electronegativity(ra) >= BondRules.electronegativity(rb) else RuneRules.rune_name(word, b)
	return "%s - %s %s" % [kind, more, "takes" if kind == "ionic" else "leads"]


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
## hand-over). An even bond stays symmetric and shimmers both ways. `emph` 1 = under the cursor
## (brighter, wider), 2 = selected (a gold sheath under it).
func _draw_bond(d: Dictionary, a: int, b: int, emph: int = 0) -> void:
	if a >= _pos.size() or b >= _pos.size():
		return
	var col: Color = LINK_COLOURS.get(str(d.get("colour", "plain")), UiTheme.TEXT_DIM)
	var flags: Array = d.get("flags", [])
	var strength: float = clampf(float(d.get("strength", 0.5)), 0.0, 1.5)
	var width: float = (1.9 + 2.6 * strength / 1.5) * (1.3 if emph >= 1 else 1.0)
	var flow: int = int(d.get("flow", 0))
	var kind: String = str(d.get("kind", ""))
	# points run from the weaker end to the dominant end
	var pts: PackedVector2Array = _bond_points(b, a) if flow < 0 else _bond_points(a, b)
	if pts.size() < 2:
		return
	if emph == 2:
		# selected: a gold glow under it and two gold rails along it, plainly set apart from the rest
		var pul: float = 0.7 + 0.3 * sin(_time * 5.0)
		draw_polyline(pts, Color(UiTheme.GOLD, 0.16 * pul), width * 7.0 + 14.0, true)
		var off: float = width * 1.6 + 7.0
		for sgn: float in [-1.0, 1.0]:
			var rail := PackedVector2Array()
			for q: int in pts.size():
				var t0: Vector2 = pts[maxi(0, q - 1)]
				var t1: Vector2 = pts[mini(pts.size() - 1, q + 1)]
				var along: Vector2 = (t1 - t0).normalized()
				rail.append(pts[q] + Vector2(-along.y, along.x) * off * sgn)
			draw_polyline(rail, Color(UiTheme.GOLD.lightened(0.3), pul), 2.6, true)
	elif emph == 1:
		draw_polyline(pts, Color(col.lightened(0.5), 0.18), width * 6.0 + 6.0, true)
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
		var ak: float = lerpf(a_ends.x, a_ends.y, t) * fl * (1.25 if emph >= 1 else 1.0)
		var dashed_gap: bool = flags.has("weakened") and s % 2 == 1
		draw_line(pts[s], pts[s + 1], Color(col, 0.10 * ak), width * 6.5 * wk, true)
		draw_line(pts[s], pts[s + 1], Color(col, 0.30 * ak), width * 2.4 * wk, true)
		if not dashed_gap:
			draw_line(pts[s], pts[s + 1], Color(col.lightened(0.35), minf(1.0, 0.95 * ak)), width * wk, true)
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


## The rune carried from the palette, following the cursor: its glyph in a glowing socket.
func _draw_carried(rid: String, at: Vector2) -> void:
	var rune: Dictionary = GameData.rune(rid)
	var aff: String = str(rune.get("affinity", ""))
	var tint: Color = GameData.affinity_color(aff).lightened(0.3) if aff != "" else UiTheme.STAR
	draw_circle(at, 30.0, Color(tint, 0.12))
	draw_circle(at, SEAL_R - 1.0, Color(0.05, 0.04, 0.07, 0.92))
	draw_arc(at, SEAL_R - 1.0, 0.0, TAU, 32, Color(UiTheme.GOLD, 0.9), 1.6, true)
	UiDraw.rune_glyph(self, at, rid, str(rune.get("character", "")), 22, tint.lightened(0.2))


## The bond being dragged: over a rune that would take it, the bond itself as it would be drawn, with
## its kind and dominant side in words at its middle; over one that would not, a broken red line;
## elsewhere a pale line of light following the cursor.
func _draw_drag(word: Dictionary, rules: RuneRules, ctx: RuneContext) -> void:
	var src: int = _press_node
	if src < 0 or src >= _pos.size():
		return
	var from: Vector2 = _pos[src]
	var tgt: int = _hover if _hover != src else -1
	if tgt >= 0 and bool((_drag_checks.get(tgt, {}) as Dictionary).get("ok", false)):
		var tmp: Dictionary = word.duplicate(true)
		RuneWord.add_link(tmp, src, tgt)
		var d: Dictionary = rules.describe_link(tmp, src, tgt, ctx)
		_draw_bond(d, mini(src, tgt), maxi(src, tgt), 1)
		var pts: PackedVector2Array = _bond_points(mini(src, tgt), maxi(src, tgt))
		if pts.size() >= 2:
			var mid: Vector2 = _sample(pts, 0.5)
			var txt: String = str(d.get("label", ""))
			var w: float = UiDraw.text_width(txt, 14) + 18.0
			var box := Rect2(mid + Vector2(-w * 0.5, -40.0), Vector2(w, 24.0))
			box.position = box.position.clamp(Vector2(4, 4), size - box.size - Vector2(4, 4))
			var kc: Color = LINK_COLOURS.get(str(d.get("colour", "plain")), UiTheme.TEXT_DIM)
			draw_rect(box, Color(0.03, 0.025, 0.05, 0.9))
			draw_rect(box, Color(kc, 0.8), false, 1.2)
			UiDraw.text(self, box.position + Vector2(9.0, 17.0), txt, 14, kc.lightened(0.35))
		return
	var to: Vector2 = _mouse
	var bad: bool = tgt >= 0
	var col: Color = UiTheme.BAD if bad else UiTheme.STAR.lightened(0.3)
	var len: float = from.distance_to(to)
	var dir: Vector2 = (to - from).normalized() if len > 0.01 else Vector2.RIGHT
	var start: Vector2 = from + dir * ((CORE_R if src == 0 else SEAL_R) + 4.0)
	var segs: int = maxi(1, int(len / 9.0))
	for s: int in segs:
		if s % 2 == 1 and bad:
			continue
		var u0: float = float(s) / float(segs)
		var u1: float = float(s + 1) / float(segs)
		var aa: float = (0.35 + 0.5 * u1) if not bad else 0.8
		draw_line(start.lerp(to, u0), start.lerp(to, u1), Color(col, 0.18 * aa), 9.0, true)
		draw_line(start.lerp(to, u0), start.lerp(to, u1), Color(col.lightened(0.3), aa), 2.2, true)
	for m: int in 5:
		var u: float = fmod(_time * 0.9 + float(m) / 5.0, 1.0)
		draw_circle(start.lerp(to, u), 2.2, Color(col.lightened(0.5), 0.9 * sin(PI * u)))
	draw_circle(to, 6.0, Color(col, 0.35))
	draw_arc(to, 9.0, 0.0, TAU, 20, Color(col.lightened(0.3), 0.9), 1.5, true)


## The selected bond's delete button: a small x in a ring beside its middle.
func _draw_cross() -> void:
	var at: Vector2 = _cross_at()
	if at.x < -9999.0:
		return
	var hot: bool = _hover_cross
	draw_circle(at, CROSS_R + 3.0, Color(0, 0, 0, 0.7))
	draw_circle(at, CROSS_R, Color(UiTheme.BAD.darkened(0.4) if hot else Color("2a1714"), 0.95))
	draw_arc(at, CROSS_R, 0.0, TAU, 24, UiTheme.BAD.lightened(0.3) if hot else Color(UiTheme.BAD, 0.85), 1.6, true)
	var d := 4.2
	draw_line(at + Vector2(-d, -d), at + Vector2(d, d), UiTheme.TEXT, 2.0, true)
	draw_line(at + Vector2(-d, d), at + Vector2(d, -d), UiTheme.TEXT, 2.0, true)


## A small box of words near the cursor: why a place or a bond is refused (where the cursor is), or
## what letting go would do.
func _draw_tip(word: Dictionary) -> void:
	var text := ""
	var col: Color = UiTheme.TEXT
	if _dragging:
		var tgt: int = _hover if _hover != _press_node else -1
		if tgt >= 0 and not bool((_drag_checks.get(tgt, {}) as Dictionary).get("ok", false)):
			text = str((_drag_checks.get(tgt, {}) as Dictionary).get("text", ""))
			col = UiTheme.BAD.lightened(0.3)
	elif _hover_cross:
		var sel: Vector2i = screen.get("picked_bond")
		text = "Delete the bond %s - %s" % [RuneRules.rune_name(word, sel.x), RuneRules.rune_name(word, sel.y)]
		col = UiTheme.BAD.lightened(0.3)
	elif _hover_slot >= 0 and _in_hand() != "" and _mode() != "view":
		var k: int = int(_slots[_hover_slot]["ring"])
		var chk: Dictionary = _slot_check(_in_hand(), k)
		if bool(chk["ok"]):
			text = "Set %s here, on ring %d" % [str(GameData.rune(_in_hand()).get("name", "")), k]
			col = UiTheme.GOLD.lightened(0.3)
		else:
			text = str(chk.get("text", ""))
			col = UiTheme.BAD.lightened(0.3)
	if text == "":
		return
	var w: float = minf(UiDraw.text_width(text, 13) + 18.0, size.x - 16.0)
	var box := Rect2(_mouse + Vector2(16.0, 18.0), Vector2(w, 24.0))
	if box.end.x > size.x - 4.0:
		box.position.x = _mouse.x - w - 12.0
	if box.end.y > size.y - 4.0:
		box.position.y = _mouse.y - 40.0
	box.position = box.position.clamp(Vector2(4, 4), size - box.size - Vector2(4, 4))
	draw_rect(box, Color(0.03, 0.025, 0.05, 0.92))
	draw_rect(box, Color(col, 0.6), false, 1.0)
	UiDraw.text(self, box.position + Vector2(9.0, 17.0), text, 13, col, HORIZONTAL_ALIGNMENT_LEFT, w - 14.0)


## The selected (or hovered) rune's bonds in words, or the selected (or hovered) bond's kind,
## dominance, transmission and what it carries - a small panel in the top-right corner.
func _draw_callout(word: Dictionary, rules: RuneRules, ctx: RuneContext) -> void:
	var picked: int = int(screen.get("picked"))
	var sel: Vector2i = screen.get("picked_bond")
	var bond: Vector2i = sel if sel.x >= 0 else (_hover_bond if picked < 0 and _hover < 0 else Vector2i(-1, -1))
	var lines: Array = []
	var title := ""
	if bond.x >= 0 and RuneWord.linked(word, bond.x, bond.y):
		var d: Dictionary = rules.describe_link(word, bond.x, bond.y, ctx)
		var kc: Color = LINK_COLOURS.get(str(d.get("colour", "plain")), UiTheme.TEXT_DIM)
		title = "Bond  %s - %s" % [RuneRules.rune_name(word, bond.x), RuneRules.rune_name(word, bond.y)]
		lines.append([str(d.get("label", "")), kc])
		if d.has("transmission"):
			lines.append(["passes x%.2f inward (read from %s's side)" % [float(d["transmission"]), RuneRules.rune_name(word, int(d.get("outer", bond.y)))], UiTheme.TEXT_DIM])
		var carries: Array = d.get("carries", [])
		if not carries.is_empty():
			lines.append(["carries " + ", ".join(PackedStringArray(carries.map(func(c: Dictionary) -> String: return "%s x%.2f" % [str(c["name"]), float(c["strength"])]))), UiTheme.TEXT_DIM])
		for h: Variant in d.get("hand_over", []):
			lines.append([str(h), LINK_COLOURS["ionic"].lightened(0.25)])
	else:
		var focus: int = picked if picked >= 0 else _hover
		if focus < 0 or focus >= RuneWord.size(word):
			return
		for k: int in RuneWord.neighbours(word, focus):
			var dl: Dictionary = rules.describe_link(word, focus, k, ctx)
			var flags: Array = dl.get("flags", [])
			var t: String = str(dl.get("label", ""))
			if not flags.is_empty():
				t += "  (%s)" % ", ".join(PackedStringArray(flags.map(func(v: Variant) -> String: return str(v))))
			lines.append([t, LINK_COLOURS.get(str(dl.get("colour", "plain")), UiTheme.TEXT_DIM)])
		title = RuneRules.rune_name(word, focus) + ("  -  no bonds yet" if lines.is_empty() else "")
	var w: float = UiDraw.text_width(title, 14, true)
	for l: Array in lines:
		w = maxf(w, UiDraw.text_width(str(l[0]), 13) + 22.0)
	w = minf(w, size.x * 0.48)
	var box := Rect2(size.x - w - 34.0, 16.0, w + 20.0, 34.0 + 18.0 * float(lines.size()))
	draw_rect(box, Color(0.03, 0.025, 0.05, 0.86))
	draw_rect(box, Color(UiTheme.GOLD, 0.35), false, 1.0)
	UiDraw.text(self, box.position + Vector2(10.0, 20.0), title, 14, UiTheme.GOLD)
	var y: float = box.position.y + 40.0
	for l: Array in lines:
		var col: Color = l[1]
		draw_line(box.position + Vector2(10.0, y - 5.0), box.position + Vector2(22.0, y - 5.0), col.lightened(0.3), 2.5, true)
		UiDraw.text(self, box.position + Vector2(28.0, y), str(l[0]), 13, col.lightened(0.4), HORIZONTAL_ALIGNMENT_LEFT, w - 10.0, false)
		y += 18.0


## The curve a bond is drawn along, from a to b. Two runes on the same ring that are neighbours there
## bond along the ring, the shorter way; two that are not bond across it (a chord bowed toward the
## skill), so the bond never runs through the rune between them. Others bow away from the skill.
func _bond_points(a: int, b: int) -> PackedVector2Array:
	var pa: Vector2 = _pos[a]
	var pb: Vector2 = _pos[b]
	var c: Vector2 = _centre()
	var ra: float = (CORE_R if a == 0 else SEAL_R) + 4.0
	var rb: float = (CORE_R if b == 0 else SEAL_R) + 4.0
	var out := PackedVector2Array()
	var word: Dictionary = _word()
	var ka: int = RuneWord.ring(word, a)
	var mid: Vector2 = (pa + pb) * 0.5
	var nrm := Vector2(-(pb - pa).y, (pb - pa).x).normalized()
	if (mid + nrm * 10.0 - c).length() < (mid - c).length():
		nrm = -nrm
	var ctrl: Vector2 = mid + nrm * pa.distance_to(pb) * 0.16
	if ka >= 1 and ka == RuneWord.ring(word, b) and _lock_t < 0.0:
		var r: float = (pa - c).length()
		var a0: float = (pa - c).angle()
		var span: float = angle_difference(a0, (pb - c).angle())
		var between := false
		for o: int in RuneWord.ring_nodes(word, ka):
			if o == a or o == b or o >= _pos.size():
				continue
			var off: float = angle_difference(a0, (_pos[o] - c).angle())
			if signf(off) == signf(span) and absf(off) < absf(span):
				between = true
		if not between:
			for s2: int in 41:
				var q2: Vector2 = c + Vector2.from_angle(a0 + span * float(s2) / 40.0) * r
				if q2.distance_to(pa) >= ra and q2.distance_to(pb) >= rb:
					out.append(q2)
			return out
		ctrl = mid + (c - mid) * 0.35          # across the ring, bowed toward the skill
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
	if pts.size() == 1:
		return pts[0]
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
## (it stays clickable, so the screen can say why). Click it to pick it up (then click a place on the
## board), or drag it onto a place. The rune in hand wears a gold frame.
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
		pressed.connect(func() -> void:
			if not _carried:
				screen.call("arm_rune", rune_id))

	var _press_at := Vector2(-1, -1)
	var _carrying := false
	var _carried := false            # this press became a carry: its release is not a click

	## Press, move past a few pixels with the button held, and the rune is carried to the board (which
	## draws it at the cursor and takes the drop); a press let go without moving is a click.
	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press_at = mb.position
				_carried = false
			else:
				if _carrying:
					screen.call("carry_end", rune_id, get_global_transform() * mb.position)
				_carrying = false
				_press_at = Vector2(-1, -1)
			return
		var mm := event as InputEventMouseMotion
		if mm == null or _press_at.x < 0.0 or (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			return
		if not _carrying and mm.position.distance_to(_press_at) > 8.0:
			var st: Dictionary = screen.call("chip_state", rune_id)
			if str(screen.call("seal_view")) == "view" or not bool(st.get("known", true)):
				return
			_carrying = true
			_carried = true
		if _carrying:
			screen.call("carry_move", rune_id, get_global_transform() * mm.position)

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
		if str(screen.get("armed_rune")) == rune_id:
			draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), Color(UiTheme.GOLD, 0.16))
			draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), UiTheme.GOLD, false, 2.0)
		draw_circle(Vector2(size.x * 0.5, 22.0), 15.0, Color(tint, 0.08))
		UiDraw.rune_glyph(self, Vector2(size.x * 0.5, 22.0), rune_id, str(rune.get("character", "")), 21, tint)
		UiDraw.text(self, Vector2(0.0, size.y - 8.0), str(rune.get("name", rune_id)), 12, UiTheme.TEXT if live else UiTheme.TEXT_FAINT, HORIZONTAL_ALIGNMENT_CENTER, size.x, false)
		var sockets: int = int(st.get("sockets", -1))
		for k: int in maxi(0, sockets):
			draw_circle(Vector2(size.x - 7.0, 7.0 + float(k) * 7.0), 2.2, UiTheme.GOLD.darkened(0.15 if live else 0.6))


