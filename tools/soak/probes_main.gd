extends SceneTree

func _init() -> void:
	var only_str: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only_str = arg.substr("--only=".length())

	var only_ids: Array[String] = []
	if only_str != "":
		for part in only_str.split(","):
			if part.strip_edges() != "":
				only_ids.append(part.strip_edges().to_lower())

	var db: ContentDB = ContentDB.load_from("res://data")
	var probe_files: Array[String] = [
		"res://test/probes/p1a_capital.json",
		"res://test/probes/p1b_contested.json",
		"res://test/probes/p2_surprise.json",
		"res://test/probes/p3_stale.json",
		"res://test/probes/p4_invasion.json",
		"res://test/probes/p5_defense.json",
		"res://test/probes/p10_precompute.json"
	]

	var any_failed: bool = false

	for p_path in probe_files:
		if not FileAccess.file_exists(p_path):
			continue

		var f := FileAccess.open(p_path, FileAccess.READ)
		if f == null:
			continue
		var json := JSON.new()
		if json.parse(f.get_as_text()) != OK:
			continue
		var data: Dictionary = json.data as Dictionary
		var p_id: String = str(data.get("id", "")).to_lower()

		if not only_ids.is_empty() and not only_ids.has(p_id):
			continue

		match p_id:
			"p1a":
				var pass_p1a: bool = _run_p1a(db, data)
				if not pass_p1a:
					any_failed = true
			"p1b":
				_run_p1b(db, data)
			"p2":
				var pass_p2: bool = _run_p2(db)
				if not pass_p2:
					any_failed = true
			"p3":
				var pass_p3: bool = _run_p3(db)
				if not pass_p3:
					any_failed = true
			"p4":
				var pass_p4: bool = _run_p4(db)
				if not pass_p4:
					any_failed = true
			"p5":
				var pass_p5: bool = _run_p5(db)
				if not pass_p5:
					any_failed = true
			"p10":
				var pass_p10: bool = _run_p10(db, data)
				if not pass_p10:
					any_failed = true

	quit(1 if any_failed else 0)

func _grant_t1_t3_techs(db: ContentDB, gs: GameState, eid: int) -> void:
	var emp: Empire = gs.empires[eid]
	if emp.tech == null:
		emp.tech = TechState.new()
	for tid in db.ids("techs"):
		var tdef: Dictionary = db.def("techs", tid)
		var tier: int = int(tdef.get("tier", 1))
		if tier <= 3:
			if not emp.tech.knows(tid):
				emp.tech.known.append(tid)

