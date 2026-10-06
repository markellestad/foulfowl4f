extends GutTest

var _db: ContentDB

func before_all() -> void:
	_db = ContentDB.load_from("res://data")

func _create_game(seed_str: String = "FOWL_TINY") -> GameState:
	var s: GameSettings = GameSettings.new()
	s.preset = "tiny"
	s.seed_string = seed_str
	s.seed = Rng.seed_from_string(seed_str)
	s.player_race = "pheasants"
	s.seat_swans = true
	var gs: GameState = GalaxyGenerator.generate(s, _db)
	StartState.apply(gs, _db)
	return gs

func test_scan_edge_and_boundary() -> void:
	var gs: GameState = _create_game("TEST_VIS_EDGE")

	# Homeworld capital has colony_scan_dpc (30) + capital_scan_add_dpc (20) + Grand Nest scan_add (20) = 70 dpc
	var hw_colony: Colony = gs.colonies[gs.empires[0].capital_colony_id]
	var hw_planet: Planet = gs.planets[hw_colony.planet_id]
	var hw_sys: StarSystem = gs.systems[hw_planet.system_id]

	# Create a foreign fleet (owned by empire 1) at exactly 70 dpc (edge)
	var f_edge: Fleet = Fleet.new()
	f_edge.id = gs.alloc_id("fleet")
	f_edge.owner = 1
	f_edge.system_id = -1
	f_edge.x = hw_sys.x + 70
	f_edge.y = hw_sys.y
	f_edge.ship_ids = []
	gs.fleets[f_edge.id] = f_edge

	# Create another foreign fleet at 71 dpc (1 dpc outside scan)
	var f_outside: Fleet = Fleet.new()
	f_outside.id = gs.alloc_id("fleet")
	f_outside.owner = 1
	f_outside.system_id = -1
	f_outside.x = hw_sys.x + 71
	f_outside.y = hw_sys.y
	f_outside.ship_ids = []
	gs.fleets[f_outside.id] = f_outside

	# Move all other empire 0 assets far away so only the homeworld colony scan reaches
	for fid in gs.fleets.keys():
		var f: Fleet = gs.fleets[fid]
		if f.owner == 0:
			f.x = 9999
			f.y = 9999

	Visibility.rebuild(_db, gs, 0)
	var knw0: Knowledge = gs.knowledge[0]

	assert_true(knw0.visible_fleets.has(f_edge.id), "Fleet at exactly 70 dpc is seen at edge")
	assert_false(knw0.visible_fleets.has(f_outside.id), "Fleet at 71 dpc is unseen (1 dpc outside)")

func test_met_empires_on_first_sight() -> void:
	var gs: GameState = _create_game("TEST_MET")

	var knw0: Knowledge = gs.knowledge[0]
	assert_false(knw0.met.has(1), "Empire 1 not met initially before visibility")

	# Place foreign fleet inside capital scan
	var hw_colony: Colony = gs.colonies[gs.empires[0].capital_colony_id]
	var hw_planet: Planet = gs.planets[hw_colony.planet_id]
	var hw_sys: StarSystem = gs.systems[hw_planet.system_id]

	var foreign_fleet: Fleet = Fleet.new()
	foreign_fleet.id = gs.alloc_id("fleet")
	foreign_fleet.owner = 1
	foreign_fleet.x = hw_sys.x + 10
	foreign_fleet.y = hw_sys.y
	foreign_fleet.system_id = -1
	gs.fleets[foreign_fleet.id] = foreign_fleet

	Visibility.rebuild(_db, gs, 0)
	assert_true(knw0.met.has(1), "Empire 1 marked as met on first sight")
	assert_eq(knw0.met[1], gs.turn, "Turn met recorded correctly")

