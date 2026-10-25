extends Node
## Cast every skill (build brief 2026-10-22). For each of the game's abilities:
##   1. a test character of its affinity (Player.make_test_character) in a small test world with
##      dummy enemies that face it and do not fight back;
##   2. the skill cast as it is aimed - at the first dummy (pointed, targeted or aimed), with what
##      it spends set out first (statuses on the dummies, a corpse, a patch of growth, a blood pool,
##      held blood, pips, heat);
##   3. a few seconds of game time ticked (physics frames at the fixed physics rate);
## then all of it again with a SEALED word, made through two level locks (design/14 sections 8 and 11):
## three good modifiers from the skill's own draft on ring 1 at the first lock, and - where the runes
## allow - a great ring of five round ring 2 at the second, so the rune engine (effects_v2) and the
## great ring's repeat run on every skill. It fails on any script error (ErrorCatcher) and on
## a cast that is refused or touches nothing. One line per skill: what it hit, the statuses it
## left, and whether it is simplified. Run headless:
##   --headless --fixed-fps 60 --path game res://tests/cast_every_skill.tscn   (prints CASTALL: PASS / FAIL)
## (--fixed-fps 60 runs game time as fast as it can be computed; add -- --only=<affinity or id>)
## It proves every skill runs and reaches something; it says nothing about feel or balance.

const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const SECONDS := 3.0

var _errors: ErrorCatcher
var _world: Node3D
var _failures: Array[String] = []


