class_name CreatureModels
extends RefCounted
## The unstarred beasts of the Stubble (design/07 5.4 and Brent's 2026-10-19 ruling), as
## procedural STAND-INS on a CreatureRig: there is no creature rig source yet, so each is built
## from MeshKit shapes (grounded, muted, readable from the game camera) and animated by hand.
## Each has a silhouette of its own and a wind-up pose of its own; each is fought from every
## side, so backs are designed too. All designs are original to this project.
##
##   var rig: CreatureRig = CreatureModels.make("thornback")
##
## Kinds are chosen by enemies.json "creature" (a builder name). Built once per kind and
## stamped out after (CreatureRig.stamp).

const NONE := Vector3.ZERO
const ONE := Vector3.ONE
const K_SKIN := ModelRig.SKIN
const K_LEATHER := ModelRig.LEATHER_KIND
const K_HAIR := ModelRig.HAIR
const K_METAL := ModelRig.METAL

const BONE := Color(0.66, 0.6, 0.48)
const HORN := Color(0.3, 0.26, 0.2)
const HOOF := Color(0.12, 0.1, 0.09)
const EYE_DIM := Color(0.08, 0.06, 0.05)

static var _snaps: Dictionary = {}


## A fresh rig for an enemies.json kind that names a "creature" builder; null if it names none.
static func make(kind: String) -> CreatureRig:
	var def: Dictionary = GameData.enemy(kind)
	var builder: String = str(def.get("creature", ""))
	if builder == "":
		return null
	var key: String = "creature:" + kind
	if _snaps.has(key):
		return CreatureRig.stamp(_snaps[key])
	var rig := CreatureRig.new()
	rig.name = "Creature_" + kind
	rig.radius = float(def.get("radius", 0.5))
	rig.height = float(def.get("height", 1.0))
	rig.stride_speed = float(def.get("speed", 3.0))
	var rgb: Array = def.get("color", [0.5, 0.45, 0.4])
	# the field's light is strong and the solid shader lifts flat colour: start a quarter darker,
	# so a beast reads as hide against the straw rather than as a pale toy
	var color := Color(float(rgb[0]), float(rgb[1]), float(rgb[2])).darkened(0.28)
	match builder:
		"gleaner":
			_gleaner(rig, color)
		"sod_lurker":
			_sod_lurker(rig, color)
		"thornback":
			_thornback(rig, color)
		"ditch_hound":
			_ditch_hound(rig, color)
		"burr_hog":
			_burr_hog(rig, color)
		"wirehorn":
			_wirehorn(rig, color)
		"kettle_beetle":
			_kettle_beetle(rig, color)
		"chaff_wren":
			_chaff_wren(rig, color)
		_:
			_ditch_hound(rig, color)
	rig.finish()
	_snaps[key] = rig.creature_snapshot()
	return rig


## Every builder name (for the art preview and the self-test).
static func builders() -> Array[String]:
	return ["gleaner", "sod_lurker", "thornback", "ditch_hound", "burr_hog", "wirehorn", "kettle_beetle", "chaff_wren"]


# ---------------------------------------------------------------- shared pieces

## A loft laid along the body: rows are [along, half-width, belly depth, back height, ...] from the
## rump (negative) to the chest (positive), turned so "along" points forward (-Z).
static func _trunk(rows: Array, sides: int = 16, detail: int = 3) -> ArrayMesh:
	return MeshKit.loft(MeshKit.refine(rows, detail), sides)


const TRUNK_ROT := Vector3(-90, 0, 0)


## A leg pair of parts under "body": the upper from the hip / shoulder pivot to the knee, the lower
## from the knee to the ground. `ground` is how far below the pivot the foot stands.
static func _leg(r: CreatureRig, id: String, pivot: Vector3, ground: float, thick: float, color: Color, foot: Color,
		phase: float, knee: float, bend: float = 0.06, kind: int = K_SKIN, foot_r: float = -1.0) -> void:
	var up: String = "leg_" + id
	var lo: String = "shin_" + id
	var l1: float = ground * 0.52
	var l2: float = ground - l1
	r.add_part(up, "body", pivot)
	r.add_shape(up, Models.tube([0, 0.03, 0, 0, -l1 * 0.5, bend * knee * 0.5, 0, -l1, bend * knee], [thick * 1.25, thick * 1.0, thick * 0.8], 7), color, NONE, NONE, ONE, 0.0, 0.0, false, kind)
	r.add_part(lo, up, Vector3(0, -l1, bend * knee))
	r.add_shape(lo, Models.tube([0, 0, 0, 0, -l2 * 0.55, -bend * knee * 0.6, 0, -l2 + 0.02, -bend * knee * 0.2], [thick * 0.8, thick * 0.6, thick * 0.5], 6), color.darkened(0.12), NONE, NONE, ONE, 0.0, 0.0, false, kind)
	var fr: float = foot_r if foot_r > 0.0 else thick * 0.7
	r.add_shape(lo, Models.ball(fr, 8, 4), foot, Vector3(0, -l2 + fr * 0.5, -bend * knee * 0.2 - fr * 0.3), NONE, Vector3(1.0, 0.6, 1.4))
	r.legs.append({"upper": up, "lower": lo, "phase": phase, "knee": knee})


## Two glinting eyes on a head part.
static func _eyes(r: CreatureRig, part: String, at: Vector3, spread: float, size: float, color: Color, glow: float) -> void:
	for side: int in [-1, 1]:
		r.add_shape(part, Models.ball(size, 6, 3), color, Vector3(at.x + spread * float(side), at.y, at.z), NONE, Vector3(1.0, 0.8, 0.8), glow)


# ---------------------------------------------------------------- the Gleaner

