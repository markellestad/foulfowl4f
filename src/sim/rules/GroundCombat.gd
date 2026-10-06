class_name GroundCombat
extends RefCounted

static func can_invade(gs: GameState, db: ContentDB, fleet_id: int, colony_id: int) -> String:
	if gs == null or not gs.fleets.has(fleet_id):
		return "refuse.unknown"
	var flt: Fleet = gs.fleets[fleet_id]
	if flt.system_id < 0:
		return "refuse.in_transit"
	if not gs.colonies.has(colony_id):
		return "refuse.unknown"
	var col: Colony = gs.colonies[colony_id]
	var sys: StarSystem = gs.system_of_planet(col.planet_id)
	if sys == null or sys.id != flt.system_id:
		return "refuse.not_here"
	if not Wars.is_at_war(gs, flt.owner, col.owner):
		return "refuse.not_at_war"

	var has_marines: bool = false
	for sid in flt.ship_ids:
		var s: Ship = gs.ships.get(sid)
		if s != null and s.design_id >= 0 and gs.designs.has(s.design_id):
			var des: ShipDesign = gs.designs[s.design_id]
			if des.specials.has("boot_pod"):
				has_marines = true
				break
	if not has_marines:
		return "refuse.no_marines"

	if col.defense_hp > 0:
		return "refuse.defenses_active"

	return ""

static func resolve_invasion(gs: GameState, db: ContentDB, fleet: Fleet, colony: Colony, report: TurnReport = null) -> bool:
	var marine_base: int = db.bal("marine_base")
	var militia_base: int = db.bal("militia_base")
	var occupied_turns: int = db.bal("occupied_turns")

	var att_emp: Empire = gs.empires[fleet.owner] if (fleet.owner >= 0 and fleet.owner < gs.empires.size()) else null
	var def_emp: Empire = gs.empires[colony.owner] if (colony.owner >= 0 and colony.owner < gs.empires.size()) else null

	var att_str_add: int = 0
	var att_troops_pct: int = 0
	var def_str_add: int = 0
	var def_troops_pct: int = 0
	var def_ground_def_pct: int = 0

	var marine_count: int = 0
	var boot_ship_ids: Array[int] = []
	for sid in fleet.ship_ids:
		var s: Ship = gs.ships.get(sid)
		if s != null and s.design_id >= 0 and gs.designs.has(s.design_id):
			var des: ShipDesign = gs.designs[s.design_id]
			var pod_count: int = 0
			for sp in des.specials:
				if sp == "boot_pod":
					pod_count += 1
			if pod_count > 0:
				marine_count += pod_count * 4
				boot_ship_ids.append(sid)

	var s_a: int = IntMath.floor_div((marine_base + att_str_add) * (100 + att_troops_pct), 100)
	var s_d_garrison: int = IntMath.floor_div((marine_base + def_str_add) * (100 + def_troops_pct), 100)
	var s_d_militia: int = IntMath.floor_div((militia_base + def_str_add) * (100 + def_troops_pct + def_ground_def_pct), 100)

	var defenders: Array[Dictionary] = []
	for i in range(colony.garrison):
		defenders.append({"is_garrison": true, "strength": s_d_garrison})
	var militia_count: int = IntMath.ceil_div(colony.pop_units(), 2)
	for i in range(militia_count):
		defenders.append({"is_garrison": false, "strength": s_d_militia})

	var duel_index: int = 0
	var attackers_remaining: int = marine_count

	while attackers_remaining > 0 and not defenders.is_empty():
		var def_unit: Dictionary = defenders[0]
		var s_d: int = int(def_unit["strength"])
		var rng: Rng = Rng.keyed(gs.settings.seed, gs.turn, Rng.GROUND, colony.id, duel_index)
		duel_index += 1

		var roll: int = rng.range_i(1, s_a + s_d)
		if roll <= s_a:
			if def_unit["is_garrison"]:
				colony.garrison = maxi(0, colony.garrison - 1)
			defenders.pop_front()
		else:
			attackers_remaining -= 1

	for sid in boot_ship_ids:
		fleet.ship_ids.erase(sid)
		gs.ships.erase(sid)
	if fleet.ship_ids.is_empty():
		gs.fleets.erase(fleet.id)
	else:
		fleet.order.clear()

	var success: bool = (attackers_remaining > 0 and defenders.is_empty())
	var planet: Planet = gs.planets[colony.planet_id]
	var place_str: String = "Star %d Orbit %d" % [planet.system_id, planet.orbit + 1]

	if success:
		if def_emp != null and def_emp.capital_colony_id == colony.id:
			def_emp.capital_colony_id = -1
		colony.owner = fleet.owner
		colony.queue.clear()
		colony.progress_pp = 0
		var has_unification: bool = (att_emp != null and att_emp.traits.has("unification"))
		if has_unification:
			colony.occupied_until = -1
		else:
			colony.occupied_until = gs.turn + occupied_turns
		if report != null:
			report.add_entry("orbital", "notify.invasion_won", {"place": place_str}, "colony", colony.id)
		return true
	else:
		if report != null:
			report.add_entry("orbital", "notify.invasion_lost", {"place": place_str}, "colony", colony.id)
		return false
