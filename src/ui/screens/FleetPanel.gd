class_name FleetPanel
extends PanelContainer

signal close_requested
signal move_mode_toggled(active: bool)

var db: ContentDB = null
var state: GameState = null
var current_fleet_id: int = -1
var is_move_mode: bool = false
var selected_ship_ids: Array[int] = []

var _title_lbl: Label = null
var _loc_lbl: Label = null
var _speed_lbl: Label = null
var _ships_container: VBoxContainer = null
var _btn_move: Button = null
var _btn_auto_explore: Button = null
var _btn_split: Button = null
var _btn_merge: Button = null
var _btn_colonize: Button = null
var _btn_outpost: Button = null
var _btn_bombard: Button = null
var _btn_invade: Button = null

# Battle Plan controls
var _opt_posture: OptionButton = null
var _opt_target: OptionButton = null
var _opt_swat: OptionButton = null
var _opt_retreat: OptionButton = null

func _ready() -> void:
	custom_minimum_size.x = 360.0
	_build_ui()

func setup(p_db: ContentDB, p_state: GameState) -> void:
	db = p_db
	state = p_state

func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.PANEL
	style.border_color = Palette.LINE
	style.border_width_left = 1
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)

	var root := Ui.vbox(8)
	add_child(root)

	# Header row
	var header := Ui.hbox(8)
	root.add_child(header)

	_title_lbl = Ui.label("Fleet", "HeadingMedium")
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_lbl)

	var btn_close := Ui.button("X", func() -> void:
		set_move_mode(false)
		close_requested.emit()
	)
	btn_close.custom_minimum_size = Vector2(28, 28)
	header.add_child(btn_close)

	_loc_lbl = Ui.label("", "Muted")
	root.add_child(_loc_lbl)

	_speed_lbl = Ui.label("", "Muted")
	root.add_child(_speed_lbl)

	var div1 := ColorRect.new()
	div1.custom_minimum_size = Vector2(0, 1)
	div1.color = Palette.LINE
	root.add_child(div1)

	# Action buttons row 1: Move & Auto-Explore
	var act_row1 := Ui.hbox(6)
	root.add_child(act_row1)

	_btn_move = Ui.button("Move", _on_move_clicked)
	_btn_move.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	act_row1.add_child(_btn_move)

	_btn_auto_explore = Ui.button("Auto-Explore", _on_auto_explore_clicked)
	_btn_auto_explore.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	act_row1.add_child(_btn_auto_explore)

	# Action buttons row 2: Colonize / Outpost
	var act_row2 := Ui.hbox(6)
	root.add_child(act_row2)

	_btn_colonize = Ui.button("Colonize", _on_colonize_clicked)
	_btn_colonize.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	act_row2.add_child(_btn_colonize)

	_btn_outpost = Ui.button("Outpost", _on_outpost_clicked)
	_btn_outpost.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	act_row2.add_child(_btn_outpost)

	# Action buttons row 3: Split & Merge
	var act_row3 := Ui.hbox(6)
	root.add_child(act_row3)

	_btn_split = Ui.button("Split Selected", _on_split_clicked)
	_btn_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	act_row3.add_child(_btn_split)

	_btn_merge = Ui.button("Merge Fleets", _on_merge_clicked)
	_btn_merge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	act_row3.add_child(_btn_merge)

	# Action buttons row 4: Bombard & Invade
	var act_row4 := Ui.hbox(6)
	root.add_child(act_row4)

	_btn_bombard = Ui.button("Bombard", _on_bombard_clicked)
	_btn_bombard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	act_row4.add_child(_btn_bombard)

	_btn_invade = Ui.button("Invade", _on_invade_clicked)
	_btn_invade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	act_row4.add_child(_btn_invade)

	var div2 := ColorRect.new()
	div2.custom_minimum_size = Vector2(0, 1)
	div2.color = Palette.LINE
	root.add_child(div2)

	# Ships list header
	var ships_hdr := Ui.hbox(4)
	root.add_child(ships_hdr)
	ships_hdr.add_child(Ui.label("Ships", "Heading"))

	var btn_up := Ui.button("▲", _on_move_ship_up, "Move selected ship forward in battle line")
	btn_up.custom_minimum_size = Vector2(28, 24)
	ships_hdr.add_child(btn_up)

	var btn_down := Ui.button("▼", _on_move_ship_down, "Move selected ship back in battle line")
	btn_down.custom_minimum_size = Vector2(28, 24)
	ships_hdr.add_child(btn_down)

	# Scrollable ships list
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 140)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_ships_container = Ui.vbox(4)
	_ships_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_ships_container)

	var div3 := ColorRect.new()
	div3.custom_minimum_size = Vector2(0, 1)
	div3.color = Palette.LINE
	root.add_child(div3)

	# Battle Plan dropdowns
	root.add_child(Ui.label("Battle Plan", "Heading"))
	var bp_grid := GridContainer.new()
	bp_grid.columns = 2
	root.add_child(bp_grid)

	bp_grid.add_child(Ui.label("Posture:", "Muted"))
	_opt_posture = OptionButton.new()
	var postures := ["auto", "close", "talon", "standoff", "retreat"]
	var posture_tips := {
		"auto": "Adjusts target distance to match the weapons and ammo of the fleet.",
		"close": "Close to distance 0 for Beak range weapons.",
		"talon": "Hold Talon range (distance 5) for beam weapons.",
		"standoff": "Stand off at distance 12 for Horizon missiles.",
		"retreat": "Escape combat at distance 12 after paying the retreat receipt."
	}
	for i in range(postures.size()):
		var p: String = postures[i]
		_opt_posture.add_item(Copy.t("battle.orders.posture." + p), i)
		_opt_posture.set_item_tooltip(i, posture_tips[p])
	_opt_posture.item_selected.connect(_on_battle_plan_changed)
	bp_grid.add_child(_opt_posture)

	bp_grid.add_child(Ui.label("Target:", "Muted"))
	_opt_target = OptionButton.new()
	_opt_target.add_item("Nearest", 0)
	_opt_target.add_item("Weakest", 1)
	_opt_target.add_item("Strongest", 2)
	_opt_target.item_selected.connect(_on_battle_plan_changed)
	bp_grid.add_child(_opt_target)

	var swat_lbl := Ui.label("Swat:", "Muted")
	swat_lbl.tooltip_text = "Swat Priority: Determines whether Swat mounts intercept incoming missiles or fire at enemy ships."
	bp_grid.add_child(swat_lbl)
	_opt_swat = OptionButton.new()
	_opt_swat.add_item("Missiles", 0)
	_opt_swat.add_item("Ships", 1)
	_opt_swat.tooltip_text = Copy.t("ui.fleet.swat_options.tip")
	_opt_swat.item_selected.connect(_on_battle_plan_changed)
	bp_grid.add_child(_opt_swat)

	bp_grid.add_child(Ui.label("Retreat:", "Muted"))
	_opt_retreat = OptionButton.new()
	_opt_retreat.add_item("Never", 0)
	_opt_retreat.add_item("Half", 1)
	_opt_retreat.add_item("Even", 2)
	_opt_retreat.item_selected.connect(_on_battle_plan_changed)
	bp_grid.add_child(_opt_retreat)

