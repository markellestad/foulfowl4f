class_name Blockade
extends RefCounted

static func get_orbit_controller(gs: GameState, db: ContentDB, system_id: int) -> int:
	return orbit_controller_for_system(gs, db, system_id)

static func orbit_controller_for_system(gs: GameState, db: ContentDB, system_id: int) -> int:
	if gs == null or system_id < 0 or system_id >= gs.systems.size():
		return -1

	var armed_empires: Array[int] = []

	for f in gs.fleets.values():
		if f.system_id == system_id:
			var has_armed: bool = false
			for sid in f.ship_ids:
				var s: Ship = gs.ships.get(sid)
				if s != null and s.hp > 0:
					if s.owner == Monsters.MONSTER_EMPIRE_ID:
						has_armed = true
						break
					elif s.design_id >= 0 and gs.designs.has(s.design_id):
						var des: ShipDesign = gs.designs[s.design_id]
						var st: Dictionary = DesignRules.stats(db, gs, des)
						if bool(st.get("armed", st.get("is_armed", false))):
							has_armed = true
							break
			if has_armed and not armed_empires.has(f.owner):
				armed_empires.append(f.owner)

	for col in gs.colonies.values():
		var sys: StarSystem = gs.system_of_planet(col.planet_id)
		if sys != null and sys.id == system_id and col.defense_hp > 0:
			if not armed_empires.has(col.owner):
				armed_empires.append(col.owner)

	if armed_empires.is_empty():
		return -1

	# Check for mutual hostilities among armed empires
	for i in range(armed_empires.size()):
		for j in range(i + 1, armed_empires.size()):
			if Wars.is_at_war(gs, armed_empires[i], armed_empires[j]):
				return -1

	return armed_empires[0]

static func update_system_blockade(gs: GameState, db: ContentDB, system_id: int, report: TurnReport = null) -> void:
	var ctrl: int = orbit_controller_for_system(gs, db, system_id)

	for col in gs.colonies.values():
		var sys: StarSystem = gs.system_of_planet(col.planet_id)
		if sys == null or sys.id != system_id or col.is_outpost:
			continue

		var should_blockade: bool = (ctrl >= 0 and Wars.is_at_war(gs, ctrl, col.owner))
		if should_blockade:
			if not col.blockaded:
				col.blockaded = true
				if report != null:
					report.add_entry("orbital", "notify.blockaded", {"colony": col.id}, "colony", col.id)
		else:
			if col.blockaded:
				col.blockaded = false
				if report != null:
					report.add_entry("orbital", "notify.blockade_lifted", {"colony": col.id}, "colony", col.id)
