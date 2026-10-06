class_name Autopsy
extends RefCounted

static func analyze(log: BattleLog) -> Dictionary:
	if log == null:
		return {
			"deciding_band": "talon",
			"standout_name": "None",
			"standout_damage": 0,
			"receipt_text": ""
		}

	var standout_name: String = "None"
	var standout_dmg: int = 0
	for u in log.final_units:
		if int(u.get("uid", -1)) == log.standout_ship_uid:
			standout_name = str(u.get("name_key", "Ship"))
			standout_dmg = int(u.get("damage_dealt", 0))
			break

	var receipt_text: String = ""
	if not log.receipt_lines.is_empty():
		var r: Dictionary = log.receipt_lines[0]
		receipt_text = "%s (%s)" % [str(r.get("name_key", "Ship")), str(r.get("hull_id", "hull"))]

	return {
		"deciding_band": log.deciding_band,
		"standout_name": standout_name,
		"standout_damage": standout_dmg,
		"receipt_text": receipt_text
	}
