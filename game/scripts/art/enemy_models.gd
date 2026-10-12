class_name EnemyModels
extends RefCounted
## The newer realm invaders, built like the pass-4 hero (smooth lofted bodies, hard edges
## only on armour): the Rampart Archer and the Harrier. Called from Models._build_enemy.

const NONE := Vector3.ZERO
const ONE := Vector3.ONE
const K_LEATHER := ModelRig.LEATHER_KIND
const K_METAL := ModelRig.METAL
const K_SKIN := ModelRig.SKIN
const K_HAIR := ModelRig.HAIR


static func _loft(rows: Array, sides: int = 16, detail: int = 3, ripple_n: int = 0, from_deg: float = 0.0, to_deg: float = 360.0) -> ArrayMesh:
	return MeshKit.loft(MeshKit.refine(rows, detail), sides, ripple_n, from_deg, to_deg)


## Rampart Archer: a slight, upright figure in a short hood and veil, a quiver high on the
## back and a bow as tall as itself held out in the left hand. Its wind-up is the draw: it
## turns side-on, the bow arm goes out straight, the string comes back to the cheek with an
## arrow on it.
static func archer(r: ModelRig, color: Color) -> void:
	r.stride_rate = 3.6
	r.swing = 0.6
	r.step_bob = 0.04
	r.lean = 0.1
	r.raise_arm = 1.35
	r.raise_forearm = 1.75
	r.strike_arm = 0.9
	r.strike_forearm = 1.2
	var hide: Color = Models.grim(color, 0.55, 0.8)
	var hide_d: Color = Models.grim(color, 0.45, 0.5)
	var hood: Color = Models.grim(color, 0.4, 0.42).lerp(Color(0.14, 0.17, 0.13), 0.5)
	var cloth := Color(0.13, 0.12, 0.12)
	var wrap := Color(0.5, 0.46, 0.37)
	var flesh := Color(0.33, 0.3, 0.29)
	var bone: Color = Models.BONE
	var leather: Color = Models.LEATHER
	var wood := Color(0.2, 0.13, 0.08)
	var eye := Color(1.0, 0.72, 0.2)

	for side: int in [-1, 1]:
		var n: String = "left" if side < 0 else "right"
		var leg: String = "leg_" + n
		var shin: String = "shin_" + n
		r.add_part(leg, "", Vector3(0.085 * side, 0.8, 0.0))
		r.add_shape(leg, _loft([[-0.42, 0.05, 0.054, 0.052], [-0.36, 0.056, 0.06, 0.056], [-0.18, 0.07, 0.072, 0.076], [-0.03, 0.078, 0.08, 0.086], [0.06, 0.066, 0.07, 0.078]], 14, 3), cloth)
		r.add_part(shin, leg, Vector3(0, -0.4, 0))
		r.add_shape(shin, _loft([[-0.37, 0.04, 0.042, 0.046], [-0.26, 0.046, 0.044, 0.058], [-0.12, 0.052, 0.048, 0.064], [0.03, 0.05, 0.052, 0.052]], 14, 3), cloth)
		var bind: Array = []
		var bind_r: Array = []
		for i: int in 31:
			var t: float = float(i) / 30.0
			var a: float = t * TAU * 4.0
			var rad: float = lerpf(0.048, 0.058, sin(t * PI))
			bind.append_array([cos(a) * rad, lerpf(-0.36, -0.12, t), sin(a) * rad + 0.004])
			bind_r.append(0.012)
		r.add_shape(shin, Models.tube(bind, bind_r, 4, 0.3, Vector3.UP), wrap)
		r.add_shape(shin, _loft([[-0.052, 0.018, 0.018, 0.018, 0, 0, 0.3], [-0.04, 0.034, 0.026, 0.034, 0, 0, 0.3], [0.03, 0.04, 0.028, 0.044, 0, 0, 0.3], [0.1, 0.042, 0.027, 0.028, 0, 0, 0.3], [0.16, 0.034, 0.024, 0.016, 0, 0, 0.3], [0.185, 0.014, 0.016, 0.01]], 12, 2), leather, Vector3(0, -0.372, 0), Vector3(-90, 0, 0), ONE, 0.0, 0.0, false, K_LEATHER)

	r.add_part("body", "", Vector3(0, 0.8, 0))
	r.add_shape("body", _loft([[-0.11, 0.08, 0.066, 0.076], [-0.04, 0.13, 0.086, 0.098], [0.05, 0.136, 0.088, 0.1], [0.14, 0.124, 0.082, 0.09]], 18, 3), cloth)
	r.add_shape("body", MeshKit.loft([[0.07, 0.136, 0.092, 0.1], [0.09, 0.14, 0.095, 0.103], [0.125, 0.14, 0.095, 0.103], [0.14, 0.134, 0.09, 0.098]], 20), leather, NONE, NONE, ONE, 0.0, 0.0, false, K_LEATHER)
	r.add_shape("body", Models.bbox(0.045, 0.05, 0.012, 0.005), bone, Vector3(0, 0.105, -0.098), NONE, ONE, 0.0, 0.3, true)
	r.add_shape("body", Models.bbox(0.07, 0.11, 0.045, 0.016, 0.9, 0.9), leather.lightened(0.1), Vector3(-0.135, 0.02, -0.02), Vector3(0, 0, 6), ONE, 0.0, 0.0, false, K_LEATHER)

	# Jerkin: lean, laced at the front, with a ragged skirt and a short shoulder cape.
	var trunk: Array = [[-0.06, 0.128, 0.086, 0.092, 0, 0, 0.15, 0.02], [0.03, 0.12, 0.08, 0.088, 0, 0, 0.15], [0.14, 0.14, 0.094, 0.098, 0, 0, 0.2], [0.24, 0.158, 0.098, 0.1, 0, 0, 0.2], [0.31, 0.162, 0.088, 0.094, 0, 0, 0.15], [0.35, 0.11, 0.066, 0.078], [0.38, 0.06, 0.05, 0.056]]
	r.add_part("torso", "body", Vector3(0, 0.12, 0))
	r.add_shape("torso", _loft(trunk, 22, 3, 11), hide, NONE, NONE, ONE, 0.0, 0.0, false, K_LEATHER)
	r.add_shape("torso", _loft([[-0.2, 0.158, 0.106, 0.118, 0, 0, 0.1, 0.07], [-0.13, 0.146, 0.098, 0.108, 0, 0, 0.1, 0.04], [-0.05, 0.13, 0.088, 0.094, 0, 0, 0.15, 0.02]], 22, 2, 9, -62.0, 242.0), hide_d, NONE, NONE, ONE, 0.0, 0.0, false, K_LEATHER)
	for y: float in [0.06, 0.13, 0.2, 0.27]:
		r.add_shape("torso", Models.bbox(0.07, 0.01, 0.012, 0.003), wrap, Vector3(0, y, -0.094 - 0.012 * sin((y + 0.06) * 6.0)), Vector3(0, 0, 22 if int(y * 100.0) % 2 == 0 else -22))
	r.add_shape("torso", _loft([[0.34, 0.05, 0.046, 0.05], [0.44, 0.044, 0.042, 0.046]], 12, 2), flesh, NONE, NONE, ONE, 0.0, 0.0, false, K_SKIN)
	# Baldric and the quiver it carries: the thing to recognise it by from behind.
	var strap: Array = []
	var strap_r: Array = []
	for i: int in 25:
		var a: float = TAU * float(i) / 24.0
		var x: float = cos(a) * 0.15
		strap.append_array([x, 0.17 + x * 0.95, sin(a) * 0.106])
		strap_r.append(0.02)
	r.add_shape("torso", Models.tube(strap, strap_r, 5, 0.3, Vector3.UP), leather, NONE, NONE, ONE, 0.0, 0.0, false, K_LEATHER)
	var quiver := Vector3(0.05, 0.2, 0.135)
	var tilt := Vector3(-8, 0, -24)
	r.add_shape("torso", Models.lathe([0.045, -0.24, 0.058, -0.2, 0.06, 0.16, 0.066, 0.18, 0.06, 0.2], 10), leather.lightened(0.06), quiver, tilt, ONE, 0.0, 0.0, false, K_LEATHER)
	r.add_shape("torso", Models.lathe([0.062, 0.1, 0.07, 0.12, 0.062, 0.14], 10), bone.darkened(0.25), quiver, tilt, ONE, 0.0, 0.3)
	var q_basis := Basis.from_euler(Vector3(deg_to_rad(tilt.x), 0, deg_to_rad(tilt.z)))
	for i: int in 6:
		var a: float = TAU * float(i) / 6.0
		var off := Vector3(cos(a) * 0.028, 0.0, sin(a) * 0.028)
		var foot: Vector3 = quiver + q_basis * (off + Vector3(0, 0.15, 0))
		var top: Vector3 = quiver + q_basis * (off * 1.5 + Vector3(0, 0.36 + 0.03 * float(i % 3), 0))
		r.add_shape("torso", Models.tube([foot.x, foot.y, foot.z, top.x, top.y, top.z], [0.006, 0.006], 3), wood)
		r.add_shape("torso", Models.bbox(0.05, 0.085, 0.006, 0.002), [bone, wrap, Color(0.5, 0.2, 0.14)][i % 3], top - q_basis * Vector3(0, 0.045, 0), Vector3(tilt.x, 60.0 * float(i), tilt.z))
	r.add_part("cape", "torso", Vector3(0, 0.36, 0.07), Vector3(-0.2, 0, 0))
	r.add_shape("cape", _loft([[-0.2, 0.2, 0.02, 0.14, 0, 0, 0, 0.1], [-0.1, 0.19, 0.02, 0.125, 0, 0, 0, 0.06], [0.0, 0.15, 0.02, 0.09], [0.03, 0.08, 0.02, 0.06]], 16, 2, 9, 10.0, 170.0), hood)
	r.sway_parts["cape"] = -0.5

	# Head: a close hood with a short peak, a veil over the lower face, two eye glints.
	r.add_part("head", "torso", Vector3(0, 0.44, 0))
	r.add_shape("head", Models.ball(0.098, 14, 7), flesh, Vector3(0, 0.1, 0.0), NONE, Vector3(0.9, 1.1, 1.0), 0.0, 0.0, false, K_SKIN)
	r.add_shape("head", _loft([[-0.03, 0.105, 0.085, 0.1], [0.04, 0.112, 0.1, 0.116], [0.12, 0.112, 0.108, 0.12], [0.19, 0.086, 0.09, 0.1], [0.225, 0.03, 0.03, 0.05, 0, 0.03]], 16, 3), hood)
	r.add_shape("head", Models.ball(0.085, 12, 6), Color(0.04, 0.035, 0.035), Vector3(0, 0.105, -0.045))
	r.add_shape("head", _loft([[0.015, 0.07, 0.085, 0.02], [0.06, 0.082, 0.1, 0.02], [0.092, 0.08, 0.1, 0.02]], 12, 2), wrap.darkened(0.25), Vector3(0, 0, -0.012))
	r.add_shape("head", Models.tube([-0.09, 0.2, -0.07, 0.0, 0.215, -0.135, 0.09, 0.2, -0.07], [0.02, 0.026, 0.02], 5, 0.4, Vector3.RIGHT), hood.lightened(0.08))
	for side: int in [-1, 1]:
		r.add_shape("head", Models.ball(0.014, 6, 3), eye, Vector3(0.036 * side, 0.118, -0.103), NONE, Vector3(1.3, 0.7, 0.6), 1.8)
	r.add_shape("head", Models.tube([0, 0.22, 0.05, 0, 0.15, 0.13, 0, 0.02, 0.15, 0, -0.08, 0.13], [0.03, 0.05, 0.04, 0.0], 6, 0.5, Vector3.RIGHT), hood.darkened(0.1))

	for side: int in [-1, 1]:
		var n: String = "left" if side < 0 else "right"
		var arm: String = "arm_" + n
		var fore: String = "forearm_" + n
		r.add_part(arm, "torso", Vector3(0.18 * side, 0.32, 0), Vector3(0.3 if side < 0 else 0.1, 0, 0.1 * side))
		r.add_shape(arm, _loft([[-0.27, 0.04, 0.042, 0.042], [-0.16, 0.046, 0.046, 0.05], [-0.05, 0.054, 0.052, 0.056], [0.01, 0.05, 0.05, 0.052], [0.035, 0.016, 0.02, 0.02]], 14, 3), hide_d, NONE, NONE, ONE, 0.0, 0.0, false, K_LEATHER)
		r.add_part(fore, arm, Vector3(0, -0.26, 0), Vector3(0.5 if side < 0 else 0.3, 0, 0))
		r.add_shape(fore, _loft([[-0.25, 0.026, 0.03, 0.03], [-0.15, 0.034, 0.036, 0.036], [-0.04, 0.04, 0.042, 0.042], [0.02, 0.038, 0.04, 0.04]], 12, 3), flesh, NONE, NONE, ONE, 0.0, 0.0, false, K_SKIN)
		# A bracer on the bow arm, a tab-wrapped drawing hand.
		r.add_shape(fore, _loft([[-0.2, 0.034, 0.038, 0.038], [-0.06, 0.044, 0.046, 0.046]], 12, 1), leather if side < 0 else wrap, NONE, NONE, ONE, 0.0, 0.0, false, K_LEATHER if side < 0 else 0)
		r.add_shape(fore, _loft([[-0.33, 0.014, 0.03, 0.03, 0, 0, 0.3], [-0.3, 0.018, 0.034, 0.034, 0, 0, 0.3], [-0.26, 0.018, 0.028, 0.028, 0, 0, 0.2]], 10, 2), flesh, NONE, NONE, ONE, 0.0, 0.0, false, K_SKIN)
		for k: int in 3:
			var z: float = -0.02 + 0.02 * float(k)
			r.add_shape(fore, Models.tube([0, -0.325, z, -0.012 * side, -0.35, z, -0.028 * side, -0.36, z], [0.008, 0.008, 0.006], 5), flesh, NONE, NONE, ONE, 0.0, 0.0, false, K_SKIN)

	# The bow rides in the left hand, its length along the forearm's Z so that it stands
	# upright when the arm is levelled. A slack string normally; the drawn string and a
	# nocked arrow are swapped in for the wind-up.
	var grip := Vector3(0.0, -0.3, 0.0)
	var bow_r: float = 0.92
	var half: float = 49.0
	var tip_y: float = bow_r * (1.0 - cos(deg_to_rad(half)))
	var tip_z: float = bow_r * sin(deg_to_rad(half))
	r.add_part("bow", "forearm_left", grip)
	r.add_shape("bow", MeshKit.arc(bow_r, 0.024, -half, half, 16, 6, 0.4), wood, Vector3(0, bow_r, 0), Vector3(0, -90, -90), ONE, 0.0, 0.2)
	r.add_shape("bow", Models.lathe([0.026, -0.07, 0.03, 0.0, 0.026, 0.07], 8), leather, NONE, Vector3(90, 0, 0), ONE, 0.0, 0.0, false, K_LEATHER)
	for end: int in [-1, 1]:
		r.add_shape("bow", Models.ball(0.022, 6, 3), bone, Vector3(0, tip_y, tip_z * end), NONE, Vector3(1, 1, 1.6), 0.0, 0.3)
	r.add_part("bow_string", "bow")
	r.add_shape("bow_string", Models.tube([0, tip_y, -tip_z, 0, tip_y, tip_z], [0.005, 0.005], 3), bone)
	r.add_part("bow_drawn", "bow")
	var nock := Vector3(0, 0.62, 0)
	r.add_shape("bow_drawn", Models.tube([0, tip_y, -tip_z, nock.x, nock.y, nock.z, 0, tip_y, tip_z], [0.005, 0.005, 0.005], 3), bone)
	r.add_shape("bow_drawn", Models.tube([0, nock.y, 0, 0, -0.16, 0], [0.008, 0.008], 4), wood.lightened(0.2))
	r.add_shape("bow_drawn", Models.cyl(0.026, 0.0, 0.09, 4), Models.STEEL.lightened(0.2), Vector3(0, -0.2, 0), NONE, Vector3(1, 1, 0.4), 0.0, 1.0, true, K_METAL)
	r.add_shape("bow_drawn", Models.bbox(0.05, 0.1, 0.006, 0.002), bone, Vector3(0, nock.y - 0.07, 0))
	r.add_shape("bow_drawn", Models.bbox(0.006, 0.1, 0.05, 0.002), Color(0.5, 0.2, 0.14), Vector3(0, nock.y - 0.07, 0))
	r.get_part("bow_drawn").visible = false

	# The draw: side-on to the target, bow arm straight out, drawing elbow high and back.
	r.windup_pose = {
		"body": Vector3(0, -0.95, 0), "torso": Vector3(0.0, -0.3, 0), "head": Vector3(0, 0.95, 0),
		"arm_left": Vector3(1.25, 1.5, 0.1), "forearm_left": Vector3(-0.5, 0, 0),
		"arm_right": Vector3(0.0, 1.25, 0.25),
	}
	# The release: still side-on with the bow arm out, the drawing hand thrown back.
	r.strike_arm = 0.4
	r.strike_forearm = 0.6
	r.strike_pose = {
		"body": Vector3(0.28 * 0.5, -0.95 - 0.2, 0), "torso": Vector3(0.14, -0.6, 0), "head": Vector3(-0.14, 1.3, 0),
		"arm_left": Vector3(1.25 + 0.5, 1.5, 0.1), "forearm_left": Vector3(-1.0, 0, 0),
		"arm_right": Vector3(0.0, -0.6, 0.5),
	}
	r.windup_show = ["bow_drawn"]
	r.windup_hide = ["bow_string"]
	r.stagger_tilt = Vector3(0.3, 0, 0.25)
	r.stagger_drop = 0.1


