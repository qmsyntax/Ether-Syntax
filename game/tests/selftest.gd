extends Node
## Headless rules self-test. Run:
##   godot --headless --path game res://tests/selftest.tscn
## Exercises wound maths, natural healing, arm loss/regrowth, healer credit and rent directly,
## because the auto-play smoke check never touches them. Proves the rules compute as specified;
## proves nothing about feel or balance.

const PlayerScript := preload("res://scripts/player.gd")
const FreeRules := preload("res://tests/free_rules.gd")

var _failed := 0
var _passed := 0
var _errors: ErrorCatcher


func _ready() -> void:
	_errors = ErrorCatcher.install()
	# `-- --only=runes` runs just the rune checks (quicker while working on runes)
	if OS.get_cmdline_user_args().has("--only=statuses"):
		await _test_status_text()
		_check("no script error was raised during the run", _errors.count() == 0, "%d, first: %s" % [_errors.count(), _errors.first()])
		print("SELFTEST: %d passed, %d failed" % [_passed, _failed])
		get_tree().quit(1 if _failed > 0 else 0)
		return
	if OS.get_cmdline_user_args().has("--only=runes"):
		await _test_runes()
		await _test_rune_effects()
		await _test_seals()
		_test_strength_rules()
		await _test_seal_editing()
		await _test_rune_discovery()
		_check("no script error was raised during the run", _errors.count() == 0, "%d, first: %s" % [_errors.count(), _errors.first()])
		print("SELFTEST: %d passed, %d failed" % [_passed, _failed])
		get_tree().quit(1 if _failed > 0 else 0)
		return
	_test_body()
	_test_natural_healing()
	_test_arm_loss_and_regrowth()
	_test_healer_credit_and_rent()
	_test_death_and_rest()
	_test_keybinds()
	_test_pipeline()
	_test_lifesteal_feedback()
	await _test_abilities()
	_test_stars()
	await _test_click_melee()
	await _test_inventory()
	_test_slot_assignment()
	await _test_weapons()
	_test_character()
	await _test_playtest_1011()
	_test_tempering()
	await _test_water_and_lightning()
	await _test_gear_step_1()
	await _test_inventory_doll()
	await _test_fire()
	await _test_wind()
	await _test_earth()
	await _test_archer_steering()
	await _test_step4_enemies()
	await _test_step5a()
	await _test_step5b()
	await _test_pathfinding()
	await _test_combat_rules()
	_test_affinities()
	_test_fog_map()
	_test_models()
	await _test_netherecho()
	_test_real_bodies()
	_test_real_enemies()
	await _test_stances()
	_test_skill_tree()
	await _test_town()
	_test_crafting()
	await _test_crafting_town()
	await _test_runes()
	await _test_rune_effects()
	await _test_seals()
	_test_strength_rules()
	await _test_seal_editing()
	await _test_rune_discovery()
	await _test_build_1022()
	await _test_status_text()
	# a script error aborts one function and lets the checks around it pass; count it as a failure
	_check("no script error was raised during the run", _errors.count() == 0, "%d, first: %s" % [_errors.count(), _errors.first()])
	print("SELFTEST: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


## Status definitions and skill details (Brent 2026-10-23: "What does Masked mean?"): every status has
## a written desc and a rules line; every key a status uses is worded or explicitly ignored, and each
## worded key really changes the line; what a skill applies, for how long, and what it only reads;
## the ethercosm's numbers for a shove, a chain and a sealed change.
func _test_status_text() -> void:
	print("status definitions and skill details (2026-10-23):")
	var ids: Array[String] = GameData.status_ids()
	var no_desc: Array[String] = []
	var no_rules: Array[String] = []
	for id: String in ids:
		if StatusText.desc(id).strip_edges() == "":
			no_desc.append(id)
		if StatusText.rules(id).strip_edges() == "":
			no_rules.append(id)
	_check("every status (%d) has a written desc, an alias its target's" % ids.size(), no_desc.is_empty(), str(no_desc))
	_check("every status has a rules line", no_rules.is_empty(), str(no_rules))
	var unexplained: Array[String] = []
	for k: String in StatusText.keys_in_use():
		if not StatusText.WORDED.has(k) and not StatusText.IGNORED.has(k):
			unexplained.append(k)
	_check("every key a status uses is worded or listed as ignored", unexplained.is_empty(), "explain: %s" % str(unexplained))
	# a worded key must really say something: drop it from a status that has it and the line changes
	var silent: Array[String] = []
	for k2: String in StatusText.WORDED:
		var users: Array[String] = ids.filter(func(id: String) -> bool: return GameData.status(id).has(k2))
		if users.is_empty():
			continue
		var moves := false
		for id2: String in users:
			var def: Dictionary = GameData.status(id2).duplicate(true)
			var line: String = StatusText.rules_of(def)
			def.erase(k2)
			if StatusText.rules_of(def) != line:
				moves = true
		if not moves:
			silent.append(k2)
	_check("every worded key changes the rules line of a status that has it", silent.is_empty(), "silent: %s" % str(silent))
	_check("an alias reads as what it stands for (Rooted is Pinned)", StatusText.rules("rooted") == StatusText.rules("pinned")
		and StatusText.label("rooted") == StatusText.label("pinned") and StatusText.desc("rooted") == StatusText.desc("pinned"))
	var masked: Dictionary = GameData.status("masked")
	_check("Masked's rules say how far its friends are drawn, the heavy rule and the elite rule",
		StatusText.rules("masked").contains("%d m" % int(masked["lure_radius"])) and StatusText.rules("masked").contains("half as long")
		and StatusText.rules("masked").contains("elites get %s instead" % StatusText.label(str(masked["elite_status"]))))
	_check("a skill's own duration replaces the status's in its rules line", StatusText.rules("masked", 9.0).begins_with("Lasts 9 s"))
	# the rune view's "+ applies Brittle" lines: the definition as a tooltip, and a click opens it in place
	var sl: Control = UiWidgets.status_line("  +  applies Brittle (lasts x0.50)", 13, UiTheme.STAR)
	var sl_label: Label = sl.get_child(0) as Label if sl.get_child_count() > 0 else null
	var sl_defs: Control = sl.find_child("StatusLineDefs", true, false) as Control
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	var shut_before: bool = sl_defs != null and not sl_defs.visible
	if sl_label != null:
		sl_label.gui_input.emit(press)
	_check("a rune line naming a status carries its definition as a tooltip, and a click opens it in place",
		sl_label != null and sl_label.tooltip_text.contains(StatusText.desc("brittle")) and sl_label.mouse_filter == Control.MOUSE_FILTER_STOP
		and shut_before and sl_defs.visible)
	sl.free()
	var plain: Control = UiWidgets.status_line("+12% damage", 13, UiTheme.STAR)
	_check("a line naming no status stays a plain label", plain is Label)
	plain.free()
	_check("statuses are found in a line by name, whole words only", StatusText.mentioned("+1 stack of Brittle") == (["brittle"] as Array[String])
		and StatusText.mentioned("a litany of nothing").is_empty())

	# what a skill applies, for how long as it applies it, and what it only reads
	var cm: Array[Dictionary] = StatusText.applied_by(GameData.ability("changeling_mask"))
	_check("Changeling Mask applies Masked, for Masked's own time", cm.size() == 1 and str(cm[0]["id"]) == "masked" and _near(float(cm[0]["lasts"]), float(masked["lasts"])))
	var gk: Dictionary = GameData.ability("gullet_knot")
	var gka: Array[Dictionary] = StatusText.applied_by(gk)
	var frac: float = float((gk["on_hit"] as Dictionary)["status_s_if_not"]["frac"])
	_check("Gullet Knot applies Choked, shorter unless it is Bleeding - and only reads Bleeding",
		gka.size() == 1 and str(gka[0]["id"]) == "choked" and str(gka[0]["notes"]).contains(StatusText._n(float(gka[0]["lasts"]) * frac) + " s unless it is Bleeding")
		and StatusText.read_by(gk).has("bleeding"), "%s / %s" % [str(gka), str(StatusText.read_by(gk))])
	var ic: Array[Dictionary] = StatusText.applied_by(GameData.ability("iron_clasp"))
	_check("Iron Clasp's Shackled lasts its skill's time, longer per class of metal", ic.size() == 1 and _near(float(ic[0]["lasts"]), float((GameData.ability("iron_clasp")["on_hit"] as Dictionary)["status_s"]))
		and str(ic[0]["notes"]).contains("per class of metal"), str(ic))
	_check("Drawdown only spends Soaked", StatusText.applied_by(GameData.ability("drawdown")).is_empty() and StatusText.read_by(GameData.ability("drawdown")).has("soaked"))
	var cmp: Array[Dictionary] = StatusText.compare({"on_hit": {"status": "soaked"}},
		{"on_hit": {"status": "soaked", "status_time_mult": 1.5, "statuses": [{"id": "silenced", "stacks": 1, "lasts": 2.0}]}})
	var soak_s: float = float(GameData.status("soaked")["lasts"])
	_check("a sealed word's longer status shows beside the skill's own, and a status it adds is marked as added",
		cmp.size() == 2 and _near(float(cmp[0]["lasts"]), soak_s * 1.5) and _near(float(cmp[0]["lasts_before"]), soak_s) and not bool(cmp[0]["added"])
		and str(cmp[1]["id"]) == "silenced" and _near(float(cmp[1]["lasts"]), 2.0) and bool(cmp[1]["added"]), str(cmp))

	# the ethercosm's numbers: a water shove, a lightning chain, a sealed change
	var p := _new_player()
	p.call("set_affinities", ["water", "lightning"])
	p.call("learn", "forked_path")
	var names: Array = (p.get("abilities") as Array).map(func(s: Dictionary) -> String: return str(s["id"]))
	var wb: Dictionary = p.call("skill_details", names.find("water_bolt"))
	var shove_row: Array = (wb.get("rows", []) as Array).filter(func(r: Dictionary) -> bool: return str(r["label"]) == "Shove")
	_check("Water Bolt's numbers include its shove, in metres", shove_row.size() == 1
		and str(shove_row[0]["after"]) == "%s m" % StatusText._n(float((GameData.ability("water_bolt")["on_hit"] as Dictionary)["shove"])), str(shove_row))
	_check("and its statuses, Soaked", (wb.get("statuses", []) as Array).any(func(s: Dictionary) -> bool: return str(s["id"]) == "soaked"))
	var fp: Dictionary = p.call("skill_details", names.find("forked_path"))
	var labels: Array = (fp.get("rows", []) as Array).map(func(r: Dictionary) -> String: return str(r["label"]))
	_check("Forked Path's numbers include its jumps, what each jump does, and its Live mark", labels.has("Jumps") and labels.has("Damage, each jump") and labels.has("Live marks"), str(labels))
	_check("every skill's numbers name its recovery and the reflux it leaves", labels.has("Recovery") and labels.has("Reflux left behind"))
	var rows: Array[Dictionary] = p.call("_stat_rows", {"on_hit": {"shove": 1.5}}, {"on_hit": {"shove": 2.5}, "pierce": true},
		[{"path": "on_hit.shove", "group": "shown", "label": "Shove", "unit": " m"}, {"path": "pierce", "group": "shown", "label": "Pierces", "bool": true}], 1.0)
	_check("a sealed number shows beside the skill's own (more shove is better; a word that adds a pierce)",
		rows.size() == 2 and str(rows[0]["before"]) == "1.5 m" and str(rows[0]["after"]) == "2.5 m" and bool(rows[0]["changed"]) and bool(rows[0]["better"])
		and str(rows[1]["before"]) == "no" and str(rows[1]["after"]) == "yes", str(rows))
	p.queue_free()


## Every affinity's skills (build brief 2026-10-22): the status engine, the rune-engine rule changes
## in play, each new affinity's rule, and a test character. Numbers come from the data.
func _test_build_1022() -> void:
	print("every affinity's skills (build brief 2026-10-22):")
	var p := _new_player()
	p.global_position = Vector3(900, 0, 0)
	var world := _test_floor(p.global_position)
	await get_tree().physics_frame
	_bare(p)
	p.set("effects", [] as Array[TalentEffect])

	# ---- status stacking: Chill builds to Frozen, which counts as Brittle; a hard hit Shatters it
	p.call("set_affinities", ["ice"])
	var e := _foe(p, Vector3(0, 0, -2.0))
	var cap: int = int(GameData.status("chilled")["stacks"])
	e.call("add_status", "chilled", cap - 2, p)
	_check("Chill stacks on a body", int(e.call("status_stacks", "chilled")) == cap - 2)
	e.call("add_status", "chilled", 2, p)
	_check("at %d Chill it freezes solid and the Chill clears" % cap, bool(e.call("has_status", "frozen")) and not bool(e.call("has_status", "chilled")))
	_check("a Frozen body counts as Brittle", bool(e.call("has_status", "brittle")))
	var shatter: Dictionary = GameData.status("brittle")["shatter"]
	var lost0: float = _lost(e)
	p.call("apply_hit", e, {"damage": 10.0, "poise": float(shatter["hard_poise"])}, ["ability", "ice"])
	_check("a hard hit Shatters it: the shatter's damage, not halved, and it is free", _lost(e) - lost0 >= float(shatter["damage"]) and not bool(e.call("has_status", "frozen")),
		"lost %f" % (_lost(e) - lost0))
	# a rune's status op on a skill that already applies that status adds stacks
	var bond: RuneRules = Runes.make("bond_v1")
	var fxp: Dictionary = (bond.params["interaction_params"] as Dictionary)["effects_v1"]
	var stacked := false
	for pair: Array in [["set_solid", "ICE-2a"], ["hoarline", "ICE-1a"]]:
		var fx: Dictionary = bond.effects(_raw_word([GameData.skill_anchor(str(pair[0])), str(pair[1])], [[0, 1]]), _rctx(str(pair[0]), 3))
		var want: int = int((GameData.ability(str(pair[0]))["on_hit"] as Dictionary).get("stacks", 1))
		if float(_row(fx, 1)["strength"]) >= float(fxp["status_threshold"]):
			stacked = stacked or (fx["patch"] as Array).any(func(o: Dictionary) -> bool: return str(o["path"]) == "on_hit.stacks" and int(o["value"]) > want)
	_check("an ice rune's Chill on an ice skill that already chills adds stacks", stacked)
	e.queue_free()
	await get_tree().process_frame                  # gone before the next bodies stand where it stood

	# ---- jumps on a hit that is not a chain
	p.call("set_affinities", ["water"])
	var j1 := _foe(p, Vector3(0, 0, -2.0))
	var j2 := _foe(p, Vector3(2.0, 0, -2.5))
	var j3 := _foe(p, Vector3(0, 0, -12.0))
	p.call("apply_hit", j1, {"damage": 100.0, "jumps": 1}, ["ability", "water"])
	_check("a hit with a jump arcs on to the nearest other enemy for less", _near(_lost(j1), 100.0) and _near(_lost(j2), 100.0 * GameData.num("skills", "jump_damage_mult")) and _near(_lost(j3), 0.0),
		"%f %f %f" % [_lost(j1), _lost(j2), _lost(j3)])
	for n: Node in [j1, j2, j3]:
		n.queue_free()
	await get_tree().process_frame

	# ---- through: past the front guard
	var brute := _foe(p, Vector3(0, 0, -2.0), "brute")
	var front: float = float(GameData.enemy("brute")["front_armour"])
	p.call("apply_hit", brute, {"damage": 100.0, "poise": 0.0}, ["ability", "water"])
	var guarded: float = _lost(brute)
	p.call("apply_hit", brute, {"damage": 100.0, "poise": 0.0, "through": true}, ["ability", "water"])
	_check("a hit that goes through ignores the front guard (%.0f%% otherwise)" % (front * 100.0), _near(guarded, 100.0 * (1.0 - front)) and _near(_lost(brute) - guarded, 100.0),
		"%f %f" % [guarded, _lost(brute) - guarded])

	# ---- light: Lit halves the front guard
	brute.call("add_status", "lit", 1, p)
	_check("a Lit body's front guard counts half", _near(float(brute.call("front_armour")), front * float(GameData.status("lit")["armour_mult"])))
	brute.call("clear_status", "lit")

	# ---- the ticking-payload rule: a hold lands at most once per target per cast
	var z_foe := _foe(p, Vector3(0, 0, -3.0))
	var zone := GroundZone.new()
	zone.shape = "circle"
	zone.radius = 2.0
	zone.life = 10.0
	zone.tick_s = 0.5
	zone.payload = {"statuses": [{"id": "pinned", "stacks": 1}, {"id": "soaked", "stacks": 1}]}
	zone.caster = p
	zone.from = z_foe.global_position
	zone.to = zone.from
	add_child(zone)
	zone.tick(0.6)
	_check("a zone's hold lands on the first tick", bool(z_foe.call("has_status", "pinned")) and bool(z_foe.call("has_status", "soaked")))
	z_foe.call("clear_status", "pinned")
	z_foe.call("clear_status", "soaked")
	zone.tick(0.6)
	_check("but not again on the same target for the same cast; a plain status does", not bool(z_foe.call("has_status", "pinned")) and bool(z_foe.call("has_status", "soaked")))
	zone.queue_free()
	z_foe.queue_free()

	# ---- poison: the dose clock
	p.call("set_affinities", ["poison"])
	var d := _foe(p, Vector3(0, 0, -2.0))
	var dosed: Dictionary = GameData.status("dosed")
	d.call("add_status", "dosed", 2, p)
	_run(d, 2.0)
	var t_left: float = float((d.get("statuses") as Dictionary)["dosed"]["t"])
	d.call("add_status", "dosed", 3, p)
	_check("more doses add to the bill but not the clock", int(d.call("status_stacks", "dosed")) == 5 and _near(float((d.get("statuses") as Dictionary)["dosed"]["t"]), t_left))
	var before_bill: float = _lost(d)
	_run(d, float(dosed["lasts"]))
	_check("when the clock runs out every dose is paid at once", not bool(d.call("has_status", "dosed")) and _near(_lost(d) - before_bill, 5.0 * float(dosed["on_expire"]["damage_per_stack"])),
		"paid %f" % (_lost(d) - before_bill))
	d.queue_free()

	# ---- disease: times flesh, through the shield; a cloud where an Infected body falls
	p.call("set_affinities", ["disease"])
	brute.set("_flash", 0.0)
	var b_lost: float = _lost(brute)
	p.call("deal_damage", brute, 100.0, ["ability", "disease"])
	_check("a Disease hit is times the target's flesh, round its guard", _near(_lost(brute) - b_lost, 100.0 * float(GameData.enemy("brute")["flesh"])), "%f" % (_lost(brute) - b_lost))
	var sick := _fighter(p, Vector3(3.0, 0, -2.0))
	sick.set("target", null)
	sick.call("add_status", "infected", 1, p)
	var clouds_before: int = get_tree().get_nodes_in_group("ground_zones").size()
	p.call("deal_damage", sick, 10000.0, ["ability"])
	_check("an Infected body that dies leaves a sick cloud", get_tree().get_nodes_in_group("ground_zones").size() > clouds_before)

	# ---- death: corpses lie longer, the Dying take more
	p.call("set_affinities", ["death"])
	_check("a Death fighter's corpses lie %d s" % int(GameData.affinity("death")["corpse_lie_s"]), _near(float(p.call("corpse_lie_s")), float(GameData.affinity("death")["corpse_lie_s"])))
	var dy := _foe(p, Vector3(-3.0, 0, -2.0))
	(dy.get("body") as Body).hp = (dy.get("body") as Body).max_hp * 0.4
	var dy_before: float = _lost(dy)
	p.call("deal_damage", dy, 100.0, ["ability", "death"])
	_check("below half health it is Dying: a Death hit does more", bool(dy.call("has_status", "dying")) and _near(_lost(dy) - dy_before, 100.0 * float(GameData.affinity("death")["dying_mult"])))
	var killed := _fighter(p, Vector3(-3.0, 0, 2.0))
	killed.set("target", null)
	p.call("deal_damage", killed, 10000.0, ["ability"])
	var fallen: Fallen = Fallen.nearest(get_tree(), p.global_position + Vector3(-3.0, 0, 2.0), 1.0)
	_check("where it fell lies a body for Death's skills, for as long", fallen != null and _near(fallen.life, float(GameData.affinity("death")["corpse_lie_s"]), 0.1))
	dy.queue_free()

	# ---- life: inside the body, harder on the hale, nothing to the unliving
	p.call("set_affinities", ["life"])
	var hale := _foe(p, Vector3(0, 0, -2.5), "brute")
	p.call("deal_damage", hale, 100.0, ["ability", "life"])
	_check("Life goes past the guard and does more to the hale", _near(_lost(hale), 100.0 * float(GameData.affinity("life")["hale_mult"])), "%f" % _lost(hale))
	hale.set("is_living", false)
	var h_before: float = _lost(hale)
	p.call("apply_hit", hale, {"damage": 100.0, "status": "withering"}, ["ability", "life"])
	_check("and nothing at all to the unliving", _near(_lost(hale), h_before) and not bool(hale.call("has_status", "withering")))
	hale.queue_free()

	# ---- blood: Bleeding drips pools; a bleeding kill is held blood; never health
	p.call("set_affinities", ["blood"])
	var bl := _foe(p, Vector3(0, 0, -2.0))
	bl.call("add_status", "bleeding", 2, p)
	var hp_me: float = (p.get("body") as Body).hp
	_run(bl, float(GameData.status("bleeding")["drips_pool_s"]) + 0.1)
	_check("Bleeding burns and drips a pool of blood", _lost(bl) > 0.0 and not get_tree().get_nodes_in_group("blood_pools").is_empty())
	p.call("deal_damage", bl, 10000.0, ["ability"])
	_check("a body that dies Bleeding by your hand is held blood", int(p.get("held_blood")) == int(GameData.status("bleeding")["on_death"]["held_blood"]))
	_check("blood never costs you health", _near((p.get("body") as Body).hp, hp_me))

	# ---- dark: Lit, Dim, Dark
	p.call("set_affinities", ["dark"])
	var dk := _foe(p, Vector3(0, 0, -3.0))
	var base_level: String = Light.level_at(get_tree(), dk.global_position)
	var dark := GroundZone.new()
	dark.shape = "circle"
	dark.radius = 1.5
	dark.life = 10.0
	dark.dark = true
	dark.caster = p
	dark.from = dk.global_position
	dark.to = dark.from
	add_child(dark)
	_check("dark ground is Dark (the level here is %s)" % base_level, Light.level_at(get_tree(), dk.global_position) == "dark")
	var dk_before: float = _lost(dk)
	p.call("deal_damage", dk, 100.0, ["ability", "dark"])
	_check("a Dark hit on a body standing in the Dark does more", _near(_lost(dk) - dk_before, 100.0 * float(GameData.affinity("dark")["light_mult"]["dark"])))
	dk.call("add_status", "alight", 1, p)
	_check("a burning body lights its ground, and light wins", Light.level_at(get_tree(), dk.global_position) == "lit")
	dk_before = _lost(dk)
	p.call("deal_damage", dk, 100.0, ["ability", "dark"])
	_check("a Dark hit in the light does less", _near(_lost(dk) - dk_before, 100.0 * float(GameData.affinity("dark")["light_mult"]["lit"])))
	dk.call("clear_status", "alight")
	dark.from = p.global_position
	dark.to = dark.from
	p.set("_unseen_reveal_t", 0.0)                  # your last hit showed you for a moment
	_check("standing in the Dark you are unseen from far off, but not up close",
		bool(p.call("unseen_from", p.global_position + Vector3(0, 0, -10.0))) and not bool(p.call("unseen_from", p.global_position + Vector3(0, 0, -2.0))))
	dark.queue_free()
	dk.queue_free()

	# ---- metal: plate is its target
	p.call("set_affinities", ["metal"])
	var plated := _foe(p, Vector3(0, 0, -2.5), "commander")
	p.call("deal_damage", plated, 100.0, ["ability", "metal"])
	var cls: int = int(GameData.enemy("commander")["metal"])
	_check("a Metal hit ignores the guard and does more per metal class worn (%d)" % cls, _near(_lost(plated), 100.0 * (1.0 + float(GameData.affinity("metal")["per_metal_class"]) * float(cls))), "%f" % _lost(plated))
	plated.call("add_status", "stripped", 1, p)
	_check("Stripped, it counts as bare", int(plated.call("metal_class")) == 0)
	plated.queue_free()

	# ---- nature: growth that ages
	p.call("set_affinities", ["nature"])
	var patch: GrowthPatch = p.call("plant_growth", p.global_position + Vector3(0, 0, -4.0), {"kind": "bramble"})
	var ages: Array = GameData.affinity("nature")["growth"]["ages"]
	_check("a new patch is a sprout", patch != null and patch.age() == 0)
	patch.tick(float(ages[0]) + 0.1)
	_check("it grows: grown works harder", patch.age() == 1 and _near(patch.mult(), float(GameData.affinity("nature")["growth"]["age_mult"][1])))
	patch.wilt()

	# ---- dream: a mind that sees you, and sleep
	p.call("set_affinities", ["dream"])
	var mind := _foe(p, Vector3(0, 0, -3.0))
	mind.set("facing", Vector3(0, 0, -1))           # its back to you
	p.call("apply_hit", mind, {"damage": 50.0, "status": "terrified"}, ["ability", "dream"])
	_check("a Dream hit does nothing to a mind that cannot see you", _near(_lost(mind), 0.0) and not bool(mind.call("has_status", "terrified")))
	mind.set("facing", Vector3(0, 0, 1))
	p.call("apply_hit", mind, {"status": "asleep"}, ["ability", "dream"])
	_check("facing you, a first sleep only Dazes it", bool(mind.call("has_status", "dazed")) and not bool(mind.call("has_status", "asleep")))
	p.call("apply_hit", mind, {"status": "asleep"}, ["ability", "dream"])
	_check("a second puts it to sleep", bool(mind.call("has_status", "asleep")))
	mind.set("facing", Vector3(0, 0, -1))
	p.call("apply_hit", mind, {"damage": 20.0}, ["ability", "dream"])
	_check("asleep, it needs no sight; the hit wakes it, Wakeful", _lost(mind) > 0.0 and not bool(mind.call("has_status", "asleep")) and bool(mind.call("has_status", "wakeful")))
	mind.queue_free()
	brute.queue_free()

	# ---- a test character has every skill of its affinity
	for aff: String in ["dream", "water"]:
		var tc := _new_player()
		tc.call("make_test_character", aff)
		var want_ids: Array = GameData.abilities.keys().filter(func(id: String) -> bool: return str(GameData.ability(id)["affinity"]) == aff)
		var have: Array = (tc.get("abilities") as Array).map(func(s: Dictionary) -> String: return str(s["id"]))
		var stage_ok: bool = (tc.get("abilities") as Array).all(func(s: Dictionary) -> bool: return int(s["stage"]) == GameData.inum("skills", "test_stage"))
		_check("a %s test character knows every %s skill (%d), at stage %d, with a full tank" % [aff, aff, want_ids.size(), GameData.inum("skills", "test_stage")],
			have.size() == want_ids.size() and want_ids.all(func(id: String) -> bool: return have.has(id)) and stage_ok and _near(float(tc.get("essence")), float(tc.get("essence_max")))
			and bool(tc.get("test_character")), "%d of %d" % [have.size(), want_ids.size()])
		var each: int = GameData.inum("skills", "test_constructs_each")
		var held: Array = tc.get("constructs")
		var every_kind: bool = GameData.construct_tiers.all(func(t: Variant) -> bool: return GameData.concept_ids().all(func(c: Variant) -> bool:
			return held.filter(func(h: Dictionary) -> bool: return str(h["tier"]) == str(t) and str(h["concept"]) == str(c)).size() == each))
		_check("and carries %d of every construct tier and concept, its bars full: ready to bind (Brent 2026-10-23)" % each,
			every_kind and held.size() == each * GameData.construct_tiers.size() * GameData.concept_ids().size()
			and str(tc.call("pending_tier", (tc.get("abilities") as Array)[0])) == GameData.tier_for_stage(GameData.inum("skills", "test_stage")),
			"%d carried" % held.size())
		_check("carried constructs group by tier and concept with a count",
			(tc.call("construct_groups", "eidolon") as Array).size() == GameData.concept_ids().size()
			and int(((tc.call("construct_groups", "eidolon") as Array)[0] as Dictionary)["count"]) == each)
		tc.call("next_hotbar_page")
		_check("its bar turns to the next six", int((tc.get("hotbar") as Array)[0]) == 6)
		tc.queue_free()
	p.queue_free()
	world.queue_free()
	await get_tree().process_frame


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_passed += 1
		print("  ok   %s" % label)
	else:
		_failed += 1
		print("  FAIL %s %s" % [label, detail])


func _near(a: float, b: float, eps: float = 0.01) -> bool:
	return absf(a - b) <= eps


## Take off every piece of armour the character wears. Checks that assert an exact amount of
## damage taken are about wounds, talents or tempering - not about the starting coat and boots.
func _bare(p: Node) -> void:
	var inv: Inventory = p.get("inventory")
	for slot: String in inv.equipped.keys():
		if (GameData.item(str(inv.equipped[slot])).get("stats", {}) as Dictionary).has("armour"):
			inv.equipped.erase(slot)


## As if a moment had passed: the last skill's recovery is over. Tests cast back to back with no
## game time in between, and a skill is refused while the previous one is still finishing.
func _rested(p: Node) -> void:
	p.set("_recover_t", 0.0)
	p.set("_melee_cd", 0.0)


func _new_player(talent: String = "") -> CharacterBody3D:
	var p: CharacterBody3D = PlayerScript.new()
	add_child(p)
	if talent != "":
		p.call("set_talent", talent)
	p.set("active", true)
	return p


func _test_body() -> void:
	print("body:")
	var b := Body.new(100.0)
	var applied: float = b.apply_damage(70.0)
	_check("damage comes off the one bar", _near(b.total(), 30.0) and _near(applied, 70.0))
	applied = b.apply_damage(500.0)
	_check("no overkill: applied capped at remaining", _near(applied, 30.0), "got %f" % applied)
	_check("dead at zero", b.is_dead())

	# wounds: a cut to the bar's ceiling, and a hidden sink that healing must fill
	var w := Body.new(100.0)
	w.add_wound("ribs", "Cracked ribs", 12.0, 8.0)
	_check("a wound lowers the bar's ceiling and takes the health above it", _near(w.total_max(), 92.0) and _near(w.total(), 92.0))
	w.apply_damage(40.0)
	_check("healing the bar stops at the lowered ceiling and leaves the sink alone", _near(w.heal(500.0), 40.0) and _near(w.total(), 92.0) and _near(w.sink_total(), 12.0))
	var part: Dictionary = w.fill_sinks(5.0)
	_check("filling a sink does not move the bar", _near(float(part["used"]), 5.0) and (part["closed"] as Array).is_empty() and _near(w.total(), 92.0) and _near(w.sink_total(), 7.0))
	var done: Dictionary = w.fill_sinks(50.0)
	_check("a full sink closes the wound and only uses what it needed", _near(float(done["used"]), 7.0) and (done["closed"] as Array) == ["ribs"] and w.wounds.is_empty())
	_check("the ceiling comes back, empty, to be refilled", _near(w.total_max(), 100.0) and _near(w.total(), 92.0))
	w.add_wound("arm", "Lost arm", 25.0, 8.0, false)
	w.add_wound("cut", "Deep gash", 6.0, 8.0)
	var rest: Dictionary = w.fill_sinks(100.0, true)
	_check("rest mends only what rest can mend", (rest["closed"] as Array) == ["cut"] and w.has_wound("arm") and _near(w.sink_total(), 25.0) and _near(w.sink_total(true), 0.0))
	w.add_wound("strain", "Strain", 8.0, 8.0, true, true)
	w.add_wound("strain", "Strain", 8.0, 8.0, true, true)
	_check("a merged wound deepens instead of doubling up", w.wounds.size() == 2 and _near(float(w.wound("strain")["sink"]), 16.0) and _near(float(w.wound("strain")["max_cut"]), 16.0))
	var deep := Body.new(100.0)
	deep.min_max_frac = 0.4
	for i: int in 12:
		deep.add_wound("w%d" % i, "Wound", 5.0, 8.0)
	_check("wounds cannot take the whole bar", _near(deep.total_max(), 40.0))
	_check("a wound says how it is doing without a number", Body.wound_state({"sink": 10.0, "sink_max": 10.0}) == "fresh" and Body.wound_state({"sink": 1.0, "sink_max": 10.0}) == "nearly closed")
	var copy := Body.new(1.0)
	copy.from_dict(JSON.parse_string(JSON.stringify(w.to_dict())))
	_check("a body survives a save", _near(copy.max_hp, 100.0) and copy.wounds.size() == 2 and _near(copy.total(), w.total()) and _near(copy.sink_total(), w.sink_total()))
	var old := Body.new(1.0)
	old.from_dict({}, {"superficial": 30.0, "structural": 20.0, "catastrophic": 10.0}, {"superficial": 68.0, "structural": 30.0, "catastrophic": 10.0})
	_check("a save from the three-layer days becomes one bar", _near(old.max_hp, 108.0) and _near(old.total(), 60.0) and old.wounds.is_empty())


func _test_natural_healing() -> void:
	print("natural healing:")
	var p := _new_player()
	var b: Body = p.get("body")
	b.add_wound("ribs", "Cracked ribs", 12.0, 8.0)
	b.apply_damage(70.0)                    # 22 of 92
	p.set("in_combat", true)
	for i: int in 5:
		p.call("_physics_process", 1.0)
	_check("none while in combat", _near(b.total(), 22.0))
	p.set("in_combat", false)
	for i: int in 10:
		p.call("_physics_process", 1.0)
	_check("the bar refills at rest", _near(b.total(), 52.0), "got %f" % b.total())
	for i: int in 60:
		p.call("_physics_process", 1.0)
	_check("but only to the wounded ceiling", _near(b.total(), 92.0), "got %f" % b.total())
	_check("and a wound never closes by resting in the field", b.has_wound("ribs") and _near(b.sink_total(), 12.0))
	p.queue_free()

	# what wounds you
	var q := _new_player()
	_bare(q)
	var qb: Body = q.get("body")
	q.call("take_hit", 15.0, false, null)
	_check("an ordinary blow leaves no wound", qb.wounds.is_empty() and _near(qb.total(), 85.0))
	q.call("take_hit", 25.0, false, null)
	_check("a blow worth a fifth of your health wounds you", qb.wounds.size() == 1 and _near(float(qb.wounds[0]["sink"]), 15.0) and _near(float(qb.wounds[0]["max_cut"]), 8.0),
		str(qb.wounds))
	q.call("take_hit", 25.0, false, null)
	_check("one flurry does not stack wounds", qb.wounds.size() == 1)
	q.set("_wound_cd", 0.0)
	qb.hp = 30.0
	q.call("take_hit", 12.0, false, null)
	_check("being left nearly dead wounds you too", qb.wounds.size() == 2 and _near(float(qb.wounds[1]["sink"]), 7.2), str(qb.wounds))
	q.queue_free()

	# talent healing order (Brent 2026-10-11)
	var s1 := _new_player("one_percent_lifesteal")
	var sb: Body = s1.get("body")
	sb.add_wound("ribs", "Cracked ribs", 12.0, 8.0)
	sb.hp = 20.0
	_check("supreme: the sink first", _near(float(s1.call("_spend_heal_points", 5.0)), 5.0) and _near(sb.sink_total(), 7.0) and _near(sb.total(), 20.0))
	s1.call("_spend_heal_points", 10.0)
	_check("supreme: then the bar, once the wound is closed", sb.wounds.is_empty() and _near(sb.total(), 23.0), "hp %f" % sb.total())
	s1.queue_free()
	var s2 := _new_player("one_percent_lifesteal")
	s2.set("stars", 2)
	var db: Body = s2.get("body")
	db.add_wound("ribs", "Cracked ribs", 12.0, 8.0)       # ceiling 92, half is 46
	db.hp = 20.0
	s2.call("_spend_heal_points", 10.0)
	_check("dynamic: the bar first while it is under half", _near(db.total(), 30.0) and _near(db.sink_total(), 12.0))
	s2.call("_spend_heal_points", 20.0)
	_check("dynamic: at half the rest goes to the sink", _near(db.total(), 46.0) and _near(db.sink_total(), 8.0), "hp %f sink %f" % [db.total(), db.sink_total()])
	s2.call("_spend_heal_points", 20.0)
	_check("dynamic: and once the wound closes, back to the bar", db.wounds.is_empty() and _near(db.total(), 58.0), "hp %f" % db.total())
	s2.queue_free()


func _overcharge(p: Node) -> void:
	p.set("_charge", 2.0)
	p.set("_charging", true)
	p.call("_release_overcharge")


func _test_arm_loss_and_regrowth() -> void:
	print("arm:")
	var p := _new_player("one_percent_lifesteal")
	p.set("in_combat", true)
	var b: Body = p.get("body")
	_overcharge(p)
	_check("one full overcharge wears the arm", float(p.get("arm_right")) < 100.0 and not bool(p.get("arm_right_lost")), "arm %f" % float(p.get("arm_right")))
	_overcharge(p)
	_check("repeated overcharge destroys the arm", bool(p.get("arm_right_lost")))
	_check("a lost arm is a wound that rest cannot mend", b.has_wound("lost_arm") and not bool(b.wound("lost_arm")["natural"]) and _near(float(b.wound("lost_arm")["sink"]), 25.0))

	p.set("in_combat", false)
	for i: int in 30:
		p.call("_physics_process", 1.0)
	p.call("rest_night")
	_check("neither rest nor a night regrows a lost arm", bool(p.get("arm_right_lost")) and b.has_wound("lost_arm"))

	p.call("_spend_heal_points", 24.0)
	_check("the talent fills the arm's sink, not yet regrown", bool(p.get("arm_right_lost")) and _near(float(b.wound("lost_arm")["sink"]), 1.0))
	p.call("_spend_heal_points", 2.0)
	_check("talent regrows the arm once enough points are spent", not bool(p.get("arm_right_lost")) and float(p.get("arm_right")) > 0.0 and not b.has_wound("lost_arm"))
	p.queue_free()


func _test_healer_credit_and_rent() -> void:
	print("healer / debt / rent:")
	var h := _new_player()
	var hb: Body = h.get("body")
	h.set("money", 5000)
	_check("nothing to mend costs nothing", int((h.call("next_healing") as Dictionary)["cost"]) == 0)
	hb.add_wound("ribs", "Cracked ribs", 14.0, 8.0)
	hb.hp = 40.0
	_check("the healer works on a wound before the bar", int((h.call("next_healing") as Dictionary)["cost"]) == 600)
	h.call("buy_healing")
	_check("a visit fills ten of the sink", int(h.get("money")) == 4400 and _near(hb.sink_total(), 4.0) and _near(hb.total(), 40.0))
	h.call("buy_healing")
	_check("the last of a wound costs only what is left", int(h.get("money")) == 4160 and hb.wounds.is_empty())
	_check("with no wounds the healer patches the bar", int((h.call("next_healing") as Dictionary)["cost"]) == 150)
	h.call("buy_healing")
	_check("a patch-up is 25 health", int(h.get("money")) == 4010 and _near(hb.total(), 65.0))
	h.queue_free()

	var p := _new_player()
	p.set("arm_right_lost", true)
	p.set("arm_right", 0.0)
	p.set("money", 0)
	p.call("buy_healing")
	_check("healer regrows an arm on credit", not bool(p.get("arm_right_lost")) and int(p.get("money")) == -1200, "money %d" % int(p.get("money")))
	p.set("arm_right_lost", true)
	p.call("buy_healing")
	_check("credit limit refuses a second arm", bool(p.get("arm_right_lost")) and int(p.get("money")) == -1200, "money %d" % int(p.get("money")))
	p.call("charge", 50)
	_check("rent pushes further into debt", int(p.get("money")) == -1250)
	_check("town refuses a ticket past the credit limit", not bool(p.call("can_afford", 800)) and bool(p.call("can_afford", 700)))
	p.queue_free()


const EnemyScript := preload("res://scripts/enemy.gd")


## A plain target for arithmetic: no armour, no poise to speak of, plenty of health, and it
## never fights back. (It was a brute until brutes grew frontal armour.)
func _dummy_enemy(p: Node3D) -> CharacterBody3D:
	var e: CharacterBody3D = EnemyScript.new()
	add_child(e)
	e.call("setup", "grunt", p, 1.0)
	e.set("target", null)      # never fights back on its own
	e.set("poise_max", 100000.0)
	e.set("poise", 100000.0)
	(e.get("body") as Body).max_hp = 700.0
	(e.get("body") as Body).hp = 700.0
	e.global_position = p.global_position + Vector3(0, 0, -1.5)
	return e


func _test_pipeline() -> void:
	print("hook pipeline:")
	for id: String in ["one_percent_lifesteal", "tenth_strike", "grudge", "glass_hour", "debt_of_pain", "furnace_gut"]:
		var q := _new_player(id)
		_check("effect loads for %s" % id, (q.get("effects") as Array).size() == 1)
		q.queue_free()

	var p := _new_player("tenth_strike")
	var e := _dummy_enemy(p)
	var eb: Body = e.get("body")
	for i: int in 10:
		p.call("deal_damage", e, 1.0, ["melee"])
	_check("tenth strike: 9 x1 + 1 x5 = 14", _near(eb.missing("superficial"), 14.0), "got %f" % eb.missing("superficial"))
	e.queue_free()
	p.queue_free()

	p = _new_player("glass_hour")
	_bare(p)
	e = _dummy_enemy(p)
	eb = e.get("body")
	p.call("start_fight")
	var ctx: HitContext = p.call("deal_damage", e, 10.0, ["melee"])
	_check("glass hour: x3 outgoing in the window", _near(ctx.applied, 30.0), "got %f" % ctx.applied)
	var pb: Body = p.get("body")
	p.call("take_hit", 5.0, false, e)
	_check("glass hour: x3 incoming in the window", _near(pb.missing("superficial"), 15.0), "got %f" % pb.missing("superficial"))
	p.set("fight_time", 10.0)
	ctx = p.call("deal_damage", e, 10.0, ["melee"])
	_check("glass hour: normal after the window", _near(ctx.applied, 10.0))
	e.queue_free()
	p.queue_free()

	p = _new_player("grudge")
	e = _dummy_enemy(p)
	for i: int in 3:
		p.call("take_hit", 1.0, false, e)
	ctx = p.call("deal_damage", e, 100.0, ["melee"])
	_check("grudge: +2% per hit taken from that enemy", _near(ctx.applied, 106.0), "got %f" % ctx.applied)
	e.queue_free()
	p.queue_free()

	p = _new_player("debt_of_pain")
	_bare(p)
	pb = p.get("body")
	p.call("start_fight")      # no natural healing while the debt is outstanding
	var returned: float = p.call("take_hit", 10.0, false, null)
	_check("debt: the hit is swallowed for now", _near(returned, 0.0) and _near(pb.missing("superficial"), 0.0))
	_check("debt: notebook shows what is owed", (p.call("status_lines") as Array).size() == 1)
	for i: int in 6:
		p.call("_physics_process", 1.0)
	_check("debt: 80% arrives after 5 s", _near(pb.missing("superficial"), 8.0), "got %f" % pb.missing("superficial"))
	p.queue_free()

	p = _new_player("furnace_gut")
	p.set("reflux", 99.0)
	p.set("essence", 100.0)
	p.call("cast_slot", 0)
	_check("furnace gut: cap vents to 50 instead of locking", not bool(p.get("reflux_locked")) and _near(float(p.get("reflux")), 50.0), "reflux %f" % float(p.get("reflux")))
	p.queue_free()

	p = _new_player("tenth_strike")
	p.set("reflux", 99.0)
	p.call("cast_slot", 0)
	_check("without furnace gut the cap locks the affinity", bool(p.get("reflux_locked")))
	p.queue_free()


func _test_lifesteal_feedback() -> void:
	print("lifesteal feedback (Brent 2026-10-12):")
	var p := _new_player("one_percent_lifesteal")
	var e := _dummy_enemy(p)
	var b: Body = p.get("body")
	var fx: TalentEffect = (p.get("effects") as Array)[0]
	p.call("deal_damage", e, 200.0, ["melee"])
	_check("at full health with no wound there is nothing to heal and nothing to show", _near(float(fx.get("_shown_pending")), 0.0) and _near(float(fx.get("_mend_pending")), 0.0))
	p.call("take_wound", "test_cut", "Deep gash", 10.0, 8.0)
	var sink0: float = float(b.wounds[0]["sink"])
	var hp0: float = b.hp
	p.call("deal_damage", e, 200.0, ["melee"])
	_check("with a wound, one-star lifesteal goes into the wound and the bar does not move", _near(sink0 - float(b.wounds[0]["sink"]), 2.0) and _near(b.hp, hp0))
	_check("and that healing has a number of its own to show", _near(float(fx.get("_mend_pending")), 2.0) and _near(float(fx.get("_shown_pending")), 0.0))
	fx.call("on_tick", 0.016)
	_check("which is shown and cleared on the next tick", _near(float(fx.get("_mend_pending")), 0.0))
	e.free()
	p.free()


func _test_abilities() -> void:
	# awaits a frame so a freed dummy enemy leaves the groups before the "nothing to fight" cast
	print("abilities:")
	var p := _new_player("one_percent_lifesteal")      # a water character: these checks use the water kit
	p.set("star_pct", [99.0] as Array[float])     # a grown star, so the tank is not the baby 20
	p.call("_recompute_essence_max")
	p.set("essence", 100.0)
	var ab: Array = p.get("abilities")
	_check("starting loadout has three abilities", ab.size() == 3 and str(ab[0]["id"]) == "water_bolt")
	# Progress: essence spent through the ability x use multiplier; vs a monster x1.0.
	var bolt_cost: float = float(GameData.ability("water_bolt")["cost"])
	var e := _dummy_enemy(p)
	p.call("start_fight")
	p.call("cast_slot", 0)
	_check("bolt spends its cost and leaves reflux", _near(float(p.get("essence")), 100.0 - bolt_cost) and _near(float(p.get("reflux")), bolt_cost),
		"essence %f reflux %f" % [float(p.get("essence")), float(p.get("reflux"))])
	_check("progress = essence spent x1 with a monster present", _near(float(ab[0]["progress"]), bolt_cost), "got %f" % float(ab[0]["progress"]))
	var spent: float = float(p.get("essence"))
	p.call("cast_slot", 0)
	_check("a skill cannot be cast again while the last one is finishing", _near(float(p.get("essence")), spent))
	p.call("end_fight")
	e.queue_free()
	await get_tree().process_frame
	p.set("essence", 100.0)
	_rested(p)
	p.call("cast_slot", 0)
	_check("progress x0.25 with nothing to fight", _near(float(ab[0]["progress"]), bolt_cost * 1.25), "got %f" % float(ab[0]["progress"]))
	ab[0]["progress"] = 99.0
	p.set("essence", 100.0)
	p.set("reflux", 0.0)
	_rested(p)
	p.call("cast_slot", 0)
	_check("a full bar waits at 100 - the stage does not advance by itself", int(ab[0]["stage"]) == 0 and _near(float(ab[0]["progress"]), 100.0))
	_check("stage 0 full needs a vestige", str(p.call("pending_tier", ab[0])) == "vestige")

	var cons: Array = p.get("constructs")
	cons.append({"tier": "remnant", "concept": "piercing"})
	_check("the wrong tier is refused", str(p.call("bind_construct", 0, 0, 0.0)) == "needs a vestige" and cons.size() == 1)
	cons.clear()
	cons.append({"tier": "vestige", "concept": "acceleration"})
	var pb0: Body = p.get("body")
	var wounds_before: int = pb0.wounds.size()
	_check("a failed bind loses the construct", str(p.call("bind_construct", 0, 0, 0.99)) == "failed" and cons.is_empty() and int(ab[0]["stage"]) == 0)
	_check("a failed bind wounds you", pb0.wounds.size() == wounds_before + 1 and str(pb0.wounds[pb0.wounds.size() - 1]["name"]) == "Soul-burn")
	cons.append({"tier": "vestige", "concept": "acceleration"})
	_check("a vestige binds into stage 0 and advances it", str(p.call("bind_construct", 0, 0, 0.0)) == "bound" and int(ab[0]["stage"]) == 1 and _near(float(ab[0]["progress"]), 0.0))
	var stats: Dictionary = p.call("ability_stats", ab[0])
	_check("the concept shapes the skill (acceleration: bolt speed x1.5)", _near(float(stats["speed"]), 30.0), "speed %f" % float(stats["speed"]))
	_check("and reaches into what the skill does on a hit (acceleration doubles the shove)", _near(float((stats["on_hit"] as Dictionary)["shove"]), 3.0)
		and _near(float((GameData.ability("water_bolt")["on_hit"] as Dictionary)["shove"]), 1.5))
	_check("stage 1 full now needs a remnant", (func() -> bool:
		ab[0]["progress"] = 100.0
		return str(p.call("pending_tier", ab[0])) == "remnant").call())
	ab[0]["stage"] = 2
	_check("stage cap is stars + 1: a 1-star's stage-2 skill waits for nothing", str(p.call("pending_tier", ab[0])) == "")
	_check("stage raises damage", _near(float(p.call("ability_damage_mult", 2)), 1.2))
	ab[0]["stage"] = 1
	ab[0]["progress"] = 0.0

	# Breaker (id tsunami_strike): a wide blow.
	var e2 := _dummy_enemy(p)
	var eb: Body = e2.get("body")
	var pb: Body = p.get("body")
	p.set("essence", 100.0)
	p.set("reflux", 0.0)
	ab[0]["stage"] = 0
	p.set("_facing", Vector3(0, 0, -1))
	var body_before: float = pb.total()
	_rested(p)
	p.call("cast_slot", 1)
	var breaker_hit: float = float(GameData.balance["player"]["melee_damage"]) * float(GameData.ability("tsunami_strike")["damage_mult"])
	_check("breaker lands its multiple of a strike", _near(eb.missing(), breaker_hit), "got %f want %f" % [eb.missing(), breaker_hit])
	_check("breaker does not hurt its caster (Brent 2026-10-11)", pb.total() >= body_before, "%f -> %f" % [body_before, pb.total()])      # lifesteal may even raise it
	for ab_id: String in GameData.abilities:
		if float(GameData.ability(ab_id).get("self_harm", 0.0)) > 0.0:
			_check("no ability hurts its caster by default", false, ab_id)
	e2.queue_free()

	# Meditation gathers wisps.
	p.set("star_pct", [99.0] as Array[float])
	p.call("_recompute_essence_max")
	p.set("essence", 20.0)
	p.set("meditating", true)
	p.call("_meditate_gather", 1.0)
	_check("meditation refills essence", _near(float(p.get("essence")), 24.0), "got %f" % float(p.get("essence")))

	# Meditating on the move was an exploit (Brent 2026-10-11): sitting roots you, and only settled sitting counts.
	p.set("meditating", false)
	p.set("active", true)
	p.set("_meditate_block", 0.0)
	p.set("move_goal", (p as Node3D).global_position + Vector3(8, 0, 0))
	p.set("has_move_goal", true)
	var before: Vector3 = (p as Node3D).global_position
	Input.action_press("meditate")
	p.call("_physics_process", 0.1)
	_check("sitting down cancels walking", not bool(p.get("has_move_goal")) and (p as CharacterBody3D).velocity.length() < 0.01,
		"goal %s vel %s" % [str(p.get("has_move_goal")), str((p as CharacterBody3D).velocity)])
	_check("nothing is gathered until you have settled", not bool(p.get("meditating")))
	for i: int in 12:
		p.call("_physics_process", 0.1)
	_check("settled sitting is meditation", bool(p.get("meditating")))
	_check("meditating does not move you", (p as Node3D).global_position.distance_to(before) < 0.05)
	Input.action_release("meditate")
	p.call("_physics_process", 0.1)
	_check("standing up ends it", not bool(p.get("meditating")))
	p.queue_free()


func _test_stars() -> void:
	print("stars:")
	var p := _new_player("tenth_strike")
	_check("you start with a baby star", _near(float((p.get("star_pct") as Array)[0]), 20.0) and _near(float(p.get("essence_max")), 20.0),
		"pct %f max %f" % [float((p.get("star_pct") as Array)[0]), float(p.get("essence_max"))])
	p.call("grow_star", 10.0)
	_check("growing the star grows the tank", _near(float(p.get("essence_max")), 30.0))
	p.call("grow_star", 500.0)
	_check("a star stops at 99%", _near(float((p.get("star_pct") as Array)[0]), 99.0))
	_check("one star never holds more than 100 essence", float(p.get("essence_max")) <= 100.0, "got %f" % float(p.get("essence_max")))
	p.call("try_ascend")
	_check("a full star alone does not ascend without latent aura", int(p.get("stars")) == 1)
	p.set("_latent_aura", GameData.num("player", "aura_threshold") + 1.0)
	p.call("try_ascend")
	var pcts: Array = p.get("star_pct")
	_check("ascension adds a second star at 1%", int(p.get("stars")) == 2 and pcts.size() == 2 and _near(float(pcts[1]), 1.0))
	_check("ascension remakes the body: a bigger bar, full", _near((p.get("body") as Body).max_hp, 100.0 * float(GameData.balance["ascension_2"]["body_scale"]))
		and _near((p.get("body") as Body).total(), (p.get("body") as Body).total_max()), "max %f" % (p.get("body") as Body).max_hp)
	_check("the tank is 99% of one star plus 1% of another", _near(float(p.get("essence_max")), 100.0), "got %f" % float(p.get("essence_max")))
	p.call("grow_star", 20.0)
	_check("only the newest star grows after ascension", _near(float(pcts[0]), 99.0) and _near(float(pcts[1]), 21.0))
	p.queue_free()


func _test_click_melee() -> void:
	# let enemies freed by earlier tests leave the scene first - a queued-for-deletion dummy at the
	# same spot is still clickable for the rest of its frame
	await get_tree().process_frame
	print("click-to-attack melee:")
	var p := _new_player("tenth_strike")
	var a := _dummy_enemy(p)
	var b := _dummy_enemy(p)
	b.global_position = p.global_position + Vector3(0.6, 0, -1.2)
	var ab_body: Body = a.get("body")
	var bb_body: Body = b.get("body")
	_check("a click on an enemy's footprint picks that enemy", p.call("pick_at", b.global_position + Vector3(0.2, 0, 0)) == b)
	p.call("_click", a.global_position)
	p.set("_melee_cd", 0.0)
	p.call("_physics_process", 0.016)
	_check("the base strike hits only the clicked enemy", ab_body.missing("superficial") > 0.0 and _near(bb_body.missing("superficial"), 0.0),
		"a %f b %f" % [ab_body.missing("superficial"), bb_body.missing("superficial")])
	p.call("_click", p.global_position + Vector3(5, 0, 5))
	_check("a click on empty ground becomes a walk goal", bool(p.get("has_move_goal")) and p.get("attack_target") == null)

	# Screen-space picking with the game's isometric camera: clicking the upper body counts.
	# The headless window is 64x64 px; give the camera the game's real 1600x900 screen so a
	# pixel margin means what it means in play.
	var screen := SubViewport.new()
	screen.size = Vector2i(1600, 900)
	screen.world_3d = get_viewport().world_3d
	add_child(screen)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 24.0
	screen.add_child(cam)
	cam.global_position = p.global_position + Vector3(12, 12, 12)
	cam.look_at(p.global_position + Vector3.UP, Vector3.UP)
	var chest: Vector2 = cam.unproject_position(a.global_position + Vector3.UP * 1.9)
	var floor_behind: Node3D = p.call("pick_at", a.global_position + Vector3(-2.5, 0, -2.5))
	_check("the old floor pick misses a click aimed at the upper body", floor_behind == null)
	_check("a click on the upper body picks that enemy in screen space", p.call("pick_screen", chest, cam) == a)
	var far: Vector2 = cam.unproject_position(a.global_position + Vector3(6, 0, 6))
	_check("empty screen space picks nothing", p.call("pick_screen", far, cam) == null)
	p.set("hovered", a)
	p.call("_refresh_highlights")
	_check("the hovered enemy is highlighted", int(a.get("highlight")) == 1 and int(b.get("highlight")) == 0)
	p.call("_click_cursor")
	_check("clicking while hovering locks that enemy as the attack target", p.get("attack_target") == a)
	p.set("hovered", null)
	p.call("_refresh_highlights")
	_check("the locked target keeps a dimmer highlight", int(a.get("highlight")) == 2)
	screen.queue_free()
	a.queue_free()
	b.queue_free()
	await get_tree().process_frame
	p.queue_free()


func _test_inventory() -> void:
	await get_tree().process_frame
	print("inventory / loot / save:")
	var p := _new_player("one_percent_lifesteal")      # a water character: these checks use the water kit
	var inv: Inventory = p.get("inventory")
	_check("you start with a backpack in the back slot and no storage ring", str(inv.equipped.get("back", "")) == "canvas_pack" and inv.bag.is_empty())
	_check("carry capacity = base 8 + pack 30", _near(inv.capacity(), 38.0), "got %f" % inv.capacity())
	_check("there is no free satellite", _near(float(p.get("satellite_rate")), 0.0))

	_check("loot goes in the bag", inv.add("brute_tusk") and _near(inv.weight(), 6.0))
	for i: int in 5:
		inv.add("brute_tusk")
	_check("six tusks fit (36 of 38 kg)", inv.bag.size() == 6)
	_check("a seventh is too heavy", not inv.add("brute_tusk") and inv.bag.size() == 6)
	_check("loot value adds up", inv.loot_value() == 6 * 280)
	_check("selling clears the loot and pays", inv.sell_loot() == 1680 and inv.bag.is_empty())

	inv.add("paired_mote")
	_check("equipping a satellite turns on essence flow - a 1-star can wear a 2-star one", inv.equip("paired_mote") == "equipped" and (func() -> bool:
		p.call("refresh_gear")
		return _near(float(p.get("satellite_rate")), 2.0)).call())
	inv.add("river_stone")
	inv.equip("river_stone")
	var bolt_cost: float = float((p.call("ability_stats", (p.get("abilities") as Array)[0]) as Dictionary)["cost"])
	_check("a trinket changes ability cost (x 0.9)", _near(bolt_cost, float(GameData.ability("water_bolt")["cost"]) * 0.9), "got %f" % bolt_cost)
	_check("unequipping returns the item to the bag", inv.unequip("trinket") == "unequipped" and inv.bag.has("river_stone"))

	# swapping packs while loaded: the bigger frame goes on, the canvas pack comes off into the bag
	inv.add("delver_frame")
	_check("a bigger backpack raises capacity", inv.equip("delver_frame") == "equipped" and _near(inv.capacity(), 83.0))
	for i: int in 12:
		inv.add("brute_tusk")
	_check("cannot swap back to a small pack while overloaded", inv.equip("canvas_pack") != "equipped" and str(inv.equipped["back"]) == "delver_frame")

	# ground loot
	var drop: Node3D = PlayerScript.spawn_pickup(self, "sinew_cord", p.global_position + Vector3(1, 0, 0))
	_check("a dropped item sits in the world", get_tree().get_nodes_in_group("pickups").has(drop))
	var before: int = inv.bag.size()
	_check("walking onto it puts it in the bag", bool(p.call("take_pickup", drop)) and inv.bag.size() == before + 1)
	var heavy: Node3D = PlayerScript.spawn_pickup(self, "brute_tusk", p.global_position)
	inv.bag.clear()
	for i: int in 13:
		inv.add("brute_tusk")     # 78 of 83 kg
	_check("an item too heavy to carry stays on the ground", not bool(p.call("take_pickup", heavy)) and get_tree().get_nodes_in_group("pickups").has(heavy))
	heavy.queue_free()

	# kills leave loot where the enemy fell
	var e := _dummy_enemy(p)
	e.set("kind", "commander")
	(e.get("body") as Body).apply_damage(99999.0)
	p.call("_roll_loot", e)
	var sigils := 0
	for n: Node in get_tree().get_nodes_in_group("pickups"):
		if str(n.get("item_id")) == "commander_sigil":
			sigils += 1
	_check("a commander always drops its sigil", sigils == 1)
	e.queue_free()

	# save round trip
	p.set("money", -321)
	p.call("grow_star", 30.0)
	(p.get("abilities") as Array)[0]["progress"] = 42.0
	(p.get("constructs") as Array).append({"tier": "vestige", "concept": "tension"})
	var data: Dictionary = p.call("to_save")
	var path := "user://selftest_save.json"
	_check("the save file is written", SaveGame.write(data, path) and SaveGame.exists(path))
	_check("slot 0 is the autosave and numbered slots are separate files",
		SaveGame.slot_path(0) == SaveGame.PATH and SaveGame.slot_path(2) != SaveGame.slot_path(3) and SaveGame.slot_path(2) != SaveGame.PATH)
	_check("a save describes itself, an empty slot says so", SaveGame.describe(SaveGame.read(path)).contains("day") and SaveGame.describe({}) == "empty",
		SaveGame.describe(SaveGame.read(path)))
	_check("a new character starts with money", GameData.inum("town", "starting_money") == 10000)
	var q := _new_player()
	q.call("from_save", SaveGame.read(path))
	var qinv: Inventory = q.get("inventory")
	_check("a loaded character has the same talent, money and star", str(q.get("talent_id")) == str(p.get("talent_id")) and int(q.get("money")) == -321 and _near(float((q.get("star_pct") as Array)[0]), float((p.get("star_pct") as Array)[0])))
	_check("abilities, constructs and gear survive the round trip", _near(float((q.get("abilities") as Array)[0]["progress"]), 42.0)
		and (q.get("constructs") as Array).size() == 1 and str(qinv.equipped.get("satellite", "")) == "paired_mote"
		and qinv.bag.size() == inv.bag.size() and _near(float(q.get("satellite_rate")), 2.0))
	SaveGame.delete(path)
	_check("deleting the save removes it", not SaveGame.exists(path) and SaveGame.read(path).is_empty())
	for n: Node in get_tree().get_nodes_in_group("pickups"):
		n.queue_free()
	p.queue_free()
	q.queue_free()


func _test_slot_assignment() -> void:
	print("skill slots:")
	var p := _new_player("tenth_strike")
	var hb: Array = p.get("hotbar")
	_check("the starting loadout fills slots 1-3", int(hb[0]) == 0 and int(hb[1]) == 1 and int(hb[2]) == 2 and int(hb[3]) == -1)
	p.call("assign_slot", 4, 2)
	_check("moving an ability to an empty slot leaves its old slot empty", int(hb[4]) == 2 and int(hb[2]) == -1)
	p.call("assign_slot", 0, 2)
	_check("moving onto an occupied slot swaps the two", int(hb[0]) == 2 and int(hb[4]) == 0)
	_check("an ability never sits on two slots", hb.count(0) == 1 and hb.count(1) == 1 and hb.count(2) == 1)
	p.call("unassign_ability", 1)
	_check("an ability can be taken off the bar", hb.find(1) == -1)
	p.call("assign_slot", 99, 0)
	p.call("assign_slot", 0, 99)
	_check("nonsense slot or ability numbers are ignored", int(hb[0]) == 2)
	var q := _new_player()
	q.call("from_save", p.call("to_save"))
	var qhb: Array = q.get("hotbar")
	_check("the arrangement survives saving", int(qhb[0]) == 2 and int(qhb[4]) == 0 and qhb.find(1) == -1)
	p.queue_free()
	q.queue_free()


func _test_weapons() -> void:
	await get_tree().process_frame
	print("weapons:")
	var p := _new_player("tenth_strike")
	var inv: Inventory = p.get("inventory")
	var e := _dummy_enemy(p)
	var eb: Body = e.get("body")
	p.call("_strike_target", e, 1.0, ["melee"])
	_check("a bare-handed strike does base damage (60)", _near(eb.missing("superficial"), 60.0), "got %f" % eb.missing("superficial"))
	_check("bare hands reach 2.3 m", _near(float(p.call("reach_now")), 2.3))

	inv.add("commander_blade")
	_check("a weapon equips into the weapon slot", inv.equip("commander_blade") == "equipped" and str(inv.equipped.get("weapon", "")) == "commander_blade")
	var before: float = eb.missing("superficial")
	p.call("_strike_target", e, 1.0, ["melee"])
	_check("the blade hits 60% harder (96)", _near(eb.missing("superficial") - before, 96.0), "got %f" % (eb.missing("superficial") - before))
	_check("the blade adds half a metre of reach", _near(float(p.call("reach_now")), 2.8))

	inv.add("serrated_dagger")
	inv.equip("serrated_dagger")
	_check("swapping weapons puts the old one back in the pack", str(inv.equipped["weapon"]) == "serrated_dagger" and inv.bag.has("commander_blade"))
	_check("the dagger strikes faster (cooldown x0.8)", _near(float(p.call("weapon_stat", "melee_cooldown_mult", true)), 0.8))

	p.set("arm_right_lost", true)
	_check("with the striking arm lost the weapon does nothing", _near(float(p.call("weapon_stat", "melee_damage_mult", true)), 1.0) and _near(float(p.call("weapon_stat", "melee_cooldown_mult", true)), 1.0))
	p.set("arm_right_lost", false)

	_check("gear sells for half, loot for full", inv.sale_price("commander_blade") == 900 and inv.sale_price("brute_tusk") == 280)
	_check("selling one item removes just that one", inv.sell_item("commander_blade") == 900 and not inv.bag.has("commander_blade"))
	inv.add("brute_tusk")
	_check("'sell all loot' leaves weapons alone", inv.sell_loot() == 280 and str(inv.equipped["weapon"]) == "serrated_dagger")
	var q := _new_player()
	q.call("from_save", p.call("to_save"))
	_check("the equipped weapon survives saving", str((q.get("inventory") as Inventory).equipped.get("weapon", "")) == "serrated_dagger")
	e.queue_free()
	p.queue_free()
	q.queue_free()


func _test_character() -> void:
	print("character:")
	var p := _new_player("grudge")
	_check("a talent alone says nothing about affinities", (p.get("affinities") as Array) == GameData.default_affinities())
	p.call("set_affinities", ["fire", "wind"])
	var opts: Dictionary = CharacterLook.options()
	var norm: Dictionary = CharacterLook.normalize({"hair": "no_such_style", "nonsense": "x"})
	_check("an unknown look falls back to the defaults", norm == CharacterLook.default_look())
	var chosen: Dictionary = CharacterLook.default_look()
	for key: String in opts:
		chosen[key] = CharacterLook.cycle(chosen, key, 1)
		_check("cycling back returns to the start (%s)" % key, CharacterLook.cycle(chosen, key, -1) == str(CharacterLook.default_look()[key]))
	p.set("char_name", "Maren")
	p.set("identity", "woman")
	p.call("set_look", chosen)
	_check("a look can be worn and the model is rebuilt", (p.get("look") as Dictionary) == chosen and p.get("_rig") != null and is_instance_valid(p.get("_rig")))
	var q := _new_player()
	q.call("from_save", JSON.parse_string(JSON.stringify(p.call("to_save"))))
	_check("name, identity, look and affinities survive a save", str(q.get("char_name")) == "Maren" and str(q.get("identity")) == "woman"
		and (q.get("look") as Dictionary) == chosen and (q.get("affinities") as Array) == (p.get("affinities") as Array))
	_check("a save names its character", SaveGame.who(p.call("to_save")).begins_with("Maren"))
	var old: Dictionary = p.call("to_save")
	for k: String in ["name", "identity", "look", "affinities", "abilities", "hotbar"]:
		old.erase(k)
	var r := _new_player()
	r.call("from_save", old)
	_check("a save from before character creation still loads", str(r.get("talent_id")) == "grudge" and (r.get("look") as Dictionary) == CharacterLook.default_look()
		and (r.get("affinities") as Array) == ["water"] and str(((r.get("abilities") as Array)[0] as Dictionary)["id"]) == "water_bolt")
	for n: Node in [p, q, r]:
		n.queue_free()


func _test_playtest_1011() -> void:
	print("playtest 2026-10-11:")
	await get_tree().process_frame
	# Report: "ability 2 on multiple enemies is not granting the lifesteal it should".
	# It pays 1% of the damage done to EACH target; the strike's own self-harm is what hides it.
	var gains: Array[float] = []
	for n: int in [1, 3]:
		var p := _new_player("one_percent_lifesteal")
		p.set("star_pct", [99.0] as Array[float])
		p.call("_recompute_essence_max")
		p.set("essence", 99.0)
		var foes: Array = []
		for i: int in n:
			var e := _dummy_enemy(p)
			e.global_position = p.global_position + Vector3(float(i) - float(n - 1) * 0.5, 0, -1.6)
			foes.append(e)
		var pts: float = float(p.get("heal_points_total"))
		p.call("cast_slot", 1)
		gains.append(float(p.get("heal_points_total")) - pts)
		for e: Node in foes:
			if is_instance_valid(e):
				e.queue_free()
		p.queue_free()
		await get_tree().process_frame
	var per_target: float = float(GameData.balance["player"]["melee_damage"]) * float(GameData.ability("tsunami_strike")["damage_mult"]) * 0.01
	_check("lifesteal pays 1% of the strike on one target", _near(gains[0], per_target), "got %f want %f" % [gains[0], per_target])
	_check("and on every target the strike hits", _near(gains[1], per_target * 3.0), "got %f want %f" % [gains[1], per_target * 3.0])

	# bind preview
	var q := _new_player("one_percent_lifesteal")
	var bolt: Dictionary = (q.get("abilities") as Array)[0]
	var rows: Array[Dictionary] = q.call("preview_bind", bolt, "acceleration")
	var by := {}
	for r: Dictionary in rows:
		by[str(r["label"])] = r
	_check("preview: acceleration makes the bolt faster and reach further", by.has("Bolt speed") and str(by["Bolt speed"]["before"]) == "20" and str(by["Bolt speed"]["after"]) == "30"
		and by.has("Range") and bool(by["Range"]["better"]), str(rows))
	_check("preview: the stage and its damage step are shown", by.has("Stage") and str(by["Stage"]["after"]) == "1" and by.has("Damage") and bool(by["Damage"]["better"]))
	_check("preview: numbers that do not move are left out", not by.has("Essence cost"))
	rows = q.call("preview_bind", bolt, "compression")
	by.clear()
	for r: Dictionary in rows:
		by[str(r["label"])] = r
	_check("preview: compression lowers the cost, shown as an improvement", by.has("Essence cost") and str(by["Essence cost"]["before"]) == "8" and str(by["Essence cost"]["after"]) == "6" and bool(by["Essence cost"]["better"]))
	rows = q.call("preview_bind", (q.get("abilities") as Array)[1], "tension")
	by.clear()
	for r: Dictionary in rows:
		by[str(r["label"])] = r
	_check("preview: tension hits harder and no longer costs you anything", by.has("Damage per target") and bool(by["Damage per target"]["better"]) and not by.has("Harm to yourself"))
	var costly: Array[Dictionary] = []
	q.call("_preview_row", costly, "Harm to yourself", 2.0, 3.0, "%.1f", false)
	_check("preview: a number that gets worse is marked as worse", costly.size() == 1 and not bool(costly[0]["better"]))
	_check("previewing changes nothing", not bolt.has("bound") and int(bolt["stage"]) == 0)
	# the preview must agree with what binding then does
	bolt["progress"] = 100.0
	(q.get("constructs") as Array).append({"tier": "vestige", "concept": "acceleration"})
	q.call("bind_construct", 0, 0, 0.0)
	_check("the bind does what the preview said", _near(float((q.call("ability_stats", bolt) as Dictionary)["speed"]), 30.0) and int(bolt["stage"]) == 1)
	q.queue_free()


func _test_tempering() -> void:
	print("tempering:")
	var p := _new_player()
	var known: Dictionary = p.get("tempering")
	_check("a water character knows the plain technique and the water one", known.has("callus") and known.has("slow_tide") and known.size() == 2, str(known.keys()))
	p.call("set_affinities", ["fire", "earth", "wind"])
	known = p.get("tempering")
	_check("techniques follow the affinities held", known.has("callus") and known.has("kiln_cured") and known.has("bedrock_bones") and known.has("thin_air_lungs")
		and not known.has("slow_tide") and not known.has("live_wire"), str(known.keys()))
	for id: String in GameData.technique_ids():
		var def: Dictionary = GameData.technique(id)
		var aff: String = str(def.get("affinity", ""))
		if not (aff == "" or not GameData.affinity(aff).is_empty()) or not (def.get("effect", {}) as Dictionary).has("stat"):
			_check("every technique names a known affinity and an effect", false, id)
	var b: Body = p.get("body")
	var base_max: float = b.max_hp
	_check("a session strains the body and moves the bar", bool(p.call("temper_session", "callus")) and b.has_wound("temper_strain")
		and _near(b.total_max(), base_max - 8.0) and _near(float(b.wound("temper_strain")["sink"]), 8.0) and _near(float(known["callus"]["progress"]), 25.0))
	p.call("rest_night")
	_check("a night's rest mends the strain", not b.has_wound("temper_strain") and _near(b.total(), base_max))
	for i: int in 3:
		b.wounds.clear()
		p.call("temper_session", "callus")
	b.wounds.clear()
	_check("four sessions make stage 1", int(known["callus"]["stage"]) == 1 and _near(float(known["callus"]["progress"]), 0.0))
	_check("callus stage 1 adds health", _near(b.max_hp, base_max + 8.0))
	_check("the next stage is slower and hurts more", _near(float(p.call("temper_session_progress", "callus")), 17.5) and _near(float(p.call("temper_session_damage", "callus")), 12.0))
	b.add_wound("old", "Old hurts", 30.0, 36.0)
	_check("a body too broken cannot train", not bool(p.call("temper_session", "callus")) and str(p.call("cannot_temper_reason", "callus")) != "" and not b.has_wound("temper_strain"))
	b.wounds.clear()
	b.hp = b.total_max()
	known["callus"]["stage"] = 2
	_check("a one-star body stops at stage 2", not bool(p.call("temper_session", "callus")) and int(p.call("temper_stage_cap")) == 2)
	known["callus"]["stage"] = 1

	# every technique's effect, all at once
	known["kiln_cured"]["stage"] = 2
	known["thin_air_lungs"]["stage"] = 1
	_check("kiln-cured hide turns blows", _near(float(p.call("temper_stat", "incoming_mult")), 0.9025))
	_bare(p)
	var before: float = b.total()
	p.call("take_hit", 20.0, false, null)
	_check("and the body takes less", _near(before - b.total(), 18.05), "took %f" % (before - b.total()))
	_check("thin air lungs quicken the feet", _near(float(p.call("temper_stat", "move_speed_mult")), 1.04))
	_check("an untrained stat is untouched", _near(float(p.call("temper_stat", "melee_cooldown_mult")), 1.0))
	for i: int in 4:
		b.wounds.clear()
		p.call("temper_session", "bedrock_bones")
	b.wounds.clear()
	p.call("take_wound", "test", "Test wound", 10.0, 4.0)
	_check("bedrock bones make wounds shallower", int(known["bedrock_bones"]["stage"]) == 1 and _near(float(b.wound("test")["sink"]), 8.8), str(b.wounds))
	b.wounds.clear()
	b.hp = b.total_max()

	var w := _new_player()
	(w.get("tempering") as Dictionary)["slow_tide"]["stage"] = 2
	(w.get("reflux_by") as Dictionary)["water"] = 50.0
	w.call("_shed_reflux", 10.0)
	_check("slow tide sheds reflux faster", _near(float(w.call("reflux_of", "water")), 50.0 - 10.0 * 1.15 * 1.15), "left %f" % float(w.call("reflux_of", "water")))
	_check("the screen can say what a stage gives", str(w.call("temper_effect_text", "slow_tide", 2)) == "reflux sheds 32% faster" and str(w.call("temper_effect_text", "callus", 3)) == "+24 health")
	w.queue_free()

	# save round trip; the health a technique added must not be added twice
	var q := _new_player()
	q.call("from_save", JSON.parse_string(JSON.stringify(p.call("to_save"))))
	var qk: Dictionary = q.get("tempering")
	_check("tempering survives a save", int(qk["callus"]["stage"]) == 1 and int(qk["kiln_cured"]["stage"]) == 2 and int(qk["bedrock_bones"]["stage"]) == 1 and qk.size() == known.size())
	_check("and its health is not counted twice", _near((q.get("body") as Body).max_hp, base_max + 8.0))
	var old: Dictionary = p.call("to_save")
	old.erase("tempering")
	var r := _new_player()
	r.call("from_save", old)
	_check("a save from before tempering starts its techniques at stage 0", int((r.get("tempering") as Dictionary)["callus"]["stage"]) == 0 and (r.get("tempering") as Dictionary).has("kiln_cured"))
	# changing affinities (a new character) gives the health back
	p.call("set_affinities", ["water"])
	_check("starting over undoes tempered health", _near(b.max_hp, base_max) and int((p.get("tempering") as Dictionary)["callus"]["stage"]) == 0)
	for n: Node in [p, q, r]:
		n.queue_free()


## A slab to stand on and, optionally, a wall across the way: shoves and blinks need a world.
func _test_floor(at: Vector3, wall_z: float = INF) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var parts: Array = [[Vector3(at.x, at.y - 0.5, at.z), Vector3(60, 1, 60)]]
	if wall_z != INF:
		parts.append([Vector3(at.x, at.y + 1.0, wall_z), Vector3(60, 2, 1)])
	for part: Array in parts:
		var sb := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = part[1]
		col.shape = shape
		sb.add_child(col)
		sb.position = part[0]
		root.add_child(sb)
	return root


## An enemy that does not fight back, `at` metres from the player in the player's frame.
func _foe(p: Node3D, offset: Vector3, kind: String = "grunt") -> CharacterBody3D:
	var e: CharacterBody3D = EnemyScript.new()
	e.call("setup", kind, p, 1.0)
	e.position = p.global_position + offset
	add_child(e)
	e.set("target", null)
	(e.get("body") as Body).max_hp = 5000.0
	(e.get("body") as Body).hp = 5000.0
	# and it is never staggered: repeated hits would otherwise break its poise and add 30% to
	# every later number in the same test (use _fighter when poise is what is being tested)
	e.set("poise_max", 100000.0)
	e.set("poise", 100000.0)
	return e


## Run an enemy's physics by hand until its shove is over.
func _settle(e: Node, steps: int = 80) -> void:
	for i: int in steps:
		if not is_instance_valid(e) or not bool(e.call("is_shoved")):
			return
		e.call("_physics_process", 1.0 / 60.0)


func _lost(e: Node) -> float:
	return (e.get("body") as Body).max_hp - (e.get("body") as Body).hp


## An enemy that is really fighting `p`: its own health and poise, and `p` as its target.
func _fighter(p: Node3D, offset: Vector3, kind: String = "grunt") -> CharacterBody3D:
	var e: CharacterBody3D = EnemyScript.new()
	e.call("setup", kind, p, 1.0)
	e.position = p.global_position + offset
	add_child(e)
	return e


## Run an enemy's thinking by hand for `seconds`.
func _run(e: Node, seconds: float, step: float = 1.0 / 60.0) -> void:
	var t := 0.0
	while t < seconds and is_instance_valid(e) and not e.is_queued_for_deletion():
		e.call("_physics_process", step)
		t += step


func _test_combat_rules() -> void:
	print("combat rules (design/05 step 2):")
	var cfg: Dictionary = GameData.balance["combat"]
	var strike: float = float(GameData.balance["player"]["melee_damage"])
	var p := _new_player()
	_bare(p)
	p.global_position = Vector3(600, 0, 0)
	var world := _test_floor(p.global_position)
	await get_tree().physics_frame
	await get_tree().physics_frame
	p.set("effects", [] as Array[TalentEffect])

	# ---------- a back exists: turning takes time
	var g := _fighter(p, Vector3(0, 0, -3.0))
	_check("an enemy starts out facing you", bool(g.call("is_in_front", p.global_position)) and not bool(g.call("is_behind", p.global_position)))
	g.set("facing", Vector3(0, 0, -1))                       # turned away
	_check("behind it is behind it", bool(g.call("is_behind", p.global_position)))
	g.call("_turn_toward", Vector3(0, 0, 1), 0.25)           # a quarter second at 240 degrees a second = 60 degrees
	var turned: float = rad_to_deg(Vector3(0, 0, -1).angle_to(g.get("facing") as Vector3))
	_check("it turns at 240 degrees a second, not at once", _near(turned, 60.0, 0.5), "turned %f" % turned)

	# ---------- rear hits
	g.set("facing", Vector3(0, 0, 1))                        # facing the player
	var hp: float = (g.get("body") as Body).hp
	p.call("deal_damage", g, 100.0, ["test"])
	_check("a hit from the front is a plain hit", _near(hp - (g.get("body") as Body).hp, 100.0))
	g.set("facing", Vector3(0, 0, -1))
	hp = (g.get("body") as Body).hp
	p.call("deal_damage", g, 100.0, ["test"])
	_check("a hit on its back does 30% more", _near(hp - (g.get("body") as Body).hp, 100.0 * float(cfg["rear_mult"])))
	g.queue_free()

	# ---------- the brute: armoured in front, open behind
	var br := _fighter(p, Vector3(0, 0, -3.0), "brute")
	br.set("target", null)
	br.set("facing", Vector3(0, 0, 1))
	hp = (br.get("body") as Body).hp
	p.call("deal_damage", br, 100.0, ["test"])
	_check("the brute shrugs off 30% from the front", _near(hp - (br.get("body") as Body).hp, 70.0), "took %f" % (hp - (br.get("body") as Body).hp))
	br.set("facing", Vector3(0, 0, -1))
	hp = (br.get("body") as Body).hp
	p.call("deal_damage", br, 100.0, ["test"])
	_check("and nothing from behind, where the rear bonus applies instead", _near(hp - (br.get("body") as Body).hp, 130.0), "took %f" % (hp - (br.get("body") as Body).hp))

	# ---------- poise, stagger, the Opening
	br.set("facing", Vector3(0, 0, 1))
	_check("the brute has 160 poise", _near(float(br.get("poise_max")), 160.0))
	p.call("_strike_target", br, 1.0, ["melee"])
	_check("a bare strike takes 20 poise", _near(float(br.get("poise")), 140.0))
	p.call("apply_hit", br, {"damage": 10.0}, ["ability"])
	_check("a skill takes 15 unless it says otherwise", _near(float(br.get("poise")), 125.0))
	p.call("apply_hit", br, {"damage": 10.0, "poise": 50.0}, ["ability"])
	_check("or what its payload says", _near(float(br.get("poise")), 75.0))
	br.set("_poise_idle", 2.9)
	_run(br, 0.2)
	_check("poise comes back after three seconds unhit - target or no target", float(br.get("poise")) > 75.0 and float(br.get("poise")) < 85.0, "poise %f" % float(br.get("poise")))
	br.set("poise", 20.0)
	_check("taking the last of it breaks the enemy", bool(br.call("take_poise", 20.0)) and bool(br.call("has_status", "staggered")))
	_check("it finds its feet again with full poise", _near(float(br.get("poise")), 160.0))
	hp = (br.get("body") as Body).hp
	p.call("_strike_target", br, 1.0, ["melee"])
	var opening: float = strike * float(cfg["opening_mult"]) * float(GameData.status("staggered")["damage_taken_mult"])
	_check("a bare strike on a staggered enemy is an Opening: double, and it takes 30% more", _near(hp - (br.get("body") as Body).hp, opening), "took %f want %f" % [hp - (br.get("body") as Body).hp, opening])
	_check("a staggered brute's hide does not help it", opening > strike * 2.0)
	hp = (br.get("body") as Body).hp
	p.call("apply_hit", br, {"damage": 100.0}, ["ability", "melee"])
	_check("a skill gets no Opening - that is what the bare strike is for", _near(hp - (br.get("body") as Body).hp, 130.0))
	for i: int in 100:
		br.call("_tick_statuses", 0.02)
	_check("the stagger passes", not bool(br.call("has_status", "staggered")))
	br.queue_free()
	await get_tree().process_frame

	# ---------- working it off
	var d := _dummy_enemy(p)
	(p.get("reflux_by") as Dictionary)["water"] = 30.0
	p.call("_strike_target", d, 1.0, ["melee"])
	_check("each bare strike that lands sheds 1 reflux", _near(float(p.call("reflux_of", "water")), 29.0))
	p.call("apply_hit", d, {"damage": 10.0}, ["ability", "melee"])
	_check("a skill sheds none", _near(float(p.call("reflux_of", "water")), 29.0))
	d.queue_free()
	await get_tree().process_frame

	# ---------- interrupts
	var slam := _fighter(p, Vector3(0, 0, -2.5), "brute")
	slam.set("_attack_cd", 0.0)
	_run(slam, 0.3)
	_check("the brute starts its slam: a circle on the ground, flagged interruptible", float(slam.get("_windup")) >= 0.0 and bool(slam.call("is_interruptible"))
		and str((slam.get("telegraph") as Dictionary).get("kind", "")) == "circle" and bool((slam.get("telegraph") as Dictionary).get("interruptible", false)))
	p.call("apply_hit", slam, {"interrupts": true}, ["ability"])
	_check("an interrupting skill cancels it and staggers the brute", float(slam.get("_windup")) < 0.0 and bool(slam.call("has_status", "staggered"))
		and _near(float((slam.get("statuses") as Dictionary)["staggered"]["t"]), float(cfg["interrupt_stagger_s"])) and (slam.get("telegraph") as Dictionary).is_empty())
	slam.queue_free()
	var sw := _fighter(p, Vector3(0, 0, -1.8))
	sw.set("_attack_cd", 0.0)
	_run(sw, 0.2)
	_check("a skirmisher winds up its swing", float(sw.get("_windup")) >= 0.0 and not bool(sw.call("is_interruptible")))
	p.call("apply_hit", sw, {"interrupts": true}, ["ability"])
	_check("an ordinary swing is broken off but its owner is not staggered", float(sw.get("_windup")) < 0.0 and not bool(sw.call("has_status", "staggered")))
	sw.queue_free()
	await get_tree().process_frame

	# ---------- the brute's slam
	(p.get("body") as Body).hp = 100.0
	var b2 := _fighter(p, Vector3(0, 0, -2.6), "brute")
	b2.set("_attack_cd", 0.0)
	_run(b2, 0.2)
	var facing_then: Vector3 = b2.get("facing")
	p.global_position = b2.global_position + Vector3(1.2, 0, 2.2)   # a sidestep - still 2.5 m from it, inside the 3 m circle
	_run(b2, 0.6)
	_check("it does not track you once it has committed", (b2.get("facing") as Vector3).is_equal_approx(facing_then) and float(b2.get("_windup")) >= 0.0)
	var hp_before: float = (p.get("body") as Body).hp
	_run(b2, 0.6)
	_check("the slam lands on anyone still in the circle, for 45", _near(hp_before - (p.get("body") as Body).hp, 45.0), "took %f" % (hp_before - (p.get("body") as Body).hp))
	_check("a heavy blow takes your feet for a moment", bool(p.call("is_staggered")))
	var ess: float = float(p.get("essence"))
	p.call("cast_slot", 0)
	_check("and you cannot cast while staggered", _near(float(p.get("essence")), ess))
	p.set("_stagger_t", 0.0)
	(p.get("body") as Body).wounds.clear()
	(p.get("body") as Body).hp = 100.0
	_check("a slam that lands does not leave it stuck", float(b2.get("_stuck_t")) <= 0.0)
	p.global_position = b2.global_position + Vector3(0, 0, 2.0)
	b2.set("facing", Vector3(0, 0, 1))
	b2.set("_attack_cd", 0.0)
	_run(b2, 0.3)
	_check("it winds up again", float(b2.get("_windup")) >= 0.0)
	p.global_position = b2.global_position + Vector3(0, 0, 9.0)      # out of the circle
	hp_before = (p.get("body") as Body).hp
	_run(b2, 1.0)
	_check("stepping out of the circle makes it miss", _near((p.get("body") as Body).hp, hp_before) and float(b2.get("_windup")) < 0.0)
	_check("and a miss leaves it stuck with its back open", float(b2.get("_stuck_t")) > 1.0, "stuck %f" % float(b2.get("_stuck_t")))
	b2.queue_free()
	await get_tree().process_frame

	# ---------- the slot ring
	p.global_position = Vector3(600, 0, 0)
	var crowd: Array = []
	for i: int in 10:
		var a: float = TAU * float(i) / 10.0
		crowd.append(_fighter(p, Vector3(cos(a), 0, sin(a)) * 7.0))
	var held := 0
	for e: Node in crowd:
		if bool(p.call("claim_slot", e)):
			held += 1
	_check("six may stand in striking range; the rest wait", held == int(cfg["ring_slots"]) and int(cfg["ring_slots"]) == 6)
	_check("one that has a place keeps it", bool(p.call("claim_slot", crowd[0])) and not bool(p.call("claim_slot", crowd[9])))
	(crowd[0] as Node).call("take_hit", 99999.0, false, null)
	_check("a death frees its place for the next", bool(p.call("claim_slot", crowd[9])))
	for e: Node in crowd:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			e.queue_free()
	p.set("_ring", [])
	await get_tree().process_frame
	var holders: Array = []
	for i: int in int(cfg["ring_slots"]):
		var hold := _fighter(p, Vector3(40.0 + float(i) * 2.0, 0, 40.0))   # far off, but each holds a place
		hold.set("target", null)
		holders.append(hold)
		p.call("claim_slot", hold)
	var waiter := _fighter(p, Vector3(0, 0, -9.0))
	for i: int in 300:
		waiter.call("_physics_process", 1.0 / 60.0)
		await get_tree().physics_frame if i % 60 == 59 else null
	var stood: float = waiter.global_position.distance_to(p.global_position)
	_check("an enemy with no place holds a few metres out and never winds up", stood > 3.0 and float(waiter.get("_windup")) < 0.0, "stood at %f" % stood)
	for hold: Node in holders:
		hold.queue_free()
	p.set("_ring", [])
	waiter.queue_free()
	await get_tree().process_frame

	# ---------- the archer
	(p.get("body") as Body).wounds.clear()
	(p.get("body") as Body).hp = 100.0
	p.set("_stagger_t", 0.0)
	var ar := _fighter(p, Vector3(0, 0, -10.0), "archer")
	_check("an archer keeps its distance and aims along a line", str(ar.get("behaviour")) == "ranged")
	ar.set("_attack_cd", 0.0)
	(p as CharacterBody3D).velocity = Vector3(5.0, 0, 0)     # running to the side, straight
	_run(ar, 0.5)
	var tele: Dictionary = ar.get("telegraph")
	_check("while it aims, the line leads where you are going", str(tele.get("kind", "")) == "line" and not bool(tele.get("locked", true))
		and (tele["to"] as Vector3).x > p.global_position.x + 1.0, str(tele))
	_run(ar, 0.3)
	tele = ar.get("telegraph")
	var locked_at: Vector3 = tele.get("to", Vector3.ZERO)
	_check("the aim locks 0.3 s before release", bool(tele.get("locked", false)))
	(p as CharacterBody3D).velocity = Vector3(-5.0, 0, 0)    # a late change of direction
	_run(ar, 0.1)
	_check("after that it no longer follows you", ((ar.get("telegraph") as Dictionary).get("to", Vector3.ONE) as Vector3).is_equal_approx(locked_at))
	_run(ar, 0.25)
	var shot: Node = null
	for n: Node in get_children():
		if n.get("shooter") == ar:
			shot = n
	_check("it looses one shot along the locked line", shot != null and float(ar.get("_windup")) < 0.0)
	hp_before = (p.get("body") as Body).hp
	for i: int in 60:
		if shot == null or not is_instance_valid(shot) or shot.is_queued_for_deletion():
			break
		shot.call("tick", 1.0 / 60.0)
	_check("standing where you were when it locked, you are missed", _near((p.get("body") as Body).hp, hp_before), "took %f" % (hp_before - (p.get("body") as Body).hp))
	await get_tree().process_frame
	# the same shot, but the player is where the line said they would be
	var ShotScript: GDScript = load("res://scripts/enemy_shot.gd")
	var arrow: Node3D = ShotScript.new()
	arrow.set("dir", (locked_at - ar.global_position).normalized())
	arrow.set("target", p)
	arrow.set("shooter", ar)
	arrow.set("damage", 18.0)
	arrow.position = ar.global_position + Vector3.UP * 1.1
	add_child(arrow)
	p.global_position = Vector3(locked_at.x, p.global_position.y, locked_at.z)
	for i: int in 60:
		if not is_instance_valid(arrow) or arrow.is_queued_for_deletion():
			break
		arrow.call("tick", 1.0 / 60.0)
	_check("running straight on, you are where the line said and it hits for 18", _near(hp_before - (p.get("body") as Body).hp, 18.0), "took %f" % (hp_before - (p.get("body") as Body).hp))
	(p as CharacterBody3D).velocity = Vector3.ZERO
	p.global_position = ar.global_position + Vector3(0, 0, 2.0)
	ar.set("_attack_cd", 0.0)
	ar.set("_windup", -1.0)
	ar.set("telegraph", {})
	var aimed_up_close := false
	var backed := true
	for i: int in 8:                                         # sampled while it is still inside 4 m
		ar.call("_physics_process", 1.0 / 60.0)
		if ar.global_position.distance_to(p.global_position) >= 4.0:
			break
		aimed_up_close = aimed_up_close or float(ar.get("_windup")) >= 0.0
		backed = backed and ar.velocity.dot(p.global_position - ar.global_position) < 0.0
	_check("come within 4 m and it only backs away - helpless in melee", backed and not aimed_up_close)
	ar.queue_free()
	await get_tree().process_frame

	# ---------- the harrier
	(p.get("body") as Body).wounds.clear()
	(p.get("body") as Body).hp = 100.0
	p.set("_stagger_t", 0.0)
	p.global_position = Vector3(600, 0, 0)
	var pack := _fighter(p, Vector3(0, 0, -8.0))             # the pack it waits for you to run from
	pack.set("target", null)
	var h := _fighter(p, Vector3(6.5, 0, 0), "harrier")
	h.set("_attack_cd", 0.0)
	(p as CharacterBody3D).velocity = Vector3.ZERO
	_run(h, 2.5)
	_check("while you stand and fight, the harrier only circles", float(h.get("_windup")) < 0.0 and float(h.get("_leap_left")) <= 0.0 and _near(float(h.get("_retreat_t")), 0.0))
	(p as CharacterBody3D).velocity = Vector3(0, 0, 5.0)     # running away from the pack
	h.global_position = p.global_position + Vector3(5.0, 0, 0)
	_run(h, 1.4)
	_check("run from the pack and it counts", float(h.get("_retreat_t")) > 1.0 and float(h.get("_windup")) < 0.0)
	_run(h, 0.2)
	_check("after a second and a half it crouches", float(h.get("_windup")) >= 0.0)
	p.call("deal_damage", h, 10.0, ["test"])
	_check("hit it in the crouch and it is knocked down for 2 s", float(h.get("_windup")) < 0.0 and bool(h.call("has_status", "staggered"))
		and _near(float((h.get("statuses") as Dictionary)["staggered"]["t"]), 2.0))
	h.call("clear_status", "staggered")
	# a leap that finds you
	(p as CharacterBody3D).velocity = Vector3.ZERO
	h.global_position = p.global_position + Vector3(5.0, 0, 0)
	h.set("facing", Vector3(-1, 0, 0))
	h.set("_aim", Vector3(-1, 0, 0))
	h.set("_leap_left", 8.0)
	h.set("_leap_hit", false)
	hp_before = (p.get("body") as Body).hp
	_run(h, 0.6)
	_check("a leap that reaches you hits for 20 and staggers you", _near(hp_before - (p.get("body") as Body).hp, 20.0) and bool(p.call("is_staggered")), "took %f" % (hp_before - (p.get("body") as Body).hp))
	# and one that does not
	p.set("_stagger_t", 0.0)
	(p.get("body") as Body).wounds.clear()
	h.set("_stuck_t", 0.0)
	h.global_position = p.global_position + Vector3(5.0, 0, 0)
	h.set("_aim", Vector3(0, 0, -1))                         # leaping past
	h.set("_leap_left", 8.0)
	h.set("_leap_hit", false)
	hp_before = (p.get("body") as Body).hp
	_run(h, 0.6)
	_check("a leap that misses leaves it stuck for a second", _near((p.get("body") as Body).hp, hp_before) and float(h.get("_stuck_t")) > 0.5)
	# alone, it does not wait
	pack.queue_free()
	await get_tree().process_frame
	h.set("_stuck_t", 0.0)
	h.set("_attack_cd", 0.0)
	h.set("_retreat_t", 0.0)
	h.global_position = p.global_position + Vector3(6.0, 0, 0)
	_run(h, 1.8)
	_check("with no pack left it comes for you anyway, so a fight can end", float(h.get("_windup")) >= 0.0 or float(h.get("_leap_left")) > 0.0 or float(h.get("_stuck_t")) > 0.0)
	h.queue_free()
	await get_tree().process_frame

	# ---------- dash commitment
	var w := _new_player("one_percent_lifesteal")
	w.global_position = Vector3(700, 0, 0)
	w.set("star_pct", [99.0] as Array[float])
	w.call("_recompute_essence_max")
	w.set("essence", 99.0)
	w.set("_facing", Vector3(0, 0, -1))
	var step_cost: float = float(GameData.ability("hydraulic_flex")["cost"])
	var step_reflux: float = step_cost * float(GameData.ability("hydraulic_flex")["reflux_per_cost"])
	w.call("cast_slot", 2)
	_check("a dash costs what it says the first time", _near(float(w.get("essence")), 99.0 - step_cost) and _near(float(w.call("reflux_of", "water")), step_reflux))
	_check("and commits you: no striking or casting until just after it ends", _near(float(w.get("_recover_t")), float(GameData.ability("hydraulic_flex")["dash_time"]) + float(cfg["dash_recovery_s"])),
		"recover %f" % float(w.get("_recover_t")))
	_rested(w)
	w.call("cast_slot", 2)
	_check("a second one too soon costs double, in essence and in heat", _near(float(w.get("essence")), 99.0 - step_cost * 3.0) and _near(float(w.call("reflux_of", "water")), step_reflux * 3.0),
		"essence %f reflux %f" % [float(w.get("essence")), float(w.call("reflux_of", "water"))])
	_rested(w)
	w.set("_winded_t", 0.0)
	var e3: float = float(w.get("essence"))
	w.call("cast_slot", 2)
	_check("wait it out and the price is the plain one again", _near(e3 - float(w.get("essence")), step_cost))
	_rested(w)
	e3 = float(w.get("essence"))
	w.call("cast_slot", 0)
	_check("being winded does not touch other skills", _near(e3 - float(w.get("essence")), float(GameData.ability("water_bolt")["cost"])))
	w.queue_free()

	# ---------- getting through a doorway (the full-passage bot stalled against a dividing wall)
	var L := 14.0
	var gap := 2.0
	_check("chambers are counted down the passage", Route.chamber_of(Vector3(0, 0, -3), L) == 0 and Route.chamber_of(Vector3(0, 0, -15), L) == 1 and Route.chamber_of(Vector3(0, 0, -139.1), L) == 9)
	var same: Vector3 = Route.step_toward(Vector3(5, 0, -20), Vector3(-4, 0, -26), L, gap, 0.4)
	_check("in the same chamber you walk straight at it", same.is_equal_approx(Vector3(-4, 0, -26)))
	# the case that stalled: 4.9 m off-centre, just short of the wall, target in the next chamber
	var stalled := Vector3(4.9, 0, -139.1)
	var first: Vector3 = Route.step_toward(stalled, Vector3(4.8, 0, -148.2), L, gap, 0.4)
	_check("off to one side, you go to the front of the gap first, not at the wall", absf(first.x) < gap and first.z > -140.0 and first.z < -138.0, str(first))
	var lined: Vector3 = Route.step_toward(Vector3(0.6, 0, -138.6), Vector3(4.8, 0, -148.2), L, gap, 0.4)
	_check("in line with the gap, you go straight through to the far side", absf(lined.x) < gap and lined.z < -140.0, str(lined))
	var back: Vector3 = Route.step_toward(Vector3(0.3, 0, -141.0), Vector3(3, 0, -133), L, gap, 0.4)
	_check("and the same coming back the other way", absf(back.x) < gap and back.z > -140.0, str(back))
	var wide: Vector3 = Route.step_toward(Vector3(1.5, 0, -138.6), Vector3(0, 0, -148), L, gap, 0.9)
	_check("a wide body keeps clear of the wall's edge", absf(wide.x) <= gap - 0.9)
	# walk it: a point that only ever steps toward what Route says must get through
	var walker := stalled
	var goal := Vector3(4.8, 0, -148.2)
	var crossed := false
	var hit_wall := false
	for i: int in 400:
		var nxt: Vector3 = Route.step_toward(walker, goal, L, gap, 0.4)
		var stepv: Vector3 = nxt - walker
		if stepv.length() < 0.05:
			break
		var moved: Vector3 = walker + stepv.normalized() * 0.1
		if (walker.z > -140.0) != (moved.z > -140.0) and absf(moved.x) > gap - 0.4:
			hit_wall = true                       # it would have crossed the wall line outside the gap
		walker = moved
		if walker.distance_to(goal) < 0.2:
			crossed = true
			break
	_check("following the route from where the bot stalled reaches the target without touching the wall", crossed and not hit_wall, "ended at %s" % str(walker))

	# ---------- what stands at each wall
	var recipes: Dictionary = GameData.balance["passage"]["wall_recipes"]
	_check("the first wall is skirmishers only, the second brings an archer", (recipes["1"] as Dictionary).is_empty() and int((recipes["2"] as Dictionary).get("archer", 0)) == 1)
	var seen: Array = []
	var ok := true
	for n: int in range(1, 11):
		var r: Dictionary = {}
		for k: int in range(n, 0, -1):
			if recipes.has(str(k)):
				r = recipes[str(k)]
				break
		var fresh := 0
		for kind: String in r:
			if GameData.enemy(kind).is_empty():
				ok = false
			if not seen.has(kind):
				seen.append(kind)
				fresh += 1
		if fresh > 1:
			ok = false
	_check("no wall introduces more than one new kind, and every kind exists", ok and seen.has("archer") and seen.has("harrier"), str(seen))

	p.queue_free()
	world.queue_free()
	await get_tree().process_frame


var _calls: Array = []


func _on_test_reinforcements(_who: Node, kinds: Array) -> void:
	_calls.append(kinds)


func _test_step4_enemies() -> void:
	print("the rest of the enemies (design/05 step 4):")
	await get_tree().process_frame
	var p := _new_player()
	p.global_position = Vector3(1700, 0, 0)
	var here: Vector3 = p.global_position
	var world := _test_floor(here)
	await get_tree().physics_frame
	await get_tree().physics_frame
	p.set("effects", [] as Array[TalentEffect])
	_bare(p)
	var body: Body = p.get("body")
	var rear: float = float(GameData.balance["combat"]["rear_mult"])
	var stag: float = float(GameData.status("staggered")["damage_taken_mult"])
	var well := func() -> void:
		body.wounds.clear()
		body.hp = body.total_max()
		p.set("_stagger_t", 0.0)
		p.set("poise", 100.0)
		p.set("_shoved_left", 0.0)
		p.set("_wound_cd", 0.0)
		p.global_position = here

	# ---------- Pavise Bearer
	var pv := _fighter(p, Vector3(0, 0, -3.0), "pavise")
	pv.set("facing", Vector3(0, 0, 1))
	p.call("deal_damage", pv, 100.0, ["test"])
	_check("a Pavise Bearer's shield takes 80% off anything from the front", _near(_lost(pv), 20.0), "lost %f" % _lost(pv))
	_check("a shot from the front stops on it", bool(pv.call("blocks_shot", here)))
	var behind_it := _foe(p, Vector3(0, 0, -6.0))
	var ProjScript: GDScript = load("res://scripts/projectile.gd")
	var gust: Node3D = ProjScript.new()
	gust.set("dir", Vector3(0, 0, -1))
	gust.set("speed", 30.0)
	gust.set("life", 0.5)
	gust.set("damage", 50.0)
	gust.set("pierce", true)
	gust.set("shooter", p)
	add_child(gust)
	gust.global_position = here + Vector3.UP
	_fly(gust)
	_check("even a shot that pierces: whoever stands behind the shield is safe", _near(_lost(behind_it), 0.0))
	behind_it.free()
	pv.set("facing", Vector3(0, 0, -1))
	var before: float = _lost(pv)
	p.call("deal_damage", pv, 100.0, ["test"])
	_check("get behind it and the blow lands whole, as a rear hit", _near(_lost(pv) - before, 100.0 * rear) and not bool(pv.call("blocks_shot", here)), "lost %f" % (_lost(pv) - before))
	pv.set("facing", Vector3(0, 0, 1))
	pv.call("take_poise", 100.0)
	_check("break its poise and the shield is down for 3 s", bool(pv.call("has_status", "staggered")) and _near(float((pv.get("statuses") as Dictionary)["staggered"]["t"]), 3.0))
	before = _lost(pv)
	p.call("deal_damage", pv, 100.0, ["test"])
	_check("while it is down the front is open", _near(_lost(pv) - before, 100.0 * stag), "lost %f" % (_lost(pv) - before))
	pv.call("clear_status", "staggered")
	well.call()
	p.global_position = here + Vector3(0, 0, -1.0)
	pv.call("_land_melee", 2.0)
	_check("its bash does 14", _near(body.total_max() - body.hp, 14.0), "took %f" % (body.total_max() - body.hp))
	var from: Vector3 = p.global_position
	for i: int in 30:
		p.call("_physics_process", 1.0 / 60.0)
	_check("and throws you 2 m back", _near(p.global_position.z - from.z, 2.0, 0.05) and absf(p.global_position.x - from.x) < 0.05, "moved %s" % str(p.global_position - from))
	well.call()
	p.global_position = here + Vector3(0, 0, -1.0)
	p.set("_windup", {"braced": true, "release": false, "facing": Vector3(0, 0, -1)})
	p.set("_windup_t", 0.5)
	pv.call("_land_melee", 2.0)
	_check("Braced, you are not moved", _near(float(p.get("_shoved_left")), 0.0))
	p.set("_windup", {})
	p.set("_windup_t", 0.0)
	pv.free()

	# ---------- Censer-Bearer
	well.call()
	var cs := _fighter(p, Vector3(0, 0, -3.0), "censer")
	var hurt := _fighter(p, Vector3(2.0, 0, -4.0))
	var away := _fighter(p, Vector3(0, 0, -12.0))
	(hurt.get("body") as Body).hp = 100.0
	(away.get("body") as Body).hp = 100.0
	p.call("deal_damage", cs, 99999.0, ["test"])
	var bursts: Array = get_tree().get_nodes_in_group("censer_bursts")
	_check("a Censer-Bearer that dies leaves its censer flaring", bursts.size() == 1 and _near((hurt.get("body") as Body).hp, 100.0))
	var burst: Node = bursts[0]
	burst.call("tick", 0.5)
	_check("for 0.8 s nothing has happened yet", _near((hurt.get("body") as Body).hp, 100.0) and not bool(hurt.call("has_status", "frenzied")))
	burst.call("tick", 0.35)
	_check("then it bursts: an enemy within 4 m gets back 40% of its health", _near((hurt.get("body") as Body).hp, 100.0 + 0.4 * 240.0), "hp %f" % (hurt.get("body") as Body).hp)
	_check("and is frenzied", bool(hurt.call("has_status", "frenzied")))
	_check("one farther off gets nothing", _near((away.get("body") as Body).hp, 100.0) and not bool(away.call("has_status", "frenzied")))
	hurt.set("_attack_cd", 5.0)
	hurt.call("_physics_process", 0.1)
	_check("frenzied: it attacks 30% faster", _near(float(hurt.get("_attack_cd")), 5.0 - 0.13, 0.005), "cd %f" % float(hurt.get("_attack_cd")))
	_check("and moves 30% faster", _near(hurt.velocity.length(), 3.4 * 1.3, 0.15), "speed %f" % hurt.velocity.length())
	hurt.free()
	away.free()

	# ---------- War Drummer
	well.call()
	var dr := _fighter(p, Vector3(0, 0, -10.0), "drummer")
	var line := _fighter(p, Vector3(0, 0, -6.0))
	line.set("facing", Vector3(0, 0, 1))
	var lone := _fighter(p, Vector3(0, 0, -30.0))
	dr.set("_attack_cd", 99.0)
	_run(dr, 0.1)
	_check("a War Drummer steadies whoever is within 6 m of it, and nobody else", bool(line.call("has_status", "drummed")) and not bool(lone.call("has_status", "drummed")))
	line.call("take_poise", 30.0)
	_check("drummed: poise damage is cut by a third", _near(float(line.get("poise")), 40.0 - 20.0), "poise %f" % float(line.get("poise")))
	line.set("_attack_cd", 5.0)
	line.set("target", null)
	line.call("_physics_process", 0.1)
	line.set("target", p)
	_check("and it attacks 25% faster", _near(float(line.get("_attack_cd")), 5.0 - 0.125, 0.005), "cd %f" % float(line.get("_attack_cd")))
	var hp0: float = body.hp
	_run(dr, 3.0)
	_check("it never attacks", _near(body.hp, hp0) and float(dr.get("_windup")) < 0.0)
	_check("and keeps the line between itself and you", dr.global_position.z < here.z - 10.5, "z %f" % (dr.global_position.z - here.z))
	dr.set("_attack_cd", 0.0)
	_run(dr, 0.05)
	_check("every so often it raises its sticks - a wind-up an interrupt would punish", float(dr.get("_windup")) >= 0.0 and bool(dr.call("is_interruptible")))
	_run(dr, 1.0)
	_check("after a second the roll rouses a fighter near it", bool(line.call("has_status", "roused")) and not bool(lone.call("has_status", "roused")))
	well.call()
	p.global_position = line.global_position + Vector3(0, 0, 2.0)
	line.call("_land_melee", 2.0)
	_check("a roused skirmisher's next blow is heavy: it staggers you", bool(p.call("is_staggered")) and not bool(line.call("has_status", "roused")))
	well.call()
	line.call("_land_melee", 99.0)
	p.global_position = line.global_position + Vector3(0, 0, 2.0)
	line.call("_land_melee", 2.0)
	_check("only that one blow", not bool(p.call("is_staggered")))
	well.call()
	dr.set("_attack_cd", 0.0)
	_run(dr, 0.05)
	_check("interrupt the roll and the drummer is staggered instead", bool(dr.call("interrupt_attack")) and bool(dr.call("has_status", "staggered")) and float(dr.get("_windup")) < 0.0)
	p.call("deal_damage", dr, 99999.0, ["test"])
	line.call("_tick_statuses", 1.1)
	_check("kill it and the steadiness goes within a second", not bool(line.call("has_status", "drummed")))
	line.free()
	lone.free()

	# ---------- Wall Commander
	well.call()
	var cm := _fighter(p, Vector3(0, 0, -3.0), "commander")
	cm.set("facing", Vector3(0, 0, 1))
	cm.connect("reinforcements", _on_test_reinforcements)
	var cb: Body = cm.get("body")
	p.call("deal_damage", cm, 100.0, ["test"])
	_check("phase 1: the Wall Commander blocks from the front", _near(_lost(cm), 40.0), "lost %f" % _lost(cm))
	_check("and answers a blocked hit with a fast swing", float(cm.get("_windup")) >= 0.0 and float(cm.get("_windup")) <= 0.25)
	cm.set("_windup", -1.0)
	cm.set("telegraph", {})
	p.call("deal_damage", cm, 100.0, ["test"])
	_check("but not twice in a row", float(cm.get("_windup")) < 0.0)
	cb.hp = cb.total_max() * 0.59
	_calls.clear()
	cm.set("_attack_cd", 99.0)
	cm.call("_physics_process", 1.0 / 60.0)
	_check("at 60% it calls three skirmishers and a drummer", int(cm.get("phase")) == 2 and _calls.size() == 1 and (_calls[0] as Array) == ["grunt", "grunt", "grunt", "drummer"], str(_calls))
	cm.call("_physics_process", 1.0 / 60.0)
	_check("once", _calls.size() == 1)
	before = _lost(cm)
	cm.set("facing", Vector3(0, 0, 1))
	p.call("deal_damage", cm, 100.0, ["test"])
	_check("and no longer blocks", _near(_lost(cm) - before, 100.0), "lost %f" % (_lost(cm) - before))
	_check("phase 2 adds a sweep, marked on the floor as a cone", str(cm.get("_special")) == "sweep" and str((cm.get("telegraph") as Dictionary).get("kind", "")) == "cone")
	well.call()
	hp0 = body.hp
	var swept := false
	for i: int in 70:
		cm.call("_physics_process", 1.0 / 60.0)
		if str(cm.get("_special")) == "" and not swept:
			swept = true
			_check("0.8 s later it lands for 35 on whoever is still in it", _near(hp0 - body.hp, 35.0) and i >= 46 and i <= 50, "took %f at frame %d" % [hp0 - body.hp, i])
			break
	_check("the sweep came", swept)
	well.call()
	(cm.get("_special_cd") as Dictionary)["sweep"] = 0.0
	cm.set("_windup", -1.0)
	cm.set("_attack_cd", 99.0)
	cm.set("facing", Vector3(0, 0, 1))
	cm.call("_physics_process", 1.0 / 60.0)
	p.global_position = cm.global_position + Vector3(0, 0, -4.0)          # round behind it
	hp0 = body.hp
	for i: int in 60:
		cm.call("_physics_process", 1.0 / 60.0)
	_check("step out of the cone and it finds nothing", _near(body.hp, hp0), "took %f" % (hp0 - body.hp))

	# phase 3: the charge
	well.call()
	cm.global_position = here + Vector3(0, 0, -10.0)
	cm.set("facing", Vector3(0, 0, 1))
	cm.set("_windup", -1.0)
	cm.set("_special", "")
	cm.set("_stuck_t", 0.0)
	cb.hp = cb.total_max() * 0.29
	await get_tree().physics_frame
	cm.call("_physics_process", 1.0 / 60.0)
	_check("under 30% it marks a lane and sets itself to charge", int(cm.get("phase")) == 3 and str(cm.get("_special")) == "charge")
	cm.call("_physics_process", 1.0 / 60.0)
	_check("the lane is drawn on the floor", str((cm.get("telegraph") as Dictionary).get("kind", "")) == "lane")
	_check("an ordinary interrupt does not stop it", not bool(cm.call("interrupt_attack")) and str(cm.get("_special")) == "charge")
	cm.call("shove", Vector3(1, 0, 0), 5.0)
	_check("nor does a shove", not bool(cm.call("is_shoved")))
	_run(cm, 1.0)
	_check("after a second it goes", float(cm.get("_charge_left")) > 0.0 and str(cm.get("_special")) == "")
	hp0 = body.hp
	_run(cm, 2.0)
	_check("stand in the lane and it hits once, for 60", _near(hp0 - body.hp, 60.0), "took %f" % (hp0 - body.hp))
	_check("with open floor ahead it simply runs out of room", _near(cm.global_position.z - here.z, 12.0, 0.3) and not bool(cm.call("has_status", "dazed")), "z %f" % (cm.global_position.z - here.z))

	var world2 := _test_floor(here, here.z + 4.0)                        # a wall behind you
	await get_tree().physics_frame
	await get_tree().physics_frame
	well.call()
	cm.global_position = here + Vector3(0, 0, -10.0)
	cm.set("facing", Vector3(0, 0, 1))
	cm.set("_stuck_t", 0.0)
	cm.set("_windup", -1.0)
	(cm.get("_special_cd") as Dictionary)["charge"] = 0.0
	await get_tree().physics_frame
	cm.call("_physics_process", 1.0 / 60.0)
	p.global_position = here + Vector3(5.0, 0, 0)                        # step aside once it has committed
	hp0 = body.hp
	_run(cm, 2.2)
	_check("put a wall behind you and step aside: it misses", _near(body.hp, hp0))
	_check("and crashes: stunned for 3 s and dazed", bool(cm.call("has_status", "stunned")) and bool(cm.call("has_status", "dazed"))
		and float((cm.get("statuses") as Dictionary)["stunned"]["t"]) > 2.0, "at z %f" % (cm.global_position.z - here.z))
	before = _lost(cm)
	cm.call("take_hit", 100.0, false, null)
	_check("dazed, it takes half again as much", _near(_lost(cm) - before, 150.0), "lost %f" % (_lost(cm) - before))
	cm.call("clear_status", "stunned")
	cm.call("clear_status", "dazed")
	cm.global_position = here + Vector3(0, 0, -10.0)
	(cm.get("_special_cd") as Dictionary)["charge"] = 0.0
	cm.set("_stuck_t", 0.0)
	p.global_position = here
	await get_tree().physics_frame
	cm.call("_physics_process", 1.0 / 60.0)
	_run(cm, 1.1)
	var running: bool = float(cm.get("_charge_left")) > 0.0
	cm.call("stun", 1.0)
	_check("a stun stops the charge dead", running and _near(float(cm.get("_charge_left")), 0.0))
	cm.free()
	world2.free()

	# the recipes keep to one problem a pack
	var ok := true
	var recipes: Dictionary = GameData.balance["passage"]["wall_recipes"]
	for key: String in recipes:
		if key != "_note":
			ok = ok and int((recipes[key] as Dictionary).get("censer", 0)) <= 1 and int((recipes[key] as Dictionary).get("drummer", 0)) <= 1
	_check("no wall has more than one Censer-Bearer or one Drummer", ok)
	for kind: String in ["pavise", "censer", "drummer"]:
		var rig: Node = Models.enemy(kind)
		_check("the %s has a model of its own" % kind, rig != null and (rig as ModelRig).triangle_count() > 0)
		rig.free()
	p.free()
	world.free()


## Cast a skill by its id (the character must know it).
func _cast(p: Node, ability_id: String) -> void:
	var list: Array = p.get("abilities")
	for i: int in list.size():
		if str(list[i]["id"]) == ability_id:
			p.call("cast_ability", i)
			return
	_check("the character knows %s" % ability_id, false)


func _test_step5a() -> void:
	print("scrolls and ten more skills (design/05 step 5a):")
	await get_tree().process_frame
	# ---------- learning
	var w := _new_player()
	var inv: Inventory = w.get("inventory")
	_check("a water character cannot learn an earth skill", str(w.call("can_learn", "pillar")) != "" and str(w.call("can_learn", "undertow")) == "")
	inv.add("scroll_pillar")
	_check("and reading the scroll does nothing but say so", str(w.call("read_scroll", "scroll_pillar")) != "" and inv.bag.has("scroll_pillar") and not bool(w.call("knows", "pillar")))
	var loot_before: int = inv.loot_value()
	inv.add("scroll_undertow")
	_check("a scroll is not loot: it is not counted or sold with the rest", inv.loot_value() == loot_before and not Inventory.is_loot("scroll_undertow"))
	inv.sell_loot()
	_check("selling all loot leaves it in the pack", inv.bag.has("scroll_undertow"))
	_check("reading a scroll of your own affinity teaches the skill", str(w.call("read_scroll", "scroll_undertow")) == "" and bool(w.call("knows", "undertow")))
	_check("the scroll is used up", not inv.bag.has("scroll_undertow"))
	_check("the skill lands on the first empty key", int((w.get("hotbar") as Array)[3]) == (w.get("abilities") as Array).size() - 1)
	inv.add("scroll_undertow")
	_check("a second copy cannot be read", str(w.call("read_scroll", "scroll_undertow")) != "" and inv.bag.has("scroll_undertow"))
	inv.remove("scroll_undertow")
	var drop: String = w.call("scroll_for_me")
	_check("a drop for this character is a scroll they can still use", ["scroll_riptide_lash", "scroll_standing_pool", "scroll_backwash"].has(drop), drop)
	for more: String in ["riptide_lash", "standing_pool", "backwash"]:
		w.call("learn", more)
	_check("and nothing once they know them all", str(w.call("scroll_for_me")) == "")
	var saved: Dictionary = w.call("to_save")
	var again := _new_player()
	again.call("from_save", saved)
	_check("learned skills survive a save", bool(again.call("knows", "undertow")) and bool(again.call("knows", "riptide_lash")))
	again.free()
	w.free()
	var icons: Dictionary = {}
	var each_has_scroll := true
	var kits: Array = []
	for a: Variant in GameData.affinity_ids():
		kits.append_array(GameData.affinity(str(a)).get("kit", []))
	for id: Variant in GameData.abilities.keys():
		icons[str(GameData.ability(str(id)).get("icon", ""))] = true
		if not kits.has(str(id)):
			each_has_scroll = each_has_scroll and str(GameData.item("scroll_" + str(id)).get("teaches", "")) == str(id)
	_check("every skill has an icon of its own", icons.size() == GameData.abilities.size(), "%d icons for %d skills" % [icons.size(), GameData.abilities.size()])
	_check("every skill outside the starter kits has a scroll", each_has_scroll)

	# ---------- the skills
	var m := _new_player()
	m.call("set_affinities", ["water", "fire", "earth", "wind", "lightning"])
	for id: String in ["undertow", "riptide_lash", "backdraft", "pyre_call", "pillar", "tremor", "downdraft", "updraft", "forked_path", "dead_short"]:
		m.call("learn", id)
	m.global_position = Vector3(1900, 0, 0)
	var here: Vector3 = m.global_position
	var world := _test_floor(here)
	await get_tree().physics_frame
	await get_tree().physics_frame
	m.set("effects", [] as Array[TalentEffect])
	_bare(m)
	m.set("star_pct", [99.0] as Array[float])
	m.call("_recompute_essence_max")
	var fresh := func() -> void:
		_rested(m)
		m.set("essence", 99.0)
		m.call("clear_reflux")
		m.set("_windup", {})
		m.set("_windup_t", 0.0)
		m.set("_facing", Vector3(0, 0, -1))
		m.set("cursor_fixed", null)
		m.set("hovered", null)
		m.set("attack_target", null)
		m.call("drop_stones")
	var spot: Vector3 = here + Vector3(0, 0, -7.0)

	# Undertow
	fresh.call()
	var a := _facing_foe(m, Vector3(3.0, 0, -7.0))
	var c := _facing_foe(m, Vector3(6.0, 0, -7.0))
	m.set("cursor_fixed", spot)
	_cast(m, "undertow")
	_settle(a)
	_check("Undertow drags an enemy within 4 m to the spot", a.global_position.distance_to(spot) < 0.45, "%.2f m off" % a.global_position.distance_to(spot))
	_check("Soaks it, and does no damage of its own", bool(a.call("has_status", "soaked")) and _near(_lost(a), 0.0))
	_check("and leaves one farther out alone", _near(c.global_position.x - here.x, 6.0) and not bool(c.call("has_status", "soaked")))
	a.free()
	c.free()

	# Riptide Lash
	fresh.call()
	var t := _facing_foe(m, Vector3(0, 0, -8.0))
	t.set("target", m)
	t.set("_windup", 0.3)
	_cast(m, "riptide_lash")
	_check("Riptide Lash does 60, Soaks and interrupts", _near(_lost(t), 60.0) and bool(t.call("has_status", "soaked")) and float(t.get("_windup")) < 0.0, "lost %f" % _lost(t))
	_settle(t)
	_check("and hauls the enemy to arm's length", _near(t.global_position.distance_to(here), 2.0, 0.1), "%.2f m" % t.global_position.distance_to(here))
	_check("with its back to you", (t.get("facing") as Vector3).dot(Vector3(0, 0, -1)) > 0.95 and bool(t.call("is_behind", here)))
	t.call("_turn_toward", Vector3(0, 0, 1), 0.5)
	_check("for a second it cannot turn round", (t.get("facing") as Vector3).dot(Vector3(0, 0, -1)) > 0.95)
	t.free()
	fresh.call()
	var heavy := _fighter(m, Vector3(0, 0, -8.0), "brute")
	_cast(m, "riptide_lash")
	_settle(heavy)
	_check("a heavy enemy comes only part of the way", _near(heavy.global_position.distance_to(here), 3.0, 0.15), "%.2f m" % heavy.global_position.distance_to(here))
	heavy.free()

	# Backdraft
	fresh.call()
	var f1 := _facing_foe(m, Vector3(0, 0, -4.0))
	var f2 := _facing_foe(m, Vector3(4.0, 0, 3.0))
	var f3 := _facing_foe(m, Vector3(0, 0, -7.0))
	(m.get("reflux_by") as Dictionary)["fire"] = 70.0
	_cast(m, "backdraft")
	_check("Backdraft winds up for 0.3 s", _near(float(m.get("_windup_t")), 0.3) and _near(_lost(f1), 0.0))
	m.call("_tick_windup", 0.31)
	_check("then everything within 5 m takes 4 x the heat above 20", _near(_lost(f1), 200.0) and _near(_lost(f2), 200.0) and _near(_lost(f3), 0.0), "lost %f / %f / %f" % [_lost(f1), _lost(f2), _lost(f3)])
	_check("and the heat is spent: fire reflux is 20", _near(float(m.call("reflux_of", "fire")), 20.0))
	fresh.call()
	(m.get("reflux_by") as Dictionary)["fire"] = 10.0
	var was: float = _lost(f1)
	_cast(m, "backdraft")
	m.call("_tick_windup", 0.31)
	_check("cold, it does nothing and takes nothing", _near(_lost(f1), was) and _near(float(m.call("reflux_of", "fire")), 10.0))
	for n: Node in [f1, f2, f3]:
		n.free()

	# Pyre Call
	fresh.call()
	var x := _facing_foe(m, Vector3(0, 0, -5.0))
	var y := _facing_foe(m, Vector3(1.5, 0, -5.0))
	var z := _facing_foe(m, Vector3(-8.0, 0, 0))
	x.call("add_status", "alight", 3, m)
	z.call("add_status", "alight", 2, m)
	_cast(m, "pyre_call")
	var hot: float = float(m.call("heat_mult", "fire"))
	_check("Pyre Call: each stack bursts for 35 on the one carrying it", _near(_lost(x), 105.0 * hot, 0.5) and _near(_lost(z), 70.0 * hot, 0.5), "lost %f / %f, heat x%f" % [_lost(x), _lost(z), hot])
	_check("and on whoever stands within 2 m", _near(_lost(y), 105.0 * hot, 0.5))
	_check("the fires are spent", not bool(x.call("has_status", "alight")) and not bool(z.call("has_status", "alight")))
	for n: Node in [x, y, z]:
		n.free()

	# Pillar
	fresh.call()
	var on := _facing_foe(m, Vector3(0, 0, -6.0))
	var off := _facing_foe(m, Vector3(2.5, 0, -6.0))
	m.set("cursor_fixed", here + Vector3(0, 0, -6.0))
	_cast(m, "pillar")
	var blasts: Array = get_tree().get_nodes_in_group("blasts")
	_check("Pillar marks the ground and you are Braced", blasts.size() == 1 and bool(m.call("is_braced")) and _near(_lost(on), 0.0))
	(blasts[0] as Node).call("tick", 0.4)
	_check("for half a second nothing", _near(_lost(on), 0.0))
	(blasts[0] as Node).call("tick", 0.15)
	_check("then the column: 120 to whoever stood there, nobody else", _near(_lost(on), 120.0) and _near(_lost(off), 0.0), "lost %f" % _lost(on))
	_check("and it stays as one of your stones", int(m.call("stone_count")) == 1 and _near(((m.get("stones") as Array)[0] as Stone).size.x, 1.2))
	m.call("_tick_windup", 0.31)
	on.free()
	off.free()

	# Tremor
	fresh.call()
	var slab_ab: Dictionary = GameData.ability("raise_slab")
	var s1: Node3D = m.call("raise_stone", here + Vector3(0, 0, -3.0), Vector3(0, 0, -1), slab_ab)
	s1.call("tick", 0.5)
	var near := _facing_foe(m, Vector3(-3.0, 0, 2.0))
	var past := _facing_foe(m, Vector3(0, 0, -6.5))                      # outside the ring, inside the shrapnel
	near.set("target", m)
	near.set("_windup", 0.3)
	_cast(m, "tremor")
	m.call("_tick_windup", 0.51)
	_check("Tremor: 60 to everything within 5 m, interrupted and slowed", _near(_lost(near), 60.0) and bool(near.call("has_status", "slowed")) and float(near.get("_windup")) < 0.0, "lost %f" % _lost(near))
	_check("and every stone of yours shatters outward", int(m.call("stone_count")) == 0 and _near(_lost(past), 80.0), "lost %f" % _lost(past))
	near.set("target", null)
	near.free()
	past.free()

	# Downdraft
	fresh.call()
	var g := _facing_foe(m, Vector3(0, 0, -6.0))
	var up := _facing_foe(m, Vector3(2.0, 0, -6.0))
	var out := _facing_foe(m, Vector3(6.0, 0, -6.0))
	up.call("add_status", "aloft")
	var ShotScript: GDScript = load("res://scripts/enemy_shot.gd")
	var arrow: Node3D = ShotScript.new()
	add_child(arrow)
	arrow.set_physics_process(false)
	arrow.global_position = here + Vector3(1.0, 1.0, -6.0)
	m.set("cursor_fixed", here + Vector3(0, 0, -6.0))
	_cast(m, "downdraft")
	blasts = get_tree().get_nodes_in_group("blasts")
	(blasts.back() as Node).call("tick", 0.26)
	var air: float = float(GameData.status("aloft")["damage_taken_mult"])
	_check("Downdraft: 50 and pinned, within 4 m", _near(_lost(g), 50.0) and bool(g.call("has_status", "pinned")) and _near(_lost(out), 0.0), "lost %f" % _lost(g))
	_check("+100 to anything Aloft", _near(_lost(up), 150.0 * air, 0.5), "lost %f" % _lost(up))
	_check("and it knocks their shots out of the air", arrow.is_queued_for_deletion())
	g.set("target", m)
	g.set("_attack_cd", 99.0)
	m.global_position = here + Vector3(0, 0, 14.0)
	g.call("_physics_process", 1.0 / 60.0)
	_check("pinned: it walks at 40%", _near(g.velocity.length(), 3.4 * 0.4, 0.1), "speed %f" % g.velocity.length())
	m.global_position = here
	g.set("target", null)
	for n: Node in [g, up, out]:
		n.free()

	# Updraft
	fresh.call()
	m.set("pips", 4)
	var light := _facing_foe(m, Vector3(0, 0, -6.0))
	var big := _fighter(m, Vector3(1.5, 0, -6.0), "brute")
	m.set("cursor_fixed", here + Vector3(0, 0, -6.0))
	_cast(m, "updraft")
	_check("Updraft throws a light enemy Aloft, longer for every pip spent", bool(light.call("has_status", "aloft")) and _near(float((light.get("statuses") as Dictionary)["aloft"]["t"]), 2.0) and int(m.get("pips")) == 0)
	_check("a heavy one keeps its feet and loses poise", not bool(big.call("has_status", "aloft")) and _near(float(big.get("poise_max")) - float(big.get("poise")), 50.0))
	_check("no damage of its own", _near(_lost(light), 0.0))
	light.free()
	big.free()

	# Forked Path
	fresh.call()
	var row: Array = []
	for i: int in 5:
		row.append(_facing_foe(m, Vector3(3.0 * float(i), 0, -5.0)))
	_cast(m, "forked_path")
	var ok := true
	for i: int in 4:
		ok = ok and _near(_lost(row[i]), 50.0) and int((row[i] as Node).call("status_stacks", "live")) == 1
	_check("Forked Path: the target and three more, 50 and one mark each", ok, "lost %f %f %f %f" % [_lost(row[0]), _lost(row[1]), _lost(row[2]), _lost(row[3])])
	_check("and no further", _near(_lost(row[4]), 0.0) and int((row[4] as Node).call("status_stacks", "live")) == 0)

	# Dead Short
	fresh.call()
	(row[1] as Node).call("add_status", "live", 1)                       # two marks now
	var lost0: float = _lost(row[0])
	var lost1: float = _lost(row[1])
	_cast(m, "dead_short")
	_check("Dead Short: one mark is 40% of an Overload, two is 70%", _near(_lost(row[0]) - lost0, 60.0) and _near(_lost(row[1]) - lost1, 105.0), "lost %f / %f" % [_lost(row[0]) - lost0, _lost(row[1]) - lost1])
	_check("every mark in reach is spent and its owner stunned", int((row[2] as Node).call("status_stacks", "live")) == 0 and bool((row[0] as Node).call("has_status", "stunned")))
	_check("and no reflux is grounded", _near(float(m.call("reflux_of", "lightning")), 18.0 * 1.4), "reflux %f" % float(m.call("reflux_of", "lightning")))
	for n: Node in row:
		n.free()
	m.set("cursor_fixed", null)
	m.free()
	world.free()


func _test_step5b() -> void:
	print("pools, buffs, the rod and the shoulder (design/05 step 5b):")
	await get_tree().process_frame
	var m := _new_player()
	m.call("set_affinities", ["water", "fire", "earth", "wind", "lightning"])
	for id: String in ["standing_pool", "backwash", "slag_pool", "stoke", "stonehide", "veil", "gale_lane", "static_coat", "ground_rod", "bedrock_shove"]:
		_check("a character with the affinity can learn %s" % id, bool(m.call("learn", id)))
	m.global_position = Vector3(2100, 0, 0)
	var here: Vector3 = m.global_position
	var world := _test_floor(here)
	await get_tree().physics_frame
	await get_tree().physics_frame
	m.set("effects", [] as Array[TalentEffect])
	_bare(m)
	m.set("star_pct", [99.0] as Array[float])
	m.call("_recompute_essence_max")
	var body: Body = m.get("body")
	var fresh := func() -> void:
		_rested(m)
		m.set("essence", 99.0)
		m.call("clear_reflux")
		(m.get("buffs") as Dictionary).clear()
		m.set("_facing", Vector3(0, 0, -1))
		m.set("cursor_fixed", here + Vector3(0, 0, -6.0))
		m.set("_stagger_t", 0.0)
		m.set("poise", 100.0)
		m.set("_wound_cd", 0.0)
		m.set("_shoved_left", 0.0)
		m.set("_dash_time", 0.0)
		body.wounds.clear()
		body.hp = body.total_max()
		m.global_position = here
		m.set("_last_pos", here)
		for z: Node in get_tree().get_nodes_in_group("ground_zones"):
			z.free()
	var zone_of := func() -> Node:
		var found: Node = null
		for z: Node in get_tree().get_nodes_in_group("ground_zones"):
			if z.get("caster") == m and not z.is_queued_for_deletion():
				found = z
		return found

	# Standing Pool
	fresh.call()
	var wet := _facing_foe(m, Vector3(1.0, 0, -6.0))
	var dry := _facing_foe(m, Vector3(6.0, 0, -6.0))
	_cast(m, "standing_pool")
	var pool: Node = zone_of.call()
	_check("Standing Pool lays a pool 3.5 m across where you point", pool != null and str(pool.get("shape")) == "circle" and _near(float(pool.get("radius")), 3.5)
		and _near((pool.get("from") as Vector3).z, here.z - 6.0))
	pool.call("tick", 0.01)
	_check("enemies in it are Soaked and slowed, and unhurt", bool(wet.call("has_status", "soaked")) and bool(wet.call("has_status", "mired")) and _near(_lost(wet), 0.0))
	_check("those outside are not", not bool(dry.call("has_status", "soaked")))
	wet.call("shove", Vector3(1, 0, 0), 1.0)
	dry.call("shove", Vector3(1, 0, 0), 1.0)
	_check("a shove that starts in the pool goes twice as far (on top of Soaked)", _near(float(wet.get("_shove_left")), 3.0) and _near(float(dry.get("_shove_left")), 1.0), "%f / %f" % [float(wet.get("_shove_left")), float(dry.get("_shove_left"))])
	pool.call("tick", 8.0)
	_check("after 8 s it is gone", pool.is_queued_for_deletion())
	wet.free()
	dry.free()

	# Slag Pool
	fresh.call()
	var burn := _facing_foe(m, Vector3(0, 0, -6.0))
	var safe := _facing_foe(m, Vector3(5.0, 0, -6.0))
	_cast(m, "slag_pool")
	var slag: Node = zone_of.call()
	var hot: float = float(m.call("heat_mult", "fire"))
	slag.call("tick", 0.01)
	_check("Slag Pool: 25 and one Alight to whoever stands in it", _near(_lost(burn), 25.0 * hot, 0.3) and int(burn.call("status_stacks", "alight")) == 1 and _near(_lost(safe), 0.0), "lost %f" % _lost(burn))
	slag.call("tick", 1.0)
	_check("again every second", _near(_lost(burn), 50.0 * hot, 0.6) and int(burn.call("status_stacks", "alight")) == 2, "lost %f" % _lost(burn))
	burn.free()
	safe.free()

	# Gale Lane
	fresh.call()
	m.set("pips", 0)
	m.set("_pip_dist", 0.0)
	var blown := _facing_foe(m, Vector3(0, 0, -5.0))
	_cast(m, "gale_lane")
	var lane: Node = zone_of.call()
	_check("Gale Lane runs 10 m from your feet along your aim", lane != null and str(lane.get("shape")) == "strip" and _near((lane.get("to") as Vector3).z, here.z - 10.0))
	lane.call("tick", 1.0)
	_check("enemies in it are pushed down it, 3 m a second", _near(blown.global_position.z, here.z - 8.0, 0.1), "z %f" % (blown.global_position.z - here.z))
	_check("in it you move 40% faster", _near(float(m.call("_zone_num", "caster_speed_mult")), 1.4))
	_walk(m, Vector3(0, 0, -1.5))
	_check("and gain pips twice as fast", int(m.get("pips")) == 2, "%d pips" % int(m.get("pips")))
	m.global_position = here + Vector3(6.0, 0, 0)
	_check("outside it, nothing", _near(float(m.call("_zone_num", "caster_speed_mult")), 1.0))
	blown.free()

	# Backwash
	fresh.call()
	var gr := _fighter(m, Vector3(0, 0, -2.0))
	gr.set("facing", Vector3(0, 0, 1))
	_cast(m, "backwash")
	_check("Backwash sits on you", (m.get("buffs") as Dictionary).has("backwash"))
	gr.call("_land_melee", 2.0)
	_check("a melee hit on you is halved", _near(body.total_max() - body.hp, 5.0), "took %f" % (body.total_max() - body.hp))
	_check("and whoever threw it is shoved and Soaked", bool(gr.call("is_shoved")) and bool(gr.call("has_status", "soaked")))
	gr.set("_shove_left", 0.0)
	gr.call("_land_melee", 2.0)
	gr.set("_shove_left", 0.0)
	gr.call("_land_melee", 2.0)
	gr.set("_shove_left", 0.0)
	_check("three blows and it is spent", not (m.get("buffs") as Dictionary).has("backwash") and _near(body.total_max() - body.hp, 15.0))
	gr.call("_land_melee", 2.0)
	_check("the fourth lands whole", _near(body.total_max() - body.hp, 25.0))

	# Static Coat
	fresh.call()
	gr.call("clear_status", "soaked")
	var gb: Body = gr.get("body")
	gb.hp = gb.total_max()
	_cast(m, "static_coat")
	gr.call("_land_melee", 2.0)
	_check("Static Coat: an enemy that hits you takes 25 and a Live mark", _near(gb.total_max() - gb.hp, 25.0) and int(gr.call("status_stacks", "live")) == 1, "lost %f" % (gb.total_max() - gb.hp))
	m.call("deal_damage", gr, 1.0, ["melee"])
	_check("one bare strike adds nothing", int(gr.call("status_stacks", "live")) == 1)
	m.call("deal_damage", gr, 1.0, ["melee"])
	_check("the second adds a mark", int(gr.call("status_stacks", "live")) == 2)
	gr.free()

	# Stoke
	fresh.call()
	var lit := _facing_foe(m, Vector3(0, 0, -2.0))
	_cast(m, "stoke")
	_check("Stoke adds 25 heat at once", _near(float(m.call("reflux_of", "fire")), 25.0))
	m.call("deal_damage", lit, 1.0, ["melee"])
	_check("and your bare strikes set things Alight", int(lit.call("status_stacks", "alight")) == 1)
	m.call("_tick_buffs", 6.1)
	m.call("deal_damage", lit, 1.0, ["melee"])
	_check("for 6 s", int(lit.call("status_stacks", "alight")) == 1 and not (m.get("buffs") as Dictionary).has("stoke"))
	lit.free()

	# Stonehide
	fresh.call()
	_cast(m, "stonehide")
	_check("Stonehide: Braced without a wind-up", bool(m.call("is_braced")) and float(m.get("_windup_t")) <= 0.0)
	m.call("take_hit", 10.0, true, null)
	_check("40% less, and a heavy blow does not stagger you", _near(body.total_max() - body.hp, 6.0) and not bool(m.call("is_staggered")))
	m.call("shove", Vector3(1, 0, 0), 2.0)
	_check("nothing shoves you", _near(float(m.get("_shoved_left")), 0.0))
	_check("you move 25% slower", _near(float(m.call("buff_num", "move_speed_mult")), 0.75))
	m.call("_tick_buffs", 8.1)
	_check("for 8 s", not bool(m.call("is_braced")))

	# Crosswind Veil
	fresh.call()
	var ShotScript: GDScript = load("res://scripts/enemy_shot.gd")
	_cast(m, "veil")
	var arrow: Node3D = ShotScript.new()
	arrow.set("dir", Vector3(0, 0, 1))
	arrow.set("damage", 18.0)
	arrow.set("target", m)
	add_child(arrow)
	arrow.global_position = here + Vector3(0, 1, -8.0)
	_fly(arrow)
	_check("Crosswind Veil: a shot aimed at you misses", _near(body.hp, body.total_max()))
	m.set("pips", 5)
	for i: int in 120:
		m.call("_tick_slipstream", 1.0 / 60.0)
	_check("and standing still does not drain your pips", int(m.get("pips")) == 5)
	m.call("_tick_buffs", 5.1)
	arrow = ShotScript.new()
	arrow.set("dir", Vector3(0, 0, 1))
	arrow.set("damage", 18.0)
	arrow.set("target", m)
	add_child(arrow)
	arrow.global_position = here + Vector3(0, 1, -8.0)
	_fly(arrow)
	_check("when it ends the next one lands", _near(body.total_max() - body.hp, 18.0))

	# Ground Rod
	fresh.call()
	m.set("cursor_fixed", here + Vector3(0, 0, -5.0))
	var by_rod := _facing_foe(m, Vector3(2.0, 0, -5.0))
	_cast(m, "ground_rod")
	var rod: Node3D = m.get("rod")
	_check("Ground Rod stands where you point and does nothing by itself", rod != null and _near(rod.global_position.z, here.z - 5.0) and _near(_lost(by_rod), 0.0))
	_rested(m)
	_cast(m, "arc_lash")
	_check("cast lightning near it and the rod arcs to the nearest enemy: 40 and a mark", _near(_lost(by_rod), 40.0) and int(by_rod.call("status_stacks", "live")) == 1, "lost %f" % _lost(by_rod))
	_rested(m)
	_cast(m, "water_bolt")
	_check("other affinities do not wake it", _near(_lost(by_rod), 40.0))
	_rested(m)
	m.global_position = here + Vector3(0, 0, 6.0)
	_cast(m, "arc_lash")
	_check("nor lightning cast too far from it", _near(_lost(by_rod), 40.0))
	m.global_position = here
	_rested(m)
	m.set("essence", 99.0)
	_cast(m, "ground_rod")
	_check("one rod at a time", rod.is_queued_for_deletion() and m.get("rod") != rod)
	(m.get("rod") as Node).call("tick", 10.1)
	_check("it lasts 10 s", (m.get("rod") as Node).is_queued_for_deletion())
	by_rod.free()

	# Bedrock Shove
	fresh.call()
	var hit := _facing_foe(m, Vector3(0, 0, -2.5))
	_cast(m, "bedrock_shove")
	_check("Bedrock Shove: Braced while you move", bool(m.call("is_braced")))
	for i: int in 24:
		m.call("_physics_process", 1.0 / 60.0)
	_settle(hit)
	_check("the first enemy you meet is thrown 3 m and loses 50 poise", _near(hit.global_position.z, here.z - 5.5, 0.15) and _near(float(hit.get("poise_max")) - float(hit.get("poise")), 50.0), "z %f" % (hit.global_position.z - here.z))
	_check("and you stop there - you do not pass through", m.global_position.z > here.z - 2.0, "z %f" % (m.global_position.z - here.z))
	hit.free()
	fresh.call()
	var wall := _fighter(m, Vector3(0, 0, -2.5), "brute")
	_cast(m, "bedrock_shove")
	for i: int in 24:
		m.call("_physics_process", 1.0 / 60.0)
	_check("a heavy enemy stops you dead and loses 60 poise", not bool(wall.call("is_shoved")) and _near(float(wall.get("poise_max")) - float(wall.get("poise")), 60.0) and _near(wall.global_position.z, here.z - 2.5, 0.05))
	wall.free()
	fresh.call()
	m.set("cursor_fixed", null)
	m.free()
	world.free()


func _test_fog_map() -> void:
	print("fog of war (Brent 2026-10-18):")
	var fog := FogMap.new(Vector2(240, 160), 4.0)
	_check("a zone starts unseen", fog.explored() == 0.0 and not fog.is_seen(10, 10))
	_check("standing somewhere sees round you", fog.reveal(100, 80, 18.0) and fog.is_seen(100, 80) and fog.is_seen(112, 80) and not fog.is_seen(124, 80))
	_check("seeing it again changes nothing", not fog.reveal(100, 80, 18.0))
	_check("the edge of the zone is handled", fog.reveal(0, 0, 18.0) and fog.is_seen(1, 1) and fog.reveal(239, 159, 18.0))
	var seen: float = fog.explored()
	var again := FogMap.new(Vector2(240, 160), 4.0)
	again.from_text(fog.to_text())
	_check("what you saw survives being saved", _near(again.explored(), seen) and again.is_seen(100, 80) and not again.is_seen(124, 80))
	var other := FogMap.new(Vector2(100, 100), 4.0)
	other.from_text(fog.to_text())
	_check("a saved map that does not fit the zone is ignored", other.explored() == 0.0)
	_check("the map image is clear where seen and dark where not", fog.image.get_pixel(25, 20).a < 0.1 and fog.image.get_pixel(50, 20).a > 0.9)


func _test_fire() -> void:
	print("fire (design/05 step 3):")
	await get_tree().process_frame
	var alight: Dictionary = GameData.status("alight")
	var strike: float = float(GameData.balance["player"]["melee_damage"])
	var f := _new_player()
	f.call("set_affinities", ["fire"])
	f.global_position = Vector3(800, 0, 0)
	f.set("effects", [] as Array[TalentEffect])
	f.set("star_pct", [99.0] as Array[float])
	f.call("_recompute_essence_max")
	f.set("essence", 99.0)
	f.set("_facing", Vector3(0, 0, -1))
	var kit: Array = f.get("abilities")
	_check("a fire character starts with Cinder Spit, Kiln Fist and Flashover", kit.size() == 3 and str(kit[0]["id"]) == "cinder_spit" and str(kit[1]["id"]) == "kiln_fist" and str(kit[2]["id"]) == "flashover")

	# ---------- Heat: reflux is the damage bonus
	var a := _foe(f, Vector3(0, 0, -2.0))
	_check("cold, fire does plain damage", _near(float(f.call("heat_mult", "fire")), 1.0))
	(f.get("reflux_by") as Dictionary)["fire"] = 50.0
	_check("at 50 heat, +30%", _near(float(f.call("heat_mult", "fire")), 1.3))
	(f.get("reflux_by") as Dictionary)["fire"] = 80.0
	_check("at 80 heat, +48%", _near(float(f.call("heat_mult", "fire")), 1.48))
	f.call("deal_damage", a, 100.0, ["ability", "fire"])
	_check("a fire hit is multiplied by the heat", _near(_lost(a), 148.0), "lost %f" % _lost(a))
	(a.get("body") as Body).hp = 5000.0
	f.call("deal_damage", a, 100.0, ["melee"])
	_check("a bare strike is not fire and is not", _near(_lost(a), 100.0), "lost %f" % _lost(a))
	_check("water has no heat", _near(float(f.call("heat_mult", "water")), 1.0))
	f.set("in_combat", true)
	(f.get("reflux_by") as Dictionary)["fire"] = 50.0
	f.call("_shed_reflux", 10.0)
	_check("fire reflux sheds at half speed in a fight, so heat stays", _near(float(f.call("reflux_of", "fire")), 45.0))
	f.set("in_combat", false)
	(f.get("reflux_by") as Dictionary)["fire"] = 0.0

	# ---------- Alight: burns, in the caster's name
	(a.get("body") as Body).hp = 5000.0
	_check("alight stacks to five", int(a.call("add_status", "alight", 3, f)) == 3 and int(a.call("add_status", "alight", 9, f)) == 5)
	a.call("clear_status", "alight")
	a.call("add_status", "alight", 2, f)
	for i: int in 10:
		a.call("_tick_statuses", 0.1)                     # one second
	_check("two stacks burn for 16 in a second", _near(_lost(a), 16.0), "lost %f" % _lost(a))
	(f.get("reflux_by") as Dictionary)["fire"] = 50.0
	(a.get("body") as Body).hp = 5000.0
	for i: int in 10:
		a.call("_tick_statuses", 0.1)
	_check("the burn is the caster's fire damage, so heat scales it", _near(_lost(a), 16.0 * 1.3), "lost %f" % _lost(a))
	(f.get("reflux_by") as Dictionary)["fire"] = 0.0
	a.call("add_status", "alight", 1, f)
	for i: int in 60:
		a.call("_tick_statuses", 0.1)
	_check("it burns out after five seconds", not bool(a.call("has_status", "alight")))
	var lifesteal := _new_player("one_percent_lifesteal")
	lifesteal.global_position = Vector3(800, 0, 40)
	var burning := _foe(lifesteal, Vector3(0, 0, -2.0))
	burning.call("add_status", "alight", 5, lifesteal)
	var pts: float = float(lifesteal.get("heal_points_total"))
	for i: int in 10:
		burning.call("_tick_statuses", 0.1)
	_check("damage over time pays a talent that cares about damage dealt", _near(float(lifesteal.get("heal_points_total")) - pts, 40.0 * 0.01), "paid %f" % (float(lifesteal.get("heal_points_total")) - pts))
	burning.queue_free()
	lifesteal.queue_free()

	# ---------- spread
	(a.get("body") as Body).hp = 5000.0
	var close := _foe(f, Vector3(1.6, 0, -2.0))              # radii 0.5 each: 0.6 m apart, inside 1.2
	var apart := _foe(f, Vector3(-5.0, 0, -2.0))
	a.call("add_status", "alight", 3, f)
	for i: int in 9:
		a.call("_tick_statuses", 0.1)
	_check("an enemy standing close does not catch at once", not bool(close.call("has_status", "alight")))
	for i: int in 3:
		a.call("_tick_statuses", 0.1)
	_check("after a full second beside it, one stack jumps across", int(close.call("status_stacks", "alight")) == 1 and int(a.call("status_stacks", "alight")) == 3)
	_check("an enemy standing apart stays unlit", not bool(apart.call("has_status", "alight")))
	close.call("clear_status", "alight")
	(a.get("body") as Body).hp = 1.0
	f.call("deal_damage", a, 50.0, ["test"])
	_check("when a burning enemy dies, one stack jumps to the nearest beside it", int(close.call("status_stacks", "alight")) == 1 and not bool(apart.call("has_status", "alight")))
	await get_tree().process_frame

	# ---------- Cinder Spit
	close.call("clear_status", "alight")
	(close.get("body") as Body).hp = 5000.0
	var ctx: HitContext = f.call("apply_hit", close, (f.call("_payload", GameData.ability("cinder_spit"), "on_hit") as Dictionary), ["ability", "fire"])
	_check("cinder spit: 55 and one Alight", _near(ctx.applied, 55.0) and int(close.call("status_stacks", "alight")) == 1)
	_check("it recovers in half the time of other bolts", float(GameData.ability("cinder_spit")["recovery"]) <= GameData.num("abilities", "cast_recovery") * 0.5)

	# ---------- Kiln Fist: cash in the burn
	var t := _foe(f, Vector3(0, 0, -2.0))
	var beside := _foe(f, Vector3(1.5, 0, -2.0))
	var far := _foe(f, Vector3(8.0, 0, -2.0))
	f.set("hovered", t)
	_rested(f)
	f.call("cast_slot", 1)
	# the blow lands with the heat its own casting just made: heat counts at the moment of impact
	var cast_heat: float = float(GameData.ability("kiln_fist")["cost"]) * float(GameData.ability("kiln_fist")["reflux_per_cost"])
	var hot: float = 1.0 + 0.6 * cast_heat / 100.0
	var plain: float = strike * 3.0 * hot
	_check("kiln fist on an unlit enemy: three strikes' worth (at the heat of the moment), and it lights it twice", _near(_lost(t), plain, 0.05) and int(t.call("status_stacks", "alight")) == 2, "lost %f want %f" % [_lost(t), plain])
	_check("with nothing to spend there is no burst", not bool(beside.call("has_status", "alight")))
	(f.get("reflux_by") as Dictionary)["fire"] = 0.0
	(t.get("body") as Body).hp = 5000.0
	t.call("add_status", "alight", 2, f)                     # now 4
	_rested(f)
	f.call("cast_slot", 1)
	_check("on a burning enemy every stack is spent for +40", _near(_lost(t), plain + 4.0 * 40.0 * hot, 0.05), "lost %f want %f" % [_lost(t), plain + 160.0 * hot])
	_check("and the blow leaves it lit afresh, twice", int(t.call("status_stacks", "alight")) == 2)
	_check("the burst lights whoever stands within 2 m, and no further", int(beside.call("status_stacks", "alight")) == 1 and not bool(far.call("has_status", "alight")))
	t.set("target", f)
	t.set("_windup", 0.3)
	(f.get("reflux_by") as Dictionary)["fire"] = 0.0
	_rested(f)
	f.call("cast_slot", 1)
	_check("fire has an interrupt now: kiln fist breaks a wind-up", float(t.get("_windup")) < 0.0)
	for n: Node in [t, beside, far, close, apart]:
		n.queue_free()
	await get_tree().process_frame

	# ---------- Flashover: a trail, and no passing through
	(f.get("reflux_by") as Dictionary)["fire"] = 0.0
	f.set("essence", 99.0)
	f.set("_winded_t", 0.0)
	f.global_position = Vector3(800, 0, 0)
	f.set("_facing", Vector3(0, 0, -1))
	var start: Vector3 = f.global_position
	_rested(f)
	f.call("cast_slot", 2)
	for i: int in 30:
		f.call("_physics_process", 1.0 / 60.0)
	var gone: float = start.z - f.global_position.z
	_check("flashover carries you exactly 4.2 m", _near(gone, 30.0 * 0.14, 0.02), "moved %f" % gone)
	var zone: GroundZone = null
	for n: Node in get_tree().get_nodes_in_group("ground_zones"):
		zone = n as GroundZone
	_check("and leaves a strip of flame from where you started to where you stopped", zone != null and zone.from.distance_to(start) < 0.1 and zone.to.distance_to(f.global_position) < 0.6
		and _near(zone.width, 1.0) and zone.life > 2.0)
	if zone != null:
		var in_it := _foe(f, Vector3(0.3, 0, 0))
		in_it.global_position = (zone.from + zone.to) * 0.5 + Vector3(0.3, 0, 0)
		var out_of_it := _foe(f, Vector3(0, 0, 0))
		out_of_it.global_position = (zone.from + zone.to) * 0.5 + Vector3(4.0, 0, 0)
		zone.tick(0.01)
		_check("anything standing in the flame catches; anything beside it does not", int(in_it.call("status_stacks", "alight")) == 1 and not bool(out_of_it.call("has_status", "alight")))
		zone.tick(0.5)
		_check("once a second, not every frame", int(in_it.call("status_stacks", "alight")) == 1)
		zone.tick(0.6)
		_check("and again the next second", int(in_it.call("status_stacks", "alight")) == 2)
		zone.tick(5.0)
		_check("the flame dies after three seconds", zone.is_queued_for_deletion())
		in_it.queue_free()
		out_of_it.queue_free()
	await get_tree().process_frame
	# it stops at a body instead of going through
	f.set("essence", 99.0)
	f.set("_winded_t", 0.0)
	f.global_position = Vector3(800, 0, 0)
	f.set("_facing", Vector3(0, 0, -1))
	var blocker := _foe(f, Vector3(0, 0, -1.6))
	_rested(f)
	f.call("cast_slot", 2)
	for i: int in 30:
		f.call("_physics_process", 1.0 / 60.0)
	_check("flashover does not carry you through an enemy", f.global_position.z > blocker.global_position.z, "player z %f blocker z %f" % [f.global_position.z, blocker.global_position.z])
	blocker.queue_free()
	for n: Node in get_tree().get_nodes_in_group("ground_zones"):
		n.queue_free()
	_check("none of it hurts the caster", (f.get("body") as Body).wounds.is_empty() and _near((f.get("body") as Body).missing(), 0.0))
	f.queue_free()
	await get_tree().process_frame


## Move a player by hand and let Slipstream see it, as a step of walking would.
func _walk(p: Node3D, metres: Vector3, steps: int = 1) -> void:
	for i: int in steps:
		p.global_position += metres / float(steps)
		p.call("_tick_slipstream", 1.0 / 60.0)


func _test_wind() -> void:
	print("wind (design/05 step 3):")
	await get_tree().process_frame
	var cfg: Dictionary = GameData.balance["slipstream"]
	var combat: Dictionary = GameData.balance["combat"]
	var strike: float = float(GameData.balance["player"]["melee_damage"])
	var w := _new_player()
	w.call("set_affinities", ["wind"])
	w.global_position = Vector3(900, 0, 0)
	var world := _test_floor(w.global_position, w.global_position.z - 9.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	w.set("effects", [] as Array[TalentEffect])
	w.set("star_pct", [99.0] as Array[float])
	w.call("_recompute_essence_max")
	w.set("essence", 99.0)
	w.set("_facing", Vector3(0, 0, -1))
	w.set("_last_pos", w.global_position)
	var kit: Array = w.get("abilities")
	_check("a wind character starts with Cutting Gust, Crosscut and Tailwind", kit.size() == 3 and str(kit[0]["id"]) == "cutting_gust" and str(kit[1]["id"]) == "crosscut" and str(kit[2]["id"]) == "tailwind")

	# ---------- Slipstream
	_check("wind runs on Slipstream; water does not", bool(w.call("has_slipstream")))
	_walk(w, Vector3(1.4, 0, 0), 4)
	_check("no pip until a metre and a half is covered", int(w.get("pips")) == 0)
	_walk(w, Vector3(0.2, 0, 0))
	_check("then one", int(w.get("pips")) == 1)
	_walk(w, Vector3(30.0, 0, 0), 40)
	_check("and never more than ten", int(w.get("pips")) == int(cfg["max"]) and int(cfg["max"]) == 10)
	for i: int in 29:
		w.call("_tick_slipstream", 1.0 / 60.0)             # just under half a second standing
	_check("a moment's pause costs nothing", int(w.get("pips")) == 10)
	for i: int in 32:
		w.call("_tick_slipstream", 1.0 / 60.0)             # past the delay and one decay step
	_check("stand to think and they drain, one every half second", int(w.get("pips")) == 9)
	for i: int in 60:
		w.call("_tick_slipstream", 1.0 / 60.0)
	_check("and keep draining", int(w.get("pips")) == 7)
	_walk(w, Vector3(0.1, 0, 0))
	for i: int in 20:
		w.call("_tick_slipstream", 1.0 / 60.0)
	_check("moving again stops the drain at once", int(w.get("pips")) == 7)
	_check("spending takes what is there and no more", int(w.call("spend_pips", 3)) == 3 and int(w.get("pips")) == 4 and int(w.call("spend_pips", 9)) == 4 and int(w.get("pips")) == 0)
	w.global_position += Vector3(900, 0, 0)
	w.call("_tick_slipstream", 1.0 / 60.0)
	_check("being put somewhere new is not travelling", int(w.get("pips")) == 0)
	w.global_position = Vector3(900, 0, 0)
	w.set("_last_pos", w.global_position)
	var plain := _new_player()
	plain.set("_last_pos", plain.global_position)
	_walk(plain, Vector3(20, 0, 0), 20)
	_check("a character without wind earns none", int(plain.get("pips")) == 0 and not bool(plain.call("has_slipstream")))
	plain.queue_free()

	# ---------- wind's reflux: sheds on the move, sits when you stand
	w.set("in_combat", true)
	(w.get("reflux_by") as Dictionary)["wind"] = 50.0
	w.set("_moving", false)
	w.call("_shed_reflux", 5.0)
	_check("in a fight, standing still, wind reflux does not shed", _near(float(w.call("reflux_of", "wind")), 50.0))
	w.set("_moving", true)
	w.call("_shed_reflux", 5.0)
	_check("moving, it sheds three times as fast", _near(float(w.call("reflux_of", "wind")), 35.0))
	w.set("in_combat", false)
	w.set("_moving", false)
	w.call("_shed_reflux", 5.0)
	_check("out of a fight it sheds as any other", _near(float(w.call("reflux_of", "wind")), 30.0))
	(w.get("reflux_by") as Dictionary)["wind"] = 0.0

	# ---------- Cutting Gust: through everything, and it wants pips
	var g1 := _foe(w, Vector3(0, 0, -3.0))
	var g2 := _foe(w, Vector3(0.2, 0, -5.0))
	var g3 := _foe(w, Vector3(0, 0, -7.5))
	var off := _foe(w, Vector3(4.0, 0, -4.0))
	w.set("pips", 0)
	w.call("cast_slot", 0)
	var gust: Node = null
	for n: Node in w.get_parent().get_children():
		if n.get("shooter") == w and not n.is_queued_for_deletion():
			gust = n
	for i: int in 40:
		if gust == null or not is_instance_valid(gust) or gust.is_queued_for_deletion():
			break
		gust.call("tick", 1.0 / 60.0)
	_check("cutting gust passes through every enemy in its line", _near(_lost(g1), 45.0) and _near(_lost(g2), 45.0) and _near(_lost(g3), 45.0), "g1 %f g2 %f g3 %f" % [_lost(g1), _lost(g2), _lost(g3)])
	_check("and touches nothing off the line, and no one twice", _near(_lost(off), 0.0))
	await get_tree().process_frame
	for g: Node in [g1, g2, g3]:
		(g.get("body") as Body).hp = 5000.0
	w.set("pips", 5)
	_rested(w)
	w.call("cast_slot", 0)
	_check("it spends up to three pips", int(w.get("pips")) == 2)
	gust = null
	for n: Node in w.get_parent().get_children():
		if n.get("shooter") == w and not n.is_queued_for_deletion():
			gust = n
	for i: int in 40:
		if gust == null or not is_instance_valid(gust) or gust.is_queued_for_deletion():
			break
		gust.call("tick", 1.0 / 60.0)
	_check("for +15 each", _near(_lost(g1), 90.0), "lost %f" % _lost(g1))
	_check("it is short: 12 m, and the wall beyond stops nothing it would reach", _near(float(GameData.ability("cutting_gust")["speed"]) * float(GameData.ability("cutting_gust")["life"]), 12.0))
	await get_tree().process_frame

	# a shot stops on a wall (any shot: the same code flies them all)
	var behind_wall := _foe(w, Vector3(0, 0, -11.0))           # the wall is at -9
	w.set("pips", 0)
	_rested(w)
	w.call("cast_slot", 0)
	gust = null
	for n: Node in w.get_parent().get_children():
		if n.get("shooter") == w and not n.is_queued_for_deletion():
			gust = n
	for i: int in 60:
		if gust == null or not is_instance_valid(gust) or gust.is_queued_for_deletion():
			break
		gust.call("tick", 1.0 / 60.0)
	_check("a shot does not pass through a wall", _near(_lost(behind_wall), 0.0))
	behind_wall.queue_free()
	for g: Node in [g1, g2, g3, off]:
		g.queue_free()
	await get_tree().process_frame

	# ---------- Tailwind
	w.set("essence", 99.0)
	w.set("_winded_t", 0.0)
	w.set("pips", 0)
	w.global_position = Vector3(900, 0, 0)
	w.set("_last_pos", w.global_position)
	w.set("_facing", Vector3(1, 0, 0))
	var start: Vector3 = w.global_position
	_rested(w)
	w.call("cast_slot", 2)
	_check("tailwind gives three pips at once", int(w.get("pips")) == 3)
	_check("and has no recovery beyond the dash itself", _near(float(w.get("_recover_t")), float(GameData.ability("tailwind")["dash_time"])))
	for i: int in 30:
		w.call("_physics_process", 1.0 / 60.0)
	var went: float = w.global_position.x - start.x
	_check("it is the longest dash: 6.6 m", _near(went, 30.0 * 0.22, 0.02), "moved %f" % went)
	_check("and the distance it covers earns pips of its own", int(w.get("pips")) >= 3 + 4, "pips %d" % int(w.get("pips")))

	# ---------- Crosscut
	w.global_position = Vector3(900, 0, 0)
	w.set("_last_pos", w.global_position)
	w.set("_facing", Vector3(0, 0, -1))
	w.set("essence", 99.0)
	(w.get("reflux_by") as Dictionary)["wind"] = 0.0
	var c := _foe(w, Vector3(0, 0, -4.0))
	c.set("facing", Vector3(0, 0, 1))                          # looking straight at the player
	w.set("hovered", c)
	w.set("pips", 0)
	_rested(w)
	w.call("cast_slot", 1)
	var lee: float = 1.0 + float(GameData.affinity("wind")["rear_bonus"])
	var base_cut: float = strike * 1.6 * float(combat["rear_mult"]) * lee
	_check("crosscut always lands on the back, Lee and all, though they were facing you", _near(_lost(c), base_cut, 0.05), "lost %f want %f" % [_lost(c), base_cut])
	_check("and you end up 2 m behind them", _near(w.global_position.z, c.global_position.z - 2.0 - float(c.get("radius")), 0.05), "player z %f" % w.global_position.z)
	_check("it has a recovery of a quarter second", _near(float(w.get("_recover_t")), 0.25))
	(c.get("body") as Body).hp = 5000.0
	w.global_position = Vector3(900, 0, 0)
	w.set("_facing", Vector3(0, 0, -1))
	w.set("pips", 6)
	_rested(w)
	w.call("cast_slot", 1)
	_check("it spends every pip for +10% each", int(w.get("pips")) == 0 and _near(_lost(c), base_cut * 1.6, 0.05), "pips %d lost %f want %f" % [int(w.get("pips")), _lost(c), base_cut * 1.6])
	var out_of_reach := _foe(w, Vector3(0, 0, 0))
	out_of_reach.global_position = w.global_position + Vector3(9.0, 0, 0)
	w.set("hovered", out_of_reach)
	var ess: float = float(w.get("essence"))
	_rested(w)
	w.call("cast_slot", 1)
	_check("beyond 7 m it does not fire and costs nothing", _near(float(w.get("essence")), ess))
	# a wall behind the target: you strike but stay on your side
	(c.get("body") as Body).hp = 5000.0
	c.global_position = Vector3(900, 0, -7.6)                  # wall face at -8.5: no room to stand behind it
	w.global_position = Vector3(900, 0, -3.0)
	w.set("_facing", Vector3(0, 0, -1))
	w.set("hovered", c)
	w.set("pips", 0)
	_rested(w)
	w.call("cast_slot", 1)
	_check("with a wall behind them you still strike, but do not pass into it", _lost(c) > 0.0 and _near(w.global_position.z, -3.0, 0.01), "player z %f" % w.global_position.z)

	# a plain rear hit from a non-wind source gets the ordinary bonus only
	(c.get("body") as Body).hp = 5000.0
	c.set("facing", Vector3(0, 0, -1))
	w.call("deal_damage", c, 100.0, ["test"])
	_check("Lee is wind's alone: another hit on a back gets only the ordinary bonus", _near(_lost(c), 100.0 * float(combat["rear_mult"])), "lost %f" % _lost(c))

	# ---------- Aloft
	(c.get("body") as Body).hp = 5000.0
	_check("a light enemy is thrown aloft", int(c.call("add_status", "aloft")) == 1 and bool(c.call("has_status", "aloft")))
	c.set("facing", Vector3(0, 0, 1))
	w.global_position = c.global_position + Vector3(0, 0, 3.0)
	w.call("deal_damage", c, 100.0, ["test"])
	_check("and takes a quarter more while it is up", _near(_lost(c), 125.0), "lost %f" % _lost(c))
	var heavy := _fighter(w, Vector3(3.0, 0, 0), "brute")
	heavy.set("target", null)
	var poise0: float = float(heavy.get("poise"))
	_check("a heavy one does not leave the ground - it loses 50 poise instead", int(heavy.call("add_status", "aloft")) == 0 and not bool(heavy.call("has_status", "aloft"))
		and _near(poise0 - float(heavy.get("poise")), 50.0))
	for n: Node in [c, out_of_reach, heavy]:
		n.queue_free()
	_check("none of it hurts the caster", (w.get("body") as Body).wounds.is_empty() and _near((w.get("body") as Body).missing(), 0.0))
	w.queue_free()
	world.queue_free()
	await get_tree().process_frame


func _facing_foe(p: Node3D, offset: Vector3, kind: String = "grunt") -> CharacterBody3D:
	var e := _foe(p, offset, kind)
	var to: Vector3 = p.global_position - e.global_position
	to.y = 0.0
	e.set("facing", to.normalized())
	return e


## The newest shot `p` has in the air, or null.
func _bolt_of(p: Node) -> Node3D:
	var found: Node3D = null
	for n: Node in p.get_parent().get_children():
		if n.get("shooter") == p and n.has_method("tick") and not n.is_queued_for_deletion():
			found = n
	return found


## Fly a shot by hand until it is spent.
func _fly(shot: Node, seconds: float = 3.0) -> void:
	var t := 0.0
	while t < seconds and is_instance_valid(shot) and not shot.is_queued_for_deletion():
		shot.call("tick", 1.0 / 60.0)
		t += 1.0 / 60.0


func _test_earth() -> void:
	print("earth (design/05 step 3):")
	await get_tree().process_frame
	var cfg: Dictionary = GameData.balance["stone"]
	var shr: Dictionary = cfg["shrapnel"]
	var e := _new_player()
	e.call("set_affinities", ["earth"])
	e.global_position = Vector3(1300, 0, 0)
	var world := _test_floor(e.global_position)
	await get_tree().physics_frame
	await get_tree().physics_frame
	e.set("effects", [] as Array[TalentEffect])
	_bare(e)
	e.set("star_pct", [99.0] as Array[float])
	e.call("_recompute_essence_max")
	e.set("_facing", Vector3(0, 0, -1))
	var here: Vector3 = e.global_position
	var body: Body = e.get("body")
	var strike: float = float(e.call("strike_damage"))
	var fresh := func() -> void:
		_rested(e)
		e.set("essence", 99.0)
		e.call("clear_reflux")
		e.set("_windup", {})
		e.set("_windup_t", 0.0)
		e.set("_stagger_t", 0.0)
		e.set("poise", 100.0)
		e.set("_facing", Vector3(0, 0, -1))
	fresh.call()
	var kit: Array = e.get("abilities")
	_check("an earth character starts with Slingstone, Landslide Blow and Raise Slab", kit.size() == 3 and str(kit[0]["id"]) == "slingstone" and str(kit[1]["id"]) == "landslide_blow" and str(kit[2]["id"]) == "raise_slab")
	var other := _new_player()
	_check("earth raises stone; a water character does not", bool(e.call("has_stone")) and not bool(other.call("has_stone")))
	other.free()

	# ---------- wind-up and Braced
	var far := _facing_foe(e, Vector3(0, 0, -6.0))
	e.call("cast_ability", 0)
	_check("Slingstone is paid for at once", _near(99.0 - float(e.get("essence")), 12.0), "spent %f" % (99.0 - float(e.get("essence"))))
	_check("but nothing leaves your hand yet: a 0.3 s wind-up", _near(float(e.get("_windup_t")), 0.3) and _bolt_of(e) == null and _near(_lost(far), 0.0))
	_check("you are Braced through it", bool(e.call("is_braced")) and _near(float(e.call("windup_frac")), 0.0))
	var hp0: float = body.hp
	for i: int in 3:
		e.call("take_hit", 10.0, true, null)
	_check("Braced: every blow does 40% less", _near(hp0 - body.hp, 18.0), "lost %f" % (hp0 - body.hp))
	_check("and heavy blows do not stagger you", not bool(e.call("is_staggered")) and _near(float(e.get("poise")), 100.0))
	var ess: float = float(e.get("essence"))
	e.call("cast_ability", 2)
	_check("you cannot start anything else while you are set", _near(float(e.get("essence")), ess) and (e.get("stones") as Array).is_empty())
	e.call("_tick_windup", 0.2)
	_check("two thirds through, still holding", bool(e.call("is_braced")) and _bolt_of(e) == null and _near(float(e.call("windup_frac")), 0.667, 0.01))
	e.call("_tick_windup", 0.11)
	var bolt: Node3D = _bolt_of(e)
	_check("when the wind-up ends the stone flies, and you are no longer Braced", bolt != null and not bool(e.call("is_braced")) and float(e.call("windup_frac")) < 0.0)
	_check("it is the slowest bolt there is: 14 m/s, 24 m", bolt != null and _near(float(bolt.get("speed")), 14.0) and _near(float(bolt.get("speed")) * float(bolt.get("life")), 24.0, 0.05))
	_fly(bolt)
	_check("and the heaviest: 120", _near(_lost(far), 120.0), "lost %f" % _lost(far))
	hp0 = body.hp
	e.call("take_hit", 10.0, false, null)
	_check("out of the wind-up a blow lands in full", _near(hp0 - body.hp, 10.0))
	far.free()

	fresh.call()
	e.set("_windup", {"braced": false, "release": false, "facing": Vector3(0, 0, -1)})
	e.set("_windup_t", 0.5)
	e.call("take_hit", 1.0, true, null)
	_check("a wind-up that is not Braced is lost to a stagger", bool(e.call("is_staggered")) and _near(float(e.get("_windup_t")), 0.0))

	# Slingstone: poise and the interrupt
	fresh.call()
	var br := _fighter(e, Vector3(0, 0, -5.0), "brute")
	br.set("facing", Vector3(0, 0, 1))
	e.call("cast_ability", 0)
	e.call("_tick_windup", 0.31)
	_fly(_bolt_of(e))
	_check("Slingstone takes 45 poise", _near(float(br.get("poise_max")) - float(br.get("poise")), 45.0), "poise %f" % float(br.get("poise")))
	br.free()
	fresh.call()
	var slam := _fighter(e, Vector3(0, 0, -5.0), "brute")
	slam.set("facing", Vector3(0, 0, 1))
	slam.set("_windup", 0.5)
	e.call("cast_ability", 0)
	e.call("_tick_windup", 0.31)
	_fly(_bolt_of(e))
	_check("and is the only starter bolt that interrupts", float(slam.get("_windup")) < 0.0)
	slam.free()

	# ---------- standing stone
	fresh.call()
	var slab_ab: Dictionary = e.call("ability_stats", kit[2])
	var stood := _facing_foe(e, Vector3(0.4, 0, -4.1))
	var apart := _facing_foe(e, Vector3(2.6, 0, -4.0))
	var s: Node3D = e.call("raise_stone", here + Vector3(0, 0, -4.0), Vector3(0, 0, -1), slab_ab)
	_check("a slab is 3 m across and 0.6 m thick", (s.get("size") as Vector3).is_equal_approx(Vector3(3.0, 1.8, 0.6)))
	s.call("tick", 0.2)
	await get_tree().physics_frame
	_check("while it rises it is not yet in the way", not bool(s.call("is_up")) and (e.call("_ray", here + Vector3.UP, here + Vector3(0, 1, -8)) as Dictionary).is_empty() and _near(_lost(stood), 0.0))
	s.call("tick", 0.16)
	_check("up in 0.35 s: whoever stood there takes 20", _near(_lost(stood), 20.0), "lost %f" % _lost(stood))
	_settle(stood)
	_check("and is pushed a metre off it, away from you", _near(stood.global_position.z, here.z - 5.1, 0.05), "z %f" % (stood.global_position.z - here.z))
	_check("someone standing past its end is left alone", _near(_lost(apart), 0.0))
	s.call("tick", 0.1)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var hit: Dictionary = e.call("_ray", here + Vector3.UP, here + Vector3(0, 1, -8))
	_check("then it is solid", bool(s.call("is_up")) and not hit.is_empty() and hit.get("collider") == s)
	_check("and counts as one of your stones", int(e.call("stone_count")) == 1)

	# it blocks shots: yours ...
	var ProjScript: GDScript = load("res://scripts/projectile.gd")
	var plain: Node3D = ProjScript.new()
	plain.set("dir", Vector3(0, 0, -1))
	plain.set("speed", 20.0)
	plain.set("life", 1.0)
	plain.set("damage", 50.0)
	plain.set("shooter", e)
	add_child(plain)
	plain.global_position = here + Vector3.UP
	var before: float = _lost(stood)
	_fly(plain)
	_check("your own shots stop on it", _near(_lost(stood), before) and _near(float(s.get("hp")), 150.0))
	# ... and theirs, which wear it down
	var ShotScript: GDScript = load("res://scripts/enemy_shot.gd")
	var arrow: Node3D = ShotScript.new()
	arrow.set("dir", Vector3(0, 0, 1))
	arrow.set("damage", 18.0)
	arrow.set("target", e)
	add_child(arrow)
	arrow.global_position = here + Vector3(0, 1, -9)
	hp0 = body.hp
	_fly(arrow)
	_check("an enemy's shot stops on it too, and wears it down", _near(body.hp, hp0) and _near(float(s.get("hp")), 150.0 - 18.0), "stone %f" % float(s.get("hp")))

	# enemies go round it, and cannot swing through it
	var walker := _fighter(e, Vector3(0.4, 0, -7.0))
	var way: Vector3 = walker.call("_route_dir", Vector3(0, 0, 1))
	_check("an enemy with the slab between you heads for the end of it", absf(way.x) > 0.5, str(way))
	_check("the nearer end", way.x > 0.0)
	walker.global_position = here + Vector3(3.5, 0, -7.0)
	way = walker.call("_route_dir", Vector3(0, 0, 1))
	_check("one already past the end just comes", way.is_equal_approx(Vector3(0, 0, 1)), str(way))
	walker.free()
	stood.free()
	apart.free()

	s.call("tick", 11.5)
	_check("it has not gone before its 12 s are up", not s.is_queued_for_deletion())
	s.call("tick", 0.5)                                          # the 12 s run from when it finished rising
	_check("and then it crumbles", s.is_queued_for_deletion() and int(e.call("stone_count")) == 0)

	# three at a time
	var made: Array = []
	for i: int in 4:
		made.append(e.call("raise_stone", here + Vector3(20.0 + 4.0 * float(i), 0, 0), Vector3(0, 0, -1), slab_ab))
	_check("three at a time: a fourth crumbles the oldest", int(e.call("stone_count")) == int(cfg["max_count"]) and int(cfg["max_count"]) == 3
		and (made[0] as Node).is_queued_for_deletion() and not (made[1] as Node).is_queued_for_deletion())
	e.call("drop_stones")
	_check("none of it follows you to a new place", int(e.call("stone_count")) == 0 and (made[3] as Node).is_queued_for_deletion())

	# a swing does not reach through stone
	var close: Node3D = e.call("raise_stone", here + Vector3(0, 0, -1.5), Vector3(0, 0, -1), slab_ab)
	close.call("tick", 0.5)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var swinger := _fighter(e, Vector3(0, 0, -2.4))
	swinger.set("facing", Vector3(0, 0, 1))
	hp0 = body.hp
	swinger.call("_land_melee", 2.4)
	_check("an enemy's swing does not land through your stone", _near(body.hp, hp0))
	close.call("crumble")
	await get_tree().physics_frame
	await get_tree().physics_frame
	swinger.call("_land_melee", 2.4)
	_check("with the stone gone the same swing lands", body.hp < hp0)
	swinger.free()

	# ---------- shatter
	fresh.call()
	var s2: Node3D = e.call("raise_stone", here + Vector3(0, 0, -3.0), Vector3(0, 0, -1), slab_ab)
	s2.call("tick", 0.5)
	var inside := _facing_foe(e, Vector3(0.8, 0, -5.0))          # 2 m beyond, in front of the slab
	var edge := _facing_foe(e, Vector3(2.2, 0, -5.0))            # just past its end, inside the fan
	var wide := _facing_foe(e, Vector3(4.5, 0, -4.0))            # well off to the side
	var beyond := _facing_foe(e, Vector3(0, 0, -8.2))            # more than 4 m past it
	var mine := _facing_foe(e, Vector3(-1.0, 0, -1.8))           # on your side of it
	var heavy := _fighter(e, Vector3(-0.8, 0, -5.0), "brute")
	heavy.set("facing", Vector3(0, 0, 1))
	var n: int = s2.call("shatter", Vector3(0, 0, -1))
	_check("shatter: shrapnel hits what is beyond the slab, within 4 m", n == 3 and _near(_lost(inside), float(shr["damage"])) and _near(float(shr["damage"]), 80.0), "hit %d, lost %f" % [n, _lost(inside)])
	_check("it fans out a little past the ends", _near(_lost(edge), 80.0))
	_check("but not sideways, not past its range, and never back at you", _near(_lost(wide), 0.0) and _near(_lost(beyond), 0.0) and _near(_lost(mine), 0.0))
	_check("shrapnel takes 40 poise", _near(float(heavy.get("poise_max")) - float(heavy.get("poise")), 40.0))
	_check("and the stone is spent", s2.is_queued_for_deletion() and int(e.call("stone_count")) == 0)
	for node: Node in [inside, edge, wide, beyond, mine, heavy]:
		node.free()

	# Slingstone into your own stone
	fresh.call()
	var s3: Node3D = e.call("raise_stone", here + Vector3(0, 0, -4.0), Vector3(0, 0, -1), slab_ab)
	s3.call("tick", 0.5)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var behind := _facing_foe(e, Vector3(0, 0, -6.0))
	e.call("cast_ability", 0)
	e.call("_tick_windup", 0.31)
	_fly(_bolt_of(e))
	_check("Slingstone thrown into your own stone shatters it over whoever is behind", s3.is_queued_for_deletion() and _near(_lost(behind), 80.0), "lost %f" % _lost(behind))
	behind.free()

	# ---------- Landslide Blow
	fresh.call()
	var front := _facing_foe(e, Vector3(0, 0, -3.6))
	var off := _facing_foe(e, Vector3(3.0, 0, -2.0))             # 56 degrees off: outside a 60-degree arc
	var gr := _fighter(e, Vector3(-0.6, 0, -3.0))
	gr.set("facing", Vector3(0, 0, 1))
	var big := _fighter(e, Vector3(0.9, 0, -3.2), "brute")
	big.set("facing", Vector3(0, 0, 1))
	var big_hp: float = (big.get("body") as Body).hp
	e.call("cast_ability", 1)
	_check("Landslide Blow winds up for 0.6 s, Braced", _near(float(e.get("_windup_t")), 0.6) and bool(e.call("is_braced")) and _near(_lost(front), 0.0))
	e.set("cursor_fixed", here + Vector3(5, 0, 0))               # looking away does not move it: you committed
	e.call("_tick_windup", 0.61)
	e.set("cursor_fixed", null)
	_check("then 3.2x a strike on what is in front, out to 3.5 m", _near(_lost(front), strike * 3.2, 0.05), "lost %f want %f" % [_lost(front), strike * 3.2])
	_check("a narrow blow: 30 degrees either side", _near(_lost(off), 0.0))
	_check("it staggers a skirmisher outright", bool(gr.call("has_status", "staggered")))
	_check("and takes 80 poise from a brute without moving it", _near(float(big.get("poise")), float(big.get("poise_max")) - 80.0) and not bool(big.call("is_shoved"))
		and (big.get("body") as Body).hp < big_hp)
	for node: Node in [front, off, gr, big]:
		node.free()

	fresh.call()
	var s5: Node3D = e.call("raise_stone", here + Vector3(0, 0, -2.5), Vector3(0, 0, -1), slab_ab)
	s5.call("tick", 0.5)
	var past := _facing_foe(e, Vector3(0, 0, -5.0))              # out of the blow's reach, inside the shrapnel's
	e.call("cast_ability", 1)
	e.call("_tick_windup", 0.61)
	_check("Landslide Blow shatters your stone in its arc: the wall becomes the weapon", s5.is_queued_for_deletion() and _near(_lost(past), 80.0), "lost %f" % _lost(past))
	past.free()

	# ---------- Raise Slab from the key
	fresh.call()
	e.set("cursor_fixed", here + Vector3(0, 0, -5.0))
	e.call("cast_ability", 2)
	var up: Node3D = (e.get("stones") as Array).back() if not (e.get("stones") as Array).is_empty() else null
	_check("Raise Slab comes up where you point", up != null and _near(up.global_position.z, here.z - 5.0, 0.05) and _near(up.global_position.x, here.x, 0.05))
	_check("it is cheap, and you are Braced while it rises", _near(99.0 - float(e.get("essence")), 6.0) and bool(e.call("is_braced")) and _near(float(e.get("_windup_t")), 0.35))
	e.call("_tick_windup", 0.36)
	_check("nothing more happens when that wind-up ends", int(e.call("stone_count")) == 1 and _bolt_of(e) == null)
	fresh.call()
	e.set("cursor_fixed", here + Vector3(0, 0, -0.7))
	e.call("cast_ability", 2)
	up = (e.get("stones") as Array).back()
	_check("point at your feet and it still rises a step away", _near(up.global_position.z, here.z - 1.5, 0.05))
	fresh.call()
	e.set("cursor_fixed", here + Vector3(-30.0, 0, 0))
	e.call("cast_ability", 2)
	up = (e.get("stones") as Array).back()
	_check("and never more than 8 m off", _near(up.global_position.x, here.x - 8.0, 0.05))
	_check("it lies across the way you aimed", absf((up.global_transform.basis.x).z) > 0.99)
	e.call("drop_stones")
	var world2 := _test_floor(here, here.z - 3.0)                # a wall: its face is 2.5 m off
	await get_tree().physics_frame
	await get_tree().physics_frame
	fresh.call()
	e.set("cursor_fixed", here + Vector3(0, 0, -6.0))
	e.call("cast_ability", 2)
	up = (e.get("stones") as Array).back() if not (e.get("stones") as Array).is_empty() else null
	_check("with a wall in the way it rises short of the wall", up != null and _near(up.global_position.z, here.z - 1.9, 0.05))
	e.call("drop_stones")
	e.set("cursor_fixed", null)
	world2.free()

	# the same thing through the game's own frame loop, not by hand
	fresh.call()
	var stood_at: Vector3 = e.global_position
	e.call("cast_ability", 0)
	for i: int in 12:
		e.call("_physics_process", 1.0 / 60.0)
	var early: bool = _bolt_of(e) != null
	for i: int in 12:
		e.call("_physics_process", 1.0 / 60.0)
	var loosed: Node3D = _bolt_of(e)
	_check("in the running game the wind-up counts itself down: nothing at 0.2 s, loosed by 0.4 s", not early and loosed != null and float(e.get("_windup_t")) <= 0.0)
	_check("and you did not move a step while it did", e.global_position.distance_to(stood_at) < 0.01)
	if loosed != null:
		loosed.free()

	# ---------- reflux
	fresh.call()
	(e.get("reflux_by") as Dictionary)["earth"] = 40.0
	(e.get("reflux_by") as Dictionary)["water"] = 40.0
	e.set("in_combat", false)
	e.call("_shed_reflux", 10.0)
	var lost_earth: float = 40.0 - float(e.call("reflux_of", "earth"))
	var lost_water: float = 40.0 - float(e.call("reflux_of", "water"))
	_check("earth keeps its reflux: it sheds at half the rate", lost_earth > 0.0 and _near(lost_water, lost_earth * 2.0), "%f against %f" % [lost_earth, lost_water])
	_check("and makes little: under half an essence's worth each", float(GameData.ability("slingstone")["reflux_per_cost"]) <= 0.4 and float(GameData.ability("landslide_blow")["reflux_per_cost"]) <= 0.4)
	e.free()
	world.free()


## A solid block for a test world.
func _block(parent: Node, at: Vector3, size: Vector3) -> void:
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	sb.add_child(col)
	sb.position = at
	parent.add_child(sb)


func _test_archer_steering() -> void:
	print("archer steering (Brent 2026-10-12):")
	await get_tree().process_frame
	var p := _new_player()
	p.global_position = Vector3(1500, 0, 0)
	var here: Vector3 = p.global_position
	var world := _test_floor(here)
	_block(world, here + Vector3(0, 1, -5.0), Vector3(4, 2, 1))          # cover between the two of them
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ar := _fighter(p, Vector3(0, 0, -10.0), "archer")
	ar.set("facing", Vector3(0, 0, 1))
	_check("with cover in the way the archer cannot see you", not bool(ar.call("_sees_target")))
	var spot: Variant = ar.call("_find_vantage")
	_check("it picks somewhere it can walk to and shoot from", spot != null and absf((spot as Vector3).x - here.x) > 1.5, str(spot))
	var start: Vector3 = ar.global_position
	var aimed := false
	var t := 0.0
	while t < 5.0 and not aimed:
		ar.call("_physics_process", 1.0 / 60.0)
		t += 1.0 / 60.0
		aimed = float(ar.get("_windup")) >= 0.0
	_check("and goes round the cover instead of walking into it", aimed and bool(ar.call("_sees_target")) and ar.global_position.distance_to(start) > 1.0,
		"after %.1f s at %s" % [t, str(ar.global_position - here)])
	_check("without coming in close to do it", ar.global_position.distance_to(here) > 6.0)
	ar.free()
	world.free()

	# its back to a wall
	p.global_position = Vector3(1500, 0, 100)
	here = p.global_position
	world = _test_floor(here, here.z - 6.0)                              # wall face 5.5 m off
	await get_tree().physics_frame
	await get_tree().physics_frame
	p.global_position = here + Vector3(0, 0, -2.0)
	ar = _fighter(p, Vector3(0, 0, -2.6), "archer")                      # 0.9 m of room behind it
	ar.set("facing", Vector3(0, 0, 1))
	_run(ar, 2.5)
	var gap: float = ar.global_position.distance_to(p.global_position)
	_check("backed against a wall it slips along it instead of pressing into it", gap >= 4.0 or absf(ar.global_position.x - here.x) > 2.0,
		"%.1f m from you, %.1f m along the wall" % [gap, absf(ar.global_position.x - here.x)])
	ar.free()
	# boxed in on every side
	ar = _fighter(p, Vector3(0, 0, -2.6), "archer")
	ar.set("facing", Vector3(0, 0, 1))
	_block(world, ar.global_position + Vector3(-1.8, 1, 0), Vector3(1, 2, 4))
	_block(world, ar.global_position + Vector3(1.8, 1, 0), Vector3(1, 2, 4))
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check("boxed in, there is no way to back off", (ar.call("_retreat_dir", Vector3(0, 0, 1)) as Vector3) == Vector3.ZERO)
	ar.set("_attack_cd", 0.0)
	ar.set("_windup", -1.0)
	var held: Vector3 = ar.global_position
	_run(ar, 0.2)
	_check("so it stands and shoots rather than walk into the wall", float(ar.get("_windup")) >= 0.0 and ar.global_position.distance_to(held) < 0.1)
	ar.free()
	world.free()
	p.free()


func _test_gear_step_1() -> void:
	print("a coat and a sling (design/06 step 1):")
	await get_tree().process_frame
	var cfg: Dictionary = GameData.balance["ranged"]
	var p := _new_player()
	var inv: Inventory = p.get("inventory")
	var b: Body = p.get("body")
	_check("there are slots for a ranged weapon and for the body", Inventory.SLOTS.has("ranged") and Inventory.SLOTS.has("body"))
	_check("a new character wears a coat and carries a sling", str(inv.equipped.get("body", "")) == "patched_coat" and str(inv.equipped.get("ranged", "")) == "cord_sling")
	for id: String in ["patched_coat", "cord_sling", "padded_jack", "husk_hide_jack"]:
		if GameData.item(id).is_empty():
			_check("the four items of this step exist", false, id)
	_check("the merchant sells the padded jack and brutes can drop the hide jack", (GameData.items_file["shop"] as Array).has("padded_jack")
		and (GameData.enemy("brute")["loot"] as Array).any(func(e: Dictionary) -> bool: return str(e["item"]) == "husk_hide_jack"))

	# armour: a percentage off each hit
	inv.equipped.erase("feet")                              # this step is about the coat: the starting boots come off
	inv.add("husk_hide_jack")
	inv.equip("husk_hide_jack")
	_check("the hide jack is 5 armour", _near(float(p.call("armour")), 5.0))
	var hp0: float = b.hp
	p.call("take_hit", 20.0, false, null)
	_check("a 20-damage hit through 5 armour lands as 19", _near(hp0 - b.hp, 19.0), "took %f" % (hp0 - b.hp))
	_check("which is just under what it takes to wound you", b.wounds.is_empty())
	b.hp = b.total_max()
	inv.equipped.erase("body")
	hp0 = b.hp
	p.call("take_hit", 20.0, false, null)                   # health lost, not distance from a ceiling a wound may lower
	_check("and as 20 with nothing on", _near(hp0 - b.hp, 20.0), "took %f" % (hp0 - b.hp))
	_check("which does wound you: armour is the difference", b.wounds.size() == 1)
	b.wounds.clear()
	b.hp = b.total_max()
	var cap: float = GameData.num("gear", "armour_cap")
	GameData.items["test_plate"] = {"name": "Test plate", "slot": "body", "weight": 1.0, "value": 0, "stats": {"armour": 95}}
	inv.equipped["body"] = "test_plate"
	_check("armour is capped so gear stays below the body", _near(float(p.call("armour")), cap))
	GameData.items.erase("test_plate")
	inv.equipped["body"] = "patched_coat"

	# armour reaches a talent that swallows a hit and delivers it later
	var d := _new_player("debt_of_pain")
	(d.get("inventory") as Inventory).equipped.erase("feet")
	(d.get("inventory") as Inventory).add("husk_hide_jack")
	(d.get("inventory") as Inventory).equip("husk_hide_jack")
	var db: Body = d.get("body")
	d.call("start_fight")
	d.call("take_hit", 20.0, false, null)
	for i: int in 6:
		d.call("_physics_process", 1.0)
	_check("armour also takes its share of a hit a talent delays", _near(db.missing(), 19.0 * 0.8), "took %f" % db.missing())
	d.queue_free()

	# the sling
	var e := _foe(p, Vector3(0, 0, -6.0))
	var far := _foe(p, Vector3(9.0, 0, -13.5))               # 16 m off: past the sling's 12
	_check("a sling shot is 45", _near(float(p.call("ranged_damage")), float(cfg["ranged_damage"]) * 0.9) and _near(float(p.call("ranged_damage")), 45.0))
	var essence: float = float(p.get("essence"))
	var shots: int = get_tree().get_nodes_in_group("hittable").size()
	_check("it looses toward where you point", bool(p.call("fire_ranged", e.global_position)))
	_check("for no essence and no reflux", _near(float(p.get("essence")), essence) and _near(float(p.call("reflux_of", "water")), 0.0))
	_check("and not again until the interval is up", not bool(p.call("fire_ranged", e.global_position)) and _near(float(p.get("_ranged_cd")), 0.8))
	var shot: Node3D = null
	for n: Node in p.get_parent().get_children():
		if n.get("shooter") == p:
			shot = n
	_check("the shot is in the air", shot != null and _near(float(shot.get("damage")), 45.0) and _near(float(shot.get("life")), 12.0 / float(cfg["projectile_speed"])))
	for i: int in 60:
		if shot == null or not is_instance_valid(shot) or shot.is_queued_for_deletion():
			break
		shot.call("_process", 1.0 / 60.0)
	_check("it lands on the first enemy in its path for 45", _near(_lost(e), 45.0), "lost %f" % _lost(e))
	await get_tree().process_frame
	p.set("_ranged_cd", 0.0)
	p.call("fire_ranged", far.global_position)
	for n: Node in p.get_parent().get_children():
		if n.get("shooter") == p and not n.is_queued_for_deletion():
			for i: int in 90:
				if not is_instance_valid(n) or n.is_queued_for_deletion():
					break
				n.call("_process", 1.0 / 60.0)
	_check("and dies at its range: nothing at 16 m is hit", _near(_lost(far), 0.0))
	await get_tree().process_frame
	p.set("_ranged_cd", 0.0)
	p.set("arm_right_lost", true)
	_check("with the striking arm gone a shot is weaker, not impossible", _near(float(p.call("ranged_damage")), 45.0 * float(cfg["off_arm_damage_factor"])))
	p.set("arm_right_lost", false)
	inv.unequip("ranged")
	_check("with no ranged weapon there is nothing to loose", not bool(p.call("fire_ranged", e.global_position)) and (p.call("ranged_weapon") as Dictionary).is_empty())
	inv.equip("cord_sling")
	p.set("_recover_t", 0.4)
	p.set("_ranged_cd", 0.0)
	_check("nor in the middle of a skill", not bool(p.call("fire_ranged", e.global_position)))

	# saves
	var old: Dictionary = p.call("to_save")
	(old["inventory"] as Dictionary)["equipped"] = {"back": "canvas_pack"}
	var q := _new_player()
	q.call("from_save", JSON.parse_string(JSON.stringify(old)))
	var qinv: Inventory = q.get("inventory")
	_check("a save from before these slots loads with them empty", not qinv.equipped.has("body") and not qinv.equipped.has("ranged")
		and _near(float(q.call("armour")), 0.0) and not bool(q.call("fire_ranged", Vector3.ZERO)))
	_check("the tooltip says what armour and a sling do", UiWidgets.item_stats_text(GameData.item("husk_hide_jack")) == "takes 5% off every hit"
		and UiWidgets.item_stats_text(GameData.item("cord_sling")) == "shoots for 45 every 0.8 s, out to 12 m", UiWidgets.item_stats_text(GameData.item("cord_sling")))
	for n: Node in [e, far, p, q]:
		n.queue_free()
	await get_tree().process_frame


func _test_water_and_lightning() -> void:
	print("water and lightning (design/05 step 1):")
	var shove_cfg: Dictionary = GameData.balance["shove"]
	var live: Dictionary = GameData.status("live")
	var strike: float = float(GameData.balance["player"]["melee_damage"])

	# ---------- statuses
	var w := _new_player("one_percent_lifesteal")
	w.global_position = Vector3(300, 0, 0)
	var world := _test_floor(w.global_position, w.global_position.z - 7.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var a := _foe(w, Vector3(0, 0, -2.0))
	_check("a status is added, capped and counted", int(a.call("add_status", "live", 2)) == 2 and int(a.call("add_status", "live", 5)) == 3 and int(a.call("status_stacks", "live")) == 3)
	a.call("clear_status", "live")
	a.call("add_status", "soaked")
	for i: int in 70:
		a.call("_tick_statuses", 0.1)
	_check("a status wears off", not bool(a.call("has_status", "soaked")))
	_check("an unknown status is ignored", int(a.call("add_status", "no_such_status")) == 0)

	# ---------- shove: distance, weight, soaked
	var z0: float = a.global_position.z
	a.call("shove", Vector3(0, 0, -1), 2.0)
	_settle(a)
	_check("a shove moves a light enemy its full distance", _near(z0 - a.global_position.z, 2.0, 0.01), "moved %f" % (z0 - a.global_position.z))
	_check("with room to spare there is no crush", _near(_lost(a), 0.0))
	var heavy := _foe(w, Vector3(3.0, 0, -2.0), "brute")
	var hz: float = heavy.global_position.z
	heavy.call("shove", Vector3(0, 0, -1), 2.0)
	_settle(heavy)
	_check("a heavy enemy is shoved half as far, never zero", _near(hz - heavy.global_position.z, 1.0, 0.01), "moved %f" % (hz - heavy.global_position.z))
	heavy.queue_free()
	a.global_position = w.global_position + Vector3(0, 0, -2.0)
	a.call("add_status", "soaked")
	a.call("shove", Vector3(0, 0, -1), 2.0)
	_settle(a)
	_check("a soaked enemy is shoved half as far again", _near(w.global_position.z - 2.0 - a.global_position.z, 3.0, 0.01), "moved %f" % (w.global_position.z - 2.0 - a.global_position.z))
	a.call("clear_status", "soaked")

	# ---------- crush: against a wall
	a.global_position = w.global_position + Vector3(0, 0, -5.0)       # wall face at -6.5; radius 0.5 -> 1.0 m of room
	(a.get("body") as Body).hp = 5000.0
	a.set("shover", w)
	a.call("shove", Vector3(0, 0, -1), 4.0)
	_settle(a)
	var room: float = 1.0
	var want: float = float(shove_cfg["crush_base"]) + float(shove_cfg["crush_per_m"]) * (4.0 - room)
	_check("shoved into a wall: crush is base + per metre it had left", _near(_lost(a), want, 0.6), "lost %f want about %f" % [_lost(a), want])
	_check("and it stops at the wall", not bool(a.call("is_shoved")) and a.global_position.z > w.global_position.z - 6.6)

	# ---------- crush: against another body
	(a.get("body") as Body).hp = 5000.0
	a.global_position = w.global_position + Vector3(0, 0, -2.0)
	var b := _foe(w, Vector3(0, 0, -3.6))
	await get_tree().physics_frame
	await get_tree().physics_frame
	a.set("shover", w)
	a.call("shove", Vector3(0, 0, -1), 4.0)
	_settle(a)
	_check("shoved into another enemy: both are hurt, the one it hit by a share", _lost(a) > float(shove_cfg["crush_base"]) and _near(_lost(b), _lost(a) * float(shove_cfg["crush_other_frac"]), 0.5),
		"a %f b %f" % [_lost(a), _lost(b)])
	b.queue_free()
	await get_tree().process_frame

	# ---------- the water skills
	(a.get("body") as Body).hp = 5000.0
	a.global_position = w.global_position + Vector3(0, 0, -2.0)
	w.set("_facing", Vector3(0, 0, -1))
	w.set("star_pct", [99.0] as Array[float])
	w.call("_recompute_essence_max")
	w.set("essence", 99.0)
	var ctx: HitContext = w.call("apply_hit", a, (w.call("_payload", GameData.ability("water_bolt"), "on_hit") as Dictionary), ["test"], 1.0, Vector3(0, 0, -1))
	_check("water bolt: damage, Soaked, and a step back", _near(ctx.applied, 70.0) and bool(a.call("has_status", "soaked")) and bool(a.call("is_shoved")))
	_settle(a)
	_check("the bolt's shove is 1.5 m, and soaking came first so it goes farther", _near(w.global_position.z - 2.0 - a.global_position.z, 2.25, 0.01), "moved %f" % (w.global_position.z - 2.0 - a.global_position.z))
	# Breaker: a wide arc, everyone thrown straight away
	(a.get("body") as Body).hp = 5000.0
	a.call("clear_status", "soaked")
	a.global_position = w.global_position + Vector3(0, 0, -2.0)
	var side := _foe(w, Vector3(1.9, 0, -1.3))                    # about 56 degrees off the facing: inside 120, outside the old 90
	var behind := _foe(w, Vector3(0, 0, 2.0))
	_rested(w)
	w.call("cast_slot", 1)
	_check("breaker hits a 120 degree arc for twice a strike", _near(_lost(a), strike * 2.0) and _near(_lost(side), strike * 2.0) and _near(_lost(behind), 0.0),
		"front %f side %f behind %f" % [_lost(a), _lost(side), _lost(behind)])
	var side_from: Vector3 = side.global_position
	_settle(a)
	_settle(side)
	var thrown: Vector3 = side.global_position - side_from
	_check("and throws each one straight away from you", bool(thrown.length() > 3.5) and thrown.normalized().dot((side_from - w.global_position).normalized()) > 0.98, "moved %s" % str(thrown))
	side.queue_free()
	behind.queue_free()
	# Sluice Step: through the enemy, soaking it
	(a.get("body") as Body).hp = 5000.0
	a.call("clear_status", "soaked")
	a.global_position = w.global_position + Vector3(0, 0, -2.2)
	w.set("_facing", Vector3(0, 0, -1))
	var start: Vector3 = w.global_position
	_rested(w)
	w.call("cast_slot", 2)
	for i: int in 30:
		w.call("_physics_process", 1.0 / 60.0)
	_check("sluice step carries you through an enemy, exactly its 4.7 m", _near(start.z - w.global_position.z, 26.0 * 0.18, 0.02), "moved %f" % (start.z - w.global_position.z))
	_check("and soaks it on the way, without hurting it", bool(a.call("has_status", "soaked")) and _near(_lost(a), 0.0))
	_check("no skill of the new kits hurts its caster", (w.get("body") as Body).wounds.is_empty() and _near((w.get("body") as Body).missing(), 0.0))
	a.queue_free()
	w.queue_free()
	world.queue_free()
	await get_tree().process_frame

	# ---------- lightning
	var l := _new_player("tenth_strike")
	l.call("set_affinities", ["lightning"])
	l.global_position = Vector3(400, 0, 0)
	var lworld := _test_floor(l.global_position, l.global_position.z - 12.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	l.set("star_pct", [99.0] as Array[float])
	l.call("_recompute_essence_max")
	l.set("essence", 99.0)
	l.set("_facing", Vector3(0, 0, -1))
	l.set("effects", [] as Array[TalentEffect])               # plain numbers: no tenth-strike multiplier in these sums
	var t1 := _foe(l, Vector3(0, 0, -3.0))
	var t2 := _foe(l, Vector3(4.0, 0, -3.0))
	var far := _foe(l, Vector3(0, 0, -5.0))
	# Arc Lash: instant, first enemy on the line, one mark - then (approved 2026-10-22) it arcs on to
	# the nearest other enemy within 4 m: `far`, 2 m behind t1, not t2, 4 m to the side
	l.call("cast_slot", 0)
	_check("arc lash lands at once on the first enemy in line", _near(_lost(t1), 85.0) and _near(_lost(t2), 0.0),
		"t1 %f far %f t2 %f" % [_lost(t1), _lost(far), _lost(t2)])
	_check("and arcs on to the nearest other enemy within 4 m, for the same", _near(_lost(far), 85.0) and int(far.call("status_stacks", "live")) == 1,
		"far %f" % _lost(far))
	_check("and leaves one Live mark", int(t1.call("status_stacks", "live")) == 1)
	var far_before: float = _lost(far)
	var out_of_range := _foe(l, Vector3(-6.0, 0, -9.6))
	l.set("_facing", (out_of_range.global_position - l.global_position).normalized())
	_rested(l)
	l.call("cast_slot", 0)
	_check("it is short: nothing past 9 m", _near(_lost(out_of_range), 0.0))
	out_of_range.queue_free()
	var shielded := _foe(l, Vector3(0, 0, -13.5))                 # beyond the wall at -12
	l.set("_facing", Vector3(0, 0, -1))
	shielded.queue_free()
	# Thunderclap Palm: needs a target in reach; two marks; with the lash's one that is an Overload
	l.set("hovered", t2)
	var ess: float = float(l.get("essence"))
	_rested(l)
	l.call("cast_slot", 1)
	_check("thunderclap palm is refused, unspent, with no one in reach", _near(float(l.get("essence")), ess) and _near(_lost(t2), 0.0))
	t2.call("add_status", "live", 1)                               # a second marked enemy, 4 m away
	far.call("add_status", "live", 1)
	(l.get("reflux_by") as Dictionary)["lightning"] = 40.0
	l.set("hovered", t1)
	var t1_before: float = _lost(t1)
	_rested(l)
	l.call("cast_slot", 1)
	var palm: float = strike * 2.2
	# the palm Dazes its target (approved 2026-10-22) before the marks go off, so the big hit lands on a Dazed body
	var dazed_mult: float = float(GameData.status("dazed")["damage_taken_mult"])
	var want_t1: float = palm + float(live["overload_damage"]) * dazed_mult
	_check("the third mark is an Overload: the palm, then the big hit", _near(_lost(t1) - t1_before, want_t1), "lost %f want %f" % [_lost(t1) - t1_before, want_t1])
	_check("the overloaded target is stunned and its marks are gone", bool(t1.call("has_status", "stunned")) and int(t1.call("status_stacks", "live")) == 0)
	_check("the arc reaches every other marked enemy", _near(_lost(t2), float(live["arc_damage"])) and _near(_lost(far) - far_before, float(live["arc_damage"])), "t2 %f far %f" % [_lost(t2), _lost(far) - far_before])
	_check("and they keep their marks", int(t2.call("status_stacks", "live")) == 1 and int(far.call("status_stacks", "live")) == 2)
	_check("the crack Dazes and staggers everyone within 2.5 m of the target, the target too", bool(t1.call("has_status", "dazed")) and bool(far.call("has_status", "dazed"))
		and bool(far.call("has_status", "staggered")) and not bool(t2.call("has_status", "dazed")))
	var unmarked := _foe(l, Vector3(-2.0, 0, -3.0))
	t1.call("add_status", "live", 2)
	l.call("_add_marks", t1, 1, true)
	_check("an unmarked enemy beside it takes nothing", _near(_lost(unmarked), 0.0))
	unmarked.queue_free()
	var palm_reflux: float = float(GameData.ability("thunderclap_palm")["cost"]) * float(GameData.ability("thunderclap_palm")["reflux_per_cost"])
	_check("each Overload grounds 12 lightning reflux", _near(float(l.call("reflux_of", "lightning")), 40.0 + palm_reflux - float(live["grounds"]) * 2.0),
		"reflux %f" % float(l.call("reflux_of", "lightning")))
	# a stunned enemy does nothing; an interrupt spends its attack
	t1.set("target", l)
	t1.set("_windup", 0.3)
	t1.call("interrupt")
	_check("an interrupt breaks a wind-up", float(t1.get("_windup")) < 0.0)
	# lightning reflux does not shed in a fight
	(l.get("reflux_by") as Dictionary)["lightning"] = 50.0
	l.set("in_combat", true)
	l.call("_shed_reflux", 10.0)
	_check("lightning reflux does not shed in a fight", _near(float(l.call("reflux_of", "lightning")), 50.0))
	l.set("in_combat", false)
	l.call("_shed_reflux", 10.0)
	_check("but does once the fight is over", _near(float(l.call("reflux_of", "lightning")), 40.0))
	# Stepped Leader: you are simply there; marks what you land beside; cannot cross a wall
	t1.queue_free()
	t2.queue_free()
	far.queue_free()
	await get_tree().process_frame
	var near_landing := _foe(l, Vector3(0.8, 0, -6.0))
	l.set("_facing", Vector3(0, 0, -1))
	var from: Vector3 = l.global_position
	_rested(l)
	l.call("cast_slot", 2)
	_check("stepped leader puts you 6 m away at once", _near(from.z - l.global_position.z, 6.0, 0.05), "moved %f" % (from.z - l.global_position.z))
	_check("and marks what you land beside", int(near_landing.call("status_stacks", "live")) == 1)
	ess = float(l.get("essence"))
	_rested(l)
	l.call("cast_slot", 2)                                          # the wall is 6 m further on
	_check("it will not take you through a wall, and costs nothing when refused", _near(from.z - l.global_position.z, 6.0, 0.05) and _near(float(l.get("essence")), ess))
	_check("a blink has a recovery of its own", _near(float(GameData.ability("stepped_leader")["recovery"]), 0.3))
	near_landing.queue_free()

	# ---------- running hot no longer hurts; it slows you
	_check("stepped leader leaves you Quickened (approved 2026-10-22)", (l.get("buffs") as Dictionary).has("quickened"))
	(l.get("buffs") as Dictionary).clear()                           # Quickened would shorten the recovery measured below
	(l.get("reflux_by") as Dictionary)["lightning"] = 85.0
	var hurt_before: float = (l.get("body") as Body).missing()
	l.set("_facing", Vector3(1, 0, 0))
	_rested(l)
	l.call("cast_slot", 0)
	var base_rec: float = GameData.num("abilities", "cast_recovery")
	_check("casting above 80 reflux does not hurt you", _near((l.get("body") as Body).missing(), hurt_before) and (l.get("body") as Body).wounds.is_empty())
	_check("it makes the skill slower to finish", _near(float(l.get("_recover_t")), base_rec * float(GameData.balance["reflux"]["burn_recovery_mult"]) + float(GameData.balance["reflux"]["burn_recovery_add"])),
		"recover %f" % float(l.get("_recover_t")))
	l.queue_free()
	lworld.queue_free()
	await get_tree().process_frame

	# ---------- cross rule 1: wet things conduct
	var c := _new_player()
	c.call("set_affinities", ["water", "lightning"])
	c.global_position = Vector3(500, 0, 0)
	c.set("effects", [] as Array[TalentEffect])
	var wet1 := _foe(c, Vector3(0, 0, -2.0))
	var wet2 := _foe(c, Vector3(2.5, 0, -2.0))
	var dry := _foe(c, Vector3(-2.5, 0, -2.0))
	var wet_far := _foe(c, Vector3(9.0, 0, -2.0))
	for n: Node in [wet1, wet2, wet_far]:
		n.call("add_status", "soaked")
	c.call("_add_marks", wet1, 1, true)
	_check("a lightning hit on a soaked enemy marks the other soaked ones nearby", int(wet1.call("status_stacks", "live")) == 1 and int(wet2.call("status_stacks", "live")) == 1)
	_check("but not a dry one, nor a soaked one out of reach", int(dry.call("status_stacks", "live")) == 0 and int(wet_far.call("status_stacks", "live")) == 0)
	c.call("_add_marks", wet2, 1, false)
	_check("conducted marks do not conduct again", int(wet1.call("status_stacks", "live")) == 1)
	for n: Node in [wet1, wet2, dry, wet_far, c]:
		n.queue_free()
	await get_tree().process_frame

	# ---------- the two renamed skills
	_check("the water skills carry our own names now, ids unchanged", str(GameData.ability("tsunami_strike")["name"]) == "Breaker" and str(GameData.ability("hydraulic_flex")["name"]) == "Sluice Step")


func _test_affinities() -> void:
	print("affinities:")
	var ids: Array = GameData.affinity_ids()
	# Brent 2026-10-22: all sixteen are in the game
	var sixteen: Array = ["water", "fire", "earth", "wind", "lightning", "ice", "dark", "metal", "blood", "life", "death", "nature", "light", "dream", "poison", "disease"]
	_check("sixteen affinities are defined", ids.size() == 16 and sixteen.all(func(a: String) -> bool: return ids.has(a)), str(ids))
	for a: String in ids:
		var kit: Array = GameData.affinity(a).get("kit", [])
		var kinds: Array = []
		var own := true
		for id: String in kit:
			var ab: Dictionary = GameData.ability(id)
			kinds.append(str(ab.get("kind", "")))
			own = own and str(ab.get("affinity", "")) == a
		# earth is the exception, on purpose: its third skill raises a wall and it has no way to move fast
		# a ranged attack may be a lobbed blast (nature, disease); movement may be a grapple or a streak (nature, light)
		_check("%s has a ranged attack, a strike and a movement skill of its own (earth: a wall instead)" % a,
			kit.size() == 3 and own and ["projectile", "beam", "delayed_blast"].has(kinds[0]) and ["melee_burst", "targeted_strike"].has(kinds[1])
			and (["dash", "blink", "grapple", "streak"].has(kinds[2]) or (a == "earth" and kinds[2] == "prop")), str(kinds))

	# the roll at character creation: talent and affinities are unrelated, slots are 1 / 2 / 3
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261011
	var pool: Array = ["one_percent_lifesteal", "tenth_strike", "grudge", "glass_hour", "debt_of_pain", "furnace_gut"]
	var offers: Array[Dictionary] = PrimeRoll.roll_offers(rng, pool)
	_check("three primes are offered, all different", offers.size() == 3 and str(offers[0]["talent_id"]) != str(offers[1]["talent_id"])
		and str(offers[1]["talent_id"]) != str(offers[2]["talent_id"]) and str(offers[0]["talent_id"]) != str(offers[2]["talent_id"]))
	var slot_counts := {1: 0, 2: 0, 3: 0}
	var by_talent := {}
	var clean := true
	for i: int in 20000:
		var o: Dictionary = PrimeRoll.roll_offer(rng, str(pool[i % pool.size()]))
		var affs: Array = o["affinities"]
		slot_counts[affs.size()] = int(slot_counts.get(affs.size(), 0)) + 1
		for a: String in affs:
			clean = clean and ids.has(a) and affs.count(a) == 1
		if not by_talent.has(o["talent_id"]):
			by_talent[o["talent_id"]] = {}
		(by_talent[o["talent_id"]] as Dictionary)[affs[0]] = true
	_check("a prime never repeats an affinity or holds an unknown one", clean)
	_check("one affinity is common, two rare, three very very rare", slot_counts[1] > 16500 and slot_counts[2] > 1800 and slot_counts[2] < 3000
		and slot_counts[3] > 20 and slot_counts[3] < 250 and slot_counts.size() == 3, str(slot_counts))
	_check("any talent can come with any affinity", by_talent.values().all(func(seen: Dictionary) -> bool: return seen.size() == ids.size()))
	_check("rarity is named by slot count", PrimeRoll.rarity(1) == "common" and PrimeRoll.rarity(2) == "rare" and PrimeRoll.rarity(3) == "legendary")

	# a single-affinity character starts with that affinity's kit
	var p := _new_player("grudge")
	p.call("set_affinities", ["fire"])
	var ab0: Array = p.get("abilities")
	_check("a fire prime starts with the fire kit on the bar", (p.get("affinities") as Array) == ["fire"] and ab0.size() == 3
		and str(ab0[0]["id"]) == "cinder_spit" and (p.get("hotbar") as Array).slice(0, 3) == [0, 1, 2])
	p.set("essence", 100.0)
	p.call("cast_slot", 0)
	_check("casting heats that affinity only", float(p.call("reflux_of", "fire")) > 0.0 and _near(float(p.call("reflux_of", "water")), 0.0))
	(p.get("abilities") as Array).append({"id": "water_bolt", "stage": 0, "progress": 0.0})
	var ess: float = float(p.get("essence"))
	p.call("cast_ability", 3)
	_check("an ability outside your affinities cannot be cast", _near(float(p.get("essence")), ess))
	p.queue_free()

	# two affinities: six abilities, and one overheating leaves the other usable
	p = _new_player("glass_hour")
	p.call("set_affinities", ["wind", "lightning"])
	p.set("star_pct", [99.0] as Array[float])
	p.call("_recompute_essence_max")
	_check("a dual prime fills the bar with both kits", (p.get("affinities") as Array) == ["wind", "lightning"] and (p.get("abilities") as Array).size() == 6
		and not (p.get("hotbar") as Array).has(-1))
	(p.get("reflux_by") as Dictionary)["wind"] = 99.0
	p.set("essence", 99.0)
	p.call("cast_slot", 0)
	_check("overheating wind locks wind", bool(p.call("is_locked", "wind")) and not bool(p.call("is_locked", "lightning")))
	ess = float(p.get("essence"))
	p.call("cast_slot", 0)
	_check("a locked affinity cannot cast", _near(float(p.get("essence")), ess))
	_rested(p)
	p.call("cast_slot", 3)
	_check("the other affinity still can", float(p.get("essence")) < ess and float(p.call("reflux_of", "lightning")) > 0.0)
	for i: int in 30:
		p.call("_shed_reflux", 2.0)
	_check("reflux sheds on every affinity and the lock lifts", not bool(p.call("is_locked", "wind")) and float(p.call("reflux_of", "wind")) < 60.0
		and _near(float(p.call("reflux_of", "lightning")), 0.0))
	p.queue_free()

	# furnace gut vents the affinity that overheated, not the other one
	p = _new_player("furnace_gut")
	p.call("set_affinities", ["fire", "earth"])
	p.set("star_pct", [99.0] as Array[float])
	p.call("_recompute_essence_max")
	p.set("essence", 99.0)
	(p.get("reflux_by") as Dictionary)["fire"] = 20.0
	(p.get("reflux_by") as Dictionary)["earth"] = 99.0
	p.call("cast_slot", 3)                 # the earth projectile
	_check("furnace gut vents the affinity that capped", _near(float(p.call("reflux_of", "earth")), 50.0) and _near(float(p.call("reflux_of", "fire")), 20.0)
		and not bool(p.call("is_locked", "earth")), "earth %f fire %f" % [float(p.call("reflux_of", "earth")), float(p.call("reflux_of", "fire"))])
	p.queue_free()

	# three affinities: nine skills, six on the bar, the rest known but unslotted
	p = _new_player("tenth_strike")
	p.call("set_affinities", ["water", "earth", "wind", "earth", "no_such_affinity"])
	_check("a three-affinity prime knows nine skills and slots the first six", (p.get("affinities") as Array) == ["water", "earth", "wind"]
		and (p.get("abilities") as Array).size() == 9 and (p.get("hotbar") as Array) == [0, 1, 2, 3, 4, 5])
	p.queue_free()

	# wisps
	p = _new_player("grudge")
	p.call("set_affinities", ["fire"])
	var n := Netherecho.new()
	add_child(n)
	n.player = p
	n.enter()
	var proj: Node3D = n.projection
	proj.set("input_blocked", true)
	var pct0: float = float((p.get("star_pct") as Array)[0])
	n.spawn_wisp(n.to_local(proj.global_position), "water")
	n.tick(0.01, null)
	_check("a wisp of an affinity you do not hold will not come to you", n.gathered_this_trip == 0 and _near(float((p.get("star_pct") as Array)[0]), pct0))
	n.spawn_wisp(n.to_local(proj.global_position), "fire")
	n.tick(0.01, null)
	_check("a wisp of your own affinity grows the star", n.gathered_this_trip == 1 and float((p.get("star_pct") as Array)[0]) > pct0)
	var seen := {}
	for i: int in 400:
		seen[n.call("_roll_wisp_affinity")] = true
	_check("the echo holds your wisps, foreign wisps and plain ether", seen.has("fire") and seen.has("plain") and seen.size() >= 3, str(seen.keys()))
	n.exit("")
	n.clear()
	n.queue_free()
	p.queue_free()


func _test_models() -> void:
	print("models:")
	# every look must build, and building one must not stall the creator
	var opts: Dictionary = CharacterLook.options()
	if opts.has("sex"):
		var slowest := 0
		for sex: Dictionary in opts["sex"]:
			for body_opt: Dictionary in opts.get("body", []):
				var look: Dictionary = CharacterLook.default_look()
				look["sex"] = str(sex["id"])
				look["body"] = str(body_opt["id"])
				look["face"] = str((opts["face"][opts["face"].size() - 1] as Dictionary)["id"])
				var t0: int = Time.get_ticks_msec()
				var m: ModelRig = CharacterLook.build(look)
				slowest = maxi(slowest, Time.get_ticks_msec() - t0)
				if m == null or m.height < 1.65 or m.height > 1.95 or not (m is RealCharacter or m.has_part("arm_right")):     # a real body has no separate arm
					_check("every sex and body builds a usable model", false, str(look))
				m.free()
		print("  note slowest first build of a look: %d ms" % slowest)
		_check("male and female are both offered", (opts["sex"] as Array).size() == 2 and str((opts["sex"][0] as Dictionary)["id"]) == "male")
		_check("building a new look takes well under a second", slowest < 700, "%d ms" % slowest)
	var p := _new_player()
	var rig: ModelRig = p.get("_rig")
	var inv: Inventory = p.get("inventory")
	_check("an unarmed character holds nothing", rig.get_weapon() == null)
	inv.add("serrated_dagger")
	inv.equip("serrated_dagger")
	p.call("refresh_gear")
	_check("an equipped weapon is in the model's hand", rig.get_weapon() != null)
	inv.unequip("weapon")
	p.call("refresh_gear")
	_check("unequipping takes it out again", rig.get_weapon() == null)
	p.queue_free()
	for tier: String in ["vestige", "remnant"]:
		for c: String in GameData.concept_ids():
			var m: Node3D = NetherArt.construct(tier, c, 1.0, 0.4)
			if not (m is ModelRig):
				_check("every wild construct has a real model", false, "%s %s" % [tier, c])
			m.free()
	var proj_model: Node3D = NetherArt.projection()
	var wisp_model: Node3D = NetherArt.wisp("water")
	_check("the projection and wisps have real models", proj_model is ModelRig and wisp_model is Wisp)
	proj_model.free()
	wisp_model.free()


func _test_netherecho() -> void:
	print("netherecho:")
	await get_tree().process_frame
	var p := _new_player()
	var n := Netherecho.new()
	add_child(n)
	n.player = p
	var cfg: Dictionary = GameData.balance["nether"]

	p.set("in_combat", true)
	_check("no projecting in the middle of a fight", not n.enter() and n.cannot_enter_reason() != "")
	p.set("in_combat", false)
	_check("out of combat the soul can leave", n.enter() and n.active and bool(p.get("projecting")) and n.projection != null)
	var proj: Node3D = n.projection
	proj.set("input_blocked", true)
	_check("the projection is fragile", _near(float(proj.get("hp")), float(cfg["projection_hp"])))

	# the body left behind meditates and takes no orders
	p.set("move_goal", p.global_position + Vector3(6, 0, 0))
	p.set("has_move_goal", true)
	var body_at: Vector3 = p.global_position
	p.call("_physics_process", 0.1)
	_check("the empty body sits and meditates", bool(p.get("meditating")) and p.global_position.distance_to(body_at) < 0.01)

	# the leash
	proj.call("click", p.global_position + Vector3(200, 0, 0))
	for i: int in 200:
		n.tick(0.1, null)
	var leash: float = float(cfg["leash_base"]) + float(cfg["leash_per_star"])
	var strayed: float = (proj.global_position - p.global_position).length()
	_check("the soul cannot stray past its tether", _near(strayed, leash, 0.05) and bool(proj.get("at_leash")), "strayed %f leash %f" % [strayed, leash])
	_check("straying does not end the trip", n.active)

	# wisps
	var pct0: float = float((p.get("star_pct") as Array)[0])
	p.set("essence", 0.0)
	var w: Node3D = n.spawn_wisp(n.to_local(proj.global_position), "water")
	n.tick(0.01, null)
	_check("touching a water wisp grows the star and refills essence",
		_near(float((p.get("star_pct") as Array)[0]), pct0 + float(cfg["wisp_attuned_star_pct"])) and _near(float(p.get("essence")), float(cfg["wisp_attuned_essence"])) and n.gathered_this_trip == 1,
		"pct %f essence %f" % [float((p.get("star_pct") as Array)[0]), float(p.get("essence"))])
	n.tick(0.01, null)
	_check("a wisp is gathered once", n.gathered_this_trip == 1 and w.is_queued_for_deletion())

	# subduing a construct
	var had: int = (p.get("constructs") as Array).size()
	var c: Node3D = n.spawn_construct(n.to_local(proj.global_position + Vector3(1.2, 0, 0)), "vestige", "tension", true)
	c.set("target", proj)
	_check("a docile construct leaves you alone at first", not bool(c.get("hostile")))
	proj.set("hovered", c)
	proj.call("click", c.global_position)
	n.tick(0.05, null)
	_check("striking one makes it hostile", bool(c.get("hostile")) and (c.get("body") as Body).missing("superficial") + (c.get("body") as Body).missing("structural") > 0.0)
	proj.set("hp", 9999.0)                # keep the test about the construct, not the soul's hp
	for i: int in 200:
		if not is_instance_valid(c) or c.is_queued_for_deletion():
			break
		proj.set("hovered", c)
		proj.call("click", c.global_position)
		n.tick(0.1, null)
	var got: Array = p.get("constructs")
	_check("a beaten construct is subdued and yours to bind", got.size() == had + 1 and str((got[got.size() - 1] as Dictionary)["concept"]) == "tension" and n.subdued_this_trip == 1,
		"constructs %d" % got.size())
	await get_tree().process_frame

	# a hostile one hurts the projection
	proj.set("hp", float(proj.get("hp_max")))
	var c2: Node3D = n.spawn_construct(n.to_local(proj.global_position + Vector3(1.0, 0, 0)), "vestige", "reach", false)
	c2.set("target", proj)
	for i: int in 40:
		n.tick(0.1, null)
		if float(proj.get("hp")) < float(proj.get("hp_max")):
			break
	_check("a wild construct attacks the projection", n.active and float(proj.get("hp")) < float(proj.get("hp_max")))

	# its destruction
	var torn := [false]
	n.projection_destroyed.connect(func() -> void: torn[0] = true)
	proj.call("take_hit", 99999.0, false, c2)
	_check("a destroyed projection ends the trip and is reported as death", torn[0] and not n.active and not bool(p.get("projecting")))
	_check("constructs calm down once you are gone", not bool(c2.get("hostile")))
	c2.call("take_hit", 99999.0, false, null)
	await get_tree().process_frame

	# killed the way it happens in play: by a construct's blow, in the middle of the echo's own update
	# (Brent 2026-10-12: "when I died in netherecho the game crashed")
	_check("the soul goes out for the fight", n.enter())
	var doomed: Node3D = n.projection
	doomed.set("input_blocked", true)
	doomed.set("hp", 1.0)
	var killer: Node3D = n.spawn_construct(n.to_local(doomed.global_position + Vector3(1.0, 0, 0)), "vestige", "piercing", false)
	killer.set("target", doomed)
	n.spawn_wisp(n.to_local(doomed.global_position), "plain")
	var torn_again := [0]
	n.projection_destroyed.connect(func() -> void: torn_again[0] += 1)
	for i: int in 60:
		n.tick(0.1, null)
		if not n.active:
			break
	_check("a construct can destroy the projection during the echo's update", not n.active and torn_again[0] == 1 and n.projection == null)
	n.tick(0.1, null)
	n.tick(0.1, null)
	_check("and the echo keeps running quietly afterwards", not n.active and not bool(p.get("projecting")))
	killer.call("take_hit", 99999.0, false, null)
	await get_tree().process_frame

	# pain in the body
	p.connect("disturbed", func() -> void: n.exit("pain"))
	_check("the soul can go out again", n.enter())
	p.call("take_hit", 1.0, false, null)
	_check("hurting the body drags the soul back", not n.active and not bool(p.get("projecting")))

	# walking back onto the body
	n.enter()
	proj = n.projection
	proj.set("input_blocked", true)
	n.tick(0.01, null)
	_check("stepping out does not instantly step back in", n.active)
	proj.global_position = p.global_position + Vector3(float(cfg["return_arm_distance"]) + 1.0, 0, 0)
	n.tick(0.01, null)
	proj.global_position = p.global_position + Vector3(0.2, 0, 0)
	n.tick(0.01, null)
	_check("walking back onto the body returns you", not n.active)

	n.spawn_wisp(Vector3(3, 0, 3), "plain")
	n.clear()
	await get_tree().process_frame
	_check("clearing the level empties its echo", n.get_child_count() == 0 and get_tree().get_nodes_in_group("nether_enemies").is_empty())
	n.queue_free()
	p.queue_free()


func _test_keybinds() -> void:
	print("keybinds:")
	Keybinds.reset_defaults()
	_check("defaults registered", Keybinds.binding_text("ability_1") == "1" and Keybinds.binding_text("ability_6") == "6" and Keybinds.binding_text("strike") == "LMB")
	var g := InputEventKey.new()
	g.physical_keycode = KEY_J
	var displaced: String = Keybinds.rebind("ability_1", g)
	_check("rebind changes the binding", Keybinds.binding_text("ability_1") == "J" and displaced == "")
	var displaced2: String = Keybinds.rebind("ascend", g)
	_check("a key held by another action is taken from it", displaced2 == "ability_1" and Keybinds.binding_text("ability_1") == "(none)" and Keybinds.binding_text("ascend") == "J")
	var mmb := InputEventMouseButton.new()
	mmb.button_index = MOUSE_BUTTON_MIDDLE
	Keybinds.rebind("meditate", mmb)
	_check("mouse buttons bind too", Keybinds.binding_text("meditate") == "MMB")
	Keybinds.call("_load")
	_check("bindings survive a save/load round trip", Keybinds.binding_text("ascend") == "J" and Keybinds.binding_text("meditate") == "MMB")
	Keybinds.reset_defaults()
	_check("reset restores defaults", Keybinds.binding_text("ability_1") == "1" and Keybinds.binding_text("ascend") == "T" and Keybinds.binding_text("meditate") == "M")


func _test_death_and_rest() -> void:
	print("death and corpse runs / night's rest:")
	var p := _new_player()
	var b: Body = p.get("body")
	var inv: Inventory = p.get("inventory")
	p.set("money", 100)
	inv.add("sinew_cord")
	var worn: Dictionary = inv.equipped.duplicate()
	p.set("arm_right_lost", true)
	b.add_wound("lost_arm", "Lost arm", 25.0, 8.0, false)
	b.add_wound("ribs", "Cracked ribs", 20.0, 8.0)
	b.apply_damage(1000.0)
	p.set("dead", true)
	var corpse: Dictionary = p.call("die_to_corpse", "passage", 4, Vector3(1.0, 0.0, -60.0))
	p.call("respawn_naked")
	_check("revived character is alive", not bool(p.get("dead")) and not b.is_dead())
	_check("death costs no money", int(p.get("money")) == 100, "money %d" % int(p.get("money")))
	_check("you wake naked: nothing worn, nothing carried", inv.equipped.is_empty() and inv.bag.is_empty())
	_check("it is all on the corpse, where you fell", str(corpse.get("where", "")) == "passage" and int(corpse["chamber"]) == 4
		and (corpse["equipped"] as Dictionary) == worn and (corpse["bag"] as Array).has("sinew_cord"))
	_check("the retrieval fee is flat, by stars", int(p.call("corpse_fee")) == GameData.inum("town", "corpse_fee_per_star") * int(p.get("stars")))
	var saved: Dictionary = p.call("to_save")
	var q := _new_player()
	q.call("from_save", saved)
	_check("a corpse survives a save", (q.get("corpses") as Array).size() == 1)
	q.free()
	inv.add("golden_seed")
	_check("dying naked again with only a seed leaves a second, small corpse", not (p.call("die_to_corpse", "arena", 0, Vector3.ZERO) as Dictionary).is_empty())
	p.call("respawn_naked")
	p.set("money", int(GameData.num("player", "debt_limit")) + 100)       # this close to the limit, no fee fits
	_check("the collectors will not go out on credit you do not have", str(p.call("buy_corpse_retrieval")) != "" and (p.get("corpses") as Array).size() == 2)
	p.set("money", 2000)
	_check("paying brings back the newest body", str(p.call("buy_corpse_retrieval")) == "" and int(p.get("money")) == 2000 - int(p.call("corpse_fee"))
		and inv.bag.has("golden_seed") and (p.get("corpses") as Array).size() == 1)
	_check("walking to the other and taking it puts everything back on", bool(p.call("recover_corpse", str(corpse["id"]))) and inv.equipped == worn and inv.bag.has("sinew_cord"))
	_check("patched up, not healed: half the bar, every wound still there", _near(b.total(), 42.0) and b.wounds.size() == 2, "hp %f" % b.total())
	_check("a lost arm stays lost through death", bool(p.get("arm_right_lost")))
	p.call("rest_night")
	_check("a night's rest refills the bar and knits a wound a little", _near(b.total(), b.total_max()) and _near(float(b.wound("ribs")["sink"]), 5.0))
	_check("a night's rest does nothing for a lost arm", _near(float(b.wound("lost_arm")["sink"]), 25.0) and bool(p.get("arm_right_lost")))
	p.call("rest_night")
	_check("a second night closes it", not b.has_wound("ribs") and _near(b.total(), 92.0))
	p.queue_free()

	# ascension pace (Brent 2026-10-11: ten minutes was far too quick, about two hours is right)
	_check("the second star is a long road", GameData.num("player", "aura_threshold") >= 1000.0 and GameData.num("stars", "growth_pct_per_aura") <= 0.05)


func _test_inventory_doll() -> void:
	print("the paper doll: twelve slots (design/06 section 2):")
	await get_tree().process_frame
	var wanted: Array[String] = ["weapon", "offhand", "ranged", "head", "body", "hands", "feet", "back", "belt", "satellite", "trinket", "trinket2"]
	_check("there are twelve slots and the main hand is still called weapon", Inventory.SLOTS.size() == 12
		and wanted.all(func(s: String) -> bool: return Inventory.SLOTS.has(s)), str(Inventory.SLOTS))
	var p := _new_player()
	var inv: Inventory = p.get("inventory")
	_check("a new character also wears street boots and a rope belt", str(inv.equipped.get("feet", "")) == "street_boots" and str(inv.equipped.get("belt", "")) == "rope_belt")

	# the data: every item fits a slot, and no item lists a stat nothing reads
	var read_anywhere: Array[String] = ["armour", "carry_capacity", "satellite_rate", "cost_mult", "reflux_shed_mult", "ranged_interval_mult"]
	var read_in_hand: Dictionary = {"weapon": ["melee_damage_mult", "melee_cooldown_mult", "melee_range_bonus"], "ranged": ["ranged_damage_mult", "ranged_interval", "ranged_range"]}
	var misfit := ""
	var unread := ""
	var filled: Dictionary = {}
	for id: String in GameData.items:
		var def: Dictionary = GameData.items[id]
		var item_slot: String = str(def.get("slot", ""))
		if item_slot == "":
			continue
		if Inventory.slots_for(item_slot).is_empty():
			misfit = id
		filled[item_slot] = int(filled.get(item_slot, 0)) + 1
		for key: String in def.get("stats", {}):
			if not read_anywhere.has(key) and not (read_in_hand.get(item_slot, []) as Array).has(key):
				unread = "%s.%s" % [id, key]
	_check("every piece of gear has a slot to go in", misfit == "", misfit)
	_check("no live item carries a stat the game does not read", unread == "", unread)
	var thin := ""
	for kind: String in ["head", "hands", "feet", "offhand", "belt"]:
		if int(filled.get(kind, 0)) < 2:
			thin = kind
	_check("each of the five new slots has at least two pieces to hold", thin == "", thin)
	var absent := ""
	for id: Variant in GameData.items_file["shop"]:
		if GameData.item(str(id)).is_empty():
			absent = str(id)
	_check("everything the merchant stocks exists", absent == "", absent)
	_check("and the merchant stocks something for the head, hands, feet, off hand and belt", ["head", "hands", "feet", "offhand", "belt"].all(func(kind: String) -> bool:
		return (GameData.items_file["shop"] as Array).any(func(id: Variant) -> bool: return str(GameData.item(str(id)).get("slot", "")) == kind)))

	# two trinkets
	for id: String in ["river_stone", "cooling_coil", "river_stone", "oilcloth_hood", "hide_bracers", "hobnailed_boots", "chalk_slate", "quiver_belt"]:
		inv.add(id)
	_check("the first trinket goes into the first trinket slot", inv.equip("river_stone") == "equipped" and str(inv.equipped.get("trinket", "")) == "river_stone")
	_check("the second into the second", inv.equip("cooling_coil") == "equipped" and str(inv.equipped.get("trinket2", "")) == "cooling_coil" and str(inv.equipped.get("trinket", "")) == "river_stone")
	_check("and both count", _near(inv.stat("cost_mult", true), 0.9) and _near(inv.stat("reflux_shed_mult", true), 1.5))
	_check("the same item cannot be worn twice", inv.equip("river_stone") != "equipped" and inv.equip("river_stone", "trinket2") != "equipped"
		and inv.bag.has("river_stone") and str(inv.equipped.get("trinket2", "")) == "cooling_coil")
	_check("a piece cannot be forced into a slot it does not fit", inv.equip("oilcloth_hood", "feet") == "cannot equip that" and str(inv.equipped.get("feet", "")) == "street_boots"
		and inv.equip("oilcloth_hood", "trinket2") == "cannot equip that")
	inv.unequip("trinket")
	_check("with the first slot empty a trinket named for the second still goes to the second", inv.equip("river_stone", "trinket2") == "equipped"
		and str(inv.equipped.get("trinket2", "")) == "river_stone" and not inv.equipped.has("trinket") and inv.bag.has("cooling_coil"))
	inv.remove("river_stone")

	# armour adds up over every slot and still goes through the one cap
	_bare(p)
	var b: Body = p.get("body")
	for id: String in ["oilcloth_hood", "hide_bracers", "hobnailed_boots"]:
		inv.equip(id)
	_check("a hood, bracers and boots are 1 + 2 + 2 armour", _near(float(p.call("armour")), 5.0) and str(inv.equipped.get("head", "")) == "oilcloth_hood"
		and str(inv.equipped.get("hands", "")) == "hide_bracers" and str(inv.equipped.get("feet", "")) == "hobnailed_boots", str(p.call("armour")))
	var hp0: float = b.hp
	p.call("take_hit", 20.0, false, null)
	_check("so a 20-damage hit lands as 19", _near(hp0 - b.hp, 19.0), "took %f" % (hp0 - b.hp))
	b.hp = b.total_max()
	b.wounds.clear()
	_check("the hood sheds a little reflux as well", _near(inv.stat("reflux_shed_mult", true), 1.03))

	# the off hand and the belt do what their text says
	var cost0: float = float((p.call("ability_stats", (p.get("abilities") as Array)[0]) as Dictionary)["cost"])
	inv.equip("chalk_slate")
	var cost1: float = float((p.call("ability_stats", (p.get("abilities") as Array)[0]) as Dictionary)["cost"])
	_check("a slate in the off hand takes 4% off what an ability costs", str(inv.equipped.get("offhand", "")) == "chalk_slate" and _near(cost1, cost0 * 0.96), "%f -> %f" % [cost0, cost1])
	_check("the sling looses every 0.8 s", _near(float(p.call("ranged_interval")), 0.8))
	inv.equip("quiver_belt")
	_check("and 4% sooner with a quiver belt on", str(inv.equipped.get("belt", "")) == "quiver_belt" and _near(float(p.call("ranged_interval")), 0.768, 0.0005))
	p.set("_ranged_cd", 0.0)
	p.set("_recover_t", 0.0)
	_check("which is what a shot actually waits", bool(p.call("fire_ranged", p.global_position + Vector3(0.0, 0.0, -6.0))) and _near(float(p.get("_ranged_cd")), 0.768, 0.0005), str(p.get("_ranged_cd")))
	for n: Node in p.get_parent().get_children():
		if n.get("shooter") == p:
			n.queue_free()
	_check("the rope belt lists no effect because it has none", UiWidgets.item_stats_text(GameData.item("rope_belt")) == ""
		and UiWidgets.item_stats_text(GameData.item("quiver_belt")) == "shoots 4% sooner", UiWidgets.item_stats_text(GameData.item("quiver_belt")))

	# saves: all twelve slots round-trip, an old save loads, a bad one is not worn
	var q := _new_player()
	q.call("from_save", JSON.parse_string(JSON.stringify(p.call("to_save"))))
	var qinv: Inventory = q.get("inventory")
	_check("what is worn in the new slots survives a save and a load", str(qinv.equipped.get("head", "")) == "oilcloth_hood" and str(qinv.equipped.get("offhand", "")) == "chalk_slate"
		and str(qinv.equipped.get("belt", "")) == "quiver_belt" and str(qinv.equipped.get("hands", "")) == "hide_bracers" and _near(float(q.call("armour")), 5.0), str(qinv.equipped))
	var old: Dictionary = p.call("to_save")
	(old["inventory"] as Dictionary)["equipped"] = {"weapon": "serrated_dagger", "back": "canvas_pack", "trinket": "river_stone"}
	q.call("from_save", JSON.parse_string(JSON.stringify(old)))
	_check("a save from before the doll loads: the weapon is in the main hand, the new slots are empty", str(qinv.equipped.get("weapon", "")) == "serrated_dagger"
		and str(qinv.equipped.get("trinket", "")) == "river_stone" and qinv.equipped.size() == 3 and _near(float(q.call("weapon_stat", "melee_damage_mult", true)), 1.1), str(qinv.equipped))
	(old["inventory"] as Dictionary)["equipped"] = {"head": "canvas_pack", "pocket": "river_stone", "back": "canvas_pack"}
	q.call("from_save", JSON.parse_string(JSON.stringify(old)))
	_check("a save that names a slot that is not there, or a piece that does not fit, is not worn", qinv.equipped.size() == 1 and str(qinv.equipped.get("back", "")) == "canvas_pack", str(qinv.equipped))

	# the comparison the screen prints against what is worn
	var screen_script: GDScript = load("res://scripts/ui/inventory_screen.gd")
	var boots: Array = screen_script.call("compare_lines", GameData.item("hobnailed_boots"), GameData.item("street_boots"))
	_check("better boots compare as one line, better", boots.size() == 1 and bool((boots[0] as Array)[1]) and str((boots[0] as Array)[0]).begins_with("Armour  2%"), str(boots))
	var blades: Array = screen_script.call("compare_lines", GameData.item("invader_cleaver"), GameData.item("serrated_dagger"))
	_check("a cleaver against a dagger hits harder and strikes slower", blades.size() == 2 and bool((blades[0] as Array)[1]) and not bool((blades[1] as Array)[1]), str(blades))
	_check("a piece compared with itself shows nothing", (screen_script.call("compare_lines", GameData.item("padded_jack"), GameData.item("padded_jack")) as Array).is_empty())
	for key: String in ["weapon", "offhand", "ranged", "head", "body", "hands", "feet", "back", "belt", "satellite", "trinket", "trinket2"]:
		for table: String in ["SLOT_LABELS", "SLOT_GHOSTS", "SLOT_HINTS"]:
			if not (screen_script.get_script_constant_map()[table] as Dictionary).has(key):
				_check("the screen has a label, a ghost and a hint for every slot", false, "%s.%s" % [table, key])
	var columns: Array = (screen_script.get_script_constant_map()["LEFT_SLOTS"] as Array) + (screen_script.get_script_constant_map()["RIGHT_SLOTS"] as Array)
	_check("the two columns either side of the figure hold each slot once", columns.size() == 12 and wanted.all(func(s: String) -> bool: return columns.count(s) == 1), str(columns))
	for n: Node in [p, q]:
		n.queue_free()
	await get_tree().process_frame


## Pathfinding (Brent 2026-10-18: "Get pathfinding working as well."): every level bakes navigation
## meshes from its colliders (LevelNav) and enemies and the bot follow paths on them (NavPath).
## Each part gets a little world of its own, far from the others; enemies are walked by hand at
## 1/60 s a step inside a physics frame, so their walking uses that step too.
func _test_pathfinding() -> void:
	print("pathfinding (Brent 2026-10-18):")
	await get_tree().process_frame
	var p := _new_player()
	var step := 1.0 / 60.0
	# walk `e` until `done` says so or `seconds` of game time pass; returns the time it took
	var walk := func(e: Node, seconds: float, done: Callable, watch: Callable = Callable()) -> float:
		var t := 0.0
		while t < seconds and is_instance_valid(e) and not bool(done.call()):
			var was: Vector3 = (e as Node3D).global_position
			e.call("_physics_process", step)
			if watch.is_valid():
				watch.call(was, (e as Node3D).global_position)
			t += step
		return t
	var baked_world := func(at: Vector3, blocks: Array) -> Node3D:
		var root: Node3D = _test_floor(at)
		for b: Array in blocks:
			_block(root, at + (b[0] as Vector3), b[1] as Vector3)
		var made := LevelNav.new()
		made.auto_rebake = false
		root.add_child(made)
		made.bake_now()
		return root
	var nav_of := func(root: Node) -> LevelNav:
		for c: Node in root.get_children():
			if c is LevelNav:
				return c as LevelNav
		return null

	# ---------- a wall across the way, 12 m wide
	var here := Vector3(2600, 0, 0)
	var world: Node3D = baked_world.call(here, [[Vector3(0, 1, -5), Vector3(12, 2, 1)]])
	var nav: LevelNav = nav_of.call(world)
	_check("the colliders of a level bake into a mesh to walk on, for that level only", nav.is_ready() and nav.covers(here) and not nav.covers(here + Vector3(500, 0, 0)))
	var route: PackedVector3Array = nav.path(here + Vector3(0, 0, -10), here, 0.5)
	var round_end := true
	for i: int in range(1, route.size()):
		var a: Vector3 = route[i - 1] - here
		var b: Vector3 = route[i] - here
		if (a.z < -5.0) != (b.z < -5.0):
			var cross_x: float = a.x + (b.x - a.x) * ((-5.0 - a.z) / (b.z - a.z))
			round_end = round_end and absf(cross_x) >= 6.0 + 0.45
	_check("a path runs round the wall from one side to the other", route.size() >= 3 and NavPath.flat(route[route.size() - 1], here) < 0.3 and LevelNav.length_of(route) > 10.5 and round_end,
		"%d points, %.1f m" % [route.size(), LevelNav.length_of(route)])
	var wide_route: PackedVector3Array = nav.path(here + Vector3(0, 0, -10), here, 0.9)
	var wide_clear := true
	for pt: Vector3 in wide_route:
		if absf(pt.z - here.z + 5.0) < 0.6:
			wide_clear = wide_clear and absf(pt.x - here.x) >= 6.0 + 0.9
	_check("a big walker gets a mesh of its own and turns the corner wider", nav.map_for(0.9) != nav.map_for(0.5) and wide_route.size() >= 3 and wide_clear, str(wide_route))

	# an enemy with that wall between it and you walks round it
	p.global_position = here
	await get_tree().physics_frame
	_check("the walking below runs inside a physics frame", Engine.is_in_physics_frame())
	var grunt := _fighter(p, Vector3(0, 0, -10.0))
	var widest := [0.0]
	var took: float = walk.call(grunt, 10.0, func() -> bool: return grunt.global_position.distance_to(p.global_position) <= 2.3,
		func(_was: Vector3, now: Vector3) -> void: widest[0] = maxf(float(widest[0]), absf(now.x - here.x)))
	_check("an enemy blocked by a wall reaches you by walking round it", grunt.global_position.distance_to(p.global_position) <= 2.3 and float(widest[0]) > 6.0,
		"after %.1f s at %s, widest %.1f" % [took, str(grunt.global_position - here), float(widest[0])])
	_check("and not slowly: about the length of the way round at its speed", took < 22.0 / float(grunt.get("speed")), "%.1f s" % took)
	grunt.free()
	world.free()

	# ---------- a narrow gap a grunt fits through and a brute does not, and a wide one farther off
	here = Vector3(2600, 0, 200)
	world = baked_world.call(here, [[Vector3(-15.4, 1, -5), Vector3(29.2, 2, 1)], [Vector3(5.4, 1, -5), Vector3(9.2, 2, 1)], [Vector3(22.0, 1, -5), Vector3(16.0, 2, 1)]])
	nav = nav_of.call(world)
	var thin: PackedVector3Array = nav.path(here + Vector3(0, 0, -10), here, 0.5)
	var fat: PackedVector3Array = nav.path(here + Vector3(0, 0, -10), here, 0.8)
	_check("a grunt goes through the 1.6 m gap", thin.size() >= 2 and NavPath.flat(thin[thin.size() - 1], here) < 0.3 and LevelNav.length_of(thin) < 10.5, "%.1f m" % LevelNav.length_of(thin))
	_check("a brute is not offered it, and goes round by the wide one", LevelNav.length_of(fat) > 20.0 and NavPath.flat(fat[fat.size() - 1], here) < 0.3, "%.1f m" % LevelNav.length_of(fat))
	p.global_position = here
	await get_tree().physics_frame
	var brute := _fighter(p, Vector3(0, 0, -10.0), "brute")
	took = walk.call(brute, 25.0, func() -> bool: return brute.global_position.distance_to(p.global_position) <= 2.6)
	_check("and gets to you that way instead of wedging itself in the narrow one", brute.global_position.distance_to(p.global_position) <= 2.6,
		"after %.1f s at %s" % [took, str(brute.global_position - here)])
	brute.free()
	world.free()

	# ---------- a doorway: an enemy in the next chamber, off to one side, comes through it
	here = Vector3(2600, 0, 400)
	world = baked_world.call(here, [[Vector3(-8.5, 1, -6), Vector3(1, 2, 20)], [Vector3(8.5, 1, -6), Vector3(1, 2, 20)],
		[Vector3(-5.0, 1, -6), Vector3(6, 2, 1)], [Vector3(5.0, 1, -6), Vector3(6, 2, 1)]])
	nav = nav_of.call(world)
	p.global_position = here + Vector3(5, 0, 0)
	await get_tree().physics_frame
	var way: Vector3 = p.call("_bot_way", here + Vector3(5, 0, -12), 0.0)
	_check("the way the bot takes to the next chamber is toward the doorway, not into the wall", way.x < -0.3, str(way))
	var door_x := [INF]
	var comer := _fighter(p, Vector3(0, 0, -12.0))
	took = walk.call(comer, 12.0, func() -> bool: return comer.global_position.distance_to(p.global_position) <= 2.3,
		func(was: Vector3, now: Vector3) -> void:
			if (was.z - here.z < -6.0) != (now.z - here.z < -6.0):
				door_x[0] = now.x - here.x)
	_check("an enemy in the next chamber comes through the doorway to reach you", comer.global_position.distance_to(p.global_position) <= 2.3 and absf(float(door_x[0])) < 2.0,
		"after %.1f s at %s, crossed at x %.1f" % [took, str(comer.global_position - here), float(door_x[0])])
	comer.free()
	world.free()

	# ---------- standing stone: not in the mesh, walked round all the same - by the open end
	here = Vector3(2600, 0, 600)
	world = baked_world.call(here, [[Vector3(2.7, 1, -5), Vector3(1, 2, 10)]])      # a wall just past the right end of the slab
	p.global_position = here
	var slab: Node3D = p.call("raise_stone", here + Vector3(0, 0, -4.0), Vector3(0, 0, -1), {})
	slab.call("tick", 0.5)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check("the stone is up", bool(slab.call("is_up")))
	var round_x := [INF]
	var stone_walker := _fighter(p, Vector3(0.6, 0, -8.0))
	took = walk.call(stone_walker, 10.0, func() -> bool: return stone_walker.global_position.distance_to(p.global_position) <= 2.3,
		func(was: Vector3, now: Vector3) -> void:
			if (was.z - here.z < -4.0) != (now.z - here.z < -4.0):
				round_x[0] = now.x - here.x)
	_check("an enemy goes round standing stone to reach you", stone_walker.global_position.distance_to(p.global_position) <= 2.3 and absf(float(round_x[0])) > 1.5,
		"after %.1f s at %s, passed the slab at x %.1f" % [took, str(stone_walker.global_position - here), float(round_x[0])])
	_check("by the end that is open, not the one against the wall", float(round_x[0]) < -1.5, "x %.1f" % float(round_x[0]))
	stone_walker.free()
	p.call("drop_stones")
	world.free()

	# ---------- an archer in a pocket: every spot it can shoot from is round a corner
	here = Vector3(2600, 0, 800)
	world = baked_world.call(here, [[Vector3(0, 1, -6), Vector3(7, 2, 1)], [Vector3(-3, 1, -8.75), Vector3(1, 2, 4.5)], [Vector3(3, 1, -8.75), Vector3(1, 2, 4.5)]])
	p.global_position = here
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ar := _fighter(p, Vector3(0, 0, -9.0), "archer")
	ar.set("facing", Vector3(0, 0, 1))
	_check("in the pocket the archer cannot see you", not bool(ar.call("_sees_target")))
	var spot: Variant = ar.call("_find_vantage")
	_check("it finds a spot to shoot from that it can only reach round a corner", spot != null and not bool(ar.call("_clear", ar.global_position + Vector3.UP, (spot as Vector3) + Vector3.UP)), str(spot))
	var aimed := [false]
	took = walk.call(ar, 10.0, func() -> bool: return bool(aimed[0]),
		func(_was: Vector3, _now: Vector3) -> void: aimed[0] = float(ar.get("_windup")) >= 0.0)
	var out: Vector3 = ar.global_position - here
	_check("and walks out and round to it, and draws", bool(aimed[0]) and bool(ar.call("_sees_target")) and (absf(out.x) > 3.5 or out.z < -11.0),
		"after %.1f s at %s" % [took, str(out)])
	ar.free()
	world.free()

	# ---------- a doorway that opens: the mesh is rebaked on its own, and only then do enemies use it
	here = Vector3(2600, 0, 1000)
	var gated: Node3D = _test_floor(here)
	_block(gated, here + Vector3(-16, 1, -5), Vector3(28, 2, 1))
	_block(gated, here + Vector3(16, 1, -5), Vector3(28, 2, 1))
	var bar := StaticBody3D.new()
	var bar_col := CollisionShape3D.new()
	var bar_shape := BoxShape3D.new()
	bar_shape.size = Vector3(4, 2, 0.6)
	bar_col.shape = bar_shape
	bar.add_child(bar_col)
	bar.position = here + Vector3(0, 1, -5)
	gated.add_child(bar)
	var live := LevelNav.new()                 # this one watches its level, as in the game
	gated.add_child(live)
	p.global_position = here
	var early := _fighter(p, Vector3(0, 0, -10.0))
	_check("before its first bake lands a level has no mesh, and enemies steer the old way", not live.is_ready() and early.call("_level_nav") == null)
	var waited: int = Time.get_ticks_msec()
	while not live.is_ready() and Time.get_ticks_msec() - waited < 5000:
		await get_tree().process_frame
	_check("the level bakes itself in the background", live.is_ready(), "%.0f ms" % live.bake_ms)
	var shut: PackedVector3Array = live.path(here + Vector3(0, 0, -10), here, 0.5)
	_check("with the doorway sealed there is no way through", not shut.is_empty() and NavPath.flat(shut[shut.size() - 1], here) > 3.0, str(shut))
	var seen_version: int = live.version
	bar.queue_free()
	waited = Time.get_ticks_msec()
	while live.version == seen_version and Time.get_ticks_msec() - waited < 5000:
		await get_tree().process_frame
	var open: PackedVector3Array = live.path(here + Vector3(0, 0, -10), here, 0.5)
	_check("open it and the mesh is rebaked with the doorway in it", live.version > seen_version and NavPath.flat(open[open.size() - 1], here) < 0.3 and LevelNav.length_of(open) < 10.5,
		"v%d, %s" % [live.version, str(open)])
	early.free()
	gated.free()
	p.free()
	await get_tree().process_frame


func _test_real_bodies() -> void:
	print("real character bodies (Brent 2026-10-18):")
	var w: Dictionary = GameData.wardrobe
	for sex: String in ["male", "female"]:
		var id: String = "body_" + sex
		_check("%s: the model exists" % id, RealCharacter.exists(id))
		if not RealCharacter.exists(id):
			continue
		var rc: RealCharacter = RealCharacter.create(id)
		add_child(rc)
		var meshes: Dictionary = rc.get("_mesh")
		var missing: Array[String] = []
		for piece: String in w["pieces"]:
			for m: Variant in (w["pieces"][piece] as Dictionary)["meshes"]:
				if not meshes.has(str(m)):
					missing.append(str(m))
		for style: String in w["hair"]:
			for m: Variant in w["hair"][style]:
				if not meshes.has(str(m)):
					missing.append(str(m))
		_check("%s: every wardrobe and hair mesh is in the model" % id, missing.is_empty(), str(missing))
		var ap: AnimationPlayer = rc.get("_player")
		var clips: Array[String] = ["idle", "walk", "run", "run_armed", "sprint", "sprint_armed", "slash_in", "slash_out", "slash_in_l", "slash_out_l", "heavy", "hit", "death", "cast", "cast_area", "dodge", "pickup", "throw", "power_up", "meditate"]
		var no_clip: Array[String] = []
		for c: String in clips:
			if ap == null or not ap.has_animation(c):
				no_clip.append(c)
		_check("%s: every clip the game plays is there" % id, no_clip.is_empty(), str(no_clip))
		# Brent 2026-10-22, "the arm positions when running are still bad": the clips were played on the
		# wrong rest pose (Mixamo's T-pose channels on our A-pose rig), which swung the upper arms into the
		# chest and the hands across the body (elbows were 4 cm past the middle in the run). Each elbow
		# must stay well out on its own side, and a hand may reach the middle but not cross it.
		for loop: String in ["walk", "run", "sprint", "run_armed", "sprint_armed"]:
			var clear: Vector2 = _arm_clearance(rc, loop)
			_check("%s: %s keeps the elbows out (closest %.2f m) and the hands on their own side (%.2f m)" % [id, loop, clear.x, clear.y],
				clear.x >= 0.1 and clear.y >= -0.05, str(clear))
		# a weapon in hand runs with the armed loops; empty hands with the plain ones
		_check("%s: a full-speed empty-handed body sprints" % id, _loop_at(rc, 6.5) == "sprint", _loop_at(rc, 6.5))
		rc.set_weapon(Models.weapon("serrated_dagger"))
		_check("%s: armed, it sprints with the weapon carried" % id, _loop_at(rc, 6.5) == "sprint_armed", _loop_at(rc, 6.5))
		_check("%s: armed, a run is the sword-and-shield run" % id, _loop_at(rc, 3.6) == "run_armed", _loop_at(rc, 3.6))
		rc.set_weapon(null)
		_check("%s: unarmed again, a run is the plain run" % id, _loop_at(rc, 4.0) == "run", _loop_at(rc, 4.0))
		var item_missing: Array[String] = []
		for item: String in w["items"]:
			if GameData.item(item).is_empty():
				item_missing.append(item)
		_check("wardrobe items are real items", item_missing.is_empty(), str(item_missing))
		# everyday clothes with nothing equipped; a coat replaces the tunic and hides the skin under it
		rc.apply_look({"sex": sex, "band": "off"})
		rc.set_outfit({})
		var everyday: Array[String] = ["trousers", "tunic", "wraps"]
		_check("%s: nothing equipped wears tunic, trousers, wraps" % id, rc.worn_pieces() == everyday, str(rc.worn_pieces()))
		rc.set_outfit({"body": "patched_coat", "feet": "hobnailed_boots", "head": "oilcloth_hood"})
		var worn: Array[String] = rc.worn_pieces()
		_check("%s: a coat replaces the tunic, boots the wraps" % id, worn.has("coat") and not worn.has("tunic") and worn.has("tallboots") and not worn.has("wraps"), str(worn))
		var skin: ShaderMaterial = (meshes["body"] as MeshInstance3D).material_override
		var mask: int = int(skin.get_shader_parameter("hidden_mask"))
		_check("%s: skin under the coat and boots is not drawn" % id, (mask >> 2) & 1 == 1 and (mask >> 12) & 1 == 1 and (mask >> 14) & 1 == 1 and (mask >> 0) & 1 == 0, str(mask))
		var trousers: ShaderMaterial = (meshes["cloth_trousers"] as MeshInstance3D).material_override
		_check("%s: tall boots hide the trouser shins" % id, (int(trousers.get_shader_parameter("hidden_mask")) >> 13) & 1 == 1)
		var hair_shown := false
		for m: String in meshes:
			if m.begins_with("hair_") and (meshes[m] as MeshInstance3D).visible:
				hair_shown = true
		_check("%s: a hood hides the hair" % id, not hair_shown)
		rc.set_outfit({})
		rc.apply_look({"sex": sex, "hair": "long", "face": "bearded", "body": "c"})
		_check("%s: long hair and a beard show" % id, (meshes["hair_long"] as MeshInstance3D).visible and (meshes["beard_cards"] as MeshInstance3D).visible)
		var body_mesh: MeshInstance3D = meshes["body"]
		_check("%s: a heavy build sets the heavy shape" % id, body_mesh.get_blend_shape_value(body_mesh.find_blend_shape_by_name("heavy")) > 0.9)
		rc.set_part_visible("arm_right", false)
		mask = int(skin.get_shader_parameter("hidden_mask"))
		_check("%s: a lost arm hides forearm and hand and shows the stump" % id, (mask >> 7) & 1 == 1 and (mask >> 9) & 1 == 1 and (meshes["stump_r"] as MeshInstance3D).visible)
		# anatomy shows on the bare body only; the photo skin is on by default
		rc.set_part_visible("arm_right", true)
		rc.set_bare(true)
		rc.set_outfit({})
		_check("%s: the bare body shows its anatomy" % id, meshes.has("anatomy") and (meshes["anatomy"] as MeshInstance3D).visible)
		rc.set_bare(false)
		_check("%s: trousers cover the anatomy" % id, not (meshes["anatomy"] as MeshInstance3D).visible)
		_check("%s: the skin wears its photo layer" % id, float(skin.get_shader_parameter("photo_mix")) > 0.5)
		rc.apply_look({"sex": sex, "features": "f4"})
		var face_tex: Texture2D = skin.get_shader_parameter("photo_tex")
		_check("%s: the look's features pick a generated face" % id, face_tex != null and face_tex.resource_path.ends_with("_gen_f4.jpg"), str(face_tex.resource_path if face_tex else ""))
		rc.set_barefoot(true)
		_check("%s: barefoot leaves the foot wraps off" % id, not rc.worn_pieces().has("wraps"))
		rc.set_barefoot(false)
		var coat_mat: ShaderMaterial = (meshes["cloth_tunic"] as MeshInstance3D).material_override
		_check("%s: garments carry their baked folds" % id, bool(coat_mat.get_shader_parameter("baked")))
		rc.set_part_visible("arm_right", false)
		var blade: Node3D = Models.weapon("serrated_dagger")
		rc.set_weapon(blade)
		_check("%s: with the right arm gone the weapon is in the left hand" % id, blade.get_parent() == rc.get("_hand_l"))
		rc.queue_free()


## How far the elbows and the hands of a real body stay out from its middle, each on its own side,
## over eight frames of a loop: [closest elbow, closest hand] in metres (negative = across the body).
func _arm_clearance(rc: RealCharacter, loop: String) -> Vector2:
	var sk: Skeleton3D = rc.get("_skeleton")
	var bone := func(n: String) -> Vector3:
		var i: int = sk.find_bone("mixamorig_" + n)
		if i < 0:
			i = sk.find_bone("mixamorig:" + n)
		return rc.to_local(sk.global_transform * sk.get_bone_global_pose(i).origin)
	var worst := Vector2(INF, INF)
	for k: int in 8:
		rc.pose_at(loop, -1.0, float(k) / 8.0)
		var mid: float = (bone.call("Hips") as Vector3).x
		for side: String in ["Left", "Right"]:
			var sign_x: float = signf((bone.call(side + "Arm") as Vector3).x - mid)
			worst.x = minf(worst.x, ((bone.call(side + "ForeArm") as Vector3).x - mid) * sign_x)
			worst.y = minf(worst.y, ((bone.call(side + "Hand") as Vector3).x - mid) * sign_x)
	rc.pose_at("idle", 0.0)
	return worst


## Brent 2026-10-23: "the character creation ... looks weird" in the combat guard. Menus and the town
## stand relaxed (wardrobe.json "stances": a clip built from the body's own skeleton); the field keeps
## the guard. The stand keeps the feet on the ground and the hands out by the thighs on every build.
func _test_stances() -> void:
	print("stances: a relaxed stand on menus and in town, the guard in the field (Brent 2026-10-23):")
	var places: Dictionary = (GameData.wardrobe["stances"] as Dictionary)["places"]
	_check("the data stands menus and the town relaxed, and the field in the guard", str(places.get("menu")) == "stand" and str(places.get("town")) == "stand" and str(places.get("_default")) == "idle", str(places))
	for sex: String in ["male", "female"]:
		var id: String = "body_" + sex
		if not RealCharacter.exists(id):
			continue
		var rc: RealCharacter = RealCharacter.create(id)
		add_child(rc)
		var sk: Skeleton3D = rc.get("_skeleton")
		var at := func(n: String) -> Vector3:
			var i: int = sk.find_bone("mixamorig_" + n)
			if i < 0:
				i = sk.find_bone("mixamorig:" + n)
			return rc.to_local(sk.global_transform * sk.get_bone_global_pose(i).origin)
		for build: String in ["a", "b", "c", "d"]:
			rc.apply_look({"sex": sex, "body": build})
			rc.pose_at("idle", 0.0)
			rc.pose_at("stand", 0.0)
			var rest_feet: Array[float] = []
			for b: String in ["LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase"]:
				var i: int = sk.find_bone("mixamorig_" + b)
				rest_feet.append(rc.to_local(sk.global_transform * sk.get_bone_global_rest(i).origin).y)
			var worst_foot := 0.0
			var spread := INF
			for f: float in [0.0, 0.25, 0.5, 0.75]:
				rc.pose_at("stand", -1.0, f)
				var k := 0
				for b: String in ["LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase"]:
					worst_foot = maxf(worst_foot, absf((at.call(b) as Vector3).y - rest_feet[k]))
					k += 1
				var mid: float = (at.call("Hips") as Vector3).x
				for side: String in ["Left", "Right"]:
					var hip_out: float = absf((at.call(side + "UpLeg") as Vector3).x - mid)
					spread = minf(spread, absf((at.call(side + "Hand") as Vector3).x - mid) - hip_out)
			_check("%s build %s: standing, the feet stay where the rest pose puts them on the ground (%.3f m)" % [id, build, worst_foot], worst_foot < 0.01)
			_check("%s build %s: standing, each wrist hangs outside its hip joint (%.2f m)" % [id, build, spread], spread > 0.08)
		var ap: AnimationPlayer = rc.get("_player")
		var stand: Animation = ap.get_animation("stand")
		_check("%s: the stand breathes in a seamless loop of about four seconds" % id, stand != null and stand.loop_mode == Animation.LOOP_LINEAR and absf(stand.length - 4.0) < 0.5)
		rc.queue_free()
	# a field enemy keeps its guard
	var foe: ModelRig = Models.enemy("grunt")
	add_child(foe)
	_check("a field enemy stands in the guard", not (foe is RealCharacter) or (foe as RealCharacter).still_clip() == "idle", str(foe.get("_idle_clip")))
	foe.queue_free()
	# the game: the creation turntable, the townsfolk, the player in town and then in the field
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.set("_test_mode", true)
	add_child(main)
	await get_tree().process_frame
	var creator: Node = main.get("screen")
	var turntable: Variant = creator.get("_rig") if creator is CreationScreen else null
	_check("the creation turntable plays the stand, not the guard", turntable is RealCharacter and (turntable as RealCharacter).still_clip() == "stand"
		and String(((turntable as RealCharacter).get("_player") as AnimationPlayer).current_animation) == "stand",
		str(turntable.call("still_clip")) if turntable is RealCharacter else str(turntable))
	var spec := {"talent_id": "grudge", "affinities": ["wind", "fire"], "name": "Test", "identity": "man", "look": CharacterLook.default_look(), "skills": ["cutting_gust", "flashover"]}
	main.call("begin_character", spec)
	for i: int in 4:
		await get_tree().physics_frame
	var p: Node3D = main.get("player")
	var body: Variant = p.get("_rig")
	_check("the player stands relaxed in town", body is RealCharacter and (body as RealCharacter).still_clip() == "stand", str(body.call("still_clip")) if body is RealCharacter else str(body))
	var town: TownBuilder = main.get("_town")
	_check("the townsfolk stand relaxed", not town.folk.is_empty() and town.folk.all(func(f: Townsperson) -> bool:
		var r: Variant = f.get("_rig")
		return r is RealCharacter and (r as RealCharacter).still_clip() == "stand"))
	main.call("enter_zone", "the_stubble", "dross_gate")
	for i: int in 4:
		await get_tree().physics_frame
	body = p.get("_rig")
	_check("in the field the player is back in the guard", str(main.get("state")) == "field" and body is RealCharacter and (body as RealCharacter).still_clip() == "idle",
		"%s %s" % [main.get("state"), body.call("still_clip") if body is RealCharacter else body])
	main.queue_free()
	await get_tree().process_frame


## The loop a real body picks at a ground speed (m/s).
func _loop_at(rc: RealCharacter, speed: float) -> String:
	rc.set("_one_shot", "")
	rc.animate(0.016, speed, false)
	var ap: AnimationPlayer = rc.get("_player")
	return String(ap.current_animation)


func _test_skill_tree() -> void:
	print("skill points and the skill tree (design/08, Brent 2026-10-18):")
	# every skill sits on exactly one tree, its own affinity's, and the roots are the old kits
	var placed: Dictionary = {}
	var wrong: Array[String] = []
	for aff: String in GameData.affinity_ids():
		var tree: Dictionary = GameData.skill_tree_of(aff)
		for id: String in tree:
			placed[id] = int(placed.get(id, 0)) + 1
			if str(GameData.ability(id).get("affinity", "")) != aff:
				wrong.append(id)
			for need: Variant in (tree[id] as Dictionary).get("requires", []):
				if not tree.has(str(need)):
					wrong.append("%s needs %s off its tree" % [id, str(need)])
		_check("%s: the tree's roots are its old starter kit" % aff, GameData.skill_roots([aff]) == (GameData.affinity(aff).get("kit", []) as Array), str(GameData.skill_roots([aff])))
	var unplaced: Array[String] = []
	for id: String in GameData.abilities:
		if int(placed.get(id, 0)) != 1:
			unplaced.append(id)
	_check("every ability is on exactly one tree", unplaced.is_empty(), str(unplaced))
	_check("every node is its own affinity's and needs only its own tree", wrong.is_empty(), str(wrong))

	# exactly the two picked skills, and nothing else
	var p: CharacterBody3D = _new_player("one_percent_lifesteal")
	p.call("set_affinities", ["water"])
	_check("a new character has no skill points", int(p.get("skill_points")) == int((GameData.skill_tree["points"] as Dictionary)["start"]))
	_check("picking one skill is refused", str(p.call("start_with_skills", ["water_bolt"])) != "")
	_check("picking three is refused", str(p.call("start_with_skills", ["water_bolt", "tsunami_strike", "hydraulic_flex"])) != "")
	_check("the same skill twice is refused", str(p.call("start_with_skills", ["water_bolt", "water_bolt"])) != "")
	_check("a skill of another affinity is refused", str(p.call("start_with_skills", ["water_bolt", "cinder_spit"])) != "")
	_check("a skill that is not a root is refused", str(p.call("start_with_skills", ["water_bolt", "undertow"])) != "")
	var why: String = p.call("start_with_skills", ["hydraulic_flex", "water_bolt"])
	var abilities: Array = p.get("abilities")
	var hotbar: Array = p.get("hotbar")
	_check("two roots of a held affinity are accepted", why == "", why)
	_check("the character starts with exactly the two chosen skills", abilities.size() == 2 and str(abilities[0]["id"]) == "hydraulic_flex" and str(abilities[1]["id"]) == "water_bolt",
		str(abilities))
	_check("they are on slots 1 and 2 and nothing else is on the bar", int(hotbar[0]) == 0 and int(hotbar[1]) == 1 and hotbar.slice(2).all(func(v: int) -> bool: return v == -1), str(hotbar))

	# points come from star growth, and from ascending
	var per: float = float((GameData.skill_tree["points"] as Dictionary)["per_star_pct"])
	p.call("grow_star", per - 0.1)
	_check("not quite %d%% of growth earns nothing yet" % int(per), int(p.get("skill_points")) == 0)
	p.call("grow_star", 0.2)
	_check("%d%% of star growth earns a skill point" % int(per), int(p.get("skill_points")) == 1 and _near(float(p.get("skill_growth")), 0.1, 0.001))
	var before_cap: float = (p.get("star_pct") as Array)[0]
	p.call("grow_star", 500.0)
	var grown: float = GameData.num("stars", "max_pct") - before_cap
	_check("growth stopped by the star's cap earns only for what was grown", int(p.get("skill_points")) == 1 + int((grown + 0.1) / per), "%d points" % int(p.get("skill_points")))
	var at_full: int = int(p.get("skill_points"))
	p.set("_latent_aura", 999999.0)
	p.call("try_ascend")
	_check("ascending earns its points", int(p.get("stars")) == 2 and int(p.get("skill_points")) == at_full + int((GameData.skill_tree["points"] as Dictionary)["on_ascend"]))
	p.free()

	# learning: points, money, prerequisites, affinity - and only through train_skill
	var t: CharacterBody3D = _new_player("one_percent_lifesteal")
	t.call("set_affinities", ["water"])
	t.call("start_with_skills", ["water_bolt", "tsunami_strike"])
	t.set("money", 5000)
	_check("no points: a trainer cannot teach", str(t.call("cannot_train_reason", "undertow")).contains("point"), str(t.call("cannot_train_reason", "undertow")))
	t.set("skill_points", 5)
	_check("a tier-2 skill whose root you know can be taught", str(t.call("cannot_train_reason", "undertow")) == "")
	_check("a tier-2 skill whose root you do not know cannot", str(t.call("cannot_train_reason", "backwash")).begins_with("Learn"), str(t.call("cannot_train_reason", "backwash")))
	_check("the capstone needs one of its two parents", not bool(t.call("skill_unlocked", "standing_pool")))
	_check("another affinity's skill cannot be taught at all", str(t.call("cannot_train_reason", "cinder_spit")).contains("affinity"), str(t.call("cannot_train_reason", "cinder_spit")))
	_check("nor can one you know", str(t.call("cannot_train_reason", "water_bolt")).contains("already"))
	var cost: Dictionary = t.call("skill_cost", "undertow")
	_check("train_skill teaches it", str(t.call("train_skill", "undertow")) == "" and bool(t.call("knows", "undertow")))
	_check("and spends the points and the fee", int(t.get("skill_points")) == 5 - int(cost["points"]) and int(t.get("money")) == 5000 - int(cost["price"]),
		"%d pts, $%d" % [int(t.get("skill_points")), int(t.get("money"))])
	_check("the new skill goes on the next empty slot", int((t.get("hotbar") as Array)[2]) == 2)
	_check("one parent is enough for the capstone", bool(t.call("skill_unlocked", "standing_pool")) and int((t.call("skill_cost", "standing_pool") as Dictionary)["points"]) == 2)
	t.set("skill_points", 1)
	_check("the capstone costs two points", str(t.call("cannot_train_reason", "standing_pool")).contains("point"))
	t.set("skill_points", 3)
	t.set("money", -999999)
	_check("deep in debt, nobody trains you", str(t.call("train_skill", "riptide_lash")) != "" and not bool(t.call("knows", "riptide_lash")))
	t.set("money", 5000)
	# drilling moves the bar on, never the stage
	var drill: Dictionary = GameData.skill_tree["drill"]
	_check("drilling a known skill moves its progress on", str(t.call("drill_skill", "water_bolt")) == ""
		and _near(float((t.get("abilities") as Array)[0]["progress"]), float(drill["progress"])) and int((t.get("abilities") as Array)[0]["stage"]) == 0)
	((t.get("abilities") as Array)[0] as Dictionary)["progress"] = 100.0
	_check("a full bar cannot be drilled: the stage still needs a construct", str(t.call("drill_skill", "water_bolt")) != "")
	_check("an unknown skill cannot be drilled", str(t.call("cannot_drill_reason", "backwash")) != "")
	# scrolls still teach anywhere: no points, no prerequisites, only the affinity
	t.set("skill_points", 0)
	(t.get("inventory") as Inventory).add("scroll_backwash")
	_check("a scroll still teaches a skill the tree has not opened, with no points", str(t.call("read_scroll", "scroll_backwash")) == "" and bool(t.call("knows", "backwash")))
	(t.get("inventory") as Inventory).add("scroll_stoke")
	_check("but not one of an affinity you do not hold", str(t.call("read_scroll", "scroll_stoke")) != "")

	# the tree survives a save
	t.set("skill_points", 4)
	t.set("skill_growth", 3.25)
	var data: Dictionary = JSON.parse_string(JSON.stringify(t.call("to_save")))
	var back: CharacterBody3D = _new_player()
	back.call("from_save", data)
	var ids_then: Array = (t.get("abilities") as Array).map(func(a: Dictionary) -> String: return str(a["id"]))
	var ids_now: Array = (back.get("abilities") as Array).map(func(a: Dictionary) -> String: return str(a["id"]))
	_check("save/load keeps the skills learned and nothing more", ids_now == ids_then, "%s vs %s" % [str(ids_now), str(ids_then)])
	_check("save/load keeps the bar", (back.get("hotbar") as Array) == (t.get("hotbar") as Array))
	_check("save/load keeps the skill points and the growth toward the next", int(back.get("skill_points")) == 4 and _near(float(back.get("skill_growth")), 3.25))
	t.free()
	back.free()


## The whole game, headless: character creation's spec, the town as a level, its people and
## gateways, and the rule that only a trainer teaches.
func _test_town() -> void:
	print("the town as a place (design/08):")
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.set("_test_mode", true)
	add_child(main)
	await get_tree().process_frame
	var p: Node3D = main.get("player")
	var spec := {"talent_id": "grudge", "affinities": ["wind", "fire"], "name": "Test", "identity": "man", "look": CharacterLook.default_look()}
	spec["skills"] = ["cutting_gust"]
	_check("a character cannot begin without its two skills", str(main.call("begin_character", spec.duplicate(true))) != "" and str(main.get("state")) == "select")
	spec["skills"] = ["cutting_gust", "flashover"]
	_check("a character begins with two picked roots", str(main.call("begin_character", spec.duplicate(true))) == "" and str(main.get("state")) == "town")
	var ids: Array = (p.get("abilities") as Array).map(func(a: Dictionary) -> String: return str(a["id"]))
	_check("it starts with exactly those two skills, nothing auto-assigned", ids == ["cutting_gust", "flashover"], str(ids))
	_check("the town is a place: you can walk in it", bool(p.get("active")) and main.get("screen") == null)
	var town: TownBuilder = main.get("_town")
	var roles: Array[String] = []
	for f: Townsperson in town.folk:
		roles.append(f.role)
	_check("someone does every service", ["healer", "merchant", "innkeeper", "trainer", "passage_clerk", "tempering", "corpse_clerk"].all(func(r: String) -> bool: return roles.has(r)), str(roles))
	_check("every person has a name plate", town.folk.all(func(f: Townsperson) -> bool: return f.folk_name != "" and f.find_children("*", "Label3D", false, false).size() == 1))
	var exit_ids: Array = town.exits.map(func(e: Dictionary) -> String: return str(e["id"]))
	_check("the gateways are in the town: the arena, the Dross Gate and the passage door", exit_ids.has("arena") and exit_ids.has("dross_gate") and exit_ids.has("passage"), str(exit_ids))
	var clear := true
	for where: String in (GameData.town["arrive"] as Dictionary):
		if not town.exit_at((main.get("level") as Node3D).to_global(town.arrival(where))).is_empty() or town.folk_in_reach((main.get("level") as Node3D).to_global(town.arrival(where))) != null:
			clear = false
	_check("nobody arrives standing in a gateway or on top of somebody", clear)

	# only the trainer teaches
	p.set("skill_points", 3)
	_check("away from the trainer, nothing is taught", str(main.call("train_skill", "downdraft")) != "" and not bool(p.call("knows", "downdraft")))
	main.call("open_skill_tree", true)
	_check("the tree opened anywhere else is for looking", main.get("screen") is SkillTreeScreen and not bool((main.get("screen") as Node).get("at_trainer")))
	main.call("close_screen")
	var trainer: Townsperson = town.person("trainer")
	p.global_position = trainer.global_position + Vector3(1.4, 0.0, 0.0)
	main.call("_town_interact")
	_check("walk up to the trainer and press interact: they talk", main.get("screen") is TalkScreen and str(main.get("_talking_to")) == "trainer")
	main.call("open_skill_tree", true)
	_check("from the trainer, the tree teaches", main.get("screen") is SkillTreeScreen and bool((main.get("screen") as Node).get("at_trainer")))
	_check("the trainer teaches a skill whose root you picked", str(main.call("train_skill", "downdraft")) == "" and bool(p.call("knows", "downdraft")) and int(p.get("skill_points")) == 2)
	_check("but not one whose root you did not", str(main.call("train_skill", "veil")) != "" and not bool(p.call("knows", "veil")))
	main.call("close_screen")
	_check("closing what the trainer showed goes back to talking to them", main.get("screen") is TalkScreen)
	p.global_position = trainer.global_position + Vector3(9.0, 0.0, 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("walk away and the conversation ends", main.get("screen") == null and str(main.get("_talking_to")) == "")
	_check("and the trainer's rule holds again", str(main.call("train_skill", "gale_lane")) != "")

	# every service is reachable by talking to someone
	var reached: Array[String] = []
	for role: String in roles:
		main.call("talk_to", role)
		var s: Node = main.get("screen")
		if s is TalkScreen and str(s.get("role")) == role and _has_button(s):
			reached.append(role)
		main.call("close_screen")
	_check("each person's panel opens and offers something", reached.size() == roles.size(), str(reached))
	main.call("talk_to", "merchant")
	main.call("open_shop")
	_check("the merchant shows the shop", main.get("screen") != null and (main.get("screen") as Node).get_script() == load("res://scripts/ui/shop_screen.gd"))
	main.call("close_screen")
	main.call("close_screen")
	main.call("talk_to", "tempering")
	main.call("open_tempering")
	_check("the yard master shows the tempering yard", main.get("screen") is TemperingScreen)
	main.call("close_screen")
	main.call("close_screen")
	_check("and closing everything leaves you in the street", main.get("screen") == null)

	# the gateways are places you walk to
	var level: Node3D = main.get("level")
	for gate: Dictionary in town.exits:
		if str(gate["id"]) == "arena":
			p.global_position = level.to_global(gate["centre"])
	await get_tree().process_frame
	await get_tree().process_frame
	_check("walk into the arena gate and you are in the arena", str(main.get("state")).begins_with("arena"), str(main.get("state")))
	main.call("_enter_town", "arena")
	for gate: Dictionary in (main.get("_town") as TownBuilder).exits:
		if str(gate["id"]) == "passage":
			p.global_position = (main.get("level") as Node3D).to_global(gate["centre"]) + Vector3(1.0, 0.0, 0.0)
	await get_tree().process_frame
	_check("at the passage door you are not taken in without asking", str(main.get("state")) == "town")
	p.set("money", 5000)
	main.call("_town_interact")
	_check("interact at the passage door buys a ticket and takes you in", str(main.get("state")) == "dungeon" and int(p.get("money")) == 5000 - int(main.get("ticket_price")))
	main.call("_enter_town", "passage")
	for gate: Dictionary in (main.get("_town") as TownBuilder).exits:
		if str(gate["id"]) == "dross_gate":
			p.global_position = (main.get("level") as Node3D).to_global(gate["centre"])
	await get_tree().process_frame
	await get_tree().process_frame
	_check("walk through the Dross Gate and you are out in the Stubble", str(main.get("state")) == "field", str(main.get("state")))
	main.queue_free()
	await get_tree().process_frame
	get_tree().paused = false


## A panel offers something: a service button besides Done (it may be greyed out - a healer with
## nothing to heal).
func _has_button(node: Node) -> bool:
	for b: Node in node.find_children("*", "Button", true, false):
		if b.name != "DoneButton":
			return true
	return node is TalkScreen and str(node.get("role")) == "corpse_clerk"     # nothing to fetch yet


func _test_real_enemies() -> void:
	print("real enemies (Brent 2026-10-18):")
	for kind: String in GameData.enemy_looks:
		if kind.begins_with("_"):
			continue
		var rc: RealCharacter = RealCharacter.create("body_" + str(GameData.enemy_looks[kind].get("body", "male")))
		add_child(rc)
		rc.make_enemy(GameData.enemy_looks[kind], GameData.enemies.get(kind, {}))
		var want: float = float(GameData.enemies[kind].get("height", 1.7))
		_check("%s: a real body at its height in enemies.json" % kind, absf(rc.height - want) < 0.01 and rc.scale.x > 0.5 and rc.scale.x < 2.0, "scale %.2f" % rc.scale.x)
		_check("%s: wears its costume and no everyday clothes" % kind, not rc.worn_pieces().has("tunic") and rc.worn_pieces().size() >= 3, str(rc.worn_pieces()))
		var ap: AnimationPlayer = rc.get("_player")
		rc.set_windup(true)
		var clips: Array = GameData.enemy_looks[kind].get("attack", [])
		_check("%s: a wind-up plays its attack" % kind, ap != null and clips.has(String(ap.current_animation)), String(ap.current_animation) if ap else "")
		rc.set_windup(false)
		rc.queue_free()


## Crafting step 1 (design/12; rules design/11 section 4): the data, then every rule on a bare player.
func _test_crafting() -> void:
	print("crafting step 1 (design/12):")
	var recipes: Dictionary = GameData.crafting.get("recipes", {})
	var stations: Dictionary = GameData.crafting.get("stations", {})
	_check("three skills, three stations and their band-1 recipes are loaded", recipes.size() >= 15 and stations.has("forge") and stations.has("leatherworks") and stations.has("flensing_yard"))
	# every input has a source in the live game: a remains drop, a craftsperson's stock, or another recipe
	var sold: Array = []
	for sid: String in stations:
		sold.append_array((stations[sid] as Dictionary).get("sells", []))
	var made: Array = []
	for rid: String in recipes:
		made.append_array(Crafting.outputs(rid).keys())
	var drops: Array = []
	for kind: String in GameData.enemies:
		drops.append(str(GameData.enemy(kind).get("remains", "")))
		for e: Dictionary in GameData.enemy(kind).get("loot", []):
			drops.append(str(e.get("item", "")))
	var orphans: Array[String] = []
	for rid: String in recipes:
		for id: String in ((recipes[rid] as Dictionary)["inputs"] as Dictionary):
			if GameData.item(id).is_empty() or not (sold.has(id) or made.has(id) or drops.has(id)):
				orphans.append(id)
	_check("every input of every recipe exists and has a source (drop, vendor or recipe)", orphans.is_empty(), str(orphans))
	_check("the rendering inputs drop from kills: brute hide (remains) and brute tusk (loot)", drops.has("brute_hide") and drops.has("brute_tusk"))
	_check("live item ids keep their live definitions", int(GameData.item("iron_knuckles").get("value", 0)) == 350 and str(GameData.item("iron_knuckles").get("slot", "")) == "weapon")
	_check("craft items join the item list", str(GameData.item("scraped_brute_hide").get("kind", "")) == "material" and str(GameData.item("smiths_hammer").get("kind", "")) == "tool")

	# a made-up recipe and tool for the rules, removed at the end
	recipes["r_test"] = {"output": "steel_sheet", "makes": 1, "skill": "smithing", "trivial": 60, "min_skill": 30, "tool": {"kind": "hammer", "tier": 1},
		"station": "forge", "grade": 1, "inputs": {"flux_salt": 2}, "fee": 7, "hours": 1}
	recipes["r_test_kit"] = {"output": "scraped_brute_hide", "makes": 1, "skill": "rendering", "trivial": 60, "min_skill": 0, "tool": {"kind": "flensing_knife", "tier": 1},
		"station": "flensing_yard", "grade": 1, "inputs": {"flux_salt": 2}, "fee": 25, "hours": 1}
	GameData.items["test_hammer_t3"] = {"name": "Test Hammer", "slot": "", "kind": "tool", "weight": 0.1, "value": 1, "tool": {"skill": "smithing", "kind": "hammer", "tier": 3}}
	var p: CharacterBody3D = _new_player("one_percent_lifesteal")
	var inv: Inventory = p.get("inventory")
	inv.bag.clear()
	p.set("money", 100000)
	var forge := {"station": "forge", "grade": 1, "kit": ""}
	var levels: Dictionary = p.get("craft_skill")
	(p.get("craft_known") as Array).append_array(["r_test", "r_test_kit", "r_steel_sheet", "r_binding_wire"])
	inv.add("smiths_hammer")
	inv.add("flux_salt")
	inv.add("flux_salt")

	# the attempt window: from trivial - 30
	levels["smithing"] = 29
	_check("below trivial - 30 the recipe cannot be tried", not Crafting.in_window(p, "r_test") and str(Crafting.why_not(p, "r_test", forge)).begins_with("Beyond"))
	levels["smithing"] = 30
	_check("at trivial - 30 it can", Crafting.in_window(p, "r_test") and Crafting.why_not(p, "r_test", forge) == "")
	# the success curve
	levels["smithing"] = 0
	_check("far below trivial the chance is the 5% floor", _near(Crafting.chance(p, "r_test", forge), 0.05))
	levels["smithing"] = 35
	_check("25 under trivial: 20%", _near(Crafting.chance(p, "r_test", forge), 0.20))
	levels["smithing"] = 60
	_check("at trivial: 70%", _near(Crafting.chance(p, "r_test", forge), 0.70))
	levels["smithing"] = 72
	_check("12 past trivial: 94%", _near(Crafting.chance(p, "r_test", forge), 0.94))
	inv.add("test_hammer_t3")
	_check("a better tool adds, but the chance is capped at 95% short of certainty", _near(Crafting.chance(p, "r_test", forge), 0.95))
	inv.remove("test_hammer_t3")
	levels["smithing"] = 73
	_check("at trivial + 13 it is certain", _near(Crafting.chance(p, "r_test", forge), 1.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1018
	var fails := 0
	for i: int in 200:
		inv.add("flux_salt")
		inv.add("flux_salt")
		var res: Dictionary = Crafting.combine(p, "r_test", forge, rng)
		if not bool(res.get("success", false)):
			fails += 1
		inv.remove("steel_sheet")
		(p.get("tool_uses") as Dictionary).erase("smiths_hammer")
	_check("past trivial + 13, 200 combines and not one fails", fails == 0)
	_check("and the skill does not rise at or past trivial", int(levels["smithing"]) == 73 + 1, "%d (the first success gave +1)" % int(levels["smithing"]))

	# failure: the fee goes, about half the inputs come back
	levels["smithing"] = 0
	(p.get("craft_known") as Array).append("r_test")
	var given := 0
	var back := 0
	var money_before: int = int(p.get("money"))
	var tries := 0
	while tries < 300:
		levels["smithing"] = 30                    # hold it still: the window, and the curve's floor
		inv.bag.clear()
		inv.add("smiths_hammer")
		inv.add("flux_salt")
		inv.add("flux_salt")
		var res2: Dictionary = Crafting.combine(p, "r_test", forge, rng)
		tries += 1
		if not bool(res2.get("success", true)):
			given += 2
			back += inv.bag.count("flux_salt")
		(p.get("tool_uses") as Dictionary).erase("smiths_hammer")
	var frac: float = float(back) / float(maxi(1, given))
	_check("a failure returns about half the inputs (%d of %d)" % [back, given], absf(frac - 0.5) < 0.07 and given > 200)
	_check("and the fee is paid on every combine", int(p.get("money")) == money_before - 300 * 7)

	# skill-ups: only below trivial; the first success of a recipe +1 for sure
	levels["smithing"] = 60
	_check("no skill-up chance at trivial", _near(Crafting.skillup_chance(p, "r_test", true), 0.0) and _near(Crafting.skillup_chance(p, "r_test", false), 0.0))
	levels["smithing"] = 35
	var up: float = minf(0.6, 0.35 * sqrt(25.0 / 25.0))
	_check("25 under trivial: 0.35 x sqrt(1), halved on a failure", _near(Crafting.skillup_chance(p, "r_test", true), up) and _near(Crafting.skillup_chance(p, "r_test", false), up * 0.5))
	levels["smithing"] = 0
	(recipes["r_test"] as Dictionary)["trivial"] = 200
	_check("far under trivial the chance is capped at 60%", _near(Crafting.skillup_chance(p, "r_test", true), 0.6))
	(recipes["r_test"] as Dictionary)["trivial"] = 60
	levels["smithing"] = 200
	inv.bag.clear()
	inv.add("smiths_hammer")
	inv.add("steel_billet")
	var first: Dictionary = Crafting.combine(p, "r_steel_sheet", forge, rng)
	_check("the first success of a recipe gives +1, even past its trivial", bool(first["success"]) and int(levels["smithing"]) == 201)
	inv.add("steel_billet")
	Crafting.combine(p, "r_steel_sheet", forge, rng)
	_check("the second gives nothing past trivial", int(levels["smithing"]) == 201)
	# no cap by stars (Brent 2026-10-18): one star, and the skill still reaches 300 and stops there
	levels["smithing"] = 299
	inv.add("steel_billet")
	Crafting.combine(p, "r_binding_wire", forge, rng)
	_check("a one-star character reaches 300", int(p.get("stars")) == 1 and int(levels["smithing"]) == 300)
	(p.get("craft_made") as Array).erase("r_binding_wire")
	for id: String in ["steel_rivets", "binding_wire", "binding_wire", "binding_wire", "binding_wire"]:
		inv.remove(id)
	inv.add("steel_billet")
	Crafting.combine(p, "r_binding_wire", forge, rng)
	_check("and never past it", int(levels["smithing"]) == 300)

	# tools: one use a combine, and they break
	inv.bag.clear()
	(p.get("tool_uses") as Dictionary).clear()
	inv.add("smiths_hammer")
	_check("a new tier-1 tool has 150 uses", Crafting.tool_uses_left(p, "smiths_hammer") == 150)
	inv.add("steel_billet")
	Crafting.combine(p, "r_steel_sheet", forge, rng)
	_check("a combine costs it one", Crafting.tool_uses_left(p, "smiths_hammer") == 149 and inv.bag.has("smiths_hammer"))
	(p.get("tool_uses") as Dictionary)["smiths_hammer"] = 1
	inv.add("steel_billet")
	var last: Dictionary = Crafting.combine(p, "r_steel_sheet", forge, rng)
	_check("its last use breaks it", str(last["broke"]) == "smiths_hammer" and not inv.bag.has("smiths_hammer"))
	inv.add("steel_billet")
	_check("and without one nothing can be made", str(Crafting.why_not(p, "r_steel_sheet", forge)).begins_with("You need"))
	inv.add("smiths_hammer")
	_check("a recipe you have not learned cannot be made", str(Crafting.why_not(p, "r_iron_knuckles", forge)).contains("not learned"))
	_check("nor one of another station", str(Crafting.why_not(p, "r_test_kit", forge)) != "")

	# a field kit: no fee, and nothing back from a failure
	inv.bag.clear()
	inv.add("flensing_knife")
	inv.add("flensing_kit")
	levels["rendering"] = 0
	var kit := {"station": "flensing_yard", "grade": 1, "kit": "flensing_kit"}
	var m0: int = int(p.get("money"))
	var kit_back := 0
	var kit_fails := 0
	for i: int in 40:
		levels["rendering"] = 0
		inv.add("flux_salt")
		inv.add("flux_salt")
		var r3: Dictionary = Crafting.combine(p, "r_test_kit", kit, rng)
		if not bool(r3["success"]):
			kit_fails += 1
			kit_back += inv.bag.count("flux_salt")
		for gone: String in ["flux_salt", "scraped_brute_hide", "barrow_tallow"]:
			while inv.bag.has(gone):
				inv.remove(gone)
	_check("on a field kit there is no station fee", int(p.get("money")) == m0)
	_check("and a failure there gives nothing back", kit_fails > 20 and kit_back == 0)

	# selling: the live rule, full price for everything but gear and scrolls (Brent 2026-10-18)
	_check("a made material sells at its full value", inv.sale_price("cured_hide") == int(GameData.item("cured_hide")["value"]))
	_check("a tool sells at its full value", inv.sale_price("smiths_hammer") == int(GameData.item("smiths_hammer")["value"]))
	_check("made gear sells as gear always has", inv.sale_price("iron_knuckles") == int(350 * float(GameData.items_file["gear_sell_factor"])))
	_check("tools, kits and materials are not swept up by 'sell your loot'", not Inventory.is_loot("smiths_hammer") and not Inventory.is_loot("flensing_kit") and not Inventory.is_loot("cured_hide") and Inventory.is_loot("brute_hide"))

	# teaching, and the save
	var known_before: int = (p.get("craft_known") as Array).size()
	var m1: int = int(p.get("money"))
	_check("a craftsperson teaches every recipe of the trade for a price", Crafting.teach(p, "leatherwork") == "" and (p.get("craft_known") as Array).size() == known_before + Crafting.recipes_of("leatherwork").size()
		and int(p.get("money")) == m1 - int(GameData.crafting["skills"]["leatherwork"]["teach_price"]))
	_check("and not twice", Crafting.teach(p, "leatherwork") != "")
	(p.get("tool_uses") as Dictionary)["flensing_knife"] = 77
	var data: Dictionary = JSON.parse_string(JSON.stringify(p.call("to_save")))
	var q: CharacterBody3D = _new_player()
	q.call("from_save", data)
	_check("save/load keeps crafting skills", (q.get("craft_skill") as Dictionary) == (p.get("craft_skill") as Dictionary), str(q.get("craft_skill")))
	_check("save/load keeps recipes known and made", (q.get("craft_known") as Array) == (p.get("craft_known") as Array) and (q.get("craft_made") as Array) == (p.get("craft_made") as Array))
	_check("save/load keeps tool wear", Crafting.tool_uses_left(q, "flensing_knife") == 77)
	recipes.erase("r_test")
	recipes.erase("r_test_kit")
	GameData.items.erase("test_hammer_t3")
	p.free()
	q.free()


## The whole loop in the game: render a kill's hide, tan it, smith a weapon and wear it, sell a made
## material at full price, and render in the field on a kit. Skills are set high enough that every
## combine is certain, so the scenario does not depend on the dice (the dice are _test_crafting's).
func _test_crafting_town() -> void:
	print("crafting in town (design/12):")
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.set("_test_mode", true)
	add_child(main)
	await get_tree().process_frame
	main.call("start_new_character", 0)
	var p: Node = main.get("player")
	var inv: Inventory = p.get("inventory")
	p.set("money", 20000)
	var town: TownBuilder = main.get("_town")
	for role: String in ["renderer", "tanner", "smith"]:
		_check("the %s works at a station in town" % role, town.person(role) != null and GameData.town_folk(role).has("station"))
	var levels: Dictionary = p.get("craft_skill")
	for s: String in ["rendering", "leatherwork", "smithing"]:
		levels[s] = 30

	# the renderer
	main.call("talk_to", "renderer")
	_check("away from the smith, the forge cannot be used", not bool((main.call("craft", "r_steel_billet", {"station": "forge"}) as Dictionary)["ok"]))
	main.call("open_crafting", "forge")
	_check("nor opened", not (main.get("screen") is CraftScreen))
	_check("the renderer teaches rendering", str(main.call("learn_trade", "flensing_yard")) == "")
	main.call("open_station_shop", "flensing_yard")
	_check("the renderer sells the knife and the kit", main.get("screen") != null and (main.get("screen") as Node).get_script() == load("res://scripts/ui/shop_screen.gd") and ((main.get("screen") as Node).get("stock") as Array).has("flensing_knife"))
	main.call("town_buy", "flensing_knife")
	main.call("close_screen")
	main.call("open_crafting", "flensing_yard")
	_check("talking to the renderer, the flensing yard opens", main.get("screen") is CraftScreen)
	inv.add("brute_hide")
	var r1: Dictionary = main.call("craft", "r_scraped_brute_hide", {"station": "flensing_yard"})
	_check("a brute hide renders: a scraped hide and two tallow", bool(r1["ok"]) and bool(r1["success"]) and inv.bag.count("scraped_brute_hide") == 1 and inv.bag.count("barrow_tallow") == 2 and not inv.bag.has("brute_hide"))
	var r2: Dictionary = main.call("craft", "r_barrow_quench_oil", {"station": "flensing_yard"})
	_check("tallow renders into quench oil", bool(r2["success"]) and inv.bag.count("barrow_quench_oil") == 2)
	main.call("close_screen")
	main.call("close_screen")

	# the tanner
	main.call("talk_to", "tanner")
	main.call("learn_trade", "leatherworks")
	main.call("town_buy", "curriers_knife")
	main.call("town_buy", "heartwood_tanning_liquor")
	var r3: Dictionary = main.call("craft", "r_cured_hide", {"station": "leatherworks"})
	_check("the scraped hide tans into leather", bool(r3["success"]) and inv.bag.count("cured_hide") == 9, str(r3))
	var r4: Dictionary = main.call("craft", "r_cured_hide_grip_wrap", {"station": "leatherworks"})
	_check("leather cuts into grip wraps", bool(r4["success"]) and inv.bag.count("cured_hide_grip_wrap") == 4)

	# the smith
	main.call("talk_to", "smith")
	main.call("learn_trade", "forge")
	for id: String in ["smiths_hammer", "scrap_iron", "scrap_iron", "scrap_iron", "scrap_iron", "flux_salt", "barrow_crucible", "barrow_fitting_mould"]:
		main.call("town_buy", id)
	var r5: Dictionary = main.call("craft", "r_steel_billet", {"station": "forge"})
	_check("scrap, flux and a crucible smelt into two billets", bool(r5["success"]) and inv.bag.count("steel_billet") == 2, str(r5))
	var r6: Dictionary = main.call("craft", "r_iron_knuckles", {"station": "forge"})
	_check("the smith makes Iron Knuckles from the chain", bool(r6["success"]) and inv.bag.has("iron_knuckles"), str(r6))
	_check("all three skills rose on their first successes", int(levels["rendering"]) > 30 and int(levels["leatherwork"]) > 30 and int(levels["smithing"]) > 30)
	_check("and the made knuckles can be worn", inv.equip("iron_knuckles") == "equipped" and str(inv.equipped.get("weapon", "")) == "iron_knuckles")
	var money_before: int = int(p.get("money"))
	var got: int = main.call("town_sell_item", "steel_billet")
	_check("a made billet sells at its full value", got == int(GameData.item("steel_billet")["value"]) and int(p.get("money")) == money_before + got)

	# rendering in the field, on a kit
	main.call("talk_to", "renderer")
	main.call("town_buy", "flensing_kit")
	main.call("close_screen")
	main.call("walk_out")
	for id: String in inv.bag.duplicate():
		if id == "cured_hide":
			inv.remove(id)                            # room for a hide
	inv.add("brute_hide")
	main.call("open_field_kit", "flensing_kit")
	_check("out in the field the kit opens the rendering recipes", str(main.get("state")) == "field" and main.get("screen") is CraftScreen and get_tree().paused)
	var m2: int = int(p.get("money"))
	var r7: Dictionary = main.call("craft", "r_scraped_brute_hide", {"station": "flensing_yard", "kit": "flensing_kit"})
	_check("a hide renders on the kit, with no fee", bool(r7["success"]) and int(p.get("money")) == m2)
	_check("but a kit cannot do a smith's work", not bool((main.call("craft", "r_steel_billet", {"station": "forge", "kit": "flensing_kit"}) as Dictionary)["ok"]))
	main.call("close_screen")
	get_tree().paused = false
	main.queue_free()
	await get_tree().process_frame


func _rctx(ability_id: String, stage: int) -> RuneContext:
	return RuneContext.of({"id": ability_id, "stage": stage})


## Base runes of one affinity in workbook order, optionally only those of one valence.
func _runes_of(aff: String, valence: int = -1, except: Array = []) -> Array[String]:
	var out: Array[String] = []
	var base: Dictionary = GameData.runes.get("base_runes", {})
	for id: String in base:
		if str((base[id] as Dictionary)["affinity"]) == aff and (valence < 0 or int((base[id] as Dictionary)["valence"]) == valence) and not except.has(id):
			out.append(id)
	return out


## The first pair of runes (base or universal) whose electronegativities differ by at least `lo`
## and less than `hi`; [] if the data has none.
func _pair_with_difference(lo: float, hi: float) -> Array:
	var ids: Array = (GameData.runes["base_runes"] as Dictionary).keys() + (GameData.runes["universal_runes"] as Dictionary).keys()
	for i: int in ids.size():
		for j: int in range(i + 1, ids.size()):
			var d: float = absf(BondRules.electronegativity(str(ids[i])) - BondRules.electronegativity(str(ids[j])))
			if d >= lo and d < hi:
				return [str(ids[i]), str(ids[j])]
	return []


## The smallest skill level whose word holds at least `runes` runes under these rules.
func _stage_for(rules: RuneRules, ability_id: String, runes: int) -> int:
	var s := 0
	while rules.capacity(_rctx(ability_id, s)) < runes and s < 20:
		s += 1
	return s


## Rune words (design/14 section 7, Brent 2026-10-22): the rules of bond_v1 on the workbook's real
## numbers, the save round trip, and a second rule set swapped in under the same player methods,
## save and screen. Runes are picked from the data by what they are (affinity, valence,
## electronegativity), never by name, so a revised workbook does not break the checks.
## Proves the rules compute as ruled; says nothing about whether words are fun.
func _test_runes() -> void:
	print("runes (design/14 section 7):")
	var base: Dictionary = GameData.runes.get("base_runes", {})
	var uni: Dictionary = GameData.runes.get("universal_runes", {})
	_check("runes.json names bond_v2 (seals as rings), and it is the rule set in force", str(GameData.runes.get("rule_set", "")) == "bond_v2" and Runes.active() is RingRules)
	_check("bond_v1 is still in the data and still builds (the chemistry checks below run on it)", Runes.make("bond_v1") is BondRules and not (Runes.make("bond_v1") is RingRules))
	_check("all 166 base runes and 56 universal runes are loaded", base.size() == 166 and uni.size() == 56, "%d / %d" % [base.size(), uni.size()])
	var anchored := true
	for id: String in GameData.abilities:
		var anchor_def: Dictionary = GameData.rune(GameData.skill_anchor(id))
		if anchor_def.is_empty() or str(anchor_def.get("affinity", "")) != str(GameData.ability(id).get("affinity", "")):
			anchored = false
			print("    not anchored: %s" % id)
	_check("every skill is built on a base rune of its own affinity", anchored)
	_check("universal runes carry placeholder numbers, flagged", uni.values().all(func(r: Dictionary) -> bool: return bool(r.get("placeholder", false))))

	var bond: RuneRules = Runes.make("bond_v1")
	var bk: BondRules = bond as BondRules
	# capacity by level [B]: level 0 holds 4, level 1 holds 6, two more a level
	_check("a skill of level 0 holds 4 runes, level 1 holds 6, level 2 holds 8",
		bond.capacity(_rctx("water_bolt", 0)) == 4 and bond.capacity(_rctx("water_bolt", 1)) == 6 and bond.capacity(_rctx("water_bolt", 2)) == 8)

	# valence: the anchor takes exactly its valence in bonds
	var anchor: String = GameData.skill_anchor("water_bolt")
	var aname: String = str(GameData.rune(anchor)["name"])
	var va: int = BondRules.valence(anchor)
	var water: Array[String] = _runes_of("water", -1, [anchor])
	var stage_v: int = _stage_for(bond, "water_bolt", va + 2)
	var ctxv: RuneContext = _rctx("water_bolt", stage_v)
	var w: Dictionary = RuneWord.make(anchor)
	_check("a word starts as the skill's anchor alone", RuneWord.nodes(w) == [anchor])
	var took := 0
	for k: int in va:
		if bool(bond.add(w, water[k], ctxv, 0)["ok"]):
			took += 1
	var over: Dictionary = bond.add(w, water[va], ctxv, 0)
	_check("the anchor (%s, valence %d) takes %d bonds and refuses one more" % [aname, va, va],
		took == va and str(over["reason"]) == "valence_full" and RuneWord.size(w) == va + 1, str(over))
	_check("a refusal says why", str(over["text"]).contains(aname) and str(over["text"]).contains("valence %d" % va))
	_check("a rune may be set without joining it", bool(bond.add(w, water[va], ctxv)["ok"]) and RuneWord.size(w) == va + 2)
	_check("a rune cannot join itself", str(bond.can_link(w, 1, 1, ctxv)["reason"]) == "self")
	_check("two runes join once: bonds are single", str(bond.can_link(w, 0, 1, ctxv)["reason"]) == "already_linked")
	_check("a full rune refuses another bond", str(bond.can_link(w, va + 1, 0, ctxv)["reason"]) == "valence_full")
	var nd: Dictionary = bond.describe_node(w, 1, ctxv)
	_check("a rune shows its sockets: its valence, one taken", int(nd["sockets"]) == BondRules.valence(water[0]) and int(nd["used"]) == 1)
	_check("the anchor cannot be taken out", str(bond.remove(w, 0, ctxv)["reason"]) == "anchor")
	var links_before: int = RuneWord.links(w).size()
	_check("taking a rune out takes its bonds with it", bool(bond.remove(w, 1, ctxv)["ok"]) and RuneWord.size(w) == va + 1 and RuneWord.links(w).size() == links_before - 1)
	# capacity: at level 0, loose runes go in until the word holds 4, anchor counted
	var wcap: Dictionary = RuneWord.make(anchor)
	var ctx0: RuneContext = _rctx("water_bolt", 0)
	var k2 := 0
	while k2 < water.size() and bool(bond.add(wcap, water[k2], ctx0)["ok"]):
		k2 += 1
	_check("level 0 is full at four runes, the anchor counted", RuneWord.size(wcap) == 4 and str(bond.add(wcap, water[k2], ctx0)["reason"]) == "capacity")

	# alignment on the workbook's positions
	var game_affs: Array[String] = ["water", "fire", "earth", "wind", "lightning"]
	var refusing: Array[String] = []
	var weakened: Array[String] = []
	for i: int in game_affs.size():
		for j: int in range(i + 1, game_affs.size()):
			var c: float = BondRules.affinity_alignment(game_affs[i], game_affs[j])
			if c < float(bond.params["refuse_below"]):
				refusing.append("%s-%s %.2f" % [game_affs[i], game_affs[j], c])
			elif c < float(bond.params["weaken_below"]):
				weakened.append("%s-%s %.2f" % [game_affs[i], game_affs[j], c])
	print("    the five game affinities: refuse [%s]; weakened [%s]" % [", ".join(refusing), ", ".join(weakened)])
	_check("on the workbook's numbers none of the five game affinities refuse each other", refusing.is_empty())
	_check("the alignment is the workbook's cosine (water-fire -0.097, fire-ice -0.768)",
		_near(BondRules.affinity_alignment("water", "fire"), -0.0968, 0.001) and _near(BondRules.affinity_alignment("fire", "ice"), -0.7678, 0.001))
	var fire_anchor: String = GameData.skill_anchor("cinder_spit")
	var ice: String = _runes_of("ice")[0]
	var ctxf: RuneContext = _rctx("cinder_spit", 0)
	var wf: Dictionary = RuneWord.make(fire_anchor)
	var rf: Dictionary = bond.add(wf, ice, ctxf, 0)
	_check("fire and ice refuse: an ice rune cannot be set joined to a fire skill's anchor", str(rf["reason"]) == "refused" and RuneWord.size(wf) == 1, str(rf))
	_check("set loose, it still cannot be joined to it", bool(bond.add(wf, ice, ctxf)["ok"]) and str(bond.link(wf, 0, 1, ctxf)["reason"]) == "refused")
	var expand: String = str(uni.keys()[0])
	_check("a universal rune joins anything: onto the ice rune, then onto the fire anchor",
		bool(bond.add(wf, expand, ctxf, 1)["ok"]) and bool(bond.link(wf, 2, 0, ctxf)["ok"]))
	var ww: Dictionary = RuneWord.make(anchor)
	bond.add(ww, _runes_of("fire")[0], ctx0, 0)
	_check("water and fire lean apart: their bond is shown weakened", (bond.describe_link(ww, 0, 1, ctx0)["flags"] as Array).has("weakened"))
	var kind_ww: String = bk.bond_kind(anchor, _runes_of("fire")[0])
	_check("a link's description carries its kind as its colour key", str(bond.describe_link(ww, 0, 1, ctx0)["kind"]) == kind_ww and str(bond.describe_link(ww, 0, 1, ctx0)["colour"]) == kind_ww)

	# bond kinds from the electronegativity difference (workbook: even below 0.4, polar to 1.7, ionic from 1.7)
	var even_pair: Array = _pair_with_difference(0.0, 0.39)
	var polar_pair: Array = _pair_with_difference(0.41, 1.69)
	var ionic_pair: Array = _pair_with_difference(1.71, 10.0)
	_check("a difference under 0.4 is an even bond", not even_pair.is_empty() and bk.bond_kind(str(even_pair[0]), str(even_pair[1])) == "even", str(even_pair))
	_check("between 0.4 and 1.7 it is polar", not polar_pair.is_empty() and bk.bond_kind(str(polar_pair[0]), str(polar_pair[1])) == "polar", str(polar_pair))
	_check("above 1.7 it is ionic", not ionic_pair.is_empty() and bk.bond_kind(str(ionic_pair[0]), str(ionic_pair[1])) == "ionic", str(ionic_pair))
	var at_04: Array = _pair_with_difference(0.4 - 0.0000001, 0.4 + 0.0000001)
	var at_17: Array = _pair_with_difference(1.7 - 0.0000001, 1.7 + 0.0000001)
	print("    pairs exactly on the thresholds: 0.4 %s, 1.7 %s" % [str(at_04), str(at_17)])
	_check("a difference of exactly 0.4 is polar and exactly 1.7 is ionic (where the data has such a pair)",
		(at_04.is_empty() or bk.bond_kind(str(at_04[0]), str(at_04[1])) == "polar") and (at_17.is_empty() or bk.bond_kind(str(at_17[0]), str(at_17[1])) == "ionic"))

	# closure: the anchor with a cap (valence 1) on every bond
	var caps: Array[String] = _runes_of("water", 1, [anchor])
	var stage_c: int = _stage_for(bond, "water_bolt", va + 3)
	var ctxc: RuneContext = _rctx("water_bolt", stage_c)
	var wc: Dictionary = RuneWord.make(anchor)
	for k: int in va - 1:
		bond.add(wc, caps[k % caps.size()], ctxc, 0)
	_check("one bond short, the word is open", not bool(bond.word_state(wc, ctxc)["closed"]) and str(bond.word_state(wc, ctxc)["lines"]).contains("1 open bond"))
	bond.add(wc, caps[0], ctxc, 0)
	_check("every valence filled: closed", bool(bond.word_state(wc, ctxc)["closed"]) and str(bond.word_state(wc, ctxc)["label"]).begins_with("closed"))
	bond.add(wc, caps[0], ctxc)
	bond.add(wc, caps[0], ctxc)
	bond.link(wc, va + 1, va + 2, ctxc)
	var st_split: Dictionary = bond.word_state(wc, ctxc)
	_check("every valence filled but in two pieces: not closed, and the screen is told why",
		not bool(st_split["closed"]) and not RuneWord.is_joined(wc) and str(st_split["lines"]).contains("joined"))
	_check("a word that is not locked does nothing to its skill", bond.locked_effects(wc, ctxc).is_empty() and not bond.effects(wc, ctxc).is_empty())

	# the save round trip, through JSON like a real save
	var hub: String = water[0]                # the roomiest water rune: it takes the most bonds
	for id: String in water:
		if BondRules.valence(id) > BondRules.valence(hub):
			hub = id
	var p: Node = _new_player()
	p.call("set_affinities", ["water", "fire"])
	((p.get("abilities") as Array)[0] as Dictionary)["stage"] = 2          # two rings
	p.set("test_character", true)                                          # a free edit: no binding needed
	p.call("open_free_edit", 0)
	var adds: Array = [p.call("word_add", 0, hub, 0), p.call("word_add", 0, _runes_of("fire")[0], 1),
		p.call("word_add", 0, expand, 1), p.call("word_add", 0, caps[0])]
	_check("a word is built through the player: four runes set", adds.all(func(r: Dictionary) -> bool: return bool(r["ok"])), str(adds))
	if BondRules.valence(hub) >= 4:
		p.call("word_toggle_link", 0, 1, 4)
	_check("and sealed (a test character's free edit)", bool((p.call("seal_now") as Dictionary)["ok"]))
	p.call("close_seal")
	var saved: Dictionary = p.call("ability_word", 0)
	var save_text: String = JSON.stringify(p.call("to_save"))
	var q: Node = _new_player()
	q.call("from_save", JSON.parse_string(save_text))
	var loaded: Dictionary = q.call("ability_word", 0)
	_check("a word survives save and load: the same runes, rings and links, still sealed",
		RuneWord.nodes(loaded) == RuneWord.nodes(saved) and RuneWord.links(loaded) == RuneWord.links(saved) and RuneWord.size(loaded) == 5
		and RuneWord.rings(loaded) == RuneWord.rings(saved) and RuneWord.sealed(loaded) == RuneWord.sealed(saved) and RuneWord.sealed(loaded) > 0, "%s vs %s" % [str(loaded), str(saved)])
	_check("its links come back as whole numbers", typeof((RuneWord.links(loaded)[0] as Dictionary)["a"]) == TYPE_INT)
	_check("and the rules read it the same", str(bond.word_state(loaded, q.call("rune_context", 0))) == str(bond.word_state(saved, p.call("rune_context", 0))))
	q.call("open_free_edit", 0)
	q.call("word_clear", 0)
	_check("a draft can be cleared back to its anchor", RuneWord.nodes(q.call("ability_word", 0)) == [anchor])
	q.call("close_seal")
	_check("closing the draft leaves the sealed word as it was", RuneWord.size(q.call("ability_word", 0)) == 5)

	# another rule set in force: the same player methods and save path
	var free: RuneRules = FreeRules.new()
	Runes.use(free)
	var f: Node = _new_player()
	f.call("set_affinities", ["water"])
	f.set("test_character", true)
	f.call("open_free_edit", 0)
	var fa: Array = [f.call("word_add", 0, water[0], 0), f.call("word_add", 0, water[1], 0)]
	var f3: Dictionary = f.call("word_add", 0, water[2], 0)
	_check("with the test rules in force the player's word follows them: three runes at most",
		bool(fa[0]["ok"]) and bool(fa[1]["ok"]) and str(f3["reason"]) == "capacity")
	_check("under them a rune joins anything", bool((f.call("word_toggle_link", 0, 1, 2) as Dictionary)["ok"]) and RuneWord.degree(f.call("ability_word", 0), 1) == 2)
	var fw: Dictionary = f.call("ability_word", 0)
	f.call("seal_now")
	var fdata: Dictionary = JSON.parse_string(JSON.stringify(f.call("to_save")))
	Runes.use(null)
	_check("back to the data's rule set", Runes.active() is BondRules)
	# a word bond_v1 would never allow: the anchor with one bond more than its valence
	var crowd: Array = [anchor]
	var crowd_links: Array = []
	for k: int in va + 1:
		crowd.append(water[k])
		crowd_links.append({"a": 0, "b": k + 1})
	((fdata["abilities"] as Array)[0] as Dictionary)["word"] = {"nodes": crowd, "links": crowd_links, "made_under": "free_test"}
	var g: Node = _new_player()
	g.call("from_save", fdata)
	var gw: Dictionary = g.call("ability_word", 0)
	var gs: Dictionary = Runes.active().word_state(gw, g.call("rune_context", 0))
	_check("a word made under other rules loads under bond_v2 as it was", RuneWord.size(gw) == va + 2 and RuneWord.links(gw).size() == va + 1 and str(gw.get("made_under", "")) == "free_test")
	_check("and bond_v2 reports what breaks its rules instead of failing",
		not bool(gs["closed"]) and str(gs["problems"]).contains("%s has %d bonds" % [aname, va + 1]), str(gs))
	_check("the over-full rune is badged for the screen", (Runes.active().describe_node(gw, 0, g.call("rune_context", 0))["badges"] as Array).has("over"))
	Runes.use(free)
	var h: Node = _new_player()
	h.call("from_save", JSON.parse_string(save_text))          # a fresh read: loading keeps the save's dictionaries
	var hs: Dictionary = free.word_state(h.call("ability_word", 0), h.call("rune_context", 0))
	_check("a bond_v2 word with five runes loads under the three-rune rules, reported as over capacity",
		RuneWord.size(h.call("ability_word", 0)) == 5 and str(hs["problems"]).contains("room for 3"), str(hs))
	Runes.use(null)
	_check("the test rules' word was untouched by the swap", RuneWord.size(fw) == 3 and RuneWord.links(fw).size() == 3)
	for n: Node in [p, q, f, g, h]:
		n.queue_free()

	# the screen, with each rule set in force
	var errors_before: int = _errors.count()
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.set("_test_mode", true)
	add_child(main)
	await get_tree().process_frame
	main.call("start_new_character", 0)
	var mp: Node = main.get("player")
	((mp.get("abilities") as Array)[0] as Dictionary)["progress"] = 100.0
	(mp.get("constructs") as Array).append({"tier": "vestige", "concept": "tension"})
	main.call("open_seal", 0, 0)
	var s: Node = main.get("screen")
	await get_tree().process_frame
	await get_tree().process_frame
	_check("the bind step opens the seal screen on the skill, forming ring 1", bool(s.get("rune_mode")) and s.find_children("RuneBoard", "Control", true, false).size() == 1
		and str(s.call("seal_view")) == "bind" and (mp.call("rune_context", 0) as RuneContext).forming == 1)
	var spare: Array[String] = _runes_of("water", -1, [GameData.skill_anchor(str(((mp.get("abilities") as Array)[0] as Dictionary)["id"]))])
	for rid: String in spare:
		mp.call("discover_rune", rid, "")
	s.call("place_rune", spare[0], 1, -1)
	s.call("finish_bond", 0, 1)
	_check("the view sets a rune and bonds it to the anchor", RuneWord.linked(mp.call("ability_word", 0), 0, 1))
	Runes.use(free)
	s.call("rebuild")
	await get_tree().process_frame
	s.call("place_rune", spare[1], 1, -1)
	s.call("place_rune", spare[2], 1, -1)
	_check("with the test rules in force the same view follows them: the fourth rune is refused, and it says why",
		RuneWord.size(mp.call("ability_word", 0)) == 3 and str(s.get("_rune_msg")).contains("full"), str(s.get("_rune_msg")))
	await get_tree().process_frame
	Runes.use(null)
	s.call("rebuild")
	await get_tree().process_frame
	await get_tree().process_frame
	_check("the rune view draws under either rule set without a script error", _errors.count() == errors_before, _errors.first())
	main.call("close_screen")
	main.queue_free()
	await get_tree().process_frame

	# glyphs: which characters no interface font can draw (those are drawn with the procedural mark)
	var missing: Array[String] = []
	for dict: Dictionary in [base, uni]:
		for id: String in dict:
			var ch: String = str((dict[id] as Dictionary).get("character", ""))
			if not UiDraw.has_glyph(ch):
				missing.append("%s U+%X" % [id, ch.unicode_at(0) if ch != "" else 0])
	print("    runes with no glyph in the interface fonts (%d): %s" % [missing.size(), ", ".join(missing)])
	_check("every rune has a character in the data", (base.values() + uni.values()).all(func(r: Dictionary) -> bool: return str(r.get("character", "")) != ""))


## The first rune (water, fire... or universal) whose ops satisfy `pred`, from the data.
func _rune_where(pool: Array, pred: Callable) -> String:
	for id: Variant in pool:
		if pred.call(GameData.rune(str(id))):
			return str(id)
	return ""


func _has_op(r: Dictionary, op: String, group: String = "") -> bool:
	for o: Dictionary in r.get("ops", []):
		if str(o["op"]) == op and (group == "" or str(o.get("group", "")) == group):
			return true
	return false


## A word built straight from a list of runes and links, with no rules asked (effects are worked
## out for any shape; whether it may be built or locked is the rule set's other business).
func _raw_word(ids: Array, links: Array) -> Dictionary:
	var w: Dictionary = RuneWord.make(str(ids[0]))
	for k: int in range(1, ids.size()):
		RuneWord.add_node(w, str(ids[k]))
	for l: Array in links:
		RuneWord.add_link(w, int(l[0]), int(l[1]))
	return w


func _row(fx: Dictionary, node: int) -> Dictionary:
	for r: Dictionary in fx.get("runes", []):
		if int(r["node"]) == node:
			return r
	return {}


## Rune effects, layers 1-3 (Brent 2026-10-22; workbook Bond Rules rows 19-40), on Water Bolt.
## Runes are picked from the data by what they do and how hard they pull, not by name.
func _test_rune_effects() -> void:
	print("rune effects, layers 1-3:")
	var bond: RuneRules = Runes.make("bond_v1")
	var bk: BondRules = bond as BondRules
	var fxp: Dictionary = (bond.params["interaction_params"] as Dictionary)["effects_v1"]
	var kf: Dictionary = fxp["kind_factors"]
	var anchor: String = GameData.skill_anchor("water_bolt")
	var en_a: float = BondRules.electronegativity(anchor)
	var base: Dictionary = GameData.ability("water_bolt")
	var ctx: RuneContext = _rctx("water_bolt", 3)
	var water: Array = (GameData.runes["base_runes"] as Dictionary).keys().filter(func(id: String) -> bool: return str(GameData.rune(id)["affinity"]) == "water" and id != anchor)
	var uni: Array = (GameData.runes["universal_runes"] as Dictionary).keys()
	_check("effects_v1 is the interaction bond_v1 runs", bond.interactions.size() == 1 and bond.interactions[0].id == "effects_v1")
	_check("Brent's numbers came through: fade 1 / 0.6 / 0.35 / 0.2, threshold 0.5, caps 0.4 and 2.5",
		(fxp["fade"] as Array).map(func(f: Dictionary) -> float: return float(f["strength"])) == [1.0, 0.6, 0.35, 0.2]
		and _near(float(fxp["status_threshold"]), 0.5) and _near(float(fxp["mult_min"]), 0.4) and _near(float(fxp["mult_max"]), 2.5))

	# strength fades with each bond: a chain of runes even-bonded to each other
	var evens: Array = [anchor]
	for id: String in water:
		if absf(BondRules.electronegativity(id) - BondRules.electronegativity(str(evens[evens.size() - 1]))) < 0.4 and BondRules.valence(id) >= 2 and evens.size() < 6:
			evens.append(id)
	if evens.size() < 6:
		for id: String in uni:
			if evens.size() < 6 and absf(BondRules.electronegativity(id) - BondRules.electronegativity(str(evens[evens.size() - 1]))) < 0.4:
				evens.append(id)
	var chain: Dictionary = _raw_word(evens, [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5]])
	var fx_chain: Dictionary = bond.effects(chain, ctx)
	var even_f: float = float((kf["even"] as Dictionary)["more_pull"])
	var got: Array = []
	for k: int in range(1, 6):
		got.append(snappedf(float(_row(fx_chain, k)["strength"]), 0.0001))
	_check("strength = fade x the even factor: 1, 0.6, 0.35, 0.2, and 0.2 again at five bonds",
		got == [snappedf(1.0 * even_f, 0.0001), snappedf(0.6 * even_f, 0.0001), snappedf(0.35 * even_f, 0.0001), snappedf(0.2 * even_f, 0.0001), snappedf(0.2 * even_f, 0.0001)], str(got))

	# kind factors, read from the rune's side
	var even_r: String = _rune_where(water + uni, func(r: Dictionary) -> bool: return absf(float(r["electronegativity"]) - en_a) < 0.39)
	var polar_r: String = _rune_where(water + uni, func(r: Dictionary) -> bool: return float(r["electronegativity"]) - en_a >= 0.41 and float(r["electronegativity"]) - en_a < 1.69)
	var ionic_r: String = _rune_where(water + uni, func(r: Dictionary) -> bool: return float(r["electronegativity"]) - en_a > 1.71)
	var kinds: Dictionary = _raw_word([anchor, even_r, polar_r, ionic_r], [[0, 1], [0, 2], [0, 3]])
	var fx_k: Dictionary = bond.effects(kinds, ctx)
	_check("one bond out, an even rune keeps %.2f, a polar one with more pull %.2f, an ionic one with more pull %.2f" % [float((kf["even"] as Dictionary)["more_pull"]), float((kf["polar"] as Dictionary)["more_pull"]), float((kf["ionic"] as Dictionary)["more_pull"])],
		_near(float(_row(fx_k, 1)["strength"]), float((kf["even"] as Dictionary)["more_pull"])) and str(_row(fx_k, 1)["kind"]) == "even"
		and _near(float(_row(fx_k, 2)["strength"]), float((kf["polar"] as Dictionary)["more_pull"])) and str(_row(fx_k, 2)["kind"]) == "polar"
		and _near(float(_row(fx_k, 3)["strength"]), float((kf["ionic"] as Dictionary)["more_pull"])) and str(_row(fx_k, 3)["kind"]) == "ionic", str(fx_k["runes"]))
	# the dominant side is named and marked (Brent: "the polar needs to show which side is dominant")
	var an: String = str(GameData.rune(anchor)["name"])
	var dl_p: Dictionary = bond.describe_link(kinds, 0, 2, ctx)
	var dl_i: Dictionary = bond.describe_link(kinds, 0, 3, ctx)
	var dl_e: Dictionary = bond.describe_link(kinds, 0, 1, ctx)
	_check("a polar bond names and points at the rune with more pull: \"%s\"" % str(dl_p["label"]),
		str(dl_p["label"]) == "polar: %s dominates %s" % [str(GameData.rune(polar_r)["name"]), an] and int(dl_p["dominant"]) == 2 and int(dl_p["flow"]) == 1)
	_check("an ionic one reads as a hand-over: \"%s\"" % str(dl_i["label"]),
		str(dl_i["label"]) == "ionic: %s takes %s's effect" % [str(GameData.rune(ionic_r)["name"]), an] and int(dl_i["dominant"]) == 3)
	_check("an even one has no dominant side", int(dl_e["dominant"]) == -1 and int(dl_e["flow"]) == 0 and str(dl_e["label"]).begins_with("even"))
	_check("the rune-by-rune breakdown names the side too", str(_row(fx_k, 3).get("relation", "")) == str(dl_i["label"]))
	var anchor_f: float = (float((kf["even"] as Dictionary)["less_pull"]) + float((kf["polar"] as Dictionary)["less_pull"]) + float((kf["ionic"] as Dictionary)["less_pull"])) / 3.0
	_check("the anchor's own factor is its side of each bond, averaged", _near(float((fx_k["anchor"] as Dictionary)["factor"]), anchor_f))
	# the ionic anchor loses its signature: Water Bolt joined only to a rune that pulls far harder
	var p: Node = _new_player()
	p.call("set_affinities", ["water"])
	((p.get("abilities") as Array)[0] as Dictionary)["stage"] = 3
	p.set("test_character", true)
	p.call("open_free_edit", 0)
	var lone: Dictionary = p.call("word_add", 0, ionic_r, 0)
	var pv: Dictionary = p.call("rune_preview", 0)
	_check("bonded ionically to a rune with more pull, Water Bolt loses its shove (%s)" % str(GameData.rune(ionic_r)["name"]),
		bool(lone["ok"]) and _near(float(((pv["before"] as Dictionary)["on_hit"] as Dictionary)["shove"]), float((base["on_hit"] as Dictionary)["shove"]))
		and _near(float(((pv["after"] as Dictionary)["on_hit"] as Dictionary).get("shove", 0.0)), 0.0), str((pv["after"] as Dictionary)["on_hit"]))

	# caps
	var power_r: String = _rune_where(uni, func(r: Dictionary) -> bool: return (r["ops"] as Array).size() == 1 and _has_op(r, "mul", "power") and float((r["ops"] as Array)[0].get("value", 1.0)) > 1.2 and float(r["electronegativity"]) > en_a + 0.4)
	var five: Dictionary = _raw_word([anchor, power_r, power_r, power_r, power_r, power_r], [[0, 1], [0, 2], [0, 3], [0, 4], [0, 5]])
	_check("five power runes would pass the cap; the group stops at %.1f" % float(fxp["mult_max"]), _near(float((bond.effects(five, ctx)["groups"] as Dictionary)["power"]), float(fxp["mult_max"])),
		"%s: %s" % [power_r, str(bond.effects(five, ctx)["groups"])])
	var shrink_r: String = _rune_where(uni, func(r: Dictionary) -> bool: return (r["ops"] as Array).size() > 0 and str((r["ops"] as Array)[0]["op"]) == "mul" and str((r["ops"] as Array)[0]["group"]) == "reach" and float((r["ops"] as Array)[0]["value"]) < 0.85)
	var small: Dictionary = _raw_word([anchor, shrink_r, shrink_r, shrink_r, shrink_r, shrink_r], [[0, 1], [0, 2], [0, 3], [0, 4], [0, 5]])
	_check("and cannot fall below %.1f" % float(fxp["mult_min"]), _near(float((bond.effects(small, ctx)["groups"] as Dictionary)["reach"]), float(fxp["mult_min"])))

	# 2026-10-22: duration also lengthens the statuses a skill applies - Water Bolt's Soaked
	var dur_r: String = _rune_where(uni, func(r: Dictionary) -> bool: return (r["ops"] as Array).size() == 1 and str((r["ops"] as Array)[0]["op"]) == "mul" and str((r["ops"] as Array)[0]["group"]) == "duration" and float((r["ops"] as Array)[0]["value"]) > 1.0)
	var fx_d: Dictionary = bond.effects(_raw_word([anchor, dur_r], [[0, 1]]), ctx)
	var s_d: float = float(_row(fx_d, 1)["strength"])
	var dur_m: float = 1.0 + (float(((GameData.rune(dur_r)["ops"] as Array)[0] as Dictionary)["value"]) - 1.0) * s_d
	_check("a duration rune on a skill that applies a status lengthens the status",
		_near(float((fx_d["groups"] as Dictionary).get("duration", 1.0)), dur_m, 0.001) and (fx_d["patch"] as Array).any(func(o: Dictionary) -> bool:
			return str(o["path"]) == "on_hit.status_time_mult" and _near(float(o["value"]), dur_m, 0.001)), str(fx_d["patch"]))
	# fallback: a group a skill has nothing for gives a quarter of its change as damage (Breaker applies no status and lasts no time)
	var gust_ctx: RuneContext = _rctx("tsunami_strike", 3)
	var gust_anchor: String = GameData.skill_anchor("tsunami_strike")
	var fx_g: Dictionary = bond.effects(_raw_word([gust_anchor, dur_r], [[0, 1]]), gust_ctx)
	var s_g: float = float(_row(fx_g, 1)["strength"])
	var dur_g: float = 1.0 + (float(((GameData.rune(dur_r)["ops"] as Array)[0] as Dictionary)["value"]) - 1.0) * s_g
	_check("a duration rune on a skill with no duration and no status gives a quarter of its change as damage",
		_near(float((fx_g["groups"] as Dictionary).get("power", 1.0)), 1.0 + (dur_g - 1.0) * float(fxp["fallback_fraction"]), 0.001) and not (fx_g["groups"] as Dictionary).has("duration"), str(fx_g["groups"]))
	# 2026-10-22: a jump on any hit arcs it on to more enemies
	var jump_r: String = _rune_where(uni, func(r: Dictionary) -> bool: return _has_op(r, "jumps"))
	var fx_j: Dictionary = bond.effects(_raw_word([anchor, jump_r], [[0, 1]]), ctx)
	var s_j: float = float(_row(fx_j, 1)["strength"])
	var own_power := 1.0
	for o: Dictionary in GameData.rune(jump_r)["ops"]:
		if str(o["op"]) == "mul" and str(o["group"]) == "power":
			own_power *= 1.0 + (float(o["value"]) - 1.0) * s_j
	_check("a jump on a bolt that does not jump makes its hit arc on",
		_near(float((fx_j["groups"] as Dictionary)["power"]), own_power, 0.001)
		and (fx_j["patch"] as Array).any(func(o: Dictionary) -> bool: return str(o["path"]) == "on_hit.jumps" and int(o["value"]) >= 1), str(fx_j["patch"]))
	# and on a skill that hits nothing it falls back to damage, or here (no damage) to a cheaper cast
	var hide_ctx: RuneContext = _rctx("veil", 3)
	var fx_v: Dictionary = bond.effects(_raw_word([GameData.skill_anchor("veil"), jump_r], [[0, 1]]), hide_ctx)
	_check("a jump on a skill that hits nothing falls back", not (fx_v["patch"] as Array).any(func(o: Dictionary) -> bool: return str(o["path"]).ends_with("jumps"))
		and ((fx_v["groups"] as Dictionary).has("power") or (fx_v["groups"] as Dictionary).has("cost")), str(fx_v["groups"]))

	# a status needs strength >= the threshold (picked from every base rune: since 2026-10-22 no water rune near Surge grants one alone)
	var every: Array = (GameData.runes["base_runes"] as Dictionary).keys().filter(func(id: String) -> bool: return id != anchor) + uni
	var status_r: String = _rune_where(every, func(r: Dictionary) -> bool: return _has_op(r, "status") and (r["ops"] as Array).size() == 1 and str((r["ops"] as Array)[0]["id"]) != "soaked" and absf(float(r["electronegativity"]) - en_a) < 0.39)
	var sid: String = str(((GameData.rune(status_r)["ops"] as Array)[0] as Dictionary)["id"])
	var appends := func(fx: Dictionary) -> bool: return (fx["patch"] as Array).any(func(o: Dictionary) -> bool: return str(o["op"]) == "append" and str((o["value"] as Dictionary).get("id", "")) == sid)
	var near_fx: Dictionary = bond.effects(_raw_word([anchor, status_r], [[0, 1]]), ctx)
	var mid: String = _rune_where(every, func(r: Dictionary) -> bool: return absf(float(r["electronegativity"]) - en_a) < 0.39 and absf(float(r["electronegativity"]) - BondRules.electronegativity(status_r)) < 0.39 and str(r["id"]) != status_r)
	var far_fx: Dictionary = bond.effects(_raw_word([anchor, mid, status_r], [[0, 1], [1, 2]]), ctx)
	_check("a status rune one even bond out (strength %.2f) applies %s" % [float(_row(near_fx, 1)["strength"]), sid], bool(appends.call(near_fx)))
	_check("two even bonds out (strength %.2f, under %.2f) it does not" % [float(_row(far_fx, 2)["strength"]), float(fxp["status_threshold"])], not bool(appends.call(far_fx)) and float(_row(far_fx, 2)["strength"]) < float(fxp["status_threshold"]))

	# the test word: faster, and a status Water Bolt does not have
	var fast_r: String = _rune_where(water, func(r: Dictionary) -> bool: return _has_op(r, "mul", "speed") and int(r["valence"]) == 2 and absf(float(r["electronegativity"]) - en_a) < 0.39)
	var cap_status: String = _rune_where(water, func(r: Dictionary) -> bool: return int(r["valence"]) == 1 and _has_op(r, "status") and float(r["electronegativity"]) - en_a > 1.71)
	var cap_any: String = _rune_where(water, func(r: Dictionary) -> bool: return int(r["valence"]) == 1 and r["id"] != cap_status)
	print("    the test word: %s + %s, %s; %s on %s" % [str(GameData.rune(anchor)["name"]), str(GameData.rune(fast_r)["name"]), str(GameData.rune(cap_status)["name"]), str(GameData.rune(cap_any)["name"]), str(GameData.rune(fast_r)["name"])])
	var q: Node = _new_player()
	q.call("set_affinities", ["water"])
	var speed0: float = float(q.call("ability_stats", (q.get("abilities") as Array)[0])["speed"])
	for rid: String in [fast_r, cap_status, cap_any]:
		q.call("discover_rune", rid, "")
	_check("before its first binding a skill has no word, and none can be set", not bool((q.call("word_add", 0, fast_r, 0) as Dictionary)["ok"])
		and str((q.call("word_add", 0, fast_r, 0) as Dictionary)["reason"]) == "not_sealing" and RuneWord.size(q.call("ability_word", 0)) == 1)
	_check("nor can a seal be opened while the bar is not full", not bool((q.call("open_seal", 0, 0) as Dictionary)["ok"]))
	((q.get("abilities") as Array)[0] as Dictionary)["progress"] = 100.0
	(q.get("constructs") as Array).append({"tier": "vestige", "concept": "tension"})
	_check("a full bar and a vestige carried: the seal opens, forming ring 1", bool((q.call("open_seal", 0, 0) as Dictionary)["ok"]) and (q.call("rune_context", 0) as RuneContext).forming == 1)
	q.call("word_add", 0, fast_r, 0)
	_check("an open word cannot be sealed", str((q.call("can_bind_seal") as Dictionary)["reason"]) == "not_closed")
	q.call("word_add", 0, cap_status, 0)
	q.call("word_add", 0, cap_any, 1)
	var st0: Dictionary = (q.get("abilities") as Array)[0]
	_check("the word is closed", bool(Runes.active().word_state(q.call("ability_word", 0), q.call("rune_context", 0))["closed"]))
	_check("a draft does not touch the skill", _near(float(q.call("ability_stats", st0)["speed"]), speed0))
	var bound: String = str(q.call("bind_seal", 0.0))
	var locked_ab: Dictionary = q.call("ability_stats", st0)
	var fx_q: Dictionary = Runes.active().effects(q.call("ability_word", 0), q.call("rune_context", 0))
	var fast_row: Dictionary = _row(fx_q, 1)
	# structure v2: an ionic bond hands the weaker rune's effect to the stronger, at its strength
	var fast_s: float = float(_row(fx_q, int(fast_row["carried_to"]))["strength"]) if int(fast_row.get("carried_to", -1)) > 0 else float(fast_row["strength"])
	print("    the speed rune's effect works at x%.3f%s" % [fast_s, (" (carried by %s)" % str(fast_row["carried_by"])) if fast_row.has("carried_by") else ""])
	var speed_m: float = 1.0
	for o: Dictionary in GameData.rune(fast_r)["ops"]:
		if str(o["op"]) == "mul" and str(o["group"]) == "speed":
			speed_m = 1.0 + (float(o["value"]) - 1.0) * fast_s
	var cap_sid: String = ""
	for o: Dictionary in GameData.rune(cap_status)["ops"]:
		if str(o["op"]) == "status":
			cap_sid = str(o["id"])
	_check("the bind takes and seals the word, and the sealed word reshapes the skill: speed x%.3f, and it applies %s" % [speed_m, cap_sid],
		bound == "bound" and int(st0["stage"]) == 1 and RuneWord.sealed(q.call("ability_word", 0)) == 1 and _near(float(locked_ab["speed"]), speed0 * speed_m, 0.001)
		and ((locked_ab["on_hit"] as Dictionary).get("statuses", []) as Array).any(func(s: Dictionary) -> bool: return str(s["id"]) == cap_sid), str(locked_ab["on_hit"]))
	_check("a sealed word cannot be changed outside a binding", str((q.call("word_add", 0, cap_any, -1) as Dictionary)["reason"]) == "not_sealing")
	_check("the tooltip summary names what it does", (q.call("rune_summary", 0) as Array).size() > 0, str(q.call("rune_summary", 0)))
	var qtext: String = JSON.stringify(q.call("to_save"))
	var r2: Node = _new_player()
	r2.call("from_save", JSON.parse_string(qtext))
	_check("a sealed word survives save and load, still sealed and still shaping the skill",
		bool(r2.call("word_locked", 0)) and _near(float(r2.call("ability_stats", (r2.get("abilities") as Array)[0])["speed"]), speed0 * speed_m, 0.001))

	# a real cast: the locked Water Bolt flies faster and leaves its new status on what it hits
	var here := Vector3(-300, 0, 0)
	q.global_position = here
	var world := _test_floor(here)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var foe := _foe(q, Vector3(0, 0, -6.0))
	q.set("cursor_fixed", here + Vector3(0, 0, -6.0))
	q.set("_facing", Vector3(0, 0, -1))
	q.set("essence", 99.0)
	_cast(q, "water_bolt")
	var shot: Node3D = _bolt_of(q)
	_check("the cast bolt flies at the sealed word's speed (%.1f, not %.1f)" % [speed0 * speed_m, speed0], shot != null and _near(float(shot.get("speed")), speed0 * speed_m, 0.01), str(shot.get("speed") if shot != null else "no bolt"))
	if shot != null:
		_fly(shot)
	_check("and the target is %s" % cap_sid, int(foe.call("status_stacks", cap_sid)) > 0, str(foe.get("statuses")))
	for n: Node in [p, q, r2, foe, world]:
		n.queue_free()
	await get_tree().process_frame


## A word on rings built straight, no rules asked: ids[0] is the anchor (ring 0), rings[k] the ring
## of ids[k], links [[a, b], ...].
func _ring_word(ids: Array, rings: Array, links: Array) -> Dictionary:
	var w: Dictionary = RuneWord.make(str(ids[0]))
	for k: int in range(1, ids.size()):
		RuneWord.add_node(w, str(ids[k]), int(rings[k]))
	for l: Array in links:
		RuneWord.add_link(w, int(l[0]), int(l[1]))
	return w


## The level 2 rework of the seal test's word: Flood and Gush parted, Dry out and Slack in on ring
## 1, Settle (with Drown and Slack) and Expand on ring 2.
func _rework(s: Node) -> void:
	s.call("word_toggle_link", 0, 1, 2)      # part Flood and Gush: ring 1 reworked
	s.call("word_remove", 0, 3)              # Dry out
	s.call("word_add", 0, "WAT-8b", 1, 1)    # Slack in its place, on ring 1, off Flood
	s.call("word_add", 0, "WAT-6b", 2)       # Settle off Gush, ring 2
	s.call("word_add", 0, "WAT-4b", 4)       # Drown off Settle, ring 2
	s.call("word_add", 0, "WAT-8b", 4)       # Slack off Settle, ring 2
	s.call("word_add", 0, "UNI-05a", 1)      # Expand off Flood, ring 2
	s.call("word_toggle_link", 0, 4, 7)      # Expand and Settle


func _rings_ctx(ability_id: String, rings: int) -> RuneContext:
	var c: RuneContext = RuneContext.of({"id": ability_id, "stage": rings})
	return c


func _trait_ids(rules: RuneRules, w: Dictionary) -> Array:
	return (rules.call("shape_traits", w) as Array).map(func(t: Dictionary) -> String: return str(t["id"]))


func _first_skill_of_kind(kind: String) -> String:
	for id: String in GameData.abilities:
		if str(GameData.ability(id).get("kind", "")) == kind:
			return id
	return ""


## Structure v2 and seals (Brent 2026-10-23, design/14 section 8; Bond Rules rows 43-59): ring
## capacity, bonds only within a ring or between neighbouring rings, strength as a product along the
## path, the ionic hand-over, each shape trait, the great ring's repeat in a real cast, and the seal
## flow - only at a binding, a failed bind keeping the old word, inner rings reworked at the next.
## Runes are mostly named here (Flood, Drown, Surge, Gush...): Brent's proof is about those runes.
func _test_seals() -> void:
	print("seals and structure v2 (design/14 section 8):")
	var rules: RuneRules = Runes.make("bond_v2")
	var rr: RingRules = rules as RingRules
	var fxp: Dictionary = (rules.params["interaction_params"] as Dictionary)["effects_v2"]
	var kf: Dictionary = fxp["kind_factors"]
	var rows: Array = rules.params["rings"]
	_check("effects_v2 is the interaction bond_v2 runs, and the rings came from Bond Rules rows 47-51",
		rules.interactions.size() == 1 and rules.interactions[0].id == "effects_v2" and rows.size() == 5 and int((rows[0] as Dictionary)["adds"]) == 3)

	# ---- ring capacity
	var adds: Array = rows.map(func(r: Dictionary) -> int: return int(r["adds"]))
	var want1: int = int(adds[0])
	var want2: int = want1 + int(adds[1]) if str(rules.params.get("ring_capacity", "")) == "grows" else int(adds[1])
	var want3: int = want2 + int(adds[2]) if str(rules.params.get("ring_capacity", "")) == "grows" else int(adds[2])
	print("    ring capacity (%s): ring 1 holds %d, ring 2 %d, ring 3 %d" % [str(rules.params.get("ring_capacity", "")), rr.ring_capacity(1), rr.ring_capacity(2), rr.ring_capacity(3)])
	_check("ring 1 holds 3 runes - with the skill's own rune, Brent's 'level 0 holds 4'", rr.ring_capacity(1) == 3 and rules.capacity(_rings_ctx("water_bolt", 1)) == 4)
	_check("each later ring adds 2 (the data's reading: %d, %d)" % [want2, want3], rr.ring_capacity(2) == want2 and rr.ring_capacity(3) == want3
		and rules.capacity(_rings_ctx("water_bolt", 2)) == 1 + want1 + want2)
	var surge: String = GameData.skill_anchor("water_bolt")
	var caps: Array[String] = _runes_of("water", 1, [surge])
	var w0: Dictionary = RuneWord.make(surge)
	var no_rings: Dictionary = rules.add(w0, caps[0], _rings_ctx("water_bolt", 0), 0)
	_check("before its first binding (no rings) nothing can be set, and the screen says why", not bool(no_rings["ok"]) and str(no_rings["text"]).contains("first binding"), str(no_rings))
	var ctx1: RuneContext = _rings_ctx("water_bolt", 1)
	var w1: Dictionary = RuneWord.make(surge)
	for k: int in 3:
		rules.add(w1, caps[k % caps.size()], ctx1)
	var fourth: Dictionary = rules.add(w1, caps[0], ctx1)
	_check("ring 1 takes three and refuses a fourth", RuneWord.ring_nodes(w1, 1).size() == 3 and str(fourth["reason"]) in ["ring_full", "capacity"], str(fourth))
	_check("a ring past the skill's rings is refused", str(rules.add(RuneWord.make(surge), caps[0], ctx1, -1, 2)["reason"]) == "ring")
	var frame_skill := ""
	for id: String in GameData.abilities:
		if BondRules.valence(GameData.skill_anchor(id)) == 4:
			frame_skill = id
			break
	if frame_skill != "":
		var fa: String = GameData.skill_anchor(frame_skill)
		var fcaps: Array[String] = _runes_of(str(GameData.rune(fa)["affinity"]), 1, [fa])
		var wf: Dictionary = RuneWord.make(fa)
		for k2: int in 3:
			rules.add(wf, fcaps[k2 % fcaps.size()], _rings_ctx(frame_skill, 1), 0)
		_check("a four-bond skill rune (%s) counts as filled once ring 1 is: its first seal can close" % str(GameData.rune(fa)["name"]),
			bool(rules.word_state(wf, _rings_ctx(frame_skill, 1))["closed"]), str(rules.word_state(wf, _rings_ctx(frame_skill, 1))))

	# ---- bonds only within a ring or between rings next to each other
	var ctx3: RuneContext = _rings_ctx("water_bolt", 3)
	var links_w: Dictionary = _ring_word(["WAT-2a", "UNI-19a", "UNI-28a", "UNI-26b", "UNI-27b"], [0, 1, 2, 3, 1], [[0, 1]])
	_check("ring 1 to ring 3: refused", str(rules.can_link(links_w, 1, 3, ctx3)["reason"]) == "rings_apart", str(rules.can_link(links_w, 1, 3, ctx3)))
	_check("the skill's own rune to ring 2: refused", str(rules.can_link(links_w, 0, 2, ctx3)["reason"]) == "rings_apart")
	_check("ring 1 to ring 2, and ring 1 to ring 1: allowed", bool(rules.can_link(links_w, 1, 2, ctx3)["ok"]) and bool(rules.can_link(links_w, 1, 4, ctx3)["ok"]))
	_check("set onto a rune two rings in: refused", str(rules.add(links_w, "UNI-19b", ctx3, 1, 3)["reason"]) == "rings_apart")
	var bad: Dictionary = _ring_word(["WAT-2a", "UNI-19a", "UNI-28a"], [0, 1, 3], [[0, 1], [1, 2]])
	_check("a saved word bonded across rings that do not touch is reported, not obeyed", str(rules.word_state(bad, ctx3)["problems"]).contains("do not touch"))

	# ---- strength: the ring's fade x the product of the bonds' transmissions on the strongest path
	var pj := "pressure_jet"
	var gush: String = GameData.skill_anchor(pj)
	var ctxp: RuneContext = _rings_ctx(pj, 2)
	var fade2: float = rr.ring_fade(2)
	var ionic_more: float = float((kf["ionic"] as Dictionary)["more_pull"])
	var even_more: float = float((kf["even"] as Dictionary)["more_pull"])
	var w_flood: Dictionary = _ring_word([gush, "WAT-1a", "WAT-4b"], [0, 1, 2], [[0, 1], [1, 2]])
	var fx_flood: Dictionary = rules.effects(w_flood, ctxp)
	var worked: float = fade2 * ionic_more * even_more
	print("    worked example (Pressure Jet): Drown on ring 2 -> Flood -> Gush = fade %.2f x ionic %.2f (Drown's side) x even %.2f (Flood's side) = %.3f" % [fade2, ionic_more, even_more, worked])
	_check("strength is a product along the path: Drown off Flood = %.3f (before conversion)" % worked, _near(float(_row(fx_flood, 2)["path_strength"]), worked, 0.0001), str(_row(fx_flood, 2)))
	var v1_s: float = float(_row(Runes.make("bond_v1").effects(w_flood, ctxp), 2)["strength"])
	var conv_p: Dictionary = fxp["ionic_conversion"]
	_check("the bond further in now counts: bond_v1 gave %.3f for the same rune" % v1_s, not _near(v1_s, worked, 0.0001))
	# two ways in: the stronger counts (Soak on ring 2, bonded to Flood and to Settle)
	var w_two: Dictionary = _ring_word([gush, "WAT-1a", "WAT-6b", "WAT-3a"], [0, 1, 1, 2], [[0, 1], [0, 2], [1, 3], [2, 3]])
	var rv2: RuneInteraction = rules.interactions[0]
	var via_flood: float = fade2 * float(rv2.call("_side_factor", w_two, 3, 1)) * float(rv2.call("_side_factor", w_two, 1, 0))
	var via_settle: float = fade2 * float(rv2.call("_side_factor", w_two, 3, 2)) * float(rv2.call("_side_factor", w_two, 2, 0))
	_check("of two paths the strongest counts (%.3f via Flood, %.3f via Settle)" % [via_flood, via_settle],
		_near(float(_row(rules.effects(w_two, ctxp), 3)["strength"]), maxf(via_flood, via_settle), 0.0001) and not _near(via_flood, via_settle, 0.001))

	# ---- ionic really transfers: Flood's effect leaves it and Drown carries it
	var flood_row: Dictionary = _row(fx_flood, 1)
	var drown_row: Dictionary = _row(fx_flood, 2)
	var reach_m: float = 1.0
	# Drown's strength once Flood's is converted into it (Bond Rules rows 71-72)
	var drown_s: float = minf(float(conv_p["cap"]), worked + float(flood_row["path_strength"]) * float(conv_p["rate"]))
	for o: Dictionary in GameData.rune("WAT-1a")["ops"]:
		if str(o["op"]) == "mul" and str(o["group"]) == "reach":
			reach_m = 1.0 + (float(o["value"]) - 1.0) * drown_s
	_check("ionic: Flood's whole effect leaves it (it is carried by Drown)", int(flood_row.get("carried_to", -1)) == 2 and (flood_row["used"] as Array).is_empty())
	_check("and Drown carries it at Drown's converted strength %.3f: reach x%.3f, not Flood's own x%.3f" % [drown_s, reach_m, 1.0 + 0.2 * float(flood_row["strength"])],
		_near(float((fx_flood["groups"] as Dictionary).get("reach", 1.0)), reach_m, 0.0005) and str(drown_row["used"]).contains("from Flood"), str(fx_flood["groups"]))
	_check("the panel says what was carried where", (fx_flood["transfers"] as Array).size() == 1 and str((fx_flood["transfers"] as Array)[0]["text"]).contains("carried by Drown"))
	# the skill's own rune on the weak side loses its nature, and nothing carries it
	var w_self: Dictionary = _ring_word([gush, "WAT-4b"], [0, 1], [[0, 1]])
	var fx_self: Dictionary = rules.effects(w_self, ctxp)
	_check("the skill's own rune losing an ionic bond loses its nature (factor 0), as before",
		_near(float((fx_self["anchor"] as Dictionary)["factor"]), 0.0) and (fx_self["transfers"] as Array).is_empty())

	# ---- Brent's proof: three Drown words on Pressure Jet
	var w_surge: Dictionary = _ring_word([gush, "WAT-2a", "WAT-4b"], [0, 1, 2], [[0, 1], [1, 2]])
	var fx_surge: Dictionary = rules.effects(w_surge, ctxp)
	var base_pj: Dictionary = GameData.ability(pj).duplicate(true)
	var words3: Array = [["on the skill", fx_self], ["off Flood", fx_flood], ["off Surge", fx_surge]]
	var after3: Array = []
	for pair: Array in words3:
		var ab: Dictionary = base_pj.duplicate(true)
		PlayerScript.apply_rune_patch(ab, (pair[1] as Dictionary)["patch"])
		after3.append(ab)
		var dr: Dictionary = _row(pair[1], RuneWord.size(w_self) - 1 if pair[0] == "on the skill" else 2)
		print("    Drown %-12s strength %.3f | damage %.2f -> %.2f | shove %.2f -> %.2f | range %.2f -> %.2f | statuses %s | interrupts %s | carries %s" % [
			str(pair[0]), float(dr["strength"]), float((base_pj["on_hit"] as Dictionary)["damage"]), float((ab["on_hit"] as Dictionary).get("damage", 0.0)),
			float((base_pj["on_hit"] as Dictionary)["shove"]), float((ab["on_hit"] as Dictionary).get("shove", 0.0)), float(base_pj["range"]), float(ab["range"]),
			str(((ab["on_hit"] as Dictionary).get("statuses", []) as Array).map(func(s: Dictionary) -> String: return str(s["id"]))),
			str((ab["on_hit"] as Dictionary).get("interrupts", false)), str(dr.get("carries", []))])
	_check("Drown off Flood carries Flood's reach and Soaked; off Surge it carries Surge's shove instead",
		float((after3[1] as Dictionary)["range"]) > float(base_pj["range"]) + 0.01 and str((after3[1] as Dictionary)["on_hit"]).contains("soaked")
		and float(((after3[2] as Dictionary)["on_hit"] as Dictionary)["shove"]) > float((base_pj["on_hit"] as Dictionary)["shove"]) + 0.01
		and not str((after3[2] as Dictionary)["on_hit"]).contains("soaked") and _near(float((after3[2] as Dictionary)["range"]), float(base_pj["range"])))
	_check("and Drown on the skill itself is a third result: full strength, Gush's nature lost",
		_near(float(_row(fx_self, 1)["path_strength"]), ionic_more) and str(after3[0]) != str(after3[1]) and str(after3[0]) != str(after3[2]) and str(after3[1]) != str(after3[2]))

	# ---- shape traits
	var bolt := "water_bolt"
	var t_word: Dictionary = _ring_word([surge, "WAT-1a", "WAT-6b", "WAT-3a", "WAT-5a", "WAT-4b"], [0, 1, 1, 1, 2, 3],
		[[0, 1], [0, 2], [1, 3], [1, 2], [2, 3], [2, 4], [4, 5]])
	var t_ids: Array = _trait_ids(rules, t_word)
	var fx_t: Dictionary = rules.effects(t_word, ctx3)
	var tdefs: Dictionary = fxp["shape_traits"]
	var closed_m: float = float(((tdefs["closed_ring"] as Dictionary)["ops"] as Array)[0]["value"])
	_check("closed ring: Flood, Settle and Soak bonded round ring 1 is a closed ring, and the skill lasts longer (duration x%.2f)" % closed_m,
		t_ids.has("closed_ring") and _near(float((fx_t["groups"] as Dictionary).get("duration", 1.0)), closed_m, 0.0005), "%s %s" % [str(t_ids), str(fx_t["groups"])])
	var open_ring: Dictionary = t_word.duplicate(true)
	RuneWord.remove_link(open_ring, 1, 3)
	_check("part one bond round it and it is no longer closed", not _trait_ids(rules, open_ring).has("closed_ring") and not (rules.effects(open_ring, ctx3)["groups"] as Dictionary).has("duration"))
	var spoke_m: float = float(((tdefs["spoke"] as Dictionary)["ops"] as Array)[0]["value"])
	var no_spoke: Dictionary = _ring_word([surge, "WAT-1a", "WAT-6b", "WAT-3a", "WAT-5a"], [0, 1, 1, 1, 2], [[0, 1], [0, 2], [1, 3], [1, 2], [2, 3], [2, 4]])
	var speed_spoke: float = float((fx_t["groups"] as Dictionary).get("speed", 1.0))
	var speed_two: float = float((rules.effects(no_spoke, ctx3)["groups"] as Dictionary).get("speed", 1.0))
	_check("spoke: Settle -> Gush -> Drown out through three rings is a spoke; two rings is not", t_ids.has("spoke") and not _trait_ids(rules, no_spoke).has("spoke"))
	_check("and it reaches further and faster: x%.2f per ring past the second" % spoke_m,
		str(fx_t["traits"]).contains("Spoke") and speed_spoke > speed_two, "%f vs %f" % [speed_spoke, speed_two])
	var hubs: Dictionary = _ring_word([surge, "UNI-19a", "UNI-28a", "UNI-26b", "UNI-27b", "UNI-21a", "UNI-01a", "UNI-11a"], [0, 1, 1, 1, 2, 2, 2, 2],
		[[0, 1], [0, 2], [0, 3], [1, 2], [2, 3], [3, 1], [1, 4], [2, 5], [3, 6], [4, 5], [5, 6], [6, 7], [7, 4]])
	var branch_t: Dictionary = {}
	for t: Dictionary in rules.call("shape_traits", hubs):
		if str(t["id"]) == "branch":
			branch_t = t
	_check("branch: six runes with three or more bonds count as %d (capped)" % int((tdefs["branch"] as Dictionary)["max_count"]),
		not branch_t.is_empty() and (branch_t["nodes"] as Array).size() == 6 and int(branch_t["count"]) == int((tdefs["branch"] as Dictionary)["max_count"]), str(branch_t))
	var bal_ctx: RuneContext = _rings_ctx(bolt, 1)
	var polar_r: String = "WAT-6b"
	var bal: Dictionary = _ring_word([surge, polar_r, polar_r, polar_r], [0, 1, 1, 1], [[0, 1], [0, 2], [0, 3]])
	var unbal: Dictionary = _ring_word([surge, polar_r, polar_r], [0, 1, 1], [[0, 1], [0, 2]])
	var fx_bal: Dictionary = rules.effects(bal, bal_ctx)
	var fx_unbal: Dictionary = rules.effects(unbal, bal_ctx)
	_check("balanced: ring 1 full, every bond to the skill the same kind - the skill's own rune keeps all its nature (x%.2f, against x%.2f with ring 1 not full)" % [
		float((fx_bal["anchor"] as Dictionary)["factor"]), float((fx_unbal["anchor"] as Dictionary)["factor"])],
		_trait_ids(rules, bal).has("balanced") and _near(float((fx_bal["anchor"] as Dictionary)["factor"]), 1.0) and float((fx_unbal["anchor"] as Dictionary)["factor"]) < 1.0)
	# the great ring
	var great: Dictionary = _ring_word([surge, "WAT-1a", "UNI-19a", "UNI-28a", "UNI-26b", "UNI-27b", "UNI-21a"], [0, 1, 2, 2, 2, 2, 2],
		[[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 2]])
	var fx_great: Dictionary = rules.effects(great, _rings_ctx(bolt, 2))
	var rep_patch: Array = (fx_great["patch"] as Array).filter(func(o: Dictionary) -> bool: return str(o["path"]) == "rune_repeat")
	_check("great ring: a closed ring of five makes a bolt repeat once at %d%%" % int(round(float((tdefs["great_ring"] as Dictionary)["mult"]) * 100.0)),
		_trait_ids(rules, great).has("great_ring") and rep_patch.size() == 1 and _near(float((rep_patch[0]["value"] as Dictionary)["mult"]), float((tdefs["great_ring"] as Dictionary)["mult"])), str(rep_patch))
	var four: Dictionary = _ring_word([surge, "WAT-1a", "UNI-19a", "UNI-28a", "UNI-26b", "UNI-27b"], [0, 1, 2, 2, 2, 2], [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 2]])
	_check("a closed ring of four is closed but not great", _trait_ids(rules, four).has("closed_ring") and not _trait_ids(rules, four).has("great_ring"))
	var dash_id: String = _first_skill_of_kind("dash")
	var fx_dash: Dictionary = rules.effects(_ring_word([GameData.skill_anchor(dash_id), "UNI-19b", "UNI-19a", "UNI-28a", "UNI-26b", "UNI-27b", "UNI-21a"], [0, 1, 2, 2, 2, 2, 2],
		[[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 2]]), _rings_ctx(dash_id, 2))
	_check("a dash cannot repeat: its great ring falls back to damage", not str(fx_dash["patch"]).contains("rune_repeat") and str(fx_dash["traits"]).contains("cannot repeat"), str(fx_dash["traits"]))

	# the repeat in a real cast: a test character seals a great ring on Water Bolt and casts it
	var here := Vector3(-340, 0, 0)
	var floor_n := _test_floor(here)
	var g: Node = _new_player()
	g.global_position = here
	g.call("set_affinities", ["water"])
	g.set("test_character", true)
	var gi := -1
	for i: int in (g.get("abilities") as Array).size():
		if str((g.get("abilities") as Array)[i]["id"]) == bolt:
			gi = i
	((g.get("abilities") as Array)[gi] as Dictionary)["stage"] = 2
	g.call("open_free_edit", gi)
	var steps: Array = [g.call("word_add", gi, "WAT-5a", 0), g.call("word_add", gi, "WAT-1a", 1), g.call("word_add", gi, "UNI-19a", 2),
		g.call("word_add", gi, "UNI-28a", 3), g.call("word_add", gi, "UNI-26b", 4), g.call("word_add", gi, "UNI-27b", 5), g.call("word_toggle_link", gi, 6, 2)]
	_check("a great ring is built by the free edit's rules (Gush on ring 1, Flood and four universal runes round ring 2)",
		steps.all(func(r: Dictionary) -> bool: return bool(r["ok"])) and _trait_ids(Runes.active(), g.call("ability_word", gi)).has("great_ring"), str(steps))
	g.call("seal_now")
	g.call("close_seal")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var foe := _foe(g, Vector3(0, 0, -6.0))
	g.set("cursor_fixed", here + Vector3(0, 0, -6.0))
	g.set("_facing", Vector3(0, 0, -1))
	g.set("essence", 99.0)
	var bolts := func() -> int: return g.get_parent().get_children().filter(func(n: Node) -> bool: return n.get("shooter") == g and n.has_method("tick") and not n.is_queued_for_deletion()).size()
	_cast(g, bolt)
	var first_n: int = bolts.call()
	var timers: Array = g.get_parent().get_children().filter(func(n: Node) -> bool: return n is SkillTimer)
	for t2: Node in timers:
		t2.call("tick", float(GameData.runes["rule_sets"]["bond_v2"]["interaction_params"]["effects_v2"]["repeat"]["delay_s"]) + 0.05)
	_check("the sealed great ring repeats the cast: one bolt, then a second", first_n == 1 and int(bolts.call()) == 2, "%d then %d" % [first_n, int(bolts.call())])

	# ---- the seal flow: only at a binding; a failed bind keeps the word; inner rings reworked later
	var s: Node = _new_player()
	s.call("set_affinities", ["water"])
	var st: Dictionary = (s.get("abilities") as Array)[0]
	for rid: String in ["WAT-1a", "WAT-3b", "WAT-5a", "WAT-6b", "WAT-4b", "WAT-8b", "UNI-05a"]:
		s.call("discover_rune", rid, "")
	st["progress"] = 100.0
	(s.get("constructs") as Array).append({"tier": "vestige", "concept": "reach"})
	s.call("open_seal", 0, 0)
	s.call("word_add", 0, "WAT-1a", 0)       # Flood
	s.call("word_add", 0, "WAT-5a", 0)       # Gush
	s.call("word_add", 0, "WAT-3b", 1)       # Dry
	s.call("word_toggle_link", 0, 1, 2)
	_check("a closed first seal binds", str(s.call("bind_seal", 0.0)) == "bound" and RuneWord.sealed(s.call("ability_word", 0)) == 1)
	var ring1: String = RuneWord.shape_key(s.call("ability_word", 0))
	st["progress"] = 100.0
	(s.get("constructs") as Array).append({"tier": "remnant", "concept": "tension"})
	s.call("open_seal", 0, 0)
	_check("the next seal opens on the sealed word, with room for ring 2", RuneWord.shape_key(s.call("ability_word", 0)) == ring1 and (s.call("rune_context", 0) as RuneContext).forming == 2)
	_rework(s)
	_check("the reworked draft is closed", bool(Runes.active().word_state(s.call("ability_word", 0), s.call("rune_context", 0))["closed"]))
	var hurt0: int = (s.get("body") as Body).wounds.size()
	var failed: String = str(s.call("bind_seal", 0.99))
	_check("a failed bind forms no seal: the word stays as it was, the construct is gone",
		failed == "failed" and RuneWord.shape_key(s.call("ability_word", 0)) == ring1 and RuneWord.sealed(s.call("ability_word", 0)) == 1
		and int(st["stage"]) == 1 and (s.get("constructs") as Array).is_empty() and (s.get("body") as Body).wounds.size() > hurt0, failed)
	(s.get("constructs") as Array).append({"tier": "remnant", "concept": "tension"})
	s.call("open_seal", 0, 0)
	_rework(s)
	var reworked: Dictionary = (s.call("ability_word", 0) as Dictionary).duplicate(true)
	var second: String = str(s.call("bind_seal", 0.0))
	var w2: Dictionary = s.call("ability_word", 0)
	_check("the level 2 seal reworks ring 1 (Dry out, Slack in, Flood and Gush parted) and adds ring 2",
		second == "bound" and RuneWord.sealed(w2) == 2 and RuneWord.shape_key(w2) == RuneWord.shape_key(reworked) and not RuneWord.nodes(w2).has("WAT-3b")
		and RuneWord.ring_nodes(w2, 2).size() == 4 and not RuneWord.linked(w2, 1, 2), str(w2))
	st["progress"] = 100.0
	(s.get("constructs") as Array).append({"tier": "spirit", "concept": "reach"})
	s.set("stars", 3)
	s.call("open_seal", 0, 0)
	s.call("word_add", 0, "UNI-05a", -1, 3)
	s.call("close_seal")
	_check("a draft left without binding changes nothing", RuneWord.shape_key(s.call("ability_word", 0)) == RuneWord.shape_key(reworked))
	s.call("open_seal", 0, 0)
	_check("binding with the draft untouched keeps the word as it is", str(s.call("bind_seal", 0.0)) == "bound" and RuneWord.shape_key(s.call("ability_word", 0)) == RuneWord.shape_key(reworked) and int(st["stage"]) == 3)
	_check("a normal character has no free edit; a test character does", not bool((s.call("open_free_edit", 0) as Dictionary)["ok"]) and bool((g.call("open_free_edit", 0) as Dictionary)["ok"]))
	for n: Node in [g, s, foe, floor_n]:
		n.queue_free()
	await get_tree().process_frame


## Strength on on/off effects and ionic conversion (Brent 2026-10-23, Bond Rules rows 62-74): a
## status lasts base x strength up to the cap, a full 1.0 of strength above 1 adds a stack where the
## status stacks, an interrupt above the silence line also silences; and nothing is lost in an ionic
## bond - Drown takes Wave on Tidal Bore and Wave's nature becomes Drown's strength (1.5 -> 2.5).
func _test_strength_rules() -> void:
	print("strength on on/off effects and ionic conversion (Bond Rules rows 62-74):")
	var rules: RuneRules = Runes.make("bond_v2")
	var fxp: Dictionary = (rules.params["interaction_params"] as Dictionary)["effects_v2"]
	var oo: Dictionary = fxp["on_off"]
	var cv: Dictionary = fxp["ionic_conversion"]
	var rv: RuneInteraction = rules.interactions[0]
	_check("rows 66-72 came through the exporter: x%.1f per strength, cap x%.1f, silence %.1f s per strength above %.1f, conversion x%.1f up to %.1f" % [
		float(oo["status_time_per_strength"]), float(oo["status_time_cap"]), float(oo["silence_s_per_strength"]), float(oo["silence_above"]), float(cv["rate"]), float(cv["cap"])],
		_near(float(oo["status_time_per_strength"]), 1.0) and _near(float(oo["status_time_cap"]), 2.5) and _near(float(oo["silence_s_per_strength"]), 1.5)
		and _near(float(oo["silence_above"]), 1.0) and _near(float(cv["rate"]), 1.0) and _near(float(cv["cap"]), 3.0) and int(oo["stack_per_strength"]) == 1
		and not GameData.status(str(oo["silence_status"])).is_empty())

	# ---- (a) the numbers
	var t15: Array = rv.call("status_time", 1.5)
	var t25: Array = rv.call("status_time", 2.5)
	var t30: Array = rv.call("status_time", 3.0)
	_check("a status lasts base x strength: x1.5 at 1.5, x2.5 at 2.5", _near(float(t15[0]), 1.5, 0.0001) and _near(float(t25[0]), 2.5, 0.0001) and not bool(t25[1]))
	_check("and no longer than the cap: x2.5 at strength 3.0 (capped)", _near(float(t30[0]), 2.5, 0.0001) and bool(t30[1]))
	var stacker := ""
	for sid: String in (GameData.get("_statuses") as Dictionary):
		if int(GameData.status(sid).get("stacks", 1)) >= 3 and not GameData.status(sid).has("alias_of"):
			stacker = sid
			break
	_check("each full 1.0 above 1 adds a stack where the status stacks (%s: +0 at 1.9, +1 at 2.5, +2 at 3.0); Dazed, which does not stack, gets none" % stacker,
		int(rv.call("extra_stacks", stacker, 1.9)) == 0 and int(rv.call("extra_stacks", stacker, 2.5)) == 1 and int(rv.call("extra_stacks", stacker, 3.0)) == 2
		and int(rv.call("extra_stacks", "dazed", 2.5)) == 0)
	_check("an interrupt above the line silences for 1.5 s per strength above it: 2.25 s at 2.5, none at 1.0",
		_near(float(rv.call("silence_s", 2.5)), 2.25, 0.0001) and _near(float(rv.call("silence_s", 1.0)), 0.0, 0.0001) and _near(float(rv.call("silence_s", 0.8)), 0.0, 0.0001))

	# ---- (b) the worked example: Drown takes Wave on Tidal Bore
	var bore := "tidal_bore"
	var wave: String = GameData.skill_anchor(bore)
	var ctx: RuneContext = _rings_ctx(bore, 1)
	var w: Dictionary = _ring_word([wave, "WAT-4b"], [0, 1], [[0, 1]])
	var fx: Dictionary = rules.effects(w, ctx)
	var drown: Dictionary = _row(fx, 1)
	print("    Tidal Bore: Drown takes %s - path strength %.2f, converted +%.2f -> %.2f (%s)" % [
		str(GameData.rune(wave)["name"]), float(drown.get("path_strength", 0.0)), float(drown.get("converted", 0.0)), float(drown.get("strength", 0.0)), str(drown.get("converted_from", ""))])
	_check("the bond is ionic and Drown takes it: Wave keeps x0 of its nature", str(drown.get("kind", "")) == "ionic" and str(drown.get("side", "")) == "more"
		and _near(float((fx["anchor"] as Dictionary)["factor"]), 0.0))
	_check("Drown's strength goes 1.5 -> 2.5: all of Wave's nature converted (x1.0)", _near(float(drown["path_strength"]), 1.5, 0.0001)
		and _near(float(drown["strength"]), 2.5, 0.0001) and _near(float(drown["converted"]), 1.0, 0.0001), str(drown))
	_check("and the panel says where it came from: \"converted from Wave's reach, stagger and carry\"",
		str(drown.get("converted_from", "")) == "converted from Wave's reach, stagger and carry", str(drown.get("converted_from", "")))
	var ab: Dictionary = GameData.ability(bore).duplicate(true)
	PlayerScript.apply_rune_patch(ab, fx["patch"])
	var hit: Dictionary = ab["on_hit"]
	var sil: Dictionary = {}
	var dazed_e: Dictionary = {}
	for e: Dictionary in hit.get("statuses", []):
		if str(e["id"]) == str(oo["silence_status"]):
			sil = e
		elif str(e["id"]) == "dazed":
			dazed_e = e
	_check("its interrupt becomes a 2.25 s silence", bool(hit.get("interrupts", false)) and _near(float(sil.get("lasts", 0.0)), 2.25, 0.0001), str(hit))
	_check("and Dazed lasts 2.5x as long (the cap)", not dazed_e.is_empty() and _near(float((hit.get("status_time_of", {}) as Dictionary).get("dazed", 0.0)), 2.5, 0.0001), str(hit))
	var dline: String = str(drown["used"])
	_check("the rune's lines say so (\"lasts x2.50\", \"silences 2.25 s\")", dline.contains("lasts x2.50") and dline.contains("silences 2.25 s"), dline)
	# the same payload through a real hit: the status engine gives each its time, nothing branches on ids
	var p := _new_player()
	var foe := _dummy_enemy(p)
	p.call("apply_hit", foe, hit, ["ability", "water"])
	var on: Dictionary = foe.get("statuses")
	var base_daze: float = float(GameData.status("dazed")["lasts"])
	var base_soak: float = float(GameData.status("soaked")["lasts"])
	print("    a real hit: Dazed %.2f s (base %.1f), Silenced %.2f s, Soaked %.2f s (base %.1f)" % [float((on.get("dazed", {}) as Dictionary).get("t", 0.0)), base_daze,
		float((on.get(str(oo["silence_status"]), {}) as Dictionary).get("t", 0.0)), float((on.get("soaked", {}) as Dictionary).get("t", 0.0)), base_soak])
	_check("a real hit: Dazed lasts %.1f s (x2.5), the silence 2.25 s, Soaked its own %.1f s" % [base_daze * 2.5, base_soak],
		_near(float((on.get("dazed", {}) as Dictionary).get("t", 0.0)), base_daze * 2.5, 0.001) and _near(float((on.get(str(oo["silence_status"]), {}) as Dictionary).get("t", 0.0)), 2.25, 0.001)
		and _near(float((on.get("soaked", {}) as Dictionary).get("t", 0.0)), base_soak, 0.001), str(on.keys()))
	_check("and silenced, it cannot start an attack", bool(foe.call("_no_attack")))
	p.queue_free()
	foe.queue_free()

	# ---- outer runes: Drown off Flood on Pressure Jet - Flood's whole effect carried, and its strength added
	var pj := "pressure_jet"
	var gush: String = GameData.skill_anchor(pj)
	var w2: Dictionary = _ring_word([gush, "WAT-1a", "WAT-4b"], [0, 1, 2], [[0, 1], [1, 2]])
	var fx2: Dictionary = rules.effects(w2, _rings_ctx(pj, 2))
	var flood: Dictionary = _row(fx2, 1)
	var drown2: Dictionary = _row(fx2, 2)
	var want2: float = float(drown2["path_strength"]) + float(flood["path_strength"]) * float(cv["rate"])
	_check("outer runes: Drown (%.3f) takes Flood (%.3f) and its strength too: %.3f, converted from Flood's reach and Soaked" % [
		float(drown2["path_strength"]), float(flood["path_strength"]), want2], int(flood.get("carried_to", -1)) == 2 and _near(float(drown2["strength"]), want2, 0.0001)
		and str(drown2.get("converted_from", "")) == "converted from Flood's reach and Soaked", str(drown2))
	_check("and the bond's description names the hand-over", str(rules.describe_link(w2, 1, 2, _rings_ctx(pj, 2)).get("hand_over", [])).contains("+0.75 strength to Drown"),
		str(rules.describe_link(w2, 1, 2, _rings_ctx(pj, 2)).get("hand_over", [])))

	# ---- the skill's own rune taken in part: it gives up only the share that bond takes
	var even_mate := ""
	for rid: String in _runes_of("water", -1, [wave, "WAT-4b"]):
		if (rules as BondRules).bond_kind(wave, rid) == "even" and (rules as BondRules).alignment_state(wave, rid) == "ok":
			even_mate = rid
			break
	if even_mate != "":
		var w3: Dictionary = _ring_word([wave, "WAT-4b", even_mate], [0, 1, 1], [[0, 1], [0, 2]])
		var fx3: Dictionary = rules.effects(w3, ctx)
		var af: float = float((fx3["anchor"] as Dictionary)["factor"])
		var kf: Dictionary = fxp["kind_factors"]
		var even_f: float = float((kf["even"] as Dictionary)["more_pull"])
		var frac: float = (1.0 - af) * 1.0 / (1.0 + (1.0 - even_f))
		_check("Wave bonded to Drown and to %s (even): it keeps x%.3f and gives Drown only the share that bond takes (+%.3f -> %.3f)" % [
			str(GameData.rune(even_mate)["name"]), af, frac, 1.5 + frac], _near(float(_row(fx3, 1)["strength"]), 1.5 + frac, 0.0001) and frac < 0.999, str(_row(fx3, 1)))

	# ---- the cap
	_check("conversion stops at the cap: 2.5 + 1.0 -> 3.0; a rune already past it keeps its own",
		_near(float(rv.call("converted_strength", 2.5, 1.0)), 3.0, 0.0001) and _near(float(rv.call("converted_strength", 3.2, 0.5)), 3.2, 0.0001)
		and _near(float(rv.call("converted_strength", 1.5, 1.0)), 2.5, 0.0001))
	# in a word: a rune on ring 1, bonded to the skill's own rune, taking the runes beside it over ionic
	# bonds - its strength plus theirs would pass the cap; it stops there
	var found := false
	var bonds := rules as BondRules
	for sid: String in GameData.abilities:
		var own: String = GameData.skill_anchor(sid)
		if found or own == "":
			continue
		var aff: String = str(GameData.rune(own).get("affinity", ""))
		for taker: String in _runes_of(aff, -1, [own]):
			if found or BondRules.valence(taker) < 2 or bonds.alignment_state(own, taker) == "refused" or BondRules.electronegativity(taker) < BondRules.electronegativity(own):
				continue
			var givers: Array[String] = []
			for giver: String in _runes_of(aff, -1, [own, taker]):
				if bonds.bond_kind(taker, giver) == "ionic" and BondRules.electronegativity(giver) < BondRules.electronegativity(taker):
					while givers.size() < BondRules.valence(taker) - 1:
						givers.append(giver)          # the same rune may be set more than once
			if givers.is_empty():
				continue
			var ids: Array = [own, taker] + givers
			var rings: Array = [0, 1]
			for gk: int in givers.size():
				rings.append(1 if gk < 2 else 2)      # ring 1 holds three: the rest go out on ring 2
			var links: Array = [[0, 1]]
			for gi: int in givers.size():
				links.append([1, 2 + gi])
			var w4: Dictionary = _ring_word(ids, rings, links)
			var r4: Dictionary = _row(rules.effects(w4, _rings_ctx(sid, 2)), 1)
			var raw: float = float(r4["path_strength"])
			for c4: Dictionary in rules.effects(w4, _rings_ctx(sid, 2)).get("conversions", []):
				raw += float(c4["amount"])
			if raw <= float(cv["cap"]) + 0.001:
				continue
			_check("in a word (%s): %s (%.2f) takes %s: %.2f before the cap; it stops at %.1f" % [str(GameData.ability(sid)["name"]),
				str(GameData.rune(taker)["name"]), float(r4["path_strength"]), str(r4.get("converted_from", "")), raw, float(cv["cap"])], _near(float(r4["strength"]), float(cv["cap"]), 0.0001) and bool(r4.get("capped", false)), str(r4))
			found = true
	if not found:
		print("    (no word in the data passes the cap - it is checked on the function only)")


# --- the seal board, driven by mouse events sent straight to it (Brent 2026-10-23: "redo the
# interface... make the bonds selectable for deletion and allow click and drag to create the bonds")

func _bpress(b: Control, at: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = true
	ev.position = at
	b.call("_gui_input", ev)


func _brelease(b: Control, at: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = false
	ev.position = at
	b.call("_gui_input", ev)


func _bmove(b: Control, at: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	b.call("_gui_input", ev)


func _bclick(b: Control, at: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	_bmove(b, at)
	_bpress(b, at, button)
	_brelease(b, at, button)


## A drag from `from` to `to` on the board, with motion in between (a real drag, not a teleport).
func _bdrag(b: Control, from: Vector2, to: Vector2) -> void:
	_bpress(b, from)
	for k: int in 6:
		_bmove(b, from.lerp(to, float(k + 1) / 6.0))
	_brelease(b, to)


func _local(b: Control, global_at: Vector2) -> Vector2:
	return b.get_global_transform().affine_inverse() * global_at


func _key(s: Node, action: String) -> void:
	var src: InputEvent = InputMap.action_get_events(action)[0]
	var ev: InputEventKey = (src as InputEventKey).duplicate()
	ev.pressed = true
	s.call("_unhandled_input", ev)


func _word_json(w: Dictionary) -> String:
	return JSON.stringify(w, "", true)


## The seal board's building controls, headless: events go straight to the board's _gui_input (the
## windowed ui_click_probe does the same through real hit-testing). One check per bug found in the
## old board (2026-10-23), so none comes back.
func _test_seal_editing() -> void:
	print("the seal board: place, bond by dragging, select, delete, undo (2026-10-23):")
	var errors_before: int = _errors.count()
	Keybinds.reset_defaults()
	var z: InputEventKey = InputMap.action_get_events("seal_undo")[0] as InputEventKey
	_check("undo and redo are InputMap actions: %s, %s; delete is %s or %s" % [Keybinds.binding_text("seal_undo"), Keybinds.binding_text("seal_redo"),
		Keybinds.binding_text("seal_delete"), Keybinds.binding_text("seal_delete_alt")], z.ctrl_pressed and z.physical_keycode == KEY_Z
		and Keybinds.binding_text("seal_delete") == "Delete" and Keybinds.binding_text("seal_delete_alt") == "Backspace")
	var plain_z := InputEventKey.new()
	plain_z.physical_keycode = KEY_Z
	plain_z.pressed = true
	var ctrl_z: InputEventKey = plain_z.duplicate()
	ctrl_z.ctrl_pressed = true
	_check("a plain Z is not undo; Ctrl+Z is", not plain_z.is_action_pressed("seal_undo") and ctrl_z.is_action_pressed("seal_undo"))

	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.set("_test_mode", true)
	add_child(main)
	await get_tree().process_frame
	main.call("start_test_character", "water")
	main.call("open_ethercosm")
	await get_tree().process_frame
	var s: Node = main.get("screen")
	s.call("open_runes")
	await get_tree().process_frame
	await get_tree().process_frame
	var p: Node = main.get("player")
	var b: RuneBoard = s.find_children("RuneBoard", "Control", true, false)[0] as RuneBoard
	var anchor: String = RuneWord.anchor(p.call("ability_word", 0))
	var links2: Array[String] = []
	var caps: Array[String] = []
	for rid: String in _runes_of("water", -1, [anchor]):
		if BondRules.valence(rid) == 1 and caps.size() < 3 and (Runes.active() as BondRules).alignment_state(anchor, rid) == "ok":
			caps.append(rid)
		elif BondRules.valence(rid) >= 2 and links2.size() < 5:
			links2.append(rid)
	var w := func() -> Dictionary: return p.call("ability_word", 0)

	# ---- place: a rune goes exactly where it is put, and alone (bugs 1 and 4)
	var place_j: int = b.empty_place(1, 1)
	var slot_at: Vector2 = b.empty_slot_global(1, 1)
	s.call("arm_rune", links2[0])
	_bclick(b, _local(b, slot_at))
	_check("a palette rune picked up, then an empty place clicked: set on that very place (bug 4: it landed elsewhere on the ring)",
		RuneWord.size(w.call()) == 2 and RuneWord.places(w.call())[1] == place_j and b.node_global(1).distance_to(slot_at) < 1.0,
		"%s vs %s" % [b.node_global(1), slot_at])
	s.call("select_node", 1)
	s.call("arm_rune", links2[1])
	_bclick(b, _local(b, b.empty_slot_global(1, 0)))
	_check("with a rune selected, a new rune is set alone - never bonded to the selection (bug 1)",
		RuneWord.size(w.call()) == 3 and RuneWord.degree(w.call(), 2) == 0 and RuneWord.links(w.call()).is_empty(), str(w.call()))
	# a palette rune carried to a place and let go there (the chip hands the cursor to the screen)
	var drop_g: Vector2 = b.empty_slot_global(2, 2)
	var drop_j: int = b.empty_place(2, 2)
	s.call("carry_move", links2[2], drop_g + Vector2(30, 10))
	var carrying: bool = b.is_carrying()
	s.call("carry_move", links2[2], drop_g)
	s.call("carry_end", links2[2], drop_g)
	_check("a palette rune carried to an empty place of ring 2 and let go is set there", carrying and not b.is_carrying() and RuneWord.size(w.call()) == 4
		and RuneWord.ring(w.call(), 3) == 2 and RuneWord.places(w.call())[3] == drop_j)

	# ---- bond by dragging (and the stale-pick bug 2: clicks only select)
	_bclick(b, _local(b, b.node_global(0)))
	_bclick(b, _local(b, b.node_global(2)))
	_check("clicking the core, then a rune, only selects them - no bond is made (bug 2: a leftover pick joined the wrong pair)",
		RuneWord.links(w.call()).is_empty() and int(s.get("picked")) == 2)
	var before_pos: Array[Vector2] = []
	for i: int in RuneWord.size(w.call()):
		before_pos.append(b.node_global(i))
	_bdrag(b, _local(b, b.node_global(0)), _local(b, b.node_global(1)))
	_check("pressing on the core and dragging to a rune bonds them, and selects the new bond", RuneWord.linked(w.call(), 0, 1) and s.get("picked_bond") == Vector2i(0, 1))
	var moved := false
	for i2: int in before_pos.size():
		if b.node_global(i2).distance_to(before_pos[i2]) > 0.5:
			moved = true
	_check("bonding moves nothing on the board (bug 5: runes jumped to sit by their partners)", not moved)
	_bdrag(b, _local(b, b.node_global(1)), _local(b, b.node_global(3)))
	_check("a rune on ring 1 dragged to one on ring 2: bonded", RuneWord.linked(w.call(), 1, 3))
	_bclick(b, _local(b, b.node_global(0)))
	_bclick(b, _local(b, b.node_global(1)))
	_check("clicking two bonded runes, one then the other, leaves their bond alone (bug 3: it was parted)", RuneWord.linked(w.call(), 0, 1) and int(s.get("picked")) == 1)
	# a drag let go on empty space makes nothing
	var n_links: int = RuneWord.links(w.call()).size()
	_bdrag(b, _local(b, b.node_global(2)), Vector2(b.size.x - 24.0, b.size.y * 0.5 + 40.0))
	_check("a drag let go on empty space makes no bond", RuneWord.links(w.call()).size() == n_links and not b.is_dragging())
	# a refused drag: ring 3 is not next to ring 1
	s.call("place_rune", links2[3], 3, -1)
	var far: int = RuneWord.size(w.call()) - 1
	_bpress(b, _local(b, b.node_global(2)))
	for k: int in 6:
		_bmove(b, _local(b, b.node_global(2)).lerp(_local(b, b.node_global(far)), float(k + 1) / 6.0))
	var refused: Dictionary = (b.get("_drag_checks") as Dictionary).get(far, {})
	_check("while dragging, a rune two rings out is marked refused, with the reason (%s)" % RuneBoard.short_reason(refused),
		b.is_dragging() and not bool(refused.get("ok", true)) and str(refused.get("reason", "")) == "rings_apart")
	_brelease(b, _local(b, b.node_global(far)))
	_check("and letting go on it makes no bond, and says why", not RuneWord.linked(w.call(), 2, far) and str(s.get("_rune_msg")).contains("cannot bond"), str(s.get("_rune_msg")))

	# ---- select a bond along its curve, delete it three ways
	_bclick(b, _local(b, b.bond_global(1, 3)))
	_check("a click on a bond's curve selects it", s.get("picked_bond") == Vector2i(1, 3), str(s.get("picked_bond")))
	_key(s, "seal_delete")
	_check("Delete parts the selected bond", not RuneWord.linked(w.call(), 1, 3) and s.get("picked_bond") == Vector2i(-1, -1))
	_bdrag(b, _local(b, b.node_global(1)), _local(b, b.node_global(3)))
	_bclick(b, _local(b, b.bond_global(1, 3)))
	var cross: Vector2 = b.cross_global()
	_bclick(b, _local(b, cross))
	_check("a selected bond shows an x, and clicking it parts the bond", cross.x >= 0.0 and not RuneWord.linked(w.call(), 1, 3))
	_bdrag(b, _local(b, b.node_global(1)), _local(b, b.node_global(3)))
	_bclick(b, _local(b, b.bond_global(1, 3)), MOUSE_BUTTON_RIGHT)
	_check("right-clicking a bond parts it", not RuneWord.linked(w.call(), 1, 3))
	_bdrag(b, _local(b, b.node_global(1)), _local(b, b.node_global(3)))
	_bclick(b, _local(b, b.bond_global(1, 3)))
	_key(s, "seal_delete_alt")
	_check("Backspace parts the selected bond too", not RuneWord.linked(w.call(), 1, 3))

	# ---- a full rune selected does not stop a placement (bug 7)
	s.call("place_rune", caps[0], 1, -1)
	var cap_i: int = RuneWord.size(w.call()) - 1
	_bdrag(b, _local(b, b.node_global(cap_i)), _local(b, b.node_global(2)))
	_bclick(b, _local(b, b.node_global(cap_i)))
	var size_before: int = RuneWord.size(w.call())
	var full: bool = RuneWord.degree(w.call(), cap_i) == 1 and int(s.get("picked")) == cap_i
	s.call("arm_rune", links2[4])
	_bclick(b, _local(b, b.empty_slot_global(2, 0)))
	_check("with a full rune selected, a new rune is still set (bug 7: refused because it would have bonded to the selection)",
		full and RuneWord.size(w.call()) == size_before + 1, "%s %s" % [str(full), str(s.get("_rune_msg"))])

	# ---- right-click a rune: gone with its bonds; Ctrl+Z brings it back exactly (bug 8)
	var kept: String = _word_json(w.call())
	var n_now: int = RuneWord.size(w.call())
	var had_bond: bool = RuneWord.linked(w.call(), 0, 1)
	_bclick(b, _local(b, b.node_global(1)), MOUSE_BUTTON_RIGHT)
	var gone: bool = had_bond and RuneWord.size(w.call()) == n_now - 1 and RuneWord.neighbours(w.call(), 0).size() == 0
	_key(s, "seal_undo")
	_check("right-click takes a rune out with its bonds; Ctrl+Z puts the draft back exactly (bug 8: no way back)", gone and _word_json(w.call()) == kept)

	# ---- undo and redo restore the draft exactly, step by step
	p.call("word_clear", 0)
	var states: Array[String] = [_word_json(w.call())]
	var steps: Array[Callable] = [
		func() -> void: s.call("place_rune", links2[0], 1, 0),
		func() -> void: s.call("place_rune", links2[1], 1, 2),
		func() -> void: _bdrag(b, _local(b, b.node_global(0)), _local(b, b.node_global(1))),
		func() -> void: _bdrag(b, _local(b, b.node_global(1)), _local(b, b.node_global(2))),
		func() -> void: s.call("place_rune", links2[2], 2, 1),
		func() -> void: s.call("delete_bond", 0, 1),
		func() -> void: s.call("remove_node", 1),
	]
	for st: Callable in steps:
		st.call()
		states.append(_word_json(w.call()))
	var back_ok := true
	for k2: int in range(states.size() - 2, -1, -1):
		_key(s, "seal_undo")
		if _word_json(w.call()) != states[k2]:
			back_ok = false
	var fwd_ok := true
	for k3: int in range(1, states.size()):
		_key(s, "seal_redo")
		if _word_json(w.call()) != states[k3]:
			fwd_ok = false
	_check("Ctrl+Z steps back through %d edits, each to exactly the draft it was (runes, rings, places, bonds)" % (states.size() - 1), back_ok)
	_check("and Ctrl+Y forward again, exactly", fwd_ok)
	_check("nothing is committed: the skill's own word is untouched by the draft", not RuneWord.is_sealed((p.get("abilities") as Array)[0].get("word", {})))

	# ---- Esc cancels a drag and keeps the screen (bug 11: Esc closed it and the draft with it)
	_bpress(b, _local(b, b.node_global(0)))
	_bmove(b, _local(b, b.node_global(0)) + Vector2(40, 30))
	var dragging: bool = b.is_dragging()
	var esc: InputEventKey = (InputMap.action_get_events("settings")[0] as InputEventKey).duplicate()
	esc.pressed = true
	s.call("_unhandled_input", esc)
	_check("Esc cancels a bond being dragged; the screen and the draft stay", dragging and not b.is_dragging() and main.get("screen") == s and bool(s.get("rune_mode")))
	_brelease(b, _local(b, b.node_global(0)) + Vector2(40, 30))

	# ---- the board's geometry (bugs 6 and 10)
	p.call("word_clear", 0)
	for j: int in 3:
		s.call("place_rune", links2[j], 2, j)
	s.call("finish_bond", 1, 3)
	await get_tree().process_frame
	var pts: PackedVector2Array = b._bond_points(1, 3)
	var mid_pos: Vector2 = (b.get("_pos") as Array)[2]
	var nearest := INF
	for q: Vector2 in pts:
		nearest = minf(nearest, q.distance_to(mid_pos))
	_check("two runes of ring 2 with one between them: their bond is drawn across, %.0f px clear of the middle rune (bug 6: along the ring, through it)" % nearest,
		RuneWord.linked(w.call(), 1, 3) and nearest > RuneBoard.SEAL_R + 2.0)
	var saved_pos: Array = (b.get("_pos") as Array).duplicate()
	var c0: Vector2 = saved_pos[0]
	b.set("_pos", [c0, c0 + Vector2(200, 0), c0 + Vector2(240, 0)] as Array[Vector2])
	_check("a click between two close runes picks the nearer (bug 10: the first by index won)", b._node_at(c0 + Vector2(226, 0)) == 2)
	await get_tree().process_frame
	_check("the board drew every state above without a script error", _errors.count() == errors_before, _errors.first())
	main.call("close_screen")
	main.queue_free()
	await get_tree().process_frame


## Rune discovery (Brent 2026-10-23, design/14 section 8): starting knowledge, the three sources
## (subduing a construct, kills, rune stones in zones and the passage), permanence and saves, the
## test character's every-rune knowledge, the palette and the HUD card. Chances are data; the
## checks force them where a roll would make a check flaky.
func _test_rune_discovery() -> void:
	print("rune discovery (design/14 section 8):")
	var disc: Dictionary = GameData.rune_discovery
	_check("rune_discovery.json is loaded: start runes, construct concepts, kill pools, passage stones",
		disc.has("start") and disc.has("construct") and disc.has("kills") and disc.has("inscriptions"))
	var p: Node = _new_player()
	p.call("set_affinities", ["water"])
	p.call("start_with_skills", p.call("default_start_skills"))
	var known: Array = p.get("known_runes")
	var want: Array = []
	for st: Dictionary in p.get("abilities"):
		if not want.has(GameData.skill_anchor(str(st["id"]))):
			want.append(GameData.skill_anchor(str(st["id"])))
	for rid: Variant in ((disc["start"] as Dictionary)["affinity_runes"] as Dictionary)["water"]:
		if not want.has(str(rid)):
			want.append(str(rid))
	_check("a new character knows its two starting skills' runes and a couple of its affinity's (%s)" % ", ".join(known.map(func(id: String) -> String: return str(GameData.rune(id)["name"]))),
		known.size() == want.size() and want.all(func(id: String) -> bool: return known.has(id)), "%s vs %s" % [str(known), str(want)])
	var palette: Array = p.call("rune_palette")
	var unknown: Array = palette.filter(func(id: String) -> bool: return not bool(p.call("knows_rune", id)))
	_check("the palette lists every rune it could use, most of them still unknown", palette.size() > known.size() and unknown.size() == palette.size() - known.size())
	var tc: Node = _new_player()
	tc.call("make_test_character", "water")
	_check("a test character knows every rune", (tc.call("rune_palette") as Array).all(func(id: String) -> bool: return bool(tc.call("knows_rune", id))))
	# an unknown rune cannot be set
	((p.get("abilities") as Array)[0] as Dictionary)["progress"] = 100.0
	(p.get("constructs") as Array).append({"tier": "vestige", "concept": "reach"})
	p.call("open_seal", 0, 0)
	_check("an undiscovered rune cannot be set, and the screen says why", str((p.call("word_add", 0, str(unknown[0]), 0) as Dictionary)["reason"]) == "unknown")
	p.call("close_seal")
	(p.get("constructs") as Array).clear()

	# subduing a construct reveals a rune of its concept
	var heard: Array = []
	p.connect("rune_discovered", func(id: String, _src: String) -> void: heard.append(id))
	var pool_reach: Array = ((((disc["construct"] as Dictionary)["concepts"] as Dictionary)["reach"] as Dictionary)["base"] as Dictionary)["water"]
	var before: int = (p.get("known_runes") as Array).size()
	var got: Array = p.call("on_construct_subdued", "vestige", "reach")
	_check("subduing a vestige of Reach reveals a rune of its concept (%s)" % str(got.map(func(id: String) -> String: return str(GameData.rune(id)["name"]))),
		got.size() == 1 and pool_reach.has(str(got[0])) and (p.get("known_runes") as Array).size() == before + 1 and heard == got
		and str((p.get("last_rune") as Dictionary)["id"]) == str(got[0]) and str((p.get("log_lines") as Array).back()).begins_with("Rune discovered: "))
	var n_echo := Netherecho.new()
	add_child(n_echo)
	n_echo.player = p
	var c: Node3D = n_echo.spawn_construct(Vector3.ZERO, "vestige", "stillness", true)
	var before2: int = (p.get("known_runes") as Array).size()
	c.emit_signal("subdued", c)
	_check("and in the Netherecho itself: a subdued construct reveals one", (p.get("known_runes") as Array).size() == before2 + 1)
	n_echo.queue_free()
	var uni_id: String = str(p.call("reveal_rune", [], (GameData.runes["universal_runes"] as Dictionary).keys(), 1.0, "test"))
	_check("universal runes come from deeper sources: a vestige never gives one, a deep roll does",
		float((((disc["construct"] as Dictionary)["by_tier"] as Dictionary)["vestige"] as Dictionary)["universal_chance"]) == 0.0
		and float((((disc["construct"] as Dictionary)["by_tier"] as Dictionary)["remnant"] as Dictionary)["universal_chance"]) > 0.0
		and uni_id != "" and not GameData.rune(uni_id).has("affinity"))
	# kills
	var kills: Dictionary = disc["kills"]
	var by_kind: Dictionary = kills["chance_by_kind"]
	var saved_chance: Variant = by_kind.get("grunt")
	var kp: Node = _new_player()
	kp.call("set_affinities", ["water"])
	var foe := _dummy_enemy(kp)
	by_kind["grunt"] = 0.0
	var before3: int = (kp.get("known_runes") as Array).size()
	kp.call("_roll_kill_rune", foe)
	var none_then: bool = (kp.get("known_runes") as Array).size() == before3
	by_kind["grunt"] = 1.0
	kp.call("_roll_kill_rune", foe)
	var latest: String = str((kp.get("last_rune") as Dictionary).get("id", ""))
	var grunt_pool: Array = (((kills["by_kind"] as Dictionary)["grunt"] as Dictionary)["base"] as Dictionary)["water"] + (((kills["by_kind"] as Dictionary)["grunt"] as Dictionary)["universal"] as Array)
	_check("a kill reveals a rune of the enemy's nature only on its chance (0: nothing; 1: %s)" % str(GameData.rune(latest).get("name", "?")),
		none_then and (kp.get("known_runes") as Array).size() == before3 + 1 and grunt_pool.has(latest), "%s in %s" % [latest, str(grunt_pool)])
	if saved_chance == null:
		by_kind.erase("grunt")
	else:
		by_kind["grunt"] = saved_chance
	foe.queue_free()
	kp.queue_free()
	# rune stones
	var r1: String = str(p.call("read_inscription", "test_stone", "base", "A test stone"))
	var r_again: String = str(p.call("read_inscription", "test_stone", "base", "A test stone"))
	var r_deep: String = str(p.call("read_inscription", "test_deep", "universal", "A deep stone"))
	_check("a rune stone reveals one rune of your affinity, once; a deep one a universal rune",
		r1 != "" and str(GameData.rune(r1)["affinity"]) == "water" and r_again == "" and r_deep != "" and not GameData.rune(r_deep).has("affinity"))
	var everything: Node = _new_player()
	everything.call("set_affinities", ["water"])
	for rid: String in everything.call("rune_palette"):
		everything.call("discover_rune", rid, "")
	_check("with every rune known there is nothing left to find", str(everything.call("read_inscription", "x", "base", "x")) == "" and (everything.call("on_construct_subdued", "remnant", "reach") as Array).is_empty())
	# permanence: saves
	var known_now: Array = (p.get("known_runes") as Array).duplicate()
	var q: Node = _new_player()
	q.call("from_save", JSON.parse_string(JSON.stringify(p.call("to_save"))))
	_check("discovered runes and read stones are saved with the character", (q.get("known_runes") as Array) == known_now and (q.get("read_inscriptions") as Array).has("test_stone"))
	var old: Dictionary = JSON.parse_string(JSON.stringify(p.call("to_save")))
	old.erase("known_runes")
	var o: Node = _new_player()
	o.call("from_save", old)
	_check("a save from before discovery knows what a new character would", (o.get("known_runes") as Array).size() >= 2 and (o.get("known_runes") as Array).size() < known_now.size())
	for n: Node in [p, tc, everything, q, o]:
		n.queue_free()

	# in the world: the zone's stones and the passage's, read with interact; the HUD's card
	var errors_before: int = _errors.count()
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.set("_test_mode", true)
	add_child(main)
	await get_tree().process_frame
	main.call("start_new_character", 0)
	main.call("enter_zone", "the_stubble", "dross_gate")
	await get_tree().process_frame
	var stones: Array = get_tree().get_nodes_in_group("rune_stones")
	_check("The Stubble has its rune stones (%d)" % stones.size(), stones.size() == (GameData.zone("the_stubble").get("inscriptions", []) as Array).size() and stones.size() >= 1)
	var mp: Node = main.get("player")
	if not stones.is_empty():
		var stone: Node3D = stones[0]
		mp.global_position = stone.global_position + Vector3(1.2, 0.0, 0.0)
		var k0: int = (mp.get("known_runes") as Array).size()
		main.call("_field_interact")
		var hud: Node = main.get("hud")
		_check("interact beside a stone reads it: a rune discovered, and the HUD shows its card",
			(mp.get("known_runes") as Array).size() == k0 + 1 and not (hud.get("_rune_card") as Dictionary).is_empty() and (mp.get("read_inscriptions") as Array).has(str(stone.get("stone_id"))))
	main.call("_enter_dungeon")
	await get_tree().process_frame
	_check("the passage has its rune stones (%d)" % get_tree().get_nodes_in_group("rune_stones").size(),
		get_tree().get_nodes_in_group("rune_stones").filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).size() == ((disc["inscriptions"] as Dictionary)["passage"] as Array).size())
	_check("no script error in the world part", _errors.count() == errors_before, _errors.first())
	main.queue_free()
	await get_tree().process_frame

