extends UiScreen
## The ascension screen (Brent 2026-10-24): shown when a star ascends, until it is settled.
## Step 1, the offer: the affinities to choose from (`Offer_<id>`, each with its colour, its role
## and, for a hybrid, its parents) and, when the data allows it, `DeclineOffer`. Step 2, the boosts:
## every skill held, its stage and its boost, and one button per aspect (`Aspect_<i>_<aspect>`)
## showing what it would change, before -> after; the skill's main aspect is preselected.
## `AscendConfirm` settles it with these choices; `AscendSkip` settles it with every skill on its
## main aspect (and the chosen affinity, if one was). Rules: `Ascension`, `Player.resolve_ascension`.

var step := "offer"                    # "offer" | "boost"
var chosen := ""                       # the affinity picked ("" = none / declined)
var aspects: Dictionary = {}           # skill index -> aspect id
var _said := ""


func _init(game_node: Node) -> void:
	super(game_node)
	var pending: Dictionary = player.get("ascension_pending")
	if (pending.get("offer", []) as Array).is_empty():
		step = "boost"
	var held: int = (player.get("abilities") as Array).size()
	for b: Dictionary in pending.get("skills", []):
		var i: int = int(b["index"])
		if i >= 0 and i < held:
			aspects[i] = str(player.call("ascension_aspect", i, ""))


func backdrop() -> float:
	return 0.86


func hud_hides() -> Array[String]:
	return HUD_MENU


func _pending() -> Dictionary:
	return player.get("ascension_pending")


## Pick an offered affinity and go on to the boosts.
func choose(affinity: String) -> void:
	chosen = affinity
	step = "boost"
	rebuild()


## Turn the offer down (only offered when balance "ascension" allow_decline is true).
func decline() -> void:
	chosen = ""
	step = "boost"
	rebuild()


func back() -> void:
	if not (_pending().get("offer", []) as Array).is_empty():
		step = "offer"
		rebuild()


## Put skill `index`'s boost into `aspect`.
func set_aspect(index: int, aspect: String) -> void:
	aspects[index] = aspect
	rebuild()


func confirm() -> void:
	var why: String = str(game.call("resolve_ascension", chosen, aspects.duplicate()))
	if why != "":
		_said = why
		rebuild()


## Settle with every skill on its main aspect.
func skip() -> void:
	var why: String = str(game.call("resolve_ascension", chosen, {}))
	if why != "":
		_said = why
		rebuild()


static func _ordinal(n: int) -> String:
	var words: Array[String] = ["first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth"]
	return words[n - 1] if n >= 1 and n <= words.size() else "%dth" % n


static func _pct(f: float) -> String:
	var v: float = f * 100.0
	return ("+%d%%" % int(round(v))) if absf(v - round(v)) < 0.05 else ("+%.1f%%" % v)


func build(root: Control) -> void:
	var box: VBoxContainer = framed(root, 0.12, 0.1, 0.88, 0.84) if step == "offer" else framed(root, 0.04, 0.04, 0.96, 0.96)
	box.name = "AscensionPanel"
	box.add_theme_constant_override("separation", 10)
	var star: int = int(_pending().get("star", player.get("stars")))
	var t := UiTheme.heading("ASCENSION", UiTheme.FS_DISPLAY, UiTheme.STAR)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var sub := UiTheme.body("A %s star splits from the first. It brings an affinity, if you take one, and it sharpens every skill you hold." % _ordinal(star)
		if step == "offer" else "Your skills ascend with the star. Choose, for each, what the boost improves.", 16, UiTheme.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(UiTheme.rule())
	if step == "offer":
		_build_offer(box)
	else:
		_build_boost(box)
	if _said != "":
		box.add_child(UiTheme.body(_said, 14, UiTheme.BAD))


# --- step 1: the affinities ------------------------------------------------------------------

func _build_offer(box: VBoxContainer) -> void:
	box.add_child(UiTheme.section("An affinity to add"))
	var held: Array = player.get("affinities")
	box.add_child(UiTheme.body("You hold %s. A new affinity opens its skill tree and its runes; its skills are still trained." % " and ".join(PackedStringArray(
		held.map(func(a: Variant) -> String: return str(GameData.affinity(str(a)).get("label", a))))), 14, UiTheme.TEXT_FAINT))
	var row := HBoxContainer.new()
	row.name = "OfferRow"
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)
	for id: Variant in _pending().get("offer", []):
		row.add_child(_offer_card(str(id), held))
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(foot)
	if Ascension.allow_decline():
		var d: Button = UiWidgets.small_button("Keep the affinities I have", decline)
		d.name = "DeclineOffer"
		d.custom_minimum_size = Vector2(280, 40)
		foot.add_child(d)