## Harrier: built to run. A long body carried almost level, digitigrade legs, arms as long as
## the legs ending in iron claws, a narrow beaked mask thrust forward and a mane of rag
## streaming behind. Its wind-up is a deep crouch - haunches down, arms swept back, head low.
static func harrier(r: ModelRig, color: Color) -> void:
	r.stride_rate = 1.5
	r.swing = 0.95
	r.step_bob = 0.06
	r.bob = 0.02
	r.lean = 0.25
	r.strike_both_arms = true
	r.raise_arm = -1.3
	r.raise_forearm = 0.9
	r.strike_arm = 2.2
	r.strike_forearm = 0.15
	r.strike_lunge = 0.25
	var hide: Color = Models.grim(color, 0.6, 0.95)
	var hide_d: Color = Models.grim(color, 0.5, 0.6)
	var hide_l: Color = Models.grim(color, 0.45, 1.25)
	var rag := Color(0.3, 0.09, 0.08)
	var bone: Color = Models.BONE
	var iron: Color = Models.IRON.lightened(0.12)
	var eye := Color(1.0, 0.35, 0.12)

	# Legs: thigh forward, long shin back, standing on the toes.
	for side: int in [-1, 1]:
		var n: String = "left" if side < 0 else "right"
		var leg: String = "leg_" + n
		var shin: String = "shin_" + n
		r.add_part(leg, "", Vector3(0.11 * side, 0.74, 0.12), Vector3(0.75, 0, 0))
		r.add_shape(leg, _loft([[-0.46, 0.04, 0.045, 0.045], [-0.34, 0.05, 0.052, 0.06], [-0.16, 0.07, 0.07, 0.085], [-0.02, 0.078, 0.08, 0.09], [0.06, 0.05, 0.06, 0.07]], 12, 3), hide, NONE, NONE, ONE, 0.0, 0.0, false, K_SKIN)
		r.add_part(shin, leg, Vector3(0, -0.44, 0), Vector3(-1.5, 0, 0))
		r.add_shape(shin, _loft([[-0.5, 0.024, 0.026, 0.03], [-0.36, 0.03, 0.03, 0.04], [-0.16, 0.042, 0.04, 0.058], [0.02, 0.042, 0.046, 0.046]], 12, 3), hide_d, NONE, NONE, ONE, 0.0, 0.0, false, K_SKIN)
		r.add_shape(shin, MeshKit.loft([[-0.4, 0.032, 0.032, 0.042], [-0.3, 0.036, 0.034, 0.048]], 10), bone.darkened(0.35))
		# Hock and a long clawed foot angled back down to the ground.
		r.add_shape(shin, _loft([[-0.02, 0.02, 0.02, 0.02, 0, 0, 0.3], [0.04, 0.034, 0.022, 0.03, 0, 0, 0.3], [0.16, 0.04, 0.02, 0.022, 0, 0, 0.3], [0.24, 0.03, 0.016, 0.014, 0, 0, 0.3]], 10, 2), hide_d, Vector3(0, -0.5, 0.0), Vector3(-158, 0, 0), ONE, 0.0, 0.0, false, K_SKIN)
		for k: int in 3:
			r.add_shape(shin, Models.cyl(0.0, 0.014, 0.09, 4), iron, Vector3(-0.022 + 0.022 * float(k), -0.6, -0.235), Vector3(-122, 0, 0), ONE, 0.0, 0.8, true, K_METAL)

	# Body: hips high at the back, spine running forward and down to a deep chest.
	r.add_part("body", "", Vector3(0, 0.76, 0.14), Vector3(-1.05, 0, 0))
	r.add_shape("body", _loft([[-0.12, 0.07, 0.07, 0.08], [-0.02, 0.105, 0.085, 0.11], [0.1, 0.1, 0.08, 0.1], [0.24, 0.085, 0.07, 0.09]], 16, 3), hide_d, NONE, NONE, ONE, 0.0, 0.0, false, K_SKIN)
	r.add_shape("body", MeshKit.loft([[0.02, 0.108, 0.088, 0.112], [0.07, 0.108, 0.088, 0.112]], 16), Models.LEATHER, NONE, NONE, ONE, 0.0, 0.0, false, K_LEATHER)
	r.add_shape("body", MeshKit.sheet(0.14, 0.08, 0.4, 1.5, 0.015, 0.03, 0.06, 5, 5), rag, Vector3(0, 0.02, 0.1), Vector3(60, 0, 0))
	r.add_part("torso", "body", Vector3(0, 0.22, 0), Vector3(-0.15, 0, 0))
	var chest: Array = [[-0.04, 0.085, 0.07, 0.09], [0.1, 0.1, 0.1, 0.1, 0, 0, 0.1], [0.24, 0.13, 0.13, 0.105, 0, -0.01, 0.15], [0.36, 0.14, 0.12, 0.1, 0, -0.01, 0.15], [0.44, 0.1, 0.08, 0.085], [0.5, 0.05, 0.05, 0.056]]
	r.add_shape("torso", _loft(chest, 18, 3), hide, NONE, NONE, ONE, 0.0, 0.0, false, K_SKIN)
	# Ribs showing along the flanks, a ridge of bone studs down the spine (its back is bare).
	for side: int in [-1, 1]:
		for k: int in 4:
			var y: float = 0.14 + 0.07 * float(k)
			r.add_shape("torso", Models.tube([0.03 * side, y + 0.02, 0.1, 0.12 * side, y, 0.03, 0.115 * side, y - 0.03, -0.06, 0.05 * side, y - 0.05, -0.115], [0.008, 0.012, 0.012, 0.006], 4), hide_l.lerp(hide, 0.4), NONE, NONE, ONE, 0.0, 0.0, false, K_SKIN)
	for k: int in 6:
		var y: float = 0.02 + 0.08 * float(k)
		r.add_shape("torso", Models.cyl(0.0, 0.022, 0.07 + 0.01 * float(k % 2), 5), bone.darkened(0.15), Vector3(0, y, 0.1 + 0.012 * sin(float(k))), Vector3(70, 0, 0), ONE, 0.0, 0.3, true)
	# Shoulder guards of banded iron over the front of the shoulders only.
	for side: int in [-1, 1]:
		r.add_shape("torso", Models.lathe([0.08, -0.03, 0.078, 0.02, 0.05, 0.06, 0.0, 0.07], 8), iron, Vector3(0.14 * side, 0.4, -0.03), Vector3(-30, 0, -40 * side), Vector3(1, 1, 1.2), 0.0, 0.8, true, K_METAL)
		r.add_shape("torso", Models.lathe([0.082, -0.04, 0.088, -0.03, 0.082, -0.02], 8), bone.darkened(0.3), Vector3(0.14 * side, 0.4, -0.03), Vector3(-30, 0, -40 * side), Vector3(1, 1, 1.2), 0.0, 0.3, true)

	# Neck and head carried level, looking where it is going.
	r.add_part("head", "torso", Vector3(0, 0.48, -0.01), Vector3(1.0, 0, 0))
	r.add_shape("head", _loft([[-0.06, 0.05, 0.05, 0.056], [0.06, 0.046, 0.046, 0.05]], 10, 2), hide_d, Vector3(0, 0, 0.02), Vector3(-28, 0, 0), ONE, 0.0, 0.0, false, K_SKIN)
	r.add_shape("head", Models.ball(0.095, 12, 6), hide_d, Vector3(0, 0.12, -0.03), NONE, Vector3(0.85, 0.9, 1.15), 0.0, 0.0, false, K_SKIN)
	# A long bone mask like a beak, eye slits burning in it, bound on with a strap.
	r.add_shape("head", _loft([[0.0, 0.07, 0.022, 0.05, 0, 0, 0.2], [0.1, 0.066, 0.03, 0.05, 0, 0, 0.2], [0.2, 0.04, 0.028, 0.034, 0, 0, 0.2], [0.3, 0.012, 0.012, 0.012]], 10, 3), bone, Vector3(0, 0.15, -0.07), Vector3(-104, 0, 0), ONE, 0.0, 0.3)
	r.add_shape("head", Models.tube([0, 0.19, -0.08, 0, 0.165, -0.2, 0, 0.11, -0.34], [0.012, 0.012, 0.004], 4), bone.darkened(0.25), NONE, NONE, ONE, 0.0, 0.3)
	for side: int in [-1, 1]:
		r.add_shape("head", Models.bbox(0.012, 0.024, 0.06, 0.004), eye, Vector3(0.058 * side, 0.15, -0.15), Vector3(0, -12 * side, 14 * side), ONE, 1.8)
		r.add_shape("head", Models.tube([0.06 * side, 0.14, -0.08, 0.09 * side, 0.13, 0.0, 0.05 * side, 0.12, 0.07], [0.012, 0.012, 0.012], 4, 0.4), Models.LEATHER, NONE, NONE, ONE, 0.0, 0.0, false, K_LEATHER)
		r.add_shape("head", Models.cyl(0.0, 0.03, 0.14, 5), hide_d, Vector3(0.085 * side, 0.2, 0.03), Vector3(40, 0, -30 * side), ONE, 0.0, 0.0, false, K_SKIN)
	# Mane: a crest of rag strips from the crown down the neck; it streams when it runs.
	r.add_part("mane", "head", Vector3(0, 0.19, 0.05), Vector3(-0.5, 0, 0))
	for k: int in 5:
		var x: float = -0.05 + 0.025 * float(k)
		var l: float = 0.5 - 0.06 * absf(float(k) - 2.0)
		r.add_shape("mane", Models.tube([x, 0.0, 0.0, x * 1.4, 0.02, l * 0.45, x * 1.2, -0.04, l * 0.8, x, -0.1, l], [0.03, 0.036, 0.03, 0.0], 4, 0.3, Vector3.RIGHT), rag if k % 2 == 0 else rag.darkened(0.3))
	r.sway_parts["mane"] = 0.5

	# Arms as long as the legs, hanging forward to the ground, three iron claws each.
	for side: int in [-1, 1]:
		var n: String = "left" if side < 0 else "right"
		var arm: String = "arm_" + n
		var fore: String = "forearm_" + n
		r.add_part(arm, "torso", Vector3(0.15 * side, 0.38, -0.02), Vector3(1.0, 0, 0.12 * side))
		r.add_shape(arm, _loft([[-0.44, 0.034, 0.036, 0.036], [-0.3, 0.042, 0.044, 0.05], [-0.12, 0.054, 0.052, 0.06], [0.0, 0.056, 0.054, 0.058], [0.04, 0.02, 0.02, 0.02]], 12, 3), hide, NONE, NONE, ONE, 0.0, 0.0, false, K_SKIN)
		r.add_part(fore, arm, Vector3(0, -0.42, 0), Vector3(0.45, 0, 0))
		r.add_shape(fore, _loft([[-0.44, 0.024, 0.026, 0.026], [-0.3, 0.032, 0.032, 0.036], [-0.1, 0.04, 0.04, 0.044], [0.02, 0.036, 0.038, 0.038]], 12, 3), hide_d, NONE, NONE, ONE, 0.0, 0.0, false, K_SKIN)
		r.add_shape(fore, MeshKit.loft([[-0.36, 0.034, 0.036, 0.04], [-0.14, 0.046, 0.046, 0.05]], 8), iron, NONE, NONE, ONE, 0.0, 0.8, true, K_METAL)
		r.add_shape(fore, _loft([[-0.52, 0.014, 0.03, 0.03, 0, 0, 0.3], [-0.48, 0.02, 0.036, 0.036, 0, 0, 0.3], [-0.43, 0.02, 0.028, 0.028, 0, 0, 0.2]], 8, 2), hide_d, NONE, NONE, ONE, 0.0, 0.0, false, K_SKIN)
		for k: int in 3:
			var z: float = -0.024 + 0.024 * float(k)
			r.add_shape(fore, Models.tube([0, -0.5, z, 0.0, -0.6, z - 0.02, 0.0, -0.7, z - 0.06], [0.012, 0.011, 0.0], 4, 0.5), Models.STEEL, NONE, NONE, ONE, 0.0, 1.0, true, K_METAL)

	# The crouch: haunches down, legs folded, arms swept back along the flanks, head low.
	r.windup_pose = {
		"leg_left": Vector3(0.55, 0, 0), "leg_right": Vector3(0.55, 0, 0),
		"shin_left": Vector3(-0.75, 0, 0), "shin_right": Vector3(-0.75, 0, 0),
		"body": Vector3(-0.2, 0, 0), "head": Vector3(0.3, 0, 0),
	}
	r.windup_drop = 0.3
	# Knocked down: over on its side, limbs loose.
	r.stagger_tilt = Vector3(0.2, 0, 1.25)
	r.stagger_drop = 0.5
