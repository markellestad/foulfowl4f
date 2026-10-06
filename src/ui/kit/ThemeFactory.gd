class_name ThemeFactory
extends RefCounted

static func build(scale_pct: int) -> Theme:
	var theme: Theme = Theme.new()
	var font_regular: FontFile = null
	if ResourceLoader.exists("res://assets/fonts/AtkinsonHyperlegible-Regular.ttf"):
		font_regular = load("res://assets/fonts/AtkinsonHyperlegible-Regular.ttf") as FontFile
	if font_regular != null:
		theme.default_font = font_regular

	var font_bold: FontFile = font_regular
	if ResourceLoader.exists("res://assets/fonts/AtkinsonHyperlegible-Bold.ttf"):
		var fb: FontFile = load("res://assets/fonts/AtkinsonHyperlegible-Bold.ttf") as FontFile
		if fb != null:
			font_bold = fb

	var base_size: int = IntMath.floor_div(16 * scale_pct, 100)
	if base_size < 14:
		base_size = 14
	theme.default_font_size = base_size

	theme.set_type_variation(&"HeadingLarge", &"Label")
	if font_bold != null:
		theme.set_font("font", &"HeadingLarge", font_bold)
	theme.set_font_size("font_size", &"HeadingLarge", IntMath.floor_div(40 * scale_pct, 100))
	theme.set_color("font_color", &"HeadingLarge", Palette.TEXT)

	theme.set_type_variation(&"Heading", &"Label")
	if font_bold != null:
		theme.set_font("font", &"Heading", font_bold)
	theme.set_font_size("font_size", &"Heading", IntMath.floor_div(24 * scale_pct, 100))
	theme.set_color("font_color", &"Heading", Palette.TEXT)

	theme.set_type_variation(&"Muted", &"Label")
	theme.set_color("font_color", &"Muted", Palette.MUTED)

	theme.set_type_variation(&"Gold", &"Label")
	theme.set_color("font_color", &"Gold", Palette.GOLD)

	var sb_panel := StyleBoxFlat.new()
	sb_panel.bg_color = Palette.PANEL
	theme.set_stylebox("panel", &"Panel", sb_panel)
	theme.set_stylebox("panel", &"PanelContainer", sb_panel)

	var sb_tooltip := StyleBoxFlat.new()
	sb_tooltip.bg_color = Palette.PANEL_ALT
	sb_tooltip.border_color = Palette.LINE
	sb_tooltip.set_border_width_all(1)
	theme.set_stylebox("panel", &"TooltipPanel", sb_tooltip)

	var sb_btn_normal := StyleBoxFlat.new()
	sb_btn_normal.bg_color = Palette.PANEL
	sb_btn_normal.border_color = Palette.LINE
	sb_btn_normal.set_border_width_all(1)
	sb_btn_normal.set_corner_radius_all(4)
	sb_btn_normal.content_margin_left = 12
	sb_btn_normal.content_margin_right = 12
	sb_btn_normal.content_margin_top = 8
	sb_btn_normal.content_margin_bottom = 8

	var sb_btn_hover := StyleBoxFlat.new()
	sb_btn_hover.bg_color = Palette.PANEL_ALT
	sb_btn_hover.border_color = Palette.GOLD
	sb_btn_hover.set_border_width_all(1)
	sb_btn_hover.set_corner_radius_all(4)
	sb_btn_hover.content_margin_left = 12
	sb_btn_hover.content_margin_right = 12
	sb_btn_hover.content_margin_top = 8
	sb_btn_hover.content_margin_bottom = 8

	var sb_btn_pressed := StyleBoxFlat.new()
	sb_btn_pressed.bg_color = Palette.BG
	sb_btn_pressed.border_color = Palette.GOLD
	sb_btn_pressed.set_border_width_all(1)
	sb_btn_pressed.set_corner_radius_all(4)
	sb_btn_pressed.content_margin_left = 12
	sb_btn_pressed.content_margin_right = 12
	sb_btn_pressed.content_margin_top = 8
	sb_btn_pressed.content_margin_bottom = 8

	var sb_btn_disabled := StyleBoxFlat.new()
	sb_btn_disabled.bg_color = Palette.BG
	sb_btn_disabled.border_color = Palette.LINE
	sb_btn_disabled.set_border_width_all(1)
	sb_btn_disabled.set_corner_radius_all(4)
	sb_btn_disabled.content_margin_left = 12
	sb_btn_disabled.content_margin_right = 12
	sb_btn_disabled.content_margin_top = 8
	sb_btn_disabled.content_margin_bottom = 8

	var sb_btn_focus := StyleBoxFlat.new()
	sb_btn_focus.draw_center = false
	sb_btn_focus.border_color = Palette.GOLD
	sb_btn_focus.set_border_width_all(1)
	sb_btn_focus.set_corner_radius_all(4)

	theme.set_stylebox("normal", &"Button", sb_btn_normal)
	theme.set_stylebox("hover", &"Button", sb_btn_hover)
	theme.set_stylebox("pressed", &"Button", sb_btn_pressed)
	theme.set_stylebox("disabled", &"Button", sb_btn_disabled)
	theme.set_stylebox("focus", &"Button", sb_btn_focus)
	theme.set_color("font_color", &"Button", Palette.TEXT)
	theme.set_color("font_disabled_color", &"Button", Palette.MUTED)
	theme.set_color("font_hover_color", &"Button", Palette.GOLD)
	theme.set_color("font_pressed_color", &"Button", Palette.TEXT)

	return theme
