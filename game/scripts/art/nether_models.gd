class_name NetherModels
extends RefCounted
## Builders for the Netherecho (the spirit layer): the player's soul projection, essence
## wisps and the wild ether constructs. Use them through Models.projection(), Models.wisp()
## and Models.construct(), which cache the baked results.
##
## The constructs are this project's own abstract designs - one silhouette per concept:
##   acceleration  a rising flight of chevrons, each bigger and further ahead than the last
##   piercing      a faceted needle driven through torn membranes
##   compression   stacked plates squeezed between two heavy slabs around a crushed core
##   tension       floating struts held apart by taut bright cords around a suspended knot
##   reach         a rooted, jointed limb straining forward at a mote it never touches
##   stillness     a hanging drop inside perfectly level rings over frozen ripples

const TIER_HEIGHT: Dictionary[String, float] = {"vestige": 0.9, "remnant": 1.5, "spirit": 2.3}
const NONE := Vector3.ZERO
const ONE := Vector3.ONE


# ---------------------------------------------------------------- projection

## The player's soul projection: 1.0 tall, radius 0.3. A hooded robe with no legs, a bright
## ember at the chest, a tattered trailing hem and slivers flaking off it.
static func build_projection() -> ModelRig:
	var r := ModelRig.new()
	r.name = "ProjectionModel"
	r.height = 1.0
	r.radius = 0.3
	r.stride_speed = 4.0
	r.stride_rate = 3.0
	r.swing = 0.45
	r.bob = 0.035
	r.step_bob = 0.0
	r.lean = 0.3
	r.raise_arm = 2.4
	r.raise_forearm = 0.6
	r.strike_arm = 1.4
	r.strike_forearm = 0.1
	r.ao_strength = 0.35
	r.set_ghost(0.3, 1.3, 0.5)
	var robe := Color(0.2, 0.62, 0.85)
	var pale := Color(0.6, 0.95, 1.0)
	var hot := Color(0.92, 1.0, 1.0)
	var void_col := Color(0.04, 0.16, 0.3)

	r.add_part("body", "", Vector3(0, 0.36, 0))
	r.add_shape("body", Models.lathe([0.2, -0.27, 0.185, -0.14, 0.15, 0.04, 0.115, 0.2], 14, 7, 0.16, 0.0, 0.11), robe)
	r.add_part("trail", "body", Vector3(0, -0.2, 0.06), Vector3(-0.2, 0, 0))
	for x: float in [-0.1, 0.0, 0.1]:
		var drop: float = 0.2 if x == 0.0 else 0.13
		r.add_shape("trail", Models.tube([x, 0.0, 0.0, x * 1.2, -drop * 0.5, 0.03, x * 1.1, -drop, 0.09], [0.04, 0.028, 0.0], 5, 0.35, Vector3.RIGHT), robe.lightened(0.15))
	r.sway_parts["trail"] = -0.9

	r.add_part("torso", "body", Vector3(0, 0.18, 0))
	r.add_shape("torso", Models.lathe([0.115, -0.02, 0.145, 0.08, 0.155, 0.17, 0.1, 0.25, 0.04, 0.285], 12), robe, NONE, NONE, Vector3(1, 1, 0.72))
	r.add_shape("torso", Models.lathe([0.0, -0.06, 0.04, 0.0, 0.0, 0.06], 4), hot, Vector3(0, 0.13, -0.105), NONE, Vector3(1.0, 1.0, 0.5), 1.6, 0.0, true)

	# Hairline fractures across the robe: it looks like it would shatter if struck.
	r.add_shape("body", Models.tube([0.07, 0.2, -0.105, -0.01, 0.08, -0.14, 0.06, -0.03, -0.165, -0.02, -0.16, -0.19], [0.009, 0.011, 0.009, 0.0], 3), hot, NONE, NONE, ONE, 1.6)
	r.add_shape("body", Models.tube([-0.01, 0.08, -0.14, -0.08, 0.02, -0.14, -0.1, -0.1, -0.16], [0.009, 0.009, 0.0], 3), hot, NONE, NONE, ONE, 1.6)
	r.add_shape("body", Models.tube([-0.05, 0.2, 0.105, 0.03, 0.06, 0.145, -0.04, -0.08, 0.175, 0.04, -0.18, 0.19], [0.009, 0.011, 0.009, 0.0], 3), hot, NONE, NONE, ONE, 1.6)

	r.add_part("head", "torso", Vector3(0, 0.26, 0))
	r.add_shape("head", Models.ball(0.118, 14, 7), pale, Vector3(0, 0.09, 0.01))
	r.add_shape("head", Models.tube([0, 0.13, 0.03, 0, 0.2, 0.07, 0, 0.215, 0.14], [0.085, 0.05, 0.0], 8), pale)
	r.add_shape("head", Models.ball(0.092, 10, 5), void_col, Vector3(0, 0.08, -0.04))
	for side: int in [-1, 1]:
		r.add_shape("head", Models.ball(0.024, 8, 4), hot, Vector3(0.04 * side, 0.09, -0.118), NONE, Vector3(1.0, 1.3, 0.6), 2.0)

	for side: int in [-1, 1]:
		var n: String = "left" if side < 0 else "right"
		r.add_part("arm_" + n, "torso", Vector3(0.155 * side, 0.2, 0), Vector3(0, 0, 0.22 * side))
		r.add_shape("arm_" + n, Models.lathe([0.05, -0.2, 0.048, -0.08, 0.05, 0.0, 0.0, 0.04], 8), robe)
		r.add_part("forearm_" + n, "arm_" + n, Vector3(0, -0.18, 0), Vector3(0.5, 0, 0))
		r.add_shape("forearm_" + n, Models.lathe([0.082, -0.17, 0.06, -0.06, 0.048, 0.02], 10, 5, 0.14, 0.0, 0.04), robe.lightened(0.1))
		r.add_shape("forearm_" + n, Models.ball(0.034, 8, 4), pale, Vector3(0, -0.175, 0), NONE, ONE, 0.6)

	# Slivers flaking away: the fragile tell. They circle the figure slowly.
	r.add_part("flakes", "body", Vector3(0, 0.1, 0))
	for i: int in 6:
		var a: float = TAU * float(i) / 6.0
		var y: float = [-0.2, 0.32, 0.05, 0.42, -0.08, 0.2][i]
		var d: float = [0.3, 0.2, 0.27, 0.16, 0.29, 0.24][i]
		r.add_shape("flakes", Models.lathe([0.0, -0.04, 0.018, 0.0, 0.0, 0.04], 4), hot, Vector3(cos(a) * d, y, sin(a) * d), Vector3(20.0 * float(i), 0, 35), ONE, 1.2, 0.0, true)
	r.spin_parts["flakes"] = Vector3(0, 0.6, 0)

	r.finish()
	return r


