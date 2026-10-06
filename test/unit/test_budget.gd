extends GutTest

var _db: ContentDB

func before_all() -> void:
	_db = ContentDB.load_from("res://data")

func _create_game(seed_str: String = "BUDGET_TEST") -> GameState:
	var s: GameSettings = (GameSettings as Variant).call(&"new")
	s.preset = "evening_standard"
	s.seed_string = seed_str
	s.seed = Rng.seed_from_string(seed_str)
	s.player_race = "pheasants"
	s.seat_swans = true
	var game: SimGame = SimGame.create(s, _db)
	return game.gs

func test_guarded_stops_at_target() -> void:
	var gs: GameState = _create_game("BUDGET_TEST1")
	var emp: Empire = gs.empires[0]
	emp.military_budget = "guarded" # 20%

	# Find or create 2 yard colonies for empire 0
	var yard_cols: Array[Colony] = []
	for cid in Ids.sorted_keys(gs.colonies):
		var c: Colony = gs.colonies[cid]
		if c.owner == 0 and not c.is_outpost:
			c.queue.clear()
			if not c.buildings.has("the_yard"):
				c.buildings.append("the_yard")
			yard_cols.append(c)

	assert_true(yard_cols.size() >= 1, "Has at least 1 colony")

	# Add a second colony if only 1 exists
	if yard_cols.size() == 1:
		var p: Planet = Planet.new()
		p.id = gs.planets.size()
		p.system_id = 0
		p.orbit = 1
		p.size = "medium"
		p.climate = "terran"
		p.minerals = "normal"
		gs.planets.append(p)

		var c2: Colony = Colony.new()
		c2.id = gs.alloc_id("colony")
		c2.planet_id = p.id
		c2.owner = 0
		c2.farmers = 1
		c2.workers = 3
		c2.scientists = 0
		c2.preset = "capital"
		c2.buildings = ["the_yard"]
		gs.colonies[c2.id] = c2
		yard_cols.append(c2)

	# Ensure both colonies have positive industry
	for c in yard_cols:
		c.workers = 4
		c.queue.clear()

	var total_ind: int = 0
	for c in yard_cols:
		total_ind += (Economy.colony_output(_db, gs, c.id)["industry"] as ModResult).value
	assert_true(total_ind > 0, "Total industry > 0")

	# Run Governor.fill_queues
	Governor.fill_queues(_db, gs, 0)

	# Target is 20% of total industry.
	# A single yard colony should cover 20% (since each has ~50% of industry).
	var warship_heads: int = 0
	var queued_items: Array[QueueItem] = []
	for c in yard_cols:
		if not c.queue.is_empty() and c.queue[0].kind == "ship":
			warship_heads += 1
			queued_items.append(c.queue[0])

	assert_eq(warship_heads, 1, "Guarded 20% adds warship at first colony and stops at target")

	# Verify running again does not add another warship (stops at target)
	Governor.fill_queues(_db, gs, 0)
	var warship_heads_after: int = 0
	for c in yard_cols:
		if not c.queue.is_empty() and c.queue[0].kind == "ship":
			warship_heads_after += 1
	assert_eq(warship_heads_after, 1, "Refuses further additions once target reached")

func test_upkeep_above_30_pct_stops_additions() -> void:
	var gs: GameState = _create_game("BUDGET_TEST2")
	var emp: Empire = gs.empires[0]
	emp.military_budget = "guarded"

	# Clear queues
	for cid in Ids.sorted_keys(gs.colonies):
		var c: Colony = gs.colonies[cid]
		if c.owner == 0:
			c.queue.clear()
			if not c.buildings.has("the_yard"):
				c.buildings.append("the_yard")

	# Spawn many armed ships so ship_upkeep is huge (> 30% of income)
	# Create a high upkeep design
	var des: ShipDesign = ShipDesign.new()
	des.id = gs.alloc_id("design")
	des.empire_id = 0
	des.hull = "large"
	des.drive = "migration_drive"
	des.plate = "unsinkable_plate"
	des.weapons = [{"part": "wick_talon", "mount": "", "count": 2}]
	gs.designs[des.id] = des

	# Create ships with this design
	for i in range(20):
		var s: Ship = Ship.new()
		s.id = gs.alloc_id("ship")
		s.owner = 0
		s.design_id = des.id
		gs.ships[s.id] = s

	# Check income vs upkeep
	var fin: Dictionary = Economy.empire_totals(_db, gs, 0)
	var upkeep: int = int(fin["ship_upkeep"])
	var income: int = int(fin["income"])
	var max_upkeep: int = IntMath.pct(income, _db.bal("budget_upkeep_stop_pct"))
	assert_true(upkeep > max_upkeep, "Upkeep exceeds 30% of income")

	# Run Governor.fill_queues
	Governor.fill_queues(_db, gs, 0)

	# Verify NO warships were queued
	for cid in Ids.sorted_keys(gs.colonies):
		var c: Colony = gs.colonies[cid]
		if c.owner == 0:
			for qi in c.queue:
				assert_ne(qi.kind, "ship", "No warship added when upkeep > 30% of income")

