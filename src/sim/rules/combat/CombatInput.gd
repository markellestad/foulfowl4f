class_name CombatInput
extends RefCounted

var system_id: int = -1
var parties: Array[CombatParty] = []
var start_distances: Dictionary = {}
var seed: int = 0
var turn: int = 0

func to_dict() -> Dictionary:
	var p_arr: Array = []
	for p in parties:
		p_arr.append(p.to_dict())
	return {
		"system_id": system_id,
		"parties": p_arr,
		"start_distances": start_distances.duplicate(),
		"seed": seed,
		"turn": turn
	}

static func from_dict(d: Dictionary) -> CombatInput:
	var ci := CombatInput.new()
	ci.system_id = int(d.get("system_id", -1))
	ci.parties = []
	for pd in d.get("parties", []):
		ci.parties.append(CombatParty.from_dict(pd as Dictionary))
	ci.start_distances = (d.get("start_distances", {}) as Dictionary).duplicate()
	ci.seed = int(d.get("seed", 0))
	ci.turn = int(d.get("turn", 0))
	return ci
