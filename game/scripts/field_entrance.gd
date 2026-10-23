class_name FieldEntrance
extends Node3D
## A dungeon mouth out in a zone that does not lead anywhere yet (zones.json "entrances"): it
## stands in the world with a name and a line of flavour, and when you use it (interact) it says
## it is sealed for now. STUBBED, on purpose and all the same way: each entry carries the id of
## the dungeon it will one day open ("dungeon"), so making it real is a matter of data and of
## main.enter_dungeon_at(id) learning that id. Group "field_entrances"; main finds the nearest
## one in reach (main._entrance_in_reach).

var entrance_id := ""
var entrance_name := "A way down"
var flavour := ""
var sealed_line := "It is sealed."
var dungeon := ""
var reach := 3.0
var _plate: Label3D


## Set before add_child.
func setup(def: Dictionary) -> void:
	entrance_id = str(def.get("id", ""))
	entrance_name = str(def.get("name", "A way down"))
	flavour = str(def.get("flavour", ""))
	sealed_line = str(def.get("sealed", "It is sealed for now."))
	dungeon = str(def.get("dungeon", ""))
	reach = float(def.get("reach", 3.0))
	name = "Entrance_%s" % entrance_id
	add_to_group("field_entrances")
	var prop: Node3D = FieldProps.prop(str(def.get("kind", "sinkhole")), float(def.get("size", 0.0)))
	add_child(prop)
	if bool(prop.get_meta("blocks", false)):
		var sb := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = float(def.get("solid", float(prop.get_meta("radius", 1.0)) * 0.8))
		shape.height = 2.0
		col.shape = shape
		sb.add_child(col)
		sb.position = Vector3.UP
		add_child(sb)
	_plate = Label3D.new()
	_plate.text = entrance_name
	_plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_plate.no_depth_test = true
	_plate.font_size = 40
	_plate.outline_size = 12
	_plate.pixel_size = 0.01
	_plate.modulate = Color(0.95, 0.82, 0.55)
	_plate.position = Vector3(0, float(prop.get_meta("height", 1.0)) + 1.2, 0)
	_plate.visible = false
	add_child(_plate)


## The name plate shows when you are close.
func set_near(on: bool) -> void:
	if _plate != null:
		_plate.visible = on


## What using it says: its name, its flavour, and that it is sealed (stubbed).
func use_text() -> String:
	return "%s. %s %s" % [entrance_name, flavour, sealed_line]
