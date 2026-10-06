class_name StatTooltip
extends PanelContainer

static func format_source(src: String) -> String:
	if src.is_empty():
		return Copy.t("ui.mod.base") if Copy.has("ui.mod.base") else "Base"
	var keys: Array[String] = [
		"ui.mod." + src,
		"building." + src + ".name",
		"trait." + src + ".name",
		"ui.preset." + src,
		"ui.label." + src,
	]
	for k in keys:
		if Copy.has(k):
			return Copy.t(k)
	var cap: String = src.replace("_", " ").capitalize()
	return cap if not cap.is_empty() else "Base"

static func format_line(line: Dictionary) -> String:
	var op: String = str(line.get("op", "add"))
	var val: int = int(line.get("value", 0))
	match op:
		"base":
			return "Base %d" % val
		"floor":
			return "Floor %d" % val
		"cap":
			return "Cap %d" % val
		"add":
			return "+%d" % val if val >= 0 else "%d" % val
		"pct":
			return "+%d%%" % val if val >= 0 else "%d%%" % val
		"min":
			return "Min %d" % val
		_:
			return str(val)

static func build(title: String, mod_res: ModResult) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.PANEL_ALT
	style.border_color = Palette.LINE
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var v := Ui.vbox(4)
	panel.add_child(v)

	var title_lbl := Ui.label(title, "Gold")
	v.add_child(title_lbl)

	var div1 := ColorRect.new()
	div1.color = Palette.LINE
	div1.custom_minimum_size = Vector2(0, 1)
	v.add_child(div1)

	if mod_res != null:
		for l in mod_res.lines:
			var row := Ui.hbox(12)
			var raw_src: String = str(l.get("source_key", l.get("source", "")))
			var src_name: String = format_source(raw_src)
			var val_str: String = format_line(l)

			var l_src := Ui.label(src_name)
			l_src.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l_src)

			var l_val := Ui.label(val_str, "Muted")
			row.add_child(l_val)
			v.add_child(row)

		var div2 := ColorRect.new()
		div2.color = Palette.LINE
		div2.custom_minimum_size = Vector2(0, 1)
		v.add_child(div2)

		var total_row := Ui.hbox(12)
		var l_total := Ui.label("Total")
		l_total.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		total_row.add_child(l_total)

		var l_tot_val := Ui.label(str(mod_res.value), "Gold")
		total_row.add_child(l_tot_val)
		v.add_child(total_row)

	return panel

static func text_for(title: String, mod_res: ModResult) -> String:
	if mod_res == null:
		return title
	var lines: Array[String] = [title, "----------------"]
	for l in mod_res.lines:
		var raw_src: String = str(l.get("source_key", l.get("source", "")))
		var src_name: String = format_source(raw_src)
		var val_str: String = format_line(l)
		lines.append("%s: %s" % [src_name, val_str])
	lines.append("----------------")
	lines.append("Total: %d" % mod_res.value)
	return "\n".join(lines)
