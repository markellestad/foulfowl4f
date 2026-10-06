class_name CmdFleetAutoExplore
extends Cmd

var fleet_id: int = -1
var on: bool = false

func kind() -> StringName:
	return &"fleet_auto_explore"

func validate(gs: GameState, _db: ContentDB) -> String:
	if not gs.fleets.has(fleet_id):
		return "refuse.unknown"
	var flt: Fleet = gs.fleets[fleet_id]
	if flt.owner != empire_id:
		return "refuse.not_owner"
	return ""

func apply(gs: GameState, _db: ContentDB) -> void:
	if gs.fleets.has(fleet_id):
		gs.fleets[fleet_id].auto_explore = on

func to_dict() -> Dictionary:
	var d: Dictionary = super.to_dict()
	d["fleet_id"] = fleet_id
	d["on"] = on
	return d

func load_dict(d: Dictionary) -> void:
	super.load_dict(d)
	fleet_id = int(d.get("fleet_id", -1))
	on = bool(d.get("on", false))
