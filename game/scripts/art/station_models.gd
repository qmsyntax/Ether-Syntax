class_name StationModels
extends RefCounted
## The crafting stations in town (design/12): a forge, a tanning yard (vats and a drying frame) and a
## rendering block (a chopping block under a hook rail). Procedural, from primitive meshes, in the
## grounded palette of the city kit; original designs. Origin on the ground at the middle of the
## station, its working side facing +Z. Gameplay size (the collider) comes from data/town.json.

const STONE := Color(0.33, 0.31, 0.29)
const STONE_D := Color(0.2, 0.19, 0.19)
const WOOD := Color(0.3, 0.21, 0.13)
const WOOD_D := Color(0.18, 0.12, 0.08)
const IRON := Color(0.12, 0.12, 0.13)
const HIDE := Color(0.46, 0.33, 0.22)
const LIQUOR := Color(0.13, 0.07, 0.03)
const TALLOW := Color(0.78, 0.72, 0.56)
const EMBER := Color(1.0, 0.42, 0.12)


static func build(kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Station_" + kind
	match kind:
		"forge":
			_forge(root)
		"leatherworks":
			_tannery(root)
		"flensing_yard":
			_rendering(root)
	return root


static func _mat(c: Color, rough: float = 0.85, metal: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


static func _box(root: Node3D, size: Vector3, at: Vector3, m: Material, yaw: float = 0.0, roll: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = at
	mi.rotation_degrees = Vector3(0.0, yaw, roll)
	root.add_child(mi)
	return mi


static func _cyl(root: Node3D, r_top: float, r_bottom: float, h: float, at: Vector3, m: Material, sides: int = 14) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bottom
	c.height = h
	c.radial_segments = sides
	mi.mesh = c
	mi.material_override = m
	mi.position = at
	root.add_child(mi)
	return mi


static func _light(root: Node3D, at: Vector3, color: Color, energy: float, reach: float) -> void:
	var l := OmniLight3D.new()
	l.position = at
	l.light_color = color
	l.light_energy = energy
	l.omni_range = reach
	l.shadow_enabled = false
	root.add_child(l)


## A stone hearth with a bed of coals, a hood and chimney over it, an anvil on a stump in front
## to one side, and a quench trough on the other.
static func _forge(root: Node3D) -> void:
	var stone := _mat(STONE)
	var dark := _mat(STONE_D)
	_box(root, Vector3(2.4, 0.95, 1.5), Vector3(0, 0.475, -0.3), stone)
	_box(root, Vector3(2.5, 0.08, 1.6), Vector3(0, 0.99, -0.3), dark)
	_box(root, Vector3(1.3, 0.12, 0.8), Vector3(0, 1.04, -0.25), _mat(EMBER, 0.6, 0.0, 3.0))
	for x: float in [-0.45, 0.0, 0.45]:
		_box(root, Vector3(0.28, 0.1, 0.22), Vector3(x, 1.12, -0.25 + x * 0.3), _mat(Color(0.08, 0.06, 0.05)), x * 40.0)
	# the hood and the chimney
	_box(root, Vector3(2.2, 0.5, 1.3), Vector3(0, 2.15, -0.4), dark)
	_box(root, Vector3(1.6, 0.5, 1.0), Vector3(0, 2.6, -0.5), dark)
	_box(root, Vector3(0.9, 1.6, 0.8), Vector3(0, 3.6, -0.6), stone)
	for x: float in [-1.0, 1.0]:
		_box(root, Vector3(0.2, 1.1, 0.2), Vector3(x, 1.5, 0.1), _mat(WOOD_D))
	# anvil on a stump
	_cyl(root, 0.32, 0.36, 0.55, Vector3(1.75, 0.275, 0.75), _mat(WOOD))
	_box(root, Vector3(0.55, 0.22, 0.26), Vector3(1.75, 0.66, 0.75), _mat(IRON, 0.4, 0.8))
	_box(root, Vector3(0.24, 0.12, 0.18), Vector3(1.75, 0.5, 0.75), _mat(IRON, 0.4, 0.8))
	var horn := _cyl(root, 0.0, 0.1, 0.32, Vector3(2.12, 0.68, 0.75), _mat(IRON, 0.4, 0.8), 8)
	horn.rotation_degrees.z = 90.0
	# a quench trough
	_box(root, Vector3(1.0, 0.5, 0.5), Vector3(-1.7, 0.25, 0.7), _mat(WOOD))
	_box(root, Vector3(0.88, 0.04, 0.38), Vector3(-1.7, 0.47, 0.7), _mat(Color(0.06, 0.07, 0.08), 0.1))
	_light(root, Vector3(0, 1.5, 0.3), EMBER, 2.6, 6.0)


## Two tanning vats, dark with liquor, and a drying frame with a hide stretched on it.
static func _tannery(root: Node3D) -> void:
	var wood := _mat(WOOD)
	for x: float in [-1.0, 0.35]:
		_cyl(root, 0.62, 0.55, 0.9, Vector3(x, 0.45, 0.2), wood, 16)
		_cyl(root, 0.57, 0.57, 0.02, Vector3(x, 0.86, 0.2), _mat(LIQUOR, 0.15), 16)
		for y: float in [0.2, 0.7]:
			_cyl(root, 0.6 + (y - 0.2) * 0.05, 0.6 + (y - 0.2) * 0.05, 0.05, Vector3(x, y, 0.2), _mat(IRON, 0.5, 0.6), 16)
	# a paddle left across a vat
	_box(root, Vector3(1.3, 0.05, 0.1), Vector3(-0.9, 0.95, 0.25), _mat(WOOD_D), 25.0)
	# the drying frame
	var post := _mat(WOOD_D)
	for x: float in [-1.4, 1.4]:
		_box(root, Vector3(0.14, 2.3, 0.14), Vector3(x, 1.15, -0.8), post)
	_box(root, Vector3(3.0, 0.14, 0.14), Vector3(0, 2.25, -0.8), post)
	_box(root, Vector3(1.3, 1.5, 0.04), Vector3(-0.55, 1.35, -0.8), _mat(HIDE, 0.9), 0.0, 3.0)
	_box(root, Vector3(0.9, 1.1, 0.04), Vector3(0.75, 1.55, -0.8), _mat(HIDE.darkened(0.25), 0.9), 0.0, -4.0)


## A great chopping block with a cleaver in it, a hook rail with a hide and a haunch on it, and a
## tub of rendered tallow.
static func _rendering(root: Node3D) -> void:
	_cyl(root, 0.55, 0.6, 0.85, Vector3(0, 0.425, 0.3), _mat(WOOD), 16)
	_cyl(root, 0.56, 0.56, 0.02, Vector3(0, 0.86, 0.3), _mat(Color(0.38, 0.2, 0.14)), 16)
	_box(root, Vector3(0.36, 0.2, 0.03), Vector3(0.1, 0.98, 0.3), _mat(IRON, 0.35, 0.8), 30.0, 0.0)
	_box(root, Vector3(0.05, 0.05, 0.22), Vector3(0.22, 1.08, 0.38), _mat(WOOD_D), 30.0)
	var post := _mat(WOOD_D)
	for x: float in [-1.3, 1.3]:
		_box(root, Vector3(0.16, 2.4, 0.16), Vector3(x, 1.2, -0.7), post)
	_box(root, Vector3(2.8, 0.12, 0.12), Vector3(0, 2.35, -0.7), _mat(IRON, 0.5, 0.6))
	for x: float in [-0.7, 0.0, 0.7]:
		_box(root, Vector3(0.03, 0.25, 0.03), Vector3(x, 2.18, -0.7), _mat(IRON, 0.4, 0.8))
	_box(root, Vector3(0.8, 1.3, 0.05), Vector3(-0.7, 1.4, -0.7), _mat(HIDE, 0.9), 0.0, 4.0)
	_cyl(root, 0.18, 0.24, 0.8, Vector3(0.0, 1.65, -0.7), _mat(Color(0.5, 0.2, 0.16), 0.7), 10)
	_cyl(root, 0.38, 0.32, 0.5, Vector3(1.3, 0.25, 0.4), _mat(WOOD), 14)
	_cyl(root, 0.35, 0.35, 0.02, Vector3(1.3, 0.49, 0.4), _mat(TALLOW, 0.5), 14)
