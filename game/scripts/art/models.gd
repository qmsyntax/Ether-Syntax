class_name Models
extends RefCounted
## Procedural low-poly art library. Every builder returns a finished ModelRig assembled from
## Godot primitive meshes - no image or mesh assets. All designs are original to this project.
##
## Usage:  var rig := Models.enemy("brute");  add_child(rig);  rig.animate(delta, speed, attacking)

const ENEMY_DATA_PATH := "res://data/enemies.json"

const SKIN := Color(0.88, 0.65, 0.47)
const BONE := Color(0.93, 0.88, 0.74)
const STEEL := Color(0.72, 0.76, 0.82)
const IRON := Color(0.2, 0.2, 0.27)
const LEATHER := Color(0.36, 0.23, 0.13)

static var _enemy_data: Dictionary = {}


# ---------------------------------------------------------------- public builders

## The hero: an "archhuman" brawler in blue with a glowing cyan headband and sash, cream
## hand-wraps and a steel gauntlet on the right arm. Supports
## set_part_visible("arm_right", false), which also reveals a bandaged stump.
static func player() -> ModelRig:
	var r := ModelRig.new()
	r.name = "PlayerModel"
	r.height = 1.85
	r.radius = 0.4
	r.stride_speed = 5.0
	r.stride_rate = 2.6
	r.swing = 0.75
	var blue := Color(0.15, 0.45, 0.75)
	var blue_l := Color(0.3, 0.62, 0.95)
	var navy := Color(0.1, 0.14, 0.3)
	var wrap := Color(0.94, 0.9, 0.8)
	var hair := Color(0.14, 0.09, 0.07)
	var cyan := Color(0.4, 0.95, 1.0)
	var boot := Color(0.22, 0.14, 0.1)

	for side: int in [-1, 1]:
		var n: String = "left" if side < 0 else "right"
		r.add_part("leg_" + n, "", Vector3(0.15 * side, 0.86, 0.0))
		r.add_shape("leg_" + n, _cyl(0.14, 0.115, 0.46), navy, Vector3(0, -0.2, 0))
		r.add_part("shin_" + n, "leg_" + n, Vector3(0, -0.42, 0))
		r.add_shape("shin_" + n, _cyl(0.11, 0.095, 0.34), navy, Vector3(0, -0.15, 0))
		r.add_shape("shin_" + n, _cyl(0.105, 0.11, 0.1), wrap, Vector3(0, -0.27, 0))
		r.add_shape("shin_" + n, _box(0.21, 0.14, 0.34), boot, Vector3(0, -0.37, -0.05))

	r.add_part("body", "", Vector3(0, 0.86, 0))
	r.add_shape("body", _box(0.5, 0.2, 0.32), navy, Vector3(0, 0.04, 0))
	r.add_shape("body", _cyl(0.27, 0.27, 0.1), cyan, Vector3(0, 0.17, 0), Vector3.ZERO, Vector3(1, 1, 0.7), 0.55)
	r.add_shape("body", _box(0.12, 0.34, 0.05), cyan, Vector3(0.15, -0.02, -0.19), Vector3(-6, 0, 0), Vector3.ONE, 0.55)

	r.add_part("torso", "body", Vector3(0, 0.2, 0))
	r.add_shape("torso", _cyl(0.38, 0.25, 0.48), blue, Vector3(0, 0.24, 0), Vector3.ZERO, Vector3(1, 1, 0.66))
	r.add_shape("torso", _box(0.3, 0.3, 0.04), blue_l, Vector3(0, 0.28, -0.2), Vector3(8, 0, 0))
	r.add_shape("torso", _cyl(0.09, 0.1, 0.12), SKIN, Vector3(0, 0.52, 0))

	r.add_part("head", "torso", Vector3(0, 0.5, 0))
	r.add_shape("head", _ball(0.19), SKIN, Vector3(0, 0.09, 0))
	r.add_shape("head", _ball(0.2), hair, Vector3(0, 0.2, 0.02), Vector3.ZERO, Vector3(1.0, 0.62, 1.0))
	r.add_shape("head", _cyl(0.195, 0.2, 0.05, 8), cyan, Vector3(0, 0.18, 0.0), Vector3(-6, 0, 0), Vector3.ONE, 0.7)
	r.add_shape("head", _box(0.05, 0.04, 0.03), hair, Vector3(-0.075, 0.06, -0.175))
	r.add_shape("head", _box(0.05, 0.04, 0.03), hair, Vector3(0.075, 0.06, -0.175))
	r.add_part("band_tail", "head", Vector3(0, 0.15, 0.19), Vector3(0.75, 0, 0))
	r.add_shape("band_tail", _box(0.06, 0.05, 0.36), cyan, Vector3(-0.05, 0, 0.18), Vector3(0, -10, 0), Vector3.ONE, 0.7)
	r.add_shape("band_tail", _box(0.06, 0.05, 0.28), cyan, Vector3(0.05, -0.03, 0.14), Vector3(-14, 12, 0), Vector3.ONE, 0.7)
	r.sway_parts["band_tail"] = -0.6

	for side: int in [-1, 1]:
		var n: String = "left" if side < 0 else "right"
		r.add_part("arm_" + n, "torso", Vector3(0.44 * side, 0.42, 0), Vector3(0, 0, 0.14 * side))
		r.add_shape("arm_" + n, _ball(0.145, 6, 3), blue_l, Vector3.ZERO)
		r.add_shape("arm_" + n, _cyl(0.105, 0.095, 0.3), SKIN, Vector3(0, -0.17, 0))
		r.add_part("forearm_" + n, "arm_" + n, Vector3(0, -0.32, 0), Vector3(0.4, 0, 0))
		if side < 0:
			r.add_shape("forearm_" + n, _cyl(0.095, 0.115, 0.28), wrap, Vector3(0, -0.13, 0))
			r.add_shape("forearm_" + n, _box(0.21, 0.2, 0.21), wrap, Vector3(0, -0.32, 0))
		else:
			r.add_shape("forearm_" + n, _cyl(0.12, 0.15, 0.3), STEEL, Vector3(0, -0.13, 0))
			r.add_shape("forearm_" + n, _cyl(0.16, 0.16, 0.06), cyan, Vector3(0, -0.02, 0), Vector3.ZERO, Vector3.ONE, 0.7)
			r.add_shape("forearm_" + n, _box(0.29, 0.25, 0.29), IRON.lightened(0.3), Vector3(0, -0.36, 0))
			r.add_shape("forearm_" + n, _box(0.31, 0.09, 0.12), cyan, Vector3(0, -0.44, -0.1), Vector3.ZERO, Vector3.ONE, 0.9)

	r.add_part("arm_right_stump", "torso", Vector3(0.44, 0.42, 0))
	r.add_shape("arm_right_stump", _ball(0.145, 6, 3), blue_l, Vector3.ZERO)
	r.add_shape("arm_right_stump", _cyl(0.11, 0.1, 0.12), wrap, Vector3(0.03, -0.12, 0), Vector3(0, 0, 12))
	r.add_shape("arm_right_stump", _cyl(0.115, 0.1, 0.07), Color(0.75, 0.06, 0.06), Vector3(0.045, -0.21, 0), Vector3(0, 0, 12), Vector3.ONE, 0.25)
	r.get_part("arm_right_stump").visible = false

	r.finish()
	return r


