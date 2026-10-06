class_name AiColonies
extends RefCounted

static func plan(view: AiView) -> Array[Cmd]:
	var cmds: Array[Cmd] = []
	var emp: Empire = view.own_empire()
	var colonies: Array[Colony] = view.own_colonies()
	if colonies.is_empty():
		return cmds

	# Check food need
	var food_total: int = 0
	var food_need: int = 0
	for col in colonies:
		if col.is_outpost:
			continue
		food_need += col.pop_units() * view.db.bal("food_eaten_per_pop")
		var out: Dictionary = Economy.colony_output(view.db, view.raw_game_state_DO_NOT_USE_EXCEPT_SIM(), col.id)
		food_total += (out["food"] as ModResult).value

	var need_food: bool = (food_total < food_need)

	# Check species traits for RP-heavy
	var rdef: Dictionary = view.db.def("races", emp.race)
	var traits: Array = rdef.get("traits", [])
	var is_rp_heavy: bool = traits.has("clever") or traits.has("scholarly") or traits.has("curious")

	# Sort colonies by ID for deterministic processing
	var sorted_cols: Array[Colony] = colonies.duplicate()
	sorted_cols.sort_custom(func(a: Colony, b: Colony) -> bool: return a.id < b.id)

	# Find best farm colony (if not capital)
	var best_farm_cid: int = -1
	var best_farm_yield: int = -1
	if need_food:
		for col in sorted_cols:
			if col.is_outpost or col.id == emp.capital_colony_id:
				continue
			var jy: Dictionary = Economy.job_yields(view.db, view.raw_game_state_DO_NOT_USE_EXCEPT_SIM(), col.id)
			var fpf: int = (jy["food_per_farmer"] as ModResult).value
			if fpf > best_farm_yield:
				best_farm_yield = fpf
				best_farm_cid = col.id

	for col in sorted_cols:
		if col.is_outpost:
			continue

		var desired_preset: String = "frontier"
		if col.id == emp.capital_colony_id:
			desired_preset = "capital"
		else:
			var p: Planet = view.planet(col.planet_id)
			var min_rank: String = p.minerals if p != null else ""
			if min_rank in ["rich", "ultra_rich"]:
				desired_preset = "industry"
			elif need_food and col.id == best_farm_cid:
				desired_preset = "breadbasket"
			elif is_rp_heavy:
				desired_preset = "research"
			else:
				desired_preset = "frontier"

		if col.preset != desired_preset:
			var cmd: CmdSetPreset = CmdSetPreset.new()
			cmd.empire_id = view.empire_id
			cmd.colony_id = col.id
			cmd.preset = desired_preset
			cmds.append(cmd)

	return cmds
