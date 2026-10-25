class_name Townsperson
extends StaticBody3D
## Someone who works in town (design/08 section 3): a real body dressed from data/town.json, a
## name plate over their head, and a role that decides what talking to them offers
## (ui/talk_screen.gd). They stand at their post, turn to face you when you come close, and are a
## solid body on layer 1, so you walk round them and the navigation mesh does too.
## They are not hittable and carry nothing.

var role := ""
var folk_name := ""
var title := ""
var radius := 0.4
var height := 1.75
var focused := false

var _def: Dictionary = {}
var _rig: ModelRig
var _plate: Label3D
var _rest_facing := Vector3(0, 0, 1)
var _facing := Vector3(0, 0, 1)


## Build from one "folk" entry of data/town.json; `rng` varies the face and colouring.
func setup(def: Dictionary, rng: RandomNumberGenerator) -> void:
	_def = def
	role = str(def.get("role", ""))
	folk_name = str(def.get("name", role))
	title = str(def.get("title", ""))
	var face: Array = def.get("face", [0.0, 1.0])
	_rest_facing = Vector3(float(face[0]), 0.0, float(face[1])).normalized()
	_facing = _rest_facing
	add_to_group("townsfolk")
	collision_layer = 1
	collision_mask = 0

	_rig = CharacterLook.build(look_for(def, rng))
	if _rig.has_method("set_stance"):
		_rig.call("set_stance", "town")        # standing about, not in the combat guard
	add_child(_rig)
	if _rig.has_method("set_outfit"):
		var worn: Dictionary = {}
		for id: Variant in def.get("outfit", []):
			for slot: String in Inventory.slots_for(str(GameData.item(str(id)).get("slot", ""))):
				if not worn.has(slot):
					worn[slot] = str(id)
					break
		_rig.call("set_outfit", worn)
	height = maxf(1.4, float(_rig.height))

	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 1.8
	col.shape = shape
	col.position.y = 0.9
	add_child(col)

	_plate = Label3D.new()
	_plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_plate.no_depth_test = true
	_plate.font = UiTheme.font()
	_plate.font_size = 26
	_plate.outline_size = 9
	_plate.outline_modulate = Color(0.02, 0.015, 0.01, 0.9)
	_plate.pixel_size = 0.0085
	_plate.position.y = height + 0.42
	add_child(_plate)
	set_focus(false)
	_turn(0.0, true)


## A look for this person: random from the seeded rng, with the sex from the data and nothing the
## creator hides for that sex (creation.json "hidden_options").
static func look_for(def: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var look: Dictionary = CharacterLook.random_look(rng)
	var sex: String = str(def.get("sex", "male"))
	if CharacterLook.options().has("sex"):
		look["sex"] = sex
	var hidden: Dictionary = (GameData.creation.get("hidden_options", {}) as Dictionary).get(sex, {})
	for key: String in hidden:
		var banned: Array = hidden[key]
		if look.has(key) and banned.has(look[key]):
			for o: Dictionary in CharacterLook.options().get(key, []):
				if not banned.has(str(o["id"])):
					look[key] = str(o["id"])
					break
	if def.has("look"):
		for key: String in (def["look"] as Dictionary):
			look[key] = (def["look"] as Dictionary)[key]
	return CharacterLook.normalize(look)


## Brighter plate, and the key to press, while you are close enough to talk.
func set_focus(on: bool) -> void:
	focused = on
	var head: String = folk_name if title == "" else "%s\n%s" % [folk_name, title]
	_plate.text = head + ("\n[%s] talk" % Keybinds.binding_text("interact") if on else "")
	_plate.modulate = Color(1.0, 0.86, 0.55) if on else Color(0.86, 0.8, 0.7, 0.85)


func _process(delta: float) -> void:
	if _rig == null:
		return
	_rig.animate(delta, 0.0, false)
	_turn(delta, false)
	# the town is built behind character creation; its name plates would show through the screen
	var game: Node = get_tree().get_first_node_in_group("router")
	_plate.visible = game == null or str(game.get("state")) != "select"


## Face whoever comes near (within town.json "face_player_within"), else the way they stand.
func _turn(delta: float, instant: bool) -> void:
	var want: Vector3 = _rest_facing
	var p: Node3D = null
	var main: Node = get_tree().get_first_node_in_group("router") if is_inside_tree() else null
	if main != null:
		p = main.get("player") as Node3D
	if p != null:
		var to: Vector3 = p.global_position - global_position
		to.y = 0.0
		if to.length() > 0.3 and to.length() < float(GameData.town.get("face_player_within", 6.0)):
			want = to.normalized()
	if instant:
		_facing = want
	else:
		# turn by angle: Vector3.slerp between nearly opposite directions (the player walking past)
		# has no axis to turn round and raised an engine error every frame
		var a: float = lerp_angle(atan2(-_facing.x, -_facing.z), atan2(-want.x, -want.z), clampf(delta * 4.0, 0.0, 1.0))
		_facing = Vector3(-sin(a), 0.0, -cos(a))
	if _facing.length() > 0.01:
		_rig.rotation.y = atan2(-_facing.x, -_facing.z)


func is_dead() -> bool:
	return false
