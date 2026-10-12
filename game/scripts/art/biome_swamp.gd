class_name BiomeSwamp
extends RefCounted
## Mire: mud and standing water, reeds, buttressed trees trailing moss, rot and fungus.

const MUD := Color(0.21, 0.18, 0.13)
const WET := Color(0.09, 0.1, 0.07)
const REED := Color(0.3, 0.33, 0.15)
const REED_D := Color(0.17, 0.21, 0.11)
const BARK := Color(0.17, 0.15, 0.12)
const MOSS := Color(0.24, 0.31, 0.17)
const ROT := Color(0.25, 0.21, 0.16)
const FUNGUS := Color(0.75, 0.6, 0.32)
const LILY := Color(0.17, 0.33, 0.19)
const WATER := "water:0c0f09"
const KINDS: Array[String] = ["pool", "reeds", "cypress", "snag", "lily_pads", "boardwalk", "posts", "boat", "fungus", "fog_bank", "stump"]


static func info() -> Dictionary:
	return {
		"label": "Mire", "floor_color": MUD, "wall_color": BARK,
		"sky": Color(0.06, 0.08, 0.07), "ambient": Color(0.42, 0.52, 0.47), "ambient_energy": 0.55,
		"sun_color": Color(0.86, 0.9, 0.7), "sun_energy": 0.75, "sun_rotation": Vector3(-48, -32, 0),
		"fog_color": Color(0.17, 0.22, 0.18), "fog_density": 0.018,
		"props": KINDS,
		"scatter": [{"kind": "reeds", "weight": 5.0}, {"kind": "lily_pads", "weight": 1.0}, {"kind": "stump", "weight": 1.0}, {"kind": "fungus", "weight": 1.0}, {"kind": "snag", "weight": 1.0}],
		"stage": [
			["pool", -3, -4, 0], ["pool", 3.5, -1, 40], ["pool", 9, 5, 80], ["pool", -9, 7, 10], ["pool", -10, -9, 60],
			["lily_pads", -3.5, -4.5, 0], ["lily_pads", 4, -0.5, 50], ["lily_pads", 9.5, 5.5, 0], ["boat", 3.2, -1.6, 35],
			["boardwalk", -6.5, 1.5, 60], ["boardwalk", -8.2, 4.4, 60], ["boardwalk", -4.8, -1.4, 60], ["posts", -2.6, -6.6, 0], ["posts", 10.5, 3, 0],
			["cypress", -12, -12, 0], ["cypress", -6, -12.5, 0], ["cypress", 7, -11, 0], ["cypress", 12.5, -6, 0], ["cypress", -12.5, -3, 0], ["cypress", 12, 11, 0], ["cypress", -2, 11.5, 0],
			["snag", 0, -10, 0], ["snag", 6, 9, 0], ["fungus", -11, 2, 0], ["fungus", 1, 5, 0], ["stump", 11, -1, 0],
			["fog_bank", -4, -3, 0], ["fog_bank", 8, 4, 30], ["fog_bank", -9, 8, 0], ["fog_bank", 3, 11, 60], ["fog_bank", 9, -9, 0],
		],
	}


static func floor_material() -> ShaderMaterial:
	return EnvKit.surface(5, MUD, WET)


