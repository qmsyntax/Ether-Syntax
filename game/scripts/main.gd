extends Node3D
## Prototype flow: talent select -> town -> (assault passage | practice arena) -> town ...
## Everything is built in code so the project stays plain text.

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
var _frames := 0
var _bot_mode := false
var _bot_scenario := ""             # "gate" = leave at the first exit, "full" = clear all walls, "die" = die inside
var _bot_finished := false
var _bot_died := false
var _bot_money_before := 0
var _bot_started_ms := 0
var _shot_dungeon := false          # windowed bot run that screenshots wall 2 as it wakes
var _shot_countdown := 0
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


func _ready() -> void:
	rng.randomize()
	add_to_group("router")              # where there is no navigation mesh yet: the way through a doorway
	_build_world()
	_build_player()
	_build_hud()
	_build_town()
	if _plays():
		GameSettings.apply_window()
	if _go_on(_then):
		return                          # a restart from the game menu: no title, no test arguments
	_show_select()

	var args: PackedStringArray = OS.get_cmdline_user_args()
	var ui_shot := ""
	for a: String in args:
		if a.begins_with("--shot-ui="):
			ui_shot = a.trim_prefix("--shot-ui=")
		elif a.begins_with("--biome="):
			forced_biome = a.trim_prefix("--biome=")
	if ui_shot != "":
		_setup_ui_shot(ui_shot)
	elif args.has("--shot"):
		_shot_mode = true
		_select_talent(0)
		enter_arena()
		rest_timer = 0.5
	elif args.has("--shot-settings"):
		# Screenshot the controls menu over the town. Not paused, so the countdown can tick.
		_shot_mode = true
		_frames = 1000
		_select_talent(0)
		_enter_town()
		_open_settings()
		get_tree().paused = false
		_shot_countdown = 25
	elif args.has("--bot-dungeon") or args.has("--bot-full") or args.has("--bot-die") or args.has("--shot-dungeon"):
		_shot_dungeon = args.has("--shot-dungeon")
		_bot_scenario = "full" if args.has("--bot-full") else ("die" if args.has("--bot-die") else "gate")
		_bot_mode = true
		_bot_started_ms = Time.get_ticks_msec()
		Engine.time_scale = 5.0
		_select_talent(0)
		player.set("money", ticket_price)
		_show_screen(null, false)
		_enter_dungeon()
		player.set("bot", true)


func _process(delta: float) -> void:
	var focus: Vector3 = nether.projection.global_position if (nether.active and nether.projection != null) else player.global_position
	_place_camera(focus, delta)
	if nether.active:
		nether.tick(delta, camera)

	match state:
		"town":
			_tick_town(delta)
		"arena_rest":
			rest_timer -= delta
			_prompt = "Wave %d in %d   -   pick up what the last one left before it starts\n%s go now     %s rest longer     %s healer     hold %s to meditate     %s back to town" % [
				wave + 1, int(ceil(rest_timer)),
				_k("go_now"), _k("rest"), _k("healer"), _k("meditate"), _k("interact")]
			if rest_timer <= 0.0:
				_start_wave()
		"arena_fight":
			_prompt = ""
			if get_tree().get_nodes_in_group("enemies").is_empty():
				player.call("end_fight")
				state = "arena_rest"
				rest_timer = GameData.num("arena", "rest_between_waves")
				player.call("note", "Wave %d cleared." % wave)
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

	if _shot_mode:
		_frames += 1
		if _frames == 260:
			_save_shot()
	if _shot_countdown > 0:
		_shot_countdown -= 1
		if _shot_countdown == 0:
			_save_shot()
	if _bot_mode:
		_tick_bot_report()


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
			if _cast_from_hotbar(event):
				pass
			elif event.is_action_pressed("ascend"):
				player.call("try_ascend")
			elif event.is_action_pressed("bind"):
				open_seal_first_ready()
			elif event.is_action_pressed("go_now"):
				if state == "arena_rest":
					rest_timer = 0.0
			elif event.is_action_pressed("rest"):
				if state == "arena_rest":
					rest_timer += GameData.num("arena", "rest_extend")
					player.call("note", "You rest a while longer. The landlord notices.")
			elif event.is_action_pressed("healer"):
				if state == "arena_rest":
					player.call("buy_healing")
				else:
					player.call("note", "The healer won't come in here mid-fight.")
			elif event.is_action_pressed("interact"):
				if state == "arena_rest":
					_enter_town("arena")
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
## character also turns the bar to its next six skills (hotbar_page).
func _cast_from_hotbar(event: InputEvent) -> bool:
	if event.is_action_pressed("hotbar_page") and bool(player.get("test_character")):
		player.call("next_hotbar_page")
		return true
	for i: int in (player.get("hotbar") as Array).size():
		if event.is_action_pressed("ability_%d" % (i + 1)):
			player.call("cast_slot", i)
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
	_new_level(float(def.get("yaw", 0.0)))
	_use_biome(def.get("biome", "scrubland"), false)
	zone_id = id
	_zone = ZoneBuilder.new(self, def)
	_zone.build()
	_build_field_life()
	var spot: Array = (def.get("arrive", {}) as Dictionary).get(arrive, [_zone.size.x * 0.5, _zone.size.y * 0.5])
	player.global_position = level.to_global(_zone.to_local(float(spot[0]), float(spot[1])))
	player.set("active", true)
	player.set("has_move_goal", false)
	player.call("end_fight")
	_place_corpses(id)
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


## Screenshot setups for the populated Stubble (windowed): --shot-ui=stubble-<what>. Each waits for
## the moment it exists to show (a wind-up, a charge, a rise) and then saves shots/shot.png.
##   overview, map, nether, swallow, cellar, herd, lurker, gleaner, scald, and fight-<kind>.
func _setup_stubble_shot(which: String) -> bool:
	var what: String = which.trim_prefix("stubble-")
	_shot_countdown = 0                              # the watch below takes the shot, at its moment
	_select_talent(0)
	player.set("look", CharacterLook.default_look())
	walk_out()
	player.set("bot", true)                         # it is not the subject: nothing it takes counts
	player.set_physics_process(false)
	var stand := func(x: float, y: float) -> void:
		player.global_position = level.to_global(_zone.to_local(x, y))
		_reveal()
	var near_kind := func(kind: String) -> Node:
		for n: Node in get_tree().get_nodes_in_group("enemies"):
			if str(n.get("kind")) == kind:
				return n
		return null
	_cam_zoom_target = 0.55
	cam_zoom = 0.55
	var until: Callable = func() -> bool: return false
	var go: Callable = func() -> void: pass         # what starts the moment, once the shaders have settled
	match what:
		"overview":
			# straight down on the whole zone, north up: the layout, not the look
			stand.call(120.0, 80.0)
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = 168.0
			camera.far = 2000.0
			_cam_debug = true
			player.visible = false
			hud.visible = false
			var north: Vector3 = level.global_transform.basis * Vector3(0, 0, -1)
			var mid: Vector3 = level.to_global(_zone.to_local(120.0, 80.0))
			cam_shot = Transform3D.IDENTITY.looking_at(Vector3.DOWN, north).translated(mid + Vector3.UP * 150.0)
			_env.fog_enabled = false                  # from this high the fog would hide everything
			# labels over the layout: camps (red), herds (green), lurker patches (brown), mouths and landmarks
			var tags: Array = []
			for c: Dictionary in _zone.def.get("camps", []):
				tags.append([c["at"], str(c.get("name", "")), Color(0.55, 1.0, 0.5) if bool(c.get("herd", false)) else Color(1.0, 0.45, 0.35)])
			for p2: Dictionary in _zone.def.get("lurker_patches", []):
				tags.append([p2["at"], "lurker", Color(0.85, 0.65, 0.4)])
			for e3: Dictionary in _zone.def.get("entrances", []):
				tags.append([e3["at"], str(e3.get("name", "")), Color(1.0, 0.85, 0.4)])
			for m: Dictionary in _zone.def.get("landmarks", []):
				tags.append([m["at"], str(m.get("name", "")), Color(0.9, 0.9, 1.0)])
			tags.append([[222, 112], "The Cut House", Color(1.0, 0.85, 0.4)])
			var labels := ShotLabels.new()
			for t: Array in tags:
				labels.items.append([level.to_global(_zone.to_local(float(t[0][0]), float(t[0][1]))), t[1], t[2]])
			labels.camera = camera
			var lay := CanvasLayer.new()
			lay.layer = 90
			add_child(lay)
			lay.add_child(labels)
		"map":
			# a walk's worth of the zone seen: the road, the well, the herd, the tree, the Cut track
			for p: Array in [[40, 6], [70, 14], [100, 18], [130, 24], [160, 30], [188, 44], [200, 80], [212, 108], [98, 70], [120, 110], [150, 96], [170, 130], [72, 130], [52, 96]]:
				stand.call(float(p[0]), float(p[1]))
			stand.call(150.0, 96.0)
			field_camps.wake_camp("tree_camp")
			field_camps.tick(0.016)
		"nether":
			stand.call(96.0, 74.0)
			player.set("bot", false)
			player.set_physics_process(true)
			nether.enter()
			nether.projection.global_position = level.to_global(_zone.to_local(99.0, 68.0))
			nether.projection.set("hp_max", 1.0e6)            # the screenshot is of the place, not of a fight
			nether.projection.set("hp", 1.0e6)
			nether.projection.set("input_blocked", true)
			_cam_zoom_target = 0.25
			cam_zoom = 0.25
		"lineup":
			# every beast in a row beside you, standing still, at the game's camera
			stand.call(140.0, 50.0)
			var i: int = 0
			for kind: String in ["chaff_wren", "kettle_beetle", "gleaner", "ditch_hound", "sod_lurker", "burr_hog", "wirehorn", "thornback"]:
				var e: Node3D = _spawn_shot_beast(kind, Vector3(-7.0 + 2.1 * float(i), 0, -3.0 - 0.6 * float(i)))
				e.set("target", null)
				e.set("calm", false)
				e.set("buried", false)
				if kind == "sod_lurker":
					e.call("rise")
					e.set("_rise_t", -1.0)
					((e.get("_rig")) as Node3D).position.y = 0.0
				i += 1
			_cam_zoom_target = 0.35
			cam_zoom = 0.35
		"swallow":
			stand.call(169.0, 142.0)
		"cellar":
			stand.call(69.0, 137.0)
		"herd":
			stand.call(119.0, 131.0)
			player.set("_facing", Vector3(0, 0, 1))
			go = func() -> void: field_camps.wake_camp("the_herd")
			_cam_zoom_target = 0.2
			cam_zoom = 0.2
			until = func() -> bool:
				for n: Node in field_camps.members_of("the_herd"):
					if str(n.get("_special")) == "charge" and float(n.get("_windup")) < 0.4:
						return true
				return false
		"lurker":
			stand.call(128.6, 72.0)
			player.set("bot", false)
			go = func() -> void:
				stand.call(128.8, 79.2)
				player.set_physics_process(true)
			until = func() -> bool:
				for p: Dictionary in field_camps.patches:
					var l: Node = p["lurker"]
					if l != null and is_instance_valid(l) and bool(l.call("is_rising")) and float(l.get("_rise_t")) < 0.3:
						return true
				return false
		"gleaner":
			stand.call(112.0, 36.0)
			go = func() -> void:
				stand.call(108.0, 53.0)
				field_camps.tick(0.016)
			_cam_zoom_target = 0.15
			cam_zoom = 0.15
			var gl_frames: Array = [0]
			until = func() -> bool:
				var g: Node = near_kind.call("gleaner")
				gl_frames[0] = int(gl_frames[0]) + 1
				return g != null and bool(g.call("is_running")) and int(gl_frames[0]) > 45
		"scald":
			stand.call(140.0, 50.0)
			var at: Array = [0]
			go = func() -> void:
				var b: Node3D = _spawn_shot_beast("kettle_beetle", Vector3(1.5, 0, -1.0))
				b.call("take_hit", 99999.0, false, null)
			until = func() -> bool:
				at[0] = int(at[0]) + 1
				return int(at[0]) > 25
		_:
			if not what.begins_with("fight-"):
				return false
			var kind: String = what.trim_prefix("fight-")
			stand.call(140.0, 50.0)
			player.set("_facing", Vector3(0, 0, -1))
			var offs: Array = [Vector3(0, 0, -5)]
			if kind == "chaff_wren":
				offs = [Vector3(-2, 0, -5), Vector3(2, 0, -5), Vector3(0, 0, -6), Vector3(3, 0, -3)]
			elif kind == "ditch_hound":
				offs = [Vector3(-3, 0, -4), Vector3(3, 0, -4)]
			elif kind == "burr_hog" or kind == "thornback":
				offs = [Vector3(0, 0, -9)]
			elif kind == "wirehorn":
				offs = [Vector3(0, 0, -1.9)]
			var made: Array = []
			go = func() -> void:
				for o: Vector3 in offs:
					var e: Node3D = _spawn_shot_beast(kind, o)
					made.append(e)
					if e.has_method("provoke"):
						e.call("provoke", player)
					if kind == "wirehorn":
						e.set("facing", Vector3(0, 0, -1))   # its back to you: the kick
			until = func() -> bool:
				for e2: Node in made:
					if not is_instance_valid(e2):
						continue
					if kind == "burr_hog" or kind == "thornback":
						if str(e2.get("_special")) == "charge" and float(e2.get("_windup")) < 0.6:
							return true
					elif kind == "ditch_hound":
						if float(e2.get("_windup")) >= 0.0 and bool(e2.call("is_at_targets_back")):
							return true
					elif kind == "wirehorn":
						if bool(e2.get("_kick")) and float(e2.get("_windup")) >= 0.0 and float(e2.get("_windup")) < 0.2:
							return true
					elif float(e2.get("_windup")) >= 0.0 and float(e2.get("_windup")) < 0.25:
						return true
				return false
	var watch := ShotWatch.new()
	watch.main_node = self
	watch.until = until
	watch.go = go
	watch.cam = cam_shot
	watch.settle = 420 if OS.get_cmdline_user_args().has("--settle") else 90
	add_child(watch)
	return true


