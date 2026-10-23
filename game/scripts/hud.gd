extends Control
## In-game HUD, drawn procedurally over nine-patch frames (layout: design/09-ui-review-v0.md):
##   bottom centre  - the dock: health orb | six skill slots, strike and shoot | essence orb.
##                    The star line runs along the dock's top edge. Ring round the health orb =
##                    striking arm; rings round the essence orb = reflux, one per affinity.
##                    Above the dock: what is on you (buffs, talent states) on the left, the
##                    affinity resources (Slipstream, standing stone, a wind-up) in the middle, and a
##                    tag over each orb only when it has something to warn about.
##   top left       - character plate (name, talent, stars, money, where you are, constructs)
##   top centre     - target frame for the enemy under the cursor, then the prompt, then titles
##   top right      - minimap (in a zone) or the passage tracker (in a passage)
##   bottom left    - message log that fades
##   bottom right   - key reminders; they fade out while a fight is on
##   over the world - enemy health / poise bars, statuses and telegraphs
## Text drawn straight onto the world is outlined (UiDraw.outlined) so it reads on any ground.
## The HUD only reads the player; it never changes game state. Screens can hide parts of it
## (UiScreen.hud_hides) so a menu never sits on top of the plate it repeats.

const ORB_R := 62.0
const SLOT := 60.0
const SLOT_GAP := 6.0
const MINI := 48.0                 # the strike and shoot slots
const DOCK_PAD := 20.0
const DOCK_TOP := 24.0             # the star line lives in this band
const DOCK_BOTTOM := 18.0          # keycaps hang into this band

var player: Node
var where := ""
var prompt := ""
var title := ""                    # big, brief announcement ("WALL 3")
var show_world := true             # false on menu screens: hide bars, orbs stay

var _time := 0.0
var _title_age := 99.0
## The "Rune discovered" card (design/14 section 8): {id, source, age} while it shows.
var _rune_card: Dictionary = {}
const RUNE_CARD_S := 5.5
var _log: Array = []               # [{text, age}]
var _log_seen := 0
var _hurt_flash := 0.0
var _last_hp := -1.0
var _bar_rect := Rect2()
var _plate_rect := Rect2()
var _panel_rects: Array[Rect2] = []   # target frame, minimap, tracker: opaque, so a click there is not an order
var _slot_rects: Array[Rect2] = []
var _strike_rect := Rect2()
var _shoot_rect := Rect2()
var _dock := Rect2()
var _health_c := Vector2.ZERO
var _essence_c := Vector2.ZERO
var _hidden: Dictionary = {}       # part -> true, from the screens that are open
var _recover_max := 0.0            # the longest the current recovery has been, for the sweep
var _melee_max := 0.0
var _ranged_max := 0.0
var _tip_what := ""
var _tip_age := 0.0
var _hint_alpha := 1.0
var _fog_tex: ImageTexture
var _fog_seen := -1.0
var _fog_src: FogMap
const FOG_TINT := Color(0.16, 0.135, 0.1, 0.95)
## Passage progress for the tracker: {walls, cleared, current, gate, bank} or {} when not in one.
var passage: Dictionary = {}
## The overland minimap (main.minimap_info()), or {} when there is none to draw.
var minimap: Dictionary = {}
## While the soul is out in the Netherecho: {hp, hp_max, leash, at_leash, gathered, subdued, hovered, target}.
var nether: Dictionary = {}
## Screenshot aid: force a tooltip ("slot:0", "strike", "shoot", "health", "essence") without a real cursor.
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


## Show the card for a rune just discovered: its glyph, name, meaning and where it was found.
func show_rune(rune_id: String, source: String) -> void:
	_rune_card = {"id": rune_id, "source": source, "age": 0.0}


## True when the cursor is over a HUD panel, so a click there is not also an attack order.
func mouse_over_ui() -> bool:
	return ui_at(get_local_mouse_position())


## True when `m` (HUD coordinates) is on the dock, the plate or one of the opaque panels.
func ui_at(m: Vector2) -> bool:
	if _bar_rect.has_point(m) or (_plate_rect.has_point(m) and not _hidden.has("plate")):
		return true
	for r: Rect2 in _panel_rects:
		if r.has_point(m):
			return true
	return false


func _process(delta: float) -> void:
	_time += delta
	_title_age += delta
	if not _rune_card.is_empty():
		_rune_card["age"] = float(_rune_card["age"]) + delta
		if float(_rune_card["age"]) > RUNE_CARD_S:
			_rune_card = {}
	_hurt_flash = maxf(0.0, _hurt_flash - delta * 2.5)
	for entry: Dictionary in _log:
		entry["age"] = float(entry["age"]) + delta
	_hidden.clear()
	if get_parent() != null:
		for c: Node in get_parent().get_children():
			if c is UiScreen and (c as Control).visible:
				for part: String in c.call("hud_hides"):
					_hidden[part] = true
	if player != null and str(player.get("talent_id")) != "":
		var serial: int = int(player.get("log_serial"))
		var lines: Array = player.get("log_lines")
		var fresh: int = mini(serial - _log_seen, lines.size())
		for i: int in range(lines.size() - fresh, lines.size()):
			_log.append({"text": str(lines[i]), "age": 0.0})
		_log_seen = serial
		while _log.size() > GameData.inum("hud", "log_max"):
			_log.remove_at(0)
		var hp: float = (player.get("body") as Body).total()
		if _last_hp >= 0.0 and hp < _last_hp - 0.5:
			_hurt_flash = 1.0
		_last_hp = hp
		_recover_max = _track_max(_recover_max, float(player.get("_recover_t")))
		_melee_max = _track_max(_melee_max, float(player.get("_melee_cd")))
		_ranged_max = _track_max(_ranged_max, float(player.get("_ranged_cd")))
		var fight: bool = bool(player.get("in_combat"))
		var target_a: float = GameData.num("hud", "hints_alpha_in_combat") if fight else 1.0
		_hint_alpha = move_toward(_hint_alpha, target_a, delta * 2.0)
	queue_redraw()


## The full length of a countdown that is running now: it restarts whenever the timer jumps up.
static func _track_max(prev: float, now: float) -> float:
	if now <= 0.0:
		return 0.0
	return maxf(prev, now) if prev > 0.0 and now <= prev + 0.001 else now


func _draw() -> void:
	if player == null or str(player.get("talent_id")) == "":
		return
	var vs: Vector2 = size
	_panel_rects.clear()
	if not nether.is_empty():
		_draw_nether_veil(vs)
	if show_world:
		_draw_enemy_bars()
		if not nether.is_empty():
			_draw_wisp_labels()
		_draw_vignette(vs)
		_draw_target_frame(vs)
		_draw_prompt(vs)
		_draw_title(vs)
		_draw_rune_card(vs)
		if not _hidden.has("log"):
			_draw_log(vs)
		if not _hidden.has("tracker"):
			_draw_tracker(vs)
			_draw_minimap(vs)
		if not nether.is_empty():
			_draw_nether_status(vs)
	if not _hidden.has("plate"):
		_draw_plate()
	_draw_dock(vs)
	if not _hidden.has("hints"):
		_draw_hints(vs)
	_draw_tooltip(vs)


# --- bottom: the dock -------------------------------------------------------------------------

func _draw_dock(vs: Vector2) -> void:
	var hotbar: Array = player.get("hotbar")
	var n: int = hotbar.size()
	var skills_w: float = n * SLOT + (n - 1) * SLOT_GAP
	var extra_w: float = 18.0 + MINI * 2.0 + SLOT_GAP
	var inner_w: float = skills_w + extra_w
	var cx: float = vs.x * 0.5
	_dock = Rect2(cx - inner_w * 0.5 - DOCK_PAD, vs.y - 12.0 - (DOCK_TOP + SLOT + DOCK_BOTTOM), inner_w + DOCK_PAD * 2.0, DOCK_TOP + SLOT + DOCK_BOTTOM)
	var left_c := Vector2(_dock.position.x - ORB_R - 6.0, vs.y - ORB_R - 18.0)
	var right_c := Vector2(_dock.end.x + ORB_R + 6.0, vs.y - ORB_R - 18.0)
	_health_c = left_c
	_essence_c = right_c
	_bar_rect = Rect2(left_c.x - ORB_R - 18.0, _dock.position.y - 30.0, (right_c.x - left_c.x) + 2.0 * ORB_R + 36.0, vs.y - _dock.position.y + 30.0)

	UiDraw.frame(self, _dock.grow(2.0), "panel")
	_draw_star_line(Rect2(_dock.position.x + DOCK_PAD, _dock.position.y + 8.0, inner_w, 12.0))

	# the six skill slots
	var abilities: Array = player.get("abilities")
	var essence: float = float(player.get("essence"))
	var recovering: float = float(player.get("_recover_t")) / _recover_max if _recover_max > 0.0 else 0.0
	_slot_rects.clear()
	var y0: float = _dock.position.y + DOCK_TOP
	for i: int in n:
		var r := Rect2(_dock.position.x + DOCK_PAD + i * (SLOT + SLOT_GAP), y0, SLOT, SLOT)
		_slot_rects.append(r)
		_draw_slot(r, i, int(hotbar[i]), abilities, essence, recovering)

	# a divider, then the strike and the shot
	var dx: float = _dock.position.x + DOCK_PAD + skills_w + 9.0
	draw_line(Vector2(dx, y0 + 4.0), Vector2(dx, y0 + SLOT - 4.0), UiTheme.BRONZE_DIM, 1.0)
	var my: float = y0 + SLOT - MINI
	_strike_rect = Rect2(dx + 9.0, my, MINI, MINI)
	_shoot_rect = Rect2(dx + 9.0 + MINI + SLOT_GAP, my, MINI, MINI)
	_draw_strike_slot(_strike_rect)
	_draw_shoot_slot(_shoot_rect)

	_draw_health_orb(left_c)
	_draw_essence_orb(right_c)
	_draw_above_dock(cx)


## The newest star's growth as a thin line along the top of the dock: label, line, then the read.
func _draw_star_line(r: Rect2) -> void:
	var pcts: Array = player.get("star_pct")
	var newest: float = float(pcts.back()) if not pcts.is_empty() else 0.0
	var aura: String = str(player.call("aura_read"))
	var ready: bool = aura.contains("ascend")
	var px: int = UiTheme.FS_CAPTION
	var label: String = "STAR %d  ·  %d%%" % [pcts.size(), int(newest)]
	var base_y: float = r.position.y + 9.0
	UiDraw.outlined(self, Vector2(r.position.x, base_y), label, px, UiTheme.STAR)
	var aura_text: String = _keyed(aura) if ready else aura
	var aw: float = UiDraw.rich_width(aura_text, px + 1) if ready else UiDraw.text_width(aura, px)
	if ready:
		UiDraw.rich(self, Vector2(r.end.x - aw, base_y), aura_text, px + 1, UiTheme.GOLD.lerp(Color(1, 1, 1), 0.25 + 0.25 * sin(_time * 4.0)))
	else:
		UiDraw.outlined(self, Vector2(r.end.x - aw, base_y), aura, px, Color(UiTheme.TEXT_DIM, 0.9))
	var lx: float = r.position.x + UiDraw.text_width(label, px) + 12.0
	var line := Rect2(lx, base_y - 6.0, maxf(20.0, r.end.x - aw - 12.0 - lx), 5.0)
	UiDraw.bar(self, line, newest / 99.0, UiTheme.STAR.darkened(0.1))


