extends RuneInteraction
## Rune effects, layers 1-3 (Brent 2026-10-22; workbook Base Runes O, Universal Runes H, Bond Rules
## rows 19-40). Every number is in runes.json: bond_v1.interaction_params.effects_v1 (`params`).
##
##   Layer 1  each rune's ops ("power x1.2", "status soaked", "shove +1.5", ...), parsed by the exporter.
##   Layer 2  the bond a rune reaches the skill through: its kind factor, read from the rune's side
##            (the rune with more pull - higher electronegativity - takes "more_pull").
##   Layer 3  the fade with each bond between the rune and the skill's own rune.
##   strength = fade(shortest path length) x kind factor of the rune's own bond on that path (the
##   best such path when there are several). A multiplier m becomes 1 + (m - 1) x strength; an
##   amount is multiplied by strength; a status, interrupt or brace needs strength >= the threshold.
##   Each stat group's total is clamped to [mult_min, mult_max].
##   The anchor: its ops name what the skill already does; those parts of the skill are scaled by
##   the anchor's own side factor averaged over its bonds (a multiplier's share is rescaled; an
##   amount is multiplied; a status/interrupt/brace is lost below the threshold).
##   Fallback: a group the skill has no fields for, or a grant it cannot use, gives fallback_fraction
##   of the change as power (or, with no damage at all, as a cost cut), so no rune does nothing.
##
## The result is a PATCH - field operations on the ability dictionary - that Player.ability_stats
## applies to a locked word's skill, plus the words and the per-rune breakdown the screen shows.
##
## Rule changes of 2026-10-22 (the build brief): a status op on a skill that already applies that
## status adds stacks; `jumps +n` arcs any hit on to n more enemies (a chain or a jumping beam gets
## more jumps); `braced` works on any skill (Braced for the cast and recovery); `through` makes a
## hit ignore front block and shields; every skill has a recovery (its own or the default), so the
## windup group always acts; a self buff's or channel's main magnitude (its `magnitude` paths, an
## amount or a multiplier's gap from 1) counts as power; poise on any damaging hit adds stagger
## damage (the default skill poise where the hit names none); duration also lengthens the statuses
## a skill applies (its status_s, or a status_time_mult on the payload).

var _cache_key := ""
var _cache: Dictionary = {}


# --- hooks ---------------------------------------------------------------------------------

func on_effects(word: Dictionary, ctx: RuneContext, effects: Dictionary) -> void:
	effects.merge(compute(word, ctx), true)


func on_describe_link(word: Dictionary, a: int, b: int, ctx: RuneContext, desc: Dictionary) -> void:
	var r: Dictionary = compute(word, ctx)
	var dist: Array = r.get("_dist", [])
	if a >= dist.size() or b >= dist.size():
		return
	var far: int = b if int(dist[b]) >= int(dist[a]) else a
	var near: int = a if far == b else b
	if int(dist[far]) < 0:
		desc["strength"] = 0.0
		return
	var depth: int = int(dist[far]) if int(dist[near]) == int(dist[far]) - 1 else int(dist[far]) + 1
	desc["strength"] = _fade(depth) * _side_factor(word, far, near)


func on_describe_node(word: Dictionary, i: int, ctx: RuneContext, desc: Dictionary) -> void:
	var r: Dictionary = compute(word, ctx)
	for row: Dictionary in r.get("runes", []):
		if int(row["node"]) == i:
			desc["strength"] = float(row["strength"])
			return
	if i == 0:
		desc["strength"] = float((r.get("anchor", {}) as Dictionary).get("factor", 1.0))


func on_describe_rune(rune_id: String, _ctx: RuneContext, desc: Dictionary) -> void:
	var words: Array[String] = []
	for op: Dictionary in GameData.rune(rune_id).get("ops", []):
		words.append(op_words(op, 1.0))
	if not words.is_empty():
		(desc["lines"] as Array).append("Effect: " + ", ".join(words))


# --- the calculation ---------------------------------------------------------------------

