class_name CreationScreen
extends UiScreen
## Character creation, in steps: who you are (name, identity, body type), what you look like, and
## which prime vestige you take (talent + affinities). A turntable in the middle shows the
## character as it will appear in play; drag it to turn it. Then two starting skills, picked
## from the prime's affinities (design/08: nothing is given that was not picked). The screen holds a draft `spec` and
## hands it to main.gd's `begin_character` at the end - it owns no game state.

const STEPS: Array[String] = ["Origin", "Appearance", "Prime", "Skills", "Embark"]

var spec: Dictionary = {}
var step := 0
## The primes on the table: [{talent_id, affinities}], rolled when the screen opens.
var offers: Array[Dictionary] = []
var rerolls_left := 0

var _rng := RandomNumberGenerator.new()
var _left: VBoxContainer
var _right: VBoxContainer
var _viewport: SubViewport
var _pivot: Node3D
var _rig: ModelRig
var _spin := PI - 0.5                   # start three-quarter on, facing the camera
var _dragging := false
var _name_edit: LineEdit


func backdrop() -> float:
	return 0.9


func _init(game_node: Node) -> void:
	super(game_node)
	_rng.randomize()
	var cfg: Dictionary = GameData.creation
	rerolls_left = GameData.inum("primes", "rerolls")
	spec = {"name": "", "identity": str((cfg["identities"][0] as Dictionary)["id"]), "look": CharacterLook.default_look(), "skills": []}
	roll_offers()


## Put three new primes on the table and take the first.
func roll_offers() -> void:
	offers = PrimeRoll.roll_offers(_rng, game.get("TALENT_CHOICES"))
	_take(0)


func _take(index: int) -> void:
	var o: Dictionary = offers[clampi(index, 0, offers.size() - 1)]
	spec["talent_id"] = str(o["talent_id"])
	spec["affinities"] = (o["affinities"] as Array).duplicate()
	# a different prime may not reach the skills picked for the last one
	var roots: Array[String] = GameData.skill_roots(spec["affinities"])
	spec["skills"] = (spec.get("skills", []) as Array).filter(func(id: Variant) -> bool: return roots.has(str(id)))


func build(root: Control) -> void:
	_left = framed(root, 0.02, 0.04, 0.3, 0.96)
	_left.add_theme_constant_override("separation", 8)
	_right = framed(root, 0.68, 0.04, 0.98, 0.96)
	_right.add_theme_constant_override("separation", 8)
	_build_preview(root)
	_refresh()


func _process(delta: float) -> void:
	if _pivot != null:
		_pivot.rotation.y = _spin
	if _rig != null:
		_rig.animate(delta, 0.0, false)
	# Ease the turntable camera between the full-figure and head-and-shoulders framings.
	if _viewport != null and _viewport.get_camera_3d() != null:
		var cam: Camera3D = _viewport.get_camera_3d()
		var want: float = 1.0 if bool(get_meta("zoom_close", false)) else 0.0
		var now: float = move_toward(float(get_meta("zoom_now", 0.0)), want, delta * 3.0)
		set_meta("zoom_now", now)
		var t: float = smoothstep(0.0, 1.0, now)
		var top: float = _rig.height if _rig != null else 1.85
		var look_at: Vector3 = Vector3(0.0, 0.98, 0.0).lerp(Vector3(0.0, top - 0.2, 0.0), t)
		cam.position = Vector3(0.0, 1.1, 6.1).lerp(Vector3(0.0, top - 0.12, 2.25), t)
		cam.look_at(look_at, Vector3.UP)


## Frame the whole figure (false) or head and shoulders (true) on the turntable.
func set_zoom(close: bool) -> void:
	set_meta("zoom_close", close)


# --- the turntable ------------------------------------------------------------------------