## An enemy model for a kind in data/enemies.json ("grunt", "brute", "commander"). Radius,
## height and base colour come from that file. Unknown kinds get a plain figure.
static func enemy(kind: String) -> ModelRig:
	var def: Dictionary = _enemy_def(kind)
	var radius: float = float(def.get("radius", 0.5))
	var height: float = float(def.get("height", 1.7))
	var rgb: Array = def.get("color", [0.6, 0.6, 0.6])
	var color := Color(float(rgb[0]), float(rgb[1]), float(rgb[2]))
	var r: ModelRig
	match kind:
		"grunt":
			r = _grunt(color)
		"brute":
			r = _brute(color)
		"commander":
			r = _commander(color)
		_:
			r = _plain(color, radius, height)
	r.name = "EnemyModel_" + kind
	r.radius = radius
	r.height = height
	r.stride_speed = float(def.get("speed", 3.0))
	r.finish()
	return r


## Living scenery: "grass" (a tuft of blades with seed heads, ~0.8 tall) or "bush" (a clumpy
## shrub, ~1.1 tall). Each call is a little different. The returned node is a ModelRig, so
## set_highlight() / flash() work on it; scale it freely to show damage.
static func scenery(kind: String) -> Node3D:
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
	r.rotation.y = randf() * TAU
	return r


