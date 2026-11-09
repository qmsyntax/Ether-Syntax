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
## The zone's camps, herds, roamers and lurker patches (FieldCamps), while in a zone.
var field_camps: FieldCamps
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
## The test and screenshot harness (MainHarness): built only when a run has test, shot or bot arguments.
var _harness_part: MainHarness = null
## The parts (docs/architecture/main-split.md), one per concern, made in _init. Each reaches the node through
## its `main`; outside code keeps calling the node, which forwards (the blocks at the end of this file).
var factory_part: LevelFactory          # the world, levels, biomes, props, navigation, enemies placed
var arena_part: MainArena               # state "arena_rest" / "arena_fight": the practice arena
var passage_part: MainPassage           # state "dungeon": the assault passage
var field_part: MainField               # state "field": an overland zone
var town_part: MainTown                 # state "town": the town, its people, crafting and services
var nether_part: MainNether             # the Netherecho over a level: leaving the body, its look, its signals
var screens_part: MainScreens           # the screens, the game menu, the controls menu, the seal and ascension
var session_part: MainSession           # the character: starting one, saving and loading, dying


func _init() -> void:
	factory_part = LevelFactory.new(self)
	arena_part = MainArena.new(self)
	passage_part = MainPassage.new(self)
	field_part = MainField.new(self)
	town_part = MainTown.new(self)
	nether_part = MainNether.new(self)
	screens_part = MainScreens.new(self)
	session_part = MainSession.new(self)


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
	town_part._build_town()
	if _plays():
		GameSettings.apply_window()
	if _go_on(_then):
		return                          # a restart from the game menu: no title, no test arguments
	session_part._show_select()

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

	var running: MainLevel = MainStates.controller(self, state)
	if running != null:
		running.tick(delta)                 # the level the state names (MainStates)

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
			screens_part.open_game_menu()
		else:
			screens_part._open_settings()            # the title and the hardcore death notice: the controls, as before
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

	var running: MainLevel = MainStates.controller(self, state)
	if running != null:
		running.handle_input(event)         # the level the state names (MainStates)


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


## "[W]"-style tag for the current binding of an action, for on-screen prompts.
func _k(action: String) -> String:
	return "[%s]" % Keybinds.binding_text(action)


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


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## The level's own light (Light.base reads it): balance.json "light", by game state.
func light_base() -> String:
	var cfg: Dictionary = GameData.balance.get("light", {})
	return str((cfg.get("by_state", {}) as Dictionary).get(state, cfg.get("default", "dim")))


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


func _exit_tree() -> void:
	Models.free_prebuilt()                   # bodies never placed are in no tree: nothing else frees them


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
	var running: MainLevel = MainStates.controller(self, state)
	return running.where() if running != null else ""


# ================================================================================================
# Forwarders, one block per part. Outside code - the UI screens, the HUD, the builders, Light, the Netherecho,
# FieldCamps, data (town.json's gate actions) and the tests - calls these on the node by name (call / get /
# has_method strings included), and the node's signal handlers are connected here as before; a part never is.
# A new function outside code needs gets a forwarder in its part's block (docs/architecture/main-split.md).
# ================================================================================================

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


# --- passage_part (MainPassage)
func enter_passage() -> void: passage_part.enter_passage()
func _enter_dungeon() -> void: passage_part._enter_dungeon()
func _wall_kinds(c: int) -> Array[String]: return passage_part._wall_kinds(c)
func _activate(c: int) -> void: passage_part._activate(c)
func route(from: Vector3, to: Vector3, walker_radius: float) -> Vector3: return passage_part.route(from, to, walker_radius)
func _extract() -> void: passage_part._extract()
func repeat_mult() -> float: return passage_part.repeat_mult()


# --- field_part (MainField)
func walk_out() -> void: field_part.walk_out()
func enter_zone(id: String, arrive: String) -> void: field_part.enter_zone(id, arrive)
func _reveal() -> void: field_part._reveal()
func zone_point(world: Vector3) -> Vector2: return field_part.zone_point(world)
func minimap_info() -> Dictionary: return field_part.minimap_info()
func _field_interact() -> void: field_part._field_interact()
func _place_for_save() -> Dictionary: return field_part._place_for_save()
func _resume_place(place: Variant) -> bool: return field_part._resume_place(place)


