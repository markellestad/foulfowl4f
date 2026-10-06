class_name Movement
extends RefCounted

static func fleet_map_speed(db: ContentDB, gs: GameState, fleet_id: int) -> int:
	var flt: Fleet = gs.fleets[fleet_id]
	if flt.ship_ids.is_empty():
		return 2
	var min_speed: int = 999999
	var mod: ModResult = Modifiers.eval(db, gs, "map_speed_add", 0, {"empire_id": flt.owner})
	for sid in flt.ship_ids:
		var s: Ship = gs.ships[sid]
		if not gs.designs.has(s.design_id):
			continue
		var des: ShipDesign = gs.designs[s.design_id]
		var st: Dictionary = DesignRules.stats(db, gs, des)
		var sp: int = int(st.get("map_speed", 2)) + mod.value
		if sp < min_speed:
			min_speed = sp
	return max(1, min_speed)

static func eta_turns(db: ContentDB, gs: GameState, fleet_id: int, dest_system_id: int) -> int:
	var flt: Fleet = gs.fleets[fleet_id]
	var dest_sys: StarSystem = gs.systems[dest_system_id]
	if flt.system_id >= 0:
		var cur_sys: StarSystem = gs.systems[flt.system_id]
		if cur_sys.wormhole_to == dest_system_id:
			return 1
		var d: int = IntMath.dist(cur_sys.x, cur_sys.y, dest_sys.x, dest_sys.y)
		var sp: int = fleet_map_speed(db, gs, fleet_id)
		return max(1, IntMath.ceil_div(d, sp * 10))
	else:
		var d: int = IntMath.dist(flt.x, flt.y, dest_sys.x, dest_sys.y)
		var sp: int = fleet_map_speed(db, gs, fleet_id)
		return max(1, IntMath.ceil_div(d, sp * 10))

static func advance(gs: GameState, fleet: Fleet) -> void:
	if fleet.dest_system_id < 0:
		return
	var dest_sys: StarSystem = gs.systems[fleet.dest_system_id]
	var total_turns: int = fleet.arrive_turn - fleet.depart_turn
	var elapsed_turns: int = gs.turn - fleet.depart_turn
	if total_turns <= 0 or elapsed_turns >= total_turns:
		fleet.x = dest_sys.x
		fleet.y = dest_sys.y
	else:
		fleet.x = IntMath.lerp_i(fleet.from_x, dest_sys.x, elapsed_turns, total_turns)
		fleet.y = IntMath.lerp_i(fleet.from_y, dest_sys.y, elapsed_turns, total_turns)

static func start_move(db: ContentDB, gs: GameState, fleet: Fleet, dest_system_id: int) -> void:
	var eta: int = eta_turns(db, gs, fleet.id, dest_system_id)
	fleet.dest_system_id = dest_system_id
	fleet.from_x = fleet.x
	fleet.from_y = fleet.y
	fleet.depart_turn = gs.turn
	fleet.arrive_turn = gs.turn + eta
	fleet.system_id = -1

