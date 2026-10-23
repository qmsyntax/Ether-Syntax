extends "res://scripts/runes/interactions/effects_v1.gd"
## Rune effects, structure v2 (Brent 2026-10-23, design/14 section 8; Bond Rules rows 43-59). Every
## number is in runes.json: bond_v2.interaction_params.effects_v2 (`params`). What it keeps from
## effects_v1: each rune's ops (layer 1), the kind factors (layer 2), how an op at a strength reaches
## the skill's fields, the fallback, the clamps and the patch.
##
## What changes:
##   strength   = the rune's RING's fade x the PRODUCT of every bond's transmission on its path to the
##                skill, each bond's kind factor read from the side further out (the rune nearer the
##                start of the path). The strongest path counts. Paths run inward: each step to the
##                same ring or one further in, never back out, no rune twice.
##   ionic      the weaker rune's whole effect leaves it and is carried by the stronger rune, at the
##              stronger rune's strength (and on along a chain of ionic bonds to the strongest; a rune
##              weaker in two ionic bonds hands to the one with more pull). The skill's own rune is the
##              exception, as before: on the weak side it loses its nature, and nothing carries it;
##              on the strong side it carries what it takes at full strength.
##   traits     the shapes RingRules.shape_traits finds: closed ring (duration per ring), great ring
##              (the skill repeats once at a fraction: patch "rune_repeat", read by
##              Player._perform_cast), spoke (reach and speed per ring past the free ones), branch
##              (reach per branch rune, capped), balanced (the skill's own rune keeps all its nature).
##              A trait's change goes through the same op rules as a rune at strength 1, so a skill
##              with nothing for it to change takes the fallback instead.


func on_describe_link(word: Dictionary, a: int, b: int, ctx: RuneContext, desc: Dictionary) -> void:
	var r: Dictionary = compute(word, ctx)
	var st: Array = r.get("_strength", [])
	if a >= st.size() or b >= st.size():
		return
	var ra: int = RuneWord.ring(word, a)
	var rb: int = RuneWord.ring(word, b)
	var outer: int = b if rb > ra or (rb == ra and float(st[b]) <= float(st[a])) else a
	desc["strength"] = 1.0 if outer == 0 else float(st[outer])


func on_describe_node(word: Dictionary, i: int, ctx: RuneContext, desc: Dictionary) -> void:
	var r: Dictionary = compute(word, ctx)
	if i == 0:
		desc["strength"] = float((r.get("anchor", {}) as Dictionary).get("factor", 1.0))
		return
	for row: Dictionary in r.get("runes", []):
		if int(row["node"]) == i:
			desc["strength"] = float(row["strength"])
			if int(row.get("carried_to", -1)) >= 0:
				desc["carried_to"] = int(row["carried_to"])
				(desc["badges"] as Array).append("carried by %s" % str(row.get("carried_by", "")))
			if not (row.get("carries", []) as Array).is_empty():
				desc["carries"] = row["carries"]
			return


func on_word_state(_word: Dictionary, _ctx: RuneContext, _state: Dictionary) -> void:
	pass


# --- the calculation ---------------------------------------------------------------------

func _ring_fade(k: int) -> float:
	if k <= 0:
		return 1.0
	var out := 0.0
	for f: Dictionary in params.get("ring_fade", []):
		if int(f["ring"]) == k or (bool(f.get("or_more", false)) and k >= int(f["ring"])):
			out = float(f["fade"])
	return out


## Each node's strength and the path that gives it: {strength: [...], path: [[...]], product: [...]}.
func strengths(word: Dictionary) -> Dictionary:
	var n: int = RuneWord.size(word)
	var rs: Array[int] = RuneWord.rings(word)
	var st: Array[float] = []
	var paths: Array = []
	var prods: Array[float] = []
	for i: int in n:
		if i == 0:
			st.append(1.0)
			paths.append([0])
			prods.append(1.0)
			continue
		var best: Dictionary = {"p": -1.0, "path": []}
		var budget: Array[int] = [4000]
		_walk(word, rs, i, [i], 1.0, best, budget)
		var p: float = maxf(0.0, float(best["p"]))
		prods.append(p)
		paths.append(best["path"])
		st.append(_ring_fade(rs[i]) * p if float(best["p"]) >= 0.0 else 0.0)
	return {"strength": st, "path": paths, "product": prods}