# --- town_part (MainTown)
func _enter_town(arrive: String = "square") -> void: town_part._enter_town(arrive)
func _town_interact() -> void: town_part._town_interact()
func _town_click(at: Vector2) -> void: town_part._town_click(at)
func talk_to(role: String) -> void: town_part.talk_to(role)
func train_skill(ability_id: String) -> String: return town_part.train_skill(ability_id)
func drill_skill(ability_id: String) -> String: return town_part.drill_skill(ability_id)
func open_crafting(station_id: String) -> void: town_part.open_crafting(station_id)
func open_station_shop(station_id: String) -> void: town_part.open_station_shop(station_id)
func learn_trade(station_id: String) -> String: return town_part.learn_trade(station_id)
func open_field_kit(kit_id: String) -> void: town_part.open_field_kit(kit_id)
func craft(recipe_id: String, ctx: Dictionary) -> Dictionary: return town_part.craft(recipe_id, ctx)
func town_sell_loot() -> int: return town_part.town_sell_loot()
func town_sell_item(item_id: String) -> int: return town_part.town_sell_item(item_id)
func town_buy(item_id: String) -> String: return town_part.town_buy(item_id)
func town_rest_night() -> void: town_part.town_rest_night()


# --- nether_part (MainNether)
func toggle_projection() -> void: nether_part.toggle_projection()
func _on_nether_entered() -> void: nether_part._on_nether_entered()
func _on_nether_exited(reason: String) -> void: nether_part._on_nether_exited(reason)
func _on_body_disturbed() -> void: nether_part._on_body_disturbed()
func _on_projection_destroyed() -> void: nether_part._on_projection_destroyed()


# --- screens_part (MainScreens)
func _show_screen(new_screen: Control, pause: bool) -> void: screens_part._show_screen(new_screen, pause)
func close_screen() -> void: screens_part.close_screen()
func _on_settings_closed() -> void: screens_part._on_settings_closed()
func open_settings() -> void: screens_part.open_settings()
func open_shop() -> void: screens_part.open_shop()
func open_tempering() -> void: screens_part.open_tempering()
func open_inventory() -> void: screens_part.open_inventory()
func open_ethercosm() -> void: screens_part.open_ethercosm()
func open_saves() -> void: screens_part.open_saves()
func open_skill_tree(at_trainer: bool = false) -> void: screens_part.open_skill_tree(at_trainer)
func open_seal(ability_index: int, construct_index: int = -1) -> void: screens_part.open_seal(ability_index, construct_index)
func open_seal_first_ready() -> void: screens_part.open_seal_first_ready()
func _on_ascended(_star: int) -> void: screens_part._on_ascended(_star)
func resolve_ascension(affinity: String, aspects: Dictionary) -> String: return screens_part.resolve_ascension(affinity, aspects)
func menu_open_saves(mode: String) -> void: screens_part.menu_open_saves(mode)
func slot_save_block_reason() -> String: return screens_part.slot_save_block_reason()
func leave_warning() -> String: return screens_part.leave_warning()
func character_label() -> String: return screens_part.character_label()
func menu_where() -> String: return screens_part.menu_where()
func has_saves() -> bool: return screens_part.has_saves()
func load_from_menu(slot: int) -> void: screens_part.load_from_menu(slot)
func menu_test_character(aff: String) -> void: screens_part.menu_test_character(aff)
func quit_to_title() -> void: screens_part.quit_to_title()
func quit_game() -> void: screens_part.quit_game()
func set_fullscreen(on: bool) -> void: screens_part.set_fullscreen(on)
func zoom_start() -> float: return screens_part.zoom_start()
func set_zoom_start(z: float) -> void: screens_part.set_zoom_start(z)


# --- session_part (MainSession)
func start_new_character(index: int) -> void: session_part.start_new_character(index)
func begin_character(spec: Dictionary) -> String: return session_part.begin_character(spec)
func start_test_character(aff: String) -> void: session_part.start_test_character(aff)
func toggle_hardcore() -> void: session_part.toggle_hardcore()
func new_character() -> void: session_part.new_character()
func save_now() -> void: session_part.save_now()
func save_to_slot(slot: int) -> bool: return session_part.save_to_slot(slot)
func continue_game() -> bool: return session_part.continue_game()
func load_slot(slot: int) -> bool: return session_part.load_slot(slot)
func drop_item(item_id: String) -> void: session_part.drop_item(item_id)
func _on_player_died() -> void: session_part._on_player_died()
