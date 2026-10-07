class_name CombatApply
extends RefCounted

static func apply(gs: GameState, db: ContentDB, log: BattleLog) -> void:
	if gs == null or log == null:
		return

	# 1. Apply HP and losses to ships and colony defenses
	var emp_ids: Array[int] = []
	for u in log.initial_units:
		var eid: int = int(u.get("empire_id", -1))
		if eid >= 0 and not emp_ids.has(eid):
			emp_ids.append(eid)
	for i in range(emp_ids.size()):
		for j in range(i + 1, emp_ids.size()):
			Wars.record_battle(gs, emp_ids[i], emp_ids[j])

	for u_dict in log.final_units:
		var uid: int = int(u_dict.get("uid", -1))
		var is_planet: bool = bool(u_dict.get("is_planet", false))
		var cur_hp: int = int(u_dict.get("hp", 0))

		if is_planet:
			var col_id: int = uid - 10000
			if gs.colonies.has(col_id):
				var col: Colony = gs.colonies[col_id]
				col.defense_hp = maxi(0, cur_hp)
		else:
			if gs.ships.has(uid):
				var s: Ship = gs.ships[uid]
				if cur_hp <= 0:
					if gs.fleets.has(s.fleet_id):
						var f: Fleet = gs.fleets[s.fleet_id]
						f.ship_ids.erase(s.id)
					else:
						for f in gs.fleets.values():
							if f.system_id == log.system_id:
								f.ship_ids.erase(s.id)
					gs.ships.erase(uid)
				else:
					s.hp = cur_hp

	# Clean up empty fleets
	var empty_fleets: Array[int] = []
	for fid in gs.fleets.keys():
		var f: Fleet = gs.fleets[fid]
		if f.system_id == log.system_id and f.ship_ids.is_empty():
			empty_fleets.append(fid)
	for fid in empty_fleets:
		gs.fleets.erase(fid)

	# 2. Winner effects
	if log.winner_empire_id >= 0:
		var winner_id: int = log.winner_empire_id
		# Veterancy for surviving ships of winner (+5, max 15)
		for u_dict in log.final_units:
			var uid: int = int(u_dict.get("uid", -1))
			var emp_id: int = int(u_dict.get("empire_id", -1))
			var cur_hp: int = int(u_dict.get("hp", 0))
			if emp_id == winner_id and cur_hp > 0 and gs.ships.has(uid):
				var s: Ship = gs.ships[uid]
				s.veterancy = mini(15, s.veterancy + 5)

		# Sole remaining armed side controls orbit: enemy unarmed ships destroyed
		var enemy_unarmed_ships: Array[int] = []
		for f in gs.fleets.values():
			if f.system_id == log.system_id and f.owner != winner_id:
				for sid in f.ship_ids:
					if gs.ships.has(sid):
						var s: Ship = gs.ships[sid]
						if gs.designs.has(s.design_id):
							var des: ShipDesign = gs.designs[s.design_id]
							var st: Dictionary = DesignRules.stats(db, gs, des)
							if not bool(st.get("is_armed", false)):
								enemy_unarmed_ships.append(sid)
		for sid in enemy_unarmed_ships:
			var s: Ship = gs.ships[sid]
			if gs.fleets.has(s.fleet_id):
				gs.fleets[s.fleet_id].ship_ids.erase(sid)
			gs.ships.erase(sid)

		# Learn loser's designs
		if gs.knowledge.has(winner_id):
			var knw: Knowledge = gs.knowledge[winner_id]
			for u_dict in log.initial_units:
				var emp_id: int = int(u_dict.get("empire_id", -1))
				var did_str: String = str(u_dict.get("design_id", ""))
				if emp_id != winner_id and did_str != "" and did_str.is_valid_int():
					var did: int = did_str.to_int()
					if gs.designs.has(did):
						knw.known_designs[did] = gs.designs[did].to_dict()

		# Guardian killed check
		for u_dict in log.initial_units:
			if u_dict.get("name_key") == "guardian":
				var g_uid: int = int(u_dict["uid"])
				for fu in log.final_units:
					if fu["uid"] == g_uid and int(fu["hp"]) <= 0:
						gs.loot["guardian"] = winner_id
						gs.loot["pending_guardian_techs"] = 2

	# Store log in gs.battle_logs (keep only last 20)
	gs.battle_logs.append(log.to_dict())
	while gs.battle_logs.size() > 20:
		gs.battle_logs.pop_front()

	# Stalemates
	if log.is_stalemate:
		gs.stalemates[log.system_id] = log.final_distances.duplicate()
	else:
		gs.stalemates.erase(log.system_id)
