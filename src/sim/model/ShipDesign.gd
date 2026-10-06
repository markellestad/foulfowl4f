class_name ShipDesign
extends RefCounted

var id: int = -1
var empire_id: int = -1
var name: String = ""
var role: String = ""
var hull: String = "small"
var drive: String = "walk_drive"
var plate: String = "pinfeather_plate"
var mantle: String = ""
var computer: String = ""
var weapons: Array[Dictionary] = []    # {"part": id, "mount": "" | "primary_mount" | "swat_mount", "count": int}
var specials: Array[String] = []
var obsolete: bool = false

func to_dict() -> Dictionary:
	var w_arr: Array = []
	for w in weapons:
		w_arr.append({
			"part": str(w.get("part", "")),
			"mount": str(w.get("mount", "")),
			"count": int(w.get("count", 1))
		})
	var s_arr: Array = []
	for s in specials:
		s_arr.append(str(s))
	return {
		"id": id,
		"empire_id": empire_id,
		"name": name,
		"role": role,
		"hull": hull,
		"drive": drive,
		"plate": plate,
		"mantle": mantle,
		"computer": computer,
		"weapons": w_arr,
		"specials": s_arr,
		"obsolete": obsolete
	}

static func from_dict(d: Dictionary) -> ShipDesign:
	var sd: ShipDesign = ShipDesign.new()
	sd.id = int(d.get("id", -1))
	sd.empire_id = int(d.get("empire_id", -1))
	sd.name = str(d.get("name", ""))
	sd.role = str(d.get("role", ""))
	sd.hull = str(d.get("hull", "small"))
	sd.drive = str(d.get("drive", "walk_drive"))
	sd.plate = str(d.get("plate", "pinfeather_plate"))
	sd.mantle = str(d.get("mantle", ""))
	sd.computer = str(d.get("computer", ""))
	sd.obsolete = bool(d.get("obsolete", false))

	sd.weapons.clear()
	var raw_w: Array = d.get("weapons", [])
	for w in raw_w:
		if w is Dictionary:
			sd.weapons.append({
				"part": str(w.get("part", "")),
				"mount": str(w.get("mount", "")),
				"count": int(w.get("count", 1))
			})

	sd.specials.clear()
	var raw_s: Array = d.get("specials", [])
	for s in raw_s:
		sd.specials.append(str(s))

	return sd
