class_name BiomeSnow
extends RefCounted
## Drifted snowfield: laden pines, dead trees, capped boulders, ice and half-buried ruins.

const SNOW := Color(0.8, 0.84, 0.9)
const SHADE := Color(0.55, 0.63, 0.77)
const ICE := Color(0.5, 0.68, 0.8)
const ROCK := Color(0.3, 0.31, 0.35)
const ROCK_D := Color(0.2, 0.21, 0.25)
const BARK := Color(0.19, 0.15, 0.13)
const PINE := Color(0.1, 0.19, 0.17)
const WOOD := Color(0.29, 0.23, 0.18)
const KINDS: Array[String] = ["pine", "dead_tree", "boulder", "icicles", "ice_patch", "stream", "ruin_wall", "fence", "tracks", "drift"]


static func info() -> Dictionary:
	return {
		"label": "Snowfield", "floor_color": SNOW, "wall_color": ROCK,
		"sky": Color(0.3, 0.35, 0.44), "ambient": Color(0.58, 0.66, 0.84), "ambient_energy": 0.72,
		"sun_color": Color(1.0, 0.92, 0.8), "sun_energy": 0.95, "sun_rotation": Vector3(-27, 42, 0),
		"fog_color": Color(0.58, 0.65, 0.75), "fog_density": 0.007,
		"props": KINDS,
		"scatter": [{"kind": "drift", "weight": 3.0}, {"kind": "boulder", "weight": 2.0}, {"kind": "pine", "weight": 2.0}, {"kind": "dead_tree", "weight": 1.0}, {"kind": "tracks", "weight": 1.0}],
		"stage": [
			["pine", -12, -12, 0], ["pine", -9, -12.5, 40], ["pine", -12.5, -8, 80], ["pine", 10, -12, 10], ["pine", 12.5, -9, 0], ["pine", -12, 6, 30], ["pine", 12, 10, 0],
			["dead_tree", 3, -11, 0], ["dead_tree", -11, 1, 50], ["stream", 2, -3.5, 25], ["stream", 7.2, -1.2, 25], ["ice_patch", -4, 3, 0], ["ice_patch", 10, 4, 60],
			["ruin_wall", -5, -7, 10], ["ruin_wall", -1.5, -7.8, 20], ["icicles", 7, -9, -20], ["fence", -8, 8, 70], ["fence", -7, 10.7, 75], ["boulder", 0, 5, 0], ["boulder", -9, -3, 0],
			["tracks", 2, 10, 20], ["tracks", 4.5, 2.5, 60], ["drift", 5, 12, 0], ["drift", -3, -12, 0],
		],
	}


static func floor_material() -> ShaderMaterial:
	return EnvKit.surface(4, SNOW, SHADE)


