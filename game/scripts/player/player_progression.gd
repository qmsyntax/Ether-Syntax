class_name PlayerProgression
extends RefCounted
## The player's part for progression: stars, the latent aura, tempering, learning, the skill tree and skill points, ascension.
## A part of the player (scripts/player.gd), split out by concern: it holds this concern's logic and its
## private state; everything shared or saved stays on the player, reached through `player`.
## Map and pattern: docs/architecture/player-split.md.

var player: Player

# --- tempering ------------------------------------------------------------------------


func _init(of: Player) -> void:
	player = of


## The techniques a new character knows: the plain one, and one for each affinity it holds.
## Any health they had added is taken back out first.
func _reset_tempering() -> void:
	for id: String in player.tempering:
		_apply_temper_health(id, -int((player.tempering[id] as Dictionary)["stage"]))
	player.tempering.clear()
	for id: String in GameData.technique_ids():
		var aff: String = str(GameData.technique(id).get("affinity", ""))
		if aff == "" or player.affinities.has(aff):
			player.tempering[id] = {"stage": 0, "progress": 0.0}


## Stages may not outrun the soul: star count + 1, as for abilities.
func temper_stage_cap() -> int:
	return player.stars + 1


## A multiplier from everything tempered so far ("reflux_shed_mult", "incoming_mult",
## "move_speed_mult", "melee_cooldown_mult"): each stage multiplies it in once more.
func temper_stat(stat: String) -> float:
	var v := 1.0
	for id: String in player.tempering:
		var eff: Dictionary = GameData.technique(id).get("effect", {})
		if str(eff.get("stat", "")) == stat:
			v *= pow(float(eff["per_stage"]), float(int((player.tempering[id] as Dictionary)["stage"])))
	return v


## "+16 health", "reflux sheds 32% faster" ... what a technique gives at `stage`.
func temper_effect_text(id: String, stage: int) -> String:
	var eff: Dictionary = GameData.technique(id).get("effect", {})
	var per: float = float(eff.get("per_stage", 0.0))
	var amount: float
	if str(eff.get("stat", "")).begins_with("max_"):
		amount = per * float(stage)
	else:
		amount = absf(pow(per, float(stage)) - 1.0) * 100.0
	return str(eff.get("text", "%d")) % int(round(amount))


## What one session strains the body by: taken off the health bar's maximum until it is mended.
func temper_session_damage(id: String) -> float:
	var s: Dictionary = GameData.tempering_session()
	return float(s["strain_base"]) + float(s["strain_per_stage"]) * float(int((player.tempering[id] as Dictionary)["stage"]))


func temper_session_progress(id: String) -> float:
	var s: Dictionary = GameData.tempering_session()
	return float(s["progress_base"]) * pow(float(s["progress_falloff_per_stage"]), float(int((player.tempering[id] as Dictionary)["stage"])))


## Why a session cannot be trained right now, or "" if it can.
func cannot_temper_reason(id: String) -> String:
	if not player.tempering.has(id):
		return "You do not know it."
	if int((player.tempering[id] as Dictionary)["stage"]) >= temper_stage_cap():
		return "Needs another star."
	if player.body.max_cut() + temper_session_damage(id) > player.body.max_hp * float(GameData.tempering_session()["max_cut_frac"]):
		return "Your body cannot take it. Mend first."
	return ""


## One training session: it costs bone and moves the technique along; a full bar is a new stage.
## Returns false if the session could not be trained.
func temper_session(id: String) -> bool:
	if cannot_temper_reason(id) != "":
		return false
	var st: Dictionary = player.tempering[id]
	var strain: float = temper_session_damage(id)
	player.body.add_wound("temper_strain", str(GameData.balance["wounds"]["temper"]["name"]), strain, strain, true, true)
	st["progress"] = float(st["progress"]) + temper_session_progress(id)
	if float(st["progress"]) >= 99.999:
		st["progress"] = 0.0
		st["stage"] = int(st["stage"]) + 1
		_apply_temper_health(id, 1)
		player.note("%s reaches stage %d: %s." % [str(GameData.technique(id).get("name", id)), int(st["stage"]), temper_effect_text(id, int(st["stage"]))])
	return true


