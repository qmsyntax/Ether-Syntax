extends Node3D
## An item lying on the ground. Click it to walk over and pick it up (Diablo-style).
## Lives under the level node, so anything left behind is lost when you leave.

var item_id := ""
var radius := 0.35
var height := 0.5
var highlight := 0
var is_scenery := false
var is_pickup := true

var _mat: StandardMaterial3D
var _label: Label3D
var _equippable := false


func setup(id: String) -> void:
	item_id = id
	var def: Dictionary = GameData.item(id)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 0.4, 0.4)
	mesh.mesh = box
	mesh.position.y = 0.25
	mesh.rotation_degrees = Vector3(0, 35, 0)
	_mat = StandardMaterial3D.new()
	var equippable: bool = str(def.get("slot", "")) != ""
	_equippable = equippable
	_mat.albedo_color = Color(0.95, 0.8, 0.25) if equippable else Color(0.8, 0.8, 0.85)
	_mat.emission_enabled = true
	_mat.emission = _mat.albedo_color * 0.25
	mesh.material_override = _mat
	add_child(mesh)

	_label = Label3D.new()
	_label.text = str(def.get("name", id))
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 30
	_label.outline_size = 8
	_label.pixel_size = 0.01
	_label.position.y = 0.9
	_label.modulate = Color(1.0, 0.92, 0.6, 0.75) if equippable else Color(0.85, 0.85, 0.9, 0.6)
	add_child(_label)
	add_to_group("pickups")


func is_dead() -> bool:
	return is_queued_for_deletion()


func set_highlight(level: int) -> void:
	highlight = level
	_label.modulate.a = 1.0 if level > 0 else (0.75 if _equippable else 0.6)
	_label.font_size = 36 if level > 0 else 30
	_mat.emission = _mat.albedo_color * (0.9 if level > 0 else 0.25)


func take() -> void:
	remove_from_group("pickups")
	queue_free()