## A binding inside running text, made into a keycap: "T to ascend" -> "[T] to ascend".
func _keyed(text: String) -> String:
	var k: String = Keybinds.binding_text("ascend")
	return text.replace("  %s to" % k, "  [%s] to" % k)


func _draw_slot(r: Rect2, i: int, idx: int, abilities: Array, essence: float, recovering: float) -> void:
	UiDraw.frame(self, r, "slot")
	var border := Color(0, 0, 0, 0)
	if idx >= 0 and idx < abilities.size():
		var st: Dictionary = abilities[idx]
		var ab: Dictionary = player.call("ability_stats", st)
		var cost: float = float(ab.get("cost", 0.0))
		var aff: String = str(ab.get("affinity", ""))
		var locked: bool = bool(player.call("is_locked", aff))
		var afford: bool = essence >= cost
		var usable: bool = not locked and afford
		var tint: Color = GameData.affinity_color(aff).lightened(0.3) if usable else Color(0.42, 0.43, 0.48)
		UiDraw.icon(self, str(ab.get("icon", "drop")), r.get_center() + Vector2(0, 1), SLOT * 0.44, tint)
		if not usable:
			draw_rect(r.grow(-3.0), Color(0, 0, 0, 0.4))
			if not afford and not locked:
				draw_rect(r.grow(-3.0), Color(UiTheme.ESSENCE_DEEP, 0.28))          # out of essence: a blue cast, as D4 does
		UiDraw.sweep(self, r.grow(-3.0), recovering)
		# stage pips, top left
		for s: int in int(st["stage"]):
			draw_circle(Vector2(r.position.x + 8.0 + s * 7.0, r.position.y + 8.0), 2.6, UiTheme.GOLD)
		# cost, top right
		UiDraw.outlined(self, Vector2(r.position.x, r.position.y + 16.0), str(int(round(cost))), UiTheme.FS_CAPTION + 1,
			UiTheme.ESSENCE.lightened(0.45) if afford else UiTheme.BAD.lightened(0.15), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 5.0)
		# progress toward the next stage along the bottom
		var prog: float = clampf(float(st["progress"]) / 100.0, 0.0, 1.0)
		var pr := Rect2(r.position.x + 4.0, r.end.y - 6.0, r.size.x - 8.0, 3.0)
		draw_rect(pr, Color(0, 0, 0, 0.8))
		draw_rect(Rect2(pr.position, Vector2(pr.size.x * prog, pr.size.y)), UiTheme.GOLD if prog >= 1.0 else UiTheme.ESSENCE.lightened(0.15))
		var need: String = str(player.call("pending_tier", st))
		if need != "":
			# full and waiting for a construct: pulsing gold frame and a gem
			var pulse: float = 0.55 + 0.45 * sin(_time * 4.0)
			border = UiTheme.GOLD.lerp(Color(1, 1, 1), pulse * 0.4)
			UiDraw.icon(self, "gem", Vector2(r.position.x + 11.0, r.end.y - 16.0), 13.0, UiTheme.GOLD)
		if locked:
			draw_line(r.position + Vector2(8, 8), r.end - Vector2(8, 8), UiTheme.REFLUX_HOT, 3.0, true)
	else:
		draw_rect(r.grow(-3.0), Color(0, 0, 0, 0.25))
	if border.a > 0.0:
		draw_rect(r.grow(1.0), border, false, 2.0)
	_slot_key(r, Keybinds.binding_text("ability_%d" % (i + 1)))


## The key that fires a slot, as a keycap hanging off the bottom of its frame.
func _slot_key(r: Rect2, key: String) -> void:
	var px: int = UiTheme.FS_CAPTION
	var w: float = maxf(float(px) + 6.0, UiDraw.text_width(key, px - 1) + 10.0)
	UiDraw.keycap(self, Vector2(r.get_center().x - w * 0.5, r.end.y + 9.0), key, px)


func _draw_strike_slot(r: Rect2) -> void:
	UiDraw.frame(self, r, "slot")
	var inv: Inventory = player.get("inventory")
	var weapon: String = str(inv.equipped.get("weapon", ""))
	var arm_lost: bool = bool(player.get("arm_right_lost"))
	var col: Color = UiTheme.TEXT if not arm_lost else UiTheme.TEXT_FAINT
	UiDraw.icon(self, UiDraw.item_icon(GameData.item(weapon)) if weapon != "" else "fist", r.get_center(), MINI * 0.46, col)
	UiDraw.sweep(self, r.grow(-3.0), float(player.get("_melee_cd")) / _melee_max if _melee_max > 0.0 else 0.0)
	if arm_lost:
		draw_line(r.position + Vector2(7, 7), r.end - Vector2(7, 7), UiTheme.BAD, 2.5, true)
	_slot_key(r, Keybinds.binding_text("strike"))


func _draw_shoot_slot(r: Rect2) -> void:
	UiDraw.frame(self, r, "slot")
	var ranged: Dictionary = player.call("ranged_weapon")
	var has: bool = not ranged.is_empty()
	var aiming: bool = bool(player.get("ranged_stance"))
	UiDraw.icon(self, UiDraw.item_icon(ranged) if has else "sling", r.get_center(), MINI * 0.46,
		(UiTheme.GOLD if aiming else UiTheme.TEXT) if has else Color(0.3, 0.28, 0.25))
	if has:
		UiDraw.sweep(self, r.grow(-3.0), float(player.get("_ranged_cd")) / _ranged_max if _ranged_max > 0.0 else 0.0)
	if aiming:
		draw_rect(r.grow(1.0), UiTheme.GOLD, false, 2.0)
	_slot_key(r, Keybinds.binding_text("ranged_stance"))


## What sits just above the dock: things on you (left), the affinity resources (middle).
func _draw_above_dock(cx: float) -> void:
	var base_y: float = _dock.position.y - 10.0
	# middle: Slipstream pips, standing stone, a wind-up
	var strip_y: float = base_y
	if bool(player.call("has_slipstream")):
		var cfg: Dictionary = GameData.balance["slipstream"]
		var total: int = int(cfg["max"])
		var have: int = int(player.get("pips"))
		var wind_col: Color = GameData.affinity_color("wind").lightened(0.2)
		var fast: bool = have >= int(cfg["speed_pips"])
		var label: String = "SLIPSTREAM" + ("  ·  SWIFT" if fast else "")
		var w: float = float(total) * 14.0 + 10.0 + UiDraw.text_width(label, UiTheme.FS_CAPTION)
		var x0: float = cx - w * 0.5
		_chip_back(Rect2(x0 - 10.0, strip_y - 16.0, w + 20.0, 22.0))
		for i: int in total:
			var c := Vector2(x0 + 5.0 + float(i) * 14.0, strip_y - 5.0)
			if i < have:
				draw_circle(c, 4.5, wind_col if not fast else wind_col.lerp(Color(1, 1, 1), 0.35))
			else:
				draw_arc(c, 4.0, 0.0, TAU, 14, Color(wind_col, 0.45), 1.5, true)
		UiDraw.outlined(self, Vector2(x0 + float(total) * 14.0 + 6.0, strip_y), label, UiTheme.FS_CAPTION, Color(wind_col, 1.0 if fast else 0.75))
		strip_y -= 26.0
	if bool(player.call("has_stone")):
		var s_total: int = GameData.inum("stone", "max_count")
		var s_have: int = int(player.call("stone_count"))
		var earth_col: Color = GameData.affinity_color("earth").lightened(0.2)
		var set_now: bool = bool(player.call("is_braced"))
		var label2: String = "STONE  %d / %d" % [s_have, s_total] + ("  ·  BRACED" if set_now else "")
		var w2: float = float(s_total) * 18.0 + 8.0 + UiDraw.text_width(label2, UiTheme.FS_CAPTION)
		var x1: float = cx - w2 * 0.5
		_chip_back(Rect2(x1 - 10.0, strip_y - 16.0, w2 + 20.0, 22.0))
		for i: int in s_total:
			var block := Rect2(x1 + float(i) * 18.0, strip_y - 10.0, 12.0, 10.0)
			if i < s_have:
				draw_rect(block, earth_col)
			else:
				draw_rect(block, Color(earth_col, 0.45), false, 1.5)
		UiDraw.outlined(self, Vector2(x1 + float(s_total) * 18.0 + 4.0, strip_y), label2, UiTheme.FS_CAPTION, Color(earth_col, 1.0 if set_now else 0.8))
		strip_y -= 26.0
	# Blood's held blood: a row of beads (it is never health)
	var blood_max: int = int(player.call("held_blood_max"))
	if blood_max > 0:
		var b_have: int = int(player.get("held_blood"))
		var red: Color = GameData.affinity_color("blood").lightened(0.1)
		var label3: String = "HELD BLOOD  %d" % b_have
		var w3: float = float(blood_max) * 13.0 + 8.0 + UiDraw.text_width(label3, UiTheme.FS_CAPTION)
		var x3: float = cx - w3 * 0.5
		_chip_back(Rect2(x3 - 10.0, strip_y - 16.0, w3 + 20.0, 22.0))
		for i: int in blood_max:
			var bc := Vector2(x3 + 5.0 + float(i) * 13.0, strip_y - 5.0)
			if i < b_have:
				draw_circle(bc, 4.5, red)
			else:
				draw_arc(bc, 4.0, 0.0, TAU, 14, Color(red, 0.4), 1.5, true)
		UiDraw.outlined(self, Vector2(x3 + float(blood_max) * 13.0 + 4.0, strip_y), label3, UiTheme.FS_CAPTION, red)
		strip_y -= 26.0
	# Dark's swallowed light, while there is any
	var stores: Dictionary = player.get("stores")
	if stores.has("swallowed") and int((stores["swallowed"] as Dictionary).get("n", 0)) > 0:
		var dark_col: Color = GameData.affinity_color("dark").lightened(0.2)
		var label4: String = "SWALLOWED LIGHT  %d" % int(stores["swallowed"]["n"])
		var w4: float = UiDraw.text_width(label4, UiTheme.FS_CAPTION)
		_chip_back(Rect2(cx - w4 * 0.5 - 10.0, strip_y - 16.0, w4 + 20.0, 22.0))
		UiDraw.outlined(self, Vector2(cx - w4 * 0.5, strip_y), label4, UiTheme.FS_CAPTION, dark_col)
		strip_y -= 26.0
	# a test character's bar can turn to the next six skills
	if bool(player.get("test_character")):
		var per: int = (player.get("hotbar") as Array).size()
		var pages: int = int(ceil(float((player.get("abilities") as Array).size()) / float(maxi(1, per))))
		if pages > 1:
			var label5: String = "TEST CHARACTER  ·  SKILL PAGE %d / %d  ·  %s NEXT" % [int(player.get("hotbar_page")) + 1, pages, Keybinds.binding_text("hotbar_page").to_upper()]
			var w5: float = UiDraw.text_width(label5, UiTheme.FS_CAPTION)
			_chip_back(Rect2(cx - w5 * 0.5 - 10.0, strip_y - 16.0, w5 + 20.0, 22.0))
			UiDraw.outlined(self, Vector2(cx - w5 * 0.5, strip_y), label5, UiTheme.FS_CAPTION, UiTheme.STAR)
			strip_y -= 26.0
	var wind_up: float = float(player.call("windup_frac"))
	if wind_up < 0.0:
		wind_up = float(player.call("held_frac"))         # a held skill: how far through its hold (or charge)
	if wind_up >= 0.0:
		var wr := Rect2(cx - 90.0, strip_y - 8.0, 180.0, 6.0)
		draw_rect(wr.grow(2.0), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(wr.position, Vector2(wr.size.x * wind_up, wr.size.y)), Color(0.95, 0.9, 0.75))
		draw_rect(wr.grow(2.0), UiTheme.BRONZE_DIM, false, 1.0)

	# left: skills sitting on you, and what your talent is holding
	if _hidden.has("buffs"):
		return
	var chips: Array = []          # [text, color]
	var on_me: Dictionary = player.get("buffs")
	for id: String in on_me:
		var b: Dictionary = on_me[id]
		chips.append(["%s  %ds" % [str(b.get("name", id)), int(ceil(float(b["t"])))], GameData.affinity_color(str(b.get("affinity", ""))).lightened(0.35)])
	for line: String in player.call("status_lines"):
		chips.append([line, Color(0.78, 0.78, 1.0)])
	var x: float = _dock.position.x + 4.0
	for chip: Array in chips:
		var t: String = str(chip[0])
		var cw: float = UiDraw.text_width(t, UiTheme.FS_CAPTION + 1) + 18.0
		if x + cw > cx - 110.0 and x > _dock.position.x + 4.0:
			break                                   # never run under the resource strip
		_chip_back(Rect2(x, base_y - 16.0, cw, 22.0), chip[1])
		UiDraw.outlined(self, Vector2(x + 9.0, base_y), t, UiTheme.FS_CAPTION + 1, chip[1])
		x += cw + 6.0


