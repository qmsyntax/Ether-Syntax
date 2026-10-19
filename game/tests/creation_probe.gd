extends Node
## Character creation click test (windowed run only - needs real GUI hit-testing):
##   godot --path game res://tests/creation_probe.tscn
## Walks the creation screen with synthetic mouse and keyboard events: types a name, picks an
## identity, changes one appearance option, picks a prime, picks two starting skills (and checks
## that nothing else is given), and presses Begin. Prints
## "CREATE: PASS" / "CREATE: FAIL" and exits 0/1.

var main: Node
var frames := 0
var results: Array[String] = []
var failed := false
var look_before := {}
var first_offers: Array = []
var picked: Dictionary = {}
var skills_picked: Array = []


func _skill_buttons() -> Array[Button]:
	var out: Array[Button] = []
	for n: Node in main.find_children("*", "Button", true, false):
		if n.has_meta("skill") and (n as Control).is_visible_in_tree():
			out.append(n as Button)
	return out


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
			if CharacterLook.options().has("sex"):
				_expect("choosing Woman gives the character a female body", str(((screen.get("spec") as Dictionary)["look"] as Dictionary).get("sex", "")) == "female")
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
			var table: Array = screen.get("offers")
			_expect("three different primes are on the table", table.size() == 3
				and str(table[0]["talent_id"]) != str(table[1]["talent_id"]) and str(table[1]["talent_id"]) != str(table[2]["talent_id"]) and str(table[0]["talent_id"]) != str(table[2]["talent_id"]))
			first_offers = table.duplicate(true)
			_click(_find(main, func(n: Node) -> bool: return n is Button and n.name == "RerollButton"))
		45:
			_expect("asking for three others rolls again and uses up a reroll",
				int(screen.get("rerolls_left")) == GameData.inum("primes", "rerolls") - 1 and (screen.get("offers") as Array).size() == 3)
			picked = ((screen.get("offers") as Array)[1] as Dictionary).duplicate(true)
			_click(_find(main, func(n: Node) -> bool: return n is Button and n.has_meta("offer") and int(n.get_meta("offer")) == 1))
		48:
			_expect("clicking a prime takes its talent and its affinities", str((screen.get("spec") as Dictionary)["talent_id"]) == str(picked["talent_id"])
				and ((screen.get("spec") as Dictionary)["affinities"] as Array) == (picked["affinities"] as Array))
			_click(_button("Next"))
		54:
			_expect("Next moves to the skills", int(screen.get("step")) == 3)
			var next: Button = _button("Next") as Button
			_expect("Next waits until two skills are picked", next != null and next.disabled)
			var choices: Array[Button] = _skill_buttons()
			var roots: Array[String] = GameData.skill_roots(picked["affinities"])
			_expect("the choices are the root skills of the prime's affinities", choices.size() == roots.size()
				and choices.all(func(b: Button) -> bool: return roots.has(str(b.get_meta("skill")))), "%d buttons, roots %s" % [choices.size(), str(roots)])
			if choices.size() >= 2:
				_click(choices[1])
		57:
			_expect("clicking a skill picks it", (screen.get("spec")["skills"] as Array).size() == 1)
			var choices: Array[Button] = _skill_buttons()
			if not choices.is_empty():
				_click(choices[0])
		60:
			skills_picked = ((screen.get("spec") as Dictionary)["skills"] as Array).duplicate()
			_expect("clicking a second picks it too", skills_picked.size() == 2, str(skills_picked))
			var rest: Array[Button] = _skill_buttons().filter(func(b: Button) -> bool: return not skills_picked.has(str(b.get_meta("skill"))))
			_expect("with two picked, the others cannot be picked", not rest.is_empty() and rest.all(func(b: Button) -> bool: return b.disabled))
			if not rest.is_empty():
				_click(rest[0])
		63:
			_expect("and clicking one does nothing", ((screen.get("spec") as Dictionary)["skills"] as Array) == skills_picked)
			_click(_button("Next"))
		66:
			_expect("Next moves to embark", int(screen.get("step")) == 4)
			_click(_button("Begin"))
		74:
			_expect("Begin starts the game in town", str(main.get("state")) == "town")
			_expect("the character has the name, identity and prime chosen",
				str(player.get("char_name")) == "Kin" and str(player.get("identity")) == "woman" and str(player.get("talent_id")) == str(picked["talent_id"]),
				"%s / %s / %s" % [str(player.get("char_name")), str(player.get("identity")), str(player.get("talent_id"))])
			_expect("the prime's affinities came with it", (player.get("affinities") as Array) == (picked["affinities"] as Array), str(player.get("affinities")))
			var have: Array = (player.get("abilities") as Array).map(func(a: Dictionary) -> String: return str(a["id"]))
			_expect("the character has exactly the two skills picked, nothing auto-assigned", have == skills_picked, "%s vs %s" % [str(have), str(skills_picked)])
			var bar: Array = player.get("hotbar")
			_expect("on slots 1 and 2", int(bar[0]) == 0 and int(bar[1]) == 1 and bar.slice(2).all(func(v: int) -> bool: return v == -1), str(bar))
			_expect("and no skill points yet", int(player.get("skill_points")) == int((GameData.skill_tree["points"] as Dictionary)["start"]))
			if CharacterLook.options().has("sex"):
				_expect("the female body carries into the game", str((player.get("look") as Dictionary).get("sex", "")) == "female")
			_expect("a new character starts with the purse", int(player.get("money")) == GameData.inum("town", "starting_money"))
			for line: String in results:
				print("CREATE: " + line)
			print("CREATE: %s" % ("FAIL" if failed else "PASS"))
			get_tree().quit(1 if failed else 0)
