class_name Main
extends Node3D
## Prototype flow: talent select -> town -> (assault passage | practice arena) -> town ...
## Everything is built in code so the project stays plain text. The node keeps the lifecycle, the shared
## state and the forwarders; each concern is a part in scripts/main/ (docs/architecture/main-split.md).

const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const SceneryScript := preload("res://scripts/scenery.gd")
const HudScript := preload("res://scripts/hud.gd")
const SettingsMenuScript := preload("res://scripts/settings_menu.gd")
const TitleScreen := preload("res://scripts/ui/title_screen.gd")
const ShopScreen := preload("res://scripts/ui/shop_screen.gd")
const InventoryScreen := preload("res://scripts/ui/inventory_screen.gd")
const MessageScreen := preload("res://scripts/ui/message_screen.gd")
const EthercosmScreen := preload("res://scripts/ui/ethercosm_screen.gd")
const AscensionScreen := preload("res://scripts/ui/ascension_screen.gd")

const CAMERA_OFFSET := Vector3(12.0, 12.0, 12.0)
const TALENT_CHOICES: Array[String] = [
	"one_percent_lifesteal", "tenth_strike", "grudge", "glass_hour", "debt_of_pain", "furnace_gut",
]

## A fresh game took this one's place (restart_game): tests that host main.tscn follow it here.
signal replaced(fresh: Node)

# Practice arena.
var arena_half: float = GameData.num("arena", "half_size")

# Assault passage. Rules follow design/01-systems-bible LAW 6b [C]: the entrance seals, a minimum
# of progress unlocks the exit, stages escalate and spike past the midpoint, the reward is paid
# only at the exit, and repeats pay less. Every number here is a first guess [MODEL].
var ch_len: float = GameData.num("passage", "chamber_length")
var ch_half_w: float = GameData.num("passage", "half_width")
var chambers: int = GameData.inum("passage", "chambers")
var gate_at: int = GameData.inum("passage", "gate_at")
var gap_half: float = GameData.num("passage", "gap_half")
var dungeon_rent_per_second: float = GameData.num("passage", "rent_per_s")
var ticket_price: int = GameData.inum("passage", "ticket_price")
var stage_value: int = GameData.inum("passage", "stage_value")
var full_clear_bonus: float = GameData.num("passage", "full_clear_bonus")
var repeat_factor: float = GameData.num("passage", "repeat_factor")
var repeat_floor: float = GameData.num("passage", "repeat_floor")
var late_strength: float = GameData.num("passage", "late_strength")
var exit_reach: float = GameData.num("passage", "exit_reach")

# Town.
var night_rent: int = GameData.inum("night", "rent")

var player: CharacterBody3D
var camera: Camera3D
var hud: Control
var hud_layer: CanvasLayer
var ui_root: Control                # themed parent of the HUD and every screen
var screen: Control                 # the menu screen currently shown, if any
var _prompt := ""                   # contextual hint shown in the HUD's prompt strip
var _screen_paused := false
var level: Node3D
var settings_menu: Control
var nether: Netherecho               # the spirit layer of the current level
var _env: Environment
var _sun: DirectionalLight3D

var state := "select"
var hardcore := false
var day := 1
var delves := 0
var rng := RandomNumberGenerator.new()

# arena
var wave := 0
var rest_timer := 0.0

# passage
var sealed := false
var current := 0                    # wall being fought (0 = none yet)
var cleared := 0
var bank := 0
var barriers: Dictionary = {}
var gates: Dictionary = {}            # chamber -> the gate model standing in that gap
## Where the current level is set (a Biomes id) and that biome's look.
var biome := "scrubland"
var _biome: Dictionary = {}
## Set by --biome=<id>: every level uses this one (tests, screenshots).
var forced_biome := ""
var pads: Array[Node3D] = []
# overland (design/07)
var zone_id := ""                   # the zone you are standing in, while state is "field"
var _zone: ZoneBuilder
var _return_to: Dictionary = {}      # where the passage's exit lets you out: {zone, at}, or town if empty
var fog: FogMap                      # what has been seen of the zone you are in
# town (design/08)
var _town: TownBuilder                # the town level's people and gateways, while it is built
var _talking_to := ""                 # role of the townsperson whose panel is open
var _walk_to: Townsperson = null      # the townsperson you clicked, being walked up to

var _rent_accum := 0.0
var _shot_mode := false
var _bot_mode := false
var _bot_finished := false
var _bot_died := false
var _last_cleared := 0
var _last_sealed := false
var _last_payout := 0
## Set by headless tests so they never touch the real save file.
var _test_mode := false
## What a fresh game does as soon as it is built (restart_game): {} = the title, {"test": affinity}
## or {"load": slot}.
var _then: Dictionary = {}
## The open screen was opened from the game menu, so closing it goes back to the menu.
var _menu_return := false
## The test and screenshot harness (MainHarness): built only when a run has test, shot or bot arguments.
var _harness_part: MainHarness = null
## The parts (docs/architecture/main-split.md), one per concern, made in _init. Each reaches the node through
## its `main`; outside code keeps calling the node, which forwards (the blocks at the end of this file).
var factory_part: LevelFactory          # the world, levels, biomes, props, navigation, enemies placed
var arena_part: MainArena               # state "arena_rest" / "arena_fight": the practice arena


func _init() -> void:
	factory_part = LevelFactory.new(self)
	arena_part = MainArena.new(self)


func _ready() -> void:
	var run_args: PackedStringArray = OS.get_cmdline_user_args()
	if run_args.has("--bot-dungeon") or run_args.has("--bot-full") or run_args.has("--bot-die"):
		RngSeed.fix_from_args()         # the passage bots are tests: the same layout and rolls every run
	RngSeed.apply(rng, "main")
	if _under_test():
		UserFiles.sandbox(TEST_SANDBOX)  # tests, shots and bots never read or write the player's own files
	add_to_group("router")              # where there is no navigation mesh yet: the way through a doorway
	factory_part._hold_effect_shaders()
	factory_part._build_world()
	_build_player()
	_build_hud()
	_build_town()
	if _plays():
		GameSettings.apply_window()
	if _go_on(_then):
		return                          # a restart from the game menu: no title, no test arguments
	_show_select()

	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		_harness().start(args)            # test, shot and bot arguments (MainHarness)


## The harness, built the first time a run needs it (a test, shot or bot argument, or a test calling in).
func _harness() -> MainHarness:
	if _harness_part == null:
		_harness_part = MainHarness.new(self)
	return _harness_part


func _process(delta: float) -> void:
	var focus: Vector3 = nether.projection.global_position if (nether.active and nether.projection != null) else player.global_position
	_place_camera(focus, delta)
	if nether.active:
		nether.tick(delta, camera)

	match state:
		"town":
			_tick_town(delta)
		"arena_rest", "arena_fight":
			arena_part.tick(delta)
		"dungeon":
			_tick_dungeon(delta)
		"field":
			_tick_field(delta)

	hud.call("refresh", player, _where())
	hud.set("show_world", state == "dungeon" or state == "arena_rest" or state == "arena_fight" or state == "field" or state == "town")
	hud.call("set_nether", nether.hud_info())
	hud.set("minimap", minimap_info())
	if nether.active and screen == null:
		_prompt = "Your body sits behind you, defenceless.   %s or walk back onto it to return.\nTouch wisps to gather them. Beat a construct down to subdue it." % _k("project")
	hud.call("set_prompt", _prompt if screen == null else "")
	hud.call("set_passage", {"walls": chambers, "cleared": cleared, "current": current, "gate": gate_at, "bank": bank} if state == "dungeon" else {})
	player.set("ui_blocked", screen != null or settings_menu != null or bool(hud.call("mouse_over_ui")))

	if _harness_part != null:
		_harness().tick()
	factory_part._tick_prebuild()


## Zoom (0 far .. 1 near) and where it is easing to; the wheel sets the target.
var cam_zoom := 0.45
var _cam_zoom_target := 0.45
var _cam_debug := false             # a debug shot mode placed the camera itself


## The BG3-style camera: perspective, at a fixed compass angle; zooming in brings it closer, lower
## and flatter (towards over-the-shoulder), zooming out raises it to look down on the fight.
func _place_camera(focus: Vector3, delta: float) -> void:
	if _cam_debug:
		camera.global_position = focus + CAMERA_OFFSET
		camera.look_at(focus + Vector3.UP, Vector3.UP)
		return
	var c: Dictionary = GameData.balance["camera"]
	cam_zoom = lerpf(cam_zoom, _cam_zoom_target, minf(1.0, delta * float(c["zoom_smoothing"]))) if delta > 0.0 else _cam_zoom_target
	var t: float = cam_zoom
	var dist: float = lerpf(float(c["distance_far"]), float(c["distance_near"]), t)
	var pitch: float = deg_to_rad(lerpf(float(c["pitch_far_deg"]), float(c["pitch_near_deg"]), t))
	var yaw: float = deg_to_rad(float(c["yaw_deg"]))
	var look: Vector3 = focus + Vector3.UP * lerpf(float(c["look_height_far"]), float(c["look_height_near"]), t)
	if player != null and player.has_method("camera_kick"):
		look += player.call("camera_kick")      # a landed blow nudges the view (balance.json feel)
	var back := Vector3(sin(yaw), 0.0, cos(yaw))
	camera.fov = lerpf(float(c["fov_far_deg"]), float(c["fov_near_deg"]), t)
	camera.global_position = look + back * cos(pitch) * dist + Vector3.UP * sin(pitch) * dist
	camera.look_at(look, Vector3.UP)


