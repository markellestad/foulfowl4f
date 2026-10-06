class_name CaptureMode
extends RefCounted

static func run(main: Node, id: String, out_path: String) -> void:
	var router: UiRouter = main.get_node_or_null("UiLayer/UiRoot") as UiRouter
	if router == null:
		print("CAPTURE_FAIL missing UiRouter")
		main.get_tree().quit(1)
		return

	match id:
		"main_menu":
			_cap_main_menu(router)
		"credits":
			_cap_credits(router)
		"new_game", "P01_new_game":
			_cap_new_game(router)
		"galaxy", "P01_galaxy":
			_cap_galaxy(router)
		"system_panel", "P01_system_panel":
			_cap_system_panel(router)
		"P02_galaxy_topbar":
			_cap_p02_galaxy_topbar(router)
		"P02_colony_panel":
			_cap_p02_colony_panel(router)
		"P02_colonies_list":
			_cap_p02_colonies_list(router)
		"P02_turn_summary":
			_cap_p02_turn_summary(router)
		"P03_fleet_panel":
			_cap_p03_fleet_panel(router)
		"P03_designer":
			_cap_p03_designer(router)
		"P03_range_overlay":
			_cap_p03_range_overlay(router)
		"P04_battle_orders":
			_cap_p04_battle_orders(router)
		"P04_battle_viewer":
			_cap_p04_battle_viewer(router)
		"P04_autopsy":
			_cap_p04_autopsy(router)
		_:
			print("CAPTURE_FAIL unknown id: ", id)
			main.get_tree().quit(1)
			return

	_capture_and_save(main, out_path)

static func _cap_main_menu(router: UiRouter) -> void:
	router.show_screen(&"main_menu", {"splash_index": 3})

static func _cap_credits(router: UiRouter) -> void:
	router.show_screen(&"credits")

static func _cap_new_game(router: UiRouter) -> void:
	router.show_screen(&"new_game")

static func _cap_galaxy(router: UiRouter) -> void:
	var s: GameSettings = (GameSettings as Variant).call(&"new")
	s.preset = "evening_standard"
	s.seed_string = "FOWL"
	s.seed = Rng.seed_from_string("FOWL")
	s.player_race = "pheasants"
	s.seat_swans = true
	Session.new_game(s)
	var screen: GalaxyScreen = router.show_screen(&"galaxy") as GalaxyScreen
	if screen != null and screen.map_view != null and screen.map_view.camera != null:
		var cam: MapCamera = screen.map_view.camera
		cam.position = Vector2(880, 600)
		cam.zoom = Vector2(0.50, 0.50)
		cam.zoom_changed.emit(0.50)

static func _cap_system_panel(router: UiRouter) -> void:
	var s: GameSettings = (GameSettings as Variant).call(&"new")
	s.preset = "evening_standard"
	s.seed_string = "FOWL"
	s.seed = Rng.seed_from_string("FOWL")
	s.player_race = "pheasants"
	s.seat_swans = true
	Session.new_game(s)
	var screen: GalaxyScreen = router.show_screen(&"galaxy") as GalaxyScreen
	var hw_id: int = -1
	for sys in Session.state.systems:
		if sys.home_of == 0:
			hw_id = sys.id
			break
	if screen != null:
		if screen.map_view != null:
			screen.map_view.select_system(hw_id)
			if screen.map_view.camera != null:
				screen.map_view.camera.center_on(screen.map_view.player_homeworld_pos)
		if screen.system_panel != null:
			screen.system_panel.show_system(hw_id)

static func _cap_p02_galaxy_topbar(router: UiRouter) -> void:
	var s: GameSettings = (GameSettings as Variant).call(&"new")
	s.preset = "evening_standard"
	s.seed_string = "FOWL"
	s.seed = Rng.seed_from_string("FOWL")
	s.player_race = "pheasants"
	s.seat_swans = true
	Session.new_game(s)
	var screen: GalaxyScreen = router.show_screen(&"galaxy") as GalaxyScreen
	if screen != null and screen.map_view != null and screen.map_view.camera != null:
		var cam: MapCamera = screen.map_view.camera
		cam.position = Vector2(880, 600)
		cam.zoom = Vector2(0.50, 0.50)
		cam.zoom_changed.emit(0.50)

