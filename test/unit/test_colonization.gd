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

func test_colonize_validation() -> void:
	var gs: GameState = _create_game("TEST_COL_VAL")
	var emp: Empire = gs.empires[0]

	# Find a habitable unowned planet in the homeworld system or nearby
	var hw_colony: Colony = gs.colonies[emp.capital_colony_id]
	var hw_planet: Planet = gs.planets[hw_colony.planet_id]
	var hw_sys: StarSystem = gs.systems[hw_planet.system_id]

	# Fleet 0 at homeworld has Glance + Nest Ship
	var fleet: Fleet = null
	for f in gs.fleets.values():
		if f.owner == 0 and f.system_id == hw_sys.id:
			# Check if fleet has nest ship
			for sid in f.ship_ids:
				var s: Ship = gs.ships[sid]
				var d: ShipDesign = gs.designs[s.design_id]
				if d.name == "Nest Ship":
					fleet = f
					break
		if fleet != null:
			break
	assert_not_null(fleet, "Found starting fleet with Nest Ship")

	# 1. Owned homeworld planet -> REFUSE refuse.owned
	var err_owned: String = Colonization.can_colonize(_db, gs, 0, hw_planet.id, fleet)
	assert_eq(err_owned, "refuse.owned", "Cannot colonize already owned planet")

	# Create a dummy habitable unowned planet in homeworld system
	var hab_p: Planet = Planet.new()
	hab_p.id = gs.planets.size()
	hab_p.system_id = hw_sys.id
	hab_p.orbit = 4
	hab_p.climate = "terran"
	hab_p.size = "medium"
	hab_p.minerals = "abundant"
	gs.planets.append(hab_p)

	# 2. Habitable unowned planet with nest ship present -> ALLOW ("")
	var err_allow: String = Colonization.can_colonize(_db, gs, 0, hab_p.id, fleet)
	assert_eq(err_allow, "", "Can colonize habitable unowned planet")

	# 3. Hostile without dome -> REFUSE refuse.not_habitable
	var host_p: Planet = Planet.new()
	host_p.id = gs.planets.size()
	host_p.system_id = hw_sys.id
	host_p.orbit = 5
	host_p.climate = "barren"
	host_p.size = "medium"
	host_p.minerals = "abundant"
	gs.planets.append(host_p)

	var err_hostile: String = Colonization.can_colonize(_db, gs, 0, host_p.id, fleet)
	assert_eq(err_hostile, "refuse.not_habitable", "Hostile planet without dome refuses")

	# 4. Fleet not at system -> REFUSE refuse.not_here
	fleet.system_id = 999
	var err_not_here: String = Colonization.can_colonize(_db, gs, 0, hab_p.id, fleet)
	assert_eq(err_not_here, "refuse.not_here", "Fleet not in system refuses")
	fleet.system_id = hw_sys.id

	# 5. Fleet with no colonize pod -> REFUSE refuse.no_pod
	# Fleet 1 has 2 Sparrows (weapons only)
	var war_fleet: Fleet = null
	for f in gs.fleets.values():
		if f.owner == 0 and f.id != fleet.id:
			war_fleet = f
			break
	assert_not_null(war_fleet, "Found war fleet")
	var err_no_pod: String = Colonization.can_colonize(_db, gs, 0, hab_p.id, war_fleet)
	assert_eq(err_no_pod, "refuse.no_pod", "Fleet without colonize pod refuses")