# ---------------------------------------------------------------- wisps

## A Wisp node coloured for `affinity`.
static func build_wisp(affinity: String) -> Node3D:
	var w := Wisp.new()
	w.name = "WispModel"
	w.color = Color(0.2, 0.45, 0.8) if affinity == "water" else Color(0.6, 0.66, 0.7)
	return w


# ---------------------------------------------------------------- constructs

## Builds a construct. Every design is authored 1.0 tall under a "root" part that is scaled
## to the tier's height; `level` (0, 1, 2) adds elements with each tier.
static func build_construct(tier: String, concept: String) -> ModelRig:
	var size: float = TIER_HEIGHT.get(tier, 0.9)
	var level: int = 0
	if tier == "remnant":
		level = 1
	elif tier == "spirit":
		level = 2
	var r := ModelRig.new()
	r.name = "Construct_%s_%s" % [tier, concept]
	r.height = size
	r.ao_strength = 0.3
	r.swing = 0.12
	r.step_bob = 0.0
	r.set_ghost(0.72, 0.9, 0.5)
	var root: Node3D = r.add_part("root")
	root.scale = ONE * size
	var unit_radius: float = 0.35
	match concept:
		"acceleration":
			unit_radius = _acceleration(r, level)
		"piercing":
			unit_radius = _piercing(r, level)
		"compression":
			unit_radius = _compression(r, level)
		"tension":
			unit_radius = _tension(r, level)
		"reach":
			unit_radius = _reach(r, level)
		"stillness":
			unit_radius = _stillness(r, level)
		_:
			unit_radius = _generic(r, level)
	r.radius = unit_radius * size
	r.finish()
	return r


