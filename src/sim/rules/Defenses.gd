class_name Defenses
extends RefCounted

static func get_best_plate_pct(gs: GameState, db: ContentDB, empire_id: int) -> int:
	if gs == null or empire_id < 0 or empire_id >= gs.empires.size():
		return 100
	var emp: Empire = gs.empires[empire_id]
	var known: Array = emp.tech.known if emp.tech != null else []
	if known.has("unsinkable_plate") or known.has("unsinkable_hull"):
		return 350
	if known.has("marrow_plate") or known.has("marrow"):
		return 275
	if known.has("keel_plate") or known.has("the_keel"):
		return 200
	if known.has("joined_plate") or known.has("proper_joinery"):
		return 150
	return 100

static func get_best_horizon_weapon(gs: GameState, db: ContentDB, empire_id: int) -> String:
	if gs == null or empire_id < 0 or empire_id >= gs.empires.size():
		return "hatch_dart"
	var emp: Empire = gs.empires[empire_id]
	var known: Array = emp.tech.known if emp.tech != null else []
	if known.has("quiet_star") or known.has("indoor_torpedo"):
		return "indoor_torpedo"
	if known.has("cited_dart"):
		return "cited_dart"
	if known.has("ink_dart"):
		return "ink_dart"
	if known.has("hatch_dart"):
		return "hatch_dart"
	return "hatch_dart"

static func get_best_talon_weapon(gs: GameState, db: ContentDB, empire_id: int) -> String:
	if gs == null or empire_id < 0 or empire_id >= gs.empires.size():
		return "wick_talon"
	var emp: Empire = gs.empires[empire_id]
	var known: Array = emp.tech.known if emp.tech != null else []
	if known.has("last_glare") or known.has("hyper_preened_thermals"):
		return "last_glare"
	if known.has("banded_glare") or known.has("focused_glare"):
		return "banded_glare"
	if known.has("sun_quill") or known.has("second_sun"):
		return "sun_quill"
	return "wick_talon"

static func get_best_mantle_shield(gs: GameState, db: ContentDB, empire_id: int) -> int:
	if gs == null or empire_id < 0 or empire_id >= gs.empires.size():
		return 0
	var emp: Empire = gs.empires[empire_id]
	var known: Array = emp.tech.known if emp.tech != null else []
	if known.has("closed_season"):
		return 9
	if known.has("full_mantle"):
		return 6
	if known.has("half_mantle"):
		return 4
	if known.has("dust_cover"):
		return 2
	return 0

static func calc_max_defense_hp(gs: GameState, db: ContentDB, colony: Colony) -> int:
	var raw_hp: int = 0
	for bid in colony.buildings:
		var bdef: Dictionary = db.def("buildings", bid) if db != null else {}
		var def_blk: Dictionary = bdef.get("defense", {})
		raw_hp += int(def_blk.get("hp", 0))

	if raw_hp <= 0:
		return 0

	var plate_pct: int = get_best_plate_pct(gs, db, colony.owner)
	var hp_with_plate: int = IntMath.floor_div(raw_hp * plate_pct, 100)

	var mod_pct: int = 0
	if gs != null and colony.owner >= 0 and colony.owner < gs.empires.size():
		var emp: Empire = gs.empires[colony.owner]
		if emp.traits.has("huddle"):
			mod_pct += 30

	return IntMath.floor_div(hp_with_plate * (100 + mod_pct), 100)

static func calc_planet_shield(db: ContentDB, colony: Colony) -> int:
	var best_shield: int = 0
	for bid in colony.buildings:
		var bdef: Dictionary = db.def("buildings", bid) if db != null else {}
		var def_blk: Dictionary = bdef.get("defense", {})
		var sh: int = int(def_blk.get("planet_shield", 0))
		if sh > best_shield:
			best_shield = sh
	return best_shield

static func build_defense_party(gs: GameState, db: ContentDB, colony: Colony) -> CombatParty:
	var party := CombatParty.new()
	party.party_id = 10000 + colony.id
	party.empire_id = colony.owner
	party.is_colony_defense = true
	party.colony_id = colony.id
	party.planet_shield = calc_planet_shield(db, colony)
	party.posture = "auto"

	var max_hp: int = calc_max_defense_hp(gs, db, colony)
	if colony.defense_hp > max_hp:
		colony.defense_hp = max_hp
	if colony.defense_hp <= 0:
		# Suppressed defenses
		return party

	var u := CombatUnit.new()
	u.uid = 10000 + colony.id
	u.empire_id = colony.owner
	u.is_planet = true
	u.hull_id = "planet"
	u.hull_space = 999
	u.hp = colony.defense_hp
	u.hp_max = max_hp
	u.shield = get_best_mantle_shield(gs, db, colony.owner)
	u.evasion = 0
	u.acc = 0
	u.combat_speed = 0
	u.line_slots = 0
	u.is_armed = false

	# Add weapons from defense buildings
	for bid in colony.buildings:
		var bdef: Dictionary = db.def("buildings", bid) if db != null else {}
		var def_blk: Dictionary = bdef.get("defense", {})
		if def_blk.has("launchers"):
			var l_count: int = int(def_blk.get("launchers", 3))
			var w_id: String = get_best_horizon_weapon(gs, db, colony.owner)
			var w_row: Dictionary = db.def("parts", w_id) if db != null else {}
			for i in range(l_count):
				u.weapons.append({
					"part_id": w_id,
					"band": "horizon",
					"dmg_min": int(w_row.get("dmg_min", 5)),
					"dmg_max": int(w_row.get("dmg_max", 5)),
					"acc": int(w_row.get("acc", 0)),
					"falloff_pct": 0,
					"salvos": -1, # Unlimited ammo for planet Horizon launchers
					"every_other_round": false,
					"swat": false
				})
			u.is_armed = true
			u.main_band = "horizon"

		if def_blk.has("talons"):
			var t_count: int = int(def_blk.get("talons", 4))
			var w_id: String = get_best_talon_weapon(gs, db, colony.owner)
			var w_row: Dictionary = db.def("parts", w_id) if db != null else {}
			var is_primary: bool = (str(def_blk.get("mount", "")) == "primary_mount")
			var falloff: int = 2 if is_primary else int(w_row.get("falloff_pct", 4))
			var dmg_pct: int = 150 if is_primary else 100
			for i in range(t_count):
				u.weapons.append({
					"part_id": w_id,
					"band": "talon",
					"dmg_min": IntMath.floor_div(int(w_row.get("dmg_min", 3)) * dmg_pct, 100),
					"dmg_max": IntMath.floor_div(int(w_row.get("dmg_max", 8)) * dmg_pct, 100),
					"acc": int(w_row.get("acc", 0)),
					"falloff_pct": falloff,
					"salvos": -1,
					"every_other_round": false,
					"swat": false
				})
			u.is_armed = true
			if u.main_band == "":
				u.main_band = "talon"

	party.units = [u]
	return party
