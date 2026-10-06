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

	var c_dsave := CmdDesignSave.new()
	c_dsave.empire_id = 0
	c_dsave.design_data = {"name": "TestD", "hull": "small", "drive": "walk_drive"}
	cmds.append(c_dsave)

	var c_ddel := CmdDesignDelete.new()
	c_ddel.empire_id = 0
	c_ddel.design_id = 1
	cmds.append(c_ddel)

	var c_fmove := CmdFleetMove.new()
	c_fmove.empire_id = 0
	c_fmove.fleet_id = 1
	c_fmove.system_id = 2
	cmds.append(c_fmove)

	var c_fsplit := CmdFleetSplit.new()
	c_fsplit.empire_id = 0
	c_fsplit.fleet_id = 1
	c_fsplit.ship_ids = [1, 2]
	cmds.append(c_fsplit)

	var c_fmerge := CmdFleetMerge.new()
	c_fmerge.empire_id = 0
	c_fmerge.fleet_id = 1
	c_fmerge.other_id = 2
	cmds.append(c_fmerge)

	var c_fauto := CmdFleetAutoExplore.new()
	c_fauto.empire_id = 0
	c_fauto.fleet_id = 1
	c_fauto.on = true
	cmds.append(c_fauto)

	var c_col := CmdColonize.new()
	c_col.empire_id = 0
	c_col.fleet_id = 1
	c_col.planet_id = 2
	cmds.append(c_col)

	var c_out := CmdOutpost.new()
	c_out.empire_id = 0
	c_out.fleet_id = 1
	c_out.planet_id = 3
	cmds.append(c_out)

	var c_plan := CmdSetBattlePlan.new()
	c_plan.empire_id = 0
	c_plan.fleet_id = 1
	c_plan.posture = "close"
	c_plan.target_priority = "biggest"
	c_plan.swat_mode = "missiles"
	c_plan.retreat_threshold = "half"
	cmds.append(c_plan)

	var c_line := CmdSetLineOrder.new()
	c_line.empire_id = 0
	c_line.fleet_id = 1
	c_line.ship_ids = [2, 1]
	cmds.append(c_line)

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

func test_design_commands_refuse_and_allow() -> void:
	var ctx: Dictionary = _setup_game()
	var gs: GameState = ctx["gs"]

	# Save valid new design
	var c_save := CmdDesignSave.new()
	c_save.empire_id = 0
	c_save.design_data = {
		"name": "Sparrow II",
		"hull": "small",
		"drive": "walk_drive",
		"weapons": [{"part": "wick_talon", "mount": "", "count": 2}]
	}
	assert_eq(c_save.validate(gs, _db), "", "Allows valid design")
	c_save.apply(gs, _db)

	# Verify design was stored
	var d_id: int = -1
	for d in gs.designs.values():
		if d.empire_id == 0 and d.name == "Sparrow II":
			d_id = d.id
			break
	assert_true(d_id >= 0, "Design saved with alloc_id")

	# REFUSE: not owner on existing design
	var c_edit := CmdDesignSave.new()
	c_edit.empire_id = 1
	c_edit.design_data = {"id": d_id, "name": "Hack", "hull": "small", "drive": "walk_drive"}
	assert_eq(c_edit.validate(gs, _db), "refuse.not_owner")

	# Delete design
	var c_del := CmdDesignDelete.new()
	c_del.empire_id = 0
	c_del.design_id = d_id
	assert_eq(c_del.validate(gs, _db), "")
	c_del.apply(gs, _db)
	assert_true(gs.designs[d_id].obsolete, "Design marked obsolete")

	# REFUSE delete: queued in colony
	var col: Colony = ctx["col"]
	var qi := QueueItem.new()
	qi.kind = "ship"
	qi.ref_id = str(d_id)
	col.queue.append(qi)
	gs.designs[d_id].obsolete = false
	assert_eq(c_del.validate(gs, _db), "refuse.design_in_use")
	col.queue.clear()

func test_fleet_commands_refuse_and_allow() -> void:
	var ctx: Dictionary = _setup_game()
	var gs: GameState = ctx["gs"]
	var f: Fleet = gs.fleets[0]

	# Move
	var c_move := CmdFleetMove.new()
	c_move.empire_id = 0
	c_move.fleet_id = f.id

	# REFUSE: same system
	c_move.system_id = f.system_id
	assert_eq(c_move.validate(gs, _db), "refuse.same_system")

	# REFUSE: out of range
	var far_sys_id: int = -1
	var hw_sys: StarSystem = gs.systems[f.system_id]
	for s in gs.systems:
		if IntMath.dist(hw_sys.x, hw_sys.y, s.x, s.y) > 60:
			far_sys_id = s.id
			break
	if far_sys_id >= 0:
		c_move.system_id = far_sys_id
		assert_eq(c_move.validate(gs, _db), "refuse.out_of_range")

	# Split & Merge
	var c_split := CmdFleetSplit.new()
	c_split.empire_id = 0
	c_split.fleet_id = f.id
	c_split.ship_ids = [f.ship_ids[0]]
	assert_eq(c_split.validate(gs, _db), "")
	c_split.apply(gs, _db)

	assert_eq(f.ship_ids.size(), 2)
	var new_f_id: int = -1
	for fid in gs.fleets.keys():
		if fid != f.id and gs.fleets[fid].owner == 0 and gs.fleets[fid].system_id == f.system_id:
			if gs.fleets[fid].ship_ids.size() == 1:
				new_f_id = fid
				break
	assert_true(new_f_id >= 0, "Split created new fleet")

	# Merge back
	var c_merge := CmdFleetMerge.new()
	c_merge.empire_id = 0
	c_merge.fleet_id = f.id
	c_merge.other_id = new_f_id
	assert_eq(c_merge.validate(gs, _db), "")
	c_merge.apply(gs, _db)
	assert_eq(f.ship_ids.size(), 3, "Merged back to 3 ships")
	assert_false(gs.fleets.has(new_f_id), "Merged fleet removed")

	# Auto explore
	var c_auto := CmdFleetAutoExplore.new()
	c_auto.empire_id = 0
	c_auto.fleet_id = f.id
	c_auto.on = true
	assert_eq(c_auto.validate(gs, _db), "")
	c_auto.apply(gs, _db)
	assert_true(f.auto_explore)

	# Battle plan
	var c_plan := CmdSetBattlePlan.new()
	c_plan.empire_id = 0
	c_plan.fleet_id = f.id
	c_plan.posture = "standoff"
	c_plan.target_priority = "biggest"
	c_plan.swat_mode = "missiles"
	c_plan.retreat_threshold = "half"
	assert_eq(c_plan.validate(gs, _db), "")
	c_plan.apply(gs, _db)
	assert_eq(f.plan.posture, "standoff")
	assert_eq(f.plan.retreat_threshold, "half")

	# Line order
	var c_line := CmdSetLineOrder.new()
	c_line.empire_id = 0
	c_line.fleet_id = f.id
	var reversed_ships: Array[int] = [f.ship_ids[2], f.ship_ids[1], f.ship_ids[0]]
	c_line.ship_ids = reversed_ships
	assert_eq(c_line.validate(gs, _db), "")
	c_line.apply(gs, _db)
	assert_eq(f.line_order, reversed_ships)

	# REFUSE line order: invalid permutation
	c_line.ship_ids = [f.ship_ids[0], 9999]
	assert_eq(c_line.validate(gs, _db), "refuse.unknown")
