class_name QueueItem
extends RefCounted

var kind: String = "" # "building" | "ship" | "trade_goods" | "housing"
var ref_id: String = "" # building id or design id ("" for fillers)
var count: int = 1 # -1 = repeat forever
var repeat: bool:
	get:
		return count == -1
	set(v):
		count = -1 if v else 1
var added_by: String = "player" # "player" | "governor"
var why_key: String = ""
var why_args: Dictionary = {}
var buy_requested: bool = false


func to_dict() -> Dictionary:
	return {
		"kind": kind,
		"ref_id": ref_id,
		"count": count,
		"added_by": added_by,
		"why_key": why_key,
		"why_args": why_args.duplicate(true),
		"buy_requested": buy_requested
	}

static func from_dict(d: Dictionary) -> QueueItem:
	var qi: QueueItem = QueueItem.new()
	qi.kind = str(d.get("kind", ""))
	qi.ref_id = str(d.get("ref_id", ""))
	qi.count = int(d.get("count", 1))
	qi.added_by = str(d.get("added_by", "player"))
	qi.why_key = str(d.get("why_key", ""))
	qi.why_args = (d.get("why_args", {}) as Dictionary).duplicate(true)
	qi.buy_requested = bool(d.get("buy_requested", false))
	return qi
