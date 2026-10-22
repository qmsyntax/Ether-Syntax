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
var params: Dictionary = {}   # its own entry in the rule set's "interaction_params", if any
## The rule set it belongs to. Held weakly: the rule set holds its interactions, and a strong
## reference back would make a cycle that is never freed.
var rules: RuneRules:
	get:
		return (_rules_ref.get_ref() as RuneRules) if _rules_ref != null else null
var _rules_ref: WeakRef


func setup(owner_rules: RuneRules, interaction_id: String, p: Dictionary) -> void:
	_rules_ref = weakref(owner_rules)
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


## Add lines about a rune before it is set (the palette's tooltip): what it would do.
func on_describe_rune(_rune_id: String, _ctx: RuneContext, _desc: Dictionary) -> void:
	pass


## Add traits, problems or summary lines for the whole word (a shape that means something).
func on_word_state(_word: Dictionary, _ctx: RuneContext, _state: Dictionary) -> void:
	pass


## What the word does to its skill. The shape Player.ability_stats reads (RuneRules.effects): a
## "patch" - a list of {op: mul | mul_round | add | set | min | erase | append, path: "a.b", value}
## applied to the ability dictionary in order - plus anything the screen shows ("lines", "groups",
## "runes", "anchor"). effects_v1 (layers 1-3) is the first.
func on_effects(_word: Dictionary, _ctx: RuneContext, _effects: Dictionary) -> void:
	pass