func test_outpost_validation_and_economy() -> void:
	var gs: GameState = _create_game("TEST_OUTPOST")
	var emp: Empire = gs.empires[0]
	var hw_colony: Colony = gs.colonies[emp.capital_colony_id]
	var hw_planet: Planet = gs.planets[hw_colony.planet_id]
	var hw_sys: StarSystem = gs.systems[hw_planet.system_id]

	# Create a stake ship design and ship
	var d_stake: ShipDesign = ShipDesign.new()
	d_stake.id = gs.alloc_id("design")
	d_stake.empire_id = 0
	d_stake.name = "Stake Ship"
	d_stake.role = "stake_ship"
	d_stake.hull = "small"
	d_stake.drive = "walk_drive"
	d_stake.specials = ["perch_pod"]
	gs.designs[d_stake.id] = d_stake

	var s_stake: Ship = Ship.new()
	s_stake.id = gs.alloc_id("ship")
	s_stake.design_id = d_stake.id
	s_stake.owner = 0
	s_stake.hp = 8
	gs.ships[s_stake.id] = s_stake

	var f_stake: Fleet = Fleet.new()
	f_stake.id = gs.alloc_id("fleet")
	f_stake.owner = 0
	f_stake.system_id = hw_sys.id
	f_stake.ship_ids = [s_stake.id]
	gs.fleets[f_stake.id] = f_stake

	# Asteroids planet (outpost class)
	var ast_p: Planet = Planet.new()
	ast_p.id = gs.planets.size()
	ast_p.system_id = hw_sys.id
	ast_p.orbit = 6
	ast_p.climate = "asteroids"
	ast_p.size = "tiny"
	ast_p.minerals = "ultra_rich"
	gs.planets.append(ast_p)

	# can_colonize should REFUSE refuse.not_habitable
	var err_col: String = Colonization.can_colonize(_db, gs, 0, ast_p.id, f_stake)
	assert_eq(err_col, "refuse.not_habitable", "Cannot colonize asteroids")

	# can_outpost should ALLOW
	var err_out: String = Colonization.can_outpost(_db, gs, 0, ast_p.id, f_stake)
	assert_eq(err_out, "", "Can outpost unowned asteroids")

	# Order outpost and step orbital
	f_stake.order = {"type": "outpost", "planet_id": ast_p.id}
	var tp: TurnProcessor = TurnProcessor.new(gs, _db)
	# Advance through movement to orbital
	tp.run_next_substep() # movement
	tp.run_next_substep() # orbital

	# Verify outpost was founded
	assert_true(ast_p.colony_id >= 0, "Planet has colony_id set")
	var outpost: Colony = gs.colonies[ast_p.colony_id]
	assert_true(outpost.is_outpost, "Colony is marked is_outpost")
	assert_eq(outpost.pop_milli, 0, "Outpost has 0 pop")
	assert_eq(outpost.preset, "frontier", "Outpost has frontier preset")
	assert_false(gs.fleets.has(f_stake.id), "Stake fleet consumed")
	assert_false(gs.ships.has(s_stake.id), "Stake ship consumed")

	# Check administration cost: outpost does NOT increase colony count or admin cost
	var col_count: int = Economy.colony_count(gs, 0)
	assert_eq(col_count, 1, "Colony count excludes outposts")
	var admin: int = Economy.admin_cost(gs, 0, col_count, _db)
	assert_eq(admin, 0, "Admin cost only charges for 1 real colony (capital is 0)")

func test_colonization_resolution_and_spare_nest() -> void:
	var gs: GameState = _create_game("TEST_COL_RES")
	var emp: Empire = gs.empires[0]
	var hw_colony: Colony = gs.colonies[emp.capital_colony_id]
	var hw_planet: Planet = gs.planets[hw_colony.planet_id]
	var hw_sys: StarSystem = gs.systems[hw_planet.system_id]

	# Find starting nest ship fleet
	var nest_fleet: Fleet = null
	for f in gs.fleets.values():
		if f.owner == 0 and f.system_id == hw_sys.id:
			for sid in f.ship_ids:
				var s: Ship = gs.ships[sid]
				var d: ShipDesign = gs.designs[s.design_id]
				if d.name == "Nest Ship":
					nest_fleet = f
					break
		if nest_fleet != null:
			break

	# Create a planet with spare_nest special
	var sn_planet: Planet = Planet.new()
	sn_planet.id = gs.planets.size()
	sn_planet.system_id = hw_sys.id
	sn_planet.orbit = 4
	sn_planet.climate = "gaia"
	sn_planet.size = "large"
	sn_planet.minerals = "rich"
	sn_planet.special = "spare_nest"
	gs.planets.append(sn_planet)

	var orig_ship_count: int = nest_fleet.ship_ids.size()
	nest_fleet.order = {"type": "colonize", "planet_id": sn_planet.id}

	var tp: TurnProcessor = TurnProcessor.new(gs, _db)
	tp.run_next_substep() # movement
	tp.run_next_substep() # orbital

	assert_true(sn_planet.colony_id >= 0, "Planet has colony_id")
	var new_col: Colony = gs.colonies[sn_planet.colony_id]
	assert_eq(new_col.preset, "frontier", "Preset is frontier")
	assert_eq(new_col.pop_milli, 2000, "Spare nest special starts with 2000 milli pop (2 pop)")
	assert_eq(nest_fleet.ship_ids.size(), orig_ship_count - 1, "Nest ship consumed from fleet")