## A camera a shot holds fixed (the overview), or null.
var cam_shot: Variant = null


## A beast for a screenshot, `offset` metres from the player (level frame), awake.
func _spawn_shot_beast(kind: String, offset: Vector3) -> Node3D:
	var e: CharacterBody3D = Beast.new()
	e.call("setup", kind, player, 0.8)
	e.position = level.to_local(player.global_position) + offset
	level.add_child(e)
	return e


## Text pinned to world points, for the overview shot.
class ShotLabels extends Control:
	var items: Array = []
	var camera: Camera3D

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		for it: Array in items:
			var p: Vector2 = camera.unproject_position(it[0])
			draw_circle(p, 5.0, Color(0, 0, 0, 0.8))
			draw_circle(p, 3.5, it[2])
			UiDraw.outlined(self, p + Vector2(8, 5), str(it[1]), 15, it[2])


## Waits (in frames) for a screenshot's moment, then takes it. At most `left` frames.
class ShotWatch extends Node:
	var main_node: Node
	var until: Callable
	var go: Callable
	var cam: Variant = null
	var settle := 90
	var left := 1500
	var _armed := -1

	func _process(_delta: float) -> void:
		if cam is Transform3D:
			(main_node.get("camera") as Camera3D).global_transform = cam
		settle -= 1
		left -= 1
		if settle == 0 and go.is_valid():
			go.call()
			return
		if _armed > 0:
			_armed -= 1
			if _armed == 0:
				main_node.call("_save_shot")
			return
		if settle <= 0 and (left <= 0 or bool(until.call())):
			_armed = 2


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


func enter_arena() -> void:
	_show_screen(null, false)
	_enter_arena()


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
	var data: Dictionary = player.call("to_save")
	data["day"] = day
	data["delves"] = delves
	data["hardcore"] = hardcore
	data["place"] = _place_for_save()
	var ok: bool = SaveGame.write(data, SaveGame.slot_path(slot))
	if slot > 0:
		player.call("note", "Saved to slot %d." % slot if ok else "Could not write slot %d." % slot)
	return ok


## Load the autosave into town. Returns false if there is nothing usable to load.
func continue_game() -> bool:
	return load_slot(0)


## Load a slot into town; the loaded character becomes the autosave too.
func load_slot(slot: int) -> bool:
	var data: Dictionary = SaveGame.read(SaveGame.slot_path(slot))
	if data.is_empty() or str(data.get("talent_id", "")) == "":
		return false
	player.call("from_save", data)
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


# --- practice arena -------------------------------------------------------------

func _enter_arena() -> void:
	_new_level(0.0)
	var bcfg: Dictionary = GameData.balance["biomes"]
	_use_biome(bcfg["arena"])
	var span: float = arena_half * 2.0 + 2.0
	_biome_floor(Vector3.ZERO, Vector2(span, span))
	# tall on the far sides, low on the camera's side so the floor is not hidden
	_biome_wall(Vector3(0, 0, -arena_half - 0.5), span, 0.0, float(bcfg["wall_height_far"]))
	_biome_wall(Vector3(-arena_half - 0.5, 0, 0), span, 90.0, float(bcfg["wall_height_far"]))
	_biome_wall(Vector3(0, 0, arena_half + 0.5), span, 180.0, float(bcfg["wall_height_near"]))
	_biome_wall(Vector3(arena_half + 0.5, 0, 0), span, -90.0, float(bcfg["wall_height_near"]))
	_scatter_props(Vector3.ZERO, Vector2(arena_half - 0.5, arena_half - 1.5), int(bcfg["arena_props"]))
	# standing blocks: something for a shove to end against, and for a beam to stop on (design/05 6.2)
	var block: Array = GameData.balance["arena"]["block_size"]
	for at: Array in GameData.balance["arena"]["blocks"]:
		_static_box(Vector3(float(at[0]), float(block[1]) * 0.5, float(at[1])), Vector3(float(block[0]), float(block[1]), float(block[2])),
			(_biome.get("wall_color", Color(0.3, 0.3, 0.33)) as Color).lightened(0.12))
	for i: int in GameData.inum("arena", "scenery_count"):
		var pos := Vector3.ZERO
		for attempt: int in 8:
			pos = Vector3(rng.randf_range(-arena_half + 1.5, arena_half - 1.5), 0.0, rng.randf_range(-arena_half + 1.5, arena_half - 1.5))
			if pos.length() > 3.0:
				break
		_spawn_cuttable(0 if i % GameData.inum("arena", "bush_every_n") == 0 else i * 2 + 2, pos)
	for q: Vector3 in [Vector3(-8, 0, -8), Vector3(8, 0, -8), Vector3(-8, 0, 8), Vector3(8, 0, 8)]:
		nether.populate_site(q, Vector2(6.0, 6.0))
	player.global_position = Vector3.ZERO
	player.set("active", true)
	_place_corpses("arena")
	wave = 0
	rest_timer = GameData.num("arena", "first_rest")
	state = "arena_rest"


func _start_wave() -> void:
	wave += 1
	state = "arena_fight"
	hud.call("announce", "WAVE %d" % wave)
	player.call("start_fight")
	for i: int in GameData.inum("arena", "grunts_base") + wave:
		_spawn_arena_enemy("grunt")
	for i: int in wave / GameData.inum("arena", "brute_every_n_waves"):
		_spawn_arena_enemy("brute")
	for i: int in wave / GameData.inum("arena", "archer_every_n_waves"):
		_spawn_arena_enemy("archer")
	for i: int in wave / GameData.inum("arena", "harrier_every_n_waves"):
		_spawn_arena_enemy("harrier")
	for i: int in wave / GameData.inum("arena", "pavise_every_n_waves"):
		_spawn_arena_enemy("pavise")
	# one problem per pack: never more than one of each
	if wave >= GameData.inum("arena", "censer_from_wave") and wave % 2 == 1:
		_spawn_arena_enemy("censer")
	if wave >= GameData.inum("arena", "drummer_from_wave"):
		_spawn_arena_enemy("drummer")


func _spawn_arena_enemy(kind: String) -> void:
	var angle: float = rng.randf() * TAU
	_spawn_enemy(kind, Vector3(cos(angle), 0.0, sin(angle)) * (arena_half - 3.0), 1.0)


# --- assault passage ------------------------------------------------------------

func _enter_dungeon() -> void:
	# Rotated so the corridor runs straight "up" the isometric screen: W alone walks it.
	_new_level(45.0)
	var total: float = float(chambers + 1) * ch_len
	var mid_z: float = -total * 0.5
	var bcfg: Dictionary = GameData.balance["biomes"]
	_use_biome(bcfg["passage"])
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
		_scatter_props(Vector3(0, 0, near_z - ch_len * 0.5), Vector2(ch_half_w - 0.3, ch_len * 0.5 - 1.2), int(bcfg["props_per_chamber"]), [near_z, near_z - ch_len])
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
	_place_corpses("passage")
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
		if _bot_scenario == "die" and cleared >= 2 and not _bot_died:
			# Kill the character outright to exercise the live death -> debt -> town path.
			_bot_money_before = int(player.get("money"))
			(player.get("body") as Body).apply_damage(99999.0)
			player.call("_check_death")
			return
		var leave_now: bool = _bot_scenario == "gate" or cleared >= chambers
		if leave_now and _pad_in_reach():
			_extract()
			return
		# the bot paths there itself (player._bot_way): no lining up with the doorway first
		var goal_local: Vector3
		if leave_now and not pads.is_empty():
			goal_local = level.to_local(pads.back().global_position)
		else:
			goal_local = Vector3(0.0, 0.0, -(float(cleared + 1) * ch_len + 4.0))
		player.set("bot_goal", level.to_global(goal_local))


func _activate(c: int) -> void:
	current = c
	var strength: float = late_strength if c > gate_at else 1.0
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
	for kind: String in kinds:
		# archers start at the back of the chamber, where a back line belongs
		var back: bool = str(GameData.enemy(kind).get("behaviour", "melee")) == "ranged"
		var local := Vector3(rng.randf_range(-ch_half_w + 2.0, ch_half_w - 2.0), 0.0,
			rng.randf_range(-float(c + 1) * ch_len + 2.0, -float(c + 1) * ch_len + 4.0) if back
			else rng.randf_range(-float(c + 1) * ch_len + 2.0, -float(c) * ch_len - 7.0))
		_spawn_enemy(kind, local, strength)
	player.call("start_fight")
	player.call("note", "Wall %d of %d." % [c, chambers])
	hud.call("announce", "WALL %d" % c if c != chambers else "THE LAST WALL")
	if _shot_dungeon and c == 2:
		Engine.time_scale = 1.0
		player.set("bot", false)
		_shot_countdown = 25


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


func _spawn_enemy(kind: String, local_pos: Vector3, strength: float) -> void:
	# Build and place before it enters the tree: a body that exists at the origin for even one
	# step can pick the player up as a "moving platform" passenger.
	var e: CharacterBody3D = EnemyScript.new()
	e.call("setup", kind, player, strength)
	e.position = local_pos
	level.add_child(e)
	e.connect("reinforcements", _on_reinforcements)


