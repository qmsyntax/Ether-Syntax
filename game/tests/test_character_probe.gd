extends Node
## Test characters click test (windowed run only - needs real GUI hit-testing):
##   godot --path game res://tests/test_character_probe.tscn
## On the title screen, clicks the "Test characters" button for one affinity (Dream), then checks
## the character: that one affinity, every skill of it learned at the test stage, a full tank,
## marked as a test character, standing in town; then presses the hotbar_page key and checks that
## the bar shows the next six skills; then the first level lock, the same as anyone's (Brent
## 2026-10-23: no free edit, no binding on the main page): the ethercosm offers only "Open the seal",
## the seal screen opens at stage 0 forming ring 1 with the vestiges offered as its keystone; every
## place of ring 1 is filled by clicks and the word closed by drags (Brent 2026-10-24: full rings), a
## vestige of Reach set as the keystone, and Bind and lock clicked with the roll made sure (balance
## "binding" success_chance 1, put back after): stage 1, ring 1 full and sealed under the vestige, the
## bar refilled (the test override) and the level 2 lock open at once with the remnants; then the
## ethercosm's skill details: click a skill, its numbers and statuses,
## click a status name for its definition, the skill slots, the glossary. Prints "TESTCHAR: PASS" /
## "TESTCHAR: FAIL" and exits 0/1.

const AFF := "dream"

var main: Node
var frames := 0
var results: Array[String] = []
var failed := false
var _caps: Array[String] = []    # one-bond runes set on ring 1 and bonded to the skill
var _queue: Array[Callable] = []  # the lock's clicks and drags, one every few frames
var _queue_at := 0
var _lock_done := false
var _detail_from := 0            # the frame the skill-detail part began, 0 until then
var _chance := 0.0               # balance "binding" success_chance, put back after the sure roll


func _mouse(at: Vector2, pressed: bool, held: bool = false) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = at
	ev.global_position = at
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if (pressed or held) else 0
	get_viewport().push_input(ev)


func _move(at: Vector2, held: bool) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	mv.relative = Vector2(12, 12)
	mv.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	get_viewport().push_input(mv)


func _board() -> RuneBoard:
	return main.find_child("RuneBoard", true, false) as RuneBoard


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	main.set("_test_mode", true)
	add_child(main)


func _click(c: Control) -> void:
	if c == null:
		return
	_click_at(c.get_global_rect().get_center())


func _click_at(at: Vector2) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	get_viewport().push_input(mv)
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		get_viewport().push_input(ev)


## Point at a spot (a mouse move only, as a hand moves before it clicks).
func _point(at: Vector2) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	get_viewport().push_input(mv)


## Where skill `id` is drawn in the ethercosm, in viewport coordinates.
func _skill_spot(id: String) -> Vector2:
	var s: Node = main.get("screen")
	var cosmos: Control = s.get("_cosmos")
	var index: int = (main.get("player").get("abilities") as Array).map(func(st: Dictionary) -> String: return str(st["id"])).find(id)
	for n: Dictionary in (cosmos.get("_nodes") as Array):
		if int(n["index"]) == index:
			return cosmos.get_global_rect().position + (n["pos"] as Vector2)
	return Vector2(-1, -1)


## Scroll the detail panel so `c` is in view (as a player would), before it is clicked.
func _reveal(c: Control) -> void:
	var at: Node = c
	while at != null and not (at is ScrollContainer):
		at = at.get_parent()
	if at != null:
		(at as ScrollContainer).ensure_control_visible(c)


