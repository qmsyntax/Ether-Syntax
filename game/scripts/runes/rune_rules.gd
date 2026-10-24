class_name RuneRules
extends RefCounted
## The interface every rune rule set implements (design/14 section 7). The screen and the player
## ask the active rule set (Runes.active()) for everything about a word - whether a rune may be
## added or two runes linked and why not, how a link and a rune look, whether the word is closed,
## and what it does to its skill - and draw the answers generically. A word itself is rule-free
## data (RuneWord), so rule sets can be swapped without touching the screen or the save.
##
## This base class is the structural part every rule set shares, and is permissive otherwise:
## any rune, any link, no capacity. A rule set extends it and overrides the _virtual methods
## (BondRules is the first). Interactions (RuneInteraction) hook in after the rule set's answer.
##
## Checks return {"ok": bool, "reason": code, "text": words for the player}. Codes used here:
## "no_anchor", "unknown_rune", "no_node", "self", "already_linked", "not_linked", "anchor",
## "capacity"; rule sets add their own.
##
## describe_link -> {"kind", "label", "colour" (a key the screen maps to a colour), "flags": [...],
##                   "text"}
## describe_node -> {"sockets" (how many links it can take; -1 = no limit), "used", "badges": [...]}
## word_state    -> {"closed": bool, "label", "problems": [...], "lines": [...]}
## effects       -> {} for now: what the word does to its skill.

const LOCKED := {"ok": false, "reason": "locked", "text": "The word is sealed. It can be reworked when the next seal is formed."}

var id := ""
var params: Dictionary = {}
var interactions: Array[RuneInteraction] = []


## Called by Runes.make with the rule set's id and its entry in runes.json "rule_sets".
func setup(rule_id: String, p: Dictionary) -> void:
	id = rule_id
	params = p
	interactions.clear()
	var extra: Dictionary = p.get("interaction_params", {})
	for iid: Variant in p.get("interactions", []):
		var path := "res://scripts/runes/interactions/%s.gd" % str(iid)
		if not ResourceLoader.exists(path):
			push_error("RuneRules: no interaction script %s" % path)
			continue
		var it: RuneInteraction = (load(path) as GDScript).new()
		it.setup(self, str(iid), extra.get(str(iid), {}))
		interactions.append(it)


## A short name for the rule set, shown on the screen.
func title() -> String:
	return str(params.get("title", id))


## Lines the screen shows under the word: what these rules do and do not decide yet.
func notes() -> Array[String]:
	var out: Array[String] = []
	for n: Variant in params.get("notes", []):
		out.append(str(n))
	return out


## Colour keys this rule set uses for links, with what each means: [{"colour", "label"}].
func legend() -> Array[Dictionary]:
	return []


## How many runes the skill may hold (-1 = no limit).
func capacity(_ctx: RuneContext) -> int:
	return -1


## How many runes of the word count against capacity.
func used(word: Dictionary, _ctx: RuneContext) -> int:
	return RuneWord.size(word)


# --- checks (structural first, then the rule set, then interactions) -----------------------

## May `rune_id` be set into the word - joined to `to_node` when that is >= 0, on ring `ring` when
## that is >= 0 (otherwise the rule set places it: place_ring)? The answer carries "ring": where it
## would go.
func can_add(word: Dictionary, rune_id: String, ctx: RuneContext, to_node: int = -1, ring: int = -1) -> Dictionary:
	var r: Dictionary
	if RuneWord.size(word) == 0:
		r = no("no_anchor", "This skill has no anchor rune in the data yet.")
	elif RuneWord.is_locked(word):
		r = LOCKED.duplicate()
	elif GameData.rune(rune_id).is_empty():
		r = no("unknown_rune", "There is no rune '%s'." % rune_id)
	elif to_node >= 0 and not RuneWord.has_node(word, to_node):
		r = no("no_node", "There is no such rune in the word.")
	elif capacity(ctx) >= 0 and used(word, ctx) + 1 > capacity(ctx):
		r = no("capacity", full_text(ctx))
	else:
		var k: int = place_ring(word, ctx, to_node, ring)
		r = _can_add(word, rune_id, ctx, to_node, k)
		r["ring"] = k
	for it: RuneInteraction in interactions:
		it.on_can_add(word, rune_id, ctx, to_node, r)
	return r


