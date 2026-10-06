extends GutTest

var _db: ContentDB

func before_all() -> void:
	_db = ContentDB.load_from("res://data")

func _create_sim(seed_str: String = "UNDO_TEST") -> SimGame:
	var s: GameSettings = GameSettings.new()
	s.preset = "tiny"
	s.seed_string = seed_str
	s.player_race = "pheasants"
	s.seat_swans = true
	return SimGame.create(s, _db)

func test_no_revert_in_commands() -> void:
	var dir := DirAccess.open("res://src/sim/commands")
	assert_not_null(dir)
	var files_to_check: Array[String] = []

	var scan_dir = func(path: String, self_fn: Callable) -> void:
		var d := DirAccess.open(path)
		if d == null:
			return
		d.list_dir_begin()
		var fname := d.get_next()
		while fname != "":
			if not fname.begins_with("."):
				var full := path.path_join(fname)
				if d.current_is_dir():
					self_fn.call(full, self_fn)
				elif fname.ends_with(".gd"):
					files_to_check.append(full)
			fname = d.get_next()

	scan_dir.call("res://src/sim/commands", scan_dir)
	assert_gt(files_to_check.size(), 0)

	for fpath in files_to_check:
		var text := FileAccess.get_file_as_string(fpath)
		assert_false(text.contains("func revert"), "File %s contains no revert method" % fpath)

