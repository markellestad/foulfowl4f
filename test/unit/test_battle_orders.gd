extends GutTest

var _db: ContentDB

func before_all() -> void:
	_db = ContentDB.load_from("res://data")

func _create_game(seed_str: String = "BATTLE_ORDERS_TEST") -> GameState:
	var s: GameSettings = GameSettings.new()
	s.preset = "tiny"
	s.seed_string = seed_str
	s.seed = Rng.seed_from_string(seed_str)
	s.player_race = "pheasants"
	s.seat_swans = true
	var gs: GameState = GalaxyGenerator.generate(s, _db)
	StartState.apply(gs, _db)
	return gs

func _find_sparrow_design(gs: GameState, emp_id: int) -> ShipDesign:
	for des in gs.designs.values():
		if des.empire_id == emp_id and des.name.to_lower().contains("sparrow"):
			return des
	for des in gs.designs.values():
		if des.empire_id == emp_id and des.hull == "small":
			return des
	return null

func _spawn_sparrows(gs: GameState, emp_id: int, sys_id: int, count: int) -> Fleet:
	var des: ShipDesign = _find_sparrow_design(gs, emp_id)
	var st: Dictionary = DesignRules.stats(_db, gs, des)
	var f: Fleet = Fleet.new()
	f.id = gs.alloc_id("fleet")
	f.owner = emp_id
	f.system_id = sys_id
	gs.fleets[f.id] = f

	for _i in range(count):
		var s: Ship = Ship.new()
		s.id = gs.alloc_id("ship")
		s.design_id = des.id
		s.owner = emp_id
		s.fleet_id = f.id
		s.hp = int(st.get("hp", 10))
		gs.ships[s.id] = s
		f.ship_ids.append(s.id)

	return f

func _clear_fleets(gs: GameState) -> void:
	gs.fleets.clear()
	gs.ships.clear()

func test_boundary_pair_big_mode() -> void:
	# 2 vs 2 Sparrows -> 4 total PP. Under "big" (threshold 6), raises NO request.
	var gs_a: GameState = _create_game("TEST_BOUNDARY_A")
	_clear_fleets(gs_a)
	Wars.set_war(gs_a, 0, 1, true)
	_spawn_sparrows(gs_a, 0, 1, 2)
	_spawn_sparrows(gs_a, 1, 1, 2)

	var tp_a: TurnProcessor = TurnProcessor.new(gs_a, _db)
	tp_a.orders_mode = "big"
	tp_a.ctx.orders_mode = "big"

	while tp_a.step_index <= TurnProcessor.STEP_ORDER.find(&"combat") and tp_a.status == TurnProcessor.Status.RUNNING:
		tp_a.run_next_substep()

	assert_eq(tp_a.requests.size(), 0, "2-vs-2 should raise no request")
	assert_ne(tp_a.status, TurnProcessor.Status.NEEDS_INPUT, "2-vs-2 status should not be NEEDS_INPUT")

	# 3 vs 3 Sparrows -> 6 total PP. Under "big" (threshold 6), RAISES a request.
	var gs_b: GameState = _create_game("TEST_BOUNDARY_B")
	_clear_fleets(gs_b)
	Wars.set_war(gs_b, 0, 1, true)
	_spawn_sparrows(gs_b, 0, 1, 3)
	_spawn_sparrows(gs_b, 1, 1, 3)

	var tp_b: TurnProcessor = TurnProcessor.new(gs_b, _db)
	tp_b.orders_mode = "big"
	tp_b.ctx.orders_mode = "big"

	while tp_b.step_index <= TurnProcessor.STEP_ORDER.find(&"combat") and tp_b.status == TurnProcessor.Status.RUNNING:
		tp_b.run_next_substep()

	assert_eq(tp_b.status, TurnProcessor.Status.NEEDS_INPUT, "3-vs-3 status should be NEEDS_INPUT")
	assert_eq(tp_b.requests.size(), 1, "3-vs-3 should raise 1 request")
	assert_eq(tp_b.requests[0]["system_id"], 1)

