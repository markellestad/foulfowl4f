class_name AiExpansion
extends RefCounted

static func plan(view: AiView, _memory: AiMemory = null) -> Array[Cmd]:
	var cmds: Array[Cmd] = []
	var emp: Empire = view.own_empire()
	var rdef: Dictionary = view.db.def("races", emp.race)
	var traits_raw: Array = rdef.get("traits", [])
	var traits: Array[String] = []
	for t in traits_raw:
		traits.append(str(t))

	var is_patient_rock: bool = (str(view.personality().get("id", "")) == "patient_rock")
	var own_cols: Array[Colony] = view.own_colonies()
	if own_cols.is_empty():
		return cmds

	# 1. First, check idle colony/outpost ships to send orders
	var colony_ships_in_flight: int = 0
	var my_fleets: Array[Fleet] = view.own_fleets()

	# 0. Split colony ships from scout ships if mixed
	var split_fleet_ids: Dictionary = {}
	for f in my_fleets:
		if f.dest_system_id >= 0 or f.system_id < 0:
			continue
		var scout_sids: Array[int] = []
		var colony_sids: Array[int] = []
		for sid in f.ship_ids:
			var s: Ship = view.own_ship(sid)
			if s != null:
				var des: ShipDesign = view.raw_game_state_DO_NOT_USE_EXCEPT_SIM().designs.get(s.design_id)
				if des != null:
					if des.specials.has("glance_pod") or des.role == "glance":
						scout_sids.append(sid)
					elif des.specials.has("nest_pod") or des.specials.has("perch_pod"):
						colony_sids.append(sid)
		if not scout_sids.is_empty() and not colony_sids.is_empty():
			var cmd_sp: CmdFleetSplit = CmdFleetSplit.new()
			cmd_sp.empire_id = view.empire_id
			cmd_sp.fleet_id = f.id
			cmd_sp.ship_ids = colony_sids
			cmds.append(cmd_sp)
			split_fleet_ids[f.id] = true

	# 0b. Auto-explore for scout fleets
	for f in my_fleets:
		if split_fleet_ids.has(f.id):
			continue
		if f.auto_explore or f.dest_system_id >= 0:
			continue
		var is_scout: bool = false
		var has_other: bool = false
		for sid in f.ship_ids:
			var s: Ship = view.own_ship(sid)
			if s != null:
				var des: ShipDesign = view.raw_game_state_DO_NOT_USE_EXCEPT_SIM().designs.get(s.design_id)
				if des != null:
					if des.specials.has("glance_pod") or des.role == "glance":
						is_scout = true
					elif des.specials.has("nest_pod") or des.specials.has("perch_pod") or not des.weapons.is_empty():
						has_other = true
		if is_scout and not has_other:
			var cmd_ae: CmdFleetAutoExplore = CmdFleetAutoExplore.new()
			cmd_ae.empire_id = view.empire_id
			cmd_ae.fleet_id = f.id
			cmd_ae.on = true
			cmds.append(cmd_ae)

	for f in my_fleets:
		if split_fleet_ids.has(f.id):
			continue
		var has_nest: bool = false
		var has_stake: bool = false
		var has_warship: bool = false
		for sid in f.ship_ids:
			var s: Ship = view.own_ship(sid)
			if s != null:
				var des: ShipDesign = view.raw_game_state_DO_NOT_USE_EXCEPT_SIM().designs.get(s.design_id)
				if des != null:
					if des.specials.has("nest_pod"):
						has_nest = true
					if des.specials.has("perch_pod"):
						has_stake = true
					if not des.weapons.is_empty():
						has_warship = true

		if has_nest or has_stake:
			colony_ships_in_flight += 1
			# If fleet has no orders and is at a system
			if f.system_id >= 0 and f.dest_system_id == -1 and f.order.is_empty() and not (view.active_wars_count() > 0 and has_warship):
				var sys: StarSystem = view.system(f.system_id)
				if sys != null:
					var target_planet_id: int = -1
					for pid in sys.planet_ids:
						var p: Planet = view.planet(pid)
						if p != null and p.colony_id == -1:
							if has_nest:
								if Colonization.can_colonize(view.db, view.raw_game_state_DO_NOT_USE_EXCEPT_SIM(), view.empire_id, p.id, f) == "":
									target_planet_id = p.id
									break
							elif has_stake:
								if Colonization.can_outpost(view.db, view.raw_game_state_DO_NOT_USE_EXCEPT_SIM(), view.empire_id, p.id, f) == "":
									target_planet_id = p.id
									break

					if target_planet_id >= 0:
						if has_nest:
							var cmd_c: CmdColonize = CmdColonize.new()
							cmd_c.empire_id = view.empire_id
							cmd_c.fleet_id = f.id
							cmd_c.planet_id = target_planet_id
							cmds.append(cmd_c)
						else:
							var cmd_o: CmdOutpost = CmdOutpost.new()
							cmd_o.empire_id = view.empire_id
							cmd_o.fleet_id = f.id
							cmd_o.planet_id = target_planet_id
							cmds.append(cmd_o)
					else:
						# Move towards best target
						var best_target: Dictionary = _find_best_target(view, traits, is_patient_rock, f.x, f.y, has_nest)
						if not best_target.is_empty():
							var target_sys: int = int(best_target["system_id"])
							if target_sys != f.system_id and FuelRange.in_range_system(view.db, view.raw_game_state_DO_NOT_USE_EXCEPT_SIM(), view.empire_id, target_sys):
								var cmd_m: CmdFleetMove = CmdFleetMove.new()
								cmd_m.empire_id = view.empire_id
								cmd_m.fleet_id = f.id
								cmd_m.system_id = target_sys
								cmds.append(cmd_m)

	# 2. Count queued colony ships
	var queued_colony_ships: int = 0
	for c in own_cols:
		for qi in c.queue:
			if qi.kind == "ship":
				var did: int = int(qi.ref_id)
				var des: ShipDesign = view.raw_game_state_DO_NOT_USE_EXCEPT_SIM().designs.get(did)
				if des != null and (des.specials.has("nest_pod") or des.specials.has("perch_pod")):
					queued_colony_ships += 1

	# Find candidate targets in fuel range
	var valid_targets: Array[Dictionary] = _find_all_targets(view, traits, is_patient_rock)
	var max_allowed: int = 0 if view.active_wars_count() > 0 else mini(valid_targets.size(), 2 + IntMath.floor_div(own_cols.size(), 3))

	if colony_ships_in_flight + queued_colony_ships < max_allowed and not valid_targets.is_empty():
		# Find best yard colony
		var best_yard: Colony = null
		var best_yard_ind: int = -1
		for c in own_cols:
			if c.is_outpost:
				continue
			var has_yard: bool = false
			for b in c.buildings:
				var bdef: Dictionary = view.db.def("buildings", str(b))
				if bool(bdef.get("counts_as_yard", false)):
					has_yard = true
					break
			if has_yard:
				var out: Dictionary = Economy.colony_output(view.db, view.raw_game_state_DO_NOT_USE_EXCEPT_SIM(), c.id)
				var ind: int = (out["industry"] as ModResult).value
				if ind > best_yard_ind:
					best_yard_ind = ind
					best_yard = c

		if best_yard != null and best_yard.queue.size() < view.db.bal("queue_max"):
			# Find nest_ship design
			var nest_des_id: int = -1
			for d in view.own_designs():
				if not d.obsolete and d.specials.has("nest_pod"):
					nest_des_id = d.id
					break

			if nest_des_id >= 0:
				var q_cmd: CmdQueueAdd = CmdQueueAdd.new()
				q_cmd.empire_id = view.empire_id
				q_cmd.colony_id = best_yard.id
				q_cmd.kind_item = "ship"
				q_cmd.ref_id = str(nest_des_id)
				q_cmd.count = 1
				cmds.append(q_cmd)

	return cmds

