class_name Models
extends RefCounted
## Procedural art library. Every builder returns a finished ModelRig assembled in code from
## Godot primitives and MeshKit shapes - no image or mesh assets. All designs are original
## to this project. Identical models are baked once and stamped out from a snapshot.
##
## Usage:  var rig := Models.enemy("brute");  add_child(rig);  rig.animate(delta, speed, attacking)

const ENEMY_DATA_PATH := "res://data/enemies.json"

# A deliberately muted, low-value palette: worn cloth, leather, dull metal. Each character
# gets ONE restrained emissive accent; kinds are told apart by silhouette, not body colour.
const SKIN := Color(0.68, 0.52, 0.41)
const BONE := Color(0.72, 0.67, 0.54)
const STEEL := Color(0.46, 0.49, 0.53)
const IRON := Color(0.12, 0.12, 0.15)
const LEATHER := Color(0.23, 0.155, 0.1)
const WOOD := Color(0.28, 0.19, 0.12)

## How many different tufts / shrubs are baked per scenery kind.
const SCENERY_VARIANTS := 6

static var _enemy_data: Dictionary = {}
## Multiplier on the segment counts of lathe() / ball() / cyl() while a model is being built.
static var _detail: float = 1.0
static var _snaps: Dictionary[String, Dictionary] = {}


# ---------------------------------------------------------------- public builders

## The hero: a lean brawler (about 7.4 heads tall) in a weathered slate coat with a leather
## baldric and one spaulder, linen hand-wraps, a dull steel gauntlet on the right arm and a
## single cyan accent (headband and gauntlet knuckle). `look` customises it (see look_options();
## {} is the stock look); two different looks never share a mesh. Supports
## set_part_visible("arm_right", false), which swaps the arm for a big bandaged stump with a
## sling strap across the chest, and set_weapon() (see weapon()).
static func player(look: Dictionary = {}) -> ModelRig:
	return _stamp(PlayerLook.cache_key(look), PlayerLook.build.bind(look))


## Every customisation option for the character creator: look key -> Array of
## {"id": String, "label": String} (plus "color": Color for colour options), in display
## order with the default first. Keys: body, skin, face, hair, hair_color, band, coat, accent.
static func look_options() -> Dictionary:
	return PlayerLook.options()


## The stock look (first option of every key) - the player as it is without a creator.
static func default_look() -> Dictionary:
	return PlayerLook.default_look()


## A complete, valid look: missing keys filled, unknown or stale ids replaced by defaults.
static func normalize_look(look: Dictionary) -> Dictionary:
	return PlayerLook.normalize(look)


## An enemy model for a kind in data/enemies.json ("grunt", "brute", "commander"). Radius,
## height and base colour come from that file. Unknown kinds get a plain figure.
static func enemy(kind: String) -> ModelRig:
	var look: Dictionary = GameData.enemy_looks.get(kind, {})
	var real: bool = bool((GameData.balance.get("art", {}) as Dictionary).get("real_bodies", false)) or OS.get_cmdline_user_args().has("--real-body")
	if real and not look.is_empty() and RealCharacter.exists("body_" + str(look.get("body", "male"))):
		var rc: RealCharacter = RealCharacter.create("body_" + str(look.get("body", "male")))
		rc.make_enemy(look, GameData.enemies.get(kind, {}))
		return rc
	return _stamp("enemy:" + kind, _build_enemy.bind(kind))


## Living scenery: "grass" (a tuft of curved blades with pale seed heads, ~0.8 tall) or
## "bush" (a clumpy berry shrub, ~1.1 tall). Each call picks one of a few variants and a
## random facing. The returned node is a ModelRig, so set_highlight() / flash() work on it;
## scale it freely to show damage.
static func scenery(kind: String) -> Node3D:
	var which: String = "bush" if kind == "bush" else "grass"
	var r: ModelRig = _stamp("scenery:%s:%d" % [which, randi() % SCENERY_VARIANTS], _build_scenery.bind(which))
	r.rotation.y = randf() * TAU
	return r


## A small loot object ~0.5 tall: a pale tied bundle, or a gold-banded chest if `equippable`.
## The returned node is a ModelRig, so set_highlight() works on it.
static func pickup(equippable: bool) -> Node3D:
	return _stamp("pickup:%s" % equippable, _build_pickup.bind(equippable))


## A weapon sized for the player's right hand, to pass to ModelRig.set_weapon(). Known ids:
## "iron_knuckles", "serrated_dagger", "invader_cleaver", "commander_blade"; anything else
## is a plain short club. The grip sits at the node's origin and the business end points
## along -Z. The returned node is a ModelRig.
static func weapon(item_id: String) -> Node3D:
	var known: Array[String] = ["iron_knuckles", "serrated_dagger", "invader_cleaver", "commander_blade"]
	var id: String = item_id if known.has(item_id) else "club"
	var w: Node3D = _stamp("weapon:" + id, _build_weapon.bind(id))
	w.set_meta("item_id", id)                  # a real body looks up how to hold it (data/wardrobe.json "grip")
	return w


## The player's soul projection for the Netherecho: a small (1.0 tall, radius 0.3) translucent
## robed figure with a cyan glow. Same animate() contract as the player.
static func projection() -> ModelRig:
	return _stamp("projection", NetherModels.build_projection)


## A drifting mote of essence about 0.25 across. `affinity` picks the colour ("water" is
## blue, anything else pale white). It bobs and pulses by itself.
static func wisp(affinity: String) -> Node3D:
	return NetherModels.build_wisp(affinity)


## A wild ether construct: `tier` is "vestige" (~0.9 tall), "remnant" (~1.5) or "spirit"
## (~2.3); `concept` is "acceleration", "piercing", "compression", "tension", "reach" or
## "stillness" (anything else is a generic floating shape). Translucent and self-lit;
## supports set_highlight / flash / set_windup / animate, and sets height and radius.
static func construct(tier: String, concept: String) -> ModelRig:
	return _stamp("construct:%s:%s" % [tier, concept], NetherModels.build_construct.bind(tier, concept))


# ---------------------------------------------------------------- enemies

static func _build_enemy(kind: String) -> ModelRig:
	var def: Dictionary = _enemy_def(kind)
	var radius: float = float(def.get("radius", 0.5))
	var height: float = float(def.get("height", 1.7))
	var rgb: Array = def.get("color", [0.6, 0.6, 0.6])
	var color := Color(float(rgb[0]), float(rgb[1]), float(rgb[2]))
	var r := ModelRig.new()
	r.name = "EnemyModel_" + kind
	r.radius = radius
	r.height = height
	r.stride_speed = float(def.get("speed", 3.0))
	# The three original kinds were authored with coarse primitives: build them with every
	# round form subdivided further so they hold up next to the hero.
	_detail = 1.75
	match kind:
		"grunt":
			_grunt(r, color)
		"brute":
			_brute(r, color)
		"commander":
			_commander(r, color)
		"pavise":
			# a skirmisher's frame behind a body-length shield
			_grunt(r, color)
			r.add_shape("torso", MeshKit.bevel_box(Vector3(0.78, 1.3, 0.07), 0.03, Vector2(0.86, 1.0)), STEEL.darkened(0.25), Vector3(0, -0.2, -0.44), Vector3(8, 0, 0), Vector3.ONE, 0.0, 0.5, false, ModelRig.METAL)
			r.add_shape("torso", MeshKit.bevel_box(Vector3(0.1, 1.2, 0.05), 0.02), color.lightened(0.15), Vector3(0, -0.2, -0.49), Vector3(8, 0, 0))
			r.add_shape("torso", ball(0.11), BONE, Vector3(0, -0.05, -0.51))
		"censer":
			# a skirmisher carrying a smoking censer on a chain
			_grunt(r, color)
			r.add_shape("torso", tube([0.28, 0.1, -0.2, 0.3, -0.25, -0.3], [0.012, 0.012], 5), IRON, Vector3.ZERO)
			r.add_shape("torso", ball(0.13), Color(0.75, 0.6, 0.32), Vector3(0.3, -0.34, -0.3), Vector3.ZERO, Vector3.ONE, 0.0, 0.6, false, ModelRig.METAL)
			r.add_shape("torso", ball(0.07), Color(1.0, 0.9, 0.7), Vector3(0.3, -0.24, -0.3), Vector3.ZERO, Vector3.ONE, 2.2)
		"drummer":
			# a skirmisher with a war drum slung in front
			_grunt(r, color)
			r.add_shape("torso", cyl(0.25, 0.22, 0.3, 14), WOOD, Vector3(0, -0.22, -0.34), Vector3(-70, 0, 0))
			r.add_shape("torso", cyl(0.24, 0.24, 0.03, 14), BONE, Vector3(0, -0.17, -0.48), Vector3(-70, 0, 0))
			r.add_shape("torso", cyl(0.26, 0.26, 0.04, 14), color.lightened(0.1), Vector3(0, -0.22, -0.34), Vector3(-70, 0, 0))
		"archer":
			_detail = 1.0
			EnemyModels.archer(r, color)
		"harrier":
			_detail = 1.0
			EnemyModels.harrier(r, color)
		_:
			_plain(r, color, radius, height)
	_detail = 1.0
	r.finish()
	return r