func test_four_qualifying_battles_and_ranking() -> void:
	# Four qualifying battles -> 3 cards + 1 auto, ranked by armed PP
	var gs: GameState = _create_game("TEST_4_BATTLES")
	_clear_fleets(gs)
	Wars.set_war(gs, 0, 1, true)

	# System 1: 3 vs 3 (6 Sparrows)
	_spawn_sparrows(gs, 0, 1, 3)
	_spawn_sparrows(gs, 1, 1, 3)

	# System 2: 4 vs 4 (8 Sparrows)
	_spawn_sparrows(gs, 0, 2, 4)
	_spawn_sparrows(gs, 1, 2, 4)

	# System 3: 5 vs 5 (10 Sparrows)
	_spawn_sparrows(gs, 0, 3, 5)
	_spawn_sparrows(gs, 1, 3, 5)

	# System 4: 6 vs 6 (12 Sparrows)
	_spawn_sparrows(gs, 0, 4, 6)
	_spawn_sparrows(gs, 1, 4, 6)

	var tp: TurnProcessor = TurnProcessor.new(gs, _db)
	tp.orders_mode = "big"
	tp.ctx.orders_mode = "big"

	while tp.step_index <= TurnProcessor.STEP_ORDER.find(&"combat") and tp.status == TurnProcessor.Status.RUNNING:
		tp.run_next_substep()

	assert_eq(tp.status, TurnProcessor.Status.NEEDS_INPUT, "Should pause on NEEDS_INPUT")
	assert_eq(tp.requests.size(), 3, "Exactly 3 requests for cards")
	assert_eq(tp.auto_systems.size(), 1, "Exactly 1 auto system")

	# Ranked by total armed PP descending: system 4 (12), system 3 (10), system 2 (8), auto: system 1 (6)
	assert_eq(tp.requests[0]["system_id"], 4, "1st request should be system 4 (highest PP)")
	assert_eq(tp.requests[1]["system_id"], 3, "2nd request should be system 3")
	assert_eq(tp.requests[2]["system_id"], 2, "3rd request should be system 2")
	assert_eq(tp.auto_systems[0], 1, "Auto system should be system 1 (lowest PP)")

	# The AI's orders are fixed before the request is built and are not present in the request dictionary
	for req in tp.requests:
		assert_false(req.has("ai_orders"), "Request must NOT contain AI orders")
		assert_true(req.has("system_id"), "Request must have system_id")
		assert_true(req.has("enemy_visible"), "Request must have enemy_visible")
		assert_true(req.has("odds_pct"), "Request must have odds_pct")
		assert_true(req.has("plan"), "Request must have plan")
		assert_true(req.has("projection"), "Request must have projection")

func test_answer_in_cmd_log_and_replay_hash() -> void:
	var s: GameSettings = GameSettings.new()
	s.preset = "tiny"
	s.seed_string = "REPLAY_TEST"
	s.seed = Rng.seed_from_string("REPLAY_TEST")
	s.player_race = "pheasants"
	s.seat_swans = true

	var game1: SimGame = SimGame.create(s, _db)
	_clear_fleets(game1.gs)
	Wars.set_war(game1.gs, 0, 1, true)
	_spawn_sparrows(game1.gs, 0, 1, 3)
	_spawn_sparrows(game1.gs, 1, 1, 3)

	var initial_state: Dictionary = game1.gs.to_dict()

	var tp1: TurnProcessor = game1.begin_end_turn()
	tp1.orders_mode = "big"
	tp1.ctx.orders_mode = "big"

	while tp1.step_index <= TurnProcessor.STEP_ORDER.find(&"combat") and tp1.status == TurnProcessor.Status.RUNNING:
		tp1.run_next_substep()

	assert_eq(tp1.status, TurnProcessor.Status.NEEDS_INPUT)

	var cmd: CmdBattleOrders = CmdBattleOrders.new()
	cmd.system_id = 1
	cmd.posture = "close"
	cmd.target_priority = "biggest"
	cmd.swat_mode = "missiles_first"
	cmd.retreat_threshold = "never"

	var ans_err: String = game1.answer_battle_orders([cmd])
	assert_eq(ans_err, "", "Answer battle orders should succeed")

	# Check cmd_log has source "battle"
	var found_battle_cmd: bool = false
	for entry in game1.gs.cmd_log:
		if entry.get("source") == "battle":
			found_battle_cmd = true
			var c_dict: Dictionary = entry.get("cmd", {})
			assert_eq(c_dict.get("kind"), "battle_orders")
			assert_eq(c_dict.get("system_id"), 1)
			assert_eq(c_dict.get("posture"), "close")
	assert_true(found_battle_cmd, "The answer must be in cmd_log with source 'battle'")

	# Finish turn 1
	while tp1.status != TurnProcessor.Status.DONE:
		tp1.run_next_substep()
	game1.finish_end_turn()

	var hash1: int = game1.state_hash()
	var saved_log: Array = game1.gs.cmd_log.duplicate(true)

	# Replay on fresh game
	var gs2: GameState = GameState.from_dict(initial_state)
	var game2: SimGame = SimGame.from_state(gs2, _db)
	var tp2: TurnProcessor = game2.begin_end_turn()
	tp2.orders_mode = "big"
	tp2.ctx.orders_mode = "big"

	while tp2.step_index <= TurnProcessor.STEP_ORDER.find(&"combat") and tp2.status == TurnProcessor.Status.RUNNING:
		tp2.run_next_substep()

	assert_eq(tp2.status, TurnProcessor.Status.NEEDS_INPUT)

	var replay_cmds: Array[Cmd] = []
	for entry in saved_log:
		if entry.get("source") == "battle":
			var r_cmd: Cmd = CmdRegistry.from_dict(entry.get("cmd", {}))
			replay_cmds.append(r_cmd)

	var r_err: String = game2.answer_battle_orders(replay_cmds)
	assert_eq(r_err, "")

	while tp2.status != TurnProcessor.Status.DONE:
		tp2.run_next_substep()
	game2.finish_end_turn()

	var hash2: int = game2.state_hash()
	assert_eq(hash1, hash2, "Replaying the log on a fresh game gives the same state hash")

