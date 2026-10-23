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
##
## Brent 2026-10-23 (Bond Rules rows 62-74, params "on_off" and "ionic_conversion"):
##   on/off     a status the word adds lasts base x (1 + (strength - 1) x per), up to the cap (a
##              status the skill already applies is only ever lengthened); each full 1.0 of
##              strength above 1 adds a stack where the status stacks; an interrupt above the
##              silence line also applies the silence status for (strength - line) x its seconds.
##              They reach the hit as data: payload "status_time_of" {id: mult} and a "statuses"
##              entry's own "lasts" (Player.apply_hit), never by id.
##   conversion nothing is lost in an ionic bond: what the weaker side gives up is added to the
##              strength of the rune that ends up holding it, x rate, up to the cap. An outer rune
##              gives up its whole effect (already carried) and its strength; the skill's own rune
##              gives up the share of its signature that bond takes from it (all of it when it is
##              taken whole). The skill's own rune on the strong side converts nothing [MODEL].


func on_describe_link(word: Dictionary, a: int, b: int, ctx: RuneContext, desc: Dictionary) -> void:
	var r: Dictionary = compute(word, ctx)
	var st: Array = r.get("_strength", [])
	if a >= st.size() or b >= st.size():
		return
	var ra: int = RuneWord.ring(word, a)
	var rb: int = RuneWord.ring(word, b)
	var outer: int = b if rb > ra or (rb == ra and float(st[b]) <= float(st[a])) else a
	var inner: int = a if outer == b else b
	desc["strength"] = 1.0 if outer == 0 else float(st[outer])
	# what the bond passes on: its kind factor read from the side further out, and the runes whose
	# strongest way to the skill runs through it
	desc["transmission"] = _side_factor(word, outer, inner)
	desc["outer"] = outer
	var carries: Array = []
	var paths: Array = r.get("_paths", [])
	for i: int in paths.size():
		var path: Array = paths[i]
		for k: int in range(path.size() - 1):
			if (int(path[k]) == a and int(path[k + 1]) == b) or (int(path[k]) == b and int(path[k + 1]) == a):
				carries.append({"node": i, "name": RuneRules.rune_name(word, i), "strength": float(st[i])})
				break
	desc["carries"] = carries
	var hand: Array = []
	for c: Dictionary in r.get("conversions", []):
		if (int(c["from"]) == a and int(c["via"]) == b) or (int(c["from"]) == b and int(c["via"]) == a):
			hand.append(str(c["text"]))
	desc["hand_over"] = hand


func on_describe_node(word: Dictionary, i: int, ctx: RuneContext, desc: Dictionary) -> void:
	var r: Dictionary = compute(word, ctx)
	if i == 0:
		desc["strength"] = float((r.get("anchor", {}) as Dictionary).get("factor", 1.0))
		return
	for row: Dictionary in r.get("runes", []):
		if int(row["node"]) == i:
			desc["strength"] = float(row["strength"])
			if float(row.get("converted", 0.0)) > 0.0:
				desc["converted"] = float(row["converted"])
				desc["path_strength"] = float(row["path_strength"])
				desc["converted_from"] = str(row.get("converted_from", ""))
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
	var to: Array[int] = hand_to(word)
	var out: Array[int] = []
	for i: int in n:
		var at: int = i
		var hops := 0
		while to[at] != at and hops < n:
			at = to[at]
			hops += 1
		out.append(at)
	return out


## The rune each node hands its effect to over an ionic bond, one step (itself if none): the
## partner with the most pull among those it is weaker than ionically.
func hand_to(word: Dictionary) -> Array[int]:
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
	return to


