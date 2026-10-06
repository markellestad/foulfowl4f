extends GutTest

var _db: ContentDB

func before_all() -> void:
	_db = ContentDB.load_from("res://data")

func _setup_game() -> Dictionary:
	var s: GameSettings = GameSettings.new()
	s.preset = "tiny"
	s.seed_string = "CMD_TEST"
	s.player_race = "pheasants"
	s.seat_swans = true
	var gs: GameState = GalaxyGenerator.generate(s, _db)
	StartState.apply(gs, _db)
	return { "gs": gs, "col": gs.colonies[0], "emp": gs.empires[0] }

func test_command_round_trip() -> void:
	var cmds: Array[Cmd] = []

	var c_preset := CmdSetPreset.new()
	c_preset.empire_id = 0
	c_preset.colony_id = 0
	c_preset.preset = "breadbasket"
	cmds.append(c_preset)

	var c_jobs := CmdSetJobs.new()
	c_jobs.empire_id = 0
	c_jobs.colony_id = 0
	c_jobs.farmers = 4
	c_jobs.workers = 2
	c_jobs.scientists = 2
	c_jobs.lock = true
	cmds.append(c_jobs)

	var c_add := CmdQueueAdd.new()
	c_add.empire_id = 0
	c_add.colony_id = 0
	c_add.kind_item = "building"
	c_add.ref_id = "feed_hall"
	c_add.count = 1
	c_add.index = 0
	cmds.append(c_add)

	var c_rem := CmdQueueRemove.new()
	c_rem.empire_id = 0
	c_rem.colony_id = 0
	c_rem.index = 1
	cmds.append(c_rem)

	var c_mov := CmdQueueMove.new()
	c_mov.empire_id = 0
	c_mov.colony_id = 0
	c_mov.from_idx = 0
	c_mov.to_idx = 2
	cmds.append(c_mov)

	var c_rep := CmdQueueSetRepeat.new()
	c_rep.empire_id = 0
	c_rep.colony_id = 0
	c_rep.index = 0
	c_rep.count = -1
	cmds.append(c_rep)

	var c_buy := CmdBuy.new()
	c_buy.empire_id = 0
	c_buy.colony_id = 0
	cmds.append(c_buy)

	for c in cmds:
		var d1: Dictionary = c.to_dict()
		var restored: Cmd = CmdRegistry.from_dict(d1)
		assert_not_null(restored, "Restored command is not null for %s" % str(c.kind()))
		var d2: Dictionary = restored.to_dict()
		assert_eq(d1, d2, "Command %s round-trips to_dict unchanged" % str(c.kind()))

func test_set_preset_refuse_and_allow() -> void:
	var ctx: Dictionary = _setup_game()
	var gs: GameState = ctx["gs"]

	var cmd := CmdSetPreset.new()
	cmd.empire_id = 0
	cmd.colony_id = 0
	cmd.preset = "breadbasket"
	assert_eq(cmd.validate(gs, _db), "", "Allows valid preset")
	cmd.apply(gs, _db)
	assert_eq(gs.colonies[0].preset, "breadbasket")

	# REFUSE: not owner
	cmd.empire_id = 1
	assert_eq(cmd.validate(gs, _db), "refuse.not_owner")

	# REFUSE: unknown preset
	cmd.empire_id = 0
	cmd.preset = "bogus_preset"
	assert_eq(cmd.validate(gs, _db), "refuse.unknown")

func test_set_jobs_refuse_and_allow() -> void:
	var ctx: Dictionary = _setup_game()
	var gs: GameState = ctx["gs"]
	var col: Colony = ctx["col"]

	var cmd := CmdSetJobs.new()
	cmd.empire_id = 0
	cmd.colony_id = col.id
	cmd.farmers = 4
	cmd.workers = 2
	cmd.scientists = 2
	cmd.lock = true
	assert_eq(cmd.validate(gs, _db), "", "Allows valid job sum (8)")
	cmd.apply(gs, _db)
	assert_eq(col.farmers, 4)
	assert_true(col.jobs_locked)

	# REFUSE: not owner
	cmd.empire_id = 1
	assert_eq(cmd.validate(gs, _db), "refuse.not_owner")

	# REFUSE: sum != pop_units
	cmd.empire_id = 0
	cmd.farmers = 5
	assert_eq(cmd.validate(gs, _db), "refuse.jobs_sum")

	# REFUSE: negative
	cmd.farmers = -1
	cmd.workers = 5
	cmd.scientists = 4
	assert_eq(cmd.validate(gs, _db), "refuse.invalid_jobs")