## A small dark plate behind a chip of text, edged in `edge` (or bronze).
func _chip_back(r: Rect2, edge: Color = UiTheme.BRONZE_DIM) -> void:
	draw_rect(r.grow(1.0), Color(0, 0, 0, 0.55))
	draw_rect(r, Color(UiTheme.PANEL, 0.88))
	draw_rect(r, Color(edge, 0.55), false, 1.0)


func _draw_health_orb(c: Vector2) -> void:
	var b: Body = player.get("body")
	var total_max: float = b.total_max()
	# the orb is the whole body: what wounds have taken stays empty at the top
	var frac: float = b.total() / b.max_hp
	var bands: Array = [[frac * 0.4, UiTheme.HEALTH_STRUCTURAL], [frac * 0.6, UiTheme.HEALTH_SUPERFICIAL]]
	# what wounds have taken: a dark band where the bar can no longer reach
	var cut: float = clampf(1.0 - total_max / b.max_hp, 0.0, 1.0)
	# ring = striking arm
	var arm_lost: bool = bool(player.get("arm_right_lost"))
	var arm: float = 0.0 if arm_lost else float(player.get("arm_right")) / 100.0
	UiDraw.ring(self, c, ORB_R + 11.0, arm, Color(0.74, 0.76, 0.84) if arm > 0.3 else UiTheme.BAD)
	UiDraw.orb(self, c, ORB_R, bands, _time, UiTheme.BRONZE)
	if cut > 0.01:
		var top_y: float = c.y - ORB_R
		var cut_y: float = top_y + 2.0 * ORB_R * cut
		var half: float = sqrt(maxf(0.0, ORB_R * ORB_R - (cut_y - c.y) * (cut_y - c.y)))
		draw_line(Vector2(c.x - half + 3.0, cut_y), Vector2(c.x + half - 3.0, cut_y), Color(1.0, 0.45, 0.35, 0.55), 1.5, true)
	if _hurt_flash > 0.0:
		draw_circle(c, ORB_R, Color(1, 0.2, 0.15, 0.35 * _hurt_flash))
	UiDraw.outlined(self, Vector2(c.x - 60.0, c.y + 8.0), "%d" % int(ceil(b.total())), 28, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 120.0, true)
	UiDraw.outlined(self, Vector2(c.x - 60.0, c.y + 26.0), "/ %d" % int(total_max), UiTheme.FS_CAPTION + 1,
		Color("e9d9c4") if b.wounds.is_empty() else Color("ffb49a"), HORIZONTAL_ALIGNMENT_CENTER, 120.0)
	# one mark per wound along the top of the orb. How deep each one is, is not shown as a number,
	# but the mark pales as it mends, so healing that goes into a wound can be seen to land.
	for i: int in b.wounds.size():
		var a: float = -PI * 0.5 + (float(i) - float(b.wounds.size() - 1) * 0.5) * 0.24
		var at: Vector2 = c + Vector2(cos(a), sin(a)) * (ORB_R - 13.0)
		var state: String = Body.wound_state(b.wounds[i])
		var mark: Color = Color("ff5a3c") if state == "fresh" else (Color("ffb070") if state == "mending" else Color("f3e3c0"))
		draw_line(at + Vector2(-4, -4), at + Vector2(4, 4), Color(0, 0, 0, 0.8), 4.5, true)
		draw_line(at + Vector2(-4, 4), at + Vector2(4, -4), Color(0, 0, 0, 0.8), 4.5, true)
		draw_line(at + Vector2(-4, -4), at + Vector2(4, 4), mark, 2.5, true)
		draw_line(at + Vector2(-4, 4), at + Vector2(4, -4), mark, 2.5, true)
	# a tag over the orb only when the arm needs saying
	if _hidden.has("tags"):
		return
	if arm_lost:
		_orb_tag(c, 0.0, "ARM LOST", UiTheme.BAD)
	elif arm < 0.995:
		_orb_tag(c, 0.0, "ARM  %d%%" % int(arm * 100.0), UiTheme.TEXT if arm > 0.3 else UiTheme.BAD)


## A short warning on a dark plate over an orb; `lift` raises it past the rings.
func _orb_tag(c: Vector2, lift: float, text: String, color: Color, row: int = 0) -> void:
	var px: int = UiTheme.FS_CAPTION + 1
	var w: float = UiDraw.text_width(text, px) + 18.0
	var y: float = c.y - ORB_R - 22.0 - lift - float(row) * 25.0
	_chip_back(Rect2(c.x - w * 0.5, y - 15.0, w, 21.0), color)
	UiDraw.outlined(self, Vector2(c.x - w * 0.5, y), text, px, color, HORIZONTAL_ALIGNMENT_CENTER, w)


func _draw_essence_orb(c: Vector2) -> void:
	var ess: float = float(player.get("essence"))
	var ess_max: float = maxf(1.0, float(player.get("essence_max")))
	var frac: float = clampf(ess / ess_max, 0.0, 1.0)
	var bands: Array = [[frac * 0.45, UiTheme.ESSENCE_DEEP], [frac * 0.55, UiTheme.ESSENCE]]
	var pain: float = GameData.num("reflux", "pain_at")
	var burn: float = GameData.num("reflux", "burn_at")
	var lock: float = maxf(1.0, GameData.num("reflux", "lock_at"))
	# one reflux ring per affinity, the first innermost; the tag speaks for the hottest
	var affs: Array = player.get("affinities")
	var reflux := 0.0
	var locked := false
	var hottest := ""
	for i: int in affs.size():
		var a: String = str(affs[i])
		var heat: float = float(player.call("reflux_of", a))
		var a_locked: bool = bool(player.call("is_locked", a))
		var a_hot: bool = a_locked or heat >= burn
		var ring_col: Color = UiTheme.REFLUX_HOT if a_hot else (UiTheme.REFLUX if heat >= pain else UiTheme.REFLUX.darkened(0.25))
		if float(GameData.affinity(a).get("damage_per_reflux", 0.0)) > 0.0 and not a_locked:
			# this affinity's heat is its damage: the ring brightens as the bonus climbs
			ring_col = GameData.affinity_color(a).darkened(0.35).lerp(Color(1.0, 0.86, 0.5), clampf(heat / lock, 0.0, 1.0))
		if a_locked:
			ring_col = ring_col.lerp(Color(1, 1, 1), 0.3 + 0.3 * sin(_time * 8.0))
		UiDraw.ring(self, c, ORB_R + 11.0 + i * 8.0, heat / lock, ring_col, [pain / lock, burn / lock])
		if affs.size() > 1:
			# a pip in the affinity's colour at the ring's start, so the rings can be told apart
			draw_circle(c + Vector2(0.0, -(ORB_R + 11.0 + i * 8.0)), 3.5, GameData.affinity_color(a))
		if hottest == "" or heat > reflux or (a_locked and not locked):
			hottest = a
			reflux = heat
			locked = a_locked
	UiDraw.orb(self, c, ORB_R, bands, _time + 1.7, UiTheme.BRONZE)
	UiDraw.outlined(self, Vector2(c.x - 60.0, c.y + 8.0), "%d" % int(ess), 28, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 120.0, true)
	UiDraw.outlined(self, Vector2(c.x - 60.0, c.y + 26.0), "/ %d" % int(ess_max), UiTheme.FS_CAPTION + 1, Color("cfe0f4"), HORIZONTAL_ALIGNMENT_CENTER, 120.0)
	if _hidden.has("tags"):
		return
	# tags over the orb: only what changes what you should do next
	var lift: float = maxf(0.0, float(affs.size() - 1)) * 8.0
	var which: String = (str(GameData.affinity(hottest).get("label", hottest)).to_upper() + " ") if affs.size() > 1 else ""
	var row := 0
	if locked:
		_orb_tag(c, lift, "%sLOCKED  -  meditate [%s]" % [which, Keybinds.binding_text("meditate")], UiTheme.REFLUX_HOT.lerp(Color(1, 1, 1), 0.15 + 0.15 * sin(_time * 6.0)), row)
		row += 1
	elif reflux >= burn:
		_orb_tag(c, lift, "%sREFLUX %d  ·  slow to recover" % [which, int(reflux)], UiTheme.REFLUX_HOT, row)
		row += 1
	elif reflux >= pain:
		_orb_tag(c, lift, "%sREFLUX %d  ·  costs more" % [which, int(reflux)], UiTheme.REFLUX, row)
		row += 1
	# heat as a damage bonus, for an affinity that has one (shown for the hottest such affinity)
	var bonus_aff := ""
	for a2: Variant in affs:
		if float(GameData.affinity(str(a2)).get("damage_per_reflux", 0.0)) > 0.0 and (bonus_aff == "" or float(player.call("reflux_of", str(a2))) > float(player.call("reflux_of", bonus_aff))):
			bonus_aff = str(a2)
	if bonus_aff != "" and not locked:
		var bonus: int = int(round((float(player.call("heat_mult", bonus_aff)) - 1.0) * 100.0))
		if bonus > 0:
			_orb_tag(c, lift, "%s  +%d%% damage" % [str(GameData.affinity(bonus_aff).get("label", bonus_aff)).to_upper(), bonus], GameData.affinity_color(bonus_aff).lightened(0.3), row)
			row += 1
	if bool(player.get("meditating")):
		_orb_tag(c, lift, "GATHERING", UiTheme.ESSENCE.lightened(0.45), row)


