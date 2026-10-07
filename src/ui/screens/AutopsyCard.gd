class_name AutopsyCard
extends PanelContainer

signal closed

const AUTOPSY_FLAVOR_KEYS: Array[String] = [
	"autopsy.flavor.1",
	"autopsy.flavor.2",
	"autopsy.flavor.3",
	"autopsy.flavor.4",
	"autopsy.flavor.5",
	"autopsy.flavor.6",
	"autopsy.flavor.7",
	"autopsy.flavor.8",
	"autopsy.flavor.9",
	"autopsy.flavor.10",
	"autopsy.flavor.11",
	"autopsy.flavor.12",
]

var title_label: Label
var winner_label: Label
var band_label: Label
var standout_label: Label
var receipt_label: Label
var flavor_label: Label
var close_btn: Button

func _init() -> void:
	custom_minimum_size = Vector2(440, 0)
	build_ui()

func build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	title_label = Label.new()
	title_label.text = Copy.t("autopsy.title")
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	winner_label = Label.new()
	winner_label.text = "Result: Decisive"
	vbox.add_child(winner_label)

	band_label = Label.new()
	band_label.text = Copy.f("autopsy.deciding_band", {"band": "Talon"})
	vbox.add_child(band_label)

	standout_label = Label.new()
	standout_label.text = ""
	vbox.add_child(standout_label)

	receipt_label = Label.new()
	receipt_label.text = Copy.t("autopsy.receipt.none")
	receipt_label.tooltip_text = Copy.t("ui.battle.sacrificed_label")
	vbox.add_child(receipt_label)

	flavor_label = Label.new()
	flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flavor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavor_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	vbox.add_child(flavor_label)

	close_btn = Button.new()
	close_btn.text = "Continue"
	close_btn.custom_minimum_size = Vector2(0, 34)
	close_btn.pressed.connect(func(): closed.emit())
	vbox.add_child(close_btn)

func setup(autopsy_data: Dictionary, winner_name: String = "", is_stalemate: bool = false, log: BattleLog = null) -> void:
	var b_log: BattleLog = log
	if b_log == null and autopsy_data.has("battle_log"):
		b_log = autopsy_data["battle_log"] as BattleLog

	var parties: Array[int] = b_log.get_party_empire_ids() if b_log != null else [0, 1]
	var win_eid: int = b_log.winner_empire_id if (b_log != null and b_log.winner_empire_id >= 0) else parties[0]
	var victor_name: String = winner_name
	if victor_name == "" or victor_name == "None":
		victor_name = Copy.empire_name(win_eid)

	if is_stalemate:
		winner_label.text = "Result: Stalemate (both sides withdrew)"
	elif victor_name != "":
		winner_label.text = Copy.f("autopsy.victor", {"victor": victor_name})
	else:
		winner_label.text = "Result: Combat Concluded"

	var band_str: String = str(autopsy_data.get("deciding_band", "talon")).capitalize()
	band_label.text = Copy.f("autopsy.deciding_band", {"band": band_str})

	var s_name: String = str(autopsy_data.get("standout_name", ""))
	var s_dmg: int = int(autopsy_data.get("standout_damage", 0))
	if s_name != "" and s_name != "None":
		standout_label.text = Copy.f("autopsy.standout", {"ship": s_name, "dmg": s_dmg})
		standout_label.visible = true
	else:
		standout_label.text = ""
		standout_label.visible = false

	var receipt: String = str(autopsy_data.get("receipt_text", ""))
	if receipt != "" and receipt != "None":
		receipt_label.text = Copy.f("autopsy.receipt", {"ship": receipt})
	else:
		receipt_label.text = Copy.t("autopsy.receipt.none")
	receipt_label.tooltip_text = Copy.t("ui.battle.sacrificed_label")

	# Opponent (loser) determination from same parties as viewer headers
	var loser_eid: int = parties[1] if win_eid == parties[0] else parties[0]
	var loser_name: String = Copy.empire_name(loser_eid)

	var ship_display: String = s_name
	if (ship_display == "" or ship_display == "None") and b_log != null:
		if b_log.standout_ship_uid >= 0:
			for u in b_log.final_units:
				if int(u.get("uid", -1)) == b_log.standout_ship_uid:
					ship_display = str(u.get("name_key", ""))
					break
			if ship_display == "" or ship_display == "None":
				for u in b_log.initial_units:
					if int(u.get("uid", -1)) == b_log.standout_ship_uid:
						ship_display = str(u.get("name_key", ""))
						break
		if ship_display == "" or ship_display == "None":
			for u in b_log.final_units:
				var nk: String = str(u.get("name_key", ""))
				if nk != "" and nk != "None":
					ship_display = nk
					break
		if ship_display == "" or ship_display == "None":
			for u in b_log.initial_units:
				var nk: String = str(u.get("name_key", ""))
				if nk != "" and nk != "None":
					ship_display = nk
					break
	if ship_display == "" or ship_display == "None":
		ship_display = Copy.t("role.talon_line.name", "Ship")

	# Deterministic flavor selection from battle data
	var seed_val: int = 0
	if b_log != null:
		seed_val = abs(b_log.system_id * 31 + b_log.turn * 17 + (win_eid if win_eid >= 0 else 0) * 7 + b_log.standout_ship_uid + b_log.rounds.size())
	var flavor_idx: int = (seed_val % 12) + 1
	var flavor_key: String = AUTOPSY_FLAVOR_KEYS[flavor_idx - 1]

	var flavor_args: Dictionary = {
		"victor": victor_name,
		"loser": loser_name,
		"ship": ship_display,
		"band": band_str,
		"dmg": str(s_dmg)
	}
	flavor_label.text = Copy.f(flavor_key, flavor_args)
