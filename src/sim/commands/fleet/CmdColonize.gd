class_name CmdColonize
extends Cmd

var fleet_id: int = -1
var planet_id: int = -1

func kind() -> StringName:
	return &"colonize"

func validate(gs: GameState, db: ContentDB) -> String:
	if not gs.fleets.has(fleet_id):
		return "refuse.unknown"
	var flt: Fleet = gs.fleets[fleet_id]
	if flt.owner != empire_id:
		return "refuse.not_owner"
	return Colonization.can_colonize(db, gs, empire_id, planet_id, flt)

func apply(gs: GameState, _db: ContentDB) -> void:
	if gs.fleets.has(fleet_id):
		gs.fleets[fleet_id].order = {
			"type": "colonize",
			"planet_id": planet_id
		}

func to_dict() -> Dictionary:
	var d: Dictionary = super.to_dict()
	d["fleet_id"] = fleet_id
	d["planet_id"] = planet_id
	return d

func load_dict(d: Dictionary) -> void:
	super.load_dict(d)
	fleet_id = int(d.get("fleet_id", -1))
	planet_id = int(d.get("planet_id", -1))
