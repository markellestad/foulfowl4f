class_name GalaxyMapView
extends Node2D

signal system_selected(system_id: int)

var starfield_layer: StarfieldLayer = null
var star_layer: StarLayer = null
var camera: MapCamera = null

var state: GameState = null
var db: ContentDB = null
var selected_system_id: int = -1

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

	# Build child layers
	starfield_layer = StarfieldLayer.new()
	starfield_layer.name = "StarfieldLayer"
	add_child(starfield_layer)
	starfield_layer.setup(map_width_px, map_height_px)

	star_layer = StarLayer.new()
	star_layer.name = "StarLayer"
	add_child(star_layer)
	star_layer.setup(state, db)

	camera = MapCamera.new()
	camera.name = "MapCamera"
	add_child(camera)
	camera.setup(map_width_px, map_height_px, player_homeworld_pos)
	camera.zoom_changed.connect(func(z: float) -> void:
		if star_layer != null:
			star_layer.set_zoom(z)
	)

func select_system(sys_id: int) -> void:
	selected_system_id = sys_id
	if star_layer != null:
		star_layer.set_selected_system(sys_id)
	system_selected.emit(sys_id)

func _unhandled_input(event: InputEvent) -> void:
	if state == null:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			# Check screen distance to stars
			var best_id: int = -1
			var best_dist: float = 24.0 # max 24 screen px
			var xform: Transform2D = get_viewport().get_canvas_transform()

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