## A small loot object ~0.5 tall: a pale tied bundle, or a gold-banded chest if `equippable`.
## The returned node is a ModelRig, so set_highlight() works on it.
static func pickup(equippable: bool) -> Node3D:
	var r := ModelRig.new()
	r.name = "PickupModel"
	r.height = 0.5
	r.radius = 0.35
	if equippable:
		var wood := Color(0.5, 0.2, 0.12)
		var gold := Color(1.0, 0.8, 0.25)
		r.add_part("body", "", Vector3.ZERO, Vector3(0, 0.6, 0))
		r.add_shape("body", _box(0.62, 0.28, 0.42), wood, Vector3(0, 0.14, 0))
		r.add_shape("body", _cyl(0.21, 0.21, 0.62, 8), wood.lightened(0.15), Vector3(0, 0.28, 0), Vector3(0, 0, 90), Vector3(0.85, 1, 1))
		for x: float in [-0.21, 0.21]:
			r.add_shape("body", _box(0.11, 0.3, 0.45), gold, Vector3(x, 0.14, 0), Vector3.ZERO, Vector3.ONE, 0.35)
			r.add_shape("body", _cyl(0.225, 0.225, 0.11, 8), gold, Vector3(x, 0.28, 0), Vector3(0, 0, 90), Vector3(0.85, 1, 1), 0.35)
		r.add_shape("body", _box(0.16, 0.18, 0.08), gold, Vector3(0, 0.26, -0.21), Vector3.ZERO, Vector3.ONE, 1.0)
	else:
		var cloth := Color(0.88, 0.89, 0.95)
		var cord := Color(0.2, 0.32, 0.6)
		r.add_part("body")
		r.add_shape("body", _ball(0.27, 7, 3), cloth, Vector3(0, 0.2, 0), Vector3.ZERO, Vector3(1, 0.8, 1))
		r.add_shape("body", _cyl(0.15, 0.08, 0.14), cloth.darkened(0.08), Vector3(0, 0.45, 0))
		r.add_shape("body", _cyl(0.1, 0.1, 0.06), cord, Vector3(0, 0.38, 0))
		r.add_shape("body", _box(0.13, 0.13, 0.04), Color(0.55, 0.85, 1.0), Vector3(0.0, 0.26, -0.24), Vector3(-20, 0, 45), Vector3.ONE, 0.7)
	r.finish()
	return r


# ---------------------------------------------------------------- enemies

## Masked Skirmisher: small hunched cone of ragged cloak, pointed hood, pale mask, long blade.
static func _grunt(color: Color) -> ModelRig:
	var r := ModelRig.new()
	r.stride_rate = 4.4
	r.swing = 0.95
	r.step_bob = 0.07
	r.lean = 0.25
	r.raise_arm = 2.7
	r.raise_forearm = 0.3
	r.strike_arm = 1.1
	r.strike_forearm = 0.0
	var cloak := color
	var cloak_d := color.darkened(0.45)
	var dark := Color(0.13, 0.09, 0.11)
	var eye := Color(1.0, 0.85, 0.25)

	for side: int in [-1, 1]:
		var n: String = "left" if side < 0 else "right"
		r.add_part("leg_" + n, "", Vector3(0.14 * side, 0.6, 0.0))
		r.add_shape("leg_" + n, _cyl(0.085, 0.07, 0.32), dark, Vector3(0, -0.14, 0))
		r.add_part("shin_" + n, "leg_" + n, Vector3(0, -0.3, 0))
		r.add_shape("shin_" + n, _cyl(0.07, 0.06, 0.26), dark, Vector3(0, -0.12, 0))
		r.add_shape("shin_" + n, _box(0.14, 0.09, 0.28), dark.lightened(0.12), Vector3(0, -0.255, -0.06))

	r.add_part("body", "", Vector3(0, 0.58, 0), Vector3(-0.16, 0, 0))
	r.add_shape("body", _cyl(0.2, 0.46, 0.72), cloak, Vector3(0, 0.2, 0.02))
	for i: int in 6:
		var a: float = TAU * float(i) / 6.0 + 0.5
		r.add_shape("body", _prism(0.3, 0.26, 0.05), cloak_d, Vector3(sin(a) * 0.4, -0.25, cos(a) * 0.4 + 0.02), Vector3(180, rad_to_deg(a), 0))
	r.add_shape("body", _cyl(0.3, 0.33, 0.12), cloak_d, Vector3(0, 0.55, 0.0))
	r.add_part("cloak", "body", Vector3(0, 0.5, 0.18), Vector3(-0.3, 0, 0))
	r.add_shape("cloak", _prism(0.5, 0.75, 0.05), cloak_d, Vector3(0, -0.36, 0.03), Vector3(180, 0, 0))
	r.sway_parts["cloak"] = -0.7

	r.add_part("torso", "body", Vector3(0, 0.3, 0))
	r.add_part("head", "torso", Vector3(0, 0.36, -0.06))
	r.add_shape("head", _cyl(0.02, 0.27, 0.5), cloak, Vector3(0, 0.2, 0.1), Vector3(32, 0, 0))
	r.add_shape("head", _ball(0.2, 6, 3), cloak_d, Vector3(0, 0.08, 0.0))
	r.add_shape("head", _box(0.25, 0.26, 0.06), BONE, Vector3(0, 0.08, -0.19), Vector3(-6, 0, 0))
	r.add_shape("head", _prism(0.25, 0.16, 0.06), BONE, Vector3(0, -0.13, -0.175), Vector3(174, 0, 0))
	r.add_shape("head", _box(0.07, 0.04, 0.03), eye, Vector3(-0.06, 0.11, -0.225), Vector3(0, 0, -14), Vector3.ONE, 1.2)
	r.add_shape("head", _box(0.07, 0.04, 0.03), eye, Vector3(0.06, 0.11, -0.225), Vector3(0, 0, 14), Vector3.ONE, 1.2)

	for side: int in [-1, 1]:
		var n: String = "left" if side < 0 else "right"
		r.add_part("arm_" + n, "torso", Vector3(0.27 * side, 0.2, -0.02), Vector3(0, 0, 0.25 * side))
		r.add_shape("arm_" + n, _cyl(0.08, 0.06, 0.3), cloak_d, Vector3(0, -0.14, 0))
		r.add_part("forearm_" + n, "arm_" + n, Vector3(0, -0.28, 0), Vector3(0.8, 0, 0))
		r.add_shape("forearm_" + n, _cyl(0.055, 0.05, 0.26), dark, Vector3(0, -0.12, 0))
		r.add_shape("forearm_" + n, _box(0.11, 0.11, 0.11), BONE.darkened(0.25), Vector3(0, -0.27, 0))
	# Blade: runs forward-and-down from the right hand so it levels out in the guard pose.
	r.add_shape("forearm_right", _box(0.05, 0.05, 0.2), LEATHER, Vector3(0, -0.27, 0), Vector3(-45, 0, 0))
	r.add_shape("forearm_right", _box(0.2, 0.04, 0.05), eye, Vector3(0, -0.33, -0.06), Vector3(-45, 0, 0), Vector3.ONE, 0.5)
	r.add_shape("forearm_right", _box(0.045, 0.13, 0.62), STEEL, Vector3(0, -0.57, -0.3), Vector3(-45, 0, 0), Vector3.ONE, 0.18)
	r.add_shape("forearm_right", _prism(0.13, 0.2, 0.045), STEEL, Vector3(0, -0.86, -0.59), Vector3(-135, 0, 0), Vector3.ONE, 0.18)
	return r


