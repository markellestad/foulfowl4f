extends GutTest

var _db: ContentDB

func before_all() -> void:
	_db = ContentDB.load_from("res://data")

func test_galaxy_generation_invariants_200_seeds() -> void:
	var presets_to_test: Array[String] = ["evening_standard", "tiny"]
	var seeds_count: int = 100 # 100 seeds for evening_standard, 100 seeds for tiny (200 total) to stay well under timeout

	var races_table: Dictionary = _db.table("races").get("rows", {})
	var climates_table: Dictionary = _db.table("climates").get("rows", {})

	for preset in presets_to_test:
		var preset_def: Dictionary = _db.table("galaxy")["presets"][preset]
		var exp_stars: int = int(preset_def["stars"])
		var exp_empires: int = int(preset_def["empires"])
		var exp_wh_pairs: int = int(preset_def["wormhole_pairs"])
		var W: int = int(preset_def["width_pc"]) * 10
		var H: int = int(preset_def["height_pc"]) * 10
		var cx: int = IntMath.floor_div(W, 2)
		var cy: int = IntMath.floor_div(H, 2)
		var min_wh_dist: int = IntMath.pct(W, 60)

		var total_far_planets: int = 0
		var total_hab_far: int = 0

		for s_idx in range(seeds_count):
			SimLog.clear()
			var seed_str: String = "S%d" % s_idx
			var s: GameSettings = (GameSettings as Variant).call(&"new")
			s.preset = preset
			s.seed_string = seed_str
			s.seed = Rng.seed_from_string(seed_str)
			s.player_race = "pheasants"
			s.seat_swans = true

			var gs: GameState = GalaxyGenerator.generate(s, _db)

			# 1. Exact star count
			assert_eq(gs.systems.size(), exp_stars, "Exact star count for %s seed %s" % [preset, seed_str])

			# 2. Every pair >= gen_min_sep
			var min_sep: int = gs.gen_min_sep
			for i in range(exp_stars):
				for j in range(i + 1, exp_stars):
					var d: int = IntMath.dist(gs.systems[i].x, gs.systems[i].y, gs.systems[j].x, gs.systems[j].y)
					assert_true(d >= min_sep, "Pair (%d,%d) dist %d >= min_sep %d" % [i, j, d, min_sep])

			# 3. Orn is nearest star to centre
			var orn_sys: StarSystem = null
			var orn_dist_to_c: int = 100000000
			for sys in gs.systems:
				if sys.is_orn:
					orn_sys = sys
					orn_dist_to_c = IntMath.dist(sys.x, sys.y, cx, cy)
					break
			assert_not_null(orn_sys, "Orn exists")
			for sys in gs.systems:
				var d_c: int = IntMath.dist(sys.x, sys.y, cx, cy)
				assert_true(d_c >= orn_dist_to_c, "Orn is nearest to centre")

			# 4. Each homeworld >= 120 dpc from Orn with no homeworld_fallback warning
			var logs: Array[String] = SimLog.take()
			for l in logs:
				assert_false(l.contains("homeworld_fallback"), "No homeworld_fallback on seed %s" % seed_str)

			var hw_systems: Array[StarSystem] = []
			for sys in gs.systems:
				if sys.home_of != -1:
					hw_systems.append(sys)
					var d_orn: int = IntMath.dist(sys.x, sys.y, orn_sys.x, orn_sys.y)
					assert_true(d_orn >= 120, "Homeworld %d dist to Orn %d >= 120" % [sys.home_of, d_orn])

			assert_eq(hw_systems.size(), exp_empires, "Exact homeworld count")

			# 5. Per homeworld exactly fair_good (2) good planets for its race within 90 dpc and >= 1 outpost body
			for hw in hw_systems:
				var emp_id: int = hw.home_of
				var r_id: String = s.seats[emp_id]
				var r_traits: Array[String] = []
				for t in races_table[r_id].get("traits", []):
					r_traits.append(str(t))

				var good_count: int = 0
				var outpost_count: int = 0
				for sys in gs.systems:
					if sys.is_orn:
						continue
					if sys.home_of != -1 and sys.home_of != emp_id:
						continue
					if IntMath.dist(hw.x, hw.y, sys.x, sys.y) > 90:
						continue
					for pid in sys.planet_ids:
						if sys.id == hw.id and pid == hw.planet_ids[0]:
							continue
						var p: Planet = gs.planets[pid]
						if Habitability.is_good_for(_db, r_traits, p.climate):
							good_count += 1
						if p.climate == "asteroids" or p.climate == "gas_giant":
							outpost_count += 1

				assert_eq(good_count, 2, "Exactly 2 good planets for empire %d on seed %s" % [emp_id, seed_str])
				assert_true(outpost_count >= 1, "At least 1 outpost body for empire %d on seed %s" % [emp_id, seed_str])

			# 6. Aggregate habitable share beyond 90 dpc
			for p in gs.planets:
				var sys: StarSystem = gs.systems[p.system_id]
				var far_from_all: bool = true
				for hw in hw_systems:
					if IntMath.dist(sys.x, sys.y, hw.x, hw.y) <= 90:
						far_from_all = false
						break
				if far_from_all:
					total_far_planets += 1
					var c_class: String = str(climates_table.get(p.climate, {}).get("class", ""))
					if c_class == "habitable":
						total_hab_far += 1

			# 7. Wormhole pairs
			var wh_count: int = 0
			for sys in gs.systems:
				if sys.wormhole_to != -1:
					wh_count += 1
					var partner: StarSystem = gs.systems[sys.wormhole_to]
					assert_eq(partner.wormhole_to, sys.id, "Wormhole is bidirectional")
					var wh_d: int = IntMath.dist(sys.x, sys.y, partner.x, partner.y)
					assert_true(wh_d >= min_wh_dist, "Wormhole pair distance >= 60% W")
			if exp_wh_pairs > 0:
				assert_eq(wh_count, 2, "Evening Standard has exactly one wormhole pair (2 endpoints)")
			else:
				assert_eq(wh_count, 0, "Tiny has 0 wormholes")

			# 8. Leviathans >= 100 dpc from homeworlds
			for m in gs.monster_spawns:
				if m["kind"] == "leviathan":
					var lev_sys: StarSystem = gs.systems[int(m["system_id"])]
					for hw in hw_systems:
						var d_lev: int = IntMath.dist(lev_sys.x, lev_sys.y, hw.x, hw.y)
						assert_true(d_lev >= 100, "Leviathan dist %d >= 100 from homeworld %d" % [d_lev, hw.home_of])

		# Aggregate share check for this preset: [20%, 40%]
		assert_true(total_far_planets > 0, "Found planets farther than 90 dpc")
		var share: float = (float(total_hab_far) / float(total_far_planets)) * 100.0
		assert_true(share >= 20.0 and share <= 40.0, "%s aggregate habitable share %.1f%% in [20%%, 40%%]" % [preset, share])

func test_determinism_same_seed_equal_hash() -> void:
	var gs1: GameState = Fixtures.galaxy("evening_standard", "DETERMINISM_TEST", "pheasants")
	var gs2: GameState = Fixtures.galaxy("evening_standard", "DETERMINISM_TEST", "pheasants")
	var h1: int = StateHash.of_value(gs1.to_dict())
	var h2: int = StateHash.of_value(gs2.to_dict())
	assert_eq(h1, h2, "Same seed yields identical StateHash")

func test_determinism_different_seeds_diverge() -> void:
	var gsA: GameState = Fixtures.galaxy("evening_standard", "SEED_A", "pheasants")
	var gsB: GameState = Fixtures.galaxy("evening_standard", "SEED_B", "pheasants")
	var hA: int = StateHash.of_value(gsA.to_dict())
	var hB: int = StateHash.of_value(gsB.to_dict())
	assert_ne(hA, hB, "Different seeds yield different StateHash")