## Masked Skirmisher: small hunched cone of pleated, ragged cloak, drooping pointed hood,
## pale mask with burning eye slits, long hooked knife.
static func _grunt(r: ModelRig, color: Color) -> void:
	r.stride_rate = 4.4
	r.swing = 0.62
	r.step_bob = 0.07
	r.lean = 0.25
	r.raise_arm = 2.7
	r.raise_forearm = 0.3
	r.strike_arm = 1.1
	r.strike_forearm = 0.0
	var cloak := grim(color, 0.5, 0.5)
	var cloak_d := grim(color, 0.4, 0.3)
	var cloak_l := grim(color, 0.5, 0.42)
	var dark := Color(0.08, 0.065, 0.07)
	var eye := Color(1.0, 0.72, 0.2)

	for side: int in [-1, 1]:
		var n: String = "left" if side < 0 else "right"
		var leg: String = "leg_" + n
		var shin: String = "shin_" + n
		r.add_part(leg, "", Vector3(0.14 * side, 0.6, 0.0))
		r.add_shape(leg, lathe([0.065, -0.31, 0.08, -0.15, 0.09, 0.02], 10), dark)
		r.add_part(shin, leg, Vector3(0, -0.3, 0))
		r.add_shape(shin, lathe([0.05, -0.27, 0.066, -0.14, 0.072, 0.02], 10), dark)
		for y: float in [-0.2, -0.13]:
			r.add_shape(shin, lathe([0.062, y - 0.015, 0.072, y, 0.062, y + 0.015], 8), BONE.darkened(0.4))
		r.add_shape(shin, bbox(0.13, 0.085, 0.24, 0.03, 0.75, 0.85), dark.lightened(0.14), Vector3(0, -0.258, -0.05))
		r.add_shape(shin, cyl(0.0, 0.05, 0.16, 6), dark.lightened(0.14), Vector3(0, -0.262, -0.22), Vector3(-78, 0, 0))

	r.add_part("body", "", Vector3(0, 0.58, 0), Vector3(-0.16, 0, 0))
	r.add_shape("body", lathe([0.31, -0.22, 0.3, -0.1, 0.25, 0.1, 0.2, 0.32, 0.165, 0.5, 0.12, 0.62], 16, 8, 0.13, 0.0, 0.11), cloak)
	r.add_shape("body", lathe([0.3, 0.24, 0.27, 0.36, 0.2, 0.5, 0.12, 0.64], 14, 7, 0.1, 0.0, 0.07), cloak_d)
	r.add_shape("body", bbox(0.06, 0.06, 0.03, 0.01), BONE.darkened(0.2), Vector3(0, 0.5, -0.2), Vector3(-25, 0, 45))
	r.add_shape("body", lathe([0.255, 0.02, 0.27, 0.04, 0.255, 0.07], 12), LEATHER, Vector3(0, 0, 0.0), Vector3.ZERO, Vector3.ONE, 0.0, 0.2)
	r.add_part("cloak", "body", Vector3(0, 0.5, 0.15), Vector3(-0.3, 0, 0))
	r.add_shape("cloak", MeshKit.sheet(0.3, 0.44, 0.8, 2.5, 0.04, 0.1, 0.12, 10, 6), cloak_d)
	r.sway_parts["cloak"] = -0.45

	r.add_part("torso", "body", Vector3(0, 0.3, 0))
	r.add_part("head", "torso", Vector3(0, 0.37, -0.05)).scale = Vector3.ONE * 0.7
	r.add_shape("head", ball(0.225, 14, 7), cloak, Vector3(0, 0.07, 0.02))
	r.add_shape("head", tube([0, 0.1, 0.02, 0, 0.26, 0.06, 0, 0.36, 0.16, 0, 0.385, 0.29, 0, 0.32, 0.4], [0.2, 0.15, 0.1, 0.055, 0.0], 10), cloak)
	r.add_shape("head", torus(0.15, 0.225, 16, 6), cloak_l, Vector3(0, 0.07, -0.13), Vector3(90, 0, 0), Vector3(1.0, 1.0, 1.1))
	r.add_shape("head", ball(0.17, 10, 5), dark, Vector3(0, 0.07, -0.07))
	r.add_shape("head", ball(0.15, 12, 6), BONE, Vector3(0, 0.06, -0.175), Vector3.ZERO, Vector3(0.85, 1.15, 0.38), 0.0, 0.25)
	r.add_shape("head", cyl(0.0, 0.075, 0.15, 6), BONE, Vector3(0, -0.13, -0.17), Vector3(180, 0, 0), Vector3(1.0, 1.0, 0.5), 0.0, 0.25, true)
	r.add_shape("head", bbox(0.21, 0.035, 0.04, 0.01), BONE.darkened(0.2), Vector3(0, 0.135, -0.222), Vector3(-8, 0, 0))
	r.add_shape("head", bbox(0.028, 0.11, 0.02, 0.006), cloak, Vector3(0, 0.185, -0.21), Vector3(-22, 0, 0))
	for side: int in [-1, 1]:
		r.add_shape("head", bbox(0.07, 0.034, 0.03, 0.008), eye, Vector3(0.056 * side, 0.09, -0.228), Vector3(0, 0, 15 * side), Vector3.ONE, 1.6)
		r.add_shape("head", bbox(0.014, 0.055, 0.02, 0.004), dark, Vector3(0.028 * side, -0.03, -0.228))
		r.add_shape("head", bbox(0.05, 0.02, 0.02, 0.005), cloak, Vector3(0.085 * side, 0.02, -0.215), Vector3(0, 0, -25 * side))
	r.add_shape("head", bbox(0.014, 0.055, 0.02, 0.004), dark, Vector3(0, -0.035, -0.23))
	# The mask's ties knotted behind the hood: the pale mark to know it by from the rear.
	r.add_shape("head", ball(0.045, 8, 4), BONE, Vector3(0, 0.08, 0.235))
	r.add_shape("head", torus(0.2, 0.232, 16, 4), BONE.darkened(0.3), Vector3(0, 0.08, 0.02), Vector3(8, 0, 0))
	for side: int in [-1, 1]:
		r.add_shape("head", tube([0.0, 0.08, 0.24, 0.05 * side, -0.02, 0.3, 0.07 * side, -0.16, 0.3], [0.02, 0.024, 0.0], 4, 0.4, Vector3.RIGHT), BONE.darkened(0.12))

	for side: int in [-1, 1]:
		var n: String = "left" if side < 0 else "right"
		var arm: String = "arm_" + n
		var fore: String = "forearm_" + n
		r.add_part(arm, "torso", Vector3(0.19 * side, 0.22, -0.02), Vector3(0, 0, 0.2 * side))
		r.add_shape(arm, lathe([0.075, -0.32, 0.062, -0.16, 0.06, 0.0, 0.03, 0.05], 8, 4, 0.12, 0.0, 0.05), cloak_d)
		r.add_part(fore, arm, Vector3(0, -0.28, 0), Vector3(0.8, 0, 0))
		r.add_shape(fore, lathe([0.042, -0.26, 0.052, -0.12, 0.058, 0.0], 8), dark)
		for y: float in [-0.2, -0.14]:
			r.add_shape(fore, lathe([0.05, y - 0.014, 0.06, y, 0.05, y + 0.014], 8), BONE.darkened(0.4))
		r.add_shape(fore, ball(0.045, 8, 4), BONE.darkened(0.35), Vector3(0, -0.27, 0))
	# Hooked knife: runs forward-and-down from the right fist so it levels out on the strike.
	var hand := Vector3(0, -0.27, 0)
	var held := Vector3(0, 90, -45)
	r.add_shape("forearm_right", MeshKit.extrude(poly([-0.11, -0.022, 0.06, -0.022, 0.06, 0.022, -0.11, 0.022]), 0.045), LEATHER, hand, held)
	r.add_shape("forearm_right", MeshKit.extrude(poly([0.045, -0.085, 0.085, -0.07, 0.085, 0.07, 0.045, 0.085]), 0.06), LEATHER.lightened(0.2), hand, held, Vector3.ONE, 0.0, 0.6)
	r.add_shape("forearm_right", MeshKit.extrude(poly([0.085, -0.04, 0.24, -0.06, 0.5, -0.06, 0.66, -0.015, 0.76, 0.08, 0.6, 0.045, 0.5, 0.05, 0.46, 0.02, 0.3, 0.03, 0.085, 0.035]), 0.03), STEEL.darkened(0.15), hand, held, Vector3.ONE, 0.0, 1.0)
	r.add_shape("forearm_right", MeshKit.extrude(poly([0.1, -0.04, 0.24, -0.06, 0.5, -0.06, 0.66, -0.015, 0.76, 0.08, 0.64, 0.0, 0.5, -0.035, 0.24, -0.035]), 0.036), STEEL.lightened(0.35), hand, held, Vector3.ONE, 0.0, 1.0)


