class_name GalaxyScreen
extends ScreenBase

const TopBarScript = preload("res://src/ui/screens/TopBar.gd")
const ColonyPanelScript = preload("res://src/ui/screens/ColonyPanel.gd")
const SystemPanelScript = preload("res://src/ui/screens/SystemPanel.gd")
const FleetPanelScript = preload("res://src/ui/screens/FleetPanel.gd")
const NewsTickerScript = preload("res://src/ui/screens/NewsTicker.gd")

var map_view: GalaxyMapView = null
var system_panel: PanelContainer = null
var colony_panel: PanelContainer = null
var fleet_panel: PanelContainer = null
var news_ticker: PanelContainer = null
var top_bar: PanelContainer = null
var current_system_id: int = -1

func build() -> void:
	if Session.game == null or Session.state == null:
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
		for c in world.get_children():
			c.queue_free()
		map_view = GalaxyMapView.new()
		map_view.name = "GalaxyMapView"
		world.add_child(map_view)
		map_view.setup(Session.state, Session.db, preset_def)

	# 1. TopBar
	top_bar = TopBarScript.new()
	top_bar.name = "TopBar"
	top_bar.set_anchors_preset(PRESET_TOP_WIDE)
	top_bar.offset_bottom = 44.0
	top_bar.colonies_requested.connect(_on_colonies_requested)
	top_bar.fleets_requested.connect(_on_fleets_requested)
	top_bar.designer_requested.connect(_on_designer_requested)
	top_bar.diplomacy_requested.connect(_on_diplomacy_requested)
	top_bar.overlay_toggle_requested.connect(_on_overlay_toggle)
	top_bar.menu_requested.connect(_on_menu)
	add_child(top_bar)

	# NewsTicker at bottom
	news_ticker = NewsTickerScript.new()
	news_ticker.name = "NewsTicker"
	news_ticker.set_anchors_preset(PRESET_BOTTOM_WIDE)
	news_ticker.offset_top = -28.0
	news_ticker.offset_bottom = 0.0
	add_child(news_ticker)

	# 2. Right-side SystemPanel (340px)
	system_panel = SystemPanelScript.new()
	system_panel.name = "SystemPanel"
	system_panel.set_anchors_preset(PRESET_RIGHT_WIDE)
	system_panel.offset_left = -340.0
	system_panel.offset_top = 44.0
	system_panel.offset_right = 0.0
	system_panel.offset_bottom = 0.0
	system_panel.custom_minimum_size = Vector2(340, 0)
	system_panel.setup(Session.db, Session.state)
	system_panel.colony_selected.connect(_open_colony)
	add_child(system_panel)

	# 3. Right-side ColonyPanel (400px)
	colony_panel = ColonyPanelScript.new()
	colony_panel.name = "ColonyPanel"
	colony_panel.set_anchors_preset(PRESET_RIGHT_WIDE)
	colony_panel.offset_left = -400.0
	colony_panel.offset_top = 44.0
	colony_panel.offset_right = 0.0
	colony_panel.offset_bottom = 0.0
	colony_panel.custom_minimum_size = Vector2(400, 0)
	colony_panel.close_requested.connect(_on_colony_panel_closed)
	colony_panel.visible = false
	add_child(colony_panel)

	# 4. Right-side FleetPanel (380px)
	fleet_panel = FleetPanelScript.new()
	fleet_panel.name = "FleetPanel"
	fleet_panel.set_anchors_preset(PRESET_RIGHT_WIDE)
	fleet_panel.offset_left = -380.0
	fleet_panel.offset_top = 44.0
	fleet_panel.offset_right = 0.0
	fleet_panel.offset_bottom = 0.0
	fleet_panel.custom_minimum_size = Vector2(380, 0)
	fleet_panel.setup(Session.db, Session.state)
	fleet_panel.close_requested.connect(_on_fleet_panel_closed)
	fleet_panel.visible = false
	add_child(fleet_panel)

	if map_view != null:
		map_view.system_selected.connect(_on_map_system_selected)
		map_view.system_right_clicked.connect(_on_system_right_clicked)
		map_view.fleet_selected.connect(_open_fleet)

	# 5. Zoom / Home controls
	var controls_bar := Ui.hbox(6)
	controls_bar.set_anchors_preset(PRESET_TOP_LEFT)
	controls_bar.offset_left = 16.0
	controls_bar.offset_top = 60.0
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

	# Session turn_started signal -> modal summary
	if not Session.turn_started.is_connected(_on_turn_started):
		Session.turn_started.connect(_on_turn_started)

	# Initial selection or params handling
	var target_sys: int = -1
	var target_col: int = -1
	var target_flt: int = -1

	if params.has("focus_system"):
		target_sys = int(params["focus_system"])
	if params.has("open_colony"):
		target_col = int(params["open_colony"])
	if params.has("open_fleet"):
		target_flt = int(params["open_fleet"])

	if target_flt != -1 and Session.state.fleets.has(target_flt):
		_open_fleet(target_flt)
	elif target_col != -1 and Session.state.colonies.has(target_col):
		var p: Planet = Session.state.planets[Session.state.colonies[target_col].planet_id]
		target_sys = p.system_id
		_select_system(target_sys)
		_open_colony(target_col)
	elif target_sys != -1:
		_select_system(target_sys)
	else:
		# Initial selection: player's homeworld
		var initial_id: int = -1
		for sys in Session.state.systems:
			if sys.home_of == 0:
				initial_id = sys.id
				break
		if initial_id == -1 and not Session.state.systems.is_empty():
			initial_id = 0
		if initial_id != -1:
			_select_system(initial_id)