## A lanky carrion-runner: shoulders high, hips low, a long bare neck held forward, a narrow
## snout and a throat-sac that sags with whatever it has picked up. Pale stripes on dusty hide;
## the eyes are the accent. No wind-up (it never attacks); running, the neck goes out level.
static func _gleaner(r: CreatureRig, color: Color) -> void:
	var hide: Color = Models.grim(color, 0.55, 0.9)
	var hide_d: Color = Models.grim(color, 0.45, 0.6)
	var stripe := Color(0.62, 0.56, 0.44)
	r.stride_rate = 1.6
	r.leg_swing = 0.7
	r.knee_fold = 0.9
	r.step_bob = 0.05
	r.lean = 0.2
	r.head_nod = 0.1
	r.tail_sway = 0.3
	r.add_part("body", "", Vector3(0, 0.66, 0))
	r.add_shape("body", _trunk([[-0.36, 0.1, 0.1, 0.08], [-0.22, 0.13, 0.13, 0.1], [0.0, 0.15, 0.17, 0.12], [0.2, 0.15, 0.2, 0.14], [0.32, 0.12, 0.16, 0.12], [0.4, 0.07, 0.08, 0.07]]), hide, Vector3(0, 0.02, 0), TRUNK_ROT + Vector3(-8, 0, 0), ONE, 0.0, 0.0, false, K_SKIN)
	for k: int in 4:
		r.add_shape("body", Models.tube([-0.14, 0.1, -0.12 + 0.1 * float(k), 0.0, 0.17, -0.1 + 0.1 * float(k), 0.14, 0.1, -0.12 + 0.1 * float(k)], [0.012, 0.016, 0.012], 4), stripe)
	# ragged crest down the spine
	r.add_part("mane", "body", Vector3(0, 0.15, -0.2), Vector3(-0.3, 0, 0))
	r.add_shape("mane", MeshKit.sheet(0.06, 0.12, 0.36, 3.0, 0.02, 0.0, 0.04, 6, 4), hide_d, NONE, Vector3(-80, 0, 0))
	r.sway_parts["mane"] = 0.4
	_leg(r, "fl", Vector3(-0.1, -0.02, -0.28), 0.64, 0.035, hide, HOOF, 0.0, 1.0, 0.05, K_SKIN)
	_leg(r, "fr", Vector3(0.1, -0.02, -0.28), 0.64, 0.035, hide, HOOF, PI, 1.0, 0.05, K_SKIN)
	_leg(r, "hl", Vector3(-0.1, -0.04, 0.3), 0.62, 0.042, hide_d, HOOF, PI, -1.0, 0.08, K_SKIN)
	_leg(r, "hr", Vector3(0.1, -0.04, 0.3), 0.62, 0.042, hide_d, HOOF, 0.0, -1.0, 0.08, K_SKIN)
	r.add_part("neck", "body", Vector3(0, 0.1, -0.38), Vector3(-0.5, 0, 0))
	r.add_shape("neck", Models.tube([0, 0, 0, 0, 0.12, -0.06, 0, 0.26, -0.1], [0.06, 0.045, 0.04], 7), hide_d.lerp(Color(0.45, 0.32, 0.3), 0.3), NONE, NONE, ONE, 0.0, 0.0, false, K_SKIN)
	# the throat sac: its hoard
	r.add_shape("neck", Models.ball(0.07, 9, 5), Color(0.42, 0.33, 0.28), Vector3(0, 0.06, -0.06), NONE, Vector3(1.0, 1.3, 1.0), 0.0, 0.1, false, K_SKIN)
	r.add_part("head", "neck", Vector3(0, 0.27, -0.1), Vector3(0.6, 0, 0))
	r.add_shape("head", Models.ball(0.065, 10, 5), hide, Vector3(0, 0.02, 0), NONE, Vector3(0.9, 0.85, 1.1), 0.0, 0.0, false, K_SKIN)
	r.add_shape("head", Models.tube([0, 0.01, -0.03, 0, -0.01, -0.13, 0, -0.025, -0.2], [0.04, 0.026, 0.012], 6), hide_d, NONE, NONE, ONE, 0.0, 0.0, false, K_SKIN)
	for side: int in [-1, 1]:
		r.add_shape("head", Models.cyl(0.0, 0.025, 0.08, 4), hide_d, Vector3(0.04 * float(side), 0.08, 0.02), Vector3(-20, 0, -25 * float(side)))
	_eyes(r, "head", Vector3(0, 0.04, -0.045), 0.04, 0.012, Color(0.95, 0.82, 0.45), 1.6)
	r.add_part("tail", "body", Vector3(0, 0.06, 0.38))
	r.add_shape("tail", Models.tube([0, 0, 0, 0, -0.08, 0.12, 0, -0.22, 0.18], [0.025, 0.018, 0.006], 5), hide_d)
	r.windup_pose = {"neck": Vector3(0.4, 0, 0)}
	r.stagger_tilt = Vector3(0.1, 0, 1.0)
	r.stagger_drop = 0.3


# ---------------------------------------------------------------- the Sod-Lurker

