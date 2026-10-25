extends Node
## UI click test (windowed run only - needs real GUI hit-testing):
##   godot --path game res://tests/ui_click_probe.tscn [-- --field]
## Opens the inventory and equips gear three ways with synthetic mouse events: left-click the item,
## right-click the item, and drag the item onto its slot; then the paper doll's own interactions:
## a head piece into the head slot, a second trinket, a drag onto the second trinket slot, and a
## click on a worn piece to take it off. Then the HUD and the controls menu: a point on the
## dock's strike slot counts as over the interface (so a click there is not an attack order), and
## a key is rebound by clicking its button and pressing a key, then put back with "Reset to
## defaults", and the menu closed with its own button. The player's saved key bindings are
## backed up first and restored at the end. Then, in town, the skill trainer: click the trainer
## in the street to walk up and talk, click Training, click a node of the tree and click Learn.
## Then the seal screen (design/14 section 8), by real drags, clicks and keys - see _rune_steps.
## Prints PASS/FAIL and exits 0/1.
## `--field` does it in the arena, where the inventory pauses the game (and skips the trainer).

var main: Node
var frames := 0
var results: Array[String] = []
var failed := false
var _binds_backup: Variant = null      # user://keybinds.cfg as it was, or null if there was none
var _step := ""
var _step_ms := 0
var _trainer_from := 0                 # the frame the trainer part began, 0 until then
var _runes_from := 0                   # the frame the rune-setting part began, 0 until then
var _anchor := ""                      # the first skill's anchor rune
var _spare: Array[String] = []         # three runes of its affinity to set, picked from the data
var _held := 0                         # runes in the word when the rule sets are swapped
var _caps: Array[String] = []          # one-bond runes to close the word with
var _stats_before := ""                # the skill's numbers before the word is sealed
var _unknown := ""                     # a rune the character has not discovered
var _chance := 0.0                     # balance "binding" success_chance, put back after the forced rolls
var _sealed_key := ""                  # the sealed word's shape, to see that a failed bind keeps it
var _drag_from := Vector2.ZERO          # where a palette drag started
var _drop_to := Vector2.ZERO            # the empty place it is dropped on
var _drop_place := -1                   # that place's index on its ring
var _kept := ""                         # the draft as it was, to see that undo puts it back exactly
var _link2 := ""                        # a two-bond rune to carry ring 2 out from ring 1
var _queue: Array[Callable] = []        # the second level lock's clicks and drags, one every few frames
var _queue_at := 0

const FreeRules := preload("res://tests/free_rules.gd")


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


func _click_at(at: Vector2) -> void:
	_move(at, false)
	_mouse(at, MOUSE_BUTTON_LEFT, true)
	_mouse(at, MOUSE_BUTTON_LEFT, false)


## A visible control by node name.
func _find(node: Node, wanted: String) -> Control:
	for n: Node in node.find_children(wanted, "Control", true, false):
		if (n as Control).is_visible_in_tree():
			return n as Control
	return null


## A service button (UiWidgets.service_button) by its title.
func _service(title: String) -> Button:
	for n: Node in main.find_children("*", "Button", true, false):
		for l: Node in n.find_children("*", "Label", true, false):
			if (l as Label).text == title and (n as Control).is_visible_in_tree():
				return n as Button
	return null


func _expect(label: String, ok: bool, detail: String = "") -> void:
	results.append("%s %s%s" % ["ok  " if ok else "FAIL", label, ("  [%s]" % detail) if not ok and detail != "" else ""])
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
			main.call("open_inventory")              # closes it
		125:
			# the real cursor is not moved by pushed events, so the HUD's own hit test is asked directly
			var hud: Node = main.get("hud")
			var strike: Rect2 = hud.get("_strike_rect")
			_expect("the dock has a strike slot", strike.size.x > 0.0)
			_expect("a point on the strike slot is over the interface", bool(hud.call("ui_at", strike.get_center())))
			_expect("a point on open ground is not", not bool(hud.call("ui_at", get_viewport().get_visible_rect().size * Vector2(0.5, 0.45))))
		135:
			if FileAccess.file_exists(Keybinds.SAVE_PATH):
				_binds_backup = FileAccess.get_file_as_string(Keybinds.SAVE_PATH)
			main.call("open_settings")
		145:
			var menu: Node = main.get("settings_menu")
			_expect("the controls menu opens", menu != null)
			if menu != null:
				var btn: Control = (menu.get("_rows") as Dictionary).get("ascend")
				_expect("the controls menu lists Ascend", btn != null and btn.is_visible_in_tree())
				if btn != null:
					_click(btn)
					_step = "rebind"
					_step_ms = Time.get_ticks_msec()
	if frames > 145 and _step != "":
		_settings_steps()
	if _trainer_from > 0:
		_trainer_steps(frames - _trainer_from)
	if _runes_from > 0:
		_rune_steps(frames - _runes_from)


