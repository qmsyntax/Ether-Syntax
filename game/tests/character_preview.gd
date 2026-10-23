extends Node
## Contact sheets of the real character bodies (scripts/art/real_character.gd), for looking at
## them without playing. Each cell is its own little world (game lighting, a ground disc):
##
##   godot --path game res://tests/character_preview.tscn -- --sheet=<name> --cells="<cell>;<cell>;..."
##       [--size=360x600] [--cols=6]                                  -> shots/char-<name>.png
##
## A cell is comma-separated key=value pairs, all optional:
##   sex, body, skin, face, hair, hair_color, band, coat, accent   look options (PlayerLook ids)
##   outfit=patched_coat+oilcloth_hood        equipped item ids
##   weapon=invader_cleaver                   in hand;  arm=lost  the right forearm gone
##   anim=walk  t=0.4 (seconds) or f=0.5 (fraction of the clip)   a frozen frame
##   yaw=30  (degrees the figure turns)       cam=full | head | hands | game (the game's camera)
## --motion=<anim> with --frames=8 and one cell spec: that clip's frames left to right.

const GAME_OFFSET := Vector3(12.0, 12.0, 12.0)

var _views: Array[SubViewport] = []


func _ready() -> void:
	var sheet := "sheet"
	var cells_arg := ""
	var size := Vector2i(360, 600)
	var cols := 6
	var motion := ""
	var frames := 8
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--sheet="):
			sheet = arg.get_slice("=", 1)
		elif arg.begins_with("--cells="):
			cells_arg = arg.substr(8)
		elif arg.begins_with("--size="):
			var wh: PackedStringArray = arg.get_slice("=", 1).split("x")
			size = Vector2i(int(wh[0]), int(wh[1]))
		elif arg.begins_with("--cols="):
			cols = int(arg.get_slice("=", 1))
		elif arg.begins_with("--motion="):
			motion = arg.get_slice("=", 1)
		elif arg.begins_with("--frames="):
			frames = int(arg.get_slice("=", 1))
	var specs: Array[Dictionary] = []
	for c: String in cells_arg.split(";", false):
		specs.append(_parse(c))
	if motion != "":
		var base: Dictionary = specs[0] if not specs.is_empty() else {}
		specs.clear()
		for i: int in frames:
			var s: Dictionary = base.duplicate()
			s["anim"] = motion
			s["f"] = str(float(i) / float(frames))
			specs.append(s)
		cols = frames
	if specs.is_empty():
		specs.append({})
	for s: Dictionary in specs:
		_views.append(_make_cell(s, size))
	for i: int in 45:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var rows: int = int(ceil(float(_views.size()) / float(cols)))
	var out := Image.create(size.x * mini(cols, _views.size()), size.y * rows, false, Image.FORMAT_RGBA8)
	for i: int in _views.size():
		var img: Image = _views[i].get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		out.blit_rect(img, Rect2i(Vector2i.ZERO, size), Vector2i((i % cols) * size.x, (i / cols) * size.y))
	var dir: String = ProjectSettings.globalize_path("res://").path_join("../shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var path: String = dir.path_join("char-%s.png" % sheet)
	print("CHARPREVIEW saved ", path, " ", out.get_size(), " err=", out.save_png(path))
	get_tree().quit()


func _parse(text: String) -> Dictionary:
	var d: Dictionary = {}
	for kv: String in text.split(",", false):
		var at: int = kv.find("=")
		if at > 0:
			d[kv.substr(0, at).strip_edges()] = kv.substr(at + 1).strip_edges()
	return d


func _make_cell(spec: Dictionary, size: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.11, 0.105, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.44, 0.5)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.15
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssil_enabled = true
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.92
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-44.0, 38.0, 0.0)
	sun.shadow_enabled = true
	vp.add_child(sun)
	var ground := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 2.5
	disc.bottom_radius = 2.5
	disc.height = 0.02
	ground.mesh = disc
	ground.position.y = -0.01
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.33, 0.29, 0.24)
	gm.roughness = 0.95
	ground.material_override = gm
	vp.add_child(ground)

	var look: Dictionary = {}
	for key: String in PlayerLook.KEYS:
		if spec.has(key):
			look[key] = spec[key]
	if spec.has("grip"):                       # grip=rx:ry:rz[:px:py:pz] overrides data/wardrobe.json
		var g: PackedStringArray = str(spec["grip"]).split(":")
		var right: Dictionary = (GameData.wardrobe["grip"] as Dictionary)["right"]
		if spec.has("weapon") and ((GameData.wardrobe["grip"] as Dictionary).get("items", {}) as Dictionary).has(str(spec["weapon"])):
			right = GameData.wardrobe["grip"]["items"][str(spec["weapon"])]["right"]
		right["rot_deg"] = [float(g[0]), float(g[1]), float(g[2])]
		if g.size() >= 6:
			right["pos"] = [float(g[3]), float(g[4]), float(g[5])]
	if spec.has("grip_rest"):                  # grip_rest=rx:ry:rz[:px:py:pz] overrides the stand's rest grip
		var gr: PackedStringArray = str(spec["grip_rest"]).split(":")
		var rests: Dictionary = ((GameData.wardrobe["stances"] as Dictionary)["stand"] as Dictionary)["grip_rest"]
		var rest: Dictionary = rests["right"]
		if spec.has("weapon") and (rests.get("items", {}) as Dictionary).has(str(spec["weapon"])):
			rest = rests["items"][str(spec["weapon"])]["right"]
		rest["rot_deg"] = [float(gr[0]), float(gr[1]), float(gr[2])]
		if gr.size() >= 6:
			rest["pos"] = [float(gr[3]), float(gr[4]), float(gr[5])]
	var rig: ModelRig = Models.enemy(str(spec["kind"])) if spec.has("kind") else CharacterLook.build(look)
	vp.add_child(rig)
	rig.rotation_degrees.y = float(spec.get("yaw", "0"))
	var equipped: Dictionary = {}
	for id: String in str(spec.get("outfit", "")).split("+", false):
		equipped[str(GameData.item(id).get("slot", id))] = id
	if rig.has_method("set_outfit"):
		rig.call("set_outfit", equipped)
	if spec.has("bare") and rig.has_method("set_bare"):
		rig.call("set_bare", true)
	if spec.has("skinsrc") and rig.has_method("set_skin_source"):
		rig.call("set_skin_source", str(spec["skinsrc"]))
	if str(spec.get("arm", "")) == "lost":
		rig.set_part_visible("arm_right", false)
	if spec.has("weapon"):
		rig.set_weapon(Models.weapon(str(spec["weapon"])))
	if spec.has("anim") and rig.has_method("pose_at"):
		var t: float = float(spec.get("t", "-1"))
		rig.call("pose_at", str(spec["anim"]), t, float(spec.get("f", "-1")))

	if spec.has("lengths"):                    # lengths=1 prints every clip's length
		var ap: AnimationPlayer = rig.get("_player")
		if ap != null:
			for a: StringName in ap.get_animation_list():
				print("CLIP %s %.2f s" % [a, ap.get_animation(a).length])
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.current = true
	var mode: String = str(spec.get("cam", "full"))
	var h: float = rig.height
	match mode:
		"head":
			cam.fov = 22.0
			cam.position = Vector3(0.3, h - 0.2, -1.25)
			cam.look_at(Vector3(0.0, h - 0.24, 0.0), Vector3.UP)
		"hands":
			cam.fov = 30.0
			cam.position = Vector3(-0.9, 1.1, -1.4)
			cam.look_at(Vector3(-0.2, 0.9, 0.0), Vector3.UP)
		"feet":
			cam.fov = 26.0
			cam.position = Vector3(0.4, 0.45, -1.4)
			cam.look_at(Vector3(0.0, 0.12, 0.0), Vector3.UP)
		"hips":
			cam.fov = 24.0
			cam.position = Vector3(0.25, 0.85, -1.5)
			cam.look_at(Vector3(0.0, h * 0.46, 0.0), Vector3.UP)
		"upper":
			cam.fov = 28.0
			cam.position = Vector3(0.6, 1.35, -2.0)
			cam.look_at(Vector3(0.0, 1.05, 0.0), Vector3.UP)
		"game":
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = 4.2
			cam.position = GAME_OFFSET
			cam.look_at(Vector3(0.0, 0.85, 0.0), Vector3.UP)
		_:
			var k: float = maxf(1.0, h / 1.72)            # step back for the big ones
			cam.fov = 30.0
			cam.position = Vector3(0.9 * k, h * 0.62, -3.6 * k)
			cam.look_at(Vector3(0.0, h * 0.5, 0.0), Vector3.UP)
	return vp
