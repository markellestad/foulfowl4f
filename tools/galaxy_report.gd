extends SceneTree

func _init() -> void:
	var preset: String = "evening_standard"
	var seed_count: int = 200

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preset="):
			preset = arg.substr("--preset=".length())
		elif arg.begins_with("--seeds="):
			seed_count = int(arg.substr("--seeds=".length()))

	var db: ContentDB = ContentDB.load_from("res://data")
	if not db.is_ok():
		print("GALAXY_REPORT FAIL ContentDB errors: ", db.errors)
		quit(1)
		return

	var climates_table: Dictionary = db.table("climates").get("rows", {})
	var total_far_planets: int = 0
	var total_hab_far: int = 0
	var total_fallbacks: int = 0
	var min_sep_overall: int = 100000

	for i in range(seed_count):
		SimLog.clear()
		var seed_str: String = "S%d" % i
		var s: GameSettings = (GameSettings as Variant).call(&"new")
		s.preset = preset
		s.seed_string = seed_str
		s.seed = Rng.seed_from_string(seed_str)
		s.player_race = "pheasants"
		s.seat_swans = true

		var gs: GameState = GalaxyGenerator.generate(s, db)

		var logs: Array[String] = SimLog.take()
		var fallbacks_this_seed: int = 0
		for l in logs:
			if l.contains("homeworld_fallback"):
				fallbacks_this_seed += 1
		total_fallbacks += fallbacks_this_seed

		if gs.gen_min_sep < min_sep_overall:
			min_sep_overall = gs.gen_min_sep

		var hw_systems: Array[StarSystem] = []
		for sys in gs.systems:
			if sys.home_of != -1:
				hw_systems.append(sys)

		var seed_far_total: int = 0
		var seed_far_hab: int = 0
		for p in gs.planets:
			var sys: StarSystem = gs.systems[p.system_id]
			var far: bool = true
			for hw in hw_systems:
				if IntMath.dist(sys.x, sys.y, hw.x, hw.y) <= 90:
					far = false
					break
			if far:
				seed_far_total += 1
				var c_class: String = str(climates_table.get(p.climate, {}).get("class", ""))
				if c_class == "habitable":
					seed_far_hab += 1

		total_far_planets += seed_far_total
		total_hab_far += seed_far_hab

		var seed_share: float = (float(seed_far_hab) / float(seed_far_total) * 100.0) if seed_far_total > 0 else 0.0
		print("seed %s: sep=%d hab_share=%.1f%% fallbacks=%d" % [seed_str, gs.gen_min_sep, seed_share, fallbacks_this_seed])

	var agg_share: float = (float(total_hab_far) / float(total_far_planets) * 100.0) if total_far_planets > 0 else 0.0
	print("\n=== GALAXY REPORT SUMMARY ===")
	print("min separation: %d dpc" % min_sep_overall)
	print("habitable share beyond 9 pc: %.1f%%" % agg_share)
	print("fallback count: %d" % total_fallbacks)

	quit(0)