## Mouse wheel: up zooms in, down zooms out.
func _zoom_input(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton) or not (event as InputEventMouseButton).pressed:
		return false
	var step: float = GameData.num("camera", "zoom_step")
	match (event as InputEventMouseButton).button_index:
		MOUSE_BUTTON_WHEEL_UP:
			_cam_zoom_target = clampf(_cam_zoom_target + step, 0.0, 1.0)
		MOUSE_BUTTON_WHEEL_DOWN:
			_cam_zoom_target = clampf(_cam_zoom_target - step, 0.0, 1.0)
		_:
			return false
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if screen == null and _zoom_input(event):
		return
	if event.is_action_pressed("settings"):
		# Esc closes the topmost thing first: an open screen, then (with none) opens the game menu.
		# Paused, the screens take Esc themselves (UiScreen.close_actions, GameMenu.back).
		if screen is GameMenu:
			(screen as GameMenu).back()
		elif screen is ShopScreen or screen is InventoryScreen or screen is EthercosmScreen or screen is TalkScreen \
				or screen is TemperingScreen or screen is SkillTreeScreen or screen is CraftScreen or screen is SavesScreen:
			close_screen()
		elif screen == null and state != "select" and state != "dead":
			open_game_menu()
		else:
			_open_settings()            # the title and the hardcore death notice: the controls, as before
		get_viewport().set_input_as_handled()
		return

	if state == "select" or state == "dead":
		return
	if screen is AscensionScreen:
		return                          # the ascension is settled on its screen before anything else
	if event.is_action_pressed("inventory"):
		open_inventory()
		return
	if event.is_action_pressed("ethercosm"):
		open_ethercosm()
		return
	if event.is_action_pressed("skills"):
		open_skill_tree(false)
		return
	if event.is_action_pressed("project"):
		toggle_projection()
		return
	if nether.active:
		return                          # a soul has no hands for anything else

	match state:
		"town":
			# no skills in town: nothing here to use them on (a test character may still turn its bar)
			if event.is_action_pressed("hotbar_page") and bool(player.get("test_character")):
				player.call("next_hotbar_page")
			elif event.is_action_pressed("interact"):
				_town_interact()
			elif event.is_action_pressed("strike"):
				_town_click((event as InputEventMouseButton).position if event is InputEventMouseButton else get_viewport().get_mouse_position())
		"arena_rest", "arena_fight":
			arena_part.handle_input(event)
		"field":
			if _cast_from_hotbar(event):
				pass
			elif event.is_action_pressed("ascend"):
				player.call("try_ascend")
			elif event.is_action_pressed("bind"):
				open_seal_first_ready()
			elif event.is_action_pressed("healer"):
				player.call("note", "No healer out here. The town is back through the gate.")
			elif event.is_action_pressed("interact"):
				_field_interact()
		"dungeon":
			if _cast_from_hotbar(event):
				pass
			elif event.is_action_pressed("ascend"):
				player.call("try_ascend")
			elif event.is_action_pressed("bind"):
				open_seal_first_ready()
			elif event.is_action_pressed("healer"):
				player.call("note", "No healer in here. The entrance is sealed.")
			elif event.is_action_pressed("interact"):
				if _rune_stone_in_reach() != null:
					_read_stone(_rune_stone_in_reach())
				elif _pad_in_reach():
					_extract()
				elif pads.is_empty():
					player.call("note", "No exit yet. %d more walls." % maxi(0, gate_at - cleared))
				else:
					player.call("note", "Stand on a glowing exit to leave.")


## Hotbar slots are the actions ability_1..N. Returns true if the event cast something. A test
## character also turns the bar to its next six skills (hotbar_page). The sidestep key (combat review
## R3) is taken here too: wherever you can cast, you can step.
func _cast_from_hotbar(event: InputEvent) -> bool:
	if event.is_action_pressed("hotbar_page") and bool(player.get("test_character")):
		player.call("next_hotbar_page")
		return true
	if event.is_action_pressed("sidestep"):
		player.call("press_sidestep")             # now, or as soon as you are free (balance.json sidestep)
		return true
	for i: int in (player.get("hotbar") as Array).size():
		if event.is_action_pressed("ability_%d" % (i + 1)):
			player.call("press_slot", i)            # cast now, or as soon as you are free (balance.json feel)
			return true
	return false


func _open_settings() -> void:
	if settings_menu != null:
		return
	settings_menu = SettingsMenuScript.new()
	settings_menu.connect("closed", _on_settings_closed)
	ui_root.add_child(settings_menu)
	get_tree().paused = true


func _on_settings_closed() -> void:
	settings_menu = null
	get_tree().paused = _screen_paused
	if screen != null and screen.has_method("rebuild"):
		screen.call("rebuild")          # key names on screen may have changed


## "[W]"-style tag for the current binding of an action, for on-screen prompts.
func _k(action: String) -> String:
	return "[%s]" % Keybinds.binding_text(action)


# --- the game menu (Esc in play) ------------------------------------------------------------

## The game menu: Resume, New game (and the test characters), Save, Load, Settings, Quit to title,
## Quit game. Pauses the game in every state it opens in (town, field, passage, arena, the
## Netherecho); not on the title or the hardcore death notice, which have their own buttons.
func open_game_menu(view: String = "main") -> void:
	if state == "select" or state == "dead":
		return
	_menu_return = false
	_talking_to = ""
	_walk_to = null
	_show_screen(GameMenu.new(self, view), true)


## The register (SavesScreen) from the game menu, as "save" or "load"; closing it comes back to the menu.
func menu_open_saves(mode: String) -> void:
	if mode == "save" and slot_save_block_reason() != "":
		return
	_show_screen(SavesScreen.new(self, mode), true)
	_menu_return = true


## Why the character cannot be written to a numbered slot now, or "" if it can. The rule is the one
## the register already had (SavesScreen offered Save only in town; save_to_slot is "only
## meaningful in town"): slots are written in town. A test character may be written to a slot: the
## slot keeps it marked as one (Player.to_save), so loading it is still never autosaved. Nothing
## writes a test character to the autosave (save_now).
func slot_save_block_reason() -> String:
	if state == "select" or str(player.get("talent_id")) == "":
		return "There is no character to save."
	if state == "dead":
		return "This character is dead."
	if state == "town":
		return ""
	var test: bool = bool(player.get("test_character"))
	match state:
		"field":
			if test:
				return "Saving to a slot is done in town, as at the inn's register. A test character is never autosaved."
			return "Saving to a slot is done in town, as at the inn's register. Out here the autosave keeps your place every %d s." % int(
				float((GameData.balance.get("camps", {}) as Dictionary).get("field_autosave_s", 30.0)))
		"dungeon":
			return "Saving to a slot is done in town. Nothing is saved inside a passage; the last autosave is from before you went in."
	return "Saving to a slot is done in town. Nothing is saved in the arena; the last autosave is from town."


## What leaving the character in play would lose, for the game menu's question; "" when there is
## nothing to lose (no character, or a test character: never saved anyway). The game keeps no
## record of what has changed since the last save, so a real character is always asked about.
func leave_warning() -> String:
	if state == "select" or state == "dead" or str(player.get("talent_id")) == "" or bool(player.get("test_character")):
		return ""
	var lines: Array[String] = []
	match state:
		"town":
			lines.append("Anything since the last autosave is lost. In town the autosave is written each time something changes; the game does not track what has changed since, so it asks every time.")
		"field":
			lines.append("Out here the autosave runs every %d s; whatever happened since the last one is lost." % int(
				float((GameData.balance.get("camps", {}) as Dictionary).get("field_autosave_s", 30.0))))
		"dungeon":
			lines.append("Nothing is saved inside a passage: this run, its spoils and anything picked up since you went in are lost.")
		_:
			lines.append("Nothing is saved in the arena: anything since you left town is lost.")
	if nether.active:
		lines.append("Your soul is out in the Netherecho.")
	return "\n".join(lines)


## The character's name for the menu ("Test: Fire", "Maren"), or its talent if it has none.
func character_label() -> String:
	var n: String = str(player.get("char_name"))
	if n != "":
		return n
	var t: String = str(player.get("talent_id"))
	return str(TalentDB.get_talent(t).get("name", "no character")) if t != "" else "no character"


## Where the character is, for the menu's header.
func menu_where() -> String:
	var w: String = _where()
	if w == "":
		w = state
	return ("The Netherecho of " + w.get_slice("  -  ", 0)) if nether.active else w