## Why the word can take no more runes.
func full_text(ctx: RuneContext) -> String:
	return "The word is full: this skill holds %d runes at level %d." % [capacity(ctx), ctx.stage]


## Which ring a new rune goes on: `ring` if given, else one further out than the rune it joins,
## else ring 1. Rule sets with rings of their own (RingRules) choose by room.
func place_ring(word: Dictionary, _ctx: RuneContext, to_node: int, ring: int) -> int:
	if ring >= 0:
		return ring
	return RuneWord.ring(word, to_node) + 1 if to_node >= 0 else 1


func can_link(word: Dictionary, a: int, b: int, ctx: RuneContext) -> Dictionary:
	var r: Dictionary
	if RuneWord.is_locked(word):
		r = LOCKED.duplicate()
	elif not RuneWord.has_node(word, a) or not RuneWord.has_node(word, b):
		r = no("no_node", "There is no such rune in the word.")
	elif a == b:
		r = no("self", "A rune cannot be joined to itself.")
	elif RuneWord.linked(word, a, b):
		r = no("already_linked", "%s and %s are already joined." % [rune_name(word, a), rune_name(word, b)])
	else:
		r = _can_link(word, a, b, ctx)
	for it: RuneInteraction in interactions:
		it.on_can_link(word, a, b, ctx, r)
	return r


func can_unlink(word: Dictionary, a: int, b: int, _ctx: RuneContext) -> Dictionary:
	if RuneWord.is_locked(word):
		return LOCKED.duplicate()
	return ok() if RuneWord.linked(word, a, b) else no("not_linked", "Those two runes are not joined.")


func can_remove(word: Dictionary, i: int, _ctx: RuneContext) -> Dictionary:
	if RuneWord.is_locked(word):
		return LOCKED.duplicate()
	if i == 0:
		return no("anchor", "The skill is built on this rune; it cannot be taken out.")
	return ok() if RuneWord.has_node(word, i) else no("no_node", "There is no such rune in the word.")


# --- changes (check, then change the word only if allowed) ------------------------------

## Add a rune, joined to `to_node` when that is >= 0 (the link must be allowed too).
func add(word: Dictionary, rune_id: String, ctx: RuneContext, to_node: int = -1, ring: int = -1) -> Dictionary:
	var r: Dictionary = can_add(word, rune_id, ctx, to_node, ring)
	if bool(r["ok"]):
		var i: int = RuneWord.add_node(word, rune_id, int(r.get("ring", -1)))
		r["node"] = i
		if to_node >= 0:
			RuneWord.add_link(word, to_node, i, link_data(word, to_node, i, ctx))
	return r


func link(word: Dictionary, a: int, b: int, ctx: RuneContext) -> Dictionary:
	var r: Dictionary = can_link(word, a, b, ctx)
	if bool(r["ok"]):
		RuneWord.add_link(word, a, b, link_data(word, a, b, ctx))
	return r


func unlink(word: Dictionary, a: int, b: int, ctx: RuneContext) -> Dictionary:
	var r: Dictionary = can_unlink(word, a, b, ctx)
	if bool(r["ok"]):
		RuneWord.remove_link(word, a, b)
	return r


## Join two runes, or part them if they are joined.
func toggle_link(word: Dictionary, a: int, b: int, ctx: RuneContext) -> Dictionary:
	return unlink(word, a, b, ctx) if RuneWord.linked(word, a, b) else link(word, a, b, ctx)


func remove(word: Dictionary, i: int, ctx: RuneContext) -> Dictionary:
	var r: Dictionary = can_remove(word, i, ctx)
	if bool(r["ok"]):
		RuneWord.remove_node(word, i)
	return r


# --- locking -----------------------------------------------------------------------------
# A locked word is the one its skill uses: only a locked word's effects reach the skill (and,
# when the rule set says so, only a closed word can be locked). A locked word cannot be changed.

func can_lock(word: Dictionary, ctx: RuneContext) -> Dictionary:
	if RuneWord.size(word) < 2:
		return no("empty", "Set runes into the word before locking it.")
	if RuneWord.is_locked(word):
		return no("locked", "The word is already locked.")
	var st: Dictionary = word_state(word, ctx)
	if not (st.get("problems", []) as Array).is_empty():
		return no("problems", "The word breaks these rules: %s" % str((st["problems"] as Array)[0]))
	if bool(params.get("lock_needs_closed", true)) and not bool(st.get("closed", false)):
		return no("not_closed", "Only a closed word can be locked; this one is %s." % str(st.get("label", "open")))
	return ok()


