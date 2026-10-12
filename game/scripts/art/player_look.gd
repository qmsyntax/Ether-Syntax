class_name PlayerLook
extends RefCounted
## The customisable hero model behind Models.player(look): the option tables the character
## creator lists, look normalisation, and the builder itself. A "look" is a Dictionary of
## option ids keyed by KEYS; anything missing or unknown falls back to the first (default)
## option, and the default look is the stock player. All designs are original.

## Look keys, in the order the creator should show them.
const KEYS: Array[String] = ["body", "skin", "face", "hair", "hair_color", "band", "coat", "accent"]

# id, label, then tuning: overall scale, shoulder half-width, hip half-width, pelvis width,
# limb thickness, torso width, torso depth.
const BODIES: Array[Array] = [
	["a", "Broad", 1.0, 0.225, 0.095, 1.0, 1.0, 1.0, 1.0],
	["b", "Slight", 0.955, 0.188, 0.106, 1.14, 0.88, 0.87, 0.94],
	["c", "Heavy", 1.03, 0.252, 0.106, 1.16, 1.24, 1.2, 1.28],
	["d", "Wiry", 0.985, 0.204, 0.088, 0.92, 0.84, 0.9, 0.88],
]
const SKINS: Array[Array] = [
	["weathered", "Weathered", Color(0.68, 0.52, 0.41)],
	["pale", "Pale", Color(0.82, 0.71, 0.63)],
	["fair", "Fair", Color(0.77, 0.62, 0.52)],
	["olive", "Olive", Color(0.62, 0.5, 0.36)],
	["tawny", "Tawny", Color(0.56, 0.4, 0.28)],
	["umber", "Umber", Color(0.43, 0.29, 0.2)],
	["deep", "Deep brown", Color(0.31, 0.2, 0.14)],
	["ebony", "Ebony", Color(0.2, 0.135, 0.105)],
]
const FACES: Array[Array] = [
	["plain", "Plain"],
	["scarred", "Scarred"],
	["heavy", "Heavy-browed"],
	["gaunt", "Gaunt"],
	["stubble", "Stubbled"],
	["bearded", "Bearded"],
]
const HAIRS: Array[Array] = [
	["messy", "Short and messy"],
	["shaved", "Shaved"],
	["cropped", "Cropped"],
	["topknot", "Topknot"],
	["long", "Long and loose"],
	["braid", "Braid"],
	["undercut", "Undercut"],
	["swept", "Swept back"],
]
const HAIR_COLORS: Array[Array] = [
	["black", "Soot black", Color(0.09, 0.07, 0.06)],
	["dark_brown", "Dark brown", Color(0.17, 0.11, 0.07)],
	["brown", "Ash brown", Color(0.3, 0.22, 0.15)],
	["auburn", "Auburn", Color(0.36, 0.15, 0.08)],
	["blond", "Straw", Color(0.62, 0.52, 0.31)],
	["grey", "Iron grey", Color(0.4, 0.4, 0.41)],
	["white", "Bone white", Color(0.74, 0.72, 0.67)],
	["ink", "Ink blue", Color(0.08, 0.11, 0.2)],
]
const BANDS: Array[Array] = [
	["on", "Headband"],
	["off", "None"],
]
const COATS: Array[Array] = [
	["slate", "Slate", Color(0.19, 0.25, 0.33)],
	["charcoal", "Charcoal", Color(0.14, 0.14, 0.16)],
	["moss", "Moss", Color(0.2, 0.26, 0.17)],
	["oxblood", "Oxblood", Color(0.31, 0.12, 0.12)],
	["rust", "Rust", Color(0.38, 0.22, 0.12)],
	["dun", "Dun", Color(0.41, 0.35, 0.25)],
	["plum", "Plum", Color(0.25, 0.17, 0.27)],
	["ash", "Ash", Color(0.38, 0.39, 0.4)],
]
const ACCENTS: Array[Array] = [
	["cyan", "Pale cyan", Color(0.25, 0.7, 0.8)],
	["ember", "Ember", Color(0.85, 0.42, 0.14)],
	["gold", "Old gold", Color(0.78, 0.63, 0.25)],
	["moss", "Lichen", Color(0.45, 0.68, 0.33)],
	["violet", "Dusk violet", Color(0.55, 0.42, 0.78)],
	["bone", "Bone", Color(0.78, 0.76, 0.68)],
]


