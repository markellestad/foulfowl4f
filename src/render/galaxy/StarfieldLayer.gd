class_name StarfieldLayer
extends Node2D

var _width: float = 1760.0
var _height: float = 1200.0
var _dots: PackedVector2Array = PackedVector2Array()
var _alphas: PackedFloat32Array = PackedFloat32Array()

func setup(map_width_px: float, map_height_px: float) -> void:
	_width = map_width_px
	_height = map_height_px
	_generate_dots()
	queue_redraw()

func _generate_dots() -> void:
	_dots.clear()
	_alphas.clear()
	var rng := Rng.new(7)
	var margin: float = 200.0
	var min_x: float = -margin
	var max_x: float = _width + margin
	var min_y: float = -margin
	var max_y: float = _height + margin

	var count: int = 600
	for i in range(count):
		var x: float = float(rng.range_i(int(min_x), int(max_x)))
		var y: float = float(rng.range_i(int(min_y), int(max_y)))
		var a: float = float(rng.range_i(12, 40)) / 100.0
		_dots.append(Vector2(x, y))
		_alphas.append(a)

func _draw() -> void:
	var base_col: Color = Palette.TEXT
	for i in range(_dots.size()):
		var pt: Vector2 = _dots[i]
		var col := Color(base_col.r, base_col.g, base_col.b, _alphas[i])
		draw_rect(Rect2(pt.x, pt.y, 1.5, 1.5), col)
