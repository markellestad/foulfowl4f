class_name CmdFleetSplit
extends Cmd

var fleet_id: int = -1
var ship_ids: Array[int] = []

func kind() -> StringName:
	return &"fleet_split"

func validate(gs: GameState, _db: ContentDB) -> String:
	if not gs.fleets.has(fleet_id):
		return "refuse.unknown"
	var flt: Fleet = gs.fleets[fleet_id]
	if flt.owner != empire_id:
		return "refuse.not_owner"
	if flt.system_id < 0:
		return "refuse.in_transit"
	if ship_ids.is_empty() or ship_ids.size() >= flt.ship_ids.size():
		return "refuse.invalid_item"
	for sid in ship_ids:
		if not flt.ship_ids.has(sid):
			return "refuse.unknown"
	return ""

func apply(gs: GameState, _db: ContentDB) -> void:
	var flt: Fleet = gs.fleets[fleet_id]
	for sid in ship_ids:
		flt.ship_ids.erase(sid)
	var nf: Fleet = Fleet.new()
	nf.id = gs.alloc_id("fleet")
	nf.owner = flt.owner
	nf.system_id = flt.system_id
	nf.x = flt.x
	nf.y = flt.y
	nf.ship_ids = ship_ids.duplicate()
	gs.fleets[nf.id] = nf

func to_dict() -> Dictionary:
	var d: Dictionary = super.to_dict()
	d["fleet_id"] = fleet_id
	var s_arr: Array = []
	for sid in ship_ids:
		s_arr.append(int(sid))
	d["ship_ids"] = s_arr
	return d

func load_dict(d: Dictionary) -> void:
	super.load_dict(d)
	fleet_id = int(d.get("fleet_id", -1))
	ship_ids.clear()
	var raw_sids: Array = d.get("ship_ids", [])
	for sid in raw_sids:
		ship_ids.append(int(sid))
