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
	return false
