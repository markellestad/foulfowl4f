class_name BattleOrdersCard
extends ScreenBase

signal orders_submitted(cmds: Array)

var requests: Array = []
var auto_systems: Array = []
var card_controls: Array[Dictionary] = []

func setup(p: Dictionary) -> void:
	super.setup(p)
	requests = p.get("requests", [])
	auto_systems = p.get("auto", [])

func build() -> void:
	# Full screen semi-transparent background
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.08, 0.95)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 16)
	main_vbox.offset_left = 30
	main_vbox.offset_top = 20
	main_vbox.offset_right = -30
	main_vbox.offset_bottom = -20
	add_child(main_vbox)

	var title := Label.new()
	title.text = "BATTLE ORDERS"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	var cards_hbox := HBoxContainer.new()
	cards_hbox.add_theme_constant_override("separation", 20)
	scroll.add_child(cards_hbox)

	card_controls.clear()

	# Up to 3 cards (fixed 380px each)
	for req in requests:
		var card_dict := _create_card(req)
		cards_hbox.add_child(card_dict["panel"])
		card_controls.append(card_dict)

	# Auto list if any
	if not auto_systems.is_empty():
		var auto_panel := _create_auto_panel(auto_systems)
		cards_hbox.add_child(auto_panel)

	# Bottom action bar
	var bottom_bar := HBoxContainer.new()
	bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(bottom_bar)

	var accept_all_btn := Button.new()
	accept_all_btn.text = "Accept All Orders (Enter)"
	accept_all_btn.custom_minimum_size = Vector2(240, 42)
	accept_all_btn.pressed.connect(_on_accept_all)
	bottom_bar.add_child(accept_all_btn)

