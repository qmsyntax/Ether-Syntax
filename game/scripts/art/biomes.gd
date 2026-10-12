class_name Biomes
extends RefCounted
## Environment kits: for each biome a floor, walls, a chamber gate, a set of props and the
## lighting that suits them. Everything is procedural and original to this project.
##
##   var ground := Biomes.floor("dungeon", Vector2(30, 30))
##   var torch := Biomes.prop("dungeon", "sconce")      # meta: radius, height, blocks, cuttable, light
##   var seal: EnvGate = Biomes.gate("dungeon", 4.0);  seal.set_open(true)
##
## Props are baked once per (biome, kind, variant) to a single mesh and drawn with the one
## shared EnvKit.prop_material(), so copies are cheap and MultiMesh-friendly: use
## prop_mesh() + prop_meta() to instance them yourself.

## How many different versions of each prop kind are baked.
const VARIANTS := 3
## Suggested ceiling for prop lights visible at once (they are unshadowed omni lights).
const MAX_LIGHTS_ON_SCREEN := 8

static var _meshes: Dictionary[String, ArrayMesh] = {}
static var _metas: Dictionary[String, Dictionary] = {}
static var _walls: Dictionary[String, Dictionary] = {}


## Every biome id, in the order they were built.
static func ids() -> Array[String]:
	return ["scrubland", "dungeon", "snow", "swamp", "mountain", "city"]


## A biome's label, colours, lighting, prop kinds and scatter weights (see the class docs of
## each Biome* script). Also carries "stage": a sample arrangement [kind, x, z, yaw_degrees]
## for a 30 x 30 m room, used by the preview. Unknown ids get the first biome.
static func info(id: String) -> Dictionary:
	return _module(id).call("info")


## A ground slab of `size` metres centred on the origin with its top at y = 0. Visual only.
## The pattern is in world space, so neighbouring floors of any size line up seamlessly.
static func floor(id: String, size: Vector2) -> Node3D:
	var root := Node3D.new()
	root.name = "Floor_" + id
	root.add_child(EnvKit.slab(Vector3(size.x, 0.4, size.y), Vector3(0, -0.2, 0), _floor_material(id)))
	return root


## A wall run along X, `length` metres long and `height` tall, base at y = 0, centred, about
## a metre thick. One-sided walls (the city street front) face +Z. Two draw calls: a patterned core and the baked trim.
static func wall(id: String, length: float, height: float) -> Node3D:
	var key: String = "%s|%.2f|%.2f" % [id, length, height]
	if not _walls.has(key):
		var b: EnvBuilder = EnvKit.builder(int(length * 10.0))
		var spec: Dictionary = _wall(id, b, length, height)
		spec["mesh"] = b.bake(height)
		_walls[key] = spec
	var made: Dictionary = _walls[key]
	var root := Node3D.new()
	root.name = "Wall_" + id
	if made.get("core", null) != null:
		root.add_child(EnvKit.slab(Vector3(length, height, float(made.get("thickness", 0.8))), Vector3(0, height * 0.5, 0), made["core"] as Material))
	root.add_child(EnvKit.instance(made["mesh"] as ArrayMesh))
	root.set_meta("thickness", float(made.get("thickness", 0.8)) + 0.4)
	return root


## One prop of a kind (see info(id)["props"]), origin on the ground, facing -Z, a random
## variant each call. Metadata on the node: "radius" (footprint), "height", "blocks"
## (should stop the player), "cuttable" (may stand in for hittable scenery), "light".
static func prop(id: String, kind: String) -> Node3D:
	return prop_variant(id, kind, randi() % VARIANTS)


## The same, with the variant (0 .. VARIANTS - 1) chosen by the caller.
static func prop_variant(id: String, kind: String, variant: int) -> Node3D:
	var info_now: Dictionary = prop_meta(id, kind, variant)
	var root := Node3D.new()
	root.name = "%s_%s" % [id, kind]
	var inst: MeshInstance3D = EnvKit.instance(prop_mesh(id, kind, variant))
	root.add_child(inst)
	for key: String in ["radius", "height", "blocks", "cuttable", "light"]:
		root.set_meta(key, info_now[key])
	if info_now.has("special"):
		_special(inst, str(info_now["special"]))
	if bool(info_now["light"]):
		var lamp := OmniLight3D.new()
		lamp.position = info_now["light_at"]
		lamp.light_color = info_now.get("light_color", Color(1.0, 0.62, 0.3))
		lamp.light_energy = float(info_now.get("light_energy", 3.0))
		lamp.omni_range = float(info_now.get("light_range", 7.5))
		lamp.omni_attenuation = 1.4
		lamp.shadow_enabled = false
		root.add_child(lamp)
	return root


