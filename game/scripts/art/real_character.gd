class_name RealCharacter
extends ModelRig
## A real character model standing in for a procedural ModelRig (Brent 2026-10-18: real assets).
## The body is Blender Studio's realistic base mesh (CC0), rigged by Mixamo's auto-rigger, with
## Mixamo animations on the same skeleton; tools/assets/blender_body_prep.py bakes its skin maps and
## tools/assets/blender_character.py adds clothes, hair and beards and packs it all into one .glb in
## game/assets/characters/. It answers the same calls gameplay already makes on a ModelRig
## - animate(), set_windup(), flash(), set_highlight(), set_weapon(), set_part_visible(),
## set_dead_look() - so the player does not need to know which kind of model it has. On top:
## apply_look(look) dresses it from the creator's options, set_outfit(equipped) from the
## inventory (data/wardrobe.json says which item shows as what), play_action(name) plays a one-off
## (a cast, a dodge) and set_activity(name) holds a state (meditating).

const DIR := "res://assets/characters/"
const TEX := "res://assets/characters/textures/"
const LOOPS: Array[String] = ["idle", "walk", "run", "sprint", "meditate"]
## Regions hidden by a lost right forearm: forearm, hand and the elbow half of the upper arm.
const LOST_ARM_MASK := (1 << 7) | (1 << 9) | (1 << 17)

static var _scenes: Dictionary = {}
static var _textures: Dictionary = {}

var _body_id := "body_male"
var _model: Node3D
var _player: AnimationPlayer
var _skeleton: Skeleton3D
var _mesh: Dictionary = {}                 # node name -> MeshInstance3D
var _overlay: StandardMaterial3D
var _skin: ShaderMaterial
var _hair: ShaderMaterial
var _hair_cards: ShaderMaterial
var _anatomy: ShaderMaterial
var _hair_mats: Array[ShaderMaterial] = []
var _piece_mat: Dictionary = {}            # piece id -> ShaderMaterial
var _hand_r: BoneAttachment3D
var _hand_l: BoneAttachment3D
var _look: Dictionary = {}
var _outfit: Dictionary = {}
var _arm_lost := false
var _bare := false                         # no everyday clothes under the empty slots
var _skin_source := "painted"
var _explicit: Array[String] = []          # an enemy's fixed costume (make_enemy); empty = base + outfit
var _piece_colors: Dictionary = {}         # piece id -> Color, over the wardrobe's colour
var _attack_clips: Array[String] = []      # enemy mode: a clip per wind-up, in turn
var _attack_next := 0
var _impact := 0.45
var _windup_s := 0.45
var _idle_clip := "idle"
var _props: Array[Node3D] = []
var _hanging: Array[Node3D] = []           # props that hang straight down from where they are held
var _barefoot := false                     # no foot wraps under an empty feet slot
var _walk_speed := 1.35
var _run_speed := 3.7
var _sprint_speed := 6.0
var _one_shot := ""                        # an action playing to its end; the loops wait for it
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
	rc._body_id = body_id
	rc._build(_scenes[body_id])
	return rc


