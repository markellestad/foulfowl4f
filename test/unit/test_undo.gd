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