## Hide-Bound Brute: a wide hunched barrel with a spined back, a small sunk head with
## up-curved tusks, and arms like tree trunks ending in bone-studded fists.
static func _brute(r: ModelRig, color: Color) -> void:
	r.stride_rate = 2.6
	r.swing = 0.5
	r.step_bob = 0.08
	r.bob = 0.035
	r.lean = 0.08
	r.strike_both_arms = true
	r.raise_arm = 2.7
	r.raise_forearm = 0.5
	r.strike_arm = 0.9
	r.strike_forearm = 0.1
	var hide := grim(color, 0.28, 1.0).lerp(Color(0.3, 0.27, 0.27), 0.3)
	var hide_d := grim(color, 0.25, 0.6)
	var hide_l := grim(color, 0.2, 1.0).lerp(Color(0.46, 0.41, 0.38), 0.55)
	var strap := LEATHER.darkened(0.25)
	var eye := Color(1.0, 0.4, 0.12)

	for side: int in [-1, 1]:
		var n: String = "left" if side < 0 else "right"
		var leg: String = "leg_" + n
		var shin: String = "shin_" + n
		r.add_part(leg, "", Vector3(0.28 * side, 0.82, 0.0))
		r.add_shape(leg, lathe([0.17, -0.43, 0.2, -0.3, 0.245, -0.12, 0.22, 0.06], 12), hide_d)
		r.add_part(shin, leg, Vector3(0, -0.4, 0))
		r.add_shape(shin, lathe([0.15, -0.36, 0.175, -0.25, 0.205, -0.1, 0.17, 0.03], 12), LEATHER)
		for y: float in [-0.27, -0.14]:
			r.add_shape(shin, lathe([0.18, y - 0.025, 0.2, y, 0.185, y + 0.025], 10), strap)
		r.add_shape(shin, bbox(0.33, 0.15, 0.44, 0.055, 0.78, 0.8), hide_d, Vector3(0, -0.345, -0.07))
		for k: int in 3:
			r.add_shape(shin, cyl(0.0, 0.045, 0.16, 5), BONE, Vector3(-0.1 + 0.1 * float(k), -0.385, -0.31), Vector3(-100, 0, 0), Vector3.ONE, 0.0, 0.3)

	r.add_part("body", "", Vector3(0, 0.82, 0))
	r.add_shape("body", lathe([0.34, -0.12, 0.45, 0.04, 0.5, 0.24, 0.48, 0.46], 16), hide_d, Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, 0.85))
	r.add_shape("body", lathe([0.5, 0.13, 0.535, 0.16, 0.535, 0.27, 0.5, 0.3], 16), strap, Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, 0.85))
	r.add_shape("body", cyl(0.11, 0.11, 0.06, 8), BONE, Vector3(0, 0.215, -0.45), Vector3(90, 0, 0), Vector3.ONE, 0.0, 0.3)
	r.add_shape("body", MeshKit.sheet(0.4, 0.3, 0.55, 1.5, 0.03, -0.03, 0.06, 8, 4), LEATHER, Vector3(0, 0.15, -0.44))
	r.add_shape("body", MeshKit.sheet(0.44, 0.34, 0.5, 1.5, 0.03, 0.03, 0.06, 8, 4), LEATHER.darkened(0.1), Vector3(0, 0.15, 0.44))

	r.add_part("torso", "body", Vector3(0, 0.42, 0), Vector3(-0.3, 0, 0))
	r.add_shape("torso", lathe([0.46, -0.04, 0.56, 0.15, 0.64, 0.38, 0.62, 0.58, 0.48, 0.76, 0.24, 0.87], 18), hide, Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, 0.8))
	r.add_shape("torso", ball(0.3, 10, 5), hide_l, Vector3(0, 0.22, -0.3), Vector3.ZERO, Vector3(1.15, 1.0, 0.8))
	for side: int in [-1, 1]:
		r.add_shape("torso", ball(0.2, 12, 6), hide_l, Vector3(0.2 * side, 0.54, -0.37), Vector3.ZERO, Vector3(1.2, 0.9, 0.7))
	r.add_shape("torso", ball(0.44, 14, 7), hide_d, Vector3(0, 0.66, 0.2), Vector3.ZERO, Vector3(1.2, 0.75, 0.95))
	# Armoured in front only: overlapping iron lames over chest and gut, riveted with bone.
	# The back is bare hide, old scars across the hump - that is where to hit it.
	var plate: Color = IRON.lightened(0.1)
	for k: int in 4:
		var py: float = 0.62 - 0.17 * float(k)
		var pw: float = [0.78, 0.86, 0.8, 0.62][k]
		var pz: float = [-0.5, -0.57, -0.6, -0.56][k]
		r.add_shape("torso", bbox(pw, 0.22, 0.1, 0.035, 0.92, 1.0), plate if k % 2 == 0 else plate.lightened(0.08), Vector3(0, py, pz), Vector3(-10 + 7 * k, 0, 0), Vector3.ONE, 0.0, 0.8, true, ModelRig.METAL)
		for side: int in [-1, 1]:
			r.add_shape("torso", ball(0.03, 6, 3), BONE, Vector3(pw * 0.42 * side, py, pz - 0.055), Vector3.ZERO, Vector3.ONE, 0.0, 0.3)
			r.add_shape("torso", bbox(0.2, 0.2, 0.09, 0.03), plate.darkened(0.15), Vector3((pw * 0.5 + 0.04) * side, py, pz + 0.12), Vector3(0, -48 * side, 0), Vector3.ONE, 0.0, 0.8, true, ModelRig.METAL)
	r.add_shape("torso", bbox(0.16, 0.7, 0.06, 0.02), BONE.darkened(0.2), Vector3(0, 0.36, -0.645), Vector3(-2, 0, 0), Vector3.ONE, 0.0, 0.3, true)
	for k: int in 3:
		var sx: float = [-0.3, 0.1, 0.34][k]
		r.add_shape("torso", tube([sx, 0.95, 0.3, sx + 0.08, 0.8, 0.52, sx + 0.02, 0.56, 0.6], [0.0, 0.022, 0.0], 4, 0.4), hide_l.lerp(Color(0.6, 0.45, 0.45), 0.5))
	var back: Array = [[0.93, 0.18, 12.0, 0.26], [0.86, 0.42, 42.0, 0.3], [0.62, 0.58, 72.0, 0.28], [0.36, 0.56, 92.0, 0.22]]
	for spine: Array in back:
		r.add_shape("torso", cyl(0.0, 0.075, float(spine[3]), 6), BONE, Vector3(0, float(spine[0]), float(spine[1])), Vector3(float(spine[2]), 0, 0), Vector3.ONE, 0.0, 0.3)
	var belt: Array = []
	var belt_r: Array = []
	for i: int in 21:
		var a: float = TAU * float(i) / 20.0
		var x: float = cos(a) * 0.64
		belt.append_array([x, 0.42 + x * 0.45, sin(a) * 0.52])
		belt_r.append(0.07)
	r.add_shape("torso", tube(belt, belt_r, 6, 0.4, Vector3.UP), strap)
	for side: int in [-1, 1]:
		r.add_shape("torso", lathe([0.27, 0.0, 0.26, 0.09, 0.17, 0.2, 0.0, 0.25], 12), LEATHER, Vector3(0.5 * side, 0.63, 0), Vector3(0, 0, -16 * side))
		r.add_shape("torso", lathe([0.275, -0.02, 0.29, 0.01, 0.27, 0.04], 12), strap, Vector3(0.5 * side, 0.63, 0), Vector3(0, 0, -16 * side))
		r.add_shape("torso", cyl(0.0, 0.085, 0.36, 6), BONE, Vector3(0.56 * side, 0.94, 0.0), Vector3(0, 0, -16 * side), Vector3.ONE, 0.0, 0.3)
		r.add_shape("torso", cyl(0.0, 0.06, 0.24, 6), BONE, Vector3(0.4 * side, 0.9, 0.16), Vector3(-18, 0, -8 * side), Vector3.ONE, 0.0, 0.3)

	r.add_part("head", "torso", Vector3(0, 0.72, -0.38), Vector3(0.3, 0, 0))
	r.add_shape("head", ball(0.24, 14, 7), hide_l, Vector3(0, 0.06, 0), Vector3.ZERO, Vector3(1.0, 0.92, 1.05))
	r.add_shape("head", bbox(0.42, 0.1, 0.16, 0.035), hide_d, Vector3(0, 0.15, -0.17), Vector3(14, 0, 0))
	r.add_shape("head", bbox(0.36, 0.17, 0.3, 0.055, 0.85, 0.9), hide_d, Vector3(0, -0.1, -0.1))
	r.add_shape("head", ball(0.07, 8, 4), hide_d, Vector3(0, 0.0, -0.235), Vector3.ZERO, Vector3(1.2, 0.8, 0.8))
	for side: int in [-1, 1]:
		r.add_shape("head", tube([0.14 * side, -0.07, -0.2, 0.2 * side, -0.05, -0.3, 0.215 * side, 0.06, -0.37, 0.19 * side, 0.19, -0.37], [0.058, 0.052, 0.036, 0.0], 7), BONE, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 0.0, 0.35)
		r.add_shape("head", ball(0.04, 8, 4), eye, Vector3(0.1 * side, 0.075, -0.215), Vector3.ZERO, Vector3(0.9, 0.6, 1.0), 1.8)
		r.add_shape("head", cyl(0.0, 0.065, 0.2, 5), hide, Vector3(0.26 * side, 0.1, 0.03), Vector3(0, 0, -68 * side))
		r.add_shape("head", cyl(0.0, 0.03, 0.08, 4), BONE, Vector3(0.06 * side, -0.01, -0.245), Vector3(-10, 0, 0))

	for side: int in [-1, 1]:
		var n: String = "left" if side < 0 else "right"
		var arm: String = "arm_" + n
		var fore: String = "forearm_" + n
		r.add_part(arm, "torso", Vector3(0.52 * side, 0.56, -0.02), Vector3(0.25, 0, 0.03 * side))
		r.add_shape(arm, ball(0.21, 10, 5), hide)
		r.add_shape(arm, lathe([0.14, -0.6, 0.165, -0.48, 0.21, -0.26, 0.2, -0.06, 0.16, 0.04], 10), hide)
		r.add_part(fore, arm, Vector3(0, -0.58, 0), Vector3(0.3, 0, 0))
		r.add_shape(fore, ball(0.155, 10, 5), hide_d)
		r.add_shape(fore, lathe([0.15, -0.62, 0.2, -0.46, 0.2, -0.3, 0.165, -0.1, 0.14, 0.02], 10), hide)
		r.add_shape(fore, lathe([0.205, -0.48, 0.218, -0.44, 0.218, -0.24, 0.195, -0.2], 8), LEATHER, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 0.0, 0.2, true)
		for k: int in 6:
			var a: float = TAU * float(k) / 6.0
			r.add_shape(fore, ball(0.035, 6, 3), BONE, Vector3(cos(a) * 0.218, -0.34, sin(a) * 0.218), Vector3.ZERO, Vector3.ONE, 0.0, 0.3)
		r.add_shape(fore, bbox(0.27, 0.26, 0.29, 0.07), hide_d, Vector3(0, -0.74, 0), Vector3.ZERO, Vector3.ONE, 0.0, 0.0, true)
		r.add_shape(fore, bbox(0.08, 0.15, 0.11, 0.03), hide_d, Vector3(-0.15 * side, -0.71, -0.06), Vector3.ZERO, Vector3.ONE, 0.0, 0.0, true)
		for k: int in 4:
			r.add_shape(fore, ball(0.04, 6, 3), BONE, Vector3(-0.095 + 0.063 * float(k), -0.86, -0.09), Vector3.ZERO, Vector3(1.0, 1.0, 1.0), 0.0, 0.3)


