extends GutTest

var _db: ContentDB

func before_all() -> void:
	_db = ContentDB.load_from("res://data")

func _create_game(seed_str: String = "SIEGE_TEST") -> GameState:
	var s: GameSettings = GameSettings.new()
	s.preset = "tiny"
	s.seed_string = seed_str
	s.seed = Rng.seed_from_string(seed_str)
	s.player_race = "pheasants"
	s.seat_swans = true
	var gs: GameState = GalaxyGenerator.generate(s, _db)
	StartState.apply(gs, _db)
	return gs

func test_repair_locations() -> void:
	var gs: GameState = _create_game("TEST_REPAIR")
	var emp: Empire = gs.empires[0]
	var hw_colony: Colony = gs.colonies[emp.capital_colony_id]
	var hw_planet: Planet = gs.planets[hw_colony.planet_id]
	var hw_sys: StarSystem = gs.systems[hw_planet.system_id]

	# Create a second system with a plain colony (no yard)
	var plain_sys: StarSystem = gs.systems[1]
	var plain_planet: Planet = gs.planets[plain_sys.planet_ids[0]]
	var plain_col: Colony = Colonization.apply_colonization(_db, gs, 0, plain_planet.id)
	plain_col.buildings.clear() # No grand_nest, no the_yard

	# Create design with 100 HP
	var des: ShipDesign = ShipDesign.new()
	des.id = gs.alloc_id("design")
	des.empire_id = 0
	des.hull = "large"
	des.drive = "walk_drive"
	gs.designs[des.id] = des

	# Ship 1: at plain colony (20% heal)
	var s_plain: Ship = Ship.new()
	s_plain.id = gs.alloc_id("ship")
	s_plain.design_id = des.id
	s_plain.owner = 0
	s_plain.hp = 10
	gs.ships[s_plain.id] = s_plain
	var f_plain: Fleet = Fleet.new()
	f_plain.id = gs.alloc_id("fleet")
	f_plain.owner = 0
	f_plain.system_id = plain_sys.id
	f_plain.ship_ids = [s_plain.id]
	s_plain.fleet_id = f_plain.id
	gs.fleets[f_plain.id] = f_plain

	# Ship 2: at yard / capital (100% heal)
	var s_yard: Ship = Ship.new()
	s_yard.id = gs.alloc_id("ship")
	s_yard.design_id = des.id
	s_yard.owner = 0
	s_yard.hp = 10
	gs.ships[s_yard.id] = s_yard
	var f_yard: Fleet = Fleet.new()
	f_yard.id = gs.alloc_id("fleet")
	f_yard.owner = 0
	f_yard.system_id = hw_sys.id
	f_yard.ship_ids = [s_yard.id]
	s_yard.fleet_id = f_yard.id
	gs.fleets[f_yard.id] = f_yard

	# Ship 3: in deep space / transit (0% heal)
	var s_deep: Ship = Ship.new()
	s_deep.id = gs.alloc_id("ship")
	s_deep.design_id = des.id
	s_deep.owner = 0
	s_deep.hp = 10
	gs.ships[s_deep.id] = s_deep
	var f_deep: Fleet = Fleet.new()
	f_deep.id = gs.alloc_id("fleet")
	f_deep.owner = 0
	f_deep.system_id = -1
	f_deep.dest_system_id = 2
	f_deep.ship_ids = [s_deep.id]
	s_deep.fleet_id = f_deep.id
	gs.fleets[f_deep.id] = f_deep

	# Ship 4: huddle empire at plain colony (100% heal)
	var emp1: Empire = gs.empires[1]
	emp1.traits.append("huddle")
	var plain_col1: Colony = Colonization.apply_colonization(_db, gs, 1, gs.planets[gs.systems[2].planet_ids[0]].id)
	plain_col1.buildings.clear()
	var s_huddle: Ship = Ship.new()
	s_huddle.id = gs.alloc_id("ship")
	s_huddle.design_id = des.id
	s_huddle.owner = 1
	s_huddle.hp = 10
	gs.ships[s_huddle.id] = s_huddle
	var f_huddle: Fleet = Fleet.new()
	f_huddle.id = gs.alloc_id("fleet")
	f_huddle.owner = 1
	f_huddle.system_id = gs.systems[2].id
	f_huddle.ship_ids = [s_huddle.id]
	s_huddle.fleet_id = f_huddle.id
	gs.fleets[f_huddle.id] = f_huddle

	var max_hp: int = int(DesignRules.stats(_db, gs, des).get("hp", 100))
	assert_true(max_hp > 10, "Max HP is greater than 10")

	# Run StepFinalize
	var step_fin: StepFinalize = StepFinalize.new()
	var ctx: TurnContext = TurnContext.new()
	ctx.gs = gs
	ctx.db = _db
	ctx.report = TurnReport.new()
	step_fin.next(ctx)

	var expected_plain: int = 10 + IntMath.floor_div(max_hp * 20, 100)
	assert_eq(s_plain.hp, expected_plain, "Plain colony repairs 20%% of max HP")
	assert_eq(s_yard.hp, max_hp, "Yard/capital colony repairs 100%% of max HP")
	assert_eq(s_deep.hp, 10, "Deep space ship gets 0 repair")
	assert_eq(s_huddle.hp, max_hp, "Huddle empire gets 100%% repair at plain colony")

