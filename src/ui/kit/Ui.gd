class_name Ui
extends RefCounted

static func label(text: String, variation: String = "") -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = StringName(variation)
	return l

static func button(text: String, on_press: Callable, tooltip: String = "") -> Button:
	var b := Button.new()
	b.text = text
	if tooltip != "":
		b.tooltip_text = tooltip
	b.pressed.connect(func() -> void:
		Sfx.play("ui_click")
		if on_press.is_valid():
			on_press.call()
	)
	return b

static func vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func panel() -> PanelContainer:
	return PanelContainer.new()

static func spacer(px: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(px, px)
	return c

static func fixed_width(c: Control, px: int) -> Control:
	c.custom_minimum_size.x = px
	return c
