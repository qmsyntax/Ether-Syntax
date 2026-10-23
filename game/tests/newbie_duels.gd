extends Node
## Can a brand-new character win in the Stubble? (Brent 2026-10-23: tune every beast so a fresh 1-star
## with its two starting skills at stage 0, in starting gear, can fight one or two at a time and win
## with care; a camp or the herd should be a real fight.)
##   godot --headless --path game res://tests/newbie_duels.tscn          (-- --only=<kind> --aff=<affinity>)
## For each of six affinities a FRESH character (begin_character's path: talent, affinities, two root
## skills, starting gear, a baby star - no test-character overrides, NOT invulnerable) fights each
## beast alone, a few in pairs, and the zone's camps, at the camp strengths of zones.json. A scripted
## fighter plays it "with care": it strikes and casts at the nearest foe, slings at what keeps away,
## and steps out of every telegraphed attack (circles, lanes, cones, a scald ring) - it does not
## kite, block or use the pack. Prints a table of win / time-to-kill / damage taken and
## "DUELS: PASS" when the singles and pairs are won at least `want_rate` of the time. Any script
## error fails it. It proves the numbers are winnable by a careful scripted player; feel needs Brent.

const PlayerScript := preload("res://scripts/player.gd")
const STEP := 1.0 / 60.0

var want_rate := 0.8
var time_limit := 75.0
var affinities: Array[String] = ["water", "earth", "fire", "wind", "lightning", "nature"]
## [label, [[kind, n], ...], strength, group] - group "single" and "pair" count toward the pass rate
var fights: Array = [
	["wren", [["chaff_wren", 1]], 0.7, "single"],
	["beetle", [["kettle_beetle", 1]], 0.6, "single"],
	["hound", [["ditch_hound", 1]], 0.6, "single"],
	["hog", [["burr_hog", 1]], 0.7, "single"],
	["wirehorn", [["wirehorn", 1]], 0.7, "single"],
	["gleaner", [["gleaner", 1]], 0.7, "single"],
	["lurker", [["sod_lurker", 1]], 0.7, "single"],
	["thornback", [["thornback", 1]], 0.8, "single"],
	["2 hounds", [["ditch_hound", 2]], 0.6, "pair"],
	["2 beetles", [["kettle_beetle", 2]], 0.6, "pair"],
	["3 wrens", [["chaff_wren", 3]], 0.7, "pair"],
	["camp: well-watch (5 wrens)", [["chaff_wren", 5]], 0.7, "camp"],
	["camp: tree (2 hounds, 3 wrens)", [["ditch_hound", 2], ["chaff_wren", 3]], 0.7, "camp"],
	["camp: Cut pickets (hog, 2 hounds)", [["burr_hog", 1], ["ditch_hound", 2]], 0.9, "camp"],
	["the herd (4 thornbacks)", [["thornback", 4]], 0.8, "camp"],
]

var results: Array = []
var errors: ErrorCatcher
var _world: Node3D


func _ready() -> void:
	errors = ErrorCatcher.install()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--aff="):
			affinities = [a.trim_prefix("--aff=")]
		elif a.begins_with("--only="):
			var want: String = a.trim_prefix("--only=")
			fights = fights.filter(func(f: Array) -> bool: return str(f[0]).contains(want))
	await get_tree().physics_frame
	for aff: String in affinities:
		for f: Array in fights:
			await _duel(aff, f)
	_report()


## A fresh character: begin_character's own steps, nothing more.
func _fresh(aff: String) -> CharacterBody3D:
	var p: CharacterBody3D = PlayerScript.new()
	_world.add_child(p)
	p.global_position = Vector3.ZERO
	p.call("set_talent", "one_percent_lifesteal")
	p.call("set_affinities", [aff])
	var roots: Array[String] = GameData.skill_roots([aff])
	var why: String = p.call("start_with_skills", [roots[0], roots[1]])
	assert(why == "", why)
	p.set("active", true)
	return p


