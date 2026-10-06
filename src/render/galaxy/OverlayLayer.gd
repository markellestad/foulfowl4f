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
	var fill_color := Color(emp_color.r, emp_color.g, emp_color.b, 0.12)
	var border_color := Color(emp_color.r, emp_color.g, emp_color.b, 0.70)

	var range_dpc: int = FuelRange.fuel_range_dpc(db, state, player_empire_id)
	var r_px: float = range_dpc * 4.0

	# Collect all unique system centers with owned colonies or outposts
	var system_centers: Array[Vector2] = []
	var visited_systems: Dictionary = {}

	for cid in state.colonies.keys():
		var col: Colony = state.colonies[cid]
		if col.owner == player_empire_id:
			var planet: Planet = state.planets[col.planet_id]
			if not visited_systems.has(planet.system_id):
				visited_systems[planet.system_id] = true
				var sys: StarSystem = state.systems[planet.system_id]
				system_centers.append(Vector2(sys.x * 4.0, sys.y * 4.0))

	if system_centers.is_empty():
		return

	# Build circle polygons (64 points each)
	var circles: Array[PackedVector2Array] = []
	const NUM_PTS: int = 64
	for center in system_centers:
		var circle_pts := PackedVector2Array()
		for i in range(NUM_PTS):
			var angle: float = (float(i) / float(NUM_PTS)) * TAU
			circle_pts.append(center + Vector2(cos(angle), sin(angle)) * r_px)
		circles.append(circle_pts)

	# Merge overlapping circles into disjoint polygon regions
	var polys: Array[PackedVector2Array] = circles.duplicate()
	var merged_any := true
	while merged_any and polys.size() > 1:
		merged_any = false
		var new_polys: Array[PackedVector2Array] = []
		var merged_indices := {}
		for i in range(polys.size()):
			if merged_indices.has(i):
				continue
			var current: PackedVector2Array = polys[i]
			for j in range(i + 1, polys.size()):
				if merged_indices.has(j):
					continue
				var res: Array[PackedVector2Array] = Geometry2D.merge_polygons(current, polys[j])
				if res.size() == 1:
					current = res[0]
					merged_indices[j] = true
					merged_any = true
			new_polys.append(current)
		polys = new_polys

	# Draw each region: soft translucent fill + single smooth antialiased edge line
	for poly in polys:
		if poly.size() < 3:
			continue
		draw_colored_polygon(poly, fill_color)
		var outline: PackedVector2Array = poly.duplicate()
		outline.append(poly[0])
		draw_polyline(outline, border_color, 2.0, true)
