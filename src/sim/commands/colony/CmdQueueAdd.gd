class_name CmdQueueAdd
extends Cmd

var colony_id: int = -1
var kind_item: String = ""
var ref_id: String = ""
var count: int = 1
var index: int = -1

func kind() -> StringName:
	return &"queue_add"

func validate(gs: GameState, db: ContentDB) -> String:
	if not gs.colonies.has(colony_id):
		return "refuse.unknown"
	var col: Colony = gs.colonies[colony_id]
	if col.owner != empire_id:
		return "refuse.not_owner"
	if col.queue.size() >= db.bal("queue_max"):
		return "refuse.queue_full"

	var emp: Empire = gs.empires[empire_id]
	if kind_item == "building":
		var bdef: Dictionary = db.def("buildings", ref_id)
		if bdef.is_empty():
			return "refuse.unknown"
		if not bool(bdef.get("buildable", true)):
			return "refuse.not_buildable"
		var tech_req: String = str(bdef.get("tech", "start"))
		if tech_req != "start" and not emp.tech.knows(tech_req):
			return "refuse.tech_unknown"
		if col.buildings.has(ref_id):
			return "refuse.already_built"
		for qi in col.queue:
			if qi.kind == "building" and qi.ref_id == ref_id:
				return "refuse.already_built"
		if bool(bdef.get("capital_only", false)) and col.id != emp.capital_colony_id:
			return "refuse.capital_only"
	elif kind_item != "trade_goods" and kind_item != "housing":
		return "refuse.unknown"

	return ""

func apply(gs: GameState, _db: ContentDB) -> void:
	var col: Colony = gs.colonies[colony_id]
	var qi: QueueItem = QueueItem.new()
	qi.kind = kind_item
	qi.ref_id = ref_id
	qi.count = count
	qi.added_by = "player"

	var insert_idx: int = index
	if insert_idx < 0 or insert_idx > col.queue.size():
		insert_idx = col.queue.size()
	col.queue.insert(insert_idx, qi)

func to_dict() -> Dictionary:
	var d: Dictionary = super.to_dict()
	d["colony_id"] = colony_id
	d["kind_item"] = kind_item
	d["ref_id"] = ref_id
	d["count"] = count
	d["index"] = index
	return d

func load_dict(d: Dictionary) -> void:
	super.load_dict(d)
	colony_id = int(d.get("colony_id", -1))
	kind_item = str(d.get("kind_item", d.get("item_kind", "")))
	ref_id = str(d.get("ref_id", ""))
	count = int(d.get("count", 1))
	index = int(d.get("index", -1))
