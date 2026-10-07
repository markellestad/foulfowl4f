extends SceneTree

func _init() -> void:
	var seeds_arg: String = ""
	var seed_single: String = ""
	var design: String = "smoke20"
	var preset: String = "evening_standard"
	var lineup_str: String = "pheasants,swans,geese,ducks"
	var turn_cap: int = 200
	var out_path: String = ""

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds_arg = arg.substr("--seeds=".length())
		elif arg.begins_with("--seed="):
			seed_single = arg.substr("--seed=".length())
		elif arg.begins_with("--design="):
			design = arg.substr("--design=".length())
		elif arg.begins_with("--preset="):
			preset = arg.substr("--preset=".length())
		elif arg.begins_with("--lineup="):
			lineup_str = arg.substr("--lineup=".length())
		elif arg.begins_with("--turn-cap="):
			turn_cap = int(arg.substr("--turn-cap=".length()))
		elif arg.begins_with("--out="):
			out_path = arg.substr("--out=".length())

	var lineup: Array[String] = []
	for r in lineup_str.split(","):
		if r.strip_edges() != "":
			lineup.append(r.strip_edges())

	var seed_list: Array[String] = []
	if seed_single != "":
		seed_list.append(seed_single)
	elif seeds_arg != "":
		var parts: PackedStringArray = seeds_arg.split(":")
		if parts.size() == 2:
			var s_start: int = int(parts[0])
			var s_end: int = int(parts[1])
			for i in range(s_start, s_end):
				seed_list.append("S%d" % i)
		else:
			seed_list.append(seeds_arg)
	else:
		var count: int = 20
		match design:
			"smoke20": count = 20
			"standard100": count = 100
			"long200": count = 200
			"overnight1000": count = 1000
		for i in range(count):
			seed_list.append("S%d" % i)

	var results: Array[Dictionary] = []
	var total_hard_failures: int = 0

	var db: ContentDB = ContentDB.load_from("res://data")

	for seed_str in seed_list:
		var settings: GameSettings = (GameSettings as Variant).call(&"new")
		settings.preset = preset
		settings.seed_string = seed_str
		settings.seed = Rng.seed_from_string(seed_str)
		settings.player_race = lineup[0] if not lineup.is_empty() else "pheasants"
		settings.seats = lineup.duplicate()
		settings.seat_swans = lineup.has("swans")
		settings.all_ai = true
		settings.turn_cap = turn_cap

		var game: SimGame = SimGame.create(settings, db)
		var game_start_usec: int = Time.get_ticks_usec()
		var turn_times_ms: Array[float] = []
		var hard_failures: Array[String] = []
		var ai_reject_count: int = 0

		SimLog.clear()

		while not game.gs.game_over and game.gs.turn <= turn_cap:
			var t0: int = Time.get_ticks_usec()
			game.end_turn_headless()
			var dt_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
			turn_times_ms.append(dt_ms)
			if dt_ms > 600.0:
				hard_failures.append("TURN_TIMEOUT_EXCEEDED: Turn %d took %.1f ms (> 600 ms)" % [game.gs.turn, dt_ms])

			var logs: Array[String] = SimLog.take()
			for l in logs:
				if l.contains("AI_REJECT"):
					ai_reject_count += 1
					hard_failures.append("AI_REJECT at turn %d: %s" % [game.gs.turn, l])

			var invs: Array[String] = Invariants.check(game.gs, db)
			if not invs.is_empty():
				for ie in invs:
					hard_failures.append("INVARIANT_BREACH at turn %d: %s" % [game.gs.turn, ie])

		var game_elapsed_ms: float = (Time.get_ticks_usec() - game_start_usec) / 1000.0

		if not game.gs.game_over:
			hard_failures.append("GAME_NOT_ENDED_AT_CAP: reached turn %d without game_over" % game.gs.turn)

		var battle_count: int = game.gs.battle_logs.size()
		var total_losses_per_species: Dictionary = {}
		for r in lineup:
			total_losses_per_species[r] = 0

		for blog in game.gs.battle_logs:
			for eid in blog.losses.keys():
				var i_eid: int = int(eid)
				if i_eid >= 0 and i_eid < game.gs.empires.size():
					var sp: String = game.gs.empires[i_eid].race
					var l_val: Variant = blog.losses[eid]
					var l_count: int = (l_val as Array).size() if l_val is Array else int(l_val)
					total_losses_per_species[sp] = int(total_losses_per_species.get(sp, 0)) + l_count

		turn_times_ms.sort()
		var max_turn_ms: float = turn_times_ms[-1] if not turn_times_ms.is_empty() else 0.0
		var median_turn_ms: float = turn_times_ms[turn_times_ms.size() / 2] if not turn_times_ms.is_empty() else 0.0
		var ms_per_turn: float = game_elapsed_ms / max(1, turn_times_ms.size())

		var winner_race: String = ""
		if game.gs.winner >= 0 and game.gs.winner < game.gs.empires.size():
			winner_race = game.gs.empires[game.gs.winner].race

		var rec: Dictionary = {
			"game_id": seed_str,
			"seed": seed_str,
			"winner": winner_race,
			"victory_type": game.gs.victory_type,
			"turn_count": game.gs.turn,
			"elapsed_ms": game_elapsed_ms,
			"ms_per_turn": ms_per_turn,
			"max_turn_ms": max_turn_ms,
			"median_turn_ms": median_turn_ms,
			"battle_count": battle_count,
			"total_losses_per_species": total_losses_per_species,
			"ai_reject_count": ai_reject_count,
			"hard_failures": hard_failures
		}
		results.append(rec)
		total_hard_failures += hard_failures.size()

		print("SOAK GAME %s: winner=%s type=%s turns=%d elapsed=%.0fms ms_per_turn=%.1f hard_failures=%d" % [
			seed_str, winner_race, game.gs.victory_type, game.gs.turn, game_elapsed_ms, ms_per_turn, hard_failures.size()
		])

	if out_path != "":
		var dir_path: String = out_path.get_base_dir()
		if dir_path != "" and not DirAccess.dir_exists_absolute(dir_path):
			DirAccess.make_dir_recursive_absolute(dir_path)
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(results, "\t"))
			f.close()

	quit(1 if total_hard_failures > 0 else 0)