func _offer_card(id: String, held: Array) -> Control:
	var aff: Dictionary = GameData.affinity(id)
	var col: Color = GameData.affinity_color(id)
	var b := Button.new()
	b.name = "Offer_" + id
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 380)
	b.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.PANEL, col.darkened(0.35), 2, 6, 14))
	b.add_theme_stylebox_override("hover", UiTheme.box(UiTheme.PANEL_HI, col, 3, 6, 14))
	b.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.PANEL_HI, col, 3, 6, 14))
	b.pressed.connect(choose.bind(id))
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 20
	v.offset_right = -20
	v.offset_top = 16
	v.offset_bottom = -16
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var band := ColorRect.new()
	band.color = col
	band.custom_minimum_size = Vector2(0, 6)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(band)
	var name_l := UiTheme.heading(str(aff.get("label", id)), UiTheme.FS_TITLE + 4, col.lightened(0.15))
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_l)
	var parents: Array[String] = GameData.affinity_parents(id)
	var kind_row := HBoxContainer.new()
	kind_row.name = "Kind"
	kind_row.add_theme_constant_override("separation", 6)
	kind_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(kind_row)
	if parents.is_empty():
		kind_row.add_child(_label("BASE AFFINITY", 14, UiTheme.GOLD))
	else:
		kind_row.add_child(_label("HYBRID OF", 14, UiTheme.GOLD))
		for k: int in parents.size():
			var p: String = parents[k]
			kind_row.add_child(_label(str(GameData.affinity(p).get("label", p)) + (" (held)" if held.has(p) else ""), 15, GameData.affinity_color(p).lightened(0.2)))
			if k < parents.size() - 1:
				kind_row.add_child(_label("+", 15, UiTheme.TEXT_DIM))
	var role := UiTheme.body(str(aff.get("role", "")), 17, UiTheme.TEXT)
	role.name = "Role"
	role.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(role)
	var desc := UiTheme.body(str(aff.get("desc", "")), 14, UiTheme.TEXT_DIM)
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(desc)
	var rule := UiTheme.body(str(aff.get("rule", "")), 13, UiTheme.TEXT_FAINT)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(rule)
	var kit: Array = (aff.get("kit", []) as Array).map(func(k: Variant) -> String: return str(GameData.ability(str(k)).get("name", k)))
	var kit_l := UiTheme.body("Its tree begins with %s." % ", ".join(PackedStringArray(kit)), 14, UiTheme.TEXT_DIM)
	kit_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(kit_l)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(gap)
	var why := _label("Grown from what you hold" if Ascension.is_hybrid_for(id, held) else "A new path", 14, UiTheme.STAR)
	why.name = "Why"
	why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(why)
	var take := _label("Take %s" % str(aff.get("label", id)), 18, col.lightened(0.25))
	take.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(take)
	return b


static func _label(text: String, px: int, color: Color) -> Label:
	var l := UiTheme.body(text, px, color)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# --- step 2: the boosts ----------------------------------------------------------------------

