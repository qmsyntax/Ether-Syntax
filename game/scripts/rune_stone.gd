class_name RuneStone
extends Node3D
## A rune stone (Brent 2026-10-23, design/14 section 8): an old carved stone in a zone or the
## passage. Read it with interact and it reveals one rune, once per character
## (Player.read_inscription). Zone stones are listed in zones.json ("inscriptions"), the passage's in
## rune_discovery.json. Drawn procedurally: a dark standing stone with a faint carved band that
## glows until it has been read. Group "rune_stones"; main finds the nearest one in reach.

var stone_id := ""
var stone_name := "A rune stone"
var pool := "base"
var _band: MeshInstance3D
var _light: OmniLight3D


## Set before add_child.
func setup(id: String, display_name: String, pool_kind: String) -> void:
	stone_id = id
	stone_name = display_name
	pool = pool_kind
	name = "RuneStone_%s" % id
	add_to_group("rune_stones")
	var rock := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.7, 1.5, 0.38)
	rock.mesh = box
	rock.position = Vector3(0, 0.75, 0)
	rock.rotation.z = 0.05
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.19, 0.21)
	mat.roughness = 0.95
	rock.material_override = mat
	add_child(rock)
	_band = MeshInstance3D.new()
	var strip := BoxMesh.new()
	strip.size = Vector3(0.5, 0.9, 0.4)
	_band.mesh = strip
	_band.position = Vector3(0, 0.85, 0)
	var glow := StandardMaterial3D.new()
	var col: Color = Color(0.55, 0.75, 1.0) if pool != "universal" else Color(1.0, 0.82, 0.45)
	glow.albedo_color = col.darkened(0.6)
	glow.emission_enabled = true
	glow.emission = col
	glow.emission_energy_multiplier = 1.4
	_band.material_override = glow
	add_child(_band)
	_light = OmniLight3D.new()
	_light.light_color = col
	_light.light_energy = 0.9
	_light.omni_range = 3.5
	_light.position = Vector3(0, 1.0, 0.4)
	add_child(_light)
	var sb := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bshape := BoxShape3D.new()
	bshape.size = Vector3(0.7, 1.5, 0.38)
	shape.shape = bshape
	sb.add_child(shape)
	sb.position = Vector3(0, 0.75, 0)
	add_child(sb)


## Dim the band once this character has read it.
func set_read(read: bool) -> void:
	if _band != null:
		(_band.material_override as StandardMaterial3D).emission_energy_multiplier = 0.15 if read else 1.4
	if _light != null:
		_light.visible = not read
