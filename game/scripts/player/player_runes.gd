class_name PlayerRunes
extends RefCounted
## The player's part for runes, seals, keystones and constructs: a skill's numbers through its word, the level lock and its draft, rune discovery.
## A part of the player (scripts/player.gd), split out by concern: it holds this concern's logic and its
## private state; everything shared or saved stays on the player, reached through `player`.
## Map and pattern: docs/architecture/player-split.md.

## The rune engine's path helpers (get_path_value, is_numeric), shared so a patch and a preview read paths alike.
const _Fx := preload("res://scripts/runes/interactions/effects_v1.gd")

var player: Player


func _init(of: Player) -> void:
	player = of


## An ability's numbers after its sealed word has shaped it: the runes and, folded in with them, the
## keystone set over each sealed ring - the construct bound at that lock, whose concept now reaches the
## skill only through the word (Brent 2026-10-24, design/14 section 12; RingRules.keystone_effect).
## The state's "bound" list is a record of the binds and changes nothing here, so a concept is never
## counted twice. `draft_word` (code and previews only): use that word's effects as if it were sealed.
func ability_stats(state: Dictionary, draft_word: Dictionary = {}) -> Dictionary:
	var ab: Dictionary = GameData.ability(str(state["id"])).duplicate(true)      # deep: payloads are changed below
	if ab.is_empty():
		return ab
	ab["damage_all"] = 1.0
	# the sealed word reshapes the skill (design/14 sections 7 and 12; the rule set's effects patch)
	if not draft_word.is_empty():
		apply_rune_patch(ab, Runes.active().effects(draft_word, RuneContext.of(state, player.affinities)).get("patch", []))
	elif state.has("word"):
		apply_rune_patch(ab, Runes.active().locked_effects(state["word"], RuneContext.of(state, player.affinities)).get("patch", []))
	# ascension boosts (Brent 2026-10-24) come AFTER the word: the word's patch can SET a field (the
	# default recovery, a status time) that a boost laid first would lose, and a boost should also
	# reach what the word added. Not levelling: stage and bar are untouched.
	_apply_ascension(ab, state)
	ab["cost"] = float(ab["cost"]) * player.inventory.stat("cost_mult", true)
	return ab


## A skill state's ascension totals onto its numbers as they stand (Ascension.patch).
static func _apply_ascension(ab: Dictionary, state: Dictionary) -> void:
	if state.has("ascension"):
		apply_rune_patch(ab, Ascension.patch(ab, state["ascension"]))


## Apply a rune effects patch to an ability dictionary, op by op: {op, path ("a.b" for nested), value}.
## mul / mul_round / min only touch numbers that are there; add, set and append create what they
## need. The patch format is the rule sets' (RuneInteraction.on_effects); nothing here knows runes.
static func apply_rune_patch(ab: Dictionary, patch: Array) -> void:
	for p: Dictionary in patch:
		var keys: PackedStringArray = str(p.get("path", "")).split(".")
		var last: String = keys[keys.size() - 1]
		var make: bool = str(p["op"]) in ["add", "set", "append", "max"]
		var ok := true
		var walk: Variant = ab
		for k: int in keys.size() - 1:
			if typeof(walk) == TYPE_ARRAY:
				# a list of {id, ...} (a payload's statuses) is walked by id: on_hit.statuses.dosed.stacks
				var found: Variant = null
				for entry: Variant in walk:
					if typeof(entry) == TYPE_DICTIONARY and str((entry as Dictionary).get("id", "")) == keys[k]:
						found = entry
						break
				if found == null:
					ok = false
					break
				walk = found
				continue
			var hd: Dictionary = walk
			if not hd.has(keys[k]) or (typeof(hd[keys[k]]) != TYPE_DICTIONARY and typeof(hd[keys[k]]) != TYPE_ARRAY):
				if not make:
					ok = false
					break
				hd[keys[k]] = {}
			walk = hd[keys[k]]
		if not ok or typeof(walk) != TYPE_DICTIONARY:
			continue
		var holder: Dictionary = walk
		var cur: Variant = holder.get(last)
		var is_num: bool = typeof(cur) == TYPE_FLOAT or typeof(cur) == TYPE_INT
		match str(p["op"]):
			"mul":
				if is_num:
					holder[last] = float(cur) * float(p["value"])
				elif _Fx.is_numeric(cur):
					var scaled: Array = []
					for x: Variant in cur:
						scaled.append(float(x) * float(p["value"]))
					holder[last] = scaled
			"mul_round":
				if is_num:
					holder[last] = int(round(float(cur) * float(p["value"])))
			"mul_gap":
				# a multiplier's distance from 1 scales: 0.75 at x1.2 is 0.70, 1.4 at x1.2 is 1.48
				if is_num:
					holder[last] = 1.0 + (float(cur) - 1.0) * float(p["value"])
			"min":
				if is_num:
					holder[last] = minf(float(cur), float(p["value"]))
			"max":
				# the larger of what is there and the value (creates it when absent)
				holder[last] = maxf(float(cur), float(p["value"])) if is_num else float(p["value"])
			"add":
				if typeof(p["value"]) == TYPE_INT and (cur == null or typeof(cur) == TYPE_INT):
					holder[last] = (int(cur) if cur != null else 0) + int(p["value"])
				else:
					holder[last] = (float(cur) if is_num else 0.0) + float(p["value"])
			"set":
				holder[last] = p["value"]
			"erase":
				holder.erase(last)
			"append":
				if typeof(cur) != TYPE_ARRAY:
					holder[last] = []
				(holder[last] as Array).append(p["value"])


