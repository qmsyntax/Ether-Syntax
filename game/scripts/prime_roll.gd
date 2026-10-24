class_name PrimeRoll
extends RefCounted
## The primes offered at character creation (Brent 2026-10-11). A prime vestige is a talent plus
## some affinity slots, and the two are unrelated: the talent comes off a weighted table, the
## number of slots is rolled (one is common, two rare, three almost unheard of), and each slot is
## then filled with a random affinity. Numbers are in balance.json "primes".


## One offer: {"talent_id": String, "affinities": Array[String]}.
static func roll_offer(rng: RandomNumberGenerator, talent_id: String) -> Dictionary:
	return {"talent_id": talent_id, "affinities": roll_affinities(rng, roll_slots(rng))}


## `count` offers with different talents, drawn from `pool` (talent ids) by the table's weights.
static func roll_offers(rng: RandomNumberGenerator, pool: Array, count: int = -1) -> Array[Dictionary]:
	if count < 0:
		count = GameData.inum("primes", "offered")
	var left: Array = pool.duplicate()
	var out: Array[Dictionary] = []
	while out.size() < count and not left.is_empty():
		var id: String = _pick_talent(rng, left)
		left.erase(id)
		out.append(roll_offer(rng, id))
	return out


## How many affinity slots a prime has: 1 to the length of balance.primes.slot_weights.
static func roll_slots(rng: RandomNumberGenerator) -> int:
	var weights: Array = GameData.balance["primes"]["slot_weights"]
	var total := 0.0
	for w: Variant in weights:
		total += float(w)
	var roll: float = rng.randf() * total
	for i: int in weights.size():
		roll -= float(weights[i])
		if roll < 0.0:
			return i + 1
	return 1


## `slots` different affinities, each equally likely - bases only (Brent 2026-10-24: a character is
## made from the eight bases; hybrids come from ascension, `Ascension.offer`).
static func roll_affinities(rng: RandomNumberGenerator, slots: int) -> Array[String]:
	var left: Array = GameData.base_affinity_ids().filter(func(id: String) -> bool: return GameData.affinity_playable(id))
	var out: Array[String] = []
	while out.size() < slots and not left.is_empty():
		var id: String = str(left[rng.randi() % left.size()])
		left.erase(id)
		out.append(id)
	return out


## "common" | "rare" | "legendary" for a slot count, for the creation screen.
static func rarity(slots: int) -> String:
	return "common" if slots <= 1 else ("rare" if slots == 2 else "legendary")


static func _pick_talent(rng: RandomNumberGenerator, pool: Array) -> String:
	var weights: Dictionary = GameData.balance["primes"]["talent_weight_by_value"]
	var total := 0.0
	var each: Array[float] = []
	for id: Variant in pool:
		var w: float = float(weights.get(str(TalentDB.get_talent(str(id)).get("value", "mid")), 1.0))
		each.append(w)
		total += w
	var roll: float = rng.randf() * total
	for i: int in pool.size():
		roll -= each[i]
		if roll < 0.0:
			return str(pool[i])
	return str(pool[pool.size() - 1])
