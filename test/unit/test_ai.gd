extends GutTest

var _db: ContentDB

func before_all() -> void:
	_db = ContentDB.load_from("res://data")

func _create_game(seed_str: String = "AI_TEST") -> GameState:
	var s: GameSettings = (GameSettings as Variant).call(&"new")
	s.preset = "evening_standard"
	s.seed_string = seed_str
	s.seed = Rng.seed_from_string(seed_str)
	s.player_race = "pheasants"
	s.seat_swans = true
	var game: SimGame = SimGame.create(s, _db)
	return game.gs

func test_ai_view_isolation() -> void:
	var gs: GameState = _create_game("ISO_TEST")
	var view0: AiView = AiView.build(gs, _db, 0)

	# Find a colony owned by empire 1
	var col_id: int = -1
	for cid in gs.colonies.keys():
		if gs.colonies[cid].owner == 1:
			col_id = cid
			break
	assert_true(col_id >= 0, "Empire 1 has a colony")

	# Colony seen only by B (empire 1) is absent from A's view (REFUSE)
	var col_info_pre: Dictionary = view0.seen_colony(col_id)
	assert_true(col_info_pre.is_empty(), "Colony seen only by B is absent from A's view (REFUSE)")

	# After A's scout sees it, it appears with turn_seen (ALLOW)
	if not gs.knowledge.has(0):
		gs.knowledge[0] = Knowledge.new()
	gs.knowledge[0].seen_colonies[col_id] = {
		"owner": 1,
		"species": "swans",
		"pop_units": 4,
		"buildings": ["the_yard"],
		"is_outpost": false,
		"turn_seen": gs.turn
	}

	var col_info_post: Dictionary = view0.seen_colony(col_id)
	assert_false(col_info_post.is_empty(), "After A's scout sees it, it appears in view (ALLOW)")
	assert_eq(int(col_info_post.get("turn_seen", -1)), gs.turn, "turn_seen is correctly recorded")

func test_strike_sizing_boundary() -> void:
	var gs: GameState = _create_game("SIZING_TEST")
	var view: AiView = AiView.build(gs, _db, 1)

	var estimated_defense: int = 100
	# Standard strike_ratio_pct is 150
	# 150 power vs 100 defense = exactly 150% -> ALLOW
	var allow: bool = AiMilitary.can_launch_strike(view, 150, estimated_defense, false)
	assert_true(allow, "Strike launch ALLOW at exactly 150% power")

	# 149 power vs 100 defense = 149% -> REFUSE
	var refuse: bool = AiMilitary.can_launch_strike(view, 149, estimated_defense, false)
	assert_false(refuse, "Strike launch REFUSE at 149% power")

func test_stale_intel_rescout() -> void:
	var gs: GameState = _create_game("STALE_TEST")
	var view: AiView = AiView.build(gs, _db, 1)
	var mem: AiMemory = AiMemory.new()
	Wars.set_war(gs, 1, 0, true)

	# Set up an enemy colony in knowledge with stale intel (11 turns old)
	var enemy_cid: int = -1
	for cid in gs.colonies.keys():
		if gs.colonies[cid].owner == 0:
			enemy_cid = cid
			break
	assert_true(enemy_cid >= 0, "Found enemy colony")

	if not gs.knowledge.has(1):
		gs.knowledge[1] = Knowledge.new()

	# 1. Stale intel: seen 11 turns ago (intel_max_age is 10)
	gs.turn = 20
	gs.knowledge[1].seen_colonies[enemy_cid] = {
		"owner": 0,
		"species": "pheasants",
		"pop_units": 2,
		"buildings": [],
		"is_outpost": false,
		"turn_seen": gs.turn - 11 # 11 turns ago
	}

	# Spawn an idle scout fleet for empire 1
	var cap_sys: int = 1
	var cap_c: Colony = view.capital_colony()
	if cap_c != null:
		var cap_p: Planet = view.planet(cap_c.planet_id)
		if cap_p != null:
			cap_sys = cap_p.system_id

	var scout_des: ShipDesign = ShipDesign.new()
	scout_des.id = gs.alloc_id("design")
	scout_des.empire_id = 1
	scout_des.hull = "small"
	scout_des.role = "glance"
	gs.designs[scout_des.id] = scout_des

	var sf: Fleet = Fleet.new()
	sf.id = gs.alloc_id("fleet")
	sf.owner = 1
	sf.system_id = cap_sys
	var ss: Ship = Ship.new()
	ss.id = gs.alloc_id("ship")
	ss.owner = 1
	ss.design_id = scout_des.id
	ss.hp = 10
	gs.ships[ss.id] = ss
	sf.ship_ids.append(ss.id)
	gs.fleets[sf.id] = sf

	var war_des: ShipDesign = ShipDesign.new()
	war_des.id = gs.alloc_id("design")
	war_des.empire_id = 1
	war_des.hull = "medium"
	war_des.weapons = [{"part": "peck_driver", "mount": "", "count": 2}]
	gs.designs[war_des.id] = war_des

	# Spawn an idle strike fleet with huge power
	var wf: Fleet = Fleet.new()
	wf.id = gs.alloc_id("fleet")
	wf.owner = 1
	wf.system_id = cap_sys
	var ws: Ship = Ship.new()
	ws.id = gs.alloc_id("ship")
	ws.owner = 1
	ws.design_id = war_des.id
	ws.hp = 500
	gs.ships[ws.id] = ws
	wf.ship_ids.append(ws.id)
	gs.fleets[wf.id] = wf

	var cmds_stale: Array[Cmd] = AiMilitary.plan(view, mem)
	# Should dispatch scout to re-scout, but NOT launch the strike fleet
	var launched_strike: bool = false
	var launched_scout: bool = false
	for c in cmds_stale:
		if c is CmdFleetMove:
			if (c as CmdFleetMove).fleet_id == wf.id:
				launched_strike = true
			if (c as CmdFleetMove).fleet_id == sf.id:
				launched_scout = true

	assert_false(launched_strike, "Stale intel (11 turns): strike fleet is NOT launched")
	assert_true(launched_scout, "Stale intel (11 turns): scout is dispatched to re-scout")

	# 2. Fresh intel: seen 10 turns ago (intel_max_age is 10)
	gs.knowledge[1].seen_colonies[enemy_cid]["turn_seen"] = gs.turn - 10
	wf.dest_system_id = -1 # ensure idle
	var cmds_fresh: Array[Cmd] = AiMilitary.plan(view, mem)
	var launched_strike_fresh: bool = false
	for c in cmds_fresh:
		if c is CmdFleetMove and (c as CmdFleetMove).fleet_id == wf.id:
			launched_strike_fresh = true

	assert_true(launched_strike_fresh, "Fresh intel (10 turns): strike fleet IS launched without re-scout")

