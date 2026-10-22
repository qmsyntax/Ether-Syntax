class_name RuneInteraction
extends RefCounted
## Extension point for rune interactions: reactions between opposites, traits that emerge from a
## word's shape, and (later) a word's effect on its skill's numbers. Nothing is built on it yet -
## Brent has not ruled on any interaction (design/14 section 7).
##
## Works like a TalentEffect: an interaction is res://scripts/runes/interactions/<id>.gd extending
## this class, listed by id in runes.json under its rule set's "interactions", loaded by
## RuneRules.setup(). The rule set runs every hook after its own answer, in list order, and an
## interaction rewrites the dictionary it is handed. Override only the hooks you need.

var id := ""
var rules: RuneRules          # the rule set it belongs to
var params: Dictionary = {}   # its own entry in the rule set's "interaction_params", if any


func setup(owner_rules: RuneRules, interaction_id: String, p: Dictionary) -> void:
	rules = owner_rules
	id = interaction_id
	params = p


## May refuse an add the rules allowed (set result.ok false, with reason and text), or explain more.
func on_can_add(_word: Dictionary, _rune_id: String, _ctx: RuneContext, _to_node: int, _result: Dictionary) -> void:
	pass


## May refuse a link the rules allowed, or (carefully) allow one they refused.
func on_can_link(_word: Dictionary, _a: int, _b: int, _ctx: RuneContext, _result: Dictionary) -> void:
	pass


## Data to keep on a new link (merged into what the rule set keeps); saved with the word.
func on_link_data(_word: Dictionary, _a: int, _b: int, _ctx: RuneContext, _data: Dictionary) -> void:
	pass


## Recolour or flag a link: a reaction between opposites would add a flag and a line here.
func on_describe_link(_word: Dictionary, _a: int, _b: int, _ctx: RuneContext, _desc: Dictionary) -> void:
	pass


## Add badges to a rune in the word.
func on_describe_node(_word: Dictionary, _i: int, _ctx: RuneContext, _desc: Dictionary) -> void:
	pass


## Add traits, problems or summary lines for the whole word (a shape that means something).
func on_word_state(_word: Dictionary, _ctx: RuneContext, _state: Dictionary) -> void:
	pass


## What the word does to its skill: stat multipliers, added payload, tags. Empty until Brent rules
## on rune effects; when he does, Player.ability_stats will read RuneRules.effects() here.
func on_effects(_word: Dictionary, _ctx: RuneContext, _effects: Dictionary) -> void:
	pass