## Hide-Bound Brute: a wide hunched wedge, small sunk head with tusks, arms like tree trunks.
static func _brute(color: Color) -> ModelRig:
	var r := ModelRig.new()
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
	var hide := color.lightened(0.08)
	var hide_d := color.darkened(0.4)
	var hide_l := color.lightened(0.3)
	var eye := Color(1.0, 0.45, 0.15)

	for side: int in [-1, 1]:
		var n: String = "left" if side < 0 else "right"
		r.add_part("leg_" + n, "", Vector3(0.3 * side, 0.82, 0.0))
		r.add_shape("leg_" + n, _cyl(0.23, 0.19, 0.44), hide_d, Vector3(0, -0.18, 0))
		r.add_part("shin_" + n, "leg_" + n, Vector3(0, -0.4, 0))
		r.add_shape("shin_" + n, _cyl(0.18, 0.2, 0.34), LEATHER, Vector3(0, -0.15, 0))
		r.add_shape("shin_" + n, _box(0.38, 0.16, 0.5), hide_d, Vector3(0, -0.34, -0.07))

	r.add_part("body", "", Vector3(0, 0.82, 0))
	r.add_shape("body", _cyl(0.52, 0.44, 0.5), hide_d, Vector3(0, 0.2, 0), Vector3.ZERO, Vector3(1, 1, 0.85))
	r.add_shape("body", _box(0.5, 0.5, 0.08), LEATHER, Vector3(0, -0.08, -0.37), Vector3(6, 0, 0))
	r.add_shape("body", _cyl(0.54, 0.54, 0.1), LEATHER.darkened(0.2), Vector3(0, 0.2, 0), Vector3.ZERO, Vector3(1, 1, 0.85))

	r.add_part("torso", "body", Vector3(0, 0.42, 0), Vector3(-0.3, 0, 0))
	r.add_shape("torso", _cyl(0.68, 0.5, 0.72), hide, Vector3(0, 0.34, 0), Vector3.ZERO, Vector3(1, 1, 0.78))
	r.add_shape("torso", _ball(0.5, 6, 3), hide_d, Vector3(0, 0.62, 0.22), Vector3.ZERO, Vector3(1.15, 0.7, 0.9))
	r.add_shape("torso", _box(1.3, 0.14, 0.2), LEATHER, Vector3(0, 0.52, -0.42), Vector3(0, 0, 0))
	r.add_shape("torso", _box(0.2, 0.75, 0.1), LEATHER, Vector3(0.2, 0.3, -0.45), Vector3(12, 0, 28))
	for side: int in [-1, 1]:
		r.add_shape("torso", _ball(0.36, 6, 3), LEATHER, Vector3(0.7 * side, 0.68, 0), Vector3.ZERO, Vector3(1, 0.7, 1))
		r.add_shape("torso", _cyl(0.0, 0.11, 0.42, 5), BONE, Vector3(0.78 * side, 0.98, 0.0), Vector3(0, 0, -24 * side))
		r.add_shape("torso", _cyl(0.0, 0.08, 0.3, 5), BONE, Vector3(0.52 * side, 0.96, 0.18), Vector3(-15, 0, -10 * side))

	r.add_part("head", "torso", Vector3(0, 0.72, -0.38), Vector3(0.3, 0, 0))
	r.add_shape("head", _ball(0.25, 6, 3), hide_l, Vector3(0, 0.06, 0), Vector3.ZERO, Vector3(1, 0.9, 1))
	r.add_shape("head", _box(0.4, 0.16, 0.3), hide_d, Vector3(0, -0.1, -0.08))
	r.add_shape("head", _box(0.36, 0.07, 0.06), hide_d, Vector3(0, 0.14, -0.21))
	for side: int in [-1, 1]:
		r.add_shape("head", _cyl(0.0, 0.07, 0.34, 5), BONE, Vector3(0.17 * side, 0.03, -0.24), Vector3(-20, 0, -12 * side))
		r.add_shape("head", _box(0.08, 0.05, 0.04), eye, Vector3(0.1 * side, 0.08, -0.235), Vector3.ZERO, Vector3.ONE, 1.3)

	for side: int in [-1, 1]:
		var n: String = "left" if side < 0 else "right"
		r.add_part("arm_" + n, "torso", Vector3(0.74 * side, 0.58, -0.02), Vector3(0.25, 0, 0.16 * side))
		r.add_shape("arm_" + n, _cyl(0.24, 0.2, 0.62), hide, Vector3(0, -0.28, 0))
		r.add_part("forearm_" + n, "arm_" + n, Vector3(0, -0.58, 0), Vector3(0.3, 0, 0))
		r.add_shape("forearm_" + n, _cyl(0.21, 0.29, 0.58), hide_l, Vector3(0, -0.26, 0))
		r.add_shape("forearm_" + n, _cyl(0.27, 0.3, 0.16), LEATHER, Vector3(0, -0.3, 0))
		r.add_shape("forearm_" + n, _box(0.5, 0.42, 0.5), hide_d, Vector3(0, -0.72, 0))
		for k: int in 3:
			r.add_shape("forearm_" + n, _cyl(0.0, 0.075, 0.2, 4), BONE, Vector3(-0.15 + 0.15 * float(k), -0.9, -0.16), Vector3(150, 0, 0))
	return r


