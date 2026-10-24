class_name RingRules
extends BondRules
## Rule set "bond_v2": seals as concentric rings (Brent 2026-10-23, design/14 section 8; Bond
## Rules rows 43-59). Everything of bond_v1 (valence, electronegativity, refusal) plus:
##   - the word is concentric rings round the skill, one per level; each binding seals a ring;
##   - ring k holds params.rings[k].adds more runes than the ring inside it ("grows") - or exactly
##     its adds ("own"); params.ring_capacity picks the reading (see the exporter);
##   - a rune bonds to runes on its own ring and on the rings just inside and outside; the skill's
##     own rune is ring 0 and bonds only to ring 1;
##   - a word is closed when every rune's valence is filled - the skill's own rune counting as filled
##     once it holds as many bonds as ring 1 has places (params.anchor_fills_by_ring);
##   - shape traits (closed ring, great ring, spoke, branch, balanced) are found here, structurally;
##     what they do is the effects interaction's (effects_v2);
##   - the seal is built from the skill outward (Brent 2026-10-23: "You should not be able to build
##     level 2 until level 1 is fully formed with construct"): no rune is set on ring k until every
##     ring inside it is formed (ring_formed), and a seal is refused while any ring up to the one
##     being formed is not;
##   - a ring is formed only when it is FULL, every place holding a rune (Brent 2026-10-24: "Every
##     slot should be filled to be fully formed ... Its all or nothing at each level");
##   - each sealed ring carries the construct bound at its lock as its keystone, whose concept's
##     effect is weighted above a rune's (params.keystone; keystone_effect, folded into effects).
## No numbers here: they are this rule set's params in runes.json.


func ring_rows() -> Array:
	return params.get("rings", [])


## How many runes ring k holds.
func ring_capacity(k: int) -> int:
	if k < 1:
		return 0
	var grows: bool = str(params.get("ring_capacity", "grows")) == "grows"
	var total := 0
	for j: int in range(1, k + 1):
		var adds: int = int(_ring_row(j).get("adds", 0))
		total = total + adds if grows else adds
	return total


## A ring's fade (its runes' strength before the bonds on their path).
func ring_fade(k: int) -> float:
	return float(_ring_row(k).get("fade", 0.0)) if k >= 1 else 1.0


func _ring_row(k: int) -> Dictionary:
	var out: Dictionary = {}
	for row: Dictionary in ring_rows():
		if int(row["ring"]) == k or (bool(row.get("or_more", false)) and k >= int(row["ring"])):
			out = row
	return out


func capacity(ctx: RuneContext) -> int:
	var n: int = 1 if bool(params.get("anchor_counts", true)) else 0
	for k: int in range(1, ctx.rings + 1):
		n += ring_capacity(k)
	return n


func full_text(ctx: RuneContext) -> String:
	if ctx.rings <= 0:
		return "Before its first binding a skill has no word: runes are sealed when a vestige is bound into it."
	return "The seal is full: %d ring%s, %d runes and the skill's own." % [ctx.rings, "" if ctx.rings == 1 else "s", capacity(ctx) - 1]


func _room(word: Dictionary, k: int) -> bool:
	return RuneWord.ring_nodes(word, k).size() < ring_capacity(k)


func place_ring(word: Dictionary, ctx: RuneContext, to_node: int, ring: int) -> int:
	if ring >= 0:
		return ring
	var tries: Array[int] = []
	if to_node >= 0:
		var tr: int = RuneWord.ring(word, to_node)
		tries = [tr + 1, tr, tr - 1]
	else:
		if ctx.forming > 0:
			tries.append(ctx.forming)
		for k: int in range(1, ctx.rings + 1):
			tries.append(k)
	# a ring with room whose inner rings are formed first (the seal is built from the skill outward)
	for k: int in tries:
		if k >= 1 and k <= ctx.rings and _room(word, k) and unformed_below(word, k) == 0:
			return k
	for k: int in tries:
		if k >= 1 and k <= ctx.rings and _room(word, k):
			return k
	return tries[0] if not tries.is_empty() else 1


