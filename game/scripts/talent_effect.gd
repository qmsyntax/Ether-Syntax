class_name TalentEffect
extends RefCounted
## Base class for anything that hooks the damage pipeline: talents now; items, summons and
## tempering techniques later. Override only the hooks you need. `owner` is the player.
## Effects are loaded by id from res://scripts/talents/<id>.gd (see Player.set_talent).

var owner: Node
var id := ""


func setup(player: Node, talent_id: String) -> void:
	owner = player
	id = talent_id


## Before the owner's hit lands. Change ctx.mult / ctx.flat / ctx.tags.
func on_outgoing(_ctx: HitContext) -> void:
	pass


## After the owner's hit landed (ctx.applied is set, ctx.killed may be true).
func on_dealt(_ctx: HitContext) -> void:
	pass


## Before a hit on the owner is applied. May set ctx.cancelled to swallow it.
func on_incoming(_ctx: HitContext) -> void:
	pass


## Reflux reached the lock threshold. Return true to handle it (and prevent the lockout).
func on_reflux_cap() -> bool:
	return false


## Every physics step while the owner is active.
func on_tick(_delta: float) -> void:
	pass


## The owner ascended to `stars`.
func on_ascend(_stars: int) -> void:
	pass


## Lines for the HUD notebook (e.g. damage still owed). Return [] for none.
func status_lines() -> Array[String]:
	return []
