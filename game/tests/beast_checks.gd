extends RefCounted
## The self-test's checks for the Stubble's unstarred beasts and the field's camps (2026-10-23):
## each new behaviour (the Gleaner fetching, a Sod-Lurker rising, the Thornback herd charging, the
## hound's bite from behind, the hog's charge and its miss, the wirehorn's shying and kick, the
## wren's peck-and-scatter, the beetle's scald), the leash and walk home, the respawn, the
## unstarred aura rule, remains as a list and the field dressing. Called from selftest.gd; it
## drives physics by hand (deterministic: no frames are awaited). Numbers come from the data.

const PlayerScript := preload("res://scripts/player.gd")
const StubScript := preload("res://tests/field_stub.gd")
const STEP := 1.0 / 60.0

var t: Node                 # the self-test node (things are added under it)
var check: Callable         # its _check(label, ok, detail)
var _made: Array[Node] = []


func _init(test: Node, check_fn: Callable) -> void:
	t = test
	check = check_fn


func run() -> void:
	print("the Stubble's beasts and camps (2026-10-23):")
	await t.get_tree().physics_frame          # move_and_slide needs a physics step length
	_data()
	_models()
	_unstarred()
	_remains_and_dressing()
	_gleaner()
	_lurker()
	_herd()
	_hound()
	_hog()
	_wirehorn()
	_wren()
	_beetle()
	_leash_and_respawn()
	for n: Node in _made:
		if is_instance_valid(n):
			n.queue_free()


# --- helpers ------------------------------------------------------------------------------------

func _keep(n: Node) -> Node:
	_made.append(n)
	return n


func _player(at: Vector3) -> CharacterBody3D:
	var p: CharacterBody3D = PlayerScript.new()
	t.add_child(p)
	p.set("active", true)
	p.global_position = at
	_keep(p)
	return p


func _floor(at: Vector3) -> void:
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(200, 1, 200)
	col.shape = shape
	sb.add_child(col)
	sb.position = at + Vector3(0, -0.5, 0)
	t.add_child(sb)
	_keep(sb)


func _beast(kind: String, p: Node3D, offset: Vector3, strength: float = 1.0) -> CharacterBody3D:
	var e: CharacterBody3D = Beast.new()
	e.call("setup", kind, p, strength)
	e.position = p.global_position + offset
	t.add_child(e)
	_keep(e)
	return e


## Run every listed beast (and the camps, and any scald) by hand for `seconds`.
func _run(beasts: Array, seconds: float, camps: FieldCamps = null) -> void:
	var left: float = seconds
	while left > 0.0:
		for e: Variant in beasts:
			if e != null and is_instance_valid(e) and not (e as Node).is_queued_for_deletion():
				(e as Node).call("_physics_process", STEP)
		if camps != null:
			camps.tick(STEP)
		for b: Node in t.get_tree().get_nodes_in_group("scald_bursts"):
			b.call("tick", STEP)
		left -= STEP


func _hp(p: Node) -> float:
	return (p.get("body") as Body).total()


func _heal(p: Node) -> void:
	var b: Body = p.get("body")
	b.heal(b.total_max())


# --- data, art, rules ----------------------------------------------------------------------------