## The ethercosm's skill details (Brent 2026-10-23): click a skill, read its numbers and the status
## it leaves, click a status name and see its definition appear, reach the skill slots, and the glossary.
func _detail_steps(at: int) -> void:
	var player: Node = main.get("player")
	var s: Node = main.get("screen")
	match at:
		0:
			_point(_skill_spot("changeling_mask"))
		3:
			_click_at(_skill_spot("changeling_mask"))
		8:
			var want: int = (player.get("abilities") as Array).map(func(st: Dictionary) -> String: return str(st["id"])).find("changeling_mask")
			_expect("clicking Changeling Mask in the ethercosm selects it", s != null and int(s.get("selected")) == want
				and (main.find_child("SkillName", true, false) as Label).text == "Changeling Mask")
			var rows: Node = main.find_child("SkillDetailRows", true, false)
			_expect("its numbers are shown (range, cost, recovery...)", rows != null and rows.find_child("Row_Range", true, false) != null
				and rows.find_child("Row_Recovery", true, false) != null)
			var entry: Node = main.find_child("StatusEntry_masked", true, false)
			var body: Control = main.find_child("StatusDef_masked", true, false) as Control
			_expect("the status it leaves, Masked, is listed with its definition open", entry != null and body != null and body.visible
				and (body.find_child("StatusDesc", true, false) as Label).text == StatusText.desc("masked")
				and (body.find_child("StatusRules", true, false) as Label).text.contains("8 m"))
			var chip: Control = main.find_child("StatusTerm_masked", true, false) as Control
			_expect("its name carries the definition as a tooltip too", chip != null and chip.tooltip_text.contains(StatusText.desc("masked")))
			_reveal(chip)
		10:
			_click(main.find_child("StatusTerm_masked", true, false) as Control)
		14:
			_expect("clicking the name folds the definition", not (main.find_child("StatusDef_masked", true, false) as Control).visible)
			_point(_skill_spot("rousing_blow"))
		17:
			_click_at(_skill_spot("rousing_blow"))
		22:
			var body2: Control = main.find_child("StatusDef_asleep", true, false) as Control
			_expect("Rousing Blow lists Asleep, a status it works on, folded", (main.find_child("SkillName", true, false) as Label).text == "Rousing Blow"
				and body2 != null and not body2.visible)
			_reveal(main.find_child("StatusTerm_asleep", true, false) as Control)
		24:
			_click(main.find_child("StatusTerm_asleep", true, false) as Control)
		28:
			var body3: Control = main.find_child("StatusDef_asleep", true, false) as Control
			_expect("clicking the status name shows its definition in place", body3 != null and body3.is_visible_in_tree()
				and (body3.find_child("StatusDesc", true, false) as Label).text == StatusText.desc("asleep"))
			var slot: Control = main.find_child("SlotButton_0", true, false) as Control
			var vp := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
			_expect("the skill slots stay in reach below the scrolling details", slot != null and slot.is_visible_in_tree() and vp.encloses(slot.get_global_rect()))
			_click(slot)
		32:
			var want2: int = (player.get("abilities") as Array).map(func(st: Dictionary) -> String: return str(st["id"])).find("rousing_blow")
			_expect("and a click on one puts the skill there", int((player.get("hotbar") as Array)[0]) == want2, str(player.get("hotbar")))
			_click(main.find_child("GlossaryButton", true, false) as Control)
		38:
			var n: int = main.find_children("StatusEntry_*", "", true, false).size()
			_expect("the Statuses button lists every status (%d)" % StatusText.all_ids().size(), bool(main.get("screen").get("glossary")) and n == StatusText.all_ids().size(), str(n))
			main.call("close_screen")


func _expect(label: String, ok: bool, detail: String = "") -> void:
	results.append("%s %s %s" % ["ok  " if ok else "FAIL", label, "" if ok else detail])
	if not ok:
		failed = true


