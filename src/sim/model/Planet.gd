class_name Planet
extends RefCounted

var id: int = -1
var system_id: int = -1
var orbit: int = 0
var climate: String = ""
var size: String = ""
var minerals: String = ""
var gravity: String = "normal"
var special: String = ""
var colony_id: int = -1

func to_dict() -> Dictionary:
	return {
		"id": id,
		"system_id": system_id,
		"orbit": orbit,
		"climate": climate,
		"size": size,
		"minerals": minerals,
		"gravity": gravity,
		"special": special,
		"colony_id": colony_id
	}

static func from_dict(d: Dictionary) -> Planet:
	var p: Planet = Planet.new()
	p.id = int(d.get("id", -1))
	p.system_id = int(d.get("system_id", -1))
	p.orbit = int(d.get("orbit", 0))
	p.climate = str(d.get("climate", ""))
	p.size = str(d.get("size", ""))
	p.minerals = str(d.get("minerals", ""))
	p.gravity = str(d.get("gravity", "normal"))
	p.special = str(d.get("special", ""))
	p.colony_id = int(d.get("colony_id", -1))
	return p