## The seal screen (design/14 sections 7-8 and 11; the building controls Brent asked for on 2026-10-23,
## and his ruling that rings and constructs lock together, only on the seal screen), by real mouse and
## keyboard events: a skill whose bar is full and a vestige carried; the skill clicked on the main
## page shows "Ready for its level 1 lock" and one Open the seal button - no bind button - which opens
## the seal screen forming ring 1, with the vestige to choose. A palette rune is DRAGGED onto an empty place
## (press, motion, release - Godot's own drag and drop) and lands on that place; a second is clicked
## in the palette and then on a place, and is set alone, unbonded. Bonds are made by dragging from the
## skill's core to a rune and from a rune to the core (live motion between press and release); a drag
## onto a full rune is refused while dragging and on release, and says why. A bond is selected by
## clicking its curve and deleted with its x; Ctrl+Z brings it back. A rune right-clicked is taken out
## with its bonds; Ctrl+Z / Ctrl+Y step back and forth exactly. With a second rule set in force
## (tests/free_rules.gd) the same view follows those rules (their three-rune limit, explained). An
## undiscovered rune ("?") is refused and explained. Then Clear (the lock cannot bind with ring 1
## empty), fill every place of ring 1 and close the word by clicks and drags (Brent 2026-10-24: full
## rings; with two of three places filled Bind says why it cannot), set the vestige over it as the
## keystone and Bind and lock - the skill's numbers change and ring 1 is sealed under the vestige.
## Then the level 2 lock, from the main page by clicks: ring 1 reworked (a cap out, a two-bond rune in)
## and all five places of ring 2 filled out from it by clicks and drags, the remnant set as its
## keystone; a failed bind (forced) changes nothing in the word, and with no remnant left the lock
## closes and the main page says what is missing; a remnant again, the lock again, built again and
## bound (sure): rings 1 and 2 full and sealed, the remnant over ring 2. The
## bind's roll is forced through balance "binding" success_chance (1, then 0, then 1) so the probe is not
## left to chance; it is put back after. Runes are chosen from the data by affinity and valence, not
## by name; the probe discovers them first (data, not clicks).
func _rune_steps(at: int) -> void:
	var player: Node = main.get("player")
	var s: Node = main.get("screen")
	var board: RuneBoard = _find(main, "RuneBoard") as RuneBoard
	match at:
		1:
			for i: int in 4:
				if main.get("screen") != null:
					main.call("close_screen")
			_anchor = GameData.skill_anchor(str(((player.get("abilities") as Array)[0] as Dictionary)["id"]))
			_spare.clear()
			_caps.clear()
			_unknown = ""
			for id: String in (player.call("rune_palette") as Array):
				if str(GameData.rune(id).get("affinity", "")) != "water" or id == _anchor:
					continue
				if BondRules.valence(id) == 1 and _caps.size() < BondRules.valence(_anchor) and (Runes.active() as BondRules).alignment_state(_anchor, id) == "ok":
					_caps.append(id)
				elif _spare.size() < 3 and BondRules.valence(id) > 1:
					_spare.append(id)
				if _link2 == "" and BondRules.valence(id) == 2 and (Runes.active() as BondRules).alignment_state(_anchor, id) == "ok":
					_link2 = id
			for id2: String in _spare + _caps + [_link2]:
				player.call("discover_rune", id2, "")
			for id3: String in (player.call("rune_palette") as Array):
				if str(GameData.rune(id3).get("affinity", "")) == "water" and not bool(player.call("knows_rune", id3)) and _unknown == "":
					_unknown = id3
			((player.get("abilities") as Array)[0] as Dictionary)["progress"] = 100.0
			(player.get("constructs") as Array).append({"tier": "vestige", "concept": "tension"})
			_chance = GameData.num("binding", "success_chance")
			main.call("open_ethercosm")
		6:
			# click the skill on the main page (the ethercosm's drawn soul)
			var es: Node = main.get("screen")
			es.call("select", 1)                     # something else first, so the click is what selects it
			var cosmos: Control = es.get("_cosmos")
			for n: Dictionary in (cosmos.get("_nodes") as Array):
				if int(n["index"]) == 0:
					_click_at(cosmos.get_global_rect().position + (n["pos"] as Vector2))
		10:
			_expect("the ethercosm is open, and clicking the skill selects it", main.get("screen") is UiScreen and main.get("screen").has_method("open_seal")
				and int(main.get("screen").get("selected")) == 0)
			var binds: Array = main.get("screen").find_children("*", "Button", true, false).filter(func(bb: Node) -> bool: return (bb as Button).text.to_lower().contains("bind"))
			var ready_l: Control = _find(main, "LockReady")
			_expect("the main page binds nothing: no bind button, no bind preview (Brent 2026-10-23)", binds.is_empty() and _find(main, "BindPreview") == null,
				str(binds.map(func(bb: Node) -> String: return (bb as Button).text)))
			_expect("it shows the full skill ready for its level 1 lock, needing a vestige", ready_l != null and (ready_l as Label).text.begins_with("Ready for its level 1 lock: needs a vestige"))
			var b: Control = _find(main, "OpenSealButton")
			_expect("and one button that opens its seal", b != null)
			if b != null:
				_click_at(_centre(b))
		20:
			_expect("it opens the seal screen at the level 1 lock, forming ring 1", s != null and bool(s.get("rune_mode")) and board != null
				and str(s.call("seal_view")) == "bind" and (player.call("rune_context", 0) as RuneContext).forming == 1)
			_expect("the vestige carried is offered on the seal screen as the keystone, not yet set (the player sets it)", _find(main, "LockConstruct_tension") != null
				and _find(main, "KeystoneHead") != null and int(player.call("seal_construct")) < 0)
			var chip: Control = _find(main, "Rune_" + _spare[0])
			_expect("the palette offers the runes it knows", chip != null)
			# drag the palette rune onto the second empty place of ring 1: press on the chip...
			_drop_place = board.empty_place(1, 1)
			_drop_to = board.empty_slot_global(1, 1)
			if chip != null:
				_drag_from = _centre(chip)
				_move(_drag_from, false)
				_mouse(_drag_from, MOUSE_BUTTON_LEFT, true)
		21, 22, 23, 24:
			# ...move with the button held (Godot starts its drag past its threshold)...
			_move(_drag_from.lerp(_drop_to, float(at - 20) / 4.0), true)
		25:
			_expect("while the palette rune is carried, the board knows it is in hand", str(board.call("_in_hand")) == _spare[0])
			_move(_drop_to, true)
			_mouse(_drop_to, MOUSE_BUTTON_LEFT, false)
		30:
			var w: Dictionary = player.call("ability_word", 0)
			_expect("a palette rune dragged onto an empty place is set on that place, unbonded", RuneWord.size(w) == 2 and RuneWord.node_id(w, 1) == _spare[0]
				and RuneWord.ring(w, 1) == 1 and RuneWord.places(w)[1] == _drop_place and board.node_global(1).distance_to(_drop_to) < 1.0 and RuneWord.links(w).is_empty(),
				"%s place %d at %s; drawn %s; msg %s" % [str(w), _drop_place, _drop_to, board.node_global(1) if RuneWord.size(w) > 1 else Vector2.ZERO, str(s.get("_rune_msg"))])
			# a click on a palette rune, then on an empty place
			_click_at(_centre(_find(main, "Rune_" + _caps[0])))
		33:
			_expect("clicking a palette rune picks it up", str(s.get("armed_rune")) == _caps[0])
			_click_at(board.empty_slot_global(1, 0))
		38:
			var w2: Dictionary = player.call("ability_word", 0)
			_expect("then clicking an empty place sets it there, alone (not bonded to the rune selected before)",
				RuneWord.size(w2) == 3 and RuneWord.node_id(w2, 2) == _caps[0] and RuneWord.links(w2).is_empty() and str(s.get("armed_rune")) == "", "%s msg %s" % [str(w2), str(s.get("_rune_msg"))])
			_drag_start(board.node_global(0))
		39, 40, 41:
			_move(board.node_global(0).lerp(board.node_global(1), float(at - 38) / 3.0), true)
		42:
			_expect("dragging from the skill's core: a live bond follows the cursor", board.is_dragging() and board.drag_source() == 0)
			_drag_end(board.node_global(1))
		46:
			_expect("let go on a rune: the core and the rune are bonded, and the new bond is selected",
				RuneWord.linked(player.call("ability_word", 0), 0, 1) and s.get("picked_bond") == Vector2i(0, 1))
			_drag_start(board.node_global(2))
		47, 48, 49:
			_move(board.node_global(2).lerp(board.node_global(0), float(at - 46) / 3.0), true)
		50:
			_drag_end(board.node_global(0))
		54:
			_expect("dragging from a rune to the core bonds them too", RuneWord.linked(player.call("ability_word", 0), 0, 2))
			# a refused drag: the cap is full now
			_drag_start(board.node_global(1))
		55, 56, 57:
			_move(board.node_global(1).lerp(board.node_global(2), float(at - 54) / 3.0), true)
		58:
			var chk: Dictionary = (board.get("_drag_checks") as Dictionary).get(2, {})
			_expect("dragging onto a full rune: it is marked refused while dragging (%s)" % RuneBoard.short_reason(chk),
				board.is_dragging() and not bool(chk.get("ok", true)) and str(chk.get("reason", "")) == "valence_full")
			_drag_end(board.node_global(2))
		62:
			var msg: Control = _find(main, "RuneMessage")
			_expect("and letting go there makes no bond, and the screen says why", not RuneWord.linked(player.call("ability_word", 0), 1, 2)
				and msg != null and (msg as Label).text.contains("full"))
			# select a bond by clicking on its curve
			_click_at(board.bond_global(0, 1))
		66:
			_expect("clicking a bond's curve selects it, and the panel shows its kind and what it carries", s.get("picked_bond") == Vector2i(0, 1)
				and _find(main, "SelectedBond") != null and _find(main, "BondKind") != null and _find(main, "BondCarries") != null)
			_expect("the selected bond shows its x", board.cross_global().x >= 0.0)
			_click_at(board.cross_global())
		70:
			_expect("clicking the x deletes the bond", not RuneWord.linked(player.call("ability_word", 0), 0, 1) and s.get("picked_bond") == Vector2i(-1, -1))
			_press_key(KEY_Z, true)
		74:
			_expect("Ctrl+Z brings it back", RuneWord.linked(player.call("ability_word", 0), 0, 1))
			_kept = JSON.stringify(player.call("ability_word", 0), "", true)
			_mouse(board.node_global(2), MOUSE_BUTTON_RIGHT, true)
			_mouse(board.node_global(2), MOUSE_BUTTON_RIGHT, false)
		78:
			_expect("right-clicking a rune takes it out with its bond", RuneWord.size(player.call("ability_word", 0)) == 2 and RuneWord.degree(player.call("ability_word", 0), 0) == 1)
			_press_key(KEY_Z, true)
		82:
			_expect("Ctrl+Z puts it back exactly", JSON.stringify(player.call("ability_word", 0), "", true) == _kept)
			_press_key(KEY_Y, true)
		86:
			_expect("Ctrl+Y takes it out again", RuneWord.size(player.call("ability_word", 0)) == 2)
			_press_key(KEY_Z, true)
		90:
			_expect("and Ctrl+Z back again, exactly", JSON.stringify(player.call("ability_word", 0), "", true) == _kept)
			_held = RuneWord.size(player.call("ability_word", 0))
			Runes.use(FreeRules.new())
			s.call("rebuild")
		94:
			_click_at(_centre(_find(main, "Rune_" + _spare[1])))
		97:
			_click_at(board.empty_slot_global(1, 0))
		101:
			var msg2: Control = _find(main, "RuneMessage")
			_expect("under the test rules the same view refuses a rune past their three, and says so",
				RuneWord.size(player.call("ability_word", 0)) == _held and msg2 != null and (msg2 as Label).text.contains("holds 3"))
			Runes.use(null)
			s.call("deselect")
			s.call("rebuild")
		105:
			var q: Control = _find(main, "Rune_" + _unknown)
			_expect("an undiscovered rune shows in the palette as \"?\"", q != null and not bool((s.call("chip_state", _unknown) as Dictionary)["known"]))
			if q != null:
				_click_at(_centre(q))
		109:
			var msg3: Control = _find(main, "RuneMessage")
			_expect("and clicking it is refused: not discovered yet", msg3 != null and (msg3 as Label).text.contains("discovered") and RuneWord.size(player.call("ability_word", 0)) == _held)
			var clear: Control = _find(main, "ClearWordButton")
			_expect("the seal screen offers Clear", clear != null and not (clear as Button).disabled)
			if clear != null:
				_click_at(_centre(clear))
		114:
			_expect("Clear leaves the skill's own rune alone", RuneWord.size(player.call("ability_word", 0)) == 1)
			_stats_before = str(player.call("ability_stats", (player.get("abilities") as Array)[0]))
			var seal0: Control = _find(main, "SealBindButton")
			_expect("with ring 1 empty the lock cannot bind, and the screen says so",
				seal0 != null and (seal0 as Button).disabled and str(main.get("screen").get("_lock_note").text).contains("Ring 1 is not full: 0 of 3"),
				str(main.get("screen").get("_lock_note").text))
		120, 140, 160:
			# ring 1, every place: a cap and a two-bond rune on the skill, a second cap on the two-bond rune
			var rid: String = [_caps[0], _link2, _caps[1] if _caps.size() > 1 else _caps[0]][[120, 140, 160].find(at)]
			_click_at(_centre(_find(main, "Rune_" + rid)))
		123, 143, 163:
			_click_at(board.empty_slot_global(1, 0))
		127, 147, 167:
			_drag_start(board.node_global(RuneWord.size(player.call("ability_word", 0)) - 1))
		128, 148, 168:
			var to: int = 2 if at == 168 else 0
			_move(board.node_global(RuneWord.size(player.call("ability_word", 0)) - 1).lerp(board.node_global(to), 0.5), true)
		129, 149, 169:
			_move(board.node_global(2 if at == 169 else 0), true)
		130, 150, 170:
			_drag_end(board.node_global(2 if at == 170 else 0))
		155:
			var sbp: Control = _find(main, "SealBindButton")
			_expect("two of ring 1's three places filled and bonded: Bind is disabled and says why (\"%s\")" % str(main.get("screen").get("_lock_note").text),
				sbp != null and (sbp as Button).disabled and str((sbp as Button).tooltip_text).contains("Ring 1 is not full: 2 of 3")
				and str(main.get("screen").get("_lock_note").text).contains("2 of 3"))
		180:
			var w: Dictionary = player.call("ability_word", 0)
			_expect("every place of ring 1 filled and bonded by drags: the word is closed and the ring full",
				RuneWord.ring_nodes(w, 1).size() == 3 and bool(Runes.active().word_state(w, player.call("rune_context", 0))["closed"]), str(w))
			var sbk: Control = _find(main, "SealBindButton")
			_expect("but Bind waits for the keystone: no vestige set yet", sbk != null and (sbk as Button).disabled and str((sbk as Button).tooltip_text).contains("keystone"),
				str((sbk as Button).tooltip_text) if sbk != null else "no button")
			var kb: Control = _find(main, "LockConstruct_tension")
			if kb != null:
				_click_at(_centre(kb))
		186:
			var ks: Dictionary = player.call("seal_keystone")
			var sb: Control = _find(main, "SealBindButton")
			_expect("clicking the vestige sets it over ring 1 as its keystone, and Bind and lock is live",
				str(ks.get("concept", "")) == "tension" and bool(ks.get("set", false)) and _find(main, "KeystoneEffect") != null and sb != null and not (sb as Button).disabled)
			(GameData.balance["binding"] as Dictionary)["success_chance"] = 1.0
			if sb != null:
				_click_at(_centre(sb))
		200:
			(GameData.balance["binding"] as Dictionary)["success_chance"] = _chance
			var w1: Dictionary = player.call("ability_word", 0)
			_expect("clicking it locks the level: stage 1, ring 1 full and sealed, the vestige of Tension its keystone",
				bool(player.call("word_locked", 0)) and int(((player.get("abilities") as Array)[0] as Dictionary)["stage"]) == 1 and RuneWord.sealed(w1) == 1
				and RuneWord.ring_nodes(w1, 1).size() == 3 and str(RuneWord.keystone(w1, 1).get("concept", "")) == "tension")
			_expect("and the skill's numbers change with it", str(player.call("ability_stats", (player.get("abilities") as Array)[0])) != _stats_before
				and not (player.call("rune_summary", 0) as Array).is_empty())
			_expect("the screen now shows the seal, read-only", str(main.get("screen").call("seal_view")) == "view" and _find(main, "SealBindButton") == null)
			_sealed_key = JSON.stringify(player.call("ability_word", 0))
			# the next lock: a full bar and a remnant
			((player.get("abilities") as Array)[0] as Dictionary)["progress"] = 100.0
			(player.get("constructs") as Array).append({"tier": "remnant", "concept": "reach"})
			var back: Control = _find(main, "RunesBackButton")
			if back != null:
				_click_at(_centre(back))
		210:
			var b2: Control = _find(main, "OpenSealButton")
			_expect("back on the main page, the level 2 lock is offered: one Open the seal button", b2 != null and _find(main, "LockReady") != null
				and (_find(main, "LockReady") as Label).text.begins_with("Ready for its level 2 lock: needs a remnant"))
			if b2 != null:
				_click_at(_centre(b2))
		220:
			_expect("it opens the seal at the level 2 lock: ring 1 sealed in the draft, ring 2 forming, the remnant offered as its keystone",
				str(main.get("screen").call("seal_view")) == "bind" and (player.call("rune_context", 0) as RuneContext).forming == 2
				and JSON.stringify(player.call("ability_word", 0)).contains("\"keystones\"") and _find(main, "LockConstruct_reach") != null)
			var sb2: Control = _find(main, "SealBindButton")
			_expect("with ring 2 empty it cannot bind", sb2 != null and (sb2 as Button).disabled)
			_queue_ring2()
			_queue.append(func() -> void:
				var w2: Dictionary = player.call("ability_word", 0)
				_expect("ring 1 reworked and all five places of ring 2 filled by clicks and drags: closed, both rings full",
					RuneWord.ring_nodes(w2, 1).size() == 3 and RuneWord.ring_nodes(w2, 2).size() == 5
					and bool(Runes.active().word_state(w2, player.call("rune_context", 0))["closed"]), str(w2))
				_click_at(_centre(_find(main, "LockConstruct_reach"))))
			_queue.append(func() -> void:
				var sb3: Control = _find(main, "SealBindButton")
				_expect("the remnant set over ring 2 as its keystone: Bind and lock is live",
					bool((player.call("seal_keystone") as Dictionary).get("set", false)) and sb3 != null and not (sb3 as Button).disabled, str(main.get("screen").get("_lock_note").text))
				(GameData.balance["binding"] as Dictionary)["success_chance"] = 0.0
				if sb3 != null:
					_click_at(_centre(sb3)))
			_queue.append(func() -> void:
				(GameData.balance["binding"] as Dictionary)["success_chance"] = _chance
				_expect("a failed bind changes nothing in the word: ring 1 as sealed, no ring 2, no second keystone; the remnant is gone",
					JSON.stringify(((player.get("abilities") as Array)[0] as Dictionary).get("word", {})) == _sealed_key
					and int(((player.get("abilities") as Array)[0] as Dictionary)["stage"]) == 1 and (player.get("constructs") as Array).is_empty())
				_expect("with no remnant left the lock closes: the main page says what is missing and offers no way in",
					not bool(main.get("screen").get("rune_mode")) and _find(main, "LockMissing") != null and _find(main, "OpenSealButton") == null
					and (_find(main, "LockMissing") as Label).text.contains("remnant"))
				(player.get("constructs") as Array).append({"tier": "remnant", "concept": "reach"})
				main.get("screen").call("rebuild"))
			_queue.append(func() -> void:
				var b3: Control = _find(main, "OpenSealButton")
				_expect("carrying a remnant again, the main page offers the lock again", b3 != null)
				if b3 != null:
					_click_at(_centre(b3)))
			_queue_ring2()
			_queue.append(func() -> void: _click_at(_centre(_find(main, "LockConstruct_reach"))))
			_queue.append(func() -> void:
				(GameData.balance["binding"] as Dictionary)["success_chance"] = 1.0
				_click_at(_centre(_find(main, "SealBindButton"))))
			_queue.append(func() -> void:
				(GameData.balance["binding"] as Dictionary)["success_chance"] = _chance
				var st: Dictionary = (player.get("abilities") as Array)[0]
				var w3: Dictionary = st.get("word", {})
				_expect("built again and bound: stage 2, ring 1 and ring 2 full and sealed, the remnant of Reach the keystone of ring 2",
					int(st["stage"]) == 2 and RuneWord.sealed(w3) == 2 and RuneWord.ring_nodes(w3, 2).size() == 5 and RuneWord.ring_nodes(w3, 1).size() == 3
					and str(RuneWord.keystone(w3, 2).get("tier", "")) == "remnant" and str(RuneWord.keystone(w3, 2).get("concept", "")) == "reach"
					and str(RuneWord.keystone(w3, 1).get("concept", "")) == "tension", str(st))
				main.call("close_screen")
				_runes_from = 0
				_finish())
			_queue_at = frames + 4
	if not _queue.is_empty() and _queue_at > 0 and frames >= _queue_at:
		var step: Callable = _queue.pop_front()
		step.call()
		_queue_at = frames + 4


