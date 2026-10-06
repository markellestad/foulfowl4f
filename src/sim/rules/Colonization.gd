class_name Colonization
extends RefCounted

static func can_colonize(db: ContentDB, gs: GameState, empire_id: int, planet_id: int, fleet: Fleet = null) -> String:
	if planet_id < 0 or planet_id >= gs.planets.size():
		return "refuse.unknown"
	var planet: Planet = gs.planets[planet_id]
	for c in gs.colonies.values():
		if c.planet_id == planet_id:
			return "refuse.owned"
	if empire_id < 0 or empire_id >= gs.empires.size():
		return "refuse.unknown"
	var emp: Empire = gs.empires[empire_id]
	var traits: Array[String] = emp.species_traits(db)
	var flags: Array[String] = []
	if emp.tech != null:
		for k in emp.tech.known:
			flags.append(str(k))
	if Habitability.pop_per_size(db, traits, planet.climate, flags) <= 0:
		return "refuse.not_habitable"

	if fleet != null:
		if fleet.system_id != planet.system_id:
			return "refuse.not_here"
		var has_pod: bool = false
		for sid in fleet.ship_ids:
			var s: Ship = gs.ships.get(sid)
			if s == null:
				continue
			var des: ShipDesign = gs.designs.get(s.design_id)
			if des == null:
				continue
			var st: Dictionary = DesignRules.stats(db, gs, des)
			if bool(st.get("colonize", false)):
				has_pod = true
				break
		if not has_pod:
			return "refuse.no_pod"

	return ""

static func can_outpost(_db: ContentDB, gs: GameState, empire_id: int, planet_id: int, fleet: Fleet = null) -> String:
	if planet_id < 0 or planet_id >= gs.planets.size():
		return "refuse.unknown"
	var planet: Planet = gs.planets[planet_id]
	for c in gs.colonies.values():
		if c.planet_id == planet_id:
			return "refuse.owned"
	if empire_id < 0 or empire_id >= gs.empires.size():
		return "refuse.unknown"

	if fleet != null:
		if fleet.system_id != planet.system_id:
			return "refuse.not_here"
		var has_pod: bool = false
		for sid in fleet.ship_ids:
			var s: Ship = gs.ships.get(sid)
			if s == null:
				continue
			var des: ShipDesign = gs.designs.get(s.design_id)
			if des == null:
				continue
			var st: Dictionary = DesignRules.stats(_db, gs, des)
			if bool(st.get("outpost", false)):
				has_pod = true
				break
		if not has_pod:
			return "refuse.no_pod"

	return ""

static func consume_ship_with_stat(db: ContentDB, gs: GameState, fleet: Fleet, stat_key: String) -> int:
	for i in range(fleet.ship_ids.size()):
		var sid: int = fleet.ship_ids[i]
		var s: Ship = gs.ships.get(sid)
		if s == null:
			continue
		var des: ShipDesign = gs.designs.get(s.design_id)
		if des == null:
			continue
		var st: Dictionary = DesignRules.stats(db, gs, des)
		if bool(st.get(stat_key, false)):
			fleet.ship_ids.remove_at(i)
			gs.ships.erase(sid)
			if fleet.ship_ids.is_empty():
				gs.fleets.erase(fleet.id)
			return sid
	return -1

static func apply_colonization(db: ContentDB, gs: GameState, empire_id: int, planet_id: int) -> Colony:
	var planet: Planet = gs.planets[planet_id]
	var emp: Empire = gs.empires[empire_id]
	var col: Colony = Colony.new()
	col.id = gs.alloc_id("colony")
	col.planet_id = planet_id
	col.owner = empire_id
	col.species = emp.race
	col.is_outpost = false
	col.preset = "frontier"
	col.founded_turn = gs.turn
	if planet.special == "spare_nest":
		col.pop_milli = 2000
	else:
		col.pop_milli = db.bal("new_colony_pop_milli")
	col.buildings = []
	col.farmers = 0
	col.workers = 0
	col.scientists = 0
	gs.colonies[col.id] = col
	planet.colony_id = col.id
	Governor.assign_jobs(db, gs, empire_id)
	return col

static func apply_outpost(_db: ContentDB, gs: GameState, empire_id: int, planet_id: int) -> Colony:
	var planet: Planet = gs.planets[planet_id]
	var emp: Empire = gs.empires[empire_id]
	var col: Colony = Colony.new()
	col.id = gs.alloc_id("colony")
	col.planet_id = planet_id
	col.owner = empire_id
	col.species = emp.race
	col.is_outpost = true
	col.preset = "frontier"
	col.founded_turn = gs.turn
	col.pop_milli = 0
	col.buildings = []
	col.farmers = 0
	col.workers = 0
	col.scientists = 0
	gs.colonies[col.id] = col
	planet.colony_id = col.id
	return col
