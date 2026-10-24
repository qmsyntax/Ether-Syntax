extends RefCounted
## The self-test's checks for the v2 build (2026-10-24, design/data-drafts/skills-v2/BUILD-BRIEF.md): the
## data the generator writes from the v2 drafts (18 affinities, their starters, dropped skills gone, every
## skill on its own rune, every ascension aspect reaching a real number, a desc for every status) and one
## check per role mechanic. Called from selftest.gd, borrowing its helpers (_new_player, _foe, _lost ...)
## through `t`; numbers come from the data. Run alone with `-- --only=v2`.

const PlayerScript := preload("res://scripts/player.gd")
const STEP := 1.0 / 60.0

## The skills the v2 drafts drop (Brent approved the drafts 2026-10-24): none may stay in the game.
const DROPPED: Array[String] = ["hammering_heart", "knell", "rousing_blow", "icicle", "bent_light", "residue", "water_bolt",
	"undertow", "pressure_jet", "upwelling", "steady_drip", "tidal_bore", "slack_water", "headwind"]

var t: Node                 # the self-test node
var check: Callable         # its _check(label, ok, detail)


func _init(test: Node, check_fn: Callable) -> void:
	t = test
	check = check_fn


func run() -> void:
	print("the v2 build: every affinity rebuilt around its role (2026-10-24):")
	await t.get_tree().physics_frame
	_data()
	await _statuses()
	await _coat_and_fire()
	await _ground_and_edge()


# --- helpers ------------------------------------------------------------------------------------

var _made: Array[Node] = []


func _keep(n: Node) -> Node:
	_made.append(n)
	return n


## A plain player far from everything else, on a floor of its own.
func _player(at: Vector3, affs: Array = []) -> CharacterBody3D:
	var p: CharacterBody3D = t.call("_new_player")
	p.global_position = at
	if not affs.is_empty():
		p.call("set_affinities", affs)
	p.set("effects", [] as Array[TalentEffect])
	t.call("_bare", p)
	_keep(p)
	_keep(t.call("_test_floor", at))
	return p


func _enemy(p: Node3D, offset: Vector3, kind: String = "grunt") -> CharacterBody3D:
	return _keep(t.call("_foe", p, offset, kind))


func _tick_enemy(e: Node, seconds: float) -> void:
	var n: int = int(ceil(seconds / STEP))
	for i: int in n:
		if is_instance_valid(e) and not bool(e.call("is_dead")):
			e.call("_physics_process", STEP)


func _clean() -> void:
	for n: Node in _made:
		if is_instance_valid(n):
			n.queue_free()
	_made.clear()


# --- the statuses: the 14 the v2 runes grant and the drafts' own, each through the one status engine ----

