class_name BootCheck
extends RefCounted

static func run(main: Node) -> void:
	if Session.db == null or not Session.db.is_ok():
		var err_str: String = "Session.db errors: %s" % (str(Session.db.errors) if Session.db != null else "null")
		print("BOOT_FAIL ", err_str)
		main.get_tree().quit(1)
		return

	if Copy.count() < 10 or not Copy.has("menu.splash.3"):
		print("BOOT_FAIL Copy count < 10 or missing menu.splash.3")
		main.get_tree().quit(1)
		return

	var font_res: Resource = load("res://assets/fonts/AtkinsonHyperlegible-Regular.ttf")
	if not (font_res is FontFile):
		print("BOOT_FAIL Atkinson Regular is not FontFile")
		main.get_tree().quit(1)
		return

	var audio_table: Dictionary = Session.db.table("audio")
	var slots: Dictionary = audio_table.get("slots", {})
	for slot_name in slots.keys():
		var res_path: String = Sfx.resolve(slot_name)
		if res_path == "" or not ResourceLoader.exists(res_path):
			print("BOOT_FAIL Audio slot %s failed to resolve to existing resource: %s" % [slot_name, res_path])
			main.get_tree().quit(1)
			return

	var s: GameSettings = (GameSettings as Variant).call(&"new")
	s.preset = "evening_standard"
	s.seed_string = "FOWL"
	s.seed = Rng.seed_from_string("FOWL")
	s.player_race = "pheasants"
	s.seat_swans = true
	var gs: GameState = GalaxyGenerator.generate(s, Session.db)
	if gs == null or gs.systems.size() != 24:
		print("BOOT_FAIL Galaxy generation failed or stars != 24: ", gs.systems.size() if gs != null else "null")
		main.get_tree().quit(1)
		return
	print("BOOT_GALAXY_OK stars=%d" % gs.systems.size())

	Session.new_game(s)
	if Session.game == null or Session.state.turn != 1:
		print("BOOT_FAIL Session new_game failed")
		main.get_tree().quit(1)
		return

	for i in range(3):
		Session.game.end_turn_headless()

	if Session.state.turn != 4:
		print("BOOT_FAIL expected turn 4, got %d" % Session.state.turn)
		main.get_tree().quit(1)
		return

	print("BOOT_SIM_OK turn=%d" % Session.state.turn)

	print("BOOT_OK")
	main.get_tree().quit(0)
