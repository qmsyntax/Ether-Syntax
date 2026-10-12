class_name BiomeDungeon
extends RefCounted
## Worked-stone interior: flagstones, block walls, pillars, iron and fire.

const STONE := Color(0.33, 0.32, 0.31)
const STONE_D := Color(0.21, 0.2, 0.2)
const STONE_L := Color(0.44, 0.43, 0.4)
const IRON := Color(0.11, 0.11, 0.13)
const WOOD := Color(0.27, 0.19, 0.12)
const BONE := Color(0.66, 0.62, 0.5)
const FLAME := Color(1.0, 0.55, 0.15)
const KINDS: Array[String] = ["pillar", "pillar_broken", "arch", "sconce", "brazier", "rubble", "bones", "chains", "crate", "barrel", "statue", "stairs", "sarcophagus"]


static func info() -> Dictionary:
	return {
		"label": "Dungeon", "floor_color": STONE, "wall_color": STONE_D,
		"sky": Color(0.012, 0.012, 0.016), "ambient": Color(0.42, 0.46, 0.6), "ambient_energy": 0.5,
		"sun_color": Color(0.75, 0.8, 1.0), "sun_energy": 0.55, "sun_rotation": Vector3(-58, 30, 0),
		"fog_color": Color(0.05, 0.05, 0.07), "fog_density": 0.012,
		"props": KINDS,
		"scatter": [{"kind": "rubble", "weight": 3.0}, {"kind": "bones", "weight": 2.0}, {"kind": "crate", "weight": 1.0}, {"kind": "barrel", "weight": 1.0}],
		"stage": [
			["pillar", -9, -9, 0], ["pillar", -3, -9, 0], ["pillar", 3, -9, 0], ["pillar_broken", 9, -9, 0], ["pillar", -9, -3, 0], ["pillar", -9, 3, 0],
			["arch", 0, -12.5, 0], ["sconce", -6, -13, 0], ["sconce", 6, -13, 0], ["sconce", -13, -6, 90], ["brazier", -2.5, 1.5, 0], ["brazier", 9, 8, 0],
			["statue", -11.5, -11.5, 45], ["sarcophagus", 5, -4, 20], ["sarcophagus", 9, -4.5, -8], ["stairs", -12, 9, 90], ["chains", -13, 0, 90], ["chains", 11, -13, 0],
			["crate", -5, 6, 15], ["crate", -6.2, 7, 50], ["barrel", -4, 7.5, 0], ["barrel", 12, 2, 0], ["rubble", 8, -8, 0], ["rubble", 2, 9, 60], ["bones", 4, 2, 0], ["bones", -1, -5, 120], ["bones", 10, 11, 40],
		],
	}


static func floor_material() -> ShaderMaterial:
	return EnvKit.surface(1, STONE, STONE_D, Color(0.07, 0.07, 0.07))