## A flat, broad burrower under a crust of earth: a wide head with a jaw built to close upward,
## tiny eyes on top, short splayed forelimbs with digging claws. Clods of soil cling to its back.
## Its wind-up is the heave out of the ground: jaw wide, forelimbs up.
static func _sod_lurker(r: CreatureRig, color: Color) -> void:
	var hide: Color = Models.grim(color, 0.5, 0.85)
	var hide_d: Color = Models.grim(color, 0.4, 0.55)
	var clod := Color(0.26, 0.21, 0.15)
	var mouth := Color(0.42, 0.18, 0.16)
	r.stride_rate = 2.6
	r.leg_swing = 0.45
	r.knee_fold = 0.5
	r.step_bob = 0.03
	r.lean = 0.05
	r.head_nod = 0.03
	r.tail_sway = 0.4
	r.strike_lunge = 0.25
	r.add_part("body", "", Vector3(0, 0.3, 0))
	r.add_shape("body", _trunk([[-0.55, 0.12, 0.06, 0.06], [-0.4, 0.3, 0.14, 0.14], [-0.1, 0.42, 0.18, 0.2], [0.2, 0.44, 0.18, 0.22], [0.42, 0.36, 0.14, 0.16]], 18), hide, NONE, TRUNK_ROT, ONE, 0.0, 0.1, false, K_SKIN)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for k: int in 14:
		var a: float = rng.randf_range(-1.2, 1.2)
		var z: float = rng.randf_range(-0.4, 0.35)
		r.add_shape("body", EnvKit.rock_mesh(rng.randf_range(0.05, 0.1), k), clod.lerp(hide_d, rng.randf()), Vector3(sin(a) * 0.32, 0.12 + cos(a) * 0.08, z), NONE, Vector3(1.2, 0.6, 1.1), 0.0, 0.0, true)
	# a ridge of bony knobs down the back
	for k: int in 5:
		r.add_shape("body", Models.ball(0.04, 6, 3), BONE.darkened(0.3), Vector3(0, 0.21, -0.32 + 0.16 * float(k)), NONE, Vector3(1.4, 0.7, 1.0))
	_leg(r, "fl", Vector3(-0.36, -0.02, -0.28), 0.29, 0.06, hide_d, HOOF, 0.0, 1.0, 0.1, K_SKIN, 0.07)
	_leg(r, "fr", Vector3(0.36, -0.02, -0.28), 0.29, 0.06, hide_d, HOOF, PI, 1.0, 0.1, K_SKIN, 0.07)
	_leg(r, "hl", Vector3(-0.32, -0.04, 0.3), 0.27, 0.055, hide_d, HOOF, PI, -1.0, 0.08, K_SKIN)
	_leg(r, "hr", Vector3(0.32, -0.04, 0.3), 0.27, 0.055, hide_d, HOOF, 0.0, -1.0, 0.08, K_SKIN)
	for side: int in [-1, 1]:
		for k: int in 3:
			r.add_shape("shin_f" + ("l" if side < 0 else "r"), Models.cyl(0.0, 0.016, 0.1, 4), BONE.darkened(0.2), Vector3(-0.03 + 0.03 * float(k), -0.27, -0.09), Vector3(-70, 0, 0), ONE, 0.0, 0.3, true)
	r.add_part("head", "body", Vector3(0, 0.04, -0.5))
	r.add_shape("head", _trunk([[-0.08, 0.3, 0.06, 0.12], [0.08, 0.32, 0.06, 0.12], [0.2, 0.24, 0.04, 0.08], [0.28, 0.12, 0.03, 0.04]], 16), hide, NONE, TRUNK_ROT, ONE, 0.0, 0.1, false, K_SKIN)
	_eyes(r, "head", Vector3(0, 0.12, -0.08), 0.13, 0.018, Color(0.9, 0.55, 0.25), 1.4)
	# the lower jaw: wide, lined with peg teeth that point up
	r.add_part("jaw", "head", Vector3(0, -0.04, 0.06))
	r.add_shape("jaw", _trunk([[-0.1, 0.3, 0.05, 0.02], [0.1, 0.31, 0.06, 0.02], [0.24, 0.22, 0.04, 0.02], [0.32, 0.08, 0.02, 0.01]], 16), hide_d, NONE, TRUNK_ROT, ONE, 0.0, 0.0, false, K_SKIN)
	r.add_shape("jaw", Models.bbox(0.5, 0.012, 0.3, 0.004), mouth, Vector3(0, 0.02, -0.12))
	for k: int in 9:
		var t: float = float(k) / 8.0
		var a2: float = lerpf(-1.3, 1.3, t)
		r.add_shape("jaw", Models.cyl(0.0, 0.016, 0.07, 4), BONE, Vector3(sin(a2) * 0.26, 0.05, -0.12 - cos(a2) * 0.16), NONE, ONE, 0.0, 0.2, true)
	r.add_part("tail", "body", Vector3(0, -0.02, 0.55))
	r.add_shape("tail", Models.tube([0, 0, 0, 0, -0.02, 0.15, 0, -0.04, 0.3], [0.08, 0.05, 0.01], 6, 0.6), hide_d)
	# the heave: forelimbs up and out, jaw wide, head tipped back
	r.windup_pose = {"head": Vector3(-0.35, 0, 0), "jaw": Vector3(0.5, 0, 0), "leg_fl": Vector3(-0.8, 0, -0.4), "leg_fr": Vector3(-0.8, 0, 0.4), "body": Vector3(-0.15, 0, 0)}
	r.strike_pose = {"head": Vector3(0.25, 0, 0), "jaw": Vector3(-0.2, 0, 0)}
	r.windup_drop = -0.08
	r.stagger_tilt = Vector3(0.2, 0, 0.5)
	r.stagger_drop = 0.08


# ---------------------------------------------------------------- the Thornback

