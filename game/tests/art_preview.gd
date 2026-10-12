extends Node3D
## Standalone art preview: every procedural model under the game's light and isometric camera.
##
##   godot --path game res://tests/art_preview.tscn                    (look around; Esc quits)
##   godot --path game res://tests/art_preview.tscn -- --shot          -> shots/art-preview.png  (game scale, everything)
##   ... -- --shot=close    -> shots/art-close.png     the four characters up close
##   ... -- --shot=back     -> shots/art-back.png      the same four seen from behind
##   ... -- --shot=motion   -> shots/art-motion.png    idle / mid-walk x2 / wind-up / mid-strike per character
##   ... -- --shot=weapons  -> shots/art-weapons.png   the player with each weapon, and with the arm lost
##   ... -- --shot=props    -> shots/art-props.png     scenery and pickups up close
##   ... -- --shot=nether   -> shots/art-nether.png    projection, wisps, every construct at every tier
##   ... -- --shot=nether-close -> shots/art-nether-close.png  projection, wisp and the six vestiges
##   godot --headless --path game res://tests/art_preview.tscn -- --stats   prints triangles / draw calls
##
## By default the stage uses the RECOMMENDED environment (dark earth floor, cool dim ambient,
## warm low sun, filmic tonemap, SSAO, soft glow, light fog - the GRIM_* constants below).
## Add `--env=game` to any run to see the models under the values main.gd uses today.
##
## Screenshots need a windowed run (headless has no framebuffer). In shot modes the poses are
## stepped with a fixed delta and frozen mid-walk / mid-strike so the image is repeatable.

const FLOOR_COLOR := Color(0.5, 0.44, 0.22)
const GRIM_FLOOR := Color(0.27, 0.245, 0.2)
const GRIM_SKY := Color(0.03, 0.035, 0.045)
const GRIM_AMBIENT := Color(0.5, 0.56, 0.7)
const GRIM_AMBIENT_ENERGY := 0.6
const GRIM_SUN_COLOR := Color(1.0, 0.87, 0.72)
const GRIM_SUN_ENERGY := 1.35
const GRIM_SUN_ROTATION := Vector3(-44, 38, 0)
const NETHER_FLOOR := Color(0.07, 0.06, 0.17)
const NETHER_SKY := Color(0.03, 0.025, 0.09)
const SCREEN_RIGHT := Vector3(0.70710678, 0.0, -0.70710678)
const SCREEN_UP := Vector3(-0.70710678, 0.0, -0.70710678)
const FACING := Vector3(1.0, 0.0, 0.35)
const GAME_CAMERA_SIZE := 19.0
const STEP := 1.0 / 60.0
const SHOT_FRAMES := 120
const CONCEPTS: Array[String] = ["acceleration", "piercing", "compression", "tension", "reach", "stillness"]
const WEAPONS: Array[String] = ["iron_knuckles", "serrated_dagger", "invader_cleaver", "commander_blade", "unknown_item"]

var _camera: Camera3D
var _env: Environment
var _floor_mat: StandardMaterial3D
var _entries: Array[Dictionary] = []
var _shot_mode: String = ""
var _frames: int = 0
var _facing: Vector3 = FACING
var _game_env: bool = false


func _ready() -> void:
	var stats: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--shot":
			_shot_mode = "preview"
		elif arg.begins_with("--shot="):
			_shot_mode = arg.get_slice("=", 1)
		elif arg == "--stats":
			stats = true
		elif arg == "--env=game":
			_game_env = true
	if stats:
		_print_stats()
		get_tree().quit()
		return
	_build_world()
	match _shot_mode:
		"close":
			_layout_close()
		"back":
			_facing = Vector3(-1.0, 0.0, -0.6)
			_layout_close()
		"motion":
			_layout_motion()
		"weapons":
			_layout_weapons()
		"props":
			_layout_props()
		"nether":
			_layout_nether()
		"nether-close":
			_layout_nether_close()
		_:
			_layout_all()


func _process(delta: float) -> void:
	var step: float = STEP if _shot_mode != "" else delta
	for entry: Dictionary in _entries:
		var left: int = entry["frames"]
		if left == 0:
			continue
		if left > 0:
			entry["frames"] = left - 1
		(entry["rig"] as ModelRig).animate(step, float(entry["speed"]), bool(entry["attacking"]))
	if _shot_mode != "":
		_frames += 1
		if _frames == SHOT_FRAMES:
			_save_shot()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_tree().quit()