func _select_system(sys_id: int) -> void:
	current_system_id = sys_id
	if map_view != null:
		map_view.select_system(sys_id)
		if map_view.camera != null and sys_id >= 0 and sys_id < Session.state.systems.size():
			var sys: StarSystem = Session.state.systems[sys_id]
			map_view.camera.center_on(Vector2(sys.x * 4.0, sys.y * 4.0))
	else:
		_on_map_system_selected(sys_id)

func _show_colony_panel_only(col_id: int) -> void:
	system_panel.visible = false
	fleet_panel.visible = false
	colony_panel.visible = true
	colony_panel.set_colony(col_id)

func _find_player_colony_in_system(sys_id: int) -> int:
	if Session.state == null or sys_id < 0 or sys_id >= Session.state.systems.size():
		return -1
	var sys: StarSystem = Session.state.systems[sys_id]
	for pid in sys.planet_ids:
		for cid in Session.state.colonies.keys():
			var col: Colony = Session.state.colonies[cid]
			if col.planet_id == pid and col.owner == 0:
				return cid
	return -1

func _open_colony(col_id: int) -> void:
	if Session.state == null or not Session.state.colonies.has(col_id):
		return
	_show_colony_panel_only(col_id)

	var p: Planet = Session.state.planets[Session.state.colonies[col_id].planet_id]
	current_system_id = p.system_id
	if map_view != null and map_view.selected_system_id != current_system_id:
		map_view.select_system(current_system_id)

func _open_fleet(fleet_id: int) -> void:
	if Session.state == null or not Session.state.fleets.has(fleet_id):
		return
	system_panel.visible = false
	colony_panel.visible = false
	fleet_panel.visible = true
	fleet_panel.show_fleet(fleet_id)
	if map_view != null and map_view.selected_fleet_id != fleet_id:
		map_view.select_fleet(fleet_id)
		var flt: Fleet = Session.state.fleets[fleet_id]
		if map_view.camera != null:
			map_view.camera.center_on(Vector2(flt.x * 4.0, flt.y * 4.0))

func _on_map_system_selected(sys_id: int) -> void:
	current_system_id = sys_id

	# If fleet panel is open in Move mode, issue move
	if fleet_panel.visible and fleet_panel.is_move_mode:
		_issue_fleet_move(fleet_panel.current_fleet_id, sys_id)
		fleet_panel.set_move_mode(false)
		return

	# If fleet panel is open, close it when a star is clicked
	if fleet_panel.visible:
		fleet_panel.visible = false
		if map_view != null:
			map_view.select_fleet(-1)

	var player_col_id: int = _find_player_colony_in_system(sys_id)
	if player_col_id != -1:
		_show_colony_panel_only(player_col_id)
	else:
		colony_panel.visible = false
		system_panel.visible = true
		system_panel.show_system(sys_id)

func _on_system_right_clicked(sys_id: int) -> void:
	if fleet_panel.visible and fleet_panel.current_fleet_id != -1:
		_issue_fleet_move(fleet_panel.current_fleet_id, sys_id)
		fleet_panel.set_move_mode(false)

func _issue_fleet_move(f_id: int, dest_sys_id: int) -> void:
	var cmd := CmdFleetMove.new()
	cmd.empire_id = 0
	cmd.fleet_id = f_id
	cmd.system_id = dest_sys_id
	var err: String = Session.submit(cmd)
	if err != "":
		# Refusal
		var msg: String = Copy.t(err) if Copy.has(err) else err
		print("Move refused: ", msg)
	else:
		if fleet_panel.visible:
			fleet_panel.refresh()
		if map_view != null:
			map_view.refresh_layers()

func _on_colony_panel_closed() -> void:
	colony_panel.visible = false
	system_panel.visible = true
	if current_system_id != -1:
		system_panel.show_system(current_system_id)

func _on_fleet_panel_closed() -> void:
	fleet_panel.visible = false
	if map_view != null:
		map_view.select_fleet(-1)
		map_view.clear_move_preview()
	system_panel.visible = true
	if current_system_id != -1:
		system_panel.show_system(current_system_id)

func _on_colonies_requested() -> void:
	if router != null:
		router.show_screen(&"colonies_list")

func _on_fleets_requested() -> void:
	if router != null:
		router.show_screen(&"fleets_list")

func _on_designer_requested() -> void:
	if router != null:
		router.show_screen(&"ship_designer")

func _on_diplomacy_requested() -> void:
	if router != null:
		router.show_screen(&"diplomacy")

func _on_overlay_toggle() -> void:
	if map_view != null and map_view.overlay_layer != null:
		map_view.overlay_layer.toggle()

func _on_turn_started(report: TurnReport) -> void:
	if report != null and not report.entries.is_empty():
		if router != null and router.current() == self:
			router.show_screen(&"turn_summary", {"report": report})

func cycle_colonies() -> void:
	if Session.state == null:
		return
	var player_col_ids: Array[int] = []
	for cid in Ids.sorted_keys(Session.state.colonies):
		var col: Colony = Session.state.colonies[cid]
		if col.owner == 0:
			player_col_ids.append(cid)
	if player_col_ids.is_empty():
		return

	var cur_idx: int = -1
	if colony_panel.visible:
		cur_idx = player_col_ids.find(colony_panel.colony_id)

	var next_idx: int = (cur_idx + 1) % player_col_ids.size()
	var next_cid: int = player_col_ids[next_idx]
	var p: Planet = Session.state.planets[Session.state.colonies[next_cid].planet_id]
	_select_system(p.system_id)
	_open_colony(next_cid)

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
