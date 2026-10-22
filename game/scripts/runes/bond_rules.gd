class_name BondRules
extends RuneRules
## Rule set "bond_v1": rune words as chemistry (Brent 2026-10-22, design/14 section 7).
##   - single bonds only; a rune makes at most its valence in bonds;
##   - the word is closed when every rune's bonds equal its valence (and, if the data says so, every
##     rune is joined to the anchor);
##   - the electronegativity difference sets a bond's kind (params.bond_kinds: even, polar, ionic);
##   - two base runes of different affinities bond only if the cosine of their affinities' five-axis
##     positions is at least params.refuse_below; below params.weaken_below the bond is weakened
##     (shown, no numbers yet); universal runes have no position and bond with anything;
##   - capacity comes from the skill's level: capacity_base + capacity_per_level x stage.
## No numbers here: they are this rule set's params in runes.json, and each rune's valence and
## electronegativity are in its row. Bond strength, "unstable", flaws and reactions are not decided.


func legend() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k: Dictionary in params.get("bond_kinds", []):
		out.append({"colour": str(k["kind"]), "label": "%s bond" % str(k["kind"])})
	out.append({"colour": "weakened", "label": "weakened: the affinities lean apart"})
	return out


func capacity(ctx: RuneContext) -> int:
	return int(params.get("capacity_base", 0)) + int(params.get("capacity_per_level", 0)) * maxi(0, ctx.stage)


func used(word: Dictionary, _ctx: RuneContext) -> int:
	var n: int = RuneWord.size(word)
	return n if bool(params.get("anchor_counts", true)) else maxi(0, n - 1)


# --- the chemistry -------------------------------------------------------------------------

static func valence(rune_id: String) -> int:
	return int(GameData.rune(rune_id).get("valence", 0))


static func electronegativity(rune_id: String) -> float:
	return float(GameData.rune(rune_id).get("electronegativity", 0.0))


## The cosine between two affinities' positions; 1.0 if either is unplaced (universal) or the same.
static func affinity_alignment(aff_a: String, aff_b: String) -> float:
	if aff_a == "" or aff_b == "" or aff_a == aff_b:
		return 1.0
	var pos: Dictionary = GameData.runes.get("affinity_positions", {})
	if not pos.has(aff_a) or not pos.has(aff_b):
		return 1.0
	var pa: Array = pos[aff_a]
	var pb: Array = pos[aff_b]
	var dot := 0.0
	var na := 0.0
	var nb := 0.0
	for k: int in mini(pa.size(), pb.size()):
		dot += float(pa[k]) * float(pb[k])
		na += float(pa[k]) * float(pa[k])
		nb += float(pb[k]) * float(pb[k])
	return 1.0 if na <= 0.0 or nb <= 0.0 else dot / sqrt(na * nb)


static func alignment(rune_a: String, rune_b: String) -> float:
	return affinity_alignment(str(GameData.rune(rune_a).get("affinity", "")), str(GameData.rune(rune_b).get("affinity", "")))


## "refused", "weakened" or "ok" for two runes' affinities.
func alignment_state(rune_a: String, rune_b: String) -> String:
	var c: float = alignment(rune_a, rune_b)
	if c < float(params.get("refuse_below", -INF)):
		return "refused"
	if c < float(params.get("weaken_below", -INF)):
		return "weakened"
	return "ok"


## The kind of bond two runes make: the bond kind with the highest "from" that the difference in
## electronegativity reaches.
func bond_kind(rune_a: String, rune_b: String) -> String:
	var diff: float = absf(electronegativity(rune_a) - electronegativity(rune_b))
	var kind := ""
	var best := -INF
	for k: Dictionary in params.get("bond_kinds", []):
		var from: float = float(k.get("from", 0.0))
		if diff + 0.000001 >= from and from > best:        # a hair of tolerance: 3.7 - 2.0 reaches 1.7
			best = from
			kind = str(k.get("kind", ""))
	return kind


func _pair(rune_a: String, rune_b: String) -> Dictionary:
	if alignment_state(rune_a, rune_b) == "refused":
		return no("refused", "%s and %s refuse each other: %s and %s pull opposite ways." % [
			str(GameData.rune(rune_a).get("name", rune_a)), str(GameData.rune(rune_b).get("name", rune_b)),
			str(GameData.rune(rune_a).get("affinity", "")).capitalize(), str(GameData.rune(rune_b).get("affinity", "")).capitalize()])
	return ok()


func _full(word: Dictionary, i: int) -> Dictionary:
	var rid: String = RuneWord.node_id(word, i)
	if RuneWord.degree(word, i) >= valence(rid):
		return no("valence_full", "%s is full: valence %d, every bond taken." % [rune_name(word, i), valence(rid)])
	return ok()


