extends GutTest

var _db: ContentDB

func before_all() -> void:
	_db = ContentDB.load_from("res://data")
	Copy.load_file("res://data/copy/en.json")

func _setup_movement_state() -> Dictionary:
	var gs: GameState = GameState.new()
	var emp: Empire = Empire.new()
	emp.id = 0
	emp.tech = TechState.new()
	emp.tech.known = ["start"]
	gs.empires.append(emp)

	# System 0: (0, 0) - Homeworld
	var s0: StarSystem = StarSystem.new()
	s0.id = 0
	s0.x = 0
	s0.y = 0
	s0.home_of = 0
	gs.systems.append(s0)

	var p0: Planet = Planet.new()
	p0.id = 0
	p0.system_id = 0
	p0.climate = "terran"
	gs.planets.append(p0)
	s0.planet_ids.append(0)

	var col: Colony = Colony.new()
	col.id = 0
	col.planet_id = 0
	col.owner = 0
	col.pop_milli = 8000
	col.preset = "capital"
	gs.colonies[0] = col
	emp.capital_colony_id = 0

	# System 1: (50, 0)
	var s1: StarSystem = StarSystem.new()
	s1.id = 1
	s1.x = 50
	s1.y = 0
	gs.systems.append(s1)

	var p1: Planet = Planet.new()
	p1.id = 1
	p1.system_id = 1
	p1.climate = "terran"
	gs.planets.append(p1)
	s1.planet_ids.append(1)

	# System 2: (60, 0) - exactly at 60 dpc
	var s2: StarSystem = StarSystem.new()
	s2.id = 2
	s2.x = 60
	s2.y = 0
	gs.systems.append(s2)

	# System 3: (61, 0) - 1 dpc outside 60 dpc
	var s3: StarSystem = StarSystem.new()
	s3.id = 3
	s3.x = 61
	s3.y = 0
	gs.systems.append(s3)

	# System 4: (110, 0) - reachable from outpost at system 1
	var s4: StarSystem = StarSystem.new()
	s4.id = 4
	s4.x = 110
	s4.y = 0
	gs.systems.append(s4)

	# System 5 & 6: Wormhole pair
	var s5: StarSystem = StarSystem.new()
	s5.id = 5
	s5.x = 10
	s5.y = 10
	s5.wormhole_to = 6
	gs.systems.append(s5)

	var s6: StarSystem = StarSystem.new()
	s6.id = 6
	s6.x = 200
	s6.y = 200
	s6.wormhole_to = 5
	gs.systems.append(s6)

	# Sparrow design: map_speed 2
	var d: ShipDesign = ShipDesign.new()
	d.id = 0
	d.empire_id = 0
	d.hull = "small"
	d.drive = "walk_drive" # map_speed 2
	d.plate = "pinfeather_plate"
	gs.designs[0] = d

	# Ship and fleet at system 0
	var ship: Ship = Ship.new()
	ship.id = 0
	ship.design_id = 0
	ship.owner = 0
	ship.fleet_id = 0
	ship.hp = 20
	gs.ships[0] = ship

	var flt: Fleet = Fleet.new()
	flt.id = 0
	flt.owner = 0
	flt.system_id = 0
	flt.x = 0
	flt.y = 0
	flt.ship_ids = [0]
	gs.fleets[0] = flt

	var knw: Knowledge = Knowledge.new()
	knw.explored[0] = 1
	gs.knowledge[0] = knw

	return {"gs": gs, "fleet": flt}

func test_eta_turns_formula_and_wormhole() -> void:
	var ctx: Dictionary = _setup_movement_state()
	var gs: GameState = ctx["gs"]
	var flt: Fleet = ctx["fleet"]

	# Fleet speed is 2 pc/turn = 20 dpc/turn
	assert_eq(Movement.fleet_map_speed(_db, gs, flt.id), 2)

	# To System 1 (dist 50 dpc): ceil_div(50, 20) = 3 turns
	assert_eq(Movement.eta_turns(_db, gs, flt.id, 1), 3)

	# To System 2 (dist 60 dpc): ceil_div(60, 20) = 3 turns
	assert_eq(Movement.eta_turns(_db, gs, flt.id, 2), 3)

	# Move fleet to System 5 with wormhole to System 6
	flt.system_id = 5
	flt.x = 10
	flt.y = 10
	assert_eq(Movement.eta_turns(_db, gs, flt.id, 6), 1, "Wormhole pair is 1 turn")

