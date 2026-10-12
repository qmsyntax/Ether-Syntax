extends Node
## Character creation click test (windowed run only - needs real GUI hit-testing):
##   godot --path game res://tests/creation_probe.tscn
## Walks the creation screen with synthetic mouse and keyboard events: types a name, picks an
## identity, changes one appearance option, picks a prime, and presses Begin. Prints
## "CREATE: PASS" / "CREATE: FAIL" and exits 0/1.

var main: Node
var frames := 0
var results: Array[String] = []
var failed := false
var look_before := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	main.set("_test_mode", true)
	add_child(main)


func _find(node: Node, test: Callable) -> Control:
	if node is Control and test.call(node):
		return node
	for c: Node in node.get_children():
		var hit: Control = _find(c, test)
		if hit != null:
			return hit
	return null


func _button(text: String) -> Control:
	return _find(main, func(n: Node) -> bool: return n is Button and (n as Button).text.strip_edges() == text and (n as Control).is_visible_in_tree())


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


func _type(text: String) -> void:
	for ch: String in text:
		for pressed: bool in [true, false]:
			var ev := InputEventKey.new()
			ev.keycode = OS.find_keycode_from_string(ch.to_upper())
			ev.physical_keycode = ev.keycode
			ev.unicode = ch.unicode_at(0)
			ev.pressed = pressed
			get_viewport().push_input(ev)


func _expect(label: String, ok: bool, detail: String = "") -> void:
	results.append("%s %s %s" % ["ok  " if ok else "FAIL", label, "" if ok else detail])
	if not ok:
		failed = true


func _process(_delta: float) -> void:
	frames += 1
	var player: Node = main.get("player")
	var screen: Node = main.get("screen")
	match frames:
		8:
			_expect("the game opens on character creation", screen is CreationScreen and str(main.get("state")) == "select")
			_click(_find(main, func(n: Node) -> bool: return n is LineEdit))
		12:
			_type("Kin")                 # letters that are also game keys must type, not trigger
		18:
			_click(_button("Woman"))
		24:
			_expect("typing in the name box does not leave the screen", main.get("screen") is CreationScreen)
			_expect("the typed name is kept", str((screen.get("spec") as Dictionary)["name"]) == "Kin", str((screen.get("spec") as Dictionary)["name"]))
			_expect("clicking an identity selects it", str((screen.get("spec") as Dictionary)["identity"]) == "woman")
			_click(_button("Next"))
		30:
			_expect("Next moves to appearance", int(screen.get("step")) == 1)
			look_before = ((screen.get("spec") as Dictionary)["look"] as Dictionary).duplicate()
			_click(_button(">"))
		36:
			var now: Dictionary = (screen.get("spec") as Dictionary)["look"]
			if not CharacterLook.options().is_empty():
				_expect("an arrow changes the look", now != look_before)
			_click(_button("Next"))
		42:
			_expect("Next moves to the prime", int(screen.get("step")) == 2)
			_click(_find(main, func(n: Node) -> bool: return n is Button and n.has_meta("talent_id") and str(n.get_meta("talent_id")) == "grudge"))
		48:
			_expect("clicking a prime selects it", str((screen.get("spec") as Dictionary)["talent_id"]) == "grudge")
			_click(_button("Next"))
		54:
			_expect("Next moves to embark", int(screen.get("step")) == 3)
			_click(_button("Begin"))
		62:
			_expect("Begin starts the game in town", str(main.get("state")) == "town")
			_expect("the character has the name, identity and prime chosen",
				str(player.get("char_name")) == "Kin" and str(player.get("identity")) == "woman" and str(player.get("talent_id")) == "grudge",
				"%s / %s / %s" % [str(player.get("char_name")), str(player.get("identity")), str(player.get("talent_id"))])
			_expect("the prime's affinities came with it", (player.get("affinities") as Array) == GameData.prime_affinities("grudge"))
			_expect("a new character starts with the purse", int(player.get("money")) == GameData.inum("town", "starting_money"))
			for line: String in results:
				print("CREATE: " + line)
			print("CREATE: %s" % ("FAIL" if failed else "PASS"))
			get_tree().quit(1 if failed else 0)
