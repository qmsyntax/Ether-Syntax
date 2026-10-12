extends Node
## Headless rules self-test. Run:
##   godot --headless --path game res://tests/selftest.tscn
## Exercises wound maths, natural healing, arm loss/regrowth, healer credit and rent directly,
## because the auto-play smoke check never touches them. Proves the rules compute as specified;
## proves nothing about feel or balance.

const PlayerScript := preload("res://scripts/player.gd")

var _failed := 0
var _passed := 0
var _errors: ErrorCatcher


func _ready() -> void:
	_errors = ErrorCatcher.install()
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
	await _test_combat_rules()
	_test_affinities()
	_test_models()
	await _test_netherecho()
	# a script error aborts one function and lets the checks around it pass; count it as a failure
	_check("no script error was raised during the run", _errors.count() == 0, "%d, first: %s" % [_errors.count(), _errors.first()])
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
	# Arc Lash: instant, first enemy on the line, one mark
	l.call("cast_slot", 0)
	_check("arc lash lands at once on the first enemy in line", _near(_lost(t1), 85.0) and _near(_lost(far), 0.0) and _near(_lost(t2), 0.0),
		"t1 %f far %f t2 %f" % [_lost(t1), _lost(far), _lost(t2)])
	_check("and leaves one Live mark", int(t1.call("status_stacks", "live")) == 1)
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
	_check("the third mark is an Overload: the palm, then the big hit", _near(_lost(t1) - t1_before, palm + float(live["overload_damage"])), "lost %f want %f" % [_lost(t1) - t1_before, palm + float(live["overload_damage"])])
	_check("the overloaded target is stunned and its marks are gone", bool(t1.call("has_status", "stunned")) and int(t1.call("status_stacks", "live")) == 0)
	_check("the arc reaches every other marked enemy", _near(_lost(t2), float(live["arc_damage"])) and _near(_lost(far), float(live["arc_damage"])), "t2 %f far %f" % [_lost(t2), _lost(far)])
	_check("and they keep their marks", int(t2.call("status_stacks", "live")) == 1 and int(far.call("status_stacks", "live")) == 1)
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
	_check("five affinities are defined", ids.size() == 5 and ids.has("water") and ids.has("fire") and ids.has("earth") and ids.has("wind") and ids.has("lightning"))
	for a: String in ids:
		var kit: Array = GameData.affinity(a).get("kit", [])
		var kinds: Array = []
		var own := true
		for id: String in kit:
			var ab: Dictionary = GameData.ability(id)
			kinds.append(str(ab.get("kind", "")))
			own = own and str(ab.get("affinity", "")) == a
		# earth is the exception, on purpose: its third skill raises a wall and it has no way to move fast
		_check("%s has a ranged attack, a strike and a movement skill of its own (earth: a wall instead)" % a,
			kit.size() == 3 and own and ["projectile", "beam"].has(kinds[0]) and ["melee_burst", "targeted_strike"].has(kinds[1]) and (["dash", "blink"].has(kinds[2]) or (a == "earth" and kinds[2] == "prop")), str(kinds))

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
				if m == null or m.height < 1.7 or m.height > 1.95 or not m.has_part("arm_right"):
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
	print("death into debt / night's rest:")
	var p := _new_player()
	var b: Body = p.get("body")
	p.set("money", 100)
	p.set("arm_right_lost", true)
	b.add_wound("lost_arm", "Lost arm", 25.0, 8.0, false)
	b.add_wound("ribs", "Cracked ribs", 20.0, 8.0)
	b.apply_damage(1000.0)
	p.set("dead", true)
	p.call("revive_in_debt", 600)
	_check("revived character is alive", not bool(p.get("dead")) and not b.is_dead())
	_check("the rescue fee is charged with no credit check", int(p.get("money")) == -500, "money %d" % int(p.get("money")))
	_check("patched up, not healed: half the bar, every wound still there", _near(b.total(), 42.0) and b.wounds.size() == 2, "hp %f" % b.total())
	_check("a lost arm stays lost through rescue", bool(p.get("arm_right_lost")))
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