## Wall Commander: tall iron-and-gold plate, crested great helm with a burning visor, heater
## shield, greatsword, pleated crimson cape and a small back-banner. The leader of a wall.
static func _commander(r: ModelRig, color: Color) -> void:
	r.stride_rate = 2.2
	r.swing = 0.42
	r.step_bob = 0.04
	r.lean = 0.05
	r.raise_arm = 2.5
	r.raise_forearm = 0.5
	r.strike_arm = 0.7
	r.strike_forearm = 0.0
	var gold := grim(color, 0.6, 0.72)
	var gold_d := gold.darkened(0.35)
	var iron := IRON.lightened(0.05)
	var iron_l := IRON.lightened(0.16)
	var crimson := Color(0.33, 0.05, 0.07)
	var crimson_d := crimson.darkened(0.35)
	var fire := Color(1.0, 0.62, 0.15)
	var m: float = 0.85
	var none := Vector3.ZERO
	var one := Vector3.ONE

	for side: int in [-1, 1]:
		var n: String = "left" if side < 0 else "right"
		var leg: String = "leg_" + n
		var shin: String = "shin_" + n
		r.add_part(leg, "", Vector3(0.2 * side, 1.05, 0.0))
		r.add_shape(leg, lathe([0.13, -0.52, 0.15, -0.36, 0.178, -0.1, 0.16, 0.05], 12), iron, none, none, one, 0.0, m)
		r.add_shape(leg, bbox(0.2, 0.32, 0.06, 0.02, 0.85, 1.0), gold, Vector3(0, -0.2, -0.155), Vector3(-4, 0, 0), one, 0.0, m)
		r.add_part(shin, leg, Vector3(0, -0.5, 0))
		r.add_shape(shin, ball(0.135, 10, 5), gold, Vector3(0, 0, -0.05), none, Vector3(1.0, 1.0, 0.9), 0.0, m)
		r.add_shape(shin, lathe([0.1, -0.47, 0.116, -0.36, 0.152, -0.14, 0.13, 0.02], 12), iron, none, none, one, 0.0, m)
		r.add_shape(shin, bbox(0.07, 0.4, 0.05, 0.016), gold, Vector3(0, -0.24, -0.13), Vector3(3, 0, 0), one, 0.0, m)
		r.add_shape(shin, lathe([0.12, -0.4, 0.132, -0.385, 0.12, -0.37], 10), gold_d, none, none, one, 0.0, m)
		r.add_shape(shin, bbox(0.24, 0.15, 0.38, 0.05, 0.75, 0.8), iron_l, Vector3(0, -0.475, -0.05), none, one, 0.0, m)
		r.add_shape(shin, cyl(0.0, 0.085, 0.2, 6), gold, Vector3(0, -0.5, -0.29), Vector3(-82, 0, 0), Vector3(1.0, 1.0, 0.7), 0.0, m)

	r.add_part("body", "", Vector3(0, 1.05, 0))
	r.add_shape("body", lathe([0.5, -0.44, 0.47, -0.25, 0.4, -0.05, 0.36, 0.1], 18, 9, 0.07, 0.0), crimson, none, none, Vector3(1, 1, 0.8))
	r.add_shape("body", lathe([0.37, 0.07, 0.405, 0.1, 0.405, 0.18, 0.37, 0.21], 16), gold, none, none, Vector3(1, 1, 0.8), 0.0, m)
	r.add_shape("body", bbox(0.22, 0.56, 0.05, 0.02, 0.85, 1.0), gold, Vector3(0, -0.17, -0.385), Vector3(13, 0, 0), one, 0.0, m)
	r.add_shape("body", bbox(0.13, 0.13, 0.04, 0.012), gold_d, Vector3(0, -0.12, -0.425), Vector3(13, 0, 45), one, 0.0, m)
	for side: int in [-1, 1]:
		r.add_shape("body", bbox(0.24, 0.34, 0.05, 0.02, 0.9, 1.0), iron_l, Vector3(0.3 * side, -0.1, -0.24), Vector3(10, -42 * side, 0), one, 0.0, m)
		r.add_shape("body", bbox(0.25, 0.05, 0.06, 0.012), gold, Vector3(0.31 * side, -0.26, -0.265), Vector3(10, -42 * side, 0), one, 0.0, m)

	r.add_part("torso", "body", Vector3(0, 0.18, 0))
	r.add_shape("torso", lathe([0.35, -0.02, 0.37, 0.14, 0.46, 0.36, 0.5, 0.54, 0.44, 0.68, 0.24, 0.77], 18), iron, none, none, Vector3(1, 1, 0.74), 0.0, m)
	r.add_shape("torso", lathe([0.385, 0.16, 0.4, 0.18, 0.385, 0.2], 16), gold, none, none, Vector3(1, 1, 0.74), 0.0, m)
	r.add_shape("torso", lathe([0.43, 0.3, 0.445, 0.32, 0.43, 0.34], 16), gold_d, none, none, Vector3(1, 1, 0.74), 0.0, m)
	r.add_shape("torso", MeshKit.extrude(poly([-0.22, 0.2, -0.13, 0.2, 0.0, 0.0, 0.13, 0.2, 0.22, 0.2, 0.0, -0.16]), 0.05), gold, Vector3(0, 0.5, -0.365), Vector3(-10, 0, 0), one, 0.0, m)
	r.add_shape("torso", lathe([0.2, 0.7, 0.26, 0.745, 0.25, 0.84, 0.2, 0.87], 14), gold, none, none, one, 0.0, m)
	for side: int in [-1, 1]:
		var at := Vector3(0.53 * side, 0.66, 0)
		var tilt := Vector3(0, 0, -14 * side)
		r.add_shape("torso", lathe([0.22, -0.17, 0.25, -0.05, 0.235, 0.0], 8), iron_l, at, tilt, Vector3(1.0, 1.0, 1.1), 0.0, m, true)
		r.add_shape("torso", lathe([0.25, 0.0, 0.24, 0.07, 0.15, 0.17, 0.0, 0.2], 8), iron_l, at, tilt, Vector3(1.0, 1.0, 1.1), 0.0, m, true)
		r.add_shape("torso", lathe([0.25, -0.015, 0.265, 0.01, 0.25, 0.035], 8), gold, at, tilt, Vector3(1.0, 1.0, 1.1), 0.0, m, true)
		r.add_shape("torso", MeshKit.extrude(poly([-0.16, 0.0, 0.16, 0.0, 0.08, 0.12, -0.11, 0.09]), 0.03), gold, Vector3(0.5 * side, 0.84, 0.0), Vector3(0, 90, 0), one, 0.0, m)

	r.add_part("cape", "torso", Vector3(0, 0.74, 0.3), Vector3(-0.14, 0, 0))
	r.add_shape("cape", MeshKit.sheet(0.88, 1.1, 1.55, 3.0, 0.06, 0.1, 0.07, 14, 7), crimson)
	r.add_shape("cape", MeshKit.sheet(0.94, 1.0, 0.45, 3.0, 0.03, 0.02, 0.0, 12, 3), crimson_d, Vector3(0, 0.02, 0.03))
	var hem: Array = []
	var hem_r: Array = []
	for i: int in 15:
		var u: float = float(i) / 14.0
		hem.append_array([(u - 0.5) * 1.15, -1.55, 0.06 * cos(u * 3.0 * TAU) + 0.1])
		hem_r.append(0.035)
	r.add_shape("cape", bbox(0.3, 0.3, 0.03, 0.01), gold_d, Vector3(0, -0.8, 0.09), Vector3(4, 0, 45), one, 0.0, m)
	r.sway_parts["cape"] = -0.5

	# Banner rides behind the LEFT shoulder, clear of the helmet crest, and tops out at 2.75.
	r.add_part("banner", "torso", Vector3(-0.56, 0.3, 0.36), Vector3(-0.06, 0, 0.05))
	r.add_shape("banner", cyl(0.03, 0.03, 1.14, 6), LEATHER.darkened(0.3), Vector3(0, 0.57, 0))
	r.add_shape("banner", bbox(0.52, 0.05, 0.05, 0.015), gold, Vector3(0, 1.07, 0), none, one, 0.0, m)
	r.add_shape("banner", cyl(0.0, 0.05, 0.1, 5), gold, Vector3(0, 1.17, 0), none, one, 0.0, m)
	r.add_shape("banner", MeshKit.sheet(0.46, 0.46, 0.5, 1.5, 0.02, 0.0, 0.09, 6, 4), crimson, Vector3(0, 1.05, 0))
	for z: float in [-0.035, 0.035]:
		r.add_shape("banner", bbox(0.18, 0.18, 0.02, 0.006), gold, Vector3(0, 0.84, z), Vector3(0, 0, 45), one, 0.0, m)
	r.sway_parts["banner"] = 0.12

	r.add_part("head", "torso", Vector3(0, 0.8, 0)).scale = Vector3.ONE * 0.86
	r.add_shape("head", lathe([0.2, 0.0, 0.228, 0.06, 0.232, 0.2, 0.21, 0.32, 0.14, 0.41, 0.0, 0.45], 10), iron_l, none, none, one, 0.0, 0.9, true)
	r.add_shape("head", lathe([0.234, 0.2, 0.248, 0.215, 0.248, 0.265, 0.228, 0.28], 16), gold, none, none, one, 0.0, m)
	r.add_shape("head", bbox(0.27, 0.04, 0.06, 0.012), fire, Vector3(0, 0.165, -0.2), none, one, 2.0)
	r.add_shape("head", bbox(0.055, 0.32, 0.05, 0.016), gold, Vector3(0, 0.14, -0.228), none, one, 0.0, m)
	for side: int in [-1, 1]:
		r.add_shape("head", bbox(0.05, 0.2, 0.17, 0.02, 0.7, 0.8), iron, Vector3(0.21 * side, 0.07, -0.1), Vector3(0, 0, 180), one, 0.0, m)
		for k: int in 3:
			r.add_shape("head", bbox(0.012, 0.05, 0.02, 0.003), Color(0.04, 0.04, 0.05), Vector3((0.06 + 0.035 * float(k)) * side, 0.07, -0.222 + 0.012 * float(k)))
	r.add_shape("head", MeshKit.extrude(poly([-0.22, 0.34, -0.2, 0.47, -0.07, 0.565, 0.1, 0.575, 0.24, 0.5, 0.31, 0.36, 0.3, 0.22, 0.2, 0.3, 0.08, 0.4, -0.08, 0.41]), 0.06), crimson, none, Vector3(0, -90, 0))
	r.add_shape("head", MeshKit.extrude(poly([-0.24, 0.3, -0.08, 0.435, 0.08, 0.425, 0.21, 0.32, 0.3, 0.2, 0.3, 0.14, 0.18, 0.26, 0.06, 0.37, -0.08, 0.38, -0.22, 0.25]), 0.075), gold, none, Vector3(0, -90, 0), one, 0.0, m)

	# Right arm: greatsword running forward-and-down from the fist (levels out on the strike).
	for side: int in [-1, 1]:
		var n: String = "left" if side < 0 else "right"
		# The shield arm is not an "arm_left": it stays put behind the shield instead of swinging.
		var arm: String = "arm_right" if side > 0 else "shield_arm"
		var fore: String = "forearm_right" if side > 0 else "shield_forearm"
		r.add_part(arm, "torso", Vector3(0.58 * side, 0.62, 0), Vector3(0.15 if side > 0 else 0.2, 0, 0.08 * side))
		r.add_shape(arm, lathe([0.11, -0.49, 0.13, -0.3, 0.152, -0.1, 0.13, 0.03], 12), iron, none, none, one, 0.0, m)
		r.add_part(fore, arm, Vector3(0, -0.48, 0), Vector3(1.1 if side > 0 else 0.9, 0, 0))
		r.add_shape(fore, ball(0.13, 10, 5), gold, none, none, one, 0.0, m)
		r.add_shape(fore, lathe([0.11, -0.42, 0.13, -0.3, 0.162, -0.1, 0.14, 0.0], 12), gold, none, none, one, 0.0, m)
		r.add_shape(fore, lathe([0.14, -0.2, 0.155, -0.18, 0.15, -0.16], 12), iron, none, none, one, 0.0, m)
		r.add_shape(fore, bbox(0.22, 0.22, 0.24, 0.06), iron, Vector3(0, -0.5, 0), none, one, 0.0, m)
	var hand := Vector3(0, -0.5, 0)
	var held := Vector3(0, 90, -30)
	var circle: Array = []
	for i: int in 8:
		circle.append_array([-0.27 + cos(TAU * float(i) / 8.0) * 0.065, sin(TAU * float(i) / 8.0) * 0.065])
	r.add_shape("forearm_right", MeshKit.extrude(poly([-0.22, -0.035, 0.1, -0.035, 0.1, 0.035, -0.22, 0.035]), 0.065), LEATHER, hand, held)
	r.add_shape("forearm_right", MeshKit.extrude(poly(circle), 0.1), gold, hand, held, one, 0.0, m)
	r.add_shape("forearm_right", MeshKit.extrude(poly([0.08, -0.3, 0.17, -0.26, 0.16, -0.08, 0.16, 0.08, 0.17, 0.26, 0.08, 0.3, 0.04, 0.2, 0.09, 0.07, 0.09, -0.07, 0.04, -0.2]), 0.085), gold, hand, held, one, 0.0, m)
	r.add_shape("forearm_right", MeshKit.extrude(poly([0.15, -0.085, 0.32, -0.1, 1.15, -0.075, 1.42, 0.0, 1.15, 0.075, 0.32, 0.1, 0.15, 0.085]), 0.04), STEEL, hand, held, one, 0.0, 1.0)
	r.add_shape("forearm_right", MeshKit.extrude(poly([0.18, -0.022, 1.05, -0.016, 1.12, 0.0, 1.05, 0.016, 0.18, 0.022]), 0.052), STEEL.darkened(0.45), hand, held, one, 0.0, 1.0)

	# Heater shield, strapped to the left side of the body.
	r.add_part("shield", "torso", Vector3(-0.56, 0.02, -0.5), Vector3(0.0, 0.5, 0))
	var outline: Array = [-0.32, 0.6, 0.0, 0.66, 0.32, 0.6, 0.34, 0.1, 0.26, -0.35, 0.0, -0.68, -0.26, -0.35, -0.34, 0.1]
	var inner: Array = []
	for i: int in range(0, outline.size(), 2):
		inner.append_array([float(outline[i]) * 0.84, float(outline[i + 1]) * 0.86 + 0.01])
	r.add_shape("shield", MeshKit.extrude(poly(outline), 0.07), gold, none, none, one, 0.0, m)
	r.add_shape("shield", MeshKit.extrude(poly(inner), 0.1), iron_l, none, none, one, 0.0, 0.6)
	r.add_shape("shield", bbox(0.56, 0.05, 0.03, 0.01), gold_d, Vector3(0, 0.14, -0.05), none, one, 0.0, m)
	r.add_shape("shield", bbox(0.05, 1.05, 0.03, 0.01), gold_d, Vector3(0, 0.0, -0.05), none, one, 0.0, m)
	r.add_shape("shield", bbox(0.26, 0.26, 0.05, 0.015), crimson, Vector3(0, 0.14, -0.06), Vector3(0, 0, 45))
	r.add_shape("shield", ball(0.07, 8, 4), gold, Vector3(0, 0.14, -0.085), none, Vector3(1.0, 1.0, 0.6), 0.0, m)


