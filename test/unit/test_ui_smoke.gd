extends GutTest

func test_theme_factory() -> void:
	var t100: Theme = ThemeFactory.build(100)
	assert_not_null(t100)
	assert_true(t100.default_font is FontFile)
	assert_true(t100.default_font.resource_path.ends_with("AtkinsonHyperlegible-Regular.ttf"))
	
	var t75: Theme = ThemeFactory.build(75)
	assert_true(t75.default_font_size >= 14, "Size never below 14 at scale 75: was %d" % t75.default_font_size)

func test_main_menu_in_router() -> void:
	var router: UiRouter = UiRouter.new()
	add_child_autofree(router)
	var screen: ScreenBase = router.show_screen(&"main_menu")
	assert_not_null(screen)

	var labels: Array[Node] = screen.find_children("*", "Label", true, false)
	var found_title: bool = false
	for lbl in labels:
		if (lbl as Label).text == Copy.t("menu.title"):
			found_title = true
			break
	assert_true(found_title, "Found title label with menu.title")

	var buttons: Array[Node] = screen.find_children("*", "Button", true, false)
	assert_eq(buttons.size(), 5, "Found exactly 5 buttons")

func test_credits_screen_builds() -> void:
	var router: UiRouter = UiRouter.new()
	add_child_autofree(router)
	var screen: ScreenBase = router.show_screen(&"credits")
	assert_not_null(screen)

func test_capture_fidelity_invariants() -> void:
	Main.apply_theme_and_environment(get_tree())
	var root_theme: Theme = get_tree().root.theme
	assert_not_null(root_theme, "Root theme applied")
	assert_true(root_theme.default_font is FontFile, "Root theme default font is FontFile")
	assert_true(root_theme.default_font.resource_path.ends_with("AtkinsonHyperlegible-Regular.ttf"), "Root theme font is Atkinson Regular")

	var main_node: Main = Main.new()
	add_child_autofree(main_node)
	main_node._build_scene_tree()

	var menu: MainMenu = main_node.ui_root.show_screen(&"main_menu", {"splash_index": 3}) as MainMenu
	assert_not_null(menu, "MainMenu created")

	var center_containers: Array[Node] = menu.find_children("*", "CenterContainer", true, false)
	assert_true(center_containers.size() > 0, "Found CenterContainer")
	var center: CenterContainer = center_containers[0] as CenterContainer

	var vboxes: Array[Node] = center.find_children("*", "VBoxContainer", true, false)
	assert_true(vboxes.size() > 0, "Found VBoxContainer menu column")
	var menu_col: VBoxContainer = vboxes[0] as VBoxContainer

	center.notification(Container.NOTIFICATION_SORT_CHILDREN)

	await get_tree().process_frame
	await get_tree().process_frame

	var col_rect: Rect2 = menu_col.get_global_rect()
	var col_center_x: float = col_rect.position.x + col_rect.size.x / 2.0
	assert_true(abs(col_center_x - 640.0) <= 5.0, "Menu column centered at x=%.1f (expected ~640)" % col_center_x)

func test_new_game_screen_builds() -> void:
	var router: UiRouter = UiRouter.new()
	add_child_autofree(router)
	var screen: ScreenBase = router.show_screen(&"new_game")
	assert_not_null(screen, "NewGameScreen builds")
	var start_btns: Array[Node] = screen.find_children("*", "Button", true, false)
	assert_true(start_btns.size() >= 3, "NewGameScreen has buttons")

func test_galaxy_screen_and_system_panel() -> void:
	var main_node: Main = Main.new()
	add_child_autofree(main_node)
	main_node._build_scene_tree()

	var s: GameSettings = (GameSettings as Variant).call(&"new")
	s.preset = "evening_standard"
	s.seed_string = "FOWL"
	s.seed = Rng.seed_from_string("FOWL")
	s.player_race = "pheasants"
	s.seat_swans = true
	Session.start_galaxy(s)

	var screen: GalaxyScreen = main_node.ui_root.show_screen(&"galaxy") as GalaxyScreen
	assert_not_null(screen, "GalaxyScreen created")
	assert_not_null(screen.system_panel, "SystemPanel present")
	assert_not_null(screen.map_view, "GalaxyMapView present")

	# Test selecting system 0
	screen.map_view.select_system(0)
	assert_eq(screen.system_panel.current_system_id, 0, "System 0 selected in panel")