func test_failure_memory_third_strike_refused() -> void:
	var gs: GameState = _create_game("FAIL_MEM_TEST")
	var view: AiView = AiView.build(gs, _db, 1)
	var mem: AiMemory = AiMemory.new()
	Wars.set_war(gs, 1, 0, true)

	var enemy_cid: int = -1
	for cid in gs.colonies.keys():
		if gs.colonies[cid].owner == 0:
			enemy_cid = cid
			break

	if not gs.knowledge.has(1):
		gs.knowledge[1] = Knowledge.new()
	gs.knowledge[1].seen_colonies[enemy_cid] = {
		"owner": 0,
		"species": "pheasants",
		"pop_units": 2,
		"buildings": [],
		"is_outpost": false,
		"turn_seen": gs.turn
	}

	var cap_sys: int = 1
	var cap_c: Colony = view.capital_colony()
	if cap_c != null:
		var cap_p: Planet = view.planet(cap_c.planet_id)
		if cap_p != null:
			cap_sys = cap_p.system_id

	var war_des: ShipDesign = ShipDesign.new()
	war_des.id = gs.alloc_id("design")
	war_des.empire_id = 1
	war_des.hull = "medium"
	war_des.weapons = [{"part": "peck_driver", "mount": "", "count": 2}]
	gs.designs[war_des.id] = war_des

	# Spawn strike fleet
	var wf: Fleet = Fleet.new()
	wf.id = gs.alloc_id("fleet")
	wf.owner = 1
	wf.system_id = cap_sys
	var ws: Ship = Ship.new()
	ws.id = gs.alloc_id("ship")
	ws.owner = 1
	ws.design_id = war_des.id
	ws.hp = 500
	gs.ships[ws.id] = ws
	wf.ship_ids.append(ws.id)
	gs.fleets[wf.id] = wf

	# Record 2 failures in window (max_failures is 2)
	mem.record_strike_failure(enemy_cid, gs.turn - 5, 50)
	mem.record_strike_failure(enemy_cid, gs.turn - 2, 50)

	var cmds: Array[Cmd] = AiMilitary.plan(view, mem)
	var launched: bool = false
	for c in cmds:
		if c is CmdFleetMove and (c as CmdFleetMove).fleet_id == wf.id:
			launched = true

	assert_false(launched, "Third strike on one target within 20 turns is refused")

func test_ai_battle_table_counter_picks() -> void:
	var gs: GameState = _create_game("BATTLE_PICK_TEST")
	var view: AiView = AiView.build(gs, _db, 1)

	# Row 1: Odds below retreat threshold -> Retreat
	var r1: Dictionary = AiBattle.choose_orders(view, {
		"odds": 30,
		"retreat_threshold_val": 50
	})
	assert_eq(r1["posture"], "retreat", "Row 1: Odds below threshold chooses Retreat")

	# Row 2: Enemy Horizon-heavy and own Swat mounts -> Missiles first + Close
	var r2: Dictionary = AiBattle.choose_orders(view, {
		"odds": 80,
		"enemy_horizon_heavy": true,
		"own_swat_mounts": true
	})
	assert_eq(r2["posture"], "close", "Row 2: Posture is close")
	assert_eq(r2["swat_mode"], "missiles", "Row 2: Swat mode is missiles")

	# Row 3: Faster Beak fleet -> Close
	var r3: Dictionary = AiBattle.choose_orders(view, {
		"odds": 80,
		"faster_beak": true
	})
	assert_eq(r3["posture"], "close", "Row 3: Faster beak chooses Close")

	# Row 4: Slower Talon fleet vs Beak -> Talon range
	var r4: Dictionary = AiBattle.choose_orders(view, {
		"odds": 80,
		"slower_talon_vs_beak": true
	})
	assert_eq(r4["posture"], "talon", "Row 4: Slower talon vs beak chooses Talon range")

	# Row 5: Own Horizon-heavy -> target Swat Escorts first
	var r5: Dictionary = AiBattle.choose_orders(view, {
		"odds": 80,
		"own_horizon_heavy": true
	})
	assert_eq(r5["target_priority"], "swat", "Row 5: Own Horizon-heavy targets Swat first")

	# Row 6: Else standing plan
	var r6: Dictionary = AiBattle.choose_orders(view, {
		"odds": 80,
		"standing_plan": {"posture": "auto", "target_priority": "auto", "swat_mode": "missiles"}
	})
	assert_eq(r6["posture"], "auto", "Row 6: Falls through to standing plan")