func _build_preview(root: Control) -> void:
	var holder := SubViewportContainer.new()
	holder.anchor_left = 0.31
	holder.anchor_right = 0.67
	holder.anchor_top = 0.04
	holder.anchor_bottom = 0.96
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.gui_input.connect(_on_preview_input)
	root.add_child(holder)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	holder.add_child(_viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.46, 0.52, 0.66)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.ssao_enabled = true
	env.ssao_radius = 0.35
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	var we := WorldEnvironment.new()
	we.environment = env
	_viewport.add_child(we)
	# Three-point light: a warm shadowed key from the upper left, a dim cool fill from the
	# right, and a cold rim from behind to lift the silhouette off the dark backdrop.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-34.0, 38.0, 0.0)
	key.light_color = Color(1.0, 0.88, 0.74)
	key.light_energy = 1.55
	key.shadow_enabled = true
	key.shadow_blur = 1.6
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 14.0
	key.shadow_normal_bias = 0.6
	key.shadow_bias = 0.02
	_viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-12.0, -48.0, 0.0)
	fill.light_color = Color(0.6, 0.7, 0.9)
	fill.light_energy = 0.38
	_viewport.add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-24.0, -158.0, 0.0)
	rim.light_color = Color(0.6, 0.76, 1.0)
	rim.light_energy = 1.1
	_viewport.add_child(rim)

	# A longer lens from further back: less distortion on the face.
	var cam := Camera3D.new()
	cam.fov = 20.0
	cam.near = 0.2
	cam.position = Vector3(0.0, 1.1, 6.1)
	_viewport.add_child(cam)
	cam.look_at(Vector3(0.0, 0.98, 0.0), Vector3.UP)

	var plinth := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.44
	disc.bottom_radius = 0.48
	disc.height = 0.06
	disc.radial_segments = 48
	plinth.mesh = disc
	plinth.position.y = -0.03
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.035, 0.033, 0.032)
	mat.roughness = 0.85
	plinth.material_override = mat
	_viewport.add_child(plinth)
	# A soft contact shadow under the feet, on top of the cast shadow.
	var contact := MeshInstance3D.new()
	var blob := QuadMesh.new()
	blob.size = Vector2(0.86, 0.86)
	contact.mesh = blob
	contact.rotation_degrees.x = -90.0
	contact.position.y = 0.004
	var blob_mat := ShaderMaterial.new()
	var blob_shader := Shader.new()
	blob_shader.code = "shader_type spatial;\nrender_mode unshaded, blend_mix, depth_draw_never, shadows_disabled;\nvoid fragment() {\n\tfloat d = length(UV - vec2(0.5)) * 2.0;\n\tALBEDO = vec3(0.0);\n\tALPHA = 0.6 * pow(clamp(1.0 - d, 0.0, 1.0), 1.6);\n}\n"
	blob_mat.shader = blob_shader
	contact.material_override = blob_mat
	_viewport.add_child(contact)

	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	_refresh_model()

	var hint := UiTheme.body("drag to turn", 13, UiTheme.TEXT_FAINT)
	hint.anchor_left = 0.31
	hint.anchor_right = 0.67
	hint.anchor_top = 0.92
	hint.anchor_bottom = 0.96
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)

	var zoom := UiWidgets.small_button("Face", func() -> void: pass)
	zoom.name = "ZoomButton"
	zoom.anchor_left = 0.615
	zoom.anchor_right = 0.662
	zoom.anchor_top = 0.05
	zoom.anchor_bottom = 0.05
	zoom.offset_bottom = 38.0
	zoom.pressed.connect(func() -> void:
		var close: bool = not bool(get_meta("zoom_close", false))
		set_zoom(close)
		zoom.text = "Full" if close else "Face")
	root.add_child(zoom)


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_dragging = (event as InputEventMouseButton).pressed
	elif event is InputEventMouseMotion and _dragging:
		_spin += (event as InputEventMouseMotion).relative.x * 0.012


func _refresh_model() -> void:
	if _rig != null:
		_rig.queue_free()
	_rig = CharacterLook.build(spec["look"])
	if _rig.has_method("set_barefoot"):
		_rig.call("set_barefoot", true)        # no foot wraps in the creator (Brent 2026-10-18)
	if _rig.has_method("set_stance"):
		_rig.call("set_stance", "menu")        # standing relaxed, not in the combat guard (Brent 2026-10-23)
	_pivot.add_child(_rig)