## Fallback for unknown kinds: a plain capsule body with a head.
static func _plain(r: ModelRig, color: Color, radius: float, height: float) -> void:
	var head_r: float = minf(radius * 0.55, height * 0.16)
	var body_h: float = height - head_r * 1.6
	var cap := CapsuleMesh.new()
	cap.radius = radius * 0.75
	cap.height = maxf(body_h, cap.radius * 2.0)
	cap.radial_segments = 14
	cap.rings = 5
	r.add_part("body", "", Vector3(0, body_h * 0.5, 0))
	r.add_shape("body", cap, color, Vector3.ZERO)
	r.add_part("head", "body", Vector3(0, body_h * 0.5, 0))
	r.add_shape("head", ball(head_r, 12, 6), color.lightened(0.25), Vector3(0, head_r * 0.5, 0))
	r.add_shape("head", bbox(head_r * 1.2, head_r * 0.25, 0.05, 0.01), Color(1, 0.9, 0.5), Vector3(0, head_r * 0.6, -head_r * 0.95), Vector3.ZERO, Vector3.ONE, 1.0)


# ---------------------------------------------------------------- scenery and loot

static func _build_scenery(kind: String) -> ModelRig:
	var r := ModelRig.new()
	r.name = "SceneryModel_" + kind
	if kind == "bush":
		r.height = 1.1
		r.radius = 0.7
		_bush(r)
	else:
		r.height = 0.8
		r.radius = 0.4
		_grass(r)
	r.finish()
	return r


