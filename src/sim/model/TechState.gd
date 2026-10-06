class_name TechState
extends RefCounted

var known: Array[String] = ["start"]

func knows(tech_id: String) -> bool:
	return known.has(tech_id)

func to_dict() -> Dictionary:
	var k_arr: Array = []
	for k in known:
		k_arr.append(str(k))
	return {
		"known": k_arr
	}

static func from_dict(d: Dictionary) -> TechState:
	var ts: TechState = TechState.new()
	ts.known.clear()
	var raw_k: Array = d.get("known", ["start"])
	for k in raw_k:
		ts.known.append(str(k))
	return ts