## Whether any slot (the autosave or a numbered one) holds a character.
func has_saves() -> bool:
	for slot: int in SaveGame.SLOTS + 1:
		if not SaveGame.read(SaveGame.slot_path(slot)).is_empty():
			return true
	return false


## The game menu's Load: a fresh game that loads this slot (restart_game). The menu asked first.
func load_from_menu(slot: int) -> void:
	if SaveGame.read(SaveGame.slot_path(slot)).is_empty():
		return
	restart_game({"load": slot})


## The game menu's test characters: a fresh game that starts this one in town at once.
func menu_test_character(aff: String) -> void:
	if GameData.affinity(aff).is_empty():
		return
	restart_game({"test": aff})


## Back to the title (character creation and the test characters), as at the first start.
func quit_to_title() -> void:
	restart_game()


func quit_game() -> void:
	get_tree().quit()


## Settings (the game menu's): the window, and the zoom a game starts at (-1 = the data's default).
## A new starting zoom moves the camera there now too.
func set_fullscreen(on: bool) -> void:
	GameSettings.set_fullscreen(on)


func zoom_start() -> float:
	return GameSettings.zoom_start()


func set_zoom_start(z: float) -> void:
	if z < 0.0:
		GameSettings.reset_zoom_start()
	else:
		GameSettings.set_zoom_start(z)
	_cam_zoom_target = GameSettings.zoom_start()
	cam_zoom = _cam_zoom_target
	var focus: Vector3 = nether.projection.global_position if (nether.active and nether.projection != null) else player.global_position
	_place_camera(focus, 0.0)                   # paused under the menu: move it now, so it shows


## Whether this run is the game being played (no test, shot or bot arguments): only then are the
## player's own settings applied, so tests and screenshots look the same on every machine.
func _plays() -> bool:
	return not _test_mode and OS.get_cmdline_user_args().is_empty()


## Where every run that is not play keeps its saves, key bindings and settings (UserFiles.sandbox).
const TEST_SANDBOX := "user://test_sandbox/"


## A run that must not touch the player's files: test, shot or bot arguments, the test flag, or a
## scene from res://tests/ hosting this one. A test that set its own folder first keeps it.
func _under_test() -> bool:
	if UserFiles.sandbox_dir != "" or SaveGame.test_dir != "":
		return false
	if not _plays():
		return true
	var top: Node = get_tree().current_scene
	return top != null and top != self and top.scene_file_path.begins_with("res://tests/")


## Throw this game away and put a fresh one in its place - the title, as at the first start - and,
## if asked, go straight on: {"test": affinity} starts that test character, {"load": slot} loads
## that slot. Replaces the main node instead of reloading the scene, so a test that hosts
## main.tscn as a child keeps running (it follows `replaced`). The innkeeper's "Someone else" and
## the hardcore death notice use it too (new_character).
func restart_game(then: Dictionary = {}) -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	_swap_for_fresh.call_deferred(then)


func _swap_for_fresh(then: Dictionary) -> void:
	var parent: Node = get_parent()
	if parent == null or is_queued_for_deletion():
		return
	var tree: SceneTree = get_tree()
	var was_current: bool = tree.current_scene == self
	var fresh: Node = (load(scene_file_path if scene_file_path != "" else "res://scenes/main.tscn") as PackedScene).instantiate()
	fresh.set("_test_mode", _test_mode)
	fresh.set("_then", then)
	fresh.process_mode = process_mode
	var at: int = get_index()
	parent.remove_child(self)             # out of the world first: two players never share it
	parent.add_child(fresh)
	parent.move_child(fresh, at)
	if was_current:
		tree.current_scene = fresh
	replaced.emit(fresh)
	queue_free()


## A fresh game's first move (restart_game): start the test character or load the slot. False if
## there was nothing to do (or the slot would not load), and the title is shown.
func _go_on(then: Dictionary) -> bool:
	if then.has("test"):
		start_test_character(str(then["test"]))
		return true
	if then.has("load"):
		return load_slot(int(then["load"]))
	return false


# --- select / town --------------------------------------------------------------

func _show_select() -> void:
	state = "select"
	_show_screen(CreationScreen.new(self), false)


func _select_talent(index: int) -> void:
	player.call("set_talent", TALENT_CHOICES[index])


func _enter_town(arrive: String = "square") -> void:
	if nether.active:
		nether.exit("")
	_build_town()
	player.call("end_fight")
	player.call("refill_endurance")             # the town gives you your wind back (balance.json endurance)
	player.global_position = level.to_global(_town.arrival(arrive))
	player.set("attack_target", null)
	player.set("pickup_target", null)
	player.set("has_move_goal", false)
	player.set("active", true)                # the town is a place you walk round (design/08)
	state = "town"
	_prompt = ""
	_talking_to = ""
	_walk_to = null
	save_now()
	_show_screen(null, false)


# --- the town as a place (design/08) -----------------------------------------------------------

## Each frame in town: who is close enough to talk to, the gateways you walk through, and the
## person you clicked being walked up to. Walking away from someone closes what they showed you.
func _tick_town(_delta: float) -> void:
	_prompt = ""
	if _town == null:
		return
	var near: Townsperson = _town.folk_in_reach(player.global_position)
	for p: Townsperson in _town.folk:
		var on: bool = p == near and screen == null
		if is_instance_valid(p) and p.focused != on:
			p.set_focus(on)
	if _talking_to != "":
		var who: Townsperson = _town.person(_talking_to)
		if screen == null:
			_talking_to = ""
		elif who != null and _flat_dist(who.global_position, player.global_position) > float(GameData.town.get("leave_reach", 4.5)):
			_talking_to = ""
			_show_screen(null, false)
	if _walk_to != null:
		if not is_instance_valid(_walk_to) or screen != null or not bool(player.get("has_move_goal")):
			_walk_to = null
		elif _flat_dist(_walk_to.global_position, player.global_position) <= float(GameData.town.get("talk_reach", 2.7)):
			var role: String = _walk_to.role
			_walk_to = null
			player.set("has_move_goal", false)
			talk_to(role)
			return
		elif not Input.is_action_pressed("strike"):
			player.set("move_goal", _walk_to.global_position)
	var ex: Dictionary = _town.exit_at(player.global_position)
	if not ex.is_empty() and bool(ex.get("walk_through", false)):
		player.call("note", "You go through %s." % str(ex.get("name", "the gate")))
		call(str(ex["action"]))
		return
	if screen != null:
		return
	if near != null:
		_prompt = "%s talk to %s, %s" % [_k("interact"), near.folk_name, near.title]
		return
	var door: Dictionary = _town_door_in_reach()
	if not door.is_empty():
		_prompt = "%s the door into %s - an owned passage: ticket $%d, and a meter while you are inside." % [_k("interact"), str(door.get("prompt", "the passage")), ticket_price]
		return
	for gate: Dictionary in _town.exits:
		if bool(gate.get("walk_through", false)) and _flat_dist(level.to_global(gate["centre"]), player.global_position) < 6.0:
			_prompt = str(gate.get("prompt", ""))


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## A shut door in town you are standing at (the passage), or {}.
func _town_door_in_reach() -> Dictionary:
	if _town == null:
		return {}
	for ex: Dictionary in _town.exits:
		if not bool(ex.get("walk_through", false)) and _flat_dist(level.to_global(ex["centre"]), player.global_position) <= float(GameData.town.get("exit_reach", 1.5)) * 2.0:
			return ex
	return {}


## The interact key in town: stop talking, talk to whoever is close, or use the door you are at.
func _town_interact() -> void:
	if screen != null:
		close_screen()
		return
	var who: Townsperson = _town.folk_in_reach(player.global_position) if _town != null else null
	if who != null:
		talk_to(who.role)
		return
	var door: Dictionary = _town_door_in_reach()
	if not door.is_empty():
		call(str(door["action"]))
		return
	player.call("note", "Nobody close enough to talk to. Walk up to someone.")


## A click in town at a screen point: on a person, walk up to them and talk.
func _town_click(at: Vector2) -> void:
	if screen != null or _town == null or bool(hud.call("ui_at", at)):
		return
	var who: Townsperson = _town.pick_screen(at, camera)
	if who == null:
		_walk_to = null                 # a click elsewhere is a new walk: _tick_town would steer back to them
		return
	if _flat_dist(who.global_position, player.global_position) <= float(GameData.town.get("talk_reach", 2.7)):
		talk_to(who.role)
		return
	_walk_to = who
	player.set("move_goal", who.global_position)
	player.set("has_move_goal", true)


## Talk to the townsperson who does `role` (data/town.json "folk"): their panel opens.
func talk_to(role: String) -> void:
	if state != "town" or GameData.town_folk(role).is_empty():
		return
	_talking_to = role
	_show_screen(TalkScreen.new(self, role), false)