static func build(b: EnvBuilder, kind: String) -> Dictionary:
	match kind:
		"pool":
			var rim: Array = []
			for i: int in 14:
				var a: float = TAU * float(i) / 14.0
				var r: float = b.rf(2.2, 3.3)
				rim.append_array([cos(a) * r, sin(a) * r * 0.8])
			b.m(Color(1, 1, 1), false).plate(rim, 0.02, Vector3(0, 0.02, 0), Vector3(90, 0, 0))
			var made: Dictionary = Biomes.meta(3.2, 0.05, false)
			made["special"] = WATER
			return made
		"reeds":
			b.tuft(16, b.rf(1.2, 1.9), 0.45, REED_D, REED, 0, 0, 0.035)
			for i: int in 4:
				var x: float = b.rf(-0.3, 0.3)
				var z: float = b.rf(-0.3, 0.3)
				var h: float = b.rf(1.3, 2.0)
				b.m(REED_D).pole(Vector3(x, 0, z), Vector3(x * 1.3, h, z * 1.3), 0.015, 0.012, 3)
				b.m(Color(0.22, 0.14, 0.09), false).cyl(0.035, 0.035, 0.22, x * 1.3, h, z * 1.3, 5)
			b.m(WET).rock(0.5, 0, 0.0, 0, 1.2, 0.12, 1.2)
			return Biomes.meta(0.5, 1.9, false, true)
		"cypress":
			var h: float = b.rf(4.5, 6.0)
			# Flared, fluted base with knees and roots reaching into the mud.
			b.m(BARK, false).mesh(MeshKit.lathe(Models.poly([0.75, 0.0, 0.42, 0.5, 0.28, 1.3, 0.22, h * 0.55, 0.14, h * 0.8]), 10, 7, 0.22, 0.02), Vector3.ZERO)
			for i: int in 6:
				var a: float = TAU * float(i) / 6.0 + b.rf(-0.3, 0.3)
				var reach: float = b.rf(0.9, 1.6)
				b.m(BARK, true).tube([cos(a) * 0.4, 0.5, sin(a) * 0.4, cos(a) * reach * 0.6, 0.3, sin(a) * reach * 0.6, cos(a) * reach, 0.0, sin(a) * reach], [0.13, 0.09, 0.04], 5)
				if i % 2 == 0:
					b.cyl(0.03, 0.09, b.rf(0.3, 0.6), cos(a) * reach * 1.15, 0.2, sin(a) * reach * 1.15, 5)
			var tips: Array[Vector3] = []
			for i: int in 5:
				var a: float = TAU * float(i) / 5.0 + b.rf(-0.4, 0.4)
				var reach: float = b.rf(1.2, 2.0)
				var from := Vector3(0, h * b.rf(0.55, 0.78), 0)
				var tip: Vector3 = from + Vector3(cos(a) * reach, b.rf(0.3, 0.9), sin(a) * reach)
				b.m(BARK, true).pole(from, tip, 0.1, 0.03, 5)
				tips.append(tip)
				b.m(MOSS.lerp(REED_D, b.rf(0, 0.5)), true).rock(b.rf(0.7, 1.0), tip.x, tip.y + 0.2, tip.z, 1.2, 0.45, 1.2)
			b.m(MOSS, true).rock(1.1, 0, h * 0.9, 0, 1.2, 0.5, 1.2)
			# Hanging moss: ragged curtains off every bough.
			for tip: Vector3 in tips:
				for k: int in 4:
					var at: Vector3 = tip * b.rf(0.55, 1.0)
					at.y = tip.y
					var drop: float = b.rf(0.7, 1.7)
					b.m(MOSS.lerp(Color(0.38, 0.42, 0.3), b.rf(0, 1)), true).tube([at.x, at.y, at.z, at.x + b.rf(-0.05, 0.05), at.y - drop * 0.5, at.z, at.x, at.y - drop, at.z + b.rf(-0.05, 0.05)], [0.05, 0.07, 0.0], 4, 0.3)
			return Biomes.meta(0.8, h, true)
		"snag":
			var h: float = b.rf(2.6, 3.6)
			var tips: Array[Vector3] = b.bare_tree(h, BARK.darkened(0.1), 3, 0.15, 0.6, Color(MOSS.r, MOSS.g, MOSS.b, 1.0))
			for tip: Vector3 in tips:
				var drop: float = b.rf(0.5, 1.2)
				b.m(MOSS, true).tube([tip.x, tip.y, tip.z, tip.x, tip.y - drop * 0.5, tip.z + 0.04, tip.x, tip.y - drop, tip.z], [0.04, 0.06, 0.0], 4, 0.3)
			return Biomes.meta(0.35, h, true)
		"lily_pads":
			for i: int in 9:
				var x: float = b.rf(-1.3, 1.3)
				var z: float = b.rf(-1.0, 1.0)
				var r: float = b.rf(0.16, 0.3)
				b.m(LILY.lerp(MOSS, b.rf(0, 0.6)), true).mesh(MeshKit.extrude(Models.poly([r, 0.0, r * 0.7, r * 0.7, 0.0, r, -r * 0.7, r * 0.7, -r, 0.0, -r * 0.7, -r * 0.7, 0.0, -r, r * 0.15, -r * 0.3, r * 0.7, -r * 0.7]), 0.012), Vector3(x, 0.045, z), Vector3(90, b.rf(0, 360), 0))
				if i % 4 == 0:
					b.m(Color(0.8, 0.76, 0.68), true, 0, 0.0, 0.1).cyl(0.0, 0.06, 0.09, x, 0.09, z, 5).m(Color(0.75, 0.6, 0.3)).ball(0.025, x, 0.08, z)
			return Biomes.meta(1.5, 0.1, false)
		"boardwalk":
			# Three metres of rotten walkway: lay several in a line. Planks sag and some are gone.
			for side: int in [-1, 1]:
				for i: int in 3:
					var z: float = -1.3 + 1.3 * float(i)
					b.m(ROT.darkened(0.2)).vary().cyl(0.08, 0.1, 0.9 + b.rf(-0.1, 0.25), 0.62 * side, 0.4, z, 6, b.rf(-5, 5), b.rf(-5, 5))
				b.m(ROT.darkened(0.1)).box(0.09, 0.11, 3.0, 0.5 * side, 0.3, 0, 0, 0, 0)
			for i: int in 11:
				if i == 4 or (i == 8 and b.rng.randf() < 0.7):
					continue
				b.m(ROT).vary(0.14).box(1.35 + b.rf(-0.1, 0.12), 0.05, 0.23, b.rf(-0.04, 0.04), 0.38 + b.rf(-0.012, 0.012), -1.37 + 0.274 * float(i), b.rf(-4, 4), b.rf(-2, 2), b.rf(-3, 3))
			b.m(ROT).box(0.9, 0.05, 0.22, 0.5, 0.2, -0.27, 20, 0, 28)
			return Biomes.meta(1.7, 0.9, false)
		"posts":
			for i: int in 4:
				var x: float = [-0.7, 0.1, 0.8, 0.2][i]
				var z: float = [0.0, -0.5, 0.2, 0.7][i]
				var h: float = b.rf(0.9, 1.9)
				b.m(ROT.darkened(0.15)).vary().cyl(0.09, 0.12, h, x, h * 0.5, z, 6, b.rf(-7, 7), b.rf(-7, 7))
				b.m(MOSS).cyl(0.125, 0.13, 0.18, x, 0.12, z, 6)
			b.m(Color(0.36, 0.3, 0.2)).tube([-0.7, 0.95, 0.0, -0.3, 0.6, -0.25, 0.1, 0.85, -0.5], [0.022, 0.022, 0.022], 4)
			b.ring(0.1, 0.13, -0.7, 0.9, 0.0)
			return Biomes.meta(1.1, 1.9, true)
		"boat":
			# A rowboat gone down by the stern, heeled over, gunwale and ribs showing.
			var hull: Array = [[-1.5, 0.05, 0.12, 0.02, 0, 0, 0.3], [-1.1, 0.42, 0.34, 0.03, 0, 0, 0.3], [-0.3, 0.6, 0.44, 0.03, 0, 0, 0.3], [0.6, 0.56, 0.4, 0.03, 0, 0, 0.3], [1.25, 0.34, 0.3, 0.03, 0, 0, 0.3], [1.6, 0.04, 0.12, 0.02, 0, 0, 0.3]]
			b.m(ROT, false).mesh(MeshKit.loft(MeshKit.refine(hull, 2), 12), Vector3(0, 0.18, 0), Vector3(-76, 0, 18))
			b.m(ROT.darkened(0.35), true)
			for i: int in 4:
				b.box(1.05 - 0.12 * absf(float(i) - 1.5), 0.04, 0.07, 0.07, 0.36 + 0.02 * float(i), -0.9 + 0.6 * float(i), 0, -14, 18)
			b.m(ROT.lightened(0.1)).box(0.9, 0.04, 0.2, 0.06, 0.4, 0.1, 0, -14, 18)
			b.m(ROT).pole(Vector3(0.9, 0.1, 0.4), Vector3(1.9, 0.5, -0.9), 0.03, 0.03, 4).box(0.14, 0.02, 0.4, 1.95, 0.52, -0.98, 38, -16, 0)
			b.m(MOSS).rock(0.3, -0.5, 0.42, -0.9, 1.3, 0.3, 1.0)
			return Biomes.meta(1.7, 0.8, true)
		"fungus":
			b.m(BARK).cyl(0.26, 0.34, 0.7, 0, 0.35, 0, 7, b.rf(-6, 6), b.rf(-6, 6))
			b.m(BARK.lightened(0.12)).cyl(0.24, 0.26, 0.03, 0, 0.71, 0, 7)
			for i: int in 7:
				var a: float = b.rf(0, TAU)
				var y: float = b.rf(0.15, 0.62)
				var r: float = b.rf(0.1, 0.2)
				b.m(FUNGUS.lerp(Color(0.5, 0.75, 0.55), b.rf(0, 0.6)), false, 0, 0.0, 0.45).mesh(Models.lathe([r, 0.0, r * 0.7, 0.03, 0.0, 0.05], 7), Vector3(cos(a) * 0.3, y, sin(a) * 0.3), Vector3.ZERO, Vector3(1, 1, 1))
			for i: int in 5:
				var x: float = b.rf(-0.7, 0.7)
				var z: float = b.rf(-0.7, 0.7)
				var h: float = b.rf(0.08, 0.2)
				b.m(Color(0.7, 0.66, 0.55), false).cyl(0.012, 0.016, h, x, h * 0.5, z, 4).m(FUNGUS, false, 0, 0.0, 0.35).mesh(Models.lathe([0.06, 0.0, 0.04, 0.03, 0.0, 0.045], 6), Vector3(x, h, z))
			return Biomes.meta(0.6, 0.75, true, true)
		"fog_bank":
			b.m(Color(1, 1, 1), false).ball(1.0, 0, 0.5, 0, b.rf(3.0, 4.5), 0.55, b.rf(2.0, 3.0), 12)
			var made: Dictionary = Biomes.meta(3.5, 1.0, false)
			made["special"] = "fog:56665a"
			return made
		"stump":
			b.m(BARK, false).mesh(MeshKit.lathe(Models.poly([0.55, 0.0, 0.34, 0.25, 0.28, 0.6 + b.rf(0, 0.4)]), 8, 5, 0.2, 0.03), Vector3.ZERO)
			b.m(ROT.lightened(0.1), true).rock(0.26, 0, 0.75, 0, 1.0, 0.4, 1.0)
			b.m(MOSS).rock(0.3, 0.2, 0.3, 0.25, 1.0, 0.5, 1.0)
			b.m(ROT).cyl(0.2, 0.22, 1.6, 1.1, 0.2, 0.2, 7, 90, 0, b.rf(0, 180))
			return Biomes.meta(1.3, 1.0, true)
	return {}