func show_fleet(f_id: int) -> void:
	current_fleet_id = f_id
	selected_ship_ids.clear()
	refresh()

func refresh() -> void:
	if state == null or not state.fleets.has(current_fleet_id):
		visible = false
		return

	visible = true
	var flt: Fleet = state.fleets[current_fleet_id]
	_title_lbl.text = "%s (%d ships)" % [flt.get_display_name(), flt.ship_ids.size()]

	# Location text
	if flt.system_id >= 0 and flt.system_id < state.systems.size():
		var sys: StarSystem = state.systems[flt.system_id]
		var s_name: String = Copy.system_name(sys)
		_loc_lbl.text = Copy.t("ui.fleet.location") % s_name
	elif flt.dest_system_id >= 0 and flt.dest_system_id < state.systems.size():
		var d_sys: StarSystem = state.systems[flt.dest_system_id]
		var eta: int = max(1, flt.arrive_turn - state.turn)
		_loc_lbl.text = Copy.t("ui.fleet.in_transit") % [d_sys.id, eta]
	else:
		_loc_lbl.text = Copy.t("ui.fleet.deep_space")

	var spd: int = Movement.fleet_map_speed(db, state, flt.id)
	_speed_lbl.text = Copy.t("ui.fleet.speed") % spd

	# Move button state
	if is_move_mode:
		_btn_move.text = Copy.t("ui.label.cancel_move")
	else:
		_btn_move.text = "Move"

	# Auto-explore button state
	if flt.auto_explore:
		_btn_auto_explore.text = Copy.t("ui.fleet.auto_explore_on")
	else:
		_btn_auto_explore.text = Copy.t("ui.fleet.auto_explore_off")

	# Colonize and Outpost target discovery
	var target_sys_id: int = flt.system_id if flt.system_id >= 0 else flt.dest_system_id
	var can_col_pid: int = -1
	var can_out_pid: int = -1
	if target_sys_id >= 0 and target_sys_id < state.systems.size():
		var target_sys: StarSystem = state.systems[target_sys_id]
		for pid in target_sys.planet_ids:
			if can_col_pid == -1 and Colonization.can_colonize(db, state, flt.id, pid) == "":
				can_col_pid = pid
			if can_out_pid == -1 and Colonization.can_outpost(db, state, flt.id, pid) == "":
				can_out_pid = pid

	_btn_colonize.disabled = (can_col_pid == -1)
	_btn_outpost.disabled = (can_out_pid == -1)
	_btn_colonize.tooltip_text = Copy.t("ui.fleet.colonize.tip") if can_col_pid != -1 else Copy.t("ui.fleet.colonize.none_tip")
	_btn_outpost.tooltip_text = Copy.t("ui.fleet.outpost.tip") if can_out_pid != -1 else Copy.t("ui.fleet.outpost.none_tip")

	# Split & Merge buttons
	_btn_split.disabled = (selected_ship_ids.is_empty() or selected_ship_ids.size() >= flt.ship_ids.size() or flt.system_id == -1)
	var can_merge: bool = false
	if flt.system_id >= 0:
		for of in state.fleets.values():
			if of.id != flt.id and of.owner == flt.owner and of.system_id == flt.system_id:
				can_merge = true
				break
	_btn_merge.disabled = not can_merge

	# Rebuild ships list
	for c in _ships_container.get_children():
		c.queue_free()

	for sid in flt.ship_ids:
		var s: Ship = state.ships.get(sid)
		if s == null:
			continue
		var des: ShipDesign = state.designs.get(s.design_id)
		var des_name: String = des.name if des != null else "Ship"
		var st: Dictionary = DesignRules.stats(db, state, des) if des != null else {}
		var max_hp: int = int(st.get("hp", 10))

		var row := Ui.hbox(6)
		var chk := CheckBox.new()
		chk.button_pressed = selected_ship_ids.has(sid)
		chk.toggled.connect(func(pressed: bool) -> void:
			if pressed:
				if not selected_ship_ids.has(sid):
					selected_ship_ids.append(sid)
			else:
				selected_ship_ids.erase(sid)
			_btn_split.disabled = (selected_ship_ids.is_empty() or selected_ship_ids.size() >= flt.ship_ids.size() or flt.system_id == -1)
		)
		row.add_child(chk)

		var lbl_name := Ui.label("%s" % des_name)
		lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl_name)

		var lbl_hp := Ui.label("HP: %d/%d" % [s.hp, max_hp], "Muted")
		row.add_child(lbl_hp)

		_ships_container.add_child(row)

	# Battle plan values
	if flt.plan != null:
		var bp: BattlePlan = flt.plan
		var postures := ["auto", "close", "talon", "standoff", "retreat"]
		var p_idx: int = postures.find(bp.posture)
		_opt_posture.select(p_idx if p_idx >= 0 else 0)
		match bp.target_priority:
			"nearest": _opt_target.select(0)
			"weakest": _opt_target.select(1)
			"strongest": _opt_target.select(2)
		_opt_swat.select(0 if bp.swat_mode == "missiles" else 1)
		match bp.retreat_threshold:
			"never": _opt_retreat.select(0)
			"half": _opt_retreat.select(1)
			"even": _opt_retreat.select(2)