## Wall Commander: tall iron-and-gold armour, crested helm, tower shield, greatsword, crimson
## cape and a back-banner. The leader of a wall.
static func _commander(color: Color) -> ModelRig:
	var r := ModelRig.new()
	r.stride_rate = 2.2
	r.swing = 0.42
	r.step_bob = 0.04
	r.lean = 0.05
	r.raise_arm = 2.5
	r.raise_forearm = 0.5
	r.strike_arm = 0.7
	r.strike_forearm = 0.0
	var gold := color.lightened(0.2)
	gold = Color(gold.r * 1.15, gold.g * 1.1, gold.b)
	var iron := IRON
	var crimson := Color(0.66, 0.07, 0.1)
	var crimson_d := crimson.darkened(0.3)
	var fire := Color(1.0, 0.75, 0.2)

	for side: int in [-1, 1]:
		var n: String = "left" if side < 0 else "right"
		r.add_part("leg_" + n, "", Vector3(0.2 * side, 1.05, 0.0))
		r.add_shape("leg_" + n, _cyl(0.17, 0.14, 0.54), iron, Vector3(0, -0.24, 0))
		r.add_part("shin_" + n, "leg_" + n, Vector3(0, -0.5, 0))
		r.add_shape("shin_" + n, _ball(0.16, 6, 3), gold, Vector3(0, 0, -0.04))
		r.add_shape("shin_" + n, _cyl(0.15, 0.12, 0.44), iron, Vector3(0, -0.22, 0))
		r.add_shape("shin_" + n, _box(0.2, 0.4, 0.06), gold, Vector3(0, -0.24, -0.13))
		r.add_shape("shin_" + n, _box(0.27, 0.16, 0.42), iron.lightened(0.1), Vector3(0, -0.47, -0.06))

	r.add_part("body", "", Vector3(0, 1.05, 0))
	r.add_shape("body", _cyl(0.36, 0.52, 0.5), crimson, Vector3(0, -0.13, 0), Vector3.ZERO, Vector3(1, 1, 0.8))
	r.add_shape("body", _cyl(0.39, 0.39, 0.1), gold, Vector3(0, 0.13, 0), Vector3.ZERO, Vector3(1, 1, 0.8))
	r.add_shape("body", _box(0.2, 0.52, 0.06), gold, Vector3(0, -0.14, -0.38), Vector3(14, 0, 0))

	r.add_part("torso", "body", Vector3(0, 0.18, 0))
	r.add_shape("torso", _cyl(0.52, 0.34, 0.72), iron, Vector3(0, 0.36, 0), Vector3.ZERO, Vector3(1, 1, 0.74))
	r.add_shape("torso", _prism(0.44, 0.4, 0.06), gold, Vector3(0, 0.44, -0.36), Vector3(188, 0, 0), Vector3.ONE, 0.25)
	r.add_shape("torso", _cyl(0.2, 0.26, 0.12), gold, Vector3(0, 0.76, 0))
	for side: int in [-1, 1]:
		r.add_shape("torso", _ball(0.34, 6, 3), gold, Vector3(0.62 * side, 0.7, 0), Vector3.ZERO, Vector3(1.05, 0.72, 1.1))
		r.add_shape("torso", _cyl(0.0, 0.1, 0.34, 5), gold, Vector3(0.78 * side, 0.9, 0), Vector3(0, 0, -38 * side))

	r.add_part("cape", "torso", Vector3(0, 0.74, 0.3), Vector3(-0.14, 0, 0))
	r.add_shape("cape", _box(1.0, 1.55, 0.06), crimson, Vector3(0, -0.78, 0.03))
	r.add_shape("cape", _box(1.0, 0.14, 0.07), gold, Vector3(0, -1.5, 0.03))
	r.sway_parts["cape"] = -0.5

	r.add_part("banner", "torso", Vector3(-0.34, 0.2, 0.38), Vector3(-0.06, 0, 0.1))
	r.add_shape("banner", _cyl(0.035, 0.035, 1.3, 5), LEATHER.darkened(0.3), Vector3(0, 0.62, 0))
	r.add_shape("banner", _box(0.66, 0.05, 0.05), gold, Vector3(0, 1.2, 0))
	r.add_shape("banner", _cyl(0.0, 0.07, 0.16, 4), gold, Vector3(0, 1.31, 0), Vector3.ZERO, Vector3.ONE, 0.3)
	r.add_shape("banner", _box(0.56, 0.5, 0.03), crimson, Vector3(0, 0.94, 0.0))
	r.add_shape("banner", _prism(0.28, 0.2, 0.03), crimson, Vector3(-0.14, 0.59, 0.0), Vector3(180, 0, 0))
	r.add_shape("banner", _prism(0.28, 0.2, 0.03), crimson, Vector3(0.14, 0.59, 0.0), Vector3(180, 0, 0))
	r.add_shape("banner", _box(0.2, 0.2, 0.045), fire, Vector3(0, 0.95, 0.0), Vector3(0, 0, 45), Vector3.ONE, 0.6)
	r.sway_parts["banner"] = 0.12

	r.add_part("head", "torso", Vector3(0, 0.8, 0))
	r.add_shape("head", _cyl(0.19, 0.23, 0.36), iron.lightened(0.12), Vector3(0, 0.16, 0))
	r.add_shape("head", _cyl(0.0, 0.2, 0.12), iron.lightened(0.12), Vector3(0, 0.4, 0))
	r.add_shape("head", _box(0.3, 0.06, 0.06), fire, Vector3(0, 0.2, -0.2), Vector3.ZERO, Vector3.ONE, 1.4)
	r.add_shape("head", _box(0.06, 0.26, 0.06), gold, Vector3(0, 0.14, -0.21))
	r.add_shape("head", _box(0.08, 0.26, 0.52), crimson, Vector3(0, 0.46, 0.05), Vector3(-10, 0, 0))
	r.add_shape("head", _box(0.085, 0.1, 0.56), gold, Vector3(0, 0.33, 0.05), Vector3(-10, 0, 0))

	# Right arm: greatsword running forward-and-down from the fist (levels out on the strike).
	r.add_part("arm_right", "torso", Vector3(0.64, 0.62, 0), Vector3(0.15, 0, 0.1))
	r.add_shape("arm_right", _cyl(0.15, 0.13, 0.5), iron, Vector3(0, -0.24, 0))
	r.add_part("forearm_right", "arm_right", Vector3(0, -0.48, 0), Vector3(1.1, 0, 0))
	r.add_shape("forearm_right", _cyl(0.14, 0.17, 0.42), gold, Vector3(0, -0.2, 0))
	r.add_shape("forearm_right", _box(0.26, 0.24, 0.26), iron, Vector3(0, -0.48, 0))
	r.add_shape("forearm_right", _box(0.07, 0.07, 0.34), LEATHER, Vector3(0, -0.48, 0), Vector3(-30, 0, 0))
	r.add_shape("forearm_right", _box(0.5, 0.08, 0.08), gold, Vector3(0, -0.57, -0.16), Vector3(-30, 0, 0))
	r.add_shape("forearm_right", _box(0.07, 0.2, 1.25), STEEL, Vector3(0, -0.91, -0.74), Vector3(-30, 0, 0), Vector3.ONE, 0.2)
	r.add_shape("forearm_right", _prism(0.2, 0.26, 0.07), STEEL, Vector3(0, -1.29, -1.4), Vector3(-120, 0, 0), Vector3.ONE, 0.2)

	# Left arm carries the tower shield.
	r.add_part("arm_left", "torso", Vector3(-0.64, 0.62, 0), Vector3(0.2, 0, -0.1))
	r.add_shape("arm_left", _cyl(0.15, 0.13, 0.5), iron, Vector3(0, -0.24, 0))
	r.add_part("forearm_left", "arm_left", Vector3(0, -0.48, 0), Vector3(0.9, 0, 0))
	r.add_shape("forearm_left", _cyl(0.14, 0.17, 0.42), gold, Vector3(0, -0.2, 0))
	r.add_part("shield", "torso", Vector3(-0.62, 0.02, -0.5), Vector3(0.0, 0.5, 0))
	r.add_shape("shield", _box(0.8, 1.3, 0.08), iron.lightened(0.08), Vector3.ZERO)
	r.add_shape("shield", _box(0.86, 0.1, 0.1), gold, Vector3(0, 0.62, 0))
	r.add_shape("shield", _box(0.86, 0.1, 0.1), gold, Vector3(0, -0.62, 0))
	r.add_shape("shield", _box(0.1, 1.3, 0.1), gold, Vector3(-0.39, 0, 0))
	r.add_shape("shield", _box(0.1, 1.3, 0.1), gold, Vector3(0.39, 0, 0))
	r.add_shape("shield", _box(0.3, 0.3, 0.06), fire, Vector3(0, 0.1, -0.05), Vector3(0, 0, 45), Vector3.ONE, 0.7)
	return r