# --- RuneRules ----------------------------------------------------------------------------

func _can_add(word: Dictionary, rune_id: String, _ctx: RuneContext, to_node: int) -> Dictionary:
	if not bool(params.get("allow_repeats", true)) and RuneWord.nodes(word).has(rune_id):
		return no("repeat", "%s is already in the word." % str(GameData.rune(rune_id).get("name", rune_id)))
	if to_node >= 0:
		var full: Dictionary = _full(word, to_node)
		if not bool(full["ok"]):
			return full
		return _pair(RuneWord.node_id(word, to_node), rune_id)
	return ok()


func _can_link(word: Dictionary, a: int, b: int, _ctx: RuneContext) -> Dictionary:
	for i: int in [a, b]:
		var full: Dictionary = _full(word, i)
		if not bool(full["ok"]):
			return full
	return _pair(RuneWord.node_id(word, a), RuneWord.node_id(word, b))


func _describe_link(word: Dictionary, a: int, b: int, _ctx: RuneContext) -> Dictionary:
	var ra: String = RuneWord.node_id(word, a)
	var rb: String = RuneWord.node_id(word, b)
	var kind: String = bond_kind(ra, rb)
	var align: String = alignment_state(ra, rb)
	var d: Dictionary = {"kind": kind, "label": "%s bond" % kind, "colour": kind, "flags": [], "text": "%s - %s: %s bond" % [rune_name(word, a), rune_name(word, b), kind]}
	if align == "weakened":
		(d["flags"] as Array).append("weakened")
		d["text"] = str(d["text"]) + ", weakened (their affinities lean apart)"
	elif align == "refused":
		# only a word made under other rules can hold this
		(d["flags"] as Array).append("refused")
		d["colour"] = "problem"
		d["text"] = str(d["text"]) + " - but these affinities refuse each other"
	return d


func _describe_node(word: Dictionary, i: int, _ctx: RuneContext) -> Dictionary:
	var rid: String = RuneWord.node_id(word, i)
	var d: Dictionary = {"sockets": valence(rid), "used": RuneWord.degree(word, i), "badges": []}
	if bool(GameData.rune(rid).get("placeholder", false)):
		(d["badges"] as Array).append("placeholder")
	if RuneWord.degree(word, i) > valence(rid):
		(d["badges"] as Array).append("over")
	return d


func _describe_rune(rune_id: String, _ctx: RuneContext) -> Dictionary:
	var rune: Dictionary = GameData.rune(rune_id)
	var v: int = valence(rune_id)
	var lines: Array = ["%s%d bond%s, electronegativity %.2f" % [
		(str(rune["role"]).capitalize() + ": ") if rune.has("role") else "", v, "" if v == 1 else "s", electronegativity(rune_id)]]
	if bool(rune.get("placeholder", false)):
		lines.append("Placeholder numbers: universal runes have no role yet.")
	return {"sockets": v, "lines": lines}


func _word_state(word: Dictionary, _ctx: RuneContext) -> Dictionary:
	var problems: Array = []
	var lines: Array = []
	var open := 0
	for i: int in RuneWord.size(word):
		var rid: String = RuneWord.node_id(word, i)
		var over: int = RuneWord.degree(word, i) - valence(rid)
		if over > 0:
			problems.append("%s has %d bonds; its valence is %d." % [rune_name(word, i), RuneWord.degree(word, i), valence(rid)])
		else:
			open -= over
	for l: Dictionary in RuneWord.links(word):
		if alignment_state(RuneWord.node_id(word, int(l["a"])), RuneWord.node_id(word, int(l["b"]))) == "refused":
			problems.append("%s and %s are bonded, but their affinities refuse each other." % [rune_name(word, int(l["a"])), rune_name(word, int(l["b"]))])
	if not bool(params.get("allow_repeats", true)):
		var seen: Dictionary = {}
		for rid: Variant in RuneWord.nodes(word):
			if seen.has(rid):
				problems.append("%s is in the word twice." % str(GameData.rune(str(rid)).get("name", rid)))
			seen[rid] = true
	var joined: bool = RuneWord.is_joined(word)
	var needs_joined: bool = bool(params.get("closed_needs_connected", true))
	var closed: bool = problems.is_empty() and open == 0 and (joined or not needs_joined)
	if open > 0:
		lines.append("%d open bond%s to fill." % [open, "" if open == 1 else "s"])
	if not joined:
		lines.append("Not every rune is joined to the anchor%s." % (" - a closed word is one piece" if needs_joined else ""))
	return {"closed": closed, "label": "closed - it could be written" if closed else "open - not a word yet", "problems": problems, "lines": lines}