static func build(b: EnvBuilder, kind: String) -> Dictionary:
	match kind:
		"pine":
			var h: float = b.rf(3.6, 5.2)
			b.m(BARK).tube([0, 0, 0, b.rf(-0.1, 0.1), h * 0.5, b.rf(-0.1, 0.1), 0, h * 0.95, 0], [0.2, 0.13, 0.03], 6)
			var tiers: int = 5
			for i: int in tiers:
				var t: float = float(i) / float(tiers - 1)
				var y: float = lerpf(h * 0.24, h * 0.86, t)
				var r: float = lerpf(1.35, 0.4, t) * b.rf(0.9, 1.08)
				var skirt: float = lerpf(1.0, 0.6, t)
				b.m(PINE.lightened(0.06 * t)).mesh(MeshKit.lathe(Models.poly([r, y - skirt * 0.35, r * 0.55, y + skirt * 0.15, 0.0, y + skirt * 0.75]), 9, 9, 0.16, 0.0, 0.18), Vector3.ZERO, Vector3(0, b.rf(0, 40), 0))
				b.m(SNOW).mesh(MeshKit.lathe(Models.poly([r * 0.82, y - skirt * 0.2, r * 0.48, y + skirt * 0.2, 0.0, y + skirt * 0.78]), 7, 7, 0.22, 0.0, 0.1), Vector3(b.rf(-0.06, 0.06), 0.05, b.rf(-0.06, 0.06)), Vector3(0, b.rf(0, 50), 0))
			b.m(SHADE).rock(0.7, 0, 0.02, 0, 1.2, 0.18, 1.2)
			return Biomes.meta(0.5, h, true)
		"dead_tree":
			var h: float = b.rf(3.0, 4.2)
			b.bare_tree(h, BARK, 4, 0.17, 0.3, Color(SNOW.r, SNOW.g, SNOW.b, 1.0))
			b.m(SNOW).rock(0.5, 0, 0.03, 0, 1.2, 0.22, 1.2)
			return Biomes.meta(0.35, h, true)
		"boulder":
			var r: float = b.rf(0.6, 1.1)
			b.m(ROCK).rock(r, 0, r * 0.5, 0, 1.2, 0.8, 1.0, b.rf(0, 180))
			b.m(ROCK_D).rock(r * 0.55, r * 0.9, r * 0.3, r * 0.3, 1, 0.8, 1)
			b.m(SNOW).rock(r * 0.86, 0, r * 0.86, 0, 1.2, 0.34, 1.0)
			b.rock(r * 0.5, r * 0.9, r * 0.52, r * 0.3, 1, 0.3, 1)
			b.m(SHADE).rock(r * 1.3, 0, 0.02, 0, 1.2, 0.1, 1.1)
			return Biomes.meta(r * 1.25, r * 1.2, true)
		"icicles":
			# A rock overhang crusted with ice: icicles down the lip, snow on top.
			b.m(ROCK_D).rock(0.8, -0.9, 0.7, 0, 0.9, 1.3, 1.0)
			b.m(ROCK).rock(1.0, 0.1, 1.6, 0, 1.6, 0.5, 1.0).rock(0.6, 1.1, 0.5, 0.2, 0.9, 1.2, 0.9)
			b.m(SNOW).rock(0.95, 0.1, 1.95, 0, 1.6, 0.28, 1.0)
			b.m(ICE, true, 0, 0.9, 0.12)
			for i: int in 9:
				var x: float = -0.9 + 0.25 * float(i) + b.rf(-0.05, 0.05)
				var l: float = b.rf(0.3, 0.95)
				b.cyl(0.07, 0.0, l, x, 1.42 - l * 0.5, -0.62 + b.rf(-0.08, 0.08), 5)
			return Biomes.meta(1.6, 2.2, true)
		"ice_patch":
			b.m(ICE, true, 0, 1.0, 0.05)
			var rim: Array = []
			for i: int in 11:
				var a: float = TAU * float(i) / 11.0
				var r: float = b.rf(1.5, 2.3)
				rim.append_array([cos(a) * r, sin(a) * r * 0.75])
			b.plate(rim, 0.03, Vector3(0, 0.012, 0), Vector3(90, 0, 0))
			b.m(Color(0.85, 0.93, 1.0), true, 0, 1.0, 0.1)
			for i: int in 5:
				var a: float = b.rf(0, 180)
				b.box(b.rf(0.8, 2.0), 0.006, 0.025, b.rf(-0.8, 0.8), 0.03, b.rf(-0.6, 0.6), a)
			b.stones(5, 2.3, 0.15, 0.35, SNOW, SHADE, 0, 0, 0.4)
			return Biomes.meta(2.3, 0.1, false)
		"stream":
			# A length of frozen stream between snow banks; lay several end to end.
			b.m(ICE, true, 0, 1.0, 0.05).plate([-3.0, -0.7, 3.0, -0.8, 3.0, 0.7, 1.0, 0.85, -1.2, 0.6, -3.0, 0.75], 0.03, Vector3(0, 0.012, 0), Vector3(90, 0, 0))
			b.m(Color(0.85, 0.93, 1.0), true, 0, 1.0, 0.1)
			for i: int in 6:
				b.box(b.rf(0.5, 1.4), 0.006, 0.025, b.rf(-2.6, 2.6), 0.03, b.rf(-0.5, 0.5), b.rf(0, 180))
			for side: int in [-1, 1]:
				for i: int in 6:
					var x: float = -2.7 + 1.08 * float(i)
					b.m(SNOW.lerp(SHADE, b.rf(0, 0.4))).rock(b.rf(0.45, 0.7), x, 0.05, (0.95 + b.rf(0, 0.2)) * side, 1.3, 0.4, 0.8)
			b.m(ROCK_D).rock(0.25, -1.4, 0.1, 0.2, 1, 0.7, 1).rock(0.2, 1.7, 0.08, -0.3, 1, 0.7, 1)
			return Biomes.meta(3.2, 0.4, false)
		"ruin_wall":
			var x: float = -1.7
			for i: int in 5:
				var hh: float = [1.9, 1.5, 0.9, 1.2, 0.5][i] * b.rf(0.85, 1.1)
				b.m(ROCK.lerp(ROCK_D, b.rf(0, 0.6))).bev(0.8, hh, 0.7, x, hh * 0.5 - 0.1, b.rf(-0.04, 0.04), 0.05, b.rf(-4, 4))
				b.m(SNOW).rock(0.42, x, hh - 0.1, 0, 1.0, 0.3, 0.9)
				x += 0.84
			b.m(ROCK).bev(0.8, 0.4, 0.6, 2.5, 0.12, 0.8, 0.05, 30, 1.0, 12).bev(0.6, 0.35, 0.5, 1.6, 0.1, 1.2, 0.05, 70)
			b.m(SNOW)
			for i: int in 6:
				b.rock(b.rf(0.5, 0.8), -1.8 + 0.8 * float(i), 0.05, 0.55 + b.rf(-0.1, 0.2), 1.2, 0.5, 1.0)
			return Biomes.meta(2.4, 2.0, true)
		"fence":
			for i: int in 4:
				var x: float = -1.5 + 1.0 * float(i)
				b.m(WOOD).vary().box(0.12, b.rf(1.2, 1.6), 0.12, x, 0.7, 0, b.rf(-8, 8), b.rf(-10, 4), b.rf(-5, 5))
			for i: int in 3:
				b.m(WOOD.darkened(0.15)).vary().box(3.3, 0.16, 0.04, b.rf(-0.1, 0.1), 0.4 + 0.42 * float(i), -0.08, 0, 0, b.rf(-3, 3))
			b.m(SNOW)
			for i: int in 5:
				b.rock(b.rf(0.45, 0.75), -1.6 + 0.8 * float(i), 0.1, 0.5, 1.2, 0.6, 1.0)
			b.box(3.2, 0.06, 0.1, 0, 1.3, -0.08)
			return Biomes.meta(1.8, 1.5, true)
		"tracks":
			b.m(SHADE.darkened(0.25))
			for i: int in 7:
				var z: float = -1.8 + 0.6 * float(i)
				b.ball(0.13, 0.14 if i % 2 == 0 else -0.14, 0.0, z + b.rf(-0.05, 0.05), 0.8, 0.12, 1.5, 6)
			return Biomes.meta(1.9, 0.05, false)
		"drift":
			b.m(SNOW).rock(b.rf(0.9, 1.5), 0, 0.0, 0, 1.4, 0.3, 1.0, b.rf(0, 180), 0.12)
			b.m(SNOW.lerp(SHADE, 0.3)).rock(b.rf(0.5, 0.8), b.rf(0.6, 1.0), 0.0, b.rf(-0.5, 0.5), 1.3, 0.3, 1.0, 0, 0.12)
			return Biomes.meta(1.6, 0.4, false)
	return {}