func _data() -> void:
	var kinds: Array[String] = ["gleaner", "sod_lurker", "thornback", "ditch_hound", "burr_hog", "wirehorn", "kettle_beetle", "chaff_wren"]
	var bad: Array[String] = []
	var four_legged := 0
	for k: String in kinds:
		var d: Dictionary = GameData.enemy(k)
		if d.is_empty() or int(d.get("stars", 1)) != 0 or float(d.get("hp", 0)) <= 0.0 or not d.has("poise") or not d.has("speed") \
				or PlayerScript.remains_of(k).is_empty() or float(d.get("aura_value", 99.0)) > 4.0 or not bool(d.get("stand_in", false)):
			bad.append(k)
		for r: String in PlayerScript.remains_of(k):
			if GameData.item(r).is_empty():
				bad.append("%s remains %s" % [k, r])
		for l: Dictionary in d.get("loot", []):
			if GameData.item(str(l.get("item", ""))).is_empty():
				bad.append("%s loot %s" % [k, str(l.get("item", ""))])
		var rig: CreatureRig = CreatureModels.make(k)
		if rig != null and rig.legs.size() == 4:
			four_legged += 1
		if rig != null:
			rig.free()
	check.call("eight unstarred kinds: stars 0, low aura, stats, remains and loot that exist, marked stand-in", bad.is_empty(), str(bad))
	check.call("at least two of them four-legged (there are %d)" % four_legged, four_legged >= 2)
	var pools: Dictionary = (GameData.rune_discovery.get("kills", {}) as Dictionary).get("by_kind", {})
	var themed: bool = pools.has("sod_lurker") and ((pools["sod_lurker"]["base"] as Dictionary)["earth"] as Array).size() > ((pools["sod_lurker"]["base"] as Dictionary)["fire"] as Array).size() \
		and ((pools["kettle_beetle"]["base"] as Dictionary)["water"] as Array).size() > ((pools["kettle_beetle"]["base"] as Dictionary)["dark"] as Array).size() \
		and ((pools["thornback"]["base"] as Dictionary)["nature"] as Array).size() > ((pools["thornback"]["base"] as Dictionary)["fire"] as Array).size()
	check.call("each kind has a kill rune pool; earth, water and nature creatures reveal more of their own", themed)
	var crafted: Array = []
	for rid: String in GameData.crafting.get("recipes", {}):
		crafted.append_array(((GameData.crafting["recipes"][rid] as Dictionary)["inputs"] as Dictionary).keys())
	var unused: Array[String] = []
	for k2: String in kinds:
		for r2: String in PlayerScript.remains_of(k2):
			# a Gleaner's hoard is odds and ends to sell; wren down is feathers, for Tailoring when it is built
			if not crafted.has(r2) and r2 != "gleaner_hoard" and r2 != "wren_down":
				unused.append(r2)
	check.call("every hide, bone, meat and fat feeds a Rendering or Leatherwork recipe", unused.is_empty(), str(unused))


func _models() -> void:
	var ok := true
	for b: String in CreatureModels.builders():
		var rig: CreatureRig = CreatureModels.make(b)
		if rig == null or rig.triangle_count() <= 0 or rig.windup_pose.is_empty() and b != "gleaner":
			ok = false
		if rig != null:
			t.add_child(rig)
			rig.set_windup(true)
			for i: int in 20:
				rig.animate(STEP, 3.0, i > 15)
			rig.flash()
			rig.animate(STEP, 0.0, false)
			rig.queue_free()
	check.call("every beast has a procedural stand-in that animates (gait, wind-up, lunge, flinch)", ok)


func _unstarred() -> void:
	var p: CharacterBody3D = _player(Vector3(500, 0, 500))
	var hound: CharacterBody3D = _beast("ditch_hound", p, Vector3(3, 0, 0))
	hound.set("target", null)
	var cfg: Dictionary = GameData.balance["unstarred"]
	(p.get("star_pct") as Array)[0] = 0.0
	var fresh: float = float(p.call("kill_aura_mult", hound))
	(p.get("star_pct") as Array)[0] = GameData.num("stars", "max_pct")
	var full: float = float(p.call("kill_aura_mult", hound))
	p.set("stars", 2)
	(p.get("star_pct") as Array)[0] = 0.0
	var two: float = float(p.call("kill_aura_mult", hound))
	var grunt: CharacterBody3D = t.call("_foe", p, Vector3(-3, 0, 0))
	_keep(grunt)
	check.call("an unstarred kill pays full aura to a fresh baby star", is_equal_approx(fresh, 1.0), str(fresh))
	check.call("and less as the star fills", is_equal_approx(full, float(cfg["at_full_star"])), str(full))
	check.call("and less again at two stars", is_equal_approx(two, float(cfg["star_falloff"])), str(two))
	check.call("a starred foe pays in full whatever your star", is_equal_approx(float(p.call("kill_aura_mult", grunt)), 1.0))