func _statuses() -> void:
	var p := _player(Vector3(5200, 0, 0))
	await t.get_tree().physics_frame
	# Taunted: it comes for whoever taunted it; a lure beside it does not draw it; an archer walks in
	var arch := _enemy(p, Vector3(0, 0, -9.0), "archer")
	arch.set("target", p)
	var lure: Lure = _keep(Lure.new())
	t.add_child(lure)
	lure.global_position = arch.global_position + Vector3(1.0, 0, 0)
	lure.life = 99.0
	arch.call("add_status", "taunted", 1, p)
	arch.call("_pick_target")
	var d0: float = arch.global_position.distance_to(p.global_position)
	_tick_enemy(arch, 0.5)
	check.call("Taunted: a lure beside it draws nothing - it goes for whoever taunted it, and an archer walks in to fight",
		arch.get("target") == p and arch.global_position.distance_to(p.global_position) < d0 - 0.5, "target %s, %.2f -> %.2f m" % [str(arch.get("target")), d0, arch.global_position.distance_to(p.global_position)])
	lure.life = 0.0
	lure.call("tick", 0.1)
	# Turned: spun round, every hit counts as from behind
	var tn := _enemy(p, Vector3(0, 0, -2.0))
	tn.set("facing", Vector3(0, 0, 1))
	tn.call("add_status", "turned", 1, p)
	check.call("Turned: it faces away from you, so a hit from you is from behind", bool(tn.call("is_behind", p.global_position))
		and (tn.get("facing") as Vector3).dot(Vector3(0, 0, -1)) > 0.9)
	# Tithed: your hits on it heal you
	var tb: Body = p.get("body")
	tb.hp = 50.0
	var ti := _enemy(p, Vector3(2.0, 0, -2.0))
	ti.call("add_status", "tithed", 1, p)
	var hit: HitContext = p.call("deal_damage", ti, 100.0, ["test"])
	check.call("Tithed: a hit you land on it heals you %d%% of the harm" % int(GameData.status("tithed")["heals_attacker_frac"] * 100.0),
		_near(tb.hp - 50.0, hit.applied * float(GameData.status("tithed")["heals_attacker_frac"])), "healed %f of %f" % [tb.hp - 50.0, hit.applied])
	# Leeched: your hits on it drain to you (the bar)
	tb.hp = 50.0
	ti.call("clear_status", "tithed")
	ti.call("add_status", "leeched", 1, p)
	hit = p.call("deal_damage", ti, 100.0, ["test"])
	check.call("Leeched: a hit you land on it drains %d%% of the harm to you" % int(GameData.status("leeched")["drain_to_source"] * 100.0),
		_near(tb.hp - 50.0, hit.applied * float(GameData.status("leeched")["drain_to_source"])), "healed %f" % (tb.hp - 50.0))
	tb.hp = tb.total_max()
	# Charmed: it turns on its friends, and they on it
	var ch := _enemy(p, Vector3(-6.0, 0, -6.0))
	var friend := _enemy(p, Vector3(-4.0, 0, -6.0))
	ch.set("target", p)
	friend.set("target", p)
	ch.call("add_status", "charmed", 1, p)
	ch.call("_pick_target")
	friend.call("_pick_target")
	check.call("Charmed: it goes for its nearest friend, and that friend for it", ch.get("target") == friend and friend.get("target") == ch,
		"%s / %s" % [str(ch.get("target")), str(friend.get("target"))])
	p.call("deal_damage", ch, 1.0, ["test"])
	check.call("and a hit from whoever charmed it snaps it out", not bool(ch.call("has_status", "charmed")))
	# Doubting: slow to commit, half-hearted
	var db := _enemy(p, Vector3(6.0, 0, -6.0))
	var w0: float = float(db.call("_windup_len"))
	var b0: float = float(db.call("_blow", 100.0))
	db.call("add_status", "doubting", 1, p)
	check.call("Doubting: its wind-ups take x%s, its blows do x%s" % [str(GameData.status("doubting")["windup_mult"]), str(GameData.status("doubting")["deals_mult"])],
		_near(float(db.call("_windup_len")), w0 * float(GameData.status("doubting")["windup_mult"])) and _near(float(db.call("_blow", 100.0)), b0 * float(GameData.status("doubting")["deals_mult"])))
	# Steeped: the dose clock runs longer once, and the bill is bigger
	var dz := _enemy(p, Vector3(8.0, 0, -2.0))
	dz.call("add_status", "dosed", 4, p)
	var clock0: float = float((dz.get("statuses") as Dictionary)["dosed"]["t"])
	dz.call("add_status", "steeped", 1, p)
	dz.call("add_status", "steeped", 1, p)
	var steep: Dictionary = GameData.status("steeped")
	var add_t: float = float((steep["adds_time"] as Dictionary)["dosed"])
	check.call("Steeped: the dose clock runs %s s longer, once" % str(add_t), _near(float((dz.get("statuses") as Dictionary)["dosed"]["t"]), clock0 + add_t, 0.02))
	var lost0: float = t.call("_lost", dz)
	(dz.get("statuses") as Dictionary)["dosed"]["t"] = 0.001
	dz.call("_tick_statuses", 0.01)
	var bill: float = 4.0 * float((GameData.status("dosed")["on_expire"] as Dictionary)["damage_per_stack"]) * float((steep["bill_mult"] as Dictionary)["dosed"])
	check.call("and the bill is x%s when it comes due - and Steeped goes with it" % str((steep["bill_mult"] as Dictionary)["dosed"]),
		_near(float(t.call("_lost", dz)) - lost0, bill, 0.5) and not bool(dz.call("has_status", "steeped")), "paid %f want %f" % [float(t.call("_lost", dz)) - lost0, bill])
	# Barbed: a barb keeps dosing; spending the doses pulls it
	var bb := _enemy(p, Vector3(10.0, 0, -2.0))
	bb.call("add_status", "dosed", 1, p)
	bb.call("add_status", "barbed", 1, p)
	var every: float = float((GameData.status("barbed")["adds_status"] as Dictionary)["every"])
	bb.call("_tick_statuses", every + 0.01)
	check.call("Barbed: every %s s it works in another dose" % str(every), int(bb.call("status_stacks", "dosed")) == 2, str(bb.get("statuses")))
	bb.call("clear_status", "dosed")
	check.call("and spending the doses pulls the barb", not bool(bb.call("has_status", "barbed")))
	# Condemned: Lit, and every hit from you adds ward, at most ward_from_one from one body
	var cn := _enemy(p, Vector3(-2.0, 0, -2.0))
	cn.call("add_status", "condemned", 1, p)
	var cdef: Dictionary = GameData.status("condemned")
	p.set("ward_parts", [])
	p.call("deal_damage", cn, 1.0, ["test"])
	check.call("Condemned: it counts as Lit, and your hit on it adds %s to your ward" % str(cdef["ward_to_attacker"]),
		bool(cn.call("has_status", "lit")) and _near(float(p.call("ward")), float(cdef["ward_to_attacker"])), "ward %f" % float(p.call("ward")))
	for i: int in 20:
		p.call("deal_damage", cn, 1.0, ["test"])
	check.call("but no more than %s from one body" % str(cdef["ward_from_one"]), _near(float(p.call("ward")), float(cdef["ward_from_one"])), "ward %f" % float(p.call("ward")))
	p.set("ward_parts", [])
	# Penitent: an attack it starts hurts it; its blows on you land softer
	var pn := _enemy(p, Vector3(0, 0, -1.6))
	pn.set("target", p)
	pn.set("_attack_cd", 0.0)
	pn.call("add_status", "penitent", 1, p)
	var pen: Dictionary = GameData.status("penitent")
	var pl0: float = t.call("_lost", pn)
	for i: int in 30:
		pn.call("_physics_process", STEP)
		if float(pn.get("_windup")) >= 0.0:
			break
	check.call("Penitent: the attack it starts deals it %s" % str(pen["on_attack_damage"]), float(pn.get("_windup")) >= 0.0 and _near(float(t.call("_lost", pn)) - pl0, float(pen["on_attack_damage"]), 0.5),
		"windup %f lost %f" % [float(pn.get("_windup")), float(t.call("_lost", pn)) - pl0])
	tb.hp = tb.total_max()
	var hp_b: float = tb.hp
	pn.call("_strike", 20.0, false)
	check.call("and its blow on you does x%s" % str(pen["deals_mult_vs_source"]), _near(hp_b - tb.hp, 20.0 * float(pen["deals_mult_vs_source"]), 0.05), "took %f" % (hp_b - tb.hp))
	tb.hp = tb.total_max()
	pn.set("target", null)
	# Exiled: it will not come within keeps_away of whoever cast it out; an elite is not held by it
	var ex := _enemy(p, Vector3(2.0, 0, 0))
	ex.set("target", p)
	ex.call("add_status", "exiled", 1, p)
	var ex_d0: float = ex.global_position.distance_to(p.global_position)
	_tick_enemy(ex, 0.4)
	check.call("Exiled: inside %s m of you it backs away" % str(GameData.status("exiled")["keeps_away"]), ex.global_position.distance_to(p.global_position) > ex_d0 + 0.3)
	var cmd := _enemy(p, Vector3(-12.0, 0, 6.0), "commander")
	check.call("an elite is not held by it", int(cmd.call("add_status", "exiled", 1, p)) == 0 and not bool(cmd.call("has_status", "exiled")))
	ex.set("target", null)
	# Leashed: it cannot get further than the leash from whoever leashed it
	var ls := _enemy(p, Vector3(0, 0, 3.0))
	ls.call("add_status", "leashed", 1, p)
	ls.global_position = p.global_position + Vector3(0, 0, 9.0)
	ls.call("_keep_leash")
	check.call("Leashed: a step past %s m is undone" % str(GameData.status("leashed")["leash_m"]),
		_near(ls.global_position.distance_to(p.global_position), float(GameData.status("leashed")["leash_m"]), 0.05), "%.2f m" % ls.global_position.distance_to(p.global_position))
	# Tormented: it hurts, and half of each hurt feeds whoever torments it
	tb.hp = 40.0
	var tm := _enemy(p, Vector3(0, 0, 6.0))
	tm.call("add_status", "tormented", 1, p)
	var tl0: float = t.call("_lost", tm)
	tm.call("_tick_statuses", 1.0)
	var tdef: Dictionary = GameData.status("tormented")
	check.call("Tormented: %s a second, and %d%% of it heals whoever torments it" % [str(tdef["dps_per_stack"]), int(float(tdef["drain_frac"]) * 100.0)],
		_near(float(t.call("_lost", tm)) - tl0, float(tdef["dps_per_stack"]), 0.5) and _near(tb.hp - 40.0, (float(t.call("_lost", tm)) - tl0) * float(tdef["drain_frac"]), 0.2),
		"dealt %f healed %f" % [float(t.call("_lost", tm)) - tl0, tb.hp - 40.0])
	tb.hp = tb.total_max()
	# Stasis: nothing on it runs down, and it comes out Stilled
	var sx := _enemy(p, Vector3(4.0, 0, 6.0))
	sx.call("add_status", "chilled", 2, p)
	sx.call("add_status", "stasis", 1, p)
	var chill_t: float = float((sx.get("statuses") as Dictionary)["chilled"]["t"])
	sx.call("_tick_statuses", 1.0)
	check.call("Stasis: it cannot act, and nothing else on it runs down", _near(float((sx.get("statuses") as Dictionary)["chilled"]["t"]), chill_t) and bool(sx.call("_st_any", "cannot_act")))
	sx.call("_tick_statuses", float(GameData.status("stasis")["lasts"]))
	check.call("and it comes out Stilled", not bool(sx.call("has_status", "stasis")) and bool(sx.call("has_status", "stilled")))
	# Infected spreads by touch: a carrier passes one stack to whoever stays beside it
	var ca := _enemy(p, Vector3(-8.0, 0, 8.0))
	var nb := _enemy(p, Vector3(-7.0, 0, 8.0))
	ca.call("add_status", "infected", 3, p)
	ca.call("_tick_statuses", float(GameData.status("infected")["spread_time"]) + 0.05)
	check.call("Infected: whoever stays within %s m of a carrier for %s s catches one stack in the carrier's name" % [str(GameData.status("infected")["spread_radius"]), str(GameData.status("infected")["spread_time"])],
		int(nb.call("status_stacks", "infected")) == 1 and ((nb.get("statuses") as Dictionary)["infected"] as Dictionary).get("by") == p, str(nb.get("statuses")))
	# Contained: when it ends, what is over the plain cap falls away
	var co := _enemy(p, Vector3(8.0, 0, 8.0))
	co.call("add_status", "contained", 1, p)
	co.call("add_status", "infected", 9, p)
	(co.get("statuses") as Dictionary)["contained"]["t"] = 0.001
	co.call("_tick_statuses", 0.01)
	check.call("Contained raises Infected's cap, and when it ends the stacks above five fall away",
		int(co.call("status_stacks", "infected")) == int(GameData.status("infected")["stacks"]), str(co.get("statuses")))
	_clean()