## A climbing train of beads that is visibly speeding up: each bead is bigger, hotter,
## further from the last and stretched longer than the one behind it, until the lead one is
## a white-tipped streak. Speed lines run alongside; higher tiers add shock rings.
static func _acceleration(r: ModelRig, level: int) -> float:
	r.stride_speed = 4.5
	r.bob = 0.03
	r.lean = 0.35
	r.strike_lunge = 0.35
	var slow := Color(0.8, 0.12, 0.05)
	var fast := Color(1.0, 0.82, 0.2)
	var hot := Color(1.0, 0.97, 0.85)
	var pitch: float = 30.0
	var dir := Vector3(0, sin(deg_to_rad(pitch)), -cos(deg_to_rad(pitch)))
	var turn := Vector3(pitch - 90.0, 0, 0)
	r.add_part("body", "root", Vector3(0, 0.5, 0.0))
	r.add_part("streaks", "body")
	var count: int = 4 + level
	var gaps: Array[float] = [0.0]
	var total: float = 0.0
	for k: int in count - 1:
		total += pow(1.5, float(k))
		gaps.append(total)
	var at: Vector3 = Vector3.ZERO
	var rad: float = 0.05
	for k: int in count:
		var t: float = float(k) / float(count - 1)
		rad = lerpf(0.06, 0.14, t)
		var tail: float = rad * (1.0 + 4.5 * t * t)
		at = dir * (gaps[k] / total * 0.8 - 0.46)
		var col: Color = slow.lerp(fast, t)
		r.add_shape("body", Models.lathe([0.0, -tail, 0.45 * rad, -tail * 0.5, 0.95 * rad, -0.1 * rad, rad, 0.3 * rad, 0.7 * rad, 0.8 * rad, 0.0, 1.05 * rad], 8), col, at, turn, ONE, 0.4 + 0.8 * t)
		if level >= 2 and k >= count - 2:
			r.add_shape("body", Models.torus(rad * 1.9, rad * 1.9 + 0.02, 18, 4), fast, at - dir * (tail * 0.5), turn, ONE, 1.0)
	r.add_shape("body", Models.ball(rad * 0.62, 8, 4), hot, at + dir * (rad * 0.62), NONE, ONE, 2.4)
	var lines: int = 3 + level * 2
	for i: int in lines:
		var a: float = TAU * (float(i) + 0.5) / float(lines)
		var side: Vector3 = Vector3(cos(a), sin(a) * cos(deg_to_rad(pitch)), sin(a) * sin(deg_to_rad(pitch))) * 0.26
		var from: Vector3 = at + side - dir * 0.05
		var to: Vector3 = from - dir * (0.5 + 0.12 * float(i % 2))
		r.add_shape("streaks", Models.tube([from.x, from.y, from.z, to.x, to.y, to.z], [0.02, 0.0], 4), fast.lerp(hot, 0.4), NONE, NONE, ONE, 1.0)
	r.sway_parts["streaks"] = -0.08
	return 0.4