func set_move_mode(active: bool) -> void:
	is_move_mode = active
	_btn_move.text = Copy.t("ui.label.cancel_move") if is_move_mode else "Move"
	move_mode_toggled.emit(is_move_mode)

func _on_move_clicked() -> void:
	set_move_mode(not is_move_mode)

func _on_auto_explore_clicked() -> void:
	if state == null or not state.fleets.has(current_fleet_id):
		return
	var flt: Fleet = state.fleets[current_fleet_id]
	var cmd := CmdFleetAutoExplore.new()
	cmd.empire_id = flt.owner
	cmd.fleet_id = flt.id
	cmd.on = not flt.auto_explore
	Session.submit(cmd)
	refresh()

func _on_split_clicked() -> void:
	if state == null or not state.fleets.has(current_fleet_id):
		return
	var flt: Fleet = state.fleets[current_fleet_id]
	var cmd := CmdFleetSplit.new()
	cmd.empire_id = flt.owner
	cmd.fleet_id = flt.id
	cmd.ship_ids = selected_ship_ids.duplicate()
	Session.submit(cmd)
	selected_ship_ids.clear()
	refresh()

func _on_merge_clicked() -> void:
	if state == null or not state.fleets.has(current_fleet_id):
		return
	var flt: Fleet = state.fleets[current_fleet_id]
	var other_id: int = -1
	for of in state.fleets.values():
		if of.id != flt.id and of.owner == flt.owner and of.system_id == flt.system_id:
			other_id = of.id
			break
	if other_id != -1:
		var cmd := CmdFleetMerge.new()
		cmd.empire_id = flt.owner
		cmd.fleet_id = flt.id
		cmd.other_id = other_id
		Session.submit(cmd)
		refresh()

