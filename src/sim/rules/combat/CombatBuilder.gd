class_name CombatBuilder
extends RefCounted

static func ai_orders(fleet: Fleet) -> Dictionary:
	if fleet == null or fleet.plan == null:
		return {
			"posture": "auto",
			"target_priority": "auto",
			"swat_mode": "missiles_first",
			"retreat_threshold": "never",
			"line_order": []
		}
	var bp: BattlePlan = fleet.plan
	var sm: String = "missiles_first" if bp.swat_mode == "missiles" or bp.swat_mode == "missiles_first" else "ships_first"
	return {
		"posture": bp.posture if bp.posture != "" else "auto",
		"target_priority": bp.target_priority if bp.target_priority != "" else "auto",
		"swat_mode": sm,
		"retreat_threshold": bp.retreat_threshold if bp.retreat_threshold != "" else "never",
		"line_order": fleet.line_order.duplicate()
	}

static func build(gs: GameState, db: ContentDB, system_id: int, custom_orders: Dictionary = {}) -> CombatInput:
	var input := CombatInput.new()
	input.system_id = system_id
	input.turn = gs.turn
	input.seed = gs.settings.seed if gs.settings != null else 42

	# Group fleets by empire
	var fleets_by_empire: Dictionary = {}
	for f in gs.fleets.values():
		if f.system_id == system_id:
			var emp_id: int = f.owner
			if not fleets_by_empire.has(emp_id):
				fleets_by_empire[emp_id] = []
			fleets_by_empire[emp_id].append(f)

	# Build parties per empire
	var next_party_id: int = 0
	for emp_id in fleets_by_empire.keys():
		var flist: Array = fleets_by_empire[emp_id]
		var party := CombatParty.new()
		party.party_id = next_party_id
		next_party_id += 1
		party.empire_id = emp_id

		for f in flist:
			party.fleet_ids.append(f.id)

		# Empire race & traits
		if emp_id >= 0 and emp_id < gs.empires.size():
			var emp: Empire = gs.empires[emp_id]
			party.traits = emp.traits.duplicate()
			var rdef: Dictionary = db.def("races", emp.race) if db != null else {}
			party.max_line_slots = int(rdef.get("line_slots", 8))
		elif emp_id == Monsters.MONSTER_EMPIRE_ID:
			party.max_line_slots = 8

		# Build units from ships
		for f in flist:
			for sid in f.ship_ids:
				if not gs.ships.has(sid):
					continue
				var s: Ship = gs.ships[sid]
				if s.hp <= 0:
					continue
				var u := CombatUnit.new()
				u.uid = s.id
				u.ship_id = s.id
				u.empire_id = emp_id
				u.hp = s.hp

				if s.design_id >= 0 and gs.designs.has(s.design_id):
					var des: ShipDesign = gs.designs[s.design_id]
					u.name_key = des.name
					u.design_id = str(des.id)
					u.hull_id = des.hull
					var st: Dictionary = DesignRules.stats(db, gs, des)
					u.hp_max = int(st.get("hp", s.hp))
					if u.hp == 0:
						u.hp = u.hp_max
					u.hull_space = int(st.get("space", 24))
					u.shield = int(st.get("shield", 0))
					u.evasion = int(st.get("evasion", 0))
					u.acc = int(st.get("acc", 0))
					u.combat_speed = int(st.get("combat_speed", 1))
					u.line_slots = 2 if des.hull == "titan" else 1
					u.is_armed = bool(st.get("is_armed", false))
					u.main_band = str(st.get("main_band", ""))
					u.specials = des.specials.duplicate()
					for sp in des.specials:
						if sp == "gone_to_molt": u.gone_to_molt = true
						elif sp == "not_this_feather": u.not_this_feather = true
						elif sp == "self_sealing_nest": u.self_sealing = true
						elif sp == "miss_field_1": u.miss_field = 20
						elif sp == "miss_field_2": u.miss_field = 40
						elif sp.ends_with("_pod"): u.has_pods = true

					# Mounts
					for w in des.weapons:
						var p_id: String = str(w.get("part", ""))
						var m_id: String = str(w.get("mount", ""))
						var cnt: int = int(w.get("count", 1))
						var p_row: Dictionary = db.row("parts", p_id) if db != null else {}
						var m_row: Dictionary = db.row("parts", m_id) if (db != null and m_id != "") else {}
						var is_swat: bool = bool(m_row.get("swat", false))
						if is_swat: u.is_swat = true

						var base_acc: int = int(p_row.get("acc", 0)) + int(m_row.get("acc", 0))
						var falloff: int = int(m_row.get("falloff_pct", -1))
						if falloff == -1: falloff = int(p_row.get("falloff_pct", 4))

						var dmg_pct: int = int(m_row.get("dmg_pct", 100))
						var d_min: int = IntMath.floor_div(int(p_row.get("dmg_min", 0)) * dmg_pct, 100)
						var d_max: int = IntMath.floor_div(int(p_row.get("dmg_max", 0)) * dmg_pct, 100)

						for _k in range(cnt):
							u.weapons.append({
								"part_id": p_id,
								"band": str(p_row.get("band", "talon")),
								"dmg_min": d_min,
								"dmg_max": d_max,
								"acc": base_acc,
								"falloff_pct": falloff,
								"salvos": int(p_row.get("salvos", -1)),
								"every_other_round": bool(p_row.get("every_other_round", false)),
								"swat": is_swat
							})
				elif emp_id == Monsters.MONSTER_EMPIRE_ID:
					# Monster unit
					var m_party := Monsters.build_monster_party(db, f.name.to_lower(), party.party_id)
					if not m_party.units.is_empty():
						u = m_party.units[0]
						u.uid = s.id
						u.ship_id = s.id
						u.hp = s.hp

				party.units.append(u)

		# Apply orders
		if custom_orders.has(emp_id):
			var co: Dictionary = custom_orders[emp_id]
			party.posture = str(co.get("posture", "auto"))
			party.target_priority = str(co.get("target_priority", "auto"))
			party.swat_mode = str(co.get("swat_mode", "missiles_first"))
			party.retreat_threshold = str(co.get("retreat_threshold", "never"))
			var lo_raw: Array = co.get("line_order", [])
			for x in lo_raw: party.line_order.append(int(x))
		else:
			# Standing plan from largest armed PP fleet
			var best_fleet: Fleet = null
			for f in flist:
				if best_fleet == null or f.id < best_fleet.id:
					best_fleet = f
			var ords: Dictionary = ai_orders(best_fleet)
			party.posture = str(ords.get("posture", "auto"))
			party.target_priority = str(ords.get("target_priority", "auto"))
			party.swat_mode = str(ords.get("swat_mode", "missiles_first"))
			party.retreat_threshold = str(ords.get("retreat_threshold", "never"))
			var lo_raw: Array = ords.get("line_order", [])
			for x in lo_raw: party.line_order.append(int(x))

		input.parties.append(party)

	# Colony defense party
	for col in gs.colonies.values():
		var sys: StarSystem = gs.system_of_planet(col.planet_id)
		if sys != null and sys.id == system_id and col.defense_hp > 0:
			var def_party := Defenses.build_defense_party(gs, db, col)
			def_party.party_id = next_party_id
			next_party_id += 1
			input.parties.append(def_party)

	# Start distances from stalemates or defaults
	for i in range(input.parties.size()):
		for j in range(i + 1, input.parties.size()):
			var p_a: CombatParty = input.parties[i]
			var p_b: CombatParty = input.parties[j]
			var key: String = "%d_%d" % [mini(p_a.party_id, p_b.party_id), maxi(p_a.party_id, p_b.party_id)]
			if gs.stalemates.has(system_id) and gs.stalemates[system_id] is Dictionary and gs.stalemates[system_id].has(key):
				input.start_distances[key] = int(gs.stalemates[system_id][key])
			else:
				input.start_distances[key] = 10

	return input
