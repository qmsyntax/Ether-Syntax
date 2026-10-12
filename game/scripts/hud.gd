extends Control
## In-game HUD, drawn procedurally (no image assets):
##   bottom centre  - health orb | action bar | essence orb, star-growth bar above the slots
##                    ring round the health orb = striking arm; ring round the essence orb = reflux
##   top left       - character plate (talent, stars, money, where you are, carried constructs)
##   top centre     - target frame for the enemy under the cursor, and the prompt strip
##   bottom left    - message log that fades
##   over the world - enemy health bars
## The HUD only reads the player; it never changes game state.

const ORB_R := 58.0
const SLOT := 58.0
const SLOT_GAP := 6.0
const LOG_SECONDS := 9.0
const LOG_MAX := 6

var player: Node
var where := ""
var prompt := ""
var title := ""                    # big, brief announcement ("WALL 3")
var show_world := true             # false on menu screens: hide bars, orbs stay

var _time := 0.0
var _title_age := 99.0
var _log: Array = []               # [{text, age}]
var _log_seen := 0
var _hurt_flash := 0.0
var _last_hp := -1.0
var _bar_rect := Rect2()
var _plate_rect := Rect2()
var _slot_rects: Array[Rect2] = []
var _health_c := Vector2.ZERO
var _essence_c := Vector2.ZERO
## Passage progress for the tracker: {walls, cleared, current, gate, bank} or {} when not in one.
var passage: Dictionary = {}
## While the soul is out in the Netherecho: {hp, hp_max, leash, at_leash, gathered, subdued, hovered, target}.
var nether: Dictionary = {}
## Screenshot aid: force a tooltip ("slot:0", "health", "essence") without a real cursor.
var debug_tip := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func refresh(p: Node, where_text: String) -> void:
	player = p
	where = where_text


func set_prompt(text: String) -> void:
	prompt = text


func set_nether(info: Dictionary) -> void:
	nether = info


func set_passage(info: Dictionary) -> void:
	passage = info


func announce(text: String) -> void:
	title = text
	_title_age = 0.0


## True when the cursor is over a HUD panel, so a click there is not also an attack order.
func mouse_over_ui() -> bool:
	var m: Vector2 = get_local_mouse_position()
	return _bar_rect.has_point(m) or _plate_rect.has_point(m)


func _process(delta: float) -> void:
	_time += delta
	_title_age += delta
	_hurt_flash = maxf(0.0, _hurt_flash - delta * 2.5)
	for entry: Dictionary in _log:
		entry["age"] = float(entry["age"]) + delta
	if player != null and str(player.get("talent_id")) != "":
		var serial: int = int(player.get("log_serial"))
		var lines: Array = player.get("log_lines")
		var fresh: int = mini(serial - _log_seen, lines.size())
		for i: int in range(lines.size() - fresh, lines.size()):
			_log.append({"text": str(lines[i]), "age": 0.0})
		_log_seen = serial
		while _log.size() > LOG_MAX:
			_log.remove_at(0)
		var hp: float = (player.get("body") as Body).total()
		if _last_hp >= 0.0 and hp < _last_hp - 0.5:
			_hurt_flash = 1.0
		_last_hp = hp
	queue_redraw()


func _draw() -> void:
	if player == null or str(player.get("talent_id")) == "":
		return
	var vs: Vector2 = size
	if not nether.is_empty():
		_draw_nether_veil(vs)
	if show_world:
		_draw_enemy_bars()
		_draw_vignette(vs)
		_draw_target_frame(vs)
		_draw_prompt(vs)
		_draw_title(vs)
		_draw_log(vs)
		_draw_tracker(vs)
		if not nether.is_empty():
			_draw_nether_status(vs)
	_draw_plate()
	_draw_action_bar(vs)
	_draw_tooltip(vs)


# --- bottom: orbs and action bar ------------------------------------------------------