## A faceted needle, tip down and forward, punched through membranes whose torn petals bend
## the way it is going. Higher tiers add membranes and circling splinters.
static func _piercing(r: ModelRig, level: int) -> float:
	r.stride_speed = 4.0
	r.bob = 0.03
	r.lean = 0.2
	r.strike_lunge = 0.3
	var shaft := Color(0.95, 0.75, 1.0)
	var petal := Color(0.75, 0.15, 0.75)
	var hot := Color(1.0, 0.95, 1.0)
	r.add_part("body", "root", Vector3(0, 0.52, 0), Vector3(0.25, 0, 0))
	r.add_shape("body", Models.lathe([0.0, -0.47, 0.022, -0.3, 0.052, 0.0, 0.036, 0.2, 0.0, 0.46], 6), shaft, NONE, NONE, ONE, 0.6, 0.0, true)
	r.add_shape("body", Models.ball(0.035, 8, 4), hot, Vector3(0, -0.45, 0), NONE, ONE, 2.2)
	var rings: Array = [[0.02, 0.3, 6]]
	if level >= 1:
		rings.append([0.22, 0.2, 5])
	if level >= 2:
		rings.append([-0.2, 0.22, 5])
	for ring: Array in rings:
		var y: float = ring[0]
		var reach: float = ring[1]
		var petals: int = ring[2]
		for i: int in petals:
			var yaw: float = 360.0 * float(i) / float(petals) + y * 200.0
			r.add_shape("body", Models.tube([0.07, y, 0.0, reach * 0.6, y - reach * 0.12, 0.0, reach, y - reach * 0.45, 0.0], [reach * 0.26, reach * 0.2, 0.0], 4, 0.12, Vector3.BACK), petal, NONE, Vector3(0, yaw, 0), ONE, 0.4)
		r.add_shape("body", Models.torus(0.055, 0.085, 10, 4), hot, Vector3(0, y, 0), NONE, ONE, 1.2)
	if level >= 1:
		r.add_part("splinters", "body")
		var count: int = 2 if level == 1 else 4
		for i: int in count:
			var a: float = TAU * float(i) / float(count)
			r.add_shape("splinters", Models.lathe([0.0, -0.2, 0.02, 0.0, 0.0, 0.14], 4), shaft, Vector3(cos(a) * 0.27, 0.1 - 0.12 * float(i % 2), sin(a) * 0.27), NONE, ONE, 0.9, 0.0, true)
		r.spin_parts["splinters"] = Vector3(0, 1.4, 0)
	return 0.32


## Two heavy slabs bearing down on a stack of plates that shrink toward a crushed, glowing
## core, with wedges driven in around the waist. Squat and dense.
static func _compression(r: ModelRig, level: int) -> float:
	r.stride_speed = 2.0
	r.bob = 0.012
	r.lean = 0.05
	r.strike_lunge = 0.18
	var slab := Color(0.24, 0.2, 0.7)
	var plate := Color(0.5, 0.3, 0.95)
	var hot := Color(1.0, 0.7, 0.95)
	r.add_part("body", "root", Vector3(0, 0.5, 0))
	for side: int in [-1, 1]:
		var flip := Vector3(0 if side > 0 else 180, 0, 0)
		r.add_shape("body", Models.bbox(0.52, 0.15, 0.52, 0.045, 0.68, 0.68), slab, Vector3(0, 0.3 * side, 0), flip, ONE, 0.1, 0.0, true)
		r.add_shape("body", Models.bbox(0.44, 0.03, 0.44, 0.012), plate, Vector3(0, 0.215 * side, 0), NONE, ONE, 0.5, 0.0, true)
		if level >= 1:
			r.add_shape("body", Models.bbox(0.3, 0.1, 0.3, 0.035, 0.6, 0.6), slab.lightened(0.12), Vector3(0, 0.42 * side, 0), flip, ONE, 0.15, 0.0, true)
		for k: int in 3:
			var y: float = [0.165, 0.115, 0.07][k]
			var rad: float = [0.2, 0.15, 0.115][k]
			r.add_shape("body", Models.cyl(rad, rad, 0.03, 10), plate.lerp(hot, float(k) / 3.0), Vector3(0, y * side, 0), NONE, ONE, 0.4 + 0.3 * float(k))
	r.add_shape("body", Models.ball(0.11, 14, 7), hot, NONE, NONE, Vector3(1.3, 0.5, 1.3), 2.0)
	var wedges: int = 4 + level * 2
	for i: int in wedges:
		var a: float = TAU * float(i) / float(wedges) + PI / 4.0
		r.add_shape("body", Models.cyl(0.0, 0.075, 0.17, 4), slab.lightened(0.25), Vector3(cos(a) * 0.3, 0.0, sin(a) * 0.3), Vector3(0, -rad_to_deg(a), 90), Vector3(1.0, 1.0, 0.6), 0.3, 0.0, true)
	if level >= 2:
		for i: int in 4:
			var yaw: float = 90.0 * float(i)
			r.add_shape("body", MeshKit.arc(0.5, 0.026, -38.0, 38.0, 10, 5, 0.5), plate, Vector3(-0.07, 0, 0).rotated(Vector3.UP, deg_to_rad(yaw)), Vector3(0, yaw, 0), ONE, 0.6)
		r.add_shape("body", Models.torus(0.36, 0.385, 20, 5), hot, NONE, NONE, Vector3(1.0, 0.6, 1.0), 0.9)
	return 0.36 if level < 2 else 0.44


