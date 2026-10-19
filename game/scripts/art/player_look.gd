class_name PlayerLook
extends RefCounted
## The customisable hero model behind Models.player(look): the option tables the character
## creator lists, look normalisation, and the builder itself. A "look" is a Dictionary of
## option ids keyed by KEYS; anything missing or unknown falls back to the first (default)
## option, and the default look is the stock player. All designs are original.

## Look keys, in the order the creator should show them.
const KEYS: Array[String] = ["sex", "body", "skin", "features", "face", "hair", "hair_color", "band", "coat", "accent"]

const SEXES: Array[Array] = [
	["male", "Male"],
	["female", "Female"],
]

# id, label, then tuning: overall scale, shoulder half-width, chest width, waist width, hip
# width, depth, limb thickness, neck thickness.
const BODIES: Array[Array] = [
	["a", "Broad", 1.0, 0.225, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
	["b", "Slight", 0.955, 0.194, 0.88, 0.9, 1.03, 0.93, 0.88, 0.9],
	["c", "Heavy", 1.03, 0.25, 1.18, 1.32, 1.15, 1.26, 1.22, 1.2],
	["d", "Wiry", 0.985, 0.207, 0.9, 0.86, 0.92, 0.88, 0.85, 0.9],
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
# which generated face (real bodies: textures/skin/skin_<sex>_gen_<id>.jpg); the procedural body ignores it
const FEATURES: Array[Array] = [
	["f1", "First"], ["f2", "Second"], ["f3", "Third"], ["f4", "Fourth"], ["f5", "Fifth"], ["f6", "Sixth"],
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
	["topknot", "Tied back"],
	["long", "Long and loose"],
	["braid", "Braid"],
	["undercut", "Undercut"],
	["swept", "Swept back"],
	["bob", "Bob"],
	["curls", "Tight curls"],
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
		"sex":
			return SEXES
		"body":
			return BODIES
		"skin":
			return SKINS
		"face":
			return FACES
		"features":
			return FEATURES
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

const K_CLOTH := ModelRig.CLOTH
const K_SKIN := ModelRig.SKIN
const K_LEATHER := ModelRig.LEATHER_KIND
const K_METAL := ModelRig.METAL
const K_HAIR := ModelRig.HAIR
const NONE := Vector3.ZERO
const ONE := Vector3.ONE


## Skeleton and build measurements for a body type and sex.
static func _dims(body_id: String, female: bool) -> Dictionary:
	var b: Array = _row("body", body_id)
	var d: Dictionary = {
		"size": float(b[2]), "sh": float(b[3]), "chest": float(b[4]), "waist": float(b[5]), "hip": float(b[6]),
		"depth": float(b[7]), "limb": float(b[8]), "neck": float(b[9]), "hand": 1.0, "bust": 0.0, "thigh": 1.0, "head": 1.06,
	}
	if female:
		d["size"] = maxf(float(d["size"]) * 0.972, 0.9475)
		d["sh"] = float(d["sh"]) * 0.86
		d["chest"] = float(d["chest"]) * 0.9
		d["waist"] = float(d["waist"]) * 0.8
		d["hip"] = float(d["hip"]) * 1.14
		d["limb"] = float(d["limb"]) * 0.9
		d["neck"] = float(d["neck"]) * 0.84
		d["hand"] = 0.9
		d["bust"] = 1.0
		d["thigh"] = 1.07
		d["head"] = 1.02
	return d


## Face sculpt tuning for a face variant and sex (see HeadKit).
static func _face_tune(face: String, female: bool) -> Dictionary:
	var t: Dictionary = {"jaw": 1.0, "chin": 1.0, "brow": 1.0, "nose": 1.0, "lips": 1.0, "cheekbone": 1.0, "hollow": 0.0, "socket": 1.0, "soft": 0.0}
	if female:
		t = {"jaw": 0.88, "chin": 0.8, "brow": 0.4, "nose": 0.82, "lips": 1.3, "cheekbone": 1.15, "hollow": 0.0, "socket": 0.85, "soft": 0.8}
	match face:
		"heavy":
			t["brow"] = float(t["brow"]) * 1.8 + 0.25
			t["jaw"] = float(t["jaw"]) * 1.13
			t["chin"] = float(t["chin"]) * 1.3
			t["nose"] = float(t["nose"]) * 1.18
		"gaunt":
			t["hollow"] = 1.6
			t["cheekbone"] = float(t["cheekbone"]) * 1.6
			t["jaw"] = float(t["jaw"]) * 0.9
			t["socket"] = float(t["socket"]) * 1.45
			t["chin"] = float(t["chin"]) * 1.12
		"scarred":
			t["nose"] = float(t["nose"]) * 1.1
			t["brow"] = float(t["brow"]) * 1.15
	return t


static func _loft(rows: Array, sides: int = 24, detail: int = 3, ripple_n: int = 0, from_deg: float = 0.0, to_deg: float = 360.0, cap_first: bool = true, cap_last: bool = true) -> ArrayMesh:
	return MeshKit.loft(MeshKit.refine(rows, detail), sides, ripple_n, from_deg, to_deg, cap_first, cap_last)


## The loft row at height `y`, interpolated (rows sorted by rising y).
static func _row_at(rows: Array, y: float) -> Array:
	var full: Array = MeshKit.refine(rows, 1)
	if y <= float(full[0][0]):
		return full[0]
	for i: int in full.size() - 1:
		var a: Array = full[i]
		var b: Array = full[i + 1]
		if y <= float(b[0]):
			var t: float = (y - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001)
			var out: Array = []
			for k: int in 8:
				out.append(lerpf(float(a[k]), float(b[k]), t))
			return out
	return full[full.size() - 1]


## A point on a loft row at an angle (degrees from +X toward +Z), pushed `out` metres.
static func _ring_point(row: Array, deg: float, out: float = 0.0) -> Vector3:
	var a: float = deg_to_rad(deg)
	var c: float = cos(a)
	var s: float = sin(a)
	var power: float = 1.0 - 0.5 * float(row[6])
	var ex: float = signf(c) * pow(absf(c), power)
	var ez: float = signf(s) * pow(absf(s), power)
	var rz: float = float(row[3]) if s > 0.0 else float(row[2])
	return Vector3(float(row[4]) + (float(row[1]) + out) * ex, float(row[0]), float(row[5]) + (rz + out) * ez)


## Offsets every row of a loft outward by `grow` metres.
static func _grown(rows: Array, grow: float) -> Array:
	var out: Array = []
	for row: Array in MeshKit.refine(rows, 1):
		var r: Array = row.duplicate()
		r[1] = float(r[1]) + grow
		r[2] = float(r[2]) + grow
		r[3] = float(r[3]) + grow
		out.append(r)
	return out


## Builds the hero for a look (normalised here). About 7.4 heads tall; supports the lost
## right arm ("arm_right" / "arm_right_stump") and ModelRig.set_weapon() on every body.
static func build(raw_look: Dictionary) -> ModelRig:
	var look: Dictionary = normalize(raw_look)
	var female: bool = str(look["sex"]) == "female"
	var d: Dictionary = _dims(str(look["body"]), female)
	var size: float = d["size"]
	var sh: float = d["sh"]
	var chest: float = d["chest"]
	var waist: float = d["waist"]
	var hip: float = d["hip"]
	var depth: float = d["depth"]
	var lw: float = d["limb"]
	var neck: float = d["neck"]
	var bust: float = d["bust"]
	var skin: Color = _row("skin", str(look["skin"]))[2]
	var hair: Color = _row("hair_color", str(look["hair_color"]))[2]
	var coat: Color = _row("coat", str(look["coat"]))[2]
	var accent: Color = _row("accent", str(look["accent"]))[2]
	var stock_coat: bool = str(look["coat"]) == "slate"
	var coat_d: Color = Color(0.15, 0.2, 0.27) if stock_coat else coat.darkened(0.22)
	var coat_l: Color = Color(0.3, 0.37, 0.45) if stock_coat else coat.lightened(0.16)
	var sash: Color = Color(0.1, 0.3, 0.34) if str(look["accent"]) == "cyan" else Models.grim(accent, 0.6, 0.42)

	var r := ModelRig.new()
	r.name = "PlayerModel"
	r.height = 1.85 * size
	r.radius = 0.4
	r.stride_speed = 5.0
	r.stride_rate = 2.6
	r.swing = 0.7
	var cloth := Color(0.12, 0.12, 0.15)
	var shirt := Color(0.5, 0.47, 0.4)
	var wrap := Color(0.62, 0.57, 0.46)
	var wrap_d := Color(0.42, 0.37, 0.29)
	var boot := Color(0.17, 0.12, 0.08)
	var brass := Color(0.5, 0.4, 0.2)
	var leather: Color = Models.LEATHER
	var leather_l: Color = leather.lightened(0.12)
	var steel: Color = Models.STEEL
	var iron: Color = Models.IRON.lightened(0.2)
	var frame: Node3D = r.add_part("frame")
	frame.scale = ONE * size
	var wh: float = lerpf(waist, hip, 0.5)
	var dw: float = depth * lerpf(1.0, waist, 0.5)
	var hip_x: float = 0.095 * lerpf(1.0, hip, 0.7)

	# ---- legs: trousers, strapped knee guards, cuffed boots
	for side: int in [-1, 1]:
		var n: String = "left" if side < 0 else "right"
		var leg: String = "leg_" + n
		var shin: String = "shin_" + n
		var up: float = lw * float(d["thigh"])
		r.add_part(leg, "frame", Vector3(hip_x * side, 0.96, 0.0))
		var thigh: Array = [
			[-0.5, 0.054 * lw, 0.057 * lw, 0.056 * lw, 0, 0, 0, 0.03], [-0.44, 0.058 * lw, 0.064 * lw, 0.058 * lw, 0, 0, 0, 0.035],
			[-0.34, 0.067 * lw, 0.069 * lw, 0.071 * lw], [-0.18, 0.084 * up, 0.086 * up, 0.091 * up],
			[-0.03, 0.09 * up, 0.092 * up, 0.099 * up], [0.07, 0.076 * up, 0.082 * up, 0.09 * up],
		]
		r.add_shape(leg, _loft(thigh, 20, 3, 8), cloth)
		r.add_shape(leg, _loft(_grown([[-0.5, 0.056 * lw, 0.058 * lw, 0.05 * lw], [-0.45, 0.06 * lw, 0.067 * lw, 0.05 * lw], [-0.4, 0.063 * lw, 0.066 * lw, 0.05 * lw], [-0.37, 0.058 * lw, 0.058 * lw, 0.05 * lw]], 0.008), 10, 2, 0, -160.0, -20.0), leather, NONE, NONE, ONE, 0.0, 0.0, false, K_LEATHER)
		r.add_shape(leg, _loft(_grown([[-0.47, 0.056 * lw, 0.06 * lw, 0.057 * lw], [-0.45, 0.057 * lw, 0.062 * lw, 0.058 * lw]], 0.006), 16, 1), leather_l, NONE, NONE, ONE, 0.0, 0.0, false, K_LEATHER)
		r.add_part(shin, leg, Vector3(0, -0.47, 0))
		r.add_shape(shin, _loft([[-0.14, 0.054 * lw, 0.052 * lw, 0.068 * lw], [-0.06, 0.058 * lw, 0.056 * lw, 0.068 * lw, 0, 0, 0, 0.03], [0.04, 0.055 * lw, 0.058 * lw, 0.057 * lw]], 18, 3, 7), cloth)
		var shaft: Array = [
			[-0.46, 0.044, 0.05, 0.052], [-0.4, 0.043 * lw, 0.045 * lw, 0.05 * lw], [-0.32, 0.046 * lw, 0.046 * lw, 0.054 * lw],
			[-0.2, 0.058 * lw, 0.052 * lw, 0.073 * lw], [-0.13, 0.064 * lw, 0.059 * lw, 0.078 * lw], [-0.09, 0.066 * lw, 0.062 * lw, 0.077 * lw],
		]
		r.add_shape(shin, _loft(shaft, 20, 3), boot, NONE, NONE, ONE, 0.0, 0.0, false, K_LEATHER)
		r.add_shape(shin, _loft(_grown([[-0.135, 0.064 * lw, 0.059 * lw, 0.078 * lw], [-0.09, 0.066 * lw, 0.062 * lw, 0.077 * lw], [-0.078, 0.064 * lw, 0.06 * lw, 0.075 * lw]], 0.007), 20, 2), leather_l, NONE, NONE, ONE, 0.0, 0.0, false, K_LEATHER)
		for y: float in [-0.19, -0.3]:
			var band: Array = _row_at(shaft, y)
			var band2: Array = _row_at(shaft, y + 0.022)
			r.add_shape(shin, MeshKit.loft(_grown([band, band2], 0.005), 18), leather_l, NONE, NONE, ONE, 0.0, 0.0, false, K_LEATHER)
			var clasp: Vector3 = _ring_point(_row_at(shaft, y + 0.011), -60.0 if side > 0 else -120.0, 0.008)
			r.add_shape(shin, Models.bbox(0.022, 0.028, 0.008, 0.003), brass, clasp, Vector3(0, 30.0 * side, 0), ONE, 0.0, 0.85, true, K_METAL)
		var foot: Array = [
			[-0.064, 0.02, 0.02, 0.02, 0, 0, 0.3], [-0.05, 0.036, 0.03, 0.036, 0, 0, 0.3], [-0.02, 0.042, 0.031, 0.052, 0, 0, 0.3],
			[0.03, 0.045, 0.031, 0.05, 0, 0, 0.3], [0.09, 0.048, 0.031, 0.034, 0, 0, 0.35], [0.15, 0.047, 0.029, 0.024, 0, 0, 0.35],
			[0.185, 0.038, 0.027, 0.018, 0, 0, 0.3], [0.2, 0.02, 0.02, 0.012, 0, 0, 0.2],
		]
		r.add_shape(shin, _loft(foot, 18, 3), boot, Vector3(0, -0.452, 0.0), Vector3(-90, 0, 0), ONE, 0.0, 0.0, false, K_LEATHER)
		r.add_shape(shin, Models.bbox(0.096, 0.014, 0.264, 0.006, 0.96, 0.98), boot.darkened(0.45), Vector3(0, -0.483, -0.068), NONE, ONE, 0.0, 0.0, true, K_LEATHER)
		r.add_shape(shin, Models.bbox(0.07, 0.03, 0.06, 0.008, 0.96, 0.98), boot.darkened(0.45), Vector3(0, -0.478, 0.03), NONE, ONE, 0.0, 0.0, true, K_LEATHER)

	# ---- pelvis: trousers, belt with buckle and pouches, sash
	r.add_part("body", "frame", Vector3(0, 0.96, 0))
	r.add_shape("body", _loft([[-0.14, 0.09 * hip, 0.075 * depth, 0.085 * depth], [-0.06, 0.153 * hip, 0.098 * depth, 0.112 * depth], [0.04, 0.164 * hip, 0.1 * depth, 0.114 * depth], [0.15, 0.15 * wh, 0.096 * dw, 0.103 * dw]], 24, 3), cloth)
	var belt: Array = [[0.068, 0.162 * wh, 0.106 * dw, 0.113 * dw], [0.09, 0.166 * wh, 0.109 * dw, 0.116 * dw], [0.118, 0.166 * wh, 0.109 * dw, 0.116 * dw], [0.14, 0.162 * wh, 0.106 * dw, 0.113 * dw]]
	r.add_shape("body", MeshKit.loft(belt, 28), leather, NONE, NONE, ONE, 0.0, 0.0, false, K_LEATHER)
	var mid: Array = _row_at(belt, 0.104)
	var buckle: Vector3 = _ring_point(mid, -90.0, 0.004)
	r.add_shape("body", Models.bbox(0.058, 0.066, 0.012, 0.006), brass, buckle, NONE, ONE, 0.0, 0.85, true, K_METAL)
	r.add_shape("body", Models.bbox(0.034, 0.042, 0.016, 0.004), leather.darkened(0.3), buckle, NONE, ONE, 0.0, 0.0, true, K_LEATHER)
	r.add_shape("body", Models.bbox(0.04, 0.008, 0.02, 0.003), brass, buckle + Vector3(0.006, 0, -0.002), NONE, ONE, 0.0, 0.85, true, K_METAL)
	r.add_shape("body", MeshKit.sheet(0.03, 0.022, 0.11, 0.5, 0.004, -0.004, 0.0, 2, 3), leather_l, _ring_point(mid, -72.0, 0.006) + Vector3(0, 0.0, 0), Vector3(0, 0, -6), ONE, 0.0, 0.0, false, K_LEATHER)
	var pouch: Vector3 = _ring_point(mid, 198.0, 0.03)
	r.add_shape("body", Models.bbox(0.085, 0.1, 0.055, 0.02, 0.9, 0.9), leather_l, pouch + Vector3(0, -0.06, 0), Vector3(0, -72, 0), ONE, 0.0, 0.0, false, K_LEATHER)
	r.add_shape("body", Models.bbox(0.09, 0.05, 0.06, 0.018), leather, pouch + Vector3(0, -0.028, 0), Vector3(0, -72, 0), ONE, 0.0, 0.0, false, K_LEATHER)
	r.add_shape("body", Models.ball(0.008, 6, 3), brass, pouch + Vector3(-0.03, -0.045, 0.0), NONE, ONE, 0.0, 0.85, false, K_METAL)
	var pouch2: Vector3 = _ring_point(mid, 55.0, 0.022)
	r.add_shape("body", Models.bbox(0.06, 0.07, 0.04, 0.016, 0.9, 0.9), leather, pouch2 + Vector3(0, -0.045, 0), Vector3(0, -35, 0), ONE, 0.0, 0.0, false, K_LEATHER)
	var sash_at: Vector3 = _ring_point(mid, -52.0, 0.008)
	r.add_shape("body", MeshKit.sheet(0.11, 0.08, 0.36, 1.5, 0.012, -0.02, 0.05, 8, 8), sash, sash_at + Vector3(0, -0.02, 0), Vector3(0, -30, 0))
	r.add_shape("body", MeshKit.sheet(0.08, 0.05, 0.27, 1.5, 0.012, -0.03, 0.04, 6, 6), sash.darkened(0.2), sash_at + Vector3(0.035, -0.02, 0.012), Vector3(0, -45, -8))

	# ---- torso: shirt under a wrap coat with collar, lapped front, hem and baldric
	var top_w: float = sh - 0.03
	var trunk: Array = [
		[-0.075, 0.151 * wh, 0.098 * dw, 0.104 * dw, 0, 0, 0.15, 0.02], [0.02, 0.143 * waist, 0.093 * dw, 0.1 * dw, 0, 0, 0.15, 0.016],
		[0.1, 0.153 * lerpf(waist, chest, 0.5), 0.1 * depth, 0.106 * depth, 0, 0, 0.2], [0.2, 0.172 * chest, 0.114 * depth + 0.016 * bust, 0.112 * depth, 0, 0, 0.25],
		[0.27, 0.188 * chest, 0.118 * depth + 0.026 * bust, 0.116 * depth, 0, 0, 0.25], [0.33, top_w + 0.004, 0.108 * depth + 0.006 * bust, 0.112 * depth, 0, 0, 0.25],
		[0.385, top_w + 0.002, 0.094 * depth, 0.102 * depth, 0, 0, 0.2], [0.425, top_w * 0.8, 0.078 * depth, 0.092 * depth], [0.45, top_w * 0.52, 0.068 * depth, 0.082 * depth],
		[0.47, 0.08 * neck, 0.064, 0.072], [0.49, 0.066 * neck, 0.056, 0.062],
	]
	r.add_part("torso", "body", Vector3(0, 0.14, 0))
	r.add_shape("torso", _loft(trunk, 32, 3, 13), coat)
	r.add_shape("torso", _loft([[0.43, 0.064 * neck, 0.058 * neck, 0.064 * neck, 0, 0.004], [0.5, 0.057 * neck, 0.053 * neck, 0.06 * neck, 0, -0.002], [0.6, 0.052 * neck, 0.052 * neck, 0.056 * neck, 0, -0.01]], 18, 3), skin, NONE, NONE, ONE, 0.0, 0.0, false, K_SKIN)
	r.add_shape("torso", _loft([[0.44, 0.07 * neck, 0.064 * neck, 0.07 * neck], [0.488, 0.066 * neck, 0.061 * neck, 0.067 * neck], [0.5, 0.068 * neck, 0.063 * neck, 0.069 * neck]], 18, 2), shirt)
	var nk: float = 0.077 * neck
	r.add_shape("torso", _loft([[0.445, nk + 0.004, nk - 0.004, nk + 0.004], [0.5, nk + 0.012, nk + 0.002, nk + 0.012], [0.512, nk + 0.008, nk - 0.002, nk + 0.008], [0.5, nk + 0.003, nk - 0.007, nk + 0.003], [0.45, nk - 0.002, nk - 0.01, nk - 0.002]], 22, 2, 0, -58.0, 238.0), coat_l)
	# Lapped front panel with a trimmed edge and three toggles.
	var body_rows: Array = [trunk[0], trunk[1], trunk[2], trunk[3], trunk[4], trunk[5], trunk[6]]
	r.add_shape("torso", _loft(_grown(body_rows, 0.006), 14, 3, 0, -152.0, -72.0), coat_d)
	var edge: Array = []
	var edge_r: Array = []
	for i: int in 13:
		var y: float = lerpf(-0.07, 0.38, float(i) / 12.0)
		var at: Vector3 = _ring_point(_row_at(trunk, y), -72.0 - 18.0 * smoothstep(0.2, 0.38, y), 0.008)
		edge.append_array([at.x, at.y, at.z])
		edge_r.append(0.008)
	r.add_shape("torso", Models.tube(edge, edge_r, 5), coat_l)
	for y: float in [0.06, 0.16, 0.26]:
		var at: Vector3 = _ring_point(_row_at(trunk, y), -76.0, 0.012)
		r.add_shape("torso", Models.bbox(0.03, 0.012, 0.012, 0.004), leather_l, at, Vector3(0, 12, 0), ONE, 0.0, 0.0, false, K_LEATHER)
		r.add_shape("torso", Models.ball(0.007, 6, 3), brass, at + Vector3(0.016, 0, -0.002), NONE, ONE, 0.0, 0.85, false, K_METAL)
	# Coat skirt: flares under the belt, open at the front, with a turned hem.
	var hem_w: float = maxf(0.156 * wh, 0.168 * hip)
	var skirt: Array = [
		[-0.262, hem_w * 1.2, 0.128 * depth, 0.14 * depth, 0, 0, 0.1, 0.07], [-0.27, hem_w * 1.22, 0.132 * depth, 0.146 * depth, 0, 0, 0.1, 0.07],
		[-0.2, hem_w * 1.17, 0.124 * depth, 0.138 * depth, 0, 0, 0.1, 0.055], [-0.12, hem_w * 1.07, 0.112 * depth, 0.124 * depth, 0, 0, 0.1, 0.03],
		[-0.06, 0.156 * wh, 0.102 * dw, 0.108 * dw, 0, 0, 0.15, 0.02],
	]
	r.add_shape("torso", _loft(skirt, 30, 2, 11, -64.0, 244.0), coat)
	r.add_shape("torso", _loft(_grown([skirt[0], skirt[1]], 0.004), 30, 1, 11, -64.0, 244.0), coat_l)
	r.add_shape("torso", _loft([[-0.25, hem_w * 1.16, 0.122 * depth, 0.134 * depth, 0, 0, 0.1, 0.07], [-0.06, 0.148 * wh, 0.094 * dw, 0.1 * dw, 0, 0, 0.15, 0.02]], 30, 2, 11, 244.0, -64.0), coat_d)
	# Baldric from the left shoulder to the right hip, with a buckle on the chest.
	var strap: Array = []
	var strap_r: Array = []
	for i: int in 33:
		var ang: float = 360.0 * float(i) / 32.0
		var probe: Vector3 = _ring_point(_row_at(trunk, 0.2), ang)
		var y: float = clampf(0.2 - probe.x * 1.0, -0.05, 0.4)
		var at: Vector3 = _ring_point(_row_at(trunk, y), ang, 0.014)
		strap.append_array([at.x, at.y, at.z])
		strap_r.append(0.027)
	r.add_shape("torso", Models.tube(strap, strap_r, 6, 0.3, Vector3.UP), leather, NONE, NONE, ONE, 0.0, 0.0, false, K_LEATHER)
	var chest_buckle: Vector3 = _ring_point(_row_at(trunk, 0.22), -100.0, 0.024)
	r.add_shape("torso", Models.bbox(0.04, 0.05, 0.01, 0.005), brass, chest_buckle, Vector3(0, 0, 44), ONE, 0.0, 0.85, true, K_METAL)
	# One layered spaulder on the left shoulder.
	var pad := Vector3(-sh + 0.004, 0.352, 0)
	var pad_w := Vector3(lerpf(1.0, lw, 0.5) * 0.9, 0.9, 1.05)
	r.add_shape("torso", Models.lathe([0.1, -0.1, 0.108, -0.085, 0.11, -0.03, 0.098, -0.012], 20), leather, pad, Vector3(0, 0, 24), pad_w, 0.0, 0.0, false, K_LEATHER)
	r.add_shape("torso", Models.lathe([0.098, -0.06, 0.106, -0.045, 0.102, 0.0, 0.086, 0.04, 0.05, 0.072, 0.0, 0.082], 20), leather_l, pad, Vector3(0, 0, 18), pad_w, 0.0, 0.0, false, K_LEATHER)
	r.add_shape("torso", Models.lathe([0.104, -0.052, 0.111, -0.044, 0.104, -0.036], 20), brass.darkened(0.2), pad, Vector3(0, 0, 18), pad_w, 0.0, 0.8, false, K_METAL)
	r.add_shape("torso", Models.lathe([0.106, -0.092, 0.112, -0.085, 0.106, -0.078], 20), brass.darkened(0.2), pad, Vector3(0, 0, 24), pad_w, 0.0, 0.8, false, K_METAL)
	for k: int in 4:
		var a: float = TAU * (float(k) + 0.5) / 4.0
		r.add_shape("torso", Models.ball(0.008, 6, 3), brass, pad + Vector3(cos(a) * 0.085 - 0.01, 0.03, sin(a) * 0.095), NONE, ONE, 0.0, 0.85, false, K_METAL)

	_head(r, look, female, float(d["head"]), neck, depth + 0.12 * bust, skin, hair, accent)

	# ---- arms
	for side: int in [-1, 1]:
		var n: String = "left" if side < 0 else "right"
		var arm: String = "arm_" + n
		var fore: String = "forearm_" + n
		r.add_part(arm, "torso", Vector3(sh * side, 0.4, 0), Vector3(0, 0, 0.1 * side))
		var sleeve: Array = [
			[-0.335, 0.05 * lw, 0.052 * lw, 0.052 * lw, 0, 0, 0, 0.05], [-0.3, 0.056 * lw, 0.057 * lw, 0.057 * lw, 0, 0, 0, 0.06], [-0.26, 0.054 * lw, 0.055 * lw, 0.056 * lw, 0, 0, 0, 0.035],
			[-0.16, 0.06 * lw, 0.06 * lw, 0.062 * lw], [-0.08, 0.068 * lw, 0.066 * lw, 0.07 * lw], [-0.03, 0.066 * lw, 0.064 * lw, 0.067 * lw],
			[0.0, 0.054 * lw, 0.056 * lw, 0.058 * lw], [0.02, 0.03 * lw, 0.036 * lw, 0.038 * lw], [0.028, 0.01 * lw, 0.012 * lw, 0.012 * lw],
		]
		r.add_shape(arm, _loft(sleeve, 18, 3, 7), coat)
		r.add_part(fore, arm, Vector3(0, -0.31, 0), Vector3(0.35, 0, 0))
		var h: float = float(d["hand"]) * lerpf(1.0, lw, 0.45)
		if side < 0:
			r.add_shape(fore, _loft([[-0.11, 0.05 * lw, 0.05 * lw, 0.05 * lw], [-0.05, 0.052 * lw, 0.053 * lw, 0.053 * lw, 0, 0, 0, 0.04], [0.03, 0.054 * lw, 0.055 * lw, 0.055 * lw, 0, 0, 0, 0.05]], 18, 2, 7), coat)
			r.add_shape(fore, _loft([[-0.122, 0.053 * lw, 0.053 * lw, 0.053 * lw], [-0.11, 0.057 * lw, 0.057 * lw, 0.057 * lw], [-0.085, 0.057 * lw, 0.057 * lw, 0.057 * lw], [-0.075, 0.053 * lw, 0.053 * lw, 0.053 * lw]], 18, 1), coat_l)
			var bare: Array = [[-0.285, 0.024 * h, 0.03 * h, 0.03 * h], [-0.25, 0.027 * lw, 0.032 * lw, 0.032 * lw], [-0.18, 0.037 * lw, 0.04 * lw, 0.04 * lw], [-0.08, 0.045 * lw, 0.047 * lw, 0.047 * lw]]
			r.add_shape(fore, _loft(bare, 16, 3), skin, NONE, NONE, ONE, 0.0, 0.0, false, K_SKIN)
			# Linen wraps wound up the forearm and across the palm.
			var wind: Array = []
			var wind_r: Array = []
			for i: int in 61:
				var t: float = float(i) / 60.0
				var y: float = lerpf(-0.305, -0.15, t)
				var at: Vector3 = _ring_point(_row_at(bare, maxf(y, -0.285)), t * 360.0 * 6.5, 0.004)
				wind.append_array([at.x, y, at.z])
				wind_r.append(0.0125)
			r.add_shape(fore, Models.tube(wind, wind_r, 5, 0.3, Vector3.UP), wrap)
			r.add_shape(fore, _loft(_grown([[-0.338, 0.02 * h, 0.041 * h, 0.041 * h, 0, 0, 0.3], [-0.32, 0.021 * h, 0.04 * h, 0.04 * h, 0, 0, 0.3], [-0.298, 0.021 * h, 0.036 * h, 0.036 * h, 0, 0, 0.3]], 0.0025), 14, 1), wrap_d)
			_hand(r, fore, side, h, skin, K_SKIN, 0.0)
		else:
			r.add_shape(fore, _loft([[-0.06, 0.05 * lw, 0.05 * lw, 0.05 * lw], [0.03, 0.054 * lw, 0.055 * lw, 0.055 * lw, 0, 0, 0, 0.05]], 18, 2, 7), coat)
			r.add_shape(fore, Models.lathe(_wide([0.04, -0.285, 0.05, -0.27, 0.055, -0.18, 0.066, -0.06, 0.082, -0.01, 0.076, 0.02, 0.05, 0.03], lw), 14), steel, NONE, NONE, ONE, 0.0, 0.9, false, K_METAL)
			for y: float in [-0.21, -0.13]:
				r.add_shape(fore, Models.lathe(_wide([0.056, y - 0.012, 0.068, y, 0.06, y + 0.012], lw), 14), steel.darkened(0.35), NONE, NONE, ONE, 0.0, 0.9, true, K_METAL)
			r.add_shape(fore, Models.lathe(_wide([0.078, -0.022, 0.087, -0.01, 0.078, 0.002], lw), 14), brass.darkened(0.15), NONE, NONE, ONE, 0.0, 0.85, true, K_METAL)
			for k: int in 5:
				var a: float = TAU * float(k) / 5.0 + 0.3
				r.add_shape(fore, Models.ball(0.0065, 6, 3), brass, Vector3(cos(a) * 0.07 * lw, -0.045, sin(a) * 0.07 * lw), NONE, ONE, 0.0, 0.85, false, K_METAL)
			r.add_shape(fore, Models.ball(0.06 * lw, 10, 5), steel.darkened(0.2), Vector3(0, 0.0, 0.03), NONE, Vector3(0.9, 0.9, 0.7), 0.0, 0.9, true, K_METAL)
			_hand(r, fore, side, h * 1.12, iron, K_METAL, 0.8)
			r.add_shape(fore, Models.bbox(0.05 * h, 0.03, 0.094 * h, 0.008), steel, Vector3(0.012 * side, -0.335, -0.002), NONE, ONE, 0.0, 0.9, true, K_METAL)
			r.add_shape(fore, Models.bbox(0.012, 0.012, 0.096 * h, 0.004), accent, Vector3(0.036 * h * side, -0.35, -0.002), NONE, ONE, 0.6)
	# Weapons ride here (see ModelRig.set_weapon): -Z runs forward-and-down out of the fist.
	r.add_part("hand_right", "forearm_right", Vector3(0, -0.33, 0), Vector3(deg_to_rad(-45.0), 0, 0))

	# Shown instead of the right arm: torn sleeve, a fat bandaged stump with a stained end,
	# a sling strap wound across the chest and a loose bandage tail.
	var st: String = "arm_right_stump"
	var blood := Color(0.4, 0.04, 0.04)
	r.add_part(st, "torso", Vector3(sh, 0.4, 0))
	r.add_shape(st, _loft([[-0.075, 0.08 * lw, 0.08 * lw, 0.08 * lw, 0, 0, 0, 0.12], [-0.02, 0.07 * lw, 0.068 * lw, 0.07 * lw, 0, 0, 0, 0.04], [0.03, 0.058 * lw, 0.058 * lw, 0.058 * lw], [0.066, 0.02 * lw, 0.02 * lw, 0.02 * lw]], 18, 3, 6), coat)
	r.add_shape(st, Models.ball(0.09 * lerpf(1.0, lw, 0.6), 16, 8), wrap, Vector3(0.012, -0.06, 0), NONE, Vector3(1.0, 0.95, 1.0))
	r.add_shape(st, _loft([[-0.22, 0.05 * lw, 0.05 * lw, 0.05 * lw], [-0.2, 0.074 * lw, 0.074 * lw, 0.074 * lw], [-0.1, 0.084 * lw, 0.084 * lw, 0.084 * lw], [-0.02, 0.074 * lw, 0.074 * lw, 0.074 * lw]], 16, 3), wrap, Vector3(0.012, 0, 0), Vector3(0, 0, 12))
	var bind: Array = []
	var bind_r: Array = []
	for i: int in 41:
		var t: float = float(i) / 40.0
		var a: float = t * TAU * 4.0
		var rad: float = lerpf(0.078, 0.088, sin(t * PI)) * lw
		bind.append_array([cos(a) * rad, lerpf(-0.2, -0.04, t), sin(a) * rad])
		bind_r.append(0.014)
	r.add_shape(st, Models.tube(bind, bind_r, 5, 0.3, Vector3.UP), wrap_d, Vector3(0.012, 0, 0), Vector3(0, 0, 12))
	r.add_shape(st, Models.ball(0.07 * lw, 12, 6), blood, Vector3(0.056, -0.205, 0), Vector3(0, 0, 12), Vector3(1.0, 0.45, 1.0), 0.12)
	var sling: Array = []
	var sling_r: Array = []
	for i: int in 33:
		var ang: float = 360.0 * float(i) / 32.0
		var probe: Vector3 = _ring_point(_row_at(trunk, 0.2), ang)
		var y: float = clampf(0.2 + probe.x * 0.9, -0.04, 0.41)
		var at: Vector3 = _ring_point(_row_at(trunk, y), ang, 0.02)
		sling.append_array([at.x - sh, at.y - 0.4, at.z])
		sling_r.append(0.034)
	r.add_shape(st, Models.tube(sling, sling_r, 6, 0.3, Vector3.UP), wrap)
	r.add_shape(st, Models.tube([0.055, -0.2, 0.02, 0.07, -0.28, 0.04, 0.06, -0.36, 0.05, 0.075, -0.41, 0.045], [0.02, 0.024, 0.02, 0.006], 5, 0.3), wrap_d)
	r.get_part(st).visible = false

	r.finish()
	return r


## A hand hanging from the wrist: a shaped palm, four curled fingers and a thumb. `h` scales
## it; `side` is -1 left / +1 right (the palm faces the body).
static func _hand(r: ModelRig, part: String, side: int, h: float, color: Color, kind: int, gloss: float) -> void:
	var c: float = -float(side)
	var palm: Array = [
		[-0.356, 0.014 * h, 0.036 * h, 0.036 * h, 0, 0, 0.35], [-0.338, 0.019 * h, 0.041 * h, 0.04 * h, 0, 0, 0.35],
		[-0.305, 0.02 * h, 0.037 * h, 0.036 * h, 0, 0, 0.3], [-0.275, 0.019 * h, 0.027 * h, 0.027 * h, 0, 0, 0.2], [-0.262, 0.016 * h, 0.022 * h, 0.022 * h],
	]
	r.add_shape(part, _loft(palm, 14, 3), color, NONE, NONE, ONE, 0.0, gloss, false, kind)
	var reach: Array[float] = [0.95, 1.0, 0.96, 0.8]
	for i: int in 4:
		var z: float = (-0.029 + 0.0193 * float(i)) * h
		var flen: float = reach[i]
		var path: Array = [
			0.0, -0.345, z,
			c * 0.004 * h, -0.345 - 0.03 * flen * h, z,
			c * 0.016 * h, -0.345 - 0.052 * flen * h, z * 0.96,
			c * 0.03 * h, -0.345 - 0.06 * flen * h, z * 0.92,
			c * 0.04 * h, -0.345 - 0.052 * flen * h, z * 0.9,
		]
		var thick: float = (0.0098 if i < 3 else 0.0086) * h
		r.add_shape(part, Models.tube(path, [thick, thick, thick * 0.95, thick * 0.86, thick * 0.7], 7), color, NONE, NONE, ONE, 0.0, gloss, false, kind)
		r.add_shape(part, Models.ball(thick * 0.75, 6, 3), color, Vector3(c * 0.04 * h, -0.345 - 0.052 * flen * h, z * 0.9), NONE, ONE, 0.0, gloss, false, kind)
	var thumb: Array = [
		c * 0.004 * h, -0.288, -0.03 * h,
		c * 0.01 * h, -0.312, -0.05 * h,
		c * 0.022 * h, -0.338, -0.056 * h,
		c * 0.03 * h, -0.358, -0.052 * h,
	]
	r.add_shape(part, Models.tube(thumb, [0.0125 * h, 0.0118 * h, 0.01 * h, 0.008 * h], 7), color, NONE, NONE, ONE, 0.0, gloss, false, kind)
	r.add_shape(part, Models.ball(0.0062 * h, 6, 3), color, Vector3(c * 0.03 * h, -0.358, -0.052 * h), NONE, ONE, 0.0, gloss, false, kind)


## Head: sculpted skin, eyes with lids, brows, lips, ears, face-variant extras, hair, band.
static func _head(r: ModelRig, look: Dictionary, female: bool, head_scale: float, neck: float, chest_depth: float, skin: Color, hair: Color, accent: Color) -> void:
	var face: String = look["face"]
	var style: String = look["hair"]
	var hk := HeadKit.new(_face_tune(face, female))
	var at := Vector3(0, 0.118 + 0.118 * head_scale * 0.06, 0.004)
	r.add_part("head", "torso", Vector3(0, 0.5, 0))
	r.add_part("skull", "head", at).scale = ONE * head_scale
	var p: String = "skull"
	r.add_shape(p, hk.skin_mesh(), skin, NONE, NONE, ONE, 0.0, 0.0, false, K_SKIN)
	var shade: Color = skin.darkened(0.45)
	var lip: Color = skin.lerp(Color(0.52, 0.27, 0.25), 0.4 if female else 0.22)
	var iris := Color(0.2, 0.14, 0.09)
	var heavy: bool = face == "heavy"
	for side: int in [-1, 1]:
		var s: float = float(side)
		# Eyeball set back in the socket, iris, pupil, a catch-light, lids and a lash line.
		var eye: Vector3 = hk.face(0.42 * s, 0.085) + Vector3(0, 0, 0.0075)
		var open: float = 1.08 if female else 1.0
		r.add_shape(p, Models.ball(0.0128, 14, 7), Color(0.74, 0.72, 0.68), eye, NONE, ONE, 0.0, 0.5)
		r.add_shape(p, Models.ball(0.0066, 10, 5), iris, eye + Vector3(0, 0, -0.0108), NONE, Vector3(1.0, 1.0, 0.35), 0.0, 0.7)
		r.add_shape(p, Models.ball(0.003, 8, 4), Color(0.01, 0.01, 0.012), eye + Vector3(0, 0, -0.0126), NONE, Vector3(1.0, 1.0, 0.35), 0.0, 0.9)
		r.add_shape(p, Models.ball(0.0012, 6, 3), Color(1, 1, 1), eye + Vector3(0.002, 0.0022, -0.0131), NONE, ONE, 0.5)
		var lid_up: Array = []
		var lid_low: Array = []
		for k: int in 7:
			var t: float = float(k) / 6.0 * 2.0 - 1.0
			var arc: float = 1.0 - t * t
			lid_up.append_array([eye.x + t * 0.0155, eye.y + (0.0015 + 0.0072 * arc * open) - (0.002 if heavy else 0.0), eye.z - 0.0085 - 0.0045 * arc])
			lid_low.append_array([eye.x + t * 0.0145, eye.y - 0.0025 - 0.0048 * arc, eye.z - 0.0085 - 0.0035 * arc])
		r.add_shape(p, Models.tube(lid_up, [0.002, 0.0034, 0.004, 0.0042, 0.004, 0.0034, 0.002], 5), skin.darkened(0.12), NONE, NONE, ONE, 0.0, 0.0, false, K_SKIN)
		r.add_shape(p, Models.tube(lid_low, [0.0016, 0.0026, 0.003, 0.003, 0.003, 0.0026, 0.0016], 5), skin.darkened(0.06), NONE, NONE, ONE, 0.0, 0.0, false, K_SKIN)
		var lash: Array = []
		for k: int in 7:
			var t: float = float(k) / 6.0 * 2.0 - 1.0
			var arc: float = 1.0 - t * t
			lash.append_array([eye.x + t * 0.0158, eye.y + (0.0002 + 0.0066 * arc * open) - (0.002 if heavy else 0.0), eye.z - 0.0102 - 0.0048 * arc])
		var lash_w: float = 0.0019 if female else 0.0012
		r.add_shape(p, Models.tube(lash, [lash_w * 0.5, lash_w, lash_w, lash_w, lash_w, lash_w, lash_w * 0.6], 4), Color(0.05, 0.04, 0.04))
		# Brow: a tapered strip of hair laid along the ridge.
		var brow: Array = []
		var brow_r: Array = []
		var lift: float = 0.0 if not female else 0.018
		var split: bool = face == "scarred" and side < 0
		for k: int in 9:
			var t: float = float(k) / 8.0
			var u: float = lerpf(0.13, 0.74, t)
			var w: float = 0.2 + lift + (0.035 if not heavy else 0.008) * sin(t * PI * 0.8) - (0.03 if heavy else 0.0) * (1.0 - t) - 0.03 * t * t
			if face == "gaunt":
				w += 0.012
			var pt: Vector3 = hk.face(u * s, w, 0.0018)
			brow.append_array([pt.x, pt.y, pt.z])
			var thick: float = (0.0052 if heavy else (0.0026 if female else 0.004)) * lerpf(1.0, 0.45, t * t)
			if split and k == 5:
				thick = 0.0004
			brow_r.append(thick)
		r.add_shape(p, Models.tube(brow, brow_r, 5, 0.6, Vector3.UP), hair.lerp(shade, 0.15), NONE, NONE, ONE, 0.0, 0.0, false, K_HAIR)
		# Ear: an outer shell with a darker hollow and a lobe.
		var ear: Vector3 = hk.on(hk.dir_at(1.62 * s, -0.03), 0.003)
		r.add_shape(p, Models.ball(0.03, 12, 6), skin.darkened(0.05), ear + Vector3(0.002 * s, 0, 0.004), Vector3(0, -28.0 * s, 8.0 * s), Vector3(0.3, 1.0, 0.62), 0.0, 0.0, false, K_SKIN)
		r.add_shape(p, Models.ball(0.018, 10, 5), skin.darkened(0.4), ear + Vector3(0.006 * s, 0.003, -0.001), Vector3(0, -28.0 * s, 8.0 * s), Vector3(0.3, 1.0, 0.6), 0.0, 0.0, false, K_SKIN)
		r.add_shape(p, Models.ball(0.009, 8, 4), skin.darkened(0.03), ear + Vector3(0.001 * s, -0.024, 0.0), NONE, Vector3(0.6, 1.0, 0.8), 0.0, 0.0, false, K_SKIN)
		# Nostril shadow.
		r.add_shape(p, Models.ball(0.0042, 6, 3), shade, hk.face(0.105 * s, -0.235, -0.0012), NONE, Vector3(1.2, 0.6, 1.0))
	# Lips as two shaped rolls with the mouth line between them.
	var full: float = 1.25 if female else 1.0
	var top_lip: Array = []
	var low_lip: Array = []
	var line: Array = []
	for k: int in 9:
		var t: float = float(k) / 8.0 * 2.0 - 1.0
		var a: Vector3 = hk.face(t * 0.21, -0.39 + 0.01 * (1.0 - absf(t)) - 0.02 * t * t, -0.0012)
		var b: Vector3 = hk.face(t * 0.18, -0.456 + 0.026 * t * t, -0.0014)
		var m: Vector3 = hk.face(t * 0.235, -0.422 - 0.006 * t * t, -0.0002)
		top_lip.append_array([a.x, a.y, a.z])
		low_lip.append_array([b.x, b.y, b.z])
		line.append_array([m.x, m.y, m.z])
	var taper: Array = [0.0006, 0.0018, 0.0026, 0.003, 0.0027, 0.003, 0.0026, 0.0018, 0.0006]
	var taper_low: Array = []
	for v: float in [0.0006, 0.002, 0.003, 0.0036, 0.0039, 0.0036, 0.003, 0.002, 0.0006]:
		taper_low.append(v * full)
	r.add_shape(p, Models.tube(top_lip, taper, 6, 0.6, Vector3.UP), lip, NONE, NONE, ONE, 0.0, 0.0, false, K_SKIN)
	r.add_shape(p, Models.tube(low_lip, taper_low, 6, 0.6, Vector3.UP), lip.lightened(0.06), NONE, NONE, ONE, 0.0, 0.0, false, K_SKIN)
	r.add_shape(p, Models.tube(line, [0.0006, 0.0014, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0014, 0.0006], 4), lip.darkened(0.6))

	match face:
		"scarred":
			var scar: Color = skin.lerp(Color(0.7, 0.4, 0.38), 0.6)
			var cut: Array = []
			for k: int in 8:
				var t: float = float(k) / 7.0
				var pt: Vector3 = hk.face(lerpf(-0.5, -0.33, t), lerpf(0.4, -0.2, t), 0.0006)
				if absf(t - 0.42) < 0.12:
					continue
				cut.append_array([pt.x, pt.y, pt.z])
			var cut_r: Array = []
			for k: int in cut.size() / 3:
				cut_r.append(0.0022 * sin(clampf((float(k) + 0.5) / float(cut.size() / 3), 0.05, 0.95) * PI))
			r.add_shape(p, Models.tube(cut, cut_r, 4), scar, NONE, NONE, ONE, 0.0, 0.0, false, K_SKIN)
			var nick: Array = []
			for k: int in 4:
				var pt: Vector3 = hk.face(0.13 + 0.02 * float(k), -0.33 - 0.05 * float(k), 0.0008)
				nick.append_array([pt.x, pt.y, pt.z])
			r.add_shape(p, Models.tube(nick, [0.0006, 0.0017, 0.0017, 0.0006], 4), scar, NONE, NONE, ONE, 0.0, 0.0, false, K_SKIN)
		"stubble":
			var grain: ArrayMesh = hk.shell("beard", 0.0011)
			if grain != null:
				r.add_shape(p, grain, skin.lerp(hair, 0.42), NONE, NONE, ONE, 0.0, 0.0, false, K_HAIR)
		"bearded":
			var fur: ArrayMesh = hk.shell("beard", 0.014, 26.0, 0.16)
			if fur != null:
				r.add_shape(p, fur, hair, NONE, NONE, ONE, 0.0, 0.0, false, K_HAIR)
		"gaunt":
			for side: int in [-1, 1]:
				var crease: Array = []
				for k: int in 5:
					var t: float = float(k) / 4.0
					var pt: Vector3 = hk.face(float(side) * lerpf(0.2, 0.34, t), lerpf(-0.22, -0.46, t), 0.0002)
					crease.append_array([pt.x, pt.y, pt.z])
				r.add_shape(p, Models.tube(crease, [0.0005, 0.0015, 0.0018, 0.0015, 0.0005], 4), shade.lerp(skin, 0.4))

	var hair_depth: float = _hair(r, hk, style, female, skin, hair, chest_depth, head_scale)

	if str(look["band"]) == "on":
		var loop: Array = []
		var loop_r: Array = []
		for k: int in 37:
			var az: float = TAU * float(k) / 36.0 - PI
			var pt: Vector3 = hk.on(hk.dir_at(az, 0.44 - 0.14 * smoothstep(1.0, 2.6, absf(az))), hair_depth + 0.0035)
			loop.append_array([pt.x, pt.y, pt.z])
			loop_r.append(0.0125)
		r.add_shape(p, Models.tube(loop, loop_r, 6, 0.3, Vector3.UP), accent, NONE, NONE, ONE, 0.22)
		var knot: Vector3 = hk.on(hk.dir_at(PI, 0.3), hair_depth + 0.012) * head_scale + at
		r.add_shape("head", Models.ball(0.014, 8, 4), accent, knot, NONE, Vector3(1.3, 0.9, 0.9), 0.22)
		r.add_part("band_tail", "head", knot, Vector3(0.75, 0, 0))
		r.add_shape("band_tail", Models.tube([-0.008, 0.0, 0.0, -0.03, -0.01, 0.09, -0.045, 0.0, 0.2, -0.03, -0.02, 0.3], [0.014, 0.019, 0.017, 0.006], 5, 0.22, Vector3.RIGHT), accent, NONE, NONE, ONE, 0.22)
		r.add_shape("band_tail", Models.tube([0.008, 0.0, 0.0, 0.03, -0.02, 0.08, 0.05, -0.05, 0.16, 0.045, -0.09, 0.22], [0.014, 0.019, 0.015, 0.006], 5, 0.22, Vector3.RIGHT), accent, NONE, NONE, ONE, 0.22)
		r.sway_parts["band_tail"] = -0.6


## One lock of hair laid from direction `from` to direction `to` over the scalp (through the
## crown if `over_top`), rising from `lift_a` to `lift_b` off the skin.
static func _lock(hk: HeadKit, from: Vector3, to: Vector3, lift_a: float, lift_b: float, over_top: bool, steps: int = 6) -> Array:
	var path: Array = []
	for k: int in steps + 1:
		var t: float = float(k) / float(steps)
		var dir: Vector3
		if over_top:
			var top := Vector3(0, 1, 0.12).normalized()
			dir = from.slerp(top, t * 2.0) if t < 0.5 else top.slerp(to, t * 2.0 - 1.0)
		else:
			dir = from.slerp(to, t)
		var pt: Vector3 = hk.on(dir, lerpf(lift_a, lift_b, t))
		path.append_array([pt.x, pt.y, pt.z])
	return path


static func _taper(count: int, thick: float, tip: float = 0.15) -> Array:
	var out: Array = []
	for k: int in count:
		var t: float = float(k) / float(count - 1)
		out.append(thick * lerpf(0.6, 1.0, sin(minf(t * 2.2, 1.0) * PI * 0.5)) * lerpf(1.0, tip, t * t * t))
	return out


## Hair: a scalp-hugging layer with a proper hairline, then locks over it. Returns the depth
## of hair at the headband line so the band can sit on top.
static func _hair(r: ModelRig, hk: HeadKit, style: String, female: bool, skin: Color, hair: Color, chest_depth: float, head_scale: float) -> float:
	var p: String = "skull"
	var light: Color = hair.lightened(0.08)
	var dark: Color = hair.darkened(0.2)
	var fuzz: Color = skin.lerp(hair, 0.55)
	var burn: float = 0.0 if female else 1.0
	var depth: float = 0.01
	var golden: float = 2.39996
	match style:
		"shaved":
			depth = 0.0012
			r.add_shape(p, hk.shell("hair", depth, 0.0, 0.0, burn * 0.5), fuzz, NONE, NONE, ONE, 0.0, 0.0, false, K_HAIR)
		"cropped":
			depth = 0.007
			r.add_shape(p, hk.shell("hair", depth, 46.0, 0.14, burn), hair, NONE, NONE, ONE, 0.0, 0.0, false, K_HAIR)
			for k: int in 14:
				var az: float = lerpf(-1.0, 1.0, float(k) / 13.0)
				var from: Vector3 = hk.dir_at(az, HeadKit.hairline(az, burn) + 0.16)
				var to: Vector3 = hk.dir_at(az * 1.1 + 0.1, HeadKit.hairline(az, burn) + 0.02)
				r.add_shape(p, Models.tube(_lock(hk, from, to, 0.006, 0.01, false, 3), _taper(4, 0.011), 5, 0.45), light if k % 2 == 0 else hair, NONE, NONE, ONE, 0.0, 0.0, false, K_HAIR)
		"topknot":
			depth = 0.006
			r.add_shape(p, hk.shell("hair", depth, 60.0, 0.2, burn), hair, NONE, NONE, ONE, 0.0, 0.0, false, K_HAIR)
			var knot_dir := Vector3(0, 0.86, 0.5).normalized()
			for k: int in 22:
				var az: float = TAU * float(k) / 22.0 - PI + 0.1
				var from: Vector3 = hk.dir_at(az, HeadKit.hairline(az, burn) + 0.05)
				r.add_shape(p, Models.tube(_lock(hk, from, knot_dir, 0.005, 0.012, false, 5), _taper(6, 0.012, 0.6), 5, 0.4), light if k % 2 == 0 else hair, NONE, NONE, ONE, 0.0, 0.0, false, K_HAIR)
			var bun: Vector3 = hk.on(knot_dir, 0.03)
			r.add_shape(p, Models.ball(0.034, 14, 7), hair, bun, Vector3(-25, 0, 0), Vector3(1.0, 0.8, 1.0), 0.0, 0.0, false, K_HAIR)
			r.add_shape(p, Models.torus(0.017, 0.03, 12, 5), Models.LEATHER.lightened(0.15), hk.on(knot_dir, 0.014), Vector3(-30, 0, 0), ONE, 0.0, 0.0, false, K_LEATHER)
			r.add_shape(p, Models.tube([bun.x, bun.y + 0.02, bun.z + 0.01, bun.x, bun.y + 0.035, bun.z + 0.045, bun.x, bun.y + 0.005, bun.z + 0.075], [0.016, 0.013, 0.0], 6), light, NONE, NONE, ONE, 0.0, 0.0, false, K_HAIR)
		"long", "braid":
			depth = 0.012
			r.add_shape(p, hk.shell("hair", depth, 30.0, 0.22, burn), hair, NONE, NONE, ONE, 0.0, 0.0, false, K_HAIR)
			var part_dir := Vector3(-0.12, 1.0, -0.05).normalized()
			var count: int = 26 if style == "long" else 18
			for k: int in count:
				var t: float = float(k) / float(count - 1)
				var az: float = lerpf(-PI + 0.25, PI - 0.25, t)
				if absf(az) < 0.62:
					az = 0.62 * signf(az) + az * 0.2
				var line: float = HeadKit.hairline(az, burn)
				var to: Vector3 = hk.dir_at(az, line + (0.04 if style == "long" else 0.0))
				var path: Array = _lock(hk, part_dir, to, 0.008, 0.016, false, 5)
				var n: int = path.size()
				var end := Vector3(float(path[n - 3]), float(path[n - 2]), float(path[n - 1]))
				if style == "long":
					# Fall free past the jaw to the shoulders, flaring a little.
					var out := Vector3(end.x, 0, end.z).normalized()
					var drop: float = lerpf(0.2, 0.26, absf(az) / PI) + 0.012 * sin(float(k) * golden)
					var floor_y: float = -0.215 if absf(az) > 1.0 else -0.2
					var mid: Vector3 = end + out * 0.016 + Vector3(0, -0.07, 0)
					var tip: Vector3 = Vector3(end.x + out.x * 0.03, maxf(end.y - drop, floor_y), end.z + out.z * 0.03 + (0.02 if absf(az) > 2.0 else 0.0))
					path.append_array([mid.x, mid.y, mid.z, lerpf(mid.x, tip.x, 0.6), lerpf(mid.y, tip.y, 0.6), lerpf(mid.z, tip.z, 0.6), tip.x, tip.y, tip.z])
				r.add_shape(p, Models.tube(path, _taper(path.size() / 3, 0.02, 0.25), 6, 0.42), [hair, light, dark][k % 3], NONE, NONE, ONE, 0.0, 0.0, false, K_HAIR)
			if style == "braid":
				# Gathered at the nape, then a plait brought forward over the right shoulder.
				var cz: float = chest_depth
				var route: Array[Vector3] = [Vector3(0.0, -0.075, 0.088), Vector3(0.05, -0.125, 0.082), Vector3(0.1, -0.165, 0.03), Vector3(0.112, -0.2, -0.05 * cz), Vector3(0.105, -0.27, -0.118 * cz), Vector3(0.095, -0.36, -0.132 * cz), Vector3(0.09, -0.44, -0.13 * cz)]
				var links: int = 16
				for k: int in links:
					var t: float = float(k) / float(links - 1) * float(route.size() - 1)
					var i: int = mini(int(t), route.size() - 2)
					var at: Vector3 = route[i].lerp(route[i + 1], t - float(i)) / head_scale
					var flip: float = 1.0 if k % 2 == 0 else -1.0
					var size: float = lerpf(0.026, 0.016, float(k) / float(links - 1))
					r.add_shape(p, Models.ball(size, 10, 5), [hair, light][k % 2], at + Vector3(0.006 * flip, 0, 0), Vector3(20.0, 0, 32.0 * flip), Vector3(0.85, 1.2, 0.8), 0.0, 0.0, false, K_HAIR)
				var tail: Vector3 = route[route.size() - 1] / head_scale
				r.add_shape(p, Models.torus(0.008, 0.019, 10, 4), Models.LEATHER.lightened(0.2), tail + Vector3(0, -0.012, 0), NONE, ONE, 0.0, 0.0, false, K_LEATHER)
				r.add_shape(p, Models.lathe([0.0, -0.06, 0.012, -0.03, 0.015, 0.0], 8), light, tail + Vector3(0, -0.016, 0), NONE, ONE, 0.0, 0.0, false, K_HAIR)
		"undercut":
			depth = 0.0012
			r.add_shape(p, hk.shell("sides", depth, 0.0, 0.0, burn * 0.6), fuzz, NONE, NONE, ONE, 0.0, 0.0, false, K_HAIR)
			r.add_shape(p, hk.shell("top", 0.017, 34.0, 0.2, burn), hair, NONE, NONE, ONE, 0.0, 0.0, false, K_HAIR)
			for k: int in 18:
				var t: float = float(k) / 17.0
				var from: Vector3 = Vector3(-0.42, 0.78, lerpf(-0.5, 0.42, t)).normalized()
				var to: Vector3 = Vector3(0.62, 0.62, lerpf(-0.62, 0.5, t)).normalized()
				r.add_shape(p, Models.tube(_lock(hk, from, to, 0.012, 0.026 - 0.008 * t, false, 5), _taper(6, 0.017, 0.3), 6, 0.45), [hair, light, dark][k % 3], NONE, NONE, ONE, 0.0, 0.0, false, K_HAIR)
		"swept":
			depth = 0.013
			r.add_shape(p, hk.shell("hair", depth, 38.0, 0.25, burn), hair, NONE, NONE, ONE, 0.0, 0.0, false, K_HAIR)
			for k: int in 20:
				var t: float = float(k) / 19.0
				var az: float = lerpf(-1.25, 1.25, t)
				var from: Vector3 = hk.dir_at(az, HeadKit.hairline(az, burn) + 0.03)
				var to: Vector3 = hk.dir_at((PI - 0.25 - absf(az) * 0.55) * (1.0 if az >= 0.0 else -1.0), -0.3)
				r.add_shape(p, Models.tube(_lock(hk, from, to, 0.012, 0.02, true, 8), _taper(9, 0.017, 0.35), 6, 0.45), [hair, light, dark][k % 3], NONE, NONE, ONE, 0.0, 0.0, false, K_HAIR)
		_:
			# "messy": short uneven locks thrown out from the crown, a ragged fringe.
			depth = 0.01
			r.add_shape(p, hk.shell("hair", depth, 24.0, 0.2, burn), hair, NONE, NONE, ONE, 0.0, 0.0, false, K_HAIR)
			var crown := Vector3(0.05, 1.0, 0.1).normalized()
			for k: int in 40:
				var az: float = fmod(float(k) * golden, TAU) - PI
				var line: float = HeadKit.hairline(az, burn)
				var fall: float = 0.25 + 0.35 * fmod(float(k) * 0.618, 1.0)
				var to: Vector3 = hk.dir_at(az + 0.3, lerpf(0.9, line - 0.04, fall))
				var from: Vector3 = crown.slerp(to, 0.25)
				var rise: float = 0.014 + 0.012 * fmod(float(k) * 0.37, 1.0)
				r.add_shape(p, Models.tube(_lock(hk, from, to, 0.008, rise, false, 4), _taper(5, 0.016, 0.1), 6, 0.45), [hair, light, dark][k % 3], NONE, NONE, ONE, 0.0, 0.0, false, K_HAIR)
			for k: int in 9:
				var az: float = lerpf(-0.75, 0.75, float(k) / 8.0)
				var from: Vector3 = hk.dir_at(az * 0.8, 0.86)
				var to: Vector3 = hk.dir_at(az + 0.12, HeadKit.hairline(az, burn) - 0.07 - 0.05 * fmod(float(k) * 0.618, 1.0))
				r.add_shape(p, Models.tube(_lock(hk, from, to, 0.01, 0.016, false, 4), _taper(5, 0.014, 0.1), 6, 0.45), [light, hair][k % 2], NONE, NONE, ONE, 0.0, 0.0, false, K_HAIR)
	return depth