## An enemy called for help: the kinds it named arrive in a ring round it, inside the room.
func _on_reinforcements(who: Node, kinds: Array) -> void:
	if level == null or not is_instance_valid(who):
		return
	var centre: Vector3 = level.to_local((who as Node3D).global_position)
	var strength: float = late_strength if (state == "dungeon" and current > gate_at) else 1.0
	for i: int in kinds.size():
		var angle: float = TAU * float(i) / float(maxi(1, kinds.size())) + 0.6
		var spot: Vector3 = centre + Vector3(cos(angle), 0.0, sin(angle)) * 3.5
		if state == "dungeon":
			spot.x = clampf(spot.x, -ch_half_w + 1.5, ch_half_w - 1.5)
			spot.z = clampf(spot.z, -float(current + 1) * ch_len + 1.5, -float(current) * ch_len - 1.5)
		else:
			spot.x = clampf(spot.x, -arena_half + 2.0, arena_half - 2.0)
			spot.z = clampf(spot.z, -arena_half + 2.0, arena_half - 2.0)
		_spawn_enemy(str(kinds[i]), spot, strength)
	hud.call("announce", "REINFORCEMENTS")


func _spawn_scenery(kind: String, local_pos: Vector3) -> void:
	var s: Node3D = SceneryScript.new()
	s.call("setup", kind)
	s.position = local_pos
	level.add_child(s)


func _on_player_died() -> void:
	if hardcore:
		state = "dead"
		if not _bot_mode and not _test_mode:
			SaveGame.delete()
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


## Your corpses that lie in this kind of level, laid back where they fell.
func _place_corpses(where: String) -> void:
	var CorpseScript: GDScript = load("res://scripts/corpse.gd")
	for c: Dictionary in player.get("corpses"):
		if str(c.get("where", "")) != where:
			continue
		var pos: Array = c.get("pos", [0.0, 0.0, 0.0])
		var body_node: Node3D = CorpseScript.new()
		body_node.call("setup", str(c["id"]), player.get("look"))
		body_node.position = Vector3(float(pos[0]), 0.0, float(pos[2]))
		level.add_child(body_node)


func _new_level(yaw_degrees: float) -> void:
	if player != null:
		player.call("drop_stones")           # stone does not follow you to a new place
		for group: String in ["ground_zones", "ground_rods", "blasts", "censer_bursts"]:
			for left: Node in get_tree().get_nodes_in_group(group):
				left.queue_free()
	if level != null:
		for group: String in ["enemies", "hittable"]:
			for n: Node in get_tree().get_nodes_in_group(group):
				if level.is_ancestor_of(n):
					n.remove_from_group(group)
		level.queue_free()
	level = Node3D.new()
	level.rotation_degrees = Vector3(0.0, yaw_degrees, 0.0)
	add_child(level)
	# the spirit layer shares the level's frame, so its sites line up with the chambers
	nether.clear()
	nether.rotation_degrees = Vector3(0.0, yaw_degrees, 0.0)
	sealed = false
	current = 0
	cleared = 0
	bank = 0
	barriers.clear()
	gates.clear()
	pads.clear()
	_rent_accum = 0.0
	_add_level_nav()


## Pathfinding for the level about to be built: a LevelNav at the level's origin bakes its
## navigation meshes from the colliders once the building is done (the frame after), and again
## whenever a collider is added or taken away (a doorway sealed or opened). See LevelNav.
func _add_level_nav() -> void:
	var nav := LevelNav.new()
	nav.name = "Nav"
	level.add_child(nav)


## The town is a level (design/08): data/town.json built by TownBuilder - streets, gateways and
## the people who do what the old town menu did.
func _build_town() -> void:
	_new_level(0.0)
	var cfg: Dictionary = GameData.balance["biomes"]
	_use_biome(cfg["town"], false)            # the town is always the town
	_town = TownBuilder.new(self, GameData.town)
	_town.build()


# --- biomes -------------------------------------------------------------------------------

## Set the level's biome: one of `choices` at random, unless one is forced.
func _use_biome(choices: Variant, allow_force: bool = true) -> void:
	var pool: Array = choices if choices is Array else [choices]
	biome = str(pool[rng.randi() % pool.size()])
	if allow_force and forced_biome != "" and Biomes.ids().has(forced_biome):
		biome = forced_biome
	if not Biomes.ids().has(biome):
		biome = "scrubland"
	_biome = Biomes.info(biome)
	_set_nether_look(nether.active)


## Ground: something to stand on, and the biome's floor drawn over it.
func _biome_floor(centre: Vector3, size: Vector2) -> void:
	_static_box(Vector3(centre.x, -0.5, centre.z), Vector3(size.x, 1.0, size.y), Color.BLACK, false)
	var ground: Node3D = Biomes.floor(biome, size)
	ground.position = Vector3(centre.x, 0.0, centre.z)
	level.add_child(ground)


## A wall run `length` long centred on `centre`, facing into the level along +Z turned by `yaw`
## degrees. Returns its collider.
func _biome_wall(centre: Vector3, length: float, yaw: float, height: float) -> StaticBody3D:
	var sb: StaticBody3D = _static_box(Vector3(centre.x, 1.0, centre.z), Vector3(length, 2.0, 1.0), Color.BLACK, false)
	sb.rotation_degrees.y = yaw
	var wall: Node3D = Biomes.wall(biome, length, height)
	wall.position = Vector3(centre.x, 0.0, centre.z)
	wall.rotation_degrees.y = yaw
	level.add_child(wall)
	return sb


## Scatter `count` decorative props over a patch `half` metres each way from `centre`. Props
## that block are kept to the strips along x = +-half.x; `keep_clear` (local z values) are lines
## nothing may stand near, such as a doorway.
func _scatter_props(centre: Vector3, half: Vector2, count: int, keep_clear: Array = []) -> void:
	var cfg: Dictionary = GameData.balance["biomes"]
	var table: Array = _biome.get("scatter", [])
	if table.is_empty():
		return
	var total := 0.0
	for e: Dictionary in table:
		total += float(e["weight"])
	var lights_left: int = int(cfg["lights_per_chamber"])
	var placed_blockers: Array = []        # [side, z, radius] - kept apart so they never form a pocket
	for i: int in count:
		var roll: float = rng.randf() * total
		var kind: String = str((table[0] as Dictionary)["kind"])
		for e: Dictionary in table:
			roll -= float(e["weight"])
			if roll < 0.0:
				kind = str(e["kind"])
				break
		var meta: Dictionary = Biomes.prop_meta(biome, kind)
		if bool(meta.get("cuttable", false)):
			continue                                # those are placed as hittable scenery instead
		if bool(meta.get("light", false)):
			if lights_left <= 0:
				continue
			lights_left -= 1
		var r: float = float(meta.get("radius", 0.5))
		var blocks: bool = bool(meta.get("blocks", false))
		var pos := Vector3.ZERO
		var ok := false
		var solid: float = minf(r, float(cfg["blocker_collider_max"]))    # how much of it actually stops you
		var side := 1.0
		for attempt: int in 6:
			var x: float
			if blocks:
				# hard against a side wall, like a feature of the wall: nothing can get behind it
				side = 1.0 if rng.randf() < 0.5 else -1.0
				x = side * (half.x - solid * 0.5)
			else:
				x = rng.randf_range(-half.x + r, half.x - r)
			pos = centre + Vector3(x, 0.0, rng.randf_range(-half.y + r, half.y - r))
			ok = true
			for line: Variant in keep_clear:
				if absf(pos.z - float(line)) < r + 1.6:
					ok = false
			if blocks:
				for other: Array in placed_blockers:
					if float(other[0]) == side and absf(pos.z - float(other[1])) < solid + float(other[2]) + float(cfg["blocker_gap"]):
						ok = false
			if ok:
				break
		if not ok:
			continue
		if blocks:
			placed_blockers.append([side, pos.z, solid])
		var prop: Node3D = Biomes.prop(biome, kind)
		prop.position = pos
		prop.rotation.y = rng.randf() * TAU
		level.add_child(prop)
		if blocks:
			var sb := StaticBody3D.new()
			var col := CollisionShape3D.new()
			var shape := CylinderShape3D.new()
			shape.radius = solid
			shape.height = 2.0
			col.shape = shape
			sb.add_child(col)
			sb.position = pos + Vector3.UP
			level.add_child(sb)


## Things you can cut down: the old grass and bushes in scrubland, the kit's own cuttables elsewhere.
func _spawn_cuttable(index: int, local_pos: Vector3) -> void:
	if biome == "scrubland":
		_spawn_scenery("bush" if index == 0 else "grass", local_pos)
		return
	var kinds: Array = []
	for kind: Variant in _biome.get("props", []):
		if bool(Biomes.prop_meta(biome, str(kind)).get("cuttable", false)):
			kinds.append(str(kind))
	if kinds.is_empty() or index % 2 == 1:           # fewer than grass: these are bigger things
		return
	var s: Node3D = SceneryScript.new()
	s.call("setup_prop", biome, str(kinds[rng.randi() % kinds.size()]))
	s.position = local_pos
	level.add_child(s)


func _static_box(pos: Vector3, size: Vector3, color: Color, show: bool = true) -> StaticBody3D:
	var sb := StaticBody3D.new()
	if show:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		mesh.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mesh.material_override = mat
		sb.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	sb.add_child(col)
	sb.position = pos
	level.add_child(sb)
	return sb


# --- construction ---------------------------------------------------------------

func _build_world() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Grim, low-key look (art pass 3): filmic, a little haze, contact shadows, restrained bloom.
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 1.15
	# light bounced off the ground and walls into the shade, so shadows are not flat black
	_env.ssil_enabled = true
	_env.ssil_radius = 4.0
	_env.ssil_intensity = 0.8
	_env.ssao_enabled = true
	_env.ssao_radius = 0.8
	_env.ssao_intensity = 1.5
	_env.glow_enabled = true
	_env.glow_intensity = 0.6
	_env.glow_bloom = 0.03
	_env.glow_hdr_threshold = 1.0
	_env.fog_enabled = true
	_env.fog_density = 0.006
	_env.adjustment_enabled = true
	_env.adjustment_contrast = 1.08
	_env.adjustment_saturation = 0.92
	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-44.0, 38.0, 0.0)
	_sun.shadow_enabled = true
	add_child(_sun)
	_set_nether_look(false)

	nether = Netherecho.new()
	add_child(nether)
	nether.connect("entered", _on_nether_entered)
	nether.connect("exited", _on_nether_exited)
	nether.connect("projection_destroyed", _on_projection_destroyed)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.size = GameData.num("camera", "ortho_size")
	camera.far = 300.0
	camera.near = 0.1
	_cam_zoom_target = GameSettings.zoom_start() if _plays() else GameData.num("camera", "zoom_default")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--zoom="):              # screenshots at a chosen zoom
			_cam_zoom_target = clampf(float(arg.get_slice("=", 1)), 0.0, 1.0)
	cam_zoom = _cam_zoom_target
	add_child(camera)
	camera.current = true


func _build_player() -> void:
	player = PlayerScript.new()
	add_child(player)
	player.global_position = Vector3.ZERO
	player.connect("died", _on_player_died)
	player.connect("disturbed", _on_body_disturbed)
	player.connect("rune_discovered", _on_rune_discovered)
	player.connect("ascended", _on_ascended)
	nether.player = player


## The ascension shots: "ascend-offer" (step 1), "ascend-boost" (step 2, an affinity chosen, one
## skill set to Reach), "ascend-ethercosm" (settled; the boosted skill selected in the ethercosm).
func _shot_ascension(which: String) -> void:
	_select_talent(0)
	player.call("set_affinities", ["fire"])
	var abilities: Array = player.get("abilities")
	if abilities.size() < 4:
		for id: String in GameData.skill_tree_of("fire"):
			if abilities.size() >= 4:
				break
			player.call("learn", id)
	var stages: Array[int] = [2, 1, 1, 0]
	for i: int in mini(stages.size(), abilities.size()):
		(abilities[i] as Dictionary)["stage"] = stages[i]
	(player.get("rng") as RandomNumberGenerator).seed = 20261024
	_enter_town()
	player.call("grow_star", 99.0)
	player.set("_latent_aura", 100000.0)
	player.call("try_ascend")                  # opens the ascension screen (_on_ascended)
	get_tree().paused = false                  # it pauses; the shot countdown has to tick
	if which == "ascend-offer":
		return
	var offer: Array = (player.get("ascension_pending") as Dictionary).get("offer", [])
	screen.call("choose", str(offer[0]) if not offer.is_empty() else "")
	screen.call("set_aspect", 1, "reach")
	if which == "ascend-boost":
		return
	screen.call("confirm")
	open_ethercosm()
	screen.call("select", 1)


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
			return "Practice arena  -  wave %d" % wave
		"dungeon":
			return "The passage  -  wall %d of %d  -  spoils $%d" % [cleared, chambers, bank]
		"field":
			return str(GameData.zone(zone_id).get("name", zone_id))
	return ""


