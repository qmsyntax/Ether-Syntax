class_name UiDraw
extends RefCounted

const STAR_TINT := Color("cdbcf2")
## Procedural drawing helpers for the HUD: liquid orbs, gauges, bars and small glyph icons.
## Every function draws onto the CanvasItem passed in, from inside its _draw().


static var _glyph_ok: Dictionary = {}


## The ethercosm's void: near-black, a bronze edge, faint dust fixed per position (so it does not
## swim) and soft rings round `c`.
static func void_field(ci: CanvasItem, size: Vector2, c: Vector2, time: float) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, size), Color("070608"))
	ci.draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BRONZE_DIM, false, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9173
	for i: int in 110:
		var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
		var tw: float = 0.25 + 0.2 * sin(time * (0.5 + rng.randf()) + rng.randf() * TAU)
		ci.draw_circle(p, 0.6 + rng.randf() * 1.1, Color(0.8, 0.8, 1.0, tw * 0.5))
	for k: int in 5:
		ci.draw_circle(c, 240.0 - k * 40.0, Color(0.25, 0.28, 0.5, 0.025))


## One original procedural rune mark: a few strokes between points of a 3x3 grid of `cell`,
## rotated by `angle`. The strokes come from `rng`, so a fixed seed always draws the same mark.
static func rune_strokes(ci: CanvasItem, at: Vector2, angle: float, rng: RandomNumberGenerator, col: Color, lit: bool, cell: float = 3.6) -> void:
	ci.draw_set_transform(at, angle, Vector2.ONE)
	var last := Vector2i(rng.randi_range(0, 2), rng.randi_range(0, 2))
	for k: int in rng.randi_range(2, 4):
		var nxt := Vector2i(rng.randi_range(0, 2), rng.randi_range(0, 2))
		if nxt == last:
			nxt = Vector2i((last.x + 1) % 3, (last.y + 2) % 3)
		ci.draw_line(Vector2(last.x - 1, last.y - 1) * cell, Vector2(nxt.x - 1, nxt.y - 1) * cell, col, (1.6 if lit else 1.0) * cell / 3.6, true)
		last = nxt
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Whether the interface font (with the system's fallback fonts) can draw `ch` as a plain glyph.
## Checked by shaping it: a character no font can draw comes back with no font. A character only
## a colour emoji font has counts as missing too - it would ignore the tint and break the look.
## Cached.
static func has_glyph(ch: String) -> bool:
	if ch == "":
		return false
	if _glyph_ok.has(ch):
		return bool(_glyph_ok[ch])
	var ts: TextServer = TextServerManager.get_primary_interface()
	var line := TextLine.new()
	line.add_string(ch, UiTheme.font(), 24)
	var ok := true
	for g: Dictionary in ts.shaped_text_get_glyphs(line.get_rid()):
		var rid: RID = g.get("font_rid", RID())
		if not rid.is_valid() or int(g.get("index", 0)) == 0 or ts.font_get_name(rid).to_lower().contains("emoji"):
			ok = false
	_glyph_ok[ch] = ok
	return ok


## A rune drawn centred on `c`: its Unicode character from the data, or - when no font can draw
## it - the procedural mark seeded by its id.
static func rune_glyph(ci: CanvasItem, c: Vector2, rune_id: String, ch: String, size: int, col: Color) -> void:
	if has_glyph(ch):
		var f: Font = UiTheme.font()
		var w: float = f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var asc: float = f.get_ascent(size)
		var h: float = asc + f.get_descent(size)
		ci.draw_string(f, Vector2(c.x - w * 0.5, c.y - h * 0.5 + asc), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(rune_id)
		rune_strokes(ci, c, 0.0, rng, col, true, float(size) * 0.22)


## Points of the part of a circle that lies below the horizontal line at `level_y` (screen y is
## down), with a gently waving top edge. Used as the liquid in an orb.
static func liquid_points(c: Vector2, r: float, level_y: float, time: float, wave: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var s: float = clampf((level_y - c.y) / r, -1.0, 1.0)
	var t0: float = asin(s)
	var t1: float = PI - t0
	var steps := 40
	for i: int in steps + 1:
		var t: float = lerpf(t0, t1, float(i) / float(steps))
		pts.append(c + Vector2(cos(t), sin(t)) * r)
	# back along the surface, right-to-left, with a ripple (none when full or empty)
	var half: float = sqrt(maxf(0.0, r * r - (level_y - c.y) * (level_y - c.y)))
	if half > 2.0 and wave > 0.0:
		var n := 14
		for i: int in range(1, n):
			var u: float = float(i) / float(n)
			var x: float = lerpf(c.x - half, c.x + half, u)
			var y: float = level_y + sin(u * TAU * 1.5 + time * 2.2) * wave * sin(u * PI)
			pts.append(Vector2(x, y))
	return pts


## A glass orb filled with stacked liquid bands. `bands` is bottom-first: [[fraction, Color], ...]
## where fractions are of the orb's height and add up to at most 1.
static func orb(ci: CanvasItem, c: Vector2, r: float, bands: Array, time: float, rim: Color) -> void:
	ci.draw_circle(c, r + 5.0, Color(0, 0, 0, 0.55))
	ci.draw_circle(c, r, UiTheme.INSET)
	var total := 0.0
	for b: Array in bands:
		total += float(b[0])
	total = clampf(total, 0.0, 1.0)
	# paint from the top band down so each lower band overdraws the one above it
	var top: float = total
	for i: int in range(bands.size() - 1, -1, -1):
		var frac: float = float(bands[i][0])
		if frac <= 0.0005:
			continue
		var level_y: float = c.y + r - 2.0 * r * top
		var is_surface: bool = is_equal_approx(top, total)
		var pts: PackedVector2Array = liquid_points(c, r - 1.0, level_y, time, 2.2 if is_surface and total < 0.995 else 0.0)
		if pts.size() >= 3:
			ci.draw_colored_polygon(pts, bands[i][1])
		top -= frac
	if total > 0.01 and total < 0.995:
		var sy: float = c.y + r - 2.0 * r * total
		var half: float = sqrt(maxf(0.0, r * r - (sy - c.y) * (sy - c.y)))
		ci.draw_line(Vector2(c.x - half + 2, sy), Vector2(c.x + half - 2, sy), Color(1, 1, 1, 0.16), 1.5, true)
	# glass: inner shade, highlight, rim
	ci.draw_arc(c, r - 3.0, 0.15 * PI, 0.85 * PI, 28, Color(0, 0, 0, 0.35), 5.0, true)
	ci.draw_arc(c, r - 7.0, 1.13 * PI, 1.42 * PI, 18, Color(1, 1, 1, 0.20), 3.0, true)
	ci.draw_arc(c, r - 13.0, 1.17 * PI, 1.31 * PI, 12, Color(1, 1, 1, 0.09), 2.0, true)
	ci.draw_arc(c, r + 1.0, 0, TAU, 64, rim.darkened(0.45), 5.0, true)
	ci.draw_arc(c, r + 1.0, 0, TAU, 64, rim, 2.0, true)
	ci.draw_arc(c, r + 3.5, 1.1 * PI, 1.9 * PI, 32, rim.lightened(0.35), 1.0, true)


## A ring gauge around an orb: fills clockwise from the top. Tick marks at the given fractions.
static func ring(ci: CanvasItem, c: Vector2, r: float, frac: float, color: Color, ticks: Array = []) -> void:
	ci.draw_arc(c, r, 0, TAU, 72, Color(0, 0, 0, 0.6), 7.0, true)
	ci.draw_arc(c, r, 0, TAU, 72, Color(0.2, 0.17, 0.14), 4.0, true)
	if frac > 0.002:
		ci.draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU * clampf(frac, 0.0, 1.0), 72, color, 4.0, true)
	for t: float in ticks:
		var a: float = -PI / 2.0 + TAU * t
		var d := Vector2(cos(a), sin(a))
		ci.draw_line(c + d * (r - 5.0), c + d * (r + 5.0), UiTheme.TEXT_DIM, 1.5, true)


## A framed horizontal bar.
static func bar(ci: CanvasItem, rect: Rect2, frac: float, color: Color, back: Color = UiTheme.INSET) -> void:
	ci.draw_rect(rect.grow(1.0), Color(0, 0, 0, 0.75))
	ci.draw_rect(rect, back)
	if frac > 0.0:
		var f := Rect2(rect.position, Vector2(rect.size.x * clampf(frac, 0.0, 1.0), rect.size.y))
		ci.draw_rect(f, color)
		ci.draw_rect(Rect2(f.position, Vector2(f.size.x, maxf(1.0, f.size.y * 0.35))), Color(1, 1, 1, 0.14))
		ci.draw_rect(Rect2(f.position.x, f.end.y - maxf(1.0, f.size.y * 0.2), f.size.x, maxf(1.0, f.size.y * 0.2)), Color(0, 0, 0, 0.18))
	ci.draw_rect(rect.grow(1.0), UiTheme.BRONZE_DIM, false, 1.0)


static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, shadow: bool = true) -> void:
	var f: Font = UiTheme.font()
	if shadow:
		ci.draw_string(f, pos + Vector2(1, 1), s, align, width, size, Color(0, 0, 0, 0.85))
	ci.draw_string(f, pos, s, align, width, size, color)


## Text with a dark outline all round: readable over any ground, any fill. Everything the HUD
## draws straight onto the world uses this, not the shadowed text above.
static func outlined(ci: CanvasItem, pos: Vector2, s: String, size: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, bold: bool = false) -> void:
	var f: Font = UiTheme.font(bold)
	var o: int = maxi(3, int(round(float(size) * 0.28)))
	ci.draw_string_outline(f, pos, s, align, width, size, o, Color(UiTheme.OUTLINE, UiTheme.OUTLINE.a * color.a))
	ci.draw_string(f, pos, s, align, width, size, color)


static func text_width(s: String, size: int, bold: bool = false) -> float:
	return UiTheme.font(bold).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## A key as a small chip: [W]. `at` is the chip's left edge on the text's baseline. Returns its width.
static func keycap(ci: CanvasItem, at: Vector2, key: String, size: int, alpha: float = 1.0) -> float:
	var w: float = maxf(float(size) + 6.0, text_width(key, size - 1) + 10.0)
	var r := Rect2(at.x, at.y - float(size) + 1.0, w, float(size) + 6.0)
	ci.draw_rect(r.grow(1.0), Color(0, 0, 0, 0.7 * alpha))
	ci.draw_rect(r, Color(UiTheme.PANEL_HI, 0.95 * alpha))
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 1.0)), Color(1, 0.95, 0.8, 0.12 * alpha))
	ci.draw_rect(r, Color(UiTheme.BRONZE, alpha), false, 1.0)
	ci.draw_string(UiTheme.font(), Vector2(r.position.x, at.y), key, HORIZONTAL_ALIGNMENT_CENTER, w, size - 1, Color(UiTheme.TEXT, alpha))
	return w