## Three struts that never touch, held in a twisted prism by taut bright cords, with a knot
## suspended dead centre. Higher tiers add strung bows around the outside.
static func _tension(r: ModelRig, level: int) -> float:
	r.stride_speed = 3.0
	r.bob = 0.02
	r.lean = 0.1
	r.strike_lunge = 0.25
	var strut := Color(0.95, 0.25, 0.2)
	var cord := Color(1.0, 0.95, 0.65)
	var knot := Color(1.0, 0.6, 0.3)
	r.add_part("body", "root", Vector3(0, 0.52, 0))
	var low: Array[Vector3] = []
	var high: Array[Vector3] = []
	for i: int in 3:
		var a: float = TAU * float(i) / 3.0
		var b: float = a + deg_to_rad(150.0)
		low.append(Vector3(cos(a) * 0.27, -0.38, sin(a) * 0.27))
		high.append(Vector3(cos(b) * 0.27, 0.38, sin(b) * 0.27))
	for i: int in 3:
		var mid: Vector3 = (low[i] + high[i]) * 0.5
		mid += Vector3(mid.x, 0, mid.z).normalized() * 0.04 if Vector3(mid.x, 0, mid.z).length() > 0.001 else Vector3.ZERO
		r.add_shape("body", Models.tube([low[i].x, low[i].y, low[i].z, mid.x, mid.y, mid.z, high[i].x, high[i].y, high[i].z], [0.022, 0.04, 0.022], 6), strut, NONE, NONE, ONE, 0.35)
		r.add_shape("body", Models.ball(0.05, 8, 4), knot, low[i], NONE, ONE, 0.7)
		r.add_shape("body", Models.ball(0.05, 8, 4), knot, high[i], NONE, ONE, 0.7)
		_cord(r, low[i], low[(i + 1) % 3], cord)
		_cord(r, high[i], high[(i + 1) % 3], cord)
		_cord(r, low[i], Vector3.ZERO, cord)
		_cord(r, high[i], Vector3.ZERO, cord)
		if level >= 1:
			_cord(r, low[i], high[(i + 2) % 3], cord)
	r.add_shape("body", Models.lathe([0.0, -0.09, 0.065, 0.0, 0.0, 0.09], 6), cord, NONE, NONE, ONE, 2.0, 0.0, true)
	if level >= 1:
		var bows: int = 3 if level == 1 else 6
		for i: int in bows:
			var yaw: float = 360.0 * float(i) / float(bows) + 30.0
			var off: Vector3 = Vector3(-0.1, 0, 0).rotated(Vector3.UP, deg_to_rad(yaw))
			r.add_shape("body", MeshKit.arc(0.5, 0.03, -52.0, 52.0, 12, 5, 0.35), strut.lightened(0.15), off, Vector3(0, yaw, 0), ONE, 0.4)
			var tip := Vector3(0.5 * cos(deg_to_rad(52.0)) - 0.1, 0.5 * sin(deg_to_rad(52.0)), 0.0).rotated(Vector3.UP, deg_to_rad(yaw))
			_cord(r, tip, Vector3(tip.x, -tip.y, tip.z), cord)
	return 0.33 if level == 0 else 0.42


static func _cord(r: ModelRig, a: Vector3, b: Vector3, color: Color) -> void:
	r.add_shape("body", Models.tube([a.x, a.y, a.z, b.x, b.y, b.z], [0.012, 0.012], 3), color, NONE, NONE, ONE, 1.4)


