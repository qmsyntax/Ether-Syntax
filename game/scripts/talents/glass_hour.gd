extends TalentEffect
## Glass Hour: for the first 6 s of any fight you deal x3 and take x3.

const WINDOW := 6.0
const FACTOR := 3.0


func _in_window() -> bool:
	return bool(owner.get("in_combat")) and float(owner.get("fight_time")) < WINDOW


func on_outgoing(ctx: HitContext) -> void:
	if _in_window():
		ctx.mult *= FACTOR


func on_incoming(ctx: HitContext) -> void:
	if _in_window():
		ctx.mult *= FACTOR