# --- building out from the skill (Brent 2026-10-23 and 2026-10-24) ------------------------------
# One level, one ring, one construct, locked together: ring N+1 is never built before ring N is
# formed. Brent 2026-10-24: "Every slot should be filled to be fully formed ... Its all or nothing at
# each level." A ring is formed when every one of its places holds a rune (ring_capacity). The word's
# own rules still apply on top at the bind: closed, every bond valid, no alignment refused. A ring a
# rework leaves with an empty place is unformed again until it is filled back.

## Ring k is full: every place on it holds a rune (the skill's own ring 0 always is).
func ring_formed(word: Dictionary, k: int) -> bool:
	if k <= 0:
		return true
	return RuneWord.ring_nodes(word, k).size() >= ring_capacity(k)


## How many of ring k's places hold a rune, and how many it has: "2 of 3".
func ring_fill_text(word: Dictionary, k: int) -> String:
	return "%d of %d" % [RuneWord.ring_nodes(word, k).size(), ring_capacity(k)]


## The innermost ring inside ring k that is not formed (0: every ring inside k is formed).
func unformed_below(word: Dictionary, k: int) -> int:
	for j: int in range(1, k):
		if not ring_formed(word, j):
			return j
	return 0


## The innermost ring up to `upto` that is not formed (0: all are).
func first_unformed(word: Dictionary, upto: int) -> int:
	for j: int in range(1, upto + 1):
		if not ring_formed(word, j):
			return j
	return 0


## Why nothing can be set on ring k while ring `gap` (inside it) is not full.
func unformed_text(word: Dictionary, gap: int, k: int) -> String:
	return "ring %d is not formed yet: %s places hold a rune. A seal is built from the skill outward: fill every place of ring %d before anything goes on ring %d." % [
		gap, ring_fill_text(word, gap), gap, k]


## May this draft be sealed? Everything the rule set asks, and every ring up to the one this level
## lock forms (and any ring the word holds) full, from the skill outward: all or nothing.
func can_seal(word: Dictionary, ctx: RuneContext) -> Dictionary:
	var r: Dictionary = super.can_seal(word, ctx)
	# what breaks the rules is said first; then the rings' places, before "close it"
	if RuneWord.size(word) == 0 or str(r.get("reason", "")) == "problems":
		return r
	var upto: int = maxi(ctx.forming, RuneWord.outer_ring(word))
	var gap: int = first_unformed(word, upto)
	if gap > 0:
		if gap == ctx.forming:
			return no("ring_unformed", "Ring %d is not full: %s places hold a rune. Every place must be filled before the level can lock." % [gap, ring_fill_text(word, gap)])
		return no("ring_unformed", "Ring %d is not full: %s places hold a rune. Every ring up to ring %d must be full before the level can lock." % [gap, ring_fill_text(word, gap), upto])
	return r


# --- keystones (Brent 2026-10-24, design/14 section 12) ------------------------------------------
# "Then a vestige is placed over the top with its effect being worth more than a regular rune...and
# that locks the level." The construct bound at a lock is set over its full ring as the keystone and
# sealed with the word (RuneWord.keystones). It works through the word's effects - the ONE place a
# construct's concept reaches a skill (the ability's "bound" list is only a record) - taken before the
# runes, so its concept multiplies the skill's own numbers as a bind always did, but weighted: every
# multiplier's distance from 1 is scaled by the tier's weight (params.keystone).

func keystone_params() -> Dictionary:
	return params.get("keystone", {})


## How much a keystone of `tier` counts: weight_base + weight_per_tier x the tier's place (vestige 0).
## A regular rune works at its strength - at most 1.0 before conversion.
func keystone_weight(tier: String) -> float:
	var kp: Dictionary = keystone_params()
	var at: int = maxi(0, GameData.construct_tiers.find(tier))
	return float(kp.get("weight_base", 1.0)) + float(kp.get("weight_per_tier", 0.0)) * float(at)


## A concept's multiplier `m`, weighted: its distance from 1 times `weight`, never under the floor.
func keystone_mult(m: float, weight: float) -> float:
	return maxf(float(keystone_params().get("mult_floor", 0.0)), 1.0 + (m - 1.0) * weight)