func _ready() -> void:
	_errors = ErrorCatcher.install()
	# procedural bodies: the real ones take seconds each to build and say nothing about the skills
	(GameData.balance["art"] as Dictionary)["real_bodies"] = false
	var counts := {"hit": 0, "status": 0, "effect": 0, "simplified": 0, "worded": 0, "great": 0}
	var simplified: Array[String] = []
	var only: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=")
	for id: String in GameData.abilities:
		var ab: Dictionary = GameData.ability(id)
		if only != "" and id != only and str(ab["affinity"]) != only:
			continue
		var before: int = _errors.count()
		var plain: Dictionary = await _try(id, [])
		var runes: Array[String] = _good_runes(id)
		var worded: Dictionary = await _try(id, runes)
		var errs: int = _errors.count() - before
		var verdict: String = "hit" if bool(plain["hit"]) else ("status" if not (plain["statuses"] as Array).is_empty() else ("effect" if bool(plain["effect"]) else "nothing"))
		if bool(plain["hit"]):
			counts["hit"] += 1
		if not (plain["statuses"] as Array).is_empty():
			counts["status"] += 1
		if verdict == "effect":
			counts["effect"] += 1
		if bool(worded["cast"]):
			counts["worded"] += 1
		if bool(worded.get("great", false)):
			counts["great"] += 1
		if not bool(worded.get("sealed", true)):
			_failures.append("%s: the level locks would not seal its word (%s)" % [id, str(worded.get("seal_why", ""))])
		if ab.has("simplified"):
			counts["simplified"] += 1
			simplified.append("%s (%s)" % [id, str(ab["simplified"])])
		print("  %-18s %-10s %-15s plain: %s | word %s: %s%s%s" % [id, str(ab["affinity"]), str(ab["kind"]), _describe(plain),
			"+".join(runes), _describe(worded), "  [simplified]" if ab.has("simplified") else "", ("  ERRORS %d" % errs) if errs > 0 else ""])
		if not bool(plain["cast"]) or not bool(worded["cast"]):
			_failures.append("%s was refused" % id)
		elif verdict == "nothing":
			_failures.append("%s touched nothing" % id)
		if errs > 0:
			_failures.append("%s raised %d script error(s): %s" % [id, errs, _errors.first()])
	print("simplified (%d):" % simplified.size())
	for s: String in simplified:
		print("  " + s)
	var n: int = 0
	for id2: String in GameData.abilities:
		if only == "" or id2 == only or str(GameData.ability(id2)["affinity"]) == only:
			n += 1
	print("CASTALL: %s - %d skills cast plain and with a sealed word: %d hit something, %d applied a status, %d did something else (no damage, no status), %d simplified, %d cast with a word, %d of them with a great ring; %d script errors%s" % [
		"PASS" if _failures.is_empty() and _errors.count() == 0 else "FAIL", n, int(counts["hit"]), int(counts["status"]), int(counts["effect"]),
		int(counts["simplified"]), int(counts["worded"]), int(counts["great"]), _errors.count(), "" if _failures.is_empty() else ": " + "; ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() and _errors.count() == 0 else 1)


## One cast's result in words: "cast, hit 2, status chilled,frozen" / "cast, effect" / "REFUSED (why)".
func _describe(r: Dictionary) -> String:
	if not bool(r["cast"]):
		return "REFUSED (%s)" % str(r["why"])
	var out: String = "cast"
	if bool(r["hit"]):
		out += ", hit %d" % int(r["hits"])
	if not (r["statuses"] as Array).is_empty():
		out += ", status " + ",".join(r["statuses"])
	elif bool(r["effect"]) and not bool(r["hit"]):
		out += ", effect"
	return out


## Three good modifiers from the skill's own draft, as rune ids: its affinity's base rune of that
## name, else the universal rune of that name.
func _good_runes(id: String) -> Array[String]:
	var ab: Dictionary = GameData.ability(id)
	var out: Array[String] = []
	for name: Variant in ab.get("good_modifiers", []):
		var rid := ""
		for b: String in (GameData.runes["base_runes"] as Dictionary):
			var r: Dictionary = GameData.runes["base_runes"][b]
			if str(r["name"]) == str(name) and str(r["affinity"]) == str(ab["affinity"]):
				rid = b
		if rid == "":
			for u: String in (GameData.runes["universal_runes"] as Dictionary):
				if str(GameData.runes["universal_runes"][u]["name"]) == str(name):
					rid = u
		if rid != "" and not out.has(rid) and rid != GameData.skill_anchor(id):
			out.append(rid)
		if out.size() == 3:
			break
	return out


## One cast in a fresh world. Returns {cast, why, hit, hits, statuses, effect}.
func _try(id: String, runes: Array[String]) -> Dictionary:
	var ab: Dictionary = GameData.ability(id)
	var aff: String = str(ab["affinity"])
	_world = Node3D.new()
	add_child(_world)
	var floor := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	col.shape = box
	floor.add_child(col)
	floor.position = Vector3(0, -0.5, 0)
	_world.add_child(floor)
	var p: CharacterBody3D = PlayerScript.new()
	_world.add_child(p)
	p.global_position = Vector3.ZERO
	p.call("make_test_character", aff)
	p.set("active", true)
	p.set("effects", [] as Array[TalentEffect])
	p.set("_facing", Vector3(0, 0, -1))
	# the dummies: one straight ahead, one further on and to the side (mailed), one beside you
	var a: CharacterBody3D = _dummy(p, Vector3(0, 0, -3.0), "grunt")
	var b: CharacterBody3D = _dummy(p, Vector3(1.2, 0, -5.5), "pavise")
	var c: CharacterBody3D = _dummy(p, Vector3(2.4, 0, -1.2), "grunt")
	var dummies: Array = [a, b, c]
	await get_tree().physics_frame
	_set_out(p, ab, dummies)
	p.set("cursor_fixed", a.global_position)
	p.set("hovered", a)
	var index := -1
	var list: Array = p.get("abilities")
	for i: int in list.size():
		if str(list[i]["id"]) == id:
			index = i
	if index < 0:
		_world.queue_free()
		return {"cast": false, "why": "not learned", "hit": false, "hits": 0, "statuses": [], "effect": false}
	var sealed := true
	var seal_why := ""
	var great := false
	if not runes.is_empty():
		var made: Dictionary = _seal_word(p, index, runes)
		sealed = bool(made["ok"])
		seal_why = str(made["text"])
		great = (p.call("ability_stats", list[index]) as Dictionary).has("rune_repeat")
	var hp_before: Array = dummies.map(func(e: Node) -> float: return (e.get("body") as Body).hp)
	var poise_before: Array = dummies.map(func(e: Node) -> float: return float(e.get("poise")))
	var st_before: Array = dummies.map(func(e: Node) -> Array: return (e.get("statuses") as Dictionary).keys())
	var groups_before: Dictionary = _counts()
	var essence_before: float = float(p.get("essence"))
	var sinks_before: float = (p.get("body") as Body).sink_total()
	var reflux_before: float = float(p.call("reflux_of", aff))
	p.call("cast_ability", index)
	var cast: bool = float(p.get("_recover_t")) > 0.0 or not (p.get("_held") as Dictionary).is_empty() or float(p.get("_windup_t")) > 0.0 \
		or float(p.get("essence")) < essence_before or float(p.call("reflux_of", aff)) != reflux_before
	var why: String = str((p.get("log_lines") as Array).back()) if not cast and not (p.get("log_lines") as Array).is_empty() else ""
	var statuses: Array = []
	var hits := 0
	var effect := false
	var frames: int = int(SECONDS * float(Engine.physics_ticks_per_second))
	for f: int in frames:
		await get_tree().physics_frame
		if f == 3 and ab.has("window_s") and is_instance_valid(a):
			p.call("take_hit", 10.0, false, a)            # a counter waits for a blow: the first dummy throws one
		for k: int in dummies.size():
			var e: Node = dummies[k]
			if not is_instance_valid(e):
				continue
			for s: String in (e.get("statuses") as Dictionary):
				if not (st_before[k] as Array).has(s) and not statuses.has(s):
					statuses.append(s)
	for k: int in dummies.size():
		var e2: Node = dummies[k]
		if not is_instance_valid(e2) or (e2.get("body") as Body).hp < float(hp_before[k]) - 0.01:
			hits += 1
	var groups_after: Dictionary = _counts()
	for g: String in groups_after:
		if int(groups_after[g]) > int(groups_before.get(g, 0)):
			effect = true
	# a self buff, a shove, a move, held blood or a refund are effects too
	if not (p.get("buffs") as Dictionary).is_empty() or (p.global_position - Vector3.ZERO).length() > 0.5 or int(p.get("held_blood")) > 0 			or float(p.call("ward")) > 0.0:
		effect = true
	for k2: int in dummies.size():
		var e3: Node3D = dummies[k2]
		if is_instance_valid(e3) and e3.global_position.distance_to(_start_of(k2)) > 0.3:
			effect = true
		# footing taken (a hard interrupt, a slip on glaze) is an effect on it too
		if is_instance_valid(e3) and float(e3.get("poise")) < float(poise_before[k2]) - 0.01:
			effect = true
	if is_instance_valid(p.get("rod")):
		effect = true                                 # a rod planted, waiting for lightning near it
	if (p.get("body") as Body).sink_total() < sinks_before - 0.01:
		effect = true                                 # a wound mended
	_world.queue_free()
	await get_tree().process_frame
	return {"cast": cast, "why": why, "hit": hits > 0, "hits": hits, "statuses": statuses, "effect": effect, "sealed": sealed, "seal_why": seal_why, "great": great}


## The word, lock by lock (no free edit since Brent 2026-10-23), every ring FULL (Brent 2026-10-24:
## "Every slot should be filled to be fully formed"): at the first level lock the good runes on ring 1
## (joined to the skill's own rune where it has bonds left, else to the first of them), its other
## places filled with universal runes, the vestige set over it as the keystone; at the second, a great
## ring on ring 2 - a three-bond rune of the skill's affinity and four universal runes bonded round,
## the three-bond one joined to a ring-1 rune with a bond to spare - if the rules let it be built (it
## fills ring 2's five places), else ring 2 filled rune by rune; the remnant set over it. Both binds go
## through the test hook Player.test_bind_unclosed (a sure roll; the closed-word rule waived,
## everything else the real lock). Returns {ok, text}.
func _seal_word(p: Node, index: int, runes: Array[String]) -> Dictionary:
	p.call("open_seal", index)
	var placed: Array[int] = []
	for rid: String in runes:
		var r: Dictionary = p.call("word_add", index, rid, 0, 1)
		if not bool(r["ok"]) and not placed.is_empty():
			r = p.call("word_add", index, rid, placed[0], 1)
		if bool(r["ok"]):
			placed.append(int(r["node"]))
	_fill_ring(p, index, 1, placed)
	_set_keystone(p, index)
	var lock1: String = str(p.call("test_bind_unclosed", 0.0))
	if lock1 != "bound":
		p.call("close_seal")
		return {"ok": false, "text": "the first lock: " + lock1}
	p.call("open_seal", index)
	var word: Dictionary = p.call("ability_word", index)
	var host := -1
	for i: int in placed:
		if RuneWord.degree(word, i) < BondRules.valence(RuneWord.node_id(word, i)):
			host = i
			break
	var aff: String = str(GameData.ability(str(((p.get("abilities") as Array)[index] as Dictionary)["id"])).get("affinity", ""))
	var hub := ""
	for rid2: String in (GameData.runes["base_runes"] as Dictionary):
		if str(GameData.rune(rid2)["affinity"]) == aff and BondRules.valence(rid2) == 3:
			hub = rid2
			break
	if host >= 0 and hub != "":
		var r2: Dictionary = p.call("word_add", index, hub, host, 2)
		if bool(r2["ok"]):
			var first: int = int(r2["node"])
			var prev: int = first
			var ok := true
			for u: String in ["UNI-19a", "UNI-28a", "UNI-26b", "UNI-27b"]:
				var r3: Dictionary = p.call("word_add", index, u, prev, 2)
				if not bool(r3["ok"]):
					ok = false
					break
				prev = int(r3["node"])
			if ok:
				p.call("word_toggle_link", index, prev, first)
	# the second lock forms ring 2: if no great ring could be hung on ring 1 (no rune there with a bond to
	# spare), one rune out on ring 2 joined to ring 1 where any bond is free; then every place of ring 2
	# filled (a great ring already fills it)
	var word2: Dictionary = p.call("ability_word", index)
	if RuneWord.ring_nodes(word2, 2).size() < 5:
		var tries: Array[String] = ["UNI-19a", "UNI-28a", "UNI-26b", "UNI-27b"]
		tries.append_array(runes)
		_one_on_ring2(p, index, RuneWord.ring_nodes(word2, 1), tries)
	_fill_ring(p, index, 2, [])
	_set_keystone(p, index)
	var second: String = str(p.call("test_bind_unclosed", 0.0))
	p.call("close_seal")
	return {"ok": second == "bound", "text": "the second lock: " + second}


## Set one of `tries` on ring 2, joined to one of the ring-1 runes `hosts`; true if one took.
func _one_on_ring2(p: Node, index: int, hosts: Array, tries: Array[String]) -> bool:
	for host: Variant in hosts:
		for rid: String in tries:
			if bool((p.call("word_add", index, rid, int(host), 2) as Dictionary)["ok"]):
				return true
	return false


## Fill every empty place of ring k with universal runes, joined to a rune of `hosts` where one has a
## bond to spare, else set alone (the test hook waives the closed-word rule).
func _fill_ring(p: Node, index: int, k: int, hosts: Array[int]) -> void:
	var rr: RingRules = Runes.active() as RingRules
	var fillers: Array[String] = ["UNI-19a", "UNI-28a", "UNI-26b", "UNI-27b", "UNI-21a"]
	var j := 0
	var guard := 0
	while RuneWord.ring_nodes(p.call("ability_word", index), k).size() < rr.ring_capacity(k) and guard < 40:
		guard += 1
		var rid: String = fillers[j % fillers.size()]
		j += 1
		var r: Dictionary = {"ok": false}
		for h: int in hosts:
			r = p.call("word_add", index, rid, h, k)
			if bool(r["ok"]):
				break
		if not bool(r["ok"]):
			p.call("word_add", index, rid, -1, k)


## Set the first carried construct of the tier as this lock's keystone.
func _set_keystone(p: Node, index: int) -> void:
	var need: String = str(p.call("pending_tier", (p.get("abilities") as Array)[index]))
	var groups: Array = p.call("construct_groups", need)
	if not groups.is_empty():
		p.call("choose_seal_construct", int((groups[0] as Dictionary)["index"]))


func _start_of(k: int) -> Vector3:
	return [Vector3(0, 0, -3.0), Vector3(1.2, 0, -5.5), Vector3(2.4, 0, -1.2)][k]


## How many of the things skills leave behind stand in the world now.
func _counts() -> Dictionary:
	var out := {}
	for g: String in ["ground_zones", "blasts", "stones", "lures", "thralls", "seeds", "growth", "blood_pools", "lamps", "light_sources", "fallen"]:
		out[g] = get_tree().get_nodes_in_group(g).size()
	return out


## An enemy that faces you, never fights back, and has health and footing to spare.
func _dummy(p: Node3D, offset: Vector3, kind: String) -> CharacterBody3D:
	var e: CharacterBody3D = EnemyScript.new()
	e.call("setup", kind, p, 1.0)
	e.position = p.global_position + offset
	_world.add_child(e)
	e.set("target", null)
	(e.get("body") as Body).max_hp = 5000.0
	(e.get("body") as Body).hp = 5000.0
	e.set("poise_max", 100000.0)
	e.set("poise", 100000.0)
	var to: Vector3 = p.global_position - e.global_position
	to.y = 0.0
	e.set("facing", to.normalized())
	return e


## Set out what the skill spends or needs: the status it consumes on every dummy, a corpse, your
## own growth and blood, held blood, swallowed light, pips, heat; dark ground for Daybreak.
func _set_out(p: Node, ab: Dictionary, dummies: Array) -> void:
	var needs: Array = []
	for key: String in ["consume_status", "needs_status", "bonus_vs_status"]:
		var v: Variant = ab.get(key)
		if v is Array:
			needs.append_array(v)
		elif v != null:
			needs.append(str(v))
	var hit: Dictionary = ab.get("on_hit", {})
	if hit.get("consume") is Dictionary:
		needs.append(str(hit["consume"].get("status", "")))
	if ab.has("needs_shadow") or ab.has("dark_status_s"):
		pass
	for e: Node in dummies:
		for st: Variant in needs:
			if str(st) != "":
				e.call("add_status", str(st), 3, p)
	# a body to raise, lay or haunt, ahead of you
	var f := Fallen.new()
	f.life = 30.0
	_world.add_child(f)
	f.global_position = Vector3(-1.0, 0, -3.0)
	# growth of your own by the first dummy, and a pool of blood beside you
	if GameData.affinity(str(ab["affinity"])).has("growth"):
		p.call("plant_growth", Vector3(0, 0, -3.0), {"kind": "bramble"})
	if p.call("held_blood_max") > 0:
		p.call("spill_blood", Vector3(0, 0, -1.5), 1, false)
		p.set("held_blood", 6)
	p.call("store_add", "swallowed", 3, 5, 12.0)
	p.call("store_add", "stolen", 40, 100, 12.0)          # Unholy's stolen life (Black Reckoning spends it)
	if bool(ab.get("consume_thralls", false)):
		# a thrall of yours by the first dummy, for Bone Burst to spend
		var th := Thrall.new()
		th.caster = p
		th.skill = "test"
		th.life = 30.0
		th.tags = ["ability", str(ab["affinity"])]
		th.position = Vector3(-0.8, 0, -2.4)
		_world.add_child(th)
	# a wound to mend (Regrowth)
	(p.get("body") as Body).add_wound("test_wound", "Test wound", 30.0, 10.0)
	p.set("pips", 6)
	var aff: String = str(ab["affinity"])
	if ab.has("heat_cost") or ab.has("damage_from_heat") or (hit.has("status_s_per_heat")):
		(p.get("reflux_by") as Dictionary)[aff] = 45.0
	if str(ab.get("consume_zone", "")) != "":
		p.call("lay_cloud", Vector3(0, 0, -3.0), {"radius": 2.0, "life": 8.0, "payload": {}}, ["dark"])
		for z: Node in get_tree().get_nodes_in_group("ground_zones"):
			z.set("dark", true)
			z.set("kind", str(ab["consume_zone"]))
