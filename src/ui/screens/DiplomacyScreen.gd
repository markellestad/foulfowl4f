class_name DiplomacyScreen
extends ScreenBase

const StatTooltipScript = preload("res://src/ui/kit/StatTooltip.gd")

var _v_list: VBoxContainer = null
var _budget_opt: OptionButton = null

func build() -> void:
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var v := Ui.vbox(16)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(v)

	# Header
	var header := Ui.hbox(16)
	v.add_child(header)

	var btn_back := Ui.button("<- " + Copy.t("ui.label.back"), _on_back_clicked)
	btn_back.custom_minimum_size = Vector2(100, 36)
	header.add_child(btn_back)

	var title := Ui.label("Diplomacy", "HeadingLarge")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	# Military Budget section
	var budget_box := Ui.hbox(8)
	var lbl_b := Ui.label("Military Budget:", "Muted")
	budget_box.add_child(lbl_b)

	_budget_opt = OptionButton.new()
	_budget_opt.add_item("Peace (10%)", 0)
	_budget_opt.add_item("Guarded (20%)", 1)
	_budget_opt.add_item("War (40%)", 2)
	_budget_opt.item_selected.connect(_on_budget_selected)
	budget_box.add_child(_budget_opt)
	header.add_child(budget_box)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)

	_v_list = Ui.vbox(12)
	_v_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_v_list)

	_refresh_data()

func _refresh_data() -> void:
	if Session.state == null or Session.db == null:
		return

	var gs: GameState = Session.state
	var db: ContentDB = Session.db
	var player_eid: int = Session.player_empire_id
	var player_emp: Empire = gs.empires[player_eid] if player_eid >= 0 and player_eid < gs.empires.size() else null

	if player_emp != null:
		match player_emp.military_budget:
			"peace": _budget_opt.selected = 0
			"guarded": _budget_opt.selected = 1
			"war": _budget_opt.selected = 2

	for c in _v_list.get_children():
		c.queue_free()

	var knw: Knowledge = gs.knowledge.get(player_eid, Knowledge.new())
	var met_keys: Array = knw.met.keys()
	met_keys.sort()

	if met_keys.is_empty():
		var empty_lbl := Ui.label("No other empires encountered yet.", "Muted")
		_v_list.add_child(empty_lbl)
		return

	for m in met_keys:
		var eid: int = int(m)
		if eid == player_eid or eid < 0 or eid >= gs.empires.size():
			continue

		var other_emp: Empire = gs.empires[eid]
		var rdef: Dictionary = db.def("races", other_emp.race)
		var race_name: String = str(rdef.get("name", other_emp.race.capitalize()))
		var personality_id: String = str(rdef.get("personality", ""))
		var pdef: Dictionary = db.def("personality", personality_id)
		var p_name: String = str(pdef.get("name", personality_id.capitalize()))

		var panel := PanelContainer.new()
		var p_style := StyleBoxFlat.new()
		p_style.bg_color = Palette.PANEL
		p_style.border_color = Palette.LINE
		p_style.set_border_width_all(1)
		p_style.set_content_margin_all(12)
		panel.add_theme_stylebox_override("panel", p_style)

		var row := Ui.hbox(16)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_child(row)

		# Empire Info
		var info_v := Ui.vbox(4)
		info_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_lbl := Ui.label("%s (%s)" % [race_name, p_name], "Heading")
		info_v.add_child(name_lbl)

		var status_str: String = "Peace"
		var status_col: Color = Palette.TEXT
		var is_war: bool = Wars.is_at_war(gs, player_eid, eid)
		var in_truce: bool = Wars.is_in_truce(gs, player_eid, eid)
		if is_war:
			status_str = "At War"
			status_col = Palette.DANGER
		elif in_truce:
			var remaining: int = Wars.truce_remaining(gs, player_eid, eid)
			status_str = "Truce (%d turns)" % remaining
			status_col = Palette.GOLD

		var status_lbl := Label.new()
		status_lbl.text = "Status: " + status_str
		status_lbl.add_theme_color_override("font_color", status_col)
		info_v.add_child(status_lbl)
		row.add_child(info_v)

		# Relation
		var rel_res: ModResult = Relations.value(db, gs, player_eid, eid)
		var rel_v := Ui.vbox(4)
		var rel_title := Ui.label("Relations", "Muted")
		var rel_val_lbl := Label.new()
		rel_val_lbl.text = ("+" if rel_res.value > 0 else "") + str(rel_res.value)
		if rel_res.value > 0:
			rel_val_lbl.add_theme_color_override("font_color", Palette.OK)
		elif rel_res.value < 0:
			rel_val_lbl.add_theme_color_override("font_color", Palette.DANGER)
		rel_v.add_child(rel_title)
		rel_v.add_child(rel_val_lbl)

		var breakdown_text: String = ""
		for line in rel_res.lines:
			var s_key: String = str(line.get("source_key", ""))
			var s_val: int = int(line.get("value", 0))
			var sign_s: String = "+" if s_val > 0 else ""
			breakdown_text += "%s: %s%d\n" % [s_key, sign_s, s_val]
		rel_val_lbl.tooltip_text = breakdown_text.strip_edges()
		row.add_child(rel_v)

		# Actions
		var act_v := Ui.hbox(8)
		var btn_war := Button.new()
		btn_war.text = "Declare War"
		var war_refuse: String = ""
		var dummy_cmd_w := CmdDeclareWar.new()
		dummy_cmd_w.empire_id = player_eid
		dummy_cmd_w.target_empire = eid
		war_refuse = dummy_cmd_w.validate(gs, db)
		if war_refuse != "":
			btn_war.disabled = true
			btn_war.tooltip_text = "Cannot declare war: " + war_refuse
		else:
			btn_war.pressed.connect(func(): _on_declare_war(eid))
		act_v.add_child(btn_war)

		var btn_peace := Button.new()
		btn_peace.text = "Propose Peace"
		var peace_refuse: String = ""
		var dummy_cmd_p := CmdProposePeace.new()
		dummy_cmd_p.empire_id = player_eid
		dummy_cmd_p.target_empire = eid
		peace_refuse = dummy_cmd_p.validate(gs, db)
		if peace_refuse != "":
			btn_peace.disabled = true
			btn_peace.tooltip_text = "Cannot propose peace: " + peace_refuse
		else:
			btn_peace.pressed.connect(func(): _on_propose_peace(eid))
		act_v.add_child(btn_peace)

		row.add_child(act_v)
		_v_list.add_child(panel)

func _on_budget_selected(idx: int) -> void:
	if Session.game == null:
		return
	var policy: String = "guarded"
	match idx:
		0: policy = "peace"
		1: policy = "guarded"
		2: policy = "war"
	var cmd := CmdSetMilitaryBudget.new()
	cmd.empire_id = Session.player_empire_id
	cmd.policy = policy
	Session.game.submit(cmd)

func _on_declare_war(target_eid: int) -> void:
	if Session.game == null:
		return
	var cmd := CmdDeclareWar.new()
	cmd.empire_id = Session.player_empire_id
	cmd.target_empire = target_eid
	Session.game.submit(cmd)
	_refresh_data()

func _on_propose_peace(target_eid: int) -> void:
	if Session.game == null:
		return
	var cmd := CmdProposePeace.new()
	cmd.empire_id = Session.player_empire_id
	cmd.target_empire = target_eid
	Session.game.submit(cmd)
	_refresh_data()

func _on_back_clicked() -> void:
	if router != null:
		router.back()
