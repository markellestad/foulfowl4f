class_name CmdSetLineOrder
extends Cmd

var fleet_id: int = -1
var ship_ids: Array[int] = []

func kind() -> StringName:
	return &"set_line_order"

func validate(gs: GameState, _db: ContentDB) -> String:
	if not gs.fleets.has(fleet_id):
		return "refuse.unknown"
	var flt: Fleet = gs.fleets[fleet_id]
	if flt.owner != empire_id:
		return "refuse.not_owner"
	if ship_ids.size() != flt.ship_ids.size():
		return "refuse.unknown"

	var s1: Array = ship_ids.duplicate()
	s1.sort()
	var s2: Array = flt.ship_ids.duplicate()
	s2.sort()
	if s1 != s2:
		return "refuse.unknown"

	return ""

func apply(gs: GameState, _db: ContentDB) -> void:
	if gs.fleets.has(fleet_id):
		gs.fleets[fleet_id].line_order = ship_ids.duplicate()

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