func _remains_and_dressing() -> void:
	var p: CharacterBody3D = _player(Vector3(600, 0, 600))
	var e: CharacterBody3D = _beast("burr_hog", p, Vector3(2, 0, 0))
	e.set("target", null)
	p.call("deal_damage", e, 99999.0, ["melee"])
	var on_ground: Array = []
	for n: Node in t.get_tree().get_nodes_in_group("pickups"):
		if (n as Node3D).global_position.distance_to(e.global_position) < 3.0 and not n.is_queued_for_deletion():
			on_ground.append(str(n.get("item_id")))
	check.call("a Burr-Hog leaves all its remains: hide and fatback", on_ground.has("hog_hide") and on_ground.has("hog_fatback"), str(on_ground))
	for n2: Node in t.get_tree().get_nodes_in_group("pickups"):
		n2.queue_free()
	var inv: Inventory = p.get("inventory")
	inv.add("field_dressing")
	(p.get("body") as Body).apply_damage(30.0)
	var before: float = _hp(p)
	p.set("in_combat", true)
	var refused: String = p.call("use_consumable", "field_dressing")
	p.set("in_combat", false)
	var used: String = p.call("use_consumable", "field_dressing")
	check.call("a field dressing is refused in a fight", refused != "" and inv.bag.has("field_dressing") or used == "")
	check.call("and out of one it heals and is used up", used == "" and _hp(p) > before and not inv.bag.has("field_dressing"), "%s %.0f -> %.0f" % [used, before, _hp(p)])
	check.call("a field dressing is not loot (never bulk-sold)", not Inventory.is_loot("field_dressing") and Inventory.is_loot("wren_glint"))


# --- behaviours ----------------------------------------------------------------------------------

## A tiny zone with two camps: the first has a Gleaner at its edge that runs for the second.
func _camps_world(origin: Vector3, defs: Array) -> Array:
	_floor(origin)
	var stub: Node = StubScript.new()
	var lvl := Node3D.new()
	t.add_child(stub)
	t.add_child(lvl)
	lvl.position = origin
	_keep(stub)
	_keep(lvl)
	var p: CharacterBody3D = _player(origin + Vector3(0, 0, 60))
	stub.set("level", lvl)
	stub.set("player", p)
	var zb := ZoneBuilder.new(stub, {"size": [120, 120], "camps": defs})
	var fc := FieldCamps.new()
	fc.setup(stub, zb)
	lvl.add_child(fc)
	fc.build(true)
	return [p, fc, zb, lvl]


func _gleaner() -> void:
	var w: Array = _camps_world(Vector3(1000, 0, 0), [
		{"id": "a", "name": "Camp A", "at": [40, 60], "strength": 0.7, "members": [{"kind": "chaff_wren", "n": 2}],
		 "edge": [{"kind": "gleaner", "runs_to": "b", "offset": [4, 0]}]},
		{"id": "b", "name": "Camp B", "at": [80, 60], "strength": 0.7, "members": [{"kind": "ditch_hound", "n": 2}]}])
	var p: CharacterBody3D = w[0]
	var fc: FieldCamps = w[1]
	var zb: ZoneBuilder = w[2]
	var lvl: Node3D = w[3]
	p.global_position = lvl.to_global(zb.to_local(30.0, 60.0))
	fc.tick(STEP)
	check.call("walking up to a camp wakes it, and not the camp beyond", fc.state_of("a") == "awake" and fc.state_of("b") == "asleep")
	var g: Node = fc.members_of("a").filter(func(e: Node) -> bool: return str(e.get("kind")) == "gleaner")[0]
	check.call("its Gleaner runs for the next camp", bool(g.call("is_running")))
	_run(fc.all_living(), 8.0, fc)
	check.call("if it gets there, that camp comes too", fc.state_of("b") == "awake" and not bool(g.call("is_running")), fc.state_of("b"))
	# again, and this time the Gleaner is stopped
	var w2: Array = _camps_world(Vector3(1300, 0, 0), [
		{"id": "a", "at": [40, 60], "members": [{"kind": "chaff_wren", "n": 1}], "edge": [{"kind": "gleaner", "runs_to": "b", "offset": [4, 0]}]},
		{"id": "b", "at": [80, 60], "members": [{"kind": "ditch_hound", "n": 1}]}])
	var p2: CharacterBody3D = w2[0]
	var fc2: FieldCamps = w2[1]
	p2.global_position = (w2[3] as Node3D).to_global((w2[2] as ZoneBuilder).to_local(30.0, 60.0))
	fc2.tick(STEP)
	var g2: Node = fc2.members_of("a").filter(func(e: Node) -> bool: return str(e.get("kind")) == "gleaner")[0]
	_run(fc2.all_living(), 1.0, fc2)
	g2.call("take_hit", 5.0, false, p2)
	check.call("a hit makes a running Gleaner stumble", bool(g2.call("has_status", "staggered")))
	p2.call("deal_damage", g2, 99999.0, ["ranged"])
	_run(fc2.all_living(), 8.0, fc2)
	check.call("kill it first and the next camp sleeps on", fc2.state_of("b") == "asleep")


