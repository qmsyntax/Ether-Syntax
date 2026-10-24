class_name FullRings
extends RefCounted
## Test helpers for the full-ring level lock (Brent 2026-10-24, design/14 section 12: "Every slot
## should be filled to be fully formed ... Its all or nothing at each level"). Tests only - the game
## never builds a word for the player.
##
##   pattern(anchor, rings, pool, rules)  a CLOSED word with every place of rings 1..`rings` filled,
##                                        built to a plan from runes of `pool` (repeats allowed): ring 1
##                                        bonded to the skill in whatever small shape the valences in
##                                        the pool allow, each later ring a closed ring (or a chain, if
##                                        the pool has no three-bond rune) joined to the ring inside it
##                                        by one bond. {} if the pool cannot make it.
##   solve(anchor, rings, pool, rules)    the same question answered exhaustively, for small words
##                                        (rings 1-2): every choice of runes for every place, every set
##                                        of bonds. {} if no closed word with full rings exists.
##   replay(p, index, word)               set `word` into player `p`'s open draft of ability `index`
##                                        through the real word_add / word_link, ring by ring from the
##                                        skill outward. Returns every answer.
## A word here is a plain RuneWord dictionary (nodes, rings, links).


## Runes of `pool` the skill's own rune does not refuse, grouped by valence: {valence: [ids]}.
static func _by_valence(anchor: String, pool: Array, rules: RingRules) -> Dictionary:
	var out: Dictionary = {}
	for rid: Variant in pool:
		var id: String = str(rid)
		if rules.alignment_state(anchor, id) == "refused":
			continue
		var v: int = BondRules.valence(id)
		if v <= 0:
			continue
		if not out.has(v):
			out[v] = []
		(out[v] as Array).append(id)
	return out


## Within one plan every rune must bond with every other one it might meet: keep, of each valence, the
## runes that agree with the first rune of the plan's affinity (the anchor's), and universal ones.
static func _aligned(anchor: String, by_v: Dictionary, rules: RingRules) -> Dictionary:
	var aff: String = str(GameData.rune(anchor).get("affinity", ""))
	var out: Dictionary = {}
	for v: Variant in by_v:
		var keep: Array = []
		for id: Variant in by_v[v]:
			var a2: String = str(GameData.rune(str(id)).get("affinity", ""))
			if a2 == "" or a2 == aff:
				keep.append(id)
		if not keep.is_empty():
			out[v] = keep
	return out


static func _pick(by_v: Dictionary, v: int, n: int) -> String:
	var list: Array = by_v[v]
	return str(list[n % list.size()])