static func build(b: EnvBuilder, kind: String) -> Dictionary:
	match kind:
		"pillar":
			b.m(STONE_D).bev(1.0, 0.25, 1.0, 0, 0.125, 0, 0.04)
			b.m(STONE).bev(0.82, 0.2, 0.82, 0, 0.35, 0, 0.05)
			b.lathe([0.34, 0.45, 0.31, 0.7, 0.3, 2.5, 0.33, 2.7], 0, 0, 0, 8)
			b.m(STONE_L).lathe([0.36, 0.5, 0.38, 0.55, 0.36, 0.6], 0, 0, 0, 8)
			b.m(STONE).bev(0.84, 0.22, 0.84, 0, 2.81, 0, 0.05, 0, 0.8, 180)
			b.m(STONE_D).bev(1.0, 0.2, 1.0, 0, 3.02, 0, 0.04)
			return Biomes.meta(0.55, 3.12, true)
		"pillar_broken":
			b.m(STONE_D).bev(1.0, 0.25, 1.0, 0, 0.125, 0, 0.04)
			b.m(STONE).bev(0.82, 0.2, 0.82, 0, 0.35, 0, 0.05)
			b.lathe([0.34, 0.45, 0.31, 0.7, 0.3, 1.2 + b.rf(0.0, 0.5)], 0, 0, 0, 8)
			b.m(STONE_L).rock(0.3, 0.02, 1.55, 0.0, 1.0, 0.7, 1.0)
			b.m(STONE).cyl(0.3, 0.3, 0.7, 0.9, 0.3, 0.5, 8, 90, 0, b.rf(0, 180))
			b.cyl(0.3, 0.31, 0.5, -0.6, 0.25, 0.9, 8, 8, 0)
			for i: int in 5:
				b.m(STONE_D).vary().rock(b.rf(0.1, 0.22), b.rf(-1.1, 1.1), 0.08, b.rf(-1.0, 1.1), 1, 0.7, 1)
			return Biomes.meta(1.2, 1.9, true)
		"arch":
			for side: int in [-1, 1]:
				b.m(STONE_D).bev(0.9, 0.3, 0.9, 1.5 * side, 0.15, 0, 0.04)
				b.m(STONE).bev(0.7, 2.3, 0.7, 1.5 * side, 1.45, 0, 0.04)
				b.m(STONE_L).bev(0.84, 0.18, 0.84, 1.5 * side, 2.69, 0, 0.04)
			for i: int in 9:
				var a: float = PI * (float(i) + 0.5) / 9.0
				b.m(STONE if i % 2 == 0 else STONE_L).bev(0.56, 0.5 if i != 4 else 0.62, 0.72, cos(a) * 1.5, 2.78 + sin(a) * 1.5, 0, 0.03, 0, 1.0, 0, rad_to_deg(a) - 90.0)
			return Biomes.meta(2.0, 4.6, false)
		"sconce":
			b.m(IRON, true, ModelRig.METAL, 0.7)
			for i: int in 3:
				var a: float = TAU * float(i) / 3.0
				b.pole(Vector3(cos(a) * 0.28, 0, sin(a) * 0.28), Vector3(0, 0.5, 0), 0.025, 0.03)
			b.cyl(0.03, 0.035, 1.2, 0, 1.0, 0, 6)
			b.lathe([0.05, 1.55, 0.16, 1.62, 0.2, 1.8, 0.18, 1.82, 0.14, 1.66, 0.04, 1.6], 0, 0, 0, 8)
			b.ring(0.19, 0.22, 0, 1.8, 0)
			_fire(b, Vector3(0, 1.78, 0), 0.6)
			return Biomes.meta(0.3, 2.2, true, false, Vector3(0, 2.0, 0))
		"brazier":
			b.m(IRON, true, ModelRig.METAL, 0.7)
			for i: int in 3:
				var a: float = TAU * float(i) / 3.0 + 0.3
				b.pole(Vector3(cos(a) * 0.42, 0, sin(a) * 0.42), Vector3(cos(a) * 0.22, 0.7, sin(a) * 0.22), 0.035, 0.03)
			b.lathe([0.1, 0.62, 0.36, 0.72, 0.46, 0.95, 0.42, 0.97, 0.33, 0.78, 0.08, 0.7], 0, 0, 0, 10)
			b.ring(0.43, 0.48, 0, 0.96, 0)
			b.m(Color(0.16, 0.08, 0.05)).rock(0.3, 0, 0.86, 0, 1.0, 0.35, 1.0)
			b.m(Color(1.0, 0.3, 0.08), true, 0, 0.0, 0.9).rock(0.2, 0.05, 0.9, 0.03, 1.0, 0.35, 1.0)
			_fire(b, Vector3(0, 0.92, 0), 1.0)
			return Biomes.meta(0.5, 1.6, true, false, Vector3(0, 1.4, 0))
		"rubble":
			for i: int in 9:
				var r: float = b.rf(0.12, 0.34)
				b.m(STONE.lerp(STONE_D, b.rf(0, 1))).rock(r, b.rf(-0.7, 0.7), r * 0.45, b.rf(-0.7, 0.7), 1.0, 0.7, 1.0, b.rf(0, 180))
			for i: int in 3:
				b.m(STONE_L).vary().bev(b.rf(0.3, 0.5), 0.22, b.rf(0.2, 0.35), b.rf(-0.6, 0.6), 0.12, b.rf(-0.6, 0.6), 0.03, b.rf(0, 180), 1.0, b.rf(-15, 15))
			return Biomes.meta(0.9, 0.5, false)
		"bones":
			b.m(BONE, false).ball(0.11, 0.2, 0.1, 0.1, 0.9, 0.95, 1.1)
			b.m(BONE.darkened(0.15), true).box(0.1, 0.06, 0.1, 0.2, 0.03, 0.02)
			b.m(Color(0.05, 0.04, 0.04), false).ball(0.03, 0.16, 0.12, 0.01).ball(0.03, 0.24, 0.12, 0.01)
			for i: int in 5:
				var z: float = -0.25 + 0.09 * float(i)
				b.m(BONE, false).tube([-0.42, 0.02, z, -0.38, 0.2, z + 0.02, -0.25, 0.26, z, -0.12, 0.2, z - 0.02, -0.08, 0.02, z], [0.012, 0.016, 0.016, 0.016, 0.012], 4)
			b.pole(Vector3(-0.25, 0.03, -0.3), Vector3(-0.25, 0.03, 0.2), 0.02, 0.02, 4)
			for i: int in 3:
				var a: float = b.rf(0, TAU)
				var c := Vector3(b.rf(-0.3, 0.5), 0.03, b.rf(0.25, 0.6))
				var d := Vector3(cos(a), 0, sin(a)) * 0.22
				b.pole(c - d, c + d, 0.022, 0.022, 5)
				b.ball(0.035, c.x - d.x, 0.03, c.z - d.z).ball(0.035, c.x + d.x, 0.03, c.z + d.z)
			return Biomes.meta(0.6, 0.3, false)
		"chains":
			b.m(STONE_D).bev(0.5, 0.3, 0.5, 0, 0.15, 0, 0.04)
			b.m(WOOD).box(0.18, 2.5, 0.18, 0, 1.5, 0).box(0.14, 0.14, 1.5, 0, 2.6, -0.55)
			b.pole(Vector3(0, 1.9, -0.05), Vector3(0, 2.55, -0.7), 0.05, 0.05, 4)
			b.m(IRON, true, ModelRig.METAL, 0.7)
			for i: int in 3:
				var z: float = -0.35 - 0.38 * float(i)
				var drop: float = b.rf(0.7, 1.5)
				var links: int = int(drop / 0.11)
				for k: int in links:
					b.mesh(Models.torus(0.022, 0.04, 6, 4), Vector3(0, 2.5 - 0.11 * float(k), z), Vector3(90, 0 if k % 2 == 0 else 90, 0))
				b.ring(0.06, 0.09, 0, 2.44 - drop, z, 90, 0, 8)
			return Biomes.meta(0.35, 2.7, true)
		"crate":
			_crate(b, Vector3(0, 0, 0), 0.9, b.rf(-6, 6))
			if b.rng.randf() < 0.5:
				_crate(b, Vector3(b.rf(-0.1, 0.1), 0.9, b.rf(-0.1, 0.1)), 0.66, b.rf(10, 40))
				return Biomes.meta(0.65, 1.56, true, true)
			return Biomes.meta(0.65, 0.9, true, true)
		"barrel":
			b.m(WOOD, false).lathe([0.3, 0.0, 0.37, 0.25, 0.39, 0.5, 0.37, 0.75, 0.3, 1.0], 0, 0, 0, 12)
			b.m(WOOD.darkened(0.3)).cyl(0.28, 0.28, 0.02, 0, 0.97, 0, 12)
			b.m(IRON, false, ModelRig.METAL, 0.7)
			for y: float in [0.14, 0.5, 0.86]:
				var rr: float = 0.345 if y != 0.5 else 0.395
				b.lathe([rr, y - 0.03, rr + 0.012, y, rr, y + 0.03], 0, 0, 0, 12)
			return Biomes.meta(0.42, 1.0, true, true)
		"statue":
			b.m(STONE_D).bev(1.3, 0.35, 1.3, 0, 0.175, 0, 0.05)
			b.m(STONE).bev(1.05, 0.5, 1.05, 0, 0.6, 0, 0.05).bev(1.15, 0.12, 1.15, 0, 0.9, 0, 0.03)
			# A robed, headless figure, one arm gone, leaning on a snapped blade.
			b.m(STONE_L, false).mesh(MeshKit.lathe(Models.poly([0.42, 0.96, 0.36, 1.3, 0.27, 1.75, 0.24, 2.0]), 14, 9, 0.12, 0.03), Vector3.ZERO)
			b.mesh(MeshKit.loft([[2.0, 0.26, 0.17], [2.25, 0.33, 0.2], [2.5, 0.36, 0.19], [2.62, 0.2, 0.14], [2.68, 0.1, 0.1]], 12), Vector3.ZERO)
			b.m(STONE, true).rock(0.11, 0.0, 2.7, 0.0, 1.0, 0.6, 1.0)
			b.m(STONE_L, false).tube([-0.36, 2.5, 0, -0.44, 2.2, -0.05, -0.4, 1.9, -0.2, -0.3, 1.72, -0.34], [0.1, 0.09, 0.075, 0.07], 7)
			b.tube([0.36, 2.5, 0, 0.47, 2.3, 0.0], [0.1, 0.085], 7)
			b.m(STONE, true).rock(0.09, 0.49, 2.26, 0.0)
			b.m(STONE_D, true).box(0.1, 0.9, 0.035, -0.28, 1.3, -0.38, 0, 6).box(0.34, 0.06, 0.06, -0.28, 1.74, -0.36)
			b.plate([-0.05, 0.0, 0.05, 0.0, 0.03, 0.1, -0.01, 0.07, -0.05, 0.14], 0.035, Vector3(-0.28, 0.84, -0.42))
			# The head lies where it fell.
			b.m(STONE_L, false).ball(0.2, 0.95, 0.19, 0.75, 0.9, 1.0, 1.05, 10)
			b.m(STONE, true).bev(0.2, 0.1, 0.16, 0.95, 0.07, 0.62, 0.03)
			b.m(STONE_D).rock(0.14, 0.6, 0.07, 1.0, 1, 0.6, 1).rock(0.1, 1.25, 0.05, 0.5, 1, 0.6, 1)
			return Biomes.meta(1.0, 2.8, true)
		"stairs":
			for i: int in 6:
				b.m(STONE if i % 2 == 0 else STONE_L).bev(2.0, 0.2 * float(i + 1), 0.42, 0, 0.1 * float(i + 1), 1.05 - 0.42 * float(i), 0.02)
			for side: int in [-1, 1]:
				b.m(STONE_D).bev(0.3, 1.5, 2.7, 1.15 * side, 0.75, 0, 0.04)
				b.m(STONE).bev(0.4, 0.14, 2.8, 1.15 * side, 1.56, 0, 0.03)
			return Biomes.meta(1.7, 1.63, true)
		"sarcophagus":
			b.m(STONE_D).bev(1.15, 0.2, 2.5, 0, 0.1, 0, 0.04)
			b.m(STONE).bev(0.95, 0.62, 2.3, 0, 0.5, 0, 0.04, 0, 0.94)
			b.m(STONE_D).box(0.99, 0.08, 2.34, 0, 0.56, 0)
			var skew: float = b.rf(-9, 9)
			b.m(STONE_L).bev(1.08, 0.14, 2.42, b.rf(-0.1, 0.1), 0.88, 0, 0.03, skew)
			b.m(STONE).bev(0.6, 0.12, 1.9, 0, 1.0, 0, 0.05, skew, 0.6)
			b.m(STONE_L).bev(0.16, 0.08, 1.2, 0, 1.08, 0, 0.02, skew).bev(0.5, 0.08, 0.16, 0, 1.08, -0.3, 0.02, skew)
			return Biomes.meta(1.3, 1.12, true)
	return {}