## A heavy grazer: a high hump over the shoulders, a low head carrying two forward-hooked horns,
## and a ridge of pale thorn-spines from the hump down the back - the thing you name it by, and
## the thing you see from behind. Its wind-up is the charge: head down, horns level, a stamp.
static func _thornback(r: CreatureRig, color: Color) -> void:
	var hide: Color = Models.grim(color, 0.5, 0.85)
	var hide_d: Color = Models.grim(color, 0.4, 0.55)
	var shag := Color(0.24, 0.19, 0.14)
	var spine := Color(0.7, 0.64, 0.5)
	r.stride_rate = 1.2
	r.leg_swing = 0.38
	r.knee_fold = 0.55
	r.step_bob = 0.04
	r.bob = 0.015
	r.lean = 0.05
	r.head_nod = 0.06
	r.graze_drop = 1.0
	r.tail_sway = 0.35
	r.strike_lunge = 0.35
	r.grazing = true
	r.add_part("body", "", Vector3(0, 1.0, 0))
	r.add_shape("body", _trunk([[-0.8, 0.22, 0.18, 0.16], [-0.62, 0.4, 0.32, 0.26], [-0.3, 0.46, 0.38, 0.3], [0.05, 0.5, 0.44, 0.42], [0.35, 0.48, 0.42, 0.5], [0.58, 0.38, 0.36, 0.4], [0.72, 0.2, 0.22, 0.24]], 20), hide, Vector3(0, 0, 0), TRUNK_ROT, ONE, 0.0, 0.05, false, K_SKIN)
	# shaggy shoulders and dewlap
	r.add_shape("body", _trunk([[0.1, 0.52, 0.46, 0.44, 0, 0, 0, 0.12], [0.4, 0.52, 0.5, 0.52, 0, 0, 0, 0.15], [0.62, 0.4, 0.46, 0.42, 0, 0, 0, 0.12]], 22), shag, Vector3(0, -0.02, 0), TRUNK_ROT, ONE, 0.0, 0.0, false, K_HAIR)
	# the thorn ridge
	for k: int in 11:
		var t: float = float(k) / 10.0
		var z: float = lerpf(-0.5, 0.65, t)
		var top: float = lerpf(0.3, 0.52, smoothstep(0.0, 0.7, 1.0 - t)) + 0.04
		var h: float = lerpf(0.18, 0.34, sin(t * PI))
		r.add_shape("body", Models.cyl(0.0, 0.04, h, 5), spine.lerp(BONE, float(k % 2) * 0.4), Vector3(0, top + h * 0.4, -z), Vector3(-25 - 20 * t, 0, 0), ONE, 0.0, 0.25, true)
		if k % 2 == 0:
			for side: int in [-1, 1]:
				r.add_shape("body", Models.cyl(0.0, 0.028, h * 0.6, 4), spine.darkened(0.15), Vector3(0.12 * float(side), top + h * 0.2, -z), Vector3(-30, 0, 35 * float(side)), ONE, 0.0, 0.2, true)
	_leg(r, "fl", Vector3(-0.28, -0.12, -0.5), 0.88, 0.1, hide_d, HOOF, 0.0, 1.0, 0.05, K_SKIN, 0.09)
	_leg(r, "fr", Vector3(0.28, -0.12, -0.5), 0.88, 0.1, hide_d, HOOF, PI, 1.0, 0.05, K_SKIN, 0.09)
	_leg(r, "hl", Vector3(-0.25, -0.1, 0.6), 0.9, 0.11, hide_d, HOOF, PI * 0.5, -1.0, 0.08, K_SKIN, 0.09)
	_leg(r, "hr", Vector3(0.25, -0.1, 0.6), 0.9, 0.11, hide_d, HOOF, PI * 1.5, -1.0, 0.08, K_SKIN, 0.09)
	r.add_part("neck", "body", Vector3(0, 0.05, -0.72), Vector3(0.35, 0, 0))
	r.add_shape("neck", Models.tube([0, 0, 0, 0, -0.06, -0.18, 0, -0.14, -0.3], [0.26, 0.22, 0.18], 10), shag, NONE, NONE, ONE, 0.0, 0.0, false, K_HAIR)
	r.add_part("head", "neck", Vector3(0, -0.14, -0.32), Vector3(0.25, 0, 0))
	r.add_shape("head", _trunk([[-0.02, 0.16, 0.14, 0.14], [0.14, 0.15, 0.13, 0.12], [0.3, 0.12, 0.1, 0.08], [0.4, 0.09, 0.08, 0.05]], 14), hide, NONE, TRUNK_ROT, ONE, 0.0, 0.05, false, K_SKIN)
	r.add_shape("head", Models.ball(0.08, 8, 4), Color(0.14, 0.11, 0.1), Vector3(0, -0.03, -0.4), NONE, Vector3(1.1, 0.8, 0.6), 0.0, 0.3)
	_eyes(r, "head", Vector3(0, 0.06, -0.14), 0.15, 0.018, Color(0.75, 0.48, 0.2), 0.9)
	for side: int in [-1, 1]:
		var s: float = float(side)
		r.add_shape("head", Models.tube([0.12 * s, 0.1, -0.02, 0.32 * s, 0.14, -0.02, 0.4 * s, 0.12, -0.22, 0.32 * s, 0.1, -0.4], [0.05, 0.04, 0.025, 0.0], 6), HORN, NONE, NONE, ONE, 0.0, 0.35, false)
	r.add_part("tail", "body", Vector3(0, 0.12, 0.78))
	r.add_shape("tail", Models.tube([0, 0, 0, 0, -0.2, 0.1, 0, -0.45, 0.12], [0.04, 0.03, 0.02], 5), hide_d)
	r.add_shape("tail", Models.ball(0.06, 6, 3), shag, Vector3(0, -0.48, 0.12), NONE, Vector3(0.8, 1.4, 0.8))
	# the charge's wind-up: head low and horns level, a forefoot drawn back to stamp
	r.windup_pose = {"neck": Vector3(0.45, 0, 0), "head": Vector3(-0.2, 0, 0), "leg_fr": Vector3(0.5, 0, 0), "shin_fr": Vector3(-0.6, 0, 0), "body": Vector3(0.08, 0, 0)}
	r.strike_pose = {"neck": Vector3(0.2, 0, 0), "head": Vector3(-0.5, 0, 0)}
	r.windup_drop = 0.08
	r.stagger_tilt = Vector3(0.1, 0, 0.35)
	r.stagger_drop = 0.25


# ---------------------------------------------------------------- the Ditch Hound