## The level 2 lock's rings, queued as real clicks and drags: ring 1 reworked (its last cap
## right-clicked out, a two-bond rune set in its place and bonded from the two-bond rune already
## there), then all five places of ring 2: a chain of two-bond runes out from it, each bonded to the
## one before, ending in a cap - every rune's bonds filled, so the word is closed.
func _queue_ring2() -> void:
	var player: Node = main.get("player")
	var bd := func() -> RuneBoard: return _find(main, "RuneBoard") as RuneBoard
	var last := func() -> int: return RuneWord.size(player.call("ability_word", 0)) - 1
	_queue.append(func() -> void:
		var at: Vector2 = (bd.call() as RuneBoard).node_global(int(last.call()))
		_move(at, false)
		_mouse(at, MOUSE_BUTTON_RIGHT, true)
		_mouse(at, MOUSE_BUTTON_RIGHT, false))
	_queue.append(func() -> void: _click_at(_centre(_find(main, "Rune_" + _link2))))
	_queue.append(func() -> void: _click_at((bd.call() as RuneBoard).empty_slot_global(1, 0)))
	_queue.append(func() -> void: _drag_start((bd.call() as RuneBoard).node_global(2)))
	_queue.append(func() -> void: _move((bd.call() as RuneBoard).node_global(2).lerp((bd.call() as RuneBoard).node_global(int(last.call())), 0.5), true))
	_queue.append(func() -> void: _drag_end((bd.call() as RuneBoard).node_global(int(last.call()))))
	for j: int in 5:
		var rid: String = _link2 if j < 4 else _caps[0]
		_queue.append(func() -> void: _click_at(_centre(_find(main, "Rune_" + rid))))
		_queue.append(func() -> void: _click_at((bd.call() as RuneBoard).empty_slot_global(2, 0)))
		_queue.append(func() -> void: _drag_start((bd.call() as RuneBoard).node_global(int(last.call()) - 1)))
		_queue.append(func() -> void: _move((bd.call() as RuneBoard).node_global(int(last.call()) - 1).lerp((bd.call() as RuneBoard).node_global(int(last.call())), 0.5), true))
		_queue.append(func() -> void: _drag_end((bd.call() as RuneBoard).node_global(int(last.call()))))


