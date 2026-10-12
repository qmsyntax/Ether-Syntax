class_name BiomeScrubland
extends RefCounted
## The dry plain the game began on: cracked earth, straw scrub, thorn, dead wood and stone.

const EARTH := Color(0.31, 0.27, 0.2)
const EARTH_D := Color(0.22, 0.19, 0.14)
const STEM := Color(0.2, 0.21, 0.11)
const STRAW := Color(0.52, 0.46, 0.27)
const LEAF := Color(0.19, 0.24, 0.14)
const LEAF_L := Color(0.33, 0.33, 0.18)
const BARK := Color(0.16, 0.12, 0.09)
const ROCK := Color(0.4, 0.36, 0.3)
const ROCK_D := Color(0.27, 0.24, 0.21)
const WOOD := Color(0.33, 0.27, 0.2)
const BONE := Color(0.68, 0.63, 0.5)
const KINDS: Array[String] = ["scrub", "thorn", "dead_tree", "outcrop", "boulder", "fence", "log", "skull", "waystone", "stones"]


static func info() -> Dictionary:
	return {
		"label": "Scrubland", "floor_color": EARTH, "wall_color": ROCK_D,
		"sky": Color(0.03, 0.035, 0.045), "ambient": Color(0.5, 0.56, 0.7), "ambient_energy": 0.6,
		"sun_color": Color(1.0, 0.87, 0.72), "sun_energy": 1.35, "sun_rotation": Vector3(-44, 38, 0),
		"fog_color": Color(0.1, 0.11, 0.14), "fog_density": 0.006,
		"props": KINDS,
		"scatter": [{"kind": "scrub", "weight": 6.0}, {"kind": "thorn", "weight": 2.0}, {"kind": "stones", "weight": 2.0}, {"kind": "boulder", "weight": 1.0}, {"kind": "log", "weight": 0.5}],
		"stage": [
			["outcrop", -11, -11, 0], ["outcrop", 9, -11.5, 40], ["outcrop", -12, 4, 90], ["dead_tree", -5, -9, 0], ["dead_tree", 11, -3, 0], ["dead_tree", -9, 9, 0],
			["fence", 0, -6, 10], ["fence", 3.6, -5.2, 15], ["fence", -3.7, -6.5, 5], ["waystone", -3, 1, 160], ["skull", 3, 3.5, 30], ["log", 9, 9, 40],
			["thorn", -7, -2, 0], ["thorn", 5, -9, 0], ["thorn", 12, 6, 0], ["boulder", -1, 9, 0],
		],
	}


static func floor_material() -> ShaderMaterial:
	return EnvKit.surface(0, EARTH, EARTH_D)


