extends Node
## Test characters click test (windowed run only - needs real GUI hit-testing):
##   godot --path game res://tests/test_character_probe.tscn
## On the title screen, clicks the "Test characters" button for one affinity (Dream), then checks
## the character: that one affinity, every skill of it learned at the test stage, a full tank,
## marked as a test character, standing in town; then presses the hotbar_page key and checks that
## the bar shows the next six skills; then the free edit (design/14 section 8): open it from the
## ethercosm, set a rune by clicking and Seal now; then the ethercosm's skill details: click a skill, its
## numbers and statuses, click a status name for its definition, the skill slots, the glossary. Prints "TESTCHAR: PASS" / "TESTCHAR: FAIL" and exits 0/1.

const AFF := "dream"

var main: Node
var frames := 0
var results: Array[String] = []
var failed := false
var _pick := ""                  # a rune set in the free edit


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
			# the free edit (design/14 section 8): a test character tries any word without a binding
			var rb: Node = main.find_child("RunesButton", true, false)
			_expect("the ethercosm offers a test character its free edit", rb is Button and (rb as Button).text.begins_with("Free edit"))
			if rb is Control:
				_reveal(rb as Control)          # the details scroll; bring the button into view first
		83:
			_click(main.find_child("RunesButton", true, false) as Control)
		90:
			var s: Node = main.get("screen")
			_expect("it opens, clearly marked as a test character's free edit", s != null and str(s.call("seal_view")) == "test"
				and main.find_child("SealBanner", true, false) != null and str((main.find_child("SealBanner", true, false) as Label).text).begins_with("TEST CHARACTER"))
			_expect("a test character knows every rune", (player.call("rune_palette") as Array).all(func(id: String) -> bool: return bool(player.call("knows_rune", id))))
			_pick = ""
			for id: String in (player.call("rune_palette") as Array):
				if str(GameData.rune(id).get("affinity", "")) == AFF and id != GameData.skill_anchor(str(((player.get("abilities") as Array)[0] as Dictionary)["id"])) and _pick == "":
					_pick = id
			_click(main.find_child("Rune_" + _pick, true, false) as Control)
		95:
			# a rune picked up in the palette goes where an empty place is clicked (2026-10-23)
			var board: RuneBoard = main.find_child("RuneBoard", true, false) as RuneBoard
			_expect("clicking a rune picks it up", str(main.get("screen").get("armed_rune")) == _pick)
			if board != null:
				_click_at(board.empty_slot_global(1, 0))
		100:
			_expect("and clicking an empty place sets it into the word", RuneWord.nodes(player.call("ability_word", 0)).has(_pick))
			_click(main.find_child("SealNowButton", true, false) as Control)
		110:
			_expect("Seal now (test) seals it without a binding", bool(player.call("word_locked", 0)) and RuneWord.nodes((player.get("abilities") as Array)[0]["word"]).has(_pick))
			main.call("close_screen")
			main.call("open_ethercosm")
		_ when frames >= 115 and frames < 200:
			_detail_steps(frames - 115)
		200:
			for r: String in results:
				print("  " + r)
			print("TESTCHAR: %s" % ("FAIL" if failed else "PASS"))
			get_tree().quit(1 if failed else 0)
