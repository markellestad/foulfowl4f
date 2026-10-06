class_name AutoExplore
extends RefCounted

static func process_empire(db: ContentDB, gs: GameState, empire_id: int) -> void:
	var knw: Knowledge = gs.knowledge.get(empire_id)
	if knw == null:
		return

	# Gather systems already targeted by auto-exploring fleets of this empire
	var targeted_systems: Dictionary = {}
	for f in gs.fleets.values():
		if f.owner == empire_id and f.auto_explore and f.dest_system_id >= 0:
			targeted_systems[f.dest_system_id] = true

	# Sort own fleets by id ascending for determinism
	var fleet_ids: Array = gs.fleets.keys()
	fleet_ids.sort()

	for fid in fleet_ids:
		var f: Fleet = gs.fleets.get(fid)
		if f == null or f.owner != empire_id:
			continue
		if not f.auto_explore:
			continue
		# Must have no destination and be at a system
		if f.dest_system_id >= 0 or f.system_id < 0:
			continue
		if f.ship_ids.is_empty():
			continue

		var cur_sys: StarSystem = gs.systems[f.system_id]

		# Find nearest unexplored in-range star not already targeted
		var best_sys_id: int = -1
		var best_dist: int = 999999999

		for s in gs.systems:
			if s.id == f.system_id:
				continue
			if knw.explored.has(s.id):
				continue
			if targeted_systems.has(s.id):
				continue
			if not FuelRange.in_range_system(db, gs, empire_id, s.id):
				continue

			var d: int = IntMath.dist(cur_sys.x, cur_sys.y, s.x, s.y)
			if d < best_dist:
				best_dist = d
				best_sys_id = s.id
			elif d == best_dist:
				if best_sys_id == -1 or s.id < best_sys_id:
					best_sys_id = s.id

		if best_sys_id >= 0:
			targeted_systems[best_sys_id] = true
			Movement.start_move(db, gs, f, best_sys_id)
