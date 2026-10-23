class_name Runes
extends RefCounted
## Which rune rule set is in force, and the runes a character may set (design/14 section 7).
##
## runes.json names the active rule set ("rule_set": "bond_v1") and lists every rule set under
## "rule_sets": {id: {"script": "res://scripts/runes/<file>.gd", ...its params}}. The script extends
## RuneRules. Everything that shows or changes a word goes through Runes.active().

## The rule set in force: a test override if one is set, else the one runes.json names (built once
## and kept on GameData).
static func active() -> RuneRules:
	if GameData.rune_rules_override != null:
		return GameData.rune_rules_override as RuneRules
	if GameData.rune_rules == null:
		GameData.rune_rules = make(str(GameData.runes.get("rule_set", "")))
	return GameData.rune_rules as RuneRules


## A rule set by id, built from its entry in runes.json; the permissive base rules if the id or
## its script is missing (so a bad data file shows an unruled word instead of crashing).
static func make(rule_id: String) -> RuneRules:
	var entry: Dictionary = (GameData.runes.get("rule_sets", {}) as Dictionary).get(rule_id, {})
	var path: String = str(entry.get("script", ""))
	var rules: RuneRules
	if path != "" and ResourceLoader.exists(path):
		rules = (load(path) as GDScript).new()
	else:
		push_error("Runes: no rule set '%s' with a script in runes.json" % rule_id)
		rules = RuneRules.new()
	rules.setup(rule_id, entry)
	return rules


## Put a rule set in force regardless of the data (tests); null goes back to the data's choice.
static func use(rules: RuneRules) -> void:
	GameData.rune_rules_override = rules


## The runes a character holding these affinities could set: their base runes, then every universal
## rune. Rune ids, in workbook order. Which of them it KNOWS is the player's (knows_rune).
static func test_palette(held: Array) -> Array[String]:
	return usable(held)


static func usable(held: Array) -> Array[String]:
	var out: Array[String] = []
	var base: Dictionary = GameData.runes.get("base_runes", {})
	for a: Variant in held:
		for id: String in base:
			if str((base[id] as Dictionary).get("affinity", "")) == str(a):
				out.append(id)
	for id: String in (GameData.runes.get("universal_runes", {}) as Dictionary):
		out.append(id)
	return out