# --- test harness ---------------------------------------------------------------

## The game menu's screenshots (--shot-ui=menu-...): the menu in town and in the field (Save
## disabled out there), the new game view with the test characters, Load and Save (from a folder
## of shot saves, never the real ones), Settings, the question before leaving a real character, and
## the menu over a test character.
func _setup_menu_shot(which: String) -> void:
	player.set("char_name", "Maren")
	SaveGame.test_dir = "user://shot_saves/"
	save_to_slot(0)                         # an autosave and slot 2, so Load has something to list
	save_to_slot(2)
	if which == "menu-field":
		walk_out()
	elif which == "menu-test":
		start_test_character("fire")
	else:
		_enter_town()
	match which:
		"menu-new":
			open_game_menu("new")
		"menu-settings":
			open_game_menu("settings")
		"menu-load", "menu-save":
			open_game_menu()
			menu_open_saves(which.trim_prefix("menu-"))
		"menu-confirm":
			open_game_menu()
			(screen as UiScreen).confirm_leave("Quit to title", quit_to_title)
		_:
			open_game_menu()
	get_tree().paused = false               # the menu pauses; the shot countdown has to tick


## Put the game into a named UI state with representative data, then screenshot it.
## States: title, town, shop, inventory, inventory-abilities, hud (mid-fight, hurt), hud-low (near death, reflux locked).
func _setup_ui_shot(which: String) -> void:
	_shot_mode = true
	_frames = 1000                      # disable the arena auto-shot; _shot_countdown drives this one
	_shot_countdown = 40
	if which == "title":
		return
	if which == "enemies4":
		# the step 4 kinds together: a shield pair, a censer, a drummer behind them, the commander mid-sweep
		forced_biome = "scrubland"
		_select_talent(0)
		_show_screen(null, false)
		enter_arena()
		rest_timer = 9999.0
		for spec: Array in [[Vector3(-1.6, 0, -3.5), "pavise"], [Vector3(-0.2, 0, -3.9), "pavise"], [Vector3(2.4, 0, -5.5), "censer"],
				[Vector3(-3.0, 0, -8.5), "drummer"], [Vector3(-4.0, 0, -4.5), "grunt"], [Vector3(4.5, 0, -1.5), "commander"]]:
			_spawn_enemy(str(spec[1]), spec[0], 1.0)
		for e: Node in get_tree().get_nodes_in_group("enemies"):
			if str(e.get("kind")) == "grunt":
				e.call("add_status", "roused")
				e.call("add_status", "frenzied")
			if str(e.get("kind")) == "commander":
				var aim: Vector3 = ((player.global_position - (e as Node3D).global_position) * Vector3(1, 0, 1)).normalized()
				e.set("facing", aim)
				e.set("telegraph", {"kind": "cone", "radius": 6.0, "arc_deg": 90.0, "dir": aim, "frac": 0.6})
				e.call("_apply_facing")
			e.set_physics_process(false)
		player.set_physics_process(false)
		return
	if which.begins_with("test-"):
		_setup_test_shot(which.trim_prefix("test-"))
		return
	if which.begins_with("role-"):
		_setup_role_shot(which.trim_prefix("role-"))
		return
	if which.begins_with("seal-"):
		_setup_seal_shot(which)
		return
	if which == "icons":
		# every skill's glyph in a slot, by affinity, with its name
		var sheet := Control.new()
		sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
		sheet.draw.connect(func() -> void:
			sheet.draw_rect(Rect2(Vector2.ZERO, sheet.size), Color(0.08, 0.08, 0.1))
			var row := 0
			for aff: Variant in GameData.affinity_ids():
				var col := 0
				UiDraw.text(sheet, Vector2(40.0, 96.0 + row * 150.0), str(GameData.affinity(str(aff)).get("label", aff)), 22, GameData.affinity_color(str(aff)).lightened(0.3))
				for id: Variant in GameData.abilities.keys():
					var ab: Dictionary = GameData.ability(str(id))
					if str(ab.get("affinity", "")) != str(aff):
						continue
					var slot := Rect2(150.0 + col * 206.0, 60.0 + row * 150.0, 84.0, 84.0)
					sheet.draw_rect(slot, UiTheme.INSET)
					sheet.draw_rect(slot, UiTheme.BRONZE_DIM, false, 2.0)
					sheet.draw_line(Vector2(slot.get_center().x, slot.position.y), Vector2(slot.get_center().x, slot.end.y), Color(1, 1, 1, 0.08), 1.0)
					sheet.draw_line(Vector2(slot.position.x, slot.get_center().y), Vector2(slot.end.x, slot.get_center().y), Color(1, 1, 1, 0.08), 1.0)
					UiDraw.icon(sheet, str(ab.get("icon", "drop")), slot.get_center(), 42.0, GameData.affinity_color(str(aff)).lightened(0.3))
					UiDraw.text(sheet, Vector2(slot.position.x, slot.end.y + 18.0), str(ab.get("name", id)), 14, UiTheme.TEXT)
					UiDraw.text(sheet, Vector2(slot.position.x, slot.end.y + 34.0), str(ab.get("kind", "")), 11, UiTheme.TEXT_DIM)
					col += 1
				row += 1)
		var layer := CanvasLayer.new()
		layer.layer = 100
		add_child(layer)
		layer.add_child(sheet)
		return
	if which == "props":
		# every real model in a row on bare ground, for looking at them up close
		_select_talent(0)
		walk_out()
		for n: Node in level.get_children():
			if n is MeshInstance3D or (n is Node3D and n.get_child_count() > 0 and not (n is StaticBody3D)):
				pass
		var spot: Vector3 = _zone.to_local(120.0, 150.0)
		player.global_position = level.to_global(spot)
		var ids: PackedStringArray = DirAccess.get_files_at("res://assets/models/props/")
		var i := 0
		for f: String in ids:
			if not f.ends_with(".glb"):
				continue
			var id: String = f.get_basename()
			var node: Node3D = RealProps.model(id, 1.0)
			node.position = spot + Vector3(-7.5 + float(i % 6) * 3.0, 0.0, -6.0 + float(i / 6) * 3.4)
			level.add_child(node)
			i += 1
		camera.size = 26.0 if not OS.get_cmdline_user_args().has("--close") else 9.0
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		_cam_debug = true
		player.set_physics_process(false)
		return
	if which.begins_with("stubble-") and _setup_stubble_shot(which):
		return
	if which == "stubble" or which == "stubble-cut":
		# out of the Dross Gate, a little way down the road: the tip, the wall behind, the field ahead
		_select_talent(0)
		player.set("look", CharacterLook.default_look())
		walk_out()
		player.global_position = level.to_global(_zone.to_local(56.0, 30.0) if which == "stubble" else _zone.to_local(214.0, 108.0))
		if OS.get_cmdline_user_args().has("--settle"):
			_shot_countdown = 420             # long enough for shaders to compile, so the frame rate means something
		player.set("_facing", Vector3(0, 0, 1))
		player.set_physics_process(false)
		return
	if which == "earth":
		# an earth character set for a blow, two of their stones standing
		forced_biome = "scrubland"
		_select_talent(0)
		player.call("set_affinities", ["earth"])
		player.call("grow_star", 70.0)
		player.set("essence", 50.0)
		_show_screen(null, false)
		enter_arena()
		rest_timer = 9999.0
		for spec: Array in [[Vector3(-1.5, 0, -5.5), "grunt"], [Vector3(1.2, 0, -6.0), "grunt"], [Vector3(5.5, 0, -3.5), "archer"]]:
			_spawn_enemy(str(spec[1]), spec[0], 1.0)
		var slab_def: Dictionary = GameData.ability("raise_slab")
		for spot: Array in [[Vector3(0, 0, -3.0), Vector3(0, 0, -1)], [Vector3(3.4, 0, -1.6), Vector3(1, 0, -0.5)]]:
			var stone: Node = player.call("raise_stone", player.global_position + (spot[0] as Vector3), spot[1], slab_def)
			stone.call("tick", 0.6)
			stone.set_physics_process(false)
		player.set("_facing", Vector3(0, 0, -1))
		player.set("_windup", {"braced": true, "release": false, "facing": Vector3(0, 0, -1)})
		player.set("_windup_t", 0.25)
		player.set("_windup_total", 0.6)
		for e: Node in get_tree().get_nodes_in_group("enemies"):
			e.set_physics_process(false)
		player.rotation.y = 0.0
		player.set_physics_process(false)
		player.call("_refresh_highlights")
		return
	if which == "wind":
		# a wind character on the move: pips over the bar, an enemy thrown aloft
		forced_biome = "scrubland"
		_select_talent(0)
		player.call("set_affinities", ["wind"])
		player.call("grow_star", 70.0)
		player.set("essence", 50.0)
		_show_screen(null, false)
		enter_arena()
		rest_timer = 9999.0
		player.set("pips", 7)
		for spec: Array in [[Vector3(-2.5, 0, -3.0), "grunt"], [Vector3(1.0, 0, -4.0), "grunt"], [Vector3(3.5, 0, -1.5), "archer"]]:
			_spawn_enemy(str(spec[1]), spec[0], 1.0)
		var foes: Array = get_tree().get_nodes_in_group("enemies")
		foes[0].call("add_status", "aloft")
		player.set("hovered", foes[1])
		for e: Node in foes:
			e.set_physics_process(false)
		player.set_physics_process(false)
		player.call("_refresh_highlights")
		return
	if which == "fire":
		# a fire character running hot: burning enemies, a flame trail, the heat readout
		forced_biome = "scrubland"
		_select_talent(0)
		player.call("set_affinities", ["fire"])
		player.call("grow_star", 70.0)
		player.set("essence", 50.0)
		_show_screen(null, false)
		enter_arena()
		rest_timer = 9999.0
		(player.get("reflux_by") as Dictionary)["fire"] = 72.0
		for spec: Array in [[Vector3(-2.0, 0, -3.0), "grunt"], [Vector3(-0.6, 0, -3.4), "grunt"], [Vector3(3.0, 0, -2.0), "brute"]]:
			_spawn_enemy(str(spec[1]), spec[0], 1.0)
		var foes: Array = get_tree().get_nodes_in_group("enemies")
		foes[0].call("add_status", "alight", 4, player)
		foes[1].call("add_status", "alight", 1, player)
		foes[2].call("add_status", "alight", 2, player)
		var trail := GroundZone.new()
		trail.from = player.global_position + Vector3(0, 0, 4.2)
		trail.to = player.global_position
		trail.life = 99.0
		trail.color = GameData.affinity_color("fire")
		level.add_child(trail)
		trail.set_physics_process(false)
		player.set("hovered", foes[0])
		# no tooltip here: it would sit on top of the heat readout this picture exists to show
		for e: Node in foes:
			e.set_physics_process(false)
		player.set_physics_process(false)
		player.call("_refresh_highlights")
		return
	if which == "combat":
		# the combat rules on one screen: a brute mid-slam, an archer aiming, a staggered grunt,
		# a crouched harrier, and a second rank waiting for a slot
		forced_biome = "scrubland"
		_select_talent(0)
		player.call("grow_star", 70.0)
		_show_screen(null, false)
		enter_arena()
		rest_timer = 9999.0
		for spec: Array in [[Vector3(2.6, 0, -1.2), "brute"], [Vector3(-7.0, 0, -8.0), "archer"], [Vector3(-2.2, 0, -1.6), "grunt"],
				[Vector3(5.0, 0, 4.5), "harrier"], [Vector3(-4.6, 0, 2.6), "grunt"], [Vector3(0.5, 0, -5.0), "grunt"]]:
			_spawn_enemy(str(spec[1]), spec[0], 1.0)
		var foes: Array = get_tree().get_nodes_in_group("enemies")
		foes[0].set("_windup", 0.45)                       # the slam, most of the way through
		foes[0].call("_update_melee_telegraph")
		foes[0].call("take_poise", 60.0)
		foes[1].set("telegraph", {"kind": "line", "to": player.global_position, "locked": true, "frac": 0.8})
		foes[2].call("stagger", 5.0)
		(foes[2].get("body") as Body).apply_damage(120.0)
		foes[3].set("telegraph", {"kind": "swing", "interruptible": true})
		player.set("hovered", foes[2])
		for e: Node in foes:
			e.set_physics_process(false)
		player.set_physics_process(false)
		player.call("_refresh_highlights")
		return
	if which == "skills":
		# a water + lightning character in the arena: marks, a Soaked enemy, a stunned one, a block
		forced_biome = "scrubland"
		_select_talent(0)
		player.call("set_affinities", ["water", "lightning"])
		player.call("grow_star", 70.0)
		player.set("essence", 60.0)
		_show_screen(null, false)
		enter_arena()
		rest_timer = 9999.0
		for spec: Array in [[Vector3(-3.0, 0, -3.5), "grunt"], [Vector3(0.5, 0, -4.5), "grunt"], [Vector3(3.5, 0, -2.5), "brute"], [Vector3(-1.0, 0, -7.0), "grunt"]]:
			_spawn_enemy(str(spec[1]), spec[0], 1.0)
		var foes: Array = get_tree().get_nodes_in_group("enemies")
		foes[0].call("add_status", "live", 2)
		foes[0].call("add_status", "soaked")
		foes[1].call("add_status", "live", 1)
		foes[2].call("stun", 5.0)
		foes[2].call("add_status", "soaked")
		(foes[1].get("body") as Body).apply_damage(90.0)
		player.set("hovered", foes[0])
		hud.set("debug_tip", "slot:3")
		for e: Node in foes:
			e.set_physics_process(false)
		player.set_physics_process(false)
		player.call("_refresh_highlights")
		return
	if which == "nav" or which.begins_with("nav-"):
		# the common walker's navigation mesh drawn over the passage, at the first doorway: --shot-ui=nav-city
		forced_biome = which.trim_prefix("nav-") if which.begins_with("nav-") else "mountain"
		_select_talent(0)
		_show_screen(null, false)
		_enter_dungeon()
		player.global_position = level.to_global(Vector3(0.0, 0.0, -ch_len - 2.0))
		(level.get_node("Nav") as LevelNav).show_debug(true)
		player.set_physics_process(false)
		return
	if which.begins_with("biome-"):
		# the passage in a given biome, two walls in: --shot-ui=biome-snow
		forced_biome = which.trim_prefix("biome-")
		_select_talent(0)
		_show_screen(null, false)
		_enter_dungeon()
		sealed = true
		cleared = 1
		# as it would be after wall 1: the doorway behind you has opened, the one ahead is shut
		(barriers[2] as Node).queue_free()
		barriers.erase(2)
		(gates[2] as Node).call("set_open", true, true)
		player.global_position = level.to_global(Vector3(1.0, 0.0, -2.35 * ch_len))
		_activate(2)
		for e: Node in get_tree().get_nodes_in_group("enemies"):
			e.set_physics_process(false)
		player.set_physics_process(false)
		return
	if which.begins_with("create"):
		# the creation screen at a given step: create-1 .. create-4
		# fixed offers so the picture does not depend on the dice: a common, a rare and a three-slot prime
		screen.set("offers", [{"talent_id": "grudge", "affinities": ["earth"]}, {"talent_id": "tenth_strike", "affinities": ["wind", "fire"]},
			{"talent_id": "one_percent_lifesteal", "affinities": ["water", "lightning", "earth"]}] as Array[Dictionary])
		screen.call("set_spec", {"name": "Maren", "identity": "woman", "look": CharacterLook.default_look(), "talent_id": "tenth_strike", "affinities": ["wind", "fire"],
			"skills": ["cutting_gust", "flashover"]})
		screen.call("_go", int(which.get_slice("-", 1)) - 1)
		if which.ends_with("-face"):
			screen.call("set_zoom", true)
			_shot_countdown = 90                # let the camera ease in
		return
	_select_talent(0)
	var inv: Inventory = player.get("inventory")
	player.set("money", 1840)
	for id: String in ["dim_mote", "river_stone", "serrated_dagger", "invader_cleaver", "brute_tusk", "brute_tusk", "husk_plate", "sinew_cord", "sinew_cord", "commander_sigil", "delver_frame"]:
		inv.add(id)
	inv.equip("dim_mote")
	inv.equip("serrated_dagger")
	player.call("refresh_gear")
	player.call("grow_star", 38.0)
	(player.get("constructs") as Array).append({"tier": "vestige", "concept": "acceleration"})
	(player.get("constructs") as Array).append({"tier": "vestige", "concept": "tension"})
	var abilities: Array = player.get("abilities")
	abilities[0]["progress"] = 100.0
	abilities[1]["progress"] = 64.0
	abilities[2]["progress"] = 23.0
	(player.get("body") as Body).apply_damage(31.0)
	player.set("arm_right", 62.0)
	_last_payout = 3000
	delves = 2
	day = 4
	match which:
		"town":
			_enter_town()
		"town-gate", "town-folk":
			# the north street from inside the Dross Gate, or the west side with the trainer and the passage door
			_enter_town("dross_gate" if which == "town-gate" else "passage")
			if which == "town-folk":
				player.global_position = level.to_global(Vector3(-11.0, 0.0, -1.5))
			player.set("_facing", Vector3(0, 0, -1))
			if OS.get_cmdline_user_args().has("--settle"):
				_shot_countdown = 300
		"stations":
			# the craft row along the south side: rendering block, tanning vats, forge
			_enter_town()
			player.global_position = level.to_global(Vector3(3.0, 0.0, 12.8))
			player.set("_facing", Vector3(0, 0, 1))
			_shot_countdown = 200
		"craft", "craft-done", "craft-item":
			# at the forge with what an iron knuckle needs: before the combine, after it, and the result worn
			_enter_town()
			player.global_position = _town.person("smith").global_position + Vector3(1.4, 0.0, -0.8)
			(player.get("craft_skill") as Dictionary)["smithing"] = 9
			(player.get("craft_known") as Array).append_array(Crafting.recipes_of("smithing"))
			for id: String in ["smiths_hammer", "steel_billet", "steel_billet", "barrow_fitting_mould", "barrow_quench_oil", "cured_hide_grip_wrap", "scrap_iron", "scrap_iron", "flux_salt"]:
				inv.add(id)
			_shot_countdown = 120
			talk_to("smith")
			open_crafting("forge")
			screen.set("selected", "r_iron_knuckles")
			screen.call("rebuild")
			if which != "craft":
				# certain at this skill, so the picture does not depend on the dice
				(player.get("craft_skill") as Dictionary)["smithing"] = 29
				screen.call("combine", "r_iron_knuckles")
			if which == "craft-item":
				close_screen()
				close_screen()
				open_inventory()
				screen.call("show_item", "iron_knuckles", "")
		"town-talk":
			_enter_town()
			player.global_position = _town.person("trainer").global_position + Vector3(1.6, 0.0, 0.5)
			player.set("skill_points", 3)
			_shot_countdown = 120                 # let the trainer turn to face you
			talk_to("trainer")
		"skill-tree", "skill-tree-field":
			# a water + lightning character: two roots picked, one tier-2 learned, points to spend
			player.call("set_affinities", ["water", "lightning"])
			player.call("start_with_skills", ["riptide_lash", "stepped_leader"])
			player.call("learn", "drench")
			player.set("skill_points", 3)
			if which == "skill-tree":
				_enter_town()
				player.global_position = _town.person("trainer").global_position + Vector3(1.6, 0.0, 0.5)
				talk_to("trainer")
				open_skill_tree(true)
			else:
				_show_screen(null, false)
				enter_arena()
				rest_timer = 9999.0
				open_skill_tree(false)
				get_tree().paused = false         # it pauses out here; the shot countdown has to tick
			screen.call("select", "standing_pool")
		"shop":
			_enter_town()
			open_shop()
		"saves":
			_enter_town()
			open_saves()
		"menu-town", "menu-field", "menu-new", "menu-load", "menu-save", "menu-settings", "menu-confirm", "menu-test":
			_setup_menu_shot(which)
		"inventory", "inventory-abilities":
			# some of the new slots filled and some left empty, and a piece in the pack to compare
			for id: String in ["oilcloth_hood", "work_gloves", "chalk_slate", "hobnailed_boots", "cooling_coil"]:
				inv.add(id)
			for id: String in ["oilcloth_hood", "work_gloves", "river_stone", "cooling_coil"]:
				inv.equip(id)
			player.call("refresh_gear")
			_enter_town()
			open_inventory()
			screen.call("show_item", "hobnailed_boots", "")     # the description has its own panel; it covers nothing
			if which == "inventory-abilities":
				_shot_lock_word()                          # its locked word shows on Breaker's row
				screen.set("_tab", "soul")
				screen.call("rebuild")
		"ethercosm", "ethercosm-2":
			if which == "ethercosm-2":
				# a later character: two stars, a bound vestige, a rearranged bar
				player.call("grow_star", 99.0)
				player.set("_latent_aura", 1000.0)
				player.call("try_ascend")
				player.call("grow_star", 33.0)
				# a vestige bound in the past (the word itself is set by _shot_lock_word below)
				var held: Array = player.get("constructs")
				if not held.is_empty():
					abilities[0]["bound"] = [{"stage": 0, "tier": "vestige", "concept": str((held[0] as Dictionary)["concept"])}]
					held.remove_at(0)
				abilities[0]["stage"] = 1
				abilities[0]["progress"] = 45.0
				abilities[1]["progress"] = 100.0
				inv.add("paired_mote")
				inv.equip("paired_mote")
				player.call("refresh_gear")
				player.call("assign_slot", 3, 2)
			_shot_lock_word()                              # Breaker's ring becomes its word's chain
			_enter_town()
			open_ethercosm()
		"runes-locked", "runes-locking", "runes", "seal-forming", "seal-traits", "seal-drown-self", "seal-drown-flood", "seal-drown-surge", \
				"seal-drag", "seal-refused", "seal-bond", "seal-convert", \
				"seal-discovered", "seal-palette":
			_setup_seal_shot(which)
		"nether":
			_show_screen(null, false)
			_enter_dungeon()
			nether.clear()
			var base: Vector3 = Vector3(0.0, 0.0, -4.0)
			var first_c: Node = null
			for spec: Array in [[Vector3(3.5, 0, -4.5), "vestige", "tension"], [Vector3(-4.0, 0, -6.0), "vestige", "acceleration"], [Vector3(1.0, 0, -9.5), "remnant", "piercing"]]:
				var made: Node = nether.spawn_construct(base + (spec[0] as Vector3), str(spec[1]), str(spec[2]), false)
				if first_c == null:
					first_c = made
			for wpos: Vector3 in [Vector3(2, 0, 1), Vector3(-2.5, 0, -2), Vector3(5, 0, -2), Vector3(-5, 0, -8), Vector3(0.5, 0, -5)]:
				nether.spawn_wisp(base + wpos, "water" if int(wpos.x * 10.0) % 2 == 0 else "plain")
			toggle_projection()
			nether.projection.global_position = player.global_position + level.to_global(Vector3(1.5, 0, -3.5)) - level.global_position
			nether.projection.set("input_blocked", true)
			nether.projection.call("take_hit", 5.0, false, null)
			(first_c.get("body") as Body).apply_damage(35.0)
			nether.projection.set("hovered", first_c)
			first_c.call("set_highlight", 1)
		"temper":
			# a two-affinity character part-way through its tempering, a little the worse for it
			player.call("set_affinities", ["water", "earth"])
			_enter_town()
			var known: Dictionary = player.get("tempering")
			known["callus"] = {"stage": 1, "progress": 43.75}
			known["slow_tide"] = {"stage": 0, "progress": 50.0}
			known["bedrock_bones"] = {"stage": 2, "progress": 0.0}
			(player.get("body") as Body).add_wound("temper_strain", "Tempering strain", 20.0, 20.0, true, true)
			open_tempering()
		"ascend-offer", "ascend-boost", "ascend-ethercosm":
			# the ascension (Brent 2026-10-24): a fire character with four skills at stages 2/1/1/0
			# ascends; the offer (a hybrid with fire as a parent, and a random one), then the boosts,
			# then the ethercosm showing a boosted skill, base in brackets
			_shot_ascension(which)
		"hud-dual":
			# a two-affinity character mid-fight: both kits on the bar, one affinity running hot
			player.call("set_talent", "furnace_gut")
			player.call("set_affinities", ["fire", "earth"])
			player.call("grow_star", 60.0)
			player.set("essence", 55.0)
			_show_screen(null, false)
			_enter_dungeon()
			(player.get("reflux_by") as Dictionary)["fire"] = 84.0
			(player.get("reflux_by") as Dictionary)["earth"] = 31.0
			player.set("ui_blocked", true)
		"hud", "hud-low":
			_show_screen(null, false)
			_enter_dungeon()
			sealed = true
			cleared = 2
			bank = 600
			player.global_position = level.to_global(Vector3(0.0, 0.0, -3.2 * ch_len))
			_activate(3)
			player.set("essence", float(player.get("essence_max")) * 0.55)
			player.set("reflux", 63.0)
			for id: String in ["brute_tusk", "serrated_dagger"]:
				PlayerScript.spawn_pickup(level, id, player.global_position + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(1.5, 3.5)))
			var first: Node = get_tree().get_nodes_in_group("enemies")[0]
			(first.get("body") as Body).apply_damage(95.0)
			player.set("attack_target", first)
			if which == "hud-low":
				(player.get("body") as Body).add_wound("hit_1", "Cracked ribs", 14.0, 8.0)
				(player.get("body") as Body).add_wound("lost_arm", "Lost arm", 25.0, 8.0, false)
				(player.get("body") as Body).apply_damage(52.0)
				player.set("reflux", 100.0)
				player.set("reflux_locked", true)
				player.set("arm_right_lost", true)
				player.set("essence", 6.0)
			if which == "hud":
				_shot_lock_word()                          # the slot tooltip names what the locked word does
			hud.set("debug_tip", "slot:0" if which == "hud" else "health")
			# freeze the fight so the picture is stable
			for e: Node in get_tree().get_nodes_in_group("enemies"):
				e.set_physics_process(false)
			player.set_physics_process(false)
			player.call("_refresh_highlights")


