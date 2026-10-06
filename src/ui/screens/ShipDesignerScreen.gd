class_name ShipDesignerScreen
extends ScreenBase

var db: ContentDB = null
var state: GameState = null
var current_design: ShipDesign = null

# UI controls
var _name_edit: LineEdit = null
var _opt_role: OptionButton = null
var _opt_hull: OptionButton = null
var _opt_drive: OptionButton = null
var _opt_plate: OptionButton = null
var _opt_mantle: OptionButton = null
var _opt_computer: OptionButton = null

var _weapons_container: VBoxContainer = null
var _specials_container: VBoxContainer = null

var _space_bar: ProgressBar = null
var _space_lbl: Label = null

# Live stats labels
var _lbl_cost: Label = null
var _lbl_upkeep: Label = null
var _lbl_hp: Label = null
var _lbl_speed: Label = null
var _lbl_evasion: Label = null
var _lbl_capabilities: Label = null
var _lbl_exp_dmg: Label = null
var _lbl_error: Label = null

var _btn_save: Button = null
var _chk_obsolete: CheckBox = null
var _designs_list: VBoxContainer = null

# Temporary weapon and special edit buffers
var _weapons_buffer: Array[Dictionary] = []
var _specials_buffer: Array[String] = []

func build() -> void:
	db = Session.db
	state = Session.state

	var root := Ui.vbox(10)
	root.set_anchors_preset(PRESET_FULL_RECT)
	var margin := 16
	root.offset_left = margin
	root.offset_top = margin
	root.offset_right = -margin
	root.offset_bottom = -margin
	add_child(root)

	# Top bar
	var top := Ui.hbox(12)
	root.add_child(top)

	var btn_back := Ui.button("◄ Back", func() -> void:
		if router != null:
			router.back()
	)
	top.add_child(btn_back)

	var title := Ui.label("Ship Designer", "HeadingLarge")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)

	var btn_new := Ui.button("New Design", _new_blank_design)
	top.add_child(btn_new)

	# Main horizontal split: Left = existing designs & auto-design, Right = editor & stats
	var main_split := Ui.hbox(16)
	main_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main_split)

	# Left panel (280px)
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size.x = 280
	var lp_style := StyleBoxFlat.new()
	lp_style.bg_color = Palette.PANEL
	lp_style.border_color = Palette.LINE
	lp_style.set_content_margin_all(10)
	left_panel.add_theme_stylebox_override("panel", lp_style)
	main_split.add_child(left_panel)

	var left_v := Ui.vbox(10)
	left_panel.add_child(left_v)

	left_v.add_child(Ui.label("Auto-Design Role", "Heading"))
	var roles_grid := GridContainer.new()
	roles_grid.columns = 2
	left_v.add_child(roles_grid)

	var roles_to_show := ["glance", "talon_line", "beak_line", "horizon_line", "nest_ship", "stake_ship"]
	for r in roles_to_show:
		var r_name: String = Copy.t("role.%s.name" % r) if Copy.has("role.%s.name" % r) else r.capitalize()
		var btn_r := Ui.button(r_name, func() -> void: _apply_auto_design(r))
		btn_r.custom_minimum_size = Vector2(120, 28)
		roles_grid.add_child(btn_r)

	var div_l := ColorRect.new()
	div_l.custom_minimum_size = Vector2(0, 1)
	div_l.color = Palette.LINE
	left_v.add_child(div_l)

	left_v.add_child(Ui.label("Existing Designs", "Heading"))
	var des_scroll := ScrollContainer.new()
	des_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	des_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_v.add_child(des_scroll)

	_designs_list = Ui.vbox(4)
	_designs_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	des_scroll.add_child(_designs_list)

	# Right panel (Editor)
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rp_style := StyleBoxFlat.new()
	rp_style.bg_color = Palette.PANEL
	rp_style.border_color = Palette.LINE
	rp_style.set_content_margin_all(12)
	right_panel.add_theme_stylebox_override("panel", rp_style)
	main_split.add_child(right_panel)

	var editor_v := Ui.vbox(10)
	right_panel.add_child(editor_v)

	# Basic info: Name, Role, Hull
	var info_grid := GridContainer.new()
	info_grid.columns = 6
	editor_v.add_child(info_grid)

	info_grid.add_child(Ui.label("Name:", "Muted"))
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size.x = 160
	_name_edit.text_changed.connect(func(_t: String) -> void: _refresh_live_stats())
	info_grid.add_child(_name_edit)

	info_grid.add_child(Ui.label("Role:", "Muted"))
	_opt_role = OptionButton.new()
	for r in roles_to_show:
		var r_name: String = Copy.t("role.%s.name" % r) if Copy.has("role.%s.name" % r) else r.replace("_", " ").capitalize()
		_opt_role.add_item(r_name)
		_opt_role.set_item_metadata(_opt_role.item_count - 1, r)
	_opt_role.item_selected.connect(func(_i: int) -> void: _refresh_live_stats())
	info_grid.add_child(_opt_role)

	info_grid.add_child(Ui.label("Hull:", "Muted"))
	_opt_hull = OptionButton.new()
	var hulls_table: Dictionary = db.table("hulls").get("rows", {})
	for h_id in hulls_table.keys():
		var h_name: String = Copy.t("hull.%s.name" % h_id) if Copy.has("hull.%s.name" % h_id) else str(h_id).capitalize()
		_opt_hull.add_item(h_name)
		_opt_hull.set_item_metadata(_opt_hull.item_count - 1, h_id)
	_opt_hull.item_selected.connect(func(_i: int) -> void: _refresh_live_stats())
	info_grid.add_child(_opt_hull)

	# Core Slots: Drive, Plate, Mantle, Computer
	var slots_grid := GridContainer.new()
	slots_grid.columns = 4
	editor_v.add_child(slots_grid)

	slots_grid.add_child(Ui.label("Drive:", "Muted"))
	_opt_drive = OptionButton.new()
	_populate_category_options(_opt_drive, "drive", true)
	_opt_drive.item_selected.connect(func(_i: int) -> void: _refresh_live_stats())
	slots_grid.add_child(_opt_drive)

	slots_grid.add_child(Ui.label("Plate (Armor):", "Muted"))
	_opt_plate = OptionButton.new()
	_populate_category_options(_opt_plate, "plate", true)
	_opt_plate.item_selected.connect(func(_i: int) -> void: _refresh_live_stats())
	slots_grid.add_child(_opt_plate)

	slots_grid.add_child(Ui.label("Mantle (Shield):", "Muted"))
	_opt_mantle = OptionButton.new()
	_populate_category_options(_opt_mantle, "mantle", true)
	_opt_mantle.item_selected.connect(func(_i: int) -> void: _refresh_live_stats())
	slots_grid.add_child(_opt_mantle)

	slots_grid.add_child(Ui.label("Computer:", "Muted"))
	_opt_computer = OptionButton.new()
	_populate_category_options(_opt_computer, "computer", true)
	_opt_computer.item_selected.connect(func(_i: int) -> void: _refresh_live_stats())
	slots_grid.add_child(_opt_computer)

	# Weapons Section
	var wp_hdr := Ui.hbox(8)
	editor_v.add_child(wp_hdr)
	wp_hdr.add_child(Ui.label("Weapons", "Heading"))
	var btn_add_wp := Ui.button("+ Add Weapon", _on_add_weapon)
	wp_hdr.add_child(btn_add_wp)

	_weapons_container = Ui.vbox(4)
	editor_v.add_child(_weapons_container)

	# Specials Section
	editor_v.add_child(Ui.label("Specials", "Heading"))
	_specials_container = Ui.vbox(4)
	editor_v.add_child(_specials_container)
	_build_specials_list()

	# Space Bar
	var space_box := Ui.vbox(2)
	editor_v.add_child(space_box)

	var sb_hdr := Ui.hbox(8)
	space_box.add_child(sb_hdr)
	sb_hdr.add_child(Ui.label("Hull Space Capacity:", "Muted"))
	_space_lbl = Ui.label("0 / 0", "Heading")
	sb_hdr.add_child(_space_lbl)

	_space_bar = ProgressBar.new()
	_space_bar.custom_minimum_size.y = 18
	_space_bar.show_percentage = false
	space_box.add_child(_space_bar)

	# Live Stats Readout
	var stats_box := PanelContainer.new()
	var s_style := StyleBoxFlat.new()
	s_style.bg_color = Palette.PANEL_ALT
	s_style.set_content_margin_all(8)
	stats_box.add_theme_stylebox_override("panel", s_style)
	editor_v.add_child(stats_box)

	var stats_grid := GridContainer.new()
	stats_grid.columns = 6
	stats_box.add_child(stats_grid)

	stats_grid.add_child(Ui.label("Cost:", "Muted"))
	_lbl_cost = Ui.label("0 PP")
	stats_grid.add_child(_lbl_cost)

	stats_grid.add_child(Ui.label("Upkeep:", "Muted"))
	_lbl_upkeep = Ui.label("0 cr/turn")
	stats_grid.add_child(_lbl_upkeep)

	stats_grid.add_child(Ui.label("Hit Points:", "Muted"))
	_lbl_hp = Ui.label("0 HP")
	stats_grid.add_child(_lbl_hp)

	stats_grid.add_child(Ui.label("Speed:", "Muted"))
	_lbl_speed = Ui.label("0 pc/turn")
	stats_grid.add_child(_lbl_speed)

	stats_grid.add_child(Ui.label("Evasion:", "Muted"))
	_lbl_evasion = Ui.label("0%")
	stats_grid.add_child(_lbl_evasion)

	stats_grid.add_child(Ui.label("Special:", "Muted"))
	_lbl_capabilities = Ui.label("None", "Gold")
	stats_grid.add_child(_lbl_capabilities)

	var dmg_box := Ui.hbox(8)
	editor_v.add_child(dmg_box)
	dmg_box.add_child(Ui.label("Expected Dmg/Rnd (d=3, vs shld 0/2/4/6/9):", "Muted"))
	_lbl_exp_dmg = Ui.label("0 / 0 / 0 / 0 / 0")
	dmg_box.add_child(_lbl_exp_dmg)

	_lbl_error = Ui.label("", "Error")
	editor_v.add_child(_lbl_error)

	# Footer action bar
	var footer := Ui.hbox(12)
	editor_v.add_child(footer)

	_chk_obsolete = CheckBox.new()
	_chk_obsolete.text = "Mark Obsolete"
	footer.add_child(_chk_obsolete)

	var f_spacer := Control.new()
	f_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(f_spacer)

	_btn_save = Ui.button("Save Design", _on_save_design)
	_btn_save.custom_minimum_size = Vector2(140, 36)
	footer.add_child(_btn_save)

	_new_blank_design()
	_refresh_designs_list()

