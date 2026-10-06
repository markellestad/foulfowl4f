class_name EmpireStyle
extends RefCounted

static func race_color(race: String) -> Color:
	var r: String = race.to_lower()
	return Palette.EMPIRE.get(r, Color("#d55e00"))

static func draw_glyph(canvas: CanvasItem, glyph: String, pos: Vector2, size: float, color: Color) -> void:
	var h: float = size * 0.5
	match glyph:
		"crown":
			# Crown with 3 peaks
			var pts := PackedVector2Array([
				pos + Vector2(-h, h),
				pos + Vector2(-h, -h * 0.4),
				pos + Vector2(-h * 0.5, h * 0.2),
				pos + Vector2(0.0, -h),
				pos + Vector2(h * 0.5, h * 0.2),
				pos + Vector2(h, -h * 0.4),
				pos + Vector2(h, h)
			])
			canvas.draw_colored_polygon(pts, color)
		"triangle":
			# Equilateral-like triangle pointing up
			var pts := PackedVector2Array([
				pos + Vector2(0.0, -h),
				pos + Vector2(h, h),
				pos + Vector2(-h, h)
			])
			canvas.draw_colored_polygon(pts, color)
		"circle":
			# Filled circle (never a ring: planets/stars are round, effect rings forbidden)
			canvas.draw_circle(pos, h, color)
		"diamond":
			# Diamond / rhombus
			var pts := PackedVector2Array([
				pos + Vector2(0.0, -h),
				pos + Vector2(h, 0.0),
				pos + Vector2(0.0, h),
				pos + Vector2(-h, 0.0)
			])
			canvas.draw_colored_polygon(pts, color)
		"square":
			# Filled square
			canvas.draw_rect(Rect2(pos.x - h, pos.y - h, size, size), color)
		"cross":
			# Plus / cross shape
			var t: float = maxf(1.0, size * 0.3)
			var th: float = t * 0.5
			canvas.draw_rect(Rect2(pos.x - th, pos.y - h, t, size), color)
			canvas.draw_rect(Rect2(pos.x - h, pos.y - th, size, t), color)
		"chevron":
			# Chevron pointing up
			var pts := PackedVector2Array([
				pos + Vector2(0.0, -h),
				pos + Vector2(h, 0.0),
				pos + Vector2(h * 0.5, 0.0),
				pos + Vector2(0.0, -h * 0.5),
				pos + Vector2(-h * 0.5, 0.0),
				pos + Vector2(-h, 0.0)
			])
			canvas.draw_colored_polygon(pts, color)
		"comb":
			# Comb shape: top bar with 3 teeth
			var t: float = maxf(1.0, size * 0.25)
			# Top bar
			canvas.draw_rect(Rect2(pos.x - h, pos.y - h, size, t), color)
			# Left tooth
			canvas.draw_rect(Rect2(pos.x - h, pos.y - h, t, size), color)
			# Center tooth
			canvas.draw_rect(Rect2(pos.x - t * 0.5, pos.y - h, t, size), color)
			# Right tooth
			canvas.draw_rect(Rect2(pos.x + h - t, pos.y - h, t, size), color)
		_:
			# Default: diamond
			var pts := PackedVector2Array([
				pos + Vector2(0.0, -h),
				pos + Vector2(h, 0.0),
				pos + Vector2(0.0, h),
				pos + Vector2(-h, 0.0)
			])
			canvas.draw_colored_polygon(pts, color)
