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
				if col.owner == eid:
					count += 1
			if count < min_val:
				return "colonies count %d < min %d" % [count, min_val]
			return ""

		_:
			return "unknown check: %s" % check_name