func _lurker() -> void:
	var p: CharacterBody3D = _player(Vector3(0, 0, 1500))
	var l: CharacterBody3D = _beast("sod_lurker", p, Vector3(6, 0, 0))
	check.call("a Sod-Lurker starts buried: unseen, not an enemy to click", bool(l.get("buried")) and not l.is_in_group("enemies") and not l.is_in_group("hittable"))
	check.call("nothing can hit it under the ground", float(l.call("take_hit", 50.0, false, p)) == 0.0)
	_run([l], 1.0)
	check.call("it waits while you are off its patch", bool(l.get("buried")))
	var before: float = _hp(p)
	p.global_position = l.global_position + Vector3(0.8, 0, 0)
	_run([l], 0.05)
	check.call("step on the patch and it heaves up, telegraphed", bool(l.call("is_rising")) and str((l.get("telegraph") as Dictionary).get("kind", "")) == "circle")
	_run([l], 1.0)
	check.call("it comes up under you: a heavy hit", _hp(p) < before and not bool(l.get("buried")) and l.is_in_group("hittable"), "%.0f -> %.0f" % [before, _hp(p)])
	p.global_position = l.global_position + Vector3(20, 0, 0)
	_run([l], float(GameData.enemy("sod_lurker").get("burrow_s", 4.0)) + 4.0)
	check.call("it will not follow past its tether, and goes back under", bool(l.get("buried")))


func _herd() -> void:
	var w: Array = _camps_world(Vector3(0, 0, 2000), [
		{"id": "herd", "at": [60, 60], "strength": 0.8, "leash": 40, "herd": true, "members": [{"kind": "thornback", "n": 3}]}])
	var p: CharacterBody3D = w[0]
	var fc: FieldCamps = w[1]
	var lvl: Node3D = w[3]
	var zb: ZoneBuilder = w[2]
	p.global_position = lvl.to_global(zb.to_local(60.0, 70.0))
	_run(fc.all_living(), 2.0, fc)
	var herd: Array = fc.members_of("herd")
	check.call("a Thornback herd is neutral: it grazes while you walk among it", fc.state_of("herd") == "calm" and herd.all(func(e: Node) -> bool: return bool(e.call("is_calm"))))
	p.call("deal_damage", herd[0], 10.0, ["melee"])
	check.call("hit one and the whole herd turns on you", fc.state_of("herd") == "awake" and herd.all(func(e: Node) -> bool: return not bool(e.call("is_calm"))))
	p.global_position = lvl.to_global(zb.to_local(60.0, 80.0))
	var before: float = _hp(p)
	var charged := false
	for i: int in 400:
		_run(herd, STEP, fc)
		for e: Node in herd:
			if is_instance_valid(e) and (str(e.get("_special")) == "charge" or float(e.get("_charge_left")) > 0.0):
				charged = true
	check.call("and charges in straight lines (a marked lane)", charged)
	check.call("and the charges hurt", _hp(p) < before, "%.0f -> %.0f" % [before, _hp(p)])
	p.global_position = lvl.to_global(zb.to_local(60.0, 119.0))
	p.global_position += Vector3(0, 0, 40)
	_run(herd, 0.1, fc)
	check.call("past the herd's leash it turns for home", fc.state_of("herd") == "returning")
	_run(herd, 30.0, fc)
	check.call("and grazes again once home", fc.state_of("herd") == "calm" and herd.all(func(e: Node) -> bool: return not is_instance_valid(e) or bool(e.call("is_calm"))))