func _create_card(req: Dictionary) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 520)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var sys_id: int = int(req.get("system_id", 0))
	var sys_lbl := Label.new()
	sys_lbl.text = "SYSTEM %d" % sys_id
	sys_lbl.add_theme_font_size_override("font_size", 18)
	vbox.add_child(sys_lbl)

	# Enemy intel
	var enemy_vis: Dictionary = req.get("enemy_visible", {})
	var intel_text: String = "Enemy force: Unknown"
	if not enemy_vis.is_empty():
		var hulls_str: Array = []
		for h_key in enemy_vis.keys():
			hulls_str.append("%s: %d" % [h_key, int(enemy_vis[h_key])])
		intel_text = "Enemy: " + ", ".join(hulls_str)
	var intel_lbl := Label.new()
	intel_lbl.text = intel_text
	vbox.add_child(intel_lbl)

	# Odds
	var odds_pct: int = int(req.get("odds_pct", 50))
	var odds_lbl := Label.new()
	odds_lbl.text = "Estimated Odds: %d%%" % odds_pct
	vbox.add_child(odds_lbl)

	# Projection line
	var proj: Dictionary = req.get("projection", {})
	var talon_r: int = int(proj.get("talon_round", 1))
	var beak_r: int = int(proj.get("beak_round", 1))
	var proj_lbl := Label.new()
	proj_lbl.text = "Projection: Talon by round %d, Beak by %d" % [talon_r, beak_r]
	vbox.add_child(proj_lbl)

	vbox.add_child(HSeparator.new())

	# Five orders as dropdowns
	var plan: Dictionary = req.get("plan", {})

	# 1. Posture
	vbox.add_child(Ui.label("Battle Posture:"))
	var posture_opt := OptionButton.new()
	var postures := ["auto", "close", "talon", "standoff", "retreat"]
	for p in postures:
		posture_opt.add_item(p.capitalize())
	var cur_posture: String = str(plan.get("posture", "auto")).to_lower()
	var p_idx: int = postures.find(cur_posture)
	if p_idx >= 0: posture_opt.selected = p_idx
	vbox.add_child(posture_opt)

	# 2. Target priority
	vbox.add_child(Ui.label("Target Priority:"))
	var prio_opt := OptionButton.new()
	var priorities := ["auto", "biggest", "swat", "band_talon", "band_beak", "band_horizon", "defenses", "transports"]
	for pr in priorities:
		prio_opt.add_item(pr.replace("_", " ").capitalize())
	var cur_prio: String = str(plan.get("target_priority", "auto")).to_lower()
	var prio_idx: int = priorities.find(cur_prio)
	if prio_idx >= 0: prio_opt.selected = prio_idx
	vbox.add_child(prio_opt)

	# 3. Swat mode
	vbox.add_child(Ui.label("Swat Escort Mode:"))
	var swat_opt := OptionButton.new()
	var swat_modes := ["missiles_first", "ships_first"]
	swat_opt.add_item("Missiles First (Intercept)")
	swat_opt.add_item("Ships First (Fire at Line)")
	var cur_swat: String = str(plan.get("swat_mode", "missiles_first")).to_lower()
	var swat_idx: int = swat_modes.find(cur_swat)
	if swat_idx >= 0: swat_opt.selected = swat_idx
	vbox.add_child(swat_opt)

	# 4. Retreat threshold
	vbox.add_child(Ui.label("Retreat Threshold:"))
	var ret_opt := OptionButton.new()
	var ret_thresh := ["never", "half", "even"]
	ret_opt.add_item("Never Retreat")
	ret_opt.add_item("Half (< 50% Odds)")
	ret_opt.add_item("Even (< 100% Odds)")
	var cur_ret: String = str(plan.get("retreat_threshold", "never")).to_lower()
	var ret_idx: int = ret_thresh.find(cur_ret)
	if ret_idx >= 0: ret_opt.selected = ret_idx
	vbox.add_child(ret_opt)

	# Accept button per card
	var accept_card_btn := Button.new()
	accept_card_btn.text = "Accept This Card"
	vbox.add_child(accept_card_btn)

	var card_dict := {
		"panel": panel,
		"system_id": sys_id,
		"posture_opt": posture_opt,
		"postures": postures,
		"prio_opt": prio_opt,
		"priorities": priorities,
		"swat_opt": swat_opt,
		"swat_modes": swat_modes,
		"ret_opt": ret_opt,
		"ret_thresh": ret_thresh,
		"accept_btn": accept_card_btn
	}

	accept_card_btn.pressed.connect(func():
		accept_card_btn.text = "Accepted ✓"
		accept_card_btn.disabled = true
	)

	return card_dict

func _create_auto_panel(autos: Array) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(240, 520)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "AUTOMATED BATTLES"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "These skirmishes use standing battle plans:"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	for sys_id in autos:
		var lbl := Label.new()
		lbl.text = "• System %d" % int(sys_id)
		vbox.add_child(lbl)

	return panel

func _on_accept_all() -> void:
	var cmds: Array[CmdBattleOrders] = []
	for cd in card_controls:
		var cmd := CmdBattleOrders.new()
		cmd.empire_id = 0
		cmd.system_id = int(cd["system_id"])
		var p_idx: int = cd["posture_opt"].selected
		cmd.posture = cd["postures"][p_idx] if (p_idx >= 0 and p_idx < cd["postures"].size()) else "auto"
		var pr_idx: int = cd["prio_opt"].selected
		cmd.target_priority = cd["priorities"][pr_idx] if (pr_idx >= 0 and pr_idx < cd["priorities"].size()) else "auto"
		var sw_idx: int = cd["swat_opt"].selected
		cmd.swat_mode = cd["swat_modes"][sw_idx] if (sw_idx >= 0 and sw_idx < cd["swat_modes"].size()) else "missiles_first"
		var rt_idx: int = cd["ret_opt"].selected
		cmd.retreat_threshold = cd["ret_thresh"][rt_idx] if (rt_idx >= 0 and rt_idx < cd["ret_thresh"].size()) else "never"
		cmds.append(cmd)

	orders_submitted.emit(cmds)
	if Session != null and Session.has_method("answer_battle_orders"):
		Session.answer_battle_orders(cmds)
	on_back()
