extends Node3D
## Prototype flow: talent select -> town -> (assault passage | practice arena) -> town ...
## Everything is built in code so the project stays plain text.

const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const SceneryScript := preload("res://scripts/scenery.gd")

const CAMERA_OFFSET := Vector3(12.0, 12.0, 12.0)
const TALENT_CHOICES: Array[String] = [
	"one_percent_lifesteal", "tenth_strike", "grudge", "glass_hour", "debt_of_pain", "furnace_gut",
]

# Practice arena.
const ARENA_HALF := 18.0
const ARENA_RENT_PER_SECOND := 5.0

# Assault passage. Rules follow design/01-systems-bible LAW 6b [C]: the entrance seals, a minimum
# of progress unlocks the exit, stages escalate and spike past the midpoint, the reward is paid
# only at the exit, and repeats pay less. Every number here is a first guess [MODEL].
const CH_LEN := 14.0
const CH_HALF_W := 8.0
const CHAMBERS := 10
const GATE_AT := 5
const GAP_HALF := 2.0
const DUNGEON_RENT_PER_SECOND := 3.0
const TICKET_PRICE := 300
const STAGE_VALUE := 200            # wall n banks STAGE_VALUE * n
const FULL_CLEAR_BONUS := 1.5
const REPEAT_FACTOR := 0.8
const REPEAT_FLOOR := 0.4
const LATE_STRENGTH := 1.3          # walls past the gate
const EXIT_REACH := 2.4

# Town.
const RESCUE_FEE := 600
const NIGHT_RENT := 150

var player: CharacterBody3D
var camera: Camera3D
var notebook: Label
var banner: Label
var level: Node3D

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


func _ready() -> void:
	rng.randomize()
	_build_world()
	_build_player()
	_build_hud()
	_build_town()
	_show_select()

	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--shot"):
		_shot_mode = true
		_select_talent(0)
		_enter_arena()
		rest_timer = 0.5
	elif args.has("--bot-dungeon") or args.has("--bot-full") or args.has("--bot-die") or args.has("--shot-dungeon"):
		_shot_dungeon = args.has("--shot-dungeon")
		_bot_scenario = "full" if args.has("--bot-full") else ("die" if args.has("--bot-die") else "gate")
		_bot_mode = true
		_bot_started_ms = Time.get_ticks_msec()
		Engine.time_scale = 5.0
		_select_talent(0)
		player.set("money", TICKET_PRICE)
		_enter_dungeon()
		player.set("bot", true)


func _process(delta: float) -> void:
	camera.global_position = player.global_position + CAMERA_OFFSET
	camera.look_at(player.global_position + Vector3.UP, Vector3.UP)

	match state:
		"town":
			banner.text = _town_text()
		"arena_rest":
			rest_timer -= delta
			# Rest is free for the body and costly for the wallet: rent ticks while you recover.
			if wave >= 1:
				_charge_rent(ARENA_RENT_PER_SECOND, delta)
			banner.text = "PRACTICE ARENA - wave %d in %d...   resting heals you for free, but rent is $%d/s\n[Space] go now   [E] rest 10s longer   [H] healer   hold [M] meditate   [F] back to town" % [wave + 1, int(ceil(rest_timer)), int(ARENA_RENT_PER_SECOND)]
			if rest_timer <= 0.0:
				_start_wave()
		"arena_fight":
			banner.text = ""
			if get_tree().get_nodes_in_group("enemies").is_empty():
				player.call("end_fight")
				state = "arena_rest"
				rest_timer = 10.0
				player.call("note", "Wave %d cleared." % wave)
		"dungeon":
			_tick_dungeon(delta)

	_refresh_notebook()

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
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var code: Key = key.physical_keycode

	if state == "select":
		if code == KEY_X:
			hardcore = not hardcore
			_show_select()
			return
		var index: int = code - KEY_1
		if index >= 0 and index < TALENT_CHOICES.size():
			_select_talent(index)
			_enter_town()
		return

	if code == KEY_R:
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()
		return

	match state:
		"town":
			match code:
				KEY_1:
					if bool(player.call("can_afford", TICKET_PRICE)):
						player.call("charge", TICKET_PRICE)
						_enter_dungeon()
					else:
						player.call("note", "No one will sell you a ticket on that much debt.")
				KEY_2:
					_enter_arena()
				KEY_E:
					player.call("rest_night")
					player.call("charge", NIGHT_RENT)
					day += 1
				KEY_H:
					player.call("buy_healing")
		"arena_rest", "arena_fight":
			match code:
				KEY_Q:
					player.call("cast_bolt")
				KEY_T:
					player.call("try_ascend")
				KEY_SPACE:
					if state == "arena_rest":
						rest_timer = 0.0
				KEY_E:
					if state == "arena_rest":
						rest_timer += 10.0
						player.call("note", "You rest a while longer. The landlord notices.")
				KEY_H:
					if state == "arena_rest":
						player.call("buy_healing")
					else:
						player.call("note", "The healer won't come in here mid-fight.")
				KEY_F:
					if state == "arena_rest":
						_enter_town()
		"dungeon":
			match code:
				KEY_Q:
					player.call("cast_bolt")
				KEY_T:
					player.call("try_ascend")
				KEY_H:
					player.call("note", "No healer in here. The entrance is sealed.")
				KEY_F:
					if _pad_in_reach():
						_extract()
					elif pads.is_empty():
						player.call("note", "No exit yet. %d more walls." % maxi(0, GATE_AT - cleared))
					else:
						player.call("note", "Stand on a glowing exit to leave.")


