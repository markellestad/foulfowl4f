class_name StepOrbital
extends TurnStep

var _orders_by_planet: Dictionary = {}
var _sorted_planet_ids: Array[int] = []
var _cursor: int = 0

func id() -> StringName:
	return &"orbital"

func begin(ctx: TurnContext) -> void:
	_orders_by_planet.clear()
	_sorted_planet_ids.clear()
	_cursor = 0

	var fleet_ids: Array = ctx.gs.fleets.keys()
	fleet_ids.sort()

	for fid in fleet_ids:
		var f: Fleet = ctx.gs.fleets.get(fid)
		if f == null:
			continue
		if f.system_id < 0:
			# In transit, cannot resolve orbital orders yet
			continue
		if f.order.is_empty():
			continue
		var otype: String = str(f.order.get("type", ""))
		var pid: int = int(f.order.get("planet_id", -1))
		if pid < 0:
			continue

		if otype == "colonize":
			var err: String = Colonization.can_colonize(ctx.db, ctx.gs, f.owner, pid, f)
			if err != "":
				f.order.clear()
				continue
		elif otype == "outpost":
			var err: String = Colonization.can_outpost(ctx.db, ctx.gs, f.owner, pid, f)
			if err != "":
				f.order.clear()
				continue
		else:
			continue

		if not _orders_by_planet.has(pid):
			_orders_by_planet[pid] = []
		_orders_by_planet[pid].append({
			"fleet": f,
			"type": otype,
			"empire_id": f.owner
		})

	for pid in _orders_by_planet.keys():
		_sorted_planet_ids.append(int(pid))
	_sorted_planet_ids.sort()

func next(ctx: TurnContext) -> bool:
	if _sorted_planet_ids.is_empty() or _cursor >= _sorted_planet_ids.size():
		return true

	var slice_count: int = ctx.db.bal("slice_items")
	var end_idx: int = min(_cursor + slice_count, _sorted_planet_ids.size())

	for i in range(_cursor, end_idx):
		var pid: int = _sorted_planet_ids[i]
		var claimants: Array = _orders_by_planet[pid]
		if claimants.is_empty():
			continue

		# Sort claimants by empire_id ascending, then fleet id ascending
		claimants.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if a["empire_id"] != b["empire_id"]:
				return a["empire_id"] < b["empire_id"]
			return a["fleet"].id < b["fleet"].id
		)

		var winner_idx: int = 0
		if claimants.size() > 1:
			var rng: Rng = Rng.keyed(ctx.gs.settings.seed, ctx.gs.turn, Rng.COLONIZE, pid)
			winner_idx = rng.pick_index(claimants.size())

		var winner: Dictionary = claimants[winner_idx]
		var winner_fleet: Fleet = winner["fleet"]
		var otype: String = winner["type"]

		if otype == "colonize":
			Colonization.consume_ship_with_stat(ctx.db, ctx.gs, winner_fleet, "colonize")
			var col: Colony = Colonization.apply_colonization(ctx.db, ctx.gs, winner_fleet.owner, pid)
			var p: Planet = ctx.gs.planets[pid]
			var place_str: String = "Star %d Orbit %d" % [p.system_id, p.orbit + 1]
			ctx.report.add_entry("orbital", "notify.colony_founded", {
				"place": place_str
			}, "colony", col.id)
		elif otype == "outpost":
			Colonization.consume_ship_with_stat(ctx.db, ctx.gs, winner_fleet, "outpost")
			Colonization.apply_outpost(ctx.db, ctx.gs, winner_fleet.owner, pid)

		if ctx.gs.fleets.has(winner_fleet.id):
			winner_fleet.order.clear()

		# Other claimants fail
		for c_idx in range(claimants.size()):
			if c_idx != winner_idx:
				var loser_fleet: Fleet = claimants[c_idx]["fleet"]
				if ctx.gs.fleets.has(loser_fleet.id):
					loser_fleet.order.clear()

	_cursor = end_idx
	return _cursor >= _sorted_planet_ids.size()
