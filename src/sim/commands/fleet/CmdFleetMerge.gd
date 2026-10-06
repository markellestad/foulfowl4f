class_name CmdFleetMerge
extends Cmd

var fleet_id: int = -1
var other_id: int = -1

func kind() -> StringName:
	return &"fleet_merge"

func validate(gs: GameState, _db: ContentDB) -> String:
	if not gs.fleets.has(fleet_id) or not gs.fleets.has(other_id):
		return "refuse.unknown"
	if fleet_id == other_id:
		return "refuse.unknown"
	var f1: Fleet = gs.fleets[fleet_id]
	var f2: Fleet = gs.fleets[other_id]
	if f1.owner != empire_id or f2.owner != empire_id:
		return "refuse.not_owner"
	if f1.system_id < 0 or f2.system_id < 0:
		return "refuse.in_transit"
	if f1.system_id != f2.system_id:
		return "refuse.not_here"
	return ""

func apply(gs: GameState, _db: ContentDB) -> void:
	var f1: Fleet = gs.fleets[fleet_id]
	var f2: Fleet = gs.fleets[other_id]
	for sid in f2.ship_ids:
		f1.ship_ids.append(sid)
	gs.fleets.erase(other_id)

func to_dict() -> Dictionary:
	var d: Dictionary = super.to_dict()
	d["fleet_id"] = fleet_id
	d["other_id"] = other_id
	return d

func load_dict(d: Dictionary) -> void:
	super.load_dict(d)
	fleet_id = int(d.get("fleet_id", -1))
	other_id = int(d.get("other_id", -1))