## What one keystone {ring, tier, concept} does to ability `ab` (its data, before any word): {ring,
## tier, concept, label, weight, patch, lines, text}. Every field of the concept the skill has - at the
## top or in one of params.keystone.parts - is multiplied by the weighted multiplier; a concept with
## none of them gives its fallback, weighted, so no keystone is wasted.
func keystone_effect(ab: Dictionary, ks: Dictionary) -> Dictionary:
	var tier: String = str(ks.get("tier", ""))
	var cid: String = str(ks.get("concept", ""))
	var c: Dictionary = GameData.concept(cid)
	var w: float = keystone_weight(tier)
	var patch: Array = []
	var lines: Array[String] = []
	var mods: Dictionary = c.get("mods", {})
	for key: String in mods:
		var m: float = keystone_mult(float(mods[key]), w)
		var hit := false
		if ab.has(key) and _is_num(ab[key]):
			patch.append({"op": "mul", "path": key, "value": m})
			hit = true
		for part: Variant in keystone_params().get("parts", []):
			var pd: Variant = ab.get(str(part))
			if typeof(pd) == TYPE_DICTIONARY and (pd as Dictionary).has(key) and _is_num((pd as Dictionary)[key]):
				patch.append({"op": "mul", "path": "%s.%s" % [str(part), key], "value": m})
				hit = true
		if hit:
			lines.append("%s x%s" % [_field_word(key), _x(m)])
	if patch.is_empty():
		var fb: Dictionary = c.get("fallback", {})
		for key2: String in fb:
			var m2: float = keystone_mult(float(fb[key2]), w)
			patch.append({"op": "mul", "path": key2, "value": m2})
			lines.append("%s x%s (none of its fields is on this skill)" % ["every hit's damage" if key2 == "damage_all" else _field_word(key2), _x(m2)])
	var label: String = "%s of %s" % [tier, str(c.get("label", cid))]
	return {"ring": int(ks.get("ring", 0)), "tier": tier, "concept": cid, "label": label, "weight": w, "patch": patch, "lines": lines,
		"text": "Keystone over ring %d - the %s (x%s, a rune at most x1): %s" % [int(ks.get("ring", 0)), label, _x(w), ", ".join(PackedStringArray(lines))]}


## The word's effects, with its keystones folded in first (their patch ahead of the runes').
func effects(word: Dictionary, ctx: RuneContext) -> Dictionary:
	var e: Dictionary = super.effects(word, ctx)
	var kss: Array[Dictionary] = RuneWord.keystones(word)
	var ab: Dictionary = GameData.ability(ctx.ability_id) if GameData.abilities.has(ctx.ability_id) else {}
	if kss.is_empty() or ab.is_empty():
		return e
	var patch: Array = []
	var rows: Array = []
	var lines: Array = []
	var summary: Array = []
	var have: Dictionary = {}
	for f: Variant in e.get("fields", []):
		have[str((f as Dictionary).get("path", ""))] = true
	var fields: Array = (e.get("fields", []) as Array).duplicate()
	var fxp: Dictionary = _fx_params()
	for ks: Dictionary in kss:
		var ke: Dictionary = keystone_effect(ab, ks)
		patch.append_array(ke["patch"])
		rows.append(ke)
		lines.append(str(ke["text"]))
		summary.append("keystone %s: %s" % [str(ke["label"]), ", ".join(PackedStringArray(ke["lines"]))])
		for p: Dictionary in ke["patch"]:
			var path: String = str(p["path"])
			if have.has(path):
				continue
			have[path] = true
			var f2: Dictionary = {"path": path, "group": "keystone", "label": _field_word(path).capitalize() if path != "damage_all" else "Damage, every hit",
				"unit": "", "lower_is_better": (fxp.get("lower_is_better", []) as Array).has(_group_of(path)), "scaled_by_stage": false}
			if path == "damage_all":
				f2["pct"] = true
			fields.append(f2)
	patch.append_array(e.get("patch", []))
	e["patch"] = patch
	e["keystones"] = rows
	e["fields"] = fields
	e["lines"] = lines + (e.get("lines", []) as Array)
	e["summary"] = summary + (e.get("summary", []) as Array)
	return e


func _fx_params() -> Dictionary:
	for iid: Variant in params.get("interactions", []):
		return (params.get("interaction_params", {}) as Dictionary).get(str(iid), {})
	return {}