## Width of a line drawn by `rich` (key names in square brackets become keycaps).
static func rich_width(s: String, size: int) -> float:
	var w := 0.0
	for part: Array in _rich_parts(s):
		if bool(part[1]):
			w += maxf(float(size) + 6.0, text_width(str(part[0]), size - 1) + 10.0) + 2.0
		else:
			w += text_width(str(part[0]), size)
	return w


## One line of text where "[Key]" is drawn as a keycap. Centred in `width` when `width` > 0.
static func rich(ci: CanvasItem, pos: Vector2, s: String, size: int, color: Color, width: float = -1.0, outline: bool = true) -> void:
	var x: float = pos.x
	if width > 0.0:
		x += (width - rich_width(s, size)) * 0.5
	for part: Array in _rich_parts(s):
		if bool(part[1]):
			x += keycap(ci, Vector2(x + 1.0, pos.y), str(part[0]), size, color.a) + 2.0
		else:
			if outline:
				outlined(ci, Vector2(x, pos.y), str(part[0]), size, color)
			else:
				ci.draw_string(UiTheme.font(), Vector2(x, pos.y), str(part[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
			x += text_width(str(part[0]), size)


## [[text, is_key], ...]: a bracketed run of up to 12 characters is a key name.
static func _rich_parts(s: String) -> Array:
	var out: Array = []
	var i := 0
	while i < s.length():
		var open: int = s.find("[", i)
		var close: int = s.find("]", open) if open >= 0 else -1
		if open < 0 or close < 0 or close - open > 13:
			out.append([s.substr(i), false])
			break
		if open > i:
			out.append([s.substr(i, open - i), false])
		out.append([s.substr(open + 1, close - open - 1), true])
		i = close + 1
	return out


## A nine-patch frame (UiTheme.FRAMES) drawn into `rect`, tinted by `modulate`.
static func frame(ci: CanvasItem, rect: Rect2, kind: String = "panel", modulate: Color = Color(1, 1, 1)) -> void:
	var sb: StyleBox = UiTheme.frame(kind)
	if sb is StyleBoxTexture and modulate != Color(1, 1, 1):
		sb = sb.duplicate()
		(sb as StyleBoxTexture).modulate_color = modulate
	ci.draw_style_box(sb, rect)


## A dark wedge over `rect` for the part of a wait still to come (1 = all of it), sweeping
## clockwise from the top as it runs out, the way a cooldown is shown.
static func sweep(ci: CanvasItem, rect: Rect2, left: float, color: Color = Color(0, 0, 0, 0.62)) -> void:
	if left <= 0.0:
		return
	var c: Vector2 = rect.get_center()
	var r: float = rect.size.length() * 0.5
	var pts := PackedVector2Array([c])
	var start: float = -PI / 2.0 + TAU * (1.0 - clampf(left, 0.0, 1.0))
	var steps := 24
	for i: int in steps + 1:
		var a: float = lerpf(start, 1.5 * PI, float(i) / float(steps))
		var p: Vector2 = c + Vector2(cos(a), sin(a)) * r
		pts.append(Vector2(clampf(p.x, rect.position.x, rect.end.x), clampf(p.y, rect.position.y, rect.end.y)))
	ci.draw_colored_polygon(pts, color)


## Small procedural glyphs so abilities and items read at a glance without art assets.
static func icon(ci: CanvasItem, kind: String, c: Vector2, s: float, color: Color) -> void:
	match kind:
		"drop":      # water bolt: a droplet with a trail
			var pts := PackedVector2Array()
			for i: int in 21:
				var t: float = PI * float(i) / 20.0
				pts.append(c + Vector2(cos(t) * s * 0.42, s * 0.18 + sin(t) * s * 0.42))
			pts.append(c + Vector2(0, -s * 0.62))
			ci.draw_colored_polygon(pts, color)
			ci.draw_circle(c + Vector2(-s * 0.14, s * 0.22), s * 0.1, Color(1, 1, 1, 0.35))
		"wave":      # tsunami strike: stacked crests
			for k: int in 3:
				var y: float = c.y - s * 0.13 + k * s * 0.3
				var prev := Vector2(c.x - s * 0.6, y)
				for i: int in range(1, 17):
					var u: float = float(i) / 16.0
					var p := Vector2(c.x - s * 0.6 + u * s * 1.2, y - sin(u * PI) * s * (0.34 - k * 0.07) * (1.0 if i < 11 else 0.5))
					ci.draw_line(prev, p, color.lightened(0.15 * (2 - k)), 3.0, true)
					prev = p
		"ember":     # cinder spit: a flame
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.04, -s * 0.58), c + Vector2(s * 0.28, -s * 0.12), c + Vector2(s * 0.38, s * 0.2), c + Vector2(s * 0.24, s * 0.46),
				c + Vector2(0, s * 0.54), c + Vector2(-s * 0.24, s * 0.46), c + Vector2(-s * 0.38, s * 0.2), c + Vector2(-s * 0.24, -s * 0.1)]), color)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.02, -s * 0.08), c + Vector2(s * 0.16, s * 0.22), c + Vector2(0, s * 0.44), c + Vector2(-s * 0.16, s * 0.22)]), color.lightened(0.5))
		"fist":      # kiln fist: knuckles, with heat coming off them
			ci.draw_rect(Rect2(c + Vector2(-s * 0.36, -s * 0.14), Vector2(s * 0.72, s * 0.56)), color)
			for k: int in 4:
				ci.draw_circle(c + Vector2(-s * 0.27 + k * s * 0.18, -s * 0.16), s * 0.1, color)
			for k: int in 3:
				ci.draw_line(c + Vector2(-s * 0.18 + k * s * 0.18, -s * 0.12), c + Vector2(-s * 0.18 + k * s * 0.18, s * 0.14), color.darkened(0.45), 1.5, true)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.46, s * 0.08), Vector2(s * 0.22, s * 0.3)), color.darkened(0.25))
			for k: int in 3:
				ci.draw_line(c + Vector2(-s * 0.24 + k * s * 0.24, -s * 0.38), c + Vector2(-s * 0.18 + k * s * 0.24, -s * 0.58), color.lightened(0.45), 2.0, true)
		"flame_trail":   # flashover: a line of fire along the ground
			ci.draw_line(c + Vector2(-s * 0.6, s * 0.42), c + Vector2(s * 0.6, s * 0.42), color.darkened(0.35), 3.0, true)
			for k: int in 3:
				var fx: float = -s * 0.4 + k * s * 0.4
				var fh: float = s * (0.42 + 0.2 * k)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(fx - s * 0.16, s * 0.4), c + Vector2(fx + s * 0.16, s * 0.4), c + Vector2(fx + s * 0.06, s * 0.4 - fh)]), color.lightened(0.12 * k))
		"stone":     # slingstone: a rock in flight
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.5, -s * 0.04), c + Vector2(s * 0.38, s * 0.28), c + Vector2(s * 0.06, s * 0.38), c + Vector2(-s * 0.18, s * 0.2),
				c + Vector2(-s * 0.2, -s * 0.16), c + Vector2(s * 0.04, -s * 0.36), c + Vector2(s * 0.34, -s * 0.3)]), color)
			ci.draw_polyline(PackedVector2Array([c + Vector2(s * 0.04, -s * 0.36), c + Vector2(s * 0.14, -s * 0.04), c + Vector2(s * 0.5, -s * 0.04)]), color.darkened(0.4), 1.5, true)
			for k: int in 3:
				ci.draw_line(c + Vector2(-s * 0.62 + k * s * 0.06, -s * 0.2 + k * s * 0.2), c + Vector2(-s * 0.32, -s * 0.2 + k * s * 0.2), color.darkened(0.2), 2.5, true)
		"landslide": # landslide blow: a great weight coming down on the ground
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.34, -s * 0.52), c + Vector2(s * 0.34, -s * 0.52), c + Vector2(s * 0.34, -s * 0.06), c + Vector2(0, s * 0.32), c + Vector2(-s * 0.34, -s * 0.06)]), color)
			ci.draw_line(c + Vector2(-s * 0.6, s * 0.42), c + Vector2(s * 0.6, s * 0.42), color.darkened(0.3), 4.0, true)
			ci.draw_line(c + Vector2(0, s * 0.32), c + Vector2(-s * 0.2, s * 0.56), color.darkened(0.5), 2.0, true)
			ci.draw_line(c + Vector2(0, s * 0.32), c + Vector2(s * 0.24, s * 0.54), color.darkened(0.5), 2.0, true)
			ci.draw_circle(c + Vector2(-s * 0.5, s * 0.2), s * 0.07, color.lightened(0.2))
			ci.draw_circle(c + Vector2(s * 0.52, s * 0.14), s * 0.06, color.lightened(0.2))
		"shoulder":  # bedrock shove: driving into something solid
			ci.draw_rect(Rect2(c + Vector2(s * 0.14, -s * 0.44), Vector2(s * 0.36, s * 0.88)), color.darkened(0.2))
			for k: int in 2:
				var sx: float = c.x - s * 0.5 + k * s * 0.28
				ci.draw_polyline(PackedVector2Array([Vector2(sx, c.y - s * 0.38), Vector2(sx + s * 0.28, c.y), Vector2(sx, c.y + s * 0.38)]), color.lightened(0.15 * k), 4.0, true)
		"gust":      # cutting gust: a crescent of air with an edge
			ci.draw_arc(c + Vector2(-s * 0.26, 0), s * 0.62, -1.0, 1.0, 20, color, 5.0, true)
			ci.draw_arc(c + Vector2(-s * 0.34, 0), s * 0.4, -0.85, 0.85, 16, color.darkened(0.2), 3.0, true)
			ci.draw_arc(c + Vector2(-s * 0.42, 0), s * 0.2, -0.7, 0.7, 12, color.darkened(0.35), 2.5, true)
		"crosscut":  # crosscut: two cuts crossing
			ci.draw_line(c + Vector2(-s * 0.46, -s * 0.42), c + Vector2(s * 0.46, s * 0.42), color.darkened(0.15), 5.0, true)
			ci.draw_line(c + Vector2(s * 0.46, -s * 0.42), c + Vector2(-s * 0.46, s * 0.42), color.lightened(0.15), 5.0, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.14), c + Vector2(s * 0.14, 0), c + Vector2(0, s * 0.14), c + Vector2(-s * 0.14, 0)]), color.lightened(0.6))
		"tailwind":  # tailwind: carried forward on the wind
			for k: int in 3:
				ci.draw_line(c + Vector2(-s * 0.6 + absf(float(k) - 1.0) * s * 0.16, -s * 0.3 + k * s * 0.3), c + Vector2(-s * 0.06, -s * 0.3 + k * s * 0.3), color.darkened(0.25), 2.5, true)
			for k: int in 2:
				var tx: float = c.x + s * 0.02 + k * s * 0.3
				ci.draw_polyline(PackedVector2Array([Vector2(tx, c.y - s * 0.42), Vector2(tx + s * 0.28, c.y), Vector2(tx, c.y + s * 0.42)]), color.lightened(0.15 * k), 4.0, true)
		"downdraft": # downdraft: air driven into the ground
			for k: int in 3:
				var dx: float = c.x - s * 0.36 + k * s * 0.36
				var dy: float = c.y + (s * 0.3 if k == 1 else s * 0.18)
				ci.draw_line(Vector2(dx, c.y - s * 0.52), Vector2(dx, dy), color, 3.0, true)
				ci.draw_polyline(PackedVector2Array([Vector2(dx - s * 0.12, dy - s * 0.14), Vector2(dx, dy), Vector2(dx + s * 0.12, dy - s * 0.14)]), color, 3.0, true)
			ci.draw_line(c + Vector2(-s * 0.6, s * 0.46), c + Vector2(s * 0.6, s * 0.46), color.darkened(0.3), 3.0, true)
		"bolt":      # arc lash: a stroke of lightning
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.14, -s * 0.58), c + Vector2(-s * 0.3, s * 0.08), c + Vector2(-s * 0.02, s * 0.08), c + Vector2(-s * 0.16, s * 0.58),
				c + Vector2(s * 0.32, -s * 0.12), c + Vector2(s * 0.04, -s * 0.12), c + Vector2(s * 0.3, -s * 0.58)]), color)
		"palm":      # thunderclap palm: a strike that rings
			ci.draw_circle(c, s * 0.2, color)
			ci.draw_arc(c, s * 0.36, 0.0, TAU, 28, color.darkened(0.15), 2.5, true)
			for k: int in 8:
				var pa: float = TAU * float(k) / 8.0 + 0.39
				ci.draw_line(c + Vector2(cos(pa), sin(pa)) * s * 0.46, c + Vector2(cos(pa), sin(pa)) * s * 0.62, color.lightened(0.35), 2.5, true)
		"blink":     # stepped leader: gone from here, there at once
			ci.draw_arc(c + Vector2(-s * 0.4, s * 0.34), s * 0.15, 0.0, TAU, 14, color.darkened(0.3), 2.0, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.3, s * 0.24), c + Vector2(-s * 0.02, s * 0.14), c + Vector2(-s * 0.12, -s * 0.06), c + Vector2(s * 0.24, -s * 0.22)]), color.darkened(0.1), 2.5, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.38, -s * 0.56), c + Vector2(s * 0.6, -s * 0.32), c + Vector2(s * 0.38, -s * 0.08), c + Vector2(s * 0.16, -s * 0.32)]), color.lightened(0.3))
		"scroll":    # a skill scroll: a rolled sheet with writing
			ci.draw_rect(Rect2(c + Vector2(-s * 0.34, -s * 0.4), Vector2(s * 0.68, s * 0.8)), color.darkened(0.1))
			ci.draw_circle(c + Vector2(-s * 0.34, -s * 0.4), s * 0.1, color)
			ci.draw_circle(c + Vector2(s * 0.34, s * 0.4), s * 0.1, color)
			for k: int in 4:
				ci.draw_line(c + Vector2(-s * 0.22, -s * 0.22 + k * s * 0.15), c + Vector2(s * (0.22 if k != 3 else 0.02), -s * 0.22 + k * s * 0.15), color.darkened(0.55), 1.5, true)
		"undertow":  # undertow: everything drawn to one spot
			ci.draw_circle(c, s * 0.12, color)
			for k: int in 4:
				var ua: float = TAU * float(k) / 4.0 + 0.5
				var tip: Vector2 = c + Vector2(cos(ua), sin(ua)) * s * 0.22
				var tail: Vector2 = c + Vector2(cos(ua), sin(ua)) * s * 0.58
				var side := Vector2(-sin(ua), cos(ua)) * s * 0.11
				ci.draw_line(tail, tip, color.darkened(0.1), 3.0, true)
				ci.draw_polyline(PackedVector2Array([tip + side + (tail - tip) * 0.3, tip, tip - side + (tail - tip) * 0.3]), color, 3.0, true)
		"lash":      # riptide lash: a rope with a hook on the end
			ci.draw_arc(c + Vector2(-s * 0.1, s * 0.1), s * 0.44, -2.6, 0.2, 18, color, 3.5, true)
			ci.draw_arc(c + Vector2(s * 0.34, -s * 0.06), s * 0.2, 0.4, 3.6, 12, color.lightened(0.2), 3.5, true)
			ci.draw_circle(c + Vector2(-s * 0.48, -s * 0.12), s * 0.08, color)
		"backdraft": # backdraft: a ring of fire going outward
			ci.draw_arc(c, s * 0.24, 0.0, TAU, 24, color.lightened(0.3), 3.0, true)
			for k: int in 8:
				var ba: float = TAU * float(k) / 8.0
				var bo := Vector2(cos(ba), sin(ba))
				var bs := Vector2(-sin(ba), cos(ba)) * s * 0.1
				ci.draw_colored_polygon(PackedVector2Array([c + bo * s * 0.34 + bs, c + bo * s * 0.62, c + bo * s * 0.34 - bs]), color)
		"pyre":      # pyre call: many small fires answering
			for k: int in 3:
				var px2: float = -s * 0.36 + k * s * 0.36
				var py2: float = s * 0.36 if k != 1 else -s * 0.02
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(px2 - s * 0.15, py2), c + Vector2(px2 + s * 0.15, py2), c + Vector2(px2 + s * 0.02, py2 - s * 0.44)]), color.lightened(0.1 * k))
				ci.draw_arc(c + Vector2(px2, py2 - s * 0.14), s * 0.24, -2.4, -0.7, 8, color.darkened(0.2), 1.5, true)
		"pillar":    # pillar: a column through the floor
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.16, s * 0.36), c + Vector2(-s * 0.2, -s * 0.4), c + Vector2(0, -s * 0.58), c + Vector2(s * 0.2, -s * 0.4), c + Vector2(s * 0.16, s * 0.36)]), color)
			ci.draw_line(c + Vector2(-s * 0.6, s * 0.38), c + Vector2(s * 0.6, s * 0.38), color.darkened(0.3), 4.0, true)
			ci.draw_line(c + Vector2(-s * 0.2, s * 0.38), c + Vector2(-s * 0.42, s * 0.16), color.darkened(0.45), 2.0, true)
			ci.draw_line(c + Vector2(s * 0.2, s * 0.38), c + Vector2(s * 0.44, s * 0.14), color.darkened(0.45), 2.0, true)
		"tremor":    # tremor: the ground ringing outward
			ci.draw_circle(c + Vector2(0, s * 0.08), s * 0.1, color)
			for k: int in 3:
				ci.draw_arc(c + Vector2(0, s * 0.08), s * (0.24 + 0.16 * k), PI + 0.35, TAU - 0.35, 14, color.darkened(0.15 * k), 3.0, true)
				ci.draw_arc(c + Vector2(0, s * 0.08), s * (0.24 + 0.16 * k), 0.35, PI - 0.35, 14, color.darkened(0.3 + 0.1 * k), 2.0, true)
		"updraft":   # updraft: thrown into the air
			for k: int in 3:
				var ux: float = c.x - s * 0.36 + k * s * 0.36
				var uy: float = c.y - (s * 0.42 if k == 1 else s * 0.28)
				ci.draw_line(Vector2(ux, c.y + s * 0.36), Vector2(ux, uy), color, 3.0, true)
				ci.draw_polyline(PackedVector2Array([Vector2(ux - s * 0.12, uy + s * 0.14), Vector2(ux, uy), Vector2(ux + s * 0.12, uy + s * 0.14)]), color, 3.0, true)
			ci.draw_arc(c + Vector2(0, s * 0.5), s * 0.5, PI + 0.5, TAU - 0.5, 12, color.darkened(0.3), 2.5, true)
		"fork":      # forked path: one stroke, three ends
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.56, -s * 0.04), c + Vector2(-s * 0.2, s * 0.06), c + Vector2(-s * 0.08, -s * 0.06)]), color, 4.0, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.08, -s * 0.06), c + Vector2(s * 0.2, -s * 0.2), c + Vector2(s * 0.28, -s * 0.5), c + Vector2(s * 0.56, -s * 0.46)]), color.lightened(0.15), 3.0, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.08, -s * 0.06), c + Vector2(s * 0.3, s * 0.02), c + Vector2(s * 0.58, s * 0.0)]), color.lightened(0.15), 3.0, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.08, -s * 0.06), c + Vector2(s * 0.14, s * 0.26), c + Vector2(s * 0.4, s * 0.3), c + Vector2(s * 0.52, s * 0.52)]), color.lightened(0.15), 3.0, true)
		"short":     # dead short: the bolt closed on itself
			ci.draw_arc(c, s * 0.52, 0.5, TAU - 0.3, 26, color.darkened(0.2), 3.0, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.1, -s * 0.4), c + Vector2(-s * 0.22, s * 0.06), c + Vector2(-s * 0.02, s * 0.06), c + Vector2(-s * 0.12, s * 0.4),
				c + Vector2(s * 0.24, -s * 0.08), c + Vector2(s * 0.03, -s * 0.08), c + Vector2(s * 0.22, -s * 0.4)]), color)
		"pool":      # standing pool: still water on the floor
			for k: int in 3:
				ci.draw_arc(c + Vector2(0, s * 0.1), s * (0.2 + 0.18 * k), 0.0, TAU, 28, color.darkened(0.12 * k), 3.0 - 0.5 * k, true)
			ci.draw_circle(c + Vector2(0, s * 0.1), s * 0.08, color.lightened(0.3))
		"backwash":  # backwash: a blow turned aside
			ci.draw_arc(c + Vector2(-s * 0.1, 0), s * 0.44, -1.2, 1.2, 16, color, 5.0, true)
			ci.draw_line(c + Vector2(s * 0.62, -s * 0.3), c + Vector2(s * 0.38, -s * 0.12), color.lightened(0.3), 3.0, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(s * 0.38, -s * 0.12), c + Vector2(s * 0.5, s * 0.14), c + Vector2(s * 0.64, s * 0.4)]), color.darkened(0.25), 3.0, true)
		"slag":      # slag pool: molten ground
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.56, s * 0.22), c + Vector2(-s * 0.3, s * 0.02), c + Vector2(s * 0.1, -s * 0.04), c + Vector2(s * 0.5, s * 0.1),
				c + Vector2(s * 0.58, s * 0.3), c + Vector2(s * 0.2, s * 0.46), c + Vector2(-s * 0.3, s * 0.44)]), color.darkened(0.2))
			for k: int in 3:
				ci.draw_circle(c + Vector2(-s * 0.26 + k * s * 0.26, s * 0.22 - (s * 0.06 if k == 1 else 0.0)), s * 0.07, color.lightened(0.45))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.1, -s * 0.12), c + Vector2(s * 0.14, -s * 0.12), c + Vector2(s * 0.04, -s * 0.56)]), color)
		"stoke":     # stoke: a fire being fed
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.02, -s * 0.5), c + Vector2(s * 0.26, -s * 0.06), c + Vector2(s * 0.2, s * 0.22), c + Vector2(0, s * 0.3), c + Vector2(-s * 0.2, s * 0.22), c + Vector2(-s * 0.24, -s * 0.04)]), color)
			ci.draw_line(c + Vector2(-s * 0.5, s * 0.46), c + Vector2(s * 0.3, s * 0.3), color.darkened(0.45), 4.0, true)
			ci.draw_line(c + Vector2(s * 0.5, s * 0.46), c + Vector2(-s * 0.3, s * 0.3), color.darkened(0.35), 4.0, true)
		"stonehide": # stonehide: a body made of blocks
			ci.draw_rect(Rect2(c + Vector2(-s * 0.3, -s * 0.22), Vector2(s * 0.6, s * 0.64)), color)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.16, -s * 0.56), Vector2(s * 0.32, s * 0.3)), color.lightened(0.12))
			ci.draw_line(c + Vector2(-s * 0.3, s * 0.08), c + Vector2(s * 0.3, s * 0.08), color.darkened(0.45), 2.0, true)
			ci.draw_line(c + Vector2(0, -s * 0.22), c + Vector2(0, s * 0.08), color.darkened(0.45), 2.0, true)
			ci.draw_line(c + Vector2(-s * 0.12, s * 0.08), c + Vector2(-s * 0.12, s * 0.42), color.darkened(0.45), 2.0, true)
		"veil":      # crosswind veil: a shot curving past
			ci.draw_circle(c + Vector2(-s * 0.1, s * 0.1), s * 0.14, color)
			ci.draw_arc(c + Vector2(-s * 0.1, s * 0.1), s * 0.4, -2.2, 0.9, 20, color.darkened(0.2), 2.5, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(s * 0.6, -s * 0.5), c + Vector2(s * 0.3, -s * 0.44), c + Vector2(s * 0.34, -s * 0.12), c + Vector2(s * 0.6, s * 0.06)]), color.lightened(0.3), 2.5, true)
		"lane":      # gale lane: a road of wind
			ci.draw_line(c + Vector2(-s * 0.6, -s * 0.34), c + Vector2(s * 0.6, -s * 0.34), color.darkened(0.3), 2.5, true)
			ci.draw_line(c + Vector2(-s * 0.6, s * 0.34), c + Vector2(s * 0.6, s * 0.34), color.darkened(0.3), 2.5, true)
			for k: int in 3:
				var lx: float = c.x - s * 0.42 + k * s * 0.3
				ci.draw_polyline(PackedVector2Array([Vector2(lx, c.y - s * 0.2), Vector2(lx + s * 0.2, c.y), Vector2(lx, c.y + s * 0.2)]), color.lightened(0.1 * k), 3.0, true)
		"coat_static":   # static coat: a body with sparks standing off it
			ci.draw_circle(c, s * 0.2, color)
			for k: int in 6:
				var sa: float = TAU * float(k) / 6.0 + 0.3
				var so := Vector2(cos(sa), sin(sa))
				var st2 := Vector2(-sin(sa), cos(sa)) * s * 0.08
				ci.draw_polyline(PackedVector2Array([c + so * s * 0.32, c + so * s * 0.42 + st2, c + so * s * 0.5 - st2, c + so * s * 0.62]), color.lightened(0.35), 2.0, true)
		"rod":       # ground rod: a spike waiting for the sky
			ci.draw_line(c + Vector2(0, s * 0.46), c + Vector2(0, -s * 0.3), color.darkened(0.25), 4.0, true)
			ci.draw_circle(c + Vector2(0, -s * 0.38), s * 0.1, color.lightened(0.3))
			ci.draw_line(c + Vector2(-s * 0.36, s * 0.46), c + Vector2(s * 0.36, s * 0.46), color.darkened(0.4), 3.0, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(s * 0.5, -s * 0.56), c + Vector2(s * 0.28, -s * 0.36), c + Vector2(s * 0.4, -s * 0.34), c + Vector2(s * 0.14, -s * 0.2)]), color.lightened(0.4), 2.5, true)
		"wall":      # raise slab: a block standing on broken ground
			ci.draw_rect(Rect2(c + Vector2(-s * 0.4, -s * 0.44), Vector2(s * 0.8, s * 0.74)), color)
			ci.draw_line(c + Vector2(-s * 0.4, -s * 0.12), c + Vector2(s * 0.4, -s * 0.18), color.darkened(0.4), 2.0, true)
			ci.draw_line(c + Vector2(-s * 0.08, -s * 0.15), c + Vector2(s * 0.04, s * 0.3), color.darkened(0.4), 2.0, true)
			ci.draw_line(c + Vector2(-s * 0.6, s * 0.36), c + Vector2(s * 0.6, s * 0.36), color.darkened(0.25), 4.0, true)
		"dash":      # hydraulic flex: chevrons
			for k: int in 3:
				var x: float = c.x - s * 0.45 + k * s * 0.36
				ci.draw_polyline(PackedVector2Array([Vector2(x, c.y - s * 0.42), Vector2(x + s * 0.3, c.y), Vector2(x, c.y + s * 0.42)]), color.darkened(0.25 * (2 - k)), 4.0, true)
		"coat":      # body armour: shoulders, two sleeves, an open front
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.2, -s * 0.46), c + Vector2(s * 0.2, -s * 0.46), c + Vector2(s * 0.5, -s * 0.22),
				c + Vector2(s * 0.36, s * 0.02), c + Vector2(s * 0.26, -s * 0.08), c + Vector2(s * 0.3, s * 0.48), c + Vector2(-s * 0.3, s * 0.48),
				c + Vector2(-s * 0.26, -s * 0.08), c + Vector2(-s * 0.36, s * 0.02), c + Vector2(-s * 0.5, -s * 0.22)]), color)
			ci.draw_line(c + Vector2(0, -s * 0.44), c + Vector2(0, s * 0.46), color.darkened(0.45), 2.0, true)
		"sling":     # a ranged weapon: two cords, a pouch, a stone
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.42, -s * 0.44), c + Vector2(-s * 0.14, s * 0.18), c + Vector2(s * 0.14, s * 0.18), c + Vector2(s * 0.42, -s * 0.44)]), color, 2.5, true)
			ci.draw_arc(c + Vector2(0, s * 0.16), s * 0.2, 0.0, PI, 12, color, 4.0, true)
			ci.draw_circle(c + Vector2(0, s * 0.14), s * 0.1, color.lightened(0.35))
		"pack":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.38, -s * 0.3), Vector2(s * 0.76, s * 0.78)), color)
			ci.draw_arc(c + Vector2(0, -s * 0.3), s * 0.24, PI, TAU, 12, color, 3.0, true)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.2, s * 0.05), Vector2(s * 0.4, s * 0.24)), color.darkened(0.4))
		"mote":
			ci.draw_circle(c, s * 0.2, color)
			ci.draw_arc(c, s * 0.42, 0.2, TAU - 0.9, 24, color.darkened(0.2), 2.5, true)
			ci.draw_circle(c + Vector2(cos(0.2), sin(0.2)) * s * 0.42, s * 0.08, color.lightened(0.3))
		"charm":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.5), c + Vector2(s * 0.36, 0), c + Vector2(0, s * 0.5), c + Vector2(-s * 0.36, 0)]), color)
			ci.draw_line(c + Vector2(0, -s * 0.5), c + Vector2(0, s * 0.5), color.lightened(0.4), 1.5, true)
		"hood":      # head: a domed cap over an open face
			ci.draw_arc(c + Vector2(0, s * 0.02), s * 0.36, PI, TAU, 20, color, s * 0.16, true)
			ci.draw_line(c + Vector2(-s * 0.36, 0), c + Vector2(-s * 0.36, s * 0.4), color, s * 0.16, true)
			ci.draw_line(c + Vector2(s * 0.36, 0), c + Vector2(s * 0.36, s * 0.4), color, s * 0.16, true)
			ci.draw_line(c + Vector2(0, -s * 0.34), c + Vector2(0, s * 0.02), color.darkened(0.35), 2.0, true)
		"glove":     # hands: a mitt, a thumb and a cuff
			ci.draw_rect(Rect2(c + Vector2(-s * 0.26, -s * 0.46), Vector2(s * 0.46, s * 0.6)), color)
			ci.draw_line(c + Vector2(s * 0.2, -s * 0.02), c + Vector2(s * 0.42, -s * 0.26), color, s * 0.16, true)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.3, s * 0.2), Vector2(s * 0.54, s * 0.26)), color.darkened(0.3))
			for k: int in 3:
				ci.draw_line(c + Vector2(-s * 0.14 + k * s * 0.115, -s * 0.44), c + Vector2(-s * 0.14 + k * s * 0.115, -s * 0.14), color.darkened(0.45), 1.5, true)
		"boot":      # feet: a shaft, a foot and a sole
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.3, -s * 0.48), c + Vector2(s * 0.04, -s * 0.48), c + Vector2(s * 0.04, s * 0.08),
				c + Vector2(s * 0.44, s * 0.2), c + Vector2(s * 0.44, s * 0.36), c + Vector2(-s * 0.3, s * 0.36)]), color)
			ci.draw_line(c + Vector2(-s * 0.34, s * 0.44), c + Vector2(s * 0.46, s * 0.44), color.darkened(0.35), 4.0, true)
		"slate":     # off hand: a framed slate with working written on it
			ci.draw_rect(Rect2(c + Vector2(-s * 0.34, -s * 0.44), Vector2(s * 0.68, s * 0.88)), color.darkened(0.45))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.34, -s * 0.44), Vector2(s * 0.68, s * 0.88)), color, false, 3.0)
			for k: int in 3:
				ci.draw_line(c + Vector2(-s * 0.2, -s * 0.2 + k * s * 0.2), c + Vector2(s * (0.2 - 0.12 * k), -s * 0.2 + k * s * 0.2), color, 2.0, true)
		"belt":      # a strap and a buckle
			ci.draw_rect(Rect2(c + Vector2(-s * 0.5, -s * 0.1), Vector2(s, s * 0.2)), color.darkened(0.25))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.16, -s * 0.2), Vector2(s * 0.32, s * 0.4)), color, false, 3.0)
			ci.draw_line(c + Vector2(-s * 0.02, 0), c + Vector2(s * 0.16, 0), color, 2.5, true)
		"gem":       # a construct waiting to be bound
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.5), c + Vector2(s * 0.42, -s * 0.1), c + Vector2(s * 0.24, s * 0.5), c + Vector2(-s * 0.24, s * 0.5), c + Vector2(-s * 0.42, -s * 0.1)]), color)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.42, -s * 0.1), c + Vector2(0, s * 0.08), c + Vector2(s * 0.42, -s * 0.1)]), color.lightened(0.5), 1.5, true)
		"blade":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.42, -s * 0.5), c + Vector2(s * 0.5, -s * 0.42), c + Vector2(-s * 0.12, s * 0.2), c + Vector2(-s * 0.2, s * 0.12)]), color)
			ci.draw_line(c + Vector2(-s * 0.32, 0.0), c + Vector2(0.0, s * 0.32), color.darkened(0.3), 4.0, true)
			ci.draw_line(c + Vector2(-s * 0.2, s * 0.2), c + Vector2(-s * 0.44, s * 0.44), color.darkened(0.15), 5.0, true)
		"arm":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.4, s * 0.4), c + Vector2(-s * 0.1, -s * 0.05), c + Vector2(s * 0.25, -s * 0.3)]), color, 5.0, true)
			ci.draw_circle(c + Vector2(s * 0.34, -s * 0.38), s * 0.17, color)
		"coin":
			ci.draw_circle(c, s * 0.42, color.darkened(0.3))
			ci.draw_circle(c, s * 0.32, color)
		"tusk":      # a curved tusk
			var tp := PackedVector2Array()
			for i: int in 13:
				var u: float = float(i) / 12.0
				tp.append(c + Vector2(-s * 0.42 + u * s * 0.8, s * 0.36 - sin(u * PI * 0.62) * s * 0.78 + u * s * 0.1))
			for i: int in range(12, -1, -1):
				var u2: float = float(i) / 12.0
				tp.append(c + Vector2(-s * 0.42 + u2 * s * 0.8, s * 0.36 - sin(u2 * PI * 0.62) * s * 0.78 + u2 * s * 0.1 + s * 0.22 * (1.0 - u2)))
			ci.draw_colored_polygon(tp, color)
			ci.draw_line(c + Vector2(-s * 0.46, s * 0.36), c + Vector2(-s * 0.4, s * 0.58), color.darkened(0.4), 3.0, true)
		"plate":     # a curved plate of shell or armour
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.46, -s * 0.2), c + Vector2(0, -s * 0.44), c + Vector2(s * 0.46, -s * 0.2),
				c + Vector2(s * 0.36, s * 0.34), c + Vector2(0, s * 0.48), c + Vector2(-s * 0.36, s * 0.34)]), color.darkened(0.15))
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.36, -s * 0.06), c + Vector2(0, -s * 0.24), c + Vector2(s * 0.36, -s * 0.06)]), color.lightened(0.3), 2.0, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.3, s * 0.14), c + Vector2(0, -s * 0.02), c + Vector2(s * 0.3, s * 0.14)]), color.darkened(0.45), 2.0, true)
		"cord":      # a coil of cord
			for k: int in 3:
				ci.draw_arc(c + Vector2(0, s * 0.04), s * (0.18 + 0.14 * k), 0.0, TAU - (0.6 if k == 2 else 0.0), 24, color.darkened(0.12 * k), 3.0, true)
			ci.draw_line(c + Vector2(s * 0.46, s * 0.04), c + Vector2(s * 0.58, s * 0.5), color, 3.0, true)
		"sigil":     # a seal: a ring with a mark struck in it
			ci.draw_circle(c, s * 0.44, color.darkened(0.35))
			ci.draw_arc(c, s * 0.36, 0.0, TAU, 28, color.lightened(0.2), 2.0, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.24), c + Vector2(s * 0.2, s * 0.16), c + Vector2(-s * 0.2, s * 0.16)]), color.lightened(0.3))
		"seed":      # a seed head
			ci.draw_line(c + Vector2(0, s * 0.56), c + Vector2(0, -s * 0.1), color.darkened(0.3), 2.0, true)
			for k: int in 5:
				var sy2: float = -s * 0.46 + k * s * 0.12
				ci.draw_circle(c + Vector2(-s * 0.08, sy2), s * 0.07, color)
				ci.draw_circle(c + Vector2(s * 0.08, sy2 + s * 0.06), s * 0.07, color)
		"mask":      # a face mask with eye holes
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.4, -s * 0.36), c + Vector2(s * 0.4, -s * 0.36), c + Vector2(s * 0.36, s * 0.14),
				c + Vector2(0, s * 0.52), c + Vector2(-s * 0.36, s * 0.14)]), color)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.3, -s * 0.12), c + Vector2(-s * 0.08, -s * 0.16), c + Vector2(-s * 0.1, -s * 0.02), c + Vector2(-s * 0.28, -s * 0.02)]), Color(0, 0, 0, 0.85))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.3, -s * 0.12), c + Vector2(s * 0.08, -s * 0.16), c + Vector2(s * 0.1, -s * 0.02), c + Vector2(s * 0.28, -s * 0.02)]), Color(0, 0, 0, 0.85))
		"stave":     # an unstrung bow stave
			ci.draw_arc(c + Vector2(s * 0.5, 0), s * 0.72, PI * 0.72, PI * 1.28, 18, color, 4.0, true)
			ci.draw_line(c + Vector2(-s * 0.14, -s * 0.5), c + Vector2(-s * 0.14, s * 0.5), color.darkened(0.45), 1.0, true)
		"hide":      # a stretched hide
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.3, -s * 0.48), c + Vector2(s * 0.3, -s * 0.48), c + Vector2(s * 0.5, -s * 0.2), c + Vector2(s * 0.34, s * 0.06),
				c + Vector2(s * 0.48, s * 0.4), c + Vector2(s * 0.14, s * 0.5), c + Vector2(-s * 0.14, s * 0.5), c + Vector2(-s * 0.48, s * 0.4), c + Vector2(-s * 0.34, s * 0.06), c + Vector2(-s * 0.5, -s * 0.2)]), color.darkened(0.1))
			ci.draw_line(c + Vector2(0, -s * 0.4), c + Vector2(0, s * 0.42), color.darkened(0.4), 1.5, true)
		"boss":      # a shield boss
			ci.draw_circle(c, s * 0.48, color.darkened(0.4))
			ci.draw_circle(c, s * 0.3, color)
			ci.draw_circle(c + Vector2(-s * 0.08, -s * 0.08), s * 0.1, color.lightened(0.4))
			for k: int in 6:
				var ra: float = TAU * float(k) / 6.0
				ci.draw_circle(c + Vector2(cos(ra), sin(ra)) * s * 0.4, s * 0.04, color.lightened(0.2))
		"ash":       # a heap of ash with smoke over it
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.5, s * 0.42), c + Vector2(-s * 0.2, s * 0.06), c + Vector2(s * 0.08, s * 0.12), c + Vector2(s * 0.5, s * 0.42)]), color.darkened(0.2))
			ci.draw_arc(c + Vector2(-s * 0.1, -s * 0.12), s * 0.16, PI, TAU, 10, color.lightened(0.2), 2.0, true)
			ci.draw_arc(c + Vector2(s * 0.12, -s * 0.3), s * 0.14, 0.0, PI, 10, color.lightened(0.2), 2.0, true)
		"drum":      # a drumhead
			ci.draw_rect(Rect2(c + Vector2(-s * 0.4, -s * 0.18), Vector2(s * 0.8, s * 0.5)), color.darkened(0.35))
			ci.draw_arc(c + Vector2(0, -s * 0.18), s * 0.4, PI, TAU, 16, color, 3.0, true)
			ci.draw_line(c + Vector2(-s * 0.4, -s * 0.18), c + Vector2(s * 0.4, -s * 0.18), color, 3.0, true)
			for k: int in 3:
				ci.draw_line(c + Vector2(-s * 0.3 + k * s * 0.3, -s * 0.12), c + Vector2(-s * 0.2 + k * s * 0.3, s * 0.3), color.lightened(0.2), 1.5, true)
		"chest":     # a bound strongbox
			ci.draw_rect(Rect2(c + Vector2(-s * 0.46, -s * 0.2), Vector2(s * 0.92, s * 0.6)), color.darkened(0.2))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.46, -s * 0.4), Vector2(s * 0.92, s * 0.22)), color)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.08, -s * 0.24), Vector2(s * 0.16, s * 0.22)), color.lightened(0.4))
			ci.draw_line(c + Vector2(-s * 0.3, -s * 0.4), c + Vector2(-s * 0.3, s * 0.4), color.darkened(0.5), 2.0, true)
			ci.draw_line(c + Vector2(s * 0.3, -s * 0.4), c + Vector2(s * 0.3, s * 0.4), color.darkened(0.5), 2.0, true)
		"relics":    # a case with three small things in it
			ci.draw_rect(Rect2(c + Vector2(-s * 0.48, -s * 0.3), Vector2(s * 0.96, s * 0.66)), color.darkened(0.45))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.48, -s * 0.3), Vector2(s * 0.96, s * 0.66)), color, false, 2.0)
			ci.draw_circle(c + Vector2(-s * 0.24, s * 0.04), s * 0.1, color.lightened(0.3))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.14), c + Vector2(s * 0.1, s * 0.04), c + Vector2(0, s * 0.2), c + Vector2(-s * 0.1, s * 0.04)]), STAR_TINT)
			ci.draw_rect(Rect2(c + Vector2(s * 0.16, -s * 0.06), Vector2(s * 0.16, s * 0.2)), color.lightened(0.2))
		"salvage":   # scrap: a bent bar and a ring
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.5, s * 0.3), c + Vector2(-s * 0.1, s * 0.1), c + Vector2(s * 0.1, -s * 0.36)]), color, 4.0, true)
			ci.draw_arc(c + Vector2(s * 0.24, s * 0.2), s * 0.2, 0.0, TAU, 18, color.lightened(0.2), 3.0, true)
		_:           # loot and anything unknown: a plain crate
			ci.draw_rect(Rect2(c - Vector2(s * 0.36, s * 0.36), Vector2(s * 0.72, s * 0.72)), color.darkened(0.25))
			ci.draw_rect(Rect2(c - Vector2(s * 0.36, s * 0.36), Vector2(s * 0.72, s * 0.72)), color, false, 2.0)
			ci.draw_line(c - Vector2(s * 0.36, 0), c + Vector2(s * 0.36, 0), color, 2.0)


## Which glyph an item uses: its own "icon" key in items.json first, then one per slot.
static func item_icon(def: Dictionary) -> String:
	if def.has("icon"):
		return str(def["icon"])
	if str(def.get("kind", "")) == "scroll":
		return "scroll"
	match str(def.get("slot", "")):
		"weapon": return "blade"
		"ranged": return "sling"
		"body": return "coat"
		"back": return "pack"
		"satellite": return "mote"
		"trinket": return "charm"
		"head": return "hood"
		"hands": return "glove"
		"feet": return "boot"
		"offhand": return "slate"
		"belt": return "belt"
	return "crate"