static func build(b: EnvBuilder, kind: String) -> Dictionary:
	match kind:
		"scrub":
			b.m(EARTH_D).rock(0.42, 0, 0.0, 0, 1.2, 0.1, 1.2, 0, 0.1)
			b.tuft(14, b.rf(0.6, 0.85), 0.2, STEM, STRAW, 0, 0, 0.055)
			for i: int in 3:
				var a: float = b.rf(0, TAU)
				var h: float = b.rf(0.55, 0.8)
				var out: float = b.rf(0.05, 0.2)
				b.m(STEM).pole(Vector3.ZERO, Vector3(cos(a) * out, h, sin(a) * out), 0.014, 0.01, 3)
				b.m(Color(0.66, 0.6, 0.42), false).lathe([0.0, -0.06, 0.035, 0.0, 0.0, 0.09], cos(a) * out, h, sin(a) * out, 5)
			return Biomes.meta(0.4, 0.85, false, true)
		"thorn":
			b.m(EARTH_D).rock(0.6, 0, 0.0, 0, 1.2, 0.1, 1.2, 0, 0.1)
			for i: int in 7:
				var a: float = TAU * float(i) / 7.0 + b.rf(-0.3, 0.3)
				var reach: float = b.rf(0.3, 0.55)
				var h: float = b.rf(0.5, 1.0)
				var tip := Vector3(cos(a) * reach, h, sin(a) * reach)
				b.m(BARK).tube([0, 0, 0, tip.x * 0.45, h * 0.5, tip.z * 0.45, tip.x, tip.y, tip.z], [0.05, 0.03, 0.008], 4)
				b.m(LEAF.lerp(LEAF_L, b.rf(0, 1))).rock(b.rf(0.2, 0.3), tip.x * 0.85, tip.y * 0.9, tip.z * 0.85, 1.2, 0.7, 1.0, 0, 0.25)
				b.m(BARK).cyl(0.0, 0.012, 0.12, tip.x, tip.y + 0.03, tip.z, 3, b.rf(-40, 40), b.rf(-40, 40))
			b.m(LEAF).rock(0.3, 0, 0.5, 0, 1.1, 0.75, 1.1, 0, 0.25)
			for i: int in 5:
				var a: float = b.rf(0, TAU)
				b.m(Color(0.5, 0.16, 0.08), false).ball(0.035, cos(a) * 0.4, b.rf(0.4, 0.8), sin(a) * 0.4, 1, 1, 1, 5)
			return Biomes.meta(0.7, 1.1, true, true)
		"dead_tree":
			var h: float = b.rf(3.2, 4.4)
			b.bare_tree(h, BARK, 5, 0.2, 0.35)
			b.m(BARK).pole(Vector3(0, 0.15, 0), Vector3(0.6, 0, 0.3), 0.12, 0.03, 4).pole(Vector3(0, 0.15, 0), Vector3(-0.5, 0, -0.35), 0.12, 0.03, 4).pole(Vector3(0, 0.15, 0), Vector3(-0.2, 0, 0.6), 0.1, 0.03, 4)
			return Biomes.meta(0.4, h, true)
		"outcrop":
			b.m(ROCK).rock(1.5, 0, 0.9, 0, 1.2, 1.0, 0.9, b.rf(0, 180)).m(ROCK_D).rock(1.1, 1.4, 0.5, 0.4, 1.1, 0.8, 1.0).m(ROCK).rock(0.9, -1.3, 0.45, -0.3, 1.2, 0.8, 0.9)
			b.m(ROCK.lightened(0.1)).rock(0.8, 0.3, 1.9, 0, 1.3, 0.5, 1.0)
			b.stones(6, 2.4, 0.15, 0.4, ROCK, ROCK_D)
			b.tuft(8, 0.6, 0.2, STEM, STRAW, 1.9, 1.0, 0.045)
			return Biomes.meta(2.3, 2.3, true)
		"boulder":
			var r: float = b.rf(0.5, 0.95)
			b.m(ROCK).rock(r, 0, r * 0.5, 0, 1.15, 0.85, 1.0, b.rf(0, 180)).m(ROCK_D).rock(r * 0.5, r * 0.85, r * 0.25, r * 0.3, 1, 0.8, 1)
			return Biomes.meta(r * 1.2, r * 1.2, true)
		"fence":
			# What is left of a stock fence: leaning posts, one rail still up, one fallen.
			for i: int in 4:
				var x: float = -1.5 + 1.0 * float(i)
				var h: float = b.rf(0.7, 1.3) if i != 2 else 0.45
				b.m(WOOD).vary(0.12).box(0.11, h, 0.11, x, h * 0.5, 0, b.rf(-10, 10), b.rf(-12, 8), b.rf(-8, 8))
			b.m(WOOD.darkened(0.15)).box(2.1, 0.09, 0.05, -0.45, 0.8, -0.07, 0, 0, 4).box(1.6, 0.09, 0.05, 0.6, 0.12, 0.3, 14, 0, -9)
			b.tuft(6, 0.5, 0.2, STEM, STRAW, -1.5, 0.15, 0.04)
			return Biomes.meta(1.8, 1.3, true)
		"log":
			b.m(BARK, false).cyl(0.22, 0.26, 2.4, 0, 0.24, 0, 8, 90)
			b.m(WOOD.lightened(0.08), true).cyl(0.2, 0.2, 0.02, 0, 0.24, -1.2, 8, 90)
			b.m(BARK).pole(Vector3(0.1, 0.4, 0.3), Vector3(0.5, 0.9, 0.5), 0.07, 0.02, 4).pole(Vector3(-0.1, 0.35, -0.5), Vector3(-0.6, 0.6, -0.7), 0.06, 0.02, 4)
			b.tuft(6, 0.5, 0.15, STEM, STRAW, 0.4, 0.6, 0.04)
			return Biomes.meta(1.3, 0.9, true)
		"skull":
			# A horned beast's skull, half sunk in the dirt, a few ribs beside it.
			b.m(BONE, false).ball(0.24, 0, 0.16, 0, 0.9, 0.8, 1.3, 8).mesh(MeshKit.loft([[0.0, 0.16, 0.12], [0.3, 0.1, 0.08], [0.48, 0.05, 0.05]], 8), Vector3(0, 0.12, -0.2), Vector3(-80, 0, 0))
			b.m(Color(0.05, 0.04, 0.04), false).ball(0.06, 0.13, 0.2, -0.16).ball(0.06, -0.13, 0.2, -0.16)
			for sx: int in [-1, 1]:
				b.m(BONE.darkened(0.12), true).tube([0.16 * sx, 0.28, 0.1, 0.42 * sx, 0.42, 0.16, 0.6 * sx, 0.7, 0.0], [0.06, 0.045, 0.0], 5)
			for i: int in 4:
				var z: float = 0.5 + 0.2 * float(i)
				b.m(BONE, true).tube([-0.3, 0.0, z, -0.2, 0.3, z + 0.03, 0.05, 0.38, z], [0.02, 0.025, 0.012], 4)
			return Biomes.meta(0.7, 0.7, false)
		"waystone":
			b.m(ROCK_D).rock(0.6, 0, 0.1, 0, 1.2, 0.3, 1.2)
			b.m(ROCK).bev(0.5, 1.6, 0.34, 0, 0.9, 0, 0.08, 0, 0.75, 0, b.rf(-6, 6))
			b.m(ROCK_D).box(0.26, 0.04, 0.02, 0, 1.3, -0.17).box(0.04, 0.3, 0.02, 0, 1.2, -0.17).box(0.2, 0.04, 0.02, 0, 1.0, -0.17)
			b.stones(4, 0.7, 0.1, 0.2, ROCK, ROCK_D)
			return Biomes.meta(0.7, 1.75, true)
		"stones":
			b.stones(9, 0.9, 0.08, 0.26, ROCK, ROCK_D)
			return Biomes.meta(1.0, 0.3, false)
	return {}


