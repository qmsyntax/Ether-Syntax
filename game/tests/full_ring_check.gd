extends Node
## Can a NEW character fill its starting skills' rings? (Brent 2026-10-24, design/14 section 12: a
## level locks only when every place of every ring up to it holds a rune and the word is closed.) For
## every affinity and every pair of root skills a single-affinity prime can start with, a fresh
## character is made through the real start (Player.start_with_skills, which grants the starting
## runes), and for each of its two skills the exhaustive search FullRings.solve asks: is there a
## closed word with ring 1 full (the first lock) - and with rings 1 and 2 full (the second) - from the
## runes it knows, repeats allowed when the rules allow them? It changes no data; it reports.
##   --headless --path game res://tests/full_ring_check.tscn      (prints FULLRINGS: ... and the stuck skills)
## Exit 0 whatever it finds (a report, not a gate); 1 only on a script error.

const PlayerScript := preload("res://scripts/player.gd")


func _ready() -> void:
	var errors: ErrorCatcher = ErrorCatcher.install()
	(GameData.balance["art"] as Dictionary)["real_bodies"] = false
	var rules: RingRules = Runes.active() as RingRules
	var want: int = int(GameData.skill_tree.get("start_picks", 2))
	var seen_skill: Dictionary = {}          # skill id -> [lock1 ok in every start, lock2 ok in every start, details]
	var stuck1: Array[String] = []
	var stuck2: Array[String] = []
	var starts := 0
	var t0: int = Time.get_ticks_msec()
	for aff_v: Variant in GameData.affinity_ids():
		var aff: String = str(aff_v)
		var roots: Array[String] = GameData.skill_roots([aff])
		var pairs: Array = []
		for i: int in roots.size():
			for j: int in range(i + 1, roots.size()):
				pairs.append([roots[i], roots[j]])
		if want != 2:
			print("  start_picks is %d, not 2: only pairs are tried" % want)
		for pair: Array in pairs:
			var p: Node = PlayerScript.new()
			add_child(p)
			p.call("set_affinities", [aff])
			var why: String = str(p.call("start_with_skills", pair))
			if why != "":
				print("  %s %s: refused (%s)" % [aff, str(pair), why])
				p.queue_free()
				continue
			starts += 1
			var known: Array = (p.call("rune_palette") as Array).filter(func(id: String) -> bool: return bool(p.call("knows_rune", id)))
			for sid: Variant in pair:
				var anchor: String = GameData.skill_anchor(str(sid))
				var w1: Dictionary = FullRings.solve(anchor, 1, known, rules)
				var w2: Dictionary = FullRings.solve(anchor, 2, known, rules) if not w1.is_empty() else {}
				var key: String = str(sid)
				var line: String = "%-18s %-9s with %-18s knows %s -> ring 1: %s, rings 1-2: %s" % [key, aff, str(pair[1] if pair[0] == sid else pair[0]),
					", ".join(PackedStringArray(known.map(func(id: String) -> String: return "%s(%d)" % [str(GameData.rune(id).get("name", id)), BondRules.valence(id)]))),
					"yes" if not w1.is_empty() else "NO", "yes" if not w2.is_empty() else "NO"]
				print("  " + line)
				if not seen_skill.has(key):
					seen_skill[key] = [true, true]
				seen_skill[key][0] = bool(seen_skill[key][0]) and not w1.is_empty()
				seen_skill[key][1] = bool(seen_skill[key][1]) and not w2.is_empty()
				if w1.is_empty():
					stuck1.append("%s (%s, started with %s)" % [key, aff, " + ".join(PackedStringArray(pair))])
				elif w2.is_empty():
					stuck2.append("%s (%s, started with %s)" % [key, aff, " + ".join(PackedStringArray(pair))])
			p.queue_free()
			await get_tree().process_frame
	var both := 0
	for k: String in seen_skill:
		if bool(seen_skill[k][0]) and bool(seen_skill[k][1]):
			both += 1
	print("stuck at the first lock (no closed word with ring 1 full): %d" % stuck1.size())
	for s: String in stuck1:
		print("  " + s)
	print("stuck at the second lock (ring 1 can be filled, rings 1 and 2 together cannot): %d" % stuck2.size())
	for s2: String in stuck2:
		print("  " + s2)
	print("FULLRINGS: %d starts tried; %d of %d starting skills can fill and close rings 1 and 2 in every start; %d skill-starts stuck at lock 1, %d at lock 2; %d script errors; %.1f s" % [
		starts, both, seen_skill.size(), stuck1.size(), stuck2.size(), errors.count(), float(Time.get_ticks_msec() - t0) / 1000.0])
	get_tree().quit(0 if errors.count() == 0 else 1)