## A lean wild dog of the ditches: deep chest, tucked belly, long muzzle, ears up, a brush of a
## tail carried low. A patchy dun coat with a darker saddle. Its wind-up is the crouch before
## the bite: forequarters down, head low and forward, lips back.
static func _ditch_hound(r: CreatureRig, color: Color) -> void:
	var coat: Color = Models.grim(color, 0.55, 0.9)
	var saddle: Color = Models.grim(color, 0.4, 0.5)
	var belly := Color(0.5, 0.45, 0.36)
	r.stride_rate = 1.9
	r.leg_swing = 0.75
	r.knee_fold = 0.9
	r.step_bob = 0.05
	r.lean = 0.12
	r.head_nod = 0.08
	r.tail_sway = 0.2
	r.strike_lunge = 0.45
	r.add_part("body", "", Vector3(0, 0.56, 0))
	r.add_shape("body", _trunk([[-0.4, 0.07, 0.07, 0.07], [-0.3, 0.12, 0.1, 0.1], [-0.08, 0.13, 0.1, 0.11], [0.14, 0.15, 0.2, 0.13], [0.3, 0.14, 0.2, 0.12], [0.4, 0.09, 0.1, 0.08]]), coat, NONE, TRUNK_ROT, ONE, 0.0, 0.0, false, K_HAIR)
	r.add_shape("body", _trunk([[-0.3, 0.09, 0.0, 0.11], [0.0, 0.11, 0.0, 0.12], [0.28, 0.1, 0.0, 0.13]], 14), saddle, Vector3(0, 0.012, 0), TRUNK_ROT, ONE, 0.0, 0.0, false, K_HAIR)
	r.add_shape("body", Models.ball(0.1, 8, 4), belly, Vector3(0, -0.1, -0.2), NONE, Vector3(0.9, 0.9, 1.3), 0.0, 0.0, false, K_HAIR)
	_leg(r, "fl", Vector3(-0.08, -0.04, -0.3), 0.52, 0.035, coat, HOOF, 0.0, 1.0, 0.04, K_HAIR, 0.035)
	_leg(r, "fr", Vector3(0.08, -0.04, -0.3), 0.52, 0.035, coat, HOOF, PI, 1.0, 0.04, K_HAIR, 0.035)
	_leg(r, "hl", Vector3(-0.08, -0.02, 0.3), 0.54, 0.045, saddle, HOOF, PI, -1.0, 0.09, K_HAIR, 0.035)
	_leg(r, "hr", Vector3(0.08, -0.02, 0.3), 0.54, 0.045, saddle, HOOF, 0.0, -1.0, 0.09, K_HAIR, 0.035)
	r.add_part("neck", "body", Vector3(0, 0.06, -0.38), Vector3(-0.55, 0, 0))
	r.add_shape("neck", Models.tube([0, 0, 0, 0, 0.12, -0.04, 0, 0.2, -0.06], [0.08, 0.065, 0.055], 8), coat, NONE, NONE, ONE, 0.0, 0.0, false, K_HAIR)
	r.add_part("head", "neck", Vector3(0, 0.2, -0.06), Vector3(0.65, 0, 0))
	r.add_shape("head", Models.ball(0.075, 10, 5), coat, Vector3(0, 0.02, 0.0), NONE, Vector3(1.0, 0.9, 1.15), 0.0, 0.0, false, K_HAIR)
	r.add_shape("head", Models.tube([0, 0.01, -0.04, 0, -0.005, -0.15, 0, -0.02, -0.21], [0.05, 0.034, 0.022], 7), saddle, NONE, NONE, ONE, 0.0, 0.0, false, K_HAIR)
	r.add_shape("head", Models.ball(0.016, 6, 3), Color(0.06, 0.05, 0.05), Vector3(0, -0.01, -0.22), NONE, ONE, 0.0, 0.5)
	for side: int in [-1, 1]:
		r.add_shape("head", Models.cyl(0.0, 0.032, 0.09, 4), saddle, Vector3(0.045 * float(side), 0.09, 0.02), Vector3(-10, 0, -15 * float(side)), Vector3(1, 1, 0.5))
	_eyes(r, "head", Vector3(0, 0.04, -0.06), 0.04, 0.011, Color(0.95, 0.65, 0.25), 1.2)
	r.add_part("jaw", "head", Vector3(0, -0.035, -0.04))
	r.add_shape("jaw", Models.tube([0, 0, 0, 0, -0.01, -0.12, 0, -0.012, -0.16], [0.03, 0.02, 0.012], 6), saddle.darkened(0.15))
	r.add_part("tail", "body", Vector3(0, 0.06, 0.4), Vector3(0.6, 0, 0))
	r.add_shape("tail", Models.tube([0, 0, 0, 0, -0.1, 0.1, 0, -0.26, 0.14], [0.03, 0.045, 0.02], 6), saddle, NONE, NONE, ONE, 0.0, 0.0, false, K_HAIR)
	r.windup_pose = {"body": Vector3(0.18, 0, 0), "neck": Vector3(0.35, 0, 0), "head": Vector3(-0.1, 0, 0), "leg_fl": Vector3(-0.3, 0, 0), "leg_fr": Vector3(-0.3, 0, 0)}
	r.strike_pose = {"neck": Vector3(0.2, 0, 0), "head": Vector3(-0.2, 0, 0), "leg_fl": Vector3(-0.6, 0, 0), "leg_fr": Vector3(-0.6, 0, 0)}
	r.windup_drop = 0.08
	r.stagger_tilt = Vector3(0.1, 0, 1.1)
	r.stagger_drop = 0.3


# ---------------------------------------------------------------- the Burr-Hog

