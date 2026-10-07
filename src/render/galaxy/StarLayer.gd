class_name StarLayer
extends Node2D

const STAR_COLORS: Dictionary = {
	"yellow": Color("#ffdd66"),
	"orange": Color("#ff9944"),
	"red": Color("#ff5544"),
	"blue": Color("#66bbff"),
	"white": Color("#ffffff"),
	"neutron": Color("#bb88ff"),
	"black_hole": Color("#8844aa")
}

var state: GameState = null
var db: ContentDB = null
var selected_system_id: int = -1
var current_zoom: float = 1.0

var _font: Font = null
var _font_size: int = 14

func setup(p_state: GameState, p_db: ContentDB) -> void:
	state = p_state
	db = p_db
	queue_redraw()

func set_selected_system(sys_id: int) -> void:
	if selected_system_id != sys_id:
		selected_system_id = sys_id
		queue_redraw()

func set_zoom(zoom: float) -> void:
	var prev_bucket: bool = current_zoom >= 0.45
	current_zoom = zoom
	var new_bucket: bool = current_zoom >= 0.45
	if prev_bucket != new_bucket:
		queue_redraw()

func _ensure_font() -> void:
	if _font == null:
		var root_theme: Theme = ThemeDB.get_project_theme()
		if root_theme != null and root_theme.default_font != null:
			_font = root_theme.default_font
			_font_size = max(14, root_theme.default_font_size)
		else:
			_font = ThemeDB.fallback_font
			_font_size = 14

func _draw() -> void:
	if state == null:
		return
	_ensure_font()

	var races_table: Dictionary = db.table("races") if db != null else {}
	var race_rows: Dictionary = races_table.get("rows", {})

	# 1. Draw wormhole dashed lines (drawn under stars)
	for sys in state.systems:
		if sys.wormhole_to != -1 and sys.id < sys.wormhole_to:
			var target_sys: StarSystem = state.systems[sys.wormhole_to]
			var p1 := Vector2(sys.x * 4.0, sys.y * 4.0)
			var p2 := Vector2(target_sys.x * 4.0, target_sys.y * 4.0)
			draw_dashed_line(p1, p2, Color(Palette.MUTED.r, Palette.MUTED.g, Palette.MUTED.b, 0.5), 1.5, 8.0)

	# 2. Draw stars
	var show_names: bool = current_zoom >= 0.45

	for sys in state.systems:
		var pos := Vector2(sys.x * 4.0, sys.y * 4.0)
		var base_col: Color = STAR_COLORS.get(sys.star_type, Color("#ffffff"))
		if sys.is_orn:
			base_col = Palette.GOLD

		# Soft glow: three filled circles of falling alpha (never rings!)
		draw_circle(pos, 16.0, Color(base_col.r, base_col.g, base_col.b, 0.08))
		draw_circle(pos, 10.0, Color(base_col.r, base_col.g, base_col.b, 0.16))
		draw_circle(pos, 6.0, Color(base_col.r, base_col.g, base_col.b, 0.32))

		# Four diffraction spikes (two crossed lines, tapered alpha)
		var spike_col := Color(base_col.r, base_col.g, base_col.b, 0.6)
		draw_line(pos + Vector2(-16, 0), pos + Vector2(16, 0), spike_col, 1.0)
		draw_line(pos + Vector2(0, -16), pos + Vector2(0, 16), spike_col, 1.0)

		# Star core
		draw_circle(pos, 3.5, Color.WHITE.lerp(base_col, 0.5))

		# Selection indicator (brackets, not a ring!)
		if sys.id == selected_system_id:
			var b_sz: float = 12.0
			var b_arm: float = 4.0
			var b_col: Color = Palette.GOLD
			# Top-left
			draw_line(pos + Vector2(-b_sz, -b_sz), pos + Vector2(-b_sz + b_arm, -b_sz), b_col, 1.5)
			draw_line(pos + Vector2(-b_sz, -b_sz), pos + Vector2(-b_sz, -b_sz + b_arm), b_col, 1.5)
			# Top-right
			draw_line(pos + Vector2(b_sz, -b_sz), pos + Vector2(b_sz - b_arm, -b_sz), b_col, 1.5)
			draw_line(pos + Vector2(b_sz, -b_sz), pos + Vector2(b_sz, -b_sz + b_arm), b_col, 1.5)
			# Bottom-left
			draw_line(pos + Vector2(-b_sz, b_sz), pos + Vector2(-b_sz + b_arm, b_sz), b_col, 1.5)
			draw_line(pos + Vector2(-b_sz, b_sz), pos + Vector2(-b_sz, b_sz - b_arm), b_col, 1.5)
			# Bottom-right
			draw_line(pos + Vector2(b_sz, b_sz), pos + Vector2(b_sz - b_arm, b_sz), b_col, 1.5)
			draw_line(pos + Vector2(b_sz, b_sz), pos + Vector2(b_sz, b_sz - b_arm), b_col, 1.5)

		# Check system owner from colonies or home_of
		var owner_empire_id: int = -1
		if state != null:
			for pid in sys.planet_ids:
				for cid in state.colonies.keys():
					var col: Colony = state.colonies[cid]
					if col.planet_id == pid:
						owner_empire_id = col.owner
						break
				if owner_empire_id != -1:
					break

		if owner_empire_id == -1 and sys.home_of != -1:
			owner_empire_id = sys.home_of

		var owner_race: String = ""
		if state != null and owner_empire_id >= 0 and owner_empire_id < state.empires.size():
			owner_race = state.empires[owner_empire_id].race
		elif Session.settings != null and owner_empire_id >= 0 and owner_empire_id < Session.settings.seats.size():
			owner_race = Session.settings.seats[owner_empire_id]

		# Star name & owner glyph
		var s_name: String = ""
		if sys.is_orn:
			s_name = Copy.t("place.orn.name")
		elif sys.name_id > 0:
			s_name = Copy.t("star.name.%d" % sys.name_id)

		var text_y_offset: float = 18.0
		if show_names and s_name != "":
			var str_sz: Vector2 = _font.get_string_size(s_name, HORIZONTAL_ALIGNMENT_CENTER, -1, _font_size)
			var text_pos := Vector2(pos.x - str_sz.x * 0.5, pos.y + text_y_offset)
			var text_color: Color = Palette.TEXT
			if owner_race != "" and Palette.EMPIRE.has(owner_race):
				text_color = Palette.EMPIRE[owner_race]
			draw_string(_font, text_pos, s_name, HORIZONTAL_ALIGNMENT_CENTER, -1, _font_size, text_color)

		if owner_race != "":
			var rdef: Dictionary = race_rows.get(owner_race, {})
			var glyph: String = str(rdef.get("glyph", "circle"))
			var emp_col: Color = Palette.EMPIRE.get(owner_race, Palette.GOLD)
			var glyph_y: float = pos.y + (32.0 if show_names else 16.0)
			EmpireStyle.draw_glyph(self, glyph, Vector2(pos.x, glyph_y), 10.0, emp_col)
