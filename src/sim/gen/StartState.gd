class_name StartState
extends RefCounted

static func apply(gs: GameState, db: ContentDB) -> void:
	var seats: Array = gs.settings.seats
	gs.empires.clear()
	for i in range(seats.size()):
		var race_id: String = str(seats[i])
		var emp: Empire = Empire.new()
		emp.id = i
		emp.race = race_id
		emp.is_ai = (i > 0)
		emp.alive = true
		emp.treasury = db.bal("start_credits")
		emp.tech = TechState.new()
		emp.tech.known = ["start"]
		var rdef: Dictionary = db.def("races", race_id)
		var raw_tr: Array = rdef.get("traits", [])
		for t in raw_tr:
			emp.traits.append(str(t))

		# Find homeworld planet
		var hw_planet_id: int = -1
		for s in gs.systems:
			if s.home_of == i:
				if not s.planet_ids.is_empty():
					hw_planet_id = s.planet_ids[0]
				break

		if hw_planet_id >= 0:
			var col: Colony = Colony.new()
			col.id = gs.alloc_id("colony")
			col.planet_id = hw_planet_id
			col.owner = i
			col.species = race_id
			col.pop_milli = db.bal("start_pop") * 1000
			col.preset = "capital"
			col.buildings = ["grand_nest", "the_yard", "boot_barracks"]
			col.founded_turn = 1
			gs.colonies[col.id] = col
			emp.capital_colony_id = col.id

		gs.empires.append(emp)

	for i in range(gs.empires.size()):
		Governor.assign_jobs(db, gs, i)
