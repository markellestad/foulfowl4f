class_name CmdFleetBombard
extends Cmd

var fleet_id: int = -1

func kind() -> StringName:
	return &"fleet_bombard"

func validate(gs: GameState, db: ContentDB) -> String:
	if not gs.fleets.has(fleet_id):
		return "refuse.unknown"
	var flt: Fleet = gs.fleets[fleet_id]
	if flt.owner != empire_id:
		return "refuse.not_owner"
	if flt.system_id < 0:
		return "refuse.in_transit"

	var has_bombs: bool = false
	for sid in flt.ship_ids:
		var s: Ship = gs.ships.get(sid)
		if s != null and s.design_id >= 0 and gs.designs.has(s.design_id):
			var des: ShipDesign = gs.designs[s.design_id]
			for sp in des.specials:
				var pdef: Dictionary = db.def("parts", sp)
				if pdef.has("bomb_milli"):
					has_bombs = true
					break
			if has_bombs:
				break
	if not has_bombs:
		return "refuse.no_bombs"

	var has_hostile_colony: bool = false
	for col in gs.colonies.values():
		var sys: StarSystem = gs.system_of_planet(col.planet_id)
		if sys != null and sys.id == flt.system_id:
			if Wars.is_at_war(gs, flt.owner, col.owner):
				has_hostile_colony = true
				break
	if not has_hostile_colony:
		return "refuse.not_here"

	return ""

func apply(gs: GameState, _db: ContentDB) -> void:
	if gs.fleets.has(fleet_id):
		gs.fleets[fleet_id].order = {
			"type": "bombard"
		}

func to_dict() -> Dictionary:
	var d: Dictionary = super.to_dict()
	d["fleet_id"] = fleet_id
	return d

func load_dict(d: Dictionary) -> void:
	super.load_dict(d)
	fleet_id = int(d.get("fleet_id", -1))
