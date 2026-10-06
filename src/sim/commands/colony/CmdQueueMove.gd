class_name CmdQueueMove
extends Cmd

var colony_id: int = -1
var from_idx: int = -1
var to_idx: int = -1

func kind() -> StringName:
	return &"queue_move"

func validate(gs: GameState, _db: ContentDB) -> String:
	if not gs.colonies.has(colony_id):
		return "refuse.unknown"
	var col: Colony = gs.colonies[colony_id]
	if col.owner != empire_id:
		return "refuse.not_owner"
	if from_idx < 0 or from_idx >= col.queue.size():
		return "refuse.out_of_range"
	if to_idx < 0 or to_idx >= col.queue.size():
		return "refuse.out_of_range"
	return ""

func apply(gs: GameState, _db: ContentDB) -> void:
	var col: Colony = gs.colonies[colony_id]
	var item: QueueItem = col.queue.pop_at(from_idx)
	col.queue.insert(to_idx, item)

func to_dict() -> Dictionary:
	var d: Dictionary = super.to_dict()
	d["colony_id"] = colony_id
	d["from_idx"] = from_idx
	d["to_idx"] = to_idx
	return d

func load_dict(d: Dictionary) -> void:
	super.load_dict(d)
	colony_id = int(d.get("colony_id", -1))
	from_idx = int(d.get("from_idx", d.get("from", -1)))
	to_idx = int(d.get("to_idx", d.get("to", -1)))
