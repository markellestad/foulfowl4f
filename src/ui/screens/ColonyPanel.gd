class_name ColonyPanel
extends PanelContainer

signal close_requested

var colony_id: int = -1
var industry_breakdown_expanded: bool = false

var _title_lbl: Label = null
var _specs_lbl: Label = null
var _pop_lbl: Label = null
var _growth_lbl: Label = null
var _lock_check: CheckBox = null
var _lbl_farmers: Label = null
var _lbl_workers: Label = null
var _lbl_scientists: Label = null
var _preset_btn: OptionButton = null
var _yields_container: VBoxContainer = null
var _ind_breakdown_panel: PanelContainer = null
var _buildings_container: VBoxContainer = null
var _queue_container: VBoxContainer = null
var _add_menu_btn: MenuButton = null
var _add_items_list: Array[Dictionary] = []

const PRESETS: Array[String] = [
	"capital", "industry", "research", "breadbasket", "frontier", "fortress", "manual"
]

func _ready() -> void:
	custom_minimum_size.x = 400
	_build_ui()
	if not Session.state_changed.is_connected(_on_state_changed):
		Session.state_changed.connect(_on_state_changed)
	refresh()

func _on_state_changed(_scope: String, _ids: Array) -> void:
	refresh()

func set_colony(cid: int) -> void:
	colony_id = cid
	refresh()

func expand_industry_breakdown(exp: bool = true) -> void:
	industry_breakdown_expanded = exp
	if _ind_breakdown_panel != null:
		_ind_breakdown_panel.visible = exp

