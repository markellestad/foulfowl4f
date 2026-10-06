class_name GameState
extends RefCounted

var version: int = 1
var settings: GameSettings = null
var turn: int = 1
var turn_cap: int = 200
var next_ids: Dictionary = {}
var systems: Array[StarSystem] = []
var planets: Array[Planet] = []
var monster_spawns: Array[Dictionary] = []
var gen_min_sep: int = 0
var empires: Array[Empire] = []
var colonies: Dictionary = {}
var designs: Dictionary = {}
var ships: Dictionary = {}
var fleets: Dictionary = {}
var knowledge: Dictionary = {}
var report: TurnReport = null
var cmd_log: Array[Dictionary] = []
var wars: Dictionary = {}
var battle_logs: Array[Dictionary] = []
var stalemates: Dictionary = {}
var monsters_empire: int = 100
var guardian_marked: Dictionary = {}
var loot: Dictionary = {}

func alloc_id(kind: String) -> int:
	var cur: int = int(next_ids.get(kind, 0))
	next_ids[kind] = cur + 1
	return cur

func system_of_planet(planet_id: int) -> StarSystem:
	if planet_id >= 0 and planet_id < planets.size():
		var sys_id: int = planets[planet_id].system_id
		if sys_id >= 0 and sys_id < systems.size():
			return systems[sys_id]
	return null

func to_dict() -> Dictionary:
	var sys_arr: Array = []
	for s in systems:
		sys_arr.append(s.to_dict())
	var plan_arr: Array = []
	for p in planets:
		plan_arr.append(p.to_dict())
	var spawns: Array = []
	for m in monster_spawns:
		spawns.append({
			"kind": str(m.get("kind", "")),
			"system_id": int(m.get("system_id", -1))
		})
	
	var n_ids: Dictionary = {}
	for k in next_ids.keys():
		n_ids[str(k)] = int(next_ids[k])

	var emp_arr: Array = []
	for e in empires:
		emp_arr.append(e.to_dict())

	var col_dict: Dictionary = {}
	for cid in Ids.sorted_keys(colonies):
		col_dict[str(cid)] = colonies[cid].to_dict()

	var des_dict: Dictionary = {}
	for did in Ids.sorted_keys(designs):
		des_dict[str(did)] = designs[did].to_dict()

	var shp_dict: Dictionary = {}
	for sid in Ids.sorted_keys(ships):
		shp_dict[str(sid)] = ships[sid].to_dict()

	var flt_dict: Dictionary = {}
	for fid in Ids.sorted_keys(fleets):
		flt_dict[str(fid)] = fleets[fid].to_dict()

	var knw_dict: Dictionary = {}
	for eid in Ids.sorted_keys(knowledge):
		knw_dict[str(eid)] = knowledge[eid].to_dict()

	var cmds: Array = []
	for c in cmd_log:
		cmds.append(c.duplicate(true))

	var blog_arr: Array = []
	for bl in battle_logs:
		blog_arr.append((bl as Dictionary).duplicate(true))

	return {
		"version": version,
		"settings": settings.to_dict() if settings != null else {},
		"turn": turn,
		"turn_cap": turn_cap,
		"next_ids": n_ids,
		"systems": sys_arr,
		"planets": plan_arr,
		"monster_spawns": spawns,
		"gen_min_sep": gen_min_sep,
		"empires": emp_arr,
		"colonies": col_dict,
		"designs": des_dict,
		"ships": shp_dict,
		"fleets": flt_dict,
		"knowledge": knw_dict,
		"report": report.to_dict() if report != null else null,
		"cmd_log": cmds,
		"wars": wars.duplicate(),
		"battle_logs": blog_arr,
		"stalemates": stalemates.duplicate(true),
		"monsters_empire": monsters_empire,
		"guardian_marked": guardian_marked.duplicate(),
		"loot": loot.duplicate()
	}