func _floor() -> void:
	_world = Node3D.new()
	add_child(_world)
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(160, 1, 160)
	col.shape = shape
	sb.add_child(col)
	sb.position = Vector3(0, -0.5, 0)
	_world.add_child(sb)


func _duel(aff: String, f: Array) -> void:
	_floor()
	var p: CharacterBody3D = _fresh(aff)
	var foes: Array = []
	var i: int = 0
	for spec: Array in f[1]:
		for n: int in int(spec[1]):
			var e: CharacterBody3D = Beast.new()
			e.call("setup", str(spec[0]), p, float(f[2]))
			var a: float = 0.5 * float(i)
			e.position = Vector3(sin(a) * 3.0, 0.0, -9.0 - 1.5 * float(i % 3)) if str(spec[0]) != "sod_lurker" else Vector3(0, 0, -6)
			_world.add_child(e)
			if e.has_method("provoke") and bool(e.call("is_calm")):
				e.call("provoke", p)
			foes.append(e)
			i += 1
	p.call("start_fight")
	var start_hp: float = (p.get("body") as Body).total()
	var t := 0.0
	var won := false
	var cast := 0
	while t < time_limit:
		await get_tree().physics_frame
		t += STEP
		if bool(p.get("dead")):
			break
		var alive: Array = foes.filter(func(e: Variant) -> bool: return is_instance_valid(e) and not (e as Node).is_queued_for_deletion() and not bool((e as Node).call("is_dead")))
		if alive.is_empty():
			won = true
			break
		cast += _think(p, alive)
		if OS.get_cmdline_user_args().has("--trace") and int(t / STEP) % 6 == 0:
			for e3: Variant in alive:
				print("TRACE %.2f %s hp %.0f at %.1f m  windup %.2f  tele %s  player hp %.0f  ess %.1f  flank %.2f slot %s" % [t, str((e3 as Node).get("kind")), ((e3 as Node).get("body") as Body).total(),
					_flat(p.global_position, (e3 as Node3D).global_position), float((e3 as Node).get("_windup")), str((e3 as Node).get("telegraph")), (p.get("body") as Body).total(),
					float(p.get("essence")), float((e3 as Node).get("_flank_wait")), str((e3 as Node).call("_has_slot"))])
	var body: Body = p.get("body")
	results.append({"aff": aff, "fight": str(f[0]), "group": str(f[3]), "won": won, "t": t,
		"lost": start_hp - body.total() if not bool(p.get("dead")) else start_hp, "dead": bool(p.get("dead")), "casts": cast})
	_world.queue_free()
	await get_tree().physics_frame


