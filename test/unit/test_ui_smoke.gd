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