## For screenshots: a closed four-rune word on the first skill (Water Bolt), locked. Rune ids are
## the 2026-10-22 workbook's.
## Test-character shots (2026-10-22 build): "ethercosm" (a water test character's soul: eighteen
## skills), "runes" (an ice skill's word), "statuses" (enemies carrying the new statuses, the HUD over
## them), or an affinity id: that test character fighting in the arena, casting its skills.
func _setup_test_shot(what: String) -> void:
	forced_biome = "scrubland"
	if what.begins_with("ethercosm-"):
		start_test_character(what.trim_prefix("ethercosm-"))       # an affinity's own (test-ethercosm-holy: a hybrid's)
		open_ethercosm()
		return
	match what:
		"ethercosm":
			start_test_character("water")
			open_ethercosm()
			return
		"detail-mask", "detail-water", "detail-chain", "detail-sealed", "status-tip", "status-glossary":
			# the ethercosm's skill details (Brent 2026-10-23): a skill's numbers and its statuses
			var spec: Array = {"detail-mask": ["dream", "changeling_mask"], "detail-water": ["water", "riptide_lash"],
				"detail-chain": ["lightning", "forked_path"], "detail-sealed": ["water", "tsunami_strike"],
				"status-tip": ["dream", "shattered_dream"], "status-glossary": ["dream", "changeling_mask"]}[what]
			start_test_character(str(spec[0]))
			if what == "detail-sealed":
				_shot_lock_word()                      # Breaker sealed through two rings: base beside sealed
			open_ethercosm()
			var at: int = (player.get("abilities") as Array).map(func(s: Dictionary) -> String: return str(s["id"])).find(str(spec[1]))
			screen.call("select", maxi(0, at))
			if what == "status-glossary":
				screen.call("show_glossary", true)
			if what == "status-tip":
				# a status named on the panel, its definition open in place and as a tooltip: the pointer
				# rests on the chip until the tooltip shows
				_shot_countdown = 90
				get_tree().create_timer(0.25).timeout.connect(func() -> void:
					var chip: Control = screen.find_child("StatusTerm_asleep", true, false) as Control
					if chip == null:
						print("shot: no Asleep chip")
						return
					(chip as Button).emit_signal("pressed")
					var p: Vector2 = chip.get_global_rect().get_center()
					var mv := InputEventMouseMotion.new()
					mv.position = p
					mv.global_position = p
					get_viewport().push_input(mv)
					Input.warp_mouse(p))
			return
		"skilltree":
			# a new water character a few skills in: its thirteen-skill tree, three tiers deep
			_select_talent(0)
			player.call("set_affinities", ["water"])
			for id: String in ["riptide_lash", "tsunami_strike", "drench", "seepage"]:
				player.call("learn", id)
			player.set("skill_points", 2)
			_enter_town()
			open_skill_tree(false)
			return
		"runes":
			# a test character at its first level lock (no free edit since Brent 2026-10-23): ring 1 of
			# an ice skill being built, a vestige chosen in the panel
			start_test_character("ice")
			open_ethercosm()
			screen.call("open_runes")
			player.call("word_add", 0, "ICE-5a", 0)       # Brittle on Frost (Hoarline)
			player.call("word_add", 0, "UNI-11a", 0)      # Persist
			screen.call("pick_node", 1)
			return
		"statuses":
			start_test_character("ice")
			_show_screen(null, false)
			enter_arena()
			rest_timer = 9999.0
			var put: Array = [[Vector3(-2.2, 0, -2.6), "grunt", [["chilled", 3], ["bleeding", 2]]],
				[Vector3(1.0, 0, -3.4), "brute", [["dosed", 4], ["lit", 1], ["rusting", 1]]],
				[Vector3(3.6, 0, -1.4), "grunt", [["infected", 3], ["sick", 1], ["exposed", 1]]],
				[Vector3(-4.4, 0, -0.6), "archer", [["blinded", 1], ["shackled", 1]]],
				[Vector3(-0.6, 0, -5.6), "pavise", [["frozen", 1], ["corroded", 2]]]]
			for row: Array in put:
				_spawn_enemy(str(row[1]), row[0], 1.0)
			var all: Array = get_tree().get_nodes_in_group("enemies")
			for i: int in mini(all.size(), put.size()):
				for st: Array in put[i][2]:
					all[i].call("add_status", str(st[0]), int(st[1]), player)
				(all[i].get("body") as Body).apply_damage(20.0 * float(i + 1))
			state = "arena_fight"                          # no rest prompt over the picture
			for e: Node in all:
				e.set_physics_process(false)
			player.set_physics_process(false)
			return
	# an affinity: its test character in the arena, three skills in the air
	start_test_character(what)
	_show_screen(null, false)
	enter_arena()
	rest_timer = 9999.0
	for at: Vector3 in [Vector3(-1.5, 0, -4.0), Vector3(1.2, 0, -4.8), Vector3(3.0, 0, -2.5), Vector3(-3.5, 0, -6.0)]:
		_spawn_enemy("grunt", at, 1.0)
	_spawn_enemy("brute", Vector3(0.5, 0, -7.0), 1.0)
	player.call("start_fight")
	state = "arena_fight"
	var first: Node3D = get_tree().get_nodes_in_group("enemies")[0]
	player.set("cursor_fixed", first.global_position)
	player.set("hovered", first)
	player.set("_facing", (first.global_position - player.global_position).normalized())
	_shot_countdown = 75
	var order: Array = [0, 1, 3, 4, 2]
	for k: int in order.size():
		var slot: int = int(order[k])
		SkillTimer.after(level, 0.05 + 0.32 * float(k), func(_i: int) -> void:
			player.set("_recover_t", 0.0)
			player.set("_held", {})
			var live: Array = get_tree().get_nodes_in_group("enemies")
			if not live.is_empty():
				player.set("cursor_fixed", (live[k % live.size()] as Node3D).global_position)
				player.set("hovered", live[k % live.size()])
			player.call("cast_slot", slot))


