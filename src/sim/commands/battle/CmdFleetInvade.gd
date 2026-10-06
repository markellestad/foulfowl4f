class_name CmdFleetInvade
extends Cmd

var fleet_id: int = -1
var colony_id: int = -1

func kind() -> StringName:
	return &"fleet_invade"

func validate(gs: GameState, db: ContentDB) -> String:
	if not gs.fleets.has(fleet_id):
		return "refuse.unknown"
	var flt: Fleet = gs.fleets[fleet_id]
	if flt.owner != empire_id:
		return "refuse.not_owner"
	if flt.system_id < 0:
		return "refuse.in_transit"
	if not gs.colonies.has(colony_id):
		return "refuse.unknown"
	var col: Colony = gs.colonies[colony_id]
	var sys: StarSystem = gs.system_of_planet(col.planet_id)
	if sys == null or sys.id != flt.system_id:
		return "refuse.not_here"
	if not Wars.is_at_war(gs, flt.owner, col.owner):
		return "refuse.not_at_war"

	var has_marines: bool = false
	for sid in flt.ship_ids:
		var s: Ship = gs.ships.get(sid)
		if s != null and s.design_id >= 0 and gs.designs.has(s.design_id):
			var des: ShipDesign = gs.designs[s.design_id]
			if des.specials.has("boot_pod"):
				has_marines = true
				break
	if not has_marines:
		return "refuse.no_marines"

	return ""

func apply(gs: GameState, _db: ContentDB) -> void:
	if gs.fleets.has(fleet_id):
		gs.fleets[fleet_id].order = {
			"type": "invade",
			"colony_id": colony_id
		}

func to_dict() -> Dictionary:
	var d: Dictionary = super.to_dict()
	d["fleet_id"] = fleet_id
	d["colony_id"] = colony_id
	return d

func load_dict(d: Dictionary) -> void:
	super.load_dict(d)
	fleet_id = int(d.get("fleet_id", -1))
	colony_id = int(d.get("colony_id", -1))
