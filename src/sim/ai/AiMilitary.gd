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

		if has_boot:
			idle_boot_ships.append(f)
		elif is_armed:
			idle_armed_fleets.append(f)
		elif is_scout:
			idle_scouts.append(f)

	# 1. Check invasion for colonies where orbit is already secured
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
							inv_cmd.planet_id = p.id
							cmds.append(inv_cmd)
							break

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
		var estimated_defense: int = AiAssess.estimate_colony_defense(view, col_info)
		if memory != null and memory.failures_in_window(cid, view.turn, failure_window) > 0:
			var last_met: int = memory.get_last_defense_met(cid)
			if last_met > 0:
				estimated_defense = max(estimated_defense, IntMath.pct(last_met, view.db.bal("strike_retry_ratio_pct")))

		var target_sys: int = view.colony_system_id(cid)
		if target_sys < 0:
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

		# Calculate total available strike power
		var total_idle_power: int = 0
		for f in idle_armed_fleets:
			total_idle_power += Power.fleet_obj_power(view.db, view.raw_game_state_DO_NOT_USE_EXCEPT_SIM(), f)

		# Check strike sizing condition: own >= strike_ratio_pct x estimated_defense
		if total_idle_power * 100 >= strike_ratio * estimated_defense:
			# Launch strike fleet!
			for f in idle_armed_fleets:
				if f.system_id != target_sys:
					var mv: CmdFleetMove = CmdFleetMove.new()
					mv.empire_id = view.empire_id
					mv.fleet_id = f.id
					mv.system_id = target_sys
					cmds.append(mv)
			idle_armed_fleets.clear()

			# Send boot ships if available
			for bf in idle_boot_ships:
				if bf.system_id != target_sys:
					var b_mv: CmdFleetMove = CmdFleetMove.new()
					b_mv.empire_id = view.empire_id
					b_mv.fleet_id = bf.id
					b_mv.system_id = target_sys
					cmds.append(b_mv)
			idle_boot_ships.clear()
			break

	return cmds

static func can_launch_strike(view: AiView, own_power: int, estimated_defense: int, is_floor: bool) -> bool:
	var strike_ratio: int = 130 if is_floor else view.db.bal("strike_ratio_pct")
	return own_power * 100 >= strike_ratio * estimated_defense
