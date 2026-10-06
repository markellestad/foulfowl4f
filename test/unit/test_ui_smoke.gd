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
