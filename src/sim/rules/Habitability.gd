class_name Habitability
extends RefCounted

static func gravity_for(size: String, minerals: String) -> String:
	match size:
		"tiny", "small":
			if minerals == "rich" or minerals == "ultra_rich":
				return "normal"
			return "low"
		"medium":
			return "normal"
		"large":
			if minerals == "rich" or minerals == "ultra_rich":
				return "heavy"
			return "normal"
		"huge":
			return "heavy"
		_:
			return "normal"

static func pop_per_size(db: ContentDB, traits: Array[String], climate: String, flags: Array[String]) -> int:
	var climates_table: Dictionary = db.table("climates")
	var rows: Dictionary = climates_table.get("rows", {})
	if not rows.has(climate):
		return 0
	var cdef: Dictionary = rows[climate]
	var c_class: String = str(cdef.get("class", ""))
	if c_class == "outpost":
		return 0

	var needs_flag: Variant = cdef.get("needs_flag")
	var is_tolerant: bool = traits.has("tolerant")
	if needs_flag != null and str(needs_flag) != "":
		var req_flag: String = str(needs_flag)
		if not is_tolerant and not flags.has(req_flag):
			return 0

	var pop: int = int(cdef.get("pop_per_size", 0))

	# Gather trait effects on pop_per_size
	var traits_table: Dictionary = db.table("traits")
	var trait_rows: Dictionary = traits_table.get("rows", {})
	
	var floor_val: int = -1
	var add_val: int = 0
	var cap_val: int = 1000000

	for tid in traits:
		if not trait_rows.has(tid):
			continue
		var tdef: Dictionary = trait_rows[tid]
		var effects: Array = tdef.get("effects", [])
		for eff in effects:
			if eff.get("stat") != "pop_per_size":
				continue
			var flt: Dictionary = eff.get("filter", {})
			if flt.has("climates"):
				var allowed_climates: Array = flt.get("climates", [])
				if not allowed_climates.has(climate):
					continue
			if flt.has("climate_class"):
				var allowed_class: String = str(flt.get("climate_class", ""))
				if allowed_class != c_class:
					continue

			var op: String = str(eff.get("op", ""))
			var v: int = int(eff.get("value", 0))
			match op:
				"floor":
					if v > floor_val:
						floor_val = v
				"add":
					add_val += v
				"cap":
					if v < cap_val:
						cap_val = v

	# Precedence: base -> floor -> add -> cap
	if floor_val >= 0 and pop < floor_val:
		pop = floor_val
	pop += add_val
	if pop > cap_val:
		pop = cap_val
	if pop < 0:
		pop = 0

	return pop

static func max_pop(db: ContentDB, traits: Array[String], planet: Planet, flags: Array[String]) -> int:
	var galaxy_table: Dictionary = db.table("galaxy")
	var sizes: Dictionary = galaxy_table.get("sizes", {})
	var sz_info: Dictionary = sizes.get(planet.size, {})
	var sz_val: int = int(sz_info.get("value", 0))
	var pps: int = pop_per_size(db, traits, planet.climate, flags)
	return sz_val * pps

static func is_good_for(db: ContentDB, traits: Array[String], climate: String) -> bool:
	var galaxy_table: Dictionary = db.table("galaxy")
	var gen_params: Dictionary = galaxy_table.get("gen", {})
	var min_pps: int = int(gen_params.get("good_min_pop_per_size", 3))
	var empty_flags: Array[String] = []
	return pop_per_size(db, traits, climate, empty_flags) >= min_pps
