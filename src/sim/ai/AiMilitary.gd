class_name AiMilitary
extends RefCounted

static func plan(view: AiView, memory: AiMemory = null) -> Array[Cmd]:
	var cmds: Array[Cmd] = []
	var is_floor: bool = (str(view.personality().get("id", "")) == "floor")
	var strike_ratio: int = 130 if is_floor else view.db.bal("strike_ratio_pct")
	var intel_max_age: int = view.db.bal("intel_max_age")
	var failure_window: int = view.db.bal("strike_failure_window")
	var max_failures: int = view.db.bal("strike_max_failures")

	# Find active wars
	var enemy_ids: Array[int] = []
	for eid in range(view.raw_game_state_DO_NOT_USE_EXCEPT_SIM().empires.size()):
		if eid != view.empire_id and view.is_at_war(eid):
			enemy_ids.append(eid)

	if enemy_ids.is_empty():
		return cmds

	# Check visible/seen enemy colonies
	var seen_cols: Dictionary = view.seen_colonies()
	var own_fleets: Array[Fleet] = view.own_fleets()
	if own_fleets.is_empty():
		return cmds

	# Gather idle armed fleets for strike/reserve
	var idle_armed_fleets: Array[Fleet] = []
	var idle_scouts: Array[Fleet] = []
	var idle_boot_ships: Array[Fleet] = []

	for f in own_fleets:
		if f.dest_system_id != -1 or f.ship_ids.is_empty():
			continue

		var is_armed: bool = false
		var is_scout: bool = false
		var has_boot: bool = false

		for sid in f.ship_ids:
			var s: Ship = view.own_ship(sid)
			if s != null:
				var des: ShipDesign = view.raw_game_state_DO_NOT_USE_EXCEPT_SIM().designs.get(s.design_id)
				if des != null:
					var st: Dictionary = DesignRules.stats(view.db, view.raw_game_state_DO_NOT_USE_EXCEPT_SIM(), des)
					if bool(st.get("is_armed", false)):
						is_armed = true
					if des.role == "glance" or (des.hull == "small" and not bool(st.get("is_armed", false))):
						is_scout = true
					if des.specials.has("boot_pod"):
						has_boot = true
				else:
					if s.hp > 100:
						is_armed = true
					else:
						is_scout = true

		if is_armed:
			idle_armed_fleets.append(f)
		elif has_boot:
			idle_boot_ships.append(f)
		elif is_scout:
			idle_scouts.append(f)

	# 1. Check invasion for colonies where orbit is already secured
	var invading_boot_ships: Array[Fleet] = []
	for f in idle_boot_ships:
		if f.system_id >= 0:
			var sys: StarSystem = view.system(f.system_id)
			if sys != null:
				for pid in sys.planet_ids:
					var p: Planet = view.planet(pid)
					if p != null and p.colony_id >= 0:
						var c_info: Dictionary = view.seen_colony(p.colony_id)
						var c_owner: int = int(c_info.get("owner", -1))
						if enemy_ids.has(c_owner):
							var inv_cmd: CmdFleetInvade = CmdFleetInvade.new()
							inv_cmd.empire_id = view.empire_id
							inv_cmd.fleet_id = f.id
							inv_cmd.colony_id = p.colony_id
							cmds.append(inv_cmd)
							invading_boot_ships.append(f)
							break
	for f in invading_boot_ships:
		idle_boot_ships.erase(f)

	# 2. Check strike opportunities
	for cid in seen_cols.keys():
		var col_info: Dictionary = seen_cols[cid]
		var c_owner: int = int(col_info.get("owner", -1))
		if not enemy_ids.has(c_owner):
			continue

		# Check failure memory: max_failures in failure_window
		if memory != null and memory.failures_in_window(cid, view.turn, failure_window) >= max_failures:
			continue

		# Estimate defense
		var estimated_defense: int = AiAssess.estimate_colony_defense(view, col_info, cid)
		if memory != null and memory.failures_in_window(cid, view.turn, failure_window) > 0:
			var last_met: int = memory.get_last_defense_met(cid)
			if last_met > 0:
				estimated_defense = max(estimated_defense, IntMath.pct(last_met, view.db.bal("strike_retry_ratio_pct")))

		var target_sys: int = view.colony_system_id(cid)
		if target_sys < 0:
			continue
		if not FuelRange.in_range_system(view.db, view.raw_game_state_DO_NOT_USE_EXCEPT_SIM(), view.empire_id, target_sys):
			continue

		# Check intel freshness

		var age: int = view.turn - int(col_info.get("turn_seen", view.turn))
		if age > intel_max_age:
			# Stale intel! Must re-scout before striking
			if not idle_scouts.is_empty():
				var scout_f: Fleet = idle_scouts.pop_back()
				if scout_f.system_id != target_sys:
					var mv: CmdFleetMove = CmdFleetMove.new()
					mv.empire_id = view.empire_id
					mv.fleet_id = scout_f.id
					mv.system_id = target_sys
					cmds.append(mv)
					if memory != null:
						memory.re_scout_sent[cid] = view.turn
			# Do not strike with stale intel
			continue

		# Fresh intel: check strike sizing
		if idle_armed_fleets.is_empty():
			break

		# Calculate total available strike power and medium warships
		var total_idle_power: int = 0
		var medium_warships_count: int = 0
		for f in idle_armed_fleets:
			total_idle_power += Power.fleet_obj_power(view.db, view.raw_game_state_DO_NOT_USE_EXCEPT_SIM(), f)
			for sid in f.ship_ids:
				var s: Ship = view.own_ship(sid)
				if s != null and view.raw_game_state_DO_NOT_USE_EXCEPT_SIM().designs.has(s.design_id):
					var des: ShipDesign = view.raw_game_state_DO_NOT_USE_EXCEPT_SIM().designs[s.design_id]
					if not des.weapons.is_empty() and des.hull != "small":
						medium_warships_count += 1

		var min_warships: int = 6 if (bool(col_info.get("is_capital", true)) and estimated_defense >= 2000) else 1
		if medium_warships_count >= min_warships and total_idle_power * 100 >= strike_ratio * estimated_defense:
			for f in idle_armed_fleets:
				if f.system_id != target_sys and f.dest_system_id != target_sys:
					var mv: CmdFleetMove = CmdFleetMove.new()
					mv.empire_id = view.empire_id
					mv.fleet_id = f.id
					mv.system_id = target_sys
					cmds.append(mv)
			idle_armed_fleets.clear()
			break

	# 2b. Dispatch idle boot ships to follow friendly forces to enemy systems
	if not idle_boot_ships.is_empty():
		for cid in seen_cols.keys():
			var col_info: Dictionary = seen_cols[cid]
			var c_owner: int = int(col_info.get("owner", -1))
			if not enemy_ids.has(c_owner):
				continue
			var target_sys: int = view.colony_system_id(cid)
			if target_sys < 0:
				continue
			if not FuelRange.in_range_system(view.db, view.raw_game_state_DO_NOT_USE_EXCEPT_SIM(), view.empire_id, target_sys):
				continue

			var has_friendly_force: bool = false

			for f in own_fleets:
				if f.system_id == target_sys or f.dest_system_id == target_sys:
					for sid in f.ship_ids:
						var s: Ship = view.own_ship(sid)
						if s != null:
							var des: ShipDesign = view.raw_game_state_DO_NOT_USE_EXCEPT_SIM().designs.get(s.design_id)
							if des != null and not des.weapons.is_empty():
								has_friendly_force = true
								break
				if has_friendly_force:
					break

			if has_friendly_force:
				var def_count: int = int(col_info.get("garrison", 0)) + IntMath.ceil_div(int(col_info.get("pop_units", 1)), 2)
				var req_marines: int = IntMath.ceil_div(def_count * view.db.bal("invade_ratio_pct"), 100)
				var req_boot_ships: int = maxi(4, IntMath.ceil_div(req_marines, 4))

				var staging_boot_ships: Array[Fleet] = []
				var total_staging_ships: int = 0
				for bf in idle_boot_ships:
					if bf.system_id != target_sys and bf.dest_system_id != target_sys:
						staging_boot_ships.append(bf)
						total_staging_ships += bf.ship_ids.size()

				if total_staging_ships >= req_boot_ships:
					var base_bf: Fleet = staging_boot_ships[0]
					for i in range(1, staging_boot_ships.size()):
						var other_bf: Fleet = staging_boot_ships[i]
						if other_bf.system_id == base_bf.system_id:
							var mrg: CmdFleetMerge = CmdFleetMerge.new()
							mrg.empire_id = view.empire_id
							mrg.fleet_id = base_bf.id
							mrg.other_id = other_bf.id
							cmds.append(mrg)

					var b_mv: CmdFleetMove = CmdFleetMove.new()
					b_mv.empire_id = view.empire_id
					b_mv.fleet_id = base_bf.id
					b_mv.system_id = target_sys
					cmds.append(b_mv)
					idle_boot_ships.clear()
					break

	# 3. Ensure sufficient Boot Ships are available or in production during war
	var target_def_count: int = 4
	for cid in seen_cols.keys():
		var col_info: Dictionary = seen_cols[cid]
		if enemy_ids.has(int(col_info.get("owner", -1))):
			var d_cnt: int = int(col_info.get("garrison", 0)) + IntMath.ceil_div(int(col_info.get("pop_units", 1)), 2)
			if d_cnt > target_def_count:
				target_def_count = d_cnt

	var needed_marines: int = IntMath.ceil_div(target_def_count * view.db.bal("invade_ratio_pct"), 100)
	var needed_boot_ships: int = maxi(4, IntMath.ceil_div(needed_marines, 4))

	var total_boot_ships: int = 0
	for f in own_fleets:
		for sid in f.ship_ids:
			var s: Ship = view.own_ship(sid)
			if s != null:
				var des: ShipDesign = view.raw_game_state_DO_NOT_USE_EXCEPT_SIM().designs.get(s.design_id)
				if des != null and des.specials.has("boot_pod"):
					total_boot_ships += 1

	var queued_boot_ships: int = 0
	for col in view.own_colonies():
		for qi in col.queue:
			if qi.kind == "ship":
				var did: int = int(qi.ref_id)
				var des: ShipDesign = view.raw_game_state_DO_NOT_USE_EXCEPT_SIM().designs.get(did)
				if des != null and des.specials.has("boot_pod"):
					queued_boot_ships += 1

	if total_boot_ships + queued_boot_ships < needed_boot_ships:
		var best_yard: Colony = null
		var best_yard_ind: int = -1
		for c in view.own_colonies():
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

		if best_yard != null:
			var boot_des: ShipDesign = null
			for d in view.own_designs():
				if not d.obsolete and d.specials.has("boot_pod"):
					boot_des = d
					break
			if boot_des == null:
				boot_des = AutoDesign.design_for_role(view.db, view.raw_game_state_DO_NOT_USE_EXCEPT_SIM(), view.empire_id, "boot_ship")
				if boot_des != null:
					boot_des.id = view.raw_game_state_DO_NOT_USE_EXCEPT_SIM().alloc_id("design")
					view.raw_game_state_DO_NOT_USE_EXCEPT_SIM().designs[boot_des.id] = boot_des

			if boot_des != null:
				if best_yard.queue.size() >= view.db.bal("queue_max"):
					for i in range(best_yard.queue.size() - 1, -1, -1):
						if str(best_yard.queue[i].added_by) == "governor":
							var rm_cmd: CmdQueueRemove = CmdQueueRemove.new()
							rm_cmd.empire_id = view.empire_id
							rm_cmd.colony_id = best_yard.id
							rm_cmd.index = i
							cmds.append(rm_cmd)
							break
				var q_cmd: CmdQueueAdd = CmdQueueAdd.new()
				q_cmd.empire_id = view.empire_id
				q_cmd.colony_id = best_yard.id
				q_cmd.kind_item = "ship"
				q_cmd.ref_id = str(boot_des.id)
				q_cmd.count = 1
				cmds.append(q_cmd)

	# 4. If at war and under strike requirement, ensure shipyards are actively producing warships
	var min_strike_needed: int = 999999999
	for cid in seen_cols.keys():
		var col_info: Dictionary = seen_cols[cid]
		var c_owner: int = int(col_info.get("owner", -1))
		if not enemy_ids.has(c_owner):
			continue
		var est_def: int = AiAssess.estimate_colony_defense(view, col_info, cid)
		var req: int = IntMath.ceil_div(est_def * strike_ratio, 100)
		if req < min_strike_needed:
			min_strike_needed = req

	if min_strike_needed < 999999999:
		var current_idle_power: int = 0
		var current_warships: int = 0
		for f in idle_armed_fleets:
			current_idle_power += Power.fleet_obj_power(view.db, view.raw_game_state_DO_NOT_USE_EXCEPT_SIM(), f)
			for sid in f.ship_ids:
				var s: Ship = view.own_ship(sid)
				if s != null and view.raw_game_state_DO_NOT_USE_EXCEPT_SIM().designs.has(s.design_id):
					var des: ShipDesign = view.raw_game_state_DO_NOT_USE_EXCEPT_SIM().designs[s.design_id]
					if not des.weapons.is_empty() and des.hull != "small":
						current_warships += 1

		if current_idle_power < min_strike_needed or current_warships < 5:
			var queued_warships: int = 0
			for col in view.own_colonies():
				for qi in col.queue:
					if qi.kind == "ship":
						var did: int = int(qi.ref_id)
						var des: ShipDesign = view.raw_game_state_DO_NOT_USE_EXCEPT_SIM().designs.get(did)
						if des != null and not des.weapons.is_empty():
							queued_warships += 1

			if queued_warships < 2:
				var best_yard: Colony = null
				var best_yard_ind: int = -1
				for c in view.own_colonies():
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

				if best_yard != null:
					var role: String = MilitaryBudget.next_role(view)
					var war_des: ShipDesign = AutoDesign.design_for_role(view.db, view.raw_game_state_DO_NOT_USE_EXCEPT_SIM(), view.empire_id, role)
					if war_des == null:
						war_des = AutoDesign.design_for_role(view.db, view.raw_game_state_DO_NOT_USE_EXCEPT_SIM(), view.empire_id, "talon_line")
					if war_des != null:
						var war_des_id: int = -1
						for d in view.own_designs():
							if not d.obsolete and d.name == war_des.name:
								war_des_id = d.id
								break
						if war_des_id < 0:
							war_des.id = view.raw_game_state_DO_NOT_USE_EXCEPT_SIM().alloc_id("design")
							view.raw_game_state_DO_NOT_USE_EXCEPT_SIM().designs[war_des.id] = war_des
							war_des_id = war_des.id

						if best_yard.queue.size() >= view.db.bal("queue_max"):
							for i in range(best_yard.queue.size() - 1, -1, -1):
								if str(best_yard.queue[i].added_by) == "governor" or str(best_yard.queue[i].kind) == "trade_goods":
									var rm_cmd: CmdQueueRemove = CmdQueueRemove.new()
									rm_cmd.empire_id = view.empire_id
									rm_cmd.colony_id = best_yard.id
									rm_cmd.index = i
									cmds.append(rm_cmd)
									break
						var q_cmd: CmdQueueAdd = CmdQueueAdd.new()
						q_cmd.empire_id = view.empire_id
						q_cmd.colony_id = best_yard.id
						q_cmd.kind_item = "ship"
						q_cmd.ref_id = str(war_des_id)
						q_cmd.count = 1
						if not best_yard.queue.is_empty() and (str(best_yard.queue[0].kind) == "trade_goods" or str(best_yard.queue[0].added_by) == "governor"):
							q_cmd.index = 0
						cmds.append(q_cmd)

	return cmds

static func can_launch_strike(view: AiView, own_power: int, estimated_defense: int, is_floor: bool) -> bool:
	var strike_ratio: int = 130 if is_floor else view.db.bal("strike_ratio_pct")
	return own_power * 100 >= strike_ratio * estimated_defense
