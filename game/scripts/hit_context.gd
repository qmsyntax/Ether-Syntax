class_name HitContext
extends RefCounted
## One damage event travelling through the hook pipeline. Effects read and rewrite it.
## Outgoing: created by the attacker before the hit lands; `mult` and `flat` shape the damage,
## `applied` is filled in after. Incoming: created by the victim; effects may `delay` or scale it.

var source: Node            # who dealt it (player, summon, enemy)
var target: Node            # who receives it
var base: float = 0.0       # damage before modifiers
var mult: float = 1.0
var flat: float = 0.0
var heavy: bool = false
var applied: float = 0.0    # damage that actually landed (never more than remaining HP)
var killed: bool = false
var is_living: bool = true
var is_scenery: bool = false
var tags: PackedStringArray = []   # "melee", "overcharge", "bolt", "vent", "dot", "summon", ...
var cancelled: bool = false        # an incoming effect swallowed it (e.g. deferred to later)


func amount() -> float:
	return maxf(0.0, base * mult + flat)


func has_tag(tag: String) -> bool:
	return tags.has(tag)