## The whole result for a word in a skill (cached on the word and the skill's level).
func compute(word: Dictionary, ctx: RuneContext) -> Dictionary:
	var key: String = "%s|%d|%d|%s" % [ctx.ability_id, ctx.stage, ctx.rings, RuneWord.shape_key(word)]
	if key == _cache_key:
		return _cache
	_cache = _compute(word, ctx)
	_cache_key = key
	return _cache


func _compute(word: Dictionary, ctx: RuneContext) -> Dictionary:
	var ab: Dictionary = GameData.ability(ctx.ability_id) if GameData.abilities.has(ctx.ability_id) else {}
	var n: int = RuneWord.size(word)
	var dist: Array[int] = _distances(word)
	var out: Dictionary = {"patch": [], "groups": {}, "lines": [], "runes": [], "anchor": {}, "_dist": dist}
	if ab.is_empty() or n == 0:
		return out
	var groups: Dictionary = {}               # group -> running multiplier
	var fallback_mult := 1.0                  # power change from fallbacks, op by op
	var patch: Array = []
	var lines: Array = []
	var threshold: float = float(params.get("status_threshold", 0.5))

	# the anchor: scale the skill's own signature
	var af: float = _anchor_factor(word)
	var anchor_lines: Array = []
	if RuneWord.degree(word, 0) > 0:
		for op: Dictionary in GameData.rune(RuneWord.node_id(word, 0)).get("ops", []):
			var t: String = _scale_signature(ab, op, af, threshold, groups, patch)
			if t != "":
				anchor_lines.append(t)
	out["anchor"] = {"factor": af, "lines": anchor_lines, "kinds": _anchor_kinds(word)}

	# every other rune
	for i: int in range(1, n):
		var rid: String = RuneWord.node_id(word, i)
		var row: Dictionary = {"node": i, "id": rid, "name": str(GameData.rune(rid).get("name", rid)), "bonds": dist[i], "kind": "", "side": "", "strength": 0.0, "used": [], "fallback": []}
		if dist[i] > 0:
			var best: Dictionary = _best_path(word, i, dist)
			row["kind"] = best["kind"]
			row["side"] = best["side"]
			row["relation"] = best["relation"]
			row["strength"] = best["strength"]
		var s: float = float(row["strength"])
		if s > 0.0:
			for op: Dictionary in GameData.rune(rid).get("ops", []):
				var res: Dictionary = _apply_op(ab, op, s, threshold, groups, patch)
				if bool(res["used"]):
					(row["used"] as Array).append(str(res["text"]))
					if str(res.get("line", "")) != "":
						lines.append(str(res["line"]))
				else:
					fallback_mult *= 1.0 + float(res["change"]) * float(params.get("fallback_fraction", 0.25))
					(row["fallback"] as Array).append("%s -> %s" % [op_words(op, s), str(res["why"])])
		(out["runes"] as Array).append(row)
	_finish(ab, groups, fallback_mult, patch, lines, anchor_lines, out)
	return out


## The end of a computation, shared with later effects versions: the fallback lands, the group
## multipliers are clamped and patched onto their fields, and the words for the screen are made.
func _finish(ab: Dictionary, groups: Dictionary, fallback_mult: float, patch: Array, lines: Array, anchor_lines: Array, out: Dictionary) -> void:
	# the fallback lands on power, or on cost for a skill that deals no damage
	if absf(fallback_mult - 1.0) > 0.000001:
		var landed := false
		for g: Variant in params.get("fallback_groups", ["power"]):
			if not _group_acts(ab, str(g)):
				continue
			var m: float = fallback_mult
			if (params.get("lower_is_better", []) as Array).has(str(g)):
				m = 1.0 - (fallback_mult - 1.0)
			groups[str(g)] = float(groups.get(str(g), 1.0)) * m
			lines.append("runes it cannot use: %s x%.2f" % [_group_word(str(g)), m])
			landed = true
			break
		if not landed:
			lines.append("runes it cannot use have nowhere to go")

	# group multipliers, clamped, onto every field of the group
	var lo: float = float(params.get("mult_min", 0.0))
	var hi: float = float(params.get("mult_max", 100.0))
	var caps: Dictionary = params.get("field_caps", {})
	for g: String in groups:
		var m2: float = clampf(float(groups[g]), lo, hi)
		(out["groups"] as Dictionary)[g] = m2
		for path: String in _group_fields(ab, g):
			patch.append({"op": "mul", "path": path, "value": m2})
			if caps.has(path):
				patch.append({"op": "min", "path": path, "value": float(caps[path])})
		_extra_group_patch(ab, g, m2, patch)
	out["patch"] = patch
	out["lines"] = lines
	out["fields"] = _fields_shown(ab)
	# one short list for tooltips: each group that moves, then the hit effects
	var summary: Array = []
	for g: String in out["groups"]:
		var m3: float = float((out["groups"] as Dictionary)[g])
		if absf(m3 - 1.0) >= 0.005:
			summary.append("%s%d%% %s" % ["+" if m3 > 1.0 else "-", int(round(absf(m3 - 1.0) * 100.0)), _group_word(g)])
	summary.append_array(anchor_lines)
	summary.append_array(lines)
	out["summary"] = summary