func _populate_category_options(opt: OptionButton, category: String, allow_none: bool) -> void:
	opt.clear()
	if allow_none:
		opt.add_item("None")
		opt.set_item_metadata(0, "")
	var parts_table: Dictionary = db.table("parts").get("rows", {})
	for p_id in parts_table.keys():
		var pdef: Dictionary = parts_table[p_id]
		if str(pdef.get("category", "")) == category:
			var p_name: String = Copy.t("part.%s.name" % p_id) if Copy.has("part.%s.name" % p_id) else str(p_id).capitalize()
			opt.add_item(p_name)
			opt.set_item_metadata(opt.item_count - 1, p_id)

func _build_specials_list() -> void:
	for c in _specials_container.get_children():
		c.queue_free()
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 4)
	_specials_container.add_child(flow)

	var parts_table: Dictionary = db.table("parts").get("rows", {})
	for p_id in parts_table.keys():
		var pdef: Dictionary = parts_table[p_id]
		if str(pdef.get("category", "")) == "special":
			var p_name: String = Copy.t("part.%s.name" % p_id) if Copy.has("part.%s.name" % p_id) else str(p_id).capitalize()
			var chk := CheckBox.new()
			chk.text = p_name
			chk.set_meta("part_id", p_id)
			chk.toggled.connect(func(pressed: bool) -> void:
				if pressed:
					if not _specials_buffer.has(p_id):
						_specials_buffer.append(p_id)
				else:
					_specials_buffer.erase(p_id)
				_refresh_live_stats()
			)
			flow.add_child(chk)