func test_ship_designer_layout_fits_in_1280x720() -> void:
	var s: GameSettings = (GameSettings as Variant).call(&"new")
	s.preset = "evening_standard"
	s.seed_string = "FOWL"
	s.seed = Rng.seed_from_string("FOWL")
	s.player_race = "pheasants"
	s.seat_swans = true
	Session.new_game(s)

	var router: UiRouter = UiRouter.new()
	router.custom_minimum_size = Vector2(1280, 720)
	router.size = Vector2(1280, 720)
	add_child_autofree(router)

	var screen: ShipDesignerScreen = router.show_screen(&"ship_designer") as ShipDesignerScreen
	assert_not_null(screen, "ShipDesignerScreen created")

	await get_tree().process_frame
	await get_tree().process_frame

	var all_controls: Array[Node] = screen.find_children("*", "Control", true, false)
	for c_node in all_controls:
		var c: Control = c_node as Control
		if c.is_visible_in_tree() and c.size.x > 0 and c.size.y > 0:
			var gr: Rect2 = c.get_global_rect()
			assert_true(gr.end.x <= 1280.0 + 5.0, "Control %s (%s) right edge <= 1280 (got %.1f)" % [c.name, c.get_class(), gr.end.x])

func test_battle_viewer_round_counter_and_conclusion() -> void:
	var router: UiRouter = UiRouter.new()
	router.size = Vector2(1280, 720)
	add_child_autofree(router)

	var blog := BattleLog.new()
	blog.system_id = 2
	for i in range(2):
		blog.initial_units.append({"uid": 10 + i, "empire_id": 0, "name_key": "Swat Escort", "hull_id": "small", "hp": 15, "hp_max": 15, "shield": 2})
		blog.initial_units.append({"uid": 20 + i, "empire_id": 1, "name_key": "Dart Frigate", "hull_id": "small", "hp": 12, "hp_max": 12, "shield": 0})
	for r_i in range(1, 9):
		blog.rounds.append({
			"round_num": r_i,
			"distances": {"1_2": 9},
			"shots": [],
			"horizon_hits": [],
			"swat_intercepts": [],
			"destroyed_uids": []
		})

	var screen: BattleScreen = router.show_screen(&"battle_screen", {"log": blog}) as BattleScreen
	assert_not_null(screen)

	# Round 1 initially
	assert_eq(screen.round_lbl.text, "Round: 1 / 8")

	# Advance to round 2
	screen.current_round_idx = 1
	screen._apply_round(1)
	assert_eq(screen.round_lbl.text, "Round: 2 / 8")
	assert_false(screen.pause_btn.disabled, "Pause enabled mid-battle")

	# Skip to end / conclude
	screen._show_autopsy()
	assert_eq(screen.round_lbl.text, "Round: 8 / 8")
	assert_true(screen.pause_btn.disabled, "Pause disabled after battle conclusion")

func _is_in_scroll_container(node: Node) -> bool:
	var p := node.get_parent()
	while p != null:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false