## Techniques that add health change the body itself, `stages` stages' worth (negative to undo).
func _apply_temper_health(id: String, stages: int) -> void:
	var eff: Dictionary = GameData.technique(id).get("effect", {})
	var stat: String = str(eff.get("stat", ""))
	if stat != "max_health" or stages == 0:
		return
	var add: float = float(eff["per_stage"]) * float(stages)
	player.body.max_hp = maxf(1.0, player.body.max_hp + add)
	player.body.hp = clampf(player.body.hp + add, 0.0, player.body.total_max())


# --- learning skills (design/05 step 5: scrolls) ----------------------------------------------

func knows(ability_id: String) -> bool:
	for st: Dictionary in player.abilities:
		if str(st["id"]) == ability_id:
			return true
	return false


## Why this character cannot learn that skill, or "" if they can.
func can_learn(ability_id: String) -> String:
	var ab: Dictionary = GameData.ability(ability_id)
	if ab.is_empty():
		return "That is not a skill."
	if knows(ability_id):
		return "You already know %s." % str(ab.get("name", ability_id))
	var aff: String = str(ab.get("affinity", ""))
	if not player.affinities.has(aff):
		return "You have no %s affinity: the words mean nothing to you." % str(GameData.affinity(aff).get("label", aff)).to_lower()
	return ""


## The skill is yours: it goes on the first empty key, or waits in the soul screen if the bar is full.
func learn(ability_id: String) -> bool:
	if can_learn(ability_id) != "":
		return false
	player.abilities.append({"id": ability_id, "stage": 0, "progress": 0.0})
	for i: int in player.hotbar.size():
		if player.hotbar[i] < 0:
			player.hotbar[i] = player.abilities.size() - 1
			break
	player.runes_part._know(GameData.skill_anchor(ability_id))          # a skill's own rune comes with it [MODEL]
	return true


## Read a scroll out of the pack. Returns "" if it taught its skill (and is gone), else why not.
func read_scroll(item_id: String) -> String:
	var def: Dictionary = GameData.item(item_id)
	if str(def.get("kind", "")) != "scroll" or not player.inventory.bag.has(item_id):
		return "That is not something you can read."
	var why: String = can_learn(str(def.get("teaches", "")))
	if why != "":
		return why
	player.inventory.remove(item_id)
	learn(str(def["teaches"]))
	var ab: Dictionary = GameData.ability(str(def["teaches"]))
	player.note("You read the scroll. %s is yours%s." % [str(ab.get("name", "?")), "" if player.hotbar.has(player.abilities.size() - 1) else " - the bar is full; place it from the soul screen"])
	player._float("LEARNED", GameData.affinity_color(str(ab.get("affinity", ""))).lightened(0.3))
	return ""


## A scroll this character could read and does not already carry, picked at random; "" if none.
func scroll_for_me() -> String:
	var pool: Array[String] = []
	var items: Dictionary = GameData.items_file.get("items", {})
	for id: String in items:
		var def: Dictionary = items[id]
		if str(def.get("kind", "")) == "scroll" and can_learn(str(def.get("teaches", ""))) == "" and not player.inventory.bag.has(id):
			pool.append(id)
	return pool[player.rng.randi() % pool.size()] if not pool.is_empty() else ""


# --- the skill tree (design/08) -----------------------------------------------------------
# No skill is given (Brent 2026-10-18): a new character picks two root skills, and the rest are
# trained in town for skill points and money. The trainer is main.gd's business (train_skill only
# goes through there); scrolls (read_scroll) still teach anywhere and skip the tree's rules.