## A closed word, every place of rings 1..`rings` filled, from `pool`. {} if the plan cannot be made.
static func pattern(anchor: String, rings: int, pool: Array, rules: RingRules) -> Dictionary:
	var by_v: Dictionary = _aligned(anchor, _by_valence(anchor, pool, rules), rules)
	var w: Dictionary = RuneWord.make(anchor, rules.id)
	var a: int = rules.anchor_needs(w)
	var n1: int = rules.ring_capacity(1)
	if n1 != 3:
		return {}             # the plan below is for a ring 1 of three places
	var pairs: Array = [[0, 1], [1, 2], [2, 0]]
	var subsets: Array = []
	for m: int in 8:
		var s: Array = []
		for i: int in 3:
			if m & (1 << i):
				s.append(i)
		if s.size() == a:
			subsets.append(s)
	var plan: Dictionary = {}
	for mask: int in 8:
		for sub: Array in subsets:
			for out_node: int in ([0, 1, 2] if rings > 1 else [-1]):
				var deg: Array[int] = [0, 0, 0]
				var adj: Dictionary = {0: [], 1: [], 2: []}
				for e: int in 3:
					if mask & (1 << e):
						var pa: Array = pairs[e]
						deg[int(pa[0])] += 1
						deg[int(pa[1])] += 1
						(adj[int(pa[0])] as Array).append(int(pa[1]))
						(adj[int(pa[1])] as Array).append(int(pa[0]))
				for i2: Variant in sub:
					deg[int(i2)] += 1
				if out_node >= 0:
					deg[out_node] += 1
				if not deg.all(func(d: int) -> bool: return by_v.has(d)):
					continue
				# every ring-1 rune joined to the skill through the anchor's bonds and ring 1's own
				var seen: Dictionary = {}
				var todo: Array = sub.duplicate()
				for s0: Variant in sub:
					seen[int(s0)] = true
				while not todo.is_empty():
					var at: int = int(todo.pop_back())
					for nb: Variant in adj[at]:
						if not seen.has(int(nb)):
							seen[int(nb)] = true
							todo.append(int(nb))
				if seen.size() < 3:
					continue
				plan = {"mask": mask, "sub": sub, "out": out_node, "deg": deg}
				break
			if not plan.is_empty():
				break
		if not plan.is_empty():
			break
	if plan.is_empty():
		return {}
	var count := 0
	var r1: Array[int] = []
	for i3: int in 3:
		r1.append(RuneWord.add_node(w, _pick(by_v, int((plan["deg"] as Array)[i3]), count), 1))
		count += 1
	for e2: int in 3:
		if int(plan["mask"]) & (1 << e2):
			RuneWord.add_link(w, r1[int(pairs[e2][0])], r1[int(pairs[e2][1])])
	for s2: Variant in plan["sub"]:
		RuneWord.add_link(w, 0, r1[int(s2)])
	var out_from: int = r1[int(plan["out"])] if int(plan["out"]) >= 0 else -1
	# rings 2..: a closed ring (needs three-bond runes) or a chain (twos, and a one at the far end)
	for k: int in range(2, rings + 1):
		var n: int = rules.ring_capacity(k)
		var last: bool = k == rings
		var ids: Array[int] = []
		var cycle: bool = by_v.has(3) and by_v.has(2)
		if cycle:
			for j: int in n:
				var dj: int = 3 if j == 0 or (j == 2 and not last) else 2
				ids.append(RuneWord.add_node(w, _pick(by_v, dj, count), k))
				count += 1
			for j2: int in n:
				RuneWord.add_link(w, ids[j2], ids[(j2 + 1) % n])
			RuneWord.add_link(w, out_from, ids[0])
			out_from = ids[2] if not last else -1
		else:
			if not by_v.has(2) or (last and not by_v.has(1)):
				return {}
			for j3: int in n:
				var dj2: int = 1 if last and j3 == n - 1 else 2
				ids.append(RuneWord.add_node(w, _pick(by_v, dj2, count), k))
				count += 1
			for j4: int in n - 1:
				RuneWord.add_link(w, ids[j4], ids[j4 + 1])
			RuneWord.add_link(w, out_from, ids[0])
			out_from = ids[n - 1] if not last else -1
	return w


# --- the exhaustive search (small words) -------------------------------------------------------

## Combinations with repetition of `n` items out of `k` kinds: [[0,0,1], ...].
static func _multisets(k: int, n: int, from: int = 0) -> Array:
	if n == 0:
		return [[]]
	var out: Array = []
	for i: int in range(from, k):
		for rest: Array in _multisets(k, n - 1, i):
			out.append([i] + rest)
	return out


## Every closed word with full rings 1..`rings` from `pool` - the first one found, or {}. Runes that
## differ only in name (same valence, same affinity) are one kind here; repeats are allowed when the
## rules allow them (params.allow_repeats).
static func solve(anchor: String, rings: int, pool: Array, rules: RingRules) -> Dictionary:
	var kinds: Array[String] = []
	var seen: Dictionary = {}
	for rid: Variant in pool:
		var id: String = str(rid)
		var key: String = "%d|%s" % [BondRules.valence(id), str(GameData.rune(id).get("affinity", ""))]
		if seen.has(key) or BondRules.valence(id) <= 0 or rules.alignment_state(anchor, id) == "refused":
			continue
		seen[key] = true
		kinds.append(id)
	if kinds.is_empty():
		return {}
	var a: int = rules.anchor_needs(RuneWord.make(anchor, rules.id))
	var per_ring: Array = []
	for k: int in range(1, rings + 1):
		per_ring.append(_multisets(kinds.size(), rules.ring_capacity(k)))
	var choice: Array = []
	return _solve_rings(anchor, rings, kinds, per_ring, 0, choice, a, rules)


static func _solve_rings(anchor: String, rings: int, kinds: Array[String], per_ring: Array, k: int, choice: Array, a: int, rules: RingRules) -> Dictionary:
	if k == rings:
		return _realise(anchor, kinds, choice, a, rules)
	for ms: Array in per_ring[k]:
		choice.append(ms)
		var w: Dictionary = _solve_rings(anchor, rings, kinds, per_ring, k + 1, choice, a, rules)
		choice.pop_back()
		if not w.is_empty():
			return w
	return {}