# --- select / town --------------------------------------------------------------

func _show_select() -> void:
	var lines: Array[String] = ["A prime vestige waits. Ask it what power it holds.\n"]
	for i: int in TALENT_CHOICES.size():
		var t: Dictionary = TalentDB.get_talent(TALENT_CHOICES[i])
		lines.append("[%d]  %s\n      \"%s\"\n" % [i + 1, str(t.get("name", "?")), str(t.get("verse", ""))])
	lines.append("[X]  Hardcore (death is permanent): %s" % ("ON" if hardcore else "off - dying leaves you in debt instead"))
	banner.text = "\n".join(lines)


func _select_talent(index: int) -> void:
	player.call("set_talent", TALENT_CHOICES[index])


func _enter_town() -> void:
	_build_town()
	player.set("active", false)
	player.call("end_fight")
	player.global_position = Vector3.ZERO
	state = "town"


func _town_text() -> String:
	var mult: float = _repeat_mult()
	var lines: Array[String] = []
	lines.append("TOWN - day %d%s" % [day, "   (HARDCORE)" if hardcore else ""])
	if _last_payout > 0:
		lines.append("Last delve paid $%d." % _last_payout)
	lines.append("")
	lines.append("[1]  Buy an assault-passage ticket ($%d) and go in" % TICKET_PRICE)
	lines.append("       Rule card: solo. The entrance seals behind you. Clear %d of %d walls to unlock" % [GATE_AT, CHAMBERS])
	lines.append("       an exit. Pay is handed over only at the exit and grows with every wall.")
	lines.append("       Rent runs while you are inside. This passage now pays x%.2f (repeats pay less)." % mult)
	lines.append("[2]  Practice arena (free, kill bounties only)")
	lines.append("[E]  Rest the night - heals what a body can heal. Rent $%d." % NIGHT_RENT)
	lines.append("[H]  Healer - fast, priced by how deep the wound is; the only way to regrow a limb without a talent")
	lines.append("[R]  Start over with a new character")
	return "\n".join(lines)


func _repeat_mult() -> float:
	return maxf(REPEAT_FLOOR, pow(REPEAT_FACTOR, float(delves)))


# --- practice arena -------------------------------------------------------------

func _enter_arena() -> void:
	_new_level(0.0)
	_static_box(Vector3(0, -0.5, 0), Vector3(ARENA_HALF * 2.0, 1.0, ARENA_HALF * 2.0), Color(0.62, 0.53, 0.22))
	var wall_color := Color(0.3, 0.3, 0.34)
	var span: float = ARENA_HALF * 2.0 + 2.0
	_static_box(Vector3(0, 1.0, -ARENA_HALF - 0.5), Vector3(span, 2.0, 1.0), wall_color)
	_static_box(Vector3(0, 1.0, ARENA_HALF + 0.5), Vector3(span, 2.0, 1.0), wall_color)
	_static_box(Vector3(-ARENA_HALF - 0.5, 1.0, 0), Vector3(1.0, 2.0, span), wall_color)
	_static_box(Vector3(ARENA_HALF + 0.5, 1.0, 0), Vector3(1.0, 2.0, span), wall_color)
	for i: int in 90:
		var pos := Vector3.ZERO
		for attempt: int in 8:
			pos = Vector3(rng.randf_range(-ARENA_HALF + 1.5, ARENA_HALF - 1.5), 0.0, rng.randf_range(-ARENA_HALF + 1.5, ARENA_HALF - 1.5))
			if pos.length() > 3.0:
				break
		_spawn_scenery("bush" if i % 9 == 0 else "grass", pos)
	player.global_position = Vector3.ZERO
	player.set("active", true)
	wave = 0
	rest_timer = 4.0
	state = "arena_rest"


