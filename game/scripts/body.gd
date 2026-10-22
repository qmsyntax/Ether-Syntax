class_name Body
extends RefCounted
## One health bar, plus lasting wounds (Brent 2026-10-11, replacing the three wound layers).
##
## Health is what the bar shows; rest refills it. A wound is a lasting injury: while it is there
## it cuts the maximum of the bar, and it has a hidden pool - its "sink" - that healing has to
## fill before the wound closes. The sink is never part of the bar. What may fill a sink (a
## night's rest, the healer, a talent) is decided by whoever owns the body; this class only
## keeps the arithmetic.

## The bar's ceiling before wounds.
var max_hp := 1.0
var hp := 1.0
## Each: {"id", "name", "sink", "sink_max", "max_cut", "natural": bool, ...}. Oldest first.
var wounds: Array[Dictionary] = []
## Wounds can never cut the bar below this share of max_hp.
var min_max_frac := 0.25


func _init(health: float) -> void:
	max_hp = health
	hp = health


func total() -> float:
	return hp


## The bar's ceiling right now: max_hp less what the wounds cut.
func total_max() -> float:
	return maxf(max_hp * min_max_frac, max_hp - max_cut())


func max_cut() -> float:
	var cut := 0.0
	for w: Dictionary in wounds:
		cut += float(w.get("max_cut", 0.0))
	return cut


func is_dead() -> bool:
	return hp <= 0.0


## Health missing from the bar. The argument is ignored; it is kept so older callers that asked
## about one wound layer still read the whole bar.
func missing(_layer: String = "") -> float:
	return total_max() - hp


## Returns the damage actually applied (never more than what was left - no overkill).
func apply_damage(amount: float, _heavy: bool = false) -> float:
	var applied: float = clampf(amount, 0.0, hp)
	hp -= applied
	return applied


## Self-inflicted costs (overcharge, reflux burn) come off the same bar.
func apply_self_harm(amount: float) -> float:
	return apply_damage(amount)


## Refill the bar, up to `cap` (default: its current ceiling). Returns the health restored.
func heal(amount: float, cap: float = -1.0) -> float:
	var ceiling: float = total_max() if cap < 0.0 else minf(cap, total_max())
	var healed: float = clampf(amount, 0.0, maxf(0.0, ceiling - hp))
	hp += healed
	return healed


## Ascension remakes the body: a bigger bar, refilled. Wounds are carried over.
func scale_max(factor: float) -> void:
	max_hp *= factor
	hp = total_max()


# --- wounds -----------------------------------------------------------------------------

func has_wound(id: String) -> bool:
	return not wound(id).is_empty()


func wound(id: String) -> Dictionary:
	for w: Dictionary in wounds:
		if str(w["id"]) == id:
			return w
	return {}


## The healing still owed to wounds. `natural_only` counts only those rest can mend.
func sink_total(natural_only: bool = false) -> float:
	var total_sink := 0.0
	for w: Dictionary in wounds:
		if not natural_only or bool(w.get("natural", true)):
			total_sink += float(w["sink"])
	return total_sink


## Add a wound, or deepen one with the same id when `merge` is set. Health above the new
## ceiling is lost with it. Returns the wound.
func add_wound(id: String, wound_name: String, sink: float, cut: float, natural: bool = true, merge: bool = false) -> Dictionary:
	var w: Dictionary = wound(id) if merge else {}
	if w.is_empty():
		w = {"id": id, "name": wound_name, "sink": 0.0, "sink_max": 0.0, "max_cut": 0.0, "natural": natural}
		wounds.append(w)
	w["sink"] = float(w["sink"]) + sink
	w["sink_max"] = float(w["sink_max"]) + sink
	w["max_cut"] = float(w["max_cut"]) + cut
	hp = minf(hp, total_max())
	return w


func remove_wound(id: String) -> void:
	for i: int in wounds.size():
		if str(wounds[i]["id"]) == id:
			wounds.remove_at(i)
			return


## Pour healing into the wounds, oldest first; a wound whose sink is full closes and gives its
## share of the bar back (empty, to be refilled). `natural_only` skips wounds rest cannot mend.
## Returns {"used": float, "closed": Array of wound ids}.
func fill_sinks(points: float, natural_only: bool = false) -> Dictionary:
	var left: float = maxf(0.0, points)
	var closed: Array[String] = []
	for w: Dictionary in wounds.duplicate():
		if left <= 0.0:
			break
		if natural_only and not bool(w.get("natural", true)):
			continue
		var into: float = minf(left, float(w["sink"]))
		w["sink"] = float(w["sink"]) - into
		left -= into
		if float(w["sink"]) <= 0.0001:
			closed.append(str(w["id"]))
			wounds.erase(w)
	return {"used": maxf(0.0, points) - left, "closed": closed}


## Fill one wound's sink by id (Regrowth mends a lost arm at its own rate). {used, closed}.
func fill_one(id: String, points: float) -> Dictionary:
	var closed: Array[String] = []
	for w: Dictionary in wounds:
		if str(w["id"]) != id:
			continue
		var into: float = minf(maxf(0.0, points), float(w["sink"]))
		w["sink"] = float(w["sink"]) - into
		if float(w["sink"]) <= 0.0001:
			closed.append(id)
			wounds.erase(w)
		return {"used": into, "closed": closed}
	return {"used": 0.0, "closed": closed}


## How far along a wound is, in words - the sink itself is never shown as a number.
static func wound_state(w: Dictionary) -> String:
	var frac: float = float(w["sink"]) / maxf(0.001, float(w["sink_max"]))
	return "fresh" if frac > 0.75 else ("mending" if frac > 0.3 else "nearly closed")


func to_dict() -> Dictionary:
	return {"hp": hp, "max": max_hp, "wounds": wounds.duplicate(true)}


## Reads a save. Saves from before wounds stored three layers; their totals become the bar.
func from_dict(d: Dictionary, legacy_hp: Dictionary = {}, legacy_max: Dictionary = {}) -> void:
	if d.is_empty():
		if legacy_max.is_empty():
			return
		max_hp = 0.0
		hp = 0.0
		for layer: String in legacy_max:
			max_hp += float(legacy_max[layer])
			hp += float(legacy_hp.get(layer, legacy_max[layer]))
		wounds.clear()
		return
	max_hp = float(d.get("max", max_hp))
	wounds.clear()
	for w: Variant in d.get("wounds", []):
		wounds.append((w as Dictionary).duplicate())
	hp = clampf(float(d.get("hp", max_hp)), 0.0, total_max())
