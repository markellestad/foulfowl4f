class_name RangeStrip
extends Control

var distance: int = 10
var party_a_name: String = "Left"
var party_b_name: String = "Right"

func _init() -> void:
	custom_minimum_size = Vector2(800, 48)
	tooltip_text = Copy.t("ui.battle.range_strip.tip")

func set_distance(d: int) -> void:
	distance = clampi(d, 0, 12)
	queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0 or h <= 0:
		w = 1200.0
		h = 48.0

	var margin_x: float = 60.0
	var track_w: float = w - (margin_x * 2.0)
	var track_y: float = h * 0.5

	# Background bar
	draw_rect(Rect2(0, 0, w, h), Color(0.08, 0.09, 0.12, 0.9))
	draw_line(Vector2(0, h), Vector2(w, h), Color(0.2, 0.22, 0.28, 1.0), 1.0)

	# Band regions under track
	var x0: float = margin_x
	var x3: float = margin_x + (track_w * (3.0 / 12.0))
	var x7: float = margin_x + (track_w * (7.0 / 12.0))
	var x12: float = margin_x + track_w

	# Band backgrounds
	draw_rect(Rect2(x0, 4, x3 - x0, h - 8), Color(0.6, 0.2, 0.2, 0.2)) # Beak
	draw_rect(Rect2(x3, 4, x7 - x3, h - 8), Color(0.8, 0.6, 0.1, 0.2)) # Talon
	draw_rect(Rect2(x7, 4, x12 - x7, h - 8), Color(0.2, 0.5, 0.7, 0.2)) # Horizon

	# Track line
	draw_line(Vector2(x0, track_y), Vector2(x12, track_y), Color(0.4, 0.45, 0.55), 2.0)

	# Band words
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 14
	if font != null:
		draw_string(font, Vector2(x0 + 10, track_y - 8), "Beak (0-3)", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.9, 0.5, 0.5))
		draw_string(font, Vector2(x3 + 10, track_y - 8), "Talon (3-7)", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.8, 0.4))
		draw_string(font, Vector2(x7 + 10, track_y - 8), "Horizon (7-12)", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.5, 0.8, 1.0))

	# Ticks 0..12
	for i in range(13):
		var tx: float = margin_x + (track_w * (float(i) / 12.0))
		var tick_h: float = 8.0 if (i == 0 or i == 3 or i == 7 or i == 12) else 4.0
		draw_line(Vector2(tx, track_y - tick_h), Vector2(tx, track_y + tick_h), Color(0.6, 0.65, 0.75), 1.5)
		if font != null:
			draw_string(font, Vector2(tx - 4, track_y + 18), str(i), HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(0.7, 0.75, 0.85))

	# Marker for current distance
	var mx: float = margin_x + (track_w * (float(distance) / 12.0))
	var marker_pts := PackedVector2Array([
		Vector2(mx, track_y - 12),
		Vector2(mx + 8, track_y - 2),
		Vector2(mx, track_y + 8),
		Vector2(mx - 8, track_y - 2)
	])
	draw_colored_polygon(marker_pts, Color(1.0, 0.9, 0.2, 0.95))
	draw_polyline(marker_pts, Color(1.0, 1.0, 1.0), 1.5)