## Every stat field the skill has, for the before/after preview: [{path, group, label, unit,
## lower_is_better, scaled_by_stage}].
func _fields_shown(ab: Dictionary) -> Array:
	var out: Array = []
	var labels: Dictionary = params.get("field_labels", {})
	var units: Dictionary = params.get("group_units", {})
	var field_units: Dictionary = params.get("field_units", {})
	var seen: Dictionary = {}
	for g: String in (params.get("stat_groups", {}) as Dictionary):
		for spec: Variant in (params["stat_groups"] as Dictionary)[g]:
			var path: String = str(spec).get_slice("@", 0)
			if seen.has(path) or not _group_fields(ab, g).has(path):
				continue
			if str(spec).contains("@") and not str(spec).get_slice("@", 1).split("|").has(str(ab.get("kind", ""))):
				continue
			seen[path] = true
			out.append({"path": path, "group": g, "label": str(labels.get(str(spec), labels.get(path, path.capitalize()))),
				"unit": str(field_units.get(path, units.get(g, ""))), "lower_is_better": (params.get("lower_is_better", []) as Array).has(g),
				"scaled_by_stage": (params.get("stage_scaled_groups", []) as Array).has(g)})
	return out


## Bonds from the anchor to each node (-1 = not joined to it).
func _distances(word: Dictionary) -> Array[int]:
	var n: int = RuneWord.size(word)
	var dist: Array[int] = []
	for i: int in n:
		dist.append(-1)
	if n == 0:
		return dist
	dist[0] = 0
	var queue: Array[int] = [0]
	while not queue.is_empty():
		var at: int = queue.pop_front()
		for k: int in RuneWord.neighbours(word, at):
			if dist[k] < 0:
				dist[k] = dist[at] + 1
				queue.append(k)
	return dist


## The strongest way node i reaches the anchor: through one of its neighbours one bond closer.
func _best_path(word: Dictionary, i: int, dist: Array[int]) -> Dictionary:
	var best: Dictionary = {"strength": -1.0, "kind": "", "side": ""}
	for p: int in RuneWord.neighbours(word, i):
		if dist[p] != dist[i] - 1:
			continue
		var s: float = _fade(dist[i]) * _side_factor(word, i, p)
		if s > float(best["strength"]):
			best = {"strength": s, "kind": _kind(word, i, p), "side": _side(word, i, p), "relation": _relation(word, i, p)}
	if float(best["strength"]) < 0.0:
		best["strength"] = 0.0
	return best


func _fade(bonds: int) -> float:
	var out := 0.0
	for f: Dictionary in params.get("fade", []):
		if int(f["bonds"]) == bonds or (bool(f.get("or_more", false)) and bonds >= int(f["bonds"])):
			out = float(f["strength"])
	return out


func _kind(word: Dictionary, a: int, b: int) -> String:
	if rules != null and rules.has_method("bond_kind"):
		return str(rules.call("bond_kind", RuneWord.node_id(word, a), RuneWord.node_id(word, b)))
	return "even"