## Ionic conversion (Bond Rules rows 71-72): what each holder gains, [{from, via, to, amount, words,
## text}]. `from` gave something up over its bond with `via`; `to` is the rune that ends up holding it.
##   an outer rune handing its effect on: its strength (the strongest of its own way in and the way
##   in through the rune it hands to, as if that bond passed it on whole) x rate;
##   the skill's own rune on the weak side of an ionic bond: the share of its signature that bond
##   takes (its factor's shortfall from 1, split over its bonds by what each takes) x rate.
func conversions(word: Dictionary, ab: Dictionary, sres: Dictionary, carry: Array[int], af: float) -> Array:
	var conv: Dictionary = params.get("ionic_conversion", {})
	var rate: float = float(conv.get("rate", 0.0))
	var out: Array = []
	if rate <= 0.0:
		return out
	var n: int = RuneWord.size(word)
	var st: Array = sres["strength"]
	var prods: Array = sres["product"]
	var rs: Array[int] = RuneWord.rings(word)
	var to: Array[int] = hand_to(word)
	for j: int in range(1, n):
		var t: int = to[j]
		var h: int = carry[j]
		if t == j or h == 0:
			continue
		var s: float = float(st[j])
		if rs[t] <= rs[j] and t > 0:
			s = maxf(s, _ring_fade(rs[j]) * float(prods[t]))
		if s <= 0.0:
			continue
		var words: String = _rune_nature(RuneWord.node_id(word, j))
		out.append({"from": j, "via": t, "to": h, "amount": s * rate, "words": words,
			"text": "%s gives up its %s: +%.2f strength to %s" % [RuneRules.rune_name(word, j), words, s * rate, RuneRules.rune_name(word, h)]})
	# the skill's own rune, taken over an ionic bond
	var lost: float = maxf(0.0, 1.0 - af)
	if lost > 0.0:
		var share := 0.0
		for k: int in RuneWord.neighbours(word, 0):
			share += maxf(0.0, 1.0 - _side_factor(word, 0, k))
		for k2: int in RuneWord.neighbours(word, 0):
			if _kind(word, 0, k2) != "ionic" or _side(word, 0, k2) != "less" or share <= 0.0:
				continue
			var frac: float = lost * maxf(0.0, 1.0 - _side_factor(word, 0, k2)) / share
			var h2: int = carry[k2]
			if frac <= 0.0 or h2 == 0:
				continue
			var words2: String = _signature_nature(ab)
			out.append({"from": 0, "via": k2, "to": h2, "amount": frac * rate, "fraction": frac, "words": words2,
				"text": "%s gives up %s of its %s: +%.2f strength to %s" % [RuneRules.rune_name(word, 0),
					"all" if frac >= 0.999 else "%d%%" % int(round(frac * 100.0)), words2, frac * rate, RuneRules.rune_name(word, h2)]})
	return out


## A holder's strength once conversion is added: up to the cap (a rune already past it keeps its own).
func converted_strength(s: float, add: float) -> float:
	if add <= 0.0:
		return s
	var cap: float = float((params.get("ionic_conversion", {}) as Dictionary).get("cap", INF))
	return s if s >= cap else minf(cap, s + add)


## A rune's nature in words: what its ops change ("reach, stagger").
func _rune_nature(rune_id: String) -> String:
	var words: Array[String] = []
	var nw: Dictionary = params.get("nature_words", {})
	for op: Dictionary in GameData.rune(rune_id).get("ops", []):
		var w: String = ""
		match str(op["op"]):
			"mul":
				w = str(nw.get(str(op["group"]), _group_word(str(op["group"]))))
			"status":
				w = _status_label(str(op["id"]))
			_:
				w = str(nw.get(str(op["op"]), str(op["op"])))
		if w != "" and not words.has(w):
			words.append(w)
	return _and_list(words)


## The skill's signature in words: each signature field's stat group ("reach", "stagger"), its status,
## or its own name ("carry").
func _signature_nature(ab: Dictionary) -> String:
	var words: Array[String] = []
	var nw: Dictionary = params.get("nature_words", {})
	var groups: Dictionary = params.get("stat_groups", {})
	for sig: Variant in ab.get("signature", []):
		var path: String = str(sig)
		var w: String = ""
		if path.ends_with("status") and typeof(get_path_value(ab, path)) == TYPE_STRING:
			w = _status_label(str(get_path_value(ab, path)))
		else:
			for g: String in groups:
				for spec: Variant in groups[g]:
					var sp: String = str(spec)
					if sp.get_slice("@", 0) == path and (not sp.contains("@") or sp.get_slice("@", 1).split("|").has(str(ab.get("kind", "")))):
						w = str(nw.get(g, _group_word(g)))
				if w != "":
					break
		if w == "":
			var last: String = path.get_slice(".", path.get_slice_count(".") - 1)
			w = str(nw.get(last, last.replace("_", " ")))
		if not words.has(w):
			words.append(w)
	return _and_list(words) if not words.is_empty() else "nature"