## The v2 role shots (`--shot-ui=role-<affinity>`): a test character in the arena using the skill its role turns on -
## Earth's Millstone (the taunt), Poison's Venom Edge (the coat) and a bare strike that carries it, Blood's Thirsting
## Glaive (the conjured weapon), Dark's Ambush out of its own Blot, Death's thralls raised from the fallen.
const ROLE_SHOTS := {
	"earth": [["millstone", 0.1]],
	"poison": [["venom_edge", 0.1], ["sting_dart", 0.5]],
	"blood": [["red_lancet", 0.1], ["thirsting_glaive", 0.4]],
	"dark": [["hungry_dark", 0.5]],
	"death": [["rise_again", 0.1], ["rise_again", 0.35], ["rise_again", 0.6]],
}


func _setup_role_shot(aff: String) -> void:
	forced_biome = "scrubland"
	start_test_character(aff)
	_show_screen(null, false)
	enter_arena()
	rest_timer = 9999.0
	for at: Vector3 in [Vector3(-1.2, 0, -2.6), Vector3(1.4, 0, -3.0), Vector3(3.0, 0, -1.6), Vector3(-3.2, 0, -4.4)]:
		_spawn_enemy("grunt", at, 1.0)
	_spawn_enemy("brute", Vector3(0.4, 0, -5.4), 1.0)
	player.call("start_fight")
	state = "arena_fight"
	var foes: Array = get_tree().get_nodes_in_group("enemies")
	var first: Node3D = foes[0]
	player.set("_facing", ((first.global_position - player.global_position) * Vector3(1, 0, 1)).normalized())
	if aff == "death":
		# three of them fall where they stood, for the thralls to rise from
		for i: int in 3:
			var e: Node = foes[foes.size() - 1 - i]
			(e.get("body") as Body).apply_damage(9999.0)
			e.call("take_hit", 1.0, false, player)
	if aff == "dark":
		# you stand in a Dark of your own (a Blot's ground), Unseen, for the Ambush
		var dz := GroundZone.new()
		dz.shape = "circle"
		dz.radius = 3.0
		dz.life = 30.0
		dz.dark = true
		dz.kind = "dark_ground"
		dz.caster = player
		dz.from = player.global_position
		level.add_child(dz)
	_shot_countdown = 70
	for step: Array in ROLE_SHOTS.get(aff, []):
		var id: String = str(step[0])
		SkillTimer.after(level, float(step[1]), func(_i: int) -> void:
			player.set("_recover_t", 0.0)
			player.set("_held", {})
			var dead_spots: Array = get_tree().get_nodes_in_group("fallen").filter(func(f: Node) -> bool: return not bool(f.get("spent")))
			var live: Array = get_tree().get_nodes_in_group("enemies").filter(func(e: Node) -> bool: return not bool(e.call("is_dead")))
			if id == "rise_again" and not dead_spots.is_empty():
				player.set("cursor_fixed", (dead_spots[0] as Node3D).global_position)
			elif not live.is_empty():
				player.set("cursor_fixed", (live[0] as Node3D).global_position)
				player.set("hovered", live[0])
			var list: Array = player.get("abilities")
			for i: int in list.size():
				if str(list[i]["id"]) == id:
					player.set("essence", float(player.get("essence_max")))
					player.call("cast_ability", i)
					break)


