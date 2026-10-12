class_name BiomeMountain
extends RefCounted
## High pass: stackable cliff pieces, scree, wind-bent trees, rope and cairns.

const ROCK := Color(0.37, 0.35, 0.33)
const ROCK_D := Color(0.24, 0.23, 0.23)
const ROCK_L := Color(0.5, 0.47, 0.42)
const SCRUB := Color(0.27, 0.3, 0.17)
const SCRUB_D := Color(0.17, 0.2, 0.13)
const BARK := Color(0.2, 0.16, 0.12)
const ROPE := Color(0.46, 0.39, 0.25)
const WOOD := Color(0.3, 0.23, 0.16)
const CLOTH := Color(0.42, 0.14, 0.11)
const KINDS: Array[String] = ["cliff_2", "cliff_4", "ledge", "scree", "boulder", "bent_tree", "rope_bridge", "cairn", "cave_mouth", "scrub", "waymarker"]


static func info() -> Dictionary:
	return {
		"label": "High pass", "floor_color": ROCK, "wall_color": ROCK_D,
		"sky": Color(0.27, 0.33, 0.43), "ambient": Color(0.52, 0.58, 0.72), "ambient_energy": 0.6,
		"sun_color": Color(1.0, 0.9, 0.76), "sun_energy": 1.25, "sun_rotation": Vector3(-36, 52, 0),
		"fog_color": Color(0.46, 0.52, 0.6), "fog_density": 0.007,
		"props": KINDS,
		"scatter": [{"kind": "scree", "weight": 3.0}, {"kind": "scrub", "weight": 3.0}, {"kind": "boulder", "weight": 2.0}, {"kind": "bent_tree", "weight": 1.0}],
		"stage": [
			["cliff_4", -12, -12.5, 0], ["cliff_4", -7.5, -13, 0], ["cliff_2", -3, -12.5, 0], ["cliff_4", -13, -7.5, 90], ["cliff_2", -12.5, -3, 90], ["cave_mouth", 4, -12.6, 0],
			["cliff_2", 10.5, -12.5, 0], ["cliff_2", -9, -9, 30], ["ledge", -8.5, -5.5, 20], ["ledge", 1, -8.5, -10],
			["rope_bridge", 2, 2.5, 55], ["cairn", -3.5, 0, 0], ["cairn", 9.5, 9, 0], ["waymarker", -6, 5, 150], ["bent_tree", 9, -7, 0], ["bent_tree", -11.5, 9, 0], ["bent_tree", 12, 1, 0],
			["boulder", 6.5, -5, 0], ["boulder", -1, 10, 0], ["scree", -9.5, -6.5, 0], ["scree", 0, -10, 0], ["scree", 11.5, -9.5, 0],
		],
	}


static func floor_material() -> ShaderMaterial:
	return EnvKit.surface(6, ROCK, ROCK_D, Color(0.1, 0.1, 0.1))


## A cliff piece `w` wide and `h` high with a walkable flat top: stack and butt them together.
static func _cliff(b: EnvBuilder, w: float, h: float, d: float) -> void:
	b.m(ROCK_D).bev(w - 0.5, h - 0.25, d - 0.5, 0, (h - 0.25) * 0.5, 0, 0.12)
	var lumps: int = int(w * h * 0.9)
	for i: int in lumps:
		var x: float = b.rf(-w * 0.5, w * 0.5)
		var y: float = b.rf(0.2, h - 0.35)
		var r: float = b.rf(0.45, 0.9)
		b.m(ROCK.lerp(ROCK_D, b.rf(0, 0.8))).rock(r, x, y, -d * 0.5 + b.rf(-0.1, 0.15), 1.1, b.rf(0.9, 1.6), 0.5)
		if i % 3 == 0:
			b.rock(r * 0.8, x * 0.9, y, d * 0.5, 1.1, 1.3, 0.45)
	for i: int in int(w / 1.1):
		var x: float = -w * 0.5 + 0.55 + 1.1 * float(i)
		b.m(ROCK_L).rock(0.62, x, h - 0.12, -d * 0.42, 1.1, 0.3, 0.8).m(ROCK_D).rock(b.rf(0.35, 0.6), x + b.rf(-0.3, 0.3), 0.15, -d * 0.5 - 0.35, 1.0, 0.7, 1.0)
	for i: int in 3:
		b.m(ROCK_L.lerp(ROCK, b.rf(0, 0.5))).rock(w * 0.36, -w * 0.3 + w * 0.3 * float(i), h - 0.2, b.rf(-0.15, 0.15), 1.25, 0.2, d / (w * 0.6), b.rf(-20, 20), 0.12)