## The skill tree. From the trainer (`at_trainer`, only while talking to them in town) its Learn
## and Drill buttons work; opened anywhere else it is for looking. Out of town it pauses the game.
func open_skill_tree(at_trainer: bool = false) -> void:
	if screen is SkillTreeScreen and not at_trainer:
		close_screen()
		return
	if state == "select" or state == "dead":
		return
	var teaching: bool = at_trainer and state == "town" and _talking_to == "trainer"
	_show_screen(SkillTreeScreen.new(self, teaching), state != "town")


## Learn a skill from the trainer: only in town, only while talking to them. Returns "" or why not.
func train_skill(ability_id: String) -> String:
	if state != "town" or _talking_to != "trainer":
		return "Only a trainer can teach you a skill. Find one in town."
	var why: String = player.call("train_skill", ability_id)
	if why == "":
		save_now()
	return why


## Drill a known skill with the trainer: the same rule. Returns "" or why not.
func drill_skill(ability_id: String) -> String:
	if state != "town" or _talking_to != "trainer":
		return "Only a trainer can drill you. Find one in town."
	var why: String = player.call("drill_skill", ability_id)
	if why == "":
		save_now()
	return why

# --- crafting (design/12) ------------------------------------------------------------------------

## The station of the craftsperson you are talking to, or "".
func _talking_station() -> String:
	return str(GameData.town_folk(_talking_to).get("station", "")) if state == "town" and _talking_to != "" else ""


## Work at a station: only in town, while talking to the person who keeps it.
func open_crafting(station_id: String) -> void:
	if _talking_station() != station_id or Crafting.station(station_id).is_empty():
		return
	_show_screen(CraftScreen.new(self, {"station": station_id, "grade": int(Crafting.station(station_id).get("grade", 1)), "kit": ""}), false)


## The craftsperson's tools and supplies (data/crafting.json stations.<id>.sells).
func open_station_shop(station_id: String) -> void:
	if _talking_station() != station_id:
		return
	var st: Dictionary = Crafting.station(station_id)
	_show_screen(ShopScreen.new(self, st.get("sells", []), str(st.get("name", "Supplies"))), false)


## Pay the craftsperson you are talking to and learn every recipe of their skill.
func learn_trade(station_id: String) -> String:
	if _talking_station() != station_id:
		return "Only the keeper of that station can teach it."
	var why: String = Crafting.teach(player, str(Crafting.station(station_id).get("skill", "")))
	if why == "":
		save_now()
	return why


## Open a field kit from the pack: its station's recipes, anywhere, with no fee and no salvage.
## Out of town it pauses the game, like the pack itself.
func open_field_kit(kit_id: String) -> void:
	var kit: Dictionary = GameData.item(kit_id).get("kit", {})
	if kit.is_empty() or not (player.get("inventory") as Inventory).bag.has(kit_id) or state == "select" or state == "dead":
		return
	_talking_to = ""
	_show_screen(CraftScreen.new(self, {"station": str(kit["station"]), "grade": int(kit.get("grade", 1)), "kit": kit_id}), state != "town")


## One combine, if this is a place you may make it: the station of the person you are talking to,
## or a kit in your pack. Returns Crafting.combine's result ({ok, why, success, ...}).
func craft(recipe_id: String, ctx: Dictionary) -> Dictionary:
	var kit: String = str(ctx.get("kit", ""))
	var here: Dictionary
	if kit != "":
		var k: Dictionary = GameData.item(kit).get("kit", {})
		if k.is_empty() or not (player.get("inventory") as Inventory).bag.has(kit):
			return {"ok": false, "why": "You do not have that kit."}
		here = {"station": str(k["station"]), "grade": int(k.get("grade", 1)), "kit": kit}
	else:
		var station_id: String = _talking_station()
		if station_id == "" or station_id != str(ctx.get("station", "")):
			return {"ok": false, "why": "You can only work at a station whose keeper you are talking to."}
		here = {"station": station_id, "grade": int(Crafting.station(station_id).get("grade", 1)), "kit": ""}
	var res: Dictionary = Crafting.combine(player, recipe_id, here, player.get("rng"))
	player.call("refresh_gear")
	if bool(res.get("ok", false)):
		save_now()
	return res


# --- overland zones (design/07) ----------------------------------------------------------------

## Out of the Dross Gate into the yard outside the city.
func walk_out() -> void:
	enter_zone("the_stubble", "dross_gate")


## Walk into an overland zone, arriving by the named line. No rent out here, no ticket, no meter.
func enter_zone(id: String, arrive: String) -> void:
	var def: Dictionary = GameData.zone(id)
	if def.is_empty():
		return
	_show_screen(null, false)
	if nether.active:
		nether.exit("")
	factory_part._new_level(float(def.get("yaw", 0.0)))
	factory_part._use_biome(def.get("biome", "scrubland"), false)
	zone_id = id
	_zone = ZoneBuilder.new(self, def)
	_zone.build()
	_build_field_life()
	var spot: Array = (def.get("arrive", {}) as Dictionary).get(arrive, [_zone.size.x * 0.5, _zone.size.y * 0.5])
	player.global_position = level.to_global(_zone.to_local(float(spot[0]), float(spot[1])))
	player.set("active", true)
	player.set("has_move_goal", false)
	player.call("end_fight")
	factory_part._place_corpses(id)
	fog = FogMap.new(_zone.size, GameData.num("minimap", "fog_cell_m"))
	fog.from_text(str((player.get("explored") as Dictionary).get(id, "")))
	state = "field"
	_reveal()
	player.call("note", "You walk out into %s." % str(def.get("name", id)))
	save_now()


## Each frame in a zone: the lines you are standing at, and what the door ahead says.
func _tick_field(_delta: float) -> void:
	_prompt = ""
	_reveal()
	var here: Vector3 = level.to_local(player.global_position)
	for line: Dictionary in _zone.def.get("lines", []):
		var c: Vector3 = _zone.line_centre(line)
		var d: float = Vector2(here.x - c.x, here.z - c.z).length()
		if bool(line.get("open", false)) and d < 2.0:
			if str(line["to"]) == "town":
				player.call("note", "You come back in through %s." % str(line.get("name", "the gate")))
				_enter_town("dross_gate")
				return
		elif not bool(line.get("open", false)) and d < 7.0:
			_prompt = str(line.get("sign", "Closed."))
	if _cut_door_in_reach():
		_prompt = "%s the door into Tenwall Cut - an owned passage: ticket $%d, and a meter while you are inside." % [_k("interact"), ticket_price]
	_stone_prompt()
	_entrance_prompt()


## Clear the fog round where you stand, and keep what you have seen with the character.
func _reveal() -> void:
	if fog == null or _zone == null:
		return
	var at: Vector2 = zone_point(player.global_position)
	if fog.reveal(at.x, at.y, GameData.num("minimap", "sight_m")):
		(player.get("explored") as Dictionary)[zone_id] = fog.to_text()
	fog.refresh_texture()


## A world position as a point in the current zone's map frame (x east, y south).
func zone_point(world: Vector3) -> Vector2:
	var l: Vector3 = level.to_local(world)
	return Vector2(l.x + _zone.size.x * 0.5, l.z + _zone.size.y * 0.5)


## What the minimap needs this frame, or {} when you are not out in a zone.
func minimap_info() -> Dictionary:
	if state != "field" or _zone == null or fog == null:
		return {}
	var facing: Vector3 = level.global_transform.basis.inverse() * (player.get("_facing") as Vector3)
	var lying: Array = []
	for c: Dictionary in player.get("corpses"):
		if str(c.get("where", "")) == zone_id:
			var pos: Array = c.get("pos", [0.0, 0.0, 0.0])
			lying.append(Vector2(float(pos[0]) + _zone.size.x * 0.5, float(pos[2]) + _zone.size.y * 0.5))
	return {"def": _zone.def, "size": _zone.size, "fog": fog, "at": zone_point(player.global_position),
		"facing": Vector2(facing.x, facing.z), "corpses": lying,
		"camps": field_camps.minimap_marks() if field_camps != null and is_instance_valid(field_camps) else []}


func _cut_door_in_reach() -> bool:
	var ch: Dictionary = _zone.def.get("cut_house", {}) if _zone != null else {}
	if ch.is_empty():
		return false
	var door: Array = ch["door"]
	var at: Vector3 = level.to_global(_zone.to_local(float(door[0]), float(door[1])))
	return Vector2(at.x - player.global_position.x, at.z - player.global_position.z).length() <= 5.0


## The interact key in a zone: the Cut House door, if you are at it.
func _field_interact() -> void:
	var stone: RuneStone = _rune_stone_in_reach()
	if stone != null:
		_read_stone(stone)
		return
	if _cut_door_in_reach():
		var from_zone: String = zone_id
		enter_passage()
		if state == "dungeon":
			_return_to = {"zone": from_zone, "at": "cut_house_door"}
		return
	if _use_entrance():
		return
	player.call("note", "Nothing here to use.")


# --- the living field: camps, entrances, your place in the save (2026-10-23, the Stubble) ---------

## The zone's camps, herds, roamers and lurker patches (FieldCamps), while in a zone.
var field_camps: FieldCamps
var _field_save_t := 0.0