static func _tex(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(TEX + path)
	return _textures[path]


static func _wardrobe() -> Dictionary:
	return GameData.wardrobe


func _build(packed: PackedScene) -> void:
	_model = packed.instantiate()
	_model.rotation_degrees.y = 180.0          # Mixamo faces +Z; models in this game face -Z
	add_child(_model)
	_player = _model.find_children("*", "AnimationPlayer", true, false).front() as AnimationPlayer
	_skeleton = _model.find_children("*", "Skeleton3D", true, false).front() as Skeleton3D
	for n: Node in _model.find_children("*", "MeshInstance3D", true, false):
		_mesh[String(n.name)] = n as MeshInstance3D
	for anim_name: String in LOOPS:
		if _player != null and _player.has_animation(anim_name):
			_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	if _player != null:
		_player.animation_finished.connect(func(done: StringName) -> void:
			if String(done) == _one_shot:
				_one_shot = "")
		_player.play("idle")
	var body_cfg: Dictionary = (_wardrobe().get("bodies", {}) as Dictionary).get(_body_id, {})
	_walk_speed = float(body_cfg.get("walk_speed", _walk_speed))
	_run_speed = float(body_cfg.get("run_speed", _run_speed))
	_sprint_speed = float(body_cfg.get("sprint_speed", _sprint_speed))
	height = float(body_cfg.get("height", 1.72))
	radius = 0.35

	var sex: String = _body_id.trim_prefix("body_")
	_skin = ShaderMaterial.new()
	_skin.shader = load("res://assets/shaders/skin.gdshader")
	_skin.set_shader_parameter("detail_tex", _tex("skin/skin_%s_detail.png" % sex))
	_skin.set_shader_parameter("mask_a", _tex("skin/skin_%s_mask_a.png" % sex))
	_skin.set_shader_parameter("mask_b", _tex("skin/skin_%s_mask_b.png" % sex))
	_skin.set_shader_parameter("normal_tex", _tex("skin/skin_%s_normal.png" % sex))
	if ResourceLoader.exists(TEX + "skin/skin_micro_normal.png"):
		_skin.set_shader_parameter("micro_tex", _tex("skin/skin_micro_normal.png"))
	set_skin_source(str(_wardrobe().get("skin_source", "painted")))
	_hair = ShaderMaterial.new()
	_hair.shader = load("res://assets/shaders/hair.gdshader")
	_anatomy = ShaderMaterial.new()
	_anatomy.shader = load("res://assets/shaders/anatomy.gdshader")
	if ResourceLoader.exists(TEX + "skin/skin_%s_anatomy.png" % sex):
		_anatomy.set_shader_parameter("tex", _tex("skin/skin_%s_anatomy.png" % sex))
	_hair_cards = ShaderMaterial.new()
	_hair_cards.shader = load("res://assets/shaders/hair_cards.gdshader")
	if ResourceLoader.exists(TEX + "hair/strands.png"):
		_hair_cards.set_shader_parameter("strand_tex", _tex("hair/strands.png"))
		_hair.set_shader_parameter("strand_tex", _tex("hair/strands.png"))
	var eye := StandardMaterial3D.new()
	eye.vertex_color_use_as_albedo = true
	eye.roughness = 0.25
	eye.metallic_specular = 0.45
	_overlay = StandardMaterial3D.new()
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_overlay.albedo_color = Color(0, 0, 0, 0)
	for mesh_name: String in _mesh:
		var mi: MeshInstance3D = _mesh[mesh_name]
		mi.material_overlay = _overlay
		if mesh_name == "body" or mesh_name == "stump_r":
			mi.material_override = _skin
		elif mesh_name == "eyes":
			mi.material_override = eye
		elif mesh_name == "anatomy":
			mi.material_override = _anatomy
		elif mesh_name.ends_with("_cards"):
			mi.material_override = _hair_cards
		elif mesh_name.begins_with("hair_"):
			mi.material_override = _hair_mesh(mesh_name.trim_prefix("hair_"))
		elif mesh_name.begins_with("hair_") or mesh_name == "beard":
			mi.material_override = _hair
		mi.visible = mesh_name == "body" or mesh_name == "eyes"
	if _skeleton != null:
		_hand_r = _attach("RightHand")
		_hand_l = _attach("LeftHand")
	apply_look({})
	set_process(true)                          # ModelRig switches it off; the flash needs it


## A hair style's material: its own texture (textures/hair/<style>.png), tinted to the hair colour.
func _hair_mesh(style: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/hair_mesh.gdshader")
	var path: String = "hair/%s.png" % style
	if ResourceLoader.exists(TEX + path):
		m.set_shader_parameter("tex", _tex(path))
		m.set_shader_parameter("mean_luma", float((_wardrobe().get("hair_luma", {}) as Dictionary).get(style, 0.3)))
	_hair_mats.append(m)
	return m


func _attach(bone_name: String) -> BoneAttachment3D:
	var bone: int = _skeleton.find_bone("mixamorig_" + bone_name)
	if bone < 0:
		bone = _skeleton.find_bone("mixamorig:" + bone_name)
	if bone < 0:
		return null
	var at := BoneAttachment3D.new()
	at.bone_name = _skeleton.get_bone_name(bone)
	_skeleton.add_child(at)
	return at


## Which skin the body wears: "painted" (made from the body's shape by blender_body_prep.py) or a
## photographic one baked onto this body: "mh" (MakeHuman CC0 skins, blender_skin_transfer.py) or
## "gen" (generated on Brent's ComfyUI and projected on). Missing files fall back to painted.
func set_skin_source(source: String) -> void:
	_skin_source = source
	var sex: String = _body_id.trim_prefix("body_")
	var feat: String = str(_look.get("features", "f1"))
	var face: String = "skin/skin_%s_gen_%s.jpg" % [sex, feat]
	var mask: String = "skin/skin_%s_gen_mask.png" % sex
	var path: String = "skin/skin_%s_%s.png" % [sex, source]
	_skin.set_shader_parameter("photo_has_mask", false)
	if source == "gen" and ResourceLoader.exists(TEX + face) and ResourceLoader.exists(TEX + mask):
		_skin.set_shader_parameter("photo_tex", _tex(face))     # one of the generated faces (look "features")
		_skin.set_shader_parameter("photo_mask", _tex(mask))
		_skin.set_shader_parameter("photo_has_mask", true)
		_skin.set_shader_parameter("photo_mix", 1.0)
	elif source != "painted" and ResourceLoader.exists(TEX + path):
		_skin.set_shader_parameter("photo_tex", _tex(path))
		_skin.set_shader_parameter("photo_mix", 1.0)
	else:
		_skin.set_shader_parameter("photo_mix", 0.0)


## Dress the body from the creator's options (see PlayerLook): build, skin, face, hair, colours.
func apply_look(look: Dictionary) -> void:
	_look = CharacterLook.normalize(look)
	var w: Dictionary = _wardrobe()
	var build: Dictionary = (w.get("builds", {}) as Dictionary).get(str(_look.get("body", "a")), {})
	var face: Dictionary = (w.get("faces", {}) as Dictionary).get(str(_look.get("face", "plain")), {})
	_model.scale = Vector3.ONE * float(build.get("scale", 1.0))
	for mi: MeshInstance3D in _mesh.values():
		_set_shape(mi, "heavy", float(build.get("heavy", 0.0)))
		_set_shape(mi, "slight", float(build.get("slight", 0.0)))
		_set_shape(mi, "gaunt", float(face.get("gaunt", 0.0)))
		_set_shape(mi, "brow", float(face.get("brow", 0.0)))
	var hair_col: Color = _option_color("hair_color", Color(0.17, 0.11, 0.07))
	_skin.set_shader_parameter("skin_color", _option_color("skin", Color(0.68, 0.52, 0.41)))
	_anatomy.set_shader_parameter("skin_color", _option_color("skin", Color(0.68, 0.52, 0.41)))
	_skin.set_shader_parameter("hair_color", hair_col)
	_skin.set_shader_parameter("stubble", float(face.get("stubble", 0.0)))
	_skin.set_shader_parameter("scar", float(face.get("scar", 0.0)))
	_skin.set_shader_parameter("brow_weight", float(face.get("brow_weight", 1.0)))
	var style: String = str(_look.get("hair", "messy"))
	# the scalp under the hair cards takes the hair's colour, so no skin shows between them
	_skin.set_shader_parameter("scalp_shade", {"shaved": 0.55, "undercut": 0.6}.get(style, 0.9))
	_hair.set_shader_parameter("hair_color", hair_col)
	set_skin_source(_skin_source)                # the face follows the look's "features"
	_hair_cards.set_shader_parameter("hair_color", hair_col)
	for m: ShaderMaterial in _hair_mats:
		m.set_shader_parameter("hair_color", hair_col)
	_piece_mat.clear()
	_refresh_outfit()


## Leave the foot wraps off when no footwear is worn (the creator shows bare feet).
func set_barefoot(on: bool) -> void:
	_barefoot = on
	_refresh_outfit()


## Leave the everyday clothes off (true): only equipped pieces are worn over the bare body.
func set_bare(on: bool) -> void:
	_bare = on
	_refresh_outfit()


## Show what is equipped (slot -> item id, as Inventory.equipped): data/wardrobe.json maps items
## to pieces; empty slots fall back to the everyday clothes.
func set_outfit(equipped: Dictionary) -> void:
	_outfit = equipped.duplicate()
	_refresh_outfit()


func _set_shape(mi: MeshInstance3D, shape: String, value: float) -> void:
	if mi.mesh == null:
		return
	var i: int = mi.find_blend_shape_by_name(shape)
	if i >= 0:
		mi.set_blend_shape_value(i, value)


func _option_color(key: String, fallback: Color) -> Color:
	for o: Dictionary in CharacterLook.options().get(key, []):
		if str(o["id"]) == str(_look.get(key, "")):
			return o.get("color", fallback)
	return fallback


## The pieces worn now, lowest layer first.
func worn_pieces() -> Array[String]:
	var w: Dictionary = _wardrobe()
	var pieces: Dictionary = w.get("pieces", {})
	var items: Dictionary = w.get("items", {})
	var on: Array[String] = []
	if not _explicit.is_empty():
		for p: String in _explicit:
			if pieces.has(p):
				on.append(p)
		on.sort_custom(func(a: String, b: String) -> bool:
			return int((pieces[a] as Dictionary).get("layer", 0)) < int((pieces[b] as Dictionary).get("layer", 0)))
		var gone: Array[String] = []
		for p: String in on:
			for r: Variant in (pieces[p] as Dictionary).get("replaces", []):
				gone.append(str(r))
		var kept: Array[String] = []
		for p: String in on:
			if not gone.has(p):
				kept.append(p)
		return kept
	for p: Variant in ([] if _bare else w.get("base", [])):
		if _barefoot and str(p) == "wraps":
			continue
		on.append(str(p))
	for slot: Variant in _outfit:
		var piece: String = str(items.get(str(_outfit[slot]), ""))
		if piece != "" and pieces.has(piece) and not on.has(piece):
			on.append(piece)
	if str(_look.get("band", "off")) == "on":
		on.append("headband")
	var replaced: Array[String] = []
	for p: String in on:
		for r: Variant in (pieces[p] as Dictionary).get("replaces", []):
			replaced.append(str(r))
	var out: Array[String] = []
	for p: String in on:
		if not replaced.has(p):
			out.append(p)
	out.sort_custom(func(a: String, b: String) -> bool:
		return int((pieces[a] as Dictionary).get("layer", 0)) < int((pieces[b] as Dictionary).get("layer", 0)))
	return out


func _refresh_outfit() -> void:
	if _skin == null:
		return
	var w: Dictionary = _wardrobe()
	var pieces: Dictionary = w.get("pieces", {})
	var worn: Array[String] = worn_pieces()
	var arm: int = LOST_ARM_MASK if _arm_lost else 0
	for mesh_name: String in _mesh:
		if mesh_name.begins_with("cloth_"):
			(_mesh[mesh_name] as MeshInstance3D).visible = false
	var body_mask := arm
	var hair_rule := ""
	for i: int in worn.size():
		var cfg: Dictionary = pieces[worn[i]]
		var above := arm
		for j: int in range(i + 1, worn.size()):
			var upper: Dictionary = pieces[worn[j]]
			if int(upper.get("layer", 0)) > int(cfg.get("layer", 0)):
				for r: Variant in upper.get("covers", []):
					above |= 1 << int(r)
		for r: Variant in cfg.get("covers", []):
			body_mask |= 1 << int(r)
		for mesh_name: Variant in cfg.get("meshes", []):
			var mi: MeshInstance3D = _mesh.get(str(mesh_name), null)
			if mi != null:
				var mat: ShaderMaterial = _material_for(worn[i], cfg, str(mesh_name))
				mat.set_shader_parameter("hidden_mask", above)
				mi.visible = true
				mi.material_override = mat
		if cfg.has("hair"):
			hair_rule = str(cfg["hair"])
	_skin.set_shader_parameter("hidden_mask", body_mask)
	if _mesh.has("anatomy"):                   # only where nothing covers the hips
		(_mesh["anatomy"] as MeshInstance3D).visible = (body_mask >> 3) & 1 == 0
	# hair: the look's style, unless a hood hides it or a cap presses it flat
	var style: String = str(_look.get("hair", "messy"))
	var show: Array = (w.get("hair", {}) as Dictionary).get(style, [])
	if hair_rule == "none":
		show = []
	elif hair_rule == "cropped" and not show.is_empty():
		show = ["hair_cropped"]
	for mesh_name: String in _mesh:
		if mesh_name.begins_with("hair_"):
			(_mesh[mesh_name] as MeshInstance3D).visible = show.has(mesh_name)
	var face: Dictionary = (w.get("faces", {}) as Dictionary).get(str(_look.get("face", "plain")), {})
	for beard: String in ["beard", "beard_cards"]:
		if _mesh.has(beard):
			(_mesh[beard] as MeshInstance3D).visible = bool(face.get("beard", false))
	if _mesh.has("stump_r"):
		(_mesh["stump_r"] as MeshInstance3D).visible = _arm_lost


## The piece's material on one of its meshes: the shared cloth set, plus that mesh's own baked fold
## and detail maps (textures/garments/<sex>/<mesh>_fold.png, _detail.png) where they exist.
func _material_for(piece: String, cfg: Dictionary, mesh_name: String) -> ShaderMaterial:
	var cache_key: String = piece + "/" + mesh_name
	if _piece_mat.has(cache_key):
		return _piece_mat[cache_key]
	var mats: Dictionary = _wardrobe().get("materials", {})
	var m: Dictionary = mats.get(str(cfg.get("material", "linen")), {})
	var tex: String = str(m.get("tex", "fabric061"))
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/cloth.gdshader")
	mat.set_shader_parameter("albedo_tex", _tex("cloth/%s_color.jpg" % tex))
	mat.set_shader_parameter("normal_tex", _tex("cloth/%s_normal.jpg" % tex))
	mat.set_shader_parameter("rough_tex", _tex("cloth/%s_rough.jpg" % tex))
	for key: String in ["tint", "uv_scale", "rough_bias", "grime", "quilt", "sheen", "normal_depth", "metallic"]:
		if m.has(key):
			mat.set_shader_parameter(key, float(m[key]))
	var col: Variant = cfg.get("color", [0.5, 0.5, 0.5])
	var c := Color(0.5, 0.5, 0.5)
	if _piece_colors.has(piece):
		col = _piece_colors[piece]
	if col is Color:
		c = col
	elif col is String:
		c = _option_color(str(col), c)
	elif col is Array:
		c = Color(float(col[0]), float(col[1]), float(col[2]))
	mat.set_shader_parameter("color", c)
	var baked: String = "garments/%s/%s_" % [_body_id.trim_prefix("body_"), mesh_name]
	if ResourceLoader.exists(TEX + baked + "fold.png") and ResourceLoader.exists(TEX + baked + "detail.png"):
		mat.set_shader_parameter("fold_tex", _tex(baked + "fold.png"))
		mat.set_shader_parameter("detail_tex", _tex(baked + "detail.png"))
		mat.set_shader_parameter("baked", true)
	for key2: String in ["wear", "fold_depth"]:
		if m.has(key2):
			mat.set_shader_parameter(key2, float(m[key2]))
	_piece_mat[cache_key] = mat
	return mat


func _process(delta: float) -> void:
	for h: Node3D in _hanging:                 # a censer on its chain: down is down, whatever the hand does
		if is_instance_valid(h):
			var s: Vector3 = h.global_transform.basis.get_scale()
			h.global_transform = Transform3D(Basis(Vector3.UP, global_rotation.y).scaled(s), h.global_position)
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


## "arm_right" off: the forearm and hand are gone (a bandaged stump shows), the weapon moves to
## the left hand and strikes swing from the left.
func set_part_visible(part: String, on: bool) -> void:
	if part != "arm_right" or _arm_lost == (not on):
		return
	_arm_lost = not on
	_refresh_outfit()
	if _weapon != null and is_instance_valid(_weapon):
		_place_weapon(_weapon)


## The weapon rides the right hand bone (the left once the right arm is gone).
func set_weapon(weapon: Node3D) -> void:
	if weapon == _weapon:
		return
	if _weapon != null and is_instance_valid(_weapon):
		if _weapon.get_parent() != null:
			_weapon.get_parent().remove_child(_weapon)
		_weapon.queue_free()
	_weapon = weapon
	if weapon != null:
		_place_weapon(weapon)


func _place_weapon(weapon: Node3D) -> void:
	var hand: BoneAttachment3D = _hand_l if _arm_lost else _hand_r
	if hand == null:
		return
	if weapon.get_parent() != null:
		weapon.get_parent().remove_child(weapon)
	var grips: Dictionary = _wardrobe().get("grip", {})
	var grip: Dictionary = grips.get("left" if _arm_lost else "right", {})
	var by_item: Dictionary = (grips.get("items", {}) as Dictionary).get(str(weapon.get_meta("item_id", "")), {})
	if by_item.has("left" if _arm_lost else "right"):
		grip = by_item["left" if _arm_lost else "right"]
	var rot: Array = grip.get("rot_deg", [-90.0, 0.0, 0.0])
	var pos: Array = grip.get("pos", [0.0, 0.08, 0.03])
	var basis := Basis.from_euler(Vector3(deg_to_rad(float(rot[0])), deg_to_rad(float(rot[1])), deg_to_rad(float(rot[2]))))
	# the bone attachment sits under the armature's 1/100 scale; the weapon is sized in metres
	var s: float = 1.0 / _scale_under_model(hand)
	weapon.transform = Transform3D(basis.scaled(Vector3.ONE * s), Vector3(float(pos[0]), float(pos[1]), float(pos[2])) * s)
	hand.add_child(weapon)


func _scale_under_model(n: Node3D) -> float:
	var s := 1.0
	var p: Node = n.get_parent()
	while p != null and p != _model:
		if p is Node3D:
			s *= (p as Node3D).scale.x
		p = p.get_parent()
	return maxf(s, 0.0001)


## Triangles drawn now: the visible pieces of the body (index counts / 3), plus props and weapon.
func triangle_count() -> int:
	var total: int = 0
	for mi: MeshInstance3D in _mesh.values():
		if mi.visible and mi.mesh != null:
			for s: int in mi.mesh.get_surface_count():
				var idx: PackedInt32Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
				total += (idx.size() if idx.size() > 0 else (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	for p: Node3D in _props:
		total += p.get_child_count() * 12
	if _weapon is ModelRig:
		total += (_weapon as ModelRig).triangle_count()
	return total


# --- enemies ----------------------------------------------------------------------------------

## Dress this body as an enemy kind from data/enemy_looks.json (Models.enemy calls it): look,
## costume, colour, weapon, props, attack clips and the size the kind is in enemies.json.
func make_enemy(look_cfg: Dictionary, def: Dictionary) -> void:
	var look: Dictionary = {"sex": str(look_cfg.get("body", "male"))}
	for key: String in ["body", "skin", "features", "hair", "hair_color", "face"]:
		var src: String = "build" if key == "body" else key
		if look_cfg.has(src):
			look[key] = look_cfg[src]
	look["band"] = "off"
	var tint: Array = def.get("color", [0.5, 0.2, 0.2])
	var enemy_col := Color(float(tint[0]), float(tint[1]), float(tint[2])).darkened(0.25)
	var colors: Dictionary = look_cfg.get("colors", {})
	for piece: Variant in colors:
		var v: Variant = colors[piece]
		if str(v) == "enemy":
			_piece_colors[str(piece)] = enemy_col
		elif v is Array:
			_piece_colors[str(piece)] = Color(float(v[0]), float(v[1]), float(v[2]))
	_explicit.clear()
	for p: Variant in look_cfg.get("pieces", []):
		_explicit.append(str(p))
	_piece_mat.clear()
	apply_look(look)
	for c: Variant in look_cfg.get("attack", []):
		_attack_clips.append(str(c))
	_impact = float(look_cfg.get("impact", 0.45))
	_windup_s = float(def.get("windup", 0.45))
	_idle_clip = str(look_cfg.get("idle", "idle"))
	if _player != null and _player.has_animation(_idle_clip):
		_player.get_animation(_idle_clip).loop_mode = Animation.LOOP_LINEAR
		_player.play(_idle_clip)
	var body_cfg: Dictionary = (_wardrobe().get("bodies", {}) as Dictionary).get(_body_id, {})
	var stature: float = float(body_cfg.get("stature", 1.68)) * _model.scale.x
	scale = Vector3.ONE * (float(def.get("height", 1.7)) / maxf(stature, 0.1))
	height = float(def.get("height", 1.7))
	radius = float(def.get("radius", 0.5))
	if look_cfg.has("weapon"):
		set_weapon(Models.weapon(str(look_cfg["weapon"])))
	for p: Variant in look_cfg.get("props", []):
		_add_prop(str(p))


## A held or worn object built from data/wardrobe.json "props": parts (box / cyl / ball) in a
## material, on a bone.
func _add_prop(id: String) -> void:
	var cfg: Dictionary = (_wardrobe().get("props", {}) as Dictionary).get(id, {})
	if cfg.is_empty() or _skeleton == null:
		return
	var at: BoneAttachment3D = _attach(str(cfg.get("bone", "RightHand")))
	if at == null:
		return
	var root := Node3D.new()
	root.name = "Prop_" + id
	for part: Variant in cfg.get("parts", []):
		var pd: Dictionary = part
		var mi := MeshInstance3D.new()
		var size: Array = pd.get("size", [0.1, 0.1, 0.1])
		match str(pd.get("shape", "box")):
			"cyl":
				var cm := CylinderMesh.new()
				cm.top_radius = float(size[0])
				cm.bottom_radius = float(size[1]) if size.size() > 2 else float(size[0])
				cm.height = float(size[size.size() - 1])
				cm.radial_segments = 20
				mi.mesh = cm
			"ball":
				var sm := SphereMesh.new()
				sm.radius = float(size[0])
				sm.height = float(size[0]) * 2.0
				mi.mesh = sm
			_:
				var bx := BoxMesh.new()
				bx.size = Vector3(float(size[0]), float(size[1]), float(size[2]))
				mi.mesh = bx
		var pos: Array = pd.get("pos", [0, 0, 0])
		var rot: Array = pd.get("rot_deg", [0, 0, 0])
		mi.position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		mi.rotation_degrees = Vector3(float(rot[0]), float(rot[1]), float(rot[2]))
		if pd.has("glow"):
			var g: Array = pd["glow"]
			var em := StandardMaterial3D.new()
			em.albedo_color = Color(float(g[0]), float(g[1]), float(g[2]))
			em.emission_enabled = true
			em.emission = em.albedo_color
			em.emission_energy_multiplier = 2.5
			mi.material_override = em
		else:
			var key: String = "prop_%s_%d" % [id, root.get_child_count()]
			mi.material_override = _material_for(key, {"material": pd.get("material", "wood"), "color": pd.get("color", [0.4, 0.3, 0.2])}, "")
		mi.material_overlay = _overlay
		root.add_child(mi)
	var place: Array = cfg.get("pos", [0, 0, 0])
	var turn: Array = cfg.get("rot_deg", [0, 0, 0])
	var s: float = 1.0 / _scale_under_model(at)
	var basis := Basis.from_euler(Vector3(deg_to_rad(float(turn[0])), deg_to_rad(float(turn[1])), deg_to_rad(float(turn[2]))))
	root.transform = Transform3D(basis.scaled(Vector3.ONE * s), Vector3(float(place[0]), float(place[1]), float(place[2])) * s)
	at.add_child(root)
	_props.append(root)
	if bool(cfg.get("hang", false)):
		_hanging.append(root)


## Enemy mode: each wind-up plays the next attack clip, timed so its blow lands as the wind-up ends.
func set_windup(on: bool) -> void:
	super.set_windup(on)
	if on and not _attack_clips.is_empty() and _player != null and not _dead:
		var clip: String = _attack_clips[_attack_next % _attack_clips.size()]
		_attack_next += 1
		if _player.has_animation(clip):
			var length: float = _player.get_animation(clip).length
			_one_shot = clip
			_player.speed_scale = clampf(length * _impact / maxf(_windup_s, 0.1), 0.5, 3.0)
			_player.play(clip, 0.1)


## A dead enemy's body: it falls, lies a while, sinks away and frees itself.
func lie_and_fade(lie_s: float) -> void:
	set_dead_look()
	var t: Tween = create_tween()
	t.tween_interval(lie_s)
	t.tween_property(self, "position:y", position.y - 0.6, 2.0)
	t.tween_callback(queue_free)


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
		_player.speed_scale = 1.0
		_player.play("death", 0.15)
		_one_shot = "death"


## Already lying where it fell (a corpse): the death motion's last frame, no fall.
func lie_dead() -> void:
	set_dead_look()
	if _player != null and _player.has_animation("death"):
		_player.seek(_player.get_animation("death").length, true)


## Freeze on one frame of a clip, at t seconds or (if t < 0) at fraction f of its length - for
## previews and tests.
func pose_at(anim: String, t: float, f: float = -1.0) -> void:
	if _player == null or not _player.has_animation(anim):
		return
	_one_shot = anim
	var at: float = t if t >= 0.0 else maxf(f, 0.0) * _player.get_animation(anim).length
	_player.play(anim, 0.0)
	_player.seek(at, true)
	_player.pause()


## Hold a state until it is cleared with "": "meditate".
func set_activity(name_now: String) -> void:
	if name_now == _activity:
		return
	_activity = name_now
	if _activity != "" and _player != null and _player.has_animation(_activity):
		_one_shot = ""
		_player.speed_scale = 1.0
		_player.play(_activity, 0.35)


## Play a one-off to its end: "cast", "cast_area", "dodge", "hit", "heavy", "pickup", "throw",
## "power_up", "slash_in", "slash_out". Speeds come from data/wardrobe.json "action_speed".
func play_action(name_now: String) -> void:
	if _dead or _player == null:
		return
	if _arm_lost and _player.has_animation(name_now + "_l"):
		name_now += "_l"
	if not _player.has_animation(name_now):
		return
	_one_shot = name_now
	_player.speed_scale = float((_wardrobe().get("action_speed", {}) as Dictionary).get(name_now.trim_suffix("_l"), 1.0))
	_player.play(name_now, 0.08)


## Called every frame: the moving loops by speed, and a slash when a strike lands.
func animate(_delta: float, speed: float, attacking: bool) -> void:
	if _dead or _player == null:
		return
	if _attack_clips.is_empty() and attacking and not _was_attacking and (_one_shot == "" or _one_shot.begins_with("slash")):
		_strike_side = not _strike_side
		play_action("slash_in" if _strike_side else "slash_out")
	_was_attacking = attacking
	if _one_shot != "":
		return
	if _activity != "":
		return
	var want := _idle_clip
	var rate := 1.0
	if speed > 0.5 * (_run_speed + _sprint_speed) and _player.has_animation("sprint"):
		want = "sprint"
		rate = speed / _sprint_speed
	elif speed > 0.5 * (_walk_speed + _run_speed):
		want = "run"
		rate = speed / _run_speed
	elif speed > 0.25:
		want = "walk"
		rate = speed / _walk_speed
	if _player.current_animation != want:
		_player.play(want, 0.2)
	_player.speed_scale = clampf(rate, 0.6, 1.8) if want != _idle_clip else 1.0