func _build_world() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.07, 0.08, 0.1)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.75, 0.75, 0.85)
	_env.ambient_light_energy = 0.55
	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)

	var floor_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(90, 0.2, 90)
	floor_mesh.mesh = box
	floor_mesh.position.y = -0.1
	_floor_mat = StandardMaterial3D.new()
	_floor_mat.albedo_color = FLOOR_COLOR
	floor_mesh.material_override = _floor_mat
	add_child(floor_mesh)

	if not _game_env:
		_floor_mat.albedo_color = GRIM_FLOOR
		_floor_mat.roughness = 1.0
		_env.background_color = GRIM_SKY
		_env.ambient_light_color = GRIM_AMBIENT
		_env.ambient_light_energy = GRIM_AMBIENT_ENERGY
		_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		_env.ssao_enabled = true
		_env.ssao_radius = 0.8
		_env.ssao_intensity = 1.5
		_env.tonemap_exposure = 1.15
		_env.glow_enabled = true
		_env.glow_intensity = 0.6
		_env.glow_bloom = 0.03
		_env.glow_hdr_threshold = 1.0
		_env.fog_enabled = true
		_env.fog_light_color = Color(0.1, 0.11, 0.14)
		_env.fog_density = 0.006
		_env.adjustment_enabled = true
		_env.adjustment_contrast = 1.08
		_env.adjustment_saturation = 0.92
		sun.light_color = GRIM_SUN_COLOR
		sun.light_energy = GRIM_SUN_ENERGY
		sun.rotation_degrees = GRIM_SUN_ROTATION

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = GAME_CAMERA_SIZE
	_camera.far = 200.0
	add_child(_camera)
	_aim_camera(Vector3.ZERO)
	_camera.current = true


func _aim_camera(target: Vector3) -> void:
	_camera.position = target + Vector3(12, 12, 12)
	_camera.look_at(target + Vector3.UP, Vector3.UP)


## Turns the whole stage into the Netherecho: dark blue-violet floor and sky.
func _nether_world() -> void:
	_floor_mat.albedo_color = NETHER_FLOOR
	_env.background_color = NETHER_SKY


## A dark strip of Netherecho floor laid along a row of the gold stage.
func _nether_strip(depth: float, width: float, length: float) -> void:
	var slab := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(length, 0.02, width)
	slab.mesh = box
	slab.position = SCREEN_UP * depth + Vector3(0, 0.005, 0)
	slab.rotation.y = atan2(-SCREEN_RIGHT.z, SCREEN_RIGHT.x)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = NETHER_FLOOR
	slab.material_override = mat
	add_child(slab)


# ---------------------------------------------------------------- layouts

func _layout_all() -> void:
	var kinds: Array[String] = ["grunt", "brute", "commander"]
	var column: int = 0
	for kind: String in kinds:
		for variant: int in 3:
			var rig: ModelRig = Models.enemy(kind)
			var tag: String = kind
			match variant:
				0:
					tag += " walking"
					_place(rig, _spot(column, 9, 3.4, 6.4), tag, rig.stride_speed, false, _walk_frames(rig, 0))
				1:
					rig.set_highlight(1)
					_place(rig, _spot(column, 9, 3.4, 6.4), tag + " highlight 1", 0.0, false)
				2:
					rig.set_windup(true)
					_place(rig, _spot(column, 9, 3.4, 6.4), tag + " windup", 0.0, false, 40)
			column += 1

	var near: Array[Dictionary] = []
	var hero: ModelRig = Models.player()
	near.append({"node": hero, "tag": "player running", "speed": hero.stride_speed, "frames": _walk_frames(hero, 0)})
	var one_arm: ModelRig = Models.player()
	one_arm.set_part_visible("arm_right", false)
	near.append({"node": one_arm, "tag": "arm lost"})
	var striker: ModelRig = Models.player()
	striker.set_weapon(Models.weapon("invader_cleaver"))
	near.append({"node": striker, "tag": "cleaver strike", "attacking": true, "frames": 14})
	var sword: ModelRig = Models.player()
	sword.set_weapon(Models.weapon("commander_blade"))
	near.append({"node": sword, "tag": "blade"})
	var target: ModelRig = Models.enemy("grunt")
	target.set_highlight(2)
	near.append({"node": target, "tag": "highlight 2"})
	var corpse: ModelRig = Models.enemy("grunt")
	corpse.set_dead_look()
	near.append({"node": corpse, "tag": "dead look"})
	var flashed: ModelRig = Models.enemy("brute")
	flashed.flash(600.0)
	near.append({"node": flashed, "tag": "hit flash"})
	near.append({"node": Models.enemy("unknown"), "tag": "fallback"})
	near.append({"node": Models.scenery("grass"), "tag": "grass"})
	near.append({"node": Models.scenery("grass"), "tag": "grass"})
	near.append({"node": Models.scenery("bush"), "tag": "bush"})
	near.append({"node": Models.pickup(false), "tag": "pickup"})
	near.append({"node": Models.pickup(true), "tag": "equippable"})
	for i: int in near.size():
		var item: Dictionary = near[i]
		_place(item["node"] as Node3D, _spot(i, near.size(), 2.5, 0.4), str(item["tag"]), float(item.get("speed", 0.0)), bool(item.get("attacking", false)), int(item.get("frames", -1)))

	_nether_strip(-6.0, 5.6, 40.0)
	var ghosts: Array[Dictionary] = [
		{"node": Models.projection(), "tag": "projection"},
		{"node": Models.wisp("water"), "tag": "wisp water"},
		{"node": Models.wisp(""), "tag": "wisp"},
	]
	for concept: String in CONCEPTS:
		ghosts.append({"node": Models.construct("vestige", concept), "tag": concept})
	ghosts.append({"node": Models.construct("remnant", "tension"), "tag": "remnant"})
	ghosts.append({"node": Models.construct("spirit", "tension"), "tag": "spirit"})
	ghosts.append({"node": Models.construct("spirit", "reach"), "tag": "spirit reach"})
	for i: int in ghosts.size():
		var item: Dictionary = ghosts[i]
		_place(item["node"] as Node3D, _spot(i, ghosts.size(), 2.7, -6.0), str(item["tag"]), 0.0, false)