## Put the zone's living things in it (zones.json "camps", "lurker_patches").
func _build_field_life() -> void:
	field_camps = FieldCamps.new()
	field_camps.setup(self, _zone)
	level.add_child(field_camps)
	field_camps.build(OS.get_cmdline_user_args().has("--all-camps"))
	_field_save_t = 0.0


## The dungeon mouth you are standing at (FieldEntrance), or null. Name plates show near them.
func _entrance_in_reach() -> FieldEntrance:
	var best: FieldEntrance = null
	var best_d := INF
	for n: Node in get_tree().get_nodes_in_group("field_entrances"):
		var e := n as FieldEntrance
		if e == null or not e.is_inside_tree():
			continue
		var d: float = _flat_dist(e.global_position, player.global_position)
		e.set_near(d <= e.reach * 3.0)
		if d <= e.reach and d < best_d:
			best = e
			best_d = d
	return best


func _entrance_prompt() -> void:
	var e: FieldEntrance = _entrance_in_reach()
	if e != null:
		_prompt = "%s %s" % [_k("interact"), e.entrance_name]
	_field_save_t += get_process_delta_time()
	if _field_save_t >= float((GameData.balance.get("camps", {}) as Dictionary).get("field_autosave_s", 30.0)):
		_field_save_t = 0.0
		save_now()                              # the save keeps your place out here


## Use the entrance you are at: it says what it is and that it is not open yet (stubbed).
func _use_entrance() -> bool:
	var e: FieldEntrance = _entrance_in_reach()
	if e == null:
		return false
	player.call("note", e.use_text())
	hud.call("announce", e.entrance_name.to_upper())
	return true


## Where the character is, for the save: the zone and the spot, or {} (town).
func _place_for_save() -> Dictionary:
	if state != "field" or _zone == null:
		return {}
	var at: Vector2 = zone_point(player.global_position)
	return {"zone": zone_id, "at": [snappedf(at.x, 0.1), snappedf(at.y, 0.1)]}


## Load into the zone and spot a save was made in. False if it was made in town (or the zone is gone).
func _resume_place(place: Variant) -> bool:
	if not (place is Dictionary) or str((place as Dictionary).get("zone", "")) == "" or GameData.zone(str(place["zone"])).is_empty():
		return false
	var where: Dictionary = place
	enter_zone(str(where["zone"]), "")
	var at: Array = where.get("at", [])
	if at.size() == 2 and _zone != null:
		player.global_position = level.to_global(_zone.to_local(float(at[0]), float(at[1])))
		_reveal()
		save_now()
	return state == "field"


# --- the Netherecho ------------------------------------------------------------------------

## Leave the body, or return to it. Only possible out of combat, in the field.
func toggle_projection() -> void:
	if nether.active:
		nether.exit("You return to your body.")
		return
	if state != "dungeon" and state != "arena_rest" and state != "field":
		player.call("note", "There is nothing to find in the echo of this place." if state == "town" else "Not now.")
		return
	var why: String = nether.cannot_enter_reason()
	if why != "":
		player.call("note", why)
		return
	nether.enter()


func _on_nether_entered() -> void:
	_set_nether_look(true)
	hud.call("announce", "THE NETHERECHO")
	player.call("note", "You step out of yourself.")


func _on_nether_exited(reason: String) -> void:
	_set_nether_look(false)
	_prompt = ""
	if reason != "":
		player.call("note", reason)


## Something hit the body while the soul was away.
func _on_body_disturbed() -> void:
	if nether.active:
		nether.exit("Pain drags you back into your body.")


## Canon: a destroyed projection is death. Standard mode turns that into debt like any other death.
func _on_projection_destroyed() -> void:
	player.call("note", "Your soul is torn apart in the echo.")
	(player.get("body") as Body).apply_damage(99999.0)
	player.call("_check_death")


## The echo of a place: dark, violet, lit from nowhere. Living enemies and loose loot do not show.
func _set_nether_look(on: bool) -> void:
	# the waking world looks like its biome; the echo of any place is the same dark violet
	_env.background_color = Color(0.03, 0.015, 0.07) if on else _biome.get("sky", Color(0.045, 0.05, 0.065))
	_env.ambient_light_color = Color(0.5, 0.42, 0.95) if on else _biome.get("ambient", Color(0.5, 0.56, 0.7))
	var boost: float = float((GameData.balance["biomes"]["ambient_boost"] as Dictionary).get(biome, 1.0))
	_env.ambient_light_energy = 0.75 if on else float(_biome.get("ambient_energy", 0.6)) * boost
	_env.fog_light_color = Color(0.1, 0.05, 0.2) if on else _biome.get("fog_color", Color(0.1, 0.11, 0.14))
	_env.fog_density = 0.006 if on else float(_biome.get("fog_density", 0.006))
	_sun.light_energy = 0.18 if on else float(_biome.get("sun_energy", 1.35))
	_sun.light_color = Color(0.7, 0.6, 1.0) if on else _biome.get("sun_color", Color(1.0, 0.87, 0.72))
	_sun.rotation_degrees = _biome.get("sun_rotation", Vector3(-44.0, 38.0, 0.0))
	for group: String in ["enemies", "pickups"]:
		for n: Node in get_tree().get_nodes_in_group(group):
			if n is Node3D:
				(n as Node3D).visible = not on


# --- screens ---------------------------------------------------------------------------

func _show_screen(new_screen: Control, pause: bool) -> void:
	if screen != null:
		screen.queue_free()
	screen = new_screen
	_screen_paused = pause and new_screen != null
	if new_screen != null:
		ui_root.add_child(new_screen)
		if settings_menu != null:
			ui_root.move_child(settings_menu, -1)
	get_tree().paused = _screen_paused or settings_menu != null


## Close the open screen. In town, a screen someone showed you goes back to talking to them, and
## closing that leaves you standing in the street.
func close_screen() -> void:
	if _menu_return and screen != null and not (screen is GameMenu):
		_show_screen(GameMenu.new(self), true)      # opened from the game menu: back to it
		_menu_return = false
		return
	_menu_return = false
	if state == "town":
		if _talking_to != "" and not (screen is TalkScreen):
			_show_screen(TalkScreen.new(self, _talking_to), false)
		else:
			_talking_to = ""
			_show_screen(null, false)
	elif state == "select":
		_show_screen(CreationScreen.new(self), false)
	else:
		_show_screen(null, false)


func open_settings() -> void:
	_open_settings()


func open_shop() -> void:
	if state == "town":
		_show_screen(ShopScreen.new(self), false)


func open_tempering() -> void:
	if state == "town":
		_show_screen(TemperingScreen.new(self), false)


## Toggle the inventory. Out in the field it pauses the game.
func open_inventory() -> void:
	if screen is InventoryScreen:
		close_screen()
	elif state != "select" and state != "dead":
		_show_screen(InventoryScreen.new(self), state != "town")


## Toggle the ethercosm - the view of your soul. Out in the field it pauses the game.
func open_ethercosm() -> void:
	if screen is EthercosmScreen:
		close_screen()
	elif state != "select" and state != "dead":
		_show_screen(EthercosmScreen.new(self), state != "town")


## Quick start with a default look (tests and bots); the creation screen uses begin_character.
## The two starting skills are the first two roots - a test convenience; a player always picks.
func start_new_character(index: int) -> void:
	player.call("set_affinities", GameData.default_affinities())
	begin_character({"talent_id": TALENT_CHOICES[index], "skills": player.call("default_start_skills")})


## Start the character described by the creation screen: {name, identity, look, talent_id,
## affinities, skills}. The talent and the affinities are the prime that was picked from the
## rolled offers; `skills` are the two starting skills the player picked (design/08) - nothing is
## given that was not picked. Returns "" or why the character could not begin.
func begin_character(spec: Dictionary) -> String:
	var talent: String = str(spec.get("talent_id", TALENT_CHOICES[0]))
	player.call("set_talent", talent if TALENT_CHOICES.has(talent) else TALENT_CHOICES[0])
	player.call("set_affinities", spec.get("affinities", []))
	var why: String = player.call("start_with_skills", spec.get("skills", []))
	if why != "":
		player.call("note", why)
		return why
	player.set("char_name", str(spec.get("name", "")).strip_edges().left(int(GameData.creation["name_max_length"])))
	player.set("identity", str(spec.get("identity", "")))
	player.call("set_look", spec.get("look", {}))
	player.set("money", GameData.inum("town", "starting_money"))
	_enter_town()
	return ""


func toggle_hardcore() -> void:
	hardcore = not hardcore


func new_character() -> void:
	restart_game()


func enter_passage() -> void:
	_return_to = {}
	if not bool(player.call("can_afford", ticket_price)):
		player.call("note", "No one will sell you a ticket on that much debt.")
		return
	player.call("charge", ticket_price)
	_show_screen(null, false)
	_enter_dungeon()


func repeat_mult() -> float:
	return _repeat_mult()