func _draw_action_bar(vs: Vector2) -> void:
	var hotbar: Array = player.get("hotbar")
	var n: int = hotbar.size()
	var slots_w: float = n * SLOT + (n - 1) * SLOT_GAP
	var cx: float = vs.x * 0.5
	var base_y: float = vs.y - 30.0
	var slab := Rect2(cx - slots_w * 0.5 - 22.0, base_y - SLOT - 30.0, slots_w + 44.0, SLOT + 44.0)
	var left_c := Vector2(slab.position.x - ORB_R + 6.0, base_y - ORB_R + 2.0)
	var right_c := Vector2(slab.end.x + ORB_R - 6.0, base_y - ORB_R + 2.0)
	_bar_rect = Rect2(left_c.x - ORB_R - 16.0, slab.position.y - 24.0, (right_c.x - left_c.x) + 2.0 * ORB_R + 32.0, vs.y - slab.position.y + 24.0)

	# stone slab
	draw_rect(slab.grow(3.0), Color(0, 0, 0, 0.6))
	draw_rect(slab, UiTheme.PANEL)
	draw_rect(Rect2(slab.position, Vector2(slab.size.x, 3.0)), UiTheme.PANEL_HI)
	draw_rect(slab, UiTheme.BRONZE, false, 2.0)

	# star growth bar across the top of the slab
	var pcts: Array = player.get("star_pct")
	var newest: float = float(pcts.back()) if not pcts.is_empty() else 0.0
	var star_rect := Rect2(slab.position.x + 22.0, slab.position.y + 9.0, slots_w, 7.0)
	UiDraw.bar(self, star_rect, newest / 99.0, UiTheme.STAR)
	UiDraw.text(self, Vector2(star_rect.position.x, star_rect.position.y - 5.0),
		"Star %d   %d%%" % [pcts.size(), int(newest)], 12, UiTheme.STAR)
	UiDraw.text(self, Vector2(star_rect.position.x, star_rect.position.y - 5.0),
		str(player.call("aura_read")), 12, UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT, slots_w)

	# ability slots
	var abilities: Array = player.get("abilities")
	var essence: float = float(player.get("essence"))
	var locked := false               # per slot now: an ability is locked when its own affinity is
	_slot_rects.clear()
	for i: int in n:
		var r := Rect2(slab.position.x + 22.0 + i * (SLOT + SLOT_GAP), slab.position.y + 26.0, SLOT, SLOT)
		_slot_rects.append(r)
		_draw_slot(r, i, int(hotbar[i]), abilities, essence, locked)

	_health_c = left_c
	_essence_c = right_c
	_draw_health_orb(left_c)
	_draw_essence_orb(right_c)

	# small print: pack weight and the two keys worth remembering
	var inv: Inventory = player.get("inventory")
	_right_text(Vector2(vs.x - 16.0, vs.y - 30.0), "Pack  %d / %d kg" % [int(inv.weight()), int(inv.capacity())],
		13, UiTheme.BAD if inv.weight() > inv.capacity() * 0.9 else UiTheme.TEXT_DIM)
	_right_text(Vector2(vs.x - 16.0, vs.y - 12.0), "%s  project      %s  soul      %s  inventory      %s  controls" % [Keybinds.binding_text("project"), Keybinds.binding_text("ethercosm"), Keybinds.binding_text("inventory"), Keybinds.binding_text("settings")], 13, UiTheme.TEXT_FAINT)


func _draw_slot(r: Rect2, i: int, idx: int, abilities: Array, essence: float, locked: bool) -> void:
	draw_rect(r, UiTheme.INSET)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2.0)), Color(0, 0, 0, 0.6))
	var border: Color = UiTheme.BRONZE_DIM
	if idx >= 0 and idx < abilities.size():
		var st: Dictionary = abilities[idx]
		var ab: Dictionary = player.call("ability_stats", st)
		var cost: float = float(ab.get("cost", 0.0))
		var aff: String = str(ab.get("affinity", ""))
		locked = bool(player.call("is_locked", aff))
		var usable: bool = not locked and essence >= cost
		var tint: Color = GameData.affinity_color(aff).lightened(0.3) if usable else Color(0.35, 0.36, 0.4)
		UiDraw.icon(self, str(ab.get("icon", "drop")), r.get_center() + Vector2(0, -2), SLOT * 0.5, tint)
		# stage pips, top right
		for s: int in int(st["stage"]):
			draw_circle(Vector2(r.end.x - 7.0 - s * 7.0, r.position.y + 8.0), 2.6, UiTheme.GOLD)
		# cost, bottom right
		_right_text(Vector2(r.end.x - 4.0, r.end.y - 9.0), str(int(round(cost))), 12, UiTheme.ESSENCE.lightened(0.4) if usable else UiTheme.BAD)
		# progress along the bottom
		var prog: float = clampf(float(st["progress"]) / 100.0, 0.0, 1.0)
		draw_rect(Rect2(r.position.x + 2.0, r.end.y - 5.0, r.size.x - 4.0, 3.0), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(r.position.x + 2.0, r.end.y - 5.0, (r.size.x - 4.0) * prog, 3.0), UiTheme.GOLD if prog >= 1.0 else UiTheme.ESSENCE)
		var need: String = str(player.call("pending_tier", st))
		if need != "":
			# full and waiting for a construct: pulsing gold frame and a gem
			var pulse: float = 0.55 + 0.45 * sin(_time * 4.0)
			border = UiTheme.GOLD.lerp(Color(1, 1, 1), pulse * 0.4)
			UiDraw.icon(self, "gem", Vector2(r.position.x + 11.0, r.end.y - 16.0), 13.0, UiTheme.GOLD)
		if not usable:
			draw_rect(r, Color(0, 0, 0, 0.45))
		if locked:
			draw_line(r.position + Vector2(8, 8), r.end - Vector2(8, 8), UiTheme.REFLUX_HOT, 3.0, true)
	draw_rect(r, border, false, 2.0 if border != UiTheme.BRONZE_DIM else 1.0)
	UiDraw.text(self, r.position + Vector2(4.0, 14.0), Keybinds.binding_text("ability_%d" % (i + 1)), 12, UiTheme.GOLD)