static func _fire(b: EnvBuilder, at: Vector3, size: float) -> void:
	b.m(FLAME, false, 0, 0.0, 1.6)
	for i: int in 4:
		var a: float = TAU * float(i) / 4.0
		var r: float = 0.08 * size
		b.cyl(0.0, 0.07 * size, b.rf(0.22, 0.4) * size, at.x + cos(a) * r, at.y + 0.14 * size, at.z + sin(a) * r, 5, b.rf(-10, 10), b.rf(-10, 10))
	b.m(Color(1.0, 0.85, 0.45), false, 0, 0.0, 2.2).cyl(0.0, 0.06 * size, 0.3 * size, at.x, at.y + 0.13 * size, at.z, 5)


static func _crate(b: EnvBuilder, at: Vector3, s: float, ry: float) -> void:
	b.m(WOOD).vary(0.1).box(s, s, s, at.x, at.y + s * 0.5, at.z, ry)
	b.m(WOOD.darkened(0.25))
	var basis := Basis(Vector3.UP, deg_to_rad(ry))
	for sx: int in [-1, 1]:
		for sz: int in [-1, 1]:
			var c: Vector3 = at + basis * Vector3(s * 0.48 * sx, s * 0.5, s * 0.48 * sz)
			b.box(0.08, s * 1.04, 0.08, c.x, c.y, c.z, ry)
	for y: float in [0.06, 0.94]:
		b.box(s * 1.04, 0.07, s * 1.04, at.x, at.y + s * y, at.z, ry)
	b.m(BiomeDungeon.IRON, true, ModelRig.METAL, 0.6).box(s * 1.05, 0.03, 0.1, at.x, at.y + s * 0.5, at.z, ry).box(0.1, 0.03, s * 1.05, at.x, at.y + s * 0.5, at.z, ry)


