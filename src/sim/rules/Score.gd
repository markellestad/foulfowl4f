class_name Score
extends RefCounted

static func of(db: ContentDB, gs: GameState, empire_or_id: Variant) -> int:
	var empire_id: int = -1
	if empire_or_id is Empire:
		empire_id = (empire_or_id as Empire).id
	elif typeof(empire_or_id) == TYPE_INT:
		empire_id = int(empire_or_id)
	else:
		return 0

	if empire_id < 0 or empire_id >= gs.empires.size():
		return 0

	var emp: Empire = gs.empires[empire_id]
	if emp.eliminated_turn >= 0:
		return 0

	# 1. Pop & colonies & Orn
	var pop_units: int = 0
	var colony_count: int = 0
	var controls_orn: bool = false

	for cid in Ids.sorted_keys(gs.colonies):
		var col: Colony = gs.colonies[cid]
		if col.owner == empire_id and not col.is_outpost:
			colony_count += 1
			pop_units += col.pop_units()
			if col.planet_id >= 0 and col.planet_id < gs.planets.size():
				var p: Planet = gs.planets[col.planet_id]
				if p != null and p.system_id >= 0 and p.system_id < gs.systems.size():
					var sys: StarSystem = gs.systems[p.system_id]
					if sys != null and (sys.is_orn or sys.name_id == -2):
						controls_orn = true

	var pop_score: int = pop_units * db.bal("score_pop")
	var colony_score: int = colony_count * db.bal("score_colony")

	# 2. Techs
	var tech_count: int = 0
	if emp.tech != null:
		tech_count = emp.tech.known.size()
	var tech_score: int = tech_count * db.bal("score_tech")

	# 3. Fleet PP
	var fleet_pp: int = 0
	for sid in Ids.sorted_keys(gs.ships):
		var s: Ship = gs.ships[sid]
		if s.owner == empire_id and s.hp > 0:
			var des: ShipDesign = gs.designs.get(s.design_id)
			if des != null:
				var st: Dictionary = DesignRules.stats(db, gs, des)
				if bool(st.get("is_armed", false)):
					fleet_pp += int(st.get("cost_pp", 0))

	var div_bal: int = db.bal("score_fleet_pp_div")
	var fleet_score: int = IntMath.floor_div(fleet_pp, div_bal) if div_bal > 0 else 0

	# 4. Capital
	var capital_score: int = 0
	if emp.capital_colony_id >= 0 and gs.colonies.has(emp.capital_colony_id):
		var cap_col: Colony = gs.colonies[emp.capital_colony_id]
		if cap_col.owner == empire_id and not cap_col.is_outpost:
			capital_score = db.bal("score_capital")

	# 5. Orn
	var orn_score: int = db.bal("score_orn") if controls_orn else 0

	return pop_score + colony_score + tech_score + fleet_score + capital_score + orn_score
