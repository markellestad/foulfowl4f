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
	Session.game.end_turn_headless()
	router.show_screen(&"turn_summary", {"report": Session.state.report})

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