func lock(word: Dictionary, ctx: RuneContext) -> Dictionary:
	var r: Dictionary = can_lock(word, ctx)
	if bool(r["ok"]):
		word["locked"] = true
	return r


## Unlocking is free for now (Brent has not ruled on a cost).
func unlock(word: Dictionary, _ctx: RuneContext) -> Dictionary:
	if not RuneWord.is_locked(word):
		return no("not_locked", "The word is not locked.")
	word.erase("locked")
	return ok()


## What a word does to its skill now: its effects if it is sealed (or locked, from before seals)
## and still fits the rules in force (a word made under other rules that no longer does fit does
## nothing), else {}. A seal made by a test hook with closure waived need not be closed.
func locked_effects(word: Dictionary, ctx: RuneContext) -> Dictionary:
	if not RuneWord.is_locked(word):
		return {}
	var st: Dictionary = word_state(word, ctx)
	if not (st.get("problems", []) as Array).is_empty():
		return {}
	if _needs_closed() and not bool(st.get("closed", false)) and not bool(word.get("closure_waived", false)):
		return {}
	return effects(word, ctx)


func _needs_closed() -> bool:
	return bool(params.get("seal_needs_closed", params.get("lock_needs_closed", true)))


# --- seals (design/14 section 8) -----------------------------------------------------------
# A seal is formed when a construct is bound into the skill (Player.bind_seal): the draft the player
# built (a copy of the sealed word, reworked, with the new ring added) becomes the skill's word.
# Test hooks (ctx.closure_waived) may seal a word that is not closed; no screen reaches them.

## May this draft be sealed? Closed and free of problems (closure waived: free of problems).
func can_seal(word: Dictionary, ctx: RuneContext) -> Dictionary:
	if RuneWord.size(word) == 0:
		return no("no_anchor", "This skill has no anchor rune in the data yet.")
	var st: Dictionary = word_state(word, ctx)
	if not (st.get("problems", []) as Array).is_empty():
		return no("problems", "The seal breaks these rules: %s" % str((st["problems"] as Array)[0]))
	if RuneWord.size(word) < 2:
		return no("empty", "Set runes into the seal first.")
	if _needs_closed() and not ctx.closure_waived and not bool(st.get("closed", false)):
		return no("not_closed", "Only a closed word can be sealed; this one is %s." % str(st.get("label", "open")))
	return ok()


## Seal the draft through `rings` rings (the skill's level after the binding).
func seal(word: Dictionary, ctx: RuneContext, rings: int) -> Dictionary:
	var r: Dictionary = can_seal(word, ctx)
	if bool(r["ok"]):
		word["sealed"] = maxi(1, rings)
		word.erase("locked")
		if ctx.closure_waived:
			word["closure_waived"] = true
		else:
			word.erase("closure_waived")
		word.erase("free_edit")
	return r


# --- descriptions (the rule set's answer, then interactions) -------------------------------

func link_data(word: Dictionary, a: int, b: int, ctx: RuneContext) -> Dictionary:
	var d: Dictionary = _link_data(word, a, b, ctx)
	for it: RuneInteraction in interactions:
		it.on_link_data(word, a, b, ctx, d)
	return d


func describe_link(word: Dictionary, a: int, b: int, ctx: RuneContext) -> Dictionary:
	var d: Dictionary = {"kind": "link", "label": "", "colour": "plain", "flags": [], "text": ""}
	d.merge(_describe_link(word, a, b, ctx), true)
	for it: RuneInteraction in interactions:
		it.on_describe_link(word, a, b, ctx, d)
	return d


func describe_node(word: Dictionary, i: int, ctx: RuneContext) -> Dictionary:
	var d: Dictionary = {"sockets": -1, "used": RuneWord.degree(word, i), "badges": []}
	d.merge(_describe_node(word, i, ctx), true)
	for it: RuneInteraction in interactions:
		it.on_describe_node(word, i, ctx, d)
	return d


## A rune before it is set (the palette): {"sockets" (-1 = no limit), "lines": [what the rules
## say about it]}.
func describe_rune(rune_id: String, ctx: RuneContext) -> Dictionary:
	var d: Dictionary = {"sockets": -1, "lines": []}
	d.merge(_describe_rune(rune_id, ctx), true)
	for it: RuneInteraction in interactions:
		it.on_describe_rune(rune_id, ctx, d)
	return d


