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
## TEST HOOK (Player.test_bind_unclosed, the screenshots): the seal need not be a closed word. Rings
## are still built from the skill outward (RingRules.ring_formed). No screen reaches it: since Brent's
## ruling of 2026-10-23 a test character has no free edit and binds ring by ring like anyone else.
var closure_waived := false


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
