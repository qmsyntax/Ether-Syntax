extends Node3D
## Prototype flow: talent select -> town -> (assault passage | practice arena) -> town ...
## Everything is built in code so the project stays plain text.

const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const SceneryScript := preload("res://scripts/scenery.gd")
const HudScript := preload("res://scripts/hud.gd")
const SettingsMenuScript := preload("res://scripts/settings_menu.gd")
const TitleScreen := preload("res://scripts/ui/title_screen.gd")
const TownScreen := preload("res://scripts/ui/town_screen.gd")
const ShopScreen := preload("res://scripts/ui/shop_screen.gd")
const InventoryScreen := preload("res://scripts/ui/inventory_screen.gd")
const MessageScreen := preload("res://scripts/ui/message_screen.gd")
const EthercosmScreen := preload("res://scripts/ui/ethercosm_screen.gd")

const CAMERA_OFFSET := Vector3(12.0, 12.0, 12.0)
const TALENT_CHOICES: Array[String] = [
	"one_percent_lifesteal", "tenth_strike", "grudge", "glass_hour", "debt_of_pain", "furnace_gut",
]

# Practice arena.
var arena_half: float = GameData.num("arena", "half_size")
var arena_rent_per_second: float = GameData.num("arena", "rent_per_s")

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
var rescue_fee: int = GameData.inum("town", "rescue_fee")
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
var pads: Array[Node3D] = []

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