func test_queue_add_refuse_and_allow() -> void:
	var ctx: Dictionary = _setup_game()
	var gs: GameState = ctx["gs"]
	var col: Colony = ctx["col"]
	var emp: Empire = ctx["emp"]

	col.queue.clear()

	# REFUSE: tech unknown
	var cmd := CmdQueueAdd.new()
	cmd.empire_id = 0
	cmd.colony_id = col.id
	cmd.kind_item = "building"
	cmd.ref_id = "feed_hall" # tech: better_feed
	assert_eq(cmd.validate(gs, _db), "refuse.tech_unknown", "Refuses building with unknown tech")

	# ALLOW: after tech learned
	emp.tech.known.append("better_feed")
	assert_eq(cmd.validate(gs, _db), "", "Allows building after tech learned")
	cmd.apply(gs, _db)
	assert_eq(col.queue.size(), 1)
	assert_eq(col.queue[0].ref_id, "feed_hall")

	# REFUSE: already queued
	var cmd2 := CmdQueueAdd.new()
	cmd2.empire_id = 0
	cmd2.colony_id = col.id
	cmd2.kind_item = "building"
	cmd2.ref_id = "feed_hall"
	assert_eq(cmd2.validate(gs, _db), "refuse.already_built", "Refuses already queued building")

	# REFUSE: already built
	col.buildings.append("richer_dirt")
	emp.tech.known.append("richer_dirt")
	var cmd3 := CmdQueueAdd.new()
	cmd3.empire_id = 0
	cmd3.colony_id = col.id
	cmd3.kind_item = "building"
	cmd3.ref_id = "richer_dirt"
	assert_eq(cmd3.validate(gs, _db), "refuse.already_built", "Refuses already built building")

	# REFUSE: not buildable (grand_nest)
	var cmd4 := CmdQueueAdd.new()
	cmd4.empire_id = 0
	cmd4.colony_id = col.id
	cmd4.kind_item = "building"
	cmd4.ref_id = "grand_nest"
	assert_eq(cmd4.validate(gs, _db), "refuse.not_buildable", "Refuses unbuildable building")

	# REFUSE: not owner
	cmd.empire_id = 1
	assert_eq(cmd.validate(gs, _db), "refuse.not_owner")

	# REFUSE: queue full
	col.queue.clear()
	for i in range(_db.bal("queue_max")):
		var qi := QueueItem.new()
		qi.kind = "trade_goods"
		col.queue.append(qi)
	var cmd_full := CmdQueueAdd.new()
	cmd_full.empire_id = 0
	cmd_full.colony_id = col.id
	cmd_full.kind_item = "trade_goods"
	assert_eq(cmd_full.validate(gs, _db), "refuse.queue_full")

func test_queue_remove_and_move_and_repeat() -> void:
	var ctx: Dictionary = _setup_game()
	var gs: GameState = ctx["gs"]
	var col: Colony = ctx["col"]

	col.queue.clear()
	var q0 := QueueItem.new()
	q0.kind = "trade_goods"
	var q1 := QueueItem.new()
	q1.kind = "housing"
	col.queue = [q0, q1]

	# Move
	var cmd_move := CmdQueueMove.new()
	cmd_move.empire_id = 0
	cmd_move.colony_id = col.id
	cmd_move.from_idx = 0
	cmd_move.to_idx = 1
	assert_eq(cmd_move.validate(gs, _db), "")
	cmd_move.apply(gs, _db)
	assert_eq(col.queue[0].kind, "housing")

	# Move REFUSE: out of range
	cmd_move.from_idx = 5
	assert_eq(cmd_move.validate(gs, _db), "refuse.out_of_range")

	# Repeat
	var cmd_rep := CmdQueueSetRepeat.new()
	cmd_rep.empire_id = 0
	cmd_rep.colony_id = col.id
	cmd_rep.index = 0
	cmd_rep.count = -1
	assert_eq(cmd_rep.validate(gs, _db), "")
	cmd_rep.apply(gs, _db)
	assert_eq(col.queue[0].count, -1)

	# Repeat REFUSE: invalid count
	cmd_rep.count = 0
	assert_eq(cmd_rep.validate(gs, _db), "refuse.invalid_count")

	# Remove
	var cmd_rem := CmdQueueRemove.new()
	cmd_rem.empire_id = 0
	cmd_rem.colony_id = col.id
	cmd_rem.index = 0
	assert_eq(cmd_rem.validate(gs, _db), "")
	cmd_rem.apply(gs, _db)
	assert_eq(col.queue.size(), 1)
	assert_eq(col.queue[0].kind, "trade_goods")

	# Remove REFUSE: out of range
	cmd_rem.index = 5
	assert_eq(cmd_rem.validate(gs, _db), "refuse.out_of_range")

func test_buy_refuse_and_allow() -> void:
	var ctx: Dictionary = _setup_game()
	var gs: GameState = ctx["gs"]
	var col: Colony = ctx["col"]
	var emp: Empire = ctx["emp"]

	col.queue.clear()
	var cmd_buy := CmdBuy.new()
	cmd_buy.empire_id = 0
	cmd_buy.colony_id = col.id

	# REFUSE: empty queue
	assert_eq(cmd_buy.validate(gs, _db), "refuse.empty_queue")

	# REFUSE: filler head
	var q_filler := QueueItem.new()
	q_filler.kind = "trade_goods"
	col.queue.append(q_filler)
	assert_eq(cmd_buy.validate(gs, _db), "refuse.cannot_buy_filler")

	# Building head
	col.queue.clear()
	var q_bld := QueueItem.new()
	q_bld.kind = "building"
	q_bld.ref_id = "boot_barracks" # cost 40
	col.queue.append(q_bld)
	col.progress_pp = 0

	# Price for zero progress: 40 * 200% * 200% = 160
	var price: int = Production.buy_price(_db, gs, col.id)
	assert_eq(price, 160)

	# REFUSE: one credit short (treasury = 159)
	emp.treasury = 159
	assert_eq(cmd_buy.validate(gs, _db), "refuse.cannot_afford", "Refuses when treasury is 1 credit short")

	# ALLOW: exactly at the price (treasury = 160)
	emp.treasury = 160
	assert_eq(cmd_buy.validate(gs, _db), "", "Allows at exactly the price")
	cmd_buy.apply(gs, _db)
	assert_true(col.queue[0].buy_requested, "buy_requested set on head")

	# REFUSE: already requested
	assert_eq(cmd_buy.validate(gs, _db), "refuse.already_requested")
