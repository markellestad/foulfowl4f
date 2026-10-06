class_name ColoniesListScreen
extends ScreenBase

const DataTableScript = preload("res://src/ui/kit/DataTable.gd")

var _table: Control = null

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

	var header := Ui.hbox(16)
	v.add_child(header)

	var btn_back := Ui.button("<- " + Copy.t("ui.label.back"), _on_back_clicked)
	btn_back.custom_minimum_size = Vector2(100, 36)
	header.add_child(btn_back)

	var title := Ui.label(Copy.t("ui.label.colonies"), "HeadingLarge")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_table = DataTableScript.new()
	_table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_table)

	var cols: Array[Dictionary] = [
		{"id": "name", "title": "Colony", "width": 200},
		{"id": "pop", "title": "Pop", "width": 90, "align": HORIZONTAL_ALIGNMENT_CENTER},
		{"id": "food", "title": "Food", "width": 80, "align": HORIZONTAL_ALIGNMENT_RIGHT},
		{"id": "industry", "title": "PP", "width": 80, "align": HORIZONTAL_ALIGNMENT_RIGHT},
		{"id": "research", "title": "RP", "width": 80, "align": HORIZONTAL_ALIGNMENT_RIGHT},
		{"id": "preset", "title": "Preset", "width": 120},
		{"id": "building", "title": "Building Now", "width": 240}
	]
	_table.setup(cols)
	_table.row_clicked.connect(_on_row_clicked)

	_refresh_data()

func _refresh_data() -> void:
	if Session.state == null:
		return

	var gs: GameState = Session.state
	var db: ContentDB = Session.db
	var rows: Array[Dictionary] = []

	for cid in Ids.sorted_keys(gs.colonies):
		var col: Colony = gs.colonies[cid]
		if col.owner != 0:
			continue

		var planet: Planet = gs.planets[col.planet_id]
		var sys: StarSystem = gs.systems[planet.system_id]

		var s_name: String = ""
		if sys.is_orn:
			s_name = Copy.t("place.orn.name")
		elif sys.name_id > 0:
			s_name = Copy.t("star.name.%d" % sys.name_id)
		else:
			s_name = "Star %d" % sys.id
		var col_name: String = "%s (O%d)" % [s_name, planet.orbit + 1]

		var max_pop: int = Economy.max_pop_units(db, gs, col.id)
		var pop_str: String = "%d / %d" % [col.pop_units(), max_pop]

		var yields: Dictionary = Economy.colony_output(db, gs, col.id)
		var f_val: int = (yields.get("food") as ModResult).value
		var ind_val: int = (yields.get("industry") as ModResult).value
		var sci_val: int = (yields.get("research") as ModResult).value

		var pr_name: String = Copy.t("ui.preset." + col.preset)

		var cur_bld: String = "None"
		if not col.queue.is_empty():
			var qi: QueueItem = col.queue[0]
			if qi.kind == "building":
				cur_bld = Copy.t("building.%s.name" % qi.ref_id)
			elif qi.kind == "trade_goods":
				cur_bld = Copy.t("filler.trade_goods.name")
			elif qi.kind == "research_project":
				cur_bld = Copy.t("filler.research_project.name")

		rows.append({
			"colony_id": col.id,
			"system_id": sys.id,
			"name": col_name,
			"pop": pop_str,
			"food": f_val,
			"industry": ind_val,
			"research": sci_val,
			"preset": pr_name,
			"building": cur_bld
		})

	_table.set_rows(rows)

func _on_row_clicked(row_data: Dictionary) -> void:
	var sys_id: int = int(row_data.get("system_id", 0))
	var col_id: int = int(row_data.get("colony_id", 0))
	if router != null:
		router.show_screen(&"galaxy", {"focus_system": sys_id, "open_colony": col_id})

func _on_back_clicked() -> void:
	on_back()

func on_back() -> void:
	if router != null:
		router.show_screen(&"galaxy")