func _draw_health_orb(c: Vector2) -> void:
	var b: Body = player.get("body")
	var total_max: float = b.total_max()
	var bands: Array = [
		[float(b.hp["catastrophic"]) / total_max, UiTheme.HEALTH_CATASTROPHIC],
		[float(b.hp["structural"]) / total_max, UiTheme.HEALTH_STRUCTURAL],
		[float(b.hp["superficial"]) / total_max, UiTheme.HEALTH_SUPERFICIAL],
	]
	# ring = striking arm
	var arm_lost: bool = bool(player.get("arm_right_lost"))
	var arm: float = 0.0 if arm_lost else float(player.get("arm_right")) / 100.0
	UiDraw.ring(self, c, ORB_R + 12.0, arm, Color(0.72, 0.74, 0.82) if arm > 0.3 else UiTheme.BAD)
	UiDraw.orb(self, c, ORB_R, bands, _time, UiTheme.BRONZE)
	if _hurt_flash > 0.0:
		draw_circle(c, ORB_R, Color(1, 0.2, 0.15, 0.35 * _hurt_flash))
	_centre_text(c + Vector2(0, 6.0), "%d" % int(ceil(b.total())), 24, UiTheme.TEXT)
	_centre_text(c + Vector2(0, 22.0), "of %d" % int(total_max), 12, UiTheme.TEXT_DIM)
	var extra: Array[String] = player.call("status_lines")
	if not extra.is_empty():
		_centre_text(c + Vector2(0, -ORB_R - 34.0), extra[0], 13, Color(0.75, 0.75, 1.0))
	if arm_lost:
		_centre_text(c + Vector2(0, -ORB_R - 20.0), "ARM LOST", 14, UiTheme.BAD)
	else:
		_centre_text(c + Vector2(0, -ORB_R - 20.0), "arm %d%%" % int(arm * 100.0), 12, UiTheme.TEXT_DIM)


func _draw_essence_orb(c: Vector2) -> void:
	var ess: float = float(player.get("essence"))
	var ess_max: float = maxf(1.0, float(player.get("essence_max")))
	var frac: float = clampf(ess / ess_max, 0.0, 1.0)
	var bands: Array = [[frac * 0.45, UiTheme.ESSENCE_DEEP], [frac * 0.55, UiTheme.ESSENCE]]
	# one reflux ring per affinity, the first innermost; the text speaks for the hottest
	var affs: Array = player.get("affinities")
	var reflux := 0.0
	var locked := false
	var hottest := ""
	for i: int in affs.size():
		var a: String = str(affs[i])
		var heat: float = float(player.call("reflux_of", a))
		var a_locked: bool = bool(player.call("is_locked", a))
		var a_hot: bool = a_locked or heat >= 80.0
		var ring_col: Color = UiTheme.REFLUX_HOT if a_hot else (UiTheme.REFLUX if heat >= 50.0 else UiTheme.REFLUX.darkened(0.25))
		if a_locked:
			ring_col = ring_col.lerp(Color(1, 1, 1), 0.3 + 0.3 * sin(_time * 8.0))
		UiDraw.ring(self, c, ORB_R + 12.0 + i * 9.0, heat / 100.0, ring_col, [0.5, 0.8])
		if affs.size() > 1:
			# a pip in the affinity's colour at the ring's start, so the rings can be told apart
			draw_circle(c + Vector2(0.0, -(ORB_R + 12.0 + i * 9.0)), 3.5, GameData.affinity_color(a))
		if hottest == "" or heat > reflux or (a_locked and not locked):
			hottest = a
			reflux = heat
			locked = a_locked
	var which: String = (str(GameData.affinity(hottest).get("label", hottest)).to_lower() + " ") if affs.size() > 1 else ""
	var lift: float = maxf(0.0, float(affs.size() - 1)) * 9.0
	UiDraw.orb(self, c, ORB_R, bands, _time + 1.7, UiTheme.BRONZE)
	_centre_text(c + Vector2(0, 6.0), "%d" % int(ess), 24, UiTheme.TEXT)
	_centre_text(c + Vector2(0, 22.0), "of %d" % int(ess_max), 12, UiTheme.TEXT_DIM)
	var rate: float = float(player.get("satellite_rate"))
	var note_text: String = "%sreflux %d" % [which, int(reflux)]
	var note_col: Color = UiTheme.TEXT_DIM
	if locked:
		note_text = "%sLOCKED - meditate (%s)" % [which.to_upper(), Keybinds.binding_text("meditate")]
		note_col = UiTheme.REFLUX_HOT
	elif reflux >= 80.0:
		note_text = "%sreflux %d - burning" % [which, int(reflux)]
		note_col = UiTheme.REFLUX_HOT
	elif reflux >= 50.0:
		note_text = "%sreflux %d - costs more" % [which, int(reflux)]
		note_col = UiTheme.REFLUX
	_centre_text(c + Vector2(0, -ORB_R - 20.0 - lift), note_text, 12 if not locked else 14, note_col)
	if bool(player.get("meditating")):
		_centre_text(c + Vector2(0, -ORB_R - 36.0 - lift), "gathering", 13, UiTheme.ESSENCE.lightened(0.4))
	elif rate > 0.0:
		_centre_text(c + Vector2(0, -ORB_R - 36.0 - lift), "satellite +%d/s" % int(rate), 12, UiTheme.TEXT_FAINT)
	else:
		_centre_text(c + Vector2(0, -ORB_R - 36.0 - lift), "no satellite", 12, UiTheme.TEXT_FAINT)