## A small root clamped to the ground and one long jointed limb straining up and forward,
## fingers splayed toward a mote that stays just out of touch. The limb is the strike arm.
static func _reach(r: ModelRig, level: int) -> float:
	r.stride_speed = 2.8
	r.bob = 0.015
	r.lean = 0.1
	r.strike_lunge = 0.1
	r.raise_arm = 3.3
	r.raise_forearm = 0.35
	r.strike_arm = 1.75
	r.strike_forearm = -0.1
	var limb := Color(0.1, 0.8, 0.65)
	var joint := Color(0.5, 1.0, 0.85)
	var hot := Color(0.92, 1.0, 0.95)
	r.add_part("body", "root", Vector3(0, 0.16, 0.26))
	r.add_shape("body", Models.lathe([0.13, -0.15, 0.12, -0.09, 0.07, 0.0, 0.05, 0.08], 8), limb.darkened(0.3), NONE, NONE, ONE, 0.0, 0.0, true)
	for i: int in 3:
		var a: float = TAU * float(i) / 3.0 + PI / 2.0
		var dir := Vector3(cos(a), 0, sin(a))
		r.add_shape("body", Models.tube([dir.x * 0.06, -0.08, dir.z * 0.06, dir.x * 0.18, -0.1, dir.z * 0.18, dir.x * 0.3, -0.15, dir.z * 0.3], [0.035, 0.025, 0.0], 4), limb.darkened(0.3))
	_reach_limb(r, "arm_right", "forearm_right", Vector3(0, 0.04, 0), Vector3(deg_to_rad(150.0), 0, 0), 1.0, 3 + level, limb, joint, hot)
	if level >= 1:
		_reach_limb(r, "arm_left", "forearm_left", Vector3(-0.04, 0.03, 0.0), Vector3(deg_to_rad(165.0), 0, deg_to_rad(-34.0)), 0.55, 3, limb, joint, hot)
	if level >= 2:
		_reach_limb(r, "limb_back", "limb_back_tip", Vector3(0.04, 0.03, 0.0), Vector3(deg_to_rad(168.0), 0, deg_to_rad(36.0)), 0.45, 3, limb, joint, hot)
	return 0.45


static func _reach_limb(r: ModelRig, upper: String, lower: String, at: Vector3, rot: Vector3, scale: float, fingers: int, limb: Color, joint: Color, hot: Color) -> void:
	var a: float = 0.5 * scale
	var b: float = 0.42 * scale
	r.add_part(upper, "body", at, rot)
	r.add_shape(upper, Models.lathe([0.04 * scale, -a, 0.052 * scale, -a * 0.5, 0.07 * scale, 0.0], 8), limb, NONE, NONE, ONE, 0.2)
	r.add_shape(upper, Models.torus(0.04 * scale, 0.085 * scale, 10, 4), joint, Vector3(0, -a, 0), NONE, ONE, 0.9)
	r.add_shape(upper, Models.torus(0.05 * scale, 0.074 * scale, 10, 4), joint, Vector3(0, -a * 0.5, 0), NONE, ONE, 0.6)
	r.add_part(lower, upper, Vector3(0, -a, 0), Vector3(-0.7, 0, 0))
	r.add_shape(lower, Models.lathe([0.026 * scale, -b, 0.034 * scale, -b * 0.5, 0.044 * scale, 0.0], 8), limb.lightened(0.15), NONE, NONE, ONE, 0.3)
	r.add_shape(lower, Models.torus(0.028 * scale, 0.06 * scale, 10, 4), joint, Vector3(0, -b, 0), NONE, ONE, 0.9)
	var flen: float = 0.24 * scale
	for i: int in fingers:
		var t: float = (float(i) / float(fingers - 1)) * 2.0 - 1.0
		var spread: float = 0.2 * scale * t
		var curl: float = 0.09 * scale * (1.0 - absf(t))
		r.add_shape(lower, Models.tube([0, -b, 0, spread * 0.5, -b - flen * 0.5, curl, spread, -b - flen, curl * 0.4], [0.026 * scale, 0.02 * scale, 0.0], 4), joint, NONE, NONE, ONE, 0.8)
	r.add_shape(lower, Models.ball(0.048 * scale, 8, 4), hot, Vector3(0, -b - flen - 0.08 * scale, 0), NONE, ONE, 2.4)


