class_name MainMenu
extends ScreenBase

var _music_started: bool = false
var _quit_dialog: ConfirmationDialog = null

func build() -> void:
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)

	var col := Ui.vbox(12)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)

	var title_lbl := Ui.label(Copy.t("menu.title"), "HeadingLarge")
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title_lbl)

	var splash_idx: int = int(params.get("splash_index", 3))
	if not params.has("splash_index"):
		splash_idx = (Time.get_ticks_msec() % 3) + 1
	var splash_key: String = "menu.splash.%d" % splash_idx
	var splash_lbl := Ui.label(Copy.t(splash_key), "Gold")
	splash_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(splash_lbl)

	var tag1 := Ui.label(Copy.t("menu.tagline"))
	tag1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tag1)

	var tag2 := Ui.label(Copy.t("menu.tagline2"), "Muted")
	tag2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tag2)

	col.add_child(Ui.spacer(16))

	var btn_col := Ui.vbox(10)
	btn_col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(btn_col)

	var btn_new := Ui.button(Copy.t("ui.label.new_game"), _on_new_game, "Coming in P01")
	btn_new.disabled = true
	btn_new.custom_minimum_size = Vector2(240, 36)
	btn_col.add_child(btn_new)

	var btn_cont := Ui.button(Copy.t("ui.label.continue"), _on_continue, Copy.t("ui.label.coming_soon"))
	btn_cont.disabled = true
	btn_cont.custom_minimum_size = Vector2(240, 36)
	btn_col.add_child(btn_cont)

	var btn_settings := Ui.button(Copy.t("ui.label.settings"), _on_settings, Copy.t("ui.label.coming_soon"))
	btn_settings.disabled = true
	btn_settings.custom_minimum_size = Vector2(240, 36)
	btn_col.add_child(btn_settings)

	var btn_credits := Ui.button(Copy.t("ui.label.credits"), _on_credits)
	btn_credits.custom_minimum_size = Vector2(240, 36)
	btn_col.add_child(btn_credits)

	var btn_quit := Ui.button(Copy.t("ui.label.quit"), _on_quit)
	btn_quit.custom_minimum_size = Vector2(240, 36)
	if OS.has_feature("web"):
		btn_quit.visible = false
	btn_col.add_child(btn_quit)

func _start_music_if_needed() -> void:
	if not _music_started:
		_music_started = true
		Sfx.music("music_menu")

func _on_new_game() -> void:
	_start_music_if_needed()

func _on_continue() -> void:
	_start_music_if_needed()

func _on_settings() -> void:
	_start_music_if_needed()

func _on_credits() -> void:
	_start_music_if_needed()
	if router != null:
		router.show_screen(&"credits")

func _on_quit() -> void:
	_start_music_if_needed()
	if _quit_dialog == null:
		_quit_dialog = ConfirmationDialog.new()
		_quit_dialog.title = Copy.t("ui.label.quit")
		_quit_dialog.dialog_text = Copy.t("menu.quit_confirm")
		_quit_dialog.confirmed.connect(func() -> void:
			get_tree().quit(0)
		)
		add_child(_quit_dialog)
	_quit_dialog.popup_centered()
