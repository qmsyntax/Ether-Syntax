extends Control
## In-game HUD: bars for the body, arm, essence and reflux; a short notebook underneath.
## Built in code so the project stays plain text.

const PANEL_W := 400.0
const BAR_H := 18.0

var _title: Label
var _bars: Dictionary = {}          # name -> Dictionary(fill, text, back)
var _money: Label
var _aura: Label
var _notebook: Label
var _hint: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := ColorRect.new()
	panel.color = Color(0.05, 0.05, 0.07, 0.72)
	panel.position = Vector2(12, 12)
	panel.size = Vector2(PANEL_W, 470)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var y := 20.0
	_title = _label(Vector2(24, y), 17)
	y += 34
	y = _add_bar("superficial", "Superficial", Color(0.35, 0.75, 0.35), y)
	y = _add_bar("structural", "Structural", Color(0.85, 0.6, 0.2), y)
	y = _add_bar("catastrophic", "Catastrophic", Color(0.7, 0.15, 0.15), y)
	y += 6
	y = _add_bar("arm", "Striking arm", Color(0.6, 0.6, 0.7), y)
	y += 6
	y = _add_bar("essence", "Essence", Color(0.25, 0.55, 0.95), y)
	y = _add_bar("reflux", "Reflux [water]", Color(0.95, 0.5, 0.15), y)
	y += 6
	_money = _label(Vector2(24, y), 15)
	y += 24
	_aura = _label(Vector2(24, y), 15)
	_aura.add_theme_color_override("font_color", Color(0.85, 0.8, 1.0))
	y += 30
	_notebook = _label(Vector2(24, y), 14)
	_notebook.size = Vector2(PANEL_W - 24, 150)
	_notebook.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint = _label(Vector2(24, panel.size.y - 14), 13)
	_hint.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))


func refresh(player: Node, where: String) -> void:
	if str(player.get("talent_id")) == "":
		_title.text = "(no talent yet)"
		return
	var b: Body = player.get("body")
	var t: Dictionary = player.get("talent")
	_title.text = "%s   %d-star" % [str(t.get("name", "?")), int(player.get("stars"))]

	for layer: String in ["superficial", "structural", "catastrophic"]:
		_set_bar(layer, float(b.hp[layer]), float(b.max_hp[layer]), "%d / %d" % [int(ceil(float(b.hp[layer]))), int(float(b.max_hp[layer]))])
	var extra: Array[String] = player.call("status_lines")
	if not extra.is_empty():
		_bars["superficial"]["text"].text += "   (" + ", ".join(extra) + ")"

	if bool(player.get("arm_right_lost")):
		_set_bar("arm", 0.0, 1.0, "LOST - off-hand only")
		_bars["arm"]["fill"].color = Color(0.7, 0.15, 0.15)
	else:
		var arm: float = float(player.get("arm_right"))
		_set_bar("arm", arm, 100.0, "%d%%" % int(arm))
		_bars["arm"]["fill"].color = Color(0.6, 0.6, 0.7)

	var ess: float = float(player.get("essence"))
	var ess_max: float = float(player.get("essence_max"))
	_set_bar("essence", ess, ess_max, "%d / %d   +%d/s" % [int(ess), int(ess_max), int(float(player.get("satellite_rate")))])

	var reflux: float = float(player.get("reflux"))
	var locked: bool = bool(player.get("reflux_locked"))
	var rtext: String = "%d" % int(reflux)
	if locked:
		rtext += "   LOCKED - meditate"
	elif reflux >= 80.0:
		rtext += "   burning"
	elif reflux >= 50.0:
		rtext += "   costs +25%"
	_set_bar("reflux", reflux, 100.0, rtext)
	_bars["reflux"]["fill"].color = Color(0.85, 0.15, 0.1) if (locked or reflux >= 80.0) else (Color(0.95, 0.65, 0.15) if reflux >= 50.0 else Color(0.95, 0.5, 0.15))

	var cash: int = int(player.get("money"))
	_money.text = ("DEBT  $%d" % -cash if cash < 0 else "Money  $%d" % cash) + "      " + where
	_aura.text = str(player.call("aura_read"))

	var lines: Array[String] = []
	for p: String in player.get("discoveries"):
		lines.append("Proven: %s" % p)
	var log: Array = player.get("log_lines")
	for i: int in range(maxi(0, log.size() - 4), log.size()):
		lines.append("> %s" % str(log[i]))
	_notebook.text = "\n".join(lines)

	_hint.text = "%s controls   %s start over" % [Keybinds.binding_text("settings"), Keybinds.binding_text("restart")]


func _add_bar(name: String, title: String, color: Color, y: float) -> float:
	var lbl := _label(Vector2(24, y), 13)
	lbl.text = title
	lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	var back := ColorRect.new()
	back.color = Color(0.12, 0.12, 0.15, 0.9)
	back.position = Vector2(140, y + 2)
	back.size = Vector2(PANEL_W - 152, BAR_H)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	var fill := ColorRect.new()
	fill.color = color
	fill.position = back.position
	fill.size = Vector2(0, BAR_H)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)
	var text := _label(Vector2(146, y + 1), 12)
	text.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	text.add_theme_constant_override("outline_size", 4)
	_bars[name] = {"fill": fill, "text": text, "back": back}
	return y + BAR_H + 8


func _set_bar(name: String, value: float, max_value: float, text: String) -> void:
	var bar: Dictionary = _bars[name]
	var frac: float = clampf(value / max_value, 0.0, 1.0) if max_value > 0.0 else 0.0
	(bar["fill"] as ColorRect).size.x = (bar["back"] as ColorRect).size.x * frac
	(bar["text"] as Label).text = text


func _label(pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l