## Depth-first over inward paths from `at` to the anchor, keeping the best product.
func _walk(word: Dictionary, rs: Array[int], at: int, path: Array, prod: float, best: Dictionary, budget: Array[int]) -> void:
	budget[0] -= 1
	if budget[0] < 0:
		return
	for k: int in RuneWord.neighbours(word, at):
		if path.has(k) or rs[k] > rs[at]:
			continue
		var p: float = prod * _side_factor(word, at, k)
		if k == 0:
			if p > float(best["p"]):
				best["p"] = p
				best["path"] = path + [0]
			continue
		_walk(word, rs, k, path + [k], p, best, budget)


## Where each node's effect ends up: itself, or the rune that takes it over an ionic bond (followed
## on to the strongest). The anchor never hands its effect on (its nature is lost instead).
func carriers(word: Dictionary) -> Array[int]:
	var n: int = RuneWord.size(word)
	var to: Array[int] = []
	for i: int in n:
		to.append(i)
	for i: int in range(1, n):
		var best := -1
		var best_en := -INF
		for k: int in RuneWord.neighbours(word, i):
			if _kind(word, i, k) == "ionic" and _side(word, i, k) == "less":
				var en: float = float(GameData.rune(RuneWord.node_id(word, k)).get("electronegativity", 0.0))
				if en > best_en:
					best_en = en
					best = k
		if best >= 0:
			to[i] = best
	var out: Array[int] = []
	for i: int in n:
		var at: int = i
		var hops := 0
		while to[at] != at and hops < n:
			at = to[at]
			hops += 1
		out.append(at)
	return out