static func _find_best_target(view: AiView, traits: Array[String], is_patient_rock: bool, from_x: int, from_y: int, is_nest: bool) -> Dictionary:
	var targets: Array[Dictionary] = _find_all_targets(view, traits, is_patient_rock, from_x, from_y)
	if targets.is_empty():
		return {}
	return targets[0]

static func _find_all_targets(view: AiView, traits: Array[String], is_patient_rock: bool, from_x: int = -9999, from_y: int = -9999) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var own_cols: Array[Colony] = view.own_colonies()
	if own_cols.is_empty():
		return results

	var ref_x: int = from_x
	var ref_y: int = from_y
	if ref_x == -9999:
		var cap_p: Planet = view.planet(own_cols[0].planet_id)
		var cap_s: StarSystem = view.system(cap_p.system_id) if cap_p != null else null
		if cap_s != null:
			ref_x = cap_s.x
			ref_y = cap_s.y
		else:
			ref_x = 0
			ref_y = 0

	for s in view.all_systems():
		if not view.is_explored(s.id):
			continue
		if not FuelRange.in_range_system(view.db, view.raw_game_state_DO_NOT_USE_EXCEPT_SIM(), view.empire_id, s.id):
			continue

		var dist: int = IntMath.dist(ref_x, ref_y, s.x, s.y)
		var eta_turns: int = IntMath.floor_div(dist, 20)

		for pid in s.planet_ids:
			var p: Planet = view.planet(pid)
			if p == null or p.colony_id != -1:
				continue
			if Colonization.can_colonize(view.db, view.raw_game_state_DO_NOT_USE_EXCEPT_SIM(), view.empire_id, p.id, null) != "":
				continue

			var max_pop: int = Habitability.max_pop(view.db, traits, p, [])
			if max_pop <= 0:
				continue

			var min_rank: int = 3
			match p.minerals:
				"very_poor": min_rank = 1
				"poor": min_rank = 2
				"normal": min_rank = 3
				"rich": min_rank = 4
				"ultra_rich": min_rank = 5

			var special_val: int = 5 if p.special != "" else 0
			var score: int = max_pop * 10 + min_rank * 8 + special_val - eta_turns * 5
			if is_patient_rock and p.climate in ["tundra", "desert", "arid"]:
				score *= 2

			results.append({
				"planet_id": p.id,
				"system_id": s.id,
				"score": score
			})

	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["score"]) != int(b["score"]):
			return int(a["score"]) > int(b["score"])
		return int(a["planet_id"]) < int(b["planet_id"])
	)
	return results
