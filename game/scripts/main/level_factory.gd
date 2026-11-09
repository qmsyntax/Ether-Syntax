class_name LevelFactory
extends RefCounted
## Builds what the game stands in: the world (environment, sun, the Netherecho node, the camera) once at boot,
## and each level - a fresh level node with its navigation, the biome's floor, walls, props and cuttable scenery,
## colliders, enemies (and their reinforcements), the bodies built ahead, and the character's corpses. The
## level controllers (MainTown, MainField, MainPassage, MainArena) and the builders (TownBuilder, ZoneBuilder)
## lay a level out through it. Moved out of main.gd as it was (docs/architecture/main-split.md).

var main: Main


func _init(of: Main) -> void:
	main = of


## The effects' shaders held from boot (_hold_effect_shaders).
var _held_materials: Array[Material] = []
## Bodies still to build ahead, one a frame (_prebuild_bodies, _tick_prebuild).
var _prebuild_queue: Array[String] = []


func _build_world() -> void:
	main._env = Environment.new()
	main._env.background_mode = Environment.BG_COLOR
	main._env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Grim, low-key look (art pass 3): filmic, a little haze, contact shadows, restrained bloom.
	main._env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	main._env.tonemap_exposure = 1.15
	# light bounced off the ground and walls into the shade, so shadows are not flat black
	main._env.ssil_enabled = true
	main._env.ssil_radius = 4.0
	main._env.ssil_intensity = 0.8
	main._env.ssao_enabled = true
	main._env.ssao_radius = 0.8
	main._env.ssao_intensity = 1.5
	main._env.glow_enabled = true
	main._env.glow_intensity = 0.6
	main._env.glow_bloom = 0.03
	main._env.glow_hdr_threshold = 1.0
	main._env.fog_enabled = true
	main._env.fog_density = 0.006
	main._env.adjustment_enabled = true
	main._env.adjustment_contrast = 1.08
	main._env.adjustment_saturation = 0.92
	var world_env := WorldEnvironment.new()
	world_env.environment = main._env
	main.add_child(world_env)

	main._sun = DirectionalLight3D.new()
	main._sun.rotation_degrees = Vector3(-44.0, 38.0, 0.0)
	main._sun.shadow_enabled = true
	main.add_child(main._sun)
	main.nether_part._set_nether_look(false)

	main.nether = Netherecho.new()
	main.add_child(main.nether)
	main.nether.connect("entered", main._on_nether_entered)
	main.nether.connect("exited", main._on_nether_exited)
	main.nether.connect("projection_destroyed", main._on_projection_destroyed)

	main.camera = Camera3D.new()
	main.camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	main.camera.size = GameData.num("camera", "ortho_size")
	main.camera.far = 300.0
	main.camera.near = 0.1
	main._cam_zoom_target = GameSettings.zoom_start() if main._plays() else GameData.num("camera", "zoom_default")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--zoom="):              # screenshots at a chosen zoom
			main._cam_zoom_target = clampf(float(arg.get_slice("=", 1)), 0.0, 1.0)
	main.cam_zoom = main._cam_zoom_target
	main.add_child(main.camera)
	main.camera.current = true


# --- the effects' shaders, held for the whole game (perf, 2026-11-08) -----------------------------
# Skill and status effects (blast rings, zones, clouds, arcs, shots, lures, auras) each make their own
# StandardMaterial3D. Godot shares one shader among the materials with the same features and FREES it
# when the last of them goes - so with no blast on the ground, the next Cave-In compiled its ring's
# shader again, a ~20 ms frame every time (docs/perf/baseline-2026-11-08.md). One material of each
# feature set the effects use is kept here from the start, so those shaders are made once, at boot,
# and never thrown away. A new effect with a new combination of these switches belongs in the list.

func _hold_effect_shaders() -> void:
	# [unshaded, alpha, emission, additive, both faces]
	var sets: Array = [
		[true, true, false, false, false],     # rings, zones, bursts, auras, patches
		[true, true, true, false, false],      # glowing zones, lures, arcs, the risen wash
		[false, true, false, false, false],    # blood pools, seed traps
		[false, true, true, false, false],     # the Netherecho's glowing pieces
		[false, false, true, false, false],    # shots, rods, lamps, stone glow
		[true, false, false, false, false],    # flat marks
		[true, true, false, true, false],      # a real body's glow (RealCharacter)
		[true, true, false, false, true],      # the navigation debug mesh
	]
	for s: Array in sets:
		var m := StandardMaterial3D.new()
		if bool(s[0]):
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if bool(s[1]):
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.emission_enabled = bool(s[2])
		if bool(s[3]):
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		if bool(s[4]):
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.get_rid()                          # a material makes its shader when first asked for it: ask now
		_held_materials.append(m)