func test_submit_then_undo_restores_hash_per_kind() -> void:
	var game: SimGame = _create_sim("RESTORE_HASH")
	var h0: int = game.state_hash()

	# 1. set_preset
	var c1 := CmdSetPreset.new()
	c1.empire_id = 0
	c1.colony_id = 0
	c1.preset = "breadbasket"
	assert_eq(game.submit(c1), "")
	assert_ne(game.state_hash(), h0)
	assert_true(game.undo())
	assert_eq(game.state_hash(), h0)

	# 2. set_jobs
	var c2 := CmdSetJobs.new()
	c2.empire_id = 0
	c2.colony_id = 0
	c2.farmers = 4
	c2.workers = 2
	c2.scientists = 2
	c2.lock = true
	assert_eq(game.submit(c2), "")
	assert_true(game.undo())
	assert_eq(game.state_hash(), h0)

	# 3. queue_add
	var c3 := CmdQueueAdd.new()
	c3.empire_id = 0
	c3.colony_id = 0
	c3.kind_item = "trade_goods"
	c3.index = 0
	assert_eq(game.submit(c3), "")
	assert_true(game.undo())
	assert_eq(game.state_hash(), h0)

	# 4. queue_move (add two items first)
	var qa1 := CmdQueueAdd.new()
	qa1.empire_id = 0
	qa1.colony_id = 0
	qa1.kind_item = "trade_goods"
	game.submit(qa1)
	var qa2 := CmdQueueAdd.new()
	qa2.empire_id = 0
	qa2.colony_id = 0
	qa2.kind_item = "housing"
	game.submit(qa2)
	var h_two: int = game.state_hash()

	var c4 := CmdQueueMove.new()
	c4.empire_id = 0
	c4.colony_id = 0
	c4.from_idx = 0
	c4.to_idx = 1
	assert_eq(game.submit(c4), "")
	assert_true(game.undo())
	assert_eq(game.state_hash(), h_two)

	# 5. queue_set_repeat
	var c5 := CmdQueueSetRepeat.new()
	c5.empire_id = 0
	c5.colony_id = 0
	c5.index = 0
	c5.count = -1
	assert_eq(game.submit(c5), "")
	assert_true(game.undo())
	assert_eq(game.state_hash(), h_two)

	# 6. buy
	game.gs.empires[0].tech.known.append("better_feed")
	game.gs.empires[0].treasury = 500
	game.checkpoints[game.turn_cmds.size()] = game.gs.to_dict()
	var qa_bld := CmdQueueAdd.new()
	qa_bld.empire_id = 0
	qa_bld.colony_id = 0
	qa_bld.kind_item = "building"
	qa_bld.ref_id = "feed_hall"
	qa_bld.index = 0
	game.submit(qa_bld)
	var h_before_buy: int = game.state_hash()

	var c6 := CmdBuy.new()
	c6.empire_id = 0
	c6.colony_id = 0
	assert_eq(game.submit(c6), "")
	assert_true(game.undo())
	assert_eq(game.state_hash(), h_before_buy)

	# 7. queue_remove
	var c7 := CmdQueueRemove.new()
	c7.empire_id = 0
	c7.colony_id = 0
	c7.index = 0
	assert_eq(game.submit(c7), "")
	assert_true(game.undo())
	assert_eq(game.state_hash(), h_before_buy)

	# 8. design_save
	var h8: int = game.state_hash()
	var c8 := CmdDesignSave.new()
	c8.empire_id = 0
	c8.design_data = {
		"name": "Sparrow II",
		"hull": "small",
		"drive": "walk_drive",
		"weapons": [{"part": "wick_talon", "mount": "", "count": 2}]
	}
	assert_eq(game.submit(c8), "")
	assert_ne(game.state_hash(), h8)
	assert_true(game.undo())
	assert_eq(game.state_hash(), h8)

	# 9. design_delete
	game.submit(c8)
	var h9: int = game.state_hash()
	var new_des_id: int = -1
	for d in game.gs.designs.values():
		if d.empire_id == 0 and d.name == "Sparrow II":
			new_des_id = d.id
			break
	var c9 := CmdDesignDelete.new()
	c9.empire_id = 0
	c9.design_id = new_des_id
	assert_eq(game.submit(c9), "")
	assert_ne(game.state_hash(), h9)
	assert_true(game.undo())
	assert_eq(game.state_hash(), h9)
	game.undo()
	assert_eq(game.state_hash(), h8)

	# 10. fleet_move
	var h10: int = game.state_hash()
	var f0: Fleet = game.gs.fleets[0]
	var in_range_sys_id: int = -1
	for s in game.gs.systems:
		if s.id != f0.system_id and FuelRange.in_range_system(_db, game.gs, 0, s.id):
			in_range_sys_id = s.id
			break
	if in_range_sys_id >= 0:
		var c10 := CmdFleetMove.new()
		c10.empire_id = 0
		c10.fleet_id = f0.id
		c10.system_id = in_range_sys_id
		assert_eq(game.submit(c10), "")
		assert_ne(game.state_hash(), h10)
		assert_true(game.undo())
		assert_eq(game.state_hash(), h10)

	# 11. fleet_split
	var h11: int = game.state_hash()
	var f11: Fleet = game.gs.fleets[0]
	var c11 := CmdFleetSplit.new()
	c11.empire_id = 0
	c11.fleet_id = f11.id
	c11.ship_ids = [f11.ship_ids[0]]
	assert_eq(game.submit(c11), "")
	assert_ne(game.state_hash(), h11)
	assert_true(game.undo())
	assert_eq(game.state_hash(), h11)

	# 12. fleet_merge
	var f12_pre: Fleet = game.gs.fleets[0]
	c11.fleet_id = f12_pre.id
	c11.ship_ids = [f12_pre.ship_ids[0]]
	game.submit(c11)
	var h12: int = game.state_hash()
	var split_f_id: int = -1
	for fid in game.gs.fleets.keys():
		if fid != f12_pre.id and game.gs.fleets[fid].owner == 0:
			split_f_id = fid
			break
	var c12 := CmdFleetMerge.new()
	c12.empire_id = 0
	c12.fleet_id = f12_pre.id
	c12.other_id = split_f_id
	assert_eq(game.submit(c12), "")
	assert_ne(game.state_hash(), h12)
	assert_true(game.undo())
	assert_eq(game.state_hash(), h12)
	game.undo()
	assert_eq(game.state_hash(), h11)

	# 13. fleet_auto_explore
	var h13: int = game.state_hash()
	var f13: Fleet = game.gs.fleets[0]
	var c13 := CmdFleetAutoExplore.new()
	c13.empire_id = 0
	c13.fleet_id = f13.id
	c13.on = true
	assert_eq(game.submit(c13), "")
	assert_ne(game.state_hash(), h13)
	assert_true(game.undo())
	assert_eq(game.state_hash(), h13)

	# 14. colonize
	var f14: Fleet = game.gs.fleets[0]
	var dum_p := Planet.new()
	dum_p.id = game.gs.planets.size()
	dum_p.system_id = f14.system_id
	dum_p.orbit = 8
	dum_p.climate = "terran"
	dum_p.size = "medium"
	dum_p.minerals = "abundant"
	game.gs.planets.append(dum_p)
	game.checkpoints[game.turn_cmds.size()] = game.gs.to_dict()
	var h14: int = game.state_hash()

	var c14 := CmdColonize.new()
	c14.empire_id = 0
	c14.fleet_id = f14.id
	c14.planet_id = dum_p.id
	assert_eq(game.submit(c14), "")
	assert_ne(game.state_hash(), h14)
	assert_true(game.undo())
	assert_eq(game.state_hash(), h14)

	# 15. outpost
	var f15: Fleet = game.gs.fleets[0]
	var des_out := ShipDesign.new()
	des_out.id = game.gs.alloc_id("design")
	des_out.empire_id = 0
	des_out.specials = ["perch_pod"]
	des_out.hull = "small"
	des_out.drive = "walk_drive"
	game.gs.designs[des_out.id] = des_out
	var s_out := Ship.new()
	s_out.id = game.gs.alloc_id("ship")
	s_out.design_id = des_out.id
	s_out.owner = 0
	game.gs.ships[s_out.id] = s_out
	f15.ship_ids.append(s_out.id)
	game.checkpoints[game.turn_cmds.size()] = game.gs.to_dict()
	var h15: int = game.state_hash()

	var c15 := CmdOutpost.new()
	c15.empire_id = 0
	c15.fleet_id = f15.id
	c15.planet_id = dum_p.id
	assert_eq(game.submit(c15), "")
	assert_ne(game.state_hash(), h15)
	assert_true(game.undo())
	assert_eq(game.state_hash(), h15)

	# 16. set_battle_plan
	var f16: Fleet = game.gs.fleets[0]
	var h16: int = game.state_hash()
	var c16 := CmdSetBattlePlan.new()
	c16.empire_id = 0
	c16.fleet_id = f16.id
	c16.posture = "standoff"
	c16.target_priority = "biggest"
	c16.swat_mode = "missiles"
	c16.retreat_threshold = "half"
	assert_eq(game.submit(c16), "")
	assert_ne(game.state_hash(), h16)
	assert_true(game.undo())
	assert_eq(game.state_hash(), h16)

	# 17. set_line_order
	var f17: Fleet = game.gs.fleets[0]
	var h17: int = game.state_hash()
	var c17 := CmdSetLineOrder.new()
	c17.empire_id = 0
	c17.fleet_id = f17.id
	var rev_sids: Array[int] = []
	for sid in f17.ship_ids:
		rev_sids.insert(0, sid)
	c17.ship_ids = rev_sids
	assert_eq(game.submit(c17), "")
	assert_ne(game.state_hash(), h17)
	assert_true(game.undo())
	assert_eq(game.state_hash(), h17)