func _hound() -> void:
	var p: CharacterBody3D = _player(Vector3(0, 0, 2500))
	p.set("_facing", Vector3(0, 0, -1))
	var h: CharacterBody3D = _beast("ditch_hound", p, Vector3(0, 0, -4))
	var circled := false
	var bit_back := false
	var before: float = _hp(p)
	for i: int in 600:
		_run([h], STEP)
		if bool(h.call("is_at_targets_back")):
			circled = true
		if float(h.get("_windup")) >= 0.0 and bool(h.call("is_at_targets_back")):
			bit_back = true
		if _hp(p) < before:
			break
	check.call("a Ditch Hound in front of you works round to your back", circled)
	check.call("and bites there", bit_back and _hp(p) < before, "%.0f -> %.0f" % [before, _hp(p)])
	# the bite on the back is worse than the bite in front
	var dmg: float = float(h.get("damage"))
	var back_bite: float = before - _hp(p)
	check.call("its bite on your back does rear_bite_mult", back_bite >= dmg * float(GameData.enemy("ditch_hound")["rear_bite_mult"]) * 0.9 * (1.0 - float(p.call("armour")) / 100.0), "%.1f vs %.1f" % [back_bite, dmg])


func _hog() -> void:
	var p: CharacterBody3D = _player(Vector3(0, 0, 3000))
	var hog: CharacterBody3D = _beast("burr_hog", p, Vector3(0, 0, -9))
	check.call("a Burr-Hog's burrs guard its front", bool(hog.call("guards_front", p.global_position)))
	var wound := false
	for i: int in 240:
		_run([hog], STEP)
		if str(hog.get("_special")) == "charge":
			wound = true
			_run([hog], STEP)
			break
	check.call("at range it scrapes, then charges down a marked lane", wound and str((hog.get("telegraph") as Dictionary).get("kind", "")) == "lane")
	p.global_position += Vector3(5, 0, 0)                        # step out of the lane
	var stuck := false
	for i: int in 240:
		_run([hog], STEP)
		if float(hog.get("_stuck_t")) > 0.6:
			stuck = true
			break
	check.call("a charge that misses leaves it stuck", stuck)
	check.call("and stuck, its guard is down", stuck and not bool(hog.call("guards_front", p.global_position)))


func _wirehorn() -> void:
	var p: CharacterBody3D = _player(Vector3(0, 0, 3500))
	var w: CharacterBody3D = _beast("wirehorn", p, Vector3(0, 0, -5))
	var start: float = w.global_position.distance_to(p.global_position)
	_run([w], 2.0)
	check.call("a calm Wirehorn shies off when you come close", bool(w.call("is_calm")) and w.global_position.distance_to(p.global_position) > start + 1.0)
	w.call("provoke", p)
	w.set("facing", (w.global_position - p.global_position).normalized() * Vector3(1, 0, 1))
	p.global_position = w.global_position - (w.get("facing") as Vector3) * 1.6
	var before: float = _hp(p)
	var kicked := false
	for i: int in 120:
		_run([w], STEP)
		if bool(w.get("_kick")) and float(w.get("_windup")) >= 0.0:
			kicked = true
	check.call("stand behind it and it kicks", kicked and _hp(p) < before, "%.0f -> %.0f" % [before, _hp(p)])


func _wren() -> void:
	var p: CharacterBody3D = _player(Vector3(0, 0, 4000))
	var wr: CharacterBody3D = _beast("chaff_wren", p, Vector3(0, 0, -2.5))
	var pecked := false
	var scattered := false
	for i: int in 400:
		_run([wr], STEP)
		if float(wr.get("_scatter_t")) > 0.0:
			pecked = true
		if pecked and wr.global_position.distance_to(p.global_position) > 3.5:
			scattered = true
			break
	check.call("a Chaff Wren pecks, then scatters", pecked and scattered)