## A barrel-bodied boar with a wedge of a head and short upcurved tusks. Burr-clumps matted into
## the bristles over its shoulders and face make a shield in front (its front armour); its rump is
## bare and pale. Its wind-up is the scrape: head down, a forefoot raking the ground.
static func _burr_hog(r: CreatureRig, color: Color) -> void:
	var hide: Color = Models.grim(color, 0.5, 0.75)
	var hide_d: Color = Models.grim(color, 0.4, 0.45)
	var burr := Color(0.5, 0.43, 0.26)
	var rump := Color(0.48, 0.38, 0.33)
	r.stride_rate = 2.4
	r.leg_swing = 0.5
	r.knee_fold = 0.6
	r.step_bob = 0.035
	r.lean = 0.08
	r.head_nod = 0.05
	r.tail_sway = 0.5
	r.strike_lunge = 0.3
	r.add_part("body", "", Vector3(0, 0.52, 0))
	r.add_shape("body", _trunk([[-0.5, 0.12, 0.1, 0.1], [-0.38, 0.24, 0.22, 0.2], [-0.1, 0.3, 0.28, 0.26], [0.2, 0.32, 0.3, 0.32], [0.42, 0.28, 0.27, 0.3], [0.56, 0.18, 0.2, 0.2]], 18), hide, NONE, TRUNK_ROT, ONE, 0.0, 0.0, false, K_HAIR)
	r.add_shape("body", Models.ball(0.2, 10, 5), rump, Vector3(0, 0.02, 0.38), NONE, Vector3(1.1, 0.9, 0.7), 0.0, 0.0, false, K_SKIN)
	# the burr mantle over the shoulders: the front armour
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for k: int in 26:
		var a: float = rng.randf_range(-1.5, 1.5)
		var z: float = rng.randf_range(-0.45, -0.05)
		var at := Vector3(sin(a) * 0.3, cos(a) * 0.26 + 0.02, z)
		r.add_shape("body", EnvKit.rock_mesh(rng.randf_range(0.04, 0.07), 200 + k, 0.5, 6, 4), burr.lerp(hide_d, rng.randf() * 0.5), at, NONE, ONE, 0.0, 0.0, true)
	for k: int in 7:
		r.add_shape("body", Models.cyl(0.0, 0.03, 0.18, 4), hide_d, Vector3(0, 0.3, -0.35 + 0.1 * float(k)), Vector3(-30, 0, 0), ONE, 0.0, 0.0, true, K_HAIR)
	_leg(r, "fl", Vector3(-0.17, -0.12, -0.34), 0.4, 0.06, hide_d, HOOF, 0.0, 1.0, 0.03, K_HAIR, 0.05)
	_leg(r, "fr", Vector3(0.17, -0.12, -0.34), 0.4, 0.06, hide_d, HOOF, PI, 1.0, 0.03, K_HAIR, 0.05)
	_leg(r, "hl", Vector3(-0.16, -0.1, 0.36), 0.42, 0.07, hide_d, HOOF, PI, -1.0, 0.06, K_HAIR, 0.05)
	_leg(r, "hr", Vector3(0.16, -0.1, 0.36), 0.42, 0.07, hide_d, HOOF, 0.0, -1.0, 0.06, K_HAIR, 0.05)
	r.add_part("head", "body", Vector3(0, 0.0, -0.5), Vector3(0.25, 0, 0))
	r.add_shape("head", _trunk([[-0.04, 0.22, 0.2, 0.2], [0.12, 0.18, 0.16, 0.16], [0.28, 0.12, 0.1, 0.09], [0.4, 0.08, 0.07, 0.06]], 14), hide, NONE, TRUNK_ROT, ONE, 0.0, 0.0, false, K_HAIR)
	r.add_shape("head", Models.lathe([0.08, -0.03, 0.085, 0.0, 0.08, 0.03, 0.0, 0.035], 10), Color(0.3, 0.22, 0.2), Vector3(0, -0.02, -0.42), Vector3(90, 0, 0), ONE, 0.0, 0.25, false, K_SKIN)
	for k: int in 12:
		var a3: float = rng.randf_range(-1.4, 1.4)
		r.add_shape("head", EnvKit.rock_mesh(rng.randf_range(0.03, 0.05), 300 + k, 0.5, 6, 4), burr, Vector3(sin(a3) * 0.18, cos(a3) * 0.15 + 0.02, rng.randf_range(-0.2, 0.0)), NONE, ONE, 0.0, 0.0, true)
	for side: int in [-1, 1]:
		var s: float = float(side)
		r.add_shape("head", Models.tube([0.08 * s, -0.06, -0.3, 0.13 * s, -0.02, -0.36, 0.14 * s, 0.07, -0.38], [0.022, 0.016, 0.0], 5), BONE, NONE, NONE, ONE, 0.0, 0.35)
		r.add_shape("head", Models.cyl(0.0, 0.05, 0.1, 4), hide_d, Vector3(0.12 * s, 0.17, 0.0), Vector3(20, 0, -40 * s), Vector3(1, 1, 0.4))
	_eyes(r, "head", Vector3(0, 0.08, -0.16), 0.11, 0.013, Color(0.9, 0.3, 0.2), 1.3)
	r.add_part("tail", "body", Vector3(0, 0.12, 0.55))
	r.add_shape("tail", Models.tube([0, 0, 0, 0.03, -0.06, 0.06, -0.02, -0.12, 0.08, 0.0, -0.2, 0.06], [0.015, 0.012, 0.01, 0.0], 4), hide_d)
	r.windup_pose = {"head": Vector3(0.3, 0, 0), "leg_fr": Vector3(0.6, 0, 0), "shin_fr": Vector3(-0.8, 0, 0), "body": Vector3(0.1, 0, 0)}
	r.strike_pose = {"head": Vector3(-0.35, 0, 0)}
	r.windup_drop = 0.06
	r.stagger_tilt = Vector3(0.15, 0, 0.9)
	r.stagger_drop = 0.22


# ---------------------------------------------------------------- the Wirehorn

