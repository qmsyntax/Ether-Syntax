class_name RealProps
extends RefCounted
## Real models standing in for a biome kit's procedural props (Brent 2026-10-18: real assets).
## The models are CC0 scans from Poly Haven, made game-ready by tools/assets/blender_optimize.py
## (one .glb each in game/assets/models/props/, origin at the middle of the base). A kit prop
## keeps its gameplay metadata - footprint, height, whether it blocks - from the kit, and only
## its look is replaced; the model is scaled to the kit's footprint so colliders still match.

const DIR := "res://assets/models/props/"

## biome -> kind -> [[model id, how to size it]]. "fit": its footprint matches the kit's radius;
## "height": its height matches the kit's height.
const KIT := {
	"scrubland": {
		"boulder": [["namaqualand_boulder_05", "fit"], ["namaqualand_boulder_06", "fit"], ["namaqualand_boulder_02", "fit"]],
		"outcrop": [["namaqualand_boulder_03", "fit"], ["namaqualand_boulder_04", "fit"], ["root_cluster_01", "fit"]],
		"stones": [["namaqualand_boulders_01", "fit"], ["bark_debris_01", "fit"], ["namaqualand_boulder_06", "fit"]],
		"log": [["dead_tree_trunk", "fit"], ["dry_branches_medium_01", "fit"], ["tree_stump_01", "fit"]],
		"dead_tree": [["dead_quiver_trunk", "height"], ["quiver_tree_01", "height"]],
	},
}

static var _scenes: Dictionary = {}
static var _sizes: Dictionary = {}


static func has(biome: String, kind: String) -> bool:
	return KIT.has(biome) and (KIT[biome] as Dictionary).has(kind)


static func exists(id: String) -> bool:
	return ResourceLoader.exists(DIR + id + ".glb")


static func scene(id: String) -> PackedScene:
	if not _scenes.has(id):
		var packed: PackedScene = load(DIR + id + ".glb")
		_fix_materials(packed)
		_scenes[id] = packed
	return _scenes[id]


## Leaves and twigs come in alpha-blended, which draws them out of order and casts no shadow.
## Foliage wants a cut-out instead: alpha scissor, both faces drawn. The materials are shared by
## every copy of the model, so this is done once, when it is first loaded.
static func _fix_materials(packed: PackedScene) -> void:
	var probe: Node = packed.instantiate()
	for n: Node in probe.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (n as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i: int in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i) as StandardMaterial3D
			if mat != null and mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				mat.alpha_scissor_threshold = 0.45
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	probe.free()


## The model's size in metres (x across, y up, z deep), at scale 1.
static func size_of(id: String) -> Vector3:
	if _sizes.has(id):
		return _sizes[id]
	var probe: Node3D = scene(id).instantiate()
	var box := AABB()
	var first := true
	for n: Node in probe.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var b: AABB = mi.get_aabb()
		b = mi.transform * b
		box = b if first else box.merge(b)
		first = false
	probe.free()
	_sizes[id] = box.size
	return box.size


## A model by id, uniformly scaled by `s`, turned `yaw` radians.
static func model(id: String, s: float, yaw: float = 0.0) -> Node3D:
	var node: Node3D = scene(id).instantiate()
	node.scale = Vector3.ONE * s
	node.rotation.y = yaw
	return node


## The real-model version of a kit prop, carrying the kit's metadata. `variant` picks the model
## and a little size variety, so the same variant always looks the same.
static func kit_prop(biome: String, kind: String, variant: int, meta: Dictionary) -> Node3D:
	var choices: Array = KIT[biome][kind]
	var pick: Array = choices[variant % choices.size()]
	var id: String = str(pick[0])
	var size: Vector3 = size_of(id)
	var s := 1.0
	if str(pick[1]) == "height":
		s = float(meta.get("height", 1.0)) / maxf(0.01, size.y)
	else:
		s = float(meta.get("radius", 0.5)) * 2.0 / maxf(0.01, maxf(size.x, size.z))
	s *= 0.88 + 0.24 * fposmod(float(variant) * 0.618, 1.0)
	var root := Node3D.new()
	root.name = "%s_%s_real" % [biome, kind]
	root.add_child(model(id, s))
	for key: String in ["radius", "height", "blocks", "cuttable", "light"]:
		root.set_meta(key, meta.get(key, false))
	return root
