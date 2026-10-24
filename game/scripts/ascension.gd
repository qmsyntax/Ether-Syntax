class_name Ascension
extends RefCounted
## What a star ascension gives (Brent 2026-10-24): an offer of affinities to add, and a permanent
## boost to every skill held, put into one aspect of each. Rules only; the player owns the state
## (`Player.ascension_pending`, a skill state's "ascension" totals) and the screen is
## `ui/ascension_screen.gd`. Numbers are in balance.json "ascension".
##
##   boost_i = (P / skills held) x (1 + stage_weight x stage_i),  P = pool_by_star[star]
##
## An aspect names rune stat groups (runes.json, the rule set's stat_groups) and a direction; the
## boost lands through `RuneRules.group_patch`, the same reader a sealed word's totals use. It is
## not levelling: stage, bar and level locks are untouched.


static func cfg() -> Dictionary:
	return GameData.balance.get("ascension", {})


# --- the offer -------------------------------------------------------------------------------

## The affinities offered to a character holding `held`: offer_count of them, none held and none
## the game lacks (GameData.affinity_playable). One is a hybrid with a parent in `held` when any
## such exists; the rest are drawn from the BASES not held (Brent 2026-10-24: a hybrid only ever
## comes through a base you hold). Order: the hybrid first.
static func offer(held: Array, rng: RandomNumberGenerator) -> Array[String]:
	var count: int = int(cfg().get("offer_count", 2))
	var pool: Array[String] = []
	for id: Variant in GameData.affinity_ids():
		if not held.has(str(id)) and GameData.affinity_playable(str(id)):
			pool.append(str(id))
	pool.sort()                          # the draw depends on the rng only, not on dictionary order
	var out: Array[String] = []
	var hybrids: Array[String] = []
	hybrids.assign(pool.filter(func(id: String) -> bool: return is_hybrid_for(id, held)))
	if not hybrids.is_empty() and count > 0:
		var h: String = hybrids[rng.randi() % hybrids.size()]
		out.append(h)
	pool.assign(pool.filter(func(id: String) -> bool: return str(GameData.affinity(id).get("kind", "")) == "base"))
	while out.size() < count and not pool.is_empty():
		var r: String = pool[rng.randi() % pool.size()]
		out.append(r)
		pool.erase(r)
	return out


## True if `id` is a hybrid one of whose parents is in `held`.
static func is_hybrid_for(id: String, held: Array) -> bool:
	if str(GameData.affinity(id).get("kind", "")) != "hybrid":
		return false
	for p: String in GameData.affinity_parents(id):
		if held.has(p):
			return true
	return false


static func allow_decline() -> bool:
	return bool(cfg().get("allow_decline", true))


# --- the boost -------------------------------------------------------------------------------

## P for the star just born: pool_by_star[star], or the highest listed star's below it.
static func pool(star: int) -> float:
	var by: Dictionary = cfg().get("pool_by_star", {})
	var best := -1
	for k: Variant in by:
		var s: int = int(str(k))
		if s <= star and s > best:
			best = s
	return float(by[str(best)]) if best >= 0 else 0.0


## Each skill's boost for an ascension to `star`: [{index, id, stage, amount}], amount =
## (P / n) x (1 + stage_weight x stage).
static func boosts(abilities: Array, star: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var n: int = abilities.size()
	if n == 0:
		return out
	var p: float = pool(star)
	var a: float = float(cfg().get("stage_weight", 0.0))
	for i: int in n:
		var st: Dictionary = abilities[i]
		var stage: int = int(st.get("stage", 0))
		out.append({"index": i, "id": str(st["id"]), "stage": stage, "amount": amount(p, n, stage, a)})
	return out


## The formula itself.
static func amount(p: float, n: int, stage: int, a: float) -> float:
	return (p / float(maxi(1, n))) * (1.0 + a * float(stage))


## The aspect ids, in data order (power, reach, speed, cost).
static func aspect_ids() -> Array[String]:
	var out: Array[String] = []
	for id: Variant in (cfg().get("aspects", {}) as Dictionary):
		out.append(str(id))
	return out


static func aspect(id: String) -> Dictionary:
	return (cfg().get("aspects", {}) as Dictionary).get(id, {})


## The stat groups an aspect reaches: {group: "up" | "down"}.
static func aspect_groups(id: String) -> Dictionary:
	return aspect(id).get("groups", {})


## The aspect a stat group counts for ("" if none).
static func aspect_of_group(g: String) -> String:
	for id: String in aspect_ids():
		if aspect_groups(id).has(g):
			return id
	return ""


## Whether a boost in this aspect would change anything in the skill `ab` (its numbers).
static func aspect_acts(ab: Dictionary, id: String) -> bool:
	for g: String in aspect_groups(id):
		if Runes.active().group_acts(ab, g):
			return true
	return false


## A skill's main aspect, the default when the player skips: the first of its signature paths
## that sits in an aspect's stat group; else power if it has a magnitude (a buff's or channel's
## strength); else the first aspect that does anything to it.
static func main_aspect(ab: Dictionary) -> String:
	for path: Variant in ab.get("signature", []):
		for g: String in Runes.active().groups_of_path(ab, str(path)):
			var asp: String = aspect_of_group(g)
			if asp != "" and aspect_acts(ab, asp):
				return asp
	if not (ab.get("magnitude", []) as Array).is_empty() and aspect_acts(ab, aspect_of_group("power")):
		return aspect_of_group("power")
	for id: String in aspect_ids():
		if aspect_acts(ab, id):
			return id
	return aspect_ids()[0] if not aspect_ids().is_empty() else ""


## The multiplier one stat group gets from an aspect's total t: (1 + t) up, 1 / (1 + t) down.
static func group_mult(direction: String, total: float) -> float:
	return 1.0 / (1.0 + total) if direction == "down" else 1.0 + total


## The patch an ability's ascension totals ({aspect: total fraction}) make on `ab` - the skill's
## numbers as they stand (after constructs and its sealed word).
static func patch(ab: Dictionary, totals: Dictionary) -> Array:
	var groups: Dictionary = {}
	for id: Variant in totals:
		var t: float = float(totals[id])
		if t <= 0.0:
			continue
		var gs: Dictionary = aspect_groups(str(id))
		for g: Variant in gs:
			groups[str(g)] = float(groups.get(str(g), 1.0)) * group_mult(str(gs[g]), t)
	if groups.is_empty():
		return []
	return Runes.active().group_patch(ab, groups)


## "+22% power, -9% essence cost" for a skill's totals ("" if none). An aspect that only lowers
## numbers shows the cut it makes (1 - 1 / (1 + t)).
static func summary(totals: Dictionary) -> String:
	var parts: Array[String] = []
	for id: String in aspect_ids():
		var t: float = float(totals.get(id, 0.0))
		if t <= 0.0:
			continue
		var word: String = str(aspect(id).get("word", id))
		if aspect_groups(id).values().all(func(d: Variant) -> bool: return str(d) == "down"):
			parts.append("-%d%% %s" % [int(round((1.0 - 1.0 / (1.0 + t)) * 100.0)), word])
		else:
			parts.append("+%d%% %s" % [int(round(t * 100.0)), word])
	return ", ".join(parts)
