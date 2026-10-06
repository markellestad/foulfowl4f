class_name StarSystem
extends RefCounted

var id: int = -1
var name_id: int = -1
var x: int = 0
var y: int = 0
var star_type: String = ""
var planet_ids: Array[int] = []
var wormhole_to: int = -1
var is_orn: bool = false
var home_of: int = -1

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name_id": name_id,
		"x": x,
		"y": y,
		"star_type": star_type,
		"planet_ids": planet_ids.duplicate(),
		"wormhole_to": wormhole_to,
		"is_orn": is_orn,
		"home_of": home_of
	}

static func from_dict(d: Dictionary) -> StarSystem:
	var sys: StarSystem = StarSystem.new()
	sys.id = int(d.get("id", -1))
	sys.name_id = int(d.get("name_id", -1))
	sys.x = int(d.get("x", 0))
	sys.y = int(d.get("y", 0))
	sys.star_type = str(d.get("star_type", ""))
	sys.wormhole_to = int(d.get("wormhole_to", -1))
	sys.is_orn = bool(d.get("is_orn", false))
	sys.home_of = int(d.get("home_of", -1))
	sys.planet_ids.clear()
	var raw_pids: Array = d.get("planet_ids", [])
	for pid in raw_pids:
		sys.planet_ids.append(int(pid))
	return sys