## Drop one item from the bag. In the field it lands at your feet; in town it is simply gone.
func drop_item(item_id: String) -> void:
	var inv: Inventory = player.get("inventory")
	if not inv.remove(item_id):
		return
	var item_name: String = str(GameData.item(item_id).get("name", item_id))
	if state == "town":
		player.call("note", "You leave the %s behind." % item_name)
		save_now()
	else:
		PlayerScript.spawn_pickup(level, item_id, player.global_position + Vector3(0.9, 0.0, 0.4))
		player.call("note", "Dropped %s." % item_name)


# --- town services (logic only; the UI calls these) ------------------------------

## Sell every piece of loot in the bag. Returns what it fetched.
func town_sell_loot() -> int:
	var inv: Inventory = player.get("inventory")
	var got: int = inv.sell_loot()
	if got > 0:
		player.set("money", int(player.get("money")) + got)
		player.call("note", "Sold your loot for $%d." % got)
	else:
		player.call("note", "Nothing in your pack that anyone wants.")
	save_now()
	return got


## Sell one item from the bag (loot at full value, gear at a fraction).
func town_sell_item(item_id: String) -> int:
	var inv: Inventory = player.get("inventory")
	var got: int = inv.sell_item(item_id)
	if got > 0:
		player.set("money", int(player.get("money")) + got)
		player.call("note", "Sold %s for $%d." % [str(GameData.item(item_id).get("name", item_id)), got])
		save_now()
	return got


## Buy a shop item on credit (to the debt limit). Returns "" on success, else why not.
func town_buy(item_id: String) -> String:
	var def: Dictionary = GameData.item(item_id)
	if def.is_empty():
		return "no such item"
	var price: int = int(def.get("value", 0))
	if not bool(player.call("can_afford", price)):
		return "Nobody will lend you that much."
	var inv: Inventory = player.get("inventory")
	if not inv.can_add(item_id):
		return "You cannot carry it - %d of %d kg." % [int(inv.weight()), int(inv.capacity())]
	player.call("charge", price)
	inv.add(item_id)
	player.call("note", "Bought %s for $%d." % [str(def.get("name", item_id)), price])
	save_now()
	return ""


## A room at the inn for the night - the only rent there is (Brent 2026-10-18).
func town_rest_night() -> void:
	player.call("rest_night")
	player.call("charge", night_rent)
	day += 1
	save_now()


## Per-person reward at the exit, scaled to how far you got (canon: contribution-scaled loot).
## Whatever you cannot carry is left behind.
func grant_exit_rewards(walls_cleared: int, full_clear: bool) -> Array[String]:
	var cfg: Dictionary = GameData.items_file.get("exit_rewards", {})
	var rolls: int = int(float(walls_cleared) / float(cfg.get("walls_per_roll", 2.5)))
	if full_clear:
		rolls += int(cfg.get("bonus_rolls_full_clear", 0))
	var table: Array = GameData.items_file.get("exit_reward_table", [])
	var total := 0.0
	for entry: Dictionary in table:
		total += float(entry["weight"])
	var got: Array[String] = []
	var inv: Inventory = player.get("inventory")
	for i: int in rolls:
		var pick: float = rng.randf() * total
		for entry: Dictionary in table:
			pick -= float(entry["weight"])
			if pick <= 0.0:
				var id: String = str(entry["item"])
				if inv.add(id):
					got.append(str(GameData.item(id).get("name", id)))
				break
	player.call("refresh_gear")
	return got


# --- saving ------------------------------------------------------------------------

## The autosave.
func save_now() -> void:
	if _bot_mode or _shot_mode or _test_mode or bool(player.get("test_character")):
		return                            # a test character never writes over the real autosave
	save_to_slot(0)


## The level's own light (Light.base reads it): balance.json "light", by game state.
func light_base() -> String:
	var cfg: Dictionary = GameData.balance.get("light", {})
	return str((cfg.get("by_state", {}) as Dictionary).get(state, cfg.get("default", "dim")))


## The title screen's "Test characters" (Brent 2026-10-22): one character with this one affinity
## and every skill of it learned, at a stage high enough for big rune words, a full tank and the
## test rune palette, starting in town (the arena gate is a short walk). Marked as a test
## character: never autosaved over the real save, and only it can turn the bar to the next page.
func start_test_character(aff: String) -> void:
	player.call("set_talent", TALENT_CHOICES[0])
	player.call("make_test_character", aff)
	player.set("char_name", "Test: %s" % str(GameData.affinity(aff).get("label", aff)))
	player.set("identity", str((GameData.creation.get("identities", [{}]) as Array)[0].get("id", "")) if not (GameData.creation.get("identities", []) as Array).is_empty() else "")
	player.call("set_look", {})
	player.set("money", GameData.inum("town", "starting_money"))
	_enter_town()


## Write the character as it stands to a slot (0 = autosave). Only meaningful in town.
func save_to_slot(slot: int) -> bool:
	if str(player.get("talent_id")) == "":
		return false
	if str(player.get("char_id")) == "":
		player.set("char_id", SaveGame.new_char_id())   # one id for every save of this character
	var data: Dictionary = player.call("to_save")
	data["day"] = day
	data["delves"] = delves
	data["hardcore"] = hardcore
	data["place"] = _place_for_save()
	var ok: bool = SaveGame.write(data, SaveGame.slot_path(slot))
	var said: String = SaveGame.take_note()   # a displaced autosave kept, or a newer save not written over
	if said != "":
		player.call("note", said)
	if slot > 0:
		player.call("note", "Saved to slot %d." % slot if ok else "Could not write slot %d." % slot)
	elif not ok and said == "":
		player.call("note", "The autosave could not be written (see the log); your last save is unchanged.")
	return ok


## Load the autosave into town. Returns false if there is nothing usable to load.
func continue_game() -> bool:
	return load_slot(0)


## Load a slot into town; the loaded character becomes the autosave too.
func load_slot(slot: int) -> bool:
	var data: Dictionary = SaveGame.read(SaveGame.slot_path(slot))
	var said: String = SaveGame.take_note()       # recovered from a backup copy, or refused as newer
	if data.is_empty() or str(data.get("talent_id", "")) == "":
		if said != "":
			player.call("note", said)
		return false
	player.call("from_save", data)
	if said != "":
		player.call("note", said)
	day = int(data.get("day", 1))
	delves = int(data.get("delves", 0))
	hardcore = bool(data.get("hardcore", false))
	if not _resume_place(data.get("place", {})):
		_enter_town()
	open_ascension()                       # an ascension left unsettled when it was saved
	return true


func open_saves() -> void:
	if state == "town" or state == "select":
		_show_screen(SavesScreen.new(self), false)


func _repeat_mult() -> float:
	return maxf(repeat_floor, pow(repeat_factor, float(delves)))


# --- assault passage ------------------------------------------------------------

func _enter_dungeon() -> void:
	# Rotated so the corridor runs straight "up" the isometric screen: W alone walks it.
	factory_part._new_level(45.0)
	var total: float = float(chambers + 1) * ch_len
	var mid_z: float = -total * 0.5
	var bcfg: Dictionary = GameData.balance["biomes"]
	factory_part._use_biome(bcfg["passage"])
	_biome_floor(Vector3(0, 0, mid_z), Vector2(ch_half_w * 2.0 + 2.0, total + 2.0))
	# side walls in chamber-length runs (the kit reuses a run of the same length)
	for c: int in range(0, chambers + 1):
		var cz: float = -(float(c) + 0.5) * ch_len
		_biome_wall(Vector3(-ch_half_w - 0.5, 0, cz), ch_len, 90.0, float(bcfg["wall_height_side"]))
		_biome_wall(Vector3(ch_half_w + 0.5, 0, cz), ch_len, -90.0, float(bcfg["wall_height_side"]))
	_biome_wall(Vector3(0, 0, 0.5), ch_half_w * 2.0, 180.0, float(bcfg["wall_height_near"]))
	_biome_wall(Vector3(0, 0, -total - 0.5), ch_half_w * 2.0, 0.0, float(bcfg["wall_height_far"]))

	var side_w: float = ch_half_w - gap_half
	var side_x: float = gap_half + side_w * 0.5
	for c: int in range(1, chambers + 1):
		var z: float = -float(c) * ch_len
		_biome_wall(Vector3(-side_x, 0, z), side_w, 0.0, float(bcfg["wall_height_divider"]))
		_biome_wall(Vector3(side_x, 0, z), side_w, 0.0, float(bcfg["wall_height_divider"]))
		# every doorway has its gate; only the sealed ones are shut
		var gate: Node3D = Biomes.gate(biome, gap_half * 2.0)
		gate.position = Vector3(0, 0, z)
		level.add_child(gate)
		gate.call("set_open", true, true)
		gates[c] = gate
		if c >= 2:
			_add_barrier(c)

	for c: int in range(0, chambers + 1):
		var near_z: float = -float(c) * ch_len
		factory_part._scatter_props(Vector3(0, 0, near_z - ch_len * 0.5), Vector2(ch_half_w - 0.3, ch_len * 0.5 - 1.2), int(bcfg["props_per_chamber"]), [near_z, near_z - ch_len])
		var tufts: int = GameData.inum("passage", "antechamber_tufts") if c == 0 else GameData.inum("passage", "chamber_tufts")
		for i: int in tufts:
			var pos := Vector3(rng.randf_range(-ch_half_w + 1.0, ch_half_w - 1.0), 0.0,
				-float(c) * ch_len - rng.randf_range(1.5, ch_len - 1.5))
			_spawn_cuttable(i, pos)

	# rune stones (design/14 section 8): one cut into the wall of each chamber the data names
	for ins: Dictionary in (GameData.rune_discovery.get("inscriptions", {}) as Dictionary).get("passage", []):
		var c2: int = int(ins.get("chamber", 1))
		if c2 < 0 or c2 > chambers:
			continue
		var stone := RuneStone.new()
		stone.setup(str(ins["id"]), str(ins.get("name", "A rune stone")), str(ins.get("pool", "base")))
		stone.position = Vector3(ch_half_w - 0.9, 0.0, -(float(c2) + 0.5) * ch_len)
		stone.rotation.y = -PI / 2.0
		level.add_child(stone)
		stone.set_read((player.get("read_inscriptions") as Array).has(str(ins["id"])))
	# the spirit layer: one site per chamber, antechamber included
	for c: int in range(0, chambers + 1):
		nether.populate_site(Vector3(0.0, 0.0, -(float(c) + 0.5) * ch_len), Vector2(ch_half_w - 1.5, ch_len * 0.5 - 1.5))
	player.global_position = level.to_global(Vector3(0.0, 0.0, -4.0))
	player.set("active", true)
	factory_part._place_corpses("passage")
	# everyone the passage can put up is loaded now, with the level, not the first time each kind wakes;
	# the first wall's bodies are built ahead (the rest after each wall falls - _on_wall_cleared)
	var roster: Array[String] = []
	for c3: int in range(1, chambers + 1):
		roster.append_array(_wall_kinds(c3))
	factory_part._warm_bodies(roster + factory_part._calls_of(roster))
	_prebuild_bodies(_wall_kinds(1))
	state = "dungeon"
	player.call("note", "You step through into %s. Walk up the corridor (%s)." % [str(_biome.get("label", biome)).to_lower(), Keybinds.binding_text("move_up")])