# --- top left: character plate ----------------------------------------------------------

func _draw_plate() -> void:
	var t: Dictionary = player.get("talent")
	var held: Array = player.get("constructs")
	var who: String = str(player.get("char_name"))
	var named: float = 20.0 if who != "" else 0.0          # a named character gets a line for the talent
	var h: float = 78.0 + named + (26.0 if not held.is_empty() else 0.0)
	var r := Rect2(14.0, 14.0, 330.0, h)
	_plate_rect = r
	draw_rect(r.grow(3.0), Color(0, 0, 0, 0.55))
	draw_rect(r, Color(UiTheme.PANEL, 0.92))
	draw_rect(r, UiTheme.BRONZE, false, 2.0)
	UiDraw.text(self, r.position + Vector2(14.0, 27.0), who if who != "" else str(t.get("name", "?")), 21, UiTheme.GOLD)
	if who != "":
		UiDraw.text(self, r.position + Vector2(14.0, 46.0), str(t.get("name", "?")), 14, UiTheme.STAR)
	r.position.y += named
	# star pips, right-aligned on the title line
	var stars: int = int(player.get("stars"))
	for i: int in stars:
		var c := Vector2(r.end.x - 18.0 - i * 20.0, r.position.y + 20.0)
		draw_circle(c, 7.0, UiTheme.STAR.darkened(0.5))
		draw_circle(c, 5.0, UiTheme.STAR)
	var cash: int = int(player.get("money"))
	UiDraw.icon(self, "coin", r.position + Vector2(22.0, 46.0), 16.0, UiTheme.BAD if cash < 0 else UiTheme.GOLD)
	UiDraw.text(self, r.position + Vector2(36.0, 52.0), UiTheme.money_text(cash), 16, UiTheme.BAD if cash < 0 else UiTheme.TEXT)
	UiDraw.text(self, r.position + Vector2(14.0, 70.0), where, 13, UiTheme.TEXT_DIM)
	if not held.is_empty():
		var x: float = r.position.x + 22.0
		for c: Dictionary in held:
			UiDraw.icon(self, "gem", Vector2(x, r.position.y + 90.0), 14.0, UiTheme.GOLD if str(c["tier"]) == "vestige" else UiTheme.STAR)
			x += 18.0
		UiDraw.text(self, Vector2(x + 4.0, r.position.y + 95.0), "%d to bind  (%s)" % [held.size(), Keybinds.binding_text("bind")], 13, UiTheme.TEXT_DIM)


# --- top centre: target frame, prompt, title ---------------------------------------------