static func _cap_p02_colony_panel(router: UiRouter) -> void:
	var s: GameSettings = (GameSettings as Variant).call(&"new")
	s.preset = "evening_standard"
	s.seed_string = "FOWL"
	s.seed = Rng.seed_from_string("FOWL")
	s.player_race = "pheasants"
	s.seat_swans = true
	Session.new_game(s)
	var screen: GalaxyScreen = router.show_screen(&"galaxy", {"open_colony": 0}) as GalaxyScreen
	if screen != null and screen.colony_panel != null:
		screen.colony_panel.call("expand_industry_breakdown", true)

static func _cap_p02_colonies_list(router: UiRouter) -> void:
	var s: GameSettings = (GameSettings as Variant).call(&"new")
	s.preset = "tiny"
	s.seed_string = "FOWL"
	s.seed = Rng.seed_from_string("FOWL")
	s.player_race = "pheasants"
	s.difficulty = "flighted"
	s.seat_swans = true
	Session.new_game(s)
	for t in range(1, 40):
		if t == 3:
			var cmd := CmdQueueAdd.new()
			cmd.empire_id = 0
			cmd.colony_id = 0
			cmd.kind_item = "building"
			cmd.ref_id = "feed_hall"
			cmd.count = 1
			cmd.index = 0
			Session.submit(cmd)
		Session.game.end_turn_headless()
	router.show_screen(&"colonies_list")

static func _cap_p02_turn_summary(router: UiRouter) -> void:
	var s: GameSettings = (GameSettings as Variant).call(&"new")
	s.preset = "evening_standard"
	s.seed_string = "FOWL"
	s.seed = Rng.seed_from_string("FOWL")
	s.player_race = "pheasants"
	s.seat_swans = true
	Session.new_game(s)

	var col: Colony = Session.state.colonies[0]
	col.pop_milli = 8900
	var qi := QueueItem.new()
	qi.kind = "building"
	qi.ref_id = "feed_hall"
	qi.count = 1
	col.queue.append(qi)
	col.progress_pp = 55

	Session.game.end_turn_headless()
	router.show_screen(&"turn_summary", {"report": Session.state.report})

static func _cap_p03_fleet_panel(router: UiRouter) -> void:
	var s: GameSettings = (GameSettings as Variant).call(&"new")
	s.preset = "tiny"
	s.seed_string = "FOWL"
	s.seed = Rng.seed_from_string("FOWL")
	s.player_race = "pheasants"
	s.difficulty = "flighted"
	s.seat_swans = true
	Session.new_game(s)

	var flt_id: int = -1
	for fid in Session.state.fleets.keys():
		var f: Fleet = Session.state.fleets[fid]
		if f.owner == 0:
			flt_id = fid
			break

	var screen: GalaxyScreen = router.show_screen(&"galaxy", {"open_fleet": flt_id}) as GalaxyScreen
	if screen != null and screen.map_view != null:
		var hw_sys: StarSystem = null
		for sys in Session.state.systems:
			if sys.home_of == 0:
				hw_sys = sys
				break

		# Nearest star system for preview move line
		var target_sys_id: int = 3
		if screen.map_view.fleet_layer != null:
			screen.map_view.fleet_layer.set_move_preview(flt_id, target_sys_id)
		if screen.map_view.camera != null and hw_sys != null:
			screen.map_view.camera.center_on(Vector2(hw_sys.x * 4.0, hw_sys.y * 4.0))
			screen.map_view.camera.zoom = Vector2(0.85, 0.85)
			screen.map_view.camera.zoom_changed.emit(0.85)

