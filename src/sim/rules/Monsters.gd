class_name Monsters
extends RefCounted

const MONSTER_EMPIRE_ID := 100

static func build_monster_party(db: ContentDB, kind: String, party_id: int = 100) -> CombatParty:
	var party := CombatParty.new()
	party.party_id = party_id
	party.empire_id = MONSTER_EMPIRE_ID
	party.posture = "auto"
	party.auto_band = "talon" if kind == "guardian" else "beak"

	var m_table: Dictionary = db.table("monsters") if db != null else {}
	var m_rows: Dictionary = m_table.get("rows", {})
	if not m_rows.has(kind):
		return party

	var m_def: Dictionary = m_rows[kind]
	var units_def: Array = m_def.get("units", [])

	for i in range(units_def.size()):
		var ud: Dictionary = units_def[i]
		var u := CombatUnit.new()
		u.uid = party_id * 100 + i + 1
		u.empire_id = MONSTER_EMPIRE_ID
		u.name_key = str(ud.get("name_key", kind))
		u.design_id = kind
		u.hull_id = kind
		u.hull_space = 600 if kind == "guardian" else 150
		u.hp = int(ud.get("hp", 400))
		u.hp_max = u.hp
		u.shield = int(ud.get("shield", 0))
		u.evasion = int(ud.get("evasion", 0))
		u.acc = int(ud.get("acc", 0))
		u.combat_speed = 1
		u.line_slots = 1
		u.is_armed = true

		var raw_specials: Array = ud.get("specials", [])
		for sp in raw_specials:
			u.specials.append(str(sp))
			if str(sp) == "self_sealing_nest":
				u.self_sealing = true

		var raw_w: Array = ud.get("weapons", [])
		for w in raw_w:
			var part_id: String = str(w.get("part", ""))
			var count: int = int(w.get("count", 1))
			var part_row: Dictionary = db.def("parts", part_id) if db != null else {}
			var band: String = str(part_row.get("band", "talon"))
			for _c in range(count):
				u.weapons.append({
					"part_id": part_id,
					"band": band,
					"dmg_min": int(part_row.get("dmg_min", 10)),
					"dmg_max": int(part_row.get("dmg_max", 10)),
					"acc": int(part_row.get("acc", 0)),
					"falloff_pct": int(part_row.get("falloff_pct", 0)),
					"salvos": int(part_row.get("salvos", -1)),
					"every_other_round": bool(part_row.get("every_other_round", false)),
					"swat": false
				})
		party.units.append(u)

	return party

static func spawn_monsters(gs: GameState, db: ContentDB) -> void:
	if gs == null or db == null:
		return

	# Monster spawns from galaxy generator
	for spawn in gs.monster_spawns:
		var kind: String = str(spawn.get("kind", ""))
		var sys_id: int = int(spawn.get("system_id", -1))
		if sys_id < 0 or sys_id >= gs.systems.size():
			continue
		var sys: StarSystem = gs.systems[sys_id]

		var f := Fleet.new()
		f.id = gs.alloc_id("fleet")
		f.owner = MONSTER_EMPIRE_ID
		f.name = kind
		f.system_id = sys_id
		f.x = sys.x
		f.y = sys.y

		var s := Ship.new()
		s.id = gs.alloc_id("ship")
		s.fleet_id = f.id
		s.owner = MONSTER_EMPIRE_ID
		s.design_id = -1
		s.hp = 3000 if kind == "guardian" else 400
		s.built_turn = 1
		f.ship_ids = [s.id]

		gs.ships[s.id] = s
		gs.fleets[f.id] = f
