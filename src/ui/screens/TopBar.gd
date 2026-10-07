class_name TopBar
extends PanelContainer

signal colonies_requested
signal fleets_requested
signal designer_requested
signal diplomacy_requested
signal overlay_toggle_requested
signal menu_requested

var _lbl_turn: Label = null
var _lbl_credits: Label = null
var _lbl_food: Label = null
var _lbl_research: Label = null
var _btn_overlay: Button = null
var _btn_fleets: Button = null
var _btn_designer: Button = null
var _btn_diplo: Button = null
var _btn_colonies: Button = null
var _btn_undo: Button = null
var _btn_redo: Button = null
var _btn_menu: Button = null
var _btn_end_turn: Button = null

func _ready() -> void:
	custom_minimum_size.y = 44
	_build_ui()
	_connect_session()
	refresh()

func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.PANEL
	style.border_color = Palette.LINE
	style.border_width_bottom = 1
	style.set_content_margin_all(6)
	add_theme_stylebox_override("panel", style)

	var hbox := Ui.hbox(8)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(hbox)

	_lbl_turn = Ui.label("Turn: 1", "Heading")
	hbox.add_child(_lbl_turn)

	hbox.add_child(Ui.spacer(6))

	_lbl_credits = Ui.label("Credits: 0 (+0)", "Gold")
	hbox.add_child(_lbl_credits)

	_lbl_food = Ui.label("Food: 0 (+0)")
	hbox.add_child(_lbl_food)

	_lbl_research = Ui.label("Research: —", "Muted")
	hbox.add_child(_lbl_research)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	_btn_overlay = Ui.button(Copy.t("ui.label.range_overlay"), _on_overlay, "Toggle Range Overlay (1)")
	hbox.add_child(_btn_overlay)

	_btn_fleets = Ui.button("Fleets", _on_fleets, "Fleets List (F)")
	hbox.add_child(_btn_fleets)

	_btn_designer = Ui.button("Designer", _on_designer, "Ship Designer (D)")
	hbox.add_child(_btn_designer)

	_btn_diplo = Ui.button("Diplomacy", _on_diplo, "Diplomacy")
	hbox.add_child(_btn_diplo)

	_btn_colonies = Ui.button(Copy.t("ui.label.colonies"), _on_colonies, "Colonies (Tab)")
	hbox.add_child(_btn_colonies)

	_btn_undo = Ui.button(Copy.t("ui.label.undo"), _on_undo, "Undo (Ctrl+Z)")
	hbox.add_child(_btn_undo)

	_btn_redo = Ui.button(Copy.t("ui.label.redo"), _on_redo, "Redo (Ctrl+Y)")
	hbox.add_child(_btn_redo)

	_btn_menu = Ui.button(Copy.t("ui.label.menu"), _on_menu, "Menu (Esc)")
	hbox.add_child(_btn_menu)

	_btn_end_turn = Ui.button(Copy.t("ui.label.next_turn"), _on_end_turn, "End Turn (Space)")
	_btn_end_turn.custom_minimum_size.x = 90
	hbox.add_child(_btn_end_turn)

func _connect_session() -> void:
	if not Session.state_changed.is_connected(_on_state_changed):
		Session.state_changed.connect(_on_state_changed)
	if not Session.turn_processing.is_connected(_on_turn_processing):
		Session.turn_processing.connect(_on_turn_processing)
	if not Session.turn_started.is_connected(_on_turn_started):
		Session.turn_started.connect(_on_turn_started)

func _on_state_changed(_scope: String, _ids: Array) -> void:
	refresh()

func _on_turn_processing(pct: int) -> void:
	if _btn_end_turn != null:
		_btn_end_turn.disabled = true
		_btn_end_turn.text = "%d%%" % pct

func _on_turn_started(_report: TurnReport) -> void:
	refresh()

func refresh() -> void:
	if Session.game == null or Session.state == null:
		return

	var gs: GameState = Session.state
	_lbl_turn.text = "%s: %d" % [Copy.t("ui.label.turn"), gs.turn]

	var totals: Dictionary = Economy.empire_totals(Session.db, gs, 0)
	var treasury: int = gs.empires[0].treasury if not gs.empires.is_empty() else 0
	var net_cr: int = int(totals.get("net_credits", 0))
	_lbl_credits.text = "%s: %d (%+d)" % [Copy.t("ui.label.credits"), treasury, net_cr]
	_lbl_credits.tooltip_text = "Income: +%d (Taxes: %d, Flat: %d, Food Sale: %d)\nExpenses: -%d (Upkeep: %d, Admin: %d)\nNet: %+d" % [
		int(totals.get("income", 0)),
		int(totals.get("taxes", 0)),
		int(totals.get("credits_flat", 0)),
		int(totals.get("food_sale_cr", 0)),
		int(totals.get("expenses", 0)),
		int(totals.get("upkeep", 0)),
		int(totals.get("admin", 0)),
		net_cr
	]

	var food_tot: int = int(totals.get("food", 0))
	var food_bal: int = int(totals.get("food_balance", 0))
	_lbl_food.text = "%s: %d (%+d)" % [Copy.t("ui.label.food"), food_tot, food_bal]
	_lbl_food.tooltip_text = "Produced: %d\nEaten: %d\nBalance: %+d" % [
		food_tot,
		int(totals.get("food_need", 0)),
		food_bal
	]

	_lbl_research.text = "%s: —" % Copy.t("ui.label.research")

	var is_running: bool = Session.is_turn_running()
	_btn_end_turn.disabled = is_running
	_btn_end_turn.text = Copy.t("ui.label.next_turn")
	_btn_end_turn.tooltip_text = Copy.t("ui.label.next_turn") + " (Space)"
	_btn_undo.disabled = is_running or not Session.can_undo()
	_btn_redo.disabled = is_running or not Session.can_redo()
	_btn_colonies.disabled = is_running

func _on_colonies() -> void:
	colonies_requested.emit()

func _on_fleets() -> void:
	fleets_requested.emit()

func _on_designer() -> void:
	designer_requested.emit()

func _on_diplo() -> void:
	diplomacy_requested.emit()

func _on_overlay() -> void:
	overlay_toggle_requested.emit()

func _on_undo() -> void:
	Session.undo()

func _on_redo() -> void:
	Session.redo()

func _on_menu() -> void:
	menu_requested.emit()

func _on_end_turn() -> void:
	if not Session.is_turn_running():
		Session.end_turn()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	var key := event as InputEventKey
	if key.is_action_pressed(&"ui_cancel") or key.keycode == KEY_ESCAPE:
		_on_menu()
		get_viewport().set_input_as_handled()
		return

	if key.keycode == KEY_TAB:
		_on_colonies()
		get_viewport().set_input_as_handled()
		return

	if not key.ctrl_pressed and not key.alt_pressed:
		if key.keycode == KEY_1:
			_on_overlay()
			get_viewport().set_input_as_handled()
			return
		elif key.keycode == KEY_F:
			_on_fleets()
			get_viewport().set_input_as_handled()
			return
		elif key.keycode == KEY_D:
			_on_designer()
			get_viewport().set_input_as_handled()
			return

	if key.ctrl_pressed:
		if key.keycode == KEY_Z:
			if key.shift_pressed:
				_on_redo()
			else:
				_on_undo()
			get_viewport().set_input_as_handled()
			return
		elif key.keycode == KEY_Y:
			_on_redo()
			get_viewport().set_input_as_handled()
			return

	if key.keycode == KEY_SPACE or key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		_on_end_turn()
		get_viewport().set_input_as_handled()
		return