## Trim for a block wall: plinth, capping course and a buttress every four metres.
static func wall(b: EnvBuilder, length: float, height: float) -> Dictionary:
	b.m(STONE_D).box(length, 0.35, 1.06, 0, 0.175, 0)
	b.m(STONE).box(length, 0.22, 1.0, 0, height - 0.11, 0)
	b.m(STONE_L).box(length, 0.1, 1.1, 0, height + 0.05, 0)
	var count: int = maxi(int(length / 4.0), 1)
	for i: int in count + 1:
		var x: float = -length * 0.5 + length * float(i) / float(count)
		b.m(STONE).bev(0.7, height, 1.2, x, height * 0.5, 0, 0.05).m(STONE_D).bev(0.86, 0.5, 1.34, x, 0.25, 0, 0.05)
		b.m(STONE_L).bev(0.84, 0.2, 1.32, x, height + 0.1, 0, 0.04)
	return {"core": EnvKit.surface(2, STONE, STONE_D, Color(0.06, 0.06, 0.06)), "thickness": 0.8}


## A portcullis in a stone frame. The barrier rises into the lintel.
static func gate(frame: EnvBuilder, barrier: EnvBuilder, width: float) -> Dictionary:
	var h: float = 3.2
	for side: int in [-1, 1]:
		var x: float = (width * 0.5 + 0.45) * side
		frame.m(STONE_D).bev(1.1, 0.4, 1.3, x, 0.2, 0, 0.05)
		frame.m(STONE).bev(0.9, h, 1.1, x, h * 0.5 + 0.2, 0, 0.05)
	frame.m(STONE).bev(width + 2.0, 0.7, 1.2, 0, h + 0.55, 0, 0.05)
	frame.m(STONE_L).bev(width + 2.3, 0.18, 1.34, 0, h + 0.99, 0, 0.04)
	barrier.m(IRON, true, ModelRig.METAL, 0.75)
	var bars: int = maxi(int(width / 0.36), 2)
	for i: int in bars + 1:
		var x: float = -width * 0.5 + width * float(i) / float(bars)
		barrier.box(0.07, h, 0.07, x, h * 0.5 + 0.12, 0, 45)
		barrier.cyl(0.0, 0.05, 0.16, x, 0.07, 0, 4, 180)
	for y: float in [0.5, 1.3, 2.1, 2.9]:
		barrier.box(width + 0.1, 0.09, 0.045, 0, y, 0)
	barrier.m(Color(0.75, 0.1, 0.06), true, 0, 0.0, 0.5).box(0.5, 0.5, 0.06, 0, 1.7, 0, 0, 0, 45)
	return {"height": h + 1.1, "shift": Vector3(0, h + 0.1, 0)}