## The baked mesh of a prop variant (shared; draw it with EnvKit.prop_material()).
static func prop_mesh(id: String, kind: String, variant: int = 0) -> ArrayMesh:
	_ensure(id, kind, variant)
	return _meshes[_key(id, kind, variant)]


## A prop variant's metadata: radius, height, blocks, cuttable, light (+ light_at, ...).
static func prop_meta(id: String, kind: String, variant: int = 0) -> Dictionary:
	_ensure(id, kind, variant)
	return _metas[_key(id, kind, variant)]


## The barrier that seals a chamber, `width` metres clear between its posts, standing along
## X at the origin. Returns an EnvGate: call set_open(true / false) on it.
static func gate(id: String, width: float) -> Node3D:
	var frame: EnvBuilder = EnvKit.builder(11)
	var barrier: EnvBuilder = EnvKit.builder(12)
	var spec: Dictionary = _gate(id, frame, barrier, width)
	var h: float = float(spec.get("height", 3.0))
	var root := EnvGate.new()
	root.name = "Gate_" + id
	root.width = width
	root.add_child(EnvKit.instance(frame.bake(h)))
	var block: MeshInstance3D = EnvKit.instance(barrier.bake(h))
	if spec.has("special"):
		_special(block, str(spec["special"]))
	root.add_child(block)
	root.barrier = block
	root.open_shift = spec.get("shift", Vector3(0, h, 0))
	root.set_meta("height", h)
	return root


## Shorthand the biome scripts use to describe a prop.
static func meta(radius: float, height: float, blocks: bool, cuttable: bool = false, light_at: Variant = null) -> Dictionary:
	var out: Dictionary = {"radius": radius, "height": height, "blocks": blocks, "cuttable": cuttable, "light": light_at != null}
	if light_at != null:
		out["light_at"] = light_at
	return out


static func _key(id: String, kind: String, variant: int) -> String:
	return "%s|%s|%d" % [id, kind, posmod(variant, VARIANTS)]


static func _ensure(id: String, kind: String, variant: int) -> void:
	var key: String = _key(id, kind, variant)
	if _meshes.has(key):
		return
	var b: EnvBuilder = EnvKit.builder(hash(kind) % 1000 + posmod(variant, VARIANTS) * 37)
	var made: Dictionary = _build(id, b, kind)
	if made.is_empty():
		b.m(Color(0.5, 0.2, 0.5)).box(0.5, 0.5, 0.5, 0, 0.25, 0)
		made = meta(0.4, 0.5, false)
	_meshes[key] = b.bake(float(made["height"]))
	_metas[key] = made


## Swaps in one of the non-standard shared materials: "water:<html>" or "fog:<html>".
static func _special(inst: MeshInstance3D, what: String) -> void:
	var tint := Color.html(what.get_slice(":", 1))
	if what.begins_with("water"):
		inst.material_override = EnvKit.water(tint)
	else:
		inst.material_override = EnvKit.fog(tint)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _floor_material(id: String) -> ShaderMaterial:
	return _module(id).call("floor_material")


static func _build(id: String, b: EnvBuilder, kind: String) -> Dictionary:
	return _module(id).call("build", b, kind)


static func _wall(id: String, b: EnvBuilder, length: float, height: float) -> Dictionary:
	return _module(id).call("wall", b, length, height)


static func _gate(id: String, frame: EnvBuilder, barrier: EnvBuilder, width: float) -> Dictionary:
	return _module(id).call("gate", frame, barrier, width)


## The script that implements a biome (info, floor_material, build, wall, gate).
static func _module(id: String) -> GDScript:
	match id:
		"snow":
			return BiomeSnow
		"swamp":
			return BiomeSwamp
		"mountain":
			return BiomeMountain
		"city":
			return BiomeCity
		"scrubland":
			return BiomeScrubland
		_:
			return BiomeDungeon
