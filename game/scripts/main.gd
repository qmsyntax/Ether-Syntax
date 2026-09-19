extends Node3D
## Prototype arena: talent select -> rest -> wave -> rest -> ...
## Everything is built in code so the project stays plain text.

const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const SceneryScript := preload("res://scripts/scenery.gd")

const ARENA_HALF := 18.0
const CAMERA_OFFSET := Vector3(12.0, 12.0, 12.0)
const TALENT_CHOICES: Array[String] = [
	"one_percent_lifesteal", "tenth_strike", "grudge", "glass_hour", "debt_of_pain", "furnace_gut",
]

var player: CharacterBody3D
var camera: Camera3D
var notebook: Label
var banner: Label

var state := "select"
var wave := 0
var rest_timer := 0.0
var rng := RandomNumberGenerator.new()

var _shot_mode := false
var _frames := 0


func _ready() -> void:
	rng.randomize()
	_build_world()
	_build_scenery()
	_build_player()
	_build_hud()
	_show_select()
	if OS.get_cmdline_user_args().has("--shot"):
		_shot_mode = true
		_select_talent(0)
		rest_timer = 0.5


func _process(delta: float) -> void:
	camera.global_position = player.global_position + CAMERA_OFFSET
	camera.look_at(player.global_position + Vector3.UP, Vector3.UP)

	match state:
		"rest":
			rest_timer -= delta
			banner.text = "Wave %d in %d...   [H] pay the healer   hold [M] to meditate   cut the grass" % [wave + 1, int(ceil(rest_timer))]
			if rest_timer <= 0.0:
				_start_wave()
		"fight":
			banner.text = ""
			if get_tree().get_nodes_in_group("enemies").is_empty():
				player.call("end_fight")
				state = "rest"
				rest_timer = 10.0
				player.call("note", "Wave %d cleared." % wave)

	_refresh_notebook()

	if _shot_mode:
		_frames += 1
		if _frames == 260:
			_save_shot()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var code: Key = key.physical_keycode
	if state == "select":
		var index: int = code - KEY_1
		if index >= 0 and index < TALENT_CHOICES.size():
			_select_talent(index)
		return
	match code:
		KEY_R:
			get_tree().reload_current_scene()
		KEY_Q:
			player.call("cast_bolt")
		KEY_T:
			player.call("try_ascend")
		KEY_H:
			if state == "rest":
				player.call("buy_healing")
			else:
				player.call("note", "The healer won't come in here mid-fight.")


# --- flow ---------------------------------------------------------------------

func _show_select() -> void:
	var lines: Array[String] = ["A prime vestige waits. Ask it what power it holds.\n"]
	for i: int in TALENT_CHOICES.size():
		var t: Dictionary = TalentDB.get_talent(TALENT_CHOICES[i])
		lines.append("[%d]  %s\n      \"%s\"\n" % [i + 1, str(t.get("name", "?")), str(t.get("verse", ""))])
	lines.append("\nThe vestige will not explain further. You find out by bleeding.")
	banner.text = "\n".join(lines)


func _select_talent(index: int) -> void:
	player.call("set_talent", TALENT_CHOICES[index])
	player.set("active", true)
	state = "rest"
	rest_timer = 4.0


func _start_wave() -> void:
	wave += 1
	state = "fight"
	player.call("start_fight")
	var grunts: int = 2 + wave
	var brutes: int = wave / 3
	for i: int in grunts:
		_spawn_enemy("grunt")
	for i: int in brutes:
		_spawn_enemy("brute")


func _spawn_enemy(kind: String) -> void:
	# Build and place the enemy before it enters the tree: a body that exists at the
	# origin for even one step can pick the player up as a "moving platform" passenger.
	var e: CharacterBody3D = EnemyScript.new()
	e.call("setup", kind, player)
	var angle: float = rng.randf() * TAU
	e.position = Vector3(cos(angle), 0.0, sin(angle)) * (ARENA_HALF - 3.0)
	add_child(e)


func _on_player_died() -> void:
	state = "dead"
	banner.text = "You died on wave %d.\n\n[R] to try again with a different talent." % wave


# --- construction -------------------------------------------------------------

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

	# Golden-grass realm floor.
	_static_box(Vector3(0, -0.5, 0), Vector3(ARENA_HALF * 2.0, 1.0, ARENA_HALF * 2.0), Color(0.62, 0.53, 0.22))
	var wall_color := Color(0.3, 0.3, 0.34)
	var span: float = ARENA_HALF * 2.0 + 2.0
	_static_box(Vector3(0, 1.0, -ARENA_HALF - 0.5), Vector3(span, 2.0, 1.0), wall_color)
	_static_box(Vector3(0, 1.0, ARENA_HALF + 0.5), Vector3(span, 2.0, 1.0), wall_color)
	_static_box(Vector3(-ARENA_HALF - 0.5, 1.0, 0), Vector3(1.0, 2.0, span), wall_color)
	_static_box(Vector3(ARENA_HALF + 0.5, 1.0, 0), Vector3(1.0, 2.0, span), wall_color)


func _static_box(pos: Vector3, size: Vector3, color: Color) -> void:
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
	add_child(sb)
	sb.global_position = pos


func _build_scenery() -> void:
	for i: int in 90:
		_spawn_scenery("bush" if i % 9 == 0 else "grass")


func _spawn_scenery(kind: String) -> void:
	var s: Node3D = SceneryScript.new()
	add_child(s)
	var pos := Vector3.ZERO
	for attempt: int in 8:
		pos = Vector3(rng.randf_range(-ARENA_HALF + 1.5, ARENA_HALF - 1.5), 0.0, rng.randf_range(-ARENA_HALF + 1.5, ARENA_HALF - 1.5))
		if pos.length() > 3.0:
			break
	s.global_position = pos
	s.call("setup", kind)


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
	panel.size = Vector2(560, 400)
	layer.add_child(panel)

	notebook = Label.new()
	notebook.position = Vector2(24, 20)
	notebook.size = Vector2(540, 390)
	notebook.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notebook.add_theme_font_size_override("font_size", 16)
	layer.add_child(notebook)

	banner = Label.new()
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.position = Vector2(620, 40)
	banner.size = Vector2(920, 600)
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner.add_theme_font_size_override("font_size", 20)
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	banner.add_theme_constant_override("outline_size", 8)
	layer.add_child(banner)


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
	lines.append("Money: $%d        Wave: %d" % [int(player.get("money")), wave])
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
	lines.append("WASD move   LMB strike   hold RMB overcharge (hurts you)")
	lines.append("Q water bolt   hold M meditate   H healer (between waves)   R restart")
	notebook.text = "\n".join(lines)


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