func _layout_close() -> void:
	_camera.size = 8.0
	_aim_camera(Vector3(0, 0.55, 0))
	var step: float = 3.1
	_place(Models.player(), _spot(0, 4, step, 0.0) + SCREEN_RIGHT * 0.5, "player", 0.0, false)
	_place(Models.enemy("grunt"), _spot(1, 4, step, 0.0), "grunt", 0.0, false)
	_place(Models.enemy("brute"), _spot(2, 4, step, 0.0), "brute", 0.0, false)
	_place(Models.enemy("commander"), _spot(3, 4, step, 0.0) + SCREEN_RIGHT * 0.4, "commander", 0.0, false)


func _layout_motion() -> void:
	_camera.size = 13.0
	_aim_camera(Vector3(0, 0.3, 0))
	var kinds: Array[String] = ["player", "grunt", "brute", "commander"]
	var depths: Array[float] = [7.6, 3.4, -1.6, -7.6]
	for row: int in kinds.size():
		var kind: String = kinds[row]
		for pose: int in 5:
			var rig: ModelRig = Models.player() if kind == "player" else Models.enemy(kind)
			var at: Vector3 = _spot(pose, 5, 4.2, depths[row])
			match pose:
				0:
					_place(rig, at, kind + " idle", 0.0, false)
				1:
					_place(rig, at, "mid-walk A", rig.stride_speed, false, _walk_frames(rig, 0))
				2:
					_place(rig, at, "mid-walk B", rig.stride_speed, false, _walk_frames(rig, 1))
				3:
					rig.set_windup(true)
					_place(rig, at, "wind-up", 0.0, false, 40)
				4:
					_place(rig, at, "mid-strike", 0.0, true, 14)


func _layout_weapons() -> void:
	_camera.size = 7.0
	_aim_camera(Vector3(0, 0.5, 0))
	var bare: ModelRig = Models.player()
	_place(bare, _spot(0, 6, 2.05, 2.6), "bare hands", 0.0, false)
	for i: int in WEAPONS.size():
		var rig: ModelRig = Models.player()
		rig.set_weapon(Models.weapon(WEAPONS[i]))
		_place(rig, _spot(i + 1, 6, 2.05, 2.6), WEAPONS[i] if i < 4 else "unknown -> club", 0.0, false)
	var poses: Array[Dictionary] = [
		{"weapon": "invader_cleaver", "tag": "cleaver wind-up", "windup": true, "frames": 40},
		{"weapon": "invader_cleaver", "tag": "cleaver strike", "attacking": true, "frames": 14},
		{"weapon": "commander_blade", "tag": "blade strike", "attacking": true, "frames": 14},
		{"weapon": "serrated_dagger", "tag": "dagger, running", "walk": true},
		{"weapon": "commander_blade", "tag": "arm lost (blade set)", "lost": true},
		{"weapon": "", "tag": "arm lost, running", "lost": true, "walk": true},
	]
	for i: int in poses.size():
		var pose: Dictionary = poses[i]
		var rig: ModelRig = Models.player()
		if str(pose["weapon"]) != "":
			rig.set_weapon(Models.weapon(str(pose["weapon"])))
		if bool(pose.get("lost", false)):
			rig.set_part_visible("arm_right", false)
		if bool(pose.get("windup", false)):
			rig.set_windup(true)
		var walking: bool = pose.get("walk", false)
		var frames: int = _walk_frames(rig, 0) if walking else int(pose.get("frames", -1))
		_place(rig, _spot(i, 6, 2.05, -2.6), str(pose["tag"]), rig.stride_speed if walking else 0.0, bool(pose.get("attacking", false)), frames)