static func _cap_p03_designer(router: UiRouter) -> void:
	var s: GameSettings = (GameSettings as Variant).call(&"new")
	s.preset = "evening_standard"
	s.seed_string = "FOWL"
	s.seed = Rng.seed_from_string("FOWL")
	s.player_race = "pheasants"
	s.seat_swans = true
	Session.new_game(s)

	var screen: ShipDesignerScreen = router.show_screen(&"ship_designer") as ShipDesignerScreen
	if screen != null:
		var d := ShipDesign.new()
		d.id = -1
		d.empire_id = 0
		d.name = "Kestrel Talon Line"
		d.role = "talon_line"
		d.hull = "medium"
		d.drive = "walk_drive"
		d.plate = "pinfeather_plate"
		d.weapons = [{"part": "wick_talon", "mount": "", "count": 10}]
		screen.current_design = d
		screen.call("_load_design_to_ui", d)

static func _cap_p03_range_overlay(router: UiRouter) -> void:
	var s: GameSettings = (GameSettings as Variant).call(&"new")
	s.preset = "tiny"
	s.seed_string = "FOWL"
	s.seed = Rng.seed_from_string("FOWL")
	s.player_race = "pheasants"
	s.difficulty = "flighted"
	s.seat_swans = true
	Session.new_game(s)

	# Execute scenario turns up to 45
	var f_sc := FileAccess.open("res://test/scenarios/p03_expand.json", FileAccess.READ)
	if f_sc != null:
		var json := JSON.new()
		if json.parse(f_sc.get_as_text()) == OK:
			var sc_data: Dictionary = json.data as Dictionary
			var acts: Array = sc_data.get("actions", [])
			for t in range(1, 46):
				for act in acts:
					if int(act.get("turn", 0)) == t:
						_exec_scenario_action(Session.game, act)
				if t < 45:
					Session.game.end_turn_headless()

	var screen: GalaxyScreen = router.show_screen(&"galaxy") as GalaxyScreen
	if screen != null:
		if screen.colony_panel != null:
			screen.colony_panel.visible = false
		if screen.system_panel != null:
			screen.system_panel.visible = false
		if screen.fleet_panel != null:
			screen.fleet_panel.visible = false
		if screen.map_view != null:
			if screen.map_view.overlay_layer != null:
				screen.map_view.overlay_layer.set_enabled(true)
			if screen.map_view.camera != null:
				var s12: StarSystem = Session.state.systems[12]
				var s3: StarSystem = Session.state.systems[3]
				var mid_pos := Vector2((s12.x + s3.x) * 2.0, (s12.y + s3.y) * 2.0)
				screen.map_view.camera.center_on(mid_pos)
				screen.map_view.camera.zoom = Vector2(0.85, 0.85)
				screen.map_view.camera.zoom_changed.emit(0.85)

