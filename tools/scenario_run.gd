extends SceneTree

func _init() -> void:
	var scenario_path: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			scenario_path = arg.substr("--scenario=".length())
			break

	if scenario_path == "":
		print("SCENARIO FAIL missing --scenario argument")
		quit(1)
		return

	if not FileAccess.file_exists(scenario_path):
		print("SCENARIO FAIL file not found: %s" % scenario_path)
		quit(1)
		return

	var file := FileAccess.open(scenario_path, FileAccess.READ)
	if file == null:
		print("SCENARIO FAIL cannot read file: %s" % scenario_path)
		quit(1)
		return

	var text: String = file.get_as_text()
	var json := JSON.new()
	var err: Error = json.parse(text)
	if err != OK:
		print("SCENARIO FAIL invalid json in %s" % scenario_path)
		quit(1)
		return

	var data: Dictionary = json.data as Dictionary
	var name: String = str(data.get("name", "unnamed"))
	var turns_total: int = int(data.get("turns", 1))
	var s_dict: Dictionary = data.get("settings", {})

	var db: ContentDB = ContentDB.load_from("res://data")
	var settings: GameSettings = GameSettings.new()
	settings.preset = str(s_dict.get("preset", "tiny"))
	settings.seed_string = str(s_dict.get("seed_string", "FOWL"))
	settings.seed = Rng.seed_from_string(settings.seed_string)
	settings.player_race = str(s_dict.get("player_race", "pheasants"))
	settings.difficulty = str(s_dict.get("difficulty", "flighted"))
	settings.seat_swans = bool(s_dict.get("seat_swans", true))

	var game: SimGame = SimGame.create(settings, db)

	if data.has("tech_known"):
		for t in data["tech_known"]:
			if not game.gs.empires[0].tech.knows(str(t)):
				game.gs.empires[0].tech.known.append(str(t))

	var cmds_by_turn: Dictionary = {}
	var raw_cmds: Array = data.get("commands", [])
	for entry in raw_cmds:
		if entry is Dictionary:
			var t_num: int = int(entry.get("turn", 1))
			var c_dict: Dictionary = entry.get("cmd", {})
			var cmd: Cmd = CmdRegistry.from_dict(c_dict)
			if cmd != null:
				if not cmds_by_turn.has(t_num):
					cmds_by_turn[t_num] = []
				cmds_by_turn[t_num].append(cmd)

	var checks_every_turn: Array = data.get("checks_every_turn", [])
	var expect_list: Array = data.get("expect", [])

	for t in range(1, turns_total + 1):
		if cmds_by_turn.has(t):
			for cmd in cmds_by_turn[t]:
				if cmd is CmdQueueAdd and cmd.kind_item == "building":
					var bdef: Dictionary = db.def("buildings", cmd.ref_id)
					var req_tech: String = str(bdef.get("tech", "start"))
					if req_tech != "start" and not game.gs.empires[cmd.empire_id].tech.knows(req_tech):
						game.gs.empires[cmd.empire_id].tech.known.append(req_tech)

				var submit_err: String = game.submit(cmd)
				if submit_err != "":
					print("SCENARIO FAIL %s turn=%d: command_refused: %s" % [name, t, submit_err])
					quit(1)
					return

		game.end_turn_headless()

		for chk in checks_every_turn:
			var chk_err: String = ScenarioChecks.run(str(chk), game, {})
			if chk_err != "":
				print("SCENARIO FAIL %s turn=%d: %s" % [name, t, chk_err])
				quit(1)
				return

		for exp in expect_list:
			if exp is Dictionary and int(exp.get("turn", 0)) == t:
				var chk_name: String = str(exp.get("check", ""))
				var exp_err: String = ScenarioChecks.run(chk_name, game, exp)
				if exp_err != "":
					print("SCENARIO FAIL %s turn=%d: %s" % [name, t, exp_err])
					quit(1)
					return

	print("SCENARIO PASS %s turns=%d hash=%d" % [name, turns_total, game.state_hash()])
	quit(0)
