class_name MapCamera
extends Camera2D

signal zoom_changed(zoom_level: float)

const MIN_ZOOM: float = 0.35
const MAX_ZOOM: float = 3.0
const PAN_SPEED: float = 600.0

var map_width_px: float = 1760.0
var map_height_px: float = 1200.0
var player_homeworld_pos: Vector2 = Vector2.ZERO

var _is_dragging: bool = false
var _last_drag_pos: Vector2 = Vector2.ZERO

func setup(w_px: float, h_px: float, hw_pos: Vector2) -> void:
	map_width_px = w_px
	map_height_px = h_px
	player_homeworld_pos = hw_pos
	center_on(player_homeworld_pos)
	zoom = Vector2(1.0, 1.0)
	zoom_changed.emit(zoom.x)

func center_on(pos: Vector2) -> void:
	position = pos
	_clamp_position()

func zoom_by(factor: float) -> void:
	var old_z: float = zoom.x
	var new_z: float = clampf(old_z * factor, MIN_ZOOM, MAX_ZOOM)
	if new_z != old_z:
		zoom = Vector2(new_z, new_z)
		_clamp_position()
		zoom_changed.emit(new_z)

func _zoom_at_point(factor: float, point: Vector2) -> void:
	var old_z: float = zoom.x
	var new_z: float = clampf(old_z * factor, MIN_ZOOM, MAX_ZOOM)
	if new_z == old_z:
		return
	var mouse_world: Vector2 = get_global_mouse_position()
	zoom = Vector2(new_z, new_z)
	var new_mouse_world: Vector2 = get_global_mouse_position()
	position += (mouse_world - new_mouse_world)
	_clamp_position()
	zoom_changed.emit(new_z)

func _clamp_position() -> void:
	var min_x: float = -200.0
	var max_x: float = map_width_px + 200.0
	var min_y: float = -200.0
	var max_y: float = map_height_px + 200.0
	position.x = clampf(position.x, min_x, max_x)
	position.y = clampf(position.y, min_y, max_y)

func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0

	if dir != Vector2.ZERO:
		position += dir.normalized() * (PAN_SPEED * delta / zoom.x)
		_clamp_position()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_is_dragging = mb.pressed
			_last_drag_pos = mb.position
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at_point(1.15, mb.position)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at_point(1.0 / 1.15, mb.position)
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and _is_dragging:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		position -= mm.relative / zoom.x
		_clamp_position()
		get_viewport().set_input_as_handled()

	elif event is InputEventKey:
		var ek: InputEventKey = event as InputEventKey
		if ek.pressed and ek.keycode == KEY_HOME:
			center_on(player_homeworld_pos)
			get_viewport().set_input_as_handled()