func _process(_delta: float) -> void:
	frames += 1
	var player: Node = main.get("player")
	match frames:
		30:
			var b: Node = main.find_child("Test_" + AFF, true, false)
			_expect("the title screen shows a Test characters button for %s" % AFF, b is Button and (b as Control).is_visible_in_tree())
			_expect("and one for every affinity", GameData.affinity_ids().all(func(a: String) -> bool: return main.find_child("Test_" + a, true, false) != null))
			_click(b as Control)
		60:
			var want: Array = GameData.abilities.keys().filter(func(id: String) -> bool: return str(GameData.ability(id)["affinity"]) == AFF)
			var have: Array = (player.get("abilities") as Array).map(func(s: Dictionary) -> String: return str(s["id"]))
			_expect("clicking it starts a %s character in town" % AFF, str(main.get("state")) == "town" and (player.get("affinities") as Array) == [AFF], str(player.get("affinities")))
			_expect("with every %s skill learned (%d)" % [AFF, want.size()], have.size() == want.size() and want.all(func(id: String) -> bool: return have.has(id)), "%d of %d" % [have.size(), want.size()])
			_expect("at the test stage, with a full tank", (player.get("abilities") as Array).all(func(s: Dictionary) -> bool: return int(s["stage"]) == GameData.inum("skills", "test_stage"))
				and is_equal_approx(float(player.get("essence")), float(player.get("essence_max"))))
			_expect("marked as a test character", bool(player.get("test_character")) and bool((player.call("to_save") as Dictionary).get("test_character", false)))
			var ev := InputEventAction.new()
			ev.action = "hotbar_page"
			ev.pressed = true
			Input.parse_input_event(ev)
		70:
			var ev2 := InputEventAction.new()
			ev2.action = "hotbar_page"
			ev2.pressed = false
			Input.parse_input_event(ev2)
			_expect("the next-page key shows skills seven to twelve", int((player.get("hotbar") as Array)[0]) == 6, str(player.get("hotbar")))
			main.call("open_ethercosm")
		80:
			# the first level lock, from the main page: its state and one button, nothing bound here
			var ob: Node = main.find_child("OpenSealButton", true, false)
			var binds: Array = main.get("screen").find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return (b as Button).text.to_lower().contains("bind"))
			_expect("the ethercosm shows a test character's full skill ready for its level 1 lock, with one Open the seal button and no bind button",
				ob is Button and binds.is_empty() and main.find_child("RunesButton", true, false) == null
				and (main.find_child("LockReady", true, false) as Label).text.begins_with("Ready for its level 1 lock: needs a vestige"), str(binds.map(func(b: Node) -> String: return (b as Button).text)))
			if ob is Control:
				_reveal(ob as Control)          # the details scroll; bring the button into view first
		83:
			_click(main.find_child("OpenSealButton", true, false) as Control)
		90:
			var s: Node = main.get("screen")
			var ctx: RuneContext = player.call("rune_context", 0)
			_expect("it opens the seal screen at the level 1 lock: stage 0, ring 1 forming, no free edit", s != null and str(s.call("seal_view")) == "bind"
				and ctx.stage == 0 and ctx.forming == 1 and ctx.rings == 1 and str((main.find_child("SealBanner", true, false) as Label).text).begins_with("FORMING RING 1"))
			_expect("the vestiges carried are offered there as the keystone, one button per concept, none set yet", GameData.concept_ids().all(func(c: Variant) -> bool:
				return main.find_child("LockConstruct_%s" % str(c), true, false) is Button) and main.find_child("KeystoneHead", true, false) != null
				and int(player.call("seal_construct")) < 0)
			_expect("a test character knows every rune", (player.call("rune_palette") as Array).all(func(id: String) -> bool: return bool(player.call("knows_rune", id))))
			var anchor: String = GameData.skill_anchor(str(((player.get("abilities") as Array)[0] as Dictionary)["id"]))
			var rules: RingRules = Runes.active() as RingRules
			# a closed word with every place of ring 1 filled (Brent 2026-10-24), planned from the
			# affinity's own runes (the palette tab shown) and then made by clicks and drags only
			var mine: Array = (player.call("rune_palette") as Array).filter(func(id: String) -> bool: return str(GameData.rune(id).get("affinity", "")) == AFF)
			var plan: Dictionary = FullRings.pattern(anchor, 1, mine, rules)
			if plan.is_empty():
				plan = FullRings.solve(anchor, 1, mine, rules)
			_expect("a closed word with ring 1 full can be made from the %s runes" % AFF, not plan.is_empty())
			_caps.clear()
			for i: int in range(1, RuneWord.size(plan)):
				_caps.append(RuneWord.node_id(plan, i))
			# each rune: picked in the palette, set on an empty place of ring 1
			for i2: int in _caps.size():
				var rid: String = _caps[i2]
				_queue.append(func() -> void: _click(main.find_child("Rune_" + rid, true, false) as Control))
				_queue.append(func() -> void: _click_at(_board().empty_slot_global(1, 0)))
			_queue.append(func() -> void:
				var sbp: Button = main.find_child("SealBindButton", true, false) as Button
				_expect("ring 1 full but nothing bonded: Bind is disabled and says why", sbp != null and sbp.disabled and sbp.tooltip_text != "", sbp.tooltip_text if sbp != null else "no button"))
			# each bond: pressed on one rune and dragged to the other
			for l: Dictionary in RuneWord.links(plan):
				var a: int = int(l["a"])
				var b: int = int(l["b"])
				_queue.append(func() -> void:
					_move(_board().node_global(a), false)
					_mouse(_board().node_global(a), true))
				_queue.append(func() -> void: _move(_board().node_global(a).lerp(_board().node_global(b), 0.5), true))
				_queue.append(func() -> void: _move(_board().node_global(b), true))
				_queue.append(func() -> void: _mouse(_board().node_global(b), false))
			_queue.append(func() -> void:
				var w: Dictionary = player.call("ability_word", 0)
				_expect("every place of ring 1 set by clicks and bonded by drags: the word is closed and the ring full", RuneWord.ring_nodes(w, 1).size() == rules.ring_capacity(1)
					and bool(Runes.active().word_state(w, player.call("rune_context", 0))["closed"]), str(w))
				_reveal(main.find_child("LockConstruct_reach", true, false) as Control)
				_click(main.find_child("LockConstruct_reach", true, false) as Control))
			_queue.append(func() -> void:
				var ks: Dictionary = player.call("seal_keystone")
				_expect("clicking a concept sets that vestige over ring 1 as its keystone", str(ks.get("tier", "")) == "vestige" and str(ks.get("concept", "")) == "reach" and bool(ks.get("set", false)))
				_chance = GameData.num("binding", "success_chance")
				(GameData.balance["binding"] as Dictionary)["success_chance"] = 1.0
				_click(main.find_child("SealBindButton", true, false) as Control))
			_queue.append(func() -> void:
				(GameData.balance["binding"] as Dictionary)["success_chance"] = _chance
				var st: Dictionary = (player.get("abilities") as Array)[0]
				var w1: Dictionary = st.get("word", {})
				_expect("Bind and lock locks the level: stage 1, ring 1 full and sealed, the vestige of Reach its keystone",
					int(st["stage"]) == 1 and RuneWord.sealed(w1) == 1 and RuneWord.ring_nodes(w1, 1).size() == rules.ring_capacity(1)
					and str(RuneWord.keystone(w1, 1).get("concept", "")) == "reach" and str(RuneWord.keystone(w1, 1).get("tier", "")) == "vestige", str(st))
				var s2: Node = main.get("screen")
				var ctx2: RuneContext = player.call("rune_context", 0)
				_expect("the bar is refilled (a test override) and the level 2 lock is open at once: ring 1 sealed, ring 2 forming, the remnants offered as its keystone",
					is_equal_approx(float(st["progress"]), 100.0) and str(s2.call("seal_view")) == "bind" and ctx2.forming == 2 and int(s2.call("sealed_rings")) == 1
					and main.find_child("LockConstruct_reach", true, false) is Button and str(player.call("pending_tier", st)) == "remnant")
				main.call("close_screen")
				main.call("open_ethercosm")
				_lock_done = true)
			_queue_at = frames + 3
	if not _queue.is_empty() and frames >= _queue_at and _queue_at > 0:
		var step: Callable = _queue.pop_front()
		step.call()
		_queue_at = frames + 3
	if _lock_done and _detail_from == 0:
		_detail_from = frames + 5
	if _detail_from > 0 and frames >= _detail_from and frames < _detail_from + 85:
		_detail_steps(frames - _detail_from)
	if (_detail_from > 0 and frames == _detail_from + 85) or frames == 900:
		if frames == 900:
			_expect("the probe finished in time", false, "the lock part never finished")
		for r: String in results:
			print("  " + r)
		print("TESTCHAR: %s" % ("FAIL" if failed else "PASS"))
		get_tree().quit(1 if failed else 0)