## Ready to cast: a full tank, nothing finishing.
func _ready_to_cast(p: Node) -> void:
	p.set("star_pct", [99.0] as Array[float])
	p.call("_recompute_essence_max")
	p.set("essence", 99.0)
	p.call("clear_reflux")
	t.call("_rested", p)
	p.set("_windup", {})
	p.set("_windup_t", 0.0)


func _cast(p: Node, id: String) -> void:
	_ready_to_cast(p)
	t.call("_cast", p, id)
	if float(p.get("_windup_t")) > 0.0:
		p.call("_tick_windup", float(p.get("_windup_t")) + 0.01)


# --- the weapon coat (one mechanic: Fire's Stoke, Poison's Venom Edge, Metal's Red Iron, Static Coat) and Fire ---

func _coat_and_fire() -> void:
	var p := _player(Vector3(5400, 0, 0), ["poison", "fire"])
	for id: String in ["steeped_blade", "stoke", "white_heat", "brushfire", "venom_spur", "clean_air"]:
		p.call("learn", id)
	await t.get_tree().physics_frame
	p.set("_facing", Vector3(0, 0, -1))
	var foe := _enemy(p, Vector3(0, 0, -1.6))
	var edge: Dictionary = GameData.ability("venom_edge")
	_cast(p, "venom_edge")
	var coat: Dictionary = ((p.get("buffs") as Dictionary).get("coat_poison", {}) as Dictionary).get("coat", {})
	check.call("Venom Edge: its blow doses, and the cast leaves a poison coat on your weapon with %d charges" % int(edge["coat"]["charges"]),
		int(foe.call("status_stacks", "dosed")) == int(edge["on_hit"]["stacks"]) and int(coat.get("charges_left", 0)) == int(edge["coat"]["charges"]), str(p.get("buffs")))
	var d0: int = int(foe.call("status_stacks", "dosed"))
	p.call("deal_damage", foe, 1.0, ["melee"])
	check.call("every bare strike carries the coat (one more dose) and spends a charge", int(foe.call("status_stacks", "dosed")) == d0 + 1
		and int(coat.get("charges_left", 0)) == int(edge["coat"]["charges"]) - 1)
	_cast(p, "stoke")
	check.call("a Fire coat (Stoke) sits beside the Poison one: one coat per affinity", (p.get("buffs") as Dictionary).has("coat_poison")
		and ((p.get("buffs") as Dictionary).get("stoke", {}) as Dictionary).has("coat"))
	p.call("deal_damage", foe, 1.0, ["melee"])
	check.call("and a strike carries both", int(foe.call("status_stacks", "alight")) >= 1 and int(foe.call("status_stacks", "dosed")) == d0 + 2)
	_cast(p, "steeped_blade")
	var sb: Dictionary = GameData.ability("steeped_blade")
	var coat2: Dictionary = ((p.get("buffs") as Dictionary).get("coat_poison", {}) as Dictionary).get("coat", {})
	check.call("a new Poison coat (Steeped Blade) replaces the old one", int(coat2.get("charges_left", 0)) == int(sb["coat"]["charges"]) and coat2 != coat)
	for i: int in int(sb["coat"]["charges"]):
		p.call("deal_damage", foe, 1.0, ["melee"])
	check.call("and when its charges are spent it is gone", not (p.get("buffs") as Dictionary).has("coat_poison"))
	# a ranged shot carries the coat too (the ranged weapon's own shot)
	_cast(p, "venom_edge")
	foe.call("clear_status", "dosed")
	var before: int = int(foe.call("status_stacks", "dosed"))
	p.call("deal_damage", foe, 1.0, ["ranged"])
	check.call("a ranged-weapon shot carries the coat as a strike does", int(foe.call("status_stacks", "dosed")) == before + 1)
	# Venom Spur: the clock comes due now, at a reduced bill
	foe.call("add_status", "dosed", 2, p)
	var spur: Dictionary = GameData.ability("venom_spur")
	_cast(p, "venom_spur")
	var dz: Dictionary = (foe.get("statuses") as Dictionary).get("dosed", {})
	check.call("Venom Spur cuts every dose clock in reach to %s s" % str(spur["clock_to"]), not dz.is_empty() and float(dz["t"]) <= float(spur["clock_to"]) + 0.001
		and _near(float((dz.get("data", {}) as Dictionary).get("bill_mult", 0.0)), float(spur["bill_mult"])), str(dz))
	# White Heat: the Heat bonus counts heat_scale times
	(foe.get("body") as Body).hp = 5000.0
	foe.call("clear_status", "dosed")
	foe.call("clear_status", "alight")
	(p.get("buffs") as Dictionary).clear()
	var wh: Dictionary = GameData.ability("white_heat")
	var heat: float = 50.0
	_ready_to_cast(p)
	(p.get("reflux_by") as Dictionary)["fire"] = heat
	var l0: float = t.call("_lost", foe)
	var bonus: float = float(p.call("heat_mult", "fire")) - 1.0
	t.call("_cast", p, "white_heat")
	p.call("_tick_windup", float(wh.get("windup", 0.0)) + 0.01)
	var heat_now: float = float(p.call("reflux_of", "fire"))
	var want: float = float(wh["damage"]) * (1.0 + (float(p.call("heat_mult", "fire")) - 1.0) * float(wh["on_hit"]["heat_scale"]))
	check.call("White Heat: its Heat bonus counts x%s" % str(wh["on_hit"]["heat_scale"]), _near(float(t.call("_lost", foe)) - l0, want, 1.0),
		"lost %f want %f (bonus %f, heat %f)" % [float(t.call("_lost", foe)) - l0, want, bonus, heat_now])
	# Brushfire: refused on a target that is not burning; on a burning one, its stacks spread
	var near := _enemy(p, Vector3(1.5, 0, -1.6))
	p.set("hovered", foe)
	var ess0: float = 0.0
	_ready_to_cast(p)
	ess0 = float(p.get("essence"))
	t.call("_cast", p, "brushfire")
	check.call("Brushfire needs a burning target, and is refused before anything is spent", _near(float(p.get("essence")), ess0) and not bool(near.call("has_status", "alight")))
	foe.call("add_status", "alight", 3, p)
	_cast(p, "brushfire")
	var bf: Dictionary = GameData.ability("brushfire")
	check.call("on a burning one, everyone near it catches as many stacks as it carries (at most %d)" % int(bf["spread_max"]),
		int(near.call("status_stacks", "alight")) == mini(3, int(bf["spread_max"])), str(near.get("statuses")))
	p.set("hovered", null)
	_clean()


