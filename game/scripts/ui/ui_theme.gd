class_name UiTheme
extends RefCounted
## One look for the whole interface: dark worn stone, bronze trim, parchment text, serif type.
## Everything visual is defined here so screens stay consistent. Frames are nine-patch textures
## made by tools/assets/make_ui_textures.py (own work); if one is missing the flat style is used.
## Layout and type rules: design/09-ui-review-v0.md section 3.

# Palette
const BG := Color("14110f")
const PANEL := Color("1d1915")
const PANEL_HI := Color("2a241d")
const INSET := Color("0e0c0a")
const BRONZE := Color("7a5f3a")
const BRONZE_DIM := Color("4a3a25")
const GOLD := Color("d2ab52")
const TEXT := Color("e8dfc8")
const TEXT_DIM := Color("a69b84")
const TEXT_FAINT := Color("857a66")         # was 6d6455: under 3:1 on a panel, too faint to read at 12 px
const GOOD := Color("7fbf6a")
const BAD := Color("d2553f")
const OUTLINE := Color(0.02, 0.015, 0.01, 0.92)

const HEALTH_SUPERFICIAL := Color("c8372d")
const HEALTH_STRUCTURAL := Color("8f1f1a")
const HEALTH_CATASTROPHIC := Color("4f0f10")
const ESSENCE := Color("2f7fd6")
const ESSENCE_DEEP := Color("163f86")
const REFLUX := Color("e08a2a")
const REFLUX_HOT := Color("e2452a")
const STAR := Color("cdbcf2")
const NETHER := Color("8a6fd0")

# Type scale (pixels at the 1600 x 900 reference size; the window scales it). Nothing smaller
# than CAPTION is drawn anywhere, and CAPTION only inside a panel or with an outline.
const FS_DISPLAY := 46
const FS_TITLE := 30
const FS_HEAD := 20
const FS_BODY := 16
const FS_SMALL := 14
const FS_CAPTION := 12

## Nine-patch frames: kind -> [texture, margin px, tiles (true) or stretches (false)].
const FRAMES := {
	"panel": ["res://assets/ui/panel.png", 24, true],
	"panel_plain": ["res://assets/ui/panel_plain.png", 24, true],
	"panel_nether": ["res://assets/ui/panel_nether.png", 24, true],
	"button": ["res://assets/ui/button.png", 10, false],
	"button_hover": ["res://assets/ui/button_hover.png", 10, false],
	"button_pressed": ["res://assets/ui/button_pressed.png", 10, false],
	"button_disabled": ["res://assets/ui/button_disabled.png", 10, false],
	"slot": ["res://assets/ui/slot.png", 12, false],
}

static var _serif: Font
static var _serif_bold: Font
static var _theme: Theme
static var _frames: Dictionary = {}


## Serif system font with sensible fallbacks; falls back to the engine font if none exist.
static func font(bold: bool = false) -> Font:
	if _serif == null:
		_serif = _system_serif(400)
		_serif_bold = _system_serif(700)
	return _serif_bold if bold else _serif


static func _system_serif(weight: int) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Palatino Linotype", "Book Antiqua", "Georgia", "Cambria", "serif"])
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	# the rune glyphs outside the serif: Holy's and Unholy's Old Turkic (U+10C00-10C21) - Segoe UI Historic on
	# Windows, Noto elsewhere - named first so the system's own fallback is not left to guess
	var historic := SystemFont.new()
	historic.font_names = PackedStringArray(["Segoe UI Historic", "Noto Sans Old Turkic"])
	historic.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.fallbacks = [historic]
	return f