## Start the character over with exactly these skills, on the bar in order. They must be
## `start_picks` different root skills of affinities the character holds. Returns "" or why not.
func start_with_skills(ids: Array) -> String:
	var want: int = int(GameData.skill_tree.get("start_picks", 2))
	var roots: Array[String] = GameData.skill_roots(player.affinities)
	var picked: Array[String] = []
	for id: Variant in ids:
		if not roots.has(str(id)):
			return "%s is not a starting skill of your affinities." % str(GameData.ability(str(id)).get("name", id))
		if picked.has(str(id)):
			return "The same skill twice."
		picked.append(str(id))
	if picked.size() != want:
		return "Pick %d starting skills." % want
	player.drop_stones()
	player.buffs.clear()
	player.abilities.clear()
	for i: int in player.hotbar.size():
		player.hotbar[i] = -1
	for id: String in picked:
		learn(id)
	player.known_runes.clear()
	player.runes_part._grant_start_runes()
	return ""


## The first `start_picks` root skills - only for quick starts in tests (start_new_character).
func default_start_skills() -> Array[String]:
	var roots: Array[String] = GameData.skill_roots(player.affinities)
	return roots.slice(0, int(GameData.skill_tree.get("start_picks", 2)))


## What learning a node costs at a trainer: {points, price}.
func skill_cost(ability_id: String) -> Dictionary:
	var node: Dictionary = GameData.skill_node(ability_id)
	var tier: Dictionary = (GameData.skill_tree.get("tiers", {}) as Dictionary).get(str(int(node.get("tier", 1))), {})
	return {"points": int(tier.get("points", 1)), "price": int(tier.get("price", 0))}


## A node's prerequisites are met: it has none, or the character knows any one of them.
func skill_unlocked(ability_id: String) -> bool:
	var needs: Array = GameData.skill_node(ability_id).get("requires", [])
	if needs.is_empty():
		return true
	for id: Variant in needs:
		if knows(str(id)):
			return true
	return false


## Why a trainer could not teach this skill now, or "" if they could.
func cannot_train_reason(ability_id: String) -> String:
	var why: String = can_learn(ability_id)
	if why != "":
		return why
	if GameData.skill_node(ability_id).is_empty():
		return "No trainer teaches that; it is not on any tree."
	if not skill_unlocked(ability_id):
		var names: Array[String] = []
		for id: Variant in GameData.skill_node(ability_id).get("requires", []):
			names.append(str(GameData.ability(str(id)).get("name", id)))
		return "Learn %s first." % " or ".join(names)
	var cost: Dictionary = skill_cost(ability_id)
	if player.skill_points < int(cost["points"]):
		return _points_short(int(cost["points"]))
	if not player.economy_part.can_afford(int(cost["price"])):
		return "Nobody trains on that much debt."
	return ""


func _points_short(need: int) -> String:
	return "Needs %d skill point%s; you have %d." % [need, "" if need == 1 else "s", player.skill_points]


## Be taught a skill: the points and the fee are spent and the skill is yours. Only main.gd calls
## this, and only while you are talking to a trainer. Returns "" or why not.
func train_skill(ability_id: String) -> String:
	var why: String = cannot_train_reason(ability_id)
	if why != "":
		return why
	var cost: Dictionary = skill_cost(ability_id)
	player.skill_points -= int(cost["points"])
	player.economy_part.charge(int(cost["price"]))
	learn(ability_id)
	var ab: Dictionary = GameData.ability(ability_id)
	player.note("Trained: %s%s." % [str(ab.get("name", ability_id)), "" if player.hotbar.has(player.abilities.size() - 1) else " - the bar is full; place it from the soul screen"])
	return ""


## Why a trainer could not drill this skill now, or "" if they could.
func cannot_drill_reason(ability_id: String) -> String:
	var st: Dictionary = {}
	for a: Dictionary in player.abilities:
		if str(a["id"]) == ability_id:
			st = a
	if st.is_empty():
		return "You do not know that skill."
	if float(st["progress"]) >= 100.0:
		return "Its bar is full. Only a bound construct takes it further."
	var cfg: Dictionary = GameData.skill_tree.get("drill", {})
	if player.skill_points < int(cfg.get("points", 1)):
		return _points_short(int(cfg.get("points", 1)))
	if not player.economy_part.can_afford(int(cfg.get("price", 0))):
		return "Nobody trains on that much debt."
	return ""