## A weathered stone wall with snow banked along its top and foot.
static func wall(b: EnvBuilder, length: float, height: float) -> Dictionary:
	b.m(ROCK_D).box(length, 0.3, 1.1, 0, 0.15, 0)
	var count: int = maxi(int(length / 1.1), 2)
	for i: int in count:
		var x: float = -length * 0.5 + length * (float(i) + 0.5) / float(count)
		b.m(SNOW.lerp(SHADE, b.rf(0, 0.3))).rock(b.rf(0.55, 0.8), x, height + 0.02, 0, 1.2, 0.4, 0.85)
		if i % 2 == 0:
			b.rock(b.rf(0.6, 1.0), x, 0.05, 0.75, 1.3, 0.5, 0.9).rock(b.rf(0.6, 1.0), x + 0.5, 0.05, -0.75, 1.3, 0.5, 0.9)
		if i % 5 == 2:
			b.m(ROCK).bev(0.9, height, 1.3, x, height * 0.5, 0, 0.06)
	return {"core": EnvKit.surface(2, ROCK, ROCK_D, Color(0.1, 0.11, 0.14)), "thickness": 0.9}


## A wall of ice shards between two frozen rock piers. The ice sinks into the ground.
static func gate(frame: EnvBuilder, barrier: EnvBuilder, width: float) -> Dictionary:
	for side: int in [-1, 1]:
		var x: float = (width * 0.5 + 0.6) * side
		frame.m(ROCK).rock(0.9, x, 1.1, 0, 0.9, 1.7, 1.0).m(ROCK_D).rock(0.8, x + 0.3 * side, 0.4, 0.2, 1.2, 0.8, 1.2)
		frame.m(SNOW).rock(0.75, x, 2.55, 0, 1.0, 0.35, 1.0)
	barrier.m(ICE, true, 0, 0.95, 0.25)
	var shards: int = maxi(int(width / 0.45), 3)
	for i: int in shards + 1:
		var x: float = -width * 0.5 + width * float(i) / float(shards)
		var h: float = barrier.rf(2.2, 3.3)
		barrier.cyl(0.0, barrier.rf(0.3, 0.45), h, x, h * 0.5, barrier.rf(-0.15, 0.15), 5, barrier.rf(-6, 6), barrier.rf(-8, 8), barrier.rf(0, 72))
	barrier.m(Color(0.75, 0.9, 1.0), true, 0, 0.95, 0.4)
	for i: int in shards:
		var x: float = -width * 0.5 + width * (float(i) + 0.5) / float(shards)
		var h: float = barrier.rf(1.0, 1.8)
		barrier.cyl(0.0, 0.25, h, x, h * 0.5, 0.3, 4, 0, barrier.rf(-12, 12))
	return {"height": 3.3, "shift": Vector3(0, -3.4, 0)}