## A drop that hangs without falling inside perfectly level rings, over ripples frozen in
## place. Nothing on it moves: no bob, no spin, no lean.
static func _stillness(r: ModelRig, level: int) -> float:
	r.stride_speed = 2.0
	r.bob = 0.0
	r.step_bob = 0.0
	r.lean = 0.0
	r.swing = 0.0
	r.strike_lunge = 0.1
	var ice := Color(0.72, 0.88, 1.0)
	var deep := Color(0.3, 0.5, 0.85)
	var hot := Color(0.96, 0.98, 1.0)
	r.add_part("body", "root", Vector3(0, 0.5, 0))
	r.add_shape("body", Models.lathe([0.0, -0.2, 0.09, -0.15, 0.14, -0.05, 0.13, 0.06, 0.07, 0.2, 0.02, 0.32, 0.0, 0.38], 16), ice, NONE, NONE, ONE, 0.5)
	r.add_shape("body", Models.torus(0.3, 0.322, 28, 5), hot, NONE, NONE, Vector3(1.0, 0.35, 1.0), 1.0)
	var ripples: Array = [0.2, 0.36]
	if level >= 2:
		ripples.append(0.5)
	for rad: float in ripples:
		r.add_shape("body", Models.torus(rad - 0.012, rad + 0.012, 28, 4), deep, Vector3(0, -0.475, 0), NONE, Vector3(1.0, 0.4, 1.0), 0.6)
	if level >= 1:
		r.add_shape("body", Models.torus(0.4, 0.42, 32, 4), ice, Vector3(0, 0.0, 0), NONE, Vector3(1.0, 0.35, 1.0), 0.8)
		r.add_shape("body", Models.cyl(0.006, 0.006, 0.26, 4), hot, Vector3(0, -0.33, 0), NONE, ONE, 1.2)
		r.add_shape("body", Models.lathe([0.0, -0.035, 0.025, 0.0, 0.0, 0.035], 4), hot, Vector3(0, -0.43, 0), NONE, ONE, 1.6, 0.0, true)
		var orbs: int = 4 if level == 1 else 8
		for i: int in orbs:
			var a: float = TAU * float(i) / float(orbs)
			var rad: float = 0.307 if i % 2 == 0 else 0.41
			r.add_shape("body", Models.ball(0.035, 8, 4), hot, Vector3(cos(a) * rad, 0.0, sin(a) * rad), NONE, ONE, 1.6)
	if level >= 2:
		r.add_shape("body", Models.cyl(0.006, 0.006, 0.1, 4), hot, Vector3(0, 0.4, 0), NONE, ONE, 1.2)
		r.add_shape("body", Models.lathe([0.0, -0.04, 0.03, 0.0, 0.0, 0.04], 4), hot, Vector3(0, 0.455, 0), NONE, ONE, 1.6, 0.0, true)
		r.add_shape("body", Models.torus(0.14, 0.152, 20, 4), ice, Vector3(0, 0.3, 0), NONE, Vector3(1.0, 0.35, 1.0), 0.8)
	return 0.34 if level == 0 else (0.43 if level == 1 else 0.5)


## Unknown concepts: a plain floating crystal with a ring.
static func _generic(r: ModelRig, level: int) -> float:
	r.bob = 0.04
	r.strike_lunge = 0.2
	var body := Color(0.6, 0.6, 0.95)
	r.add_part("body", "root", Vector3(0, 0.5, 0))
	r.add_shape("body", Models.lathe([0.0, -0.36, 0.2, 0.0, 0.0, 0.36], 4), body, NONE, NONE, ONE, 0.5, 0.0, true)
	r.add_part("ring", "body", NONE, Vector3(0.4, 0, 0))
	for i: int in level + 1:
		var rad: float = 0.28 + 0.07 * float(i)
		r.add_shape("ring", Models.torus(rad, rad + 0.025, 20, 4), Color(0.9, 0.9, 1.0), NONE, Vector3(0, 0, 25.0 * float(i)), ONE, 1.0)
	r.spin_parts["ring"] = Vector3(0, 1.2, 0)
	return 0.35