static func from_dict(d: Dictionary) -> GameState:
	var gs: GameState = GameState.new()
	gs.version = int(d.get("version", 1))
	var s_dict: Dictionary = d.get("settings", {})
	if not s_dict.is_empty():
		gs.settings = (GameSettings as Variant).call(&"from_dict", s_dict)
	else:
		gs.settings = (GameSettings as Variant).call(&"new")
	gs.turn = int(d.get("turn", 1))
	gs.turn_cap = int(d.get("turn_cap", 200))
	gs.gen_min_sep = int(d.get("gen_min_sep", 0))

	var raw_nids: Dictionary = d.get("next_ids", {})
	gs.next_ids.clear()
	for k in raw_nids.keys():
		gs.next_ids[str(k)] = int(raw_nids[k])

	gs.systems.clear()
	var raw_sys: Array = d.get("systems", [])
	for s_data in raw_sys:
		if s_data is Dictionary:
			gs.systems.append(StarSystem.from_dict(s_data))

	gs.planets.clear()
	var raw_plan: Array = d.get("planets", [])
	for p_data in raw_plan:
		if p_data is Dictionary:
			gs.planets.append(Planet.from_dict(p_data))

	gs.monster_spawns.clear()
	var raw_spawns: Array = d.get("monster_spawns", [])
	for m_data in raw_spawns:
		if m_data is Dictionary:
			gs.monster_spawns.append({
				"kind": str(m_data.get("kind", "")),
				"system_id": int(m_data.get("system_id", -1))
			})

	gs.empires.clear()
	var raw_emp: Array = d.get("empires", [])
	for e_data in raw_emp:
		if e_data is Dictionary:
			gs.empires.append(Empire.from_dict(e_data))

	gs.colonies.clear()
	var raw_cols: Dictionary = d.get("colonies", {})
	for k in raw_cols.keys():
		var cid: int = int(k)
		if raw_cols[k] is Dictionary:
			gs.colonies[cid] = Colony.from_dict(raw_cols[k])

	gs.designs.clear()
	var raw_des: Dictionary = d.get("designs", {})
	for k in raw_des.keys():
		var did: int = int(k)
		if raw_des[k] is Dictionary:
			gs.designs[did] = ShipDesign.from_dict(raw_des[k])

	gs.ships.clear()
	var raw_shp: Dictionary = d.get("ships", {})
	for k in raw_shp.keys():
		var sid: int = int(k)
		if raw_shp[k] is Dictionary:
			gs.ships[sid] = Ship.from_dict(raw_shp[k])

	gs.fleets.clear()
	var raw_flt: Dictionary = d.get("fleets", {})
	for k in raw_flt.keys():
		var fid: int = int(k)
		if raw_flt[k] is Dictionary:
			gs.fleets[fid] = Fleet.from_dict(raw_flt[k])

	gs.knowledge.clear()
	var raw_knw: Dictionary = d.get("knowledge", {})
	for k in raw_knw.keys():
		var eid: int = int(k)
		if raw_knw[k] is Dictionary:
			gs.knowledge[eid] = Knowledge.from_dict(raw_knw[k])

	if d.has("report") and d["report"] is Dictionary:
		gs.report = TurnReport.from_dict(d["report"])
	else:
		gs.report = null

	gs.cmd_log.clear()
	var raw_cmds: Array = d.get("cmd_log", [])
	for c in raw_cmds:
		if c is Dictionary:
			gs.cmd_log.append((c as Dictionary).duplicate(true))

	gs.wars = (d.get("wars", {}) as Dictionary).duplicate()

	gs.battle_logs.clear()
	var raw_blogs: Array = d.get("battle_logs", [])
	for bl in raw_blogs:
		if bl is Dictionary:
			gs.battle_logs.append((bl as Dictionary).duplicate(true))

	gs.stalemates = (d.get("stalemates", {}) as Dictionary).duplicate(true)
	gs.monsters_empire = int(d.get("monsters_empire", 100))
	gs.guardian_marked = (d.get("guardian_marked", {}) as Dictionary).duplicate()
	gs.loot = (d.get("loot", {}) as Dictionary).duplicate()

	return gs