func _layout_props() -> void:
	_camera.size = 6.0
	_aim_camera(Vector3(0, 0.2, 0))
	var items: Array[Dictionary] = [
		{"node": Models.scenery("grass"), "tag": "grass"},
		{"node": Models.scenery("grass"), "tag": "grass"},
		{"node": Models.scenery("grass"), "tag": "grass"},
		{"node": Models.scenery("bush"), "tag": "bush"},
		{"node": Models.scenery("bush"), "tag": "bush"},
		{"node": Models.pickup(false), "tag": "pickup"},
		{"node": Models.pickup(true), "tag": "equippable"},
	]
	for i: int in items.size():
		_place(items[i]["node"] as Node3D, _spot(i, items.size(), 1.45, 1.5), str(items[i]["tag"]), 0.0, false)
	for i: int in WEAPONS.size():
		var item: Node3D = Models.weapon(WEAPONS[i])
		var stand := Node3D.new()
		stand.add_child(item)
		item.position = Vector3(0, 0.45, 0)
		item.rotation = Vector3(0.9, 0, 0)
		_place(stand, _spot(i, WEAPONS.size(), 1.9, -2.0), WEAPONS[i], 0.0, false)
		stand.rotation.y = atan2(-SCREEN_RIGHT.x, -SCREEN_RIGHT.z)


func _layout_nether() -> void:
	_nether_world()
	_camera.size = 13.0
	_aim_camera(Vector3(0, 0.6, 0))
	var tiers: Array[String] = ["spirit", "remnant", "vestige"]
	var depths: Array[float] = [6.0, 0.6, -3.6]
	for row: int in tiers.size():
		for i: int in CONCEPTS.size():
			var rig: ModelRig = Models.construct(tiers[row], CONCEPTS[i])
			_place(rig, _spot(i, 6, 3.5, depths[row]), "%s %s" % [tiers[row], CONCEPTS[i]], 0.0, false)
	var front: Array[Dictionary] = [
		{"node": Models.projection(), "tag": "projection"},
		{"node": Models.projection(), "tag": "projection moving", "walk": true},
		{"node": Models.projection(), "tag": "projection strike", "attacking": true, "frames": 14},
		{"node": Models.wisp("water"), "tag": "wisp (water)"},
		{"node": Models.wisp("stone"), "tag": "wisp"},
		{"node": Models.wisp("water"), "tag": "wisp (water)"},
		{"node": Models.construct("vestige", "nonsense"), "tag": "unknown concept"},
		{"node": Models.construct("spirit", "nonsense"), "tag": "unknown, spirit"},
	]
	for i: int in front.size():
		var item: Dictionary = front[i]
		var rig: ModelRig = item["node"] as ModelRig
		var walking: bool = item.get("walk", false)
		_place(item["node"] as Node3D, _spot(i, front.size(), 2.6, -7.6), str(item["tag"]), rig.stride_speed if walking else 0.0, bool(item.get("attacking", false)), 40 if walking else int(item.get("frames", -1)))