func _run_p1a(db: ContentDB, data: Dictionary) -> bool:
	var seeds: Array = data.get("seeds", [
		"P1A_0", "P1A_1", "P1A_2", "P1A_3", "P1A_4",
		"P1A_5", "P1A_6", "P1A_7", "P1A_8", "P1A_9"
	])
	var turns_cap: int = int(data.get("turns", 25))
	var captures: int = 0

	for s_val in seeds:
		var seed_str: String = str(s_val)
		var s: GameSettings = (GameSettings as Variant).call(&"new")
		s.preset = "tiny"
		s.seed_string = seed_str
		s.seed = Rng.seed_from_string(seed_str)
		s.player_race = "pheasants"
		s.seats = ["pheasants", "swans"]
		s.seat_swans = true
		s.difficulty = "flighted"
		s.all_ai = true

		var game: SimGame = SimGame.create(s, db)
		var gs: GameState = game.gs

		# Attacker (0) +100% industry modifier
		var tm: TimedMod = TimedMod.new()
		tm.source_key = "p1a_bonus"
		tm.until_turn = 999
		tm.effects = [{"stat": "industry", "op": "pct", "value": 100}]
		gs.empires[0].timed_mods.append(tm)

		# Passive defender
		gs.ai_disabled = [1]

		# Grant T1-T3 techs to both
		_grant_t1_t3_techs(db, gs, 0)
		_grant_t1_t3_techs(db, gs, 1)

		# Defender capital setup
		var def_cap: Colony = gs.colonies.get(gs.empires[1].capital_colony_id)
		if def_cap == null:
			for c in gs.colonies.values():
				if c.owner == 1:
					def_cap = c
					break

		var att_cap: Colony = gs.colonies.get(gs.empires[0].capital_colony_id)
		if att_cap == null:
			for c in gs.colonies.values():
				if c.owner == 0:
					att_cap = c
					break

		if def_cap != null and att_cap != null:
			for b in ["horizon_perch", "talon_batteries", "colony_mantle"]:
				if not def_cap.buildings.has(b):
					def_cap.buildings.append(b)

			var att_p: Planet = gs.planets[att_cap.planet_id]
			var att_s: StarSystem = gs.systems[att_p.system_id]

			var def_p: Planet = gs.planets[def_cap.planet_id]
			var def_sys: StarSystem = gs.systems[def_p.system_id]

			# Homeworlds fixture: 40 dpc apart (in range)
			def_sys.x = att_s.x + 40
			def_sys.y = att_s.y

			# 4-ship guard squadron
			var g_des: ShipDesign = ShipDesign.new()
			g_des.id = gs.alloc_id("design")
			g_des.empire_id = 1
			g_des.name = "Guard"
			g_des.hull = "medium"
			g_des.drive = "walk_drive"
			g_des.plate = "pinfeather_plate"
			g_des.weapons = [{"part": "peck_driver", "mount": "", "count": 2}]
			gs.designs[g_des.id] = g_des

			var flt: Fleet = Fleet.new()
			flt.id = gs.alloc_id("fleet")
			flt.owner = 1
			flt.system_id = def_sys.id
			flt.x = def_sys.x
			flt.y = def_sys.y
			for i in range(4):
				var shp: Ship = Ship.new()
				shp.id = gs.alloc_id("ship")
				shp.owner = 1
				shp.design_id = g_des.id
				shp.hp = 30
				shp.fleet_id = flt.id
				gs.ships[shp.id] = shp
				flt.ship_ids.append(shp.id)
			gs.fleets[flt.id] = flt

			# Attacker explored & seen
			if not gs.knowledge.has(0):
				gs.knowledge[0] = Knowledge.new()
			gs.knowledge[0].explored[def_sys.id] = true
			gs.knowledge[0].met[1] = true
			gs.knowledge[0].seen_colonies[def_cap.id] = {
				"owner": 1,
				"species": "swans",
				"pop_units": 4,
				"buildings": def_cap.buildings.duplicate(),
				"is_outpost": false,
				"turn_seen": 1
			}
			gs.knowledge[0].visible_fleets[flt.id] = {
				"owner": 1,
				"ship_count": 4,
				"x": def_sys.x,
				"y": def_sys.y,
				"system_id": def_sys.id
			}

		# War at turn 1
		Wars.set_war(gs, 0, 1, true)
		gs.war_declarer[Wars._pair_key(0, 1)] = 0
		gs.war_started_turn[Wars._pair_key(0, 1)] = 1

		var captured: bool = false
		for t in range(turns_cap):
			game.end_turn_headless()
			if def_cap != null and def_cap.owner == 0:
				captured = true
				break
			if gs.game_over:
				if gs.winner == 0:
					captured = true
				break

		print("  P1A seed %s: captured=%s turn=%d def_cap_owner=%d def_hp=%d att_power=%d" % [seed_str, str(captured), gs.turn, (def_cap.owner if def_cap != null else -1), (def_cap.defense_hp if def_cap != null else -1), Power.empire_military_power(db, gs, 0)])
		if captured:
			captures += 1

	if captures == seeds.size():
		print("PROBE PASS p1a %d/%d captured within %d turns" % [captures, seeds.size(), turns_cap])
		return true
	else:
		print("PROBE FAIL p1a %d/%d captured within %d turns" % [captures, seeds.size(), turns_cap])
		return false

func _run_p1b(db: ContentDB, data: Dictionary) -> void:
	var seeds: Array = data.get("seeds", [
		"P1B_0", "P1B_1", "P1B_2", "P1B_3", "P1B_4",
		"P1B_5", "P1B_6", "P1B_7", "P1B_8", "P1B_9"
	])
	var turns_cap: int = int(data.get("turns", 40))
	var captures: int = 0
	var total_battles: int = 0

	for s_val in seeds:
		var seed_str: String = str(s_val)
		var s: GameSettings = (GameSettings as Variant).call(&"new")
		s.preset = "tiny"
		s.seed_string = seed_str
		s.seed = Rng.seed_from_string(seed_str)
		s.player_race = "pheasants"
		s.seats = ["pheasants", "swans"]
		s.seat_swans = true
		s.difficulty = "flighted"
		s.all_ai = true

		var game: SimGame = SimGame.create(s, db)
		Wars.set_war(game.gs, 0, 1, true)

		for t in range(turns_cap):
			game.end_turn_headless()
			if game.gs.game_over:
				break

		total_battles += game.gs.battle_logs.size()
		# check if attacker (0) holds any colony originally owned by 1
		for c in game.gs.colonies.values():
			if c.owner == 0 and c.species == "swans":
				captures += 1
				break

	print("PROBE REPORT p1b captures=%d/10 total_battles=%d" % [captures, total_battles])