func test_redo_cleared_by_new_submit() -> void:
	var game: SimGame = _create_sim("REDO_TEST")
	var c1 := CmdSetPreset.new()
	c1.empire_id = 0
	c1.colony_id = 0
	c1.preset = "breadbasket"
	game.submit(c1)
	assert_true(game.can_undo())
	game.undo()
	assert_true(game.can_redo())

	# New submit clears redo list
	var c2 := CmdSetPreset.new()
	c2.empire_id = 0
	c2.colony_id = 0
	c2.preset = "fortress"
	game.submit(c2)
	assert_false(game.can_redo(), "Redo cleared by new submit")

func test_checkpoint_boundary_undo() -> void:
	var game: SimGame = _create_sim("CHECKPOINT_TEST")
	var presets := ["capital", "industry", "research", "breadbasket", "frontier", "fortress"]
	var applied_cmds: Array[Cmd] = []

	# Submit 25 commands
	for i in range(25):
		var c := CmdSetPreset.new()
		c.empire_id = 0
		c.colony_id = 0
		c.preset = presets[i % presets.size()]
		game.submit(c)
		applied_cmds.append(c)

	assert_eq(game.turn_cmds.size(), 25)
	# Checkpoints were taken at 0, 10, 20
	assert_true(game.checkpoints.has(0))
	assert_true(game.checkpoints.has(10))
	assert_true(game.checkpoints.has(20))

	# Undo 7 commands (target size 18)
	for i in range(7):
		assert_true(game.undo())

	assert_eq(game.turn_cmds.size(), 18)
	assert_false(game.checkpoints.has(20), "Checkpoint at 20 was removed on undo to 18")

	# Compare with fresh game that only had the first 18 commands applied
	var fresh: SimGame = _create_sim("CHECKPOINT_TEST")
	for i in range(18):
		fresh.submit(applied_cmds[i])

	assert_eq(game.state_hash(), fresh.state_hash(), "Undo across checkpoint boundary is exact")

