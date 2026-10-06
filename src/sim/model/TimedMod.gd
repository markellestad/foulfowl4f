class_name TimedMod
extends RefCounted

var source_key: String = ""
var effects: Array = []
var until_turn: int = 0

func to_dict() -> Dictionary:
	var effs: Array = []
	for e in effects:
		if e is Dictionary:
			effs.append((e as Dictionary).duplicate(true))
	return {
		"source_key": source_key,
		"effects": effs,
		"until_turn": until_turn
	}

static func from_dict(d: Dictionary) -> TimedMod:
	var tm: TimedMod = TimedMod.new()
	tm.source_key = str(d.get("source_key", ""))
	tm.until_turn = int(d.get("until_turn", 0))
	tm.effects = []
	var raw_effs: Array = d.get("effects", [])
	for e in raw_effs:
		if e is Dictionary:
			tm.effects.append((e as Dictionary).duplicate(true))
	return tm
