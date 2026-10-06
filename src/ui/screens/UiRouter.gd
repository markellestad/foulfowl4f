class_name UiRouter
extends Control

const SCREENS: Dictionary = {
	&"main_menu": preload("res://src/ui/screens/MainMenu.gd"),
	&"credits": preload("res://src/ui/screens/CreditsScreen.gd")
}

var _stack: Array[ScreenBase] = []

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)

func show_screen(id: StringName, p: Dictionary = {}) -> ScreenBase:
	if not SCREENS.has(id):
		push_error("Unknown screen: " + str(id))
		return null
	var script: Script = SCREENS[id]
	var screen: ScreenBase = script.new() as ScreenBase
	screen.setup(p)
	screen.router = self
	if not _stack.is_empty():
		var cur: ScreenBase = _stack[-1]
		cur.hide()
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
