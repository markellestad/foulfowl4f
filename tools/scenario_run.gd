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
	settings.all_ai = bool(s_dict.get("all_ai", false))

	var game: SimGame = SimGame.create(settings, db)

	if data.has("tech_known"):
		for t in data["tech_known"]:
			if not game.gs.empires[0].tech.knows(str(t)):
				game.gs.empires[0].tech.known.append(str(t))

	# Index commands by turn
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

	# Index scenario actions by turn
	var actions_by_turn: Dictionary = {}
	var raw_actions: Array = data.get("actions", [])
	for entry in raw_actions:
		if entry is Dictionary:
			var t_num: int = int(entry.get("turn", 1))
			if not actions_by_turn.has(t_num):
				actions_by_turn[t_num] = []
			actions_by_turn[t_num].append(entry)

	var checks_every_turn: Array = data.get("checks_every_turn", [])
	var expect_list: Array = data.get("expect", [])

	for t in range(1, turns_total + 1):
		# 1. Execute scenario actions for turn t
		if actions_by_turn.has(t):
			for act in actions_by_turn[t]:
				var a_err: String = _execute_action(act, game, db)
				if a_err != "":
					print("SCENARIO FAIL %s turn=%d: action_error: %s" % [name, t, a_err])
					quit(1)
					return

		# 2. Execute explicit commands for turn t
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

		# Check for nest drain
		if game.last_report != null:
			for e in game.last_report.entries:
				if e.get("key") == "notify.nest_drained":
					game.metadata["nest_drain_observed"] = true

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

		if game.gs.game_over:
			var all_earlier_done: bool = true
			for exp in expect_list:
				var exp_t: int = int(exp.get("turn", 0))
				if exp_t > t and str(exp.get("check", "")) != "game_over":
					all_earlier_done = false
					break
			if all_earlier_done:
				print("SCENARIO PASS %s turns=%d hash=%d" % [name, t, game.state_hash()])
				quit(0)
				return

	print("SCENARIO PASS %s turns=%d hash=%d" % [name, turns_total, game.state_hash()])
	quit(0)