static func box(bg: Color, border: Color, border_w: int = 1, radius: int = 4, margin: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


## A nine-patch frame of the given kind (see FRAMES), with `margin` of room inside it for content.
## Shared and read-only: duplicate() it before changing it. Falls back to a flat box.
static func frame(kind: String, margin: float = -1.0) -> StyleBox:
	var key := "%s:%d" % [kind, int(margin)]
	if _frames.has(key):
		return _frames[key]
	var spec: Array = FRAMES.get(kind, [])
	var sb: StyleBox
	if not spec.is_empty() and ResourceLoader.exists(str(spec[0])):
		var t := StyleBoxTexture.new()
		t.texture = load(str(spec[0]))
		t.set_texture_margin_all(float(spec[1]))
		var mode: int = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT if bool(spec[2]) else StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		t.axis_stretch_horizontal = mode
		t.axis_stretch_vertical = mode
		sb = t
	else:
		sb = _flat_fallback(kind)
	if margin >= 0.0:
		sb.set_content_margin_all(margin)
	_frames[key] = sb
	return sb


static func _flat_fallback(kind: String) -> StyleBoxFlat:
	match kind:
		"button": return box(PANEL_HI, BRONZE_DIM, 1, 3, 10)
		"button_hover": return box(Color("3a3024"), GOLD, 1, 3, 10)
		"button_pressed": return box(Color("15120e"), GOLD, 1, 3, 10)
		"button_disabled": return box(Color("191613"), Color("2c261f"), 1, 3, 10)
		"slot": return box(INSET, BRONZE_DIM, 1, 2, 4)
		"panel_nether": return box(Color(0.09, 0.06, 0.16, 0.95), NETHER, 2, 4, 14)
	return box(PANEL, BRONZE, 2, 4, 18)


## A framed panel: worn fill, bronze bevel, corner brackets.
static func panel_box() -> StyleBox:
	return frame("panel", 22.0)


## The Theme applied at the HUD root: styles every Button, Label and Panel below it.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = FS_BODY + 1

	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", panel_box())
	t.set_stylebox("panel", "Panel", panel_box())

	var states := {"normal": "button", "hover": "button_hover", "pressed": "button_pressed", "disabled": "button_disabled", "focus": "button_hover"}
	for state: String in states:
		var sb: StyleBox = frame(str(states[state]), -1.0).duplicate()
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 7
		sb.content_margin_bottom = 7
		t.set_stylebox(state, "Button", sb)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color("fff3d0"))
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", TEXT_FAINT)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_font_size("font_size", "Button", FS_BODY + 1)

	var field: StyleBox = frame("slot", -1.0).duplicate()
	field.set_content_margin_all(8)
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", box(Color(0, 0, 0, 0), GOLD, 1, 2, 8))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", TEXT_FAINT)

	# scroll bars: a thin bronze grip in a dark groove
	for bar: String in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, box(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 0, 3, 3))
		t.set_stylebox("grabber", bar, box(BRONZE_DIM, BRONZE_DIM, 0, 3, 3))
		t.set_stylebox("grabber_highlight", bar, box(BRONZE, BRONZE, 0, 3, 3))
		t.set_stylebox("grabber_pressed", bar, box(GOLD.darkened(0.2), GOLD, 0, 3, 3))

	t.set_stylebox("panel", "TooltipPanel", frame("panel_plain", 10.0))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", FS_SMALL)

	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 10)
	_theme = t
	return t


static func heading(text: String, size: int = 26, color: Color = GOLD) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func body(text: String, size: int = 16, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## A small heading over a group of rows: spaced capitals in dim gold, with a rule under it.
static func section(text: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	col.add_child(gap)
	var l := heading(text.to_upper(), FS_CAPTION + 1, GOLD.darkened(0.15))
	col.add_child(l)
	col.add_child(rule())
	return col


## A thin bronze rule to separate sections.
static func rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = BRONZE_DIM
	r.custom_minimum_size = Vector2(0, 1)
	return r


## A skill's line under its name: its verse in quotes, or - for a drafted skill that has none yet -
## the rune it is built on.
static func verse_of(ab: Dictionary) -> String:
	if str(ab.get("verse", "")) != "":
		return "\"%s\"" % str(ab["verse"])
	return "Built on the rune %s" % str(ab.get("rune", "?")) if ab.has("rune") else ""


static func money_text(amount: int) -> String:
	return ("debt  $%s" % _commas(-amount)) if amount < 0 else ("$%s" % _commas(amount))


static func _commas(n: int) -> String:
	var s: String = str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
