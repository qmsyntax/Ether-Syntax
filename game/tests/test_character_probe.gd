extends Node
## Test characters click test (windowed run only - needs real GUI hit-testing):
##   godot --path game res://tests/test_character_probe.tscn
## On the title screen, clicks the "Test characters" button for one affinity (Dream), then checks
## the character: that one affinity, every skill of it learned at the test stage, a full tank,
## marked as a test character, standing in town; then presses the hotbar_page key and checks that
## the bar shows the next six skills. Prints "TESTCHAR: PASS" / "TESTCHAR: FAIL" and exits 0/1.

const AFF := "dream"

var main: Node
var frames := 0
var results: Array[String] = []
var failed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	main.set("_test_mode", true)
	add_child(main)


func _click(c: Control) -> void:
	if c == null:
		return
	var at: Vector2 = c.get_global_rect().get_center()
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
		80:
			for r: String in results:
				print("  " + r)
			print("TESTCHAR: %s" % ("FAIL" if failed else "PASS"))
			get_tree().quit(1 if failed else 0)