static func _and_list(words: Array[String]) -> String:
	if words.size() <= 1:
		return "".join(PackedStringArray(words))
	return ", ".join(PackedStringArray(words.slice(0, words.size() - 1))) + " and " + words[words.size() - 1]


# --- on/off effects grow with strength (Bond Rules rows 66-70) ------------------------------

## How much longer a status lasts at strength s (a multiple of its base), and whether the cap held it.
func status_time(s: float) -> Array:
	var oo: Dictionary = params.get("on_off", {})
	var m: float = 1.0 + (s - 1.0) * float(oo.get("status_time_per_strength", 0.0))
	var cap: float = float(oo.get("status_time_cap", INF))
	return [clampf(m, 0.0, cap), m > cap + 0.0001]


## Extra stacks at strength s, where status `id` stacks (its max above 1).
func extra_stacks(id: String, s: float) -> int:
	var def: Dictionary = GameData.status(id)
	if def.has("alias_of"):
		def = GameData.status(str(def["alias_of"]))
	if int(def.get("stacks", 1)) <= 1 or s <= 1.0:
		return 0
	return int(floor(s - 1.0 + 0.000001)) * int((params.get("on_off", {}) as Dictionary).get("stack_per_strength", 0))


## Seconds of silence an interrupt carries at strength s (0 at or below the line).
func silence_s(s: float) -> float:
	var oo: Dictionary = params.get("on_off", {})
	var line: float = float(oo.get("silence_above", INF))
	if s <= line + 0.000001:
		return 0.0
	return (s - line) * float(oo.get("silence_s_per_strength", 0.0))


func _apply_op(ab: Dictionary, op: Dictionary, s: float, threshold: float, groups: Dictionary, patch: Array) -> Dictionary:
	match str(op["op"]):
		"status":
			return _grow_status(ab, op, s, threshold, patch)
		"interrupts":
			var res: Dictionary = super._apply_op(ab, op, s, threshold, groups, patch)
			var secs: float = silence_s(s)
			var part: String = _payload_part(ab)
			var sid: String = str((params.get("on_off", {}) as Dictionary).get("silence_status", ""))
			if secs <= 0.0 or part == "" or sid == "":
				return res
			patch.append({"op": "append", "path": part + ".statuses", "value": {"id": sid, "stacks": 1, "lasts": secs}})
			var said: String = "silences %.2f s" % secs
			if bool(res["used"]):
				res["text"] = "%s, %s" % [str(res["text"]), said]
				res["line"] = "%s, and %s" % [str(res.get("line", "")), "silences what it hits for %.2f s" % secs]
				return res
			return {"used": true, "text": said, "line": "silences what it hits for %.2f s" % secs}
	return super._apply_op(ab, op, s, threshold, groups, patch)