func _on_colonize_clicked() -> void:
	if state == null or not state.fleets.has(current_fleet_id):
		return
	var flt: Fleet = state.fleets[current_fleet_id]
	var target_sys_id: int = flt.system_id if flt.system_id >= 0 else flt.dest_system_id
	if target_sys_id < 0 or target_sys_id >= state.systems.size():
		return
	var target_sys: StarSystem = state.systems[target_sys_id]
	for pid in target_sys.planet_ids:
		if Colonization.can_colonize(db, state, flt.id, pid) == "":
			var cmd := CmdColonize.new()
			cmd.empire_id = flt.owner
			cmd.fleet_id = flt.id
			cmd.planet_id = pid
			Session.submit(cmd)
			refresh()
			break

func _on_outpost_clicked() -> void:
	if state == null or not state.fleets.has(current_fleet_id):
		return
	var flt: Fleet = state.fleets[current_fleet_id]
	var target_sys_id: int = flt.system_id if flt.system_id >= 0 else flt.dest_system_id
	if target_sys_id < 0 or target_sys_id >= state.systems.size():
		return
	var target_sys: StarSystem = state.systems[target_sys_id]
	for pid in target_sys.planet_ids:
		if Colonization.can_outpost(db, state, flt.id, pid) == "":
			var cmd := CmdOutpost.new()
			cmd.empire_id = flt.owner
			cmd.fleet_id = flt.id
			cmd.planet_id = pid
			Session.submit(cmd)
			refresh()
			break

func _on_bombard_clicked() -> void:
	if state == null or not state.fleets.has(current_fleet_id):
		return
	var flt: Fleet = state.fleets[current_fleet_id]
	var cmd := CmdFleetBombard.new()
	cmd.empire_id = flt.owner
	cmd.fleet_id = flt.id
	Session.submit(cmd)
	refresh()

func _on_invade_clicked() -> void:
	if state == null or not state.fleets.has(current_fleet_id):
		return
	var flt: Fleet = state.fleets[current_fleet_id]
	var target_sys_id: int = flt.system_id if flt.system_id >= 0 else flt.dest_system_id
	if target_sys_id < 0 or target_sys_id >= state.systems.size():
		return
	var target_sys: StarSystem = state.systems[target_sys_id]
	for pid in target_sys.planet_ids:
		for col in state.colonies.values():
			if col.planet_id == pid and Wars.is_at_war(state, flt.owner, col.owner):
				var cmd := CmdFleetInvade.new()
				cmd.empire_id = flt.owner
				cmd.fleet_id = flt.id
				cmd.colony_id = col.id
				Session.submit(cmd)
				refresh()
				return

func _on_move_ship_up() -> void:
	_shift_selected_ship(-1)

func _on_move_ship_down() -> void:
	_shift_selected_ship(1)

func _shift_selected_ship(dir: int) -> void:
	if selected_ship_ids.size() != 1 or state == null or not state.fleets.has(current_fleet_id):
		return
	var flt: Fleet = state.fleets[current_fleet_id]
	var sid: int = selected_ship_ids[0]
	var idx: int = flt.ship_ids.find(sid)
	if idx == -1:
		return
	var new_idx: int = idx + dir
	if new_idx >= 0 and new_idx < flt.ship_ids.size():
		var new_order: Array[int] = flt.ship_ids.duplicate()
		new_order.remove_at(idx)
		new_order.insert(new_idx, sid)
		var cmd := CmdSetLineOrder.new()
		cmd.empire_id = flt.owner
		cmd.fleet_id = flt.id
		cmd.ship_ids = new_order
		Session.submit(cmd)
		refresh()

func _on_battle_plan_changed(_idx: int) -> void:
	if state == null or not state.fleets.has(current_fleet_id):
		return
	var flt: Fleet = state.fleets[current_fleet_id]
	var cmd := CmdSetBattlePlan.new()
	cmd.empire_id = flt.owner
	cmd.fleet_id = flt.id
	var postures := ["auto", "close", "talon", "standoff", "retreat"]
	var p_sel: int = _opt_posture.selected
	cmd.posture = postures[p_sel] if (p_sel >= 0 and p_sel < postures.size()) else "auto"
	match _opt_target.selected:
		0: cmd.target_priority = "nearest"
		1: cmd.target_priority = "weakest"
		2: cmd.target_priority = "strongest"
	cmd.swat_mode = "missiles" if _opt_swat.selected == 0 else "ships"
	match _opt_retreat.selected:
		0: cmd.retreat_threshold = "never"
		1: cmd.retreat_threshold = "half"
		2: cmd.retreat_threshold = "even"
	Session.submit(cmd)