func _start_wave() -> void:
	wave += 1
	state = "arena_fight"
	player.call("start_fight")
	for i: int in 2 + wave:
		_spawn_arena_enemy("grunt")
	for i: int in wave / 3:
		_spawn_arena_enemy("brute")


func _spawn_arena_enemy(kind: String) -> void:
	var angle: float = rng.randf() * TAU
	_spawn_enemy(kind, Vector3(cos(angle), 0.0, sin(angle)) * (ARENA_HALF - 3.0), 1.0)


# --- assault passage ------------------------------------------------------------

func _enter_dungeon() -> void:
	# Rotated so the corridor runs straight "up" the isometric screen: W alone walks it.
	_new_level(45.0)
	var total: float = float(CHAMBERS + 1) * CH_LEN
	var mid_z: float = -total * 0.5
	var wall_color := Color(0.26, 0.26, 0.3)
	_static_box(Vector3(0, -0.5, mid_z), Vector3(CH_HALF_W * 2.0, 1.0, total), Color(0.5, 0.44, 0.22))
	_static_box(Vector3(-CH_HALF_W - 0.5, 1.0, mid_z), Vector3(1.0, 2.0, total + 2.0), wall_color)
	_static_box(Vector3(CH_HALF_W + 0.5, 1.0, mid_z), Vector3(1.0, 2.0, total + 2.0), wall_color)
	_static_box(Vector3(0, 1.0, 0.5), Vector3(CH_HALF_W * 2.0, 2.0, 1.0), wall_color)
	_static_box(Vector3(0, 1.0, -total - 0.5), Vector3(CH_HALF_W * 2.0, 2.0, 1.0), wall_color)

	var side_w: float = CH_HALF_W - GAP_HALF
	var side_x: float = GAP_HALF + side_w * 0.5
	for c: int in range(1, CHAMBERS + 1):
		var z: float = -float(c) * CH_LEN
		_static_box(Vector3(-side_x, 1.0, z), Vector3(side_w, 2.0, 1.0), wall_color)
		_static_box(Vector3(side_x, 1.0, z), Vector3(side_w, 2.0, 1.0), wall_color)
		if c >= 2:
			_add_barrier(c)

	for c: int in range(0, CHAMBERS + 1):
		var tufts: int = 14 if c == 0 else 7
		for i: int in tufts:
			var pos := Vector3(rng.randf_range(-CH_HALF_W + 1.0, CH_HALF_W - 1.0), 0.0,
				-float(c) * CH_LEN - rng.randf_range(1.5, CH_LEN - 1.5))
			_spawn_scenery("bush" if i == 0 else "grass", pos)

	player.global_position = level.to_global(Vector3(0.0, 0.0, -4.0))
	player.set("active", true)
	state = "dungeon"
	player.call("note", "You step through. Walk up the corridor (W).")


func _add_barrier(c: int) -> void:
	var b: StaticBody3D = _static_box(Vector3(0, 1.0, -float(c) * CH_LEN), Vector3(GAP_HALF * 2.0, 2.0, 0.6), Color(0.75, 0.15, 0.15))
	barriers[c] = b


func _tick_dungeon(delta: float) -> void:
	var local: Vector3 = level.to_local(player.global_position)
	var depth: float = -local.z
	var fighting: bool = current > cleared

	if not fighting:
		var next_c: int = cleared + 1
		if next_c <= CHAMBERS and depth > float(next_c) * CH_LEN + 1.5:
			if not sealed:
				sealed = true
				_add_barrier(1)
				player.call("note", "Stone grinds shut behind you. The entrance is sealed.")
			_activate(next_c)
			_set_dungeon_banner()
			return
		if sealed:
			# The town clock does not stop because you are underground.
			_charge_rent(DUNGEON_RENT_PER_SECOND, delta)
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
		var leave_now: bool = _bot_scenario == "gate" or cleared >= CHAMBERS
		if leave_now and _pad_in_reach():
			_extract()
			return
		var goal_local: Vector3
		if leave_now and not pads.is_empty():
			goal_local = level.to_local(pads.back().global_position)
		elif absf(local.x) > 0.8:
			goal_local = Vector3(0.0, 0.0, local.z)
		else:
			goal_local = Vector3(0.0, 0.0, -(float(cleared + 1) * CH_LEN + 4.0))
		player.set("bot_goal", level.to_global(goal_local))


