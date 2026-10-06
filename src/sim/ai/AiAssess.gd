class_name AiAssess
extends RefCounted

static func plan(view: AiView, memory: AiMemory = null) -> Array[Cmd]:
	# Assess does not issue direct commands, but evaluates posture and threats
	return []

static func estimate_colony_defense(view: AiView, col_info: Dictionary) -> int:
	var base_defense: int = 50
	var b_list = col_info.get("buildings")
	if b_list is Array:
		for b in b_list:
			var bdef: Dictionary = view.db.def("buildings", str(b))
			if bdef.has("defense"):
				base_defense += 100
	var pop: int = int(col_info.get("pop_units", 1))
	base_defense += pop * 10

	var age: int = view.turn - int(col_info.get("turn_seen", view.turn))
	var inflations: int = IntMath.floor_div(maxi(0, age), 5)
	var inflate_pct: int = inflations * view.db.bal("intel_inflate_pct_per_5")
	return IntMath.pct(base_defense, 100 + inflate_pct)

static func posture(view: AiView) -> String:
	if view.active_wars_count() > 0:
		var own_p: int = view.own_power()
		var strongest_enemy_p: int = 1
		for eid in range(view.raw_game_state_DO_NOT_USE_EXCEPT_SIM().empires.size()):
			if eid != view.empire_id and view.is_at_war(eid):
				var ep: int = view.estimated_enemy_power(eid)
				if ep > strongest_enemy_p:
					strongest_enemy_p = ep
		if own_p * 100 < 50 * strongest_enemy_p:
			return "Losing"
		return "War"

	if view.met_empires().size() > 0:
		return "Tension"

	return "Peace"

static func threats_at_colony(view: AiView, col: Colony) -> int:
	var col_p: Planet = view.planet(col.planet_id)
	if col_p == null:
		return 0
	var col_sys: StarSystem = view.system(col_p.system_id)
	if col_sys == null:
		return 0

	var threat_power: int = 0
	var resp_turns: int = view.db.bal("defense_response_turns")
	var vis_fleets: Dictionary = view.visible_fleets()

	for fid in vis_fleets.keys():
		var f_data: Dictionary = vis_fleets[fid]
		var f_owner: int = int(f_data.get("owner", -1))
		if f_owner == view.empire_id:
			continue
		var fx: int = int(f_data.get("x", 0))
		var fy: int = int(f_data.get("y", 0))
		var d: int = IntMath.dist(fx, fy, col_sys.x, col_sys.y)
		# Assume speed ~20 dpc/turn
		if IntMath.floor_div(d, 20) <= resp_turns:
			threat_power += int(f_data.get("ship_count", 0)) * 50

	return threat_power