## Dry scrub: stiff, dark, sun-bleached stalks over a patch of bare earth, paling to straw
## at the tips, with a few husked seed heads.
static func _grass(r: ModelRig) -> void:
	var stem := Color(0.2, 0.21, 0.11)
	var straw := Color(0.52, 0.46, 0.27)
	var husk := Color(0.66, 0.6, 0.42)
	r.add_part("body")
	r.add_shape("body", cyl(0.3, 0.37, 0.025, 12), Color(0.2, 0.17, 0.11), Vector3(0, 0.01, 0), Vector3.ZERO, Vector3.ONE, 0.001)
	var blades: int = 18
	for i: int in blades:
		var yaw: float = TAU * float(i) / float(blades) + randf_range(-0.25, 0.25)
		var h: float = randf_range(0.34, 0.76)
		var out: float = h * randf_range(0.15, 0.7)
		var w: float = randf_range(0.04, 0.065)
		var start: float = randf_range(0.02, 0.14)
		var bend: float = randf_range(0.3, 0.6)
		var turn := Vector3(0, rad_to_deg(yaw), 0)
		# Lower half dark, upper half bleached: two straight, kinked segments.
		r.add_shape("body", tube([0, 0, start, 0, h * 0.55, start + out * bend * 0.4], [w, w * 0.8], 3, 0.35), stem.lerp(straw, randf() * 0.25), Vector3.ZERO, turn, Vector3.ONE, 0.0, 0.0, true)
		r.add_shape("body", tube([0, h * 0.55, start + out * bend * 0.4, 0, h, start + out], [w * 0.8, 0.0], 3, 0.35), straw.lerp(stem, randf() * 0.35), Vector3.ZERO, turn, Vector3.ONE, 0.0, 0.0, true)
	for i: int in 3:
		var yaw: float = TAU * float(i) / 3.0 + randf_range(-0.6, 0.6)
		var h: float = randf_range(0.5, 0.68)
		var out: float = randf_range(0.03, 0.16)
		r.add_shape("body", tube([0, 0, 0.02, 0, h, 0.02 + out], [0.014, 0.01], 3), stem, Vector3.ZERO, Vector3(0, rad_to_deg(yaw), 0))
		var top: Vector3 = Basis.from_euler(Vector3(0, yaw, 0)) * Vector3(0, h + 0.03, 0.02 + out)
		r.add_shape("body", lathe([0.0, -0.06, 0.032, -0.01, 0.026, 0.04, 0.0, 0.09], 5), husk, top, Vector3.ZERO, Vector3.ONE, 0.0, 0.0, true)