func _ready() -> void:
	rng.randomize()
	_build_world()
	_build_player()
	_build_hud()
	_build_town()
	_show_select()

	var args: PackedStringArray = OS.get_cmdline_user_args()
	var ui_shot := ""
	for a: String in args:
		if a.begins_with("--shot-ui="):
			ui_shot = a.trim_prefix("--shot-ui=")
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
	camera.global_position = focus + CAMERA_OFFSET
	camera.look_at(focus + Vector3.UP, Vector3.UP)
	if nether.active:
		nether.tick(delta, camera)

	match state:
		"town":
			_prompt = ""
		"arena_rest":
			rest_timer -= delta
			# Rest is free for the body and costly for the wallet: rent ticks while you recover.
			if wave >= 1:
				_charge_rent(arena_rent_per_second, delta)
			_prompt = "Wave %d in %d   -   resting heals you for free, but rent is $%d a second\n%s go now     %s rest longer     %s healer     hold %s to meditate     %s back to town" % [
				wave + 1, int(ceil(rest_timer)), int(arena_rent_per_second),
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

	hud.call("refresh", player, _where())
	hud.set("show_world", state == "dungeon" or state == "arena_rest" or state == "arena_fight")
	hud.call("set_nether", nether.hud_info())
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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("settings"):
		if screen is ShopScreen or screen is InventoryScreen or screen is EthercosmScreen:
			close_screen()
		else:
			_open_settings()
		return

	if state == "select" or state == "dead":
		return
	if event.is_action_pressed("inventory"):
		open_inventory()
		return
	if event.is_action_pressed("ethercosm"):
		open_ethercosm()
		return
	if event.is_action_pressed("project"):
		toggle_projection()
		return
	if nether.active:
		return                          # a soul has no hands for anything else

	match state:
		"arena_rest", "arena_fight":
			if _cast_from_hotbar(event):
				pass
			elif event.is_action_pressed("ascend"):
				player.call("try_ascend")
			elif event.is_action_pressed("bind"):
				player.call("bind_first_ready")
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
					_enter_town()
		"dungeon":
			if _cast_from_hotbar(event):
				pass
			elif event.is_action_pressed("ascend"):
				player.call("try_ascend")
			elif event.is_action_pressed("bind"):
				player.call("bind_first_ready")
			elif event.is_action_pressed("healer"):
				player.call("note", "No healer in here. The entrance is sealed.")
			elif event.is_action_pressed("interact"):
				if _pad_in_reach():
					_extract()
				elif pads.is_empty():
					player.call("note", "No exit yet. %d more walls." % maxi(0, gate_at - cleared))
				else:
					player.call("note", "Stand on a glowing exit to leave.")


## Hotbar slots are the actions ability_1..N. Returns true if the event cast something.
func _cast_from_hotbar(event: InputEvent) -> bool:
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


# --- select / town --------------------------------------------------------------

func _show_select() -> void:
	state = "select"
	_show_screen(TitleScreen.new(self), false)


func _select_talent(index: int) -> void:
	player.call("set_talent", TALENT_CHOICES[index])


func _enter_town() -> void:
	if nether.active:
		nether.exit("")
	_build_town()
	player.set("active", false)
	player.call("end_fight")
	player.global_position = Vector3.ZERO
	player.set("attack_target", null)
	player.set("pickup_target", null)
	player.set("has_move_goal", false)
	state = "town"
	_prompt = ""
	save_now()
	_show_screen(TownScreen.new(self), false)


# --- the Netherecho ------------------------------------------------------------------------

## Leave the body, or return to it. Only possible out of combat, in the field.
func toggle_projection() -> void:
	if nether.active:
		nether.exit("You return to your body.")
		return
	if state != "dungeon" and state != "arena_rest":
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
	_env.background_color = Color(0.03, 0.015, 0.07) if on else Color(0.07, 0.08, 0.1)
	_env.ambient_light_color = Color(0.5, 0.42, 0.95) if on else Color(0.75, 0.75, 0.85)
	_env.ambient_light_energy = 0.75 if on else 0.55
	_sun.light_energy = 0.18 if on else 1.0
	_sun.light_color = Color(0.7, 0.6, 1.0) if on else Color(1, 1, 1)
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


## Close the open screen. In town that means back to the town screen.
func close_screen() -> void:
	if state == "town":
		_show_screen(TownScreen.new(self), false)
	else:
		_show_screen(null, false)


func open_settings() -> void:
	_open_settings()


func open_shop() -> void:
	if state == "town":
		_show_screen(ShopScreen.new(self), false)


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


func start_new_character(index: int) -> void:
	_select_talent(index)
	_enter_town()


func toggle_hardcore() -> void:
	hardcore = not hardcore


func new_character() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()


func enter_passage() -> void:
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

func save_now() -> void:
	if _bot_mode or _shot_mode or _test_mode or str(player.get("talent_id")) == "":
		return
	var data: Dictionary = player.call("to_save")
	data["day"] = day
	data["delves"] = delves
	data["hardcore"] = hardcore
	SaveGame.write(data)


## Load the saved character into town. Returns false if there is nothing usable to load.
func continue_game() -> bool:
	var data: Dictionary = SaveGame.read()
	if data.is_empty() or str(data.get("talent_id", "")) == "":
		return false
	player.call("from_save", data)
	day = int(data.get("day", 1))
	delves = int(data.get("delves", 0))
	hardcore = bool(data.get("hardcore", false))
	_enter_town()
	return true


func _repeat_mult() -> float:
	return maxf(repeat_floor, pow(repeat_factor, float(delves)))


# --- practice arena -------------------------------------------------------------

func _enter_arena() -> void:
	_new_level(0.0)
	_static_box(Vector3(0, -0.5, 0), Vector3(arena_half * 2.0, 1.0, arena_half * 2.0), Color(0.62, 0.53, 0.22))
	var wall_color := Color(0.3, 0.3, 0.34)
	var span: float = arena_half * 2.0 + 2.0
	_static_box(Vector3(0, 1.0, -arena_half - 0.5), Vector3(span, 2.0, 1.0), wall_color)
	_static_box(Vector3(0, 1.0, arena_half + 0.5), Vector3(span, 2.0, 1.0), wall_color)
	_static_box(Vector3(-arena_half - 0.5, 1.0, 0), Vector3(1.0, 2.0, span), wall_color)
	_static_box(Vector3(arena_half + 0.5, 1.0, 0), Vector3(1.0, 2.0, span), wall_color)
	for i: int in GameData.inum("arena", "scenery_count"):
		var pos := Vector3.ZERO
		for attempt: int in 8:
			pos = Vector3(rng.randf_range(-arena_half + 1.5, arena_half - 1.5), 0.0, rng.randf_range(-arena_half + 1.5, arena_half - 1.5))
			if pos.length() > 3.0:
				break
		_spawn_scenery("bush" if i % GameData.inum("arena", "bush_every_n") == 0 else "grass", pos)
	for q: Vector3 in [Vector3(-8, 0, -8), Vector3(8, 0, -8), Vector3(-8, 0, 8), Vector3(8, 0, 8)]:
		nether.populate_site(q, Vector2(6.0, 6.0))
	player.global_position = Vector3.ZERO
	player.set("active", true)
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


func _spawn_arena_enemy(kind: String) -> void:
	var angle: float = rng.randf() * TAU
	_spawn_enemy(kind, Vector3(cos(angle), 0.0, sin(angle)) * (arena_half - 3.0), 1.0)


# --- assault passage ------------------------------------------------------------

func _enter_dungeon() -> void:
	# Rotated so the corridor runs straight "up" the isometric screen: W alone walks it.
	_new_level(45.0)
	var total: float = float(chambers + 1) * ch_len
	var mid_z: float = -total * 0.5
	var wall_color := Color(0.26, 0.26, 0.3)
	_static_box(Vector3(0, -0.5, mid_z), Vector3(ch_half_w * 2.0, 1.0, total), Color(0.5, 0.44, 0.22))
	_static_box(Vector3(-ch_half_w - 0.5, 1.0, mid_z), Vector3(1.0, 2.0, total + 2.0), wall_color)
	_static_box(Vector3(ch_half_w + 0.5, 1.0, mid_z), Vector3(1.0, 2.0, total + 2.0), wall_color)
	_static_box(Vector3(0, 1.0, 0.5), Vector3(ch_half_w * 2.0, 2.0, 1.0), wall_color)
	_static_box(Vector3(0, 1.0, -total - 0.5), Vector3(ch_half_w * 2.0, 2.0, 1.0), wall_color)

	var side_w: float = ch_half_w - gap_half
	var side_x: float = gap_half + side_w * 0.5
	for c: int in range(1, chambers + 1):
		var z: float = -float(c) * ch_len
		_static_box(Vector3(-side_x, 1.0, z), Vector3(side_w, 2.0, 1.0), wall_color)
		_static_box(Vector3(side_x, 1.0, z), Vector3(side_w, 2.0, 1.0), wall_color)
		if c >= 2:
			_add_barrier(c)

	for c: int in range(0, chambers + 1):
		var tufts: int = GameData.inum("passage", "antechamber_tufts") if c == 0 else GameData.inum("passage", "chamber_tufts")
		for i: int in tufts:
			var pos := Vector3(rng.randf_range(-ch_half_w + 1.0, ch_half_w - 1.0), 0.0,
				-float(c) * ch_len - rng.randf_range(1.5, ch_len - 1.5))
			_spawn_scenery("bush" if i == 0 else "grass", pos)

	# the spirit layer: one site per chamber, antechamber included
	for c: int in range(0, chambers + 1):
		nether.populate_site(Vector3(0.0, 0.0, -(float(c) + 0.5) * ch_len), Vector2(ch_half_w - 1.5, ch_len * 0.5 - 1.5))
	player.global_position = level.to_global(Vector3(0.0, 0.0, -4.0))
	player.set("active", true)
	state = "dungeon"
	player.call("note", "You step through. Walk up the corridor (%s)." % Keybinds.binding_text("move_up"))


func _add_barrier(c: int) -> void:
	var b: StaticBody3D = _static_box(Vector3(0, 1.0, -float(c) * ch_len), Vector3(gap_half * 2.0, 2.0, 0.6), Color(0.75, 0.15, 0.15))
	barriers[c] = b


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
		var goal_local: Vector3
		if leave_now and not pads.is_empty():
			goal_local = level.to_local(pads.back().global_position)
		elif absf(local.x) > 0.8:
			goal_local = Vector3(0.0, 0.0, local.z)
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
	for kind: String in kinds:
		var local := Vector3(rng.randf_range(-ch_half_w + 2.0, ch_half_w - 2.0), 0.0,
			rng.randf_range(-float(c + 1) * ch_len + 2.0, -float(c) * ch_len - 7.0))
		_spawn_enemy(kind, local, strength)
	player.call("start_fight")
	player.call("note", "Wall %d of %d." % [c, chambers])
	hud.call("announce", "WALL %d" % c if c != chambers else "THE LAST WALL")
	if _shot_dungeon and c == 2:
		Engine.time_scale = 1.0
		player.set("bot", false)
		_shot_countdown = 25


func _on_wall_cleared() -> void:
	cleared = current
	bank += stage_value * cleared
	player.call("end_fight")
	var next_c: int = cleared + 1
	if barriers.has(next_c):
		(barriers[next_c] as Node).queue_free()
		barriers.erase(next_c)
	if cleared >= gate_at:
		_spawn_pad(cleared)
	player.call("note", "Wall %d cleared. $%d banked - yours only if you walk out." % [cleared, bank])
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
	var payout: int = _payout_now()
	player.set("money", int(player.get("money")) + payout)
	_last_payout = payout
	_last_cleared = cleared
	_last_sealed = sealed
	_bot_finished = _bot_mode
	delves += 1
	player.call("note", "You walk out after %d walls with $%d." % [cleared, payout])
	var rewards: Array[String] = grant_exit_rewards(cleared, cleared == chambers)
	_enter_town()
	if not rewards.is_empty():
		player.call("note", "At the exit: %s." % ", ".join(rewards))


func _set_dungeon_banner() -> void:
	if not sealed:
		_prompt = "The antechamber. Walk up the corridor (%s) to begin - the entrance seals behind you.\nLast chance to cut grass in peace." % Keybinds.binding_text("move_up")
	elif current > cleared:
		_prompt = ""
	elif cleared >= chambers:
		_prompt = "All %d walls down.   %s on a glowing exit to leave with $%d, full-clear bonus included." % [chambers, _k("interact"), _payout_now()]
	elif cleared >= gate_at:
		_prompt = "%s on a glowing exit to leave with $%d   -   or push on: wall %d banks $%d more.\nRent is $%d a second while you stand here." % [_k("interact"), _payout_now(), cleared + 1, stage_value * (cleared + 1), int(dungeon_rent_per_second)]
	else:
		_prompt = "$%d banked, but no exit until wall %d.   Rest if you need it - rent is $%d a second." % [bank, gate_at, int(dungeon_rent_per_second)]


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
	player.call("revive_in_debt", rescue_fee)
	if lost > 0:
		player.call("note", "The $%d you had banked stayed in the passage." % lost)
	_last_payout = 0
	_enter_town()


func _new_level(yaw_degrees: float) -> void:
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
	pads.clear()
	_rent_accum = 0.0


func _build_town() -> void:
	_new_level(0.0)
	_static_box(Vector3(0, -0.5, 0), Vector3(24.0, 1.0, 24.0), Color(0.33, 0.32, 0.3))


func _static_box(pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var sb := StaticBody3D.new()
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
	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-52.0, 30.0, 0.0)
	_sun.shadow_enabled = true
	add_child(_sun)
	_set_nether_look(false)

	nether = Netherecho.new()
	add_child(nether)
	nether.connect("entered", _on_nether_entered)
	nether.connect("exited", _on_nether_exited)
	nether.connect("projection_destroyed", _on_projection_destroyed)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = GameData.num("camera", "ortho_size")
	camera.far = 200.0
	add_child(camera)
	camera.current = true


func _build_player() -> void:
	player = PlayerScript.new()
	add_child(player)
	player.global_position = Vector3.ZERO
	player.connect("died", _on_player_died)
	player.connect("disturbed", _on_body_disturbed)
	nether.player = player


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
			return "The passage  -  wall %d of %d  -  $%d banked" % [cleared, chambers, bank]
	return ""


# --- test harness ---------------------------------------------------------------

## Put the game into a named UI state with representative data, then screenshot it.
## States: title, town, shop, inventory, hud (mid-fight, hurt), hud-low (near death, reflux locked).
func _setup_ui_shot(which: String) -> void:
	_shot_mode = true
	_frames = 1000                      # disable the arena auto-shot; _shot_countdown drives this one
	_shot_countdown = 40
	if which == "title":
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
		"shop":
			_enter_town()
			open_shop()
		"inventory":
			_enter_town()
			open_inventory()
		"ethercosm", "ethercosm-2":
			if which == "ethercosm-2":
				# a later character: two stars, a bound vestige, a rearranged bar
				player.call("grow_star", 99.0)
				player.set("_latent_aura", 1000.0)
				player.call("try_ascend")
				player.call("grow_star", 33.0)
				player.call("bind_construct", 0, 0, 0.0)
				abilities[0]["progress"] = 45.0
				abilities[1]["progress"] = 100.0
				inv.add("paired_mote")
				inv.equip("paired_mote")
				player.call("refresh_gear")
				player.call("assign_slot", 3, 2)
			_enter_town()
			open_ethercosm()
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
				(player.get("body") as Body).apply_damage(52.0)
				player.set("reflux", 100.0)
				player.set("reflux_locked", true)
				player.set("arm_right_lost", true)
				player.set("essence", 6.0)
			hud.set("debug_tip", "slot:0" if which == "hud" else "health")
			# freeze the fight so the picture is stable
			for e: Node in get_tree().get_nodes_in_group("enemies"):
				e.set_physics_process(false)
			player.set_physics_process(false)
			player.call("_refresh_highlights")


func _tick_bot_report() -> void:
	var elapsed: int = Time.get_ticks_msec() - _bot_started_ms
	if _bot_finished and state == "town":
		var ok := false
		if _bot_scenario == "die":
			var money_now: int = int(player.get("money"))
			ok = not bool(player.get("dead")) and money_now == _bot_money_before - rescue_fee and _last_payout == 0
			print("BOT[die]: alive=%s money %d -> %d (fee %d) payout=%d state=%s -> %s" % [
				str(not bool(player.get("dead"))), _bot_money_before, money_now, rescue_fee, _last_payout, state, "PASS" if ok else "FAIL"])
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
	var img: Image = get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(dir.path_join("shot.png"))
		print("shot saved")
	get_tree().quit()
