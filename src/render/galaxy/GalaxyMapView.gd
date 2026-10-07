class_name GalaxyMapView
extends Node2D

signal system_selected(system_id: int)
signal system_right_clicked(system_id: int)
signal fleet_selected(fleet_id: int)

var starfield_layer: StarfieldLayer = null
var overlay_layer: OverlayLayer = null
var star_layer: StarLayer = null
var fleet_layer: FleetLayer = null
var camera: MapCamera = null

var state: GameState = null
var db: ContentDB = null
var selected_system_id: int = -1
var selected_fleet_id: int = -1

var map_width_px: float = 1760.0
var map_height_px: float = 1200.0
var player_homeworld_pos: Vector2 = Vector2.ZERO

func setup(p_state: GameState, p_db: ContentDB, preset_def: Dictionary) -> void:
	state = p_state
	db = p_db

	var w_pc: int = int(preset_def.get("width_pc", 44))
	var h_pc: int = int(preset_def.get("height_pc", 30))
	map_width_px = float(w_pc * 40)
	map_height_px = float(h_pc * 40)

	# Find player homeworld position (empire 0)
	player_homeworld_pos = Vector2(map_width_px * 0.5, map_height_px * 0.5)
	for sys in state.systems:
		if sys.home_of == 0:
			player_homeworld_pos = Vector2(sys.x * 4.0, sys.y * 4.0)
			break

	# 1. Starfield Layer (bottom)
	starfield_layer = StarfieldLayer.new()
	starfield_layer.name = "StarfieldLayer"
	add_child(starfield_layer)
	starfield_layer.setup(map_width_px, map_height_px)

	# 2. Overlay Layer (fuel range shaded grid)
	overlay_layer = OverlayLayer.new()
	overlay_layer.name = "OverlayLayer"
	add_child(overlay_layer)
	overlay_layer.setup(state, db, preset_def)

	# 3. Star Layer
	star_layer = StarLayer.new()
	star_layer.name = "StarLayer"
	add_child(star_layer)
	star_layer.setup(state, db)

	# 4. Fleet Layer (chevrons, lines, ETA ticks, selection)
	fleet_layer = FleetLayer.new()
	fleet_layer.name = "FleetLayer"
	add_child(fleet_layer)
	fleet_layer.setup(state, db, 0)

	# 5. Camera
	camera = MapCamera.new()
	camera.name = "MapCamera"
	add_child(camera)
	camera.setup(map_width_px, map_height_px, player_homeworld_pos)
	camera.zoom_changed.connect(func(z: float) -> void:
		if star_layer != null:
			star_layer.set_zoom(z)
		if fleet_layer != null:
			fleet_layer.set_zoom(z)
	)

func select_system(sys_id: int) -> void:
	if selected_system_id == sys_id:
		return
	selected_system_id = sys_id
	if star_layer != null:
		star_layer.set_selected_system(sys_id)
	system_selected.emit(sys_id)

func select_fleet(f_id: int) -> void:
	if selected_fleet_id == f_id:
		return
	selected_fleet_id = f_id
	if fleet_layer != null:
		fleet_layer.set_selected_fleet(f_id)
	fleet_selected.emit(f_id)

func refresh_layers() -> void:
	if star_layer != null:
		star_layer.queue_redraw()
	if fleet_layer != null:
		fleet_layer.queue_redraw()
	if overlay_layer != null:
		overlay_layer.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if state == null:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		var xform: Transform2D = get_viewport().get_canvas_transform()

		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			# Check fleet click first
			if fleet_layer != null:
				var clicked_fid: int = fleet_layer.find_fleet_at_screen_pos(mb.position, xform, 22.0)
				if clicked_fid != -1:
					select_fleet(clicked_fid)
					get_viewport().set_input_as_handled()
					return

			# Check star system click
			var best_id: int = -1
			var best_dist: float = 24.0
			for sys in state.systems:
				var world_pos := Vector2(sys.x * 4.0, sys.y * 4.0)
				var screen_pos: Vector2 = xform * world_pos
				var d: float = screen_pos.distance_to(mb.position)
				if d < best_dist:
					best_dist = d
					best_id = sys.id

			if best_id != -1:
				select_system(best_id)
				get_viewport().set_input_as_handled()

		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			# Right click on star system -> issue move if fleet selected
			var best_id: int = -1
			var best_dist: float = 24.0
			for sys in state.systems:
				var world_pos := Vector2(sys.x * 4.0, sys.y * 4.0)
				var screen_pos: Vector2 = xform * world_pos
				var d: float = screen_pos.distance_to(mb.position)
				if d < best_dist:
					best_dist = d
					best_id = sys.id

			if best_id != -1:
				system_right_clicked.emit(best_id)
				get_viewport().set_input_as_handled()