## A thorn bush: bare dark branches carrying a few angular clumps of grey-green leaf and a
## scatter of small rust-coloured hips.
static func _bush(r: ModelRig) -> void:
	var leaf := Color(0.15, 0.2, 0.12)
	var leaf_l := Color(0.27, 0.31, 0.17)
	var dry := Color(0.36, 0.32, 0.18)
	var bark := Color(0.13, 0.1, 0.08)
	var berry := Color(0.5, 0.16, 0.08)
	r.add_part("body")
	r.add_shape("body", cyl(0.5, 0.6, 0.025, 12), Color(0.2, 0.17, 0.11), Vector3(0, 0.01, 0), Vector3.ZERO, Vector3.ONE, 0.001)
	var limbs: int = 7
	for i: int in limbs:
		var a: float = TAU * float(i) / float(limbs) + randf_range(-0.3, 0.3)
		var reach: float = randf_range(0.3, 0.52)
		var h: float = randf_range(0.5, 0.95)
		var dir := Vector3(sin(a), 0, cos(a))
		var knee: Vector3 = dir * reach * 0.45 + Vector3(0, h * 0.5, 0)
		var tip: Vector3 = dir * reach + Vector3(0, h, 0)
		r.add_shape("body", tube([0, 0, 0, knee.x, knee.y, knee.z, tip.x, tip.y, tip.z], [0.045, 0.03, 0.008], 4), bark, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 0.0, 0.0, true)
		var twig: Vector3 = knee + Vector3(dir.z, 0.6, -dir.x) * randf_range(0.15, 0.26)
		r.add_shape("body", tube([knee.x, knee.y, knee.z, twig.x, twig.y, twig.z], [0.02, 0.0], 3), bark, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 0.0, 0.0, true)
		var col: Color = leaf.lerp(leaf_l, randf()) if i % 3 != 0 else leaf_l.lerp(dry, randf_range(0.4, 0.9))
		var rad: float = randf_range(0.17, 0.26)
		r.add_shape("body", ball(rad, 6, 3), col, tip * 0.82, Vector3(randf() * 60.0, randf() * 90.0, randf() * 40.0), Vector3(1.0, 0.7, 1.0), 0.0, 0.0, true)
		r.add_shape("body", ball(rad * 0.7, 5, 3), col.darkened(0.15), knee + Vector3(0, 0.08, 0), Vector3(randf() * 60.0, randf() * 90.0, 0), Vector3(1.0, 0.7, 1.0), 0.0, 0.0, true)
	r.add_shape("body", ball(0.3, 6, 4), leaf, Vector3(0, 0.5, 0), Vector3(20, randf() * 90.0, 10), Vector3(1.0, 0.75, 1.0), 0.0, 0.0, true)
	for i: int in 6:
		var a: float = randf() * TAU
		var y: float = randf_range(0.4, 0.85)
		var dist: float = lerpf(0.5, 0.3, (y - 0.4) / 0.45)
		r.add_shape("body", ball(0.035, 5, 3), berry, Vector3(sin(a) * dist, y, cos(a) * dist))


static func _build_pickup(equippable: bool) -> ModelRig:
	var r := ModelRig.new()
	r.name = "PickupModel"
	r.height = 0.5
	r.radius = 0.35
	r.ao_strength = 0.6
	var none := Vector3.ZERO
	var one := Vector3.ONE
	if equippable:
		var wood := Color(0.25, 0.15, 0.1)
		var gold := Color(0.55, 0.44, 0.2)
		r.add_part("body", "", Vector3.ZERO, Vector3(0, 0.6, 0))
		r.add_shape("body", bbox(0.62, 0.28, 0.42, 0.03), wood, Vector3(0, 0.14, 0))
		r.add_shape("body", cyl(0.21, 0.21, 0.6, 12), wood.lightened(0.15), Vector3(0, 0.28, 0), Vector3(0, 0, 90), Vector3(0.85, 1, 1))
		for x: float in [-0.21, 0.21]:
			r.add_shape("body", bbox(0.1, 0.3, 0.45, 0.02), gold, Vector3(x, 0.14, 0), none, one, 0.0, 0.85)
			r.add_shape("body", cyl(0.225, 0.225, 0.1, 12), gold, Vector3(x, 0.28, 0), Vector3(0, 0, 90), Vector3(0.85, 1, 1), 0.0, 0.85)
		r.add_shape("body", bbox(0.64, 0.04, 0.44, 0.012), gold.darkened(0.2), Vector3(0, 0.27, 0), none, one, 0.0, 0.8)
		r.add_shape("body", bbox(0.15, 0.18, 0.08, 0.025), Color(1.0, 0.75, 0.3), Vector3(0, 0.25, -0.21), none, one, 0.7, 0.8)
		r.add_shape("body", bbox(0.04, 0.07, 0.09, 0.01), Color(0.1, 0.06, 0.04), Vector3(0, 0.23, -0.215))
	else:
		var cloth := Color(0.55, 0.52, 0.45)
		var cord := Color(0.2, 0.14, 0.1)
		r.add_part("body")
		r.add_shape("body", lathe([0.12, 0.0, 0.25, 0.08, 0.27, 0.22, 0.2, 0.34, 0.09, 0.39], 14, 7, 0.03, 0.08), cloth)
		r.add_shape("body", lathe([0.075, 0.37, 0.1, 0.44, 0.16, 0.5, 0.15, 0.52], 12, 6, 0.1, 0.25), cloth.darkened(0.08))
		r.add_shape("body", torus(0.075, 0.115, 12, 5), cord, Vector3(0, 0.385, 0))
		r.add_shape("body", bbox(0.13, 0.13, 0.04, 0.012), Color(0.45, 0.8, 0.95), Vector3(0.0, 0.24, -0.265), Vector3(-12, 0, 45), one, 0.6)
	r.finish()
	return r


# ---------------------------------------------------------------- weapons

