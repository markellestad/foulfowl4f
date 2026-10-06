class_name AutopsyCard
extends PanelContainer

signal closed

var title_label: Label
var winner_label: Label
var band_label: Label
var standout_label: Label
var receipt_label: Label
var close_btn: Button

func _init() -> void:
	custom_minimum_size = Vector2(400, 260)
	build_ui()

func build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	title_label = Label.new()
	title_label.text = "Battle Autopsy"
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	winner_label = Label.new()
	winner_label.text = "Result: Decisive"
	vbox.add_child(winner_label)

	band_label = Label.new()
	band_label.text = "Deciding Band: Talon"
	vbox.add_child(band_label)

	standout_label = Label.new()
	standout_label.text = "Standout Ship: None"
	vbox.add_child(standout_label)

	receipt_label = Label.new()
	receipt_label.text = "Receipt: None"
	vbox.add_child(receipt_label)

	close_btn = Button.new()
	close_btn.text = "Continue"
	close_btn.pressed.connect(func(): closed.emit())
	vbox.add_child(close_btn)

func setup(autopsy_data: Dictionary, winner_name: String = "", is_stalemate: bool = false) -> void:
	if is_stalemate:
		winner_label.text = "Result: Stalemate (both sides withdrew)"
	elif winner_name != "":
		winner_label.text = "Victor: %s" % winner_name
	else:
		winner_label.text = "Result: Combat Concluded"

	var band_str: String = str(autopsy_data.get("deciding_band", "talon")).capitalize()
	band_label.text = "Deciding Band: %s" % band_str

	var s_name: String = str(autopsy_data.get("standout_name", "None"))
	var s_dmg: int = int(autopsy_data.get("standout_damage", 0))
	if s_name != "None" and s_dmg > 0:
		standout_label.text = "Standout Ship: %s (%d dmg)" % [s_name, s_dmg]
	else:
		standout_label.text = "Standout Ship: None"

	var receipt: String = str(autopsy_data.get("receipt_text", ""))
	if receipt != "":
		receipt_label.text = "Sacrificed on Retreat: %s" % receipt
	else:
		receipt_label.text = "Retreat: No retreat"
