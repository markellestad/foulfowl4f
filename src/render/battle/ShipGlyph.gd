class_name ShipGlyph
extends Node2D

var unit_uid: int = -1
var race: String = "pheasants"
var hull: String = "small"
var unit_name: String = "Ship"
var hp: int = 10
var hp_max: int = 10
var shield: int = 0
var facing_left: bool = false
var is_destroyed: bool = false
var color: Color = Color(0.85, 0.85, 0.9)
var _name_lbl: Label = null

func _init() -> void:
	_name_lbl = Label.new()
	_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_lbl.position = Vector2(-60, -28)
	_name_lbl.size = Vector2(120, 16)
	_name_lbl.add_theme_font_size_override("font_size", 11)
	_name_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95, 0.9))
	add_child(_name_lbl)

func setup(u_data: Dictionary, p_color: Color, p_facing_left: bool = false) -> void:
	unit_uid = int(u_data.get("uid", -1))
	unit_name = str(u_data.get("name_key", "Ship"))
	if _name_lbl != null:
		_name_lbl.text = unit_name
	hull = str(u_data.get("hull_id", "small"))
	hp = int(u_data.get("hp", 10))
	hp_max = maxi(1, int(u_data.get("hp_max", 10)))
	shield = int(u_data.get("shield", 0))
	color = p_color
	facing_left = p_facing_left
	is_destroyed = (hp <= 0)
	if _name_lbl != null and is_destroyed:
		_name_lbl.modulate.a = 0.3
	queue_redraw()

func set_hp(new_hp: int) -> void:
	hp = new_hp
	if hp <= 0:
		hp = 0
		is_destroyed = true
		if _name_lbl != null:
			_name_lbl.modulate.a = 0.3
	queue_redraw()

func _draw() -> void:
	if is_destroyed:
		# Draw dim wreck marker (crossed debris lines, no round blob)
		draw_line(Vector2(-5, -5), Vector2(5, 5), Color(0.4, 0.4, 0.4, 0.4), 1.5)
		draw_line(Vector2(-5, 5), Vector2(5, -5), Color(0.4, 0.4, 0.4, 0.4), 1.5)
		return

	var base_pts: PackedVector2Array = BirdShapes.side(race, hull)
	var scale_factor: float = 16.0
	var poly := PackedVector2Array()

	for p in base_pts:
		var px: float = p.x * scale_factor * (-1.0 if facing_left else 1.0)
		var py: float = p.y * scale_factor
		poly.append(Vector2(px, py))

	draw_colored_polygon(poly, color)
	draw_polyline(poly, Color(1, 1, 1, 0.6), 1.2)

	# Health bar
	var bar_w: float = 32.0
	var bar_h: float = 3.0
	var bar_y: float = 18.0
	var hp_pct: float = clampf(float(hp) / float(hp_max), 0.0, 1.0)

	draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w, bar_h), Color(0.2, 0.2, 0.2, 0.8))
	draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w * hp_pct, bar_h), Color(0.2, 0.85, 0.3, 0.9))

	if shield > 0:
		# Mini shield pip
		draw_rect(Rect2(-bar_w * 0.5, bar_y - 3, bar_w * 0.5, 2.0), Color(0.3, 0.7, 1.0, 0.8))
