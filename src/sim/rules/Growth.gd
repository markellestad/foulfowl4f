class_name Growth
extends RefCounted

static func calc_growth(db: ContentDB, gs: GameState, colony_id: int) -> int:
	var colony: Colony = gs.colonies[colony_id]
	var P: int = colony.pop_milli
	var M: int = Economy.max_pop_milli(db, gs, colony_id)
	if colony.blockaded or P >= M or M <= 0:
		return 0
	var growth_k_pct: int = db.bal("growth_k_pct")
	var growth_flat_milli: int = db.bal("growth_flat_milli")
	var curve: int = IntMath.floor_div(P * (M - P), M)
	var base_growth: int = IntMath.pct(curve, growth_k_pct) + growth_flat_milli
	var ctx: Dictionary = {
		"empire_id": colony.owner,
		"colony_id": colony_id
	}
	var g_mod: ModResult = Modifiers.eval(db, gs, "growth_pct", 0, ctx)
	var growth: int = IntMath.pct(base_growth, 100 + g_mod.value)
	if P + growth > M:
		growth = M - P
	return max(0, growth)

static func apply_growth(db: ContentDB, gs: GameState, colony_id: int) -> int:
	var g: int = calc_growth(db, gs, colony_id)
	var colony: Colony = gs.colonies[colony_id]
	colony.pop_milli += g
	return g

static func format_growth(pop_milli: int, max_milli: int, growth_milli: int, blockaded: bool = false) -> String:
	if blockaded:
		return "Blockaded"
	if pop_milli >= max_milli:
		return "Full"
	if growth_milli <= 0:
		return "No growth"
	var cur_units: int = IntMath.floor_div(pop_milli, 1000)
	var next_threshold: int = min((cur_units + 1) * 1000, max_milli)
	var needed: int = next_threshold - pop_milli
	if needed <= 0:
		return "Full"
	var turns: int = IntMath.ceil_div(needed, growth_milli)
	if turns == 1:
		return "+1 pop in 1 turn"
	return "+1 pop in %d turns" % turns
