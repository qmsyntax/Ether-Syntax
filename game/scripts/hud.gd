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
var _slots: Array = []              # per hotbar slot: {panel, key, name, fill, back, info}

const SLOT_W := 150.0
const SLOT_H := 64.0


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


## The hotbar is built on first refresh, once the player's slot count is known.
func _build_hotbar(count: int) -> void:
	var total_w: float = count * SLOT_W + (count - 1) * 8.0
	var x0: float = (get_viewport_rect().size.x - total_w) * 0.5
	var y: float = get_viewport_rect().size.y - SLOT_H - 16.0
	for i: int in count:
		var x: float = x0 + i * (SLOT_W + 8.0)
		var bg := ColorRect.new()
		bg.color = Color(0.05, 0.05, 0.07, 0.8)
		bg.position = Vector2(x, y)
		bg.size = Vector2(SLOT_W, SLOT_H)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		var key := _label(Vector2(x + 6, y + 3), 13)
		key.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		var nm := _label(Vector2(x + 6, y + 20), 14)
		var back := ColorRect.new()
		back.color = Color(0.15, 0.15, 0.18)
		back.position = Vector2(x + 6, y + SLOT_H - 12)
		back.size = Vector2(SLOT_W - 12, 6)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(back)
		var fill := ColorRect.new()
		fill.color = Color(0.55, 0.8, 1.0)
		fill.position = back.position
		fill.size = Vector2(0, 6)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(fill)
		var info := _label(Vector2(x + 6, y + 38), 11)
		info.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		_slots.append({"bg": bg, "key": key, "name": nm, "fill": fill, "back": back, "info": info})


func _refresh_hotbar(player: Node) -> void:
	var hotbar: Array = player.get("hotbar")
	if _slots.is_empty():
		_build_hotbar(hotbar.size())
	var abilities: Array = player.get("abilities")
	var essence: float = float(player.get("essence"))
	var locked: bool = bool(player.get("reflux_locked"))
	for i: int in _slots.size():
		var s: Dictionary = _slots[i]
		(s["key"] as Label).text = Keybinds.binding_text("ability_%d" % (i + 1))
		var idx: int = int(hotbar[i])
		if idx < 0 or idx >= abilities.size():
			(s["name"] as Label).text = "(empty)"
			(s["info"] as Label).text = ""
			(s["fill"] as ColorRect).size.x = 0.0
			continue
		var st: Dictionary = abilities[idx]
		var ab: Dictionary = GameData.ability(str(st["id"]))
		(s["name"] as Label).text = str(ab.get("name", "?"))
		var need: String = player.call("pending_tier", st)
		if need != "":
			(s["info"] as Label).text = "stage %d FULL - needs a %s" % [int(st["stage"]), need]
		else:
			(s["info"] as Label).text = "stage %d   %d essence" % [int(st["stage"]), int(float(player.call("ability_stats", st).get("cost", 0)))]
		(s["fill"] as ColorRect).size.x = (s["back"] as ColorRect).size.x * clampf(float(st["progress"]) / 100.0, 0.0, 1.0)
		var usable: bool = not locked and essence >= float(player.call("ability_stats", st).get("cost", 0.0))
		(s["bg"] as ColorRect).color = Color(0.05, 0.05, 0.07, 0.8) if usable else Color(0.25, 0.05, 0.05, 0.8)


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
	var pcts: Array = player.get("star_pct")
	var star_txt: Array[String] = []
	for i: int in pcts.size():
		star_txt.append("star %d  %d%%" % [i + 1, int(float(pcts[i]))])
	_aura.text = "%s      %s" % ["   ".join(star_txt), str(player.call("aura_read"))]

	var lines: Array[String] = []
	var held: Array = player.get("constructs")
	if not held.is_empty():
		var names: Array[String] = []
		for c: Dictionary in held:
			names.append("%s of %s" % [str(c["tier"]), str(GameData.concept(str(c["concept"])).get("label", c["concept"]))])
		lines.append("Carrying: %s   (%s to bind)" % [", ".join(names), Keybinds.binding_text("bind")])
	for p: String in player.get("discoveries"):
		lines.append("Proven: %s" % p)
	var log: Array = player.get("log_lines")
	for i: int in range(maxi(0, log.size() - 4), log.size()):
		lines.append("> %s" % str(log[i]))
	_notebook.text = "\n".join(lines)

	_hint.text = "%s controls   %s start over" % [Keybinds.binding_text("settings"), Keybinds.binding_text("restart")]
	_refresh_hotbar(player)


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