func _draw_target_frame(vs: Vector2) -> void:
	var target: Variant = player.get("hovered")
	if not nether.is_empty():
		# out of the body, the projection's target is what matters
		target = nether.get("hovered")
		if target == null or not is_instance_valid(target):
			target = nether.get("target")
		if target == null or not is_instance_valid(target) or (target as Node).get("body") == null:
			return
	if target == null or not is_instance_valid(target) or (target as Node).get("is_scenery") == true or (target as Node).get("is_pickup") != null:
		target = player.get("attack_target")
	if target == null or not is_instance_valid(target) or (target as Node).get("is_scenery") == true or (target as Node).get("body") == null:
		return
	var node := target as Node
	var b: Body = node.get("body")
	var r := Rect2(vs.x * 0.5 - 170.0, 14.0, 340.0, 46.0)
	draw_rect(r.grow(3.0), Color(0, 0, 0, 0.55))
	draw_rect(r, Color(UiTheme.PANEL, 0.92))
	draw_rect(r, UiTheme.BRONZE, false, 2.0)
	var name_text: String = str(node.get("display_name")) if node.get("display_name") != null else "Enemy"
	UiDraw.text(self, r.position + Vector2(0.0, 19.0), name_text, 16, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	UiDraw.bar(self, Rect2(r.position.x + 12.0, r.position.y + 27.0, r.size.x - 24.0, 10.0), b.total() / b.total_max(), UiTheme.HEALTH_SUPERFICIAL)
	UiDraw.text(self, Vector2(r.position.x, r.position.y + 37.0), "%d / %d" % [int(ceil(b.total())), int(b.total_max())], 11, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _draw_prompt(vs: Vector2) -> void:
	if prompt == "":
		return
	var f: Font = UiTheme.font()
	var lines: PackedStringArray = prompt.split("\n")
	var w := 0.0
	for line: String in lines:
		w = maxf(w, f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x)
	var r := Rect2(vs.x * 0.5 - w * 0.5 - 18.0, 72.0, w + 36.0, lines.size() * 22.0 + 14.0)
	draw_rect(r, Color(0.04, 0.035, 0.03, 0.72))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1.0)), UiTheme.BRONZE_DIM)
	draw_rect(Rect2(r.position.x, r.end.y - 1.0, r.size.x, 1.0), UiTheme.BRONZE_DIM)
	for i: int in lines.size():
		UiDraw.text(self, Vector2(r.position.x, r.position.y + 23.0 + i * 22.0), lines[i], 16, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _draw_title(vs: Vector2) -> void:
	if title == "" or _title_age > 2.6:
		return
	var a: float = clampf(1.0 - maxf(0.0, _title_age - 1.6), 0.0, 1.0) * clampf(_title_age * 4.0, 0.0, 1.0)
	var col := Color(UiTheme.GOLD, a)
	var f: Font = UiTheme.font()
	draw_string(f, Vector2(2.0, vs.y * 0.3 + 2.0), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 46, Color(0, 0, 0, a * 0.8))
	draw_string(f, Vector2(0.0, vs.y * 0.3), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 46, col)


# --- bottom left: message log ---------------------------------------------------------------

func _draw_log(vs: Vector2) -> void:
	var y: float = vs.y - 170.0
	for i: int in range(_log.size() - 1, -1, -1):
		var entry: Dictionary = _log[i]
		var age: float = float(entry["age"])
		if age > LOG_SECONDS:
			continue
		var a: float = clampf((LOG_SECONDS - age) / 2.0, 0.0, 1.0)
		UiDraw.text(self, Vector2(18.0, y), str(entry["text"]), 14, Color(UiTheme.TEXT, a * (1.0 if i == _log.size() - 1 else 0.8)), HORIZONTAL_ALIGNMENT_LEFT, 420.0)
		y -= 20.0


# --- over the world ---------------------------------------------------------------------------

func _draw_enemy_bars() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	for node: Node in get_tree().get_nodes_in_group("nether_enemies" if not nether.is_empty() else "enemies"):
		var e := node as Node3D
		if e == null or cam.is_position_behind(e.global_position):
			continue
		var b: Body = e.get("body")
		if b == null or b.is_dead():
			continue
		var lit: bool = int(e.get("highlight")) > 0
		if b.total() >= b.total_max() and not lit:
			continue                      # untouched enemies show no bar - less clutter
		var top: Vector2 = cam.unproject_position(e.global_position + Vector3.UP * (float(e.get("height")) + 0.35))
		var w: float = 46.0 + float(e.get("radius")) * 22.0
		UiDraw.bar(self, Rect2(top.x - w * 0.5, top.y - 4.0, w, 5.0), b.total() / b.total_max(), UiTheme.HEALTH_SUPERFICIAL if not lit else Color("f0563f"))


func _draw_vignette(vs: Vector2) -> void:
	var b: Body = player.get("body")
	var frac: float = b.total() / b.total_max()
	var danger: float = clampf((0.4 - frac) / 0.4, 0.0, 1.0)
	var a: float = danger * (0.22 + 0.1 * sin(_time * 4.5)) + _hurt_flash * 0.12
	if a <= 0.01:
		return
	# four gradient bands, opaque at the screen edge and clear toward the middle
	var c0 := Color(0.62, 0.04, 0.03, a)
	var c1 := Color(0.62, 0.04, 0.03, 0.0)
	var e: float = minf(vs.x, vs.y) * 0.22
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(vs.x, 0), Vector2(vs.x, e), Vector2(0, e)]), PackedColorArray([c0, c0, c1, c1]))
	draw_polygon(PackedVector2Array([Vector2(0, vs.y - e), Vector2(vs.x, vs.y - e), Vector2(vs.x, vs.y), Vector2(0, vs.y)]), PackedColorArray([c1, c1, c0, c0]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(e, 0), Vector2(e, vs.y), Vector2(0, vs.y)]), PackedColorArray([c0, c1, c1, c0]))
	draw_polygon(PackedVector2Array([Vector2(vs.x - e, 0), Vector2(vs.x, 0), Vector2(vs.x, vs.y), Vector2(vs.x - e, vs.y)]), PackedColorArray([c1, c0, c0, c1]))


