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

		# Find homeworld system and planet
		var hw_planet_id: int = -1
		var hw_sys: StarSystem = null
		for s in gs.systems:
			if s.home_of == i:
				hw_sys = s
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

		# Initialize Knowledge
		var knw: Knowledge = Knowledge.new()
		if hw_sys != null:
			knw.explored[hw_sys.id] = 1
		gs.knowledge[i] = knw

		# Starting designs
		var d_glance: ShipDesign = ShipDesign.new()
		d_glance.id = gs.alloc_id("design")
		d_glance.empire_id = i
		d_glance.name = "Glance"
		d_glance.role = "glance"
		d_glance.hull = "small"
		d_glance.drive = "walk_drive"
		d_glance.plate = "pinfeather_plate"
		d_glance.specials = ["glance_pod"]
		gs.designs[d_glance.id] = d_glance

		var d_nest: ShipDesign = ShipDesign.new()
		d_nest.id = gs.alloc_id("design")
		d_nest.empire_id = i
		d_nest.name = "Nest Ship"
		d_nest.role = "nest_ship"
		d_nest.hull = "medium"
		d_nest.drive = "walk_drive"
		d_nest.plate = "pinfeather_plate"
		d_nest.specials = ["nest_pod"]
		gs.designs[d_nest.id] = d_nest

		var d_sparrow: ShipDesign = ShipDesign.new()
		d_sparrow.id = gs.alloc_id("design")
		d_sparrow.empire_id = i
		d_sparrow.name = "Sparrow"
		d_sparrow.role = "talon_line"
		d_sparrow.hull = "small"
		d_sparrow.drive = "walk_drive"
		d_sparrow.plate = "pinfeather_plate"
		d_sparrow.weapons = [{"part": "wick_talon", "mount": "", "count": 4}]
		gs.designs[d_sparrow.id] = d_sparrow

		# Starting ships & fleets at homeworld
		if hw_sys != null:
			# Fleet 1: 2 Glance, 1 Nest Ship
			var f1: Fleet = Fleet.new()
			f1.id = gs.alloc_id("fleet")
			f1.owner = i
			f1.name = "1st Flock"
			f1.system_id = hw_sys.id
			f1.x = hw_sys.x
			f1.y = hw_sys.y

			var glance_st: Dictionary = DesignRules.stats(db, gs, d_glance)
			for _k in range(2):
				var s: Ship = Ship.new()
				s.id = gs.alloc_id("ship")
				s.design_id = d_glance.id
				s.owner = i
				s.fleet_id = f1.id
				s.hp = int(glance_st["hp"])
				s.built_turn = 1
				gs.ships[s.id] = s
				f1.ship_ids.append(s.id)

			var nest_st: Dictionary = DesignRules.stats(db, gs, d_nest)
			var s_nest: Ship = Ship.new()
			s_nest.id = gs.alloc_id("ship")
			s_nest.design_id = d_nest.id
			s_nest.owner = i
			s_nest.fleet_id = f1.id
			s_nest.hp = int(nest_st["hp"])
			s_nest.built_turn = 1
			gs.ships[s_nest.id] = s_nest
			f1.ship_ids.append(s_nest.id)
			gs.fleets[f1.id] = f1

			# Fleet 2: 2 Sparrows
			var f2: Fleet = Fleet.new()
			f2.id = gs.alloc_id("fleet")
			f2.owner = i
			f2.name = "2nd Flock"
			f2.system_id = hw_sys.id
			f2.x = hw_sys.x
			f2.y = hw_sys.y

			var sparrow_st: Dictionary = DesignRules.stats(db, gs, d_sparrow)
			for _k in range(2):
				var s: Ship = Ship.new()
				s.id = gs.alloc_id("ship")
				s.design_id = d_sparrow.id
				s.owner = i
				s.fleet_id = f2.id
				s.hp = int(sparrow_st["hp"])
				s.built_turn = 1
				gs.ships[s.id] = s
				f2.ship_ids.append(s.id)
			gs.fleets[f2.id] = f2

	for i in range(gs.empires.size()):
		Governor.assign_jobs(db, gs, i)
