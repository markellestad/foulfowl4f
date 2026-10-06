class_name OverlayLayer
extends Node2D

var state: GameState = null
var db: ContentDB = null
var width_pc: int = 44
var height_pc: int = 30
var player_empire_id: int = 0
var enabled: bool = false

func setup(p_state: GameState, p_db: ContentDB, preset_def: Dictionary) -> void:
	state = p_state
	db = p_db
	width_pc = int(preset_def.get("width_pc", 44))
	height_pc = int(preset_def.get("height_pc", 30))
	visible = enabled
	queue_redraw()

func toggle() -> bool:
	enabled = not enabled
	visible = enabled
	if enabled:
		queue_redraw()
	return enabled

func set_enabled(v: bool) -> void:
	if enabled != v:
		enabled = v
		visible = enabled
		if enabled:
			queue_redraw()

func _draw() -> void:
	if not enabled or state == null or db == null:
		return

	var emp: Empire = state.empires[player_empire_id] if player_empire_id < state.empires.size() else null
	var race_id: String = emp.race if emp != null else "pheasants"
	var emp_color: Color = EmpireStyle.race_color(race_id)
	var fill_color := Color(emp_color.r, emp_color.g, emp_color.b, 0.14)
	var border_color := Color(emp_color.r, emp_color.g, emp_color.b, 0.22)

	# 1 pc cells: each cell is 10 dpc = 40 world px
	var cell_size_px: float = 40.0
	for cx in range(width_pc):
		for cy in range(height_pc):
			var center_x_dpc: int = cx * 10 + 5
			var center_y_dpc: int = cy * 10 + 5
			if FuelRange.in_range(db, state, player_empire_id, center_x_dpc, center_y_dpc):
				var r := Rect2(cx * cell_size_px, cy * cell_size_px, cell_size_px, cell_size_px)
				draw_rect(r, fill_color, true)
				draw_rect(r, border_color, false, 1.0)