## A press on the board, the start of a drag (the moves and the release come on later frames).
func _drag_start(at: Vector2) -> void:
	_move(at, false)
	_mouse(at, MOUSE_BUTTON_LEFT, true)


func _drag_end(at: Vector2) -> void:
	_move(at, true)
	_mouse(at, MOUSE_BUTTON_LEFT, false)


## A key pressed and let go (with Ctrl when `ctrl`), as the keyboard would send it.
func _press_key(code: Key, ctrl: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.keycode = code
	key.ctrl_pressed = ctrl
	key.pressed = true
	get_viewport().push_input(key)
	var up := key.duplicate() as InputEventKey
	up.pressed = false
	get_viewport().push_input(up)


## The skill trainer in the street, counted in frames from the moment the controls menu closed.
func _trainer_steps(at: int) -> void:
	var player: Node = main.get("player")
	match at:
		1:
			var town: TownBuilder = main.get("_town")
			var trainer: Townsperson = town.person("trainer")
			(player as Node3D).global_position = trainer.global_position + Vector3(1.6, 0.0, 0.6)
			player.set("has_move_goal", false)
			player.set("skill_points", 2)
		10:
			var trainer: Townsperson = (main.get("_town") as TownBuilder).person("trainer")
			var cam: Camera3D = main.get("camera")
			_click_at(cam.unproject_position(trainer.global_position + Vector3.UP * 1.1))
		20:
			var s: Node = main.get("screen")
			_expect("clicking the trainer in the street opens their panel", s is TalkScreen and str(s.get("role")) == "trainer")
			var b: Button = _service("Training")
			_expect("the trainer offers training", b != null)
			if b != null:
				_click_at(_centre(b))
		30:
			var s: Node = main.get("screen")
			_expect("Training opens the skill tree, teaching", s is SkillTreeScreen and bool(s.get("at_trainer")))
			var node: Control = _find(main, "Node_standing_pool")
			_expect("the tree shows Standing Pool", node != null)
			if node != null:
				_click_at(_centre(node))
		40:
			_expect("clicking a node selects it", main.get("screen") is SkillTreeScreen and str((main.get("screen") as Node).get("selected")) == "standing_pool")
			var learn: Control = _find(main, "LearnButton")
			_expect("its Learn button is live", learn != null and not (learn as Button).disabled)
			if learn != null:
				_click_at(_centre(learn))
		50:
			_expect("clicking Learn teaches it and spends a point", bool(player.call("knows", "standing_pool")) and int(player.get("skill_points")) == 1)
			# the smith at the forge (design/12): what a billet needs, and enough skill that it cannot fail
			main.call("close_screen")
			main.call("close_screen")
			var smith: Townsperson = (main.get("_town") as TownBuilder).person("smith")
			(player as Node3D).global_position = smith.global_position + Vector3(1.4, 0.0, 0.8)
			player.set("has_move_goal", false)
			var inv: Inventory = player.get("inventory")
			for id: String in ["smiths_hammer", "scrap_iron", "scrap_iron", "scrap_iron", "scrap_iron", "flux_salt", "barrow_crucible"]:
				inv.add(id)
			(player.get("craft_skill") as Dictionary)["smithing"] = 30
		60:
			var smith: Townsperson = (main.get("_town") as TownBuilder).person("smith")
			var cam: Camera3D = main.get("camera")
			_click_at(cam.unproject_position(smith.global_position + Vector3.UP * 1.1))
		70:
			var s: Node = main.get("screen")
			_expect("clicking the smith opens their panel", s is TalkScreen and str(s.get("role")) == "smith")
			var teach: Control = _find(main, "TeachButton")
			_expect("the smith offers to teach the trade", teach != null and not (teach as Button).disabled)
			if teach != null:
				_click_at(_centre(teach))
		80:
			_expect("clicking it teaches the forge's recipes", Crafting.knows(player, "r_steel_billet"))
			var work: Control = _find(main, "WorkButton")
			if work != null:
				_click_at(_centre(work))
		90:
			_expect("Work at the forge opens the crafting screen", main.get("screen") is CraftScreen)
			var rec: Control = _find(main, "Recipe_r_steel_billet")
			_expect("it lists Steel Billet", rec != null)
			if rec != null:
				_click_at(_centre(rec))
		100:
			_expect("clicking a recipe selects it", main.get("screen") is CraftScreen and str((main.get("screen") as Node).get("selected")) == "r_steel_billet")
			var go: Control = _find(main, "CombineButton")
			_expect("its Combine button is live", go != null and not (go as Button).disabled)
			if go != null:
				_click_at(_centre(go))
		110:
			_expect("clicking Combine makes two billets from the scrap", (player.get("inventory") as Inventory).bag.count("steel_billet") == 2
				and not (player.get("inventory") as Inventory).bag.has("scrap_iron"))
			_trainer_from = 0
			_runes_from = frames


## The controls menu ignores input for 200 ms after a capture starts, so these steps go by the clock.
func _settings_steps() -> void:
	var since: int = Time.get_ticks_msec() - _step_ms
	match _step:
		"rebind":
			if since > 400:
				var key := InputEventKey.new()
				key.physical_keycode = KEY_Y
				key.keycode = KEY_Y
				key.pressed = true
				get_viewport().push_input(key)
				var up := key.duplicate() as InputEventKey
				up.pressed = false
				get_viewport().push_input(up)
				_step = "check_rebind"
				_step_ms = Time.get_ticks_msec()
		"check_rebind":
			if since > 150:
				_expect("clicking Ascend and pressing Y binds Ascend to Y", _physical("ascend") == KEY_Y)
				_click(_button_named("Reset to defaults"))
				_step = "check_reset"
				_step_ms = Time.get_ticks_msec()
		"check_reset":
			if since > 150:
				_expect("Reset to defaults puts Ascend back on T", _physical("ascend") == KEY_T)
				_click(_button_named("Close"))
				_step = "check_close"
				_step_ms = Time.get_ticks_msec()
		"check_close":
			if since > 150:
				_expect("the Close button shuts the controls menu", main.get("settings_menu") == null)
				_step = ""
				if OS.get_cmdline_user_args().has("--field"):
					_runes_from = frames
				else:
					_trainer_from = frames


func _physical(action: String) -> Key:
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	return (events[0] as InputEventKey).physical_keycode if not events.is_empty() and events[0] is InputEventKey else KEY_NONE


func _button_named(text: String) -> Control:
	return _find_button(main, text)


func _find_button(node: Node, text: String) -> Control:
	if node is Button and (node as Button).text == text and (node as Control).is_visible_in_tree():
		return node
	for c: Node in node.get_children():
		var b: Control = _find_button(c, text)
		if b != null:
			return b
	return null


func _click(c: Control) -> void:
	if c == null:
		return
	_move(_centre(c), false)
	_mouse(_centre(c), MOUSE_BUTTON_LEFT, true)
	_mouse(_centre(c), MOUSE_BUTTON_LEFT, false)


## Put the player's own key bindings back as they were before the test touched them.
func _restore_binds() -> void:
	if _binds_backup != null:
		var f := FileAccess.open(Keybinds.SAVE_PATH, FileAccess.WRITE)
		f.store_string(str(_binds_backup))
		f.close()
		Keybinds.call("_load")
	else:
		Keybinds.reset_defaults()


func _finish() -> void:
	_restore_binds()
	for line: String in results:
		print("UICLICK: " + line)
	print("UICLICK: %s" % ("FAIL" if failed else "PASS"))
	get_tree().quit(1 if failed else 0)