func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.PANEL
	style.border_color = Palette.LINE
	style.border_width_left = 1
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)

	var root_col := Ui.vbox(8)
	root_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(root_col)

	# Header row
	var header := Ui.hbox(8)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_col.add_child(header)

	_title_lbl = Ui.label("Colony", "HeadingMedium")
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_lbl)

	var btn_close := Ui.button("X", func() -> void: close_requested.emit())
	btn_close.custom_minimum_size = Vector2(28, 28)
	header.add_child(btn_close)

	_specs_lbl = Ui.label("", "Muted")
	root_col.add_child(_specs_lbl)

	var div1 := ColorRect.new()
	div1.color = Palette.LINE
	div1.custom_minimum_size = Vector2(0, 1)
	root_col.add_child(div1)

	# Scrollable body
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_col.add_child(scroll)

	var body := Ui.vbox(10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	# Pop & Growth
	var pop_box := Ui.vbox(4)
	body.add_child(pop_box)

	var pop_row := Ui.hbox(8)
	pop_box.add_child(pop_row)
	_pop_lbl = Ui.label("Pop: 0 / 0", "Heading")
	_pop_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pop_row.add_child(_pop_lbl)

	_growth_lbl = Ui.label("+0 / turn", "OK")
	pop_row.add_child(_growth_lbl)

	# Jobs
	var jobs_header := Ui.hbox(8)
	body.add_child(jobs_header)

	var lbl_jobs_title := Ui.label(Copy.t("ui.label.jobs"), "Heading")
	lbl_jobs_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jobs_header.add_child(lbl_jobs_title)

	_lock_check = CheckBox.new()
	_lock_check.text = Copy.t("ui.label.lock")
	_lock_check.toggled.connect(_on_lock_toggled)
	jobs_header.add_child(_lock_check)

	var jobs_table := Ui.vbox(4)
	body.add_child(jobs_table)

	# Farmers row
	var row_f := Ui.hbox(6)
	var btn_f_minus := Ui.button("-", func() -> void: _adjust_job("farmers", -1))
	btn_f_minus.custom_minimum_size = Vector2(28, 24)
	row_f.add_child(btn_f_minus)
	_lbl_farmers = Ui.label("Farmers: 0")
	_lbl_farmers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_f.add_child(_lbl_farmers)
	var btn_f_plus := Ui.button("+", func() -> void: _adjust_job("farmers", 1))
	btn_f_plus.custom_minimum_size = Vector2(28, 24)
	row_f.add_child(btn_f_plus)
	jobs_table.add_child(row_f)

	# Workers row
	var row_w := Ui.hbox(6)
	var btn_w_minus := Ui.button("-", func() -> void: _adjust_job("workers", -1))
	btn_w_minus.custom_minimum_size = Vector2(28, 24)
	row_w.add_child(btn_w_minus)
	_lbl_workers = Ui.label("Workers: 0")
	_lbl_workers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_w.add_child(_lbl_workers)
	var btn_w_plus := Ui.button("+", func() -> void: _adjust_job("workers", 1))
	btn_w_plus.custom_minimum_size = Vector2(28, 24)
	row_w.add_child(btn_w_plus)
	jobs_table.add_child(row_w)

	# Scientists row
	var row_s := Ui.hbox(6)
	var btn_s_minus := Ui.button("-", func() -> void: _adjust_job("scientists", -1))
	btn_s_minus.custom_minimum_size = Vector2(28, 24)
	row_s.add_child(btn_s_minus)
	_lbl_scientists = Ui.label("Scientists: 0")
	_lbl_scientists.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_s.add_child(_lbl_scientists)
	var btn_s_plus := Ui.button("+", func() -> void: _adjust_job("scientists", 1))
	btn_s_plus.custom_minimum_size = Vector2(28, 24)
	row_s.add_child(btn_s_plus)
	jobs_table.add_child(row_s)

	# Preset dropdown
	var preset_row := Ui.hbox(8)
	body.add_child(preset_row)
	var lbl_pr := Ui.label(Copy.t("ui.label.preset") + ":")
	preset_row.add_child(lbl_pr)
	_preset_btn = OptionButton.new()
	_preset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for p_id in PRESETS:
		var p_name: String = Copy.t("ui.preset." + p_id)
		_preset_btn.add_item(p_name)
	_preset_btn.item_selected.connect(_on_preset_selected)
	preset_row.add_child(_preset_btn)

	var div2 := ColorRect.new()
	div2.color = Palette.LINE
	div2.custom_minimum_size = Vector2(0, 1)
	body.add_child(div2)

	# Yields
	var lbl_yields := Ui.label(Copy.t("ui.label.yields"), "Heading")
	body.add_child(lbl_yields)

	_yields_container = Ui.vbox(4)
	body.add_child(_yields_container)

	_ind_breakdown_panel = PanelContainer.new()
	_ind_breakdown_panel.visible = false
	body.add_child(_ind_breakdown_panel)

	var div3 := ColorRect.new()
	div3.color = Palette.LINE
	div3.custom_minimum_size = Vector2(0, 1)
	body.add_child(div3)

	# Buildings
	var lbl_bld := Ui.label(Copy.t("ui.label.buildings"), "Heading")
	body.add_child(lbl_bld)

	_buildings_container = Ui.vbox(4)
	body.add_child(_buildings_container)

	var div4 := ColorRect.new()
	div4.color = Palette.LINE
	div4.custom_minimum_size = Vector2(0, 1)
	body.add_child(div4)

	# Production Queue
	var queue_hdr := Ui.hbox(8)
	body.add_child(queue_hdr)
	var lbl_q := Ui.label(Copy.t("ui.label.queue"), "Heading")
	lbl_q.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue_hdr.add_child(lbl_q)

	_add_menu_btn = MenuButton.new()
	_add_menu_btn.text = "+ " + Copy.t("ui.label.add")
	_add_menu_btn.get_popup().id_pressed.connect(_on_add_menu_item_selected)
	queue_hdr.add_child(_add_menu_btn)

	_queue_container = Ui.vbox(4)
	body.add_child(_queue_container)

func refresh() -> void:
	if Session.game == null or Session.state == null or not Session.state.colonies.has(colony_id):
		visible = false
		return

	visible = true
	var gs: GameState = Session.state
	var db: ContentDB = Session.db
	var col: Colony = gs.colonies[colony_id]
	var planet: Planet = gs.planets[col.planet_id]
	var sys: StarSystem = gs.systems[planet.system_id]

	# Star name / planet orbit
	var s_name: String = ""
	if sys.is_orn:
		s_name = Copy.t("place.orn.name")
	elif sys.name_id > 0:
		s_name = Copy.t("star.name.%d" % sys.name_id)
	else:
		s_name = "Star %d" % sys.id
	_title_lbl.text = "%s - Orbit %d" % [s_name, planet.orbit + 1]

	var cl_name: String = Copy.t("climate.%s.name" % planet.climate)
	var sz_name: String = Copy.t("ui.size.%s" % planet.size)
	var min_name: String = Copy.t("ui.minerals.%s" % planet.minerals)
	_specs_lbl.text = "%s • %s • %s • %s gravity" % [cl_name, sz_name, min_name, planet.gravity]

	var max_pop: int = Economy.max_pop_units(db, gs, col.id)
	_pop_lbl.text = "%s: %d / %d" % [Copy.t("ui.label.pop"), col.pop_units(), max_pop]

	var growth_milli: int = Growth.calc_growth(db, gs, col.id)
	_growth_lbl.text = "+%d / turn" % growth_milli

	_lock_check.set_pressed_no_signal(col.jobs_locked)
	_lbl_farmers.text = "%s: %d" % [Copy.t("ui.label.farmers"), col.farmers]
	_lbl_workers.text = "%s: %d" % [Copy.t("ui.label.workers"), col.workers]
	_lbl_scientists.text = "%s: %d" % [Copy.t("ui.label.scientists"), col.scientists]

	var pr_idx: int = PRESETS.find(col.preset)
	if pr_idx >= 0:
		_preset_btn.select(pr_idx)

	# Yields
	for child in _yields_container.get_children():
		child.queue_free()

	var yields: Dictionary = Economy.colony_output(db, gs, col.id)
	var f_res: ModResult = yields.get("food") as ModResult
	var ind_res: ModResult = yields.get("industry") as ModResult
	var sci_res: ModResult = yields.get("research") as ModResult
	var tax_res: ModResult = yields.get("taxes") as ModResult

	_add_yield_row(_yields_container, Copy.t("ui.label.food"), f_res, Palette.OK)
	_add_yield_row(_yields_container, Copy.t("ui.label.industry"), ind_res, Palette.GOLD, true)
	_add_yield_row(_yields_container, Copy.t("ui.label.research"), sci_res, Color("#66bbff"))
	_add_yield_row(_yields_container, Copy.t("ui.label.taxes"), tax_res, Palette.TEXT)

	# Industry breakdown panel
	for child in _ind_breakdown_panel.get_children():
		child.queue_free()
	if ind_res != null:
		var stat_ctl: Control = StatTooltip.build("Industry Breakdown", ind_res)
		_ind_breakdown_panel.add_child(stat_ctl)
	_ind_breakdown_panel.visible = industry_breakdown_expanded

	# Buildings
	for child in _buildings_container.get_children():
		child.queue_free()
	if col.buildings.is_empty():
		var lbl_none := Ui.label(Copy.t("ui.label.none"), "Muted")
		_buildings_container.add_child(lbl_none)
	else:
		for bid in col.buildings:
			var b_name: String = Copy.t("building.%s.name" % bid)
			var b_tip: String = Copy.t("building.%s.tip" % bid)
			var b_lbl := Ui.label("• " + b_name)
			b_lbl.tooltip_text = b_tip
			_buildings_container.add_child(b_lbl)

	# Queue
	for child in _queue_container.get_children():
		child.queue_free()

	var ind_val: int = ind_res.value if ind_res != null else 1
	var emp: Empire = gs.empires[col.owner]

	for q_idx in range(col.queue.size()):
		var item: QueueItem = col.queue[q_idx]
		var q_row := Ui.vbox(2)
		var style_q := StyleBoxFlat.new()
		style_q.bg_color = Palette.PANEL_ALT
		style_q.set_content_margin_all(6)
		style_q.set_corner_radius_all(4)
		q_row.add_theme_stylebox_override("panel", style_q)

		var top_line := Ui.hbox(6)
		q_row.add_child(top_line)

		var item_name: String = item.ref_id
		if item.kind == "building":
			item_name = Copy.t("building.%s.name" % item.ref_id)
		elif item.kind == "trade_goods":
			item_name = Copy.t("filler.trade_goods.name")
		elif item.kind == "research_project":
			item_name = Copy.t("filler.research_project.name")

		var lbl_in := Ui.label(item_name)
		lbl_in.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_line.add_child(lbl_in)

		var is_filler: bool = (item.kind == "trade_goods" or item.kind == "research_project")
		if not is_filler:
			var cost: int = Production.cost_for_item(db, gs, col.id, item)
			var cur_prog: int = col.progress_pp if q_idx == 0 else 0
			var left: int = max(0, cost - cur_prog)
			var turns_left: int = IntMath.ceil_div(left, max(1, ind_val))
			var lbl_cost := Ui.label("%d/%d (%dT)" % [cur_prog, cost, turns_left], "Muted")
			top_line.add_child(lbl_cost)

			# Repeat toggle
			var btn_rep := Ui.button("Rep" if item.repeat else "Once", func() -> void:
				var cmd := CmdQueueSetRepeat.new()
				cmd.empire_id = col.owner
				cmd.colony_id = col.id
				cmd.index = q_idx
				cmd.repeat = not item.repeat
				Session.submit(cmd)
			)
			btn_rep.custom_minimum_size = Vector2(40, 24)
			top_line.add_child(btn_rep)

			# Buy button on active item
			if q_idx == 0:
				var b_price: int = Production.buy_price(db, gs, col.id)
				var btn_buy := Ui.button("Buy %d cr" % b_price, func() -> void:
					var cmd := CmdBuy.new()
					cmd.empire_id = col.owner
					cmd.colony_id = col.id
					Session.submit(cmd)
				)
				btn_buy.disabled = emp.treasury < b_price
				btn_buy.custom_minimum_size = Vector2(60, 24)
				top_line.add_child(btn_buy)

		# Up / Down / Remove buttons
		var btn_up := Ui.button("^", func() -> void:
			var cmd := CmdQueueMove.new()
			cmd.empire_id = col.owner
			cmd.colony_id = col.id
			cmd.from_idx = q_idx
			cmd.to_idx = q_idx - 1
			Session.submit(cmd)
		)
		btn_up.disabled = (q_idx == 0)
		btn_up.custom_minimum_size = Vector2(24, 24)
		top_line.add_child(btn_up)

		var btn_down := Ui.button("v", func() -> void:
			var cmd := CmdQueueMove.new()
			cmd.empire_id = col.owner
			cmd.colony_id = col.id
			cmd.from_idx = q_idx
			cmd.to_idx = q_idx + 1
			Session.submit(cmd)
		)
		btn_down.disabled = (q_idx == col.queue.size() - 1)
		btn_down.custom_minimum_size = Vector2(24, 24)
		top_line.add_child(btn_down)

		var btn_rem := Ui.button("x", func() -> void:
			var cmd := CmdQueueRemove.new()
			cmd.empire_id = col.owner
			cmd.colony_id = col.id
			cmd.index = q_idx
			Session.submit(cmd)
		)
		btn_rem.custom_minimum_size = Vector2(24, 24)
		top_line.add_child(btn_rem)

		_queue_container.add_child(q_row)

	# Rebuild Add menu
	_rebuild_add_menu(col, gs, db)

func _add_yield_row(container: VBoxContainer, name_text: String, mod_res: ModResult, col: Color, is_industry: bool = false) -> void:
	var row := Ui.hbox(8)
	var lbl_name := Ui.label(name_text)
	lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl_name)

	var val_str: String = str(mod_res.value) if mod_res != null else "0"
	var lbl_val := Ui.label(val_str)
	lbl_val.add_theme_color_override("font_color", col)
	lbl_val.tooltip_text = StatTooltip.text_for("%s Breakdown" % name_text, mod_res)
	row.add_child(lbl_val)

	if is_industry:
		var btn_exp := Ui.button("...", func() -> void:
			expand_industry_breakdown(not industry_breakdown_expanded)
		, "Toggle Industry Breakdown")
		btn_exp.custom_minimum_size = Vector2(24, 20)
		row.add_child(btn_exp)

	container.add_child(row)

