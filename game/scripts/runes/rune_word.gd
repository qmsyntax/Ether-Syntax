class_name RuneWord
extends RefCounted
## The data model of a rune word, with no rules in it (design/14 sections 7-8). A word is a graph
## laid out on concentric rings round its skill:
##
##   {"nodes": ["WAT-1a", "UNI-05a", ...],                 # rune ids; nodes[0] is the skill's anchor
##    "rings": [0, 1, 2, ...],                             # each node's ring; the anchor is ring 0
##    "links": [{"a": 0, "b": 1}, {"a": 1, "b": 2, "data": {...}}],
##    "made_under": "bond_v2",                             # the rule set it was built under (for reports)
##    "sealed": 2,                                         # rings sealed in (0 / absent: no seal yet)
##    "places": [-1, 0, 2, ...]}                           # where each rune sits on its ring (optional)
##
## "places" is layout only (2026-10-23): the index of each rune's place on its ring, so a rune stays
## where it was set when bonds change (-1: not chosen - layout_places picks). No rule reads it.
##
## Brent 2026-10-23: the word is concentric circles, one per level, stacking outward; each binding
## seals a ring. A word is sealed when its skill uses it (sealed > 0); a seal is drafted on a copy
## (Player.open_seal) and only that copy is changed. Older words (bond_v1) kept "locked": true and
## had no rings - their rings are read as each rune's distance in bonds from the anchor.
##
## A link joins two node indices (a < b), at most one per pair; its optional "data" is whatever the
## rule set that made it chose to keep. This is what is saved on an ability state ("word"), so any
## rule set can read any word: whether a word is allowed, closed or broken is asked of the rules
## (RuneRules), never stored. Everything here is plain graph bookkeeping.


static func make(anchor_id: String, rule_set: String = "") -> Dictionary:
	return {"nodes": [anchor_id] if anchor_id != "" else [], "rings": [0] if anchor_id != "" else [], "links": [], "made_under": rule_set}


static func nodes(word: Dictionary) -> Array:
	return word.get("nodes", [])


static func links(word: Dictionary) -> Array:
	return word.get("links", [])


static func size(word: Dictionary) -> int:
	return nodes(word).size()


static func node_id(word: Dictionary, i: int) -> String:
	var ns: Array = nodes(word)
	return str(ns[i]) if i >= 0 and i < ns.size() else ""


## How many rings are sealed in (0: none - the skill does not use the word).
static func sealed(word: Dictionary) -> int:
	return int(word.get("sealed", 0))


static func is_sealed(word: Dictionary) -> bool:
	return sealed(word) > 0


## A word its skill uses and that cannot be changed: sealed (or, from before seals, locked).
static func is_locked(word: Dictionary) -> bool:
	return bool(word.get("locked", false)) or is_sealed(word)


static func anchor(word: Dictionary) -> String:
	return node_id(word, 0)


static func has_node(word: Dictionary, i: int) -> bool:
	return i >= 0 and i < size(word)


# --- rings ----------------------------------------------------------------------------------

