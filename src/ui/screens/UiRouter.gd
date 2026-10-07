class_name UiRouter
extends Control

const SCREENS: Dictionary = {
	&"main_menu": preload("res://src/ui/screens/MainMenu.gd"),
	&"credits": preload("res://src/ui/screens/CreditsScreen.gd"),
	&"new_game": preload("res://src/ui/screens/NewGameScreen.gd"),
	&"galaxy": preload("res://src/ui/screens/GalaxyScreen.gd"),
	&"colonies_list": preload("res://src/ui/screens/ColoniesListScreen.gd"),
	&"fleets_list": preload("res://src/ui/screens/FleetsListScreen.gd"),
	&"ship_designer": preload("res://src/ui/screens/ShipDesignerScreen.gd"),
	&"turn_summary": preload("res://src/ui/screens/TurnSummaryScreen.gd"),
	&"battle_screen": preload("res://src/ui/screens/BattleScreen.gd"),
	&"battle_orders": preload("res://src/ui/screens/BattleOrdersCard.gd"),
	&"diplomacy": preload("res://src/ui/screens/DiplomacyScreen.gd"),
	&"victory": preload("res://src/ui/screens/VictoryScreen.gd")
}

var _stack: Array[ScreenBase] = []

func _ready() -> void:
	_sync_size()
	var vp: Viewport = get_viewport()
	if vp != null:
		vp.size_changed.connect(_sync_size)

func _sync_size() -> void:
	var vp: Viewport = get_viewport()
	var vp_size: Vector2 = Vector2(1280, 720)
	if vp != null:
		var s: Vector2 = vp.get_visible_rect().size
		if s != Vector2.ZERO:
			vp_size = s
	size = vp_size
	custom_minimum_size = vp_size

func show_screen(id: StringName, p: Dictionary = {}) -> ScreenBase:
	if not SCREENS.has(id):
		push_error("Unknown screen: " + str(id))
		return null
	_sync_size()
	var script: Script = SCREENS[id]
	var screen: ScreenBase = script.new() as ScreenBase
	screen.setup(p)
	screen.router = self
	if not _stack.is_empty():
		var cur: ScreenBase = _stack[-1]
		cur.hide()
	screen.anchor_left = 0.0
	screen.anchor_top = 0.0
	screen.anchor_right = 1.0
	screen.anchor_bottom = 1.0
	screen.offset_left = 0.0
	screen.offset_top = 0.0
	screen.offset_right = 0.0
	screen.offset_bottom = 0.0
	_stack.append(screen)
	add_child(screen)
	return screen

func back() -> void:
	if _stack.size() <= 1:
		return
	var cur: ScreenBase = _stack.pop_back()
	cur.queue_free()
	if not _stack.is_empty():
		var prev: ScreenBase = _stack[-1]
		prev.show()

func current() -> ScreenBase:
	if _stack.is_empty():
		return null
	return _stack[-1]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or (event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE):
		var cur: ScreenBase = current()
		if cur != null:
			cur.on_back()
			get_viewport().set_input_as_handled()