## Is there a set of bonds that closes these runes on these rings? The word if so, else {}.
static func _realise(anchor: String, kinds: Array[String], choice: Array, a: int, rules: RingRules) -> Dictionary:
	var ids: Array[String] = [anchor]
	var rs: Array[int] = [0]
	var need: Array[int] = [a]
	var total: int = a
	for k: int in choice.size():
		for kind: Variant in choice[k]:
			var id: String = kinds[int(kind)]
			if not bool(rules.params.get("allow_repeats", true)) and ids.has(id):
				return {}
			ids.append(id)
			rs.append(k + 1)
			need.append(BondRules.valence(id))
			total += BondRules.valence(id)
	if total % 2 != 0:
		return {}
	var n: int = ids.size()
	var edges: Array = []
	for i: int in n:
		for j: int in range(i + 1, n):
			if RingRules.rings_meet(rs[i], rs[j]) and not (rs[i] == 0 and rs[j] == 0) and rules.alignment_state(ids[i], ids[j]) != "refused":
				edges.append([i, j])
	var left: Array[int] = []
	left.resize(n)
	left.fill(0)
	for e: Array in edges:
		left[int(e[0])] += 1
		left[int(e[1])] += 1
	for i2: int in n:
		if need[i2] > left[i2]:
			return {}
	var chosen: Array = []
	if not _bt(edges, 0, need, left, chosen, n):
		return {}
	var w: Dictionary = RuneWord.make(anchor, rules.id)
	for i3: int in range(1, n):
		RuneWord.add_node(w, ids[i3], rs[i3])
	for e2: Array in chosen:
		RuneWord.add_link(w, int(e2[0]), int(e2[1]))
	return w


static func _bt(edges: Array, ei: int, need: Array[int], left: Array[int], chosen: Array, n: int) -> bool:
	if ei == edges.size():
		for v: int in need:
			if v != 0:
				return false
		return _joined(chosen, n)
	var e: Array = edges[ei]
	var u: int = int(e[0])
	var v2: int = int(e[1])
	left[u] -= 1
	left[v2] -= 1
	var ok := false
	# take the bond
	if need[u] > 0 and need[v2] > 0:
		need[u] -= 1
		need[v2] -= 1
		chosen.append(e)
		if need[u] <= left[u] and need[v2] <= left[v2]:
			ok = _bt(edges, ei + 1, need, left, chosen, n)
		if not ok:
			chosen.pop_back()
		need[u] += 1
		need[v2] += 1
	# or leave it
	if not ok and need[u] <= left[u] and need[v2] <= left[v2]:
		ok = _bt(edges, ei + 1, need, left, chosen, n)
	left[u] += 1
	left[v2] += 1
	return ok


static func _joined(chosen: Array, n: int) -> bool:
	var adj: Array = []
	for i: int in n:
		adj.append([])
	for e: Array in chosen:
		(adj[int(e[0])] as Array).append(int(e[1]))
		(adj[int(e[1])] as Array).append(int(e[0]))
	var seen: Dictionary = {0: true}
	var todo: Array = [0]
	while not todo.is_empty():
		var at: int = int(todo.pop_back())
		for nb: Variant in adj[at]:
			if not seen.has(int(nb)):
				seen[int(nb)] = true
				todo.append(int(nb))
	return seen.size() == n


# --- through the player ------------------------------------------------------------------------

## Set `word` into `p`'s open draft of ability `index`: cleared first, then every rune on its ring,
## ring by ring from the skill outward, then every bond - through the real word_add and word_link.
static func replay(p: Node, index: int, word: Dictionary) -> Array:
	p.call("word_clear", index)
	var out: Array = []
	var rs: Array[int] = RuneWord.rings(word)
	var order: Array[int] = []
	for k: int in range(1, RuneWord.outer_ring(word) + 1):
		for i: int in RuneWord.ring_nodes(word, k):
			order.append(i)
	var at: Dictionary = {0: 0}
	for i2: int in order:
		var r: Dictionary = p.call("word_add", index, RuneWord.node_id(word, i2), -1, rs[i2])
		out.append(r)
		at[i2] = int(r.get("node", -1))
	for l: Dictionary in RuneWord.links(word):
		out.append(p.call("word_link", index, int(at.get(int(l["a"]), -1)), int(at.get(int(l["b"]), -1))))
	return out
