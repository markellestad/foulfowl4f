class_name FleetLayer
extends Node2D

signal fleet_selected(fleet_id: int)

var state: GameState = null
var db: ContentDB = null
var selected_fleet_id: int = -1
var viewer_empire_id: int = 0

# Move preview (for Move button / mouse target preview)
var preview_fleet_id: int = -1
var preview_target_system_id: int = -1

var _font: Font = null
var _font_size: int = 12

func setup(p_state: GameState, p_db: ContentDB, p_viewer_empire_id: int = 0) -> void:
	state = p_state
	db = p_db
	viewer_empire_id = p_viewer_empire_id
	queue_redraw()

func set_selected_fleet(f_id: int) -> void:
	if selected_fleet_id != f_id:
		selected_fleet_id = f_id
		queue_redraw()

func set_move_preview(fleet_id: int, target_sys_id: int) -> void:
	preview_fleet_id = fleet_id
	preview_target_system_id = target_sys_id
	queue_redraw()

func clear_move_preview() -> void:
	if preview_fleet_id != -1 or preview_target_system_id != -1:
		preview_fleet_id = -1
		preview_target_system_id = -1
		queue_redraw()

func _ensure_font() -> void:
	if _font == null:
		var root_theme: Theme = ThemeDB.get_project_theme()
		if root_theme != null and root_theme.default_font != null:
			_font = root_theme.default_font
			_font_size = root_theme.default_font_size
		else:
			_font = ThemeDB.fallback_font
			_font_size = 12

func _draw() -> void:
	if state == null or db == null:
		return
	_ensure_font()

	var visible_fleets: Array[Fleet] = Visibility.visible_fleets(db, state, viewer_empire_id)

	# 1. Draw move preview line if active
	if preview_fleet_id != -1 and preview_target_system_id >= 0 and preview_target_system_id < state.systems.size():
		var pf: Fleet = state.fleets.get(preview_fleet_id)
		if pf != null:
			var start_p := Vector2(pf.x * 4.0, pf.y * 4.0)
			var target_sys: StarSystem = state.systems[preview_target_system_id]
			var end_p := Vector2(target_sys.x * 4.0, target_sys.y * 4.0)
			_draw_dotted_trajectory(start_p, end_p, Color(0.3, 0.8, 1.0, 0.8), 2.0, 3)

	# 2. Draw destination dotted lines & ETA ticks for visible fleets
	for f in visible_fleets:
		if f.dest_system_id >= 0 and f.dest_system_id < state.systems.size():
			var start_pos := Vector2(f.x * 4.0, f.y * 4.0)
			var dest_sys: StarSystem = state.systems[f.dest_system_id]
			var dest_pos := Vector2(dest_sys.x * 4.0, dest_sys.y * 4.0)
			var emp: Empire = state.empires[f.owner] if f.owner < state.empires.size() else null
			var race_id: String = emp.race if emp != null else "pheasants"
			var col: Color = EmpireStyle.race_color(race_id)
			var eta_turns: int = max(1, f.arrive_turn - state.turn)
			_draw_dotted_trajectory(start_pos, dest_pos, col, 1.5, eta_turns)

	# 3. Draw selection filled underlay (NO RINGS!)
	if selected_fleet_id != -1:
		var sel_fleet: Fleet = state.fleets.get(selected_fleet_id)
		if sel_fleet != null:
			var sel_pos := Vector2(sel_fleet.x * 4.0, sel_fleet.y * 4.0)
			var emp: Empire = state.empires[sel_fleet.owner] if sel_fleet.owner < state.empires.size() else null
			var race_id: String = emp.race if emp != null else "pheasants"
			var col: Color = EmpireStyle.race_color(race_id)
			# Filled underlay polygon / circle
			var underlay_col := Color(col.r, col.g, col.b, 0.35)
			draw_circle(sel_pos, 16.0, underlay_col)
			draw_circle(sel_pos, 11.0, Color(1.0, 1.0, 1.0, 0.20))

	# 4. Draw chevrons & doomstack labels
	for f in visible_fleets:
		var f_pos := Vector2(f.x * 4.0, f.y * 4.0)
		var emp: Empire = state.empires[f.owner] if f.owner < state.empires.size() else null
		var race_id: String = emp.race if emp != null else "pheasants"
		var col: Color = EmpireStyle.race_color(race_id)

		var angle: float = -PI * 0.5
		if f.dest_system_id >= 0 and f.dest_system_id < state.systems.size():
			var dest_sys: StarSystem = state.systems[f.dest_system_id]
			var dest_pos := Vector2(dest_sys.x * 4.0, dest_sys.y * 4.0)
			if f_pos.distance_squared_to(dest_pos) > 0.01:
				angle = (dest_pos - f_pos).angle() + PI * 0.5

		var chevron_sz: float = 18.0
		BirdShapes.draw_icon(self, race_id, f_pos, chevron_sz, col, angle)

		# Doomstack label (8+ ships)
		if f.ship_ids.size() >= 8:
			var txt: String = Copy.t("ui.fleet.doomstack") if Copy.has("ui.fleet.doomstack") else "8+"
			var t_pos := f_pos + Vector2(10, -10)
			draw_string(_font, t_pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#ffdd66"))

func _draw_dotted_trajectory(start: Vector2, finish: Vector2, color: Color, width: float, ticks: int) -> void:
	var total_dist: float = start.distance_to(finish)
	if total_dist < 4.0:
		return

	var dir: Vector2 = (finish - start) / total_dist
	var normal: Vector2 = Vector2(-dir.y, dir.x)

	# Dotted dash line
	var dash_len: float = 6.0
	var gap_len: float = 4.0
	var cur: float = 0.0
	while cur < total_dist:
		var seg_end: float = minf(cur + dash_len, total_dist)
		draw_line(start + dir * cur, start + dir * seg_end, color, width)
		cur += dash_len + gap_len

	# ETA ticks along the path
	if ticks > 1:
		for t in range(1, ticks):
			var frac: float = float(t) / float(ticks)
			var tick_p: Vector2 = start.lerp(finish, frac)
			draw_line(tick_p - normal * 4.0, tick_p + normal * 4.0, color, width + 0.5)

func find_fleet_at_screen_pos(screen_pos: Vector2, canvas_xform: Transform2D, max_dist: float = 20.0) -> int:
	if state == null:
		return -1
	var visible_fleets: Array[Fleet] = Visibility.visible_fleets(db, state, viewer_empire_id)
	var best_id: int = -1
	var best_d: float = max_dist
	for f in visible_fleets:
		var world_pos := Vector2(f.x * 4.0, f.y * 4.0)
		var sp: Vector2 = canvas_xform * world_pos
		var d: float = sp.distance_to(screen_pos)
		if d < best_d:
			best_d = d
			best_id = f.id
	return best_id