func _shot_lock_word() -> void:
	# Heave and Drown on ring 1, Dry on Heave on ring 2: sealed through two rings, on Breaker (Surge)
	_shot_surge_first()
	_shot_seal(0, 2, [["WAT-4a", 0], ["WAT-4b", 0], ["WAT-3b", 1]])


## For the water seal shots: the skill built on Surge (Breaker; Water Bolt before v2) is put first, so a
## shot's rows (given against Surge) mean what they say. The hotbar follows the swap.
func _shot_surge_first() -> void:
	if not bool(player.call("knows", "tsunami_strike")) and str(player.call("can_learn", "tsunami_strike")) == "":
		player.call("learn", "tsunami_strike")
	var list: Array = player.get("abilities")
	var k: int = list.map(func(st: Dictionary) -> String: return str(st["id"])).find("tsunami_strike")
	if k <= 0:
		return
	var first: Dictionary = list[0]
	list[0] = list[k]
	list[k] = first
	var bar: Array = player.get("hotbar")
	for i: int in bar.size():
		if int(bar[i]) == 0:
			bar[i] = k
		elif int(bar[i]) == k:
			bar[i] = 0


## For screenshots: seal a word on skill `index` as if it had been bound in, lock by lock (the skill
## is raised to `stage` first). Rows are [rune, joined to row (0 = the skill's own rune, 1 = the first
## row ...), ring (optional)], inside out; `links` are extra [row a, row b] bonds. Every ring is full
## (Brent 2026-10-24): before a row goes on ring k, the empty places of the rings inside it are filled
## with SHOT_FILLER runes, set alone (so they change nothing the shot shows), and so are the rings left
## with empty places at the end; each ring gets a keystone (`concepts`, else the concepts in turn).
## Shot setup only: the rules are asked for every rune and bond (rings are built from the skill
## outward) and the closed-word rule is waived (RuneContext.closure_waived), as the test hook does; no
## screen reaches this.
const SHOT_FILLER := "UNI-19a"


func _shot_seal(index: int, stage: int, rows: Array, links: Array = [], concepts: Array = []) -> void:
	var st: Dictionary = (player.get("abilities") as Array)[index]
	st["stage"] = maxi(stage, int(st["stage"]))
	var w: Dictionary = RuneWord.make(GameData.skill_anchor(str(st["id"])), Runes.active().id)
	var rules: RuneRules = Runes.active()
	var rr: RingRules = rules as RingRules
	var ctx: RuneContext = player.call("rune_context", index)
	ctx.closure_waived = true
	var at: Dictionary = {0: 0}               # row -> node
	for ri: int in rows.size():
		var row: Array = rows[ri]
		var to: int = int(at.get(int(row[1]), -1))
		var k: int = int(row[2]) if row.size() > 2 else _shot_ring(w, ctx, to)
		_shot_fill(w, ctx, k - 1)
		var r: Dictionary = rules.add(w, str(row[0]), ctx, to, k)
		if not bool(r["ok"]):
			print("shot seal: %s refused: %s" % [str(row[0]), str(r["text"])])
		else:
			at[ri + 1] = int(r["node"])
	for l: Array in links:
		var r2: Dictionary = rules.link(w, int(at.get(int(l[0]), -1)), int(at.get(int(l[1]), -1)), ctx)
		if not bool(r2["ok"]):
			print("shot seal: link %s refused: %s" % [str(l), str(r2["text"])])
	_shot_fill(w, ctx, int(st["stage"]))
	if rr != null:
		for k2: int in range(1, int(st["stage"]) + 1):
			var cid: String = str(concepts[k2 - 1]) if k2 - 1 < concepts.size() else str(GameData.concept_ids()[(k2 - 1) % GameData.concept_ids().size()])
			RuneWord.set_keystone(w, k2, GameData.tier_for_stage(k2 - 1), cid)
	var sealed: Dictionary = rules.seal(w, ctx, int(st["stage"]))
	if bool(sealed["ok"]):
		st["word"] = w
	else:
		print("shot seal: refused: %s" % str(sealed["text"]))
	for rid: Variant in RuneWord.nodes(w):
		player.call("_know", str(rid))


## The ring a shot row joined to node `to` goes on: one further out where the skill has it and there is
## room, else the same ring, else the one inside (ring 1 for a rune joined to nothing or the skill).
func _shot_ring(w: Dictionary, ctx: RuneContext, to: int) -> int:
	var rr: RingRules = Runes.active() as RingRules
	if to <= 0 or rr == null:
		return 1
	var tr: int = RuneWord.ring(w, to)
	for k: int in [tr + 1, tr, tr - 1]:
		if k >= 1 and k <= ctx.rings and RuneWord.ring_nodes(w, k).size() < rr.ring_capacity(k):
			return k
	return tr


## Fill every empty place of rings 1..`upto` with the shot filler, set alone.
func _shot_fill(w: Dictionary, ctx: RuneContext, upto: int) -> void:
	var rr: RingRules = Runes.active() as RingRules
	if rr == null:
		return
	for k: int in range(1, upto + 1):
		while RuneWord.ring_nodes(w, k).size() < rr.ring_capacity(k):
			if not bool(rr.add(w, SHOT_FILLER, ctx, -1, k)["ok"]):
				print("shot seal: ring %d could not be filled" % k)
				break


## The seal board in the middle of an action, for a shot (the draft of "seal-drag" and friends):
## "seal-drag" Drown dragged onto Flood (an ionic bond: Drown would take Flood's effect), "seal-refused"
## Drown dragged onto Dry (full), "seal-bond" the Drown - Flood bond made and selected.
func _shot_board_state(which: String) -> void:
	if not (screen is EthercosmScreen):
		return
	var board: RuneBoard = null
	for n: Node in screen.find_children("RuneBoard", "Control", true, false):
		board = n as RuneBoard
	if board == null:
		return
	var word: Dictionary = player.call("ability_word", 0)
	var idx := {}
	for i: int in RuneWord.size(word):
		idx[RuneWord.node_id(word, i)] = i
	match which:
		"seal-drag":
			board.show_drag(int(idx["WAT-4b"]), board.node_global(int(idx["WAT-1a"])) + Vector2(4.0, 3.0))
		"seal-refused":
			board.show_drag(int(idx["WAT-4b"]), board.node_global(int(idx["WAT-3b"])) + Vector2(4.0, 3.0))
		"seal-bond":
			screen.call("finish_bond", int(idx["WAT-4b"]), int(idx["WAT-1a"]))


## The index of ability `id` on the player, learning it first if need be.
func _shot_skill(id: String) -> int:
	if not bool(player.call("knows", id)):
		player.call("learn", id)
	var list: Array = player.get("abilities")
	for i: int in list.size():
		if str(list[i]["id"]) == id:
			return i
	return 0


## The seal screen's shots (design/14 section 8). Rune ids are the 2026-10-22 workbook's.
##   seal-forming       a water + fire Breaker sealed through ring 1, its bar full and a remnant
##                      carried: the seal screen forming ring 2 over ring 1, part-built (also "runes")
##   runes-locking      the same seal bound through the screen (a sure roll), caught mid-animation
##   runes-locked       a two-ring seal on Breaker, looked at (no binding)
##   seal-traits        a three-ring Breaker: a closed ring 1, a spoke out to ring 3, two branch runes
##   seal-drown-*       Overboard's three Drown words (on Heave): Drown on the skill itself, Drown hung off Flood,
##                      Drown hung off Surge (each carries what it took over its ionic bond)
##   seal-drag          the seal-forming draft with a bond being dragged onto a rune that takes it: the
##                      live bond, its kind and dominant side in words, valid runes glowing, the rest dimmed
##   seal-refused       the same, dragged onto a rune that refuses it: the reason under it and at the cursor
##   seal-bond          the same draft with a bond selected: its gold sheath, its x, the panel's bond section
##   seal-convert       Drown takes Wave on Sluice Step (sealed, looked at, Drown selected): the converted
##                      strength 1.5 -> 2.5 and where it came from, the silence and the longer Dazed
##   seal-discovered    a new water character reading the waystone's runes: the "Rune discovered" card
##   seal-palette       the palette of a new character: what it knows, and the "?" it has yet to find
##   seal-lock-main     a water test character's ethercosm (Brent 2026-10-23): Breaker's bar full, "ready
##                      for its level 1 lock", one "Open the seal" button and no bind buttons
##   seal-lock-first    its seal at the first lock: ring 1 part-filled (2 of 3 places), the vestige
##                      waiting above it, Bind disabled with the reason (Brent 2026-10-24: full rings)
##   seal-lock-keystone the first lock with every place of ring 1 filled, the word closed and the vestige
##                      set over it as the keystone: Bind live
##   seal-lock-second   the second lock, by the real flow (ring 1 full, closed and bound under a vestige,
##                      the bar refilled - a test override): ring 1 reworked, ring 2 full and closed, the
##                      remnant set over it
##   seal-lock-missing  a new character's main page: the bar full, no vestige carried - what is missing,
##                      and no way into the lock
func _setup_seal_shot(which: String) -> void:
	if which.begins_with("seal-lock-"):
		_setup_lock_shot(which.trim_prefix("seal-lock-"))
		return
	if which.begins_with("seal-palette-"):
		# an affinity's own runes in the palette of its test character's first lock (Holy's Old Turkic glyphs)
		var aff: String = which.trim_prefix("seal-palette-")
		start_test_character(aff)
		_enter_town()
		open_seal(0, 0)
		screen.call("set_palette_tab", aff)
		return
	_select_talent(0)
	(player.get("constructs") as Array).clear()          # the other UI shots hand out two vestiges first
	match which:
		"seal-drag", "seal-refused", "seal-bond":
			# ring 1 sealed: Flood and Heave on Surge, Dry on Heave; forming ring 2: Drown and Settle set, not bonded
			player.call("set_affinities", ["water"])
			_shot_surge_first()
			_shot_seal(0, 1, [["WAT-1a", 0], ["WAT-4a", 0], ["WAT-3b", 2]])
			for rid2: String in ["WAT-6b", "WAT-4b", "WAT-7b", "UNI-05a"]:
				player.call("_know", rid2)
			(player.get("abilities") as Array)[0]["progress"] = 100.0
			(player.get("constructs") as Array).append({"tier": "remnant", "concept": "tension"})
			_enter_town()
			open_seal(0, 0)
			screen.call("place_rune", "WAT-4b", 2, 1)          # Drown, ring 2
			screen.call("place_rune", "WAT-6b", 2, 3)          # Settle, ring 2
			screen.call("deselect")
			_shot_countdown = 60
			get_tree().create_timer(0.4, true).timeout.connect(_shot_board_state.bind(which))
		"seal-forming", "runes", "runes-locking":
			player.call("set_affinities", ["water", "fire"])
			_shot_surge_first()
			_shot_seal(0, 1, [["WAT-1a", 0], ["WAT-4a", 0], ["WAT-3b", 1]], [[1, 2]])     # Flood, Heave (joined), Dry
			for rid: String in ["WAT-6b", "WAT-4b", "WAT-7b", "UNI-05a", "UNI-11a", "FIR-1b", "WAT-2b"]:
				player.call("_know", rid)
			var own: Array = player.get("abilities")
			own[0]["progress"] = 100.0
			(player.get("constructs") as Array).append({"tier": "remnant", "concept": "tension"})
			_enter_town()
			open_seal(0, 0)
			# rework ring 1: part Flood and Heave, so each has a bond for the new ring
			player.call("word_toggle_link", 0, 1, 2)
			player.call("word_add", 0, "WAT-6b", 2)        # Settle off Heave, out on ring 2
			player.call("word_add", 0, "WAT-4b", 4)        # Drown off Settle, ring 2
			player.call("word_add", 0, "WAT-3b", 4)        # a second Dry off Settle, ring 2 (Slack before v2)
			player.call("word_add", 0, "UNI-05a", 1)       # Expand off Flood, ring 2
			if which == "runes-locking":
				player.call("word_toggle_link", 0, 4, 7)   # Expand joins Settle: the word closes
				screen.call("bind_and_seal", 0.0)
				_shot_countdown = 38
			else:
				screen.call("pick_node", 7)                # Expand picked: one bond still open
		"seal-convert":
			player.call("set_affinities", ["water"])
			var tb: int = _shot_skill("hydraulic_flex")
			_shot_seal(tb, 1, [["WAT-4b", 0]])                # Drown on Wave: ionic, Drown takes it
			_enter_town()
			open_ethercosm()
			screen.call("select", tb)
			screen.call("open_runes")
			screen.call("pick_node", 1)
		"runes-locked":
			player.call("set_affinities", ["water", "fire"])
			_shot_surge_first()
			_shot_seal(0, 2, [["WAT-6b", 0], ["WAT-4b", 0], ["WAT-3b", 1], ["WAT-4a", 1, 2], ["WAT-3b", 1, 2], ["FIR-1b", 4, 2]])
			_enter_town()
			open_ethercosm()
			screen.call("open_runes")
		"seal-traits":
			player.call("set_affinities", ["water"])
			_shot_surge_first()
			# ring 1: Flood, Settle, Soak round a triangle; Settle -> Heave (ring 2) -> Drown (ring 3)
			_shot_seal(0, 3, [["WAT-1a", 0], ["WAT-6b", 0], ["WAT-3a", 1, 1], ["WAT-4a", 2, 2], ["WAT-4b", 4, 3]], [[1, 2], [2, 3]])
			_enter_town()
			open_ethercosm()
			screen.call("open_runes")
		"seal-drown-self", "seal-drown-flood", "seal-drown-surge":
			player.call("set_affinities", ["water"])
			var pj: int = _shot_skill("overboard")
			match which:
				"seal-drown-self":
					_shot_seal(pj, 2, [["WAT-4b", 0]])
				"seal-drown-flood":
					_shot_seal(pj, 2, [["WAT-1a", 0], ["WAT-4b", 1]])
				"seal-drown-surge":
					_shot_seal(pj, 2, [["WAT-2a", 0], ["WAT-4b", 1]])
			_enter_town()
			open_ethercosm()
			screen.call("select", pj)
			screen.call("open_runes")
		"seal-discovered":
			player.call("set_affinities", ["water"])
			player.call("start_with_skills", player.call("default_start_skills"))
			_show_screen(null, false)
			enter_zone("the_stubble", "dross_gate")
			var stone: RuneStone = null
			for n: Node in get_tree().get_nodes_in_group("rune_stones"):
				stone = n as RuneStone
				if stone.stone_id == "stubble_waystone_runes":
					break
			if stone != null:
				player.global_position = stone.global_position + Vector3(2.2, 0.0, 0.0)
				player.set("rng", RandomNumberGenerator.new())
				_read_stone(stone)
			_shot_countdown = 40
		"seal-palette":
			player.call("set_affinities", ["water"])
			player.call("start_with_skills", player.call("default_start_skills"))
			var mine: Array = player.get("abilities")
			mine[0]["progress"] = 100.0
			(player.get("constructs") as Array).append({"tier": "vestige", "concept": "reach"})
			player.call("discover_rune", "UNI-05a", "")
			_enter_town()
			open_seal(0, 0)
			screen.call("set_palette_tab", "universal")


