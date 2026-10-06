class_name CmdFleetMove
extends Cmd

var fleet_id: int = -1
var system_id: int = -1

func kind() -> StringName:
	return &"fleet_move"

func validate(gs: GameState, db: ContentDB) -> String:
	if not gs.fleets.has(fleet_id):
		return "refuse.unknown"
	var flt: Fleet = gs.fleets[fleet_id]
	if flt.owner != empire_id:
		return "refuse.not_owner"
	if system_id < 0 or system_id >= gs.systems.size():
		return "refuse.unknown"
	if flt.system_id == system_id:
		return "refuse.same_system"
	if not FuelRange.in_range_system(db, gs, empire_id, system_id):
		return "refuse.out_of_range"
	return ""

func apply(gs: GameState, db: ContentDB) -> void:
	var flt: Fleet = gs.fleets[fleet_id]
	Movement.start_move(db, gs, flt, system_id)

func to_dict() -> Dictionary:
	var d: Dictionary = super.to_dict()
	d["fleet_id"] = fleet_id
	d["system_id"] = system_id
	return d

func load_dict(d: Dictionary) -> void:
	super.load_dict(d)
	fleet_id = int(d.get("fleet_id", -1))
	system_id = int(d.get("system_id", -1))
