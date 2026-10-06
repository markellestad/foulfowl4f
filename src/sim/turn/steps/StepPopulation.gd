class_name StepPopulation
extends TurnStep

var _phase: int = 0 # 0 = empire food & starvation, 1 = colony growth
var _work_colonies: Array = []
var _cursor: int = 0

func id() -> StringName:
	return &"population"

func begin(ctx: TurnContext) -> void:
	_phase = 0
	_work_colonies = Ids.sorted_keys(ctx.gs.colonies)
	_cursor = 0

func next(ctx: TurnContext) -> bool:
	if _phase == 0:
		for eid in range(ctx.gs.empires.size()):
			var emp: Empire = ctx.gs.empires[eid]
			var totals: Dictionary = Economy.empire_totals(ctx.db, ctx.gs, eid)
			var food_balance: int = int(totals["food_balance"])
			var sold_food: int = int(totals["food_sale_cr"]) * ctx.db.bal("food_sale_food_per_credit")
			var imported_food: int = 0
			var unpaid_food: int = 0

			if food_balance < 0:
				var deficit: int = -food_balance
				var import_rate: int = ctx.db.bal("food_import_credits_per_food")
				var cost: int = deficit * import_rate
				var paid_cr: int = min(emp.treasury, cost)
				imported_food = IntMath.floor_div(paid_cr, import_rate)
				emp.treasury -= imported_food * import_rate
				unpaid_food = deficit - imported_food

				if unpaid_food > 0:
					var starve_rate: int = ctx.db.bal("starve_food_per_pop")
					var pop_lost: int = IntMath.ceil_div(unpaid_food, starve_rate)
					var best_cid: int = -1
					var best_pop: int = -1
					for cid in Ids.sorted_keys(ctx.gs.colonies):
						var c: Colony = ctx.gs.colonies[cid]
						if c.owner == eid:
							if c.pop_milli > best_pop:
								best_pop = c.pop_milli
								best_cid = cid

					if best_cid >= 0:
						var target_col: Colony = ctx.gs.colonies[best_cid]
						target_col.pop_milli = max(0, target_col.pop_milli - pop_lost * 1000)
						var rem: int = pop_lost
						var rw: int = min(target_col.workers, rem)
						target_col.workers -= rw
						rem -= rw
						if rem > 0:
							var rs: int = min(target_col.scientists, rem)
							target_col.scientists -= rs
							rem -= rs
						if rem > 0:
							var rf: int = min(target_col.farmers, rem)
							target_col.farmers -= rf
							rem -= rf
						ctx.report.add_entry("colonies", "notify.starvation", {
							"place": "Colony %d" % best_cid
						}, "colony", best_cid)

			emp.food_last = {
				"produced": totals["food"],
				"eaten": totals["food_need"],
				"sold": sold_food,
				"imported": imported_food,
				"unpaid": unpaid_food
			}

		_phase = 1
		_cursor = 0
		return false

	# Phase 1: colony growth
	if _work_colonies.is_empty():
		return true

	var slice_count: int = ctx.db.bal("slice_items")
	var end_idx: int = min(_cursor + slice_count, _work_colonies.size())
	for i in range(_cursor, end_idx):
		var cid: int = int(_work_colonies[i])
		var col: Colony = ctx.gs.colonies[cid]
		if not col.blockaded:
			var old_u: int = col.pop_units()
			Growth.apply_growth(ctx.db, ctx.gs, cid)
			var new_u: int = col.pop_units()
			if new_u > old_u:
				# When pop units increase from growth, assign new pop to workers
				col.workers += (new_u - old_u)
				if col.owner == 0:
					var planet: Planet = ctx.gs.planets[col.planet_id]
					ctx.report.add_entry("colony", "notify.growth", {
						"pop": str(new_u),
						"place": "Star %d Orbit %d" % [planet.system_id, planet.orbit + 1]
					}, "colony", cid)

		# Garrison regen
		var max_garrison: int = 0
		for bid in col.buildings:
			var bdef: Dictionary = ctx.db.def("buildings", bid)
			var def_blk: Dictionary = bdef.get("defense", {})
			max_garrison += int(def_blk.get("garrison", 0))
		if max_garrison > 0:
			col.garrison = mini(max_garrison, col.garrison + ctx.db.bal("garrison_regen"))

		# Defense HP regen
		var max_def_hp: int = Defenses.calc_max_defense_hp(ctx.gs, ctx.db, col)
		if max_def_hp > 0:
			var regen_amt: int = IntMath.ceil_div(max_def_hp * ctx.db.bal("defense_regen_pct"), 100)
			col.defense_hp = mini(max_def_hp, col.defense_hp + regen_amt)

	_cursor = end_idx
	return _cursor >= _work_colonies.size()