## The stat group a field belongs to in the effects params ("" if none).
func _group_of(path: String) -> String:
	var groups: Dictionary = _fx_params().get("stat_groups", {})
	for g: String in groups:
		for spec: Variant in groups[g]:
			if str(spec).get_slice("@", 0) == path:
				return g
	return ""


func _field_word(path: String) -> String:
	var labels: Dictionary = _fx_params().get("field_labels", {})
	return str(labels.get(path, path.get_slice(".", path.get_slice_count(".") - 1).replace("_", " "))).to_lower()


static func _x(v: float) -> String:
	return ("%.3f" % v).rstrip("0").rstrip(".")


static func _is_num(v: Variant) -> bool:
	return typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT


## Two rings a bond may span: the same, or next to each other.
static func rings_meet(ra: int, rb: int) -> bool:
	return absi(ra - rb) <= 1


func _apart(word: Dictionary, a: int, b: int) -> Dictionary:
	var ra: int = RuneWord.ring(word, a)
	var rb: int = RuneWord.ring(word, b)
	if rings_meet(ra, rb) and not (ra == 0 and rb == 0):
		return ok()
	return no("rings_apart", "%s is %s and %s %s: a rune bonds only on its own ring and the rings just inside and outside." % [
		rune_name(word, a), _ring_words(ra), rune_name(word, b), _ring_words(rb)])


static func _ring_words(k: int) -> String:
	return "the skill's own rune" if k == 0 else "on ring %d" % k


func _can_add(word: Dictionary, rune_id: String, ctx: RuneContext, to_node: int, ring: int) -> Dictionary:
	if ctx.rings <= 0:
		return no("no_rings", full_text(ctx))
	if ring < 1 or ring > ctx.rings:
		return no("ring", "Ring %d is not open: this skill has %d ring%s." % [ring, ctx.rings, "" if ctx.rings == 1 else "s"])
	if not _room(word, ring):
		return no("ring_full", "Ring %d is full: it holds %d rune%s." % [ring, ring_capacity(ring), "" if ring_capacity(ring) == 1 else "s"])
	if to_node >= 0 and not rings_meet(RuneWord.ring(word, to_node), ring):
		return no("rings_apart", "%s is %s; ring %d is too far out to bond to it." % [rune_name(word, to_node), _ring_words(RuneWord.ring(word, to_node)), ring])
	var gap: int = unformed_below(word, ring)
	if gap > 0:
		return no("ring_unformed", unformed_text(word, gap, ring))
	return super._can_add(word, rune_id, ctx, to_node, ring)


func _can_link(word: Dictionary, a: int, b: int, ctx: RuneContext) -> Dictionary:
	var apart: Dictionary = _apart(word, a, b)
	if not bool(apart["ok"]):
		return apart
	return super._can_link(word, a, b, ctx)


## Bonds the skill's own rune needs before the word can close.
func anchor_needs(word: Dictionary) -> int:
	var v: int = valence(RuneWord.node_id(word, 0))
	if bool(params.get("anchor_fills_by_ring", true)):
		return mini(v, ring_capacity(1))
	return v


