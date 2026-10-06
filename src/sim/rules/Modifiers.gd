class_name Modifiers
extends RefCounted

static func _stat_matches(stat: String, eff_stat: String) -> bool:
	if eff_stat == stat:
		return true
	if stat == "food" and (eff_stat == "food_flat" or eff_stat == "food_pct"):
		return true
	if stat == "industry" and (eff_stat == "industry_flat" or eff_stat == "industry_pct"):
		return true
	if stat == "research" and (eff_stat == "research_flat" or eff_stat == "research_pct"):
		return true
	if stat == "taxes" and eff_stat == "taxes_pct":
		return true
	if stat == "credits" and eff_stat == "credits_flat":
		return true
	return false

static func _matches_filter(db: ContentDB, eff: Dictionary, climate: String, band: String, hull: String) -> bool:
	if not eff.has("filter") or not (eff["filter"] is Dictionary):
		return true
	var flt: Dictionary = eff["filter"]
	if flt.has("climates"):
		var allowed_climates: Array = flt["climates"]
		if not allowed_climates.has(climate):
			return false
	if flt.has("climate_class"):
		var cdef: Dictionary = db.def("climates", climate)
		var c_class: String = str(cdef.get("class", ""))
		if c_class != str(flt["climate_class"]):
			return false
	if flt.has("band"):
		if str(flt["band"]) != band:
			return false
	if flt.has("hulls"):
		var allowed_hulls: Array = flt["hulls"]
		if not allowed_hulls.has(hull):
			return false
	return true