func _execute_action(act: Dictionary, game: SimGame, db: ContentDB) -> String:
	var action_type: String = str(act.get("action", ""))
	var eid: int = int(act.get("empire", 0))

	match action_type:
		"auto_explore_all":
			for f in game.gs.fleets.values():
				if f.owner == eid:
					var cmd := CmdFleetAutoExplore.new()
					cmd.empire_id = eid
					cmd.fleet_id = f.id
					cmd.on = true
					var err := game.submit(cmd)
					if err != "":
						return "auto_explore_all failed on fleet %d: %s" % [f.id, err]
			return ""

		"colonize_best":
			var nest_fleet: Fleet = null
			for f in game.gs.fleets.values():
				if f.owner == eid and f.system_id >= 0 and f.dest_system_id == -1:
					for sid in f.ship_ids:
						var s: Ship = game.gs.ships.get(sid)
						if s != null:
							var des: ShipDesign = game.gs.designs.get(s.design_id)
							if des != null:
								var st: Dictionary = DesignRules.stats(db, game.gs, des)
								if bool(st.get("colonize", false)):
									nest_fleet = f
									break
				if nest_fleet != null:
					break
			if nest_fleet == null:
				return "colonize_best: no available fleet with colonize ship"

			var emp: Empire = game.gs.empires[eid]
			var traits: Array[String] = emp.species_traits(db)
			var flags: Array[String] = []
			if emp.tech != null:
				for k in emp.tech.known:
					flags.append(str(k))

			var best_pid: int = -1
			var best_pop: int = -1

			for p in game.gs.planets:
				var is_owned: bool = false
				for c in game.gs.colonies.values():
					if c.planet_id == p.id:
						is_owned = true
						break
				if is_owned:
					continue
				if not FuelRange.in_range_system(db, game.gs, eid, p.system_id):
					continue
				var p_sz: int = Habitability.pop_per_size(db, traits, p.climate, flags)
				if p_sz <= 0:
					continue
				var max_pop: int = p_sz * Economy.planet_size_val(p.size)
				if max_pop > best_pop:
					best_pop = max_pop
					best_pid = p.id
				elif max_pop == best_pop:
					if best_pid == -1 or p.id < best_pid:
						best_pid = p.id

			if best_pid == -1:
				return "colonize_best: no habitable unowned in-range planet found"




			var target_p: Planet = game.gs.planets[best_pid]
			if nest_fleet.system_id != target_p.system_id:
				var cmd_move := CmdFleetMove.new()
				cmd_move.empire_id = eid
				cmd_move.fleet_id = nest_fleet.id
				cmd_move.system_id = target_p.system_id
				var m_err := game.submit(cmd_move)
				if m_err != "":
					return "colonize_best move error: %s" % m_err

			var cmd_col := CmdColonize.new()
			cmd_col.empire_id = eid
			cmd_col.fleet_id = nest_fleet.id
			cmd_col.planet_id = target_p.id
			var c_err := game.submit(cmd_col)
			if c_err != "":
				return "colonize_best colonize error: %s" % c_err
			return ""

		"queue_role":
			var role: String = str(act.get("role", ""))
			var des_id: int = -1
			for d in game.gs.designs.values():
				if d.empire_id == eid and d.role == role and not d.obsolete:
					des_id = d.id
					break
			if des_id == -1:
				var best_d: ShipDesign = AutoDesign.design_for_role(db, game.gs, eid, role)
				if best_d != null:
					var cmd_save := CmdDesignSave.new()
					cmd_save.empire_id = eid
					cmd_save.design_data = best_d.to_dict()
					game.submit(cmd_save)
					for d in game.gs.designs.values():
						if d.empire_id == eid and d.role == role and not d.obsolete:
							des_id = d.id
							break
			if des_id == -1:
				return "queue_role: could not find or create design for role %s" % role

			var cap_cid: int = game.gs.empires[eid].capital_colony_id
			var cmd_q := CmdQueueAdd.new()
			cmd_q.empire_id = eid
			cmd_q.colony_id = cap_cid
			cmd_q.kind_item = "ship"
			cmd_q.ref_id = str(des_id)
			cmd_q.count = 1
			cmd_q.index = 0
			var q_err := game.submit(cmd_q)
			if q_err != "":
				return "queue_role error: %s" % q_err
			return ""

		"outpost_best":
			var stake_fleet: Fleet = null
			for f in game.gs.fleets.values():
				if f.owner == eid and f.system_id >= 0 and f.dest_system_id == -1:
					for sid in f.ship_ids:
						var s: Ship = game.gs.ships.get(sid)
						if s != null:
							var des: ShipDesign = game.gs.designs.get(s.design_id)
							if des != null:
								var st: Dictionary = DesignRules.stats(db, game.gs, des)
								if bool(st.get("outpost", false)):
									stake_fleet = f
									break
				if stake_fleet != null:
					break
			if stake_fleet == null:
				return "outpost_best: no available fleet with outpost ship"

			var best_pid: int = -1
			var best_grade: int = -1

			for p in game.gs.planets:
				var is_owned: bool = false
				for c in game.gs.colonies.values():
					if c.planet_id == p.id:
						is_owned = true
						break
				if is_owned:
					continue
				if not FuelRange.in_range_system(db, game.gs, eid, p.system_id):
					continue
				var grade: int = Economy.mineral_base_pp(p.minerals)
				if grade > best_grade:
					best_grade = grade
					best_pid = p.id
				elif grade == best_grade:
					if best_pid == -1 or p.id < best_pid:
						best_pid = p.id

			if best_pid == -1:
				return "outpost_best: no unowned in-range planet found"

			var target_p: Planet = game.gs.planets[best_pid]
			if stake_fleet.system_id != target_p.system_id:
				var cmd_move := CmdFleetMove.new()
				cmd_move.empire_id = eid
				cmd_move.fleet_id = stake_fleet.id
				cmd_move.system_id = target_p.system_id
				var m_err := game.submit(cmd_move)
				if m_err != "":
					return "outpost_best move error: %s" % m_err

			var cmd_out := CmdOutpost.new()
			cmd_out.empire_id = eid
			cmd_out.fleet_id = stake_fleet.id
			cmd_out.planet_id = target_p.id
			var o_err := game.submit(cmd_out)
			if o_err != "":
				return "outpost_best outpost error: %s" % o_err
			return ""

		"set_war":
			var a: int = int(act.get("a", 0))
			var b: int = int(act.get("b", 1))
			Wars.set_war(game.gs, a, b, true)
			return ""

		"spawn_fleet":
			var target_sys_id: int = int(act.get("system", -1))
			if act.has("at_empire_capital"):
				var target_eid: int = int(act["at_empire_capital"])
				for s in game.gs.systems:
					if s.home_of == target_eid:
						target_sys_id = s.id
						break
			if target_sys_id < 0 or target_sys_id >= game.gs.systems.size():
				return "spawn_fleet: invalid target system %d" % target_sys_id

			var flt := Fleet.new()
			flt.id = game.gs.alloc_id("fleet")
			flt.owner = eid
			flt.system_id = target_sys_id
			flt.x = game.gs.systems[target_sys_id].x
			flt.y = game.gs.systems[target_sys_id].y
			flt.name = "Invasion Strike"
			game.gs.fleets[flt.id] = flt

			# 1. Sparrow design
			var sparrow_des: ShipDesign = null
			for d in game.gs.designs.values():
				if d.empire_id == eid and d.name.to_lower().contains("sparrow"):
					sparrow_des = d
					break
			if sparrow_des == null:
				sparrow_des = AutoDesign.design_for_role(db, game.gs, eid, "escort")
			if sparrow_des == null:
				sparrow_des = ShipDesign.new()
				sparrow_des.id = game.gs.alloc_id("design")
				sparrow_des.empire_id = eid
				sparrow_des.name = "Sparrow"
				sparrow_des.hull = "small"
				sparrow_des.engine = "standard_engine"
				sparrow_des.weapons = [{"part": "wick_talon", "mount": "standard", "count": 4}]
				game.gs.designs[sparrow_des.id] = sparrow_des

			var sparrow_stats: Dictionary = DesignRules.stats(db, game.gs, sparrow_des)
			var sparrow_count: int = int(act.get("sparrows", 8))
			for _i in range(sparrow_count):
				var s := Ship.new()
				s.id = game.gs.alloc_id("ship")
				s.design_id = sparrow_des.id
				s.owner = eid
				s.fleet_id = flt.id
				s.hp = int(sparrow_stats.get("hp", 10))
				s.built_turn = game.gs.turn
				game.gs.ships[s.id] = s
				flt.ship_ids.append(s.id)

			# 2. Boot ship design
			var boot_des: ShipDesign = null
			for d in game.gs.designs.values():
				if d.empire_id == eid and (d.role == "boot_ship" or d.name.to_lower().contains("boot")):
					boot_des = d
					break
			if boot_des == null:
				boot_des = AutoDesign.design_for_role(db, game.gs, eid, "boot_ship")
				if boot_des != null:
					boot_des.id = game.gs.alloc_id("design")
					game.gs.designs[boot_des.id] = boot_des
			if boot_des == null:
				boot_des = ShipDesign.new()
				boot_des.id = game.gs.alloc_id("design")
				boot_des.empire_id = eid
				boot_des.name = "Boot Ship"
				boot_des.hull = "small"
				boot_des.engine = "standard_engine"
				boot_des.role = "boot_ship"
				boot_des.specials = ["boot_pod"]
				game.gs.designs[boot_des.id] = boot_des

			var boot_stats: Dictionary = DesignRules.stats(db, game.gs, boot_des)
			var boot_count: int = int(act.get("boot_ships", 5))
			for _i in range(boot_count):
				var s := Ship.new()
				s.id = game.gs.alloc_id("ship")
				s.design_id = boot_des.id
				s.owner = eid
				s.fleet_id = flt.id
				s.hp = int(boot_stats.get("hp", 10))
				s.built_turn = game.gs.turn
				game.gs.ships[s.id] = s
				flt.ship_ids.append(s.id)

			return ""

		"order_invade":
			var target_cid: int = int(act.get("colony_id", -1))
			if act.has("at_empire_capital"):
				var target_eid: int = int(act["at_empire_capital"])
				for c in game.gs.colonies.values():
					var p: Planet = game.gs.planets[c.planet_id]
					var sys: StarSystem = game.gs.systems[p.system_id]
					if sys.home_of == target_eid:
						target_cid = c.id
						break
			if target_cid < 0 or not game.gs.colonies.has(target_cid):
				return "order_invade: colony %d not found" % target_cid

			var target_col: Colony = game.gs.colonies[target_cid]
			var target_sys: StarSystem = game.gs.system_of_planet(target_col.planet_id)
			if target_sys == null:
				return "order_invade: system not found for colony %d" % target_cid

			for f in game.gs.fleets.values():
				if f.owner == eid and f.system_id == target_sys.id:
					f.order = {
						"type": "invade",
						"colony_id": target_cid
					}
			return ""

		_:
			return "unknown action: %s" % action_type