# --- Earth's ground, Metal's edge, Wind's turn: auras, the millstone, the counter window, Edge Heat, the leap ---

func _ground_and_edge() -> void:
	var p := _player(Vector3(5600, 0, 0), ["earth", "metal", "wind"])
	for id: String in ["millstone", "stonehide", "turn_the_edge", "plating", "veil", "downdraft", "turning_palm", "red_iron"]:
		p.call("learn", id)
	await t.get_tree().physics_frame
	p.set("_facing", Vector3(0, 0, -1))
	# Millstone: an aura that drags them in and keeps them Taunted; nothing moves you; a slam when it ends
	var ms: Dictionary = GameData.ability("millstone")
	var near := _enemy(p, Vector3(0, 0, -4.0))
	_cast(p, "millstone")
	var d0: float = near.global_position.distance_to(p.global_position)
	p.call("_tick_buffs", 1.0)
	check.call("Millstone: its aura Taunts whoever is near and draws them in", bool(near.call("has_status", "taunted"))
		and near.global_position.distance_to(p.global_position) < d0 - 0.3, "%.2f -> %.2f m" % [d0, near.global_position.distance_to(p.global_position)])
	p.call("shove", Vector3(1, 0, 0), 3.0)
	check.call("and while it lasts nothing shoves you", _near(float(p.get("_shoved_left")), 0.0))
	var l0: float = t.call("_lost", near)
	near.global_position = p.global_position + Vector3(0, 0, -1.5)
	p.call("_tick_buffs", float(ms["duration"]))
	check.call("when it runs out it slams down round you (%d)" % int(ms["on_end"]["damage"]), _near(float(t.call("_lost", near)) - l0, float(ms["on_end"]["damage"]), 0.5)
		and not (p.get("buffs") as Dictionary).has("millstone"), "lost %f" % (float(t.call("_lost", near)) - l0))
	# Stonehide's aura of mud
	_cast(p, "stonehide")
	p.call("_tick_buffs", 0.6)
	check.call("Stonehide: an aura of mud round you (Mired)", bool(near.call("has_status", "mired")))
	(p.get("buffs") as Dictionary).clear()
	# the counter window (one mechanic for Holy, Wind and Metal): Turn the Edge refuses the first blow whole and answers it
	var tte: Dictionary = GameData.ability("turn_the_edge")
	var att := _enemy(p, Vector3(0, 0, -1.6))
	att.set("facing", Vector3(0, 0, 1))
	var body: Body = p.get("body")
	body.hp = body.total_max()
	_cast(p, "turn_the_edge")
	check.call("Turn the Edge opens a %s s window and roots you" % str(tte["window_s"]), (p.get("buffs") as Dictionary).has("turn_the_edge") and _near(float(p.call("buff_num", "move_factor")), 0.0))
	var took: float = p.call("take_hit", 30.0, true, att)
	check.call("the first blow in it is refused whole - no harm, no wound", _near(took, 0.0) and _near(body.hp, body.total_max()) and body.wounds.is_empty())
	check.call("and answered: the attacker Dulled and Staggered, and two Edge Heat on it", bool(att.call("has_status", "dulled")) and bool(att.call("has_status", "staggered"))
		and int(p.get("focus")) == int(tte["focus_gain"]) and p.get("_focus_target") == att, "focus %d" % int(p.get("focus")))
	check.call("then the window is shut", not (p.get("buffs") as Dictionary).has("turn_the_edge"))
	took = p.call("take_hit", 10.0, false, att)
	check.call("so the next blow lands", took > 0.0)
	body.hp = body.total_max()
	# a window that passes with no blow gives a share of the essence back (Turning Palm's refund_unused)
	var tp: Dictionary = GameData.ability("turning_palm")
	_cast(p, "turning_palm")
	var e_after: float = float(p.get("essence"))
	p.call("_tick_buffs", float(tp["window_s"]) + 0.05)
	check.call("an unused Turning Palm gives back %d%% of its essence" % int(float(tp["refund_unused"]) * 100.0), _near(float(p.get("essence")) - e_after, float(tp["cost"]) * float(tp["refund_unused"]), 0.05))
	# Turning Palm answers from behind: you end up at the attacker's back, and it is Turned
	att.call("clear_status", "staggered")
	att.set("facing", Vector3(0, 0, 1))
	_cast(p, "turning_palm")
	p.call("take_hit", 10.0, false, att)
	check.call("Turning Palm puts you behind the attacker and Turns it", bool(att.call("is_behind", p.global_position)) and bool(att.call("has_status", "turned")))
	(p.get("buffs") as Dictionary).clear()
	# Edge Heat: blows on the same enemy heat the edge, each +8%; another enemy starts again; it cools
	var a1 := _enemy(p, Vector3(4.0, 0, 0))
	var a2 := _enemy(p, Vector3(-4.0, 0, 0))
	p.set("focus", 0)
	p.set("_focus_target", null)
	var mcfg: Dictionary = GameData.affinity("metal")
	var h1: HitContext = p.call("deal_damage", a1, 100.0, ["ability", "metal"])
	var h2: HitContext = p.call("deal_damage", a1, 100.0, ["ability", "metal"])
	var h3: HitContext = p.call("deal_damage", a1, 100.0, ["ability", "metal"])
	check.call("Edge Heat: each metal blow on the same enemy adds one, +%d%% each" % int(float(mcfg["focus_mult"]) * 100.0),
		int(p.get("focus")) == 3 and _near(h2.applied / h1.applied, 1.0 + float(mcfg["focus_mult"]), 0.001) and _near(h3.applied / h1.applied, 1.0 + 2.0 * float(mcfg["focus_mult"]), 0.001),
		"focus %d, %f %f %f" % [int(p.get("focus")), h1.applied, h2.applied, h3.applied])
	p.call("deal_damage", a1, 50.0, ["ability", "metal", "spall"])
	check.call("a side-effect (spall) neither adds nor resets it", int(p.get("focus")) == 3)
	p.call("deal_damage", a2, 100.0, ["ability", "metal"])
	check.call("a blow on another enemy starts again at one, on that one", int(p.get("focus")) == 1 and p.get("_focus_target") == a2)
	for i: int in int(float(mcfg["focus_max"])) + 2:
		p.call("deal_damage", a2, 1.0, ["ability", "metal"])
	check.call("it stops at %d" % int(mcfg["focus_max"]), int(p.get("focus")) == int(mcfg["focus_max"]))
	p.set("_focus_t", 0.0)
	p.call("_physics_process", STEP)
	check.call("and %s s without a metal blow cools it to nothing" % str(mcfg["focus_cools_s"]), int(p.get("focus")) == 0)
	_cast(p, "red_iron")
	p.call("deal_damage", a1, 1.0, ["ability", "metal"])
	check.call("Red Iron starts the edge white-hot on the next enemy you hit", int(p.get("focus")) == int(mcfg["focus_max"]) and p.get("_focus_target") == a1)
	(p.get("buffs") as Dictionary).clear()
	# Plating answers only the blows from close by
	var pl: Dictionary = GameData.ability("plating")
	var far_att := _enemy(p, Vector3(0, 0, 4.0))
	_cast(p, "plating")
	p.call("take_hit", 5.0, false, far_att)
	check.call("Plating: an attacker beyond %s m is not Dulled" % str(pl["attacker_reach"]), not bool(far_att.call("has_status", "dulled")))
	far_att.global_position = p.global_position + Vector3(0, 0, 1.6)
	p.call("take_hit", 5.0, false, far_att)
	check.call("one within it is", bool(far_att.call("has_status", "dulled")))
	(p.get("buffs") as Dictionary).clear()
	body.hp = body.total_max()
	# Crosswind Veil: a shot passing close curves away and pays a pip
	_cast(p, "veil")
	var ShotScript: GDScript = load("res://scripts/enemy_shot.gd")
	var arrow: Node3D = _keep(ShotScript.new())
	arrow.set("dir", Vector3(0, 0, 1))
	arrow.set("damage", 18.0)
	arrow.set("target", p)
	t.add_child(arrow)
	arrow.set_physics_process(false)
	arrow.global_position = p.global_position + Vector3(1.0, 1.0, -8.0)
	p.set("pips", 0)
	for i: int in 60:
		if is_instance_valid(arrow) and not arrow.is_queued_for_deletion():
			arrow.call("_physics_process", STEP)
	check.call("Crosswind Veil: a shot within %s m curves away and pays a pip" % str(GameData.ability("veil")["deflect_radius"]),
		_near(body.hp, body.total_max()) and int(p.get("pips")) == int(GameData.ability("veil")["gain_pips_per_deflect"]), "pips %d hp %f" % [int(p.get("pips")), body.hp])
	(p.get("buffs") as Dictionary).clear()
	# Downdraft leaps to the aimed point, no further
	var dd: Dictionary = GameData.ability("downdraft")
	var start: Vector3 = p.global_position
	p.set("cursor_fixed", start + Vector3(0, 0, -4.0))
	p.set("pips", 0)
	_cast(p, "downdraft")
	for i: int in 40:
		p.call("_physics_process", STEP)
	check.call("Downdraft leaps to where you aim (4 m), not its full %s m" % str(float(dd["dash_speed"]) * float(dd["dash_time"])),
		_near(start.distance_to(p.global_position), 4.0, 0.15), "%.2f m" % start.distance_to(p.global_position))
	p.set("cursor_fixed", null)
	_clean()


