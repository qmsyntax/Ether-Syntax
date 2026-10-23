class_name UiWidgets
extends RefCounted
## Small reusable controls for the menu screens.


## A procedural glyph in a framed square (see UiDraw.icon).
class Icon extends Control:
	var kind := "crate"
	var color := UiTheme.TEXT

	func _init(icon_kind: String, icon_color: Color = UiTheme.TEXT, px: float = 40.0) -> void:
		kind = icon_kind
		color = icon_color
		custom_minimum_size = Vector2(px, px)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var side: float = minf(size.x, size.y)
		var sq := Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))      # square even if the row stretches it
		UiDraw.frame(self, sq, "slot")
		UiDraw.icon(self, kind, sq.get_center(), side * 0.62, color)


## A framed bar with an optional caption drawn over it.
class Bar extends Control:
	var frac := 0.0
	var color := UiTheme.ESSENCE
	var caption := ""

	func _init(fraction: float, bar_color: Color, text: String = "", height: float = 16.0) -> void:
		frac = fraction
		color = bar_color
		caption = text
		custom_minimum_size = Vector2(120, height)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		UiDraw.bar(self, Rect2(Vector2(1, 1), size - Vector2(2, 2)), frac, color)
		if caption != "":
			var px: int = UiTheme.FS_CAPTION + 1 if size.y >= 18.0 else UiTheme.FS_CAPTION
			UiDraw.outlined(self, Vector2(0, size.y * 0.5 + float(px) * 0.36), caption, px, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, size.x)


## A tooltip that wraps (the default one runs a long definition off the screen).
static func wrapped_tip(text: String) -> Control:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(minf(380.0, 9.0 * float(text.length()) + 20.0), 0)
	l.add_theme_font_size_override("font_size", UiTheme.FS_SMALL)
	l.add_theme_color_override("font_color", UiTheme.TEXT)
	return l


## A status's name as a small chip in its colour. Its definition (StatusText) is its tooltip, and a
## click shows or hides the definition in place (not hover-only: the technical preferences).
class StatusChip extends Button:
	var status_id := ""
	var tip_lasts := -1.0

	func _init(id: String, lasts: float = -1.0) -> void:
		status_id = StatusText.resolve(id)
		tip_lasts = lasts
		name = "StatusTerm_%s" % status_id
		text = StatusText.label(id)
		focus_mode = Control.FOCUS_NONE
		tooltip_text = StatusText.definition(status_id, lasts)
		var col := Color(str(StatusText.def_of(id).get("color", "d2ab52")))
		var normal := UiTheme.box(Color(0, 0, 0, 0.35), col.darkened(0.25), 1, 3, 4)
		normal.content_margin_left = 8
		normal.content_margin_right = 8
		normal.content_margin_top = 1
		normal.content_margin_bottom = 1
		var hover: StyleBoxFlat = normal.duplicate()
		hover.border_color = col.lightened(0.2)
		hover.bg_color = Color(col, 0.16)
		add_theme_stylebox_override("normal", normal)
		add_theme_stylebox_override("hover", hover)
		add_theme_stylebox_override("pressed", hover)
		add_theme_stylebox_override("focus", normal)
		add_theme_font_size_override("font_size", 14)
		add_theme_color_override("font_color", col.lightened(0.3))
		add_theme_color_override("font_hover_color", col.lightened(0.5))
		add_theme_color_override("font_pressed_color", col.lightened(0.5))
		size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _make_custom_tooltip(for_text: String) -> Object:
		return UiWidgets.wrapped_tip(for_text)


## One status: a row with its chip (and `note` beside it - how long, how many), and its definition
## under it - the desc and the rules line - shown when `open`, or after a click on the chip.
class StatusEntry extends VBoxContainer:
	var chip: StatusChip
	var body: VBoxContainer

	func _init(id: String, note: String = "", lasts: float = -1.0, open: bool = false, note_color: Color = UiTheme.TEXT_DIM) -> void:
		var sid: String = StatusText.resolve(id)
		name = "StatusEntry_%s" % sid
		add_theme_constant_override("separation", 2)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		add_child(row)
		chip = StatusChip.new(sid, lasts)
		row.add_child(chip)
		if note != "":
			var n := UiTheme.body(note, 13, note_color)
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(n)
		body = VBoxContainer.new()
		body.name = "StatusDef_%s" % sid
		body.add_theme_constant_override("separation", 1)
		body.visible = open
		add_child(body)
		var d: String = StatusText.desc(sid)
		if d != "":
			var dl := UiTheme.body(d, 13, UiTheme.TEXT)
			dl.name = "StatusDesc"
			body.add_child(dl)
		var rl := UiTheme.body(StatusText.rules(sid, lasts, not (note != "" and lasts >= 0.0)), 12, UiTheme.TEXT_DIM)      # the time is in the note
		rl.name = "StatusRules"
		body.add_child(rl)
		chip.pressed.connect(toggle)

	## Show or hide the definition (what a click on the name does).
	func toggle() -> void:
		body.visible = not body.visible


