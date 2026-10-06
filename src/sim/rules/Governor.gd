class_name Governor
extends RefCounted

static func assign_jobs(db: ContentDB, gs: GameState, empire_id: int) -> void:
	# 0. Adjust locked colonies if pop changed
	for cid in Ids.sorted_keys(gs.colonies):
		var col: Colony = gs.colonies[cid]
		if col.owner != empire_id:
			continue
		if col.jobs_locked:
			var sum_jobs: int = col.farmers + col.workers + col.scientists
			var diff: int = col.pop_units() - sum_jobs
			if diff > 0:
				col.workers += diff
			elif diff < 0:
				var to_remove: int = -diff
				var rem_w: int = min(col.workers, to_remove)
				col.workers -= rem_w
				to_remove -= rem_w
				if to_remove > 0:
					var rem_s: int = min(col.scientists, to_remove)
					col.scientists -= rem_s
					to_remove -= rem_s
				if to_remove > 0:
					var rem_f: int = min(col.farmers, to_remove)
					col.farmers -= rem_f
					to_remove -= rem_f

	# 1. Unlocked colonies: initialize farmers
	var unlocked_cols: Array[Colony] = []
	for cid in Ids.sorted_keys(gs.colonies):
		var col: Colony = gs.colonies[cid]
		if col.owner != empire_id:
			continue
		if not col.jobs_locked:
			unlocked_cols.append(col)
			var pdef: Dictionary = db.def("presets", col.preset)
			var farm_first: bool = bool(pdef.get("farm_first", false))
			if farm_first:
				col.farmers = col.pop_units()
			else:
				col.farmers = 0
			col.workers = 0
			col.scientists = 0

	# 2. While empire food < need: add farmer
	var food_need: int = 0
	for cid in Ids.sorted_keys(gs.colonies):
		var col: Colony = gs.colonies[cid]
		if col.owner != empire_id:
			continue
		food_need += col.pop_units() * db.bal("food_eaten_per_pop")

	var current_food: int = 0
	for cid in Ids.sorted_keys(gs.colonies):
		var col: Colony = gs.colonies[cid]
		if col.owner != empire_id:
			continue
		var out: Dictionary = Economy.colony_output(db, gs, cid)
		current_food += (out["food"] as ModResult).value

	while current_food < food_need:
		var best_col: Colony = null
		var best_gain: int = -1
		var best_farm_first: bool = false

		for col in unlocked_cols:
			if col.farmers < col.pop_units():
				var jy: Dictionary = Economy.job_yields(db, gs, col.id)
				var fpf: int = (jy["food_per_farmer"] as ModResult).value
				var pdef: Dictionary = db.def("presets", col.preset)
				var farm_first: bool = bool(pdef.get("farm_first", false))

				var is_better: bool = false
				if best_col == null:
					is_better = true
				elif fpf > best_gain:
					is_better = true
				elif fpf == best_gain:
					# Tie-break (orchestrator ruling 2026-10-06):
					# (a) farm_first presets first
					var col_ff: bool = farm_first
					var best_ff: bool = best_farm_first
					if col_ff != best_ff:
						is_better = col_ff
					else:
						# (b) then colonies whose preset is NOT capital
						var col_not_cap: bool = (col.preset != "capital")
						var best_not_cap: bool = (best_col.preset != "capital")
						if col_not_cap != best_not_cap:
							is_better = col_not_cap
						else:
							# (c) then the colony with the MOST remaining non-farmers
							var col_rem: int = col.pop_units() - col.farmers
							var best_rem: int = best_col.pop_units() - best_col.farmers
							if col_rem != best_rem:
								is_better = (col_rem > best_rem)
							else:
								# (d) then lowest id for determinism
								is_better = (col.id < best_col.id)

				if is_better:
					best_col = col
					best_gain = fpf
					best_farm_first = farm_first

		if best_col == null:
			break # No colony can add farmers

		best_col.farmers += 1
		# Recompute current food
		current_food = 0
		for cid in Ids.sorted_keys(gs.colonies):
			var col: Colony = gs.colonies[cid]
			if col.owner != empire_id:
				continue
			var out: Dictionary = Economy.colony_output(db, gs, cid)
			current_food += (out["food"] as ModResult).value

	# 3. Per unlocked colony, split remaining pop R
	for col in unlocked_cols:
		var pdef: Dictionary = db.def("presets", col.preset)
		var w: int = int(pdef.get("workers", 1))
		var s: int = int(pdef.get("scientists", 1))
		var R: int = col.pop_units() - col.farmers
		if R > 0:
			col.workers = IntMath.ceil_div(R * w, w + s)
			col.scientists = R - col.workers
		else:
			col.workers = 0
			col.scientists = 0

static func fill_queues(db: ContentDB, gs: GameState, empire_id: int, report: TurnReport = null) -> void:
	var emp: Empire = gs.empires[empire_id]
	var max_q: int = db.bal("queue_max")

	for cid in Ids.sorted_keys(gs.colonies):
		var col: Colony = gs.colonies[cid]
		if col.owner != empire_id:
			continue
		var pdef: Dictionary = db.def("presets", col.preset)
		if not bool(pdef.get("auto", true)):
			continue

		var build_list: Array = pdef.get("build", [])
		for bid in build_list:
			if col.queue.size() >= max_q:
				break
			var b_str: String = str(bid)
			if col.buildings.has(b_str):
				continue
			var already_queued: bool = false
			for qi in col.queue:
				if qi.kind == "building" and qi.ref_id == b_str:
					already_queued = true
					break
			if already_queued:
				continue

			var bdef: Dictionary = db.def("buildings", b_str)
			var tech_req: String = str(bdef.get("tech", "start"))
			if tech_req != "start" and not emp.tech.knows(tech_req):
				continue
			if bool(bdef.get("capital_only", false)) and col.id != emp.capital_colony_id:
				continue
			if not bool(bdef.get("buildable", true)):
				continue

			var qi: QueueItem = QueueItem.new()
			qi.kind = "building"
			qi.ref_id = b_str
			qi.count = 1
			qi.added_by = "governor"
			qi.why_key = "summary.why_queued.preset"
			col.queue.append(qi)

			if report != null and empire_id == 0:
				var planet: Planet = gs.planets[col.planet_id]
				report.add_entry("governor", "notify.governor_queued", {
					"item": b_str,
					"building": b_str,
					"place": "Star %d Orbit %d" % [planet.system_id, planet.orbit + 1]
				}, "colony", col.id)

		if col.queue.is_empty():
			var filler: String = str(pdef.get("filler", "trade_goods"))
			var qi: QueueItem = QueueItem.new()
			qi.kind = filler
			qi.ref_id = ""
			qi.count = -1
			qi.added_by = "governor"
			qi.why_key = "summary.why_queued.preset"
			col.queue.append(qi)

			if report != null and empire_id == 0:
				var planet: Planet = gs.planets[col.planet_id]
				report.add_entry("governor", "notify.governor_queued", {
					"item": filler,
					"place": "Star %d Orbit %d" % [planet.system_id, planet.orbit + 1]
				}, "colony", col.id)