func _activate(c: int) -> void:
	current = c
	var strength: float = LATE_STRENGTH if c > GATE_AT else 1.0
	var kinds: Array[String] = []
	for i: int in 2 + c / 2:
		kinds.append("grunt")
	for i: int in maxi(0, (c - 1) / 3):
		kinds.append("brute")
	if c == GATE_AT or c == CHAMBERS:
		kinds.append("commander")
	for kind: String in kinds:
		var local := Vector3(rng.randf_range(-CH_HALF_W + 2.0, CH_HALF_W - 2.0), 0.0,
			rng.randf_range(-float(c + 1) * CH_LEN + 2.0, -float(c) * CH_LEN - 7.0))
		_spawn_enemy(kind, local, strength)
	player.call("start_fight")
	player.call("note", "Wall %d of %d." % [c, CHAMBERS])
	if _shot_dungeon and c == 2:
		Engine.time_scale = 1.0
		player.set("bot", false)
		_shot_countdown = 25


func _on_wall_cleared() -> void:
	cleared = current
	bank += STAGE_VALUE * cleared
	player.call("end_fight")
	var next_c: int = cleared + 1
	if barriers.has(next_c):
		(barriers[next_c] as Node).queue_free()
		barriers.erase(next_c)
	if cleared >= GATE_AT:
		_spawn_pad(cleared)
	player.call("note", "Wall %d cleared. $%d banked - yours only if you walk out." % [cleared, bank])


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
	pad.position = Vector3(0.0, 0.06, -(float(c) + 0.5) * CH_LEN)
	level.add_child(pad)
	pads.append(pad)


func _pad_in_reach() -> bool:
	for pad: Node3D in pads:
		var d: Vector3 = pad.global_position - player.global_position
		d.y = 0.0
		if d.length() <= EXIT_REACH:
			return true
	return false


func _payout_now() -> int:
	var bonus: float = FULL_CLEAR_BONUS if cleared == CHAMBERS else 1.0
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
	_enter_town()


func _set_dungeon_banner() -> void:
	if not sealed:
		banner.text = "ASSAULT PASSAGE - the antechamber.\nWalk up the corridor (W) to begin; the entrance seals behind you. Last chance to cut grass in peace."
	elif current > cleared:
		banner.text = "Wall %d of %d" % [current, CHAMBERS]
	elif cleared >= CHAMBERS:
		banner.text = "All %d walls down. [F] on a glowing exit to leave with $%d (full-clear bonus included)." % [CHAMBERS, _payout_now()]
	elif cleared >= GATE_AT:
		banner.text = "Wall %d cleared. [F] on a glowing exit to leave with $%d - or push on: wall %d banks $%d more.\nRent is $%d/s while you stand here." % [cleared, _payout_now(), cleared + 1, STAGE_VALUE * (cleared + 1), int(DUNGEON_RENT_PER_SECOND)]
	else:
		banner.text = "Wall %d cleared. $%d banked, but no exit until wall %d.\nRest if you need it - rent is $%d/s." % [cleared, bank, GATE_AT, int(DUNGEON_RENT_PER_SECOND)]


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
		banner.text = "You died. Hardcore: that was the only life this character had.\n\n[R] to begin again."
		return
	var lost: int = bank if state == "dungeon" else 0
	_bot_died = true
	_bot_finished = _bot_mode
	player.call("revive_in_debt", RESCUE_FEE)
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
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.08, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.75, 0.85)
	env.ambient_light_energy = 0.55
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, 30.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 24.0
	camera.far = 200.0
	add_child(camera)
	camera.current = true