## Seal the doorway into chamber `c`: an unseen collider, and its gate shut.
func _add_barrier(c: int) -> void:
	var b: StaticBody3D = _static_box(Vector3(0, 1.0, -float(c) * ch_len), Vector3(gap_half * 2.0, 2.0, 0.6), Color.BLACK, false)
	barriers[c] = b
	if gates.has(c):
		(gates[c] as Node).call("set_open", false, c >= 2 and not sealed)


func _tick_dungeon(delta: float) -> void:
	var local: Vector3 = level.to_local(player.global_position)
	var depth: float = -local.z
	var fighting: bool = current > cleared

	if not fighting:
		var next_c: int = cleared + 1
		if next_c <= chambers and depth > float(next_c) * ch_len + 1.5:
			if not sealed:
				sealed = true
				_add_barrier(1)
				player.call("note", "Stone grinds shut behind you. The entrance is sealed.")
			_activate(next_c)
			_set_dungeon_banner()
			return
		if sealed:
			# The town clock does not stop because you are underground.
			_charge_rent(dungeon_rent_per_second, delta)
	elif get_tree().get_nodes_in_group("enemies").is_empty():
		_on_wall_cleared()

	_set_dungeon_banner()

	if _bot_mode:
		_harness().bot_dungeon_tick()


## Who stands in wall `c`, in the order they are placed: the front line of grunts, the brutes, a
## commander at the gate and at the last wall, then the wall's recipe (design/05 6.2).
func _wall_kinds(c: int) -> Array[String]:
	var kinds: Array[String] = []
	for i: int in GameData.inum("passage", "grunts_base") + c / 2:
		kinds.append("grunt")
	for i: int in maxi(0, (c - GameData.inum("passage", "brute_offset")) / GameData.inum("passage", "brute_every")):
		kinds.append("brute")
	if c == gate_at or c == chambers:
		kinds.append("commander")
	# the wall's recipe: what stands behind the front line, and its one problem (design/05 6.2)
	var recipe: Dictionary = _wall_recipe(c)
	for kind: String in recipe:
		for i: int in int(recipe[kind]):
			kinds.append(kind)
	return kinds


func _activate(c: int) -> void:
	current = c
	var strength: float = late_strength if c > gate_at else 1.0
	var kinds: Array[String] = _wall_kinds(c)
	for kind: String in kinds:
		# archers start at the back of the chamber, where a back line belongs
		var back: bool = str(GameData.enemy(kind).get("behaviour", "melee")) == "ranged"
		var local := Vector3(rng.randf_range(-ch_half_w + 2.0, ch_half_w - 2.0), 0.0,
			rng.randf_range(-float(c + 1) * ch_len + 2.0, -float(c + 1) * ch_len + 4.0) if back
			else rng.randf_range(-float(c + 1) * ch_len + 2.0, -float(c) * ch_len - 7.0))
		factory_part._spawn_enemy(kind, local, strength)
	_prebuild_bodies(factory_part._calls_of(kinds))         # a commander's call for help lands mid-fight: its bodies wait ready
	player.call("start_fight")
	player.call("note", "Wall %d of %d." % [c, chambers])
	hud.call("announce", "WALL %d" % c if c != chambers else "THE LAST WALL")
	if _harness_part != null:
		_harness().shot_dungeon_wall(c)


## Where something at `from` should walk next to reach `to` (both in world space). In the passage
## that may be a doorway first; anywhere else it is `to` itself. See Route. Only used until the
## level's navigation mesh is baked (LevelNav); after that everything follows paths.
func route(from: Vector3, to: Vector3, walker_radius: float) -> Vector3:
	if state != "dungeon" or level == null:
		return to
	var step: Vector3 = Route.step_toward(level.to_local(from), level.to_local(to), ch_len, gap_half, walker_radius)
	return level.to_global(step)


## Extra enemies for wall `c`: its own recipe, or the nearest lower one that has one.
func _wall_recipe(c: int) -> Dictionary:
	var recipes: Dictionary = GameData.balance["passage"]["wall_recipes"]
	for n: int in range(c, 0, -1):
		if recipes.has(str(n)):
			return recipes[str(n)]
	return {}


func _on_wall_cleared() -> void:
	cleared = current
	bank += stage_value * cleared
	player.call("end_fight")
	var next_c: int = cleared + 1
	if barriers.has(next_c):
		(barriers[next_c] as Node).queue_free()
		barriers.erase(next_c)
		if gates.has(next_c):
			(gates[next_c] as Node).call("set_open", true)
	if cleared < chambers:
		_prebuild_bodies(_wall_kinds(cleared + 1))   # built while you walk to the next doorway
	if cleared >= gate_at:
		_spawn_pad(cleared)
	player.call("note", "Wall %d cleared. Spoils worth $%d waiting - yours only if you walk out with them." % [cleared, bank])
	if cleared == gate_at:
		hud.call("announce", "AN EXIT OPENS")


func _spawn_pad(c: int) -> void:
	var pad := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.4
	disc.bottom_radius = 1.4
	disc.height = 0.1
	pad.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 1.0, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.9, 0.4)
	pad.material_override = mat
	pad.position = Vector3(0.0, 0.06, -(float(c) + 0.5) * ch_len)
	level.add_child(pad)
	pads.append(pad)


func _pad_in_reach() -> bool:
	for pad: Node3D in pads:
		var d: Vector3 = pad.global_position - player.global_position
		d.y = 0.0
		if d.length() <= exit_reach:
			return true
	return false


func _payout_now() -> int:
	var bonus: float = full_clear_bonus if cleared == chambers else 1.0
	return int(float(bank) * _repeat_mult() * bonus)


func _extract() -> void:
	var owed: int = _payout_now()
	var carried: Array = grant_spoils(owed)
	_last_payout = int(carried[0])
	_last_cleared = cleared
	_last_sealed = sealed
	_bot_finished = _bot_mode
	delves += 1
	player.call("note", "You walk out after %d walls carrying spoils worth $%d." % [cleared, int(carried[0])])
	if int(carried[1]) > 0:
		player.call("note", "You could not carry the rest - $%d of it stays at the exit." % int(carried[1]))
	var rewards: Array[String] = grant_exit_rewards(cleared, cleared == chambers)
	if _return_to.is_empty():
		_enter_town("passage")
	else:
		var back: Dictionary = _return_to
		_return_to = {}
		enter_zone(str(back["zone"]), str(back["at"]))
	if not rewards.is_empty():
		player.call("note", "At the exit: %s." % ", ".join(rewards))


## A delve's spoils as things to carry home and sell (nothing pays cash - Brent 2026-10-18): the
## most valuable kind first, as many as the pack will take. Returns [value carried, value left].
func grant_spoils(value: int) -> Array:
	var inv: Inventory = player.get("inventory")
	var left: int = value
	for id: Variant in GameData.items_file.get("spoils", []):
		var each: int = int(GameData.item(str(id)).get("value", 0))
		while each > 0 and left >= each and inv.add(str(id)):
			left -= each
	player.call("refresh_gear")
	return [value - left, left]


