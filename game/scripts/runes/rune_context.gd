class_name RuneContext
extends RefCounted
## What a rule set may know about the skill a word is being built in, the way a HitContext carries
## one blow through the talent hooks. Built by Player.rune_context(); tests build their own.

var ability_id := ""
var anchor := ""                         # the base rune the skill is built on
var stage := 0                           # the skill's level
var affinities: Array[String] = []       # what the character holds
var state: Dictionary = {}               # the ability state itself (read only)
## How many rings the word may hold (design/14 section 8: one per level). The skill's stage, or one
## more while the next seal is being formed at a binding.
var rings := 0
## The ring being formed at a binding (0: no seal is being formed).
var forming := 0
## A test character's free edit: any rune it knows, any time (the seal need not be closed).
var free_edit := false


static func of(ability_state: Dictionary, held: Array = [], forming_seal: bool = false) -> RuneContext:
	var c := RuneContext.new()
	c.state = ability_state
	c.ability_id = str(ability_state.get("id", ""))
	c.anchor = GameData.skill_anchor(c.ability_id)
	c.stage = int(ability_state.get("stage", 0))
	c.rings = c.stage + (1 if forming_seal else 0)
	c.forming = c.rings if forming_seal else 0
	for a: Variant in held:
		c.affinities.append(str(a))
	return c