func _new_blank_design() -> void:
	current_design = ShipDesign.new()
	current_design.id = -1
	current_design.empire_id = 0
	current_design.name = "Custom Design"
	current_design.hull = "small"
	current_design.drive = "walk_drive"
	_weapons_buffer.clear()
	_specials_buffer.clear()
	_load_design_to_ui(current_design)

func _apply_auto_design(role: String) -> void:
	var best: ShipDesign = AutoDesign.design_for_role(db, state, 0, role)
	if best != null:
		best.id = -1
		current_design = best
		_load_design_to_ui(best)

func _load_design_to_ui(des: ShipDesign) -> void:
	_name_edit.text = des.name
	for i in range(_opt_role.item_count):
		if str(_opt_role.get_item_metadata(i)) == des.role or _opt_role.get_item_text(i) == des.role:
			_opt_role.select(i)
			break
	for i in range(_opt_hull.item_count):
		if str(_opt_hull.get_item_metadata(i)) == des.hull:
			_opt_hull.select(i)
			break
	_select_option_by_metadata(_opt_drive, des.drive)
	_select_option_by_metadata(_opt_plate, des.plate)
	_select_option_by_metadata(_opt_mantle, des.mantle)
	_select_option_by_metadata(_opt_computer, des.computer)

	_weapons_buffer = []
	for w in des.weapons:
		_weapons_buffer.append(w.duplicate())

	_specials_buffer = des.specials.duplicate()
	_chk_obsolete.button_pressed = des.obsolete

	# Update specials checkboxes
	if _specials_container.get_child_count() > 0:
		var flow: Container = _specials_container.get_child(0) as Container
		if flow != null:
			for c in flow.get_children():
				if c is CheckBox:
					var cb: CheckBox = c as CheckBox
					var p_id: String = str(cb.get_meta("part_id", ""))
					cb.button_pressed = _specials_buffer.has(p_id)

	_rebuild_weapons_ui()
	_refresh_live_stats()

