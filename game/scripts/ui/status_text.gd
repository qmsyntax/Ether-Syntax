class_name StatusText
extends RefCounted
## What a status means, in words (Brent 2026-10-23: "Any way we can get a definition of the status
## effects? What does Masked mean?"). Two parts, both from statuses.json:
##   desc   - one plain line in the game's voice, written by hand (tools/skills/skill_tables.py
##            STATUS_DESC, emitted as the status's "desc");
##   rules  - a line made here from the status's generic keys (the keys enemy.gd's status engine
##            reads): lasts N s, stacks to N, moves at X%, takes X% more, cannot act, spreads within
##            N m, heavy enemies half as long, elites get Dazed instead...
## Every key a status may carry is either WORDED here or listed in IGNORED (presentation only); the
## self-test fails on a key that is neither, so a new key has to be explained before it ships.
## Also: which statuses a skill applies (and how long, as that skill applies them) and which it only
## reads - applied_by / read_by / compare, walking the ability's data generically.

## Keys that only change how a status is drawn or named, never what it does.
const IGNORED: Array[String] = ["label", "desc", "color", "hidden", "alias_of"]

## Keys rules_of() puts into words.
const WORDED: Array[String] = [
	"derived", "lasts", "heavy_lasts_mult", "no_refresh", "stacks", "cap_raise", "living_only", "needs_first", "blocked_by",
	"elite_status", "control", "cannot_act", "cannot_move", "immovable", "cannot_attack", "no_call", "move_mult", "speed_mult",
	"move_mult_per_stack", "attack_speed_mult", "attack_rate_mult", "windup_mult", "reach_mult", "lighter_class",
	"damage_taken_mult", "damage_taken_except", "damage_taken_from", "armour_mult", "armour_mult_per_stack",
	"front_block_off", "counts_rear", "metal_class_off", "flesh_per_stack", "deals_mult", "no_poise_damage",
	"poise_regen_off", "poise_max_mult", "poise_per_s", "poise_mult", "heavy_poise", "dps_per_stack", "dps_per_metal_class",
	"tick_s", "moving_mult", "times_flesh", "dot_tags", "dps_mult", "ends_after_damage", "spread_radius", "spread_time",
	"jumps_on_death", "on_expire", "on_cap", "on_death", "drips_pool_s", "wakes_on_hit", "then_status", "ends", "blocks",
	"counts_as", "freezes", "flees", "blinded", "floor_health", "kneels_below", "no_heal", "shatter", "light_radius",
	"retch_every", "retch_s", "makes_interruptible", "staggers_in_windup", "lure_radius", "shove_mult", "ends_on_shove",
	"goes_to_goal", "no_conduct", "no_death_effects", "nudge_per_s", "conduct_radius", "conduct_marks", "overload_damage",
	"stun", "arc_damage", "arc_radius", "grounds",
]

## Keys of a skill's data that name statuses it reads, spends or keeps off rather than applies.
const READ_KEYS: Array[String] = ["consume_status", "needs_status", "bonus_vs_status", "bonus_also_vs", "banks",
	"blocks_status", "ends_status", "consume", "status_s_if_not", "bonus_vs", "bonus_flat_vs", "poise_vs", "counts",
	"consume_counts", "consume_stacks", "status_lasts", "status_time_of"]


# --- one status -------------------------------------------------------------------------------

## The id a status is kept under (rooted -> pinned).
static func resolve(id: String) -> String:
	return str(GameData.status(id).get("alias_of", id))


## Its definition, following alias_of.
static func def_of(id: String) -> Dictionary:
	return GameData.status(resolve(id))


static func exists(id: String) -> bool:
	return not GameData.status(id).is_empty()


static func label(id: String) -> String:
	var own: Dictionary = GameData.status(id)
	if own.has("label"):
		return str(own["label"])
	return str(def_of(id).get("label", id.capitalize()))


## The hand-written line: what it means for the enemy.
static func desc(id: String) -> String:
	return str(def_of(id).get("desc", ""))


## The rules line for status `id`; `lasts` >= 0 says how long it lasts as a given skill applies it.
## `with_lasts` false leaves the time out (a caller that says it beside the name).
static func rules(id: String, lasts: float = -1.0, with_lasts: bool = true) -> String:
	return rules_of(def_of(id), lasts, with_lasts)