## Drill a known skill: its stage progress moves on (capped at 100 - the stage still needs a
## bound construct, Brent 2026-09-23). Only main.gd calls this, at a trainer.
func drill_skill(ability_id: String) -> String:
	var why: String = cannot_drill_reason(ability_id)
	if why != "":
		return why
	var cfg: Dictionary = GameData.skill_tree.get("drill", {})
	player.skill_points -= int(cfg.get("points", 1))
	player.economy_part.charge(int(cfg.get("price", 0)))
	for a: Dictionary in player.abilities:
		if str(a["id"]) == ability_id:
			a["progress"] = minf(100.0, float(a["progress"]) + float(cfg.get("progress", 0.0)))
	player.note("You drill %s until your hands know it better." % str(GameData.ability(ability_id).get("name", ability_id)))
	return ""


## Star growth banks toward skill points: one per `points.per_star_pct` percentage points grown.
func _earn_skill_points(grown: float) -> void:
	var per: float = float((GameData.skill_tree.get("points", {}) as Dictionary).get("per_star_pct", 10.0))
	if grown <= 0.0 or per <= 0.0:
		return
	player.skill_growth += grown
	while player.skill_growth >= per:
		player.skill_growth -= per
		player.skill_points += 1
		player.note("A skill point. A trainer in town can spend it (%s shows the tree)." % Keybinds.binding_text("skills"))


## Latent aura from a deed that was not a kill (subduing a construct, for one).
func add_aura(amount: float) -> void:
	player._latent_aura += amount


func _on_kill(target: Node) -> void:
	for bid: String in player.buffs:
		if int((player.buffs[bid] as Dictionary).get("kill_blood", 0)) > 0:
			player.hits_part.gain_blood(int(player.buffs[bid]["kill_blood"]))                      # Red Frenzy: every kill feeds it
	var hurt: float = 1.0 - player.body.total() / player.body.total_max()
	var risk: float = 1.0 + hurt * float(player._p["aura_hurt_risk_bonus"])
	var aura: float = float(target.get("aura_value")) * kill_aura_mult(target)
	player._latent_aura += aura * risk
	grow_star(aura * GameData.num("stars", "growth_pct_per_aura"))
	player.runes_part._roll_drops(target)
	player.economy_part._roll_loot(target)
	player.runes_part._roll_kill_rune(target)


# --- stars ----------------------------------------------------------------------

func _recompute_essence_max() -> void:
	var total := 0.0
	for pct: float in player.star_pct:
		total += GameData.num("stars", "full_tank") * pct / 100.0
	player.essence_max = total


## Grow the newest star's capacity by `pct` points, capped at max_pct.
func grow_star(pct: float) -> void:
	if player.star_pct.is_empty():
		return
	var i: int = player.star_pct.size() - 1
	var before: float = player.star_pct[i]
	var cap: float = GameData.num("stars", "max_pct")
	player.star_pct[i] = minf(cap, player.star_pct[i] + pct)
	if player.star_pct[i] != before:
		_recompute_essence_max()
		_earn_skill_points(player.star_pct[i] - before)
		if before < cap and player.star_pct[i] >= cap:
			player.note("Your newest star is full. It will grow no further without ascending.")


## Meditation gathers wisps and refills essence (Brent 2026-09-23).
func _meditate_gather(delta: float) -> void:
	if player.meditating:
		player.essence = minf(player.essence_max, player.essence + GameData.num("meditation", "gather_per_s") * delta)


func aura_read() -> String:
	var frac: float = player._latent_aura / player._aura_threshold
	if frac < 0.25:
		return "The star is quiet."
	if frac < 0.6:
		return "The star stirs."
	if frac < 1.0 or player.star_pct.back() < GameData.num("stars", "max_pct"):
		return "The star feels heavy." if frac >= 0.6 else "The star stirs."
	return "The star strains against itself.  %s to ascend" % Keybinds.binding_text("ascend")


