extends TalentEffect
## Debt of Pain: incoming damage is delayed 5 s, then arrives at 80%.

const DELAY := 5.0
const ARRIVES_AT := 0.8

var _pending: Array[Dictionary] = []


func on_incoming(ctx: HitContext) -> void:
	_pending.append({"t": DELAY, "amount": ctx.amount() * ARRIVES_AT, "heavy": ctx.heavy})
	ctx.cancelled = true
	owner.call("_float", "later...", Color(0.7, 0.7, 1))


func on_tick(delta: float) -> void:
	if _pending.is_empty():
		return
	var still: Array[Dictionary] = []
	for p: Dictionary in _pending:
		p["t"] = float(p["t"]) - delta
		if float(p["t"]) <= 0.0:
			owner.call("_apply_damage", float(p["amount"]), bool(p["heavy"]))
		else:
			still.append(p)
	_pending = still


func pending_total() -> float:
	var sum := 0.0
	for p: Dictionary in _pending:
		sum += float(p["amount"])
	return sum


func status_lines() -> Array[String]:
	var owed: float = pending_total()
	return ["%d damage still owed" % int(owed)] if owed > 0.0 else []
