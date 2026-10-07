class_name AiAssess
extends RefCounted

static func plan(view: AiView, memory: AiMemory = null) -> Array[Cmd]:
	# Assess does not issue direct commands, but evaluates posture and threats
	return []

static func estimate_colony_defense(view: AiView, col_info: Dictionary, colony_id: int = -1) -> int:
	var base_defense: int = 50
	var b_list = col_info.get("buildings")
	if b_list is Array:
		for b in b_list:
			var bdef: Dictionary = view.db.def("buildings", str(b))
			if bdef.has("defense"):
				var dblk: Dictionary = bdef.get("defense", {})
				var b_pow: int = 500
				if dblk.has("launchers"):
					b_pow += 500
				if dblk.has("talons"):
					b_pow += 400
				if dblk.has("planet_shield"):
					b_pow += 300
				base_defense += b_pow
	var pop: int = int(col_info.get("pop_units", 1))
	base_defense += pop * 20

	var age: int = view.turn - int(col_info.get("turn_seen", view.turn))
	var inflations: int = IntMath.floor_div(maxi(0, age), 5)
	var inflate_pct: int = inflations * view.db.bal("intel_inflate_pct_per_5")
	var col_defense: int = IntMath.pct(base_defense, 100 + inflate_pct)

	var target_sys: int = -1
	if colony_id >= 0:
		target_sys = view.colony_system_id(colony_id)
	else:
		var c_owner: int = int(col_info.get("owner", -1))
		for s in view.all_systems():
			for pid in s.planet_ids:
				var p: Planet = view.planet(pid)
				if p != null and p.colony_id >= 0:
					var sc: Dictionary = view.seen_colony(p.colony_id)
					if int(sc.get("owner", -2)) == c_owner:
						target_sys = s.id
						break
			if target_sys >= 0:
				break

	if target_sys >= 0:
		var sys: StarSystem = view.system(target_sys)
		if sys != null:
			var vis: Dictionary = view.visible_fleets()
			for fid in vis.keys():
				var f_info: Dictionary = vis[fid]
				var f_owner: int = int(f_info.get("owner", -1))
				if f_owner >= 0 and f_owner != view.empire_id:
					var fx: int = int(f_info.get("x", -9999))
					var fy: int = int(f_info.get("y", -9999))
					var in_sys: bool = (int(f_info.get("system_id", -1)) == target_sys)
					if in_sys or IntMath.dist(fx, fy, sys.x, sys.y) <= 10:
						var sc: int = int(f_info.get("ship_count", 0))
						var flt_p: int = (sc * 18) * (sc * 18)
						col_defense += flt_p

	return col_defense

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