func try_ascend() -> void:
	var full: bool = player.star_pct.back() >= GameData.num("stars", "max_pct")
	if not full or player._latent_aura < player._aura_threshold:            # every star ascends (Brent 2026-10-24: no cap)
		player.note("Nothing happens. The star is not ready.")
		return
	# the body grows by the new star's "ascension_<n>" block, else by the second star's
	var asc: Dictionary = GameData.balance.get("ascension_%d" % (player.stars + 1), GameData.balance["ascension_2"])
	player._latent_aura -= player._aura_threshold
	player.stars += 1
	# A new star is born tiny (Brent 2026-09-23) and grows from here.
	player.star_pct.append(GameData.num("stars", "new_star_start_pct"))
	_recompute_essence_max()
	player.essence = player.essence_max
	player.body.scale_max(float(asc["body_scale"]))
	player.casting_part.clear_reflux()
	player.skill_points += int((GameData.skill_tree.get("points", {}) as Dictionary).get("on_ascend", 0))
	for e: TalentEffect in player.effects:
		e.on_ascend(player.stars)
	_begin_ascension()
	player.motion_part._rig_action("power_up")
	player.note("ASCENDED. Star %d splits off - tiny, for now." % player.stars)
	if player.talent.has("evolve_%d" % player.stars):
		player.note("Talent evolves: %s" % str(player.talent["evolve_%d" % player.stars]))
	if player.talent_id != "one_percent_lifesteal":
		player.note("(this talent's evolution is not wired into the prototype yet)")
	player.ascended.emit(player.stars)


# --- what an ascension gives (Brent 2026-10-24; rules in Ascension, numbers balance.json "ascension") ---

## Roll what this ascension offers, alongside the talents' on_ascend: the affinities to choose from
## and each skill's boost, measured now (skills held and their stages at the moment of ascending).
## It waits in `ascension_pending` (saved) until `resolve_ascension`.
func _begin_ascension() -> void:
	player.ascension_pending = {"star": player.stars, "offer": Ascension.offer(player.affinities, player.rng), "skills": Ascension.boosts(player.abilities, player.stars)}


## The affinity is yours: its skill tree, its tempering technique and its starting runes - and no
## skill (Brent 2026-10-18: nothing is given automatically; the tree's roots are trained). Returns
## "" or why not.
func add_affinity(id: String) -> String:
	if player.affinities.has(id):
		return "You already hold %s." % str(GameData.affinity(id).get("label", id))
	if GameData.affinity(id).is_empty() or not GameData.affinity_playable(id):
		return "There is no such affinity."
	player.affinities.append(id)
	for tid: String in GameData.technique_ids():
		if str(GameData.technique(tid).get("affinity", "")) == id and not player.tempering.has(tid):
			player.tempering[tid] = {"stage": 0, "progress": 0.0}
	var start: Dictionary = (GameData.rune_discovery.get("start", {}) as Dictionary).get("affinity_runes", {})
	for rid: Variant in start.get(id, []):
		player.runes_part._know(str(rid))
	return ""


## Settle the pending ascension: add `affinity` (one of the offer, or "" to decline when the data
## allows it) and put each skill's boost into an aspect - `aspects` maps a skill's index (int or
## its string) to an aspect id; a skill left out, or given an aspect that does nothing to it, gets
## its main aspect (Ascension.main_aspect). Boosts add to the skill's "ascension" totals. Returns ""
## or why not (nothing is changed then).
func resolve_ascension(affinity: String, aspects: Dictionary = {}) -> String:
	if player.ascension_pending.is_empty():
		return "Nothing is waiting from an ascension."
	var offered: Array = player.ascension_pending.get("offer", [])
	if affinity == "" and not Ascension.allow_decline() and not offered.is_empty():
		return "An affinity must be chosen."
	if affinity != "" and not offered.has(affinity):
		return "That affinity was not offered."
	if affinity != "":
		var why: String = add_affinity(affinity)
		if why != "":
			return why
	for b: Dictionary in player.ascension_pending.get("skills", []):
		var i: int = int(b["index"])
		if i < 0 or i >= player.abilities.size() or str((player.abilities[i] as Dictionary)["id"]) != str(b["id"]):
			continue                            # the skill list changed under the offer; skip what no longer matches
		var asp: String = ascension_aspect(i, str(aspects.get(i, aspects.get(str(i), ""))))
		var st: Dictionary = player.abilities[i]
		var totals: Dictionary = st.get("ascension", {})
		totals[asp] = float(totals.get(asp, 0.0)) + float(b["amount"])
		st["ascension"] = totals
	player.ascension_pending = {}
	player.note("The star settles.%s" % ((" %s is yours." % str(GameData.affinity(affinity).get("label", affinity))) if affinity != "" else ""))
	return ""


