class_name ScenarioChecks
extends RefCounted

static func run(check_name: String, game: SimGame, params: Dictionary) -> String:
	match check_name:
		"invariants_clean":
			var errs: Array[String] = Invariants.check(game.gs, game.db)
			if not errs.is_empty():
				return "invariant_violation: %s" % errs[0]
			return ""

		"simlog_clean":
			var entries: Array[String] = SimLog.take()
			if not entries.is_empty():
				return "simlog not clean: %s" % entries[0]
			return ""

		"capital_pop_min":
			var eid: int = int(params.get("empire", 0))
			var min_val: int = int(params.get("value", 0))
			if eid < 0 or eid >= game.gs.empires.size():
				return "invalid empire %d" % eid
			var emp: Empire = game.gs.empires[eid]
			if emp.capital_colony_id < 0 or not game.gs.colonies.has(emp.capital_colony_id):
				return "capital colony not found for empire %d" % eid
			var cap_col: Colony = game.gs.colonies[emp.capital_colony_id]
			if cap_col.pop_units() < min_val:
				return "capital pop %d < min %d" % [cap_col.pop_units(), min_val]
			return ""

		"treasury_min":
			var eid: int = int(params.get("empire", 0))
			var min_val: int = int(params.get("value", 0))
			if eid < 0 or eid >= game.gs.empires.size():
				return "invalid empire %d" % eid
			var emp: Empire = game.gs.empires[eid]
			if emp.treasury < min_val:
				return "treasury %d < min %d" % [emp.treasury, min_val]
			return ""

		"colonies_min":
			var eid: int = int(params.get("empire", 0))
			var min_val: int = int(params.get("value", 0))
			var count: int = 0
			for cid in game.gs.colonies.keys():
				var col: Colony = game.gs.colonies[cid]
				if col.owner == eid and not col.is_outpost:
					count += 1
			if count < min_val:
				return "colonies count %d < min %d" % [count, min_val]
			return ""

		"outposts_min":
			var eid: int = int(params.get("empire", 0))
			var min_val: int = int(params.get("value", 0))
			var count: int = 0
			for cid in game.gs.colonies.keys():
				var col: Colony = game.gs.colonies[cid]
				if col.owner == eid and col.is_outpost:
					count += 1
			if count < min_val:
				return "outposts count %d < min %d" % [count, min_val]
			return ""

		"nest_drain_observed":
			if not bool(game.metadata.get("nest_drain_observed", false)):
				return "nest_drain_observed was false"
			return ""

		"explored_in_range_pct":
			var eid: int = int(params.get("empire", 0))
			var min_val: int = int(params.get("value", 100))
			var knw: Knowledge = game.gs.knowledge.get(eid)
			if knw == null:
				return "no knowledge for empire %d" % eid
			var in_range_total: int = 0
			var explored_count: int = 0
			for s in game.gs.systems:
				if FuelRange.in_range_system(game.db, game.gs, eid, s.id):
					in_range_total += 1
					if knw.explored.has(s.id):
						explored_count += 1
			var pct: int = 100 if in_range_total == 0 else IntMath.floor_div(explored_count * 100, in_range_total)
			if pct < min_val:
				return "explored_in_range_pct %d%% < min %d%% (%d/%d)" % [pct, min_val, explored_count, in_range_total]
			return ""

		_:
			return "unknown check: %s" % check_name