func _rebuild_add_menu(col: Colony, gs: GameState, db: ContentDB) -> void:
	var popup: PopupMenu = _add_menu_btn.get_popup()
	popup.clear()
	_add_items_list.clear()

	var b_table: Dictionary = db.table("buildings")
	var rows: Dictionary = b_table.get("rows", {})
	var b_keys: Array = Ids.sorted_keys(rows)

	var item_idx: int = 0
	for bid in b_keys:
		var b_name: String = Copy.t("building.%s.name" % bid)
		var test_cmd := CmdQueueAdd.new()
		test_cmd.empire_id = col.owner
		test_cmd.colony_id = col.id
		test_cmd.kind_item = "building"
		test_cmd.ref_id = bid
		test_cmd.count = 1
		test_cmd.index = -1
		var refusal: String = test_cmd.validate(gs, db)
		var is_ok: bool = (refusal == "")

		popup.add_item(b_name, item_idx)
		popup.set_item_disabled(item_idx, not is_ok)
		if not is_ok:
			var tip: String = Copy.t("refuse." + refusal)
			popup.set_item_tooltip(item_idx, tip)
		_add_items_list.append({"kind": "building", "ref_id": bid})
		item_idx += 1

	popup.add_separator()

	# Fillers
	for filler_id in ["trade_goods", "research_project"]:
		var f_name: String = Copy.t("filler.%s.name" % filler_id)
		var test_f := CmdQueueAdd.new()
		test_f.empire_id = col.owner
		test_f.colony_id = col.id
		test_f.kind_item = filler_id
		test_f.ref_id = filler_id
		test_f.count = 1
		test_f.index = -1
		var f_refusal: String = test_f.validate(gs, db)
		var f_ok: bool = (f_refusal == "")

		popup.add_item(f_name, item_idx)
		popup.set_item_disabled(item_idx, not f_ok)
		_add_items_list.append({"kind": filler_id, "ref_id": filler_id})
		item_idx += 1

