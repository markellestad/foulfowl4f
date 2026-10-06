class_name Visibility
extends RefCounted

static func rebuild(db: ContentDB, gs: GameState, empire_id: int) -> void:
	var knw: Knowledge = gs.knowledge.get(empire_id)
	if knw == null:
		knw = Knowledge.new()
		gs.knowledge[empire_id] = knw

	var emp: Empire = gs.empires[empire_id]

	# Clear turn-specific visible fleets
	knw.visible_fleets.clear()

	# 1. Collect scan circles for this empire
	var circles: Array[Dictionary] = []

	var colony_scan_base: int = db.bal("colony_scan_dpc")
	var capital_scan_add: int = db.bal("capital_scan_add_dpc")
	var ship_scan_base: int = db.bal("ship_scan_dpc")

	# Scan from colonies
	for col in gs.colonies.values():
		if col.owner != empire_id:
			continue
		var p: Planet = gs.planets[col.planet_id]
		var sys: StarSystem = gs.systems[p.system_id]
		if col.is_outpost:
			circles.append({
				"x": sys.x,
				"y": sys.y,
				"radius": ship_scan_base,
				"is_colony": false
			})
		else:
			var r: int = colony_scan_base
			if col.preset == "capital" or emp.capital_colony_id == col.id:
				r += capital_scan_add
			for b in col.buildings:
				var bdef: Dictionary = db.def("buildings", b)
				for eff in bdef.get("effects", []):
					if eff.get("stat") == "scan_add":
						r += int(eff.get("value", 0)) * 10
			circles.append({
				"x": sys.x,
				"y": sys.y,
				"radius": r,
				"is_colony": true
			})

	# Scan from fleets
	for f in gs.fleets.values():
		if f.owner != empire_id:
			continue
		if f.ship_ids.is_empty():
			continue
		var max_r: int = ship_scan_base
		for sid in f.ship_ids:
			var s: Ship = gs.ships.get(sid)
			if s == null:
				continue
			var des: ShipDesign = gs.designs.get(s.design_id)
			if des == null:
				continue
			var st: Dictionary = DesignRules.stats(db, gs, des)
			var r: int = ship_scan_base + int(st.get("scan_dpc", 0))
			if r > max_r:
				max_r = r
		circles.append({
			"x": f.x,
			"y": f.y,
			"radius": max_r,
			"is_colony": false
		})

	# 2. Reveal systems inside circles
	for sys in gs.systems:
		for c in circles:
			if IntMath.dist(c["x"], c["y"], sys.x, sys.y) <= c["radius"]:
				if not knw.explored.has(sys.id):
					knw.explored[sys.id] = gs.turn
				break

	# 3. Reveal fleets
	var fleet_ids: Array = gs.fleets.keys()
	fleet_ids.sort()
	for fid in fleet_ids:
		var f: Fleet = gs.fleets[fid]
		if f.owner == empire_id:
			var des_ids: Array[int] = []
			for sid in f.ship_ids:
				var s: Ship = gs.ships.get(sid)
				if s != null and not des_ids.has(s.design_id):
					des_ids.append(s.design_id)
			knw.visible_fleets[f.id] = {
				"owner": f.owner,
				"x": f.x,
				"y": f.y,
				"ship_count": f.ship_ids.size(),
				"design_ids": des_ids,
				"dest_system_id": f.dest_system_id
			}
		else:
			var seen: bool = false
			for c in circles:
				if IntMath.dist(c["x"], c["y"], f.x, f.y) <= c["radius"]:
					seen = true
					break
			if seen:
				var des_ids: Array[int] = []
				for sid in f.ship_ids:
					var s: Ship = gs.ships.get(sid)
					if s != null and not des_ids.has(s.design_id):
						des_ids.append(s.design_id)
				knw.visible_fleets[f.id] = {
					"owner": f.owner,
					"x": f.x,
					"y": f.y,
					"ship_count": f.ship_ids.size(),
					"design_ids": des_ids,
					"dest_system_id": f.dest_system_id
				}
				if not knw.met.has(f.owner):
					knw.met[f.owner] = gs.turn

	# 4. Reveal colonies
	var col_ids: Array = gs.colonies.keys()
	col_ids.sort()
	for cid in col_ids:
		var col: Colony = gs.colonies[cid]
		if col.owner == empire_id:
			knw.seen_colonies[col.id] = {
				"owner": col.owner,
				"species": col.species,
				"pop_units": col.pop_units(),
				"buildings": col.buildings.duplicate(),
				"is_outpost": col.is_outpost,
				"turn_seen": gs.turn
			}
		else:
			var p: Planet = gs.planets[col.planet_id]
			var sys: StarSystem = gs.systems[p.system_id]
			var seen: bool = false
			var seen_by_colony: bool = false
			for c in circles:
				if IntMath.dist(c["x"], c["y"], sys.x, sys.y) <= c["radius"]:
					seen = true
					if c["is_colony"]:
						seen_by_colony = true
			if seen:
				var prev_buildings: Variant = null
				if knw.seen_colonies.has(col.id):
					prev_buildings = knw.seen_colonies[col.id].get("buildings")
				var buildings_val: Variant = col.buildings.duplicate() if seen_by_colony else prev_buildings
				knw.seen_colonies[col.id] = {
					"owner": col.owner,
					"species": col.species,
					"pop_units": col.pop_units(),
					"buildings": buildings_val,
					"is_outpost": col.is_outpost,
					"turn_seen": gs.turn
				}
				if not knw.met.has(col.owner):
					knw.met[col.owner] = gs.turn
