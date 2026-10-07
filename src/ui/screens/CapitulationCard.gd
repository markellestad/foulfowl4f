class_name CapitulationCard
extends Control

signal answered(accepted: bool)

var offer_id: int = -1
var leader_name: String = ""

func setup(p_offer_id: int, p_leader: String = "The enemy leader") -> void:
	offer_id = p_offer_id
	leader_name = p_leader
	build_ui()

func build_ui() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.6)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(480, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.PANEL
	style.border_color = Palette.LINE
	style.set_border_width_all(2)
	style.set_content_margin_all(20)
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	card.add_child(vbox)

	var title := Label.new()
	title.text = Copy.t("capitulation.card.title")
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var raw_body: String = Copy.t("capitulation.card.body")
	var body_text: String = raw_body.replace("{leader}", leader_name)
	var body_lbl := Label.new()
	body_lbl.text = body_text
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(body_lbl)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox)

	var btn_accept := Button.new()
	btn_accept.text = Copy.t("capitulation.card.accept")
	btn_accept.custom_minimum_size = Vector2(160, 36)
	btn_accept.pressed.connect(func(): _on_answer(true))
	hbox.add_child(btn_accept)

	var btn_decline := Button.new()
	btn_decline.text = Copy.t("capitulation.card.decline")
	btn_decline.custom_minimum_size = Vector2(160, 36)
	btn_decline.pressed.connect(func(): _on_answer(false))
	hbox.add_child(btn_decline)

func _on_answer(accept: bool) -> void:
	if Session.game != null and offer_id >= 0:
		var cmd := CmdAcceptCapitulation.new()
		cmd.empire_id = Session.player_empire_id
		cmd.offer_id = offer_id
		cmd.accept = accept
		Session.game.submit(cmd)
	answered.emit(accept)
	queue_free()