func test_no_raw_ids_in_all_capture_screens() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	var re_emp := RegEx.new()
	re_emp.compile("\\bEmpire \\d+\\b")
	var re_sys := RegEx.new()
	re_sys.compile("(?i)\\bSystem \\d+\\b")
	var re_flt := RegEx.new()
	re_flt.compile("(?i)\\bFleet \\d+\\b")
	var re_snake := RegEx.new()
	re_snake.compile("\\b[a-z]+_[a-z_]+\\b")
	var re_hull := RegEx.new()
	re_hull.compile("(?i)\\b(small|medium|large|huge):")

	var capture_ids: Array[String] = [
		"main_menu", "credits", "P01_new_game", "P01_galaxy", "P01_system_panel",
		"P02_galaxy_topbar", "P02_colony_panel", "P02_colonies_list", "P02_turn_summary",
		"P03_fleet_panel", "P03_designer", "P03_range_overlay",
		"P04_battle_orders", "P04_battle_viewer", "P04_autopsy",
		"P05_diplomacy", "P05_capitulation_card", "P05_victory", "P05_galaxy_midgame"
	]

	var main_node: Main = Main.new()
	add_child_autofree(main_node)
	main_node._build_scene_tree()
	var router: UiRouter = main_node.ui_root
	router.size = Vector2(1280, 720)
	router.custom_minimum_size = Vector2(1280, 720)

	for cap_id in capture_ids:
		# Run capture setup
		match cap_id:
			"main_menu": CaptureMode._cap_main_menu(router)
			"credits": CaptureMode._cap_credits(router)
			"P01_new_game": CaptureMode._cap_new_game(router)
			"P01_galaxy": CaptureMode._cap_galaxy(router)
			"P01_system_panel": CaptureMode._cap_system_panel(router)
			"P02_galaxy_topbar": CaptureMode._cap_p02_galaxy_topbar(router)
			"P02_colony_panel": CaptureMode._cap_p02_colony_panel(router)
			"P02_colonies_list": CaptureMode._cap_p02_colonies_list(router)
			"P02_turn_summary": CaptureMode._cap_p02_turn_summary(router)
			"P03_fleet_panel": CaptureMode._cap_p03_fleet_panel(router)
			"P03_designer": CaptureMode._cap_p03_designer(router)
			"P03_range_overlay": CaptureMode._cap_p03_range_overlay(router)
			"P04_battle_orders": CaptureMode._cap_p04_battle_orders(router)
			"P04_battle_viewer": CaptureMode._cap_p04_battle_viewer(router)
			"P04_autopsy": CaptureMode._cap_p04_autopsy(router)
			"P05_diplomacy": CaptureMode._cap_p05_diplomacy(router)
			"P05_capitulation_card": CaptureMode._cap_p05_capitulation_card(router)
			"P05_victory": CaptureMode._cap_p05_victory(router)
			"P05_galaxy_midgame": CaptureMode._cap_p05_galaxy_midgame(router)

		await get_tree().process_frame
		await get_tree().process_frame

		# Walk all Labels, Buttons, OptionButtons in router
		var all_nodes: Array[Node] = router.find_children("*", "Control", true, false)
		for node in all_nodes:
			if not (node is Control) or not (node as Control).is_visible_in_tree():
				continue

			var texts_to_check: Array[String] = []
			if node is OptionButton:
				var ob := node as OptionButton
				if ob.text != "":
					texts_to_check.append(ob.text)
				for item_i in range(ob.item_count):
					texts_to_check.append(ob.get_item_text(item_i))
			elif node is Button:
				var btn := node as Button
				if btn.text != "":
					texts_to_check.append(btn.text)
			elif node is Label:
				var lbl := node as Label
				if lbl.text != "":
					texts_to_check.append(lbl.text)

			for t in texts_to_check:
				var m_emp = re_emp.search(t)
				assert_null(m_emp, "[%s] '%s' matched raw Empire pattern: '%s' in node %s" % [cap_id, t, m_emp.get_string() if m_emp else "", node.name])

				var m_sys = re_sys.search(t)
				assert_null(m_sys, "[%s] '%s' matched raw System pattern: '%s' in node %s" % [cap_id, t, m_sys.get_string() if m_sys else "", node.name])

				var m_flt = re_flt.search(t)
				assert_null(m_flt, "[%s] '%s' matched raw Fleet pattern: '%s' in node %s" % [cap_id, t, m_flt.get_string() if m_flt else "", node.name])

				var m_snake = re_snake.search(t)
				assert_null(m_snake, "[%s] '%s' matched snake_case pattern: '%s' in node %s" % [cap_id, t, m_snake.get_string() if m_snake else "", node.name])

				var m_hull = re_hull.search(t)
				assert_null(m_hull, "[%s] '%s' matched raw hull:count pattern: '%s' in node %s" % [cap_id, t, m_hull.get_string() if m_hull else "", node.name])

			var c := node as Control
			if c.size.x > 0 and c.size.y > 0:
				var gr: Rect2 = c.get_global_rect()
				assert_true(gr.end.x <= 1280.0 + 2.0, "[%s] Control %s (%s) right edge <= 1280 (got %.1f)" % [cap_id, c.name, c.get_class(), gr.end.x])
				assert_true(gr.position.x >= -2.0, "[%s] Control %s (%s) left edge >= 0 (got %.1f)" % [cap_id, c.name, c.get_class(), gr.position.x])
				if not _is_in_scroll_container(c):
					assert_true(gr.end.y <= 720.0 + 2.0, "[%s] Control %s (%s) bottom edge <= 720 (got %.1f)" % [cap_id, c.name, c.get_class(), gr.end.y])
					assert_true(gr.position.y >= -2.0, "[%s] Control %s (%s) top edge >= 0 (got %.1f)" % [cap_id, c.name, c.get_class(), gr.position.y])