func _layout_nether_close() -> void:
	_nether_world()
	_camera.size = 5.6
	_aim_camera(Vector3(0, 0.25, 0))
	var windup: ModelRig = Models.construct("vestige", "reach")
	windup.set_windup(true)
	var struck: ModelRig = Models.construct("vestige", "piercing")
	struck.flash(600.0)
	var lit: ModelRig = Models.construct("vestige", "compression")
	lit.set_highlight(1)
	var back: Array[Dictionary] = [
		{"node": Models.projection(), "tag": "projection"},
		{"node": Models.wisp("water"), "tag": "wisp (water)"},
		{"node": Models.wisp(""), "tag": "wisp"},
		{"node": windup, "tag": "reach wind-up", "frames": 40},
		{"node": Models.construct("vestige", "reach"), "tag": "reach strike", "attacking": true, "frames": 14},
		{"node": struck, "tag": "flash"},
		{"node": lit, "tag": "highlight 1"},
	]
	for i: int in back.size():
		var item: Dictionary = back[i]
		_place(item["node"] as Node3D, _spot(i, back.size(), 1.35, 2.3), str(item["tag"]), 0.0, bool(item.get("attacking", false)), int(item.get("frames", -1)))
	for i: int in CONCEPTS.size():
		_place(Models.construct("vestige", CONCEPTS[i]), _spot(i, 6, 1.55, -1.6), CONCEPTS[i], 0.0, false)


# ---------------------------------------------------------------- helpers

func _spot(index: int, count: int, step: float, depth: float) -> Vector3:
	return SCREEN_RIGHT * ((float(index) - float(count - 1) * 0.5) * step) + SCREEN_UP * depth


## Frames of walking (at the rig's full speed, fixed step) that end at the peak of a stride:
## `half` 0 stops with one leg forward, 1 with the other.
func _walk_frames(rig: ModelRig, half: int) -> int:
	var per_frame: float = rig.stride_speed * rig.stride_rate * STEP
	var target: float = PI * 0.5 + PI * float(half)
	while target / per_frame < 26.0:
		target += TAU
	return roundi(target / per_frame)


## Adds a model to the stage. `frames` < 0 animates it forever; otherwise it is stepped that
## many frames and then frozen (shot modes only freeze; live preview keeps cycling).
func _place(node: Node3D, at: Vector3, tag: String, speed: float, attacking: bool, frames: int = -1) -> void:
	node.position = at
	var rig: ModelRig = node as ModelRig
	var is_prop: bool = rig != null and (rig.name.begins_with("Scenery") or rig.name.begins_with("Pickup"))
	if rig != null and not is_prop:
		node.rotation.y = atan2(-_facing.x, -_facing.z)
	add_child(node)
	if rig != null:
		_entries.append({"rig": rig, "speed": speed, "attacking": attacking, "frames": frames if _shot_mode != "" else -1})
	var label := Label3D.new()
	label.text = tag
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 30
	label.outline_size = 8
	label.pixel_size = 0.0085 * (_camera.size / GAME_CAMERA_SIZE)
	label.position = at - SCREEN_UP * (1.4 * _camera.size / GAME_CAMERA_SIZE + 0.4) + Vector3(0, 0.05, 0)
	add_child(label)


func _print_stats() -> void:
	var rigs: Dictionary[String, ModelRig] = {
		"player": Models.player(),
		"player + commander_blade": Models.player(),
		"grunt": Models.enemy("grunt"),
		"brute": Models.enemy("brute"),
		"commander": Models.enemy("commander"),
		"grass": Models.scenery("grass") as ModelRig,
		"bush": Models.scenery("bush") as ModelRig,
		"pickup": Models.pickup(false) as ModelRig,
		"pickup equippable": Models.pickup(true) as ModelRig,
		"projection": Models.projection(),
	}
	rigs["player + commander_blade"].set_weapon(Models.weapon("commander_blade"))
	for id: String in WEAPONS:
		rigs["weapon " + id] = Models.weapon(id) as ModelRig
	for tier: String in ["vestige", "remnant", "spirit"]:
		for concept: String in CONCEPTS:
			rigs["%s %s" % [tier, concept]] = Models.construct(tier, concept)
	for key: String in rigs:
		var rig: ModelRig = rigs[key]
		print("ART STATS %-28s tris %5d  draws %2d  height %.2f  radius %.2f" % [key, rig.triangle_count(), rig.draw_call_count(), rig.height, rig.radius])
		rig.free()
	var start: int = Time.get_ticks_usec()
	for i: int in 50:
		Models.enemy("commander").free()
	print("ART STATS stamping a cached commander: %.2f ms each" % (float(Time.get_ticks_usec() - start) / 50000.0))


func _save_shot() -> void:
	var dir: String = ProjectSettings.globalize_path("res://").path_join("../shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(dir)
	var file: String = "art-%s%s.png" % [_shot_mode, "-gameenv" if _game_env else ""]
	var image: Image = get_viewport().get_texture().get_image()
	var err: Error = image.save_png(dir.path_join(file))
	print("art_preview: saved %s (%s)" % [dir.path_join(file), error_string(err)])
	get_tree().quit()
