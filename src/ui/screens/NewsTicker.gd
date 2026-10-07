class_name NewsTicker
extends PanelContainer

var _lbl: Label = null

func _init() -> void:
	custom_minimum_size.y = 28
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.12, 0.9)
	style.border_color = Palette.LINE
	style.border_width_top = 1
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	add_theme_stylebox_override("panel", style)

	_lbl = Label.new()
	_lbl.text = "PNN: The lanes are calm."
	_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl.tooltip_text = Copy.t("news.pnn.ident")
	add_child(_lbl)

func set_news(news_text: String) -> void:
	if news_text == "":
		_lbl.text = "PNN: " + Copy.t("news.pnn.ident") + " — All frequencies nominal."
	else:
		_lbl.text = "PNN: " + news_text
