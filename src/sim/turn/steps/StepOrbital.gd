class_name StepOrbital
extends TurnStep

var _system_ids: Array[int] = []
var _cursor: int = 0

func id() -> StringName:
	return &"orbital"

func begin(ctx: TurnContext) -> void:
	_system_ids.clear()
	_cursor = 0
	for i in range(ctx.gs.systems.size()):
		_system_ids.append(i)

func next(ctx: TurnContext) -> bool:
	if _system_ids.is_empty() or _cursor >= _system_ids.size():
		return true

	var slice_count: int = ctx.db.bal("slice_items")
	var end_idx: int = min(_cursor + slice_count, _system_ids.size())

	for i in range(_cursor, end_idx):
		var sys_id: int = _system_ids[i]
		var ctrl: int = Blockade.orbit_controller_for_system(ctx.gs, ctx.db, sys_id)

		# 1. Razing: an outpost whose system has a hostile armed fleet controlling orbit is removed
		if ctrl >= 0:
			var colonies_to_raze: Array[int] = []
			for col in ctx.gs.colonies.values():
				var c_sys: StarSystem = ctx.gs.system_of_planet(col.planet_id)
				if c_sys != null and c_sys.id == sys_id and col.is_outpost:
					if Wars.is_at_war(ctx.gs, ctrl, col.owner):
						colonies_to_raze.append(col.id)

			for cid in colonies_to_raze:
				if ctx.gs.colonies.has(cid):
					var col: Colony = ctx.gs.colonies[cid]
					var p: Planet = ctx.gs.planets[col.planet_id]
					p.colony_id = -1
					ctx.gs.colonies.erase(cid)
					if ctx.report != null:
						var place_str: String = "Star %d Orbit %d" % [p.system_id, p.orbit + 1]
						ctx.report.add_entry("orbital", "notify.outpost_razed", {"place": place_str}, "planet", p.id)

		# 2. Blockade: colony with hostile armed fleet controlling orbit gets blockaded = true, else false
		Blockade.update_system_blockade(ctx.gs, ctx.db, sys_id, ctx.report)

		# 3. Bombardment: fleets with order bombard controlling orbit
		for f in ctx.gs.fleets.values():
			if f.system_id == sys_id and str(f.order.get("type", "")) == "bombard":
				if ctrl == f.owner:
					var target_col: Colony = null
					for col in ctx.gs.colonies.values():
						var c_sys: StarSystem = ctx.gs.system_of_planet(col.planet_id)
						if c_sys != null and c_sys.id == sys_id and not col.is_outpost:
							if Wars.is_at_war(ctx.gs, f.owner, col.owner):
								target_col = col
								break
					if target_col != null:
						Bombardment.apply_bombardment(ctx.gs, ctx.db, f, target_col, ctx.report)
				f.order.clear()

		# 4. Invasion: fleets with order invade (or boot ships controlling orbit) when defenses suppressed
		for f in ctx.gs.fleets.values():
			if f.system_id == sys_id:
				var col_id: int = int(f.order.get("colony_id", -1))
				var is_invade: bool = (str(f.order.get("type", "")) == "invade")
				if not is_invade and (ctrl == f.owner or ctrl == -1):
					for sid in f.ship_ids:
						var s: Ship = ctx.gs.ships.get(sid)
						if s != null and ctx.gs.designs.has(s.design_id):
							var des: ShipDesign = ctx.gs.designs[s.design_id]
							if des.specials.has("boot_pod"):
								is_invade = true
								break

				if is_invade and (ctrl == f.owner or ctrl == -1):
					var target_col: Colony = null
					if col_id >= 0 and ctx.gs.colonies.has(col_id):
						target_col = ctx.gs.colonies[col_id]
					else:
						for col in ctx.gs.colonies.values():
							var c_sys: StarSystem = ctx.gs.system_of_planet(col.planet_id)
							if c_sys != null and c_sys.id == sys_id and not col.is_outpost and Wars.is_at_war(ctx.gs, f.owner, col.owner):
								target_col = col
								break
					if target_col != null and target_col.defense_hp <= 0:
						GroundCombat.resolve_invasion(ctx.gs, ctx.db, f, target_col, ctx.report)
						f.order.clear()

		# 5. Colonisation: claimants resolve with the orbit controller winning conflicts first
		var orders_by_pid: Dictionary = {}
		for fid in ctx.gs.fleets.keys():
			var f: Fleet = ctx.gs.fleets.get(fid)
			if f == null or f.system_id != sys_id or f.order.is_empty():
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
				if not orders_by_pid.has(pid):
					orders_by_pid[pid] = []
				orders_by_pid[pid].append({"fleet": f, "type": otype, "empire_id": f.owner})
			elif otype == "outpost":
				var err: String = Colonization.can_outpost(ctx.db, ctx.gs, f.owner, pid, f)
				if err != "":
					f.order.clear()
					continue
				if not orders_by_pid.has(pid):
					orders_by_pid[pid] = []
				orders_by_pid[pid].append({"fleet": f, "type": otype, "empire_id": f.owner})

		var sorted_pids: Array = orders_by_pid.keys()
		sorted_pids.sort()
		for pid in sorted_pids:
			var claimants: Array = orders_by_pid[pid]

			claimants.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				if a["empire_id"] != b["empire_id"]:
					return a["empire_id"] < b["empire_id"]
				return a["fleet"].id < b["fleet"].id
			)

			var winner_idx: int = 0
			var ctrl_claimant_idx: int = -1
			for c_i in range(claimants.size()):
				if claimants[c_i]["empire_id"] == ctrl:
					ctrl_claimant_idx = c_i
					break

			if ctrl_claimant_idx >= 0:
				winner_idx = ctrl_claimant_idx
			elif claimants.size() > 1:
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
				if ctx.report != null:
					ctx.report.add_entry("orbital", "notify.colony_founded", {
						"place": place_str
					}, "colony", col.id)
			elif otype == "outpost":
				Colonization.consume_ship_with_stat(ctx.db, ctx.gs, winner_fleet, "outpost")
				Colonization.apply_outpost(ctx.db, ctx.gs, winner_fleet.owner, pid)

			if ctx.gs.fleets.has(winner_fleet.id):
				winner_fleet.order.clear()

			for c_idx in range(claimants.size()):
				if c_idx != winner_idx:
					var loser_fleet: Fleet = claimants[c_idx]["fleet"]
					if ctx.gs.fleets.has(loser_fleet.id):
						loser_fleet.order.clear()

	_cursor = end_idx
	return _cursor >= _system_ids.size()
