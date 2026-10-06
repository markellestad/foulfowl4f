class_name CmdQueueRemove
extends Cmd

var colony_id: int = -1
var index: int = -1

func kind() -> StringName:
	return &"queue_remove"

func validate(gs: GameState, _db: ContentDB) -> String:
	if not gs.colonies.has(colony_id):
		return "refuse.unknown"
	var col: Colony = gs.colonies[colony_id]
	if col.owner != empire_id:
		return "refuse.not_owner"
	if index < 0 or index >= col.queue.size():
		return "refuse.out_of_range"
	return ""

func apply(gs: GameState, _db: ContentDB) -> void:
	var col: Colony = gs.colonies[colony_id]
	col.queue.remove_at(index)

func to_dict() -> Dictionary:
	var d: Dictionary = super.to_dict()
	d["colony_id"] = colony_id
	d["index"] = index
	return d

func load_dict(d: Dictionary) -> void:
	super.load_dict(d)
	colony_id = int(d.get("colony_id", -1))
	index = int(d.get("index", -1))
