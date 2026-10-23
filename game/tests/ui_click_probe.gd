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
## Then the seal screen (design/14 section 8), by clicks - see _rune_steps.
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


## The seal screen (design/14 sections 7-8, Brent 2026-10-23), by clicking: a skill whose bar is full
## and a vestige carried; Bind the vestige - form the seal opens the seal screen, forming ring 1.
## Set a rune from the palette, join it to the skill's own rune by clicking both, set a second rune
## onto the picked anchor, and a third (refused and explained when the anchor's two bonds are taken);
## then with a second rule set in force (tests/free_rules.gd) the same view follows those rules:
## their three-rune limit, explained, and a join by clicking. An undiscovered rune ("?") is refused
## and explained. Clear the draft; aim at ring 1 by clicking an empty place on it; close a word by
## clicking (the anchor's bonds filled with caps); Bind and seal - the skill's numbers change and the
## word is sealed. Then the next binding, from the ethercosm by clicks: a failed bind (forced) forms
## no seal and the word stays. The bind's roll is forced through balance "binding" success_chance
## (1, then 0) so the probe is not left to chance; it is put back after. Runes are chosen from the
## data by affinity and valence, not by name; the probe discovers them first (data, not clicks).
func _rune_steps(at: int) -> void:
	var player: Node = main.get("player")
	var s: Node = main.get("screen")
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
				if BondRules.valence(id) == 1 and _caps.size() < BondRules.valence(_anchor):
					_caps.append(id)
				elif _spare.size() < 3 and BondRules.valence(id) > 1:
					_spare.append(id)
			for id2: String in _spare + _caps:
				player.call("discover_rune", id2, "")
			for id3: String in (player.call("rune_palette") as Array):
				if str(GameData.rune(id3).get("affinity", "")) == "water" and not bool(player.call("knows_rune", id3)) and _unknown == "":
					_unknown = id3
			((player.get("abilities") as Array)[0] as Dictionary)["progress"] = 100.0
			(player.get("constructs") as Array).append({"tier": "vestige", "concept": "tension"})
			_chance = GameData.num("binding", "success_chance")
			main.call("open_ethercosm")
		10:
			_expect("the ethercosm is open", main.get("screen") is UiScreen and main.get("screen").has_method("open_seal"))
			var b: Control = _find(main, "FormSealButton_0")
			_expect("a full skill with a vestige carried offers to bind it and form the seal", b != null)
			if b != null:
				_click_at(_centre(b))
		20:
			_expect("the bind step opens the seal screen, forming ring 1", s != null and bool(s.get("rune_mode")) and _find(main, "RuneBoard") != null
				and str(s.call("seal_view")) == "bind" and (player.call("rune_context", 0) as RuneContext).forming == 1)
			var chip: Control = _find(main, "Rune_" + _spare[0])
			_expect("the palette offers the runes it knows", chip != null)
			if chip != null:
				_click_at(_centre(chip))
		30:
			var w: Dictionary = player.call("ability_word", 0)
			_expect("clicking a palette rune sets it into the draft, on ring 1", RuneWord.size(w) == 2 and RuneWord.node_id(w, 1) == _spare[0] and RuneWord.ring(w, 1) == 1)
			_click_at((_find(main, "RuneBoard") as RuneBoard).node_global(0))
		35:
			_expect("clicking the anchor picks it", int(s.get("picked")) == 0)
			_click_at((_find(main, "RuneBoard") as RuneBoard).node_global(1))
		45:
			_expect("clicking a second rune joins the two", RuneWord.linked(player.call("ability_word", 0), 0, 1))
			_click_at((_find(main, "RuneBoard") as RuneBoard).node_global(0))
		50:
			var chip: Control = _find(main, "Rune_" + _spare[1])
			if chip != null:
				_click_at(_centre(chip))
		60:
			_expect("with the anchor picked, a palette rune is set joined to it", RuneWord.linked(player.call("ability_word", 0), 0, 2))
			var chip: Control = _find(main, "Rune_" + _spare[2])
			if chip != null:
				_click_at(_centre(chip))
		70:
			var msg: Control = _find(main, "RuneMessage")
			if BondRules.valence(_anchor) <= 2:
				_expect("a third rune on the full anchor is refused, and the screen says why",
					RuneWord.size(player.call("ability_word", 0)) == 3 and msg != null and (msg as Label).text.contains("full"))
			else:
				_expect("a third rune on the anchor, which has room, is set", RuneWord.linked(player.call("ability_word", 0), 0, 3))
			_held = RuneWord.size(player.call("ability_word", 0))
			Runes.use(FreeRules.new())
			s.set("picked", -1)
			s.call("rebuild")
		80:
			var chip: Control = _find(main, "Rune_" + _spare[2])
			if chip != null:
				_click_at(_centre(chip))
		90:
			var msg: Control = _find(main, "RuneMessage")
			_expect("under the test rules the same view refuses a rune past their three, and says so",
				RuneWord.size(player.call("ability_word", 0)) == _held and msg != null and (msg as Label).text.contains("holds 3"))
			_click_at((_find(main, "RuneBoard") as RuneBoard).node_global(1))
		95:
			_click_at((_find(main, "RuneBoard") as RuneBoard).node_global(2))
		105:
			_expect("and joins two runes by clicking", RuneWord.linked(player.call("ability_word", 0), 1, 2))
			Runes.use(null)
			s.call("rebuild")
		110:
			var q: Control = _find(main, "Rune_" + _unknown)
			_expect("an undiscovered rune shows in the palette as \"?\"", q != null and not bool((s.call("chip_state", _unknown) as Dictionary)["known"]))
			if q != null:
				_click_at(_centre(q))
		115:
			var msg: Control = _find(main, "RuneMessage")
			_expect("and clicking it is refused: not discovered yet", msg != null and (msg as Label).text.contains("discovered") and RuneWord.size(player.call("ability_word", 0)) == _held)
			var clear: Control = _find(main, "ClearWordButton")
			_expect("the seal screen offers Clear", clear != null and not (clear as Button).disabled)
			if clear != null:
				_click_at(_centre(clear))
		122:
			_expect("Clear leaves the skill's own rune alone", RuneWord.size(player.call("ability_word", 0)) == 1)
			var slot: Vector2 = (_find(main, "RuneBoard") as RuneBoard).empty_slot_global(1)
			_expect("ring 1 shows its empty places", slot.x >= 0.0)
			_click_at(slot)
		126:
			_expect("clicking an empty place aims the next rune at its ring", int(s.get("target_ring")) == 1)
			_stats_before = str(player.call("ability_stats", (player.get("abilities") as Array)[0]))
			var seal0: Control = _find(main, "SealBindButton")
			_expect("with only the skill's own rune the draft is unchanged: binding would leave it without a word, and the screen says so",
				seal0 != null and not (seal0 as Button).disabled and str(main.get("screen").get("_lock_note").text).begins_with("Nothing set"))
			_click_at((_find(main, "RuneBoard") as RuneBoard).node_global(0))
		130, 140, 150:
			var k: int = int(float(at - 130) / 10.0)
			if k < _caps.size():
				var chip: Control = _find(main, "Rune_" + _caps[k])
				if chip != null:
					_click_at(_centre(chip))
		160:
			var w: Dictionary = player.call("ability_word", 0)
			_expect("the anchor's bonds filled with caps by clicking: the word is closed",
				RuneWord.size(w) == _caps.size() + 1 and bool(Runes.active().word_state(w, player.call("rune_context", 0))["closed"]))
			var sb: Control = _find(main, "SealBindButton")
			_expect("and Bind and seal is live", sb != null and not (sb as Button).disabled)
			(GameData.balance["binding"] as Dictionary)["success_chance"] = 1.0
			if sb != null:
				_click_at(_centre(sb))
		175:
			(GameData.balance["binding"] as Dictionary)["success_chance"] = _chance
			_expect("clicking it binds the vestige and seals the word: stage 1, one ring sealed",
				bool(player.call("word_locked", 0)) and int(((player.get("abilities") as Array)[0] as Dictionary)["stage"]) == 1 and RuneWord.sealed(player.call("ability_word", 0)) == 1)
			_expect("and the skill's numbers change with it", str(player.call("ability_stats", (player.get("abilities") as Array)[0])) != _stats_before
				and not (player.call("rune_summary", 0) as Array).is_empty())
			_expect("the screen now shows the seal, read-only", str(main.get("screen").call("seal_view")) == "view" and _find(main, "SealBindButton") == null)
			_sealed_key = RuneWord.shape_key(player.call("ability_word", 0))
			# the next binding: a full bar and a remnant
			((player.get("abilities") as Array)[0] as Dictionary)["progress"] = 100.0
			(player.get("constructs") as Array).append({"tier": "remnant", "concept": "reach"})
			var back: Control = _find(main, "RunesBackButton")
			if back != null:
				_click_at(_centre(back))
		185:
			var b2: Control = _find(main, "FormSealButton_0")
			_expect("back in the ethercosm, the next binding is offered", b2 != null)
			if b2 != null:
				_click_at(_centre(b2))
		195:
			_expect("it opens the seal forming ring 2, the sealed ring 1 in the draft", str(main.get("screen").call("seal_view")) == "bind"
				and (player.call("rune_context", 0) as RuneContext).forming == 2 and RuneWord.shape_key(player.call("ability_word", 0)) == _sealed_key)
			var sb2: Control = _find(main, "SealBindButton")
			_expect("an untouched draft may be bound as it is", sb2 != null and not (sb2 as Button).disabled)
			(GameData.balance["binding"] as Dictionary)["success_chance"] = 0.0
			if sb2 != null:
				_click_at(_centre(sb2))
		210:
			(GameData.balance["binding"] as Dictionary)["success_chance"] = _chance
			var msg: Control = _find(main, "RuneMessage")
			_expect("a failed bind forms no seal: the word stays as it was, the remnant is gone",
				RuneWord.shape_key(player.call("ability_word", 0)) == _sealed_key and RuneWord.sealed(player.call("ability_word", 0)) == 1
				and int(((player.get("abilities") as Array)[0] as Dictionary)["stage"]) == 1 and (player.get("constructs") as Array).is_empty()
				and msg != null and (msg as Label).text.contains("fails"))
			main.call("close_screen")
			_runes_from = 0
			_finish()


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
			var node: Control = _find(main, "Node_undertow")
			_expect("the tree shows Undertow", node != null)
			if node != null:
				_click_at(_centre(node))
		40:
			_expect("clicking a node selects it", main.get("screen") is SkillTreeScreen and str((main.get("screen") as Node).get("selected")) == "undertow")
			var learn: Control = _find(main, "LearnButton")
			_expect("its Learn button is live", learn != null and not (learn as Button).disabled)
			if learn != null:
				_click_at(_centre(learn))
		50:
			_expect("clicking Learn teaches it and spends a point", bool(player.call("knows", "undertow")) and int(player.get("skill_points")) == 1)
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
