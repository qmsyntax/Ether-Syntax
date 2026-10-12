extends Node
## UI click test (windowed run only - needs real GUI hit-testing):
##   godot --path game res://tests/ui_click_probe.tscn [-- --field]
## Opens the inventory and equips gear three ways with synthetic mouse events: left-click the item,
## right-click the item, and drag the item onto its slot; then the paper doll's own interactions:
## a head piece into the head slot, a second trinket, a drag onto the second trinket slot, and a
## click on a worn piece to take it off. Prints PASS/FAIL and exits 0/1.
## `--field` does it in the arena, where the inventory pauses the game.

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


func _find_item(node: Node, item_id: String) -> Control:
	if node is Button and node.get("item_id") != null and str(node.get("item_id")) == item_id:
		return node
	for c: Node in node.get_children():
		var b: Control = _find_item(c, item_id)
		if b != null:
			return b
	return null


func _find_slot(node: Node, slot: String) -> Control:
	if node is PanelContainer and node.get("slot") != null and str(node.get("slot")) == slot:
		return node
	for c: Node in node.get_children():
		var b: Control = _find_slot(c, slot)
		if b != null:
			return b
	return null


func _mouse(at: Vector2, button: MouseButton, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.position = at
	ev.global_position = at
	ev.button_mask = (MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
	get_viewport().push_input(ev)


func _move(at: Vector2, held: bool) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	mv.relative = Vector2(12, 12)
	mv.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	get_viewport().push_input(mv)


func _centre(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


func _expect(label: String, ok: bool) -> void:
	results.append("%s %s" % ["ok  " if ok else "FAIL", label])
	if not ok:
		failed = true


func _process(_delta: float) -> void:
	frames += 1
	var player: Node = main.get("player")
	var inv: Inventory = player.get("inventory") if player != null else null
	match frames:
		5:
			main.call("start_new_character", 0)
			inv = player.get("inventory")
			for id: String in ["river_stone", "dim_mote", "delver_frame", "brute_tusk", "oilcloth_hood", "cooling_coil"]:
				inv.add(id)
			if OS.get_cmdline_user_args().has("--field"):
				main.call("enter_arena")
			main.call("open_inventory")
			print("UICLICK: state=%s paused=%s" % [str(main.get("state")), str(get_tree().paused)])
		15:
			var item: Control = _find_item(main, "river_stone")
			_expect("the charm is listed in the pack", item != null)
			if item != null:
				_move(_centre(item), false)
				_mouse(_centre(item), MOUSE_BUTTON_LEFT, true)
				_mouse(_centre(item), MOUSE_BUTTON_LEFT, false)
		25:
			_expect("left-clicking gear equips it", str(inv.equipped.get("trinket", "")) == "river_stone")
			var item: Control = _find_item(main, "dim_mote")
			if item != null:
				_move(_centre(item), false)
				_mouse(_centre(item), MOUSE_BUTTON_RIGHT, true)
				_mouse(_centre(item), MOUSE_BUTTON_RIGHT, false)
		35:
			_expect("right-clicking gear equips it", str(inv.equipped.get("satellite", "")) == "dim_mote")
			_expect("the satellite now feeds essence", float(player.get("satellite_rate")) > 0.0)
			var item: Control = _find_item(main, "delver_frame")
			if item != null:
				_move(_centre(item), false)
				_mouse(_centre(item), MOUSE_BUTTON_LEFT, true)
		37:
			var item: Control = _find_item(main, "delver_frame")
			if item != null:
				_move(_centre(item) + Vector2(20, 20), true)
		39:
			var slot: Control = _find_slot(main, "back")
			if slot != null:
				_move(_centre(slot) - Vector2(10, 0), true)
		41:
			var slot: Control = _find_slot(main, "back")
			if slot != null:
				_move(_centre(slot), true)
				_mouse(_centre(slot), MOUSE_BUTTON_LEFT, false)
		50:
			_expect("dragging gear onto its slot equips it", str(inv.equipped.get("back", "")) == "delver_frame")
			_expect("the pack it replaced went back into the bag", inv.bag.has("canvas_pack"))
			var loot: Control = _find_item(main, "brute_tusk")
			if loot != null:
				_move(_centre(loot), false)
				_mouse(_centre(loot), MOUSE_BUTTON_LEFT, true)
				_mouse(_centre(loot), MOUSE_BUTTON_LEFT, false)
		60:
			_expect("clicking loot does nothing", inv.bag.has("brute_tusk"))
			_expect("every one of the twelve slots is on the screen", Inventory.SLOTS.all(func(s: String) -> bool: return _find_slot(main, s) != null))
			var hood: Control = _find_item(main, "oilcloth_hood")
			_expect("the hood is in the pack", hood != null)
			if hood != null:
				_move(_centre(hood), false)
				_mouse(_centre(hood), MOUSE_BUTTON_LEFT, true)
				_mouse(_centre(hood), MOUSE_BUTTON_LEFT, false)
		70:
			_expect("clicking a head piece fills the head slot", str(inv.equipped.get("head", "")) == "oilcloth_hood")
			_expect("and it counts: the hood's armour is on top of the coat's and the boots'", float(player.call("armour")) > 3.5)
			var coil: Control = _find_item(main, "cooling_coil")
			if coil != null:
				_move(_centre(coil), false)
				_mouse(_centre(coil), MOUSE_BUTTON_LEFT, true)
				_mouse(_centre(coil), MOUSE_BUTTON_LEFT, false)
		80:
			_expect("a second trinket goes into the second trinket slot", str(inv.equipped.get("trinket2", "")) == "cooling_coil" and str(inv.equipped.get("trinket", "")) == "river_stone")
			var worn: Control = _find_slot(main, "trinket2")
			if worn != null:
				_move(_centre(worn), false)
				_mouse(_centre(worn), MOUSE_BUTTON_LEFT, true)
				_mouse(_centre(worn), MOUSE_BUTTON_LEFT, false)
		90:
			_expect("clicking a worn piece takes it off", not inv.equipped.has("trinket2") and inv.bag.has("cooling_coil"))
			var worn: Control = _find_slot(main, "trinket")
			if worn != null:
				_move(_centre(worn), false)
				_mouse(_centre(worn), MOUSE_BUTTON_LEFT, true)
				_mouse(_centre(worn), MOUSE_BUTTON_LEFT, false)
		100:
			_expect("both trinket slots are empty and both trinkets are back in the pack", not inv.equipped.has("trinket") and inv.bag.has("river_stone"))
			var coil: Control = _find_item(main, "cooling_coil")
			if coil != null:
				_move(_centre(coil), false)
				_mouse(_centre(coil), MOUSE_BUTTON_LEFT, true)
		102:
			var coil: Control = _find_item(main, "cooling_coil")
			if coil != null:
				_move(_centre(coil) + Vector2(20, 20), true)
		104:
			var slot: Control = _find_slot(main, "trinket2")
			if slot != null:
				_move(_centre(slot) - Vector2(10, 0), true)
		106:
			var slot: Control = _find_slot(main, "trinket2")
			if slot != null:
				_move(_centre(slot), true)
				_mouse(_centre(slot), MOUSE_BUTTON_LEFT, false)
		115:
			_expect("dragging a trinket onto the second slot puts it there, not in the first", str(inv.equipped.get("trinket2", "")) == "cooling_coil" and not inv.equipped.has("trinket"))
			var boots: Control = _find_slot(main, "feet")
			_expect("the starting boots are worn", boots != null and str(inv.equipped.get("feet", "")) == "street_boots")
			var hood: Control = _find_item(main, "cooling_coil")
			_expect("nothing worn is still listed in the pack", hood == null)
			for line: String in results:
				print("UICLICK: " + line)
			print("UICLICK: %s" % ("FAIL" if failed else "PASS"))
			get_tree().quit(1 if failed else 0)