func test_random_commands_undo_redo_replay_equivalence() -> void:
	var game: SimGame = _create_sim("RANDOM_REPLAY")
	var rng: Rng = Rng.keyed(12345, 1, Rng.AI, 0, 0)

	var valid_cmds: Array[Cmd] = []
	var presets := ["capital", "industry", "research", "breadbasket", "frontier", "fortress"]

	# Generate and submit 30 valid commands
	for i in range(30):
		var choice: int = rng.range_i(0, 2)
		var c: Cmd = null
		if choice == 0:
			var cp := CmdSetPreset.new()
			cp.empire_id = 0
			cp.colony_id = 0
			cp.preset = presets[rng.range_i(0, presets.size() - 1)]
			c = cp
		elif choice == 1:
			var cj := CmdSetJobs.new()
			cj.empire_id = 0
			cj.colony_id = 0
			var f: int = rng.range_i(0, 8)
			var w: int = rng.range_i(0, 8 - f)
			var s: int = 8 - f - w
			cj.farmers = f
			cj.workers = w
			cj.scientists = s
			cj.lock = (rng.range_i(0, 1) == 1)
			c = cj
		else:
			var ca := CmdQueueAdd.new()
			ca.empire_id = 0
			ca.colony_id = 0
			ca.kind_item = "trade_goods" if rng.range_i(0, 1) == 0 else "housing"
			ca.index = 0
			c = ca

		# If queue is full, switch to preset
		if c is CmdQueueAdd and game.gs.colonies[0].queue.size() >= 8:
			var cp2 := CmdSetPreset.new()
			cp2.empire_id = 0
			cp2.colony_id = 0
			cp2.preset = "manual"
			c = cp2

		var err: String = game.submit(c)
		assert_eq(err, "", "Command %d valid: %s" % [i, err])

	assert_eq(game.turn_cmds.size(), 30)

	# 12 undos
	for i in range(12):
		assert_true(game.undo())
	assert_eq(game.turn_cmds.size(), 18)

	# 5 redos
	for i in range(5):
		assert_true(game.redo())
	assert_eq(game.turn_cmds.size(), 23)

	# Copy surviving 23 commands
	var surviving: Array[Cmd] = []
	for c in game.turn_cmds:
		surviving.append(CmdRegistry.from_dict(c.to_dict()))

	# End turn on game
	game.end_turn_headless()
	var hash_game: int = game.state_hash()

	# Fresh game fed only the surviving 23 commands then ended
	var fresh: SimGame = _create_sim("RANDOM_REPLAY")
	for c in surviving:
		var err2: String = fresh.submit(c)
		assert_eq(err2, "")
	fresh.end_turn_headless()
	var hash_fresh: int = fresh.state_hash()

	assert_eq(hash_game, hash_fresh, "30 cmds -> 12 undos -> 5 redos -> end turn equals fresh game fed 23 surviving cmds")

func test_undo_beyond_max_returns_false() -> void:
	var game: SimGame = _create_sim("UNDO_MAX_TEST")
	var presets := ["capital", "industry", "research", "breadbasket", "frontier", "fortress"]

	# Submit 55 commands (undo_max is 50)
	for i in range(55):
		var c := CmdSetPreset.new()
		c.empire_id = 0
		c.colony_id = 0
		c.preset = presets[i % presets.size()]
		game.submit(c)

	assert_eq(game.turn_cmds.size(), 55)

	# 50 undos succeed
	for i in range(50):
		assert_true(game.undo(), "Undo %d of 50 succeeds" % (i + 1))

	# 51st undo returns false
	assert_false(game.can_undo(), "can_undo is false after 50 undos")
	assert_false(game.undo(), "51st undo beyond undo_max returns false")