## Fallback for unknown kinds: a plain capsule body with a head.
static func _plain(color: Color, radius: float, height: float) -> ModelRig:
	var r := ModelRig.new()
	var head_r: float = minf(radius * 0.55, height * 0.16)
	var body_h: float = height - head_r * 1.6
	var cap := CapsuleMesh.new()
	cap.radius = radius * 0.75
	cap.height = maxf(body_h, cap.radius * 2.0)
	cap.radial_segments = 6
	cap.rings = 2
	r.add_part("body", "", Vector3(0, body_h * 0.5, 0))
	r.add_shape("body", cap, color, Vector3.ZERO)
	r.add_part("head", "body", Vector3(0, body_h * 0.5, 0))
	r.add_shape("head", _ball(head_r, 6, 3), color.lightened(0.25), Vector3(0, head_r * 0.5, 0))
	r.add_shape("head", _box(head_r * 1.2, head_r * 0.25, 0.05), Color(1, 0.9, 0.5), Vector3(0, head_r * 0.6, -head_r * 0.95), Vector3.ZERO, Vector3.ONE, 1.0)
	return r


# ---------------------------------------------------------------- scenery

static func _grass(r: ModelRig) -> void:
	var green := Color(0.35, 0.62, 0.2)
	var gold := Color(0.8, 0.7, 0.28)
	var seed_col := Color(0.98, 0.9, 0.5)
	r.add_part("body")
	var blades: int = 11
	for i: int in blades:
		var yaw: float = TAU * float(i) / float(blades) + randf_range(-0.3, 0.3)
		var tilt: float = randf_range(0.15, 0.62)
		var h: float = randf_range(0.42, 0.78)
		var base := Vector3(sin(yaw), 0.0, cos(yaw)) * randf_range(0.03, 0.13)
		var col: Color = green.lerp(gold, randf_range(0.0, 0.3)).lightened(randf_range(0.0, 0.18))
		_blade(r, base, h, tilt, yaw, col, 0.13)
	# Two upright seed stalks give the tuft its golden-realm silhouette.
	for i: int in 2:
		var yaw: float = randf() * TAU
		var tilt: float = randf_range(0.03, 0.14)
		var h: float = randf_range(0.54, 0.66)
		var basis := Basis.from_euler(Vector3(tilt, yaw, 0.0))
		r.add_shape("body", _cyl(0.02, 0.028, h, 4), green.darkened(0.2), basis * Vector3(0, h * 0.5, 0), Vector3(rad_to_deg(tilt), rad_to_deg(yaw), 0))
		r.add_shape("body", _cyl(0.0, 0.075, 0.24, 4), seed_col, basis * Vector3(0, h + 0.0, 0), Vector3(rad_to_deg(tilt), rad_to_deg(yaw), 0))