# --- panels ---------------------------------------------------------------------------------

func _clear(box: Container) -> void:
	for c: Node in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _refresh() -> void:
	_keep_name()
	_clear(_left)
	_clear(_right)
	_name_edit = null
	_build_left()
	match step:
		0:
			_build_origin()
		1:
			_build_appearance()
		2:
			_build_prime()
		3:
			_build_skills()
		_:
			_build_embark()
	_build_nav()


## Replace the whole draft (screenshots and tests).
func set_spec(new_spec: Dictionary) -> void:
	_name_edit = null
	spec = new_spec
	for idn: Dictionary in GameData.creation["identities"]:
		if str(idn["id"]) == str(spec.get("identity", "")) and CharacterLook.options().has("sex"):
			(spec["look"] as Dictionary)["sex"] = str(idn.get("sex", "male"))
	_refresh_model()
	_refresh()


func _keep_name() -> void:
	if _name_edit != null and is_instance_valid(_name_edit):
		spec["name"] = _name_edit.text.strip_edges()


func _go(to: int) -> void:
	_keep_name()
	step = clampi(to, 0, STEPS.size() - 1)
	_refresh()


func _build_left() -> void:
	var title := UiTheme.heading("ETHER SYNTAX", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_left.add_child(title)
	var sub := UiTheme.body("Who goes in?", 15, UiTheme.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_left.add_child(sub)
	_left.add_child(UiTheme.rule())
	for i: int in STEPS.size():
		var b := Button.new()
		b.text = "%d.   %s" % [i + 1, STEPS[i]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta("step", i)
		if i == step:
			b.add_theme_color_override("font_color", UiTheme.GOLD)
			b.add_theme_stylebox_override("normal", UiTheme.box(Color("3a3024"), UiTheme.GOLD, 1, 4, 10))
		b.pressed.connect(_go.bind(i))
		_left.add_child(b)
	_left.add_child(UiTheme.rule())

	# the draft so far
	var who: String = str(spec["name"]) if str(spec["name"]) != "" else "(unnamed)"
	_left.add_child(UiTheme.heading(who, 22))
	_left.add_child(UiTheme.body("%s   -   %s" % [_identity_label(), CharacterLook.label("body", str((spec["look"] as Dictionary).get("body", "")))], 14, UiTheme.TEXT_DIM))
	var t: Dictionary = TalentDB.get_talent(str(spec["talent_id"]))
	_left.add_child(UiTheme.body("Prime:  %s" % str(t.get("name", "?")), 15, UiTheme.STAR))
	_left.add_child(UiTheme.body("%s:  %s" % [_affinity_word(spec["affinities"]), _affinity_text(spec["affinities"])], 14, UiTheme.TEXT_DIM))
	_left.add_child(UiTheme.body("Skills:  %s" % _skill_names(), 14, UiTheme.TEXT_DIM))

	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left.add_child(gap)
	_build_test_characters()
	_left.add_child(UiTheme.rule())
	var save: Dictionary = SaveGame.read()
	if not save.is_empty() and str(save.get("talent_id", "")) != "":
		_left.add_child(UiWidgets.small_button("Continue  -  %s" % SaveGame.who(save), func() -> void: game.call("continue_game")))
	for slot: int in range(1, SaveGame.SLOTS + 1):
		if SaveGame.exists(SaveGame.slot_path(slot)):
			_left.add_child(UiWidgets.small_button("Load a saved character", func() -> void: game.call("open_saves")))
			break
	_left.add_child(UiWidgets.small_button("Controls", func() -> void: game.call("open_settings")))


## Test characters (Brent 2026-10-22): one button per affinity; each starts a character with that
## one affinity and every one of its skills learned (main.start_test_character). For trying skills,
## not for play: it is never autosaved over the real save.
func _build_test_characters() -> void:
	_left.add_child(UiTheme.rule())
	var head := UiTheme.heading("Test characters", 17)
	_left.add_child(head)
	_left.add_child(UiTheme.body("Every skill of one affinity, ready to try. Not saved over your character.", 12, UiTheme.TEXT_FAINT))
	_left.add_child(UiWidgets.test_character_grid(func(aff: String) -> void: game.call("start_test_character", aff)))


func _build_nav() -> void:
	if step == 0 or step == STEPS.size() - 1:
		# the other steps have a scrolling list that takes the spare height itself
		var gap := Control.new()
		gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_right.add_child(gap)
	_right.add_child(UiTheme.rule())
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	_right.add_child(row)
	row.add_child(UiWidgets.small_button("Back", _go.bind(step - 1), step > 0))
	var ready: bool = _chosen().size() == picks()
	if step < STEPS.size() - 1:
		row.add_child(UiWidgets.small_button("Next", _go.bind(step + 1), step != 3 or ready))
	else:
		var go := UiWidgets.small_button("Begin", _begin, ready)
		go.name = "BeginButton"
		go.add_theme_color_override("font_color", UiTheme.GOLD)
		row.add_child(go)


func _section(text: String) -> void:
	_right.add_child(UiTheme.heading(text, 19))


# --- step 1: origin ----------------------------------------------------------------------

func _build_origin() -> void:
	_right.add_child(UiTheme.heading("Origin", 28))
	_right.add_child(UiTheme.rule())
	_section("Name")
	var row := HBoxContainer.new()
	_right.add_child(row)
	_name_edit = LineEdit.new()
	_name_edit.name = "NameEdit"
	_name_edit.text = str(spec["name"])
	_name_edit.max_length = int(GameData.creation["name_max_length"])
	_name_edit.placeholder_text = "a name to be remembered by"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_submitted.connect(func(_t: String) -> void: _refresh())
	_name_edit.focus_exited.connect(_keep_name)
	row.add_child(_name_edit)
	row.add_child(UiWidgets.small_button("Random", func() -> void:
		spec["name"] = random_name()
		_name_edit.text = str(spec["name"])
		_refresh()))

	_section("Identity")
	var ids := HBoxContainer.new()
	_right.add_child(ids)
	for idn: Dictionary in GameData.creation["identities"]:
		ids.add_child(_choice(str(idn["label"]), str(spec["identity"]) == str(idn["id"]), _set_identity.bind(str(idn["id"]))))

	var bodies: Array = CharacterLook.options().get("body", [])
	if not bodies.is_empty():
		_section("Body type")
		var grid := GridContainer.new()
		grid.columns = 2
		_right.add_child(grid)
		for o: Dictionary in bodies:
			var b := _choice(str(o["label"]), str((spec["look"] as Dictionary).get("body", "")) == str(o["id"]), _set_look.bind("body", str(o["id"])))
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(b)
		_right.add_child(UiTheme.body("Build only. A body is tempered by what it survives, not by how it starts.", 13, UiTheme.TEXT_FAINT))


## Who the character is also decides the body's shape (the look's "sex"), when the model offers it.
func _set_identity(id: String) -> void:
	spec["identity"] = id
	for idn: Dictionary in GameData.creation["identities"]:
		if str(idn["id"]) == id and CharacterLook.options().has("sex"):
			(spec["look"] as Dictionary)["sex"] = str(idn.get("sex", "male"))
			_drop_hidden()
			_refresh_model()
	_refresh()


func random_name() -> String:
	var names: Array = GameData.creation["names"]
	return str(names[_rng.randi() % names.size()])


func _identity_label() -> String:
	for idn: Dictionary in GameData.creation["identities"]:
		if str(idn["id"]) == str(spec["identity"]):
			return str(idn["label"])
	return ""


func _choice(text: String, chosen: bool, on_press: Callable) -> Button:
	var b := UiWidgets.small_button(text, on_press)
	if chosen:
		b.add_theme_color_override("font_color", UiTheme.GOLD)
		b.add_theme_stylebox_override("normal", UiTheme.box(Color("3a3024"), UiTheme.GOLD, 1, 4, 10))
	return b


func _set_look(key: String, id: String) -> void:
	(spec["look"] as Dictionary)[key] = id
	_refresh_model()
	_refresh()


# --- step 2: appearance ---------------------------------------------------------------------

func _build_appearance() -> void:
	_right.add_child(UiTheme.heading("Appearance", 28))
	_right.add_child(UiTheme.rule())
	var opts: Dictionary = CharacterLook.options()
	var labels: Dictionary = GameData.creation["look_labels"]
	var list: VBoxContainer = scroller(_right)
	list.add_theme_constant_override("separation", 10)
	var shown := 0
	for key: String in GameData.creation["look_order"]:
		var choices: Array = opts.get(key, [])
		if choices.size() < 2:
			continue
		shown += 1
		var current: String = str((spec["look"] as Dictionary).get(key, ""))
		var head := HBoxContainer.new()
		list.add_child(head)
		var name_label := UiTheme.heading(str(labels.get(key, key.capitalize())), 18)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_label)
		var value := UiTheme.body(CharacterLook.label(key, current), 14, UiTheme.TEXT_DIM)
		value.autowrap_mode = TextServer.AUTOWRAP_OFF      # a wrapping label in a row collapses to one letter wide
		head.add_child(value)
		if (choices[0] as Dictionary).has("color"):
			var row := HFlowContainer.new()
			row.add_theme_constant_override("h_separation", 6)
			list.add_child(row)
			for o: Dictionary in choices:
				row.add_child(_swatch(key, o, current == str(o["id"])))
		else:
			var row2 := HBoxContainer.new()
			list.add_child(row2)
			row2.add_child(UiWidgets.small_button("  <  ", func() -> void: _set_look(key, _cycle(key, -1))))
			var mid := UiTheme.body(CharacterLook.label(key, current), 16)
			mid.autowrap_mode = TextServer.AUTOWRAP_OFF
			mid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row2.add_child(mid)
			row2.add_child(UiWidgets.small_button("  >  ", func() -> void: _set_look(key, _cycle(key, 1))))
	if shown == 0:
		list.add_child(UiTheme.body("No appearance options are available in this build.", 15, UiTheme.TEXT_DIM))
	else:
		_right.add_child(UiWidgets.small_button("Randomise", func() -> void:
			var keep: Dictionary = spec["look"]
			spec["look"] = CharacterLook.random_look(_rng)
			for key: String in ["body", "sex"]:              # chosen on the Origin step, not here
				if keep.has(key):
					(spec["look"] as Dictionary)[key] = keep[key]
			_drop_hidden()
			_refresh_model()
			_refresh()))


## Ids of `key` that are not offered to the current sex (creation.json "hidden_options").
func _hidden(key: String) -> Array:
	var sex: String = str((spec["look"] as Dictionary).get("sex", ""))
	return ((GameData.creation.get("hidden_options", {}) as Dictionary).get(sex, {}) as Dictionary).get(key, [])


## The next option for `key` in that direction, stepping over the ones hidden for this sex.
func _cycle(key: String, step: int) -> String:
	var trial: Dictionary = (spec["look"] as Dictionary).duplicate()
	var hidden: Array = _hidden(key)
	for i: int in (CharacterLook.options().get(key, []) as Array).size():
		trial[key] = CharacterLook.cycle(trial, key, step)
		if not hidden.has(trial[key]):
			break
	return str(trial[key])


## After the sex changes (or a random roll), move any option that is now hidden to one that is not.
func _drop_hidden() -> void:
	for key: String in (spec["look"] as Dictionary).keys():
		if _hidden(key).has((spec["look"] as Dictionary)[key]):
			(spec["look"] as Dictionary)[key] = _cycle(key, 1)


func _swatch(key: String, option: Dictionary, chosen: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(38, 38)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = str(option.get("label", ""))
	var col: Color = option["color"]
	for state: String in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(state, UiTheme.box(col, UiTheme.GOLD if (chosen or state == "hover") else UiTheme.BRONZE_DIM, 3 if chosen else 1, 4, 0))
	b.pressed.connect(_set_look.bind(key, str(option["id"])))
	return b


# --- step 3: prime ------------------------------------------------------------------------

func _build_prime() -> void:
	_right.add_child(UiTheme.heading("Prime vestige", 28))
	_right.add_child(UiTheme.body("Three lie on the table. Each holds one power and one, two or - almost never - three affinities, and the two have nothing to do with each other. You may only ever take one.", 14, UiTheme.TEXT_DIM))
	_right.add_child(UiTheme.rule())
	var list: VBoxContainer = scroller(_right)
	list.add_theme_constant_override("separation", 6)
	for i: int in offers.size():
		var o: Dictionary = offers[i]
		var t: Dictionary = TalentDB.get_talent(str(o["talent_id"]))
		var affs: Array = o["affinities"]
		var chosen: bool = str(spec["talent_id"]) == str(o["talent_id"])
		var b := UiWidgets.service_button(str(t.get("name", "?")), "\"%s\"" % str(t.get("verse", "")), _affinity_text(affs), func() -> void:
			_take(i)
			_refresh())
		b.set_meta("offer", i)
		if chosen:
			b.add_theme_stylebox_override("normal", UiTheme.box(Color("3a3024"), UiTheme.GOLD, 2, 4, 10))
		list.add_child(b)
		var tag := UiTheme.body(_rarity_text(affs.size()), 12, _rarity_color(affs.size()))
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		list.add_child(tag)
	var again := UiWidgets.small_button("Ask for three others   (%d left)" % rerolls_left, func() -> void:
		rerolls_left -= 1
		roll_offers()
		_refresh(), rerolls_left > 0)
	again.name = "RerollButton"
	list.add_child(again)

	# what the chosen prime says about itself
	var t2: Dictionary = TalentDB.get_talent(str(spec["talent_id"]))
	_right.add_child(UiTheme.rule())
	_right.add_child(UiTheme.heading(str(t2.get("name", "?")), 20))
	_right.add_child(UiTheme.body(str(t2.get("rule", "")), 14))
	_right.add_child(UiTheme.body("At two stars:  %s" % str(t2.get("evolve_2", "unknown")), 13, UiTheme.TEXT_DIM))
	var unknowns: Array = t2.get("hidden", [])
	if not unknowns.is_empty():
		_right.add_child(UiTheme.body("Still to be proven:  %s" % str(unknowns[0]), 13, UiTheme.TEXT_FAINT))
	for aff: String in spec["affinities"]:
		var a: Dictionary = GameData.affinity(aff)
		_right.add_child(UiTheme.body("%s affinity:  %s" % [str(a.get("label", aff)), str(a.get("desc", ""))], 13, GameData.affinity_color(aff).lightened(0.25)))


func _affinity_text(affs: Array) -> String:
	var parts: Array[String] = []
	for aff: Variant in affs:
		parts.append(str(GameData.affinity(str(aff)).get("label", aff)))
	return ", ".join(parts)


func _affinity_word(affs: Array) -> String:
	return "Affinity" if affs.size() <= 1 else "Affinities"


func _rarity_text(slots: int) -> String:
	match PrimeRoll.rarity(slots):
		"rare":
			return "two affinities  -  rare"
		"legendary":
			return "three affinities  -  almost unheard of"
	return "one affinity"


func _rarity_color(slots: int) -> Color:
	match PrimeRoll.rarity(slots):
		"rare":
			return UiTheme.STAR
		"legendary":
			return UiTheme.GOLD
	return UiTheme.TEXT_FAINT


# --- step 4: skills -------------------------------------------------------------------------

## How many starting skills are picked (data/skill_tree.json "start_picks").
func picks() -> int:
	return int(GameData.skill_tree.get("start_picks", 2))


func _chosen() -> Array:
	return spec.get("skills", [])


## Pick a starting skill, or put one back. Only the prime's root skills can be picked, and only
## `picks()` of them; a full hand has to put one back first.
func toggle_skill(id: String) -> void:
	var chosen: Array = _chosen()
	if chosen.has(id):
		chosen.erase(id)
	elif chosen.size() < picks() and GameData.skill_roots(spec["affinities"]).has(id):
		chosen.append(id)
	spec["skills"] = chosen
	_refresh()


func _build_skills() -> void:
	_right.add_child(UiTheme.heading("Skills", 28))
	var chosen: Array = _chosen()
	_right.add_child(UiTheme.body("Nothing is given. Pick %d skills to start with from what your %s can do. Everything else is trained in town, for skill points that come as your star grows." % [
		picks(), _affinity_word(spec["affinities"]).to_lower()], 14, UiTheme.TEXT_DIM))
	var count := UiTheme.body("%d of %d chosen" % [chosen.size(), picks()], 15, UiTheme.GOLD if chosen.size() == picks() else UiTheme.TEXT)
	count.name = "PickCount"
	_right.add_child(count)
	_right.add_child(UiTheme.rule())
	var list: VBoxContainer = scroller(_right)
	list.add_theme_constant_override("separation", 6)
	for aff: String in spec["affinities"]:
		list.add_child(UiTheme.heading(str(GameData.affinity(aff).get("label", aff)), 17, GameData.affinity_color(aff).lightened(0.3)))
		for id: String in GameData.skill_roots([aff]):
			var ab: Dictionary = GameData.ability(id)
			var on: bool = chosen.has(id)
			var b := UiWidgets.service_button(str(ab.get("name", id)), str(ab.get("summary", ab.get("verse", ""))), "chosen" if on else "",
				toggle_skill.bind(id), on or chosen.size() < picks())
			b.set_meta("skill", id)
			b.custom_minimum_size.y = 84                # room for a three-line summary
			if on:
				b.add_theme_stylebox_override("normal", UiTheme.box(Color("3a3024"), UiTheme.GOLD, 2, 4, 10))
			list.add_child(b)


func _skill_names() -> String:
	var names: Array[String] = []
	for id: Variant in _chosen():
		names.append(str(GameData.ability(str(id)).get("name", id)))
	return ", ".join(names) if not names.is_empty() else "(none yet)"


# --- step 5: embark -------------------------------------------------------------------------

func _build_embark() -> void:
	_right.add_child(UiTheme.heading("Embark", 28))
	_right.add_child(UiTheme.rule())
	var t: Dictionary = TalentDB.get_talent(str(spec["talent_id"]))
	_right.add_child(UiWidgets.stat_row("Name", str(spec["name"]) if str(spec["name"]) != "" else "(unnamed - one will be given)"))
	_right.add_child(UiWidgets.stat_row("Identity", _identity_label()))
	_right.add_child(UiWidgets.stat_row("Prime", str(t.get("name", "?")), UiTheme.STAR))
	_right.add_child(UiWidgets.stat_row(_affinity_word(spec["affinities"]), _affinity_text(spec["affinities"]), _rarity_color((spec["affinities"] as Array).size()).lightened(0.3)))
	_right.add_child(UiWidgets.stat_row("Skills", _skill_names(), UiTheme.TEXT if _chosen().size() == picks() else UiTheme.BAD))
	if _chosen().size() != picks():
		_right.add_child(UiTheme.body("Pick %d skills first (step 4)." % picks(), 13, UiTheme.BAD))
	_right.add_child(UiWidgets.stat_row("Purse", UiTheme.money_text(GameData.inum("town", "starting_money")), UiTheme.GOLD))
	_right.add_child(UiWidgets.stat_row("Soul", "one star, barely lit"))
	_right.add_child(UiTheme.rule())
	var hardcore: bool = bool(game.get("hardcore"))
	_right.add_child(UiWidgets.service_button("Hardcore", "Death is permanent. Otherwise you wake in town, in debt.", "ON" if hardcore else "off", func() -> void:
		game.call("toggle_hardcore")
		_refresh()))


func _begin() -> void:
	_keep_name()
	if _chosen().size() != picks():
		_go(3)
		return
	if str(spec["name"]) == "":
		spec["name"] = random_name()
	game.call("begin_character", spec.duplicate(true))
