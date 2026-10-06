extends GutTest

var _db: ContentDB

func before_all() -> void:
	_db = ContentDB.load_from("res://data")

func _create_game(seed_str: String = "FOWL_TINY") -> GameState:
	var s: GameSettings = GameSettings.new()
	s.preset = "tiny"
	s.seed_string = seed_str
	s.seed = Rng.seed_from_string(seed_str)
	s.player_race = "pheasants"
	s.seat_swans = true
	var gs: GameState = GalaxyGenerator.generate(s, _db)
	StartState.apply(gs, _db)
	return gs

func test_pipeline_order() -> void:
	var expected: Array[StringName] = [
		&"movement",
		&"orbital",
		&"production",
		&"population",
		&"finance",
		&"visibility",
		&"governor",
		&"finalize"
	]
	assert_eq(TurnProcessor.STEP_ORDER, expected, "Pipeline order matches STEP_ORDER")

func test_run_all_equals_substep_by_substep() -> void:
	var gs1: GameState = _create_game("EQUAL_RUN")
	var gs2: GameState = _create_game("EQUAL_RUN")

	var hash_pre1: int = StateHash.of_value(gs1.to_dict())
	var hash_pre2: int = StateHash.of_value(gs2.to_dict())
	assert_eq(hash_pre1, hash_pre2, "Pre-state hashes equal")

	var tp1: TurnProcessor = TurnProcessor.new(gs1, _db)
	tp1.run_all()

	var tp2: TurnProcessor = TurnProcessor.new(gs2, _db)
	while tp2.status != TurnProcessor.Status.DONE:
		tp2.run_next_substep()

	var hash_post1: int = StateHash.of_value(gs1.to_dict())
	var hash_post2: int = StateHash.of_value(gs2.to_dict())
	assert_eq(hash_post1, hash_post2, "run_all equals substep-by-substep execution")

func test_30_turns_zero_invariants() -> void:
	var gs: GameState = _create_game("SOAK_30")
	for t in range(30):
		var tp: TurnProcessor = TurnProcessor.new(gs, _db)
		tp.run_all()
		var errs: Array[String] = Invariants.check(gs, _db)
		assert_eq(errs.size(), 0, "Turn %d has zero invariant violations: %s" % [gs.turn, str(errs)])
	assert_eq(gs.turn, 31, "Turn incremented 30 times from turn 1 to turn 31")

func test_save_load_equivalence() -> void:
	var gs1: GameState = _create_game("SAVE_LOAD_EQ")
	for t in range(10):
		var tp: TurnProcessor = TurnProcessor.new(gs1, _db)
		tp.run_all()

	# Save after turn 10 (now turn 11)
	var bytes: PackedByteArray = Serializer.to_bytes(gs1)
	var res: Dictionary = Serializer.from_bytes(bytes)
	assert_true(bool(res.get("ok", false)), "Save loaded successfully")
	var gs2: GameState = res.get("state") as GameState
	assert_not_null(gs2)

	# Run 20 more turns on both
	for t in range(20):
		var tp1: TurnProcessor = TurnProcessor.new(gs1, _db)
		tp1.run_all()
		var tp2: TurnProcessor = TurnProcessor.new(gs2, _db)
		tp2.run_all()

	var hash1: int = StateHash.of_value(gs1.to_dict())
	var hash2: int = StateHash.of_value(gs2.to_dict())
	assert_eq(hash1, hash2, "Save at T10 + 20 turns equals 30 straight turns")
