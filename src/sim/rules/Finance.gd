class_name Finance
extends RefCounted

static func process_empire(db: ContentDB, gs: GameState, empire_id: int, trade_goods_income: int = 0) -> Dictionary:
	var emp: Empire = gs.empires[empire_id]
	var totals: Dictionary = Economy.empire_totals(db, gs, empire_id)

	var income: int = int(totals["income"]) + trade_goods_income
	var expenses: int = int(totals["expenses"])
	var net: int = income - expenses

	var new_treasury: int = emp.treasury + net
	var went_on_strike: bool = false
	if new_treasury < 0:
		emp.treasury = 0
		emp.strike_next_turn = true
		went_on_strike = true
	else:
		emp.treasury = new_treasury
		emp.strike_next_turn = false

	return {
		"income": income,
		"expenses": expenses,
		"net": net,
		"strike": went_on_strike
	}