static func _exec_scenario_action(game: SimGame, act: Dictionary) -> void:
	var a_name: String = str(act.get("action", ""))
	var eid: int = int(act.get("empire", 0))
	match a_name:
		"auto_explore_all":
			for f in game.gs.fleets.values():
				if f.owner == eid:
					var cmd := CmdFleetAutoExplore.new()
					cmd.empire_id = eid
					cmd.fleet_id = f.id
					cmd.on = true
					game.submit(cmd)
		"colonize_best":
			var nest_fleet: Fleet = null
			for f in game.gs.fleets.values():
				if f.owner == eid and f.system_id >= 0 and f.dest_system_id == -1:
					for sid in f.ship_ids:
						var s: Ship = game.gs.ships.get(sid)
						if s != null:
							var des: ShipDesign = game.gs.designs.get(s.design_id)
							if des != null:
								var st: Dictionary = DesignRules.stats(game.db, game.gs, des)
								if bool(st.get("colonize", false)):
									nest_fleet = f
									break
				if nest_fleet != null:
					break
			if nest_fleet == null:
				return
			var emp: Empire = game.gs.empires[eid]
			var traits: Array[String] = emp.species_traits(game.db)
			var flags: Array[String] = []
			var best_pid: int = -1
			var best_pop: int = -1
			for p in game.gs.planets:
				var is_owned: bool = false
				for c in game.gs.colonies.values():
					if c.planet_id == p.id:
						is_owned = true
						break
				if is_owned or not FuelRange.in_range_system(game.db, game.gs, eid, p.system_id):
					continue
				var p_sz: int = Habitability.pop_per_size(game.db, traits, p.climate, flags)
				if p_sz <= 0:
					continue
				var max_pop: int = p_sz * Economy.planet_size_val(p.size)
				if max_pop > best_pop or (max_pop == best_pop and (best_pid == -1 or p.id < best_pid)):
					best_pop = max_pop
					best_pid = p.id
			if best_pid != -1:
				var target_p: Planet = game.gs.planets[best_pid]
				if nest_fleet.system_id != target_p.system_id:
					var cmd_m := CmdFleetMove.new()
					cmd_m.empire_id = eid
					cmd_m.fleet_id = nest_fleet.id
					cmd_m.system_id = target_p.system_id
					game.submit(cmd_m)
				var cmd_c := CmdColonize.new()
				cmd_c.empire_id = eid
				cmd_c.fleet_id = nest_fleet.id
				cmd_c.planet_id = target_p.id
				game.submit(cmd_c)
		"queue_role":
			var role: String = str(act.get("role", ""))
			var des_id: int = -1
			for d in game.gs.designs.values():
				if d.empire_id == eid and d.role == role and not d.obsolete:
					des_id = d.id
					break
			if des_id == -1:
				var best_d: ShipDesign = AutoDesign.design_for_role(game.db, game.gs, eid, role)
				if best_d != null:
					var cmd_save := CmdDesignSave.new()
					cmd_save.empire_id = eid
					cmd_save.design_data = best_d.to_dict()
					game.submit(cmd_save)
					for d in game.gs.designs.values():
						if d.empire_id == eid and d.role == role and not d.obsolete:
							des_id = d.id
							break
			if des_id != -1:
				var cap_cid: int = game.gs.empires[eid].capital_colony_id
				var cmd_q := CmdQueueAdd.new()
				cmd_q.empire_id = eid
				cmd_q.colony_id = cap_cid
				cmd_q.kind_item = "ship"
				cmd_q.ref_id = str(des_id)
				cmd_q.count = 1
				cmd_q.index = 0
				game.submit(cmd_q)
		"outpost_best":
			var stake_fleet: Fleet = null
			for f in game.gs.fleets.values():
				if f.owner == eid and f.system_id >= 0 and f.dest_system_id == -1:
					for sid in f.ship_ids:
						var s: Ship = game.gs.ships.get(sid)
						if s != null:
							var des: ShipDesign = game.gs.designs.get(s.design_id)
							if des != null:
								var st: Dictionary = DesignRules.stats(game.db, game.gs, des)
								if bool(st.get("outpost", false)):
									stake_fleet = f
									break
				if stake_fleet != null:
					break
			if stake_fleet == null:
				return
			var best_pid: int = -1
			for p in game.gs.planets:
				var is_owned: bool = false
				for c in game.gs.colonies.values():
					if c.planet_id == p.id:
						is_owned = true
						break
				if is_owned or not FuelRange.in_range_system(game.db, game.gs, eid, p.system_id):
					continue
				if best_pid == -1 or p.id < best_pid:
					best_pid = p.id
			if best_pid != -1:
				var target_p: Planet = game.gs.planets[best_pid]
				if stake_fleet.system_id != target_p.system_id:
					var cmd_m := CmdFleetMove.new()
					cmd_m.empire_id = eid
					cmd_m.fleet_id = stake_fleet.id
					cmd_m.system_id = target_p.system_id
					game.submit(cmd_m)
				var cmd_o := CmdOutpost.new()
				cmd_o.empire_id = eid
				cmd_o.fleet_id = stake_fleet.id
				cmd_o.planet_id = target_p.id
				game.submit(cmd_o)

static func _cap_p04_battle_orders(router: UiRouter) -> void:
	var reqs: Array = [
		{
			"system_id": 1,
			"enemy_visible": {"small": 3, "medium": 1},
			"odds_pct": 65,
			"plan": {"posture": "talon", "target_priority": "biggest", "swat_mode": "missiles_first", "retreat_threshold": "half"},
			"projection": {"talon_round": 2, "beak_round": 5}
		},
		{
			"system_id": 3,
			"enemy_visible": {"small": 2},
			"odds_pct": 82,
			"plan": {"posture": "close", "target_priority": "auto", "swat_mode": "missiles_first", "retreat_threshold": "never"},
			"projection": {"talon_round": 1, "beak_round": 3}
		}
	]
	router.show_screen(&"battle_orders", {"requests": reqs, "auto": [4]})