## A tall, rangy grazer of the power-line verge: long thin legs, a long neck carried high, and
## branching antlers that have snagged lengths of old copper wire, green with age - its one accent.
## Its back end is the dangerous end. Two wind-ups: the antler toss (head down, forward) and the
## kick (the alternative pose: rump up, hind legs drawn under, then lashed out behind).
static func _wirehorn(r: CreatureRig, color: Color) -> void:
	var coat: Color = Models.grim(color, 0.5, 0.85)
	var coat_d: Color = Models.grim(color, 0.4, 0.55)
	var pale := Color(0.62, 0.58, 0.5)
	var copper := Color(0.36, 0.52, 0.42)
	r.stride_rate = 1.4
	r.leg_swing = 0.55
	r.knee_fold = 0.8
	r.step_bob = 0.04
	r.lean = 0.06
	r.head_nod = 0.07
	r.graze_drop = 1.1
	r.tail_sway = 0.4
	r.strike_lunge = 0.15
	r.grazing = true
	r.add_part("body", "", Vector3(0, 1.0, 0))
	r.add_shape("body", _trunk([[-0.5, 0.1, 0.1, 0.1], [-0.38, 0.17, 0.17, 0.16], [-0.1, 0.18, 0.2, 0.16], [0.18, 0.19, 0.23, 0.17], [0.38, 0.16, 0.2, 0.15], [0.48, 0.1, 0.1, 0.09]]), coat, NONE, TRUNK_ROT, ONE, 0.0, 0.0, false, K_HAIR)
	r.add_shape("body", Models.ball(0.13, 8, 4), pale, Vector3(0, 0.04, 0.44), NONE, Vector3(1.1, 1.0, 0.5), 0.0, 0.0, false, K_HAIR)
	_leg(r, "fl", Vector3(-0.09, -0.08, -0.36), 0.92, 0.04, coat_d, HOOF, 0.0, 1.0, 0.04, K_HAIR, 0.035)
	_leg(r, "fr", Vector3(0.09, -0.08, -0.36), 0.92, 0.04, coat_d, HOOF, PI, 1.0, 0.04, K_HAIR, 0.035)
	_leg(r, "hl", Vector3(-0.1, -0.06, 0.4), 0.94, 0.05, coat_d, HOOF, PI * 0.5, -1.0, 0.1, K_HAIR, 0.035)
	_leg(r, "hr", Vector3(0.1, -0.06, 0.4), 0.94, 0.05, coat_d, HOOF, PI * 1.5, -1.0, 0.1, K_HAIR, 0.035)
	r.add_part("neck", "body", Vector3(0, 0.08, -0.46), Vector3(-0.85, 0, 0))
	r.add_shape("neck", Models.tube([0, 0, 0, 0, 0.25, -0.03, 0, 0.5, -0.02], [0.09, 0.07, 0.06], 8), coat, NONE, NONE, ONE, 0.0, 0.0, false, K_HAIR)
	r.add_part("head", "neck", Vector3(0, 0.52, -0.02), Vector3(0.95, 0, 0))
	r.add_shape("head", Models.ball(0.08, 10, 5), coat, Vector3(0, 0.02, 0.0), NONE, Vector3(0.9, 0.95, 1.1), 0.0, 0.0, false, K_HAIR)
	r.add_shape("head", Models.tube([0, 0.0, -0.05, 0, -0.03, -0.16, 0, -0.05, -0.22], [0.055, 0.04, 0.03], 7), coat_d, NONE, NONE, ONE, 0.0, 0.0, false, K_HAIR)
	for side: int in [-1, 1]:
		var s: float = float(side)
		r.add_shape("head", Models.cyl(0.0, 0.035, 0.11, 4), coat_d, Vector3(0.07 * s, 0.05, 0.04), Vector3(0, 0, -70 * s), Vector3(1, 1, 0.4))
		# antlers: a beam back and up with three tines
		var beam: Array = [0.04 * s, 0.07, 0.02, 0.14 * s, 0.24, 0.08, 0.2 * s, 0.42, 0.04, 0.24 * s, 0.56, -0.06]
		r.add_shape("head", Models.tube(beam, [0.02, 0.016, 0.012, 0.004], 5), HORN.lightened(0.15), NONE, NONE, ONE, 0.0, 0.2)
		for k: int in 3:
			var y0: float = 0.22 + 0.13 * float(k)
			var x0: float = (0.12 + 0.035 * float(k)) * s
			r.add_shape("head", Models.tube([x0, y0, 0.06, x0 + 0.06 * s, y0 + 0.12, -0.04 - 0.03 * float(k)], [0.011, 0.002], 4), HORN.lightened(0.15), NONE, NONE, ONE, 0.0, 0.2)
		# the snagged wire, looping between the tines
		r.add_shape("head", Models.tube([0.08 * s, 0.2, 0.08, 0.2 * s, 0.3, -0.02, 0.1 * s, 0.38, 0.05, 0.22 * s, 0.46, -0.04, 0.3 * s, 0.38, 0.02], [0.006, 0.006, 0.006, 0.006, 0.006], 4), copper, NONE, NONE, ONE, 0.6, 0.6, false, K_METAL)
	_eyes(r, "head", Vector3(0, 0.04, -0.05), 0.065, 0.013, EYE_DIM, 0.0)
	r.add_part("tail", "body", Vector3(0, 0.1, 0.5), Vector3(0.4, 0, 0))
	r.add_shape("tail", Models.tube([0, 0, 0, 0, -0.08, 0.06, 0, -0.16, 0.06], [0.04, 0.03, 0.01], 5), pale)
	# the antler toss: head swept down and forward
	r.windup_pose = {"neck": Vector3(0.9, 0, 0), "head": Vector3(-0.3, 0, 0)}
	r.strike_pose = {"neck": Vector3(0.2, 0, 0), "head": Vector3(-0.7, 0, 0)}
	# the kick: weight onto the forelegs, hind legs gathered, then lashed out behind
	r.alt_windup_pose = {"body": Vector3(0.18, 0, 0), "leg_hl": Vector3(-0.5, 0, 0), "leg_hr": Vector3(-0.5, 0, 0), "shin_hl": Vector3(0.7, 0, 0), "shin_hr": Vector3(0.7, 0, 0), "neck": Vector3(0.2, 0, 0)}
	r.alt_strike_pose = {"body": Vector3(0.28, 0, 0), "leg_hl": Vector3(1.0, 0, 0), "leg_hr": Vector3(1.0, 0, 0), "shin_hl": Vector3(-0.2, 0, 0), "shin_hr": Vector3(-0.2, 0, 0)}
	r.stagger_tilt = Vector3(0.1, 0, 0.6)
	r.stagger_drop = 0.3


# ---------------------------------------------------------------- the Kettle Beetle

