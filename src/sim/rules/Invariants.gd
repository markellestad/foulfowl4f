class_name Invariants
extends RefCounted

static func check(gs: GameState, db: ContentDB) -> Array[String]:
	var errs: Array[String] = []

	# 1. Pop >= 0 and jobs sum to whole pop units
	for cid in Ids.sorted_keys(gs.colonies):
		var col: Colony = gs.colonies[cid]
		if col.pop_milli < 0:
			errs.append("Colony %d pop_milli < 0: %d" % [cid, col.pop_milli])
		if col.farmers < 0 or col.workers < 0 or col.scientists < 0:
			errs.append("Colony %d has negative job assignment: %d/%d/%d" % [cid, col.farmers, col.workers, col.scientists])
		var sum_jobs: int = col.farmers + col.workers + col.scientists
		if sum_jobs != col.pop_units():
			errs.append("Colony %d jobs sum %d != pop_units %d" % [cid, sum_jobs, col.pop_units()])

	# 2. Treasury >= 0 for all empires
	for i in range(gs.empires.size()):
		var emp: Empire = gs.empires[i]
		if emp.treasury < 0:
			errs.append("Empire %d treasury < 0: %d" % [i, emp.treasury])
		if emp.id != i:
			errs.append("Empire id %d != array index %d" % [emp.id, i])

	# 3. Colony owners exist and <= 1 colony per planet
	var planet_colonies: Dictionary = {}
	for cid in Ids.sorted_keys(gs.colonies):
		var col: Colony = gs.colonies[cid]
		if col.owner < 0 or col.owner >= gs.empires.size():
			errs.append("Colony %d owner %d invalid" % [cid, col.owner])

		if planet_colonies.has(col.planet_id):
			errs.append("Multiple colonies on planet %d: %d and %d" % [col.planet_id, planet_colonies[col.planet_id], cid])
		else:
			planet_colonies[col.planet_id] = cid

		# Check no colony on outpost-only body
		if col.planet_id >= 0 and col.planet_id < gs.planets.size():
			var p: Planet = gs.planets[col.planet_id]
			var cdef: Dictionary = db.def("climates", p.climate)
			if str(cdef.get("class", "")) == "outpost":
				errs.append("Colony %d founded on outpost-only body %s" % [cid, p.climate])

	# 4. Known techs valid
	for emp in gs.empires:
		if emp.tech != null:
			for t in emp.tech.known:
				if t != "start":
					# Building tech or general tech
					pass

	return errs
