class_name BattleStage
extends Node2D

const VfxLayerClass = preload("res://src/render/battle/VfxLayer.gd")
const ShipGlyphClass = preload("res://src/render/battle/ShipGlyph.gd")

var left_glyphs: Dictionary = {} # uid -> Node2D
var right_glyphs: Dictionary = {} # uid -> Node2D
var vfx = null

var left_header: Label = null
var right_header: Label = null

var current_distance: int = 10
var stage_width: float = 1280.0
var stage_height: float = 720.0

func _init() -> void:
	vfx = VfxLayerClass.new()
	add_child(vfx)

	left_header = Label.new()
	left_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_header.add_theme_font_size_override("font_size", 15)
	add_child(left_header)

	right_header = Label.new()
	right_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_header.add_theme_font_size_override("font_size", 15)
	add_child(right_header)

func set_headers(left_text: String, col_left: Color, right_text: String, col_right: Color) -> void:
	left_header.text = left_text
	left_header.add_theme_color_override("font_color", col_left)
	right_header.text = right_text
	right_header.add_theme_color_override("font_color", col_right)
	update_header_positions()

func update_header_positions() -> void:
	var center_x: float = stage_width * 0.5
	var offset: float = 60.0 + (float(current_distance) * 28.0)
	left_header.size = Vector2(260, 24)
	left_header.position = Vector2(center_x - offset - 130.0, 95.0)
	right_header.size = Vector2(260, 24)
	right_header.position = Vector2(center_x + offset - 130.0, 95.0)

func setup_parties(left_units: Array, right_units: Array, col_left: Color, col_right: Color) -> void:
	for g in left_glyphs.values():
		g.queue_free()
	for g in right_glyphs.values():
		g.queue_free()
	left_glyphs.clear()
	right_glyphs.clear()

	for u in left_units:
		var g = ShipGlyphClass.new()
		g.setup(u, col_left, false)
		add_child(g)
		left_glyphs[int(u["uid"])] = g

	for u in right_units:
		var g = ShipGlyphClass.new()
		g.setup(u, col_right, true)
		add_child(g)
		right_glyphs[int(u["uid"])] = g

	update_positions()

func set_distance(d: int) -> void:
	current_distance = clampi(d, 0, 12)
	update_positions()

func update_positions() -> void:
	update_header_positions()
	var center_x: float = stage_width * 0.5
	var offset: float = 60.0 + (float(current_distance) * 28.0)
	var left_x: float = center_x - offset
	var right_x: float = center_x + offset

	var start_y: float = 160.0
	var avail_h: float = stage_height - 240.0

	var l_keys: Array = left_glyphs.keys()
	var l_step: float = avail_h / maxf(1.0, float(l_keys.size()))
	for i in range(l_keys.size()):
		var g = left_glyphs[l_keys[i]]
		var col_offset: float = -30.0 if (i % 2 == 1) else 0.0
		var gy: float = start_y + (float(i) * l_step)
		g.position = Vector2(left_x + col_offset, gy)

	var r_keys: Array = right_glyphs.keys()
	var r_step: float = avail_h / maxf(1.0, float(r_keys.size()))
	for i in range(r_keys.size()):
		var g = right_glyphs[r_keys[i]]
		var col_offset: float = 30.0 if (i % 2 == 1) else 0.0
		var gy: float = start_y + (float(i) * r_step)
		g.position = Vector2(right_x + col_offset, gy)

func get_unit_pos(uid: int) -> Vector2:
	if left_glyphs.has(uid):
		return left_glyphs[uid].position
	if right_glyphs.has(uid):
		return right_glyphs[uid].position
	return Vector2(stage_width * 0.5, stage_height * 0.5)

func get_glyph(uid: int):
	if left_glyphs.has(uid):
		return left_glyphs[uid]
	if right_glyphs.has(uid):
		return right_glyphs[uid]
	return null
