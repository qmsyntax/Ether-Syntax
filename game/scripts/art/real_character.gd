class_name RealCharacter
extends ModelRig
## A real character model standing in for a procedural ModelRig (Brent 2026-10-18: real assets).
## The body is Blender Studio's realistic base mesh (CC0), rigged by Mixamo's auto-rigger, with
## Mixamo animations on the same skeleton; tools/assets/blender_character.py packs it all into one
## .glb in game/assets/characters/. It answers the same calls gameplay already makes on a ModelRig
## - animate(), set_windup(), flash(), set_highlight(), set_weapon(), set_dead_look() - so the
## player does not need to know which kind of model it has. play_action(name) plays a one-off
## (a cast, a dodge) and set_activity(name) holds a state (meditating).

const DIR := "res://assets/characters/"
const LOOPS: Array[String] = ["idle", "walk", "run", "meditate"]
## Metres a second each moving loop covers at normal speed (to match feet to the ground).
const WALK_SPEED := 1.45
const RUN_SPEED := 4.6

static var _scenes: Dictionary = {}

var _model: Node3D
var _player: AnimationPlayer
var _skeleton: Skeleton3D
var _bodies: Array[MeshInstance3D] = []
var _overlay: StandardMaterial3D
var _hand: BoneAttachment3D
var _one_shot := ""                  # an action playing to its end; the loops wait for it
var _activity := ""
var _strike_side := false
var _was_attacking := false


## True if a real model exists for this body ("body_male", ...).
static func exists(body_id: String) -> bool:
	return ResourceLoader.exists(DIR + body_id + ".glb")


static func create(body_id: String) -> RealCharacter:
	if not _scenes.has(body_id):
		var packed: PackedScene = load(DIR + body_id + ".glb")
		_scenes[body_id] = packed
	var rc := RealCharacter.new()
	rc.name = "RealCharacter_" + body_id
	rc._build(_scenes[body_id])
	return rc


func _build(packed: PackedScene) -> void:
	_model = packed.instantiate()
	_model.rotation_degrees.y = 180.0          # Mixamo faces +Z; models in this game face -Z
	add_child(_model)
	_player = _model.find_children("*", "AnimationPlayer", true, false).front() as AnimationPlayer
	_skeleton = _model.find_children("*", "Skeleton3D", true, false).front() as Skeleton3D
	for n: Node in _model.find_children("*", "MeshInstance3D", true, false):
		_bodies.append(n as MeshInstance3D)
	for anim_name: String in LOOPS:
		if _player != null and _player.has_animation(anim_name):
			_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	if _player != null:
		_player.animation_finished.connect(func(done: StringName) -> void:
			if String(done) == _one_shot:
				_one_shot = "")
		_player.play("idle")
	_overlay = StandardMaterial3D.new()
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_overlay.albedo_color = Color(0, 0, 0, 0)
	for mi: MeshInstance3D in _bodies:
		mi.material_overlay = _overlay
	if _skeleton != null:
		var bone: int = _skeleton.find_bone("mixamorig_RightHand")
		if bone < 0:
			bone = _skeleton.find_bone("mixamorig:RightHand")
		if bone >= 0:
			_hand = BoneAttachment3D.new()
			_hand.bone_name = _skeleton.get_bone_name(bone)
			_skeleton.add_child(_hand)
	height = 1.7
	radius = 0.35
	set_process(true)                          # ModelRig switches it off; the flash needs it


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_flash_left = 0.0
		_refresh()


## The look of highlight, wind-up and hit flash, as a glow laid over the body.
func _refresh() -> void:
	if _overlay == null:
		return
	var c := Color(0, 0, 0, 0)
	if _highlight > 0:
		c = Color(HIGHLIGHT_GLOW, 0.10 * float(_highlight))
	if _windup:
		c = Color(WINDUP_GLOW, 0.18)
	if _flash_left > 0.0:
		c = Color(1, 1, 1, 0.45)
	if _dead:
		c = Color(0, 0, 0, 0)
	_overlay.albedo_color = c


func set_part_visible(_part: String, _on: bool) -> void:
	pass                                       # one skinned body: no separate arm to hide yet


## The weapon rides the right hand bone.
func set_weapon(weapon: Node3D) -> void:
	if weapon == _weapon:
		return
	if _weapon != null and is_instance_valid(_weapon):
		_weapon.queue_free()
	_weapon = weapon
	if weapon == null or _hand == null:
		return
	if weapon.get_parent() != null:
		weapon.get_parent().remove_child(weapon)
	# the weapon's grip is at its origin with the business end along -Z; the hand bone runs
	# along +Y to the fingers, so the blade is turned to stand out of the fist
	weapon.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-90.0), 0.0, 0.0)), Vector3(0.0, 0.08, 0.03))
	_hand.add_child(weapon)


func set_staggered(on: bool) -> void:
	if on and not _staggered:
		play_action("hit")
	_staggered = on


func set_dead_look() -> void:
	if _dead:
		return
	_dead = true
	_windup = false
	_refresh()
	if _player != null and _player.has_animation("death"):
		_player.play("death", 0.15)
		_one_shot = "death"


## Hold a state until it is cleared with "": "meditate".
func set_activity(name_now: String) -> void:
	if name_now == _activity:
		return
	_activity = name_now
	if _activity != "" and _player != null and _player.has_animation(_activity):
		_one_shot = ""
		_player.speed_scale = 1.0
		_player.play(_activity, 0.35)


## Play a one-off to its end: "cast", "cast_area", "dodge", "hit", "slash_in", "slash_out".
func play_action(name_now: String) -> void:
	if _dead or _player == null or not _player.has_animation(name_now):
		return
	_one_shot = name_now
	_player.speed_scale = 1.0
	_player.play(name_now, 0.08)


## Called every frame: the moving loops by speed, and a slash when a strike lands.
func animate(_delta: float, speed: float, attacking: bool) -> void:
	if _dead or _player == null:
		return
	if attacking and not _was_attacking and _one_shot == "":
		_strike_side = not _strike_side
		play_action("slash_in" if _strike_side else "slash_out")
	_was_attacking = attacking
	if _one_shot != "":
		return
	if _activity != "":
		return
	var want := "idle"
	var rate := 1.0
	if speed > 3.0:
		want = "run"
		rate = speed / RUN_SPEED
	elif speed > 0.25:
		want = "walk"
		rate = speed / WALK_SPEED
	if _player.current_animation != want:
		_player.play(want, 0.2)
	_player.speed_scale = clampf(rate, 0.6, 1.8) if want != "idle" else 1.0