func _select_option_by_metadata(opt: OptionButton, val: String) -> void:
	for i in range(opt.item_count):
		if str(opt.get_item_metadata(i)) == val:
			opt.select(i)
			return
	opt.select(0)

func _rebuild_weapons_ui() -> void:
	for c in _weapons_container.get_children():
		c.queue_free()

	for idx in range(_weapons_buffer.size()):
		var w_dict: Dictionary = _weapons_buffer[idx]
		var row := Ui.hbox(8)

		var opt_part := OptionButton.new()
		var parts_table: Dictionary = db.table("parts").get("rows", {})
		for p_id in parts_table.keys():
			var pdef: Dictionary = parts_table[p_id]
			if str(pdef.get("category", "")) == "weapon":
				var p_name: String = Copy.t("part.%s.name" % p_id) if Copy.has("part.%s.name" % p_id) else str(p_id).capitalize()
				opt_part.add_item(p_name)
				opt_part.set_item_metadata(opt_part.item_count - 1, p_id)
		_select_option_by_metadata(opt_part, str(w_dict.get("part", "")))
		opt_part.item_selected.connect(func(sel: int) -> void:
			w_dict["part"] = opt_part.get_item_metadata(sel)
			_refresh_live_stats()
		)
		row.add_child(opt_part)

		var opt_mount := OptionButton.new()
		opt_mount.add_item("Normal Mount")
		opt_mount.set_item_metadata(0, "")
		opt_mount.add_item("Swat Mount")
		opt_mount.set_item_metadata(1, "swat")
		opt_mount.add_item("Spinal Mount")
		opt_mount.set_item_metadata(2, "spinal")
		_select_option_by_metadata(opt_mount, str(w_dict.get("mount", "")))
		opt_mount.item_selected.connect(func(sel: int) -> void:
			w_dict["mount"] = opt_mount.get_item_metadata(sel)
			_refresh_live_stats()
		)
		row.add_child(opt_mount)

		row.add_child(Ui.label("Count:", "Muted"))
		var spin := SpinBox.new()
		spin.min_value = 1
		spin.max_value = 20
		spin.value = int(w_dict.get("count", 1))
		spin.value_changed.connect(func(val: float) -> void:
			w_dict["count"] = int(val)
			_refresh_live_stats()
		)
		row.add_child(spin)

		var btn_del := Ui.button("X", func() -> void:
			_weapons_buffer.remove_at(idx)
			_rebuild_weapons_ui()
			_refresh_live_stats()
		)
		btn_del.custom_minimum_size = Vector2(24, 24)
		row.add_child(btn_del)

		_weapons_container.add_child(row)

func _on_add_weapon() -> void:
	_weapons_buffer.append({"part": "wick_talon", "mount": "", "count": 1})
	_rebuild_weapons_ui()
	_refresh_live_stats()