func test_why_args_carry_policy_target_current() -> void:
	var gs: GameState = _create_game("BUDGET_TEST3")
	var emp: Empire = gs.empires[0]
	emp.military_budget = "guarded"

	for cid in Ids.sorted_keys(gs.colonies):
		var c: Colony = gs.colonies[cid]
		if c.owner == 0:
			c.queue.clear()
			if not c.buildings.has("the_yard"):
				c.buildings.append("the_yard")

	Governor.fill_queues(_db, gs, 0)

	var found_budget_item: bool = false
	for cid in Ids.sorted_keys(gs.colonies):
		var c: Colony = gs.colonies[cid]
		if c.owner == 0:
			for qi in c.queue:
				if qi.kind == "ship" and qi.why_key == "summary.why_queued.budget":
					found_budget_item = true
					assert_eq(qi.added_by, "governor", "added_by is governor")
					assert_true(qi.why_args.has("policy"), "why_args has policy")
					assert_true(qi.why_args.has("target"), "why_args has target")
					assert_true(qi.why_args.has("current"), "why_args has current")
					assert_eq(qi.why_args["policy"], "guarded", "policy is guarded")
					assert_eq(qi.why_args["target"], 20, "target is 20")
					break

	assert_true(found_budget_item, "Found queued warship with why_args")

func test_presets_never_add_warships() -> void:
	var gs: GameState = _create_game("BUDGET_TEST4")
	var emp: Empire = gs.empires[0]
	# When budget is peace and target is met (or industry 0), governor only runs preset logic
	emp.military_budget = "peace"

	# Set all colonies to non-yard or industry 0 so budget adds 0
	for cid in Ids.sorted_keys(gs.colonies):
		var c: Colony = gs.colonies[cid]
		if c.owner == 0:
			c.queue.clear()
			# Keep preset auto: true
			c.preset = "capital"

	# Run Governor.fill_queues with budget peace and target already met
	# To test preset rules specifically:
	for p_id in _db.ids("presets"):
		var pdef: Dictionary = _db.def("presets", p_id)
		var b_list: Array = pdef.get("build", [])
		for b in b_list:
			var bdef: Dictionary = _db.def("buildings", str(b))
			assert_ne(bdef.get("category", ""), "ship", "Preset build items are buildings, never ships")
		assert_ne(str(pdef.get("filler", "")), "ship", "Preset filler is never a ship")

func test_cmd_set_military_budget() -> void:
	var gs: GameState = _create_game("BUDGET_TEST5")
	var emp: Empire = gs.empires[0]
	assert_eq(emp.military_budget, "guarded", "Default is guarded")

	var cmd: CmdSetMilitaryBudget = CmdSetMilitaryBudget.new()
	cmd.empire_id = 0
	cmd.policy = "war"

	var err: String = cmd.validate(gs, _db)
	assert_eq(err, "", "Validation succeeds for war")
	cmd.apply(gs, _db)
	assert_eq(emp.military_budget, "war", "Policy changed to war")

	# Test invalid policy
	var invalid_cmd: CmdSetMilitaryBudget = CmdSetMilitaryBudget.new()
	invalid_cmd.empire_id = 0
	invalid_cmd.policy = "blitzkrieg"
	assert_eq(invalid_cmd.validate(gs, _db), "refuse.invalid_policy", "Invalid policy refused")

	# Serialization test
	var d: Dictionary = cmd.to_dict()
	var restored: Cmd = CmdRegistry.from_dict(d)
	assert_not_null(restored, "Restored command from dict")
	assert_eq(restored.kind(), &"set_military_budget", "Restored kind matches")
	assert_eq((restored as CmdSetMilitaryBudget).policy, "war", "Restored policy matches")

func test_military_budget_next_role() -> void:
	var gs: GameState = _create_game("BUDGET_TEST6")
	var view: AiView = AiView.build(gs, _db, 0)

	# 1. Baseline: no enemy designs known -> returns talon_line
	var role_base: String = MilitaryBudget.next_role(view)
	assert_eq(role_base, "talon_line", "Baseline role is talon_line")

	# 2. Enemy shield >= 4 seen and Beak tech known -> returns beak_line
	# Grant beak tech to empire 0
	gs.empires[0].tech.grant("peck_driver")
	# Register an enemy design with half_mantle (shield: 4)
	var enemy_des: ShipDesign = ShipDesign.new()
	enemy_des.id = gs.alloc_id("design")
	enemy_des.empire_id = 1
	enemy_des.hull = "medium"
	enemy_des.mantle = "half_mantle"
	enemy_des.weapons = [{"part": "wick_talon", "mount": "", "count": 1}]
	gs.designs[enemy_des.id] = enemy_des

	if not gs.knowledge.has(0):
		gs.knowledge[0] = Knowledge.new()
	gs.knowledge[0].known_designs[enemy_des.id] = enemy_des.to_dict()

	var role_shield: String = MilitaryBudget.next_role(view)
	assert_eq(role_shield, "beak_line", "Beak line chosen when enemy shield >= 4 and Beak tech known")

	# 3. Enemy Horizon seen and own Swat share < 25% -> returns swat_escort
	# Grant swat_mount tech (second_sun) to empire 0
	gs.empires[0].tech.grant("second_sun")
	var enemy_hz: ShipDesign = ShipDesign.new()
	enemy_hz.id = gs.alloc_id("design")
	enemy_hz.empire_id = 1
	enemy_hz.hull = "medium"
	enemy_hz.weapons = [{"part": "indoor_torpedo", "mount": "", "count": 1}]
	gs.designs[enemy_hz.id] = enemy_hz
	gs.knowledge[0].known_designs[enemy_hz.id] = enemy_hz.to_dict()

	var role_swat: String = MilitaryBudget.next_role(view)
	assert_eq(role_swat, "swat_escort", "Swat escort chosen when enemy Horizon seen and Swat share < 25%")