# --- top left: character plate ----------------------------------------------------------

func _draw_plate() -> void:
	var t: Dictionary = player.get("talent")
	var held: Array = player.get("constructs")
	var who: String = str(player.get("char_name"))
	var named: float = 20.0 if who != "" else 0.0          # a named character gets a line for the talent
	var h: float = 92.0 + named + (28.0 if not held.is_empty() else 0.0)
	var r := Rect2(12.0, 12.0, 300.0, h)
	_plate_rect = r
	UiDraw.frame(self, r, "panel")
	var x: float = r.position.x + 18.0
	UiDraw.text(self, Vector2(x, r.position.y + 33.0), who if who != "" else str(t.get("name", "?")), UiTheme.FS_HEAD, UiTheme.GOLD)
	if who != "":
		UiDraw.text(self, Vector2(x, r.position.y + 52.0), str(t.get("name", "?")), UiTheme.FS_SMALL, UiTheme.STAR)
	# star pips, right-aligned on the name line
	var stars: int = int(player.get("stars"))
	for i: int in stars:
		var c := Vector2(r.end.x - 24.0 - i * 18.0, r.position.y + 27.0)
		draw_circle(c, 7.0, UiTheme.STAR.darkened(0.55))
		draw_circle(c, 4.8, UiTheme.STAR)
	var y: float = r.position.y + 58.0 + named
	var cash: int = int(player.get("money"))
	UiDraw.icon(self, "coin", Vector2(x + 7.0, y - 5.0), 15.0, UiTheme.BAD if cash < 0 else UiTheme.GOLD)
	UiDraw.text(self, Vector2(x + 20.0, y), UiTheme.money_text(cash), UiTheme.FS_BODY, UiTheme.BAD if cash < 0 else UiTheme.TEXT)
	UiDraw.text(self, Vector2(x, y + 19.0), where, UiTheme.FS_CAPTION + 1, UiTheme.TEXT_DIM)
	if not held.is_empty():
		var gx: float = x + 6.0
		var gy: float = y + 40.0
		for c: Dictionary in held.slice(0, 8):                 # at most 8 gems; the count says the rest
			UiDraw.icon(self, "gem", Vector2(gx, gy - 5.0), 14.0, UiTheme.GOLD if str(c["tier"]) == "vestige" else UiTheme.STAR)
			gx += 17.0
		UiDraw.rich(self, Vector2(gx + 4.0, gy), "%d carried  [%s the seal]" % [held.size(), Keybinds.binding_text("bind")], UiTheme.FS_CAPTION + 1, UiTheme.TEXT_DIM, -1.0, false)


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
	var r := Rect2(vs.x * 0.5 - 190.0, 10.0, 380.0, 62.0)
	_panel_rects.append(r)
	UiDraw.frame(self, r, "panel_plain")
	var name_text: String = str(node.get("display_name")) if node.get("display_name") != null else "Enemy"
	UiDraw.outlined(self, Vector2(r.position.x, r.position.y + 25.0), name_text, UiTheme.FS_BODY + 1, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, true)
	var hb := Rect2(r.position.x + 16.0, r.position.y + 32.0, r.size.x - 32.0, 13.0)
	UiDraw.bar(self, hb, b.total() / b.total_max(), UiTheme.HEALTH_SUPERFICIAL)
	UiDraw.outlined(self, Vector2(hb.position.x, hb.end.y - 2.0), "%d / %d" % [int(ceil(b.total())), int(b.total_max())], UiTheme.FS_CAPTION, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, hb.size.x)
	# poise under the health, in the stagger colour: when it runs out, the Opening comes
	var poise_max: Variant = node.get("poise_max")
	if poise_max != null and float(poise_max) < 10000.0:
		UiDraw.bar(self, Rect2(hb.position.x, hb.end.y + 3.0, hb.size.x, 4.0), float(node.get("poise")) / float(poise_max), Color("ffd27a"))
	if node is Node3D:
		_draw_statuses(node as Node3D, Vector2(r.end.x - 56.0, r.position.y + 19.0))


func _draw_prompt(vs: Vector2) -> void:
	if prompt == "":
		return
	var lines: PackedStringArray = prompt.split("\n")
	var px: int = UiTheme.FS_BODY
	var w := 0.0
	for line: String in lines:
		w = maxf(w, UiDraw.rich_width(line, px))
	var r := Rect2(vs.x * 0.5 - w * 0.5 - 24.0, 84.0, w + 48.0, lines.size() * 25.0 + 14.0)
	# a dark band that fades out at both ends, gold hairlines top and bottom
	var mid := Color(0.03, 0.025, 0.02, 0.8)
	var clear := Color(0.03, 0.025, 0.02, 0.0)
	var e: float = 40.0
	draw_polygon(PackedVector2Array([Vector2(r.position.x - e, r.position.y), r.position, Vector2(r.position.x, r.end.y), Vector2(r.position.x - e, r.end.y)]), PackedColorArray([clear, mid, mid, clear]))
	draw_rect(r, mid)
	draw_polygon(PackedVector2Array([Vector2(r.end.x, r.position.y), Vector2(r.end.x + e, r.position.y), Vector2(r.end.x + e, r.end.y), r.end]), PackedColorArray([mid, clear, clear, mid]))
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1.0), Color(UiTheme.GOLD, 0.35))
	draw_rect(Rect2(r.position.x, r.end.y - 1.0, r.size.x, 1.0), Color(UiTheme.GOLD, 0.35))
	for i: int in lines.size():
		UiDraw.rich(self, Vector2(r.position.x, r.position.y + 26.0 + i * 25.0), lines[i], px, UiTheme.TEXT, r.size.x)


func _draw_title(vs: Vector2) -> void:
	if title == "" or _title_age > 2.6:
		return
	var a: float = clampf(1.0 - maxf(0.0, _title_age - 1.6), 0.0, 1.0) * clampf(_title_age * 4.0, 0.0, 1.0)
	var px: int = UiTheme.FS_DISPLAY
	var y: float = vs.y * 0.26
	var w: float = UiDraw.text_width(title, px)
	# a soft dark glow behind it (no hard edge anywhere) and a gold rule either side
	_soft_shade(Rect2(vs.x * 0.5 - w * 0.5 - 200.0, y - float(px) - 22.0, w + 400.0, float(px) + 56.0), 0.45 * a)
	var ry: float = y - float(px) * 0.33
	draw_line(Vector2(vs.x * 0.5 - w * 0.5 - 150.0, ry), Vector2(vs.x * 0.5 - w * 0.5 - 24.0, ry), Color(UiTheme.GOLD, 0.7 * a), 1.5, true)
	draw_line(Vector2(vs.x * 0.5 + w * 0.5 + 24.0, ry), Vector2(vs.x * 0.5 + w * 0.5 + 150.0, ry), Color(UiTheme.GOLD, 0.7 * a), 1.5, true)
	UiDraw.outlined(self, Vector2(0.0, y), title, px, Color(UiTheme.GOLD, a), HORIZONTAL_ALIGNMENT_CENTER, vs.x)


## The rune just discovered, under the title: a glyph in its affinity's colour, RUNE DISCOVERED,
## its name, what it means and where it was found. Fades in and out.
func _draw_rune_card(vs: Vector2) -> void:
	if _rune_card.is_empty():
		return
	var age: float = float(_rune_card["age"])
	var a: float = clampf(age * 3.0, 0.0, 1.0) * clampf((RUNE_CARD_S - age) / 0.8, 0.0, 1.0)
	var rid: String = str(_rune_card["id"])
	var rune: Dictionary = GameData.rune(rid)
	var aff: String = str(rune.get("affinity", ""))
	var col: Color = GameData.affinity_color(aff).lightened(0.3) if aff != "" else UiTheme.STAR
	var w := 600.0
	var h := 138.0
	var r := Rect2(vs.x * 0.5 - w * 0.5, vs.y * 0.155, w, h)
	_soft_shade(Rect2(r.position - Vector2(60, 30), r.size + Vector2(120, 60)), 0.5 * a)
	draw_rect(r, Color(0.035, 0.03, 0.05, 0.86 * a))
	draw_rect(r, Color(UiTheme.GOLD, 0.55 * a), false, 1.5)
	draw_rect(r.grow(-5.0), Color(UiTheme.GOLD, 0.18 * a), false, 1.0)
	var gc := Vector2(r.position.x + 70.0, r.position.y + h * 0.5)
	var pulse: float = 1.0 + 0.06 * sin(_time * 3.0)
	for k: int in 6:
		draw_circle(gc, (54.0 - float(k) * 7.0) * pulse, Color(col, (0.03 + float(k) * 0.025) * a))
	draw_circle(gc, 36.0, Color(0, 0, 0, 0.8 * a))
	draw_arc(gc, 37.0, 0.0, TAU, 48, Color(UiTheme.GOLD, 0.8 * a), 1.5, true)
	var spin: float = _time * 0.6
	for j: int in 3:
		var a0: float = spin + TAU * float(j) / 3.0
		draw_arc(gc, 44.0, a0, a0 + 1.3, 16, Color(col, 0.7 * a), 1.5, true)
	UiDraw.rune_glyph(self, gc, rid, str(rune.get("character", "")), 40, Color(col.lightened(0.35), a))
	var x: float = r.position.x + 128.0
	var tw: float = w - 140.0
	UiDraw.text(self, Vector2(x, r.position.y + 28.0), "R U N E   D I S C O V E R E D", 13, Color(UiTheme.GOLD, a), HORIZONTAL_ALIGNMENT_LEFT, tw)
	UiDraw.outlined(self, Vector2(x, r.position.y + 62.0), "%s%s" % [str(rune.get("name", rid)), ("   -   " + str(GameData.affinity(aff).get("label", aff))) if aff != "" else "   -   universal"], 26, Color(col.lightened(0.2), a), HORIZONTAL_ALIGNMENT_LEFT, tw, true)
	UiDraw.text(self, Vector2(x, r.position.y + 88.0), str(rune.get("meaning", "")), 14, Color(UiTheme.TEXT, a), HORIZONTAL_ALIGNMENT_LEFT, tw)
	var src: String = str(_rune_card.get("source", ""))
	UiDraw.text(self, Vector2(x, r.position.y + 112.0), (src.capitalize().substr(0, 1) + src.substr(1) + ".  " if src != "" else "") + "Yours for good, in any seal.", 12, Color(UiTheme.TEXT_FAINT, a), HORIZONTAL_ALIGNMENT_LEFT, tw)


