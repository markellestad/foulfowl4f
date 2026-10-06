class_name Economy
extends RefCounted

static func mineral_base_pp(minerals: String) -> int:
	match minerals:
		"ultra_poor":
			return 1
		"poor":
			return 2
		"abundant":
			return 3
		"rich":
			return 4
		"ultra_rich":
			return 6
		_:
			return 3

static func planet_size_val(size: String) -> int:
	match size:
		"tiny":
			return 1
		"small":
			return 2
		"medium":
			return 3
		"large":
			return 4
		"huge":
			return 5
		_:
			return 3

static func job_yields(db: ContentDB, gs: GameState, colony_id: int) -> Dictionary:
	var colony: Colony = gs.colonies[colony_id]
	var planet: Planet = gs.planets[colony.planet_id]
	var emp: Empire = gs.empires[colony.owner]
	var cdef: Dictionary = db.def("climates", planet.climate)

	var species: String = colony.species
	var rdef: Dictionary = db.def("races", species)
	var species_traits: Array = rdef.get("traits", [])
	if species == emp.race:
		species_traits = emp.traits

	var has_piscivore: bool = species_traits.has("piscivore")
	var has_tolerant: bool = species_traits.has("tolerant")

	var base_food: int = int(cdef.get("fish", 0)) if has_piscivore else int(cdef.get("farm", 0))

	var food_ctx: Dictionary = {
		"empire_id": colony.owner,
		"colony_id": colony_id,
		"climate": planet.climate,
		"gravity": planet.gravity
	}
	if has_tolerant and not has_piscivore:
		food_ctx["effects"] = [{
			"stat": "food_per_farmer",
			"op": "floor",
			"value": 1,
			"source_key": "tolerant"
		}]

	var food_res: ModResult = Modifiers.eval(db, gs, "food_per_farmer", base_food, food_ctx)

	var base_pp: int = mineral_base_pp(planet.minerals)
	var ind_ctx: Dictionary = {
		"empire_id": colony.owner,
		"colony_id": colony_id,
		"climate": planet.climate,
		"gravity": planet.gravity
	}
	var pp_res: ModResult = Modifiers.eval(db, gs, "industry_per_worker", base_pp, ind_ctx)

	var base_rp: int = db.bal("base_rp_per_scientist")
	var res_ctx: Dictionary = {
		"empire_id": colony.owner,
		"colony_id": colony_id,
		"climate": planet.climate,
		"gravity": planet.gravity
	}
	var rp_res: ModResult = Modifiers.eval(db, gs, "research_per_scientist", base_rp, res_ctx)

	return {
		"food_per_farmer": food_res,
		"pp_per_worker": pp_res,
		"rp_per_scientist": rp_res
	}

static func colony_output(db: ContentDB, gs: GameState, colony_id: int) -> Dictionary:
	var colony: Colony = gs.colonies[colony_id]
	var planet: Planet = gs.planets[colony.planet_id]
	var jy: Dictionary = job_yields(db, gs, colony_id)
	var ctx: Dictionary = {
		"empire_id": colony.owner,
		"colony_id": colony_id,
		"climate": planet.climate,
		"gravity": planet.gravity
	}

	var raw_food: int = colony.farmers * (jy["food_per_farmer"] as ModResult).value
	var f_ctx: Dictionary = ctx.duplicate()
	f_ctx["base_source"] = "farmers"
	var food_res: ModResult = Modifiers.eval(db, gs, "food", raw_food, f_ctx)

	var raw_ind: int = colony.workers * (jy["pp_per_worker"] as ModResult).value
	var ind_ctx: Dictionary = ctx.duplicate()
	ind_ctx["base_source"] = "workers"
	var ind_res: ModResult = Modifiers.eval(db, gs, "industry", raw_ind, ind_ctx)

	var raw_res: int = colony.scientists * (jy["rp_per_scientist"] as ModResult).value
	var res_ctx: Dictionary = ctx.duplicate()
	res_ctx["base_source"] = "scientists"
	var res_res: ModResult = Modifiers.eval(db, gs, "research", raw_res, res_ctx)

	var pop_u: int = colony.pop_units()
	var raw_tax: int = pop_u * db.bal("tax_per_pop")
	var tax_ctx: Dictionary = ctx.duplicate()
	tax_ctx["base_source"] = "pop"
	var tax_res: ModResult = Modifiers.eval(db, gs, "taxes", raw_tax, tax_ctx)

	var cred_res: ModResult = Modifiers.eval(db, gs, "credits", 0, ctx)

	return {
		"food": food_res,
		"industry": ind_res,
		"research": res_res,
		"taxes": tax_res,
		"credits": cred_res
	}

