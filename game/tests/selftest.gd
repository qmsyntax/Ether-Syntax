extends Node
## Headless rules self-test. Run:
##   godot --headless --path game res://tests/selftest.tscn
## Exercises wound maths, natural healing, arm loss/regrowth, healer credit and rent directly,
## because the auto-play smoke check never touches them. Proves the rules compute as specified;
## proves nothing about feel or balance.

const PlayerScript := preload("res://scripts/player.gd")

var _failed := 0
var _passed := 0


func _ready() -> void:
	_test_body()
	_test_natural_healing()
	_test_arm_loss_and_regrowth()
	_test_healer_credit_and_rent()
	_test_death_and_rest()
	_test_keybinds()
	_test_pipeline()
	await _test_abilities()
	_test_stars()
	await _test_click_melee()
	await _test_inventory()
	print("SELFTEST: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_passed += 1
		print("  ok   %s" % label)
	else:
		_failed += 1
		print("  FAIL %s %s" % [label, detail])


func _near(a: float, b: float, eps: float = 0.01) -> bool:
	return absf(a - b) <= eps


func _new_player(talent: String = "") -> CharacterBody3D:
	var p: CharacterBody3D = PlayerScript.new()
	add_child(p)
	if talent != "":
		p.call("set_talent", talent)
	p.set("active", true)
	return p


func _test_body() -> void:
	print("body:")
	var b := Body.new(60.0, 30.0, 10.0)
	var applied: float = b.apply_damage(70.0)
	_check("damage spills superficial -> structural", _near(float(b.hp["superficial"]), 0.0) and _near(float(b.hp["structural"]), 20.0))
	_check("reports damage applied", _near(applied, 70.0))
	applied = b.apply_damage(500.0)
	_check("no overkill: applied capped at remaining", _near(applied, 30.0), "got %f" % applied)
	_check("dead at zero", b.is_dead())

	var sup := Body.new(60.0, 30.0, 10.0)
	sup.apply_damage(80.0)  # superficial 0, structural 10, catastrophic 10
	var used: float = sup.heal(5.0, false)
	_check("supreme: 1 point = 1 HP, worst layer first", _near(float(sup.hp["structural"]), 15.0) and _near(used, 5.0))
	var dyn := Body.new(60.0, 30.0, 10.0)
	dyn.apply_damage(80.0)
	dyn.heal(3.0, true)     # 2 pts -> 20 structural (full), 1 pt -> up to 100 superficial (caps at 60)
	_check("dynamic: 10x structural, 100x superficial", _near(float(dyn.hp["structural"]), 30.0) and _near(float(dyn.hp["superficial"]), 60.0),
		"struct %f sup %f" % [float(dyn.hp["structural"]), float(dyn.hp["superficial"])])


func _test_natural_healing() -> void:
	print("natural healing:")
	var p := _new_player()
	var b: Body = p.get("body")
	b.apply_damage(85.0)                    # superficial 0, structural 5, catastrophic 10
	b.damage_layer("catastrophic", 6.0)     # catastrophic 4
	p.set("in_combat", true)
	for i: int in 5:
		p.call("_physics_process", 1.0)
	_check("none while in combat", _near(float(b.hp["superficial"]), 0.0) and _near(float(b.hp["structural"]), 5.0))
	p.set("in_combat", false)
	for i: int in 10:
		p.call("_physics_process", 1.0)
	_check("superficial recovers at rest", _near(float(b.hp["superficial"]), 30.0), "got %f" % float(b.hp["superficial"]))
	_check("structural recovers slowly at rest", _near(float(b.hp["structural"]), 9.0), "got %f" % float(b.hp["structural"]))
	_check("catastrophic never recovers naturally", _near(float(b.hp["catastrophic"]), 4.0), "got %f" % float(b.hp["catastrophic"]))
	p.queue_free()


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
	_check("losing the arm is catastrophic damage", float(b.hp["catastrophic"]) < 10.0, "cat %f" % float(b.hp["catastrophic"]))

	p.set("in_combat", false)
	for i: int in 30:
		p.call("_physics_process", 1.0)
	_check("rest never regrows a lost arm", bool(p.get("arm_right_lost")))

	var cat_gap: float = b.missing("catastrophic")
	p.call("_spend_heal_points", cat_gap + 24.0)
	_check("talent heals catastrophic first, arm not yet regrown", _near(b.missing("catastrophic"), 0.0) and bool(p.get("arm_right_lost")))
	p.call("_spend_heal_points", 2.0)
	_check("talent regrows the arm once enough points are spent", not bool(p.get("arm_right_lost")) and float(p.get("arm_right")) > 0.0)
	p.queue_free()


func _test_healer_credit_and_rent() -> void:
	print("healer / debt / rent:")
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


func _dummy_enemy(p: Node3D) -> CharacterBody3D:
	var e: CharacterBody3D = EnemyScript.new()
	add_child(e)
	e.call("setup", "brute", p, 1.0)
	e.set("target", null)      # never fights back on its own
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


func _test_abilities() -> void:
	# awaits a frame so a freed dummy enemy leaves the groups before the "nothing to fight" cast
	print("abilities:")
	var p := _new_player("tenth_strike")
	p.set("star_pct", [99.0] as Array[float])     # a grown star, so the tank is not the baby 20
	p.call("_recompute_essence_max")
	p.set("essence", 100.0)
	var ab: Array = p.get("abilities")
	_check("starting loadout has three abilities", ab.size() == 3 and str(ab[0]["id"]) == "water_bolt")
	# Progress: essence spent through the ability x use multiplier. Bolt costs 12; vs a monster x1.0.
	var e := _dummy_enemy(p)
	p.call("start_fight")
	p.call("cast_slot", 0)
	_check("bolt spends its cost and leaves reflux", _near(float(p.get("essence")), 88.0) and _near(float(p.get("reflux")), 12.0))
	_check("progress = essence spent x1 with a monster present", _near(float(ab[0]["progress"]), 12.0), "got %f" % float(ab[0]["progress"]))
	p.call("end_fight")
	e.queue_free()
	await get_tree().process_frame
	p.set("essence", 100.0)
	p.call("cast_slot", 0)
	_check("progress x0.25 with nothing to fight", _near(float(ab[0]["progress"]), 15.0), "got %f" % float(ab[0]["progress"]))
	ab[0]["progress"] = 99.0
	p.set("essence", 100.0)
	p.set("reflux", 0.0)
	p.call("cast_slot", 0)
	_check("a full bar waits at 100 - the stage does not advance by itself", int(ab[0]["stage"]) == 0 and _near(float(ab[0]["progress"]), 100.0))
	_check("stage 0 full needs a vestige", str(p.call("pending_tier", ab[0])) == "vestige")

	var cons: Array = p.get("constructs")
	cons.append({"tier": "remnant", "concept": "piercing"})
	_check("the wrong tier is refused", str(p.call("bind_construct", 0, 0, 0.0)) == "needs a vestige" and cons.size() == 1)
	cons.clear()
	cons.append({"tier": "vestige", "concept": "acceleration"})
	var pb0: Body = p.get("body")
	var hurt_before: float = pb0.missing("structural")
	_check("a failed bind loses the construct", str(p.call("bind_construct", 0, 0, 0.99)) == "failed" and cons.is_empty() and int(ab[0]["stage"]) == 0)
	_check("a failed bind wounds you", pb0.missing("structural") > hurt_before)
	cons.append({"tier": "vestige", "concept": "acceleration"})
	_check("a vestige binds into stage 0 and advances it", str(p.call("bind_construct", 0, 0, 0.0)) == "bound" and int(ab[0]["stage"]) == 1 and _near(float(ab[0]["progress"]), 0.0))
	var stats: Dictionary = p.call("ability_stats", ab[0])
	_check("the concept shapes the skill (acceleration: bolt speed x1.5)", _near(float(stats["speed"]), 30.0), "speed %f" % float(stats["speed"]))
	_check("stage 1 full now needs a remnant", (func() -> bool:
		ab[0]["progress"] = 100.0
		return str(p.call("pending_tier", ab[0])) == "remnant").call())
	ab[0]["stage"] = 2
	_check("stage cap is stars + 1: a 1-star's stage-2 skill waits for nothing", str(p.call("pending_tier", ab[0])) == "")
	_check("stage raises damage", _near(float(p.call("ability_damage_mult", 2)), 1.2))
	ab[0]["stage"] = 1
	ab[0]["progress"] = 0.0

	# Tsunami strike: a big blow that costs the body.
	var e2 := _dummy_enemy(p)
	var eb: Body = e2.get("body")
	var pb: Body = p.get("body")
	p.set("essence", 100.0)
	p.set("reflux", 0.0)
	ab[0]["stage"] = 0
	p.set("_facing", Vector3(0, 0, -1))
	p.call("cast_slot", 1)
	_check("tsunami strike lands x3 melee damage", eb.missing("superficial") >= 179.0, "got %f" % eb.missing("superficial"))
	_check("tsunami strike wounds the caster", pb.missing("structural") > 0.0)
	e2.queue_free()

	# Meditation gathers wisps.
	p.set("star_pct", [99.0] as Array[float])
	p.call("_recompute_essence_max")
	p.set("essence", 20.0)
	p.set("meditating", true)
	p.call("_meditate_gather", 1.0)
	_check("meditation refills essence", _near(float(p.get("essence")), 24.0), "got %f" % float(p.get("essence")))
	p.queue_free()


func _test_stars() -> void:
	print("stars:")
	var p := _new_player("tenth_strike")
	_check("you start with a baby star", _near(float((p.get("star_pct") as Array)[0]), 5.0) and _near(float(p.get("essence_max")), 20.0),
		"pct %f max %f" % [float((p.get("star_pct") as Array)[0]), float(p.get("essence_max"))])
	p.call("grow_star", 10.0)
	_check("growing the star grows the tank", _near(float(p.get("essence_max")), 60.0))
	p.call("grow_star", 500.0)
	_check("a star stops at 99%", _near(float((p.get("star_pct") as Array)[0]), 99.0))
	p.call("try_ascend")
	_check("a full star alone does not ascend without latent aura", int(p.get("stars")) == 1)
	p.set("_latent_aura", 1000.0)
	p.call("try_ascend")
	var pcts: Array = p.get("star_pct")
	_check("ascension adds a second star at 1%", int(p.get("stars")) == 2 and pcts.size() == 2 and _near(float(pcts[1]), 1.0))
	_check("the tank is 99% of one star plus 1% of another", _near(float(p.get("essence_max")), 400.0), "got %f" % float(p.get("essence_max")))
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
	var p := _new_player("tenth_strike")
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
	_check("a trinket changes ability cost (12 x 0.9)", _near(bolt_cost, 10.8), "got %f" % bolt_cost)
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
	var q := _new_player()
	q.call("from_save", SaveGame.read(path))
	var qinv: Inventory = q.get("inventory")
	_check("a loaded character has the same talent, money and star", str(q.get("talent_id")) == "tenth_strike" and int(q.get("money")) == -321 and _near(float((q.get("star_pct") as Array)[0]), 35.0))
	_check("abilities, constructs and gear survive the round trip", _near(float((q.get("abilities") as Array)[0]["progress"]), 42.0)
		and (q.get("constructs") as Array).size() == 1 and str(qinv.equipped.get("satellite", "")) == "paired_mote"
		and qinv.bag.size() == inv.bag.size() and _near(float(q.get("satellite_rate")), 2.0))
	SaveGame.delete(path)
	_check("deleting the save removes it", not SaveGame.exists(path) and SaveGame.read(path).is_empty())
	for n: Node in get_tree().get_nodes_in_group("pickups"):
		n.queue_free()
	p.queue_free()
	q.queue_free()


func _test_keybinds() -> void:
	print("keybinds:")
	Keybinds.reset_defaults()
	_check("defaults registered", Keybinds.binding_text("ability_1") == "1" and Keybinds.binding_text("ability_6") == "6" and Keybinds.binding_text("strike") == "LMB")
	var g := InputEventKey.new()
	g.physical_keycode = KEY_K
	var displaced: String = Keybinds.rebind("ability_1", g)
	_check("rebind changes the binding", Keybinds.binding_text("ability_1") == "K" and displaced == "")
	var displaced2: String = Keybinds.rebind("ascend", g)
	_check("a key held by another action is taken from it", displaced2 == "ability_1" and Keybinds.binding_text("ability_1") == "(none)" and Keybinds.binding_text("ascend") == "K")
	var mmb := InputEventMouseButton.new()
	mmb.button_index = MOUSE_BUTTON_MIDDLE
	Keybinds.rebind("meditate", mmb)
	_check("mouse buttons bind too", Keybinds.binding_text("meditate") == "MMB")
	Keybinds.call("_load")
	_check("bindings survive a save/load round trip", Keybinds.binding_text("ascend") == "K" and Keybinds.binding_text("meditate") == "MMB")
	Keybinds.reset_defaults()
	_check("reset restores defaults", Keybinds.binding_text("ability_1") == "1" and Keybinds.binding_text("ascend") == "T" and Keybinds.binding_text("meditate") == "M")


func _test_death_and_rest() -> void:
	print("death into debt / night's rest:")
	var p := _new_player()
	var b: Body = p.get("body")
	p.set("money", 100)
	p.set("arm_right_lost", true)
	b.apply_damage(1000.0)
	p.set("dead", true)
	p.call("revive_in_debt", 600)
	_check("revived character is alive", not bool(p.get("dead")) and not b.is_dead())
	_check("the rescue fee is charged with no credit check", int(p.get("money")) == -500, "money %d" % int(p.get("money")))
	_check("patched up, not healed", _near(float(b.hp["superficial"]), 30.0) and _near(float(b.hp["structural"]), 12.0) and _near(float(b.hp["catastrophic"]), 2.0),
		"%f / %f / %f" % [float(b.hp["superficial"]), float(b.hp["structural"]), float(b.hp["catastrophic"])])
	_check("a lost arm stays lost through rescue", bool(p.get("arm_right_lost")))
	p.call("rest_night")
	_check("a night's rest closes cuts and knits some bone", _near(float(b.hp["superficial"]), 60.0) and _near(float(b.hp["structural"]), 27.0))
	_check("a night's rest restores nothing catastrophic, and no arm", _near(float(b.hp["catastrophic"]), 2.0) and bool(p.get("arm_right_lost")))
	p.queue_free()