## "Label: desc" and the rules line under it - the whole definition, for a tooltip.
static func definition(id: String, lasts: float = -1.0) -> String:
	var d: String = desc(id)
	return "%s%s\n%s" % [label(id), (": " + d) if d != "" else "", rules(id, lasts)]


## Every status that is not an alias, by label.
static func all_ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in GameData.status_ids():
		if not GameData.status(id).has("alias_of"):
			out.append(id)
	out.sort_custom(func(a: String, b: String) -> bool: return label(a) < label(b))
	return out


## Every key used by any status in statuses.json (for the self-test's coverage check).
static func keys_in_use() -> Array[String]:
	var out: Array[String] = []
	for id: String in GameData.status_ids():
		for k: String in (GameData.status(id) as Dictionary):
			if not out.has(k):
				out.append(k)
	return out


## The statuses named in a line of text (by label, as whole words): the rune view's "+ ..." lines.
static func mentioned(text: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in GameData.status_ids():
		if GameData.status(id).has("alias_of"):
			continue
		var l: String = label(id)
		var at: int = text.find(l)
		while at >= 0:
			var before_ok: bool = at == 0 or not _is_letter(text[at - 1])
			var end: int = at + l.length()
			var after_ok: bool = end >= text.length() or not _is_letter(text[end])
			if before_ok and after_ok:
				out.append(id)
				break
			at = text.find(l, at + 1)
	return out


static func _is_letter(c: String) -> bool:
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z")


# --- the rules line ---------------------------------------------------------------------------

## The rules line made from a definition's keys (see WORDED). `lasts` >= 0 replaces its own.
static func rules_of(def: Dictionary, lasts: float = -1.0, with_lasts: bool = true) -> String:
	var p: Array[String] = []
	var der: String = str(def.get("derived", ""))
	if der != "":
		p.append("read from its health (%s half), never put on it" % ("above" if der == "above_half" else "below"))
	var secs: float = lasts if lasts >= 0.0 else float(def.get("lasts", 0.0))
	if with_lasts and (der == "" and def.has("lasts") or lasts >= 0.0):
		if secs > 0.0:
			p.append("lasts %s s" % _n(secs))
	if def.has("heavy_lasts_mult") and absf(float(def["heavy_lasts_mult"]) - 1.0) > 0.001:
		p.append("heavy enemies %s" % ("half as long" if is_equal_approx(float(def["heavy_lasts_mult"]), 0.5) else "x%s as long" % _n(float(def["heavy_lasts_mult"]))))
	if bool(def.get("no_refresh", false)):
		p.append("more of it does not reset the clock")
	if int(def.get("stacks", 1)) > 1:
		p.append("stacks to %d" % int(def["stacks"]))
	for other: String in (def.get("cap_raise", {}) as Dictionary):
		p.append("%s on it stacks to %d" % [label(other), int((def["cap_raise"] as Dictionary)[other])])
	if bool(def.get("living_only", false)):
		p.append("the living only")
	if def.has("needs_first"):
		p.append("the first only makes it %s; it takes hold on one already %s" % [label(str(def["needs_first"])), label(str(def["needs_first"]))])
	if def.has("blocked_by"):
		p.append("not while %s" % _labels(def["blocked_by"], " or "))
	if def.has("elite_status"):
		p.append("elites get %s instead" % label(str(def["elite_status"])))
	# what it cannot do
	if bool(def.get("cannot_act", false)):
		p.append("cannot move or act")
	if bool(def.get("cannot_move", false)):
		p.append("cannot walk")
	if bool(def.get("immovable", false)):
		p.append("cannot be shoved, dragged or nudged")
	if bool(def.get("cannot_attack", false)):
		p.append("cannot start an attack")
	if bool(def.get("no_call", false)):
		p.append("cannot drum or call for help")
	if bool(def.get("control", false)):
		p.append("a hold: a lingering skill lays it on each enemy only once a cast")
	# how it moves and fights
	var move: float = float(def.get("move_mult", def.get("speed_mult", 1.0)))
	if def.has("move_mult") or def.has("speed_mult"):
		p.append("moves at %d%%" % int(round(move * 100.0)))
	if def.has("move_mult_per_stack"):
		p.append("%d%% slower a stack" % int(round((1.0 - float(def["move_mult_per_stack"])) * 100.0)))
	if def.has("attack_speed_mult") or def.has("attack_rate_mult"):
		p.append("attacks %s" % _more_less(float(def.get("attack_speed_mult", def.get("attack_rate_mult", 1.0))), "faster", "slower"))
	if def.has("windup_mult"):
		p.append("wind-ups take %s" % _more_less(float(def["windup_mult"]), "longer", "less long"))
	if def.has("reach_mult"):
		p.append("reach %d%%" % int(round(float(def["reach_mult"]) * 100.0)))
	if bool(def.get("lighter_class", false)):
		p.append("one weight class lighter")
	if def.has("lure_radius"):
		p.append("its friends within %s m go for it instead of you" % _n(float(def["lure_radius"])))
	if def.has("flees"):
		p.append("runs from whoever put it there" if str(def["flees"]) == "source" else "backs out of the ground that caused it")
	if bool(def.get("goes_to_goal", false)):
		p.append("walks to the spot it was sent to")
	if def.get("blinded") is Dictionary:
		var b: Dictionary = def["blinded"]
		p.append("sees no further than %s m, cannot aim, and its swings land only within %s m in front" % [_n(float(b.get("sight", 2.0))), _n(float(b.get("melee_reach", 1.5)))])
	if def.has("retch_every"):
		p.append("every %s s it retches%s" % [_n(float(def["retch_every"])), (" and stands still %s s" % _n(float(def["retch_s"]))) if def.has("retch_s") else ", losing what it was doing"])
	if bool(def.get("makes_interruptible", false)):
		p.append("every attack it starts can be interrupted")
	if bool(def.get("staggers_in_windup", false)):
		p.append("a hit while it winds up staggers it")
	# what it takes
	if def.has("damage_taken_mult"):
		var ex: String = (" (not from %s)" % ", ".join(PackedStringArray((def.get("damage_taken_except", []) as Array).map(func(v: Variant) -> String: return str(v))))) if def.has("damage_taken_except") else ""
		p.append("takes %s damage%s" % [_more_less(float(def["damage_taken_mult"]), "more", "less"), ex])
	elif def.has("damage_taken_except"):
		p.append("(not from %s)" % ", ".join(PackedStringArray((def["damage_taken_except"] as Array).map(func(v: Variant) -> String: return str(v)))))
	for aff: String in (def.get("damage_taken_from", {}) as Dictionary):
		p.append("takes %s damage from %s" % [_more_less(float((def["damage_taken_from"] as Dictionary)[aff]), "more", "less"), str(GameData.affinity(aff).get("label", aff.capitalize()))])
	if def.has("armour_mult"):
		var am: float = float(def["armour_mult"])
		p.append("no front armour" if am <= 0.0 else ("front armour halved" if is_equal_approx(am, 0.5) else "front armour x%s" % _n(am)))
	if def.has("armour_mult_per_stack"):
		p.append("front armour -%d%% a stack" % int(round((1.0 - float(def["armour_mult_per_stack"])) * 100.0)))
	if def.has("flesh_per_stack"):
		p.append("+%d%% bare flesh a stack" % int(round(float(def["flesh_per_stack"]) * 100.0)))
	if bool(def.get("front_block_off", false)):
		p.append("its front guard blocks nothing")
	if bool(def.get("counts_rear", false)):
		p.append("every hit counts as from behind")
	if bool(def.get("metal_class_off", false)):
		p.append("counts as wearing no metal")
	if def.has("shove_mult"):
		p.append("shoves move it x%s%s" % [_n(float(def["shove_mult"])), " (the next one only)" if bool(def.get("ends_on_shove", false)) else ""])
	elif bool(def.get("ends_on_shove", false)):
		p.append("a shove ends it")
	if def.has("floor_health"):
		p.append("cannot go below %s health" % _n(float(def["floor_health"])))
	if def.has("kneels_below"):
		p.append("below %d%% health it kneels and does nothing" % int(round(float(def["kneels_below"]) * 100.0)))
	if bool(def.get("no_heal", false)):
		p.append("cannot be healed")
	# what it deals and its poise
	if def.has("deals_mult"):
		p.append("its blows do %s" % _more_less(float(def["deals_mult"]), "more", "less"))
	if bool(def.get("no_poise_damage", false)):
		p.append("its blows cannot stagger you")
	if def.has("poise_max_mult"):
		p.append("poise cut to %d%%" % int(round(float(def["poise_max_mult"]) * 100.0)))
	if bool(def.get("poise_regen_off", false)):
		p.append("its poise does not recover")
	if def.has("poise_per_s"):
		p.append("loses %s poise a second" % _n(float(def["poise_per_s"])))
	if def.has("poise_mult"):
		p.append("takes poise damage at %d%%" % int(round(100.0 / maxf(0.01, float(def["poise_mult"])))))
	if def.has("heavy_poise"):
		p.append("one too heavy to lift loses %s poise instead" % _n(float(def["heavy_poise"])))
	if def.has("nudge_per_s"):
		p.append("pushed %s m a second away from you" % _n(float(def["nudge_per_s"])))
	# damage over time, in the name of whoever put it there
	var tick: String = (", every %s s" % _n(float(def["tick_s"]))) if def.has("tick_s") else ""
	if def.has("dps_per_stack"):
		p.append("%s damage a second%s%s" % [_n(float(def["dps_per_stack"])), " a stack" if int(def.get("stacks", 1)) > 1 else "", tick])
	if def.has("dps_per_metal_class"):
		p.append("%s damage a second per class of metal worn%s" % [_n(float(def["dps_per_metal_class"])), tick])
	if not def.has("dps_per_stack") and not def.has("dps_per_metal_class") and def.has("tick_s"):
		p.append("ticks every %s s" % _n(float(def["tick_s"])))
	if def.has("moving_mult"):
		p.append("x%s while it moves or winds up" % _n(float(def["moving_mult"])))
	if bool(def.get("times_flesh", false)):
		p.append("armour keeps out all but its bare flesh's share")
	if (def.get("dot_tags", []) as Array).has("through"):
		p.append("passes shields and armour")
	for other2: String in (def.get("dps_mult", {}) as Dictionary):
		p.append("%s on it burns at %d%%" % [label(other2), int(round(float((def["dps_mult"] as Dictionary)[other2]) * 100.0))])
	if def.has("ends_after_damage"):
		p.append("ends once it has taken %s" % _n(float(def["ends_after_damage"])))
	if def.has("spread_radius"):
		p.append("spreads to an enemy within %s m%s" % [_n(float(def["spread_radius"])), (" after %s s beside it" % _n(float(def["spread_time"]))) if def.has("spread_time") else ""])
	elif def.has("spread_time"):
		p.append("spreads after %s s" % _n(float(def["spread_time"])))
	if bool(def.get("jumps_on_death", false)):
		p.append("jumps to a neighbour when it dies")
	if bool(def.get("no_conduct", false)):
		p.append("Live marks do not pass into or out of it")
	if bool(def.get("no_death_effects", false)):
		p.append("nothing spreads or bursts from it")
	if def.has("light_radius"):
		p.append("gives light (%s m)" % _n(float(def["light_radius"])))
	if def.has("drips_pool_s"):
		p.append("drips a blood pool every %s s" % _n(float(def["drips_pool_s"])))
	# how it ends, and what it leaves
	if bool(def.get("wakes_on_hit", false)):
		p.append("a hit ends it%s" % ((", leaving it %s" % label(str(def["then_status"]))) if def.has("then_status") else ""))
	elif def.has("then_status"):
		p.append("then %s" % label(str(def["then_status"])))
	var exp: Dictionary = def.get("on_expire", {})
	if exp.has("status"):
		p.append("leaves %d %s when it ends" % [int(exp.get("stacks", 1)), label(str(exp["status"]))])
	if exp.has("damage_per_stack"):
		p.append("when it runs out: %s damage a stack, all at once" % _n(float(exp["damage_per_stack"])))
	var cap: Dictionary = def.get("on_cap", {})
	if not cap.is_empty():
		p.append("at %d stacks it becomes %s%s%s" % [int(def.get("stacks", 1)), label(str(cap.get("status", ""))), " (the stacks go)" if bool(cap.get("clear", false)) else "",
			(", elites %s" % label(str(cap["elite_status"]))) if cap.has("elite_status") else ""])
	var od: Dictionary = def.get("on_death", {})
	if not od.is_empty():
		var bits: Array[String] = []
		if bool(od.get("pool", false)):
			bits.append("a blood pool")
		if int(od.get("held_blood", 0)) > 0:
			bits.append("%d held blood for you" % int(od["held_blood"]))
		if od.get("cloud") is Dictionary:
			var c: Dictionary = od["cloud"]
			var gives: String = str((c.get("payload", {}) as Dictionary).get("status", ""))
			bits.append("a cloud %s m across for %s s%s" % [_n(float(c.get("radius", 1.0)) * 2.0), _n(float(c.get("life", 4.0))), (" that gives %s" % label(gives)) if gives != "" else ""])
		p.append("dying leaves " + " and ".join(PackedStringArray(bits)))
	if def.has("ends"):
		p.append("ends %s" % _labels(def["ends"], ", "))
	if def.has("blocks"):
		p.append("keeps off %s" % _labels(def["blocks"], ", "))
	if def.has("counts_as"):
		p.append("counts as %s" % _labels(def["counts_as"], ", "))
	if def.has("freezes"):
		p.append("%s on it do not run down" % _labels(def["freezes"], ", "))
	if def.get("shatter") is Dictionary:
		var sh: Dictionary = def["shatter"]
		var shard: Dictionary = sh.get("shard", {})
		p.append("a hard hit (%s+ poise) Shatters it: %s damage, and %s%s to everyone within %s m" % [_n(float(sh.get("hard_poise", 40.0))), _n(float(sh.get("damage", 100.0))),
			_n(float(shard.get("damage", 0.0))), (" and %s" % label(str(shard["status"]))) if shard.has("status") else "", _n(float(sh.get("radius", 2.5)))])
	# Soaked and Live: lightning's rules ride on them
	if def.has("conduct_radius") or def.has("conduct_marks"):
		p.append("a Live mark on it %s every other Soaked enemy%s" % [("adds %d to" % int(def["conduct_marks"])) if def.has("conduct_marks") else "carries to",
			(" within %s m" % _n(float(def["conduct_radius"]))) if def.has("conduct_radius") else " close by"])
	if def.has("overload_damage") or def.has("stun"):
		p.append("at %d marks it Overloads: %s damage%s" % [int(def.get("stacks", 3)), _n(float(def.get("overload_damage", 0.0))),
			(" and stunned %s s" % _n(float(def["stun"]))) if def.has("stun") else ""])
	if def.has("arc_damage") or def.has("arc_radius"):
		p.append("the Overload arcs %s to every other marked enemy within %s m" % [_n(float(def.get("arc_damage", 0.0))), _n(float(def.get("arc_radius", 0.0)))])
	if def.has("grounds"):
		p.append("an Overload grounds %s of your lightning reflux" % _n(float(def["grounds"])))
	if p.is_empty():
		return "No rules of its own beyond its name."
	var s: String = "; ".join(PackedStringArray(p))
	return s.left(1).to_upper() + s.substr(1) + "."


## "30% more" / "35% less" from a multiplier.
static func _more_less(m: float, more: String, less: String) -> String:
	if m >= 1.0:
		return "%d%% %s" % [int(round((m - 1.0) * 100.0)), more]
	return "%d%% %s" % [int(round((1.0 - m) * 100.0)), less]


static func _labels(ids: Variant, joiner: String) -> String:
	var out: Array[String] = []
	for v: Variant in (ids as Array):
		out.append(label(str(v)))
	return joiner.join(PackedStringArray(out))


## A number without trailing zeros: 4.0 -> "4", 0.25 -> "0.25", 0.0333 -> "0.03".
static func _n(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return "%d" % int(roundf(v))
	return ("%.2f" % v).rstrip("0").rstrip(".")


# --- what a skill does with statuses ----------------------------------------------------------

## The statuses ability `ab` (its data, as Player.ability_stats gives it) lays on enemies, in the
## order its data names them, each once: [{id, stacks, lasts, notes: [String], where}]. `lasts` is
## how long it lasts as this skill applies it (its payload's status_s or a list entry's own lasts,
## else the status's own, times status_time_mult and status_time_of); notes are the conditions the
## data puts on it (per metal class, per heat, in the Dark, unless the target already has something,
## standing in the zone).
static func applied_by(ab: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_walk_applied(ab, "", out)
	return out


static func _walk_applied(d: Dictionary, path: String, out: Array[Dictionary]) -> void:
	# (dictionaries under READ_KEYS - consume, status_s_if_not... - are never walked: what they name is read)
	if d.get("status") is String and exists(str(d["status"])):
		_add_applied(out, str(d["status"]), int(d.get("stacks", 1)), d, {}, path)
	for e: Variant in d.get("statuses", []):
		if e is Dictionary and exists(str((e as Dictionary).get("id", ""))):
			_add_applied(out, str(e["id"]), int((e as Dictionary).get("stacks", 1)), d, e, path)
	for k: String in d:
		if k.ends_with("_status") and not READ_KEYS.has(k) and d[k] is String and exists(str(d[k])):
			var lasts_key: String = k + "_s"
			var own: Dictionary = {"lasts": float(d[lasts_key])} if d.has(lasts_key) else {}
			_add_applied(out, str(d[k]), 1, {}, own, path)
	for k2: String in d:
		if d[k2] is Dictionary and not READ_KEYS.has(k2):
			_walk_applied(d[k2], path + k2 + ".", out)


static func _add_applied(out: Array[Dictionary], id: String, stacks: int, payload: Dictionary, entry: Dictionary, path: String) -> void:
	for have: Dictionary in out:
		if str(have["id"]) == resolve(id):
			return
	var def: Dictionary = def_of(id)
	var lasts: float = float(def.get("lasts", 0.0))
	var notes: Array[String] = []
	if entry.has("lasts"):
		lasts = float(entry["lasts"])
	elif payload.has("status_s"):
		lasts = float(payload["status_s"])
	if payload.has("status_s_per_class"):
		notes.append("+%s s per class of metal it wears" % _n(float(payload["status_s_per_class"])))
	if payload.has("status_s_per_heat") and float(payload["status_s_per_heat"]) > 0.0:
		notes.append("+1 s per %s heat, up to %s s" % [_n(roundf(1.0 / float(payload["status_s_per_heat"]))), _n(float(payload.get("status_s_max", 99.0)))])
	if payload.has("dark_status_s"):
		notes.append("%s s in the Dark" % _n(float(payload["dark_status_s"])))
	if payload.get("status_s_if_not") is Dictionary:
		var c: Dictionary = payload["status_s_if_not"]
		notes.append("%s s unless it is %s" % [_n(lasts * float(c.get("frac", 1.0))), label(str(c.get("status", "")))])
	var m: float = float(payload.get("status_time_mult", 1.0)) * float((payload.get("status_time_of", {}) as Dictionary).get(id, 1.0))
	if not entry.has("lasts"):
		lasts *= m
	if path.begins_with("zone.") or path.begins_with("trail.") or path.begins_with("leave_zone."):
		notes.append("while it stands in it")
	out.append({"id": resolve(id), "stacks": stacks, "lasts": lasts, "notes": notes, "where": path.trim_suffix(".")})


## Statuses ability `ab` reads, spends, needs or keeps off without applying them: [id].
static func read_by(ab: Dictionary) -> Array[String]:
	var out: Array[String] = []
	_walk_read(ab, false, out)
	var applied: Array = applied_by(ab).map(func(a: Dictionary) -> String: return str(a["id"]))
	return out.filter(func(id: String) -> bool: return not applied.has(id))


static func _walk_read(v: Variant, reading: bool, out: Array[String]) -> void:
	if v is String:
		if reading and exists(str(v)) and not out.has(resolve(str(v))):
			out.append(resolve(str(v)))
	elif v is Array:
		for e: Variant in (v as Array):
			_walk_read(e, reading, out)
	elif v is Dictionary:
		for k: String in (v as Dictionary):
			var r: bool = reading or READ_KEYS.has(k)
			if r and exists(k) and not out.has(resolve(k)):
				out.append(resolve(k))          # a dictionary keyed by status: bonus_vs {asleep: 1.0}
			if k == "status" and not reading:
				continue                        # applied, not read
			_walk_read((v as Dictionary)[k], r, out)


## What a skill applies bare (`before`) and as it is now (`after`, its sealed word in), side by side:
## [{id, stacks, stacks_before, lasts, lasts_before, notes, added}]; `added` when only the word
## brings it (then the *_before are -1).
static func compare(before: Dictionary, after: Dictionary) -> Array[Dictionary]:
	var b: Array[Dictionary] = applied_by(before)
	var out: Array[Dictionary] = []
	for a: Dictionary in applied_by(after):
		var row: Dictionary = a.duplicate()
		row["stacks_before"] = -1
		row["lasts_before"] = -1.0
		row["added"] = true
		for o: Dictionary in b:
			if str(o["id"]) == str(a["id"]):
				row["stacks_before"] = int(o["stacks"])
				row["lasts_before"] = float(o["lasts"])
				row["added"] = false
		out.append(row)
	return out