## The careful fighter: dodge what is telegraphed, else fight the nearest; cast when it can; sling
## at what will not stand. Returns 1 if it cast a skill this frame.
func _think(p: CharacterBody3D, alive: Array) -> int:
	var me: Vector3 = p.global_position
	var away := Vector3.ZERO
	for e: Variant in alive:
		var n := e as Node3D
		var tele: Dictionary = n.get("telegraph")
		if tele.is_empty():
			continue
		var at: Vector3 = n.global_position
		match str(tele.get("kind", "")):
			"circle":
				if _flat(me, at) < float(tele["radius"]) + 0.8:
					away += _dir(at, me)
			"cone":
				if _flat(me, at) < float(tele["radius"]) + 0.8:
					away += _dir(at, me)
			"lane":
				var to: Vector3 = tele["to"]
				var c: Vector2 = Geometry2D.get_closest_point_to_segment(Vector2(me.x, me.z), Vector2(at.x, at.z), Vector2(to.x, to.z))
				if c.distance_to(Vector2(me.x, me.z)) < float(tele.get("width", 2.0)) * 0.5 + 1.0:
					var along: Vector3 = (to - at)
					along.y = 0.0
					var side := Vector3(-along.z, 0.0, along.x).normalized()
					away += side if side.dot(me - at) >= 0.0 else -side
	for b: Node in get_tree().get_nodes_in_group("scald_bursts"):
		if _flat(me, (b as Node3D).global_position) < float(b.get("radius")) + 0.6:
			away += _dir((b as Node3D).global_position, me)
	if away.length() > 0.01:
		p.set("attack_target", null)
		p.set("move_goal", me + away.normalized() * 3.0)
		p.set("has_move_goal", true)
		return 0
	p.set("has_move_goal", false)
	var near: Node3D = null
	for e2: Variant in alive:
		if bool((e2 as Node).get("buried")):
			continue
		if near == null or _flat(me, (e2 as Node3D).global_position) < _flat(me, near.global_position):
			near = e2
	if near == null:
		# nothing to fight yet (a lurker under the ground): walk on across the field
		p.set("move_goal", me + Vector3(0, 0, -3))
		p.set("has_move_goal", true)
		return 0
	var d: float = _flat(me, near.global_position)
	p.set("attack_target", near)
	p.set("cursor_fixed", near.global_position)
	var kept_away: bool = d > float(p.call("reach_now")) + float(near.get("radius")) + 2.5
	if kept_away and str(near.get("behaviour")) in ["runner", "darter"]:
		p.call("fire_ranged", near.global_position)
	var abilities: Array = p.get("abilities")
	for i: int in abilities.size():
		var ab: Dictionary = GameData.ability(str((abilities[i] as Dictionary)["id"]))
		if float(p.get("essence")) < float(ab.get("cost", 99.0)) or float(p.get("_recover_t")) > 0.0:
			continue
		var kind: String = str(ab.get("kind", ""))
		var close: bool = kind in ["melee_burst", "targeted_strike"]
		if close and d > 3.0:
			continue
		if kind in ["dash", "blink", "prop", "grapple"]:
			continue
		var before: float = float(p.get("essence"))
		p.call("cast_ability", i)
		if float(p.get("essence")) < before:
			return 1
	return 0


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _dir(from: Vector3, to: Vector3) -> Vector3:
	var v := Vector3(to.x - from.x, 0.0, to.z - from.z)
	return v.normalized() if v.length() > 0.01 else Vector3(1, 0, 0)


func _report() -> void:
	var counted := 0
	var won := 0
	print("DUELS: a fresh 1-star (two stage-0 skills, starting gear, not invulnerable), careful scripted play")
	print("DUELS: %-10s %-34s %-5s %7s %8s %6s" % ["affinity", "fight", "won", "time s", "hp lost", "casts"])
	for r: Dictionary in results:
		print("DUELS: %-10s %-34s %-5s %7.1f %8.0f %6d" % [r["aff"], r["fight"], "yes" if r["won"] else ("DIED" if r["dead"] else "no"), r["t"], r["lost"], r["casts"]])
		if str(r["group"]) != "camp":
			counted += 1
			won += 1 if bool(r["won"]) else 0
	print("DUELS: per fight, over every affinity (wins / time when won / hp lost):")
	for f: Array in fights:
		var rs: Array = results.filter(func(r: Dictionary) -> bool: return str(r["fight"]) == str(f[0]))
		var w: Array = rs.filter(func(r: Dictionary) -> bool: return bool(r["won"]))
		var tt := 0.0
		var hl := 0.0
		for r2: Dictionary in w:
			tt += float(r2["t"])
		for r3: Dictionary in rs:
			hl += float(r3["lost"])
		print("DUELS:   %-34s %d/%d  ttk %5.1f s  hp lost %5.1f" % [f[0], w.size(), rs.size(), tt / maxf(1.0, float(w.size())), hl / maxf(1.0, float(rs.size()))])
	var rate: float = float(won) / maxf(1.0, float(counted))
	var ok: bool = rate >= want_rate and errors.count() == 0
	print("DUELS: singles and pairs won %d of %d (%.0f%%, want %.0f%%); script errors %d" % [won, counted, rate * 100.0, want_rate * 100.0, errors.count()])
	print("DUELS: %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
