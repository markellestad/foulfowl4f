class_name SystemPanel
extends PanelContainer

signal colony_selected(colony_id: int)

var db: ContentDB = null
var state: GameState = null
var current_system_id: int = -1

var _name_lbl: Label = null
var _type_lbl: Label = null
var _owner_lbl: Label = null
var _planets_container: VBoxContainer = null

func _ready() -> void:
	custom_minimum_size.x = 340.0
	_build_ui()

func setup(p_db: ContentDB, p_state: GameState) -> void:
	db = p_db
	state = p_state

func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.PANEL
	style.border_color = Palette.LINE
	style.border_width_left = 1
	style.set_content_margin_all(14)
	add_theme_stylebox_override("panel", style)

	var root_col := Ui.vbox(10)
	add_child(root_col)

	_name_lbl = Ui.label("", "HeadingMedium")
	root_col.add_child(_name_lbl)

	_type_lbl = Ui.label("", "Muted")
	root_col.add_child(_type_lbl)

	_owner_lbl = Ui.label("", "Gold")
	root_col.add_child(_owner_lbl)

	root_col.add_child(Ui.spacer(4))

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.color = Palette.LINE
	root_col.add_child(divider)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_col.add_child(scroll)

	_planets_container = Ui.vbox(8)
	_planets_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_planets_container)

func show_system(sys_id: int) -> void:
	current_system_id = sys_id
	if state == null or sys_id < 0 or sys_id >= state.systems.size():
		return

	var sys: StarSystem = state.systems[sys_id]

	# Star name
	var s_name: String = ""
	if sys.is_orn:
		s_name = Copy.t("place.orn.name")
	elif sys.name_id > 0:
		s_name = Copy.t("star.name.%d" % sys.name_id)
	else:
		s_name = "Star %d" % sys.id
	_name_lbl.text = s_name

	# Star type
	var type_name: String = Copy.t("star.%s.name" % sys.star_type)
	if sys.wormhole_to != -1:
		type_name += " • " + Copy.t("ui.label.wormhole") if Copy.has("ui.label.wormhole") else " • Wormhole"
	_type_lbl.text = type_name

	# Owner / Homeworld
	if sys.home_of != -1:
		var race_id: String = Session.settings.seats[sys.home_of] if Session.settings != null and sys.home_of < Session.settings.seats.size() else ""
		var r_name: String = Copy.t("race.%s.name" % race_id)
		_owner_lbl.text = "Homeworld: %s" % r_name
		_owner_lbl.visible = true
	else:
		_owner_lbl.visible = false

	# Planets list
	for child in _planets_container.get_children():
		child.queue_free()

	# Player race traits for habitability
	var player_traits: Array[String] = []
	if Session.settings != null and db != null:
		var p_race: String = Session.settings.player_race
		var rdef: Dictionary = db.table("races").get("rows", {}).get(p_race, {})
		for t in rdef.get("traits", []):
			player_traits.append(str(t))

	for pid in sys.planet_ids:
		var p: Planet = state.planets[pid]
		var card := _build_planet_card(p, player_traits)
		_planets_container.add_child(card)

func _build_planet_card(p: Planet, player_traits: Array[String]) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.PANEL_ALT
	style.set_content_margin_all(8)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)

	var v := Ui.vbox(4)
	panel.add_child(v)

	# Row 1: Orbit, Climate, Special
	var row1 := Ui.hbox(6)
	v.add_child(row1)

	var orbit_lbl := Ui.label("Orbit %d" % (p.orbit + 1), "Muted")
	row1.add_child(orbit_lbl)

	var climate_name: String = Copy.t("climate.%s.name" % p.climate)
	var climate_lbl := Ui.label(climate_name)
	row1.add_child(climate_lbl)

	if p.special != "":
		var sp_name: String = Copy.t("special.%s.name" % p.special)
		var sp_lbl := Ui.label("(%s)" % sp_name, "Gold")
		row1.add_child(sp_lbl)

	# Row 2: Size, Minerals, Max Pop
	var row2 := Ui.hbox(8)
	v.add_child(row2)

	var sz_name: String = Copy.t("ui.size.%s" % p.size)
	var sz_lbl := Ui.label(sz_name, "Muted")
	row2.add_child(sz_lbl)

	var min_name: String = Copy.t("ui.minerals.%s" % p.minerals)
	var min_lbl := Ui.label(min_name, "Muted")
	row2.add_child(min_lbl)

	var max_pop: int = 0
	if db != null:
		var empty_flags: Array[String] = []
		max_pop = Habitability.max_pop(db, player_traits, p, empty_flags)
	var pop_lbl := Ui.label("max pop %d" % max_pop, "OK" if max_pop >= 8 else "Muted")
	row2.add_child(pop_lbl)

	# Row 3: Colony info (if colonized)
	var col_id: int = -1
	if state != null:
		for cid in state.colonies.keys():
			var c: Colony = state.colonies[cid]
			if c.planet_id == p.id:
				col_id = cid
				break
	if col_id != -1:
		var c: Colony = state.colonies[col_id]
		var col_row := Ui.hbox(8)
		v.add_child(col_row)
		var sp_key: String = "race.%s.species" % c.species
		var sp_name: String = Copy.t(sp_key) if Copy.has(sp_key) else c.species.capitalize()
		var col_lbl := Ui.label("Colony: %s (%d pop)" % [sp_name, c.pop_units()], "Gold")
		col_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col_row.add_child(col_lbl)
		var btn_view := Ui.button("Manage", func() -> void:
			colony_selected.emit(col_id)
		)
		btn_view.custom_minimum_size = Vector2(70, 24)
		col_row.add_child(btn_view)

	return panel
