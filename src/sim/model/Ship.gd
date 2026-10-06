class_name Ship
extends RefCounted

var id: int = -1
var design_id: int = -1
var owner: int = -1
var fleet_id: int = -1
var hp: int = 0
var veterancy: int = 0
var refit_until: int = -1
var built_turn: int = 1

func to_dict() -> Dictionary:
	return {
		"id": id,
		"design_id": design_id,
		"owner": owner,
		"fleet_id": fleet_id,
		"hp": hp,
		"veterancy": veterancy,
		"refit_until": refit_until,
		"built_turn": built_turn
	}

static func from_dict(d: Dictionary) -> Ship:
	var s: Ship = Ship.new()
	s.id = int(d.get("id", -1))
	s.design_id = int(d.get("design_id", -1))
	s.owner = int(d.get("owner", -1))
	s.fleet_id = int(d.get("fleet_id", -1))
	s.hp = int(d.get("hp", 0))
	s.veterancy = int(d.get("veterancy", 0))
	s.refit_until = int(d.get("refit_until", -1))
	s.built_turn = int(d.get("built_turn", 1))
	return s