## "more" if node i pulls harder than node j (higher electronegativity), "less" if weaker.
func _side(word: Dictionary, i: int, j: int) -> String:
	var ei: float = float(GameData.rune(RuneWord.node_id(word, i)).get("electronegativity", 0.0))
	var ej: float = float(GameData.rune(RuneWord.node_id(word, j)).get("electronegativity", 0.0))
	return "more" if ei >= ej else "less"


## The kind factor of the bond i-j, read from i's side.
func _side_factor(word: Dictionary, i: int, j: int) -> float:
	var kf: Dictionary = (params.get("kind_factors", {}) as Dictionary).get(_kind(word, i, j), {})
	return float(kf.get("more_pull" if _side(word, i, j) == "more" else "less_pull", 1.0))


func _anchor_factor(word: Dictionary) -> float:
	var ns: Array[int] = RuneWord.neighbours(word, 0)
	if ns.is_empty():
		return 1.0
	var t := 0.0
	for k: int in ns:
		t += _side_factor(word, 0, k)
	return t / float(ns.size())


## The bond i-j in words naming its dominant side ("polar: Gush dominates Surge"), as the rule set
## words it.
func _relation(word: Dictionary, i: int, j: int) -> String:
	var kind: String = _kind(word, i, j)
	var ni: String = RuneRules.rune_name(word, i)
	var nj: String = RuneRules.rune_name(word, j)
	var more: String = ni if _side(word, i, j) == "more" else nj
	var less: String = nj if more == ni else ni
	if rules != null and rules.has_method("relation"):
		return str(rules.call("relation", kind, more, less))
	return "%s: %s pulls harder" % [kind, more]


func _anchor_kinds(word: Dictionary) -> Array:
	var out: Array = []
	for k: int in RuneWord.neighbours(word, 0):
		out.append(_relation(word, 0, k))
	return out


# --- ability fields --------------------------------------------------------------------

## What a group's multiplier also reaches beyond the skill's own fields (2026-10-22): the default
## recovery, a self buff's magnitude, the default poise of a damaging hit, the statuses it applies.
func _extra_group_patch(ab: Dictionary, g: String, m: float, patch: Array) -> void:
	match g:
		"windup":
			if not ab.has("recovery"):
				patch.append({"op": "set", "path": "recovery", "value": GameData.num("abilities", "cast_recovery") * m})
		"power":
			for mag: Variant in ab.get("magnitude", []):
				var path: String = str((mag as Dictionary)["path"])
				patch.append({"op": "mul_gap" if str((mag as Dictionary).get("as", "amount")) == "mult" else "mul", "path": path, "value": m})
		"poise":
			for part: String in _payload_parts(ab):
				if _part_deals_damage(ab, part) and not (get_path_value(ab, part) as Dictionary).has("poise"):
					patch.append({"op": "set", "path": part + ".poise", "value": GameData.num("combat", "skill_poise") * m})
		"duration":
			for part2: String in _payload_parts(ab):
				var p: Dictionary = get_path_value(ab, part2)
				if (p.has("status") or p.has("statuses")) and not p.has("status_s"):
					patch.append({"op": "set", "path": part2 + ".status_time_mult", "value": m})


## True if the group reaches something in this skill once the 2026-10-22 rules are counted.
func _group_acts(ab: Dictionary, g: String) -> bool:
	if not _group_fields(ab, g).is_empty():
		return true
	match g:
		"windup":
			return true                           # every skill has a recovery
		"power":
			return not (ab.get("magnitude", []) as Array).is_empty()
		"poise":
			for part: String in _payload_parts(ab):
				if _part_deals_damage(ab, part):
					return true
		"duration":
			for part2: String in _payload_parts(ab):
				var p: Dictionary = get_path_value(ab, part2)
				if p.has("status") or p.has("statuses"):
					return true
	return false


## The fields of a stat group this skill has: paths whose value is a non-zero number.
func _group_fields(ab: Dictionary, group: String) -> Array[String]:
	var out: Array[String] = []
	for spec: Variant in (params.get("stat_groups", {}) as Dictionary).get(group, []):
		var s: String = str(spec)
		var path: String = s.get_slice("@", 0)
		if s.contains("@") and not s.get_slice("@", 1).split("|").has(str(ab.get("kind", ""))):
			continue
		var v: Variant = get_path_value(ab, path)
		if (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) and float(v) != 0.0:
			out.append(path)
	return out