func _build_boost(box: VBoxContainer) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	var took := UiTheme.body("New affinity:  %s" % str(GameData.affinity(chosen).get("label", chosen)) if chosen != "" else "No new affinity.", 17,
		GameData.affinity_color(chosen).lightened(0.2) if chosen != "" else UiTheme.TEXT_DIM)
	took.name = "ChosenAffinity"
	took.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(took)
	if not (_pending().get("offer", []) as Array).is_empty():
		var bk: Button = UiWidgets.small_button("Back to the affinities", back)
		bk.name = "AscendBack"
		head.add_child(bk)
	var skills: Array = _pending().get("skills", [])
	var star: int = int(_pending().get("star", 2))
	box.add_child(UiTheme.body("The star's pool, %s, is shared by the %d skill%s you hold; a skill at a higher stage takes a larger share (x(1 + %s x stage)). It is not a level: no stage or lock moves." % [
		_pct(Ascension.pool(star)).trim_prefix("+"), skills.size(), "" if skills.size() == 1 else "s", str(Ascension.cfg().get("stage_weight", 0.0))], 13, UiTheme.TEXT_FAINT))
	var list: VBoxContainer = scroller(box)
	list.name = "BoostList"
	list.add_theme_constant_override("separation", 6)
	var abilities: Array = player.get("abilities")
	for b: Dictionary in skills:
		var i: int = int(b["index"])
		if i < 0 or i >= abilities.size():
			continue
		list.add_child(_skill_row(i, abilities[i], float(b["amount"])))
		list.add_child(UiTheme.rule())
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 16)
	box.add_child(foot)
	var sk: Button = UiWidgets.small_button("Skip: each skill's main aspect", skip)
	sk.name = "AscendSkip"
	sk.custom_minimum_size = Vector2(280, 44)
	foot.add_child(sk)
	var ok: Button = UiWidgets.small_button("Ascend", confirm)
	ok.name = "AscendConfirm"
	ok.custom_minimum_size = Vector2(220, 44)
	ok.add_theme_stylebox_override("normal", UiTheme.box(Color("3a3024"), UiTheme.GOLD, 2, 4, 10))
	ok.add_theme_color_override("font_color", UiTheme.GOLD)
	foot.add_child(ok)


func _skill_row(i: int, st: Dictionary, amount: float) -> Control:
	var ab: Dictionary = player.call("ability_stats", st)
	var row := HBoxContainer.new()
	row.name = "BoostRow_%d" % i
	row.add_theme_constant_override("separation", 10)
	var aff_col: Color = GameData.affinity_color(str(ab.get("affinity", "")))
	row.add_child(UiWidgets.Icon.new(str(ab.get("icon", "drop")), aff_col.lightened(0.3), 44.0))
	var name_col := VBoxContainer.new()
	name_col.custom_minimum_size = Vector2(190, 0)
	name_col.add_theme_constant_override("separation", 0)
	name_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_col)
	name_col.add_child(_label(str(ab.get("name", "?")), 16, UiTheme.TEXT))
	var amt := _label("stage %d   %s" % [int(st["stage"]), _pct(amount)], 14, UiTheme.STAR)
	amt.name = "Amount"
	name_col.add_child(amt)
	var main: String = Ascension.main_aspect(ab)
	for asp: String in Ascension.aspect_ids():
		row.add_child(_aspect_button(i, asp, amount, ab, asp == main))
	return row


func _aspect_button(i: int, asp: String, amount: float, ab: Dictionary, is_main: bool) -> Button:
	var acts: bool = Ascension.aspect_acts(ab, asp)
	var here: bool = str(aspects.get(i, "")) == asp
	var b := Button.new()
	b.name = "Aspect_%d_%s" % [i, asp]
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not acts
	b.toggle_mode = false
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(150, 62)
	b.tooltip_text = str(Ascension.aspect(asp).get("desc", ""))
	if here:
		b.add_theme_stylebox_override("normal", UiTheme.box(Color("3a3024"), UiTheme.GOLD, 2, 4, 8))
		b.add_theme_stylebox_override("hover", UiTheme.box(Color("3a3024"), UiTheme.GOLD.lightened(0.2), 2, 4, 8))
	b.pressed.connect(set_aspect.bind(i, asp))
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 8
	v.offset_right = -8
	v.offset_top = 4
	v.offset_bottom = -4
	v.add_theme_constant_override("separation", 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var title: String = str(Ascension.aspect(asp).get("label", asp)) + ("  (main)" if is_main else "")
	v.add_child(_label(title, 15, (UiTheme.GOLD if here else UiTheme.TEXT) if acts else UiTheme.TEXT_FAINT))
	var lines: Array[String] = []
	if acts:
		for r: Dictionary in (player.call("ascension_preview", i, asp, amount) as Array).slice(0, 2):
			lines.append("%s %s -> %s" % [str(r["label"]), str(r["before"]), str(r["after"])])
	var shown := _label("\n".join(PackedStringArray(lines)) if not lines.is_empty() else ("nothing to change" if not acts else "no number moves"), 12,
		UiTheme.TEXT_DIM if acts else UiTheme.TEXT_FAINT)
	shown.name = "Preview"
	shown.clip_text = true
	v.add_child(shown)
	return b