static func _build_weapon(id: String) -> ModelRig:
	var r := ModelRig.new()
	r.name = "Weapon_" + id
	r.height = 0.3
	r.radius = 0.3
	r.ao_strength = 0.0
	var none := Vector3.ZERO
	var one := Vector3.ONE
	var flatwise := Vector3(0, 90, 0)
	var dark_iron := Color(0.17, 0.17, 0.2)
	var brass := Color(0.5, 0.4, 0.2)
	var edge := Color(0.72, 0.75, 0.8)
	match id:
		"iron_knuckles":
			# Authored in forearm space (fist at the origin, knuckles toward -Y); the part
			# rotation undoes the hand's forward tilt so the bands sit square on the fist.
			r.add_part("body", "", none, Vector3(deg_to_rad(45.0), 0, 0)).scale = Vector3.ONE * 0.5
			r.add_shape("body", lathe([0.15, -0.085, 0.172, -0.065, 0.172, -0.005, 0.15, 0.015], 12), dark_iron, Vector3(0, 0, -0.01), none, Vector3(0.95, 1.0, 1.0), 0.0, 0.8)
			for x: float in [-0.065, 0.065]:
				r.add_shape("body", lathe([0.13, -0.022, 0.145, 0.0, 0.13, 0.022], 10), STEEL, Vector3(x, -0.01, -0.01), Vector3(0, 0, 90), Vector3(1.0, 1.0, 1.0), 0.0, 1.0)
			r.add_shape("body", bbox(0.3, 0.085, 0.13, 0.025), dark_iron, Vector3(0, -0.105, -0.085), none, one, 0.0, 0.8)
			for k: int in 4:
				var x: float = -0.108 + 0.072 * float(k)
				r.add_shape("body", cyl(0.0, 0.04, 0.1, 4), edge, Vector3(x, -0.165, -0.115), Vector3(-155, 0, 0), one, 0.0, 1.0, true)
				r.add_shape("body", ball(0.02, 6, 3), brass, Vector3(x, -0.085, -0.153), none, one, 0.0, 0.9)
		"serrated_dagger":
			r.add_part("body")
			var teeth: Array = [0.085, 0.05, 0.36, 0.05, 0.5, 0.0]
			var x: float = 0.44
			while x > 0.1:
				teeth.append_array([x, -0.07, x - 0.022, -0.03])
				x -= 0.055
			teeth.append_array([0.085, -0.045])
			r.add_shape("body", MeshKit.extrude(poly(teeth), 0.02), STEEL.lightened(0.15), none, flatwise, one, 0.0, 1.0)
			r.add_shape("body", MeshKit.extrude(poly([0.1, 0.018, 0.38, 0.018, 0.38, 0.034, 0.1, 0.034]), 0.034), dark_iron, none, flatwise, one, 0.0, 0.8)
			r.add_shape("body", MeshKit.extrude(poly([0.05, -0.09, 0.085, -0.075, 0.085, 0.075, 0.05, 0.09]), 0.055), brass, none, flatwise, one, 0.0, 0.9)
			r.add_shape("body", MeshKit.extrude(poly([-0.13, -0.024, 0.05, -0.024, 0.05, 0.024, -0.13, 0.024]), 0.042), Color(0.2, 0.07, 0.06), none, flatwise)
			r.add_shape("body", ball(0.036, 8, 4), brass, Vector3(0, 0, 0.14), none, one, 0.0, 0.9)
		"invader_cleaver":
			r.add_part("body").scale = Vector3.ONE * 0.8
			r.add_shape("body", MeshKit.extrude(poly([0.09, 0.06, 0.3, 0.075, 0.36, 0.055, 0.42, 0.085, 0.6, 0.09, 0.66, 0.04, 0.66, -0.17, 0.6, -0.22, 0.18, -0.19, 0.12, -0.07, 0.09, -0.05]), 0.04), dark_iron, none, flatwise, one, 0.0, 0.8)
			r.add_shape("body", MeshKit.extrude(poly([0.18, -0.19, 0.6, -0.22, 0.66, -0.17, 0.66, -0.12, 0.6, -0.17, 0.18, -0.145]), 0.046), edge, none, flatwise, one, 0.0, 1.0)
			for at: Vector2 in [Vector2(0.52, 0.02), Vector2(0.2, 0.0), Vector2(0.3, 0.0)]:
				r.add_shape("body", cyl(0.028, 0.028, 0.052, 8), brass if at.x < 0.4 else Color(0.06, 0.06, 0.08), Vector3(0, at.y, -at.x), Vector3(0, 0, 90), one, 0.0, 0.9)
			r.add_shape("body", MeshKit.extrude(poly([-0.17, -0.03, 0.09, -0.03, 0.09, 0.03, -0.17, 0.03]), 0.052), WOOD, none, flatwise)
			for x: float in [-0.12, -0.04, 0.04]:
				r.add_shape("body", MeshKit.extrude(poly([x - 0.014, -0.034, x + 0.014, -0.034, x + 0.014, 0.034, x - 0.014, 0.034]), 0.058), LEATHER.lightened(0.15), none, flatwise)
		"commander_blade":
			r.add_part("body")
			var gold := Color(0.55, 0.44, 0.2)
			var fire := Color(1.0, 0.62, 0.15)
			r.add_shape("body", MeshKit.extrude(poly([0.11, -0.055, 0.3, -0.045, 0.82, -0.042, 1.02, 0.0, 0.82, 0.042, 0.3, 0.045, 0.11, 0.055]), 0.024), STEEL.lightened(0.2), none, flatwise, one, 0.0, 1.0)
			r.add_shape("body", MeshKit.extrude(poly([0.15, -0.012, 0.74, -0.009, 0.8, 0.0, 0.74, 0.009, 0.15, 0.012]), 0.03), STEEL.darkened(0.4), none, flatwise, one, 0.0, 1.0)
			r.add_shape("body", MeshKit.extrude(poly([0.05, -0.17, 0.1, -0.21, 0.135, -0.16, 0.115, -0.06, 0.115, 0.06, 0.135, 0.16, 0.1, 0.21, 0.05, 0.17, 0.075, 0.06, 0.075, -0.06]), 0.045), gold, none, flatwise, one, 0.0, 0.9)
			r.add_shape("body", ball(0.035, 8, 4), fire, Vector3(0, 0, -0.095), none, Vector3(1.4, 0.8, 0.8), 0.9)
			r.add_shape("body", MeshKit.extrude(poly([-0.15, -0.023, 0.06, -0.023, 0.06, 0.023, -0.15, 0.023]), 0.042), Color(0.22, 0.05, 0.06), none, flatwise)
			for x: float in [-0.1, -0.04, 0.02]:
				r.add_shape("body", MeshKit.extrude(poly([x - 0.008, -0.027, x + 0.008, -0.027, x + 0.008, 0.027, x - 0.008, 0.027]), 0.048), gold, none, flatwise, one, 0.0, 0.9)
			r.add_shape("body", lathe([0.0, -0.05, 0.04, -0.02, 0.045, 0.01, 0.0, 0.05], 8), gold, Vector3(0, 0, 0.18), Vector3(90, 0, 0), one, 0.0, 0.9, true)
		_:
			r.add_part("body")
			r.add_shape("body", lathe([0.026, -0.12, 0.03, 0.05, 0.05, 0.3, 0.058, 0.4, 0.03, 0.44], 8), WOOD, none, Vector3(-90, 0, 0))
			r.add_shape("body", lathe([0.05, 0.27, 0.06, 0.29, 0.056, 0.31], 8), dark_iron, none, Vector3(-90, 0, 0), one, 0.0, 0.8)
			r.add_shape("body", lathe([0.03, -0.1, 0.036, -0.03, 0.03, 0.04], 8), LEATHER, none, Vector3(-90, 0, 0))
	r.finish()
	return r


# ---------------------------------------------------------------- helpers

## Returns a fresh rig for `key`, building and baking it only the first time.
static func _stamp(key: String, builder: Callable) -> ModelRig:
	if _snaps.has(key):
		return ModelRig.from_snapshot(_snaps[key])
	var rig: ModelRig = builder.call() as ModelRig
	_snaps[key] = rig.snapshot()
	return rig


static func _enemy_def(kind: String) -> Dictionary:
	if _enemy_data.is_empty() and FileAccess.file_exists(ENEMY_DATA_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ENEMY_DATA_PATH))
		if parsed is Dictionary:
			_enemy_data = (parsed as Dictionary).get("enemies", {})
	var def: Variant = _enemy_data.get(kind, {})
	return def if def is Dictionary else {}


## Pulls a (data-file) colour toward grey and darkens it: `keep` is how much saturation
## survives, `value` scales brightness. Enemy body colours go through this.
static func grim(color: Color, keep: float = 0.45, value: float = 0.7) -> Color:
	var l: float = color.get_luminance()
	return Color(lerpf(l, color.r, keep) * value, lerpf(l, color.g, keep) * value, lerpf(l, color.b, keep) * value)


## MeshKit.lathe from a flat [radius, y, radius, y, ...] list.
static func lathe(profile: Array, sides: int = 12, ripple_n: int = 0, ripple_bottom: float = 0.0, ripple_top: float = 0.0, hem: float = 0.0) -> ArrayMesh:
	var around: int = sides if ripple_n > 0 or sides <= 5 else int(round(float(sides) * _detail))
	return MeshKit.lathe(poly(profile), around, ripple_n, ripple_bottom, ripple_top, hem)


## MeshKit.tube from a flat [x, y, z, ...] path and a list of radii.
static func tube(path: Array, radii: Array, sides: int = 8, flatten: float = 1.0, wide: Vector3 = Vector3.ZERO) -> ArrayMesh:
	var points := PackedVector3Array()
	for i: int in range(0, path.size() - 2, 3):
		points.append(Vector3(float(path[i]), float(path[i + 1]), float(path[i + 2])))
	return MeshKit.tube(points, PackedFloat32Array(radii), sides, flatten, wide)


## Bevelled box; `top_x` / `top_z` taper the top face.
static func bbox(x: float, y: float, z: float, bevel: float = 0.03, top_x: float = 1.0, top_z: float = 1.0) -> ArrayMesh:
	return MeshKit.bevel_box(Vector3(x, y, z), bevel, Vector2(top_x, top_z))


## A flat [x, y, x, y, ...] list as points.
static func poly(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in range(0, points.size() - 1, 2):
		out.append(Vector2(float(points[i]), float(points[i + 1])))
	return out


static func cyl(top: float, bottom: float, h: float, sides: int = 12) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = sides if sides <= 5 else int(round(float(sides) * _detail))
	m.rings = 0
	return m


static func ball(radius: float, sides: int = 12, rings: int = 6) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = int(round(float(sides) * _detail))
	m.rings = int(round(float(rings) * _detail))
	return m


## A ring lying in the XZ plane; `inner` / `outer` are the hole and rim radii.
static func torus(inner: float, outer: float, segments: int = 20, sides: int = 6) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = segments
	m.ring_segments = sides
	return m
