class_name BirdShapes
extends RefCounted

# Normalized polygon shapes centered at (0, 0), facing UP (0, -1) with bounding radius ~1.0

const SHAPES: Dictionary = {
	"swans": [
		Vector2(0.0, -1.0),
		Vector2(0.2, -0.6),
		Vector2(0.9, 0.4),
		Vector2(0.5, 0.2),
		Vector2(0.0, 0.8),
		Vector2(-0.5, 0.2),
		Vector2(-0.9, 0.4),
		Vector2(-0.2, -0.6)
	],
	"pheasants": [
		Vector2(0.0, -0.9),
		Vector2(0.25, -0.4),
		Vector2(0.85, 0.1),
		Vector2(0.4, 0.2),
		Vector2(0.1, 1.0),
		Vector2(0.0, 1.1),
		Vector2(-0.1, 1.0),
		Vector2(-0.4, 0.2),
		Vector2(-0.85, 0.1),
		Vector2(-0.25, -0.4)
	],
	"ducks": [
		Vector2(0.0, -1.0),
		Vector2(0.3, -0.7),
		Vector2(0.8, 0.2),
		Vector2(0.4, 0.4),
		Vector2(0.0, 0.7),
		Vector2(-0.4, 0.4),
		Vector2(-0.8, 0.2),
		Vector2(-0.3, -0.7)
	],
	"owls": [
		Vector2(-0.25, -0.9),
		Vector2(0.0, -0.65),
		Vector2(0.25, -0.9),
		Vector2(0.4, -0.5),
		Vector2(0.85, 0.3),
		Vector2(0.3, 0.5),
		Vector2(0.0, 0.7),
		Vector2(-0.3, 0.5),
		Vector2(-0.85, 0.3),
		Vector2(-0.4, -0.5)
	],
	"penguins": [
		Vector2(0.0, -1.0),
		Vector2(0.3, -0.5),
		Vector2(0.7, 0.2),
		Vector2(0.35, 0.4),
		Vector2(0.2, 0.9),
		Vector2(-0.2, 0.9),
		Vector2(-0.35, 0.4),
		Vector2(-0.7, 0.2),
		Vector2(-0.3, -0.5)
	],
	"crows": [
		Vector2(0.0, -1.1),
		Vector2(0.15, -0.6),
		Vector2(0.9, 0.2),
		Vector2(0.45, 0.3),
		Vector2(0.0, 0.8),
		Vector2(-0.45, 0.3),
		Vector2(-0.9, 0.2),
		Vector2(-0.15, -0.6)
	],
	"geese": [
		Vector2(0.0, -1.1),
		Vector2(0.15, -0.4),
		Vector2(0.8, 0.3),
		Vector2(0.3, 0.3),
		Vector2(0.0, 0.6),
		Vector2(-0.3, 0.3),
		Vector2(-0.8, 0.3),
		Vector2(-0.15, -0.4)
	],
	"chickens": [
		Vector2(0.0, -1.0),
		Vector2(0.2, -0.8),
		Vector2(0.3, -0.4),
		Vector2(0.75, 0.2),
		Vector2(0.35, 0.4),
		Vector2(0.0, 0.7),
		Vector2(-0.35, 0.4),
		Vector2(-0.75, 0.2),
		Vector2(-0.3, -0.4),
		Vector2(-0.2, -0.8)
	]
}

static func icon(race: String) -> PackedVector2Array:
	var key: String = race.to_lower()
	if not SHAPES.has(key):
		key = "pheasants"
	var raw: Array = SHAPES[key]
	var res := PackedVector2Array()
	for v in raw:
		res.append(v as Vector2)
	return res

static func draw_icon(canvas: CanvasItem, race: String, pos: Vector2, size: float, color: Color, angle: float = 0.0) -> void:
	var base_pts: PackedVector2Array = icon(race)
	var xformed := PackedVector2Array()
	var cos_a: float = cos(angle)
	var sin_a: float = sin(angle)
	var half_sz: float = size * 0.5
	for p in base_pts:
		var sx: float = p.x * half_sz
		var sy: float = p.y * half_sz
		var rx: float = sx * cos_a - sy * sin_a
		var ry: float = sx * sin_a + sy * cos_a
		xformed.append(pos + Vector2(rx, ry))
	canvas.draw_colored_polygon(xformed, color)