# --- bottom left: message log ---------------------------------------------------------------

func _draw_log(vs: Vector2) -> void:
	var secs: float = GameData.num("hud", "log_seconds")
	var px: int = UiTheme.FS_SMALL
	var line_h := 21.0
	# as wide as the floor left of the health orb allows; a longer line wraps rather than run under it
	var width: float = clampf(_health_c.x - ORB_R - 40.0 - 18.0, 220.0, 480.0)
	var rows: Array = []            # [text, alpha], newest first
	var fade := 0.0
	for i: int in range(_log.size() - 1, -1, -1):
		var age: float = float(_log[i]["age"])
		if age > secs:
			continue
		var a: float = clampf((secs - age) / 2.0, 0.0, 1.0) * (1.0 if i == _log.size() - 1 else 0.82)
		fade = maxf(fade, a)
		var parts: Array[String] = _wrap(str(_log[i]["text"]), px, width)
		for k: int in range(parts.size() - 1, -1, -1):
			rows.append([parts[k], a])
	if rows.is_empty():
		return
	var bottom: float = vs.y - 22.0
	var top: float = bottom - rows.size() * line_h
	# a soft dark wash behind the lines, so they read over a bright floor
	_soft_shade(Rect2(-160.0, top - 34.0, width + 300.0, bottom - top + 70.0), 0.42 * fade)
	var y: float = bottom
	for row: Array in rows:
		UiDraw.outlined(self, Vector2(18.0, y), str(row[0]), px, Color(UiTheme.TEXT, float(row[1])))
		y -= line_h


## `text` cut into lines no wider than `width` at `px`, breaking between words.
static func _wrap(text: String, px: int, width: float) -> Array[String]:
	var out: Array[String] = []
	var line := ""
	for word: String in text.split(" "):
		var next: String = word if line == "" else line + " " + word
		if line != "" and UiDraw.text_width(next, px) > width:
			out.append(line)
			line = word
		else:
			line = next
	if line != "":
		out.append(line)
	return out


## A dark patch with soft edges: a 4 x 4 grid of vertices, the inner four dark and the rim clear,
## so the middle is an even shade and nothing behind text ever shows a hard line.
func _soft_shade(r: Rect2, alpha: float) -> void:
	var fx: float = r.size.x * 0.32
	var fy: float = r.size.y * 0.32
	var xs: Array[float] = [r.position.x, r.position.x + fx, r.end.x - fx, r.end.x]
	var ys: Array[float] = [r.position.y, r.position.y + fy, r.end.y - fy, r.end.y]
	var dark := Color(0, 0, 0, alpha)
	var clear := Color(0, 0, 0, 0)
	for i: int in 3:
		for j: int in 3:
			var quad := PackedVector2Array([Vector2(xs[i], ys[j]), Vector2(xs[i + 1], ys[j]), Vector2(xs[i + 1], ys[j + 1]), Vector2(xs[i], ys[j + 1])])
			var cols := PackedColorArray([
				dark if (i in [1, 2] and j in [1, 2]) else clear,
				dark if (i + 1 in [1, 2] and j in [1, 2]) else clear,
				dark if (i + 1 in [1, 2] and j + 1 in [1, 2]) else clear,
				dark if (i in [1, 2] and j + 1 in [1, 2]) else clear])
			draw_polygon(quad, cols)


# --- bottom right: key reminders --------------------------------------------------------------

func _draw_hints(vs: Vector2) -> void:
	var inv: Inventory = player.get("inventory")
	var heavy: bool = inv.weight() > inv.capacity() * 0.9
	var rows: Array = [
		["Inventory  %d / %d kg" % [int(inv.weight()), int(inv.capacity())], "inventory", heavy],
		["Soul", "ethercosm", false],
		["Project", "project", false],
		["Menu", "settings", false],
	]
	var px: int = UiTheme.FS_CAPTION + 1
	var y: float = vs.y - 18.0 - float(rows.size() - 1) * 24.0
	for row: Array in rows:
		var a: float = 1.0 if bool(row[2]) else _hint_alpha     # an over-full pack is said even mid-fight
		if a > 0.02:
			var key: String = Keybinds.binding_text(str(row[1]))
			var kw: float = maxf(float(px) + 6.0, UiDraw.text_width(key, px - 1) + 10.0)
			var right: float = vs.x - 16.0
			UiDraw.keycap(self, Vector2(right - kw, y), key, px, a)
			UiDraw.outlined(self, Vector2(right - kw - 8.0 - UiDraw.text_width(str(row[0]), px), y), str(row[0]), px,
				Color(UiTheme.BAD if bool(row[2]) else UiTheme.TEXT_DIM, a))
		y += 24.0


# --- over the world ---------------------------------------------------------------------------

func _draw_enemy_bars() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var show_all: bool = GameData.num("hud", "show_untouched_enemy_bars") > 0.0
	for node: Node in get_tree().get_nodes_in_group("nether_enemies" if not nether.is_empty() else "enemies"):
		var e := node as Node3D
		if e == null or cam.is_position_behind(e.global_position):
			continue
		var b: Body = e.get("body")
		if b == null or b.is_dead():
			continue
		_draw_telegraph(e, cam)
		var lit: bool = int(e.get("highlight")) > 0
		if not nether.is_empty():
			# out here you need to know what a thing is before you decide to fight it
			var tag: Vector2 = cam.unproject_position(e.global_position + Vector3.UP * (float(e.get("height")) + 0.75))
			UiDraw.outlined(self, Vector2(tag.x - 120.0, tag.y), str(e.get("display_name")), UiTheme.FS_CAPTION + 1,
				Color("fff3d0") if lit else (UiTheme.GOLD if str(e.get("tier")) != "vestige" else UiTheme.STAR), HORIZONTAL_ALIGNMENT_CENTER, 240.0)
		var top: Vector2 = cam.unproject_position(e.global_position + Vector3.UP * (float(e.get("height")) + 0.35))
		var w: float = 50.0 + float(e.get("radius")) * 24.0
		_draw_statuses(e, Vector2(top.x, top.y - 15.0))
		# poise: a thin second bar, shown once it has been dented
		var poise_max: Variant = e.get("poise_max")
		if poise_max != null and float(poise_max) < 10000.0 and float(e.get("poise")) < float(poise_max):
			UiDraw.bar(self, Rect2(top.x - w * 0.5, top.y + 4.0, w, 3.0), float(e.get("poise")) / float(poise_max), Color("ffd27a"))
		if b.total() >= b.total_max() and not lit and not show_all:
			continue                      # untouched enemies show no bar - less clutter
		UiDraw.bar(self, Rect2(top.x - w * 0.5, top.y - 4.0, w, 6.0), b.total() / b.total_max(), UiTheme.HEALTH_SUPERFICIAL if not lit else Color("f0563f"))


## The attack an enemy is winding up, drawn where it will land: a circle that fills for a slam,
## a line for a shot (thin while it still follows you, solid once the aim has locked). An attack
## that an interrupting skill would punish is drawn white.
func _draw_telegraph(e: Node3D, cam: Camera3D) -> void:
	var t: Variant = e.get("telegraph")
	if not (t is Dictionary) or (t as Dictionary).is_empty():
		return
	var tele: Dictionary = t
	var danger := Color(1.0, 0.36, 0.22)
	var white := Color(1, 1, 1)
	var col: Color = white if bool(tele.get("interruptible", false)) else danger
	match str(tele.get("kind", "")):
		"circle":
			var r: float = float(tele["radius"])
			var frac: float = clampf(float(tele.get("frac", 0.0)), 0.0, 1.0)
			var outer := PackedVector2Array()
			var inner := PackedVector2Array()
			for i: int in 49:
				var a: float = TAU * float(i) / 48.0
				var off := Vector3(cos(a), 0.0, sin(a))
				outer.append(cam.unproject_position(e.global_position + off * r + Vector3.UP * 0.05))
				inner.append(cam.unproject_position(e.global_position + off * r * frac + Vector3.UP * 0.05))
			draw_polyline(outer, Color(0, 0, 0, 0.45), 5.0, true)
			draw_polyline(outer, Color(col, 0.9), 2.5, true)
			if frac > 0.02:
				draw_colored_polygon(inner, Color(danger, 0.22))
		"line":
			var from: Vector2 = cam.unproject_position(e.global_position + Vector3.UP * 1.1)
			var to: Vector2 = cam.unproject_position((tele["to"] as Vector3) + Vector3.UP * 1.0)
			var locked: bool = bool(tele.get("locked", false))
			draw_line(from, to, Color(0, 0, 0, 0.4), 5.0 if locked else 3.0, true)
			draw_line(from, to, Color(danger, 0.95 if locked else 0.5), 3.0 if locked else 1.5, true)
			draw_circle(to, 5.0 if locked else 3.0, Color(danger, 0.9 if locked else 0.5))
		"cone":
			# a sweep: the wedge it will cover, filling as it comes
			var aim: Vector3 = tele["dir"]
			var half: float = deg_to_rad(float(tele["arc_deg"]) * 0.5)
			var reach: float = float(tele["radius"])
			var fill: float = clampf(float(tele.get("frac", 0.0)), 0.0, 1.0)
			var edge := PackedVector2Array([cam.unproject_position(e.global_position + Vector3.UP * 0.05)])
			var inside := PackedVector2Array([edge[0]])
			for i: int in 17:
				var ray: Vector3 = aim.rotated(Vector3.UP, lerpf(-half, half, float(i) / 16.0))
				edge.append(cam.unproject_position(e.global_position + ray * reach + Vector3.UP * 0.05))
				inside.append(cam.unproject_position(e.global_position + ray * reach * fill + Vector3.UP * 0.05))
			edge.append(edge[0])
			draw_polyline(edge, Color(0, 0, 0, 0.45), 5.0, true)
			draw_polyline(edge, Color(danger, 0.9), 2.5, true)
			if fill > 0.05:
				draw_colored_polygon(inside, Color(danger, 0.22))
		"lane":
			# a charge: the strip of floor it will run down
			var start: Vector3 = e.global_position + Vector3.UP * 0.05
			var finish: Vector3 = (tele["to"] as Vector3) + Vector3.UP * 0.05
			var along: Vector3 = finish - start
			if along.length() > 0.1:
				var side: Vector3 = Vector3(-along.z, 0.0, along.x).normalized() * float(tele.get("width", 2.0)) * 0.5
				var done: Vector3 = start + along * clampf(float(tele.get("frac", 0.0)), 0.0, 1.0)
				var strip := PackedVector2Array([cam.unproject_position(start - side), cam.unproject_position(finish - side),
					cam.unproject_position(finish + side), cam.unproject_position(start + side)])
				draw_colored_polygon(PackedVector2Array([strip[0], cam.unproject_position(done - side), cam.unproject_position(done + side), strip[3]]), Color(danger, 0.25))
				strip.append(strip[0])
				draw_polyline(strip, Color(white, 0.6 + 0.4 * sin(_time * 18.0)), 2.5, true)
		"swing":
			if bool(tele.get("interruptible", false)):
				var head: Vector2 = cam.unproject_position(e.global_position + Vector3.UP * (float(e.get("height")) + 0.2))
				draw_arc(head, 10.0, 0.0, TAU, 20, Color(0, 0, 0, 0.5), 4.5, true)
				draw_arc(head, 10.0, 0.0, TAU, 20, Color(white, 0.6 + 0.4 * sin(_time * 18.0)), 2.5, true)


