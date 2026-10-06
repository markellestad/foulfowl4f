class_name CmdBuy
extends Cmd

var colony_id: int = -1

func kind() -> StringName:
	return &"buy"

func validate(gs: GameState, db: ContentDB) -> String:
	if not gs.colonies.has(colony_id):
		return "refuse.unknown"
	var col: Colony = gs.colonies[colony_id]
	if col.owner != empire_id:
		return "refuse.not_owner"
	if col.queue.is_empty():
		return "refuse.empty_queue"
	var head: QueueItem = col.queue[0]
	if head.kind == "trade_goods" or head.kind == "housing":
		return "refuse.cannot_buy_filler"
	if head.buy_requested:
		return "refuse.already_requested"

	var emp: Empire = gs.empires[empire_id]
	var price: int = Production.buy_price(db, gs, colony_id)
	if emp.treasury < price:
		return "refuse.cannot_afford"

	return ""

func apply(gs: GameState, _db: ContentDB) -> void:
	var col: Colony = gs.colonies[colony_id]
	if not col.queue.is_empty():
		col.queue[0].buy_requested = true

func to_dict() -> Dictionary:
	var d: Dictionary = super.to_dict()
	d["colony_id"] = colony_id
	return d

func load_dict(d: Dictionary) -> void:
	super.load_dict(d)
	colony_id = int(d.get("colony_id", -1))
