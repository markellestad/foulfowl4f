class_name Production
extends RefCounted

static func cost_for_item(db: ContentDB, gs: GameState, colony_id: int, item: QueueItem) -> int:
	if item.kind == "building":
		var bdef: Dictionary = db.def("buildings", item.ref_id)
		var base_pp: int = int(bdef.get("pp", 0))
		var col: Colony = gs.colonies[colony_id]
		var ctx: Dictionary = {
			"empire_id": col.owner,
			"colony_id": colony_id
		}
		var cost_mod: ModResult = Modifiers.eval(db, gs, "building_cost_pct", 0, ctx)
		var final_cost: int = IntMath.pct(base_pp, 100 + cost_mod.value)
		return max(1, final_cost)
	return 0

static func buy_price(db: ContentDB, gs: GameState, colony_id: int) -> int:
	var col: Colony = gs.colonies[colony_id]
	if col.queue.is_empty():
		return 0
	var head: QueueItem = col.queue[0]
	if head.kind != "building" and head.kind != "ship":
		return 0
	var cost: int = cost_for_item(db, gs, colony_id, head)
	var remaining: int = max(0, cost - col.progress_pp)
	var price: int = IntMath.pct(remaining, db.bal("rush_mult_pct"))
	if col.progress_pp == 0:
		price = IntMath.pct(price, db.bal("rush_zero_progress_mult_pct"))
	return price

static func process_colony(db: ContentDB, gs: GameState, colony_id: int) -> Dictionary:
	var col: Colony = gs.colonies[colony_id]
	var emp: Empire = gs.empires[col.owner]
	var out: Dictionary = Economy.colony_output(db, gs, colony_id)
	var pp_available: int = (out["industry"] as ModResult).value

	var trade_goods_credits: int = 0
	var housing_milli_added: int = 0
	var completed_buildings: Array[String] = []

	# Check rush buy first
	if not col.queue.is_empty():
		var head: QueueItem = col.queue[0]
		if head.buy_requested and (head.kind == "building" or head.kind == "ship"):
			var price: int = buy_price(db, gs, colony_id)
			if emp.treasury >= price:
				emp.treasury -= price
				head.buy_requested = false
				# Complete head
				if head.kind == "building":
					col.buildings.append(head.ref_id)
					completed_buildings.append(head.ref_id)
				if head.count > 0:
					head.count -= 1
					if head.count == 0:
						col.queue.remove_at(0)
				col.progress_pp = 0

	# Now spend available PP through the queue
	while pp_available > 0 and not col.queue.is_empty():
		var head: QueueItem = col.queue[0]
		if head.kind == "trade_goods":
			var tg_ratio: int = db.bal("trade_goods_pp_per_credit")
			trade_goods_credits += IntMath.floor_div(pp_available, tg_ratio)
			pp_available = 0
			break
		elif head.kind == "housing":
			var h_rate: int = db.bal("housing_milli_per_pp")
			var pop_add: int = pp_available * h_rate
			var max_milli: int = Economy.max_pop_milli(db, gs, colony_id)
			var old_pop: int = col.pop_milli
			col.pop_milli = min(col.pop_milli + pop_add, max_milli)
			housing_milli_added += (col.pop_milli - old_pop)
			pp_available = 0
			break
		elif head.kind == "building":
			var cost: int = cost_for_item(db, gs, colony_id, head)
			var needed: int = cost - col.progress_pp
			if pp_available >= needed:
				pp_available -= needed
				col.buildings.append(head.ref_id)
				completed_buildings.append(head.ref_id)
				if head.count > 0:
					head.count -= 1
					if head.count == 0:
						col.queue.remove_at(0)
				col.progress_pp = 0
			else:
				col.progress_pp += pp_available
				pp_available = 0
		else:
			# Unknown kind or ship in later phases
			pp_available = 0
			break

	return {
		"completed_buildings": completed_buildings,
		"trade_goods_credits": trade_goods_credits,
		"housing_milli_added": housing_milli_added
	}