static func build(b: EnvBuilder, kind: String) -> Dictionary:
	match kind:
		"cliff_2":
			_cliff(b, 4.0, 2.0, 2.4)
			return Biomes.meta(2.3, 2.0, true)
		"cliff_4":
			_cliff(b, 4.0, 4.0, 2.4)
			return Biomes.meta(2.3, 4.0, true)
		"ledge":
			b.m(ROCK_L).rock(1.6, 0, 0.42, 0, 1.3, 0.3, 1.0, 0, 0.14).m(ROCK).rock(1.3, 0.2, 0.2, 0.1, 1.3, 0.3, 1.0, 40, 0.2)
			b.stones(5, 1.9, 0.18, 0.4, ROCK, ROCK_D)
			return Biomes.meta(2.0, 0.8, true)
		"scree":
			b.stones(16, 1.4, 0.1, 0.3, ROCK, ROCK_D)
			b.stones(4, 1.0, 0.25, 0.45, ROCK_L, ROCK)
			return Biomes.meta(1.5, 0.4, false)
		"boulder":
			var r: float = b.rf(0.7, 1.3)
			b.m(ROCK).rock(r, 0, r * 0.55, 0, 1.15, 0.9, 1.0, b.rf(0, 180))
			b.m(ROCK_D).rock(r * 0.6, r * 0.8, r * 0.3, r * 0.4, 1, 0.8, 1)
			b.m(SCRUB_D).rock(r * 0.4, -r * 0.6, r * 0.9, 0, 1.2, 0.3, 1.0)
			return Biomes.meta(r * 1.2, r * 1.5, true)
		"bent_tree":
			# Grown sideways by the wind: the whole crown streams off to one side.
			var h: float = b.rf(2.4, 3.4)
			b.m(BARK).tube([0, 0, 0, 0.15, h * 0.35, 0.05, 0.7, h * 0.7, 0.1, 1.6, h * 0.92, 0.1], [0.2, 0.15, 0.1, 0.04], 6)
			for i: int in 5:
				var t: float = b.rf(0.45, 1.0)
				var from := Vector3(lerpf(0.2, 1.6, t), h * lerpf(0.5, 0.92, t), 0.08)
				var tip: Vector3 = from + Vector3(b.rf(0.9, 1.6), b.rf(-0.1, 0.35), b.rf(-0.7, 0.7))
				b.m(BARK).pole(from, tip, 0.06, 0.02, 4)
				b.m(SCRUB.lerp(SCRUB_D, b.rf(0, 1))).rock(b.rf(0.45, 0.7), tip.x, tip.y + 0.1, tip.z, 1.7, 0.4, 1.0, 0, 0.2)
			b.m(BARK).pole(Vector3(0.05, 0.1, 0), Vector3(-0.5, 0.0, 0.3), 0.1, 0.03, 4).pole(Vector3(0.05, 0.1, 0), Vector3(-0.3, 0.0, -0.4), 0.1, 0.03, 4)
			return Biomes.meta(0.4, h, true)
		"rope_bridge":
			# Six metres of sagging plank bridge between two pairs of posts.
			for end: int in [-1, 1]:
				for side: int in [-1, 1]:
					b.m(WOOD).vary().cyl(0.09, 0.11, 1.9, 0.75 * side, 0.95, 3.2 * end, 6, b.rf(-4, 4), b.rf(-4, 4))
					b.m(ROPE).cyl(0.12, 0.12, 0.12, 0.75 * side, 1.5, 3.2 * end, 6)
				b.m(ROCK_D).rock(0.5, 0.9, 0.2, 3.5 * end, 1, 0.7, 1).rock(0.45, -0.9, 0.2, 3.5 * end, 1, 0.7, 1)
			for i: int in 15:
				var t: float = float(i) / 14.0
				var z: float = lerpf(-3.0, 3.0, t)
				var sag: float = 0.35 * sin(t * PI)
				if i == 6:
					continue
				b.m(WOOD).vary(0.14).box(1.3, 0.05, 0.3, b.rf(-0.03, 0.03), 0.55 - sag, z, b.rf(-4, 4), 0, b.rf(-3, 3))
			b.m(ROPE)
			for side: int in [-1, 1]:
				var hand: Array = []
				var foot: Array = []
				for i: int in 9:
					var t: float = float(i) / 8.0
					hand.append_array([0.75 * side, 1.5 - 0.45 * sin(t * PI), lerpf(-3.2, 3.2, t)])
					foot.append_array([0.62 * side, 0.52 - 0.35 * sin(t * PI), lerpf(-3.2, 3.2, t)])
				b.tube(hand, [0.03, 0.03, 0.03, 0.03, 0.03, 0.03, 0.03, 0.03, 0.03], 4).tube(foot, [0.03, 0.03, 0.03, 0.03, 0.03, 0.03, 0.03, 0.03, 0.03], 4)
				for i: int in 7:
					var t: float = (float(i) + 1.0) / 8.0
					b.pole(Vector3(0.75 * side, 1.5 - 0.45 * sin(t * PI), lerpf(-3.2, 3.2, t)), Vector3(0.62 * side, 0.52 - 0.35 * sin(t * PI), lerpf(-3.2, 3.2, t)), 0.015, 0.015, 3)
			return Biomes.meta(3.4, 1.9, false)
		"cairn":
			var y: float = 0.0
			for i: int in 6:
				var r: float = lerpf(0.42, 0.14, float(i) / 5.0) * b.rf(0.9, 1.1)
				b.m(ROCK.lerp(ROCK_L, b.rf(0, 1))).rock(r, b.rf(-0.04, 0.04), y + r * 0.45, b.rf(-0.04, 0.04), 1.2, 0.55, 1.0, b.rf(0, 180), 0.16)
				y += r * 0.82
			b.stones(4, 0.7, 0.1, 0.2, ROCK, ROCK_D)
			return Biomes.meta(0.6, y + 0.1, true)
		"cave_mouth":
			b.m(Color(0.02, 0.02, 0.025), true).plate([-1.3, 0.0, 1.3, 0.0, 1.4, 1.4, 0.8, 2.4, -0.2, 2.7, -1.1, 2.1, -1.45, 1.1], 0.3, Vector3(0, 0, 0.45))
			for side: int in [-1, 1]:
				b.m(ROCK).rock(1.3, 2.2 * side, 1.3, 0.3, 0.9, 1.6, 1.0).m(ROCK_D).rock(1.0, 1.8 * side, 0.5, -0.5, 1.0, 0.9, 0.9)
			b.m(ROCK).rock(1.7, 0, 3.4, 0.4, 1.8, 0.7, 1.0).m(ROCK_L).rock(1.2, 0.6, 4.0, 0.5, 1.6, 0.5, 1.0).m(ROCK_D).rock(1.0, -1.2, 3.0, 0.2, 1.2, 0.6, 1.0)
			b.stones(6, 1.6, 0.15, 0.35, ROCK, ROCK_D, 0, -1.2)
			b.m(ROCK_D).bev(4.6, 3.6, 1.2, 0, 1.8, 1.0, 0.1)
			return Biomes.meta(3.2, 4.4, true)
		"scrub":
			b.m(BARK).pole(Vector3.ZERO, Vector3(0.1, 0.3, 0), 0.05, 0.03, 4)
			for i: int in 5:
				var a: float = TAU * float(i) / 5.0
				b.m(SCRUB.lerp(SCRUB_D, b.rf(0, 1))).rock(b.rf(0.25, 0.4), cos(a) * 0.3, b.rf(0.25, 0.45), sin(a) * 0.3, 1.2, 0.6, 1.0, 0, 0.22)
			b.tuft(7, 0.5, 0.4, SCRUB_D, Color(0.45, 0.42, 0.25), 0, 0, 0.03)
			return Biomes.meta(0.6, 0.7, false, true)
		"waymarker":
			# A standing stone with a carved niche, an offering bowl and weathered prayer strips.
			b.m(ROCK_D).rock(0.75, 0, 0.15, 0, 1.2, 0.35, 1.2)
			b.m(ROCK).bev(0.7, 2.0, 0.5, 0, 1.2, 0, 0.1, 0, 0.72)
			b.m(Color(0.05, 0.05, 0.06)).bev(0.34, 0.5, 0.1, 0, 1.45, -0.24, 0.05)
			b.m(ROCK_L).bev(0.5, 0.08, 0.3, 0, 1.12, -0.28, 0.02).lathe([0.05, 0.0, 0.12, 0.04, 0.14, 0.1, 0.12, 0.1, 0.08, 0.05], 0, 1.16, -0.3, 8)
			b.m(Color(1.0, 0.75, 0.4), false, 0, 0.0, 0.8).ball(0.035, 0, 1.24, -0.3)
			b.m(ROPE).tube([-0.36, 2.0, 0, 0.0, 1.9, -0.3, 0.36, 2.0, 0], [0.015, 0.015, 0.015], 3)
			for i: int in 5:
				var x: float = -0.28 + 0.14 * float(i)
				b.m([CLOTH, Color(0.5, 0.45, 0.32), Color(0.2, 0.28, 0.33)][i % 3]).box(0.09, b.rf(0.25, 0.45), 0.01, x, 1.76 - 0.1 * (1.0 - absf(x) / 0.3), -0.2 - 0.1 * (1.0 - absf(x) / 0.3), b.rf(-10, 10), b.rf(-10, 5))
			return Biomes.meta(0.9, 2.25, true)
	return {}


