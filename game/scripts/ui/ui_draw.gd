class_name UiDraw
extends RefCounted
## Procedural drawing helpers for the HUD: liquid orbs, gauges, bars and small glyph icons.
## Every function draws onto the CanvasItem passed in, from inside its _draw().


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
	ci.draw_rect(rect.grow(1.0), Color(0, 0, 0, 0.7))
	ci.draw_rect(rect, back)
	if frac > 0.0:
		var f := Rect2(rect.position, Vector2(rect.size.x * clampf(frac, 0.0, 1.0), rect.size.y))
		ci.draw_rect(f, color)
		ci.draw_rect(Rect2(f.position, Vector2(f.size.x, maxf(1.0, f.size.y * 0.35))), Color(1, 1, 1, 0.14))
	ci.draw_rect(rect.grow(1.0), UiTheme.BRONZE_DIM, false, 1.0)


static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, shadow: bool = true) -> void:
	var f: Font = UiTheme.font()
	if shadow:
		ci.draw_string(f, pos + Vector2(1, 1), s, align, width, size, Color(0, 0, 0, 0.85))
	ci.draw_string(f, pos, s, align, width, size, color)


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
				var y: float = c.y - s * 0.3 + k * s * 0.3
				var prev := Vector2(c.x - s * 0.6, y)
				for i: int in range(1, 17):
					var u: float = float(i) / 16.0
					var p := Vector2(c.x - s * 0.6 + u * s * 1.2, y - sin(u * PI) * s * (0.34 - k * 0.07) * (1.0 if i < 11 else 0.5))
					ci.draw_line(prev, p, color.lightened(0.15 * (2 - k)), 3.0, true)
					prev = p
		"dash":      # hydraulic flex: chevrons
			for k: int in 3:
				var x: float = c.x - s * 0.45 + k * s * 0.36
				ci.draw_polyline(PackedVector2Array([Vector2(x, c.y - s * 0.42), Vector2(x + s * 0.3, c.y), Vector2(x, c.y + s * 0.42)]), color.darkened(0.25 * (2 - k)), 4.0, true)
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
		"gem":       # a construct waiting to be bound
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.5), c + Vector2(s * 0.42, -s * 0.1), c + Vector2(s * 0.24, s * 0.5), c + Vector2(-s * 0.24, s * 0.5), c + Vector2(-s * 0.42, -s * 0.1)]), color)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.42, -s * 0.1), c + Vector2(0, s * 0.08), c + Vector2(s * 0.42, -s * 0.1)]), color.lightened(0.5), 1.5, true)
		"arm":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.4, s * 0.4), c + Vector2(-s * 0.1, -s * 0.05), c + Vector2(s * 0.25, -s * 0.3)]), color, 5.0, true)
			ci.draw_circle(c + Vector2(s * 0.34, -s * 0.38), s * 0.17, color)
		"coin":
			ci.draw_circle(c, s * 0.42, color.darkened(0.3))
			ci.draw_circle(c, s * 0.32, color)
		_:           # loot and anything unknown: a plain crate
			ci.draw_rect(Rect2(c - Vector2(s * 0.36, s * 0.36), Vector2(s * 0.72, s * 0.72)), color.darkened(0.25))
			ci.draw_rect(Rect2(c - Vector2(s * 0.36, s * 0.36), Vector2(s * 0.72, s * 0.72)), color, false, 2.0)
			ci.draw_line(c - Vector2(s * 0.36, 0), c + Vector2(s * 0.36, 0), color, 2.0)


## Which glyph an item uses.
static func item_icon(def: Dictionary) -> String:
	match str(def.get("slot", "")):
		"back": return "pack"
		"satellite": return "mote"
		"trinket": return "charm"
	return "crate"