## Every option per key, for the creator UI: key -> Array of {"id", "label"} (plus "color"
## for colour options), in display order with the default first.
static func options() -> Dictionary:
	var out: Dictionary = {}
	for key: String in KEYS:
		var list: Array[Dictionary] = []
		for row: Array in _table(key):
			var entry: Dictionary = {"id": str(row[0]), "label": str(row[1])}
			if row.size() == 3 and row[2] is Color:
				entry["color"] = row[2]
			list.append(entry)
		out[key] = list
	return out


## The stock look: the first option of every key.
static func default_look() -> Dictionary:
	var look: Dictionary = {}
	for key: String in KEYS:
		look[key] = str(_table(key)[0][0])
	return look


## A complete look: missing keys are filled and unknown ids replaced with the defaults;
## keys that are not look keys are dropped.
static func normalize(look: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: String in KEYS:
		var want: String = str(look.get(key, ""))
		out[key] = str(_row(key, want)[0])
	return out


## A string that is the same for two looks exactly when they build the same model.
static func cache_key(look: Dictionary) -> String:
	var clean: Dictionary = normalize(look)
	var bits: PackedStringArray = []
	for key: String in KEYS:
		bits.append(str(clean[key]))
	return "player:" + ":".join(bits)


static func _table(key: String) -> Array[Array]:
	match key:
		"body":
			return BODIES
		"skin":
			return SKINS
		"face":
			return FACES
		"hair":
			return HAIRS
		"hair_color":
			return HAIR_COLORS
		"band":
			return BANDS
		"coat":
			return COATS
		_:
			return ACCENTS


## The table row for an id, or the default row if the id is unknown.
static func _row(key: String, id: String) -> Array:
	var table: Array[Array] = _table(key)
	for row: Array in table:
		if str(row[0]) == id:
			return row
	return table[0]


## Scales the radii of a flat [radius, y, ...] lathe profile.
static func _wide(profile: Array, k: float) -> Array:
	var out: Array = []
	for i: int in profile.size():
		out.append(float(profile[i]) * k if i % 2 == 0 else float(profile[i]))
	return out


# ---------------------------------------------------------------- builder

## Builds the hero for a look (normalised here). About 7.4 heads tall; supports the lost
## right arm ("arm_right" / "arm_right_stump") and ModelRig.set_weapon() on every body.
static func build(raw_look: Dictionary) -> ModelRig:
	var look: Dictionary = normalize(raw_look)
	var body: Array = _row("body", str(look["body"]))
	var size: float = body[2]
	var sh: float = body[3]
	var hip: float = body[4]
	var pelvis: float = body[5]
	var lw: float = body[6]
	var tw: float = body[7]
	var td: float = body[8]
	var skin: Color = _row("skin", str(look["skin"]))[2]
	var hair: Color = _row("hair_color", str(look["hair_color"]))[2]
	var coat: Color = _row("coat", str(look["coat"]))[2]
	var accent: Color = _row("accent", str(look["accent"]))[2]
	var stock_coat: bool = str(look["coat"]) == "slate"
	var coat_d: Color = Color(0.15, 0.2, 0.27) if stock_coat else coat.darkened(0.22)
	var coat_l: Color = Color(0.3, 0.37, 0.45) if stock_coat else coat.lightened(0.16)
	var sash: Color = Color(0.1, 0.3, 0.34) if str(look["accent"]) == "cyan" else Models.grim(accent, 0.6, 0.42)
	var face: String = look["face"]
	var style: String = look["hair"]
	var banded: bool = str(look["band"]) == "on"

	var r := ModelRig.new()
	r.name = "PlayerModel"
	r.height = 1.85 * size
	r.radius = 0.4
	r.stride_speed = 5.0
	r.stride_rate = 2.6
	r.swing = 0.7
	var cloth := Color(0.12, 0.12, 0.15)
	var wrap := Color(0.62, 0.57, 0.46)
	var wrap_d := Color(0.42, 0.37, 0.29)
	var boot := Color(0.17, 0.12, 0.08)
	var brass := Color(0.5, 0.4, 0.2)
	var leather: Color = Models.LEATHER
	var steel: Color = Models.STEEL
	var none := Vector3.ZERO
	var one := Vector3.ONE
	var frame: Node3D = r.add_part("frame")
	frame.scale = one * size

	for side: int in [-1, 1]:
		var n: String = "left" if side < 0 else "right"
		var leg: String = "leg_" + n
		var shin: String = "shin_" + n
		r.add_part(leg, "frame", Vector3(hip * side, 0.96, 0.0))
		r.add_shape(leg, Models.lathe(_wide([0.062, -0.48, 0.07, -0.4, 0.088, -0.2, 0.095, -0.04, 0.08, 0.05], lw), 10), cloth)
		r.add_shape(leg, Models.bbox(0.1 * lw, 0.11, 0.05, 0.02, 0.8, 1.0), leather, Vector3(0.0, -0.44, -0.055 * lw), Vector3(-6, 0, 0))
		r.add_part(shin, leg, Vector3(0, -0.47, 0))
		r.add_shape(shin, Models.lathe(_wide([0.05, -0.2, 0.066, -0.1, 0.066, 0.0, 0.058, 0.04], lw), 10), cloth)
		r.add_shape(shin, Models.lathe(_wide([0.048, -0.42, 0.052, -0.34, 0.07, -0.18, 0.075, -0.1, 0.07, -0.09], lw), 10), boot, none, none, one, 0.0, 0.2)
		for y: float in [-0.16, -0.25]:
			r.add_shape(shin, Models.lathe(_wide([0.064, y - 0.012, 0.074, y, 0.064, y + 0.012], lw), 8), leather.lightened(0.12), none, none, one, 0.0, 0.2, true)
		r.add_shape(shin, Models.bbox(0.105, 0.085, 0.25, 0.028, 0.8, 0.82), boot, Vector3(0, -0.445, -0.045), none, one, 0.0, 0.2, true)
		r.add_shape(shin, Models.bbox(0.11, 0.022, 0.26, 0.008), boot.darkened(0.4), Vector3(0, -0.478, -0.045))

	var girth := Vector3(pelvis, 1, 0.7 * td)
	r.add_part("body", "frame", Vector3(0, 0.96, 0))
	r.add_shape("body", Models.lathe([0.1, -0.12, 0.15, -0.05, 0.165, 0.04, 0.155, 0.14], 12), cloth, none, none, girth)
	r.add_shape("body", Models.lathe([0.158, 0.07, 0.172, 0.085, 0.172, 0.135, 0.158, 0.15], 12), leather, none, none, Vector3(pelvis, 1, 0.72 * td), 0.0, 0.2)
	r.add_shape("body", Models.bbox(0.055, 0.06, 0.02, 0.008), brass, Vector3(0.0, 0.11, -0.125 * td), none, one, 0.0, 0.8, true)
	r.add_shape("body", Models.bbox(0.09, 0.11, 0.06, 0.02, 0.85, 0.85), leather.lightened(0.08), Vector3(-0.15 * pelvis, 0.03, -0.03), Vector3(0, 0, 6), one, 0.0, 0.2, true)
	r.add_shape("body", MeshKit.sheet(0.11, 0.08, 0.36, 1.0, 0.012, -0.02, 0.05, 4, 4), sash, Vector3(0.1 * pelvis, 0.08, -0.125 * td))
	r.add_shape("body", MeshKit.sheet(0.08, 0.05, 0.27, 1.0, 0.012, -0.03, 0.04, 4, 3), sash.darkened(0.2), Vector3(0.14 * pelvis, 0.08, -0.105 * td), Vector3(0, -30, -8))

	var chest := Vector3(tw, 1, 0.62 * td)
	var front: float = -0.118 * td
	r.add_part("torso", "body", Vector3(0, 0.14, 0))
	r.add_shape("torso", Models.lathe([0.15, -0.05, 0.15, 0.05, 0.175, 0.19, 0.205, 0.32, 0.205, 0.39, 0.13, 0.45, 0.055, 0.47], 12), coat, none, none, chest)
	# Coat skirt, a darker crossed front panel, collar, a leather baldric, one spaulder.
	r.add_shape("torso", Models.lathe([0.2, -0.2, 0.185, -0.1, 0.16, -0.02, 0.15, 0.02], 12, 6, 0.05, 0.0, 0.035), coat_d, none, none, Vector3(maxf(tw, pelvis), 1, 0.72 * td))
	r.add_shape("torso", MeshKit.extrude(Models.poly([-0.02, 0.44, 0.1, 0.43, 0.11, 0.2, 0.02, 0.0, -0.09, 0.0]), 0.02), coat_d, Vector3(0, 0, front), Vector3(-7, 0, 0), Vector3(tw, 1, 1))
	r.add_shape("torso", Models.bbox(0.025, 0.47, 0.022, 0.006), coat_l, Vector3(-0.055 * tw, 0.215, front - 0.007), Vector3(-7, 0, -13), one, 0.0, 0.0, true)
	r.add_shape("torso", Models.lathe(_wide([0.058, 0.44, 0.052, 0.54], lerpf(1.0, lw, 0.6)), 8), skin)
	r.add_shape("torso", Models.lathe([0.07, 0.44, 0.085, 0.47, 0.075, 0.5], 10), coat_l, Vector3(0, 0, 0.01))
	var strap: Array = []
	var strap_r: Array = []
	for i: int in 17:
		var a: float = TAU * float(i) / 16.0
		var x: float = cos(a) * (0.19 + 0.02 * cos(a))
		strap.append_array([x * tw, 0.2 - x * 0.95, sin(a) * 0.135 * td])
		strap_r.append(0.03)
	r.add_shape("torso", Models.tube(strap, strap_r, 5, 0.35, Vector3.UP), leather, none, none, one, 0.0, 0.2)
	r.add_shape("torso", Models.lathe([0.105, -0.05, 0.1, 0.02, 0.06, 0.07, 0.0, 0.085], 6), leather.lightened(0.1), Vector3(-sh + 0.01, 0.39, 0), Vector3(0, 0, 18), Vector3(lerpf(1.0, lw, 0.5), 1.0, 1.15), 0.0, 0.25, true)

	_head(r, face, style, banded, skin, hair, accent)

	for side: int in [-1, 1]:
		var n: String = "left" if side < 0 else "right"
		var arm: String = "arm_" + n
		var fore: String = "forearm_" + n
		r.add_part(arm, "torso", Vector3(sh * side, 0.4, 0), Vector3(0, 0, 0.1 * side))
		r.add_shape(arm, Models.lathe(_wide([0.056, -0.31, 0.062, -0.2, 0.072, -0.08, 0.07, 0.0, 0.045, 0.05, 0.0, 0.065], lw), 10), coat)
		r.add_shape(arm, Models.lathe(_wide([0.062, -0.33, 0.068, -0.31, 0.062, -0.29], lw), 8), coat_l)
		r.add_part(fore, arm, Vector3(0, -0.31, 0), Vector3(0.35, 0, 0))
		if side < 0:
			r.add_shape(fore, Models.lathe(_wide([0.036, -0.27, 0.046, -0.16, 0.054, -0.05, 0.05, 0.02], lw), 10), skin)
			r.add_shape(fore, Models.lathe(_wide([0.04, -0.28, 0.049, -0.17, 0.053, -0.1, 0.05, -0.09], lw), 10), wrap)
			for y: float in [-0.24, -0.19, -0.14]:
				r.add_shape(fore, Models.lathe(_wide([0.047, y - 0.01, 0.055, y, 0.047, y + 0.01], lw), 8), wrap_d)
			r.add_shape(fore, Models.bbox(0.075, 0.095, 0.09, 0.025), wrap, Vector3(0, -0.325, -0.008), none, one, 0.0, 0.0, true)
			r.add_shape(fore, Models.bbox(0.08, 0.03, 0.04, 0.008), wrap_d, Vector3(0, -0.36, -0.035))
		else:
			r.add_shape(fore, Models.lathe(_wide([0.05, -0.28, 0.055, -0.18, 0.066, -0.06, 0.08, -0.01, 0.074, 0.02, 0.04, 0.03], lw), 8), steel, none, none, one, 0.0, 0.9, true)
			for y: float in [-0.21, -0.13]:
				r.add_shape(fore, Models.lathe(_wide([0.056, y - 0.012, 0.068, y, 0.06, y + 0.012], lw), 8), steel.darkened(0.35), none, none, one, 0.0, 0.9, true)
			r.add_shape(fore, Models.bbox(0.095, 0.105, 0.105, 0.028), Models.IRON.lightened(0.2), Vector3(0, -0.33, -0.008), none, one, 0.0, 0.8, true)
			r.add_shape(fore, Models.bbox(0.1, 0.022, 0.035, 0.007), accent, Vector3(0, -0.375, -0.045), none, one, 0.6)
	# Weapons ride here (see ModelRig.set_weapon): -Z runs forward-and-down out of the fist.
	r.add_part("hand_right", "forearm_right", Vector3(0, -0.33, 0), Vector3(deg_to_rad(-45.0), 0, 0))

	# Shown instead of the right arm: torn sleeve, a fat bandaged stump with a stained end,
	# a sling strap wound across the chest and a loose bandage tail.
	var st: String = "arm_right_stump"
	var blood := Color(0.4, 0.04, 0.04)
	r.add_part(st, "torso", Vector3(sh, 0.4, 0))
	r.add_shape(st, Models.lathe(_wide([0.085, -0.07, 0.078, 0.0, 0.045, 0.05, 0.0, 0.065], lw), 10, 5, 0.12, 0.0, 0.035), coat)
	r.add_shape(st, Models.ball(0.092 * lerpf(1.0, lw, 0.6), 10, 5), wrap, Vector3(0.012, -0.06, 0), none, Vector3(1.0, 0.95, 1.0))
	r.add_shape(st, Models.lathe(_wide([0.07, -0.21, 0.082, -0.18, 0.086, -0.07, 0.075, -0.02], lw), 10), wrap, Vector3(0.012, 0, 0), Vector3(0, 0, 12))
	for y: float in [-0.15, -0.1]:
		r.add_shape(st, Models.lathe(_wide([0.084, y - 0.012, 0.094, y, 0.085, y + 0.012], lw), 8), wrap_d, Vector3(0.012, 0, 0), Vector3(0, 0, 12))
	r.add_shape(st, Models.ball(0.076 * lw, 10, 5), blood, Vector3(0.056, -0.205, 0), Vector3(0, 0, 12), Vector3(1.0, 0.5, 1.0), 0.12)
	var sling: Array = []
	var sling_r: Array = []
	for i: int in 17:
		var a: float = TAU * float(i) / 16.0
		var x: float = cos(a) * (0.2 + 0.025 * cos(a))
		sling.append_array([x * tw - sh, 0.22 + x * 0.75 - 0.4, sin(a) * 0.142 * td])
		sling_r.append(0.034)
	r.add_shape(st, Models.tube(sling, sling_r, 5, 0.35, Vector3.UP), wrap)
	r.add_shape(st, Models.tube([0.055, -0.2, 0.02, 0.07, -0.28, 0.04, 0.06, -0.36, 0.05, 0.075, -0.41, 0.045], [0.02, 0.024, 0.02, 0.006], 4, 0.3), wrap_d)
	r.get_part(st).visible = false

	r.finish()
	return r


## Head, face variant, hair style and headband. The creator shows this up close, so it
## carries more geometry than the rest of the figure.
static func _head(r: ModelRig, face: String, style: String, banded: bool, skin: Color, hair: Color, accent: Color) -> void:
	var none := Vector3.ZERO
	var one := Vector3.ONE
	var shade: Color = skin.darkened(0.42)
	var jaw_w: float = 0.13
	var jaw_taper: float = 1.25
	if face == "heavy":
		jaw_w = 0.146
		jaw_taper = 1.1
	elif face == "gaunt":
		jaw_w = 0.112
		jaw_taper = 1.42
	r.add_part("head", "torso", Vector3(0, 0.5, 0))
	r.add_shape("head", Models.ball(0.105, 16, 8), skin, Vector3(0, 0.125, 0.005), none, Vector3(0.9, 1.12, 1.0))
	r.add_shape("head", Models.bbox(jaw_w, 0.11, 0.13, 0.035, jaw_taper, 1.2), skin, Vector3(0, 0.055, -0.03), none, one, 0.0, 0.0, true)
	r.add_shape("head", Models.bbox(0.026, 0.055, 0.035, 0.008, 0.6, 0.5), skin.darkened(0.12), Vector3(0, 0.097, -0.104), none, one, 0.0, 0.0, true)
	r.add_shape("head", Models.bbox(0.05, 0.012, 0.02, 0.004), skin.lerp(Color(0.4, 0.2, 0.18), 0.45), Vector3(0, 0.05, -0.098))
	r.add_shape("head", Models.bbox(0.04, 0.008, 0.02, 0.003), shade, Vector3(0, 0.041, -0.097))
	# Eye line: a shadowed socket band, then eyes set into it under the brows.
	var brow_h: float = 0.03 if face == "heavy" else 0.02
	r.add_shape("head", Models.bbox(0.15, 0.024, 0.03, 0.006), skin.darkened(0.22), Vector3(0, 0.128, -0.086), Vector3(-6, 0, 0))
	for side: int in [-1, 1]:
		r.add_shape("head", Models.ball(0.024, 8, 4), skin.darkened(0.08), Vector3(0.096 * side, 0.115, 0.0), none, Vector3(0.5, 1.0, 0.8))
		r.add_shape("head", Models.ball(0.013, 8, 4), Color(0.6, 0.58, 0.54), Vector3(0.04 * side, 0.127, -0.096), none, Vector3(1.35, 0.75, 0.5))
		r.add_shape("head", Models.ball(0.0075, 6, 3), Color(0.05, 0.05, 0.06), Vector3(0.039 * side, 0.127, -0.1015), none, Vector3(1.0, 1.0, 0.5))
		r.add_shape("head", Models.bbox(0.062, brow_h, 0.024, 0.005), hair.lerp(shade, 0.3), Vector3(0.042 * side, 0.146 + brow_h * 0.3, -0.094), Vector3(0, 0, (4 if face == "heavy" else 9) * side))
		if face == "gaunt":
			r.add_shape("head", Models.ball(0.03, 8, 4), shade.lerp(skin, 0.35), Vector3(0.058 * side, 0.078, -0.07), Vector3(0, -30 * side, 12 * side), Vector3(0.7, 1.3, 0.25))
	match face:
		"scarred":
			var scar: Color = skin.lerp(Color(0.72, 0.42, 0.4), 0.65)
			r.add_shape("head", Models.bbox(0.011, 0.1, 0.012, 0.003), scar, Vector3(-0.047, 0.118, -0.0985), Vector3(-4, 0, 16))
			r.add_shape("head", Models.bbox(0.009, 0.035, 0.012, 0.003), scar, Vector3(0.05, 0.07, -0.09), Vector3(0, 0, -50))
		"stubble":
			var grain: Color = skin.lerp(hair, 0.4)
			r.add_shape("head", Models.bbox(jaw_w + 0.004, 0.07, 0.134, 0.035, 1.3, 1.2), grain, Vector3(0, 0.034, -0.03), none, one, 0.0, 0.0, true)
			r.add_shape("head", Models.bbox(0.06, 0.012, 0.02, 0.004), grain, Vector3(0, 0.064, -0.099))
		"bearded":
			r.add_shape("head", Models.bbox(jaw_w + 0.012, 0.1, 0.14, 0.035, 1.3, 1.15), hair, Vector3(0, 0.022, -0.034), none, one, 0.0, 0.0, true)
			r.add_shape("head", Models.bbox(0.07, 0.016, 0.022, 0.005), hair, Vector3(0, 0.064, -0.1))
			for side: int in [-1, 1]:
				r.add_shape("head", Models.bbox(0.02, 0.08, 0.06, 0.008), hair, Vector3(0.082 * side, 0.085, -0.03), Vector3(0, 0, -6 * side))

	_hair(r, style, skin, hair)

	if banded:
		r.add_shape("head", Models.lathe([0.107, 0.17, 0.1125, 0.175, 0.1125, 0.196, 0.107, 0.201], 14), accent, Vector3(0, 0.0, 0.012), Vector3(-6, 0, 0), one, 0.22)
		r.add_part("band_tail", "head", Vector3(0, 0.17, 0.125), Vector3(0.75, 0, 0))
		r.add_shape("band_tail", Models.tube([-0.01, 0.0, 0.0, -0.03, -0.01, 0.09, -0.045, 0.0, 0.2, -0.03, -0.02, 0.3], [0.016, 0.02, 0.018, 0.006], 4, 0.35, Vector3.RIGHT), accent, none, none, one, 0.3)
		r.add_shape("band_tail", Models.tube([0.01, 0.0, 0.0, 0.03, -0.02, 0.08, 0.05, -0.05, 0.16, 0.045, -0.09, 0.22], [0.016, 0.02, 0.016, 0.006], 4, 0.35, Vector3.RIGHT), accent, none, none, one, 0.3)
		r.sway_parts["band_tail"] = -0.6


static func _hair(r: ModelRig, style: String, skin: Color, hair: Color) -> void:
	var none := Vector3.ZERO
	var one := Vector3.ONE
	var light: Color = hair.lightened(0.07)
	var fuzz: Color = skin.lerp(hair, 0.5)
	var cap := Vector3(0, 0.165, 0.018)
	match style:
		"shaved":
			r.add_shape("head", Models.ball(0.1095, 14, 7), fuzz, Vector3(0, 0.152, 0.012), none, Vector3(0.91, 0.87, 1.02))
		"cropped":
			r.add_shape("head", Models.ball(0.111, 14, 7), hair, Vector3(0, 0.158, 0.016), none, Vector3(0.93, 0.81, 1.03))
			r.add_shape("head", Models.ball(0.098, 10, 5), hair, Vector3(0, 0.125, 0.04), none, Vector3(0.98, 0.9, 0.8))
		"topknot":
			r.add_shape("head", Models.ball(0.11, 14, 7), hair, Vector3(0, 0.158, 0.016), none, Vector3(0.92, 0.82, 1.03))
			r.add_shape("head", Models.ball(0.097, 10, 5), hair, Vector3(0, 0.122, 0.04), none, Vector3(0.98, 0.95, 0.8))
			for i: int in 5:
				var x: float = -0.06 + 0.03 * float(i)
				r.add_shape("head", Models.tube([x, 0.19, -0.075, x * 0.7, 0.24, -0.01, x * 0.3, 0.25, 0.05], [0.014, 0.016, 0.012], 4), light)
			r.add_shape("head", Models.ball(0.04, 10, 5), hair, Vector3(0, 0.262, 0.062), none, Vector3(1.0, 0.85, 1.0))
			r.add_shape("head", Models.torus(0.022, 0.036, 10, 4), Models.LEATHER.lightened(0.15), Vector3(0, 0.243, 0.058), Vector3(-20, 0, 0))
			r.add_shape("head", Models.tube([0, 0.275, 0.07, 0, 0.3, 0.1, 0, 0.27, 0.14], [0.02, 0.016, 0.0], 5), light)
		"long", "braid":
			r.add_shape("head", Models.ball(0.113, 14, 7), hair, cap, none, Vector3(0.95, 0.73, 1.05))
			r.add_shape("head", Models.ball(0.1, 12, 6), hair, Vector3(0, 0.115, 0.05), none, Vector3(1.02, 1.1, 0.82))
			r.add_shape("head", Models.bbox(0.012, 0.02, 0.15, 0.004), light, Vector3(0.012, 0.243, -0.01), Vector3(8, 0, 0))
			for side: int in [-1, 1]:
				r.add_shape("head", Models.tube([0.07 * side, 0.2, -0.06, 0.1 * side, 0.13, -0.045, 0.105 * side, 0.03, -0.03, 0.095 * side, -0.05 if style == "long" else 0.02, -0.02], [0.02, 0.026, 0.022, 0.0], 5, 0.5, Vector3.BACK), light)
			r.add_part("hair_tail", "head", Vector3(0, 0.1, 0.085), Vector3(0.12, 0, 0))
			if style == "long":
				for i: int in 5:
					var x: float = -0.08 + 0.04 * float(i)
					var drop: float = 0.26 - 0.03 * absf(float(i) - 2.0)
					r.add_shape("hair_tail", Models.tube([x, 0.05, -0.01, x * 1.05, -drop * 0.5, 0.03, x * 0.95, -drop, 0.02], [0.03, 0.03, 0.0], 5, 0.5, Vector3.RIGHT), hair if i % 2 == 0 else light)
			else:
				for i: int in 7:
					var t: float = float(i) / 6.0
					r.add_shape("hair_tail", Models.ball(lerpf(0.034, 0.018, t), 8, 4), hair if i % 2 == 0 else light, Vector3(0.012 * (1.0 if i % 2 == 0 else -1.0), -0.045 * float(i), 0.02 + 0.03 * sin(t * PI)), Vector3(0, 0, 20.0 * (1.0 if i % 2 == 0 else -1.0)), Vector3(1.0, 1.25, 0.9))
				r.add_shape("hair_tail", Models.torus(0.01, 0.022, 8, 4), Models.LEATHER.lightened(0.15), Vector3(0, -0.29, 0.02))
			r.sway_parts["hair_tail"] = -0.4
		"undercut":
			r.add_shape("head", Models.ball(0.1095, 14, 7), fuzz, Vector3(0, 0.147, 0.014), none, Vector3(0.91, 0.92, 1.02))
			r.add_shape("head", Models.ball(0.1, 12, 6), hair, Vector3(0.008, 0.205, 0.0), none, Vector3(0.74, 0.55, 1.1))
			for i: int in 5:
				var x: float = -0.05 + 0.022 * float(i)
				r.add_shape("head", Models.tube([x, 0.215, -0.1, x + 0.02, 0.25, -0.03, x + 0.035, 0.235, 0.07, x + 0.03, 0.19, 0.11], [0.016, 0.028, 0.026, 0.0], 5), light if i % 2 == 0 else hair)
		"swept":
			r.add_shape("head", Models.ball(0.113, 14, 7), hair, cap, none, Vector3(0.95, 0.74, 1.06))
			r.add_shape("head", Models.ball(0.1, 12, 6), hair, Vector3(0, 0.115, 0.055), none, Vector3(1.0, 1.1, 0.84))
			for i: int in 5:
				var x: float = -0.07 + 0.035 * float(i)
				r.add_shape("head", Models.tube([x, 0.2, -0.09, x * 0.95, 0.252, -0.02, x * 0.85, 0.235, 0.08, x * 0.7, 0.14, 0.14, x * 0.6, 0.07, 0.13], [0.018, 0.03, 0.03, 0.024, 0.0], 5), light if i % 2 == 1 else hair)
		_:
			# "messy": the stock cut.
			r.add_shape("head", Models.ball(0.112, 14, 7), hair, cap, none, Vector3(0.95, 0.72, 1.05))
			r.add_shape("head", Models.ball(0.098, 10, 5), hair, Vector3(0, 0.115, 0.05), none, Vector3(1.0, 1.05, 0.8))
			var tufts: Array = [[-0.05, 0.215, -0.07, -62, 22, 0.1], [0.03, 0.225, -0.075, -68, -12, 0.11], [0.07, 0.2, -0.04, -40, -40, 0.09], [-0.02, 0.235, 0.02, -15, 10, 0.08], [0.0, 0.2, 0.11, 60, 0, 0.1], [-0.075, 0.19, 0.02, -20, 55, 0.08], [0.05, 0.215, 0.06, 35, -25, 0.09]]
			for tuft: Array in tufts:
				r.add_shape("head", Models.cyl(0.0, 0.04, float(tuft[5]), 5), light, Vector3(float(tuft[0]), float(tuft[1]), float(tuft[2])), Vector3(float(tuft[3]), 0, float(tuft[4])), one, 0.0, 0.0, true)