## Every node's ring: the stored rings, or - for a word without them (made before rings, or built
## raw in a test) - each node's distance in bonds from the anchor (1 for a node joined to nothing).
static func rings(word: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var rs: Array = word.get("rings", [])
	var n: int = size(word)
	if rs.size() == n:
		for r: Variant in rs:
			out.append(int(r))
		return out
	var d: Array[int] = distances(word)
	for i: int in n:
		out.append(0 if i == 0 else (d[i] if d[i] > 0 else 1))
	return out


static func ring(word: Dictionary, i: int) -> int:
	var rs: Array[int] = rings(word)
	return rs[i] if i >= 0 and i < rs.size() else -1


## The nodes on ring k, in index order.
static func ring_nodes(word: Dictionary, k: int) -> Array[int]:
	var out: Array[int] = []
	var rs: Array[int] = rings(word)
	for i: int in rs.size():
		if rs[i] == k:
			out.append(i)
	return out


## The outermost ring holding a rune (0 if only the anchor).
static func outer_ring(word: Dictionary) -> int:
	var m := 0
	for r: int in rings(word):
		m = maxi(m, r)
	return m


## Put node i on ring k (rings are made explicit first if the word had none).
static func set_ring(word: Dictionary, i: int, k: int) -> void:
	if not has_node(word, i):
		return
	word["rings"] = rings(word)
	(word["rings"] as Array)[i] = k


## Bonds from the anchor to each node (-1 = not joined to it).
static func distances(word: Dictionary) -> Array[int]:
	var n: int = size(word)
	var dist: Array[int] = []
	for i: int in n:
		dist.append(-1)
	if n == 0:
		return dist
	dist[0] = 0
	var queue: Array[int] = [0]
	while not queue.is_empty():
		var at: int = queue.pop_front()
		for k: int in neighbours(word, at):
			if dist[k] < 0:
				dist[k] = dist[at] + 1
				queue.append(k)
	return dist


# --- links ------------------------------------------------------------------------------

## The link between a and b (either order), or {} if there is none.
static func link_between(word: Dictionary, a: int, b: int) -> Dictionary:
	for l: Dictionary in links(word):
		if (int(l["a"]) == a and int(l["b"]) == b) or (int(l["a"]) == b and int(l["b"]) == a):
			return l
	return {}


static func linked(word: Dictionary, a: int, b: int) -> bool:
	return not link_between(word, a, b).is_empty()


## How many links node i takes part in.
static func degree(word: Dictionary, i: int) -> int:
	var n := 0
	for l: Dictionary in links(word):
		if int(l["a"]) == i or int(l["b"]) == i:
			n += 1
	return n


## The nodes linked to node i.
static func neighbours(word: Dictionary, i: int) -> Array[int]:
	var out: Array[int] = []
	for l: Dictionary in links(word):
		if int(l["a"]) == i:
			out.append(int(l["b"]))
		elif int(l["b"]) == i:
			out.append(int(l["a"]))
	return out


## Every node is joined, through links, to the anchor.
static func is_joined(word: Dictionary) -> bool:
	var n: int = size(word)
	if n == 0:
		return false
	var seen: Dictionary = {0: true}
	var todo: Array[int] = [0]
	while not todo.is_empty():
		var at: int = todo.pop_back()
		for other: int in neighbours(word, at):
			if not seen.has(other):
				seen[other] = true
				todo.append(other)
	return seen.size() == n


## Append a node on ring `k` (-1: ring 1, or for a word without stored rings, none stored);
## returns its index.
static func add_node(word: Dictionary, rune_id: String, k: int = -1) -> int:
	if not word.has("nodes"):
		word["nodes"] = []
	var had_rings: bool = (word.get("rings", []) as Array).size() == size(word) and word.has("rings")
	var had_places: bool = word.has("places") and (word["places"] as Array).size() == size(word)
	if k >= 0 and not had_rings:
		word["rings"] = rings(word)
		had_rings = true
	(word["nodes"] as Array).append(rune_id)
	if had_rings:
		(word["rings"] as Array).append(k if k >= 0 else (0 if size(word) == 1 else 1))
	if had_places:
		(word["places"] as Array).append(-1)
	else:
		word.erase("places")
	return (word["nodes"] as Array).size() - 1


# --- places (layout only) ---------------------------------------------------------------------

## Each node's stored place on its ring (-1: none stored).
static func places(word: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var ps: Array = word.get("places", [])
	var n: int = size(word)
	for i: int in n:
		out.append(int(ps[i]) if ps.size() == n else -1)
	return out


static func set_place(word: Dictionary, i: int, j: int) -> void:
	if not has_node(word, i):
		return
	word["places"] = places(word)
	(word["places"] as Array)[i] = j


## The angle of place j of `count` on ring k (the first at the top; even rings turned half a step,
## so neighbouring rings' places do not line up).
static func place_angle(k: int, j: int, count: int) -> float:
	var c: int = maxi(1, count)
	return -PI / 2.0 + (PI / float(c) if k % 2 == 0 else 0.0) + TAU * float(j) / float(c)


## Every node's place, given how many places each ring has (`counts` {ring: n}): a stored place is
## kept when it is on the ring and free; the others are chosen - inner rings first, the rune with the
## most placed partners next, at the free place nearest the mean angle of its partners already
## placed (the first free place when it has none). The anchor (ring 0) is -1.
static func layout_places(word: Dictionary, counts: Dictionary) -> Array[int]:
	var n: int = size(word)
	var rs: Array[int] = rings(word)
	var stored: Array[int] = places(word)
	var out: Array[int] = []
	var angle: Array[float] = []
	var placed: Array[bool] = []
	for i: int in n:
		out.append(-1)
		angle.append(0.0)
		placed.append(i == 0)
	var ks: Array = counts.keys()
	ks.sort()
	for kv: Variant in ks:
		var k: int = int(kv)
		var count: int = int(counts[kv])
		var taken: Array[int] = []
		for j: int in count:
			taken.append(-1)
		var todo: Array[int] = ring_nodes(word, k)
		for i: int in todo.duplicate():
			var j0: int = stored[i]
			if j0 >= 0 and j0 < count and taken[j0] < 0:
				taken[j0] = i
				out[i] = j0
				angle[i] = place_angle(k, j0, count)
				placed[i] = true
				todo.erase(i)
		while not todo.is_empty():
			var best_i := -1
			var best_n := -1
			for i: int in todo:
				var m := 0
				for p: int in neighbours(word, i):
					if placed[p]:
						m += 1
				if m > best_n:
					best_n = m
					best_i = i
			todo.erase(best_i)
			var sx := 0.0
			var sy := 0.0
			for p: int in neighbours(word, best_i):
				if placed[p] and p != 0:
					sx += cos(angle[p])
					sy += sin(angle[p])
			var free_first := -1
			for j: int in count:
				if taken[j] < 0:
					free_first = j
					break
			if free_first < 0:
				continue
			var pick: int = free_first
			if absf(sx) + absf(sy) > 0.0001:
				var want: float = atan2(sy, sx)
				var pick_d := INF
				for j: int in count:
					if taken[j] >= 0:
						continue
					var d: float = absf(angle_difference(want, place_angle(k, j, count)))
					if d < pick_d - 0.0001:
						pick_d = d
						pick = j
			taken[pick] = best_i
			out[best_i] = pick
			angle[best_i] = place_angle(k, pick, count)
			placed[best_i] = true
	return out


## Add a link (no checks: ask the rules first).
static func add_link(word: Dictionary, a: int, b: int, data: Dictionary = {}) -> void:
	if not word.has("links"):
		word["links"] = []
	var l: Dictionary = {"a": mini(a, b), "b": maxi(a, b)}
	if not data.is_empty():
		l["data"] = data.duplicate(true)
	(word["links"] as Array).append(l)


static func remove_link(word: Dictionary, a: int, b: int) -> bool:
	var ls: Array = links(word)
	for k: int in ls.size():
		var l: Dictionary = ls[k]
		if (int(l["a"]) == a and int(l["b"]) == b) or (int(l["a"]) == b and int(l["b"]) == a):
			ls.remove_at(k)
			return true
	return false


## Remove node i and its links; the indices above it move down by one.
static func remove_node(word: Dictionary, i: int) -> void:
	if not has_node(word, i):
		return
	var had_rings: bool = (word.get("rings", []) as Array).size() == size(word)
	var had_places: bool = (word.get("places", []) as Array).size() == size(word)
	(word["nodes"] as Array).remove_at(i)
	if had_rings:
		(word["rings"] as Array).remove_at(i)
	if had_places:
		(word["places"] as Array).remove_at(i)
	else:
		word.erase("places")
	var kept: Array = []
	for l: Dictionary in links(word):
		var a: int = int(l["a"])
		var b: int = int(l["b"])
		if a == i or b == i:
			continue
		var moved: Dictionary = l.duplicate(true)
		moved["a"] = a - (1 if a > i else 0)
		moved["b"] = b - (1 if b > i else 0)
		kept.append(moved)
	word["links"] = kept


## The word's shape as text, to tell whether two words are the same word (runes, rings, links).
static func shape_key(word: Dictionary) -> String:
	var ls: Array = []
	for l: Dictionary in links(word):
		ls.append([int(l["a"]), int(l["b"])])
	return "%s|%s|%s" % [str(nodes(word)), str(rings(word)), str(ls)]


## A word read back from a save, whatever rule set made it: JSON's floats made ints again, links
## to nodes that are not there, self-links and repeated pairs dropped, and runes the data no longer
## knows taken out. It is NOT checked against any rules - a word that breaks the current rules
## loads as it is and the rules report the problems (RuneRules.word_state). A word whose first
## node is not this skill's anchor starts over. A word without rings gets them from its bonds; a
## word locked before seals existed comes back sealed through its outer ring (the player then caps
## that at the skill's stage). Returns a fresh dictionary.
static func normalize(saved: Variant, anchor_id: String) -> Dictionary:
	if typeof(saved) != TYPE_DICTIONARY:
		return make(anchor_id)
	var src: Dictionary = saved
	var src_nodes: Array = src.get("nodes", [])
	if anchor_id == "" or src_nodes.is_empty() or str(src_nodes[0]) != anchor_id:
		return make(anchor_id, str(src.get("made_under", "")))
	var src_rings: Array = src.get("rings", [])
	var stored: bool = src_rings.size() == src_nodes.size()
	var src_places: Array = src.get("places", [])
	var kept_places: Array = []
	var index_map: Dictionary = {}
	var out: Dictionary = make("", str(src.get("made_under", "")))
	out.erase("rings")
	var kept_rings: Array = []
	for i: int in src_nodes.size():
		var id: String = str(src_nodes[i])
		if GameData.rune(id).is_empty():
			continue
		index_map[i] = add_node(out, id)
		var r: int = 0
		if stored and i > 0:
			r = maxi(1, int(src_rings[i]))
		kept_rings.append(r)
		kept_places.append(int(src_places[i]) if src_places.size() == src_nodes.size() and i > 0 else -1)
	for l: Variant in src.get("links", []):
		if typeof(l) != TYPE_DICTIONARY or not (l as Dictionary).has("a") or not (l as Dictionary).has("b"):
			continue
		var a_src: int = int((l as Dictionary)["a"])
		var b_src: int = int((l as Dictionary)["b"])
		if not index_map.has(a_src) or not index_map.has(b_src):
			continue
		var a: int = int(index_map[a_src])
		var b: int = int(index_map[b_src])
		if a == b or linked(out, a, b):
			continue
		var data: Variant = (l as Dictionary).get("data", {})
		add_link(out, a, b, data if typeof(data) == TYPE_DICTIONARY else {})
	out["rings"] = kept_rings if stored else rings(out)
	if src_places.size() == src_nodes.size():
		out["places"] = kept_places
	if int(src.get("sealed", 0)) > 0:
		out["sealed"] = int(src["sealed"])
	elif bool(src.get("locked", false)):
		out["sealed"] = maxi(1, outer_ring(out))
	if bool(src.get("free_edit", false)):
		out["free_edit"] = true
	return out