## A line of text that may name statuses (a rune's "+1 stack of Brittle"): a plain Label when it
## names none; otherwise the same Label with the statuses' definitions as its tooltip, and a click
## on it shows them in place under it.
static func status_line(text: String, px: int, color: Color) -> Control:
	var ids: Array[String] = StatusText.mentioned(text)
	if ids.is_empty():
		return UiTheme.body(text, px, color)
	var col := VBoxContainer.new()
	col.name = "StatusLine"
	col.add_theme_constant_override("separation", 1)
	var l := TipLabel.new()
	l.text = text
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	l.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	l.tooltip_text = "\n\n".join(PackedStringArray(ids.map(func(id: String) -> String: return StatusText.definition(id))))
	col.add_child(l)
	var defs := VBoxContainer.new()
	defs.name = "StatusLineDefs"
	defs.visible = false
	defs.add_theme_constant_override("separation", 1)
	col.add_child(defs)
	for id: String in ids:
		defs.add_child(UiTheme.body("      %s: %s" % [StatusText.label(id), StatusText.desc(id)], px - 1, UiTheme.TEXT))
		defs.add_child(UiTheme.body("      " + StatusText.rules(id), px - 2, UiTheme.TEXT_DIM))
	l.gui_input.connect(func(ev: InputEvent) -> void:
		var mb := ev as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			defs.visible = not defs.visible
			if l.is_inside_tree():
				l.accept_event())
	return col


## A Label whose tooltip wraps.
class TipLabel extends Label:
	func _make_custom_tooltip(for_text: String) -> Object:
		return UiWidgets.wrapped_tip(for_text)


## A big clickable row: bold title, smaller description underneath, optional price on the right.
static func service_button(title: String, desc: String, right: String, on_press: Callable, enabled: bool = true) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 64 if desc != "" else 44)
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -14
	row.offset_top = 6
	row.offset_bottom = -6
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var t := UiTheme.body(title, 18, UiTheme.TEXT if enabled else UiTheme.TEXT_FAINT)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(t)
	if desc != "":
		var d := UiTheme.body(desc, 13, UiTheme.TEXT_DIM if enabled else UiTheme.TEXT_FAINT)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(d)
	if right != "":
		var r := UiTheme.body(right, 17, UiTheme.GOLD if enabled else UiTheme.TEXT_FAINT)
		r.autowrap_mode = TextServer.AUTOWRAP_OFF
		r.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(r)
	return b


static func small_button(text: String, on_press: Callable, enabled: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	return b


## "Label ........ value" on one line.
static func stat_row(label: String, value: String, value_color: Color = UiTheme.TEXT) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := UiTheme.body(label, 15, UiTheme.TEXT_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var v := UiTheme.body(value, 15, value_color)
	v.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(v)
	return row


## Human-readable summary of what an item does.
static func item_stats_text(def: Dictionary) -> String:
	var parts: Array[String] = []
	var stats: Dictionary = def.get("stats", {})
	if stats.has("melee_damage_mult"):
		parts.append("strikes hit %d%% harder" % int(round((float(stats["melee_damage_mult"]) - 1.0) * 100.0)))
	if stats.has("melee_cooldown_mult"):
		var cd: float = float(stats["melee_cooldown_mult"])
		parts.append(("strikes %d%% faster" % int(round((1.0 / cd - 1.0) * 100.0))) if cd < 1.0 else ("strikes %d%% slower" % int(round((1.0 - 1.0 / cd) * 100.0))))
	if stats.has("melee_range_bonus"):
		parts.append("+%.1f m reach" % float(stats["melee_range_bonus"]))
	if stats.has("armour"):
		parts.append("takes %d%% off every hit" % int(float(stats["armour"])))
	if stats.has("ranged_damage_mult") or stats.has("ranged_interval") or stats.has("ranged_range"):
		parts.append("shoots for %d every %.1f s, out to %d m" % [
			int(round(GameData.num("ranged", "ranged_damage") * float(stats.get("ranged_damage_mult", 1.0)))),
			float(stats.get("ranged_interval", GameData.num("ranged", "default_interval"))),
			int(float(stats.get("ranged_range", GameData.num("ranged", "default_range"))))])
	if stats.has("ranged_interval_mult"):
		parts.append("shoots %d%% sooner" % int(round((1.0 - float(stats["ranged_interval_mult"])) * 100.0)))
	if stats.has("carry_capacity"):
		parts.append("carry +%d kg" % int(float(stats["carry_capacity"])))
	if stats.has("satellite_rate"):
		parts.append("+%d essence per second" % int(float(stats["satellite_rate"])))
	if stats.has("cost_mult"):
		parts.append("abilities cost %d%% less" % int(round((1.0 - float(stats["cost_mult"])) * 100.0)))
	if stats.has("reflux_shed_mult"):
		parts.append("reflux sheds %d%% faster" % int(round((float(stats["reflux_shed_mult"]) - 1.0) * 100.0)))
	return ", ".join(parts)