func test_advance_and_position_lerp() -> void:
	var ctx: Dictionary = _setup_movement_state()
	var gs: GameState = ctx["gs"]
	var flt: Fleet = ctx["fleet"]

	# Start transit from (0, 0) to System 1 (50, 0) departing T1 arriving T4 (3 turns total)
	flt.system_id = -1
	flt.from_x = 0
	flt.from_y = 0
	flt.x = 0
	flt.y = 0
	flt.dest_system_id = 1
	flt.depart_turn = 1
	flt.arrive_turn = 4

	# At turn 1: 0 elapsed / 3 total -> (0, 0)
	gs.turn = 1
	Movement.advance(gs, flt)
	assert_eq(flt.x, 0)
	assert_eq(flt.y, 0)

	# At turn 2: 1 elapsed / 3 total -> lerp_i(0, 50, 1, 3) = 16
	gs.turn = 2
	Movement.advance(gs, flt)
	assert_eq(flt.x, IntMath.lerp_i(0, 50, 1, 3), "Turn 2 position equals lerp_i")
	assert_eq(flt.x, 16)

	# At turn 3: 2 elapsed / 3 total -> lerp_i(0, 50, 2, 3) = 33
	gs.turn = 3
	Movement.advance(gs, flt)
	assert_eq(flt.x, IntMath.lerp_i(0, 50, 2, 3), "Turn 3 position equals lerp_i")
	assert_eq(flt.x, 33)

	# At turn 4: arrived -> (50, 0)
	gs.turn = 4
	Movement.advance(gs, flt)
	assert_eq(flt.x, 50)
	assert_eq(flt.y, 0)

func test_range_boundary_and_outpost_extension() -> void:
	var ctx: Dictionary = _setup_movement_state()
	var gs: GameState = ctx["gs"]

	# Base range is 60 dpc
	assert_eq(FuelRange.fuel_range_dpc(_db, gs, 0), 60)

	# System 2 at (60, 0) is exactly at range (dist 60) -> ALLOW
	assert_true(FuelRange.in_range(_db, gs, 0, 60, 0), "Exactly at range 60 dpc is in range")

	# System 3 at (61, 0) is 1 dpc outside range (dist 61) -> REFUSE
	assert_false(FuelRange.in_range(_db, gs, 0, 61, 0), "1 dpc outside range 60 is out of range")

	# System 4 at (110, 0) is out of range from capital (dist 110)
	assert_false(FuelRange.in_range(_db, gs, 0, 110, 0), "System 4 is out of range before outpost")

	# Plant an outpost at System 1 (50, 0)
	var outpost: Colony = Colony.new()
	outpost.id = 1
	outpost.planet_id = 1
	outpost.owner = 0
	outpost.is_outpost = true
	outpost.pop_milli = 0
	gs.colonies[1] = outpost

	# Now System 4 (110, 0) is dist 60 from outpost at (50, 0) -> ALLOW
	assert_true(FuelRange.in_range(_db, gs, 0, 110, 0), "Outpost extends range: System 4 now in range")

func test_redirect_mid_flight_continues_from_current_position() -> void:
	var ctx: Dictionary = _setup_movement_state()
	var gs: GameState = ctx["gs"]
	var flt: Fleet = ctx["fleet"]

	# Flying to System 1 (50, 0)
	flt.system_id = -1
	flt.from_x = 0
	flt.from_y = 0
	flt.dest_system_id = 1
	flt.depart_turn = 1
	flt.arrive_turn = 4

	# At turn 2, fleet advances to (16, 0)
	gs.turn = 2
	Movement.advance(gs, flt)
	assert_eq(flt.x, 16)

	# Redirect to System 2 (60, 0) mid-flight
	# Remaining dist from (16, 0) to (60, 0) = 44 dpc. Speed 20 dpc/t -> ceil_div(44, 20) = 3 turns
	var eta: int = Movement.eta_turns(_db, gs, flt.id, 2)
	assert_eq(eta, 3)

	flt.from_x = flt.x
	flt.from_y = flt.y
	flt.dest_system_id = 2
	flt.depart_turn = gs.turn
	flt.arrive_turn = gs.turn + eta

	assert_eq(flt.from_x, 16, "Redirect continues from current position (16, 0)")
	assert_eq(flt.dest_system_id, 2)

	# Advance 1 turn to turn 3: lerp_i(16, 60, 1, 3) = 16 + 44/3 = 16 + 14 = 30
	gs.turn = 3
	Movement.advance(gs, flt)
	assert_eq(flt.x, 30)