## The aspect a boost to skill `index` goes into: `wanted` if it changes something there, else the
## skill's main aspect.
func ascension_aspect(index: int, wanted: String) -> String:
	var ab: Dictionary = player.runes_part.ability_stats(player.abilities[index])
	if wanted != "" and Ascension.aspect_ids().has(wanted) and Ascension.aspect_acts(ab, wanted):
		return wanted
	return Ascension.main_aspect(ab)


## What putting `amount` into `aspect` would change on skill `index`: the rule set's rows for that
## aspect's stat groups, before -> after ([{label, before, after, changed, better}]), numbers formatted.
func ascension_preview(index: int, aspect: String, amount: float) -> Array[Dictionary]:
	if index < 0 or index >= player.abilities.size():
		return []
	var st: Dictionary = player.abilities[index]
	var trial: Dictionary = st.duplicate(true)
	var totals: Dictionary = trial.get("ascension", {})
	totals[aspect] = float(totals.get(aspect, 0.0)) + amount
	trial["ascension"] = totals
	var before: Dictionary = player.runes_part.ability_stats(st)
	var after: Dictionary = player.runes_part.ability_stats(trial)
	var groups: Dictionary = Ascension.aspect_groups(aspect)
	var fields: Array = Runes.active().fields_of(before).filter(func(f: Dictionary) -> bool:
		return groups.has(str(f["group"])) or (str(f["path"]) == "recovery" and groups.has("windup")))
	if groups.has("power"):
		# a buff's or channel's strength (its magnitude paths) counts as power but is in no field list
		for mag: Variant in before.get("magnitude", []):
			var mp: String = str((mag as Dictionary).get("path", ""))
			if mp != "" and not fields.any(func(f: Dictionary) -> bool: return str(f["path"]) == mp):
				fields.append({"path": mp, "group": "power", "label": "Strength (%s)" % mp.get_slice(".", mp.get_slice_count(".") - 1).replace("_", " "),
					"unit": "", "lower_is_better": str((mag as Dictionary).get("dir", "up")) == "down", "scaled_by_stage": false})
	var stage_mult: float = player.casting_part.ability_damage_mult(int(st["stage"])) * float(before.get("damage_all", 1.0))
	return player.runes_part._stat_rows(before, after, fields, stage_mult).filter(func(r: Dictionary) -> bool: return bool(r["changed"]))


## "Ascension: +22% power" for skill `index`, or "" if it has never been boosted.
func ascension_summary(index: int) -> String:
	if index < 0 or index >= player.abilities.size():
		return ""
	var s: String = Ascension.summary((player.abilities[index] as Dictionary).get("ascension", {}))
	return ("Ascension: " + s) if s != "" else ""


# --- the unstarred tier and field consumables (2026-10-23, the Stubble) --------------------------

## How much of a kill's aura counts (design/01 LAW 2, Brent 2026-10-19): a starred foe in full; an
## unstarred one (enemies.json stars 0) less for every star you hold, and less again as your newest
## star fills (balance.json "unstarred").
func kill_aura_mult(target: Node) -> float:
	var kind_v: Variant = target.get("kind")
	if kind_v == null or int(GameData.enemy(str(kind_v)).get("stars", 1)) > 0:
		return 1.0
	var cfg: Dictionary = GameData.balance.get("unstarred", {})
	var fill: float = 0.0
	if not player.star_pct.is_empty():
		fill = clampf(player.star_pct[player.star_pct.size() - 1] / GameData.num("stars", "max_pct"), 0.0, 1.0)
	return pow(float(cfg.get("star_falloff", 0.35)), float(maxi(0, player.stars - 1))) * lerpf(1.0, float(cfg.get("at_full_star", 0.25)), fill)