static func eval(db: ContentDB, gs: GameState, stat: String, base: int, ctx: Dictionary) -> ModResult:
	var lines: Array[Dictionary] = []
	var base_src: String = str(ctx.get("base_source", "base"))
	lines.append({
		"source_key": base_src,
		"source": base_src,
		"op": "base",
		"value": base
	})

	var empire_id: int = int(ctx.get("empire_id", -1))
	var colony_id: int = int(ctx.get("colony_id", -1))

	var colony: Colony = null
	if colony_id >= 0 and gs != null and gs.colonies.has(colony_id):
		colony = gs.colonies[colony_id]

	var planet: Planet = null
	if colony != null and gs != null and colony.planet_id >= 0 and colony.planet_id < gs.planets.size():
		planet = gs.planets[colony.planet_id]

	var climate: String = str(ctx.get("climate", ""))
	if climate == "" and planet != null:
		climate = planet.climate

	var band: String = str(ctx.get("band", ""))
	var hull: String = str(ctx.get("hull", ""))

	var effects_to_apply: Array[Dictionary] = []

	# 1. Custom/hand-made effects passed in ctx
	if ctx.has("effects") and ctx["effects"] is Array:
		var raw_effs: Array = ctx["effects"]
		for e in raw_effs:
			if e is Dictionary:
				var e_stat: String = str(e.get("stat", stat))
				if _stat_matches(stat, e_stat) and _matches_filter(db, e, climate, band, hull):
					effects_to_apply.append({
						"source_key": str(e.get("source_key", "custom")),
						"op": str(e.get("op", "add")),
						"value": int(e.get("value", 0))
					})

	# 2. Empire traits & species traits
	var emp: Empire = null
	if gs != null and empire_id >= 0 and empire_id < gs.empires.size():
		emp = gs.empires[empire_id]

	if emp != null:
		var trait_ids: Array[String] = []
		for t in emp.traits:
			var tdef: Dictionary = db.def("traits", t)
			var is_species: bool = bool(tdef.get("species", false))
			if not is_species:
				trait_ids.append(t)
			else:
				if colony == null or colony.species == "" or colony.species == emp.race:
					trait_ids.append(t)
		if colony != null and colony.species != "" and colony.species != emp.race:
			var rdef: Dictionary = db.def("races", colony.species)
			var rtraits: Array = rdef.get("traits", [])
			for t in rtraits:
				var tdef: Dictionary = db.def("traits", str(t))
				if bool(tdef.get("species", false)):
					trait_ids.append(str(t))

		for tid in trait_ids:
			var tdef: Dictionary = db.def("traits", tid)
			var t_effs: Array = tdef.get("effects", [])
			for eff in t_effs:
				if eff is Dictionary:
					var eff_stat: String = str(eff.get("stat", ""))
					if _stat_matches(stat, eff_stat) and _matches_filter(db, eff, climate, band, hull):
						effects_to_apply.append({
							"source_key": tid,
							"op": str(eff.get("op", "add")),
							"value": int(eff.get("value", 0))
						})

	# 3. Colony buildings
	if colony != null:
		for bid in colony.buildings:
			var bdef: Dictionary = db.def("buildings", bid)
			var b_effs: Array = bdef.get("effects", [])
			for eff in b_effs:
				if eff is Dictionary:
					var eff_stat: String = str(eff.get("stat", ""))
					if _stat_matches(stat, eff_stat) and _matches_filter(db, eff, climate, band, hull):
						effects_to_apply.append({
							"source_key": bid,
							"op": str(eff.get("op", "add")),
							"value": int(eff.get("value", 0))
						})

	# 4. Empire timed mods
	if emp != null:
		for tm in emp.timed_mods:
			for eff in tm.effects:
				if eff is Dictionary:
					var eff_stat: String = str(eff.get("stat", ""))
					if _stat_matches(stat, eff_stat) and _matches_filter(db, eff, climate, band, hull):
						effects_to_apply.append({
							"source_key": tm.source_key,
							"op": str(eff.get("op", "add")),
							"value": int(eff.get("value", 0))
						})

	# 5. Difficulty (AI empires only: industry_pct, research_pct, growth_pct)
	if emp != null and emp.is_ai and gs != null and gs.settings != null:
		var diff_name: String = gs.settings.difficulty
		var ddef: Dictionary = db.def("difficulty", diff_name)
		var check_stat: String = stat
		if stat == "industry":
			check_stat = "industry_pct"
		elif stat == "research":
			check_stat = "research_pct"
		elif stat == "growth":
			check_stat = "growth_pct"
		if ddef.has(check_stat):
			var val: int = int(ddef[check_stat])
			if val != 0:
				effects_to_apply.append({
					"source_key": "difficulty",
					"op": "pct",
					"value": val
				})

	# 6. Strike (industry_pct)
	if emp != null and emp.strike_next_turn and (stat == "industry" or stat == "industry_pct"):
		var strike_pct: int = db.bal("strike_industry_pct")
		effects_to_apply.append({
			"source_key": "strike",
			"op": "pct",
			"value": strike_pct
		})

	# 7. Gravity (food_pct / industry_pct / research_pct)
	if stat == "food" or stat == "food_pct" or stat == "industry" or stat == "industry_pct" or stat == "research" or stat == "research_pct":
		var has_gravity_manners: bool = false
		if colony != null:
			for bid in colony.buildings:
				var bdef: Dictionary = db.def("buildings", bid)
				var bflags: Array = bdef.get("flags", [])
				if bflags.has("gravity_manners") or bid == "gravity_manners":
					has_gravity_manners = true
					break
		if not has_gravity_manners:
			var species_id: String = ""
			if colony != null and colony.species != "":
				species_id = colony.species
			elif emp != null:
				species_id = emp.race

			var species_traits_list: Array[String] = []
			if species_id != "":
				var rdef: Dictionary = db.def("races", species_id)
				var raw_tr: Array = rdef.get("traits", [])
				for t in raw_tr:
					species_traits_list.append(str(t))
			elif emp != null:
				species_traits_list = emp.traits

			var ideal_g: int = 1 # 0: low, 1: normal, 2: heavy
			if species_traits_list.has("low_g"):
				ideal_g = 0
			elif species_traits_list.has("high_g"):
				ideal_g = 2

			var world_g: String = str(ctx.get("gravity", ""))
			if world_g == "" and planet != null:
				world_g = planet.gravity
			elif world_g == "":
				world_g = "normal"

			var world_g_idx: int = 1
			if world_g == "low":
				world_g_idx = 0
			elif world_g == "heavy":
				world_g_idx = 2

			var mismatch: int = abs(world_g_idx - ideal_g)
			if mismatch > 0:
				var step_pct: int = db.bal("gravity_step_pct")
				var penalty: int = mismatch * step_pct
				effects_to_apply.append({
					"source_key": "gravity",
					"op": "pct",
					"value": penalty
				})

	# 8. Occupation (industry_pct / research_pct -50 while occupied)
	if colony != null and gs != null and colony.occupied_until >= gs.turn:
		if stat == "industry" or stat == "industry_pct" or stat == "research" or stat == "research_pct":
			effects_to_apply.append({
				"source_key": "occupation",
				"op": "pct",
				"value": -50
			})

	# Apply GDD §3.4 order: base -> floor -> add -> cap -> pct -> min clamp
	var current: int = base
	var max_floor: int = -2147483648
	var has_floor: bool = false
	var sum_add: int = 0
	var min_cap: int = 2147483647
	var has_cap: bool = false
	var sum_pct: int = 0

	for eff in effects_to_apply:
		if not eff.has("source"):
			eff["source"] = eff.get("source_key", "")
		if not eff.has("source_key"):
			eff["source_key"] = eff.get("source", "")
		lines.append(eff)
		var op: String = eff["op"]
		var val: int = eff["value"]
		match op:
			"floor":
				has_floor = true
				if val > max_floor:
					max_floor = val
			"add":
				sum_add += val
			"cap":
				has_cap = true
				if val < min_cap:
					min_cap = val
			"pct":
				sum_pct += val

	if stat.ends_with("_pct"):
		current = base + sum_add + sum_pct
	else:
		if has_floor and current < max_floor:
			current = max_floor
		current += sum_add
		if has_cap and current > min_cap:
			current = min_cap
		if sum_pct != 0:
			current = IntMath.pct(current, 100 + sum_pct)

	var stat_min: int = Stats.min_of(stat)
	if stat_min > -1000000 and current < stat_min:
		current = stat_min

	var result: ModResult = ModResult.new()
	result.value = current
	result.lines = lines
	return result
