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

	# Military Budget warship queueing
	var budget_pct: int = MilitaryBudget.budget_pct(db, emp.military_budget)
	var total_industry: int = 0
	for cid in Ids.sorted_keys(gs.colonies):
		var col: Colony = gs.colonies[cid]
		if col.owner == empire_id and not col.is_outpost:
			var out: Dictionary = Economy.colony_output(db, gs, cid)
			total_industry += (out["industry"] as ModResult).value

	var target: int = IntMath.pct(total_industry, budget_pct)
	var current: int = 0
	for cid in Ids.sorted_keys(gs.colonies):
		var col: Colony = gs.colonies[cid]
		if col.owner == empire_id and not col.is_outpost:
			if _colony_has_yard(db, col) and _queue_head_is_warship(db, gs, col):
				var out: Dictionary = Economy.colony_output(db, gs, cid)
				current += (out["industry"] as ModResult).value

	var fin: Dictionary = Economy.empire_totals(db, gs, empire_id)
	var fleet_upkeep: int = int(fin["ship_upkeep"])
	var income: int = int(fin["income"])
	var max_upkeep: int = IntMath.pct(income, db.bal("budget_upkeep_stop_pct"))

	if fleet_upkeep <= max_upkeep and current < target:
		var view: AiView = AiView.build(gs, db, empire_id)
		var role: String = MilitaryBudget.next_role(view)
		var des: ShipDesign = AutoDesign.design_for_role(db, gs, empire_id, role)
		if des == null and role == "swat_escort":
			des = AutoDesign.design_for_role(db, gs, empire_id, "talon_line")
		if des != null:
			var des_id: int = -1
			for did in Ids.sorted_keys(gs.designs):
				var existing: ShipDesign = gs.designs[did]
				if existing.empire_id == empire_id and not existing.obsolete and _designs_equal(existing, des):
					des_id = did
					break
			if des_id < 0:
				des_id = gs.alloc_id("design")
				des.id = des_id
				des.empire_id = empire_id
				gs.designs[des_id] = des
				if not gs.knowledge.has(empire_id):
					gs.knowledge[empire_id] = Knowledge.new()
				gs.knowledge[empire_id].known_designs[des_id] = des.to_dict()

			var hdef: Dictionary = db.def("hulls", des.hull)
			var is_yard_only: bool = bool(hdef.get("yard_only", false))

			while current < target:
				var best_col: Colony = null
				var best_ind: int = -1

				for cid in Ids.sorted_keys(gs.colonies):
					var col: Colony = gs.colonies[cid]
					if col.owner != empire_id or col.is_outpost:
						continue
					var pdef: Dictionary = db.def("presets", col.preset)
					if not bool(pdef.get("auto", true)):
						continue
					if not _colony_has_yard(db, col):
						continue
					if _queue_head_is_warship(db, gs, col):
						continue
					if is_yard_only and col.id != emp.capital_colony_id:
						continue
					if col.queue.size() >= max_q and (col.queue.is_empty() or col.queue[-1].count != -1):
						continue

					var out: Dictionary = Economy.colony_output(db, gs, cid)
					var ind: int = (out["industry"] as ModResult).value
					if ind > best_ind:
						best_ind = ind
						best_col = col

				if best_col == null:
					break

				var target_pct: int = budget_pct
				var current_pct: int = IntMath.floor_div(current * 100, total_industry) if total_industry > 0 else 0

				var qi: QueueItem = QueueItem.new()
				qi.kind = "ship"
				qi.ref_id = str(des_id)
				qi.count = 1
				qi.added_by = "governor"
				qi.why_key = "summary.why_queued.budget"
				qi.why_args = {
					"policy": emp.military_budget,
					"target": target_pct,
					"current": current_pct
				}

				if best_col.queue.size() >= max_q and best_col.queue[-1].count == -1:
					best_col.queue.pop_back()
				if not best_col.queue.is_empty() and best_col.queue[0].count == -1:
					best_col.queue.remove_at(0)

				best_col.queue.insert(0, qi)
				current += best_ind

				if report != null and empire_id == 0:
					var planet: Planet = gs.planets[best_col.planet_id]
					report.add_entry("governor", "notify.governor_queued", {
						"item": des.name,
						"place": "Star %d Orbit %d" % [planet.system_id, planet.orbit + 1]
					}, "colony", best_col.id)

	# 3. Filler for colonies that remain empty
	for cid in Ids.sorted_keys(gs.colonies):
		var col: Colony = gs.colonies[cid]
		if col.owner != empire_id:
			continue
		var pdef: Dictionary = db.def("presets", col.preset)
		if not bool(pdef.get("auto", true)):
			continue
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

static func _colony_has_yard(db: ContentDB, col: Colony) -> bool:
	for b in col.buildings:
		var bdef: Dictionary = db.def("buildings", b)
		if bool(bdef.get("counts_as_yard", false)):
			return true
	return false

static func _queue_head_is_warship(db: ContentDB, gs: GameState, col: Colony) -> bool:
	if col.queue.is_empty():
		return false
	var qi: QueueItem = col.queue[0]
	if qi.kind != "ship":
		return false
	var did: int = int(qi.ref_id)
	if not gs.designs.has(did):
		return false
	var des: ShipDesign = gs.designs[did]
	var st: Dictionary = DesignRules.stats(db, gs, des)
	return bool(st.get("armed", false))

static func _designs_equal(a: ShipDesign, b: ShipDesign) -> bool:
	return a.hull == b.hull and a.drive == b.drive and a.plate == b.plate and \
		a.mantle == b.mantle and a.computer == b.computer and \
		a.specials == b.specials and a.weapons == b.weapons