func word_state(word: Dictionary, ctx: RuneContext) -> Dictionary:
	var s: Dictionary = {"closed": false, "label": "", "problems": [], "lines": []}
	if RuneWord.size(word) == 0:
		(s["problems"] as Array).append("This skill has no anchor rune in the data yet.")
	else:
		var cap: int = capacity(ctx)
		if cap >= 0 and used(word, ctx) > cap:
			(s["problems"] as Array).append("It holds %d runes; the skill has room for %d." % [used(word, ctx), cap])
		var own: Dictionary = _word_state(word, ctx)
		for key: String in own:
			if key == "problems" or key == "lines":
				(s[key] as Array).append_array(own[key])
			else:
				s[key] = own[key]
		if not (s["problems"] as Array).is_empty():
			s["closed"] = false          # a word with problems cannot be written, whatever its shape
	for it: RuneInteraction in interactions:
		it.on_word_state(word, ctx, s)
	return s


## What the word does to its skill. Empty: no rule set changes a skill's numbers yet.
func effects(word: Dictionary, ctx: RuneContext) -> Dictionary:
	var e: Dictionary = _effects(word, ctx)
	for it: RuneInteraction in interactions:
		it.on_effects(word, ctx, e)
	return e


# --- the stat groups, for whatever else scales a skill by them (an ascension boost) ----------------

## The patch that multiplies each stat group in `groups` ({group: multiplier}) in this skill, from
## the first interaction that reads stat groups; [] under rules with none.
func group_patch(ab: Dictionary, groups: Dictionary) -> Array:
	for it: RuneInteraction in interactions:
		if it.has_method("group_patch"):
			return it.call("group_patch", ab, groups)
	return []


## Whether stat group `g` reaches anything in this skill (false under rules with no stat groups).
func group_acts(ab: Dictionary, g: String) -> bool:
	for it: RuneInteraction in interactions:
		if it.has_method("group_acts"):
			return bool(it.call("group_acts", ab, g))
	return false


## The stat groups a field path of this skill belongs to.
func groups_of_path(ab: Dictionary, path: String) -> Array[String]:
	for it: RuneInteraction in interactions:
		if it.has_method("groups_of_path"):
			var out: Array[String] = []
			out.assign(it.call("groups_of_path", ab, path))
			return out
	return []


## The skill's before/after field list ([{path, group, label, unit, lower_is_better, ...}]).
func fields_of(ab: Dictionary) -> Array:
	for it: RuneInteraction in interactions:
		if it.has_method("fields_of"):
			return it.call("fields_of", ab)
	return []


# --- overridden by a rule set ---------------------------------------------------------------

func _can_add(_word: Dictionary, _rune_id: String, _ctx: RuneContext, _to_node: int, _ring: int) -> Dictionary:
	return ok()


func _can_link(_word: Dictionary, _a: int, _b: int, _ctx: RuneContext) -> Dictionary:
	return ok()


func _link_data(_word: Dictionary, _a: int, _b: int, _ctx: RuneContext) -> Dictionary:
	return {}


func _describe_link(_word: Dictionary, _a: int, _b: int, _ctx: RuneContext) -> Dictionary:
	return {}


func _describe_node(_word: Dictionary, _i: int, _ctx: RuneContext) -> Dictionary:
	return {}


func _describe_rune(_rune_id: String, _ctx: RuneContext) -> Dictionary:
	return {}


## Must set "closed" and "label"; may add "problems" and "lines".
func _word_state(word: Dictionary, _ctx: RuneContext) -> Dictionary:
	var one: bool = RuneWord.is_joined(word)
	return {"closed": one and RuneWord.size(word) > 1, "label": "joined" if one else "not all joined"}


func _effects(_word: Dictionary, _ctx: RuneContext) -> Dictionary:
	return {}


# --- helpers ----------------------------------------------------------------------------

static func ok() -> Dictionary:
	return {"ok": true, "reason": "", "text": ""}


static func no(reason: String, text: String) -> Dictionary:
	return {"ok": false, "reason": reason, "text": text}


static func rune_name(word: Dictionary, i: int) -> String:
	var rid: String = RuneWord.node_id(word, i)
	return str(GameData.rune(rid).get("name", rid))
