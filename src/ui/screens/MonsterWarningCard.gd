class_name MonsterWarningCard
extends PanelContainer

signal closed

func _init() -> void:
	custom_minimum_size = Vector2(480, 320)
	build_ui()

func build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	add_child(vbox)

	var title := Label.new()
	title.text = "GUARDIAN OF ORN"
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var roar_label := Label.new()
	roar_label.text = "\"AN IMMENSE CYCLOPEAN TERROR GUARDS THE NEST AT ORN. IT DRIFTS MOTIONLESS, BROODING UPON AN ANCIENT CLUTCH.\""
	roar_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	roar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(roar_label)

	var warn_label := Label.new()
	warn_label.text = "Warning: Any fleet that confronts the Guardian and retreats will bear the Guardian's Mark (-10% combat damage across all bands) for 10 turns."
	warn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(warn_label)

	var ok_btn := Button.new()
	ok_btn.text = "Acknowledge"
	ok_btn.custom_minimum_size = Vector2(160, 36)
	ok_btn.pressed.connect(func(): closed.emit())
	vbox.add_child(ok_btn)