func test_run_all_never_returns_needs_input() -> void:
	var gs: GameState = _create_game("TEST_RUN_ALL")
	_clear_fleets(gs)
	Wars.set_war(gs, 0, 1, true)
	_spawn_sparrows(gs, 0, 1, 4)
	_spawn_sparrows(gs, 1, 1, 4)

	var tp: TurnProcessor = TurnProcessor.new(gs, _db)
	tp.orders_mode = "big" # Even if orders_mode is initially big
	tp.run_all()

	assert_eq(tp.status, TurnProcessor.Status.DONE, "run_all must finish with Status.DONE")
	assert_ne(tp.status, TurnProcessor.Status.NEEDS_INPUT, "run_all must never return NEEDS_INPUT")

func test_undo_cannot_remove_battle_orders() -> void:
	var s: GameSettings = GameSettings.new()
	s.preset = "tiny"
	s.seed_string = "UNDO_TEST"
	s.seed = Rng.seed_from_string("UNDO_TEST")
	s.player_race = "pheasants"
	s.seat_swans = true

	var game: SimGame = SimGame.create(s, _db)
	_clear_fleets(game.gs)
	Wars.set_war(game.gs, 0, 1, true)
	_spawn_sparrows(game.gs, 0, 1, 3)
	_spawn_sparrows(game.gs, 1, 1, 3)

	var tp: TurnProcessor = game.begin_end_turn()
	tp.orders_mode = "big"
	tp.ctx.orders_mode = "big"

	while tp.step_index <= TurnProcessor.STEP_ORDER.find(&"combat") and tp.status == TurnProcessor.Status.RUNNING:
		tp.run_next_substep()

	assert_eq(tp.status, TurnProcessor.Status.NEEDS_INPUT)

	var cmd: CmdBattleOrders = CmdBattleOrders.new()
	cmd.system_id = 1
	cmd.posture = "close"
	game.answer_battle_orders([cmd])

	while tp.status != TurnProcessor.Status.DONE:
		tp.run_next_substep()
	game.finish_end_turn()

	# Start of turn 2: can_undo should be false
	assert_false(game.can_undo(), "Cannot undo at the start of a turn after battles")

	# If a player submits a command in turn 2 and undoes it:
	var emp: Empire = game.gs.empires[0]
	if emp.capital_colony_id >= 0 and game.gs.colonies.has(emp.capital_colony_id):
		var cmd_preset: CmdSetPreset = CmdSetPreset.new()
		cmd_preset.empire_id = 0
		cmd_preset.colony_id = emp.capital_colony_id
		cmd_preset.preset = "industry"
		var sub_err: String = game.submit(cmd_preset)
		assert_eq(sub_err, "")
		assert_true(game.can_undo())
		game.undo()

	# Verify battle_orders is still in cmd_log
	var has_battle_orders: bool = false
	for entry in game.gs.cmd_log:
		if entry.get("source") == "battle":
			has_battle_orders = true
	assert_true(has_battle_orders, "Undo after a battle turn cannot remove a battle_orders command")
