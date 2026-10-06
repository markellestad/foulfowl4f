class_name NewGameScreen
extends ScreenBase

const PLAYABLE_RACES: Array[String] = ["pheasants", "swans", "ducks", "geese"]
const DIFFICULTIES: Array[String] = ["nestling", "flighted", "honk_admiral", "lights_off_ledger"]

var _selected_preset: String = "evening_standard"
var _selected_difficulty: String = "flighted"
var _selected_race: String = "pheasants"

var _preset_group: ButtonGroup = ButtonGroup.new()
var _race_group: ButtonGroup = ButtonGroup.new()

var _difficulty_btn: OptionButton = null
var _seed_edit: LineEdit = null
var _seat_swans_chk: CheckBox = null

func build() -> void:
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var root_vbox := Ui.vbox(20)
	margin.add_child(root_vbox)

	# Header
	var title_lbl := Ui.label(Copy.t("ui.label.new_game"), "HeadingLarge")
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(title_lbl)

	# Main 2-column layout (Preset/Difficulty/Seed on left, Race on right)
	var columns := Ui.hbox(40)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(columns)

	# Left Column
	var left_col := Ui.vbox(16)
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left_col)

	# Preset Selection
	var preset_panel := _build_preset_section()
	left_col.add_child(preset_panel)

	# Difficulty Selection
	var diff_section := _build_difficulty_section()
	left_col.add_child(diff_section)

	# Seed Selection
	var seed_section := _build_seed_section()
	left_col.add_child(seed_section)

	# Seat the Swans Toggle
	_seat_swans_chk = CheckBox.new()
	_seat_swans_chk.text = Copy.t("menu.toggle.seat_swans")
	_seat_swans_chk.tooltip_text = Copy.t("menu.toggle.seat_swans.tip")
	_seat_swans_chk.button_pressed = true
	left_col.add_child(_seat_swans_chk)

	# Right Column (Race Selection)
	var right_col := Ui.vbox(10)
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right_col)

	var race_lbl := Ui.label(Copy.t("ui.label.race"), "HeadingMedium")
	right_col.add_child(race_lbl)

	var race_list := _build_race_section()
	right_col.add_child(race_list)

	# Bottom Actions
	var actions_row := Ui.hbox(20)
	actions_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(actions_row)

	var btn_back := Ui.button(Copy.t("ui.label.back"), _on_back)
	btn_back.custom_minimum_size = Vector2(160, 42)
	actions_row.add_child(btn_back)

	var btn_start := Ui.button(Copy.t("ui.label.start"), _on_start)
	btn_start.custom_minimum_size = Vector2(200, 42)
	actions_row.add_child(btn_start)

func _build_preset_section() -> Control:
	var v := Ui.vbox(8)

	var lbl := Ui.label(Copy.t("ui.label.preset"), "HeadingMedium")
	v.add_child(lbl)

	var presets: Array[String] = ["evening_standard", "tiny"]
	for p_id in presets:
		var btn := CheckBox.new()
		btn.button_group = _preset_group
		var p_name: String = Copy.t("menu.preset.%s.name" % p_id)
		var p_sub: String = Copy.t("menu.preset.%s.sub" % p_id)
		btn.text = "%s (%s)" % [p_name, p_sub]
		if p_id == _selected_preset:
			btn.button_pressed = true
		btn.toggled.connect(func(pressed: bool) -> void:
			if pressed:
				_selected_preset = p_id
		)
		v.add_child(btn)

	return v

func _build_difficulty_section() -> Control:
	var v := Ui.vbox(6)
	var lbl := Ui.label(Copy.t("ui.label.difficulty"), "HeadingMedium")
	v.add_child(lbl)

	_difficulty_btn = OptionButton.new()
	_difficulty_btn.custom_minimum_size = Vector2(260, 36)
	for i in range(DIFFICULTIES.size()):
		var d_id: String = DIFFICULTIES[i]
		var d_name: String = Copy.t("difficulty.%s.name" % d_id)
		_difficulty_btn.add_item(d_name, i)
		_difficulty_btn.set_item_tooltip(i, Copy.t("difficulty.%s.tip" % d_id))
		if d_id == _selected_difficulty:
			_difficulty_btn.select(i)

	_difficulty_btn.item_selected.connect(func(idx: int) -> void:
		_selected_difficulty = DIFFICULTIES[idx]
	)
	v.add_child(_difficulty_btn)
	return v

func _build_seed_section() -> Control:
	var v := Ui.vbox(6)
	var lbl := Ui.label(Copy.t("ui.label.seed"), "HeadingMedium")
	v.add_child(lbl)

	var h := Ui.hbox(8)
	v.add_child(h)

	_seed_edit = LineEdit.new()
	_seed_edit.text = "FOWL"
	_seed_edit.custom_minimum_size = Vector2(180, 36)
	h.add_child(_seed_edit)

	var btn_rand := Ui.button(Copy.t("ui.label.random"), func() -> void:
		_seed_edit.text = "S%d" % (Time.get_ticks_usec() % 10000)
	)
	btn_rand.custom_minimum_size = Vector2(80, 36)
	h.add_child(btn_rand)

	return v

func _build_race_section() -> Control:
	var v := Ui.vbox(8)

	for r_id in PLAYABLE_RACES:
		var panel := PanelContainer.new()
		var p_style := StyleBoxFlat.new()
		p_style.bg_color = Palette.PANEL
		p_style.set_content_margin_all(10)
		p_style.corner_radius_top_left = 6
		p_style.corner_radius_top_right = 6
		p_style.corner_radius_bottom_left = 6
		p_style.corner_radius_bottom_right = 6
		panel.add_theme_stylebox_override("panel", p_style)

		var row := Ui.hbox(12)
		panel.add_child(row)

		var radio := CheckBox.new()
		radio.button_group = _race_group
		if r_id == _selected_race:
			radio.button_pressed = true
		radio.toggled.connect(func(pressed: bool) -> void:
			if pressed:
				_selected_race = r_id
		)
		row.add_child(radio)

		# Color Swatch
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(24, 24)
		swatch.color = Palette.EMPIRE.get(r_id, Color.WHITE)
		row.add_child(swatch)

		# Text info
		var text_col := Ui.vbox(2)
		text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text_col)

		var name_lbl := Ui.label(Copy.t("race.%s.name" % r_id), "HeadingMedium")
		text_col.add_child(name_lbl)

		var pitch_lbl := Ui.label(Copy.t("race.%s.pitch" % r_id), "Muted")
		pitch_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_col.add_child(pitch_lbl)

		v.add_child(panel)

	return v

func _on_back() -> void:
	on_back()

func _on_start() -> void:
	var s: GameSettings = (GameSettings as Variant).call(&"new")
	s.preset = _selected_preset
	s.difficulty = _selected_difficulty
	s.player_race = _selected_race
	s.seat_swans = _seat_swans_chk.button_pressed
	var st: String = _seed_edit.text.strip_edges()
	if st.is_empty():
		st = "FOWL"
	s.seed_string = st
	s.seed = Rng.seed_from_string(st)

	Session.start_galaxy(s)
	if router != null:
		router.show_screen(&"galaxy")