# --- the Netherecho ---------------------------------------------------------------------------

## A cold violet wash over the world, darker at the edges: you are looking at the echo, not the place.
func _draw_nether_veil(vs: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.16, 0.08, 0.34, 0.26))
	var c0 := Color(0.05, 0.0, 0.16, 0.7)
	var c1 := Color(0.05, 0.0, 0.16, 0.0)
	var e: float = minf(vs.x, vs.y) * 0.3
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(vs.x, 0), Vector2(vs.x, e), Vector2(0, e)]), PackedColorArray([c0, c0, c1, c1]))
	draw_polygon(PackedVector2Array([Vector2(0, vs.y - e), Vector2(vs.x, vs.y - e), Vector2(vs.x, vs.y), Vector2(0, vs.y)]), PackedColorArray([c1, c1, c0, c0]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(e, 0), Vector2(e, vs.y), Vector2(0, vs.y)]), PackedColorArray([c0, c1, c1, c0]))
	draw_polygon(PackedVector2Array([Vector2(vs.x - e, 0), Vector2(vs.x, 0), Vector2(vs.x, vs.y), Vector2(vs.x - e, vs.y)]), PackedColorArray([c1, c0, c0, c1]))


## The projection's own small panel: how much of it is left, and how far it has strayed.
func _draw_nether_status(vs: Vector2) -> void:
	var r := Rect2(vs.x * 0.5 - 190.0, vs.y - 282.0, 380.0, 92.0)
	draw_rect(r.grow(3.0), Color(0, 0, 0, 0.55))
	draw_rect(r, Color(0.09, 0.06, 0.16, 0.93))
	draw_rect(r, Color("7b5fc9"), false, 2.0)
	UiDraw.text(self, Vector2(r.position.x, r.position.y + 19.0), "THE NETHERECHO", 14, Color("cdbcf2"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var hp: float = float(nether.get("hp", 0.0))
	var hp_max: float = maxf(1.0, float(nether.get("hp_max", 1.0)))
	var danger: bool = hp / hp_max <= 0.5
	var hp_col: Color = Color("7fe6ff") if not danger else Color("ff7a6b").lerp(Color(1, 1, 1), 0.3 + 0.3 * sin(_time * 9.0))
	UiDraw.bar(self, Rect2(r.position.x + 14.0, r.position.y + 28.0, r.size.x - 28.0, 12.0), hp / hp_max, hp_col)
	UiDraw.text(self, Vector2(r.position.x, r.position.y + 55.0), "projection  %d / %d   -   if it dies, you die" % [int(ceil(hp)), int(hp_max)], 12, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var leash: float = clampf(float(nether.get("leash", 0.0)), 0.0, 1.0)
	UiDraw.bar(self, Rect2(r.position.x + 14.0, r.position.y + 64.0, r.size.x - 28.0, 6.0), leash, Color("b08cff") if leash < 0.92 else UiTheme.BAD)
	UiDraw.text(self, Vector2(r.position.x + 14.0, r.position.y + 84.0),
		"tether to your body" + ("  -  at its limit" if bool(nether.get("at_leash", false)) else ""), 11, UiTheme.TEXT_DIM)
	_right_text(Vector2(r.end.x - 14.0, r.position.y + 84.0), "gathered %d    subdued %d" % [int(nether.get("gathered", 0)), int(nether.get("subdued", 0))], 11, Color("cdbcf2"))


# --- top right: passage tracker -------------------------------------------------------------------

func _draw_tracker(vs: Vector2) -> void:
	if passage.is_empty():
		return
	var walls: int = int(passage.get("walls", 0))
	var cleared: int = int(passage.get("cleared", 0))
	var current: int = int(passage.get("current", 0))
	var gate: int = int(passage.get("gate", 0))
	var step := 26.0
	var w: float = walls * step + 28.0
	var r := Rect2(vs.x - w - 14.0, 14.0, w, 80.0)
	draw_rect(r.grow(3.0), Color(0, 0, 0, 0.55))
	draw_rect(r, Color(UiTheme.PANEL, 0.92))
	draw_rect(r, UiTheme.BRONZE, false, 2.0)
	UiDraw.text(self, r.position + Vector2(14.0, 20.0), "THE PASSAGE", 13, UiTheme.TEXT_DIM)
	_right_text(Vector2(r.end.x - 14.0, r.position.y + 20.0), "$%d banked" % int(passage.get("bank", 0)), 14, UiTheme.GOLD)
	for i: int in walls:
		var c := Vector2(r.position.x + 27.0 + i * step, r.position.y + 42.0)
		var n: int = i + 1
		var fill: Color = UiTheme.INSET
		var edge: Color = UiTheme.BRONZE_DIM
		if n <= cleared:
			fill = UiTheme.GOLD
			edge = UiTheme.GOLD.lightened(0.3)
		elif n == current:
			fill = UiTheme.BAD.lerp(Color(1, 0.8, 0.6), 0.5 + 0.5 * sin(_time * 5.0))
			edge = UiTheme.BAD
		var d := 8.0
		var pts := PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)])
		draw_colored_polygon(pts, fill)
		pts.append(pts[0])
		draw_polyline(pts, edge, 1.5, true)
		if n == gate:
			# the wall that opens the first exit
			draw_line(c + Vector2(0, 11.0), c + Vector2(0, 17.0), UiTheme.GOOD, 2.0)
			UiDraw.text(self, c + Vector2(-9.0, 28.0), "exit", 10, UiTheme.GOOD if cleared >= gate else UiTheme.TEXT_FAINT)