func test_contested_colonization_keyed_coin() -> void:
	# Run two identical simulations with two empires claiming the same planet
	var simulate_contested := func(seed_val: String) -> int:
		var gs: GameState = _create_game(seed_val)
		var hw_sys: StarSystem = gs.systems[0]

		var target_p: Planet = Planet.new()
		target_p.id = gs.planets.size()
		target_p.system_id = hw_sys.id
		target_p.orbit = 7
		target_p.climate = "terran"
		target_p.size = "medium"
		target_p.minerals = "abundant"
		gs.planets.append(target_p)

		# Give empire 0 and empire 1 a nest ship fleet at hw_sys
		var des0: ShipDesign = ShipDesign.new()
		des0.id = gs.alloc_id("design")
		des0.empire_id = 0
		des0.hull = "medium"
		des0.drive = "walk_drive"
		des0.specials = ["nest_pod"]
		gs.designs[des0.id] = des0

		var des1: ShipDesign = ShipDesign.new()
		des1.id = gs.alloc_id("design")
		des1.empire_id = 1
		des1.hull = "medium"
		des1.drive = "walk_drive"
		des1.specials = ["nest_pod"]
		gs.designs[des1.id] = des1

		var s0: Ship = Ship.new()
		s0.id = gs.alloc_id("ship")
		s0.design_id = des0.id
		s0.owner = 0
		gs.ships[s0.id] = s0

		var s1: Ship = Ship.new()
		s1.id = gs.alloc_id("ship")
		s1.design_id = des1.id
		s1.owner = 1
		gs.ships[s1.id] = s1

		var f0: Fleet = Fleet.new()
		f0.id = gs.alloc_id("fleet")
		f0.owner = 0
		f0.system_id = hw_sys.id
		f0.ship_ids = [s0.id]
		f0.order = {"type": "colonize", "planet_id": target_p.id}
		gs.fleets[f0.id] = f0

		var f1: Fleet = Fleet.new()
		f1.id = gs.alloc_id("fleet")
		f1.owner = 1
		f1.system_id = hw_sys.id
		f1.ship_ids = [s1.id]
		f1.order = {"type": "colonize", "planet_id": target_p.id}
		gs.fleets[f1.id] = f1

		var tp: TurnProcessor = TurnProcessor.new(gs, _db)
		tp.run_next_substep() # movement
		tp.run_next_substep() # orbital

		assert_true(target_p.colony_id >= 0, "Colony founded")
		var col: Colony = gs.colonies[target_p.colony_id]
		return col.owner

	var winner_run1: int = simulate_contested.call("KEYED_COIN_1")
	var winner_run2: int = simulate_contested.call("KEYED_COIN_1")
	assert_eq(winner_run1, winner_run2, "Deterministic keyed coin winner on replay")
	assert_true(winner_run1 == 0 or winner_run1 == 1, "Winner is either empire 0 or empire 1")

func test_nest_ship_pop_drain_wait_and_launch() -> void:
	var gs: GameState = _create_game("TEST_NEST_DRAIN")
	var emp: Empire = gs.empires[0]
	var col: Colony = gs.colonies[emp.capital_colony_id]

	# Find Nest Ship design
	var nest_des_id: int = -1
	for d in gs.designs.values():
		if d.empire_id == 0 and d.name == "Nest Ship":
			nest_des_id = d.id
			break
	assert_true(nest_des_id >= 0, "Found nest ship design")

	# Set colony pop to 2000 milli (pop_units = 2 < 3 min pop)
	col.pop_milli = 2000
	col.queue.clear()

	var q: QueueItem = QueueItem.new()
	q.kind = "ship"
	q.ref_id = str(nest_des_id)
	q.count = 1
	col.progress_pp = 0
	col.queue.append(q)

	# Process production with enough PP to complete the ship
	col.farmers = 0
	col.workers = 2
	col.scientists = 0
	# Give huge progress so it's ready to complete
	col.progress_pp = 1000

	var res: Dictionary = Production.process_colony(_db, gs, col.id)
	assert_eq(res["completed_ships"].size(), 0, "Ship did not complete because pop < 3")
	assert_eq(col.pop_milli, 2000, "Pop was not drained while waiting")
	assert_eq(col.queue.size(), 1, "Queue item remains")

	var notices: Array = res["notices"]
	assert_eq(notices.size(), 1, "Emitted waiting notice")
	assert_eq(notices[0]["key"], "notify.nest_waiting", "Notice key is notify.nest_waiting")

	# Now increase pop to 3000 milli (pop_units = 3 >= 3)
	col.pop_milli = 3000
	var res2: Dictionary = Production.process_colony(_db, gs, col.id)
	assert_eq(res2["completed_ships"].size(), 1, "Ship completes when pop >= 3")
	assert_eq(col.pop_milli, 2000, "Pop drained by 1000 milli to 2000")
	assert_eq(col.queue.size(), 0, "Queue item finished")
