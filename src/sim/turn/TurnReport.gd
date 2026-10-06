class_name TurnReport
extends RefCounted

var turn: int = 1
var entries: Array[Dictionary] = []

func add_entry(kind: String, text_key: String, args: Dictionary = {}, target_type: String = "", target_id: int = -1) -> void:
	entries.append({
		"kind": kind,
		"text_key": text_key,
		"key": text_key,
		"args": args.duplicate(true),
		"params": args.duplicate(true),
		"target_type": target_type,
		"target_kind": target_type,
		"target_id": target_id
	})

func to_dict() -> Dictionary:
	var ent_arr: Array = []
	for e in entries:
		ent_arr.append(e.duplicate(true))
	return {
		"turn": turn,
		"entries": ent_arr
	}

static func from_dict(d: Dictionary) -> TurnReport:
	var tr: TurnReport = TurnReport.new()
	tr.turn = int(d.get("turn", 1))
	tr.entries.clear()
	var raw_ent: Array = d.get("entries", [])
	for e in raw_ent:
		if e is Dictionary:
			tr.entries.append((e as Dictionary).duplicate(true))
	return tr