func _build_player() -> void:
	player = PlayerScript.new()
	add_child(player)
	player.global_position = Vector3.ZERO
	player.connect("died", _on_player_died)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var panel := ColorRect.new()
	panel.color = Color(0.05, 0.05, 0.07, 0.72)
	panel.position = Vector2(12, 12)
	panel.size = Vector2(560, 560)
	layer.add_child(panel)

	notebook = Label.new()
	notebook.position = Vector2(24, 20)
	notebook.size = Vector2(540, 545)
	notebook.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notebook.add_theme_font_size_override("font_size", 16)
	layer.add_child(notebook)

	banner = Label.new()
	banner.position = Vector2(620, 40)
	banner.size = Vector2(940, 600)
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner.add_theme_font_size_override("font_size", 20)
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	banner.add_theme_constant_override("outline_size", 8)
	layer.add_child(banner)


func _where() -> String:
	match state:
		"town":
			return "Town, day %d" % day
		"arena_rest", "arena_fight":
			return "Arena, wave %d" % wave
		"dungeon":
			return "Passage: %d/%d walls, $%d banked" % [cleared, CHAMBERS, bank]
	return ""


func _refresh_notebook() -> void:
	if str(player.get("talent_id")) == "":
		notebook.text = "- NOTEBOOK -\n\n(blank pages)"
		return
	var b: Body = player.get("body")
	var t: Dictionary = player.get("talent")
	var lines: Array[String] = []
	lines.append("- NOTEBOOK -")
	lines.append("Talent: %s   (%d-star)" % [str(t.get("name", "?")), int(player.get("stars"))])
	lines.append("  \"%s\"" % str(t.get("verse", "")))
	lines.append("")
	lines.append("Body:  superficial %d/%d   structural %d/%d   catastrophic %d/%d" % [
		int(ceil(float(b.hp["superficial"]))), int(float(b.max_hp["superficial"])),
		int(ceil(float(b.hp["structural"]))), int(float(b.max_hp["structural"])),
		int(ceil(float(b.hp["catastrophic"]))), int(float(b.max_hp["catastrophic"])),
	])
	var pending: float = player.call("pending_damage")
	if pending > 0.0:
		lines.append("  ...%d damage still owed" % int(pending))
	var lock: String = "  LOCKED" if bool(player.get("reflux_locked")) else ""
	lines.append("Essence: %d/%d  (satellite +%d/s)     Reflux [water]: %d%s" % [
		int(float(player.get("essence"))), int(float(player.get("essence_max"))),
		int(float(player.get("satellite_rate"))), int(float(player.get("reflux"))), lock,
	])
	if bool(player.get("arm_right_lost")):
		lines.append("Striking arm: LOST - off-hand blows only, no overcharge")
	else:
		lines.append("Striking arm: %d%%" % int(float(player.get("arm_right"))))
	var cash: int = int(player.get("money"))
	lines.append("%s        %s" % ["DEBT: $%d" % -cash if cash < 0 else "Money: $%d" % cash, _where()])
	if str(player.get("talent_id")) == "one_percent_lifesteal":
		lines.append("Heal points drawn so far: %.1f" % float(player.get("heal_points_total")))
	lines.append("")
	lines.append(str(player.call("aura_read")))
	var proven: Array = player.get("discoveries")
	if not proven.is_empty():
		lines.append("")
		for p: String in proven:
			lines.append("Proven: %s" % p)
	lines.append("")
	for l: String in player.get("log_lines"):
		lines.append("> %s" % l)
	lines.append("")
	lines.append("WASD move   LMB strike   hold RMB overcharge (wears out your arm)")
	lines.append("Q water bolt   hold M meditate   F use exit   R start over")
	notebook.text = "\n".join(lines)


# --- test harness ---------------------------------------------------------------

func _tick_bot_report() -> void:
	var elapsed: int = Time.get_ticks_msec() - _bot_started_ms
	if _bot_finished and state == "town":
		var ok := false
		if _bot_scenario == "die":
			var money_now: int = int(player.get("money"))
			ok = not bool(player.get("dead")) and money_now == _bot_money_before - RESCUE_FEE and _last_payout == 0
			print("BOT[die]: alive=%s money %d -> %d (fee %d) payout=%d state=%s -> %s" % [
				str(not bool(player.get("dead"))), _bot_money_before, money_now, RESCUE_FEE, _last_payout, state, "PASS" if ok else "FAIL"])
		else:
			var walls: int = CHAMBERS if _bot_scenario == "full" else GATE_AT
			var banked: int = 0
			for c: int in range(1, walls + 1):
				banked += STAGE_VALUE * c
			var expected: int = int(float(banked) * (FULL_CLEAR_BONUS if walls == CHAMBERS else 1.0))
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