## What setting a construct of `concept` over the forming ring as its keystone would change, for
## showing before the (irreversible) bind: [{"label", "before", "after", "better"}], numbers already
## formatted. The keystone and the stage step: the level lock's word (the draft while it is open, else
## the sealed word) without the keystone and with it, so the runes' own changes are in neither side.
func preview_bind(state: Dictionary, concept: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var index: int = player.abilities.find(state)
	var stage: int = int(state["stage"])
	var base: Dictionary = (player.seal_draft["word"] as Dictionary).duplicate(true) if index >= 0 and index == sealing_index() \
		else (_sealed_word(index) if index >= 0 else RuneWord.make(GameData.skill_anchor(str(state["id"])))).duplicate(true)
	var trial: Dictionary = state.duplicate(true)
	trial["stage"] = stage + 1
	var tier: String = GameData.tier_for_stage(stage)
	var now: Dictionary = ability_stats(trial, base)
	var then: Dictionary = ability_stats(trial, RuneWord.with_keystone(base, stage + 1, tier, concept))
	if now.is_empty():
		return out
	var strike: float = float(player._p["melee_damage"]) * player.economy_part.weapon_stat("melee_damage_mult", true)
	# the stage step comes with every keystone: the damage rows carry it too
	var mult_now: float = player.ability_damage_mult(stage) * float(now.get("damage_all", 1.0))
	var mult_then: float = player.ability_damage_mult(stage + 1) * float(then.get("damage_all", 1.0))
	out.append({"label": "Stage", "before": str(stage), "after": str(stage + 1), "better": true})
	if now.has("damage"):
		_preview_row(out, "Damage", float(now["damage"]) * mult_now, float(then["damage"]) * mult_then, "%d", true)
	if now.has("damage_mult"):
		_preview_row(out, "Damage per target", strike * float(now["damage_mult"]) * mult_now, strike * float(then["damage_mult"]) * mult_then, "%d", true)
	if now.has("speed"):
		_preview_row(out, "Bolt speed", float(now["speed"]), float(then["speed"]), "%d", true)
		_preview_row(out, "Range", float(now["speed"]) * float(now["life"]), float(then["speed"]) * float(then["life"]), "%d m", true)
	if now.has("reach_bonus"):
		_preview_row(out, "Reach", player.melee_range + float(now["reach_bonus"]), player.melee_range + float(then["reach_bonus"]), "%.1f m", true)
	if now.has("range"):
		_preview_row(out, "Range", float(now["range"]), float(then["range"]), "%.1f m", true)
	for part: String in ["on_hit", "on_pass", "on_arrive", "on_rise"]:
		if now.has(part) and (now[part] as Dictionary).has("shove"):
			_preview_row(out, "Shove", float((now[part] as Dictionary)["shove"]), float((then[part] as Dictionary)["shove"]), "%.1f m", true)
	if str(now.get("kind", "")) == "prop":
		_preview_row(out, "Stone stands for", float(now["life"]), float(then["life"]), "%d s", true)
	if now.has("dash_speed"):
		_preview_row(out, "Dash distance", float(now["dash_speed"]) * float(now["dash_time"]), float(then["dash_speed"]) * float(then["dash_time"]), "%.1f m", true)
		_preview_row(out, "Dash speed", float(now["dash_speed"]), float(then["dash_speed"]), "%d", true)
	if now.has("self_harm"):
		_preview_row(out, "Harm to yourself", float(now["self_harm"]), float(then["self_harm"]), "%.1f", false)
	_preview_row(out, "Essence cost", float(now["cost"]), float(then["cost"]), "%d", false)
	_preview_row(out, "Reflux left behind", float(now["cost"]) * float(now["reflux_per_cost"]), float(then["cost"]) * float(then["reflux_per_cost"]), "%d", false)
	return out


## Add a row only when the number actually moves. `more_is_better` decides its colour.
func _preview_row(out: Array[Dictionary], label: String, before: float, after: float, fmt: String, more_is_better: bool) -> void:
	var a: String = fmt % ([int(round(before))] if fmt.begins_with("%d") else [before])
	var b: String = fmt % ([int(round(after))] if fmt.begins_with("%d") else [after])
	if a == b:
		return
	out.append({"label": label, "before": a, "after": b, "better": (after > before) == more_is_better})


## The carried constructs grouped by tier and word, in carried order: [{tier, concept (the word id),
## count, index (the first one carried), text ("vestige of Flood x3"), fits, why (when it does not fit,
## the reason - Brent 2026-11-04: a word with an affinity rune fits only where that rune could be set,
## can_use_rune)}], optionally of one tier only.
func construct_groups(tier: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var at: Dictionary = {}
	for i: int in player.constructs.size():
		var c: Dictionary = player.constructs[i]
		if tier != "" and str(c["tier"]) != tier:
			continue
		var key: String = "%s|%s" % [c["tier"], c["concept"]]
		if at.has(key):
			out[int(at[key])]["count"] = int(out[int(at[key])]["count"]) + 1
		else:
			at[key] = out.size()
			out.append({"tier": str(c["tier"]), "concept": str(c["concept"]), "count": 1, "index": i})
	for g: Dictionary in out:
		g["text"] = "%s%s" % [ConstructWords.phrase(str(g["tier"]), str(g["concept"])), (" x%d" % int(g["count"])) if int(g["count"]) > 1 else ""]
		var f: Dictionary = construct_fits(str(g["tier"]), str(g["concept"]))
		g["fits"] = bool(f["ok"])
		g["why"] = "" if bool(f["ok"]) else str(f["text"])
	return out


## Whether a construct carrying word `concept` fits this character's skills (Brent 2026-11-04,
## design/14 section 14): every rune of it one this character may set (can_use_rune - its universal
## runes always, an affinity's only when the affinity is held). {ok, reason, text}.
func construct_fits(tier: String, concept: String) -> Dictionary:
	return ConstructWords.fits(tier, concept, player.affinities)


## How many carried constructs of `tier` fit, and how many do not: {fit, unfit}.
func construct_fit_counts(tier: String) -> Dictionary:
	var out: Dictionary = {"fit": 0, "unfit": 0}
	for g: Dictionary in construct_groups(tier):
		out["fit" if bool(g["fits"]) else "unfit"] = int(out["fit" if bool(g["fits"]) else "unfit"]) + int(g["count"])
	return out


## Bind a carried construct into an ability. Irreversible; can fail, and failure hurts
## (Brent 2026-09-23). `roll` < 0 means roll randomly (tests pass a fixed roll).
## The bind's own arithmetic, with no seal: only bind_seal calls it in the game (Brent 2026-10-23:
## "No binding the constructs on the main page, only with the runes"); the self-test calls it to
## check the roll, the wound and the concept. The leading underscore says: not an entry point.
func _bind_construct(ability_index: int, construct_index: int, roll: float = -1.0) -> String:
	if ability_index < 0 or ability_index >= player.abilities.size() or construct_index < 0 or construct_index >= player.constructs.size():
		return "nothing to bind"
	var state: Dictionary = player.abilities[ability_index]
	var con: Dictionary = player.constructs[construct_index]
	var need: String = player.pending_tier(state)
	if need == "":
		return "not ready"
	if need != str(con["tier"]):
		return "needs a %s" % need
	player.constructs.remove_at(construct_index)
	var r: float = player.rng.randf() if roll < 0.0 else roll
	var ab_name: String = str(GameData.ability(str(state["id"])).get("name", "?"))
	var label: String = ConstructWords.label(str(con["tier"]), str(con["concept"]))
	if r >= GameData.num("binding", "success_chance"):
		var burn_wound: Dictionary = GameData.balance["wounds"]["bind_fail"]
		player._wound_seq += 1
		player.take_wound("bind_%d" % player._wound_seq, str(burn_wound["name"]), float(burn_wound["sink"]), float(burn_wound["cut"]))
		player.note("The %s of %s tears free. The bind fails and it is gone." % [con["tier"], label])
		player._check_death()
		return "failed"
	# a record of the bind only: the concept reaches the skill as the keystone the seal sets over its
	# ring (bind_seal; RingRules.keystone_effect), never from this list
	var bound: Array = state.get("bound", [])
	bound.append({"stage": int(state["stage"]), "tier": con["tier"], "concept": con["concept"]})
	state["bound"] = bound
	state["stage"] = int(state["stage"]) + 1
	state["progress"] = 0.0
	player.note("%s binds a %s of %s. Now stage %d." % [ab_name, con["tier"], label, int(state["stage"])])
	return "bound"


# --- rune words and seals (design/14 sections 7-8, 11) ---------------------------------------
# A skill's word is saved on its ability state as "word" (RuneWord: nodes on rings + links, no rules
# in it). Brent 2026-10-23: a skill just levels until its bar is full; binding a construct into it
# is when its runes are SEALED, one ring per level. Before the first binding a skill has no word.
# Brent 2026-10-23 (later): "the binding of the constructs should come with each level lock ...
# The levels all LOCK together. No binding the constructs on the main page, only with the runes."
# A level lock is one act on the seal screen: the forming ring is built, the construct of the right
# tier is chosen there, and the bind locks ring and construct together. The draft (seal_draft) is a
# copy of the sealed word - inner rings may be reworked - and becomes the skill's word only if the
# bind takes; a failed bind changes nothing in the word. Rings are built from the skill outward by
# level: ring k takes runes only from the level-k lock on.
# Brent 2026-10-24 (design/14 section 12): "Then a vestige is placed over the top with its effect
# being worth more than a regular rune...and that locks the level ... You have to be able to lock the
# current level (have a proper construct for it) before you can reform." So the lock opens only when
# the bar is full AND a construct of the tier is carried (can_open_seal), and the chosen construct is
# the keystone set over the forming ring (seal_keystone).
# Brent 2026-11-03 reversed the rest of that day's ruling ("Every slot should be filled to be fully
# formed ... Its all or nothing at each level") and the closed-word rule: "Forcing all valence to be
# filled is not right. Also, forcing the ring to be complete is wrong. let them bind and close no
# matter what." So the bind needs only the keystone chosen and no hard rule broken (RuneRules.
# can_seal: a rune over its valence, refused affinities, bonds across rings that do not touch, a ring
# over its room, runes on a ring the skill lacks). Open bonds, empty places, runes joined to nothing
# and a new ring with no rune at all are allowed (bond_v2 seal_needs_closed / seal_needs_full_rings
# false). It locks all of it - or, if the roll fails, nothing. Test characters follow the same rule.
# A skill from an older save loads as it is, and its next lock starts from what it has.
# Whether a change is allowed, and what the word is, is asked of the rule set in force
# (Runes.active()).

## What the rule set may know about ability `index` - the draft's context while it is being sealed.
func rune_context(index: int) -> RuneContext:
	if index < 0 or index >= player.abilities.size():
		return RuneContext.of({}, player.affinities)
	var drafting: bool = sealing_index() == index
	return RuneContext.of(player.abilities[index], player.affinities, drafting and seal_mode() == "bind")


## The word of ability `index`: the draft while it is being sealed, else its sealed word, else a word
## holding just the skill's own rune (no word yet).
func ability_word(index: int) -> Dictionary:
	if index < 0 or index >= player.abilities.size():
		return RuneWord.make("")
	if sealing_index() == index:
		return player.seal_draft["word"]
	return _sealed_word(index)


## The skill's own word, never the draft.
func _sealed_word(index: int) -> Dictionary:
	var st: Dictionary = player.abilities[index]
	if st.has("word"):
		return st["word"]
	return RuneWord.make(GameData.skill_anchor(str(st["id"])), Runes.active().id)


## The ability being sealed (-1: none).
func sealing_index() -> int:
	return int(player.seal_draft.get("index", -1)) if not player.seal_draft.is_empty() else -1


## "bind" while a level lock is being drafted, else "".
func seal_mode() -> String:
	return str(player.seal_draft.get("mode", ""))


## The construct the level lock will bind (-1: none chosen - none of the tier is carried).
func seal_construct() -> int:
	return int(player.seal_draft.get("construct", -1))


## A fresh draft of ability `index`: its sealed word, unsealed, its rings made explicit and every
## rune given its place on its ring (so nothing moves when bonds change).
func _draft_from(index: int) -> Dictionary:
	var w: Dictionary = _sealed_word(index).duplicate(true)
	for key: String in ["sealed", "locked", "free_edit", "closure_waived"]:
		w.erase(key)
	w["rings"] = RuneWord.rings(w)
	w["made_under"] = Runes.active().id
	_pin_places(w, rune_context(index))
	return w


## Give every rune of a word a place on its ring (the ones it has are kept).
static func _pin_places(word: Dictionary, ctx: RuneContext) -> void:
	word["places"] = RuneWord.layout_places(word, Runes.place_counts(word, ctx))


# --- the draft's history (Ctrl+Z / Ctrl+Y on the seal screen) ---------------------------------
# Every change to the draft that the rules allow is a step; undo puts the draft back as it was before
# the last step, redo puts the step back. The history lives with the draft and goes when it closes:
# nothing is committed until the bind.

const DRAFT_HISTORY_MAX := 200


## Keep the draft as it is now, before a change (call _changed after the change took).
func _before_change() -> Dictionary:
	return (player.seal_draft["word"] as Dictionary).duplicate(true)


func _changed(before: Dictionary) -> void:
	var undo: Array = player.seal_draft.get("undo", [])
	undo.append(before)
	if undo.size() > DRAFT_HISTORY_MAX:
		undo.pop_front()
	player.seal_draft["undo"] = undo
	player.seal_draft["redo"] = []
	_pin_places(player.seal_draft["word"], rune_context(sealing_index()))


func can_undo() -> bool:
	return not player.seal_draft.is_empty() and not (player.seal_draft.get("undo", []) as Array).is_empty()


func can_redo() -> bool:
	return not player.seal_draft.is_empty() and not (player.seal_draft.get("redo", []) as Array).is_empty()


## Step the draft back. Returns false if there is nothing to undo.
func draft_undo() -> bool:
	if not can_undo():
		return false
	var redo: Array = player.seal_draft.get("redo", [])
	redo.append((player.seal_draft["word"] as Dictionary).duplicate(true))
	player.seal_draft["redo"] = redo
	player.seal_draft["word"] = (player.seal_draft["undo"] as Array).pop_back()
	return true


## Step the draft forward again. Returns false if there is nothing to redo.
func draft_redo() -> bool:
	if not can_redo():
		return false
	var undo: Array = player.seal_draft.get("undo", [])
	undo.append((player.seal_draft["word"] as Dictionary).duplicate(true))
	player.seal_draft["undo"] = undo
	player.seal_draft["word"] = (player.seal_draft["redo"] as Array).pop_back()
	return true


## May ability `index`'s next level lock be opened? Only with its bar full AND a construct of the
## tier carried (Brent 2026-10-24: "You have to be able to lock the current level (have a proper
## construct for it) before you can reform"). Since Brent 2026-11-04 the construct must also FIT the
## skill (its word's runes ones this character may set, construct_fits): one that does not, does not
## count. {ok, reason ("no_skill", "at_cap", "bar", "no_construct", "no_fit"), text (what is missing,
## for the main page), tier, stage}.
func can_open_seal(index: int) -> Dictionary:
	if index < 0 or index >= player.abilities.size():
		return RuneRules.no("no_skill", "No such skill.")
	var st: Dictionary = player.abilities[index]
	var stage: int = int(st["stage"])
	var tier: String = GameData.tier_for_stage(stage)
	var r: Dictionary = RuneRules.ok()
	var counts: Dictionary = construct_fit_counts(tier) if tier != "" else {"fit": 0, "unfit": 0}
	if stage >= player.stars + 1 or tier == "":
		r = RuneRules.no("at_cap", "Level %d is as far as it goes at %d star%s: no lock is left until you ascend." % [stage, player.stars, "" if player.stars == 1 else "s"])
	elif float(st["progress"]) < 100.0:
		r = RuneRules.no("bar", "Its level %d lock needs its bar full first (%d%%): it fills as you use the skill." % [stage + 1, int(float(st["progress"]))])
	elif int(counts["fit"]) == 0 and int(counts["unfit"]) > 0:
		var first: Dictionary = construct_groups(tier)[0]
		r = RuneRules.no("no_fit", "The bar is full, but its level %d lock needs a %s that fits, and the %d you carry do%s not. %s Subdue one of your own affinities, or a universal one." % [
			stage + 1, tier, int(counts["unfit"]), "es" if int(counts["unfit"]) == 1 else "", str(first["why"])])
	elif int(counts["fit"]) == 0:
		r = RuneRules.no("no_construct", "The bar is full, but its level %d lock needs a %s and you carry none: subdue one in the Netherecho, then open the seal." % [stage + 1, tier])
	r["tier"] = tier
	r["stage"] = stage
	return r


## Open the next level lock of ability `index`: its bar full and a construct of the tier carried
## (can_open_seal), else it does not open. The draft starts as the sealed word, with room for the next
## ring. The keystone - which carried construct this lock binds - is chosen on the seal screen
## (choose_seal_construct); `construct_index` >= 0 chooses it at once (code and tests). Returns
## {ok, reason, text}.
func open_seal(index: int, construct_index: int = -1) -> Dictionary:
	var can: Dictionary = can_open_seal(index)
	if not bool(can["ok"]):
		return can
	var need: String = str(can["tier"])
	var ci: int = construct_index
	if ci >= 0 and (ci >= player.constructs.size() or str(player.constructs[ci]["tier"]) != need):
		return RuneRules.no("wrong_tier", "It needs a %s." % need)
	if ci >= 0 and not bool(construct_fits(need, str(player.constructs[ci]["concept"]))["ok"]):
		return RuneRules.no("unfit", str(construct_fits(need, str(player.constructs[ci]["concept"]))["text"]))
	player.seal_draft = {"index": index, "construct": ci, "mode": "bind", "word": _draft_from(index)}
	return RuneRules.ok()


## The keystone this level lock will set over its forming ring: {ring, tier, concept, construct,
## set (it sits over the ring - at once since Brent 2026-11-03; only with seal_needs_full_rings does it
## wait for every ring up to it to be full), label}; {} when none is chosen yet.
func seal_keystone() -> Dictionary:
	var c: int = seal_construct()
	if seal_mode() != "bind" or c < 0 or c >= player.constructs.size():
		return {}
	var ctx: RuneContext = rune_context(sealing_index())
	var rr: RingRules = Runes.active() as RingRules
	var con: Dictionary = player.constructs[c]
	return {"ring": ctx.forming, "tier": str(con["tier"]), "concept": str(con["concept"]), "construct": c,
		"set": rr == null or rr.first_unformed(player.seal_draft["word"], ctx.forming) == 0,
		"label": ConstructWords.phrase(str(con["tier"]), str(con["concept"]))}


## The draft as it would be sealed: with the chosen keystone over its forming ring (a copy).
func draft_with_keystone() -> Dictionary:
	if player.seal_draft.is_empty():
		return {}
	var ks: Dictionary = seal_keystone()
	if ks.is_empty():
		return (player.seal_draft["word"] as Dictionary).duplicate(true)
	return RuneWord.with_keystone(player.seal_draft["word"], int(ks["ring"]), str(ks["tier"]), str(ks["concept"]))


## Choose, on the seal screen, which carried construct this level lock binds - the keystone set over
## the forming ring: one of the tier the skill needs, whose word fits (Brent 2026-11-04: construct_fits;
## reason "unfit" with why). Returns {ok, reason, text}.
func choose_seal_construct(construct_index: int) -> Dictionary:
	if seal_mode() != "bind":
		return RuneRules.no("not_sealing", "No level lock is being formed.")
	var need: String = player.pending_tier(player.abilities[sealing_index()])
	if construct_index < 0 or construct_index >= player.constructs.size():
		return RuneRules.no("no_construct", "You carry no such construct.")
	if str(player.constructs[construct_index]["tier"]) != need:
		return RuneRules.no("wrong_tier", "This level lock needs a %s." % need)
	var fit: Dictionary = construct_fits(need, str(player.constructs[construct_index]["concept"]))
	if not bool(fit["ok"]):
		return RuneRules.no("unfit", str(fit["text"]))
	player.seal_draft["construct"] = construct_index
	return RuneRules.ok()


func close_seal() -> void:
	player.seal_draft = {}


## Put the draft back as the sealed word was (a step that can be undone).
func draft_reset() -> void:
	if not player.seal_draft.is_empty():
		var before: Dictionary = _before_change()
		player.seal_draft["word"] = _draft_from(sealing_index())
		_changed(before)


## The draft differs from the skill's sealed word.
func draft_changed() -> bool:
	if player.seal_draft.is_empty():
		return false
	return RuneWord.shape_key(player.seal_draft["word"]) != RuneWord.shape_key(_draft_from(sealing_index()))


## May the level lock be bound? Brent 2026-11-03 ("let them bind and close no matter what"): the
## draft a seal the rules accept (no hard rule broken - RuneRules.can_seal; full rings and a closed
## word only where bond_v2's switches still ask them), then the keystone - a construct of the right
## tier - chosen. The reasons come in that order. {ok, reason, text}.
func can_bind_seal() -> Dictionary:
	if seal_mode() != "bind":
		return RuneRules.no("not_sealing", "No level lock is being formed.")
	return _can_bind(rune_context(sealing_index()))


func _can_bind(ctx: RuneContext) -> Dictionary:
	var r: Dictionary = Runes.active().can_seal(player.seal_draft["word"], ctx)
	if not bool(r["ok"]):
		return r
	var need: String = player.pending_tier(player.abilities[sealing_index()])
	var c: int = seal_construct()
	if c >= 0 and c < player.constructs.size() and need == str(player.constructs[c]["tier"]) and not bool(construct_fits(need, str(player.constructs[c]["concept"]))["ok"]):
		return RuneRules.no("unfit", str(construct_fits(need, str(player.constructs[c]["concept"]))["text"]))
	if c < 0 or c >= player.constructs.size() or need != str(player.constructs[c]["tier"]):
		return RuneRules.no("no_keystone", "Choose the %s to set over ring %d as its keystone, then bind." % [need, ctx.forming])
	return r


## Bind the chosen construct and, if the bind takes, seal the draft as the skill's word: one ring per
## level, locked together (the only bind in the game). A failed bind (the existing roll) forms no
## seal: the word stays as it was and the construct is gone. Returns what _bind_construct returns
## ("bound", "failed", ...) or why it could not be tried. (test_bind_unclosed, the test hook that
## waived the closed-word rule, went on 2026-11-03: every bind is like that now.)
func bind_seal(roll: float = -1.0) -> String:
	if seal_mode() != "bind":
		return "No level lock is being formed."
	var index: int = sealing_index()
	var ctx: RuneContext = rune_context(index)
	var check: Dictionary = _can_bind(ctx)
	if not bool(check["ok"]):
		return str(check["text"])
	# the whole level as it will lock: every reworked ring, the new ring as built, the keystone over it
	var draft: Dictionary = draft_with_keystone()
	var ks: Dictionary = seal_keystone()
	var result: String = _bind_construct(index, seal_construct(), roll)
	close_seal()
	var st: Dictionary = player.abilities[index]
	var skill: String = str(GameData.ability(str(st["id"])).get("name", "?"))
	if result == "bound":
		var after: RuneContext = RuneContext.of(st, player.affinities)
		var r: Dictionary = Runes.active().seal(draft, after, int(st["stage"]))
		if bool(r["ok"]):
			st["word"] = draft
			player.note("The level lock holds: %s is sealed through %d ring%s, the %s set over ring %d." % [skill, int(st["stage"]),
				"" if int(st["stage"]) == 1 else "s", str(ks.get("label", "construct")), int(ks.get("ring", int(st["stage"])))])
		else:
			push_error("bind_seal: the bind took but the seal was refused: %s" % str(r["text"]))
		# TEST OVERRIDE (balance.json skills.test_refill_after_bind): a test character's next lock is open at once
		if player.test_character and bool((GameData.balance["skills"] as Dictionary).get("test_refill_after_bind", false)):
			st["progress"] = 100.0
	elif result == "failed":
		player.note("No seal forms. The word of %s stays as it was." % skill)
	return result


## The draft of ability `index` if it is being sealed, else {}.
func _draft_for(index: int) -> Dictionary:
	return player.seal_draft["word"] if sealing_index() == index else {}


func _not_sealing(index: int) -> Dictionary:
	var st: Dictionary = player.abilities[index] if index >= 0 and index < player.abilities.size() else {}
	var need: String = player.pending_tier(st) if not st.is_empty() else ""
	return RuneRules.no("not_sealing", ("Runes are set at a level lock: open the seal of this skill, build its ring and bind a %s there." % need) if need != ""
		else "Runes are set at a level lock, when the skill's bar is full: fill it first.")


## Set a rune into the draft of ability `index`, joined to node `to_node` when that is >= 0, on ring
## `ring` when that is >= 0, at place `place` of that ring when that is >= 0 and free (otherwise the
## layout picks one). Returns the rules' check: {ok, reason, text, node, ring}.
func word_add(index: int, rune_id: String, to_node: int = -1, ring: int = -1, place: int = -1) -> Dictionary:
	if index < 0 or index >= player.abilities.size():
		return RuneRules.no("no_skill", "No such skill.")
	var w: Dictionary = _draft_for(index)
	if w.is_empty():
		return _not_sealing(index)
	if not can_use_rune(rune_id):
		return RuneRules.no("not_yours", "%s belongs to an affinity you do not hold." % str(GameData.rune(rune_id).get("name", rune_id)))
	if not knows_rune(rune_id):
		return RuneRules.no("unknown", "You have not discovered that rune yet: runes are found in the Netherecho, in fights and on old stones.")
	var before: Dictionary = _before_change()
	var r: Dictionary = Runes.active().add(w, rune_id, rune_context(index), to_node, ring)
	if bool(r["ok"]):
		var i: int = int(r["node"])
		var k: int = RuneWord.ring(w, i)
		var free: bool = place >= 0
		for o: int in RuneWord.ring_nodes(w, k):
			if o != i and RuneWord.places(w)[o] == place:
				free = false
		RuneWord.set_place(w, i, place if free else -1)
		_changed(before)
	return r


## Join two runes of the draft, or part them if they are joined.
func word_toggle_link(index: int, a: int, b: int) -> Dictionary:
	var w: Dictionary = _draft_for(index) if index >= 0 and index < player.abilities.size() else {}
	if not w.is_empty() and RuneWord.linked(w, a, b):
		return word_unlink(index, a, b)
	return word_link(index, a, b)


## Bond two runes of the draft (never parts them). Returns the rules' check.
func word_link(index: int, a: int, b: int) -> Dictionary:
	if index < 0 or index >= player.abilities.size():
		return RuneRules.no("no_skill", "No such skill.")
	var w: Dictionary = _draft_for(index)
	if w.is_empty():
		return _not_sealing(index)
	var before: Dictionary = _before_change()
	var r: Dictionary = Runes.active().link(w, a, b, rune_context(index))
	if bool(r["ok"]):
		_changed(before)
	return r


## Part two runes of the draft. Returns the rules' check.
func word_unlink(index: int, a: int, b: int) -> Dictionary:
	if index < 0 or index >= player.abilities.size():
		return RuneRules.no("no_skill", "No such skill.")
	var w: Dictionary = _draft_for(index)
	if w.is_empty():
		return _not_sealing(index)
	var before: Dictionary = _before_change()
	var r: Dictionary = Runes.active().unlink(w, a, b, rune_context(index))
	if bool(r["ok"]):
		_changed(before)
	return r


## Take a rune (not the skill's own) out of the draft, with its bonds.
func word_remove(index: int, node: int) -> Dictionary:
	if index < 0 or index >= player.abilities.size():
		return RuneRules.no("no_skill", "No such skill.")
	var w: Dictionary = _draft_for(index)
	if w.is_empty():
		return _not_sealing(index)
	var before: Dictionary = _before_change()
	var r: Dictionary = Runes.active().remove(w, node, rune_context(index))
	if bool(r["ok"]):
		_changed(before)
	return r


## Clear the draft back to the skill's own rune alone (a step that can be undone). The keystones of
## the sealed rings stay: the constructs bound at earlier locks are not given back.
func word_clear(index: int) -> void:
	if sealing_index() == index:
		var before: Dictionary = _before_change()
		var w: Dictionary = RuneWord.make(GameData.skill_anchor(str(player.abilities[index]["id"])), Runes.active().id)
		if (player.seal_draft["word"] as Dictionary).has("keystones"):
			w["keystones"] = (player.seal_draft["word"]["keystones"] as Array).duplicate(true)
		player.seal_draft["word"] = w
		_changed(before)


## The skill uses a sealed word.
func word_locked(index: int) -> bool:
	return index >= 0 and index < player.abilities.size() and RuneWord.is_locked(_sealed_word(index))


## What the word in ability `index` (the draft, while sealing) does - or would do once sealed - to
## its skill: {rows: [{label, before, after, better}], lines, runes, anchor, groups, traits,
## transfers}. `before` is the skill without the word, `after` with it. Numbers are formatted.
func rune_preview(index: int) -> Dictionary:
	if index < 0 or index >= player.abilities.size():
		return {}
	var state: Dictionary = player.abilities[index]
	var bare: Dictionary = state.duplicate(true)
	bare.erase("word")
	bare.erase("ascension")                  # laid after the word below, as ability_stats does
	var before: Dictionary = ability_stats(bare)
	# while a lock is open: the draft with the chosen keystone over its forming ring, as it would seal
	var word: Dictionary = draft_with_keystone() if sealing_index() == index else ability_word(index).duplicate(true)
	var fx: Dictionary = Runes.active().effects(word, rune_context(index))
	var after: Dictionary = before.duplicate(true)
	apply_rune_patch(after, fx.get("patch", []))
	_apply_ascension(before, state)
	_apply_ascension(after, state)
	# the rule set names the fields worth showing: [{path, group, label, lower_is_better, unit}]
	var stage_mult: float = player.ability_damage_mult(int(state["stage"])) * float(before.get("damage_all", 1.0))
	var rows: Array[Dictionary] = _stat_rows(before, after, fx.get("fields", []), stage_mult)
	if after.has("rune_repeat"):
		var rep: Dictionary = after["rune_repeat"]
		rows.append({"label": "Repeats", "group": "power", "before": "no", "after": "x%d at %d%%" % [int(rep.get("times", 1)), int(round(float(rep.get("mult", 0.0)) * 100.0))],
			"changed": true, "better": true})
	return {"rows": rows, "lines": fx.get("lines", []), "runes": fx.get("runes", []), "anchor": fx.get("anchor", {}),
		"groups": fx.get("groups", {}), "traits": fx.get("traits", []), "effect_lines": fx.get("effect_lines", fx.get("lines", [])), "transfers": fx.get("transfers", []),
		"conversions": fx.get("conversions", []), "keystones": fx.get("keystones", []), "before": before, "after": after}


## Labelled rows for `fields` (the rule set's field list), `before` beside `after`: [{label, group,
## path, before, after, changed, better}], numbers formatted. A field one side lacks counts as 0 (or
## "no"); a field's "default" [section, key] is read from balance.json when the skill leaves it out.
func _stat_rows(before: Dictionary, after: Dictionary, fields: Array, stage_mult: float) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for f: Dictionary in fields:
		var path: String = str(f["path"])
		var b: Variant = _path_value(before, path)
		var a: Variant = _path_value(after, path)
		var label: String = str(f["label"])
		if bool(f.get("bool", false)):
			var bb: bool = b is bool and bool(b)
			var ab2: bool = a is bool and bool(a)
			rows.append({"label": label, "group": str(f["group"]), "path": path, "before": "yes" if bb else "no", "after": "yes" if ab2 else "no",
				"changed": bb != ab2, "better": ab2})
			continue
		if f.has("default"):
			var dflt: Array = f["default"]
			var dv: float = GameData.num(str(dflt[0]), str(dflt[1]))
			b = b if (typeof(b) == TYPE_FLOAT or typeof(b) == TYPE_INT) else dv
			a = a if (typeof(a) == TYPE_FLOAT or typeof(a) == TYPE_INT) else dv
		var b_num: bool = typeof(b) == TYPE_FLOAT or typeof(b) == TYPE_INT
		var a_num: bool = typeof(a) == TYPE_FLOAT or typeof(a) == TYPE_INT
		if not b_num and not a_num:
			continue
		var scale: float = stage_mult if bool(f.get("scaled_by_stage", false)) else 1.0
		var shown_b: float = (float(b) if b_num else 0.0) * scale
		var shown_a: float = (float(a) if a_num else 0.0) * scale
		rows.append({"label": label, "group": str(f["group"]), "path": path,
			"before": _stat_text(shown_b, f), "after": _stat_text(shown_a, f),
			"changed": absf(shown_a - shown_b) > 0.0001, "better": (shown_a < shown_b) == bool(f.get("lower_is_better", false))})
	return rows


## The number at `path` in `d`, or 0 when it is not a number there.
static func _num_at(d: Dictionary, path: String) -> float:
	var v: Variant = _path_value(d, path)
	return float(v) if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT else 0.0


static func _stat_text(v: float, f: Dictionary) -> String:
	if bool(f.get("pct", false)):
		return "%d%%" % int(round(v * 100.0))
	var whole: bool = absf(v) >= 10.0
	return (("%d" % int(round(v))) if whole else ("%.2f" % v).rstrip("0").rstrip(".")) + str(f.get("unit", ""))


## What skill `index` does, in numbers and statuses, for the ethercosm (Brent 2026-10-23: "the
## details of the skill visible in text"): {rows, statuses, works_on, sealed}. `rows` are the rule
## set's fields (rune_preview's list) plus a few worked out from them, each "before" the skill
## without its sealed word and "after" as it is now - the same before/after a seal view shows.
## `statuses`: StatusText.compare of what it applies, bare and sealed. `works_on`: statuses it
## reads, spends or keeps off without applying them.
func skill_details(index: int) -> Dictionary:
	if index < 0 or index >= player.abilities.size():
		return {}
	var state: Dictionary = player.abilities[index]
	var bare: Dictionary = state.duplicate(true)
	bare.erase("word")
	bare.erase("ascension")                  # "before" is the skill's own: no word, no ascension boost
	var before: Dictionary = ability_stats(bare)
	var after: Dictionary = ability_stats(state)
	if before.is_empty():
		return {}
	var fx: Dictionary = Runes.active().effects(_sealed_word(index), rune_context(index))
	var stage_mult: float = player.ability_damage_mult(int(state["stage"])) * float(before.get("damage_all", 1.0))
	var stage_after: float = player.ability_damage_mult(int(state["stage"])) * float(after.get("damage_all", 1.0))
	var fields: Array = (fx.get("fields", []) as Array).duplicate(true)
	if str(before.get("kind", "")) == "channel":
		for f: Dictionary in fields:
			if str(f["path"]) == "cost":
				f["label"] = "Essence a second"        # a held skill's cost is by the second
	var rows: Array[Dictionary] = _stat_rows(before, after, fields, stage_mult)
	# worked out from the fields: what a strike-scaled hit does, where a shot reaches, how far a dash
	# goes, what an arc does on a jump, and the reflux the cost leaves
	var strike: float = player.strike_damage()
	var derived: Array[Dictionary] = []
	for part: String in ["", "on_hit."]:
		if _num_at(before, part + "damage_mult") > 0.0:
			derived.append({"label": "Damage, each hit", "b": strike * _num_at(before, part + "damage_mult") * stage_mult,
				"a": strike * _num_at(after, part + "damage_mult") * stage_after, "f": {}})
			break
	if str(before.get("kind", "")) == "projectile" and not before.has("range") and before.has("speed") and before.has("life"):
		derived.append({"label": "Reaches", "b": _num_at(before, "speed") * _num_at(before, "life"), "a": _num_at(after, "speed") * _num_at(after, "life"), "f": {"unit": " m"}})
	if before.has("dash_speed") and before.has("dash_time"):
		derived.append({"label": "Dash distance", "b": _num_at(before, "dash_speed") * _num_at(before, "dash_time"), "a": _num_at(after, "dash_speed") * _num_at(after, "dash_time"), "f": {"unit": " m"}})
	var jumps_b: int = int(maxf(_num_at(before, "jumps"), _num_at(before, "on_hit.jumps")))
	var jumps_a: int = int(maxf(_num_at(after, "jumps"), _num_at(after, "on_hit.jumps")))
	if jumps_b > 0 or jumps_a > 0:
		var hit_b: float = maxf(_num_at(before, "on_hit.damage"), _num_at(before, "damage"))
		var hit_a: float = maxf(_num_at(after, "on_hit.damage"), _num_at(after, "damage"))
		var cut: float = GameData.num("skills", "jump_damage_mult")
		if hit_b > 0.0 or hit_a > 0.0:
			derived.append({"label": "Damage, each jump", "b": hit_b * cut * stage_mult if jumps_b > 0 else 0.0, "a": hit_a * cut * stage_after if jumps_a > 0 else 0.0, "f": {}})
		if not before.has("jump_radius"):
			derived.append({"label": "Jumps reach", "b": GameData.num("skills", "jump_radius"), "a": GameData.num("skills", "jump_radius"), "f": {"unit": " m"}})
	derived.append({"label": "Reflux left behind", "b": float(before["cost"]) * float(before.get("reflux_per_cost", 1.0)),
		"a": float(after["cost"]) * float(after.get("reflux_per_cost", 1.0)), "f": {}, "lower": true})
	for d: Dictionary in derived:
		var fd: Dictionary = d["f"]
		rows.append({"label": str(d["label"]), "group": "derived", "path": "", "before": _stat_text(float(d["b"]), fd), "after": _stat_text(float(d["a"]), fd),
			"changed": absf(float(d["a"]) - float(d["b"])) > 0.0001, "better": (float(d["a"]) < float(d["b"])) == bool(d.get("lower", false))})
	return {"rows": rows, "statuses": StatusText.compare(before, after), "works_on": StatusText.read_by(after),
		"keystones": fx.get("keystones", []) if word_locked(index) else [],
		"sealed": word_locked(index), "boosted": player.progress_part.ascension_summary(index) != "", "before": before, "after": after}


## Short lines on what a SEALED word does to ability `index` ([] if it has none), for tooltips and
## the ethercosm.
func rune_summary(index: int) -> Array:
	if not word_locked(index):
		return []
	return Runes.active().locked_effects(_sealed_word(index), RuneContext.of(player.abilities[index], player.affinities)).get("summary", [])


## (A list of {id, ...} entries is walked by id, as the rune engine's get_path_value does; a list of
## numbers reads as its largest, for the numbers panel.)
static func _path_value(d: Dictionary, path: String) -> Variant:
	var v: Variant = _Fx.get_path_value(d, path)
	if typeof(v) == TYPE_ARRAY and _Fx.is_numeric(v):
		var top: float = -INF
		for x: Variant in v:
			top = maxf(top, float(x))
		return top
	return v


## Every rune this character could set - its affinities' base runes and the universal ones, in
## workbook order - known or not (the screen shows the unknown ones as "?").
func rune_palette() -> Array[String]:
	return Runes.usable(player.affinities)


# --- rune discovery (Brent 2026-10-23, design/14 section 8) -----------------------------------
# A discovered rune is permanent knowledge. Runes are found by subduing constructs (a rune of the
# construct's concept), by kills (a small chance of a rune of the enemy's nature) and at rune
# stones; universal runes are rarer and come from deeper sources. Pools and chances are
# data/rune_discovery.json; only runes this character can use and does not know are revealed.

func knows_rune(rune_id: String) -> bool:
	return player.test_character or player.known_runes.has(rune_id)


## A base rune of an affinity held, or a universal rune.
func can_use_rune(rune_id: String) -> bool:
	var r: Dictionary = GameData.rune(rune_id)
	if r.is_empty():
		return false
	var aff: String = str(r.get("affinity", ""))
	return aff == "" or player.affinities.has(aff)


## Learn a rune: a message, the HUD's card (rune_discovered). False if it was known or is no rune.
func discover_rune(rune_id: String, source: String = "") -> bool:
	if rune_id == "" or GameData.rune(rune_id).is_empty() or player.known_runes.has(rune_id):
		return false
	player.known_runes.append(rune_id)
	player.last_rune = {"id": rune_id, "source": source}
	player.note("Rune discovered: %s%s" % [str(GameData.rune(rune_id).get("name", rune_id)), (" - " + source) if source != "" else ""])
	player.rune_discovered.emit(rune_id, source)
	return true


## Know a rune without a fanfare (a starting rune, a learned skill's own rune).
func _know(rune_id: String) -> void:
	if rune_id != "" and not GameData.rune(rune_id).is_empty() and not player.known_runes.has(rune_id):
		player.known_runes.append(rune_id)


## What a new character knows: the runes of the skills it holds, and a couple of each affinity's
## runes (rune_discovery.json "start").
func _grant_start_runes() -> void:
	for st: Dictionary in player.abilities:
		_know(GameData.skill_anchor(str(st["id"])))
	var start: Dictionary = (GameData.rune_discovery.get("start", {}) as Dictionary).get("affinity_runes", {})
	for a: String in player.affinities:
		for rid: Variant in start.get(a, []):
			_know(str(rid))


func _unknown_usable(pool: Array) -> Array[String]:
	var out: Array[String] = []
	for rid: Variant in pool:
		if can_use_rune(str(rid)) and not knows_rune(str(rid)) and not out.has(str(rid)):
			out.append(str(rid))
	return out


## Every base rune of the affinities held, then every universal rune (for stones).
func _all_base() -> Array:
	return Runes.usable(player.affinities).filter(func(id: String) -> bool: return str(GameData.rune(id).get("affinity", "")) != "")


func _all_universal() -> Array:
	return (GameData.runes.get("universal_runes", {}) as Dictionary).keys()


## Reveal one rune: universal with `universal_chance` (else from `base`); a universal wish that finds
## nothing falls back to base, never the other way (universal runes are the rarer). With
## `any_base`, a base pool with nothing new falls back to any base rune of the affinities held.
## Returns the rune id, or "" if there was nothing new to find.
func reveal_rune(base: Array, universal: Array, universal_chance: float, source: String, any_base: bool = false) -> String:
	var picks: Array[String] = []
	if universal_chance > 0.0 and player.rng.randf() < universal_chance:
		picks = _unknown_usable(universal)
	if picks.is_empty():
		picks = _unknown_usable(base)
	if picks.is_empty() and any_base:
		picks = _unknown_usable(_all_base())
	if picks.is_empty():
		return ""
	var rid: String = picks[player.rng.randi() % picks.size()]
	discover_rune(rid, source)
	return rid


## A construct subdued in the Netherecho reveals runes of the word it carries (Brent 2026-11-04,
## design/14 section 14): "reveals" of them by tier (rune_discovery.json construct.by_tier) - first the
## word's OWN runes this character can use and does not know (in random order), then, for the reveals
## left, the runes nearest the word (construct.words.<id>: per affinity held, universal with the tier's
## universal_chance), as before. Returns the ids revealed.
func on_construct_subdued(tier: String, concept: String) -> Array[String]:
	var cfg: Dictionary = GameData.rune_discovery.get("construct", {})
	var by_tier: Dictionary = (cfg.get("by_tier", {}) as Dictionary).get(tier, {})
	var wid: String = GameData.construct_word_id(tier, concept)
	var entry: Dictionary = (cfg.get("words", {}) as Dictionary).get(wid, {})
	var base: Array = []
	for a: String in player.affinities:
		base.append_array((entry.get("base", {}) as Dictionary).get(a, []))
	var source: String = "from the %s you subdued" % ConstructWords.phrase(tier, concept)
	var own: Array[String] = _unknown_usable(ConstructWords.runes(tier, concept))
	var out: Array[String] = []
	for n: int in int(by_tier.get("reveals", 0)):
		var rid: String = ""
		if not own.is_empty():
			rid = own[player.rng.randi() % own.size()]
			own.erase(rid)
			discover_rune(rid, source)
		else:
			rid = reveal_rune(base, entry.get("universal", []), float(by_tier.get("universal_chance", 0.0)), source)
		if rid != "":
			out.append(rid)
	return out


## A kill may reveal a rune of the enemy's nature.
func _roll_kill_rune(target: Node) -> void:
	var kind_v: Variant = target.get("kind")
	if kind_v == null or str(kind_v) == "":
		return
	var cfg: Dictionary = GameData.rune_discovery.get("kills", {})
	var chance: float = float((cfg.get("chance_by_kind", {}) as Dictionary).get(str(kind_v), cfg.get("chance", 0.0)))
	if player.rng.randf() >= chance:
		return
	kill_reveals(str(kind_v))


## The rune a kill of `kind` reveals (the chance already rolled). Public for tests.
func kill_reveals(kind: String) -> String:
	var cfg: Dictionary = GameData.rune_discovery.get("kills", {})
	var entry: Dictionary = (cfg.get("by_kind", {}) as Dictionary).get(kind, {})
	var base: Array = []
	for a: String in player.affinities:
		base.append_array((entry.get("base", {}) as Dictionary).get(a, []))
	return reveal_rune(base, entry.get("universal", []), float(cfg.get("universal_chance", 0.0)), "from the %s you killed" % kind)


## Read a rune stone: once per stone, a rune of one of your affinities ("base") or a universal one.
## Returns the rune revealed, or "".
func read_inscription(id: String, pool: String, stone_name: String = "the stone") -> String:
	if player.read_inscriptions.has(id):
		player.note("You have read %s; it holds nothing more for you." % stone_name.to_lower())
		return ""
	player.read_inscriptions.append(id)
	var fallback: bool = bool((GameData.rune_discovery.get("inscriptions", {}) as Dictionary).get("base_fallback", true))
	var rid: String = reveal_rune(_all_base(), _all_universal(), 1.0 if pool == "universal" else 0.0, "read from %s" % stone_name.to_lower(), fallback)
	if rid == "":
		player.note("%s holds only runes you already know." % stone_name)
	return rid


## PLACEHOLDER source of constructs until the Netherecho exists: some enemies leave one behind.
func _roll_drops(target: Node) -> void:
	var kind_v: Variant = target.get("kind")
	if kind_v == null or str(kind_v) == "":
		return
	var drops: Dictionary = GameData.enemy(str(kind_v)).get("drops", {})
	for tier: String in drops:
		if player.rng.randf() < float(drops[tier]):
			# a word of the tier, leaning toward your affinities (ConstructWords.pick_wild)
			var concept_id: String = ConstructWords.pick_wild(tier, player.affinities, player.rng)
			if concept_id == "":
				continue
			player.constructs.append({"tier": tier, "concept": concept_id})
			player.note("It leaves a %s behind." % ConstructWords.phrase(tier, concept_id))