## What a skill has left on an enemy, above its health bar: one pip per Live mark (the third is
## an Overload, so the count matters), a drop while Soaked, a flash of bars while stunned.
func _draw_statuses(e: Node3D, at: Vector2) -> void:
	var st: Variant = e.get("statuses")
	if not (st is Dictionary) or (st as Dictionary).is_empty():
		return
	var have: Dictionary = st
	var x: float = at.x
	if have.has("live"):
		var live: Dictionary = GameData.status("live")
		var n: int = int((have["live"] as Dictionary)["stacks"])
		var total: int = int(live.get("stacks", 3))
		var col := Color(str(live.get("color", "d9c8ff")))
		x = at.x - float(total - 1) * 6.0
		for i: int in total:
			var c := Vector2(x + float(i) * 12.0, at.y)
			var pip := PackedVector2Array([c + Vector2(0, -5), c + Vector2(4.5, 0), c + Vector2(0, 5), c + Vector2(-4.5, 0)])
			if i < n:
				draw_colored_polygon(pip, col)
			pip.append(pip[0])
			draw_polyline(pip, Color(0, 0, 0, 0.6), 3.0, true)
			draw_polyline(pip, Color(col, 0.9) if i < n else Color(col, 0.35), 1.5, true)
		x = at.x + float(total - 1) * 6.0 + 16.0
	if have.has("alight"):
		# one small flame per stack
		var fire := Color(str(GameData.status("alight").get("color", "ff8a3c")))
		var stacks: int = int((have["alight"] as Dictionary)["stacks"])
		for i: int in stacks:
			var fc := Vector2(x + float(i) * 8.0, at.y + sin(_time * 9.0 + float(i)) * 1.2)
			draw_colored_polygon(PackedVector2Array([fc + Vector2(0, -7), fc + Vector2(4.5, 2), fc + Vector2(0, 6), fc + Vector2(-4.5, 2)]), Color(0, 0, 0, 0.5))
			draw_colored_polygon(PackedVector2Array([fc + Vector2(0, -6), fc + Vector2(3.5, 2), fc + Vector2(0, 5), fc + Vector2(-3.5, 2)]), fire)
		x += float(stacks) * 8.0 + 6.0
	if have.has("soaked"):
		UiDraw.icon(self, "drop", Vector2(x, at.y - 1.0), 13.0, Color(str(GameData.status("soaked").get("color", "4f9be8"))))
		x += 15.0
	if have.has("aloft"):
		# off the ground: two short lines under an upward chevron
		var air := Color(str(GameData.status("aloft").get("color", "bfe9dc")))
		var ac := Vector2(at.x, at.y - 15.0)
		draw_polyline(PackedVector2Array([ac + Vector2(-7, 2), ac + Vector2(0, -6), ac + Vector2(7, 2)]), air, 2.5, true)
		draw_line(ac + Vector2(-5, 6), ac + Vector2(5, 6), Color(air, 0.7), 2.0, true)
	if have.has("frenzied"):
		# worked up by the censer: two red chevrons, pointing up
		var red := Color(str(GameData.status("frenzied").get("color", "ff5a4a")))
		for k: int in 2:
			var fc2 := Vector2(x + 4.0, at.y + 3.0 - float(k) * 6.0)
			draw_polyline(PackedVector2Array([fc2 + Vector2(-5, 3), fc2 + Vector2(0, -3), fc2 + Vector2(5, 3)]), red, 2.5, true)
		x += 16.0
	if have.has("roused"):
		# its next blow is heavy: a white ring that beats
		draw_arc(Vector2(at.x, at.y - 16.0), 7.0 + 2.0 * sin(_time * 10.0), 0.0, TAU, 18, Color(1, 1, 1, 0.9), 2.5, true)
	if have.has("staggered"):
		# off its feet: the moment for a bare strike
		var gold := Color(str(GameData.status("staggered").get("color", "ffd27a")))
		var c := Vector2(at.x, at.y - 15.0)
		draw_line(c + Vector2(-9, 0), c + Vector2(9, 0), gold, 2.5, true)
		draw_line(c + Vector2(-6, -5), c + Vector2(6, 5), gold, 2.0, true)
		draw_line(c + Vector2(-6, 5), c + Vector2(6, -5), gold, 2.0, true)
	if have.has("stunned"):
		var col2 := Color(str(GameData.status("stunned").get("color", "fff2a8")))
		for k: int in 3:
			var a: float = _time * 6.0 + float(k) * TAU / 3.0
			draw_circle(Vector2(at.x, at.y - 16.0) + Vector2(cos(a) * 9.0, sin(a) * 3.5), 2.4, col2)
	# every other status (2026-10-22: the status engine's many): a small chip of its colour with the
	# first letters of its name and its stacks, in a row above the marks
	var drawn: Array = ["live", "alight", "soaked", "aloft", "frenzied", "roused", "staggered", "stunned"]
	var chips: Array = []
	for id: String in have:
		var def: Dictionary = GameData.status(id)
		if drawn.has(id) or bool(def.get("hidden", false)):
			continue
		var n: int = int((have[id] as Dictionary).get("stacks", 1))
		chips.append([str(def.get("label", id)).left(4).to_upper() + (" %d" % n if n > 1 else ""), Color(str(def.get("color", "ffffff")))])
	if chips.is_empty():
		return
	var cw: Array = chips.map(func(c: Array) -> float: return UiDraw.text_width(str(c[0]), 11) + 8.0)
	var total_w: float = 0.0
	for wv: Variant in cw:
		total_w += float(wv) + 3.0
	var cxp: float = at.x - total_w * 0.5
	for i: int in chips.size():
		var r := Rect2(cxp, at.y - 31.0, float(cw[i]), 14.0)
		draw_rect(r, Color(0.05, 0.04, 0.03, 0.8))
		draw_rect(r, Color(chips[i][1] as Color, 0.95), false, 1.0)
		UiDraw.outlined(self, Vector2(r.position.x + 4.0, r.end.y - 3.0), str(chips[i][0]), 11, (chips[i][1] as Color).lightened(0.25))
		cxp += float(cw[i]) + 3.0


