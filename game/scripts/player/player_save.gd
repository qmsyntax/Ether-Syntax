class_name PlayerSave
extends RefCounted
## The player's part for save and load: to_save / from_save (the save's keys are unchanged).
## A part of the player (scripts/player.gd), split out by concern: it holds this concern's logic and its
## private state; everything shared or saved stays on the player, reached through `player`.
## Map and pattern: docs/architecture/player-split.md.

var player: Player


func _init(of: Player) -> void:
	player = of


## Everything that must survive between sessions.
func to_save() -> Dictionary:
	return {
		"test_character": player.test_character, "char_id": player.char_id,
		"name": player.char_name, "identity": player.identity, "look": player.look.duplicate(), "affinities": player.affinities.duplicate(),
		"tempering": player.tempering.duplicate(true),
		"talent_id": player.talent_id, "stars": player.stars, "star_pct": player.star_pct.duplicate(), "money": player.money,
		"ascension_pending": player.ascension_pending.duplicate(true),
		"essence": player.essence, "latent_aura": player._latent_aura,
		"body": player.body.to_dict(),
		"arm_right": player.arm_right, "arm_right_lost": player.arm_right_lost,
		"abilities": player.abilities.duplicate(true), "hotbar": player.hotbar.duplicate(),
		"skill_points": player.skill_points, "skill_growth": player.skill_growth,
		"craft_skill": player.craft_skill.duplicate(), "craft_known": player.craft_known.duplicate(), "craft_made": player.craft_made.duplicate(),
		"tool_uses": player.tool_uses.duplicate(),
		"constructs": player.constructs.duplicate(true), "discoveries": player.discoveries.duplicate(),
		"known_runes": player.known_runes.duplicate(), "read_inscriptions": player.read_inscriptions.duplicate(),
		"heal_points_total": player.heal_points_total, "inventory": player.inventory.to_dict(), "corpses": player.corpses.duplicate(true), "explored": player.explored.duplicate(),
	}


