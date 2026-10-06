class_name TurnSummaryScreen
extends ScreenBase

var report: TurnReport = null

func build() -> void:
	if params.has("report") and params["report"] is TurnReport:
		report = params["report"] as TurnReport
	elif Session.state != null:
		report = Session.state.report

	var bg := ColorRect.new()
	bg.color = Color(Palette.BG.r, Palette.BG.g, Palette.BG.b, 0.9)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 480)
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.PANEL
	style.border_color = Palette.LINE
	style.set_border_width_all(1)
	style.set_content_margin_all(20)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var v := Ui.vbox(12)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(v)

	var turn_num: int = report.turn if report != null else (Session.state.turn if Session.state != null else 1)
	var title_lbl := Ui.label("%s - %s %d" % [Copy.t("ui.label.turn_summary"), Copy.t("ui.label.turn"), turn_num], "HeadingLarge")
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title_lbl)

	var div1 := ColorRect.new()
	div1.color = Palette.LINE
	div1.custom_minimum_size = Vector2(0, 1)
	v.add_child(div1)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)

	var entries_box := Ui.vbox(10)
	entries_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(entries_box)

	if report == null or report.entries.is_empty():
		var empty_lbl := Ui.label("No new reports for this turn.", "Muted")
		entries_box.add_child(empty_lbl)
	else:
		_populate_entries(entries_box)

	var div2 := ColorRect.new()
	div2.color = Palette.LINE
	div2.custom_minimum_size = Vector2(0, 1)
	v.add_child(div2)

	var btn_row := Ui.hbox(8)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(btn_row)

	var btn_close := Ui.button(Copy.t("ui.label.close"), _on_close)
	btn_close.custom_minimum_size = Vector2(160, 36)
	btn_row.add_child(btn_close)

func _populate_entries(container: VBoxContainer) -> void:
	var grouped: Dictionary = {
		"production": [],
		"colony": [],
		"governor": [],
		"finance": [],
		"other": []
	}

	for entry in report.entries:
		var kind: String = str(entry.get("kind", "other"))
		if kind == "colonies":
			kind = "colony"
		if not grouped.has(kind):
			kind = "other"
		grouped[kind].append(entry)

	var kind_order: Array[String] = ["production", "colony", "governor", "finance", "other"]
	var kind_titles: Dictionary = {
		"production": Copy.t("ui.label.production"),
		"colony": Copy.t("ui.label.colonies"),
		"governor": Copy.t("ui.label.governor"),
		"finance": Copy.t("ui.label.finance"),
		"other": "General"
	}

	for k in kind_order:
		var list: Array = grouped[k]
		if list.is_empty():
			continue

		var k_lbl := Ui.label(str(kind_titles.get(k, k)), "Gold")
		container.add_child(k_lbl)

		for entry in list:
			var row := Ui.hbox(8)
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var key: String = str(entry.get("key", entry.get("text_key", "")))
			var p: Dictionary = entry.get("params", entry.get("args", {})) as Dictionary

			# Format params if needed (e.g. building name)
			var formatted_p: Dictionary = p.duplicate()
			if formatted_p.has("building"):
				var b_ref: String = str(formatted_p["building"])
				var b_key: String = "building." + b_ref + ".name"
				if Copy.has(b_key):
					formatted_p["building"] = Copy.t(b_key)
			if formatted_p.has("item"):
				var item_ref: String = str(formatted_p["item"])
				var b_key: String = "building." + item_ref + ".name"
				var f_key: String = "filler." + item_ref + ".name"
				if Copy.has(b_key):
					formatted_p["item"] = Copy.t(b_key)
				elif Copy.has(f_key):
					formatted_p["item"] = Copy.t(f_key)

			var t_kind: String = str(entry.get("target_kind", entry.get("target_type", "")))
			var t_id: int = int(entry.get("target_id", -1))

			if formatted_p.has("place") and Session.state != null and t_kind == "colony" and t_id >= 0 and Session.state.colonies.has(t_id):
				var c_target: Colony = Session.state.colonies[t_id]
				var pl_target: Planet = Session.state.planets[c_target.planet_id]
				var sys_target: StarSystem = Session.state.systems[pl_target.system_id]
				var s_name: String = ""
				if sys_target.is_orn:
					s_name = Copy.t("place.orn.name")
				elif sys_target.name_id > 0:
					s_name = Copy.t("star.name.%d" % sys_target.name_id)
				else:
					s_name = "Star %d" % sys_target.id
				formatted_p["place"] = "%s - Orbit %d" % [s_name, pl_target.orbit + 1]

			var msg: String = Copy.f(key, formatted_p, key)
			var lbl := Ui.label("• " + msg)
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(lbl)
			if t_kind == "colony" and t_id != -1:
				var btn_goto := Ui.button(Copy.t("ui.label.goto"), func() -> void:
					_goto_colony(t_id)
				)
				btn_goto.custom_minimum_size = Vector2(70, 24)
				row.add_child(btn_goto)

			container.add_child(row)

func _goto_colony(col_id: int) -> void:
	if Session.state == null or not Session.state.colonies.has(col_id):
		_on_close()
		return
	var col: Colony = Session.state.colonies[col_id]
	var planet: Planet = Session.state.planets[col.planet_id]
	if router != null:
		router.show_screen(&"galaxy", {"focus_system": planet.system_id, "open_colony": col_id})

func _on_close() -> void:
	on_back()

func on_back() -> void:
	if router != null:
		router.show_screen(&"galaxy")