static func _cap_p04_battle_viewer(router: UiRouter) -> void:
	var blog := BattleLog.new()
	blog.system_id = 2
	blog.turn = 5
	for i in range(4):
		blog.initial_units.append({
			"uid": 10 + i,
			"empire_id": 0,
			"name_key": "Swat Escort",
			"hull_id": "small",
			"hp": 15,
			"hp_max": 15,
			"shield": 2
		})
	for i in range(4):
		blog.initial_units.append({
			"uid": 20 + i,
			"empire_id": 1,
			"name_key": "Dart Frigate",
			"hull_id": "small",
			"hp": 12,
			"hp_max": 12,
			"shield": 0
		})
	for r_i in range(1, 9):
		var r_dict: Dictionary = {
			"round_num": r_i,
			"distances": {"1_2": maxi(0, 11 - r_i)},
			"shots": [],
			"horizon_hits": [],
			"swat_intercepts": [],
			"destroyed_uids": []
		}
		if r_i == 2:
			r_dict["distances"] = {"1_2": 9}
			r_dict["swat_intercepts"] = [
				{"swat_uid": 10, "hit": true},
				{"swat_uid": 11, "hit": true}
			]
		blog.rounds.append(r_dict)

	var screen = router.show_screen(&"battle_screen", {"log": blog})
	if screen != null:
		screen.current_round_idx = 1
		screen._apply_round(1)
		screen.add_ticker_event("Dart Frigate fires Horizon Dart")
		screen.add_ticker_event("Swat Escort intercepts Horizon Dart")
		screen.add_ticker_event("Swat Escort intercepts Horizon Dart")
		if screen.stage != null:
			screen.range_strip.set_distance(9)
			screen.stage.set_distance(9)
			for i in range(5):
				var from_p: Vector2 = screen.stage.get_unit_pos(20 + (i % 4))
				var to_p: Vector2 = screen.stage.get_unit_pos(10 + (i % 4))
				screen.stage.vfx.add_shot(from_p, to_p, "horizon")
			for i in range(3):
				var sp: Vector2 = screen.stage.get_unit_pos(10 + i) + Vector2(randf_range(-20, 20), randf_range(-20, 20))
				screen.stage.vfx.add_swat_flash(sp)

static func _cap_p04_autopsy(router: UiRouter) -> void:
	var blog := BattleLog.new()
	blog.system_id = 1
	blog.turn = 4
	blog.winner_empire_id = 0
	blog.deciding_band = "talon"
	blog.standout_ship_uid = 101
	for r_i in range(1, 9):
		blog.rounds.append({
			"round_num": r_i,
			"distances": {"1_2": maxi(0, 11 - r_i)},
			"shots": [],
			"horizon_hits": [],
			"swat_intercepts": [],
			"destroyed_uids": []
		})
	blog.receipt_lines.append({
		"name_key": "Sparrow",
		"hull_id": "small"
	})
	blog.final_units.append({
		"uid": 101,
		"name_key": "Peregrine Flag",
		"damage_dealt": 84
	})
	var screen = router.show_screen(&"battle_screen", {"log": blog})
	if screen != null:
		screen._show_autopsy()

static func _capture_and_save(main: Node, out_path: String) -> void:
	var tree: SceneTree = main.get_tree()
	for i in 6:
		await tree.process_frame
	await RenderingServer.frame_post_draw

	var img: Image = main.get_viewport().get_texture().get_image()
	var full_path: String = ProjectSettings.globalize_path("res://").path_join(out_path)
	var dir_path: String = full_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)

	var err: Error = img.save_png(full_path)
	if err == OK:
		print("CAPTURE_OK ", out_path)
		tree.quit(0)
	else:
		print("CAPTURE_FAIL failed to save png: ", err)
		tree.quit(1)
