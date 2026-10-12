class_name UiTheme
extends RefCounted
## One look for the whole interface: dark stone, bronze trim, parchment text, serif type.
## Everything visual is defined here so screens stay consistent. No image assets - all drawn.

# Palette
const BG := Color("14110f")
const PANEL := Color("1d1915")
const PANEL_HI := Color("2a241d")
const INSET := Color("0e0c0a")
const BRONZE := Color("7a5f3a")
const BRONZE_DIM := Color("4a3a25")
const GOLD := Color("d2ab52")
const TEXT := Color("e8dfc8")
const TEXT_DIM := Color("9c917b")
const TEXT_FAINT := Color("6d6455")
const GOOD := Color("7fbf6a")
const BAD := Color("d2553f")

const HEALTH_SUPERFICIAL := Color("c8372d")
const HEALTH_STRUCTURAL := Color("8f1f1a")
const HEALTH_CATASTROPHIC := Color("4f0f10")
const ESSENCE := Color("2f7fd6")
const ESSENCE_DEEP := Color("163f86")
const REFLUX := Color("e08a2a")
const REFLUX_HOT := Color("e2452a")
const STAR := Color("cdbcf2")

static var _serif: Font
static var _theme: Theme


## Serif system font with sensible fallbacks; falls back to the engine font if none exist.
static func font() -> Font:
	if _serif == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Palatino Linotype", "Book Antiqua", "Georgia", "Cambria", "serif"])
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_serif = f
	return _serif


static func box(bg: Color, border: Color, border_w: int = 1, radius: int = 4, margin: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


## A framed panel: stone fill, bronze edge, soft drop shadow.
static func panel_box() -> StyleBoxFlat:
	var sb := box(PANEL, BRONZE, 2, 6, 18)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 14
	return sb


## The Theme applied at the HUD root: styles every Button, Label and Panel below it.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 17

	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", panel_box())
	t.set_stylebox("panel", "Panel", panel_box())

	var normal := box(PANEL_HI, BRONZE_DIM, 1, 4, 10)
	var hover := box(Color("3a3024"), GOLD, 1, 4, 10)
	var pressed := box(Color("15120e"), GOLD, 1, 4, 10)
	var disabled := box(Color("191613"), Color("2c261f"), 1, 4, 10)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb: StyleBoxFlat = {"normal": normal, "hover": hover, "pressed": pressed, "disabled": disabled, "focus": hover}[state]
		t.set_stylebox(state, "Button", sb)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color("fff3d0"))
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", TEXT_FAINT)
	t.set_font_size("font_size", "Button", 17)

	t.set_stylebox("normal", "LineEdit", box(INSET, BRONZE_DIM, 1, 3, 8))
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


## A thin bronze rule to separate sections.
static func rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = BRONZE_DIM
	r.custom_minimum_size = Vector2(0, 1)
	return r


static func money_text(amount: int) -> String:
	return ("debt  $%s" % _commas(-amount)) if amount < 0 else ("$%s" % _commas(amount))


static func _commas(n: int) -> String:
	var s: String = str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