## The first hit payload the skill has (params.payload_parts), or "".
func _payload_part(ab: Dictionary) -> String:
	for p: Variant in params.get("payload_parts", []):
		if typeof(get_path_value(ab, str(p))) == TYPE_DICTIONARY:
			return str(p)
	return ""


## Every payload part the skill has.
func _payload_parts(ab: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for p: Variant in params.get("payload_parts", []):
		if typeof(get_path_value(ab, str(p))) == TYPE_DICTIONARY:
			out.append(str(p))
	return out


static func get_path_value(d: Dictionary, path: String) -> Variant:
	var cur: Variant = d
	for key: String in path.split("."):
		if typeof(cur) != TYPE_DICTIONARY or not (cur as Dictionary).has(key):
			return null
		cur = (cur as Dictionary)[key]
	return cur


## Whether the hit payload `part` deals damage when it lands.
func _part_deals_damage(ab: Dictionary, part: String) -> bool:
	var p: Dictionary = get_path_value(ab, part)
	if p.has("damage") or p.has("damage_mult"):
		return true
	return part == "on_hit" and (ab.has("damage") or ab.has("damage_mult"))


# --- one op ------------------------------------------------------------------------------

## A rune's op at strength s. Returns {used, text, line} or {used: false, change, why}.
func _apply_op(ab: Dictionary, op: Dictionary, s: float, threshold: float, groups: Dictionary, patch: Array) -> Dictionary:
	var kind: String = str(op["op"])
	var grant_change: float = float(params.get("grant_as_change", 0.2)) * s
	match kind:
		"mul":
			var g: String = str(op["group"])
			var m: float = 1.0 + (float(op["value"]) - 1.0) * s
			if not _group_acts(ab, g):
				var c: float = m - 1.0
				if (params.get("lower_is_better", []) as Array).has(g):
					c = -c
				return {"used": false, "change": c, "why": "no %s here" % _group_word(g)}
			groups[g] = float(groups.get(g, 1.0)) * m
			return {"used": true, "text": op_words(op, s), "line": ""}
		"status":
			var part: String = _payload_part(ab)
			var id: String = str(op["id"])
			if part == "":
				return {"used": false, "change": grant_change, "why": "nothing it hits"}
			if s < threshold:
				return {"used": false, "change": grant_change, "why": "too faint to take hold"}
			var label: String = _status_label(id)
			if _has_status(ab, part, id):
				# the skill already applies it: more stacks of it (2026-10-22)
				var p: Dictionary = get_path_value(ab, part)
				if str(p.get("status", "")) == id:
					patch.append({"op": "set", "path": part + ".stacks", "value": int(p.get("stacks", 1)) + int(op.get("stacks", 1))})
				else:
					patch.append({"op": "append", "path": part + ".statuses", "value": {"id": id, "stacks": int(op.get("stacks", 1))}})
				return {"used": true, "text": "+%d %s" % [int(op.get("stacks", 1)), label], "line": "+%d stack%s of %s" % [int(op.get("stacks", 1)), "" if int(op.get("stacks", 1)) == 1 else "s", label]}
			patch.append({"op": "append", "path": part + ".statuses", "value": {"id": id, "stacks": int(op.get("stacks", 1))}})
			return {"used": true, "text": "applies %s" % label, "line": "applies %s" % label}
		"shove", "pull":
			var part2: String = _payload_part(ab)
			if part2 == "":
				return {"used": false, "change": grant_change, "why": "nothing it hits"}
			var amt: float = float(op["value"]) * s
			patch.append({"op": "add", "path": part2 + "." + kind, "value": amt})
			var t: String = ("shoves %.1f m further" % amt) if kind == "shove" else ("pulls %.1f m toward you" % amt)
			return {"used": true, "text": t, "line": t}
		"marks":
			var part3: String = _payload_part(ab)
			var marks: int = int(round(float(op["value"]) * s))
			if part3 == "" or marks < 1:
				return {"used": false, "change": grant_change, "why": "nothing it hits" if part3 == "" else "too faint for a whole mark"}
			patch.append({"op": "add", "path": part3 + ".marks", "value": marks})
			return {"used": true, "text": "+%d Live mark%s" % [marks, "" if marks == 1 else "s"], "line": "+%d Live mark%s" % [marks, "" if marks == 1 else "s"]}
		"jumps":
			# 2026-10-22: any hit arcs on (a chain, or a beam that already jumps, gets more jumps)
			var jumps: int = int(round(float(op["value"]) * s))
			var part6: String = _payload_part(ab)
			if jumps < 1 or (part6 == "" and not ab.has("jumps")):
				return {"used": false, "change": grant_change, "why": "too faint for a whole jump" if jumps < 1 else "nothing it hits"}
			if str(ab.get("kind", "")) == "chain" or ab.has("jumps"):
				patch.append({"op": "add", "path": "jumps", "value": jumps})
			else:
				patch.append({"op": "add", "path": part6 + ".jumps", "value": jumps})
			return {"used": true, "text": "+%d jump%s" % [jumps, "" if jumps == 1 else "s"], "line": "arcs on to %d more" % jumps}
		"pierce":
			if str(ab.get("kind", "")) != "projectile" or bool(ab.get("pierce", false)) or int(round(float(op["value"]) * s)) < 1:
				return {"used": false, "change": grant_change, "why": "it already pierces" if bool(ab.get("pierce", false)) else "it is not a shot" if str(ab.get("kind", "")) != "projectile" else "too faint to pierce"}
			patch.append({"op": "set", "path": "pierce", "value": true})
			return {"used": true, "text": "pierces", "line": "passes through every enemy in its path"}
		"interrupts":
			var part4: String = _payload_part(ab)
			if part4 == "" or s < threshold or bool((get_path_value(ab, part4) as Dictionary).get("interrupts", false)):
				return {"used": false, "change": grant_change, "why": "nothing it hits" if part4 == "" else "too faint" if s < threshold else "already interrupts"}
			patch.append({"op": "set", "path": part4 + ".interrupts", "value": true})
			return {"used": true, "text": "interrupts", "line": "interrupts what it hits"}
		"braced":
			# 2026-10-22: any skill - braced for its wind-up, its cast and its recovery
			if s < threshold or bool(ab.get("braced", false)):
				return {"used": false, "change": grant_change, "why": "too faint" if s < threshold else "already braced"}
			patch.append({"op": "set", "path": "braced", "value": true})
			return {"used": true, "text": "braces you", "line": "you are braced while you cast it"}
		"through":
			var part7: String = _payload_part(ab)
			if part7 == "" or s < threshold or bool((get_path_value(ab, part7) as Dictionary).get("through", false)):
				return {"used": false, "change": grant_change, "why": "nothing it hits" if part7 == "" else "too faint" if s < threshold else "already goes through"}
			patch.append({"op": "set", "path": part7 + ".through", "value": true})
			return {"used": true, "text": "goes through guards", "line": "ignores front block and shields"}
		"bonus":
			var part5: String = _payload_part(ab)
			if part5 == "" or not _part_deals_damage(ab, part5):
				return {"used": false, "change": grant_change, "why": "it deals no damage on a hit"}
			var frac: float = float(op["value"]) * s
			var st: String = str(op["status"])
			patch.append({"op": "add", "path": "%s.bonus_vs.%s" % [part5, st], "value": frac})
			var t2: String = "+%d%% damage to %s targets" % [int(round(frac * 100.0)), _status_label(st)]
			return {"used": true, "text": t2, "line": t2}
	return {"used": false, "change": 0.0, "why": "unknown effect"}


func _has_status(ab: Dictionary, part: String, id: String) -> bool:
	var p: Dictionary = get_path_value(ab, part)
	if str(p.get("status", "")) == id:
		return true
	for s: Variant in p.get("statuses", []):
		if str((s as Dictionary).get("id", "")) == id:
			return true
	return false


## Scale the part of the skill the anchor's op names by the anchor's side factor f. Returns a line
## for the screen, or "" if the skill has no such part.
func _scale_signature(ab: Dictionary, op: Dictionary, f: float, threshold: float, groups: Dictionary, patch: Array) -> String:
	var kind: String = str(op["op"])
	match kind:
		"mul":
			var g: String = str(op["group"])
			var m: float = float(op["value"])
			if _group_fields(ab, g).is_empty() or m == 0.0:
				return ""
			var ratio: float = (1.0 + (m - 1.0) * f) / m
			groups[g] = float(groups.get(g, 1.0)) * ratio
			return "its own %s x%.2f" % [_group_word(g), ratio]
		"shove", "pull", "marks":
			var paths: Array[String] = []
			for part: String in _payload_parts(ab):
				if typeof(get_path_value(ab, part + "." + kind)) in [TYPE_FLOAT, TYPE_INT]:
					paths.append(part + "." + kind)
			if typeof(ab.get(kind)) in [TYPE_FLOAT, TYPE_INT]:
				paths.append(kind)
			if paths.is_empty():
				return ""
			for path: String in paths:
				if kind == "marks":
					patch.append({"op": "mul_round", "path": path, "value": f})
				else:
					patch.append({"op": "mul", "path": path, "value": f})
			if f <= 0.0:
				return "loses its %s" % kind
			return "its own %s x%.2f" % [kind, f]
		"jumps":
			if not ab.has("jumps"):
				return ""
			patch.append({"op": "mul_round", "path": "jumps", "value": f})
			return "its own jumps x%.2f" % f
		"status", "interrupts":
			var lost := false
			for part: String in _payload_parts(ab):
				var p: Dictionary = get_path_value(ab, part)
				if kind == "status" and str(p.get("status", "")) == str(op["id"]) and f < threshold:
					patch.append({"op": "erase", "path": part + ".status"})
					patch.append({"op": "erase", "path": part + ".stacks"})
					lost = true
				elif kind == "interrupts" and bool(p.get("interrupts", false)) and f < threshold:
					patch.append({"op": "erase", "path": part + ".interrupts"})
					lost = true
			if lost:
				return "loses its %s" % (_status_label(str(op["id"])) if kind == "status" else "interrupt")
			return ""
		"braced", "pierce":
			if bool(ab.get(kind, false)) and f < threshold:
				patch.append({"op": "set", "path": kind, "value": false})
				return "loses its %s" % ("brace" if kind == "braced" else "pierce")
			return ""
		"bonus":
			if ab.has("bonus_damage") and str(ab.get("bonus_vs_status", "")) == str(op["status"]):
				patch.append({"op": "mul", "path": "bonus_damage", "value": f})
				return "its own bonus x%.2f" % f
			return ""
	return ""


# --- words -------------------------------------------------------------------------------

func _group_word(g: String) -> String:
	return str((params.get("group_words", {}) as Dictionary).get(g, g))


func _status_label(id: String) -> String:
	return str(GameData.status(id).get("label", id.capitalize()))


## One op in plain words at strength s ("+30% speed", "applies Soaked", "shoves 1.5 m").
func op_words(op: Dictionary, s: float) -> String:
	match str(op["op"]):
		"mul":
			var m: float = 1.0 + (float(op["value"]) - 1.0) * s
			return "%s%d%% %s" % ["+" if m >= 1.0 else "-", int(round(absf(m - 1.0) * 100.0)), _group_word(str(op["group"]))]
		"status":
			return "applies %s" % _status_label(str(op["id"]))
		"shove":
			return "shoves %.1f m" % (float(op["value"]) * s)
		"pull":
			return "pulls %.1f m" % (float(op["value"]) * s)
		"marks":
			return "+%s Live mark" % _num(float(op["value"]) * s)
		"jumps":
			return "+%s jump" % _num(float(op["value"]) * s)
		"pierce":
			return "pierces"
		"interrupts":
			return "interrupts"
		"braced":
			return "braces you"
		"through":
			return "goes through guards"
		"bonus":
			return "+%d%% damage to %s" % [int(round(float(op["value"]) * s * 100.0)), _status_label(str(op["status"]))]
	return str(op["op"])


func _num(x: float) -> String:
	return str(int(x)) if is_equal_approx(x, roundf(x)) else "%.1f" % x