static func _blade(r: ModelRig, base: Vector3, h: float, tilt: float, yaw: float, color: Color, width: float) -> void:
	var basis := Basis.from_euler(Vector3(tilt, yaw, 0.0))
	r.add_shape("body", _cyl(0.0, width, h, 4), color, base + basis * Vector3(0, h * 0.5, 0), Vector3(rad_to_deg(tilt), rad_to_deg(yaw), 0), Vector3(1, 1, 0.45))


static func _bush(r: ModelRig) -> void:
	var leaf := Color(0.16, 0.38, 0.14)
	var leaf_l := Color(0.27, 0.5, 0.16)
	var olive := Color(0.5, 0.5, 0.16)
	var berry := Color(1.0, 0.6, 0.15)
	r.add_part("body")
	r.add_shape("body", _cyl(0.07, 0.11, 0.3, 5), LEATHER.darkened(0.2), Vector3(0, 0.15, 0))
	r.add_shape("body", _ball(0.46, 6, 3), leaf, Vector3(0, 0.46, 0), Vector3(0, randf() * 60.0, 0), Vector3(1, 0.85, 1))
	var clumps: int = 6
	for i: int in clumps:
		var a: float = TAU * float(i) / float(clumps) + randf_range(-0.25, 0.25)
		var rad: float = randf_range(0.24, 0.34)
		var dist: float = randf_range(0.3, 0.4)
		var y: float = randf_range(0.26, 0.5)
		var col: Color = leaf.lerp(leaf_l, randf()) if i % 3 != 0 else leaf_l.lerp(olive, randf_range(0.3, 0.8))
		r.add_shape("body", _ball(rad, 6, 3), col, Vector3(sin(a) * dist, y, cos(a) * dist), Vector3(randf() * 40.0, randf() * 60.0, 0), Vector3(1, 0.85, 1))
	r.add_shape("body", _ball(0.3, 6, 3), leaf_l, Vector3(randf_range(-0.1, 0.1), 0.82, randf_range(-0.1, 0.1)), Vector3(0, randf() * 60.0, 0), Vector3(1, 0.85, 1))
	for i: int in 5:
		var a: float = randf() * TAU
		var y: float = randf_range(0.35, 0.85)
		var dist: float = lerpf(0.66, 0.36, (y - 0.35) / 0.5)
		r.add_shape("body", _ball(0.055, 5, 2), berry, Vector3(sin(a) * dist, y, cos(a) * dist), Vector3.ZERO, Vector3.ONE, 0.35)


# ---------------------------------------------------------------- helpers

static func _enemy_def(kind: String) -> Dictionary:
	if _enemy_data.is_empty() and FileAccess.file_exists(ENEMY_DATA_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ENEMY_DATA_PATH))
		if parsed is Dictionary:
			_enemy_data = (parsed as Dictionary).get("enemies", {})
	var def: Variant = _enemy_data.get(kind, {})
	return def if def is Dictionary else {}


static func _box(x: float, y: float, z: float) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(x, y, z)
	return m


static func _cyl(top: float, bottom: float, h: float, sides: int = 6) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = sides
	m.rings = 0
	return m


static func _ball(radius: float, sides: int = 8, rings: int = 4) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = sides
	m.rings = rings
	return m


static func _prism(x: float, y: float, z: float) -> PrismMesh:
	var m := PrismMesh.new()
	m.size = Vector3(x, y, z)
	return m
