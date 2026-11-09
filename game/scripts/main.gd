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
## The open screen was opened from the game menu, so closing it goes back to the menu.
var _menu_return := false
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


func _init() -> void:
	factory_part = LevelFactory.new(self)
	arena_part = MainArena.new(self)
	passage_part = MainPassage.new(self)
	field_part = MainField.new(self)
	town_part = MainTown.new(self)
	nether_part = MainNether.new(self)


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
			town_part.tick(delta)
		"arena_rest", "arena_fight":
			arena_part.tick(delta)
		"dungeon":
			passage_part.tick(delta)
		"field":
			field_part.tick(delta)

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
			town_part.handle_input(event)
		"arena_rest", "arena_fight":
			arena_part.handle_input(event)
		"field":
			field_part.handle_input(event)
		"dungeon":
			passage_part.handle_input(event)


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


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


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
			return town_part.where()
		"arena_rest", "arena_fight":
			return arena_part.where()
		"dungeon":
			return passage_part.where()
		"field":
			return field_part.where()
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