func _compute(word: Dictionary, ctx: RuneContext) -> Dictionary:
	var ab: Dictionary = GameData.ability(ctx.ability_id) if GameData.abilities.has(ctx.ability_id) else {}
	var n: int = RuneWord.size(word)
	var sres: Dictionary = strengths(word)
	var st: Array = sres["strength"]
	var out: Dictionary = {"patch": [], "groups": {}, "lines": [], "runes": [], "anchor": {}, "traits": [], "transfers": [],
		"_dist": _distances(word), "_strength": st}
	if ab.is_empty() or n == 0:
		return out
	var groups: Dictionary = {}
	var fallback_mult := 1.0
	var patch: Array = []
	var lines: Array = []
	var threshold: float = float(params.get("status_threshold", 0.5))
	var traits: Array[Dictionary] = []
	if rules != null and rules.has_method("shape_traits"):
		traits = rules.call("shape_traits", word)
	var trait_defs: Dictionary = params.get("shape_traits", {})

	# the skill's own rune: its nature scaled by its bonds - all of it when the word is balanced
	var balanced := false
	for t: Dictionary in traits:
		if str(t["id"]) == "balanced":
			balanced = true
	var af: float = float((trait_defs.get("balanced", {}) as Dictionary).get("anchor_factor", 1.0)) if balanced else _anchor_factor(word)
	var anchor_lines: Array = []
	if RuneWord.degree(word, 0) > 0:
		for op: Dictionary in GameData.rune(RuneWord.node_id(word, 0)).get("ops", []):
			var t2: String = _scale_signature(ab, op, af, threshold, groups, patch)
			if t2 != "":
				anchor_lines.append(t2)
	out["anchor"] = {"factor": af, "lines": anchor_lines, "kinds": _anchor_kinds(word), "balanced": balanced}

	# who carries whose effect
	var carry: Array[int] = carriers(word)
	var rows: Array = []
	for i: int in range(1, n):
		var rid: String = RuneWord.node_id(word, i)
		var row: Dictionary = {"node": i, "id": rid, "name": str(GameData.rune(rid).get("name", rid)), "ring": RuneWord.ring(word, i),
			"bonds": (sres["path"][i] as Array).size() - 1 if not (sres["path"][i] as Array).is_empty() else -1,
			"kind": "", "side": "", "strength": float(st[i]), "path": sres["path"][i], "used": [], "fallback": [], "carries": []}
		var path: Array = sres["path"][i]
		if path.size() >= 2:
			row["kind"] = _kind(word, i, int(path[1]))
			row["side"] = _side(word, i, int(path[1]))
			row["relation"] = _relation(word, i, int(path[1]))
		if carry[i] != i:
			row["carried_to"] = carry[i]
			row["carried_by"] = RuneRules.rune_name(word, carry[i])
		rows.append(row)
	# each holder works its own ops and everything carried to it, at its own strength
	var holders: Array[int] = []
	for i: int in n:
		if not holders.has(carry[i]):
			holders.append(carry[i])
	for h: int in holders:
		var s: float = 1.0 if h == 0 else float(st[h])
		var hrow: Dictionary = {} if h == 0 else rows[h - 1]
		for j: int in range(1, n):
			if carry[j] != h:
				continue
			var from: String = "" if j == h else RuneRules.rune_name(word, j)
			if j != h:
				(out["transfers"] as Array).append({"from": j, "to": h, "strength": s,
					"text": "%s's effect is carried by %s (x%.2f)" % [from, "the skill" if h == 0 else RuneRules.rune_name(word, h), s]})
				if h > 0:
					(hrow["carries"] as Array).append(from)
			if s <= 0.0:
				continue
			for op: Dictionary in GameData.rune(RuneWord.node_id(word, j)).get("ops", []):
				var res: Dictionary = _apply_op(ab, op, s, threshold, groups, patch)
				var tag: String = "" if from == "" else "  (from %s)" % from
				if bool(res["used"]):
					if h == 0:
						anchor_lines.append("%s%s" % [str(res["text"]), tag])
					else:
						(hrow["used"] as Array).append(str(res["text"]) + tag)
					if str(res.get("line", "")) != "" and h != 0:
						lines.append(str(res["line"]) + tag)
				else:
					fallback_mult *= 1.0 + float(res["change"]) * float(params.get("fallback_fraction", 0.25))
					var fb: String = "%s -> %s%s" % [op_words(op, s), str(res["why"]), tag]
					if h == 0:
						anchor_lines.append(fb)
					else:
						(hrow["fallback"] as Array).append(fb)
	out["runes"] = rows
	out["effect_lines"] = lines.duplicate()          # what the hits gain (statuses, shoves...), for the screen

	# shape traits
	for t: Dictionary in traits:
		var def: Dictionary = trait_defs.get(str(t["id"]), {})
		var count: int = maxi(0, int(t.get("count", 1)))
		var said: Array[String] = []
		for op: Dictionary in def.get("ops", []):
			if count <= 0:
				break
			var whole: Dictionary = op.duplicate()
			whole["value"] = pow(float(op["value"]), float(count))
			var res2: Dictionary = _apply_op(ab, whole, 1.0, threshold, groups, patch)
			if bool(res2["used"]):
				said.append(str(res2["text"]))
			else:
				fallback_mult *= 1.0 + float(res2["change"]) * float(params.get("fallback_fraction", 0.25))
				said.append("%s -> %s" % [op_words(whole, 1.0), str(res2["why"])])
		if str(t["id"]) == "great_ring":
			said.append(_great_ring(ab, def, patch))
			if str(said.back()).begins_with("cannot"):
				fallback_mult *= 1.0 + float(def.get("mult", 0.0)) * float(params.get("fallback_fraction", 0.25))
		if str(t["id"]) == "balanced":
			said.append("its own rune keeps all of its nature")
		var tt: Dictionary = t.duplicate()
		tt["effect"] = ", ".join(PackedStringArray(said))
		(out["traits"] as Array).append(tt)
		lines.append("%s: %s" % [str(t["label"]) + ((" (ring %d)" % int(t["ring"])) if t.has("ring") else ""), tt["effect"]])
	for tr: Dictionary in out["transfers"]:
		lines.append(str(tr["text"]))
	_finish(ab, groups, fallback_mult, patch, lines, anchor_lines, out)
	return out


## The great ring's repeat: a patch field the cast reads, or why this kind of skill cannot repeat.
func _great_ring(ab: Dictionary, def: Dictionary, patch: Array) -> String:
	var rep: Dictionary = params.get("repeat", {})
	var kind: String = str(ab.get("kind", ""))
	var mult: float = float(def.get("mult", 0.0))
	if (rep.get("no_repeat_kinds", []) as Array).has(kind):
		return "cannot repeat a %s: +%d%% as damage instead" % [kind.replace("_", " "), int(round(mult * float(params.get("fallback_fraction", 0.25)) * 100.0))]
	patch.append({"op": "set", "path": "rune_repeat", "value": {"times": int(def.get("repeats", 1)), "mult": mult, "delay_s": float(rep.get("delay_s", 0.4))}})
	return "repeats %s at %d%%" % ["once" if int(def.get("repeats", 1)) == 1 else "%d times" % int(def.get("repeats", 1)), int(round(mult * 100.0))]
