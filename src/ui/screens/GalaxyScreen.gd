class_name GalaxyScreen
extends ScreenBase

var map_view: GalaxyMapView = null
var system_panel: SystemPanel = null

func build() -> void:
	if Session.state == null or Session.settings == null:
		# If no session active, start a default Evening Standard session
		var s: GameSettings = (GameSettings as Variant).call(&"new")
		s.preset = "evening_standard"
		s.seed_string = "FOWL"
		s.seed = Rng.seed_from_string("FOWL")
		s.player_race = "pheasants"
		s.seat_swans = true
		Session.start_galaxy(s)

	var preset_id: String = Session.settings.preset if Session.settings != null else "evening_standard"
	var preset_def: Dictionary = Session.db.table("galaxy").get("presets", {}).get(preset_id, {})

	# Mount GalaxyMapView in World
	var world: Node2D = get_tree().root.find_child("World", true, false) as Node2D
	if world != null:
		# Clear existing children in World
		for c in world.get_children():
			c.queue_free()
		map_view = GalaxyMapView.new()
		map_view.name = "GalaxyMapView"
		world.add_child(map_view)
		map_view.setup(Session.state, Session.db, preset_def)

	# Build UI overlay
	# 1. Right-side SystemPanel
	system_panel = SystemPanel.new()
	system_panel.name = "SystemPanel"
	system_panel.set_anchors_preset(PRESET_RIGHT_WIDE)
	system_panel.offset_left = -340.0
	system_panel.offset_top = 0.0
	system_panel.offset_right = 0.0
	system_panel.offset_bottom = 0.0
	system_panel.custom_minimum_size = Vector2(340, 0)
	system_panel.setup(Session.db, Session.state)
	add_child(system_panel)

	if map_view != null:
		map_view.system_selected.connect(func(id: int) -> void:
			if system_panel != null:
				system_panel.show_system(id)
		)

	# 2. Top-left controls: Zoom In, Zoom Out, Home, Menu
	var controls_bar := Ui.hbox(6)
	controls_bar.set_anchors_preset(PRESET_TOP_LEFT)
	controls_bar.offset_left = 16.0
	controls_bar.offset_top = 16.0
	add_child(controls_bar)

	var btn_zoom_in := Ui.button("+", _on_zoom_in, "Zoom In")
	btn_zoom_in.custom_minimum_size = Vector2(36, 36)
	controls_bar.add_child(btn_zoom_in)

	var btn_zoom_out := Ui.button("-", _on_zoom_out, "Zoom Out")
	btn_zoom_out.custom_minimum_size = Vector2(36, 36)
	controls_bar.add_child(btn_zoom_out)

	var btn_home := Ui.button("Home", _on_home, "Center on Home")
	btn_home.custom_minimum_size = Vector2(64, 36)
	controls_bar.add_child(btn_home)

	var btn_menu := Ui.button("Menu", _on_menu, "Main Menu (Esc)")
	btn_menu.custom_minimum_size = Vector2(64, 36)
	controls_bar.add_child(btn_menu)

	# Initial selection: player's homeworld
	var initial_id: int = -1
	for sys in Session.state.systems:
		if sys.home_of == 0:
			initial_id = sys.id
			break
	if initial_id == -1 and not Session.state.systems.is_empty():
		initial_id = 0

	if initial_id != -1:
		if map_view != null:
			map_view.select_system(initial_id)
		if system_panel != null:
			system_panel.show_system(initial_id)

func _on_zoom_in() -> void:
	if map_view != null and map_view.camera != null:
		map_view.camera.zoom_by(1.2)

func _on_zoom_out() -> void:
	if map_view != null and map_view.camera != null:
		map_view.camera.zoom_by(1.0 / 1.2)

func _on_home() -> void:
	if map_view != null and map_view.camera != null:
		map_view.camera.center_on(map_view.player_homeworld_pos)

func _on_menu() -> void:
	on_back()

func on_back() -> void:
	_cleanup_world()
	if router != null:
		router.show_screen(&"main_menu")

func _exit_tree() -> void:
	_cleanup_world()

func _cleanup_world() -> void:
	if map_view != null and is_instance_valid(map_view):
		map_view.queue_free()
		map_view = null