## A dry-stone wall: a rubble core, tumbled stones at its foot, flat cap stones on top.
static func wall(b: EnvBuilder, length: float, height: float) -> Dictionary:
	var count: int = maxi(int(length / 0.9), 2)
	for i: int in count:
		var x: float = -length * 0.5 + length * (float(i) + 0.5) / float(count)
		b.m(ROCK.lerp(ROCK_D, b.rf(0, 0.7))).rock(b.rf(0.45, 0.6), x, height, 0, 1.2, 0.35, 0.95, b.rf(0, 40), 0.16)
		if i % 2 == 0:
			b.m(ROCK_D).rock(b.rf(0.3, 0.55), x + b.rf(-0.3, 0.3), 0.15, 0.7, 1.0, 0.7, 1.0).rock(b.rf(0.3, 0.55), x + b.rf(-0.3, 0.3), 0.15, -0.7, 1.0, 0.7, 1.0)
		if i % 7 == 3:
			b.tuft(7, 0.7, 0.2, STEM, STRAW, x, 0.85, 0.05)
	return {"core": EnvKit.surface(6, ROCK, ROCK_D, Color(0.08, 0.07, 0.06), 0.28), "thickness": 0.8}


## A barricade of sharpened stakes lashed between two posts. It drops flat into the earth.
static func gate(frame: EnvBuilder, barrier: EnvBuilder, width: float) -> Dictionary:
	for side: int in [-1, 1]:
		var x: float = (width * 0.5 + 0.35) * side
		frame.m(BARK).cyl(0.16, 0.2, 3.0, x, 1.5, 0, 7, 0, 3.0 * side)
		frame.m(ROCK_D).rock(0.5, x, 0.15, 0, 1.2, 0.5, 1.2)
		frame.m(BONE, false).ball(0.16, x, 3.05, 0, 0.9, 0.9, 1.1, 7)
		frame.m(Color(0.48, 0.16, 0.12)).box(0.3, 0.6, 0.02, x, 2.3, -0.2, 0, 0, 6.0 * side)
	barrier.m(WOOD.darkened(0.1))
	barrier.cyl(0.09, 0.09, width + 0.5, 0, 1.0, 0, 6, 0, 90).cyl(0.07, 0.07, width + 0.5, 0, 1.9, 0, 6, 0, 90)
	var stakes: int = maxi(int(width / 0.35), 4)
	for i: int in stakes:
		var x: float = -width * 0.5 + width * (float(i) + 0.5) / float(stakes)
		var tilt: float = -32.0 if i % 2 == 0 else 32.0
		barrier.m(WOOD).vary(0.12).cyl(0.02, 0.08, 2.9, x, 1.25, 0, 5, tilt, barrier.rf(-4, 4))
	barrier.m(Color(0.42, 0.36, 0.24)).ring(0.1, 0.14, -width * 0.25, 1.0, 0, 0, 90).ring(0.1, 0.14, width * 0.25, 1.0, 0, 0, 90)
	barrier.m(Color(0.75, 0.1, 0.06), true, 0, 0.0, 0.5).box(0.44, 0.44, 0.04, 0, 1.45, -0.75, 0, 0, 45)
	return {"height": 3.2, "shift": Vector3(0, -3.0, 0)}
