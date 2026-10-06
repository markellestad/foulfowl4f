class_name Production
extends RefCounted

static func cost_for_item(db: ContentDB, gs: GameState, colony_id: int, item: QueueItem) -> int:
	var col: Colony = gs.colonies[colony_id]
	var ctx: Dictionary = {
		"empire_id": col.owner,
		"colony_id": colony_id
	}
	if item.kind == "building":
		var bdef: Dictionary = db.def("buildings", item.ref_id)
		var base_pp: int = int(bdef.get("pp", 0))
		var cost_mod: ModResult = Modifiers.eval(db, gs, "building_cost_pct", 0, ctx)
		var final_cost: int = IntMath.pct(base_pp, 100 + cost_mod.value)
		return max(1, final_cost)
	elif item.kind == "ship":
		var did: int = int(item.ref_id)
		if not gs.designs.has(did):
			return 0
		var design: ShipDesign = gs.designs[did]
		var st: Dictionary = DesignRules.stats(db, gs, design)
		var base_pp: int = int(st["pp"])
		var cost_mod: ModResult = Modifiers.eval(db, gs, "ship_cost_pct", 0, ctx)
		var final_cost: int = IntMath.pct(base_pp, 100 + cost_mod.value)
		return max(1, final_cost)
	elif item.kind == "colony_base":
		return db.bal("colony_base_pp")
	return 0

static func buy_price(db: ContentDB, gs: GameState, colony_id: int) -> int:
	var col: Colony = gs.colonies[colony_id]
	if col.queue.is_empty():
		return 0
	var head: QueueItem = col.queue[0]
	if head.kind != "building" and head.kind != "ship" and head.kind != "colony_base":
		return 0
	var cost: int = cost_for_item(db, gs, colony_id, head)
	var remaining: int = max(0, cost - col.progress_pp)
	var price: int = IntMath.pct(remaining, db.bal("rush_mult_pct"))
	if col.progress_pp == 0:
		price = IntMath.pct(price, db.bal("rush_zero_progress_mult_pct"))
	return price

static func _drain_nest_pop(col: Colony) -> void:
	col.pop_milli -= 1000
	var total_jobs: int = col.pop_units()
	var cur_jobs: int = col.farmers + col.workers + col.scientists
	while cur_jobs > total_jobs:
		if col.scientists > 0:
			col.scientists -= 1
		elif col.workers > 0:
			col.workers -= 1
		elif col.farmers > 0:
			col.farmers -= 1
		cur_jobs = col.farmers + col.workers + col.scientists

static func _add_ship_to_system_fleet(gs: GameState, ship: Ship, colony_id: int) -> void:
	var col: Colony = gs.colonies[colony_id]
	var sys_id: int = gs.planets[col.planet_id].system_id
	var target_fleet: Fleet = null
	for fid in Ids.sorted_keys(gs.fleets):
		var flt: Fleet = gs.fleets[fid]
		if flt.owner == col.owner and flt.system_id == sys_id and flt.order.is_empty():
			target_fleet = flt
			break
	if target_fleet != null:
		target_fleet.ship_ids.append(ship.id)
		ship.fleet_id = target_fleet.id
	else:
		var new_flt: Fleet = Fleet.new()
		new_flt.id = gs.alloc_id("fleet")
		new_flt.owner = col.owner
		new_flt.system_id = sys_id
		var sys: StarSystem = gs.systems[sys_id]
		new_flt.x = sys.x
		new_flt.y = sys.y
		new_flt.ship_ids = [ship.id]
		ship.fleet_id = new_flt.id
		gs.fleets[new_flt.id] = new_flt

static func _try_complete_head(db: ContentDB, gs: GameState, col: Colony, head: QueueItem, completed_buildings: Array[String], completed_ships: Array[int], notices: Array[Dictionary]) -> bool:
	if head.kind == "building":
		col.buildings.append(head.ref_id)
		completed_buildings.append(head.ref_id)
		return true
	elif head.kind == "ship":
		var did: int = int(head.ref_id)
		var des: ShipDesign = gs.designs.get(did)
		if des != null:
			var st: Dictionary = DesignRules.stats(db, gs, des)
			if bool(st.get("colonize", false)):
				if col.pop_units() < db.bal("nest_min_pop_units"):
					notices.append({
						"key": "notify.nest_waiting",
						"args": {
							"colony": "Colony %d" % col.id,
							"min_pop": db.bal("nest_min_pop_units")
						}
					})
					return false
				_drain_nest_pop(col)
			var s: Ship = Ship.new()
			s.id = gs.alloc_id("ship")
			s.design_id = did
			s.owner = col.owner
			s.hp = int(st["hp"])
			s.built_turn = gs.turn
			gs.ships[s.id] = s
			_add_ship_to_system_fleet(gs, s, col.id)
			completed_ships.append(s.id)
		return true
	elif head.kind == "colony_base":
		if col.pop_units() < db.bal("nest_min_pop_units"):
			notices.append({
				"key": "notify.nest_waiting",
				"args": {
					"colony": "Colony %d" % col.id,
					"min_pop": db.bal("nest_min_pop_units")
				}
			})
			return false
		_drain_nest_pop(col)
		var pid: int = int(head.ref_id)
		var new_col: Colony = Colony.new()
		new_col.id = gs.alloc_id("colony")
		new_col.planet_id = pid
		new_col.owner = col.owner
		new_col.species = col.species
		new_col.pop_milli = db.bal("new_colony_pop_milli")
		new_col.preset = "frontier"
		new_col.founded_turn = gs.turn
		gs.colonies[new_col.id] = new_col
		Governor.assign_jobs(db, gs, col.owner)
		return true
	return false

static func process_colony(db: ContentDB, gs: GameState, colony_id: int) -> Dictionary:
	var col: Colony = gs.colonies[colony_id]
	var emp: Empire = gs.empires[col.owner]
	var out: Dictionary = Economy.colony_output(db, gs, colony_id)
	var pp_available: int = (out["industry"] as ModResult).value

	var trade_goods_credits: int = 0
	var housing_milli_added: int = 0
	var completed_buildings: Array[String] = []
	var completed_ships: Array[int] = []
	var notices: Array[Dictionary] = []

	# Check rush buy first
	if not col.queue.is_empty():
		var head: QueueItem = col.queue[0]
		if head.buy_requested and (head.kind == "building" or head.kind == "ship" or head.kind == "colony_base"):
			var price: int = buy_price(db, gs, colony_id)
			if emp.treasury >= price:
				var did_complete: bool = _try_complete_head(db, gs, col, head, completed_buildings, completed_ships, notices)
				if did_complete:
					emp.treasury -= price
					head.buy_requested = false
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
		elif head.kind == "building" or head.kind == "ship" or head.kind == "colony_base":
			var cost: int = cost_for_item(db, gs, colony_id, head)
			var needed: int = cost - col.progress_pp
			if pp_available >= needed:
				var did_complete: bool = _try_complete_head(db, gs, col, head, completed_buildings, completed_ships, notices)
				if did_complete:
					pp_available -= needed
					if head.count > 0:
						head.count -= 1
						if head.count == 0:
							col.queue.remove_at(0)
					col.progress_pp = 0
				else:
					# Can't complete (e.g. nest waiting for pop)
					col.progress_pp = cost
					pp_available = 0
					break
			else:
				col.progress_pp += pp_available
				pp_available = 0
		else:
			pp_available = 0
			break

	return {
		"completed_buildings": completed_buildings,
		"completed_ships": completed_ships,
		"trade_goods_credits": trade_goods_credits,
		"housing_milli_added": housing_milli_added,
		"notices": notices
	}