func test_bombardment_reductions_and_guns_never_kill_pop() -> void:
	var gs: GameState = _create_game("TEST_BOMB")
	var col: Colony = gs.colonies[gs.empires[0].capital_colony_id]
	var p: Planet = gs.planets[col.planet_id]
	var sys: StarSystem = gs.systems[p.system_id]
	col.pop_milli = 10000

	# Design 1: Guns only (Talons), no bomb parts
	var d_guns: ShipDesign = ShipDesign.new()
	d_guns.id = gs.alloc_id("design")
	d_guns.empire_id = 1
	d_guns.hull = "small"
	d_guns.drive = "walk_drive"
	d_guns.weapons = [{"part": "wick_talon", "mount": "", "count": 2}]
	gs.designs[d_guns.id] = d_guns

	var s_guns: Ship = Ship.new()
	s_guns.id = gs.alloc_id("ship")
	s_guns.design_id = d_guns.id
	s_guns.owner = 1
	s_guns.hp = 10
	gs.ships[s_guns.id] = s_guns

	var f_guns: Fleet = Fleet.new()
	f_guns.id = gs.alloc_id("fleet")
	f_guns.owner = 1
	f_guns.system_id = sys.id
	f_guns.ship_ids = [s_guns.id]
	f_guns.order = {"type": "bombard"}
	gs.fleets[f_guns.id] = f_guns

	# Guns never kill pop
	var killed: int = Bombardment.apply_bombardment(gs, _db, f_guns, col)
	assert_eq(killed, 0, "Fleet with only guns kills 0 pop (REFUSE)")
	assert_eq(col.pop_milli, 10000, "Pop unchanged by guns")

	# Design 2: Bomb bay (250 milli)
	var d_bomb: ShipDesign = ShipDesign.new()
	d_bomb.id = gs.alloc_id("design")
	d_bomb.empire_id = 1
	d_bomb.hull = "medium"
	d_bomb.drive = "walk_drive"
	d_bomb.specials = ["bomb_bay"]
	gs.designs[d_bomb.id] = d_bomb

	var s_bomb: Ship = Ship.new()
	s_bomb.id = gs.alloc_id("ship")
	s_bomb.design_id = d_bomb.id
	s_bomb.owner = 1
	s_bomb.hp = 20
	gs.ships[s_bomb.id] = s_bomb
	var f_bomb: Fleet = Fleet.new()
	f_bomb.id = gs.alloc_id("fleet")
	f_bomb.owner = 1
	f_bomb.system_id = sys.id
	f_bomb.ship_ids = [s_bomb.id]
	gs.fleets[f_bomb.id] = f_bomb

	# Base Bomb Bay: 250 milli killed
	col.buildings.clear()
	killed = Bombardment.apply_bombardment(gs, _db, f_bomb, col)
	assert_eq(killed, 250, "Bomb Bay kills 250 milli base")

	# Colony Mantle: halves it (125 milli)
	col.buildings = ["colony_mantle"]
	killed = Bombardment.apply_bombardment(gs, _db, f_bomb, col)
	assert_eq(killed, 125, "Colony Mantle halves bomb damage (125 milli)")

	# Storm Mantle: quarters it (62 milli)
	col.buildings = ["storm_mantle"]
	killed = Bombardment.apply_bombardment(gs, _db, f_bomb, col)
	assert_eq(killed, 62, "Storm Mantle quarters bomb damage (62 milli)")

	# Very polite warhead (2000 milli, ignores shield)
	var d_warhead: ShipDesign = ShipDesign.new()
	d_warhead.id = gs.alloc_id("design")
	d_warhead.empire_id = 1
	d_warhead.hull = "medium"
	d_warhead.drive = "walk_drive"
	d_warhead.specials = ["very_polite_warhead"]
	gs.designs[d_warhead.id] = d_warhead

	var s_warhead: Ship = Ship.new()
	s_warhead.id = gs.alloc_id("ship")
	s_warhead.design_id = d_warhead.id
	s_warhead.owner = 1
	s_warhead.hp = 20
	gs.ships[s_warhead.id] = s_warhead
	var f_warhead: Fleet = Fleet.new()
	f_warhead.id = gs.alloc_id("fleet")
	f_warhead.owner = 1
	f_warhead.system_id = sys.id
	f_warhead.ship_ids = [s_warhead.id]
	gs.fleets[f_warhead.id] = f_warhead

	# Warhead ignores Storm Mantle: still kills 2000
	col.buildings = ["storm_mantle"]
	killed = Bombardment.apply_bombardment(gs, _db, f_warhead, col)
	assert_eq(killed, 2000, "Very polite warhead ignores shield (2000 milli killed)")

