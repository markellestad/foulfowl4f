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

	if Session.state.fleets.is_empty() or Session.state.ships.is_empty() or Session.state.designs.is_empty():
		print("BOOT_FAIL fleets/ships/designs is empty")
		main.get_tree().quit(1)
		return

	print("BOOT_FLEET_OK fleets=%d ships=%d" % [Session.state.fleets.size(), Session.state.ships.size()])

	# Fixed 4-vs-4 battle for BOOT_COMBAT_OK
	var c_input := CombatInput.new()
	c_input.system_id = 1
	c_input.turn = 1
	c_input.seed = 12345

	var p0 := CombatParty.new()
	p0.party_id = 1
	p0.empire_id = 0
	p0.posture = "auto"
	for i in range(4):
		var u0 := CombatUnit.new()
		u0.uid = 100 + i
		u0.empire_id = 0
		u0.hull_id = "small"
		u0.hull_space = 1
		u0.hp = 10
		u0.hp_max = 10
		u0.is_armed = true
		u0.combat_speed = 2
		u0.main_band = "talon"
		u0.weapons.append({
			"part_id": "wick_talon",
			"band": "talon",
			"dmg_min": 3,
			"dmg_max": 8,
			"acc": 10,
			"falloff_pct": 4
		})
		p0.units.append(u0)
	c_input.parties.append(p0)

	var p1 := CombatParty.new()
	p1.party_id = 2
	p1.empire_id = 1
	p1.posture = "auto"
	for i in range(4):
		var u1 := CombatUnit.new()
		u1.uid = 200 + i
		u1.empire_id = 1
		u1.hull_id = "small"
		u1.hull_space = 1
		u1.hp = 10
		u1.hp_max = 10
		u1.is_armed = true
		u1.combat_speed = 2
		u1.main_band = "talon"
		u1.weapons.append({
			"part_id": "wick_talon",
			"band": "talon",
			"dmg_min": 3,
			"dmg_max": 8,
			"acc": 10,
			"falloff_pct": 4
		})
		p1.units.append(u1)
	c_input.parties.append(p1)

	var blog: BattleLog = CombatResolver.resolve(c_input)
	if blog == null:
		print("BOOT_FAIL CombatResolver.resolve returned null")
		main.get_tree().quit(1)
		return
	var blog_hash: int = StateHash.hash_dict(blog.to_dict())
	print("BOOT_COMBAT_OK hash=%d" % blog_hash)

	# All-AI 10 turns for BOOT_AI_OK
	var s_ai: GameSettings = (GameSettings as Variant).call(&"new")
	s_ai.preset = "evening_standard"
	s_ai.seed_string = "BOOT"
	s_ai.seed = Rng.seed_from_string("BOOT")
	s_ai.player_race = "pheasants"
	s_ai.seat_swans = true
	s_ai.all_ai = true

	var game_ai: SimGame = SimGame.create(s_ai, Session.db)
	SimLog.clear()
	for i in range(10):
		game_ai.end_turn_headless()
	var invs: Array[String] = Invariants.check(game_ai.gs, Session.db)
	if not invs.is_empty():
		print("BOOT_FAIL BOOT_AI_OK invariants: %s" % str(invs))
		main.get_tree().quit(1)
		return
	print("BOOT_AI_OK turns=%d hash=%d" % [game_ai.gs.turn, game_ai.state_hash()])

	print("BOOT_OK")
	main.get_tree().quit(0)
