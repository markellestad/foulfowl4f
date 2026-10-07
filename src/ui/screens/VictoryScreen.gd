class_name VictoryScreen
extends ScreenBase

var victory_type: String = "conquest"
var winner_race: String = "pheasants"
var is_player_winner: bool = true

func setup(p: Dictionary = {}) -> void:
	super.setup(p)
	victory_type = str(p.get("victory_type", "conquest"))
	winner_race = str(p.get("winner_race", "pheasants"))
	is_player_winner = bool(p.get("is_player_winner", true))

func build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.6)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.PANEL
	style.border_color = Palette.LINE
	style.set_border_width_all(2)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	# Banner Title
	var title := Label.new()
	if not is_player_winner and victory_type == "conquest":
		title.text = "DEFEAT"
		title.add_theme_color_override("font_color", Palette.DANGER)
	else:
		title.text = "VICTORY: " + victory_type.to_upper().replace("_", " ")
		title.add_theme_color_override("font_color", Palette.GOLD)
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Banner Subtitle
	var banner_key: String = "victory.banner." + winner_race
	var banner_text: String = Copy.t(banner_key)
	if banner_text == banner_key:
		banner_text = "As expected."
	var banner_lbl := Label.new()
	banner_lbl.text = banner_text
	banner_lbl.add_theme_font_size_override("font_size", 18)
	banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(banner_lbl)

	# Body
	var body_key: String = "victory." + victory_type + ".body"
	var body_text: String = Copy.t(body_key)
	if body_text == body_key:
		body_text = "The galaxy settles into quiet."
	var body_lbl := Label.new()
	body_lbl.text = body_text
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(body_lbl)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox)

	var btn_one_more := Button.new()
	btn_one_more.text = "One More Turn"
	btn_one_more.tooltip_text = Copy.t("victory.one_more_turn")
	btn_one_more.custom_minimum_size = Vector2(160, 36)
	btn_one_more.pressed.connect(_on_one_more_turn)
	hbox.add_child(btn_one_more)

	var btn_menu := Button.new()
	btn_menu.text = "Quit to Menu"
	btn_menu.custom_minimum_size = Vector2(160, 36)
	btn_menu.pressed.connect(_on_quit_to_menu)
	hbox.add_child(btn_menu)

func _on_one_more_turn() -> void:
	if Session.state != null:
		Session.state.one_more_turn = true
	if router != null:
		router.back()

func _on_quit_to_menu() -> void:
	if router != null:
		router.show_screen(&"main_menu")
