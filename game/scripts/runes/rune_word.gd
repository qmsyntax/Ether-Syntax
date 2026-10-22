class_name RuneWord
extends RefCounted
## The data model of a rune word, with no rules in it (design/14 section 7). A word is a graph:
##
##   {"nodes": ["WAT-1a", "UNI-05a", ...],                 # rune ids; nodes[0] is the skill's anchor
##    "links": [{"a": 0, "b": 1}, {"a": 1, "b": 2, "data": {...}}],
##    "made_under": "bond_v1"}                             # the rule set it was built under (for reports)
##
## A link joins two node indices (a < b), at most one per pair; its optional "data" is whatever the
## rule set that made it chose to keep (nothing, for bond_v1). This is what is saved on an ability
## state ("word"), so any rule set can read any word: whether a word is allowed, closed or broken
## is asked of the rules (RuneRules), never stored. Everything here is plain graph bookkeeping.


static func make(anchor_id: String, rule_set: String = "") -> Dictionary:
	return {"nodes": [anchor_id] if anchor_id != "" else [], "links": [], "made_under": rule_set}


static func nodes(word: Dictionary) -> Array:
	return word.get("nodes", [])


static func links(word: Dictionary) -> Array:
	return word.get("links", [])


static func size(word: Dictionary) -> int:
	return nodes(word).size()


static func node_id(word: Dictionary, i: int) -> String:
	var ns: Array = nodes(word)
	return str(ns[i]) if i >= 0 and i < ns.size() else ""


static func anchor(word: Dictionary) -> String:
	return node_id(word, 0)


static func has_node(word: Dictionary, i: int) -> bool:
	return i >= 0 and i < size(word)


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


## Append a node; returns its index.
static func add_node(word: Dictionary, rune_id: String) -> int:
	if not word.has("nodes"):
		word["nodes"] = []
	(word["nodes"] as Array).append(rune_id)
	return (word["nodes"] as Array).size() - 1


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
	(word["nodes"] as Array).remove_at(i)
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


## A word read back from a save, whatever rule set made it: JSON's floats made ints again, links
## to nodes that are not there, self-links and repeated pairs dropped, and runes the data no longer
## knows taken out. It is NOT checked against any rules - a word that breaks the current rules
## loads as it is and the rules report the problems (RuneRules.word_state). A word whose first
## node is not this skill's anchor starts over. Returns a fresh dictionary.
static func normalize(saved: Variant, anchor_id: String) -> Dictionary:
	if typeof(saved) != TYPE_DICTIONARY:
		return make(anchor_id)
	var src: Dictionary = saved
	var src_nodes: Array = src.get("nodes", [])
	if anchor_id == "" or src_nodes.is_empty() or str(src_nodes[0]) != anchor_id:
		return make(anchor_id, str(src.get("made_under", "")))
	var index_map: Dictionary = {}
	var out: Dictionary = make("", str(src.get("made_under", "")))
	for i: int in src_nodes.size():
		var id: String = str(src_nodes[i])
		if GameData.rune(id).is_empty():
			continue
		index_map[i] = add_node(out, id)
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
	return out
