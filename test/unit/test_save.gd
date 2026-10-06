extends GutTest

func _build_sample_state() -> GameState:
	var gs: GameState = GameState.new()
	gs.version = 1
	gs.turn = 5
	gs.turn_cap = 200
	gs.gen_min_sep = 45
	gs.settings = GameSettings.new()
	gs.settings.preset = "evening_standard"
	gs.settings.seed_string = "TEST_SEED"
	gs.settings.seed = 12345
	gs.settings.difficulty = "flighted"
	gs.settings.player_race = "pheasants"
	gs.settings.seat_swans = true
	gs.settings.seats = ["pheasants", "swans", "geese", "ducks"]

	gs.next_ids = {
		"fleet": 12,
		"colony": 4,
		"design": 8
	}

	var s0: StarSystem = StarSystem.new()
	s0.id = 0
	s0.name_id = 1
	s0.x = 100
	s0.y = 200
	s0.star_type = "yellow"
	s0.planet_ids = [0, 1]
	s0.is_orn = true
	gs.systems.append(s0)

	var p0: Planet = Planet.new()
	p0.id = 0
	p0.system_id = 0
	p0.orbit = 0
	p0.climate = "gaia"
	p0.size = "huge"
	p0.minerals = "ultra_rich"
	p0.gravity = "normal"
	gs.planets.append(p0)

	var p1: Planet = Planet.new()
	p1.id = 1
	p1.system_id = 0
	p1.orbit = 1
	p1.climate = "barren"
	p1.size = "medium"
	p1.minerals = "poor"
	p1.gravity = "low"
	p1.special = "old_nest"
	gs.planets.append(p1)

	gs.monster_spawns.append({
		"kind": "guardian",
		"system_id": 0
	})

	var emp: Empire = Empire.new()
	emp.id = 0
	emp.race = "pheasants"
	emp.traits = ["talon_adepts", "flush"]
	emp.treasury = 100
	emp.capital_colony_id = 0
	emp.tech.known = ["start", "feed_hall"]
	var tm: TimedMod = TimedMod.new()
	tm.source_key = "event_bonus"
	tm.effects = [{"stat": "growth_pct", "op": "pct", "value": 10}]
	tm.until_turn = 10
	emp.timed_mods.append(tm)
	gs.empires.append(emp)

	var col: Colony = Colony.new()
	col.id = 0
	col.planet_id = 0
	col.owner = 0
	col.species = "pheasants"
	col.pop_milli = 8000
	col.farmers = 3
	col.workers = 3
	col.scientists = 2
	col.preset = "capital"
	col.buildings = ["grand_nest", "the_yard"]
	var qi: QueueItem = QueueItem.new()
	qi.kind = "building"
	qi.ref_id = "feed_hall"
	qi.count = 1
	qi.added_by = "player"
	col.queue.append(qi)
	gs.colonies[0] = col

	var rep: TurnReport = TurnReport.new()
	rep.turn = 5
	rep.add_entry("production", "notify.building_done", {"building": "the_yard", "place": "Gaia Prime"}, "colony", 0)
	gs.report = rep

	return gs

func test_save_round_trip() -> void:
	var gs: GameState = _build_sample_state()
	var summary: Dictionary = {"player_score": 100}
	var bytes: PackedByteArray = Serializer.to_bytes(gs, summary)
	assert_gt(bytes.size(), 0, "Compressed bytes not empty")

	var result: Dictionary = Serializer.from_bytes(bytes)
	assert_true(bool(result.get("ok", false)), "Save loaded successfully")
	assert_eq(str(result.get("error", "")), "")

	var loaded: GameState = result.get("state") as GameState
	assert_not_null(loaded, "Loaded GameState is not null")

	# Envelope fields present
	var env: Dictionary = result.get("envelope", {}) as Dictionary
	assert_eq(env.get("format"), "foulfowl-save")
	assert_eq(env.get("version"), 1)
	assert_eq(env.get("game_version"), "0.1.0")
	assert_true(env.has("created_unix"))
	assert_eq(env.get("turn"), 5)
	assert_eq(env.get("seed_string"), "TEST_SEED")
	assert_eq(env.get("summary"), summary)
	assert_true(env.has("state"))

	# Int keys survive next_ids
	assert_eq(loaded.next_ids.get("fleet"), 12)
	assert_eq(loaded.next_ids.get("colony"), 4)
	assert_eq(loaded.next_ids.get("design"), 8)

	# Empires and colonies round trip
	assert_eq(loaded.empires.size(), 1)
	assert_eq(loaded.empires[0].race, "pheasants")
	assert_true(loaded.colonies.has(0))
	var loaded_col: Colony = loaded.colonies[0]
	assert_eq(loaded_col.species, "pheasants")
	assert_eq(loaded_col.queue.size(), 1)
	assert_eq(loaded_col.queue[0].ref_id, "feed_hall")
	assert_not_null(loaded.report)
	assert_eq(loaded.report.entries.size(), 1)

	# State hash equal
	var hash_orig: int = StateHash.of_value(gs.to_dict())
	var hash_loaded: int = StateHash.of_value(loaded.to_dict())
	assert_eq(hash_orig, hash_loaded, "State hashes match across serialize/deserialize")

func test_save_refuse_corrupt_bytes() -> void:
	var bad_bytes: PackedByteArray = PackedByteArray([0, 1, 2, 3, 4, 5, 6, 7])
	var result: Dictionary = Serializer.from_bytes(bad_bytes)
	assert_false(bool(result.get("ok", false)), "Corrupt bytes refused")
	assert_ne(str(result.get("error", "")), "", "Error message provided")

func test_save_refuse_unsupported_version() -> void:
	var gs: GameState = _build_sample_state()
	gs.version = 99
	var bytes: PackedByteArray = Serializer.to_bytes(gs)
	var result: Dictionary = Serializer.from_bytes(bytes)
	assert_false(bool(result.get("ok", false)), "Version 99 refused")
	assert_true(str(result.get("error", "")).contains("unsupported_save_version: 99"))

func test_migrations_allow_v1() -> void:
	var env: Dictionary = {
		"format": "foulfowl-save",
		"version": 1
	}
	var res: Dictionary = Migrations.migrate(env)
	assert_true(bool(res.get("ok", false)), "Version 1 migration allows")
	assert_eq(str(res.get("error", "")), "")