func _set_dungeon_banner() -> void:
	if not sealed:
		_prompt = "The antechamber. Walk up the corridor (%s) to begin - the entrance seals behind you.\nLast chance to cut grass in peace." % Keybinds.binding_text("move_up")
	elif current > cleared:
		_prompt = ""
	elif cleared >= chambers:
		_prompt = "All %d walls down.   %s on a glowing exit to leave with spoils worth $%d, full-clear bonus included - as much as you can carry." % [chambers, _k("interact"), _payout_now()]
	elif cleared >= gate_at:
		_prompt = "%s on a glowing exit to leave with spoils worth $%d   -   or push on: wall %d adds $%d more.\nRent is $%d a second while you stand here." % [_k("interact"), _payout_now(), cleared + 1, stage_value * (cleared + 1), int(dungeon_rent_per_second)]
	else:
		_prompt = "Spoils worth $%d waiting, but no exit until wall %d.   Rest if you need it - rent is $%d a second." % [bank, gate_at, int(dungeon_rent_per_second)]
	_stone_prompt()


# --- rune stones (design/14 section 8) ------------------------------------------------------

## The nearest rune stone within reading reach, or null.
func _rune_stone_in_reach() -> RuneStone:
	if player == null:
		return null
	var reach: float = float((GameData.rune_discovery.get("inscriptions", {}) as Dictionary).get("reach", 2.5))
	var best: RuneStone = null
	var best_d := INF
	for n: Node in get_tree().get_nodes_in_group("rune_stones"):
		var st := n as RuneStone
		if st == null or not st.is_inside_tree():
			continue
		var d: float = _flat_dist(st.global_position, player.global_position)
		if d <= reach and d < best_d:
			best = st
			best_d = d
	return best


func _read_stone(stone: RuneStone) -> void:
	player.call("read_inscription", stone.stone_id, stone.pool, stone.stone_name)
	stone.set_read(true)
	save_now()


func _stone_prompt() -> void:
	var stone: RuneStone = _rune_stone_in_reach()
	if stone == null:
		return
	var read: bool = (player.get("read_inscriptions") as Array).has(stone.stone_id)
	_prompt = ("%s.   Already read." % stone.stone_name) if read else ("%s read %s - runes are cut into it." % [_k("interact"), stone.stone_name.to_lower()])


## Open the seal screen of ability `ability_index` at its next level lock (design/14 sections 8 and
## 11): the ring is built and the construct chosen and bound there - the only place a construct is
## bound (Brent 2026-10-23), and only with the bar full and a construct of the tier carried (Brent
## 2026-10-24). `construct_index` < 0: the keystone is chosen on the screen.
func open_seal(ability_index: int, construct_index: int = -1) -> void:
	if not (screen is EthercosmScreen):
		if state == "select" or state == "dead":
			return
		_show_screen(EthercosmScreen.new(self), state != "town")
	screen.call("select", ability_index)
	screen.call("open_seal", construct_index)


## The B key ("bind"): opens the seal screen of the first skill whose level lock can open - its bar
## full and a construct of its tier carried (Brent 2026-10-24). With none, it says what the first full
## skill is missing. It binds nothing itself.
func open_seal_first_ready() -> void:
	var abilities: Array = player.get("abilities")
	var missing := ""
	for ai: int in abilities.size():
		var lock: Dictionary = player.call("can_open_seal", ai)
		if bool(lock["ok"]):
			open_seal(ai)
			return
		if missing == "" and str(lock["reason"]) == "no_construct":
			missing = "%s: %s" % [str(GameData.ability(str(abilities[ai]["id"])).get("name", "?")), str(lock["text"])]
	player.call("note", missing if missing != "" else "No skill is ready for its level lock: a skill's bar fills as you use it.")


# --- shared ---------------------------------------------------------------------

func _charge_rent(rate: float, delta: float) -> void:
	_rent_accum += rate * delta
	if _rent_accum >= 1.0:
		var due: int = int(_rent_accum)
		_rent_accum -= float(due)
		player.call("charge", due)


func _exit_tree() -> void:
	Models.free_prebuilt()                   # bodies never placed are in no tree: nothing else frees them


func _on_player_died() -> void:
	if hardcore:
		state = "dead"
		# permadeath: every save of this character goes - the autosave, any slot, every backup copy
		# (a test or bot run is sandboxed, so this only ever reaches the player's files in play)
		if _plays() or SaveGame.test_dir != "":
			SaveGame.clear_character(str(player.get("char_id")))
		_prompt = ""
		_show_screen(MessageScreen.new(self, "YOU DIED", "Hardcore: that was the only life this character had.", "Begin again", new_character), false)
		return
	var lost: int = bank if state == "dungeon" else 0
	_bot_died = true
	_bot_finished = _bot_mode
	# a corpse run (Brent 2026-10-18): the body stays where it fell with everything on it
	var where: String = "passage" if state == "dungeon" else ("arena" if state.begins_with("arena") else (zone_id if state == "field" else ""))
	_return_to = {}
	if where != "" and level != null:
		var at: Vector3 = level.to_local(player.global_position)
		player.call("die_to_corpse", where, Route.chamber_of(at, ch_len) if where == "passage" else 0, at)
	player.call("respawn_naked")
	if lost > 0:
		player.call("note", "The spoils of the walls you cleared stayed in the passage.")
	_last_payout = 0
	_enter_town()


## The town is a level (design/08): data/town.json built by TownBuilder - streets, gateways and
## the people who do what the old town menu did.
func _build_town() -> void:
	factory_part._new_level(0.0)
	var cfg: Dictionary = GameData.balance["biomes"]
	factory_part._use_biome(cfg["town"], false)            # the town is always the town
	_town = TownBuilder.new(self, GameData.town)
	_town.build()


# --- construction ---------------------------------------------------------------


func _build_player() -> void:
	player = PlayerScript.new()
	add_child(player)
	player.global_position = Vector3.ZERO
	player.connect("died", _on_player_died)
	player.connect("disturbed", _on_body_disturbed)
	player.connect("rune_discovered", _on_rune_discovered)
	player.connect("ascended", _on_ascended)
	nether.player = player


## A star ascended (Brent 2026-10-24): the ascension screen offers its affinities and boosts.
func _on_ascended(_star: int) -> void:
	open_ascension()


## Show the pending ascension's screen (an affinity to choose, then each skill's boost). It pauses
## and holds the keys until it is settled; a save made meanwhile keeps it, and loading reopens it.
func open_ascension() -> void:
	if (player.get("ascension_pending") as Dictionary).is_empty() or state == "select" or state == "dead":
		return
	_show_screen(AscensionScreen.new(self), true)


## Settle the pending ascension with the screen's choices (Player.resolve_ascension), then save and
## close. Returns "" or why not.
func resolve_ascension(affinity: String, aspects: Dictionary) -> String:
	var why: String = str(player.call("resolve_ascension", affinity, aspects))
	if why != "":
		return why
	save_now()
	close_screen()
	return ""


## A rune became known: the HUD shows it (design/14 section 8).
func _on_rune_discovered(rune_id: String, source: String) -> void:
	if hud != null:
		hud.call("show_rune", rune_id, source)


func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)

	# One themed root so every Button, Label and Panel below shares the same look.
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_root.theme = UiTheme.theme()
	hud_layer.add_child(ui_root)

	hud = HudScript.new()
	ui_root.add_child(hud)


func _where() -> String:
	match state:
		"town":
			return "Town  -  day %d" % day
		"arena_rest", "arena_fight":
			return arena_part.where()
		"dungeon":
			return "The passage  -  wall %d of %d  -  spoils $%d" % [cleared, chambers, bank]
		"field":
			return str(GameData.zone(zone_id).get("name", zone_id))
	return ""


# --- the test harness (MainHarness): a shot's watcher (MainShots.ShotWatch) calls this by name
func _save_shot() -> void: _harness()._save_shot()


# --- factory_part (LevelFactory)
func _biome_floor(centre: Vector3, size: Vector2) -> void: factory_part._biome_floor(centre, size)
func _biome_wall(centre: Vector3, length: float, yaw: float, height: float) -> StaticBody3D: return factory_part._biome_wall(centre, length, yaw, height)
func _spawn_cuttable(index: int, local_pos: Vector3) -> void: factory_part._spawn_cuttable(index, local_pos)
func _static_box(pos: Vector3, size: Vector3, color: Color, show: bool = true) -> StaticBody3D: return factory_part._static_box(pos, size, color, show)
func _on_reinforcements(who: Node, kinds: Array) -> void: factory_part._on_reinforcements(who, kinds)
func _prebuild_bodies(kinds: Array[String]) -> void: factory_part._prebuild_bodies(kinds)


# --- arena_part (MainArena)
func enter_arena() -> void: arena_part.enter_arena()