func test_knowledge_isolation() -> void:
	var gs: GameState = _create_game("TEST_ISOLATION")

	# Empire 1 has an asset that sees empire 1's secret fleet
	# Empire 0 cannot see either
	var f_secret: Fleet = Fleet.new()
	f_secret.id = gs.alloc_id("fleet")
	f_secret.owner = 1
	f_secret.x = 5000
	f_secret.y = 5000
	f_secret.system_id = -1
	gs.fleets[f_secret.id] = f_secret

	Visibility.rebuild(_db, gs, 0)
	Visibility.rebuild(_db, gs, 1)

	var knw0: Knowledge = gs.knowledge[0]
	var knw1: Knowledge = gs.knowledge[1]

	assert_true(knw1.visible_fleets.has(f_secret.id), "Empire 1 sees its own secret fleet")
	assert_false(knw0.visible_fleets.has(f_secret.id), "Empire 0 does NOT see empire 1 secret fleet (isolation)")

func test_explored_systems_persist() -> void:
	var gs: GameState = _create_game("TEST_PERSIST")

	# Find a star system far from homeworld
	var scout_sys: StarSystem = null
	var hw_sys: StarSystem = gs.systems[0]
	for s in gs.systems:
		if IntMath.dist(hw_sys.x, hw_sys.y, s.x, s.y) > 200:
			scout_sys = s
			break
	assert_not_null(scout_sys, "Found far system")

	# Place scout fleet at scout_sys
	var scout_fleet: Fleet = Fleet.new()
	scout_fleet.id = gs.alloc_id("fleet")
	scout_fleet.owner = 0
	scout_fleet.x = scout_sys.x
	scout_fleet.y = scout_sys.y
	scout_fleet.system_id = scout_sys.id
	# Glance ship with glance pod
	var des: ShipDesign = ShipDesign.new()
	des.id = gs.alloc_id("design")
	des.empire_id = 0
	des.specials = ["glance_pod"]
	gs.designs[des.id] = des
	var shp: Ship = Ship.new()
	shp.id = gs.alloc_id("ship")
	shp.design_id = des.id
	shp.owner = 0
	gs.ships[shp.id] = shp
	scout_fleet.ship_ids = [shp.id]
	gs.fleets[scout_fleet.id] = scout_fleet

	# Rebuild visibility: scout explores scout_sys
	Visibility.rebuild(_db, gs, 0)
	var knw: Knowledge = gs.knowledge[0]
	assert_true(knw.explored.has(scout_sys.id), "Scout explored star system")

	# Now move scout far away
	scout_fleet.x = -9999
	scout_fleet.y = -9999
	scout_fleet.system_id = -1
	Visibility.rebuild(_db, gs, 0)

	# Explored system must persist!
	assert_true(knw.explored.has(scout_sys.id), "Explored star system persists after scout leaves")

func test_auto_explore_targeting() -> void:
	var gs: GameState = _create_game("TEST_AUTO_EXPLORE")
	var emp: Empire = gs.empires[0]
	var hw_colony: Colony = gs.colonies[emp.capital_colony_id]
	var hw_planet: Planet = gs.planets[hw_colony.planet_id]
	var hw_sys: StarSystem = gs.systems[hw_planet.system_id]

	# Find or create a fleet with auto_explore = true at homeworld
	var scout_fleet: Fleet = null
	for f in gs.fleets.values():
		if f.owner == 0 and f.system_id == hw_sys.id:
			scout_fleet = f
			break
	assert_not_null(scout_fleet, "Found fleet at homeworld")
	scout_fleet.auto_explore = true

	# Mark only hw_sys as explored
	var knw: Knowledge = gs.knowledge[0]
	knw.explored.clear()
	knw.explored[hw_sys.id] = 1

	# Process auto explore
	AutoExplore.process_empire(_db, gs, 0)

	# Fleet should have picked the nearest unexplored in-range star
	assert_true(scout_fleet.dest_system_id >= 0, "Auto-explore fleet picked a destination")
	assert_eq(scout_fleet.system_id, -1, "Auto-explore fleet is in transit (system_id == -1)")
	assert_true(FuelRange.in_range_system(_db, gs, 0, scout_fleet.dest_system_id), "Destination is in fuel range")