func _word_state(word: Dictionary, ctx: RuneContext) -> Dictionary:
	var problems: Array = []
	var lines: Array = []
	var open := 0
	for i: int in RuneWord.size(word):
		var rid: String = RuneWord.node_id(word, i)
		var deg: int = RuneWord.degree(word, i)
		if deg > valence(rid):
			problems.append("%s has %d bonds; its valence is %d." % [rune_name(word, i), deg, valence(rid)])
		else:
			open += maxi(0, (anchor_needs(word) if i == 0 else valence(rid)) - deg)
	for l: Dictionary in RuneWord.links(word):
		var a: int = int(l["a"])
		var b: int = int(l["b"])
		if alignment_state(RuneWord.node_id(word, a), RuneWord.node_id(word, b)) == "refused":
			problems.append("%s and %s are bonded, but their affinities refuse each other." % [rune_name(word, a), rune_name(word, b)])
		if not bool(_apart(word, a, b)["ok"]):
			problems.append("%s and %s are bonded across rings that do not touch." % [rune_name(word, a), rune_name(word, b)])
	var counts: Array[String] = []
	for k: int in range(1, maxi(ctx.rings, RuneWord.outer_ring(word)) + 1):
		var n: int = RuneWord.ring_nodes(word, k).size()
		if k > ctx.rings and n > 0:
			problems.append("Ring %d holds runes, but the skill has %d ring%s." % [k, ctx.rings, "" if ctx.rings == 1 else "s"])
		elif n > ring_capacity(k):
			problems.append("Ring %d holds %d runes; it has room for %d." % [k, n, ring_capacity(k)])
		if k <= ctx.rings:
			counts.append("ring %d: %d of %d" % [k, n, ring_capacity(k)])
	if not bool(params.get("allow_repeats", true)):
		var seen: Dictionary = {}
		for rid: Variant in RuneWord.nodes(word):
			if seen.has(rid):
				problems.append("%s is in the word twice." % str(GameData.rune(str(rid)).get("name", rid)))
			seen[rid] = true
	var joined: bool = RuneWord.is_joined(word)
	var needs_joined: bool = bool(params.get("closed_needs_connected", true))
	var closed: bool = problems.is_empty() and open == 0 and (joined or not needs_joined) and RuneWord.size(word) > 1
	if not counts.is_empty():
		lines.append(",  ".join(PackedStringArray(counts)) + ".")
	if open > 0:
		lines.append("%d open bond%s to fill." % [open, "" if open == 1 else "s"])
	if not joined:
		lines.append("Not every rune is joined to the skill%s." % (" - a closed word is one piece" if needs_joined else ""))
	var gap: int = first_unformed(word, maxi(ctx.forming, RuneWord.outer_ring(word)))
	if gap > 0:
		lines.append("Ring %d is not full yet (%s): every place must hold a rune%s." % [gap, ring_fill_text(word, gap),
			" before the rings outside it can hold runes" if gap < maxi(ctx.forming, RuneWord.outer_ring(word)) else ""])
	var traits: Array = []
	for t: Dictionary in shape_traits(word):
		traits.append(str(t["text"]))
	return {"closed": closed, "label": "closed - it can be sealed" if closed else "open - not a word yet", "problems": problems, "lines": lines,
		"traits": traits}


# --- shape traits ----------------------------------------------------------------------------

## The trait definitions (Bond Rules rows 55-59), kept with the effects interaction's params.
func trait_params() -> Dictionary:
	for iid: Variant in params.get("interactions", []):
		var p: Dictionary = (params.get("interaction_params", {}) as Dictionary).get(str(iid), {})
		if p.has("shape_traits"):
			return p["shape_traits"]
	return {}