func _new_level(yaw_degrees: float) -> void:
	if main.player != null:
		main.player.drop_stones()           # stone does not follow you to a new place
		for group: String in ["ground_zones", "ground_rods", "blasts", "censer_bursts"]:
			for left: Node in main.get_tree().get_nodes_in_group(group):
				left.queue_free()
	if main.level != null:
		for group: String in ["enemies", "hittable"]:
			for n: Node in main.get_tree().get_nodes_in_group(group):
				if main.level.is_ancestor_of(n):
					n.remove_from_group(group)
		main.level.queue_free()
	main.level = Node3D.new()
	main.level.rotation_degrees = Vector3(0.0, yaw_degrees, 0.0)
	main.add_child(main.level)
	# the spirit layer shares the level's frame, so its sites line up with the chambers
	main.nether.clear()
	main.nether.rotation_degrees = Vector3(0.0, yaw_degrees, 0.0)
	main.sealed = false
	main.current = 0
	main.cleared = 0
	main.bank = 0
	main.barriers.clear()
	main.gates.clear()
	main.pads.clear()
	main._rent_accum = 0.0
	_add_level_nav()


## Pathfinding for the level about to be built: a LevelNav at the level's origin bakes its
## navigation meshes from the colliders once the building is done (the frame after), and again
## whenever a collider is added or taken away (a doorway sealed or opened). See LevelNav.
func _add_level_nav() -> void:
	var nav := LevelNav.new()
	nav.name = "Nav"
	main.level.add_child(nav)


# --- biomes -------------------------------------------------------------------------------

## Set the level's biome: one of `choices` at random, unless one is forced.
func _use_biome(choices: Variant, allow_force: bool = true) -> void:
	var pool: Array = choices if choices is Array else [choices]
	main.biome = str(pool[main.rng.randi() % pool.size()])
	if allow_force and main.forced_biome != "" and Biomes.ids().has(main.forced_biome):
		main.biome = main.forced_biome
	if not Biomes.ids().has(main.biome):
		main.biome = "scrubland"
	main._biome = Biomes.info(main.biome)
	main.nether_part._set_nether_look(main.nether.active)


## Ground: something to stand on, and the biome's floor drawn over it.
func _biome_floor(centre: Vector3, size: Vector2) -> void:
	_static_box(Vector3(centre.x, -0.5, centre.z), Vector3(size.x, 1.0, size.y), Color.BLACK, false)
	var ground: Node3D = Biomes.floor(main.biome, size)
	ground.position = Vector3(centre.x, 0.0, centre.z)
	main.level.add_child(ground)


## A wall run `length` long centred on `centre`, facing into the level along +Z turned by `yaw`
## degrees. Returns its collider.
func _biome_wall(centre: Vector3, length: float, yaw: float, height: float) -> StaticBody3D:
	var sb: StaticBody3D = _static_box(Vector3(centre.x, 1.0, centre.z), Vector3(length, 2.0, 1.0), Color.BLACK, false)
	sb.rotation_degrees.y = yaw
	var wall: Node3D = Biomes.wall(main.biome, length, height)
	wall.position = Vector3(centre.x, 0.0, centre.z)
	wall.rotation_degrees.y = yaw
	main.level.add_child(wall)
	return sb


## Scatter `count` decorative props over a patch `half` metres each way from `centre`. Props
## that block are kept to the strips along x = +-half.x; `keep_clear` (local z values) are lines
## nothing may stand near, such as a doorway.
func _scatter_props(centre: Vector3, half: Vector2, count: int, keep_clear: Array = []) -> void:
	var cfg: Dictionary = GameData.balance["biomes"]
	var table: Array = main._biome.get("scatter", [])
	if table.is_empty():
		return
	var total := 0.0
	for e: Dictionary in table:
		total += float(e["weight"])
	var lights_left: int = int(cfg["lights_per_chamber"])
	var placed_blockers: Array = []        # [side, z, radius] - kept apart so they never form a pocket
	for i: int in count:
		var roll: float = main.rng.randf() * total
		var kind: String = str((table[0] as Dictionary)["kind"])
		for e: Dictionary in table:
			roll -= float(e["weight"])
			if roll < 0.0:
				kind = str(e["kind"])
				break
		var meta: Dictionary = Biomes.prop_meta(main.biome, kind)
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
				side = 1.0 if main.rng.randf() < 0.5 else -1.0
				x = side * (half.x - solid * 0.5)
			else:
				x = main.rng.randf_range(-half.x + r, half.x - r)
			pos = centre + Vector3(x, 0.0, main.rng.randf_range(-half.y + r, half.y - r))
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
		var prop: Node3D = Biomes.prop(main.biome, kind)
		prop.position = pos
		prop.rotation.y = main.rng.randf() * TAU
		main.level.add_child(prop)
		if blocks:
			var sb := StaticBody3D.new()
			var col := CollisionShape3D.new()
			var shape := CylinderShape3D.new()
			shape.radius = solid
			shape.height = 2.0
			col.shape = shape
			sb.add_child(col)
			sb.position = pos + Vector3.UP
			main.level.add_child(sb)


