class_name BiomeStage
extends RefCounted
## Sample scenes for the environment kits: a dressed 30 x 30 m room per biome and a labelled
## contact sheet of its props. Used by tests/art_preview; also a worked example of driving
## the Biomes API (floor, walls on two sides, a gate, the staged props, a scatter).

const ROOM := 30.0


## Applies a biome's sky, ambient, fog and sun to an Environment and a DirectionalLight3D.
static func light(id: String, env: Environment, sun: DirectionalLight3D) -> void:
	var i: Dictionary = Biomes.info(id)
	env.background_mode = Environment.BG_COLOR
	env.background_color = i["sky"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = i["ambient"]
	env.ambient_light_energy = i["ambient_energy"]
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.15
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.5
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = i["fog_color"]
	env.fog_density = i["fog_density"]
	sun.light_color = i["sun_color"]
	sun.light_energy = i["sun_energy"]
	sun.rotation_degrees = i["sun_rotation"]
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0


## The dressed sample room. Returns its root; "triangles", "draws" and "lights" are set as
## metadata on it.
static func room(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Stage_" + id
	var info: Dictionary = Biomes.info(id)
	var half: float = ROOM * 0.5
	root.add_child(Biomes.floor(id, Vector2(ROOM + 8.0, ROOM + 8.0)))
	var back: Node3D = Biomes.wall(id, ROOM + 1.0, 3.6)
	back.position = Vector3(0, 0, -half - 0.5)
	root.add_child(back)
	var left: Node3D = Biomes.wall(id, ROOM + 1.0, 3.6)
	left.position = Vector3(-half - 0.5, 0, 0)
	left.rotation_degrees.y = 90.0
	root.add_child(left)
	var seal: Node3D = Biomes.gate(id, 4.0)
	seal.position = Vector3(6.0, 0, 6.5)
	seal.rotation_degrees.y = 40.0
	root.add_child(seal)
	var open_seal: Node3D = Biomes.gate(id, 4.0)
	open_seal.position = Vector3(-7.0, 0, 11.5)
	open_seal.rotation_degrees.y = -20.0
	root.add_child(open_seal)
	(open_seal as EnvGate).set_open(true, true)
	var taken: Array[Vector3] = [Vector3(6.0, 2.6, 6.5), Vector3(-7.0, 2.6, 11.5)]
	var variant: int = 0
	for entry: Array in info.get("stage", []):
		var p: Node3D = Biomes.prop_variant(id, str(entry[0]), variant)
		variant += 1
		p.position = Vector3(float(entry[1]), 0, float(entry[2]))
		p.rotation_degrees.y = float(entry[3])
		root.add_child(p)
		taken.append(Vector3(p.position.x, float(p.get_meta("radius")), p.position.z))
	# Filler decoration from the scatter weights, kept clear of everything already placed.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var scatter: Array = info.get("scatter", [])
	var total: float = 0.0
	for s: Dictionary in scatter:
		total += float(s["weight"])
	var placed: int = 0
	var tries: int = 0
	while placed < 46 and tries < 600 and total > 0.0:
		tries += 1
		var pick: float = rng.randf() * total
		var kind: String = ""
		for s: Dictionary in scatter:
			pick -= float(s["weight"])
			if pick <= 0.0:
				kind = str(s["kind"])
				break
		var p: Node3D = Biomes.prop_variant(id, kind, rng.randi() % Biomes.VARIANTS)
		var at := Vector3(rng.randf_range(-half + 1.0, half - 1.0), 0, rng.randf_range(-half + 1.0, half - 1.0))
		var radius: float = p.get_meta("radius")
		var clear: bool = true
		for t: Vector3 in taken:
			if Vector2(at.x - t.x, at.z - t.z).length() < radius + t.y + 0.4:
				clear = false
				break
		if not clear:
			p.free()
			continue
		p.position = at
		p.rotation_degrees.y = rng.randf_range(0.0, 360.0)
		root.add_child(p)
		taken.append(Vector3(at.x, radius, at.z))
		placed += 1
	_count(root)
	return root


## Every prop kind of a biome in a labelled grid (labels are Label3D children).
static func sheet(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Sheet_" + id
	root.add_child(Biomes.floor(id, Vector2(60, 60)))
	var kinds: Array = Biomes.info(id)["props"]
	var per_row: int = 6
	var right := Vector3(0.70710678, 0, -0.70710678)
	var up := Vector3(-0.70710678, 0, -0.70710678)
	for i: int in kinds.size():
		var col: int = i % per_row
		var row: int = i / per_row
		var at: Vector3 = right * ((float(col) - float(per_row - 1) * 0.5) * 5.4) + up * (7.5 - float(row) * 7.6)
		var p: Node3D = Biomes.prop_variant(id, str(kinds[i]), 0)
		p.position = at
		p.rotation_degrees.y = -45.0 + 180.0 + 25.0
		root.add_child(p)
		var second: Node3D = Biomes.prop_variant(id, str(kinds[i]), 1)
		second.position = at + right * (float(p.get_meta("radius")) + float(second.get_meta("radius")) + 0.3) + up * 0.6
		second.rotation_degrees.y = 200.0
		if float(p.get_meta("radius")) < 1.2:
			root.add_child(second)
		else:
			second.free()
		var label := Label3D.new()
		label.text = "%s\nr %.1f  h %.1f%s%s%s" % [str(kinds[i]), float(p.get_meta("radius")), float(p.get_meta("height")), "  blocks" if bool(p.get_meta("blocks")) else "", "  cuttable" if bool(p.get_meta("cuttable")) else "", "  light" if bool(p.get_meta("light")) else ""]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.font_size = 28
		label.outline_size = 8
		label.pixel_size = 0.0085
		label.position = at - up * 2.6 + Vector3(0, 0.05, 0)
		root.add_child(label)
	_count(root)
	return root


static func _count(root: Node3D) -> void:
	var tris: int = 0
	var draws: int = 0
	var lights: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children():
			stack.append(child)
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var mesh: Mesh = (node as MeshInstance3D).mesh
			for s: int in mesh.get_surface_count():
				draws += 1
				var arrays_len: int = mesh.surface_get_array_len(s) if mesh is ArrayMesh else 0
				var index_len: int = mesh.surface_get_array_index_len(s) if mesh is ArrayMesh else 0
				tris += (index_len if index_len > 0 else arrays_len) / 3 if mesh is ArrayMesh else 12
		elif node is OmniLight3D:
			lights += 1
	root.set_meta("triangles", tris)
	root.set_meta("draws", draws)
	root.set_meta("lights", lights)