func from_save(d: Dictionary) -> void:
	player.set_talent(str(d.get("talent_id", "")))
	player.test_character = bool(d.get("test_character", false))
	player.char_id = str(d.get("char_id", ""))
	player.char_name = str(d.get("name", ""))
	player.identity = str(d.get("identity", ""))
	# a save keeps the affinities it was made with; saves from before affinities were all water
	player.affinities.clear()
	for a: Variant in d.get("affinities", ["water"]):
		player.affinities.append(str(a))
	player.casting_part.clear_reflux()
	player.casting_part._reset_loadout()                  # the kit for those affinities, unless the save lists abilities below
	# tempering: what the save has, on top of what such a character starts knowing. The health it
	# added is already in the saved body_max, so stages are set here without applying it again.
	player.tempering.clear()
	for id: String in GameData.technique_ids():
		var t_aff: String = str(GameData.technique(id).get("affinity", ""))
		if t_aff == "" or player.affinities.has(t_aff):
			player.tempering[id] = {"stage": 0, "progress": 0.0}
	var saved_temper: Dictionary = d.get("tempering", {})
	for id: String in saved_temper:
		if not GameData.technique(id).is_empty():
			player.tempering[id] = {"stage": int((saved_temper[id] as Dictionary).get("stage", 0)), "progress": float((saved_temper[id] as Dictionary).get("progress", 0.0))}
	player.set_look(d.get("look", {}))
	player.stars = int(d.get("stars", 1))
	player.star_pct.clear()
	for pct: Variant in d.get("star_pct", [GameData.num("stars", "first_star_start_pct")]):
		player.star_pct.append(float(pct))
	player.progress_part._recompute_essence_max()
	player.money = int(d.get("money", 0))
	player.essence = minf(player.essence_max, float(d.get("essence", player.essence_max)))
	player._latent_aura = float(d.get("latent_aura", 0.0))
	player.ascension_pending = (d.get("ascension_pending", {}) as Dictionary).duplicate(true)
	# older saves kept three wound layers; their totals become the bar
	player.body.from_dict(d.get("body", {}), d.get("body_hp", {}), d.get("body_max", {}))
	player.arm_right = float(d.get("arm_right", player.arm_right))
	player.arm_right_lost = bool(d.get("arm_right_lost", false))
	if player.arm_right_lost and not player.body.has_wound("lost_arm"):
		var arm_wound: Dictionary = GameData.balance["wounds"]["lost_arm"]
		player.body.add_wound("lost_arm", str(arm_wound["name"]), maxf(1.0, float(player._arm["regrow_heal_points"]) - float(d.get("arm_regrow", 0.0))), float(arm_wound["cut"]), false)
	player._wound_seq = player.body.wounds.size()
	var saved_abilities: Array = d.get("abilities", [])
	if not saved_abilities.is_empty():
		player.abilities.clear()
		for a: Dictionary in saved_abilities:
			a["stage"] = int(a.get("stage", 0))
			a["progress"] = float(a.get("progress", 0.0))
			if a.has("word"):
				# rule-free data: read back as it was; the rules in force report what no longer fits.
				# No seal outlasts its skill's level (a word locked before seals, on a stage-0 skill,
				# comes back unsealed: before the first binding a skill has no word).
				var w: Dictionary = RuneWord.normalize(a["word"], GameData.skill_anchor(str(a.get("id", ""))))
				if RuneWord.sealed(w) > int(a["stage"]):
					w["sealed"] = int(a["stage"])
				if RuneWord.sealed(w) <= 0:
					w.erase("sealed")
				# a keystone sits only over a sealed ring
				if w.has("keystones"):
					w["keystones"] = RuneWord.keystones(w).filter(func(ks: Dictionary) -> bool: return int(ks["ring"]) <= RuneWord.sealed(w))
				a["word"] = w
			player.abilities.append(a)
	var saved_hotbar: Array = d.get("hotbar", [])
	for i: int in mini(saved_hotbar.size(), player.hotbar.size()):
		player.hotbar[i] = int(saved_hotbar[i])
	player.skill_points = int(d.get("skill_points", 0))
	player.skill_growth = float(d.get("skill_growth", 0.0))
	player.craft_skill.clear()
	var saved_craft: Dictionary = d.get("craft_skill", {})
	for s: String in saved_craft:
		player.craft_skill[s] = int(saved_craft[s])
	player.craft_known = (d.get("craft_known", []) as Array).map(func(v: Variant) -> String: return str(v))
	player.craft_made = (d.get("craft_made", []) as Array).map(func(v: Variant) -> String: return str(v))
	player.tool_uses.clear()
	var saved_uses: Dictionary = d.get("tool_uses", {})
	for t: String in saved_uses:
		player.tool_uses[t] = int(saved_uses[t])
	player.constructs.clear()
	for c: Variant in d.get("constructs", []):
		# an old concept id becomes the word it now is at that tier (constructs.json legacy); a construct
		# naming no word at all is dropped
		if typeof(c) == TYPE_DICTIONARY:
			var cd: Dictionary = (c as Dictionary).duplicate()
			var wid: String = GameData.construct_word_id(str(cd.get("tier", "")), str(cd.get("concept", "")))
			if wid != "":
				cd["concept"] = wid
				player.constructs.append(cd)
	player.discoveries.clear()
	for line: Variant in d.get("discoveries", []):
		player.discoveries.append(str(line))
	player.seal_draft = {}
	player.known_runes.clear()
	if d.has("known_runes"):
		for rid: Variant in d["known_runes"]:
			if not GameData.rune(str(rid)).is_empty() and not player.known_runes.has(str(rid)):
				player.known_runes.append(str(rid))
	else:
		player.runes_part._grant_start_runes()              # a save from before discovery: what a new character knows
	player.read_inscriptions.clear()
	for sid: Variant in d.get("read_inscriptions", []):
		player.read_inscriptions.append(str(sid))
	player.heal_points_total = float(d.get("heal_points_total", 0.0))
	player.corpses = (d.get("corpses", []) as Array).duplicate(true)
	player.explored = (d.get("explored", {}) as Dictionary).duplicate()
	player.inventory.from_dict(d.get("inventory", {}))
	player.economy_part.refresh_gear()