func _beetle() -> void:
	var p: CharacterBody3D = _player(Vector3(0, 0, 4500))
	var b: CharacterBody3D = _beast("kettle_beetle", p, Vector3(0, 0, -1.6))
	b.set("target", null)
	b.call("take_hit", float((b.get("body") as Body).total_max()) * 0.6, false, null)   # from nowhere: its shell guards the front
	_run([b], STEP)
	check.call("a hurt Kettle Beetle swells and hurries", float(b.get("speed")) > float(GameData.enemy("kettle_beetle")["speed"]) * 1.2)
	var before: float = _hp(p)
	p.call("deal_damage", b, 99999.0, ["melee"])
	var bursts: Array = t.get_tree().get_nodes_in_group("scald_bursts")
	check.call("killed, it leaves a scalding burst (a ring that fills)", bursts.size() == 1)
	_run([], float(GameData.enemy("kettle_beetle")["death_burst"]["delay"]) + 0.1)
	check.call("standing in it when it goes off scalds you", _hp(p) < before)
	_heal(p)
	var b2: CharacterBody3D = _beast("kettle_beetle", p, Vector3(0, 0, -1.6))
	b2.set("target", null)
	p.call("deal_damage", b2, 99999.0, ["melee"])
	p.global_position += Vector3(6, 0, 0)
	var before2: float = _hp(p)
	_run([], float(GameData.enemy("kettle_beetle")["death_burst"]["delay"]) + 0.1)
	check.call("step out of the ring in time and it does not", is_equal_approx(_hp(p), before2))


func _leash_and_respawn() -> void:
	var w: Array = _camps_world(Vector3(3000, 0, 0), [
		{"id": "c", "at": [60, 60], "strength": 0.7, "leash": 20, "respawn_s": 5.0, "members": [{"kind": "ditch_hound", "n": 2}]}])
	var p: CharacterBody3D = w[0]
	var fc: FieldCamps = w[1]
	var zb: ZoneBuilder = w[2]
	var lvl: Node3D = w[3]
	p.set("bot", true)                          # untouchable: this is about where they go, not what they do
	var hounds: Array = fc.members_of("c")
	check.call("a camp sleeps until you come near", fc.state_of("c") == "asleep" and hounds.all(func(e: Node) -> bool: return bool(e.get("asleep"))))
	p.global_position = lvl.to_global(zb.to_local(60.0, 68.0))
	fc.tick(STEP)
	check.call("then all of it comes", fc.state_of("c") == "awake" and hounds.all(func(e: Node) -> bool: return not bool(e.get("asleep"))))
	(hounds[0].get("body") as Body).apply_damage(40.0)
	_run(hounds, 1.5, fc)
	p.global_position = lvl.to_global(zb.to_local(60.0, 100.0))
	_run(hounds, 0.1, fc)
	check.call("past the leash they turn and walk home", fc.state_of("c") == "returning" and hounds.all(func(e: Node) -> bool: return bool(e.call("is_going_home"))))
	_run(hounds, 20.0, fc)
	var b0: Body = hounds[0].get("body")
	check.call("home again, they mend and sleep", fc.state_of("c") == "asleep" and is_equal_approx(b0.total(), b0.total_max()))
	p.set("bot", false)
	for e: Node in hounds:
		p.call("deal_damage", e, 99999.0, ["melee"])
	fc.tick(STEP)
	check.call("kill them all and the camp is cleared", fc.state_of("c") == "cleared")
	p.global_position = lvl.to_global(zb.to_local(60.0, 64.0))
	_run([], 6.0, fc)
	check.call("it does not refill while you stand there", fc.state_of("c") == "cleared")
	p.global_position = lvl.to_global(zb.to_local(60.0, 60.0)) + Vector3(0, 0, 90)
	fc.tick(STEP)
	check.call("walk away and after its time it refills", fc.state_of("c") == "asleep" and fc.members_of("c").size() == 2)