## A domed beetle the size of a kettle-drum, its shell dented and coppery-brown like an old
## kettle, with a vent at the back that glows when it is hurt (the accent - and the warning:
## it bursts in scalding steam when it dies). Six legs on a tripod gait; it lifts its shell to bite.
static func _kettle_beetle(r: CreatureRig, color: Color) -> void:
	var shell: Color = Models.grim(color, 0.6, 0.85)
	var shell_d: Color = Models.grim(color, 0.45, 0.5)
	var under := Color(0.16, 0.13, 0.11)
	r.stride_rate = 3.2
	r.leg_swing = 0.4
	r.knee_fold = 0.5
	r.step_bob = 0.02
	r.bob = 0.01
	r.lean = 0.0
	r.head_nod = 0.04
	r.tail_sway = 0.0
	r.strike_lunge = 0.18
	r.add_part("body", "", Vector3(0, 0.3, 0))
	r.add_shape("body", _trunk([[-0.45, 0.12, 0.04, 0.08], [-0.36, 0.3, 0.06, 0.2], [-0.1, 0.4, 0.08, 0.3], [0.18, 0.4, 0.08, 0.3], [0.38, 0.3, 0.06, 0.2], [0.46, 0.14, 0.04, 0.08]], 20), shell, NONE, TRUNK_ROT, ONE, 0.0, 0.55, false, K_METAL)
	r.add_shape("body", Models.tube([0, 0.3, 0.38, 0, 0.33, -0.36], [0.012, 0.012], 4), shell_d)
	for side: int in [-1, 1]:
		for k: int in 3:
			r.add_shape("body", Models.ball(0.05, 6, 3), shell_d, Vector3(0.2 * float(side), 0.24 - 0.02 * float(k), -0.15 + 0.18 * float(k)), NONE, Vector3(1.0, 0.4, 1.0), 0.0, 0.5, true)
	r.add_shape("body", Models.ball(0.32, 10, 4), under, Vector3(0, -0.04, 0), NONE, Vector3(1.1, 0.25, 1.35))
	# the vent: a spout at the back that glows
	r.add_shape("body", Models.cyl(0.04, 0.06, 0.1, 8), shell_d, Vector3(0, 0.22, 0.36), Vector3(55, 0, 0), ONE, 0.0, 0.5, false, K_METAL)
	r.add_shape("body", Models.ball(0.035, 6, 3), Color(1.0, 0.55, 0.2), Vector3(0, 0.26, 0.41), NONE, ONE, 2.0)
	var phases: Array = [0.0, PI, 0.0]
	for k: int in 3:
		var z: float = -0.22 + 0.22 * float(k)
		_leg(r, "%dl" % k, Vector3(-0.3, -0.06, z), 0.26, 0.022, under, under, float(phases[k]), 1.0, 0.12, K_SKIN, 0.02)
		_leg(r, "%dr" % k, Vector3(0.3, -0.06, z), 0.26, 0.022, under, under, float(phases[k]) + PI, 1.0, 0.12, K_SKIN, 0.02)
	# splay the legs outward
	for k: int in 3:
		(r.get_part("leg_%dl" % k)).rotation.z = 0.5
		(r.get_part("leg_%dr" % k)).rotation.z = -0.5
	r.add_part("head", "body", Vector3(0, -0.02, -0.46))
	r.add_shape("head", Models.ball(0.12, 9, 5), under.lightened(0.05), NONE, NONE, Vector3(1.2, 0.7, 0.9))
	for side: int in [-1, 1]:
		var s: float = float(side)
		r.add_shape("head", Models.tube([0.06 * s, -0.02, -0.08, 0.1 * s, -0.03, -0.18, 0.03 * s, -0.04, -0.24], [0.018, 0.012, 0.0], 4), shell_d, NONE, NONE, ONE, 0.0, 0.4)
		r.add_shape("head", Models.tube([0.05 * s, 0.05, -0.06, 0.16 * s, 0.14, -0.2, 0.22 * s, 0.12, -0.32], [0.006, 0.004, 0.002], 3), under)
	_eyes(r, "head", Vector3(0, 0.03, -0.08), 0.07, 0.016, Color(0.85, 0.5, 0.2), 0.8)
	r.windup_pose = {"body": Vector3(-0.22, 0, 0), "head": Vector3(0.3, 0, 0)}
	r.strike_pose = {"body": Vector3(0.12, 0, 0), "head": Vector3(-0.2, 0, 0)}
	r.windup_drop = -0.05
	r.stagger_tilt = Vector3(0.0, 0, 2.6)
	r.stagger_drop = 0.0


# ---------------------------------------------------------------- the Chaff Wren

## A plump ground bird of the stubble, straw-and-ash feathered, long-legged, with a short hard
## beak. They come in flocks and peck and scatter. Its wind-up is the crouch with wings half up.
static func _chaff_wren(r: CreatureRig, color: Color) -> void:
	var plume: Color = Models.grim(color, 0.55, 0.95)
	var plume_d: Color = Models.grim(color, 0.4, 0.55)
	var leg := Color(0.32, 0.26, 0.18)
	r.stride_rate = 6.0
	r.leg_swing = 0.6
	r.knee_fold = 0.6
	r.step_bob = 0.05
	r.bob = 0.012
	r.lean = 0.2
	r.head_nod = 0.18
	r.tail_sway = 0.25
	r.wing_flap = 0.9
	r.strike_lunge = 0.22
	r.add_part("body", "", Vector3(0, 0.28, 0))
	r.add_shape("body", Models.ball(0.13, 10, 6), plume, Vector3(0, 0.02, 0), NONE, Vector3(0.85, 0.85, 1.25), 0.0, 0.0, false, K_HAIR)
	r.add_shape("body", Models.ball(0.09, 8, 4), Color(0.6, 0.55, 0.42), Vector3(0, -0.04, -0.06), NONE, Vector3(0.9, 0.9, 1.1), 0.0, 0.0, false, K_HAIR)
	for k: int in 3:
		r.add_shape("body", Models.ball(0.03, 5, 3), plume_d, Vector3(-0.04 + 0.04 * float(k), 0.12, 0.04 * float(k % 2)), NONE, Vector3(1, 0.4, 1.4))
	for side: int in [-1, 1]:
		var n: String = "wing_" + ("left" if side < 0 else "right")
		r.add_part(n, "body", Vector3(0.09 * float(side), 0.06, 0.0))
		r.add_shape(n, MeshKit.sheet(0.1, 0.04, 0.2, 2.0, 0.01, 0.0, 0.03, 5, 4), plume_d, Vector3(0.0, 0.0, 0.04), Vector3(-80, 0, 70 * float(side)), ONE, 0.0, 0.0, false, K_HAIR)
	_leg(r, "l", Vector3(-0.05, -0.08, 0.02), 0.2, 0.012, leg, leg, 0.0, -1.0, 0.04, K_SKIN, 0.025)
	_leg(r, "r", Vector3(0.05, -0.08, 0.02), 0.2, 0.012, leg, leg, PI, -1.0, 0.04, K_SKIN, 0.025)
	r.add_part("head", "body", Vector3(0, 0.12, -0.12))
	r.add_shape("head", Models.ball(0.065, 8, 5), plume, NONE, NONE, ONE, 0.0, 0.0, false, K_HAIR)
	r.add_shape("head", Models.cyl(0.0, 0.022, 0.08, 5), Color(0.45, 0.4, 0.3), Vector3(0, -0.01, -0.08), Vector3(-90, 0, 0), ONE, 0.0, 0.3)
	_eyes(r, "head", Vector3(0, 0.015, -0.035), 0.045, 0.01, EYE_DIM, 0.0)
	r.add_part("tail", "body", Vector3(0, 0.04, 0.15), Vector3(-0.4, 0, 0))
	r.add_shape("tail", MeshKit.sheet(0.04, 0.08, 0.14, 1.0, 0.0, 0.0, 0.02, 3, 3), plume_d, NONE, Vector3(80, 0, 0))
	r.windup_pose = {"body": Vector3(-0.25, 0, 0), "head": Vector3(-0.3, 0, 0)}
	r.strike_pose = {"body": Vector3(0.35, 0, 0), "head": Vector3(0.5, 0, 0)}
	r.windup_drop = 0.05
	r.stagger_tilt = Vector3(0.0, 0, 1.4)
	r.stagger_drop = 0.12
