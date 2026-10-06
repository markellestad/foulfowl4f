class_name FleetsListScreen
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

	var btn_back := Ui.button("◄ " + Copy.t("ui.label.back"), _on_back_clicked)
	btn_back.custom_minimum_size = Vector2(100, 36)
	header.add_child(btn_back)

	var title := Ui.label("Fleets", "HeadingLarge")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_table = DataTableScript.new()
	_table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_table)

	var cols: Array[Dictionary] = [
		{"id": "name", "title": "Fleet", "width": 120},
		{"id": "location", "title": "Location", "width": 220},
		{"id": "ships", "title": "Ships", "width": 280},
		{"id": "speed", "title": "Speed", "width": 110, "align": HORIZONTAL_ALIGNMENT_CENTER},
		{"id": "eta", "title": "ETA", "width": 110, "align": HORIZONTAL_ALIGNMENT_CENTER},
		{"id": "order", "title": "Order", "width": 180}
	]
	_table.setup(cols)
	_table.row_clicked.connect(_on_row_clicked)

	_refresh_data()

func _refresh_data() -> void:
	if Session.state == null or Session.db == null:
		return

	var gs: GameState = Session.state
	var db: ContentDB = Session.db
	var rows: Array[Dictionary] = []

	for fid in Ids.sorted_keys(gs.fleets):
		var flt: Fleet = gs.fleets[fid]
		if flt.owner != 0:
			continue

		var loc_str: String = ""
		var eta_str: String = "—"
		if flt.system_id >= 0 and flt.system_id < gs.systems.size():
			var sys: StarSystem = gs.systems[flt.system_id]
			if sys.is_orn:
				loc_str = Copy.t("place.orn.name")
			elif sys.name_id > 0:
				loc_str = Copy.t("star.name.%d" % sys.name_id)
			else:
				loc_str = "Star %d" % sys.id
		elif flt.dest_system_id >= 0 and flt.dest_system_id < gs.systems.size():
			var d_sys: StarSystem = gs.systems[flt.dest_system_id]
			loc_str = "-> Star %d" % d_sys.id
			eta_str = "%d turns" % max(1, flt.arrive_turn - gs.turn)
		else:
			loc_str = "Deep Space"

		# Ships breakdown
		var counts: Dictionary = {}
		for sid in flt.ship_ids:
			var s: Ship = gs.ships.get(sid)
			if s != null:
				var des: ShipDesign = gs.designs.get(s.design_id)
				var dname: String = des.name if des != null else "Ship"
				counts[dname] = int(counts.get(dname, 0)) + 1
		var parts_list: Array[String] = []
		for k in counts.keys():
			parts_list.append("%dx %s" % [counts[k], k])
		var ships_str: String = ", ".join(parts_list) if not parts_list.is_empty() else "Empty"

		var spd: int = Movement.fleet_map_speed(db, gs, flt.id)

		var order_str: String = "Holding"
		if flt.auto_explore:
			order_str = "Auto-Explore"
		elif flt.dest_system_id != -1:
			order_str = "Moving"
		if flt.order != null and flt.order.kind != "":
			order_str = flt.order.kind.capitalize()

		rows.append({
			"_fleet_id": flt.id,
			"name": "Fleet %d" % flt.id,
			"location": loc_str,
			"ships": ships_str,
			"speed": "%d pc/t" % spd,
			"eta": eta_str,
			"order": order_str
		})

	_table.set_rows(rows)

func _on_row_clicked(row_data: Dictionary) -> void:
	var fid: int = int(row_data.get("_fleet_id", -1))
	if fid != -1 and router != null:
		router.show_screen(&"galaxy", {"open_fleet": fid})

func _on_back_clicked() -> void:
	if router != null:
		router.back()
