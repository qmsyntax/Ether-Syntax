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
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), UiTheme.INSET)
		draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BRONZE_DIM, false, 1.0)
		UiDraw.icon(self, kind, size * 0.5, minf(size.x, size.y) * 0.62, color)


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
			UiDraw.text(self, Vector2(0, size.y * 0.5 + 5.0), caption, 13, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, size.x)


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
	if stats.has("carry_capacity"):
		parts.append("carry +%d kg" % int(float(stats["carry_capacity"])))
	if stats.has("satellite_rate"):
		parts.append("+%d essence per second" % int(float(stats["satellite_rate"])))
	if stats.has("cost_mult"):
		parts.append("abilities cost %d%% less" % int(round((1.0 - float(stats["cost_mult"])) * 100.0)))
	if stats.has("reflux_shed_mult"):
		parts.append("reflux sheds %d%% faster" % int(round((float(stats["reflux_shed_mult"]) - 1.0) * 100.0)))
	return ", ".join(parts)
