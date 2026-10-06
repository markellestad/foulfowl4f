class_name ScenarioChecks
extends RefCounted

const BattlePlayerClass = preload("res://src/render/battle/BattlePlayer.gd")

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

		"battle_at":
			var sys_id: int = int(params.get("system", -1))
			if params.has("system_of_empire_capital"):
				var target_eid: int = int(params["system_of_empire_capital"])
				var emp: Empire = game.gs.empires[target_eid]
				if emp.capital_colony_id >= 0 and game.gs.colonies.has(emp.capital_colony_id):
					sys_id = game.gs.colonies[emp.capital_colony_id].system_id
				else:
					for s in game.gs.systems:
						if s.home_of == target_eid:
							sys_id = s.id
							break
			var target_turn: int = int(params.get("turn", game.gs.turn))
			var found: bool = false
			for bl in game.gs.battle_logs:
				if int(bl.get("turn", -1)) == target_turn and (sys_id == -1 or int(bl.get("system_id", -1)) == sys_id):
					found = true
					break
			if not found:
				return "battle_at: no battle found at system %d on turn %d" % [sys_id, target_turn]
			return ""

		"orbit_controlled":
			var eid: int = int(params.get("empire", 0))
			var sys_id: int = int(params.get("system", -1))
			if params.has("system_of_empire_capital"):
				var target_eid: int = int(params["system_of_empire_capital"])
				var emp: Empire = game.gs.empires[target_eid]
				if emp.capital_colony_id >= 0 and game.gs.colonies.has(emp.capital_colony_id):
					sys_id = game.gs.colonies[emp.capital_colony_id].system_id
				else:
					for s in game.gs.systems:
						if s.home_of == target_eid:
							sys_id = s.id
							break
			var controller: int = Blockade.get_orbit_controller(game.gs, game.db, sys_id)
			if controller != eid:
				return "orbit_controlled: system %d controller is %d, expected %d" % [sys_id, controller, eid]
			return ""

		"colony_owner":
			var target_cid: int = int(params.get("colony_id", -1))
			if params.has("colony_of_empire_capital"):
				var target_eid: int = int(params["colony_of_empire_capital"])
				for c in game.gs.colonies.values():
					var p: Planet = game.gs.planets[c.planet_id]
					var sys: StarSystem = game.gs.systems[p.system_id]
					if sys.home_of == target_eid:
						target_cid = c.id
						break
			var expected_owner: int = int(params.get("owner", 0))
			if target_cid < 0 or not game.gs.colonies.has(target_cid):
				return "colony_owner: colony %d not found" % target_cid
			var col: Colony = game.gs.colonies[target_cid]
			if col.owner != expected_owner:
				return "colony_owner: colony %d owner is %d, expected %d" % [target_cid, col.owner, expected_owner]
			return ""

		"viewer_equals_resolver":
			if game.gs.battle_logs.is_empty():
				return "viewer_equals_resolver: no battle logs found"
			for blog_dict in game.gs.battle_logs:
				var blog: BattleLog = BattleLog.from_dict(blog_dict)
				var player = BattlePlayerClass.new(blog)
				player.play_all()
				for fu in blog.final_units:
					var uid: int = int(fu.get("uid", -1))
					var expected_hp: int = int(fu.get("hp", 0))
					var actual_hp: int = player.get_unit_hp(uid)
					if actual_hp != expected_hp:
						return "viewer_equals_resolver mismatch unit %d: expected hp %d, got %d" % [uid, expected_hp, actual_hp]
			return ""

		_:
			return "unknown check: %s" % check_name