# --- tooltips ---------------------------------------------------------------------------------------

func _draw_tooltip(vs: Vector2) -> void:
	var m: Vector2 = get_local_mouse_position()
	var what: String = debug_tip
	var anchor: Vector2 = m
	if what == "":
		for i: int in _slot_rects.size():
			if _slot_rects[i].has_point(m):
				what = "slot:%d" % i
		if m.distance_to(_health_c) <= ORB_R + 14.0:
			what = "health"
		elif m.distance_to(_essence_c) <= ORB_R + 14.0:
			what = "essence"
	elif what.begins_with("slot:"):
		anchor = _slot_rects[int(what.get_slice(":", 1))].get_center() if _slot_rects.size() > int(what.get_slice(":", 1)) else m
	elif what == "health":
		anchor = _health_c
	elif what == "essence":
		anchor = _essence_c
	if what == "":
		return

	var lines: Array = []           # [[text, size, color]]
	if what.begins_with("slot:"):
		var i: int = int(what.get_slice(":", 1))
		var hotbar: Array = player.get("hotbar")
		var abilities: Array = player.get("abilities")
		var idx: int = int(hotbar[i]) if i < hotbar.size() else -1
		if idx < 0 or idx >= abilities.size():
			lines.append(["Empty slot", 16, UiTheme.TEXT_DIM])
			lines.append(["Learn an ability to fill it.", 13, UiTheme.TEXT_FAINT])
		else:
			var st: Dictionary = abilities[idx]
			var ab: Dictionary = player.call("ability_stats", st)
			lines.append([str(ab.get("name", "?")), 18, UiTheme.GOLD])
			lines.append(["\"%s\"" % str(ab.get("verse", "")), 13, UiTheme.STAR])
			lines.append(["%s affinity" % str(GameData.affinity(str(ab.get("affinity", ""))).get("label", "?")), 13, GameData.affinity_color(str(ab.get("affinity", ""))).lightened(0.3)])
			lines.append(["Costs %d essence and leaves %d reflux" % [int(round(float(ab.get("cost", 0.0)))), int(round(float(ab.get("cost", 0.0)) * float(ab.get("reflux_per_cost", 1.0))))], 13, UiTheme.TEXT])
			match str(ab.get("kind", "")):
				"projectile":
					lines.append(["%d damage at range" % int(float(ab.get("damage", 0.0)) * float(player.call("ability_damage_mult", int(st["stage"]))) * float(ab.get("damage_all", 1.0))), 13, UiTheme.TEXT])
				"melee_burst":
					lines.append(["Hits everything in front of you for x%.1f a normal blow, and wounds you" % float(ab.get("damage_mult", 1.0)), 13, UiTheme.TEXT])
				"dash":
					lines.append(["A burst of movement in the direction you are heading", 13, UiTheme.TEXT])
			lines.append(["Stage %d   -   %d%% toward the next" % [int(st["stage"]), int(float(st["progress"]))], 13, UiTheme.TEXT_DIM])
			var need: String = str(player.call("pending_tier", st))
			if need != "":
				lines.append(["Full. Bind a %s to advance (%s, or the inventory to choose)." % [need, Keybinds.binding_text("bind")], 13, UiTheme.GOLD])
			for up: Dictionary in st.get("bound", []):
				lines.append(["Bound: %s of %s" % [str(up["tier"]), str(GameData.concept(str(up["concept"])).get("label", up["concept"]))], 13, UiTheme.STAR])
	elif what == "health":
		var b: Body = player.get("body")
		lines.append(["Your body", 18, UiTheme.GOLD])
		lines.append(["Superficial   %d / %d     heals fast when you rest" % [int(ceil(float(b.hp["superficial"]))), int(float(b.max_hp["superficial"]))], 13, UiTheme.HEALTH_SUPERFICIAL.lightened(0.3)])
		lines.append(["Structural   %d / %d     heals slowly" % [int(ceil(float(b.hp["structural"]))), int(float(b.max_hp["structural"]))], 13, UiTheme.HEALTH_STRUCTURAL.lightened(0.45)])
		lines.append(["Catastrophic   %d / %d     never heals on its own" % [int(ceil(float(b.hp["catastrophic"]))), int(float(b.max_hp["catastrophic"]))], 13, UiTheme.HEALTH_CATASTROPHIC.lightened(0.6)])
		lines.append(["The ring is your striking arm. Overcharging wears it out;" , 13, UiTheme.TEXT_DIM])
		lines.append(["lose it and only a healer or a talent brings it back.", 13, UiTheme.TEXT_DIM])
	elif what == "essence":
		var pcts: Array = player.get("star_pct")
		lines.append(["Essence", 18, UiTheme.GOLD])
		lines.append(["%d of %d   -   your star holds %d%% of what it could" % [int(float(player.get("essence"))), int(float(player.get("essence_max"))), int(float(pcts.back()))], 13, UiTheme.ESSENCE.lightened(0.4)])
		var rate: float = float(player.get("satellite_rate"))
		lines.append([("A satellite feeds you +%d a second." % int(rate)) if rate > 0.0 else "No satellite: essence returns only when you meditate (%s)." % Keybinds.binding_text("meditate"), 13, UiTheme.TEXT])
		lines.append(["The ring is reflux - heat left by every cast.", 13, UiTheme.TEXT_DIM])
		lines.append(["Past 50 casts cost more, past 80 they burn you, at 100 you are locked out.", 13, UiTheme.TEXT_DIM])
		lines.append(["Meditating sheds it fastest.", 13, UiTheme.TEXT_DIM])

	var f: Font = UiTheme.font()
	var w := 0.0
	var h := 14.0
	for l: Array in lines:
		w = maxf(w, f.get_string_size(str(l[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(l[1])).x)
		h += float(int(l[1])) + 7.0
	var r := Rect2(anchor.x - w * 0.5 - 14.0, anchor.y - h - 96.0, w + 28.0, h)
	if what == "health" or what == "essence":
		r.position.y = anchor.y - ORB_R - 64.0 - h
	r.position.x = clampf(r.position.x, 8.0, vs.x - r.size.x - 8.0)
	r.position.y = maxf(8.0, r.position.y)
	draw_rect(r.grow(3.0), Color(0, 0, 0, 0.6))
	draw_rect(r, Color(UiTheme.PANEL, 0.97))
	draw_rect(r, UiTheme.GOLD.darkened(0.2), false, 1.5)
	var y: float = r.position.y + 8.0
	for l: Array in lines:
		y += float(int(l[1])) + 2.0
		UiDraw.text(self, Vector2(r.position.x + 14.0, y), str(l[0]), int(l[1]), l[2])
		y += 5.0


# --- text helpers -------------------------------------------------------------------------------

func _centre_text(at: Vector2, s: String, font_size: int, color: Color) -> void:
	var w: float = UiTheme.font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	UiDraw.text(self, Vector2(at.x - w * 0.5, at.y), s, font_size, color)


func _right_text(at: Vector2, s: String, font_size: int, color: Color) -> void:
	var w: float = UiTheme.font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	UiDraw.text(self, Vector2(at.x - w, at.y), s, font_size, color)