func _on_add_menu_item_selected(id: int) -> void:
	if id < 0 or id >= _add_items_list.size():
		return
	var item_info: Dictionary = _add_items_list[id]
	var cmd := CmdQueueAdd.new()
	cmd.empire_id = Session.state.colonies[colony_id].owner
	cmd.colony_id = colony_id
	cmd.kind_item = str(item_info["kind"])
	cmd.ref_id = str(item_info["ref_id"])
	cmd.count = 1
	cmd.index = -1
	Session.submit(cmd)

func _adjust_job(job_name: String, delta: int) -> void:
	if Session.state == null or not Session.state.colonies.has(colony_id):
		return
	var col: Colony = Session.state.colonies[colony_id]
	var f: int = col.farmers
	var w: int = col.workers
	var s: int = col.scientists

	if delta > 0:
		match job_name:
			"farmers":
				if s > 0: s -= 1; f += 1
				elif w > 0: w -= 1; f += 1
			"workers":
				if s > 0: s -= 1; w += 1
				elif f > 0: f -= 1; w += 1
			"scientists":
				if w > 0: w -= 1; s += 1
				elif f > 0: f -= 1; s += 1
	elif delta < 0:
		match job_name:
			"farmers":
				if f > 0:
					f -= 1
					if w <= s: w += 1
					else: s += 1
			"workers":
				if w > 0:
					w -= 1
					s += 1
			"scientists":
				if s > 0:
					s -= 1
					w += 1

	var cmd := CmdSetJobs.new()
	cmd.empire_id = col.owner
	cmd.colony_id = col.id
	cmd.farmers = f
	cmd.workers = w
	cmd.scientists = s
	cmd.lock = true
	Session.submit(cmd)

func _on_lock_toggled(toggled_on: bool) -> void:
	if Session.state == null or not Session.state.colonies.has(colony_id):
		return
	var col: Colony = Session.state.colonies[colony_id]
	var cmd := CmdSetJobs.new()
	cmd.empire_id = col.owner
	cmd.colony_id = col.id
	cmd.farmers = col.farmers
	cmd.workers = col.workers
	cmd.scientists = col.scientists
	cmd.lock = toggled_on
	Session.submit(cmd)

func _on_preset_selected(index: int) -> void:
	if index < 0 or index >= PRESETS.size() or Session.state == null or not Session.state.colonies.has(colony_id):
		return
	var col: Colony = Session.state.colonies[colony_id]
	var pr: String = PRESETS[index]
	var cmd := CmdSetPreset.new()
	cmd.empire_id = col.owner
	cmd.colony_id = col.id
	cmd.preset = pr
	Session.submit(cmd)
