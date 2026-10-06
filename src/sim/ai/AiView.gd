class_name AiView
extends RefCounted

var empire_id: int = -1
var turn: int = 1
var seed: int = 0
var db: ContentDB = null

var _gs: GameState = null
var _personality: Dictionary = {}

static func build(gs: GameState, p_db: ContentDB, p_empire_id: int) -> AiView:
	var view: AiView = AiView.new()
	view._gs = gs
	view.db = p_db
	view.empire_id = p_empire_id
	view.turn = gs.turn
	view.seed = gs.settings.seed if gs.settings != null else 0

	var emp: Empire = gs.empires[p_empire_id]
	var p_id: String = ""
	if p_db != null:
		var rdef: Dictionary = p_db.def("races", emp.race)
		p_id = str(rdef.get("personality", ""))
	if p_id != "" and p_db != null:
		view._personality = p_db.def("personalities", p_id)
	return view

func rng(salt: int) -> Rng:
	return Rng.keyed(seed, turn, Rng.AI, empire_id, salt)

func personality() -> Dictionary:
	return _personality

func own_empire() -> Empire:
	return _gs.empires[empire_id]

func treasury() -> int:
	return own_empire().treasury

func military_budget() -> String:
	return own_empire().military_budget

func capital_colony() -> Colony:
	var cap_id: int = own_empire().capital_colony_id
	if cap_id >= 0 and _gs.colonies.has(cap_id):
		return _gs.colonies[cap_id]
	return null

func own_colonies() -> Array[Colony]:
	var res: Array[Colony] = []
	for cid in Ids.sorted_keys(_gs.colonies):
		var c: Colony = _gs.colonies[cid]
		if c.owner == empire_id:
			res.append(c)
	return res

func own_fleets() -> Array[Fleet]:
	var res: Array[Fleet] = []
	for fid in Ids.sorted_keys(_gs.fleets):
		var f: Fleet = _gs.fleets[fid]
		if f.owner == empire_id:
			res.append(f)
	return res

func own_designs() -> Array[ShipDesign]:
	var res: Array[ShipDesign] = []
	for did in Ids.sorted_keys(_gs.designs):
		var d: ShipDesign = _gs.designs[did]
		if d.empire_id == empire_id:
			res.append(d)
	return res

func own_ship(sid: int) -> Ship:
	var s: Ship = _gs.ships.get(sid)
	if s != null and s.owner == empire_id:
		return s
	return null

func own_ships() -> Array[Ship]:
	var res: Array[Ship] = []
	for sid in Ids.sorted_keys(_gs.ships):
		var s: Ship = _gs.ships[sid]
		if s.owner == empire_id:
			res.append(s)
	return res

func knowledge() -> Knowledge:
	if not _gs.knowledge.has(empire_id):
		_gs.knowledge[empire_id] = Knowledge.new()
	return _gs.knowledge[empire_id]

func is_explored(sys_id: int) -> bool:
	return knowledge().explored.has(sys_id)

func seen_colonies() -> Dictionary:
	return knowledge().seen_colonies

func visible_fleets() -> Dictionary:
	return knowledge().visible_fleets

func known_designs() -> Dictionary:
	return knowledge().known_designs

func met_empires() -> Dictionary:
	return knowledge().met

func is_met(other_id: int) -> bool:
	return knowledge().met.has(other_id)

func is_at_war(other_id: int) -> bool:
	return Wars.is_at_war(_gs, empire_id, other_id)

func is_in_truce(other_id: int) -> bool:
	return Wars.is_in_truce(_gs, empire_id, other_id)

func war_started_turn(other_id: int) -> int:
	return Wars.war_started(_gs, empire_id, other_id)

func last_battle_turn(other_id: int) -> int:
	return Wars.last_battle(_gs, empire_id, other_id)

func war_declarer(other_id: int) -> int:
	var key: String = Wars._pair_key(empire_id, other_id)
	return int(_gs.war_declarer.get(key, -1))

func active_wars_count() -> int:
	var count: int = 0
	for eid in range(_gs.empires.size()):
		if eid != empire_id and Wars.is_at_war(_gs, empire_id, eid):
			count += 1
	return count

func relations_value(other_id: int) -> ModResult:
	return Relations.value(db, _gs, empire_id, other_id)

func all_systems() -> Array[StarSystem]:
	return _gs.systems

func system(sys_id: int) -> StarSystem:
	if sys_id >= 0 and sys_id < _gs.systems.size():
		return _gs.systems[sys_id]
	return null

func planet(planet_id: int) -> Planet:
	if planet_id >= 0 and planet_id < _gs.planets.size():
		return _gs.planets[planet_id]
	return null

func own_power() -> int:
	return Power.empire_military_power(db, _gs, empire_id)

func estimated_enemy_power(other_id: int) -> int:
	var knw: Knowledge = knowledge()
	var total: int = 0
	for fid in knw.visible_fleets.keys():
		var f_info: Dictionary = knw.visible_fleets[fid]
		if int(f_info.get("owner", -1)) == other_id:
			var sc: int = int(f_info.get("ship_count", 0))
			total += sc * 50
	# If no fleets visible but met, give a baseline estimate based on seen colonies or minimum
	if total == 0:
		total = 50
	return total

func raw_game_state_DO_NOT_USE_EXCEPT_SIM() -> GameState:
	return _gs