## A status op at strength s: as effects_v1 (it applies, or adds stacks to what the skill already
## applies), plus its duration and stacks by strength.
func _grow_status(ab: Dictionary, op: Dictionary, s: float, threshold: float, patch: Array) -> Dictionary:
	var grant_change: float = float(params.get("grant_as_change", 0.2)) * s
	var part: String = _payload_part(ab)
	var id: String = str(op["id"])
	if part == "":
		return {"used": false, "change": grant_change, "why": "nothing it hits"}
	if s < threshold:
		return {"used": false, "change": grant_change, "why": "too faint to take hold"}
	var label: String = _status_label(id)
	var extra: int = extra_stacks(id, s)
	var stacks: int = int(op.get("stacks", 1)) + extra
	var tm: Array = status_time(s)
	var mult: float = float(tm[0])
	var had: bool = _has_status(ab, part, id)
	if had:
		mult = maxf(1.0, mult)                  # the skill's own status is never cut short by a rune
	var grow: Array[String] = []
	if absf(mult - 1.0) > 0.001:
		patch.append({"op": "max", "path": "%s.status_time_of.%s" % [part, id], "value": mult})
		grow.append("lasts x%.2f%s" % [mult, " (capped)" if bool(tm[1]) else ""])
	if extra > 0:
		grow.append("+%d stack%s by strength" % [extra, "" if extra == 1 else "s"])
	var tail: String = (" (" + ", ".join(PackedStringArray(grow)) + ")") if not grow.is_empty() else ""
	if had:
		var p: Dictionary = get_path_value(ab, part)
		if str(p.get("status", "")) == id:
			patch.append({"op": "set", "path": part + ".stacks", "value": int(p.get("stacks", 1)) + stacks})
		else:
			patch.append({"op": "append", "path": part + ".statuses", "value": {"id": id, "stacks": stacks}})
		return {"used": true, "text": "+%d %s%s" % [stacks, label, tail], "line": "+%d stack%s of %s%s" % [stacks, "" if stacks == 1 else "s", label, tail]}
	patch.append({"op": "append", "path": part + ".statuses", "value": {"id": id, "stacks": stacks}})
	return {"used": true, "text": "applies %s%s" % [label, tail], "line": "applies %s%s" % [label, tail]}


func _compute(word: Dictionary, ctx: RuneContext) -> Dictionary:
	var ab: Dictionary = GameData.ability(ctx.ability_id) if GameData.abilities.has(ctx.ability_id) else {}
	var n: int = RuneWord.size(word)
	var sres: Dictionary = strengths(word)
	var st: Array = sres["strength"]
	var out: Dictionary = {"patch": [], "groups": {}, "lines": [], "runes": [], "anchor": {}, "traits": [], "transfers": [],
		"conversions": [], "_dist": _distances(word), "_strength": st, "_paths": sres["path"]}
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

	# who carries whose effect, and what the ionic bonds convert into strength (rows 71-72)
	var carry: Array[int] = carriers(word)
	var conv: Array = conversions(word, ab, sres, carry, af)
	out["conversions"] = conv
	var gain: Dictionary = {}
	var gain_from: Dictionary = {}
	for c: Dictionary in conv:
		var h0: int = int(c["to"])
		gain[h0] = float(gain.get(h0, 0.0)) + float(c["amount"])
		if not gain_from.has(h0):
			gain_from[h0] = []
		(gain_from[h0] as Array).append("%s's %s" % [RuneRules.rune_name(word, int(c["from"])), str(c["words"])])
	var final_st: Array[float] = []
	for i0: int in n:
		final_st.append(1.0 if i0 == 0 else converted_strength(float(st[i0]), float(gain.get(i0, 0.0))))
	out["_final"] = final_st
	var rows: Array = []
	for i: int in range(1, n):
		var rid: String = RuneWord.node_id(word, i)
		var row: Dictionary = {"node": i, "id": rid, "name": str(GameData.rune(rid).get("name", rid)), "ring": RuneWord.ring(word, i),
			"bonds": (sres["path"][i] as Array).size() - 1 if not (sres["path"][i] as Array).is_empty() else -1,
			"kind": "", "side": "", "strength": final_st[i], "path_strength": float(st[i]), "path": sres["path"][i], "used": [], "fallback": [], "carries": []}
		if final_st[i] > float(st[i]) + 0.000001:
			row["converted"] = final_st[i] - float(st[i])
			var from_words: Array[String] = []
			var times: Dictionary = {}
			for fw: Variant in gain_from[i]:
				if not times.has(str(fw)):
					from_words.append(str(fw))
				times[str(fw)] = int(times.get(str(fw), 0)) + 1
			for k: int in from_words.size():
				if int(times[from_words[k]]) > 1:
					from_words[k] = "%s (x%d)" % [from_words[k], int(times[from_words[k]])]
			row["converted_from"] = "converted from %s" % _and_list(from_words)
			row["capped"] = float(st[i]) + float(gain[i]) > final_st[i] + 0.000001
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
		var s: float = final_st[h]
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
	for cv: Dictionary in conv:
		lines.append(str(cv["text"]))
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
