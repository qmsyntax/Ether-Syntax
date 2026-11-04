extends TalentEffect
## Combat-review meter: rides the player's own damage pipeline as one more TalentEffect, so every
## hit the player deals and takes is seen exactly as the game counts it. Changes nothing (it only reads).

var drv: Node          # the driver, which owns the tallies


func on_dealt(ctx: HitContext) -> void:
	if drv != null:
		drv.call("on_dealt", ctx)


func on_incoming(ctx: HitContext) -> void:
	if drv != null:
		drv.call("on_incoming", ctx)