func _create_design_from_ui() -> ShipDesign:
	var des := ShipDesign.new()
	des.id = current_design.id if current_design != null else -1
	des.empire_id = 0
	des.name = _name_edit.text.strip_edges()
	var sel_role: int = _opt_role.selected
	if sel_role >= 0 and sel_role < _opt_role.item_count:
		des.role = str(_opt_role.get_item_metadata(sel_role))
	else:
		des.role = "talon_line"
	des.hull = str(_opt_hull.get_item_metadata(_opt_hull.selected))
	des.drive = str(_opt_drive.get_item_metadata(_opt_drive.selected))
	des.plate = str(_opt_plate.get_item_metadata(_opt_plate.selected))
	des.mantle = str(_opt_mantle.get_item_metadata(_opt_mantle.selected))
	des.computer = str(_opt_computer.get_item_metadata(_opt_computer.selected))
	des.weapons = _weapons_buffer.duplicate(true)
	des.specials = _specials_buffer.duplicate()
	des.obsolete = _chk_obsolete.button_pressed
	return des

func _refresh_live_stats() -> void:
	if db == null or state == null:
		return
	var des: ShipDesign = _create_design_from_ui()
	var err: String = DesignRules.validate(db, state, des)

	var st: Dictionary = DesignRules.stats(db, state, des)
	var used_sp: int = int(st.get("space_used", 0))
	var max_sp: int = int(st.get("space_max", 24))
	_space_lbl.text = "%d / %d" % [used_sp, max_sp]
	_space_bar.max_value = max(1, max_sp)
	_space_bar.value = used_sp

	if used_sp > max_sp:
		_space_lbl.add_theme_color_override("font_color", Palette.DANGER)
		_space_bar.modulate = Palette.DANGER
	else:
		_space_lbl.remove_theme_color_override("font_color")
		_space_bar.modulate = Color.WHITE

	if err != "":
		_lbl_error.text = Copy.t(err) if Copy.has(err) else err
		_btn_save.disabled = true
	else:
		_lbl_error.text = ""
		_btn_save.disabled = false

	_lbl_cost.text = "%d PP" % int(st.get("cost_pp", 0))
	_lbl_upkeep.text = "%d cr/turn" % int(st.get("upkeep", 0))
	_lbl_hp.text = "%d HP" % int(st.get("hp", 0))
	_lbl_speed.text = "%d pc/turn" % int(st.get("map_speed", 2))
	_lbl_evasion.text = "%d%%" % int(st.get("evasion", 0))

	var caps: Array[String] = []
	if bool(st.get("colonize", false)):
		caps.append("Colonize")
	if bool(st.get("outpost", false)):
		caps.append("Outpost")
	if int(st.get("range_dpc", 0)) > 0:
		caps.append("+%d Range" % int(st["range_dpc"]))
	_lbl_capabilities.text = ", ".join(caps) if not caps.is_empty() else "None"

	if _lbl_exp_dmg != null:
		var d0: int = CombatMath.expected_damage(db, state, des, 3, 0, 5)
		var d2: int = CombatMath.expected_damage(db, state, des, 3, 2, 5)
		var d4: int = CombatMath.expected_damage(db, state, des, 3, 4, 5)
		var d6: int = CombatMath.expected_damage(db, state, des, 3, 6, 5)
		var d9: int = CombatMath.expected_damage(db, state, des, 3, 9, 5)
		_lbl_exp_dmg.text = "%d / %d / %d / %d / %d" % [d0, d2, d4, d6, d9]

func _refresh_designs_list() -> void:
	for c in _designs_list.get_children():
		c.queue_free()

	for d in state.designs.values():
		if d.empire_id == 0:
			var r_name: String = Copy.t("role.%s.name" % d.role) if Copy.has("role.%s.name" % d.role) else d.role.replace("_", " ").capitalize()
			var display_text: String = d.name
			if d.name.strip_edges().to_lower() != r_name.strip_edges().to_lower() and d.name.strip_edges().to_lower() != d.role.strip_edges().to_lower():
				display_text = "%s (%s)" % [d.name, r_name]
			var btn := Ui.button(display_text, func() -> void:
				current_design = d
				_load_design_to_ui(d)
			)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_designs_list.add_child(btn)

func _on_save_design() -> void:
	var des: ShipDesign = _create_design_from_ui()
	var cmd := CmdDesignSave.new()
	cmd.empire_id = 0
	cmd.design_data = des.to_dict()
	var err: String = Session.submit(cmd)
	if err == "":
		_refresh_designs_list()
		_refresh_live_stats()
	else:
		_lbl_error.text = Copy.t(err) if Copy.has(err) else err