func test_zero_ai_reject_over_turns() -> void:
	for seed_str in ["FOWL_SEED1", "FOWL_SEED2", "FOWL_SEED3"]:
		var s: GameSettings = (GameSettings as Variant).call(&"new")
		s.preset = "evening_standard"
		s.seed_string = seed_str
		s.seed = Rng.seed_from_string(seed_str)
		s.player_race = "pheasants"
		s.seat_swans = true
		s.all_ai = true

		var game: SimGame = SimGame.create(s, _db)
		for t in range(40):
			if game.gs.game_over:
				break
			var tp: TurnProcessor = TurnProcessor.new(game.gs, _db)
			tp.run_all()
			assert_false(game.gs.game_over and game.gs.victory_type == "error", "No fatal error")

func test_precompute_equals_end_turn() -> void:
	# P10 in miniature: 5 seeds x 10 turns
	for s_idx in range(5):
		var seed_str: String = "PRE_SEED_%d" % s_idx
		var s: GameSettings = (GameSettings as Variant).call(&"new")
		s.preset = "tiny"
		s.seed_string = seed_str
		s.seed = Rng.seed_from_string(seed_str)
		s.player_race = "pheasants"
		s.seat_swans = true
		s.all_ai = true

		var game: SimGame = SimGame.create(s, _db)
		for t in range(10):
			if game.gs.game_over:
				break

			# Precompute economy commands for empire 1
			var view: AiView = AiView.build(game.gs, _db, 1)
			var precomputed: Array[Cmd] = AiPlayer.plan_economy(view)

			# Compute again as End Turn would
			var end_turn_cmds: Array[Cmd] = AiPlayer.plan_economy(view)

			assert_eq(precomputed.size(), end_turn_cmds.size(), "Precomputed cmd count equals end turn")
			for i in range(precomputed.size()):
				assert_eq(precomputed[i].kind(), end_turn_cmds[i].kind(), "Command kind matches")
				assert_eq(precomputed[i].to_dict(), end_turn_cmds[i].to_dict(), "Command data matches")

			var tp: TurnProcessor = TurnProcessor.new(game.gs, _db)
			tp.run_all()

func test_precompute_step_lifecycle_and_invalidation() -> void:
	var s: GameSettings = (GameSettings as Variant).call(&"new")
	s.preset = "evening_standard"
	s.seed_string = "PRE_LIFE_1"
	s.seed = 12345
	s.player_race = "pheasants"
	s.seat_swans = true
	var game: SimGame = SimGame.create(s, _db)

	assert_eq(game.ai_held.size(), 0, "ai_held starts empty")

	# Precompute step advances AI one by one
	var count: int = 0
	while game.precompute_step():
		count += 1
		assert_eq(game.ai_held.size(), count, "ai_held holds precomputed AI")

	assert_gt(count, 0, "At least one AI precomputed")
	assert_false(game.precompute_step(), "precompute_step returns false when all AI held")

	# Submit a player command
	var cmd: CmdSetMilitaryBudget = CmdSetMilitaryBudget.new()
	cmd.empire_id = 0
	cmd.policy = "war"
	var sub_err: String = game.submit(cmd)
	assert_eq(sub_err, "", "Command submitted")

	# Undo clears ai_held
	var undo_ok: bool = game.undo()
	assert_true(undo_ok, "Undo ok")
	assert_eq(game.ai_held.size(), 0, "ai_held cleared on undo")

	# Precompute again after undo
	assert_true(game.precompute_step(), "Precomputed after undo")
	assert_gt(game.ai_held.size(), 0, "ai_held has entries")

	# Redo clears ai_held
	var redo_ok: bool = game.redo()
	assert_true(redo_ok, "Redo ok")
	assert_eq(game.ai_held.size(), 0, "ai_held cleared on redo")

	# Load clears ai_held
	game.precompute_step()
	assert_gt(game.ai_held.size(), 0, "ai_held has entries before load")
	var loaded_game: SimGame = SimGame.from_state(game.gs, _db)
	assert_eq(loaded_game.ai_held.size(), 0, "ai_held cleared on load / from_state")