## A cliff face: a rock core faced with outcrops, rubble at the foot, slabs along the top.
static func wall(b: EnvBuilder, length: float, height: float) -> Dictionary:
	var count: int = maxi(int(length / 1.5), 2)
	for i: int in count:
		var x: float = -length * 0.5 + length * (float(i) + 0.5) / float(count)
		for side: int in [-1, 1]:
			b.m(ROCK.lerp(ROCK_D, b.rf(0, 0.8))).rock(b.rf(0.8, 1.2), x + b.rf(-0.3, 0.3), b.rf(0.6, height - 0.6), 0.55 * side, 1.2, b.rf(1.2, 2.0), 0.5)
			b.m(ROCK_D).rock(b.rf(0.4, 0.7), x + b.rf(-0.4, 0.4), 0.15, 1.0 * side, 1.0, 0.7, 1.0)
		b.m(ROCK_L).rock(0.9, x, height, 0, 1.2, 0.3, 0.9)
	return {"core": EnvKit.surface(6, ROCK, ROCK_D, Color(0.1, 0.1, 0.1)), "thickness": 1.1}


## A rockfall choking the gap between two crags. It drops away.
static func gate(frame: EnvBuilder, barrier: EnvBuilder, width: float) -> Dictionary:
	for side: int in [-1, 1]:
		var x: float = (width * 0.5 + 0.8) * side
		frame.m(ROCK).rock(1.1, x, 1.3, 0, 0.9, 1.8, 1.0).m(ROCK_D).rock(0.9, x + 0.4 * side, 0.5, 0.3, 1.2, 0.9, 1.1).m(ROCK_L).rock(0.7, x, 3.0, 0, 1.1, 0.5, 1.0)
	var rows: int = 4
	for row: int in rows:
		var per: int = maxi(int(width / 0.8) - row, 2)
		for i: int in per:
			var x: float = lerpf(-width * 0.5 + 0.3, width * 0.5 - 0.3, (float(i) + 0.5) / float(per)) + barrier.rf(-0.15, 0.15)
			var r: float = barrier.rf(0.5, 0.72)
			barrier.m(ROCK.lerp(ROCK_D, barrier.rf(0, 1))).rock(r, x, 0.4 + 0.68 * float(row), barrier.rf(-0.2, 0.2), 1.0, 0.85, 1.0, barrier.rf(0, 180))
	barrier.stones(8, width * 0.5, 0.15, 0.3, ROCK_L, ROCK, 0, -0.9)
	barrier.m(WOOD).pole(Vector3(-width * 0.3, 0.2, -0.6), Vector3(width * 0.2, 2.6, 0.1), 0.09, 0.07, 5)
	barrier.m(Color(0.75, 0.1, 0.06), true, 0, 0.0, 0.5).box(0.5, 0.36, 0.03, width * 0.2, 2.5, -0.02, 0, 0, 8)
	return {"height": 3.4, "shift": Vector3(0, -3.2, 0)}
