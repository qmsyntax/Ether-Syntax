class_name GroundMaterial
extends RefCounted
## Textured ground (Brent 2026-10-18: "lets make some real assets"). For a biome that has a
## ground set in game/assets/textures/ground/ (made by tools/assets/make_ground_textures.py),
## a ShaderMaterial on assets/shaders/ground.gdshader; null for one that has none yet, so the
## biome's procedural floor is used instead.

const SETS := {
	"scrubland": {"a": "dry_earth", "b": "dry_grass", "tile_m": 3.0, "b_amount": 0.75, "tint": Color(0.8, 0.76, 0.7)},
}
const DIR := "res://assets/textures/ground/"

static var _made: Dictionary = {}


static func for_biome(id: String) -> Material:
	if _made.has(id):
		return _made[id]
	if not SETS.has(id):
		return null
	var spec: Dictionary = SETS[id]
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/ground.gdshader")
	for layer: String in ["a", "b"]:
		var name: String = str(spec[layer])
		mat.set_shader_parameter(layer + "_albedo", load(DIR + name + "_albedo.png"))
		mat.set_shader_parameter(layer + "_normal", load(DIR + name + "_normal.png"))
		mat.set_shader_parameter(layer + "_rough", load(DIR + name + "_rough.png"))
	mat.set_shader_parameter("macro_mask", load(DIR + "ground_macro_mask.png"))
	mat.set_shader_parameter("tile_m", float(spec.get("tile_m", 3.0)))
	mat.set_shader_parameter("b_amount", float(spec.get("b_amount", 0.5)))
	var t: Color = spec.get("tint", Color(1, 1, 1))
	mat.set_shader_parameter("tint", Vector3(t.r, t.g, t.b))
	_made[id] = mat
	return mat
