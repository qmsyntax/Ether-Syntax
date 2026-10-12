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
	_test_slot_assignment()
	await _test_weapons()
	_test_character()
	_test_affinities()
	_test_models()
	await _test_netherecho()
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
	var p := _new_player("one_percent_lifesteal")      # a water character: these checks use the water kit
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
	p.set("_latent_aura", 1000.0)
	p.call("try_ascend")
	var pcts: Array = p.get("star_pct")
	_check("ascension adds a second star at 1%", int(p.get("stars")) == 2 and pcts.size() == 2 and _near(float(pcts[1]), 1.0))
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
	_check("a prime brings its affinities", (p.get("affinities") as Array) == GameData.prime_affinities("grudge") and not (p.get("affinities") as Array).is_empty())
	_check("every affinity a prime carries is defined", GameData.prime_affinities("grudge").all(func(a: String) -> bool: return not GameData.affinity(a).is_empty()))
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


func _test_affinities() -> void:
	print("affinities:")
	var ids: Array = GameData.affinity_ids()
	_check("five affinities are defined", ids.size() == 5 and ids.has("water") and ids.has("fire") and ids.has("earth") and ids.has("wind") and ids.has("lightning"))
	for a: String in ids:
		var kit: Array = GameData.affinity(a).get("kit", [])
		var kinds: Array = []
		var own := true
		for id: String in kit:
			var ab: Dictionary = GameData.ability(id)
			kinds.append(str(ab.get("kind", "")))
			own = own and str(ab.get("affinity", "")) == a
		_check("%s has a ranged attack, a strike and a movement skill of its own" % a,
			kit.size() == 3 and own and kinds == ["projectile", "melee_burst", "dash"], str(kinds))
	for id: String in ["one_percent_lifesteal", "tenth_strike", "grudge", "glass_hour", "debt_of_pain", "furnace_gut"]:
		var carried: Array[String] = GameData.prime_affinities(id)
		if carried.is_empty() or not carried.all(func(a: String) -> bool: return ids.has(a)):
			_check("every playable prime carries known affinities", false, id)

	# a single-affinity character starts with that affinity's kit
	var p := _new_player("grudge")
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
	p.call("cast_slot", 3)
	_check("the other affinity still can", float(p.get("essence")) < ess and float(p.call("reflux_of", "lightning")) > 0.0)
	for i: int in 30:
		p.call("_shed_reflux", 2.0)
	_check("reflux sheds on every affinity and the lock lifts", not bool(p.call("is_locked", "wind")) and float(p.call("reflux_of", "wind")) < 60.0
		and _near(float(p.call("reflux_of", "lightning")), 0.0))
	p.queue_free()

	# furnace gut vents the affinity that overheated, not the other one
	p = _new_player("furnace_gut")
	p.set("star_pct", [99.0] as Array[float])
	p.call("_recompute_essence_max")
	p.set("essence", 99.0)
	(p.get("reflux_by") as Dictionary)["fire"] = 20.0
	(p.get("reflux_by") as Dictionary)["earth"] = 99.0
	p.call("cast_slot", 3)                 # the earth projectile
	_check("furnace gut vents the affinity that capped", _near(float(p.call("reflux_of", "earth")), 50.0) and _near(float(p.call("reflux_of", "fire")), 20.0)
		and not bool(p.call("is_locked", "earth")), "earth %f fire %f" % [float(p.call("reflux_of", "earth")), float(p.call("reflux_of", "fire"))])
	p.queue_free()

	# wisps
	p = _new_player("grudge")
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