func test_razing_and_blockade() -> void:
	var gs: GameState = _create_game("TEST_RAZE")
	var capital_col: Colony = gs.colonies[gs.empires[0].capital_colony_id]
	var p: Planet = gs.planets[capital_col.planet_id]
	var sys: StarSystem = gs.systems[p.system_id]
	Wars.set_war(gs, 0, 1, true)

	# Remove empire 0 fleets from this system so empire 1 can control orbit
	for f in gs.fleets.values():
		if f.system_id == sys.id and f.owner == 0:
			f.system_id = -1

	# Create outpost for empire 0 at planet
	var p_out: Planet = Planet.new()
	p_out.id = gs.planets.size()
	p_out.system_id = sys.id
	p_out.orbit = 8
	p_out.climate = "asteroids"
	p_out.size = "tiny"
	p_out.minerals = "ultra_rich"
	gs.planets.append(p_out)
	var col_out: Colony = Colonization.apply_outpost(_db, gs, 0, p_out.id)
	assert_true(col_out.is_outpost, "Colony is outpost")

	# 1. Unarmed enemy fleet: does NOT raze outpost (REFUSE)
	var d_unarmed: ShipDesign = ShipDesign.new()
	d_unarmed.id = gs.alloc_id("design")
	d_unarmed.empire_id = 1
	d_unarmed.hull = "small"
	d_unarmed.drive = "walk_drive"
	gs.designs[d_unarmed.id] = d_unarmed

	var s_unarmed: Ship = Ship.new()
	s_unarmed.id = gs.alloc_id("ship")
	s_unarmed.design_id = d_unarmed.id
	s_unarmed.owner = 1
	s_unarmed.hp = 10
	gs.ships[s_unarmed.id] = s_unarmed
	var f_unarmed: Fleet = Fleet.new()
	f_unarmed.id = gs.alloc_id("fleet")
	f_unarmed.owner = 1
	f_unarmed.system_id = sys.id
	f_unarmed.ship_ids = [s_unarmed.id]
	gs.fleets[f_unarmed.id] = f_unarmed

	# Run StepOrbital
	var step_orb: StepOrbital = StepOrbital.new()
	var ctx: TurnContext = TurnContext.new()
	ctx.gs = gs
	ctx.db = _db
	ctx.report = TurnReport.new()
	step_orb.begin(ctx)
	while not step_orb.next(ctx):
		pass

	assert_true(gs.colonies.has(col_out.id), "Outpost not razed by unarmed enemy fleet")
	capital_col = gs.colonies[gs.empires[0].capital_colony_id]
	assert_false(capital_col.blockaded, "Colony not blockaded by unarmed enemy fleet")

	# 2. Armed enemy fleet: razes outpost and blockades colony (ALLOW)
	capital_col.defense_hp = 0
	var d_armed: ShipDesign = ShipDesign.new()
	d_armed.id = gs.alloc_id("design")
	d_armed.empire_id = 1
	d_armed.hull = "small"
	d_armed.drive = "walk_drive"
	d_armed.weapons = [{"part": "wick_talon", "mount": "", "count": 2}]
	gs.designs[d_armed.id] = d_armed

	var s_armed: Ship = Ship.new()
	s_armed.id = gs.alloc_id("ship")
	s_armed.design_id = d_armed.id
	s_armed.owner = 1
	s_armed.hp = 10
	gs.ships[s_armed.id] = s_armed
	var f_armed: Fleet = Fleet.new()
	f_armed.id = gs.alloc_id("fleet")
	f_armed.owner = 1
	f_armed.system_id = sys.id
	f_armed.ship_ids = [s_armed.id]
	gs.fleets[f_armed.id] = f_armed

	# Re-run StepOrbital
	step_orb = StepOrbital.new()
	step_orb.begin(ctx)
	while not step_orb.next(ctx):
		pass

	assert_false(gs.colonies.has(col_out.id), "Outpost razed by hostile armed fleet")
	assert_eq(p_out.colony_id, -1, "Planet colony_id reset after raze")
	assert_true(capital_col.blockaded, "Colony is blockaded by hostile armed fleet")

	# Test Modifiers on blockaded colony: industry is halved
	capital_col.buildings.clear()
	var res_normal: ModResult = Modifiers.eval(_db, gs, "industry", 100, {"colony_id": capital_col.id, "empire_id": 0})
	assert_eq(res_normal.value, 50, "Blockade halves industry (-50%)")

	# Lift blockade when hostile fleet moves away
	f_armed.system_id = -1
	step_orb = StepOrbital.new()
	step_orb.begin(ctx)
	while not step_orb.next(ctx):
		pass
	assert_false(capital_col.blockaded, "Blockade lifts when hostile fleet leaves")

