extends Node3D
## Standalone art preview: every procedural model under the game's light and isometric camera.
##
##   godot --path game res://tests/art_preview.tscn                 (look around; Esc quits)
##   godot --path game res://tests/art_preview.tscn -- --shot       -> shots/art-preview.png
##   godot --path game res://tests/art_preview.tscn -- --shot=close -> shots/art-close.png
##
## Screenshots need a windowed run (headless has no framebuffer).

const FLOOR_COLOR := Color(0.5, 0.44, 0.22)
const SCREEN_RIGHT := Vector3(0.70710678, 0.0, -0.70710678)
const SCREEN_UP := Vector3(-0.70710678, 0.0, -0.70710678)
const FACING := Vector3(1.0, 0.0, 0.35)
const SHOT_FRAMES := 40

var _camera: Camera3D
var _entries: Array[Dictionary] = []
var _shot_mode: String = ""
var _frames: int = 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--shot":
			_shot_mode = "preview"
		elif arg.begins_with("--shot="):
			_shot_mode = arg.get_slice("=", 1)
	_build_world()
	if _shot_mode == "close":
		_layout_close()
	else:
		_layout_all()


func _process(delta: float) -> void:
	for entry: Dictionary in _entries:
		var rig: ModelRig = entry["rig"]
		rig.animate(delta, float(entry["speed"]), bool(entry["attacking"]))
	if _shot_mode != "":
		_frames += 1
		if _frames == SHOT_FRAMES:
			_save_shot()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_tree().quit()


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
	sun.rotation_degrees = Vector3(-52, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)

	var floor_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(70, 0.2, 70)
	floor_mesh.mesh = box
	floor_mesh.position.y = -0.1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = FLOOR_COLOR
	floor_mesh.material_override = mat
	add_child(floor_mesh)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 24.0
	_camera.far = 200.0
	add_child(_camera)
	_aim_camera(Vector3.ZERO)
	_camera.current = true


func _aim_camera(target: Vector3) -> void:
	_camera.position = target + Vector3(12, 12, 12)
	_camera.look_at(target + Vector3.UP, Vector3.UP)


func _layout_all() -> void:
	var step: float = 4.0
	var kinds: Array[String] = ["grunt", "brute", "commander"]
	var column: int = 0
	for kind: String in kinds:
		for variant: int in 3:
			var rig: ModelRig = Models.enemy(kind)
			var tag: String = kind
			var speed: float = 0.0
			match variant:
				0:
					speed = rig.stride_speed
					tag += " (walking)"
				1:
					rig.set_highlight(1)
					tag += " highlight 1"
				2:
					rig.set_windup(true)
					tag += " windup"
			_place(rig, _spot(column, 9, step, 3.6), tag, speed, false)
			column += 1

	var near: Array[Dictionary] = []
	var hero: ModelRig = Models.player()
	near.append({"node": hero, "tag": "player (running)", "speed": hero.stride_speed})
	var one_arm: ModelRig = Models.player()
	one_arm.set_part_visible("arm_right", false)
	near.append({"node": one_arm, "tag": "player, arm lost", "speed": 0.0})
	var striker: ModelRig = Models.player()
	near.append({"node": striker, "tag": "player striking", "speed": 0.0, "attacking": true})
	var corpse: ModelRig = Models.enemy("grunt")
	corpse.set_dead_look()
	near.append({"node": corpse, "tag": "dead look", "speed": 0.0})
	var flashed: ModelRig = Models.enemy("brute")
	flashed.flash(600.0)
	near.append({"node": flashed, "tag": "hit flash", "speed": 0.0})
	near.append({"node": Models.enemy("unknown"), "tag": "fallback", "speed": 0.0})
	near.append({"node": Models.scenery("grass"), "tag": "grass", "speed": 0.0})
	near.append({"node": Models.scenery("bush"), "tag": "bush", "speed": 0.0})
	near.append({"node": Models.pickup(false), "tag": "pickup", "speed": 0.0})
	near.append({"node": Models.pickup(true), "tag": "pickup (equippable)", "speed": 0.0})
	for i: int in near.size():
		var item: Dictionary = near[i]
		_place(item["node"] as Node3D, _spot(i, near.size(), 3.8, -4.2), str(item["tag"]), float(item["speed"]), bool(item.get("attacking", false)))


func _layout_close() -> void:
	_camera.size = 8.0
	_aim_camera(Vector3(0, 0.55, 0))
	var step: float = 3.1
	_place(Models.player(), _spot(0, 4, step, 0.0) + SCREEN_RIGHT * 0.5, "player", 0.0, false)
	_place(Models.enemy("grunt"), _spot(1, 4, step, 0.0), "grunt", 0.0, false)
	_place(Models.enemy("brute"), _spot(2, 4, step, 0.0), "brute", 0.0, false)
	_place(Models.enemy("commander"), _spot(3, 4, step, 0.0) + SCREEN_RIGHT * 0.4, "commander", 0.0, false)


func _spot(index: int, count: int, step: float, depth: float) -> Vector3:
	return SCREEN_RIGHT * ((float(index) - float(count - 1) * 0.5) * step) + SCREEN_UP * depth


func _place(node: Node3D, at: Vector3, tag: String, speed: float, attacking: bool) -> void:
	node.position = at
	var rig: ModelRig = node as ModelRig
	if rig != null and rig.has_part("leg_left") or tag == "fallback":
		node.rotation.y = atan2(-FACING.x, -FACING.z)
	add_child(node)
	if rig != null:
		_entries.append({"rig": rig, "speed": speed, "attacking": attacking})
	var label := Label3D.new()
	label.text = tag
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 30
	label.outline_size = 8
	label.pixel_size = 0.012 * (_camera.size / 24.0)
	label.position = at - SCREEN_UP * (1.5 * _camera.size / 24.0 + 0.5) + Vector3(0, 0.05, 0)
	add_child(label)


func _save_shot() -> void:
	var dir: String = ProjectSettings.globalize_path("res://").path_join("../shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(dir)
	var file: String = "art-close.png" if _shot_mode == "close" else "art-preview.png"
	var image: Image = get_viewport().get_texture().get_image()
	var err: Error = image.save_png(dir.path_join(file))
	print("art_preview: saved %s (%s)" % [dir.path_join(file), error_string(err)])
	get_tree().quit()