static func max_pop_milli(db: ContentDB, gs: GameState, colony_id: int) -> int:
	var colony: Colony = gs.colonies[colony_id]
	var planet: Planet = gs.planets[colony.planet_id]
	var sz_val: int = planet_size_val(planet.size)

	var flags: Array[String] = []
	for bid in colony.buildings:
		var bdef: Dictionary = db.def("buildings", bid)
		for f in bdef.get("flags", []):
			flags.append(str(f))

	var emp: Empire = gs.empires[colony.owner]
	var species_traits: Array = emp.traits
	if colony.species != "" and colony.species != emp.race:
		var rdef: Dictionary = db.def("races", colony.species)
		species_traits = rdef.get("traits", [])

	var tr_arr: Array[String] = []
	for t in species_traits:
		tr_arr.append(str(t))

	var base_pps: int = Habitability.pop_per_size(db, tr_arr, planet.climate, flags)
	var ctx: Dictionary = {
		"empire_id": colony.owner,
		"colony_id": colony_id,
		"climate": planet.climate,
		"gravity": planet.gravity
	}
	var pps_res: ModResult = Modifiers.eval(db, gs, "pop_per_size", base_pps, ctx)
	var flat_res: ModResult = Modifiers.eval(db, gs, "max_pop_flat", 0, ctx)

	var total_max_units: int = sz_val * pps_res.value + flat_res.value
	return total_max_units * 1000

static func max_pop_units(db: ContentDB, gs: GameState, colony_id: int) -> int:
	return IntMath.floor_div(max_pop_milli(db, gs, colony_id), 1000)

static func admin_cost_for(colony_count: int, db: ContentDB) -> int:
	if colony_count <= 1:
		return 0
	var cost_low: int = db.bal("admin_cost")
	var cost_high: int = db.bal("admin_cost_high")
	var high_after: int = db.bal("admin_high_after")

	if colony_count <= high_after:
		return (colony_count - 1) * cost_low

	var low_colonies: int = high_after - 1
	var high_colonies: int = colony_count - high_after
	return low_colonies * cost_low + high_colonies * cost_high

static func empire_totals(db: ContentDB, gs: GameState, empire_id: int) -> Dictionary:
	var food_total: int = 0
	var industry_total: int = 0
	var research_total: int = 0
	var taxes_total: int = 0
	var credits_flat_total: int = 0
	var food_need: int = 0
	var upkeep: int = 0
	var colony_count: int = 0

	for cid in Ids.sorted_keys(gs.colonies):
		var col: Colony = gs.colonies[cid]
		if col.owner != empire_id:
			continue
		colony_count += 1
		var out: Dictionary = colony_output(db, gs, cid)
		food_total += (out["food"] as ModResult).value
		industry_total += (out["industry"] as ModResult).value
		research_total += (out["research"] as ModResult).value
		taxes_total += (out["taxes"] as ModResult).value
		credits_flat_total += (out["credits"] as ModResult).value

		food_need += col.pop_units() * db.bal("food_eaten_per_pop")

		for bid in col.buildings:
			var bdef: Dictionary = db.def("buildings", bid)
			upkeep += int(bdef.get("upkeep", 0))

	var admin: int = admin_cost_for(colony_count, db)
	var food_balance: int = food_total - food_need
	var surplus_food: int = max(0, food_balance)
	var food_sale_cr: int = IntMath.floor_div(surplus_food, db.bal("food_sale_food_per_credit"))

	var income: int = taxes_total + credits_flat_total + food_sale_cr
	var expenses: int = upkeep + admin
	var net_credits: int = income - expenses

	return {
		"food": food_total,
		"industry": industry_total,
		"research": research_total,
		"taxes": taxes_total,
		"credits_flat": credits_flat_total,
		"food_need": food_need,
		"food_balance": food_balance,
		"surplus_food": surplus_food,
		"food_sale_cr": food_sale_cr,
		"upkeep": upkeep,
		"admin": admin,
		"income": income,
		"expenses": expenses,
		"net_credits": net_credits
	}
