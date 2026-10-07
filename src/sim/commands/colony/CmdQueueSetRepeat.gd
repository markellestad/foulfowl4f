class_name CmdQueueSetRepeat
extends Cmd

var colony_id: int = -1
var index: int = -1
var count: int = 1

var repeat: bool:
	get:
		return count == -1
	set(v):
		count = -1 if v else 1


func kind() -> StringName:
	return &"queue_set_repeat"

func validate(gs: GameState, _db: ContentDB) -> String:
	if not gs.colonies.has(colony_id):
		return "refuse.unknown"
	var col: Colony = gs.colonies[colony_id]
	if col.owner != empire_id:
		return "refuse.not_owner"
	if index < 0 or index >= col.queue.size():
		return "refuse.out_of_range"
	if count == 0 or count < -1:
		return "refuse.invalid_count"
	return ""

func apply(gs: GameState, _db: ContentDB) -> void:
	var col: Colony = gs.colonies[colony_id]
	col.queue[index].count = count

func to_dict() -> Dictionary:
	var d: Dictionary = super.to_dict()
	d["colony_id"] = colony_id
	d["index"] = index
	d["count"] = count
	return d

func load_dict(d: Dictionary) -> void:
	super.load_dict(d)
	colony_id = int(d.get("colony_id", -1))
	index = int(d.get("index", -1))
	count = int(d.get("count", 1))