## Wisps close to the projection say what they are, and whether they will come to you.
func _draw_wisp_labels() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	var at: Variant = nether.get("position")
	if cam == null or at == null:
		return
	var mine: Array = player.get("affinities")
	var reach: float = GameData.num("hud", "wisp_label_range")
	for node: Node in get_tree().get_nodes_in_group("nether_wisps"):
		var w := node as Node3D
		if w == null or cam.is_position_behind(w.global_position) or w.global_position.distance_to(at) > reach:
			continue
		var kind: String = str(w.get("affinity"))
		var p: Vector2 = cam.unproject_position(w.global_position + Vector3.UP * 1.05)
		var text: String = "ether"
		var col: Color = Color(0.82, 0.84, 0.92, 0.9)
		if kind != "plain":
			var yours: bool = mine.has(kind)
			text = "%s wisp" % str(GameData.affinity(kind).get("label", kind)).to_lower() + ("" if yours else "  -  not yours")
			col = GameData.affinity_color(kind).lightened(0.4) if yours else Color(0.66, 0.64, 0.72, 0.9)
		UiDraw.outlined(self, Vector2(p.x - 100.0, p.y), text, UiTheme.FS_CAPTION, col, HORIZONTAL_ALIGNMENT_CENTER, 200.0)


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
	var r := Rect2(vs.x * 0.5 - 210.0, _dock.position.y - 150.0, 420.0, 114.0)
	_panel_rects.append(r)
	UiDraw.frame(self, r, "panel_nether")
	UiDraw.outlined(self, Vector2(r.position.x, r.position.y + 25.0), "THE NETHERECHO", UiTheme.FS_CAPTION + 1, UiTheme.STAR, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var hp: float = float(nether.get("hp", 0.0))
	var hp_max: float = maxf(1.0, float(nether.get("hp_max", 1.0)))
	var danger: bool = hp / hp_max <= 0.5
	var hp_col: Color = Color("7fe6ff") if not danger else Color("ff7a6b").lerp(Color(1, 1, 1), 0.3 + 0.3 * sin(_time * 9.0))
	var x: float = r.position.x + 20.0
	var bw: float = r.size.x - 40.0
	UiDraw.bar(self, Rect2(x, r.position.y + 34.0, bw, 11.0), hp / hp_max, hp_col)
	UiDraw.outlined(self, Vector2(x, r.position.y + 62.0), "projection  %d / %d" % [int(ceil(hp)), int(hp_max)], UiTheme.FS_CAPTION + 1, UiTheme.TEXT)
	UiDraw.outlined(self, Vector2(x, r.position.y + 62.0), "if it dies, you die", UiTheme.FS_CAPTION, Color("ff9a8a") if danger else UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT, bw)
	var leash: float = clampf(float(nether.get("leash", 0.0)), 0.0, 1.0)
	UiDraw.bar(self, Rect2(x, r.position.y + 70.0, bw, 6.0), leash, Color("b08cff") if leash < 0.92 else UiTheme.BAD)
	UiDraw.outlined(self, Vector2(x, r.position.y + 94.0),
		"tether to your body" + ("  -  at its limit" if bool(nether.get("at_leash", false)) else ""), UiTheme.FS_CAPTION, UiTheme.BAD if bool(nether.get("at_leash", false)) else UiTheme.TEXT_DIM)
	UiDraw.outlined(self, Vector2(x, r.position.y + 94.0), "gathered %d    subdued %d" % [int(nether.get("gathered", 0)), int(nether.get("subdued", 0))],
		UiTheme.FS_CAPTION, UiTheme.STAR, HORIZONTAL_ALIGNMENT_RIGHT, bw)


# --- top right: minimap, passage tracker -------------------------------------------------------

## The minimap (top right, out in a zone): north up, as the screen is. What you have not been
## near is under the fog; the edges, the road, the landmarks, the lines and the dungeon door show
## once seen. Your arrow, and any corpse of yours, always show.
func _draw_minimap(vs: Vector2) -> void:
	if minimap.is_empty():
		return
	var zsize: Vector2 = minimap["size"]
	var fog: FogMap = minimap["fog"]
	var def: Dictionary = minimap["def"]
	var w: float = GameData.num("minimap", "size_px")
	var k: float = w / zsize.x
	var r := Rect2(vs.x - w - 24.0, 24.0, w, zsize.y * k)
	var outer := Rect2(r.position - Vector2(12, 12), r.size + Vector2(24, 52))
	_panel_rects.append(outer)
	UiDraw.frame(self, outer, "panel")
	var to_map := func(x: float, y: float) -> Vector2:
		return r.position + Vector2(x, y) * k
	draw_rect(r, Color(0.4, 0.33, 0.23))
	# the road
	var road: Dictionary = def.get("road", {})
	var pts: Array = road.get("points", [])
	for i: int in pts.size() - 1:
		draw_line(to_map.call(float(pts[i][0]), float(pts[i][1])), to_map.call(float(pts[i + 1][0]), float(pts[i + 1][1])),
			Color(0.6, 0.51, 0.36), maxf(2.0, float(road.get("width", 8.0)) * k), true)
	_draw_minimap_country(def, to_map, k)
	# the Cut House and its door
	var ch: Dictionary = def.get("cut_house", {})
	if not ch.is_empty():
		var yard: Array = ch["yard"]
		var a: Vector2 = to_map.call(float(yard[0]), float(yard[1]))
		var b: Vector2 = to_map.call(float(yard[2]), float(yard[3]))
		draw_rect(Rect2(a, b - a), Color(0.66, 0.38, 0.28), false, 2.0)
		var door: Array = ch["door"]
		draw_circle(to_map.call(float(door[0]), float(door[1])), 4.0, Color(0.95, 0.75, 0.35))
	# landmarks
	for mark: Dictionary in def.get("landmarks", []):
		var at: Array = mark["at"]
		draw_circle(to_map.call(float(at[0]), float(at[1])), 3.0, Color(0.92, 0.87, 0.72))
	# the fog, over all of it: a dark sepia, so the unexplored still reads as map, not as a hole
	draw_texture_rect(_tinted_fog(fog), r, false)
	# zone lines: open ones bright, shut ones dim - drawn over the fog only where seen
	for line: Dictionary in def.get("lines", []):
		var at_l: float = float(line["at"])
		var half: float = float(line["width"]) * 0.5
		var p0: Vector2
		var p1: Vector2
		match str(line["edge"]):
			"north":
				p0 = to_map.call(at_l - half, 0.0)
				p1 = to_map.call(at_l + half, 0.0)
			"south":
				p0 = to_map.call(at_l - half, zsize.y)
				p1 = to_map.call(at_l + half, zsize.y)
			"east":
				p0 = to_map.call(zsize.x, at_l - half)
				p1 = to_map.call(zsize.x, at_l + half)
			_:
				p0 = to_map.call(0.0, at_l - half)
				p1 = to_map.call(0.0, at_l + half)
		var mid: Vector2 = (p0 + p1) * 0.5
		var seen_at: Vector2 = (mid - r.position) / k
		if fog.is_seen(clampf(seen_at.x, 0.0, zsize.x - 0.1), clampf(seen_at.y, 0.0, zsize.y - 0.1)):
			draw_line(p0, p1, Color(0.5, 1.0, 0.6) if bool(line.get("open", false)) else Color(0.7, 0.4, 0.35), 4.0, true)
	# names of what you have seen
	for mark: Dictionary in def.get("landmarks", []):
		var at2: Array = mark["at"]
		if fog.is_seen(float(at2[0]), float(at2[1])):
			UiDraw.outlined(self, to_map.call(float(at2[0]), float(at2[1])) + Vector2(6.0, 4.0), str(mark.get("name", "")), UiTheme.FS_CAPTION - 1, Color(0.96, 0.92, 0.8))
	if not ch.is_empty():
		var door2: Array = ch["door"]
		if fog.is_seen(float(door2[0]) - 1.0, float(door2[1])):
			UiDraw.outlined(self, to_map.call(float(door2[0]), float(door2[1])) + Vector2(-70.0, -8.0), str(ch.get("name", "")), UiTheme.FS_CAPTION - 1, Color(0.97, 0.78, 0.4))
	_draw_minimap_life(def, fog, to_map)
	# your corpses
	for c: Vector2 in minimap.get("corpses", []):
		var cp: Vector2 = to_map.call(c.x, c.y)
		draw_line(cp + Vector2(-4, -4), cp + Vector2(4, 4), Color(1, 0.35, 0.3), 2.5, true)
		draw_line(cp + Vector2(-4, 4), cp + Vector2(4, -4), Color(1, 0.35, 0.3), 2.5, true)
	# you
	var me: Vector2 = to_map.call((minimap["at"] as Vector2).x, (minimap["at"] as Vector2).y)
	var f: Vector2 = minimap.get("facing", Vector2(0, -1))
	if f.length() < 0.01:
		f = Vector2(0, -1)
	f = f.normalized()
	var side := Vector2(-f.y, f.x)
	var arrow := PackedVector2Array([me + f * 8.0, me - f * 4.5 + side * 5.0, me - f * 2.0, me - f * 4.5 - side * 5.0])
	draw_colored_polygon(arrow, Color(0, 0, 0, 0.6))
	draw_colored_polygon(PackedVector2Array([me + f * 7.0, me - f * 4.0 + side * 4.5, me - f * 2.0, me - f * 4.0 - side * 4.5]), Color(0.6, 0.92, 1.0))
	draw_rect(r, Color(0, 0, 0, 0.8), false, 1.0)
	# north, and the caption strip under the map
	UiDraw.outlined(self, Vector2(r.position.x + 6.0, r.position.y + 15.0), "N", UiTheme.FS_CAPTION, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
	UiDraw.text(self, Vector2(r.position.x + 12.0, r.end.y + 22.0), str(def.get("name", "")), UiTheme.FS_SMALL, UiTheme.TEXT)
	UiDraw.text(self, Vector2(r.position.x, r.end.y + 22.0), "%d%% explored" % int(round(fog.explored() * 100.0)), UiTheme.FS_CAPTION, UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 12.0)


## Under the fog: the zone's tracks and its power line (the road is drawn by _draw_minimap).
func _draw_minimap_country(def: Dictionary, to_map: Callable, k: float) -> void:
	for track: Dictionary in def.get("tracks", []):
		var tp: Array = track.get("points", [])
		for i: int in tp.size() - 1:
			draw_line(to_map.call(float(tp[i][0]), float(tp[i][1])), to_map.call(float(tp[i + 1][0]), float(tp[i + 1][1])),
				Color(0.55, 0.46, 0.33), maxf(1.5, float(track.get("width", 4.0)) * k), true)
	var poles: Array = (def.get("power_line", {}) as Dictionary).get("poles", [])
	for i: int in poles.size():
		var p: Vector2 = to_map.call(float(poles[i][0]), float(poles[i][1]))
		draw_circle(p, 1.6, Color(0.25, 0.2, 0.16))
		if i + 1 < poles.size() and (poles[i] as Array).size() < 3 and (poles[i + 1] as Array).size() < 3:
			draw_line(p, to_map.call(float(poles[i + 1][0]), float(poles[i + 1][1])), Color(0.22, 0.2, 0.18, 0.7), 1.0, true)


## Over the fog, where seen: the dungeon mouths (a ring, named) and the camps - dull red asleep,
## bright red awake, green for a herd left alone, a grey cross once cleared.
func _draw_minimap_life(def: Dictionary, fog: FogMap, to_map: Callable) -> void:
	for e: Dictionary in def.get("entrances", []):
		var at: Array = e["at"]
		if not fog.is_seen(float(at[0]), float(at[1])):
			continue
		var p: Vector2 = to_map.call(float(at[0]), float(at[1]))
		draw_arc(p, 5.0, 0.0, TAU, 14, Color(0, 0, 0, 0.7), 3.5, true)
		draw_arc(p, 5.0, 0.0, TAU, 14, Color(0.95, 0.75, 0.35), 2.0, true)
		draw_circle(p, 2.0, Color(0.05, 0.04, 0.04))
		UiDraw.outlined(self, p + Vector2(7.0, 4.0), str(e.get("name", "")), UiTheme.FS_CAPTION - 1, Color(0.97, 0.78, 0.4))
	for c: Dictionary in minimap.get("camps", []):
		var at2: Vector2 = c["at"]
		if not fog.is_seen(clampf(at2.x, 0.0, (minimap["size"] as Vector2).x - 0.1), clampf(at2.y, 0.0, (minimap["size"] as Vector2).y - 0.1)):
			continue
		var cp: Vector2 = to_map.call(at2.x, at2.y)
		match str(c.get("state", "")):
			"cleared":
				draw_line(cp + Vector2(-3, -3), cp + Vector2(3, 3), Color(0.6, 0.6, 0.6), 2.0, true)
				draw_line(cp + Vector2(-3, 3), cp + Vector2(3, -3), Color(0.6, 0.6, 0.6), 2.0, true)
			"calm":
				draw_circle(cp, 4.0, Color(0, 0, 0, 0.6))
				draw_circle(cp, 3.0, Color(0.55, 0.8, 0.45))
			"awake", "returning":
				draw_circle(cp, 4.5, Color(0, 0, 0, 0.6))
				draw_circle(cp, 3.5, Color(1.0, 0.3, 0.2))
			_:
				draw_circle(cp, 4.0, Color(0, 0, 0, 0.6))
				draw_circle(cp, 3.0, Color(0.7, 0.3, 0.22))


## The fog map's texture is black where unseen; the minimap wants it sepia. A tinted copy is kept
## and remade only when more of the zone has been seen (the map is a few thousand cells).
func _tinted_fog(fog: FogMap) -> Texture2D:
	var seen: float = fog.explored()
	if _fog_tex == null or not is_equal_approx(seen, _fog_seen) or _fog_src != fog:
		var img: Image = fog.image.duplicate()
		for y: int in img.get_height():
			for x: int in img.get_width():
				img.set_pixel(x, y, Color(FOG_TINT, FOG_TINT.a * img.get_pixel(x, y).a))
		if _fog_tex == null or _fog_tex.get_size() != Vector2(img.get_size()):
			_fog_tex = ImageTexture.create_from_image(img)
		else:
			_fog_tex.update(img)
		_fog_seen = seen
		_fog_src = fog
	return _fog_tex


func _draw_tracker(vs: Vector2) -> void:
	if passage.is_empty():
		return
	var walls: int = int(passage.get("walls", 0))
	var cleared: int = int(passage.get("cleared", 0))
	var current: int = int(passage.get("current", 0))
	var gate: int = int(passage.get("gate", 0))
	var step := 26.0
	var w: float = maxf(walls * step + 36.0, 250.0)
	var r := Rect2(vs.x - w - 12.0, 12.0, w, 88.0)
	_panel_rects.append(r)
	UiDraw.frame(self, r, "panel")
	UiDraw.text(self, r.position + Vector2(18.0, 28.0), "THE PASSAGE", UiTheme.FS_CAPTION + 1, UiTheme.TEXT_DIM)
	UiDraw.text(self, Vector2(r.position.x, r.position.y + 28.0), "spoils $%d" % int(passage.get("bank", 0)), UiTheme.FS_SMALL, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 18.0)
	var x0: float = r.get_center().x - float(walls - 1) * step * 0.5
	for i: int in walls:
		var c := Vector2(x0 + i * step, r.position.y + 50.0)
		var n: int = i + 1
		var fill: Color = UiTheme.INSET
		var edge: Color = UiTheme.BRONZE
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
			UiDraw.text(self, Vector2(c.x - 30.0, c.y + 30.0), "exit", UiTheme.FS_CAPTION, UiTheme.GOOD if cleared >= gate else UiTheme.TEXT_FAINT, HORIZONTAL_ALIGNMENT_CENTER, 60.0)


# --- tooltips ---------------------------------------------------------------------------------------

func _draw_tooltip(vs: Vector2) -> void:
	var m: Vector2 = get_local_mouse_position()
	var what: String = debug_tip
	if what == "":
		for i: int in _slot_rects.size():
			if _slot_rects[i].has_point(m):
				what = "slot:%d" % i
		if _strike_rect.has_point(m):
			what = "strike"
		elif _shoot_rect.has_point(m):
			what = "shoot"
		elif m.distance_to(_health_c) <= ORB_R + 14.0:
			what = "health"
		elif m.distance_to(_essence_c) <= ORB_R + 14.0:
			what = "essence"
		# a short rest before it opens, so sweeping the mouse across the bar does not flicker
		if what != _tip_what:
			_tip_what = what
			_tip_age = 0.0
		_tip_age += get_process_delta_time()
		if _tip_age < GameData.num("hud", "tooltip_delay_s"):
			return
	if what == "":
		return
	var anchor: Vector2 = m
	if what.begins_with("slot:"):
		var si: int = int(what.get_slice(":", 1))
		anchor = _slot_rects[si].get_center() if si < _slot_rects.size() else m
	elif what == "strike":
		anchor = _strike_rect.get_center()
	elif what == "shoot":
		anchor = _shoot_rect.get_center()
	elif what == "health":
		anchor = _health_c
	elif what == "essence":
		anchor = _essence_c

	var body_px: int = UiTheme.FS_SMALL
	var lines: Array = []           # [[text, size, color]]
	if what.begins_with("slot:"):
		var i: int = int(what.get_slice(":", 1))
		var hotbar: Array = player.get("hotbar")
		var abilities: Array = player.get("abilities")
		var idx: int = int(hotbar[i]) if i < hotbar.size() else -1
		if idx < 0 or idx >= abilities.size():
			lines.append(["Empty slot", 17, UiTheme.TEXT_DIM])
			lines.append(["Learn an ability, then set it here in the ethercosm (%s)." % Keybinds.binding_text("ethercosm"), body_px, UiTheme.TEXT_FAINT])
		else:
			var st: Dictionary = abilities[idx]
			var ab: Dictionary = player.call("ability_stats", st)
			lines.append([str(ab.get("name", "?")), 19, UiTheme.GOLD])
			lines.append([UiTheme.verse_of(ab), body_px - 1, UiTheme.STAR])
			if str(ab.get("summary", "")) != "":
				lines.append([str(ab["summary"]), body_px, UiTheme.TEXT])
			lines.append(["%s affinity" % str(GameData.affinity(str(ab.get("affinity", ""))).get("label", "?")), body_px, GameData.affinity_color(str(ab.get("affinity", ""))).lightened(0.3)])
			lines.append(["Costs %d essence and leaves %d reflux" % [int(round(float(ab.get("cost", 0.0)))), int(round(float(ab.get("cost", 0.0)) * float(ab.get("reflux_per_cost", 1.0))))], body_px, UiTheme.TEXT])
			match str(ab.get("kind", "")):
				"projectile":
					lines.append(["%d damage at range" % int(float(ab.get("damage", 0.0)) * float(player.call("ability_damage_mult", int(st["stage"]))) * float(ab.get("damage_all", 1.0))), body_px, UiTheme.TEXT])
				"melee_burst":
					lines.append(["Hits everything in front of you for x%.1f a normal blow" % float(ab.get("damage_mult", 1.0)), body_px, UiTheme.TEXT])
				"dash":
					lines.append(["A burst of movement in the direction you are heading", body_px, UiTheme.TEXT])
				"prop":
					lines.append(["A wall %d m across that stands for %d s" % [int(round(float(ab.get("width", 3.0)))), int(round(float(ab.get("life", 12.0))))], body_px, UiTheme.TEXT])
			if float(ab.get("windup", 0.0)) > 0.0:
				var set_text: String = ""
				if bool(ab.get("braced", false)):
					set_text = "   -   Braced: %d%% less damage, and nothing staggers you" % int(round((1.0 - GameData.num("braced", "damage_taken_mult")) * 100.0))
				lines.append(["%.2f s wind-up, rooted%s" % [float(ab["windup"]), set_text], body_px, UiTheme.TEXT_DIM])
			lines.append(["Stage %d   -   %d%% toward the next" % [int(st["stage"]), int(float(st["progress"]))], body_px, UiTheme.TEXT_DIM])
			var rune_fx: Array = player.call("rune_summary", idx)
			if not rune_fx.is_empty():
				lines.append(["Sealed word: " + ", ".join(PackedStringArray(rune_fx.map(func(v: Variant) -> String: return str(v)))), body_px, UiTheme.GOLD])
			var need: String = str(player.call("pending_tier", st))
			if need != "":
				lines.append(["Full. Ready for its level %d lock: needs a %s, bound on its seal (%s)." % [int(st["stage"]) + 1, need, Keybinds.binding_text("bind")], body_px, UiTheme.GOLD])
			for up: Dictionary in st.get("bound", []):
				lines.append(["Bound: %s of %s" % [str(up["tier"]), str(GameData.concept(str(up["concept"])).get("label", up["concept"]))], body_px, UiTheme.STAR])
	elif what == "strike":
		var arm_lost: bool = bool(player.get("arm_right_lost"))
		var strike: float = float(player.call("strike_damage")) * (GameData.num("player", "off_hand_factor") if arm_lost else 1.0)
		lines.append(["Strike", 19, UiTheme.GOLD])
		lines.append(["%d damage, %.1f m reach" % [int(round(strike)), float(player.call("reach_now"))], body_px, UiTheme.TEXT])
		lines.append(["Hold %s to overcharge: harder, slower, and it wears on the arm." % Keybinds.binding_text("overcharge"), body_px, UiTheme.TEXT_DIM])
		if arm_lost:
			lines.append(["Your striking arm is gone: you fight with the other one.", body_px, UiTheme.BAD])
	elif what == "shoot":
		var ranged: Dictionary = player.call("ranged_weapon")
		lines.append(["Shoot", 19, UiTheme.GOLD])
		if ranged.is_empty():
			lines.append(["Nothing to shoot with. A sling or bow goes in the ranged slot.", body_px, UiTheme.TEXT_DIM])
		else:
			lines.append(["%s:  %d damage every %.1f s" % [str(ranged.get("name", "?")), int(round(float(player.call("ranged_damage")))), float(player.call("ranged_interval"))], body_px, UiTheme.TEXT])
			lines.append(["Hold %s, then %s to loose. No essence." % [Keybinds.binding_text("ranged_stance"), Keybinds.binding_text("strike")], body_px, UiTheme.TEXT_DIM])
	elif what == "health":
		var b: Body = player.get("body")
		lines.append(["Your body", 19, UiTheme.GOLD])
		lines.append(["Health   %d / %d     refills on its own when nothing is trying to kill you" % [int(ceil(b.total())), int(b.total_max())], body_px, UiTheme.HEALTH_SUPERFICIAL.lightened(0.35)])
		if b.wounds.is_empty():
			lines.append(["No wounds.", body_px, UiTheme.TEXT_DIM])
		for w: Dictionary in b.wounds:
			lines.append(["%s   -%d health while it lasts   (%s)" % [str(w["name"]), int(round(float(w["max_cut"]))), Body.wound_state(w)], body_px, Color("ff8a5c")])
		if not b.wounds.is_empty():
			lines.append(["Wounds do not close by resting in the field: a night in town,", body_px, UiTheme.TEXT_DIM])
			lines.append(["the healer, or a talent that heals.", body_px, UiTheme.TEXT_DIM])
		lines.append(["The ring is your striking arm. Overcharging wears it out;", body_px, UiTheme.TEXT_DIM])
		lines.append(["lose it and only a healer or a talent brings it back.", body_px, UiTheme.TEXT_DIM])
	elif what == "essence":
		var pcts: Array = player.get("star_pct")
		lines.append(["Essence", 19, UiTheme.GOLD])
		lines.append(["%d of %d   -   your star holds %d%% of what it could" % [int(float(player.get("essence"))), int(float(player.get("essence_max"))), int(float(pcts.back()))], body_px, UiTheme.ESSENCE.lightened(0.45)])
		var rate: float = float(player.get("satellite_rate"))
		lines.append([("A satellite feeds you +%s a second." % String.num(rate, 1)) if rate > 0.0 else "No satellite: essence returns only when you meditate (%s)." % Keybinds.binding_text("meditate"), body_px, UiTheme.TEXT])
		var parts: Array[String] = []
		for a: Variant in player.get("affinities"):
			parts.append("%s %d" % [str(GameData.affinity(str(a)).get("label", a)).to_lower(), int(float(player.call("reflux_of", str(a))))])
		lines.append(["Reflux:  " + "   ".join(parts), body_px, UiTheme.REFLUX])
		lines.append(["The ring is reflux - heat left by every cast.", body_px, UiTheme.TEXT_DIM])
		lines.append(["Past %d casts cost more, past %d they recover slowly, at %d you are locked out." % [int(GameData.num("reflux", "pain_at")), int(GameData.num("reflux", "burn_at")), int(GameData.num("reflux", "lock_at"))], body_px, UiTheme.TEXT_DIM])
		lines.append(["Meditating sheds it fastest.", body_px, UiTheme.TEXT_DIM])

	var w := 0.0
	var h := 25.0
	for l: Array in lines:
		w = maxf(w, UiDraw.text_width(str(l[0]), int(l[1])))
		h += float(int(l[1])) + 7.0
	var r := Rect2(anchor.x - w * 0.5 - 18.0, _dock.position.y - h - 52.0, w + 36.0, h)
	if what == "health" or what == "essence":
		r.position.y = anchor.y - ORB_R - 70.0 - h
	r.position.x = clampf(r.position.x, 8.0, vs.x - r.size.x - 8.0)
	r.position.y = maxf(8.0, r.position.y)
	UiDraw.frame(self, r, "panel_plain")
	var y: float = r.position.y + 10.0
	for li: int in lines.size():
		var l: Array = lines[li]
		y += float(int(l[1])) + 2.0
		UiDraw.text(self, Vector2(r.position.x + 18.0, y), str(l[0]), int(l[1]), l[2])
		y += 5.0
		if li == 0:
			draw_line(Vector2(r.position.x + 18.0, y + 1.0), Vector2(r.end.x - 18.0, y + 1.0), Color(UiTheme.BRONZE, 0.6), 1.0)
			y += 3.0