## The shapes this word has, each {id, label, text, nodes, ring?, count}. Structural only: what each
## does to the skill is the effects interaction's.
##   closed_ring  every rune on a ring bonded round it (3 or more, each bonded to two on its ring,
##                one piece, and the ring joined to the skill)
##   great_ring   a closed ring of params' min_runes or more
##   spoke        a chain from ring 1 (bonded to the skill) straight out through min_rings rings
##   branch       runes (not the skill's own) with min_bonds or more bonds, counted up to max_count
##   balanced     ring 1 full and every bond of the skill's own rune the same kind
func shape_traits(word: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var tp: Dictionary = trait_params()
	if tp.is_empty() or RuneWord.size(word) < 2:
		return out
	var rs: Array[int] = RuneWord.rings(word)
	var dist: Array[int] = RuneWord.distances(word)
	# closed and great rings
	var closed_def: Dictionary = tp.get("closed_ring", {})
	var great_def: Dictionary = tp.get("great_ring", {})
	for k: int in range(1, RuneWord.outer_ring(word) + 1):
		var on: Array[int] = RuneWord.ring_nodes(word, k)
		if on.size() < int(closed_def.get("min_runes", 3)) or not _ring_round(word, on, rs):
			continue
		if not on.any(func(i: int) -> bool: return dist[i] >= 0):
			continue
		if not closed_def.is_empty():
			out.append({"id": "closed_ring", "label": str(closed_def.get("label", "Closed ring")), "ring": k, "nodes": on, "count": 1,
				"text": "%s (ring %d): %s" % [str(closed_def.get("label", "Closed ring")), k, str(closed_def.get("change", ""))]})
		if not great_def.is_empty() and on.size() >= int(great_def.get("min_runes", 5)):
			out.append({"id": "great_ring", "label": str(great_def.get("label", "Great ring")), "ring": k, "nodes": on, "count": 1,
				"text": "%s (ring %d, %d runes): %s" % [str(great_def.get("label", "Great ring")), k, on.size(), str(great_def.get("change", ""))]})
	# the spoke: the longest chain straight out from ring 1
	var spoke_def: Dictionary = tp.get("spoke", {})
	if not spoke_def.is_empty():
		var chain: Array[int] = _longest_spoke(word, rs)
		if chain.size() >= int(spoke_def.get("min_rings", 3)):
			out.append({"id": "spoke", "label": str(spoke_def.get("label", "Spoke")), "nodes": chain, "rings": chain.size(),
				"count": chain.size() - int(spoke_def.get("free_rings", 2)),
				"text": "%s through %d rings: %s" % [str(spoke_def.get("label", "Spoke")), chain.size(), str(spoke_def.get("change", ""))]})
	# branch runes
	var branch_def: Dictionary = tp.get("branch", {})
	if not branch_def.is_empty():
		var hubs: Array[int] = []
		for i: int in range(1, RuneWord.size(word)):
			if RuneWord.degree(word, i) >= int(branch_def.get("min_bonds", 3)):
				hubs.append(i)
		if not hubs.is_empty():
			var names: Array[String] = []
			for i: int in hubs:
				names.append(rune_name(word, i))
			out.append({"id": "branch", "label": str(branch_def.get("label", "Branch")), "nodes": hubs,
				"count": mini(hubs.size(), int(branch_def.get("max_count", 3))),
				"text": "%s x%d (%s): %s" % [str(branch_def.get("label", "Branch")), hubs.size(), ", ".join(names), str(branch_def.get("change", ""))]})
	# balanced
	var bal_def: Dictionary = tp.get("balanced", {})
	var ring1: Array[int] = RuneWord.ring_nodes(word, 1)
	var anchor_ns: Array[int] = RuneWord.neighbours(word, 0)
	if not bal_def.is_empty() and ring1.size() >= ring_capacity(1) and not anchor_ns.is_empty():
		var kinds: Dictionary = {}
		for k2: int in anchor_ns:
			kinds[bond_kind(RuneWord.node_id(word, 0), RuneWord.node_id(word, k2))] = true
		if kinds.size() == 1:
			out.append({"id": "balanced", "label": str(bal_def.get("label", "Balanced")), "nodes": ring1, "count": 1, "kind": str(kinds.keys()[0]),
				"text": "%s (every bond to the skill %s): %s" % [str(bal_def.get("label", "Balanced")), str(kinds.keys()[0]), str(bal_def.get("change", ""))]})
	return out


## Every rune of the ring bonded to at least two others on it, and the ring one piece.
func _ring_round(word: Dictionary, on: Array[int], rs: Array[int]) -> bool:
	for i: int in on:
		var same := 0
		for k: int in RuneWord.neighbours(word, i):
			if rs[k] == rs[i]:
				same += 1
		if same < 2:
			return false
	var seen: Dictionary = {on[0]: true}
	var todo: Array[int] = [on[0]]
	while not todo.is_empty():
		var at: int = todo.pop_back()
		for k: int in RuneWord.neighbours(word, at):
			if rs[k] == rs[at] and not seen.has(k):
				seen[k] = true
				todo.append(k)
	return seen.size() == on.size()


## The longest chain from a ring-1 rune bonded to the skill, one ring further out at each bond.
func _longest_spoke(word: Dictionary, rs: Array[int]) -> Array[int]:
	var best: Array[int] = []
	for start: int in RuneWord.neighbours(word, 0):
		if rs[start] != 1:
			continue
		var chain: Array[int] = _spoke_from(word, start, rs)
		if chain.size() > best.size():
			best = chain
	return best


func _spoke_from(word: Dictionary, i: int, rs: Array[int]) -> Array[int]:
	var best: Array[int] = []
	for k: int in RuneWord.neighbours(word, i):
		if rs[k] == rs[i] + 1:
			var c: Array[int] = _spoke_from(word, k, rs)
			if c.size() > best.size():
				best = c
	var out: Array[int] = [i]
	out.append_array(best)
	return out
