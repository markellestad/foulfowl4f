class_name CreditsScreen
extends ScreenBase

func build() -> void:
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(800, 600)
	center.add_child(scroll)

	var col := Ui.vbox(10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll.add_child(col)

	var title_lbl := Ui.label(Copy.t("ui.label.credits"), "HeadingLarge")
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title_lbl)

	col.add_child(Ui.spacer(8))

	var c1 := Ui.label(Copy.t("credits.1"), "Heading")
	c1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(c1)

	var c2 := Ui.label(Copy.t("credits.2"), "Muted")
	c2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(c2)

	col.add_child(Ui.spacer(12))

	var errs: Array[String] = []
	var credits_data: Variant = DefLoader.load_json("res://data/credits.json", errs)
	if credits_data != null and typeof(credits_data) == TYPE_DICTIONARY:
		var d: Dictionary = credits_data as Dictionary
		if d.has("sections") and typeof(d["sections"]) == TYPE_ARRAY:
			for sec in d["sections"]:
				if typeof(sec) == TYPE_DICTIONARY and (sec as Dictionary).has("lines"):
					for line in (sec as Dictionary)["lines"]:
						var line_lbl := Ui.label(str(line))
						line_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
						col.add_child(line_lbl)
					col.add_child(Ui.spacer(6))

		if Sfx.licensed_count() > 0 and d.has("licensed_vendors") and typeof(d["licensed_vendors"]) == TYPE_ARRAY:
			var lic_heading := Ui.label("Licensed Audio Packs", "Heading")
			lic_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(lic_heading)
			for vendor in d["licensed_vendors"]:
				if typeof(vendor) == TYPE_DICTIONARY:
					var p_str: String = str((vendor as Dictionary).get("pack", ""))
					var v_str: String = str((vendor as Dictionary).get("vendor", ""))
					var v_lbl := Ui.label("%s — %s" % [p_str, v_str], "Muted")
					v_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					col.add_child(v_lbl)
			col.add_child(Ui.spacer(6))

	col.add_child(Ui.spacer(16))

	var back_btn := Ui.button(Copy.t("ui.label.back"), func() -> void:
		on_back()
	)
	back_btn.custom_minimum_size = Vector2(200, 36)
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(back_btn)