## Things you can cut down: the old grass and bushes in scrubland, the kit's own cuttables elsewhere.
func _spawn_cuttable(index: int, local_pos: Vector3) -> void:
	if main.biome == "scrubland":
		_spawn_scenery("bush" if index == 0 else "grass", local_pos)
		return
	var kinds: Array = []
	for kind: Variant in main._biome.get("props", []):
		if bool(Biomes.prop_meta(main.biome, str(kind)).get("cuttable", false)):
			kinds.append(str(kind))
	if kinds.is_empty() or index % 2 == 1:           # fewer than grass: these are bigger things
		return
	var s: Node3D = Main.SceneryScript.new()
	s.call("setup_prop", main.biome, str(kinds[main.rng.randi() % kinds.size()]))
	s.position = local_pos
	main.level.add_child(s)


func _spawn_scenery(kind: String, local_pos: Vector3) -> void:
	var s: Node3D = Main.SceneryScript.new()
	s.call("setup", kind)
	s.position = local_pos
	main.level.add_child(s)


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
	main.level.add_child(sb)
	return sb


func _spawn_enemy(kind: String, local_pos: Vector3, strength: float) -> void:
	# Build and place before it enters the tree: a body that exists at the origin for even one
	# step can pick the player up as a "moving platform" passenger.
	var e: Enemy = Enemy.new()
	e.setup(kind, main.player, strength)
	e.position = local_pos
	main.level.add_child(e)
	e.connect("reinforcements", main._on_reinforcements)     # the node's handler, as before (FieldCamps connects it too)


## An enemy called for help: the kinds it named arrive in a ring round it, inside the room.
func _on_reinforcements(who: Node, kinds: Array) -> void:
	if main.level == null or not is_instance_valid(who):
		return
	var centre: Vector3 = main.level.to_local((who as Node3D).global_position)
	var strength: float = main.late_strength if (main.state == "dungeon" and main.current > main.gate_at) else 1.0
	for i: int in kinds.size():
		var angle: float = TAU * float(i) / float(maxi(1, kinds.size())) + 0.6
		var spot: Vector3 = centre + Vector3(cos(angle), 0.0, sin(angle)) * 3.5
		if main.state == "dungeon":
			spot.x = clampf(spot.x, -main.ch_half_w + 1.5, main.ch_half_w - 1.5)
			spot.z = clampf(spot.z, -float(main.current + 1) * main.ch_len + 1.5, -float(main.current) * main.ch_len - 1.5)
		else:
			spot.x = clampf(spot.x, -main.arena_half + 2.0, main.arena_half - 2.0)
			spot.z = clampf(spot.z, -main.arena_half + 2.0, main.arena_half - 2.0)
		_spawn_enemy(str(kinds[i]), spot, strength)
	main.hud.announce("REINFORCEMENTS")


# --- bodies built ahead (perf, 2026-11-08; docs/perf/baseline-2026-11-08.md) ----------------------
# A real body costs ~2 ms to build once its kind's model and textures are loaded, and far more the first
# time a kind appears (the female body's model, the kind's garments and props): a whole wall built in the
# frame it woke stalled that frame for ~0.4 s. So a level loads every kind it can put up as it is built
# (_warm_bodies), and the bodies of the next wall or wave are built ahead, one a frame, while you walk or
# rest (_prebuild_bodies); Models.enemy hands out a ready one. Nothing about the enemies changes.

## The kinds these enemies may call for help (enemies.json "calls"), so their bodies can wait ready.
func _calls_of(kinds: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for kind: String in kinds:
		for k2: Variant in GameData.enemy(kind).get("calls", []):
			out.append(str(k2))
	return out


## Load every kind in `kinds` now (in a level's own loading frame): one body of each is built and kept
## ready, which brings in its model and textures.
func _warm_bodies(kinds: Array[String]) -> void:
	var seen: Dictionary = {}
	for kind: String in kinds:
		if seen.has(kind):
			continue
		seen[kind] = true
		if Models.prebuilt_count(kind) == 0:
			Models.prebuild(kind)


## Have bodies for `kinds` (one entry per body) ready before they are needed: what is not already
## built or queued is queued, and built one a frame (_tick_prebuild).
func _prebuild_bodies(kinds: Array[String]) -> void:
	var want: Dictionary = {}
	for kind: String in kinds:
		if Models.is_real_enemy(kind):
			want[kind] = int(want.get(kind, 0)) + 1
	for kind: String in want:
		var short: int = int(want[kind]) - Models.prebuilt_count(kind) - _prebuild_queue.count(kind)
		for i: int in short:
			_prebuild_queue.append(kind)


func _tick_prebuild() -> void:
	if not _prebuild_queue.is_empty():
		Models.prebuild(_prebuild_queue.pop_front())


## Your corpses that lie in this kind of level, laid back where they fell.
func _place_corpses(where: String) -> void:
	var CorpseScript: GDScript = load("res://scripts/corpse.gd")
	for c: Dictionary in main.player.corpses:
		if str(c.get("where", "")) != where:
			continue
		var pos: Array = c.get("pos", [0.0, 0.0, 0.0])
		var body_node: Node3D = CorpseScript.new()
		body_node.call("setup", str(c["id"]), main.player.look)
		body_node.position = Vector3(float(pos[0]), 0.0, float(pos[2]))
		main.level.add_child(body_node)