## For a shot: set the carried construct of the open lock's tier and `concept` as its keystone.
func _shot_keystone(concept: String) -> void:
	var need: String = str(player.call("pending_tier", (player.get("abilities") as Array)[int(player.call("sealing_index"))]))
	for g: Dictionary in player.call("construct_groups", need):
		if str(g["concept"]) == concept:
			screen.call("choose_construct", int(g["index"]))
			return
	print("shot: no %s of %s carried" % [need, concept])


## The level lock's shots (design/14 sections 11-12); see _setup_seal_shot.
func _setup_lock_shot(what: String) -> void:
	forced_biome = "scrubland"
	match what:
		"main":
			start_test_character("water")
			_shot_surge_first()
			open_ethercosm()
			screen.call("select", 0)
		"first":
			# ring 1 part-filled (2 of 3 places), the vestige chosen and waiting above it: Bind says why not
			start_test_character("water")
			_shot_surge_first()
			open_seal(0)
			screen.call("place_rune", "WAT-1a", 1, 0)        # Flood, ring 1
			screen.call("place_rune", "WAT-4a", 1, 1)        # Heave, ring 1
			screen.call("finish_bond", 0, 1)                 # Flood joined to the skill
			screen.call("finish_bond", 0, 2)                 # Gush joined to the skill
			_shot_keystone("acceleration")
			screen.call("deselect")
		"keystone":
			# every place of ring 1 filled, the word closed, the vestige set over it: ready to bind
			start_test_character("water")
			_shot_surge_first()
			open_seal(0)
			screen.call("place_rune", "WAT-1a", 1, 0)        # Flood
			screen.call("place_rune", "WAT-4a", 1, 1)        # Heave
			screen.call("place_rune", "WAT-3b", 1, 2)        # Dry
			for pair: Array in [[0, 1], [0, 2], [1, 3], [1, 2]]:
				screen.call("finish_bond", int(pair[0]), int(pair[1]))
			_shot_keystone("acceleration")
			screen.call("deselect")
		"second":
			# lock 1 bound by the real flow (ring 1 full and closed, the vestige of Acceleration over it;
			# the bar refills - a test override), then lock 2: ring 1 reworked, all five places of ring 2
			# filled and the word closed, the remnant of Reach set over ring 2
			start_test_character("water")
			_shot_surge_first()
			open_seal(0)
			player.call("word_add", 0, "WAT-1a", 0)          # Flood
			player.call("word_add", 0, "WAT-4a", 0)          # Heave
			player.call("word_add", 0, "WAT-3b", 1)          # Dry on Flood
			player.call("word_toggle_link", 0, 1, 2)         # Flood - Heave: closed, ring 1 full
			_shot_keystone("acceleration")
			screen.call("bind_and_seal", 0.0)                # the vestige binds; the bar refills (test override)
			player.call("word_toggle_link", 0, 1, 2)         # rework ring 1: part Flood and Heave
			player.call("word_remove", 0, 3)                 # Dry out
			player.call("word_add", 0, "WAT-4b", 1, 1)       # Drown in its place, on ring 1, off Flood (Slack before v2)
			player.call("word_add", 0, "WAT-6b", 2)          # Settle off Heave, ring 2
			player.call("word_add", 0, "WAT-4b", 4)          # Drown off Settle, ring 2
			player.call("word_add", 0, "WAT-3b", 4)          # Dry off Settle, ring 2
			player.call("word_add", 0, "UNI-05a", 1)         # Expand off Flood, ring 2
			player.call("word_add", 0, "UNI-05a", 7)         # a second Expand off the first: ring 2 full
			player.call("word_toggle_link", 0, 4, 8)         # it and Settle: the word closes
			_shot_keystone("reach")
			screen.call("deselect")
			_shot_countdown = 70
		"missing":
			# a new character's full skill and no vestige carried: the main page says what is missing,
			# and there is no way into the lock
			_select_talent(0)
			player.call("set_affinities", ["water"])
			player.call("start_with_skills", player.call("default_start_skills"))
			(player.get("abilities") as Array)[0]["progress"] = 100.0
			(player.get("constructs") as Array).clear()
			_enter_town()
			open_ethercosm()
			screen.call("select", 0)


func _tick_bot_report() -> void:
	var elapsed: int = Time.get_ticks_msec() - _bot_started_ms
	if _bot_finished and state == "town":
		var ok := false
		if _bot_scenario == "die":
			var money_now: int = int(player.get("money"))
			var inv: Inventory = player.get("inventory")
			var left_behind: Array = player.get("corpses")
			ok = not bool(player.get("dead")) and money_now == _bot_money_before and _last_payout == 0 \
				and inv.equipped.is_empty() and left_behind.size() == 1 and str((left_behind[0] as Dictionary)["where"]) == "passage"
			print("BOT[die]: alive=%s money %d -> %d payout=%d naked=%s corpses=%d state=%s -> %s" % [
				str(not bool(player.get("dead"))), _bot_money_before, money_now, _last_payout, str(inv.equipped.is_empty()), left_behind.size(), state, "PASS" if ok else "FAIL"])
		else:
			var walls: int = chambers if _bot_scenario == "full" else gate_at
			var banked: int = 0
			for c: int in range(1, walls + 1):
				banked += stage_value * c
			var expected: int = int(float(banked) * (full_clear_bonus if walls == chambers else 1.0))
			ok = _last_sealed and _last_cleared == walls and _last_payout == expected
			print("BOT[%s]: sealed=%s walls=%d payout=%d expected=%d money=%d -> %s" % [
				_bot_scenario, str(_last_sealed), _last_cleared, _last_payout, expected, int(player.get("money")), "PASS" if ok else "FAIL"])
		Engine.time_scale = 1.0
		get_tree().quit(0 if ok else 1)
	elif elapsed > 120000:
		print("BOT: TIMEOUT state=%s sealed=%s current=%d cleared=%d -> FAIL" % [state, str(sealed), current, cleared])
		# what was still standing, and what it was doing - a stall is an enemy that could not be killed
		var here: Vector3 = level.to_local(player.global_position)
		print("BOT:   bot at local (%.1f, %.1f) chamber %d  vel %s  target %s  melee_cd %.2f recover %.2f stagger %.2f" % [
			here.x, here.z, int(-here.z / ch_len), str((player as CharacterBody3D).velocity), str(player.get("attack_target")),
			float(player.get("_melee_cd")), float(player.get("_recover_t")), float(player.get("_stagger_t"))])
		for n: Node in get_tree().get_nodes_in_group("enemies"):
			var e := n as Node3D
			var at: Vector3 = level.to_local(e.global_position)
			print("BOT:   left: %s at local (%.1f, %.1f) chamber %d  %.1f m away  hp %d  windup %.2f  stuck %.2f  leap %.2f  retreat_t %.2f  statuses %s" % [
				str(e.get("kind")), at.x, at.z, int(-at.z / ch_len), e.global_position.distance_to(player.global_position), int((e.get("body") as Body).hp),
				float(e.get("_windup")), float(e.get("_stuck_t")), float(e.get("_leap_left")), float(e.get("_retreat_t")), str((e.get("statuses") as Dictionary).keys())])
		Engine.time_scale = 1.0
		get_tree().quit(1)


func _save_shot() -> void:
	var dir: String = ProjectSettings.globalize_path("res://").path_join("../shots")
	DirAccess.make_dir_recursive_absolute(dir)
	print("shot: player at %s" % str(player.global_position))
	# The headless renderer has no framebuffer to read.
	if DisplayServer.get_name() == "headless":
		get_tree().quit()
		return
	# what it cost to draw: frame rate, draw calls and triangles in view
	print("render: %d fps, %d draw calls, %d objects, %d primitives in view" % [Engine.get_frames_per_second(),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	var img: Image = get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(dir.path_join("shot.png"))
		print("shot saved")
	get_tree().quit()