func test_invasion_defenses_and_capture() -> void:
	var gs: GameState = _create_game("TEST_INVADE")
	var col: Colony = gs.colonies[gs.empires[0].capital_colony_id]
	var sys: StarSystem = gs.system_of_planet(col.planet_id)
	Wars.set_war(gs, 0, 1, true)
	col.defense_hp = 100

	# Design: Boot Ship
	var d_boot: ShipDesign = ShipDesign.new()
	d_boot.id = gs.alloc_id("design")
	d_boot.empire_id = 1
	d_boot.hull = "medium"
	d_boot.drive = "walk_drive"
	d_boot.specials = ["boot_pod"]
	gs.designs[d_boot.id] = d_boot

	var s_boot: Ship = Ship.new()
	s_boot.id = gs.alloc_id("ship")
	s_boot.design_id = d_boot.id
	s_boot.owner = 1
	s_boot.hp = 20
	gs.ships[s_boot.id] = s_boot

	var f_inv: Fleet = Fleet.new()
	f_inv.id = gs.alloc_id("fleet")
	f_inv.owner = 1
	f_inv.system_id = sys.id
	f_inv.ship_ids = [s_boot.id]
	gs.fleets[f_inv.id] = f_inv

	# 1. Refused while defenses active
	var err: String = GroundCombat.can_invade(gs, _db, f_inv.id, col.id)
	assert_eq(err, "refuse.defenses_active", "Invasion refused while defenses have HP (REFUSE)")

	# 2. Allowed once defenses suppressed (defense_hp == 0)
	col.defense_hp = 0
	err = GroundCombat.can_invade(gs, _db, f_inv.id, col.id)
	assert_eq(err, "", "Invasion allowed once defenses suppressed (ALLOW)")

	# 3. Add more boot ships to guarantee victory
	for i in range(10):
		var s: Ship = Ship.new()
		s.id = gs.alloc_id("ship")
		s.design_id = d_boot.id
		s.owner = 1
		s.hp = 20
		gs.ships[s.id] = s
		f_inv.ship_ids.append(s.id)

	var orig_pop: int = col.pop_milli
	var orig_species: String = col.species
	var orig_bld_count: int = col.buildings.size()

	var won: bool = GroundCombat.resolve_invasion(gs, _db, f_inv, col)
	assert_true(won, "Invasion won by attacker")
	assert_eq(col.owner, 1, "Colony owner changed to attacker")
	assert_eq(col.pop_milli, orig_pop, "Captured colony keeps pop")
	assert_eq(col.species, orig_species, "Captured colony keeps species")
	assert_eq(col.buildings.size(), orig_bld_count, "Captured colony keeps buildings")
	assert_eq(col.queue.size(), 0, "Queue cleared on capture")
	assert_eq(col.occupied_until, gs.turn + 10, "Colony occupied for 10 turns")
	assert_false(gs.ships.has(s_boot.id), "Boot Ship consumed on invasion")
