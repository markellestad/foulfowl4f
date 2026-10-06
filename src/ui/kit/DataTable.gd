class_name DataTable
extends VBoxContainer

signal row_clicked(row_data: Dictionary)

var columns: Array[Dictionary] = []
var _rows_data: Array[Dictionary] = []
var _row_pool: Array[Button] = []
var _row_cell_labels: Array[Array] = [] # pool_index -> Array[Label]
var _header_bar: HBoxContainer = null
var _scroll: ScrollContainer = null
var _rows_container: VBoxContainer = null
var sort_col_id: String = ""
var sort_ascending: bool = true

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

func setup(p_columns: Array[Dictionary]) -> void:
	columns = p_columns
	for child in get_children():
		child.queue_free()
	_row_pool.clear()
	_row_cell_labels.clear()

	_build_header()

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	_rows_container = Ui.vbox(2)
	_rows_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_rows_container)

	if not columns.is_empty():
		sort_col_id = str(columns[0].get("id", ""))

func _build_header() -> void:
	_header_bar = Ui.hbox(4)
	_header_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_header_bar)

	for col in columns:
		var cid: String = str(col.get("id", ""))
		var title: String = str(col.get("title", cid.capitalize()))
		var w: int = int(col.get("width", 100))

		var btn := Button.new()
		btn.text = title
		btn.custom_minimum_size.x = w
		btn.theme_type_variation = &"Muted"
		btn.pressed.connect(_on_header_clicked.bind(cid))
		_header_bar.add_child(btn)

func _on_header_clicked(cid: String) -> void:
	if sort_col_id == cid:
		sort_ascending = not sort_ascending
	else:
		sort_col_id = cid
		sort_ascending = true
	_refresh()

func set_rows(data: Array[Dictionary]) -> void:
	_rows_data = data.duplicate()
	_refresh()

func _sort_data() -> void:
	if sort_col_id == "":
		return
	_rows_data.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var va: Variant = a.get(sort_col_id, "")
		var vb: Variant = b.get(sort_col_id, "")
		if sort_ascending:
			return va < vb
		return va > vb
	)

func _create_row_control(pool_idx: int) -> Button:
	var row_btn := Button.new()
	row_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_btn.custom_minimum_size.y = 32

	var style_norm := StyleBoxFlat.new()
	style_norm.bg_color = Palette.PANEL if pool_idx % 2 == 0 else Palette.PANEL_ALT
	style_norm.set_content_margin_all(4)
	row_btn.add_theme_stylebox_override("normal", style_norm)

	var style_hov := StyleBoxFlat.new()
	style_hov.bg_color = Palette.LINE
	style_hov.border_color = Palette.GOLD
	style_hov.set_border_width_all(1)
	style_hov.set_content_margin_all(4)
	row_btn.add_theme_stylebox_override("hover", style_hov)

	var hbox := Ui.hbox(4)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_btn.add_child(hbox)

	var cell_labels: Array = []
	for col in columns:
		var w: int = int(col.get("width", 100))
		var align: int = int(col.get("align", HORIZONTAL_ALIGNMENT_LEFT))
		var lbl := Ui.label("")
		lbl.custom_minimum_size.x = w
		lbl.horizontal_alignment = align as HorizontalAlignment
		hbox.add_child(lbl)
		cell_labels.append(lbl)

	_row_cell_labels.append(cell_labels)
	row_btn.pressed.connect(_on_row_clicked.bind(pool_idx))
	_rows_container.add_child(row_btn)
	return row_btn

func _refresh() -> void:
	_sort_data()

	while _row_pool.size() < _rows_data.size():
		var idx: int = _row_pool.size()
		var btn := _create_row_control(idx)
		_row_pool.append(btn)

	for i in range(_rows_data.size()):
		var r_data: Dictionary = _rows_data[i]
		var btn: Button = _row_pool[i]
		btn.visible = true
		var labels: Array = _row_cell_labels[i]

		for c_idx in range(columns.size()):
			var col: Dictionary = columns[c_idx]
			var cid: String = str(col.get("id", ""))
			var lbl: Label = labels[c_idx] as Label
			lbl.text = str(r_data.get(cid, ""))

	for i in range(_rows_data.size(), _row_pool.size()):
		_row_pool[i].visible = false

func _on_row_clicked(pool_idx: int) -> void:
	if pool_idx >= 0 and pool_idx < _rows_data.size():
		row_clicked.emit(_rows_data[pool_idx])