# --- the data -------------------------------------------------------------------------------------

func _data() -> void:
	var ids: Array = GameData.affinity_ids()
	check.call("eighteen affinities, each with a kit of three of its own starters", ids.size() == 18 and ids.all(func(a: Variant) -> bool:
		var kit: Array = GameData.affinity(str(a)).get("kit", [])
		return kit.size() == 3 and kit.all(func(k: Variant) -> bool:
			return str(GameData.ability(str(k)).get("affinity", "")) == str(a) and bool(GameData.ability(str(k)).get("starter", false)))), str(ids))
	var still: Array[String] = DROPPED.filter(func(id: String) -> bool: return GameData.abilities.has(id))
	check.call("the %d skills the v2 drafts drop are gone" % DROPPED.size(), still.is_empty(), str(still))
	var off_rune: Array[String] = []
	for id: String in GameData.abilities:
		var ab: Dictionary = GameData.ability(id)
		var rid: String = str(ab.get("base_rune", ""))
		var r: Dictionary = GameData.rune(rid)
		if r.is_empty() or str(r.get("affinity", "")) != str(ab.get("affinity", "")) or GameData.skill_anchor(id) != rid or str(r.get("name", "")) != str(ab.get("rune", "")):
			off_rune.append("%s (%s)" % [id, rid])
	check.call("every skill sits on exactly the rune its draft names, a rune of its own affinity (%d skills)" % GameData.abilities.size(), off_rune.is_empty(), str(off_rune))
	# the ascension boost reads aspects through the rune stat groups: each draft-named field must be a number one reaches
	var unreached: Array[String] = []
	for id: String in GameData.abilities:
		var ab: Dictionary = GameData.ability(id)
		var mags: Array = (ab.get("magnitude", []) as Array).map(func(m: Dictionary) -> String: return str(m["path"]))
		var fields: Dictionary = ab.get("ascension_fields", {})
		if fields.is_empty():
			unreached.append("%s: no ascension fields" % id)
			continue
		for aspect: String in Ascension.aspect_ids():
			if not fields.has(aspect):
				unreached.append("%s: no %s field" % [id, aspect])
				continue
			for path: String in str(fields[aspect]).split(" + "):
				var groups: Array[String] = Runes.active().groups_of_path(ab, path)
				var want: Dictionary = Ascension.aspect_groups(aspect)
				var ok: bool = groups.any(func(g: String) -> bool: return want.has(g)) or (aspect == "power" and mags.has(path)) \
					or (path == "recovery" and want.has("windup"))
				if not ok:
					unreached.append("%s: %s -> %s" % [id, aspect, path])
	check.call("every skill's four ascension aspects reach a real number of it (through the stat groups, or as its magnitude)", unreached.is_empty(), str(unreached))
	var no_desc: Array[String] = []
	for sid: String in GameData.status_ids():
		if StatusText.desc(sid).strip_edges() == "":
			no_desc.append(sid)
	for pid: String in GameData.player_state_ids():
		if str(GameData.player_state(pid).get("desc", "")).strip_edges() == "":
			no_desc.append(pid)
	var v2_statuses: Array[String] = ["taunted", "turned", "tithed", "bidden", "quarry", "charmed", "doubting", "steeped", "condemned", "penitent",
		"exiled", "leeched", "leashed", "tormented", "stasis", "barbed"]
	var missing: Array[String] = v2_statuses.filter(func(sid: String) -> bool: return GameData.status(sid).is_empty())
	check.call("the 14 statuses the v2 runes grant, and the drafts' own (Stasis, Barbed), are in the status engine", missing.is_empty(), str(missing))
	check.call("every status and every state of yours has a written desc", no_desc.is_empty(), str(no_desc))


func _near(a: float, b: float, eps: float = 0.01) -> bool:
	return absf(a - b) <= eps