## A palisade of sharpened, mossy stakes bound with rails. No solid core.
static func wall(b: EnvBuilder, length: float, height: float) -> Dictionary:
	var count: int = maxi(int(length / 0.42), 2)
	for i: int in count:
		var x: float = -length * 0.5 + length * (float(i) + 0.5) / float(count)
		var h: float = height * b.rf(0.82, 1.05)
		b.m(BARK.lerp(ROT, b.rf(0, 1))).cyl(0.16, 0.2, h, x, h * 0.5, b.rf(-0.06, 0.06), 6, b.rf(-3, 3), b.rf(-3, 3))
		b.cyl(0.0, 0.16, 0.4, x, h + 0.2, 0, 6)
		if i % 6 == 0:
			b.m(MOSS).rock(0.35, x, h * b.rf(0.3, 0.8), 0.2, 1.0, 1.4, 0.4)
	for y: float in [0.6, height * 0.72]:
		b.m(ROT.darkened(0.2)).box(length, 0.16, 0.12, 0, y, 0.24).box(length, 0.16, 0.12, 0, y, -0.24)
	return {"core": null, "thickness": 0.5}


## A tangle of roots woven between two trunks. The roots draw down into the mud.
static func gate(frame: EnvBuilder, barrier: EnvBuilder, width: float) -> Dictionary:
	for side: int in [-1, 1]:
		var x: float = (width * 0.5 + 0.55) * side
		frame.m(BARK, false).mesh(MeshKit.lathe(Models.poly([0.8, 0.0, 0.5, 0.5, 0.38, 1.6, 0.3, 3.4, 0.0, 3.9]), 9, 6, 0.2, 0.04), Vector3(x, 0, 0))
		frame.m(MOSS, true).rock(0.45, x, 2.4, 0.2, 1.0, 1.6, 0.5)
	barrier.m(BARK.darkened(0.15), true)
	var strands: int = maxi(int(width / 0.3), 4)
	for i: int in strands:
		var t: float = float(i) / float(strands - 1)
		var x0: float = lerpf(-width * 0.55, width * 0.55, t)
		var x1: float = lerpf(-width * 0.55, width * 0.55, 1.0 - t + barrier.rf(-0.2, 0.2))
		var z: float = barrier.rf(-0.25, 0.25)
		barrier.vary(0.1).tube([x0, 0.0, z, lerpf(x0, x1, 0.35) + barrier.rf(-0.3, 0.3), 1.0, -z, lerpf(x0, x1, 0.7), 2.0, z * 0.5, x1, 3.0, 0.0], [0.13, 0.11, 0.09, 0.05], 5)
	for i: int in 3:
		var y: float = 0.6 + 0.9 * float(i)
		barrier.tube([-width * 0.55, y, 0.1, 0.0, y + barrier.rf(-0.3, 0.3), -0.2, width * 0.55, y, 0.1], [0.1, 0.12, 0.1], 5)
	barrier.m(Color(0.6, 0.85, 0.5), true, 0, 0.0, 0.7)
	for i: int in 5:
		barrier.ball(0.07, barrier.rf(-width * 0.4, width * 0.4), barrier.rf(0.6, 2.4), -0.3, 1, 1, 1, 6)
	return {"height": 3.9, "shift": Vector3(0, -3.3, 0)}
