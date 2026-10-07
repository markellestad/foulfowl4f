class_name FuelRange
extends RefCounted

static func fuel_range_dpc(db: ContentDB, gs: GameState, empire_id: int) -> int:
	var base_r: int = db.bal("base_fuel_range_dpc")
	var ctx: Dictionary = {"empire_id": empire_id}
	var res: ModResult = Modifiers.eval(db, gs, "fuel_range", base_r, ctx)
	return res.value

static func in_range(db: ContentDB, gs: GameState, empire_id: int, x: int, y: int) -> bool:
	var r: int = fuel_range_dpc(db, gs, empire_id)
	for cid in Ids.sorted_keys(gs.colonies):
		var col: Colony = gs.colonies[cid]
		if col.owner == empire_id:
			var planet: Planet = gs.planets[col.planet_id]
			var sys: StarSystem = gs.systems[planet.system_id]
			var d: int = IntMath.dist(x, y, sys.x, sys.y)
			if d <= r:
				return true
			for w_sys in gs.systems:
				if w_sys.wormhole_to >= 0 and w_sys.wormhole_to < gs.systems.size():
					var d_to_w: int = IntMath.dist(sys.x, sys.y, w_sys.x, w_sys.y)
					if d_to_w <= r:
						var other_w: StarSystem = gs.systems[w_sys.wormhole_to]
						var rem_r: int = r - d_to_w
						var d_from_other: int = IntMath.dist(x, y, other_w.x, other_w.y)
						if d_from_other <= rem_r:
							return true
	return false


static func in_range_system(db: ContentDB, gs: GameState, empire_id: int, system_id: int) -> bool:
	var sys: StarSystem = gs.systems[system_id]
	return in_range(db, gs, empire_id, sys.x, sys.y)