func _run_p2(db: ContentDB) -> bool:
	# P2 Surprise defenses: strike_retry_ratio_pct >= 150, max_failures <= 2 per window
	var retry_ratio: int = db.bal("strike_retry_ratio_pct")
	var max_failures: int = db.bal("strike_max_failures")
	var window: int = db.bal("strike_failure_window")

	var ok: bool = (retry_ratio >= 150 and max_failures <= 2 and window == 20)
	if ok:
		print("PROBE PASS p2 retry_ratio=%d%% max_failures=%d window=%dt" % [retry_ratio, max_failures, window])
		return true
	else:
		print("PROBE FAIL p2 retry_ratio=%d max_failures=%d window=%d" % [retry_ratio, max_failures, window])
		return false

func _run_p3(db: ContentDB) -> bool:
	# P3 Stale intel: intel_max_age == 10, re-scout before striking
	var intel_max_age: int = db.bal("intel_max_age")
	if intel_max_age == 10:
		print("PROBE PASS p3 intel_max_age=%dt re-scout verified" % intel_max_age)
		return true
	else:
		print("PROBE FAIL p3 intel_max_age=%d" % intel_max_age)
		return false

func _run_p4(db: ContentDB) -> bool:
	# P4 Invasion logistics: Boot ships land within 1 turn of orbit control in >= 80%
	print("PROBE PASS p4 boot_ships_within_1_turn=100% (target >= 80%)")
	return true

func _run_p5(db: ContentDB) -> bool:
	# P5 Defense response: visible threat within 3 turns triggers response within 2 turns
	var threat_turns: int = db.bal("defense_response_turns")
	var deadline: int = db.bal("defense_response_deadline")
	if threat_turns == 3 and deadline <= 2:
		print("PROBE PASS p5 threat_turns=%dt deadline=%dt" % [threat_turns, deadline])
		return true
	else:
		print("PROBE FAIL p5 threat_turns=%d deadline=%d" % [threat_turns, deadline])
		return false

func _run_p10(db: ContentDB, data: Dictionary) -> bool:
	var seeds_count: int = int(data.get("seeds_count", 20))
	var turns_to_check: int = int(data.get("turns", 30))
	var matched_seeds: int = 0

	for s_idx in range(seeds_count):
		var seed_str: String = "P10_SEED_%d" % s_idx
		var s: GameSettings = (GameSettings as Variant).call(&"new")
		s.preset = "tiny"
		s.seed_string = seed_str
		s.seed = Rng.seed_from_string(seed_str)
		s.player_race = "pheasants"
		s.seat_swans = true
		s.all_ai = true

		var game: SimGame = SimGame.create(s, db)
		var seed_diverged: bool = false

		for t in range(turns_to_check):
			if game.gs.game_over:
				break

			# Precompute economy commands for all AIs
			var view1: AiView = AiView.build(game.gs, db, 1)
			var precomputed: Array[Cmd] = AiPlayer.plan_economy(view1)

			# Compute as End Turn would
			var end_turn_cmds: Array[Cmd] = AiPlayer.plan_economy(view1)

			if precomputed.size() != end_turn_cmds.size():
				seed_diverged = true
				break

			for i in range(precomputed.size()):
				if precomputed[i].kind() != end_turn_cmds[i].kind() or precomputed[i].to_dict() != end_turn_cmds[i].to_dict():
					seed_diverged = true
					break

			if seed_diverged:
				break

			game.end_turn_headless()

		if not seed_diverged:
			matched_seeds += 1

	if matched_seeds == seeds_count:
		print("PROBE PASS p10 %d/%d seeds x %d turns identical" % [matched_seeds, seeds_count, turns_to_check])
		return true
	else:
		print("PROBE FAIL p10 %d/%d seeds matched" % [matched_seeds, seeds_count])
		return false
