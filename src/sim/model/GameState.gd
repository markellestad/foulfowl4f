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
var report: TurnReport = null
var cmd_log: Array[Dictionary] = []

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

	var cmds: Array = []
	for c in cmd_log:
		cmds.append(c.duplicate(true))

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
		"report": report.to_dict() if report != null else null,
		"cmd_log": cmds
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

	if d.has("report") and d["report"] is Dictionary:
		gs.report = TurnReport.from_dict(d["report"])
	else:
		gs.report = null

	gs.cmd_log.clear()
	var raw_cmds: Array = d.get("cmd_log", [])
	for c in raw_cmds:
		if c is Dictionary:
			gs.cmd_log.append((c as Dictionary).duplicate(true))

	return gs
