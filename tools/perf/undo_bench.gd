extends SceneTree

func _init() -> void:
	var db: ContentDB = ContentDB.load_from("res://data")
	var settings: GameSettings = (GameSettings as Variant).call(&"new")
	settings.preset = "evening_standard"
	settings.seed_string = "S0"
	settings.seed = Rng.seed_from_string("S0")
	settings.player_race = "pheasants"
	settings.seats = ["pheasants", "swans", "geese", "ducks"]
	settings.seat_swans = true
	settings.all_ai = true
	settings.turn_cap = 200

	var game: SimGame = SimGame.create(settings, db)
	for t in range(150):
		if game.gs.game_over:
			break
		game.end_turn_headless()

	game.gs.settings.all_ai = false

	# Submit 30 valid planning commands
	for i in range(30):
		var cmd: CmdSetMilitaryBudget = CmdSetMilitaryBudget.new()
		cmd.empire_id = 0
		cmd.policy = "war" if i % 2 == 0 else "guarded"
		game.submit(cmd)

	# Time 20 undos
	var undo_times_usec: Array[int] = []
	for i in range(20):
		var t0: int = Time.get_ticks_usec()
		game.undo()
		var dt: int = Time.get_ticks_usec() - t0
		undo_times_usec.append(dt)

	# Time 20 redos
	var redo_times_usec: Array[int] = []
	for i in range(20):
		var t0: int = Time.get_ticks_usec()
		game.redo()
		var dt: int = Time.get_ticks_usec() - t0
		redo_times_usec.append(dt)

	var all_times_ms: Array[float] = []
	for u in undo_times_usec:
		all_times_ms.append(u / 1000.0)

	all_times_ms.sort()
	var median_ms: float = all_times_ms[all_times_ms.size() / 2]
	var max_ms: float = all_times_ms[-1]
	var checkpoints_count: int = game.checkpoints.size()

	print("UNDO_BENCH median_ms=%.2f max_ms=%.2f checkpoints=%d" % [median_ms, max_ms, checkpoints_count])
	if median_ms <= 80.0:
		print("UNDO_BENCH PASS (budget <= 80 ms)")
		quit(0)
	else:
		print("UNDO_BENCH OVER_BUDGET (median %.2f > 80 ms)" % median_ms)
		quit(1)
