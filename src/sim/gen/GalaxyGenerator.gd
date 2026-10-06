class_name GalaxyGenerator
extends RefCounted

static func generate(settings: GameSettings, db: ContentDB) -> GameState:
	if settings.seed == 0 and settings.seed_string != "":
		settings.seed = Rng.seed_from_string(settings.seed_string)

	var gs: GameState = GameState.new()
	gs.settings = settings
	gs.version = 1
	gs.turn = 1

	var galaxy_table: Dictionary = db.table("galaxy")
	var presets: Dictionary = galaxy_table.get("presets", {})
	var preset_def: Dictionary = presets.get(settings.preset, {})
	var total_stars: int = int(preset_def.get("stars", 24))
	var n: int = int(preset_def.get("empires", 4))
	var width_pc: int = int(preset_def.get("width_pc", 44))
	var height_pc: int = int(preset_def.get("height_pc", 30))
	var W: int = width_pc * 10
	var H: int = height_pc * 10

	var gen_def: Dictionary = galaxy_table.get("gen", {})
	var min_sep: int = int(gen_def.get("min_sep_dpc", 45))
	var margin: int = int(gen_def.get("margin_dpc", 20))
	var darts_per_star: int = int(gen_def.get("darts_per_star", 30))
	var relax_pct: int = int(gen_def.get("relax_pct", 95))
	var max_relax: int = int(gen_def.get("max_relax", 20))

	# Streams
	var rng: Rng = Rng.keyed(settings.seed, 0, Rng.GALAXY, 0, 0)
	var names_rng: Rng = Rng.keyed(settings.seed, 0, Rng.NAMES, 0, 0)

	# 1. Seating
	settings.seats = Seating.resolve(settings, db)

	# 2. Positions (Poisson-disk sampling)
	var cur_sep: int = min_sep
	var points: Array[Vector2i] = []
	for attempt in range(max_relax + 1):
		points.clear()
		var max_darts: int = darts_per_star * total_stars
		for dart in range(max_darts):
			var x: int = rng.range_i(margin, W - margin)
			var y: int = rng.range_i(margin, H - margin)
			var ok: bool = true
			for pt in points:
				if IntMath.dist(x, y, pt.x, pt.y) < cur_sep:
					ok = false
					break
			if ok:
				points.append(Vector2i(x, y))
				if points.size() == total_stars:
					break
		if points.size() == total_stars:
			break
		cur_sep = IntMath.pct(cur_sep, relax_pct)

	gs.gen_min_sep = cur_sep

	for i in range(total_stars):
		var sys: StarSystem = StarSystem.new()
		sys.id = i
		sys.x = points[i].x
		sys.y = points[i].y
		gs.systems.append(sys)

	# 3. Star types (weighted pick per star in id order)
	var star_types: Dictionary = galaxy_table.get("star_types", {})
	for i in range(total_stars):
		gs.systems[i].star_type = _pick_weighted(rng, star_types)

	# 4. Orn (star nearest centre (W/2, H/2), ties lower id)
	var cx: int = IntMath.floor_div(W, 2)
	var cy: int = IntMath.floor_div(H, 2)
	var best_dist: int = 100000000
	var orn_idx: int = 0
	for i in range(total_stars):
		var d: int = IntMath.dist(gs.systems[i].x, gs.systems[i].y, cx, cy)
		if d < best_dist:
			best_dist = d
			orn_idx = i
	var orn_sys: StarSystem = gs.systems[orn_idx]
	orn_sys.is_orn = true
	orn_sys.star_type = "yellow"

	# 5. Planets per star in id order
	var outpost_body_pct: int = int(gen_def.get("outpost_body_pct", 25))
	var habitable_pct: int = int(gen_def.get("habitable_pct", 40))
	var special_one_in: int = int(gen_def.get("special_one_in", 8))
	var sizes_def: Dictionary = galaxy_table.get("sizes", {})
	var specials_def: Dictionary = galaxy_table.get("specials", {})

	for sys in gs.systems:
		var st_def: Dictionary = star_types.get(sys.star_type, {})
		var orbits_min: int = int(st_def.get("orbits_min", 2))
		var orbits_max: int = int(st_def.get("orbits_max", 4))
		var orbits_count: int = rng.range_i(orbits_min, orbits_max)

		for orbit in range(orbits_count):
			var is_outpost: bool = rng.chance_pct(outpost_body_pct)
			var climate: String = ""
			if is_outpost:
				if rng.chance_pct(50):
					climate = "asteroids"
				else:
					climate = "gas_giant"
			else:
				var hab_map: Dictionary = st_def.get("habitable", {})
				if not hab_map.is_empty() and rng.chance_pct(habitable_pct):
					climate = _pick_weighted(rng, hab_map)
				else:
					climate = _pick_weighted(rng, st_def.get("hostile", {}))

			var size: String = ""
			if is_outpost:
				size = "medium"
			else:
				size = _pick_size(rng, sizes_def)

			var minerals: String = _pick_weighted(rng, st_def.get("minerals", {}))
			var gravity: String = Habitability.gravity_for(size, minerals)

			var special: String = ""
			if not is_outpost and rng.range_i(1, special_one_in) == 1:
				special = _pick_weighted(rng, specials_def)

			var p: Planet = Planet.new()
			p.id = gs.planets.size()
			p.system_id = sys.id
			p.orbit = orbit
			p.climate = climate
			p.size = size
			p.minerals = minerals
			p.gravity = gravity
			p.special = special
			sys.planet_ids.append(p.id)
			gs.planets.append(p)

	# Orn: replace orbit 0 with gaia/huge/ultra_rich/no special
	if orn_sys.planet_ids.size() > 0:
		var orn_p0: Planet = gs.planets[orn_sys.planet_ids[0]]
		orn_p0.climate = "gaia"
		orn_p0.size = "huge"
		orn_p0.minerals = "ultra_rich"
		orn_p0.special = ""
		orn_p0.gravity = Habitability.gravity_for(orn_p0.size, orn_p0.minerals)

	# 6. Homeworlds
	var homeworld_min_orn_dpc: int = int(gen_def.get("homeworld_min_orn_dpc", 120))
	var candidates: Array[StarSystem] = []
	for s in gs.systems:
		if not s.is_orn and IntMath.dist(s.x, s.y, orn_sys.x, orn_sys.y) >= homeworld_min_orn_dpc:
			candidates.append(s)

	if candidates.size() < n:
		SimLog.warn("homeworld_fallback")
		candidates.clear()
		for s in gs.systems:
			if not s.is_orn:
				candidates.append(s)

	var chosen_homeworlds: Array[StarSystem] = []
	# First = farthest from Orn (ties: lower id)
	var first_idx: int = -1
	var first_dist: int = -1
	for i in range(candidates.size()):
		var c: StarSystem = candidates[i]
		var d: int = IntMath.dist(c.x, c.y, orn_sys.x, orn_sys.y)
		if d > first_dist or (d == first_dist and (first_idx == -1 or c.id < candidates[first_idx].id)):
			first_dist = d
			first_idx = i
	chosen_homeworlds.append(candidates[first_idx])

	# Next = maximises minimum distance to those chosen (ties: lower id)
	while chosen_homeworlds.size() < n:
		var best_cand: StarSystem = null
		var max_min_d: int = -1
		for c in candidates:
			if chosen_homeworlds.has(c):
				continue
			var min_d_to_chosen: int = 100000000
			for ch in chosen_homeworlds:
				var d: int = IntMath.dist(c.x, c.y, ch.x, ch.y)
				if d < min_d_to_chosen:
					min_d_to_chosen = d
			if min_d_to_chosen > max_min_d:
				max_min_d = min_d_to_chosen
				best_cand = c
			elif min_d_to_chosen == max_min_d:
				if best_cand == null or c.id < best_cand.id:
					best_cand = c
		chosen_homeworlds.append(best_cand)

	# 7. Seat -> homeworld (shuffle chosen homeworld list with GALAXY stream)
	rng.shuffle(chosen_homeworlds)
	for i in range(n):
		chosen_homeworlds[i].home_of = i

	# 8. Homeworld planet
	var races_table: Dictionary = db.table("races")
	var race_rows: Dictionary = races_table.get("rows", {})
	for i in range(n):
		var race_id: String = settings.seats[i]
		var rdef: Dictionary = race_rows.get(race_id, {})
		var hw_info: Dictionary = rdef.get("homeworld", {})
		var hw_sys: StarSystem = chosen_homeworlds[i]
		var hw_p0: Planet = gs.planets[hw_sys.planet_ids[0]]
		hw_p0.climate = str(hw_info.get("climate", "terran"))
		hw_p0.size = str(hw_info.get("size", "medium"))
		hw_p0.minerals = str(hw_info.get("minerals", "abundant"))
		hw_p0.special = ""
		hw_p0.gravity = "normal"

	# 9. Fair start
	var fair_radius: int = int(gen_def.get("fair_radius_dpc", 90))
	var fair_good: int = int(gen_def.get("fair_good", 2))
	var fair_outposts: int = int(gen_def.get("fair_outposts", 1))

	var locked_planets: Dictionary = {}
	# Lock homeworld planets
	for i in range(n):
		var hw_sys: StarSystem = chosen_homeworlds[i]
		locked_planets[hw_sys.planet_ids[0]] = true

	for i in range(n):
		var hw_sys: StarSystem = chosen_homeworlds[i]
		var race_id: String = settings.seats[i]
		var rdef: Dictionary = race_rows.get(race_id, {})
		var race_traits: Array[String] = []
		for t in rdef.get("traits", []):
			race_traits.append(str(t))
		var best_climate: String = str(rdef.get("best_climate", "terran"))

		# Ensure the homeworld system or in-range stars have at least 3 planets total
		var in_range_systems: Array[StarSystem] = []
		var count_total_in_range_planets: int = 0
		for s in gs.systems:
			if s.is_orn:
				continue
			if s.home_of != -1 and s.home_of != i:
				continue
			if IntMath.dist(hw_sys.x, hw_sys.y, s.x, s.y) <= fair_radius:
				in_range_systems.append(s)
				for pid in s.planet_ids:
					if s.id == hw_sys.id and pid == hw_sys.planet_ids[0]:
						continue
					count_total_in_range_planets += 1

		while count_total_in_range_planets < (fair_good + fair_outposts):
			# Add an orbit to hw_sys
			var add_p: Planet = Planet.new()
			add_p.id = gs.planets.size()
			add_p.system_id = hw_sys.id
			add_p.orbit = hw_sys.planet_ids.size()
			add_p.climate = "barren"
			add_p.size = "medium"
			add_p.minerals = "abundant"
			add_p.gravity = Habitability.gravity_for(add_p.size, add_p.minerals)
			add_p.special = ""
			hw_sys.planet_ids.append(add_p.id)
			gs.planets.append(add_p)
			count_total_in_range_planets += 1

		# Gather all candidate in-range planets
		var all_candidate_planets: Array[Dictionary] = []
		for s in in_range_systems:
			var d_sys: int = IntMath.dist(hw_sys.x, hw_sys.y, s.x, s.y)
			for pid in s.planet_ids:
				if s.id == hw_sys.id and pid == hw_sys.planet_ids[0]:
					continue
				all_candidate_planets.append({
					"planet": gs.planets[pid],
					"dist": d_sys
				})

		# Nearest first comparator: dist ascending, then planet.id ascending
		var sort_nearest = func(a: Dictionary, b: Dictionary) -> bool:
			if a["dist"] != b["dist"]:
				return a["dist"] < b["dist"]
			return a["planet"].id < b["planet"].id

		all_candidate_planets.sort_custom(sort_nearest)

		# Count how many in range are currently good for the race
		var current_good: Array[Dictionary] = []
		for item in all_candidate_planets:
			var p: Planet = item["planet"]
			if Habitability.is_good_for(db, race_traits, p.climate):
				current_good.append(item)

		if current_good.size() > fair_good:
			# Convert farthest UNLOCKED extras to barren (ties: higher planet id first)
			# Sort current_good nearest first
			current_good.sort_custom(sort_nearest)
			# Extras to convert: from the end backward, if unlocked
			var extras_needed: int = current_good.size() - fair_good
			for g_idx in range(current_good.size() - 1, -1, -1):
				if extras_needed <= 0:
					break
				var p_cand: Planet = current_good[g_idx]["planet"]
				if not locked_planets.has(p_cand.id):
					p_cand.climate = "barren"
					p_cand.gravity = Habitability.gravity_for(p_cand.size, p_cand.minerals)
					extras_needed -= 1

			# Lock the fair_good planets
			var locked_count: int = 0
			for item in current_good:
				var p_good: Planet = item["planet"]
				if Habitability.is_good_for(db, race_traits, p_good.climate):
					locked_planets[p_good.id] = true
					locked_count += 1
					if locked_count == fair_good:
						break
		elif current_good.size() < fair_good:
			for item in current_good:
				locked_planets[item["planet"].id] = true
			var needed_good: int = fair_good - current_good.size()
			# Convert nearest unlocked non-outpost planets first
			var non_op_cands: Array[Dictionary] = []
			var op_cands: Array[Dictionary] = []
			for item in all_candidate_planets:
				var p: Planet = item["planet"]
				if locked_planets.has(p.id):
					continue
				if p.climate != "asteroids" and p.climate != "gas_giant":
					non_op_cands.append(item)
				else:
					op_cands.append(item)

			for c_item in non_op_cands:
				if needed_good <= 0:
					break
				var cp: Planet = c_item["planet"]
				cp.climate = best_climate
				cp.size = "medium"
				cp.gravity = Habitability.gravity_for(cp.size, cp.minerals)
				locked_planets[cp.id] = true
				needed_good -= 1

			# If still needed, convert outpost cands
			for c_item in op_cands:
				if needed_good <= 0:
					break
				var cp: Planet = c_item["planet"]
				cp.climate = best_climate
				cp.size = "medium"
				cp.gravity = Habitability.gravity_for(cp.size, cp.minerals)
				locked_planets[cp.id] = true
				needed_good -= 1
		else:
			for item in current_good:
				locked_planets[item["planet"].id] = true

		# Ensure >= fair_outposts outpost bodies in range
		var outpost_count: int = 0
		for item in all_candidate_planets:
			var p: Planet = item["planet"]
			if p.climate == "asteroids" or p.climate == "gas_giant":
				outpost_count += 1

		if outpost_count < fair_outposts:
			for item in all_candidate_planets:
				var p: Planet = item["planet"]
				if locked_planets.has(p.id):
					continue
				p.climate = "asteroids"
				p.size = "medium"
				p.special = ""
				p.gravity = "normal"
				locked_planets[p.id] = true
				outpost_count += 1
				if outpost_count >= fair_outposts:
					break

	# Clean up any homeworld overlap where subsequent empire conversions caused an earlier homeworld to exceed fair_good
	for i in range(n):
		var hw_sys: StarSystem = chosen_homeworlds[i]
		var race_id: String = settings.seats[i]
		var rdef: Dictionary = race_rows.get(race_id, {})
		var race_traits: Array[String] = []
		for t in rdef.get("traits", []):
			race_traits.append(str(t))

		var goods: Array[Dictionary] = []
		for s in gs.systems:
			if s.is_orn or (s.home_of != -1 and s.home_of != i):
				continue
			var d_sys: int = IntMath.dist(hw_sys.x, hw_sys.y, s.x, s.y)
			if d_sys <= fair_radius:
				for pid in s.planet_ids:
					if s.id == hw_sys.id and pid == hw_sys.planet_ids[0]:
						continue
					var p: Planet = gs.planets[pid]
					if Habitability.is_good_for(db, race_traits, p.climate):
						goods.append({"planet": p, "dist": d_sys})

		if goods.size() > fair_good:
			goods.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				if a["dist"] != b["dist"]:
					return a["dist"] > b["dist"]
				return a["planet"].id > b["planet"].id
			)
			var excess: int = goods.size() - fair_good
			for g in goods:
				if excess <= 0:
					break
				var p: Planet = g["planet"]
				var safe_to_convert: bool = true
				var compensations: Array[Dictionary] = []
				for other_i in range(n):
					if other_i == i:
						continue
					var other_hw: StarSystem = chosen_homeworlds[other_i]
					var other_sys: StarSystem = gs.systems[p.system_id]
					if IntMath.dist(other_hw.x, other_hw.y, other_sys.x, other_sys.y) <= fair_radius:
						var other_r_id: String = settings.seats[other_i]
						var other_rdef: Dictionary = race_rows.get(other_r_id, {})
						var other_traits: Array[String] = []
						for ot in other_rdef.get("traits", []):
							other_traits.append(str(ot))
						if Habitability.is_good_for(db, other_traits, p.climate):
							var other_good_count: int = 0
							for os in gs.systems:
								if os.is_orn or (os.home_of != -1 and os.home_of != other_i):
									continue
								if IntMath.dist(other_hw.x, other_hw.y, os.x, os.y) <= fair_radius:
									for opid in os.planet_ids:
										if os.id == other_hw.id and opid == other_hw.planet_ids[0]:
											continue
										var op: Planet = gs.planets[opid]
										if Habitability.is_good_for(db, other_traits, op.climate):
											other_good_count += 1
							if other_good_count <= fair_good:
								var other_best_climate: String = str(other_rdef.get("best_climate", "terran"))
								var comp_cand: Planet = null
								for os in gs.systems:
									if os.is_orn or (os.home_of != -1 and os.home_of != other_i):
										continue
									if IntMath.dist(other_hw.x, other_hw.y, os.x, os.y) <= fair_radius:
										if IntMath.dist(hw_sys.x, hw_sys.y, os.x, os.y) > fair_radius:
											for opid in os.planet_ids:
												if os.id == other_hw.id and opid == other_hw.planet_ids[0]:
													continue
												var op: Planet = gs.planets[opid]
												if op.climate != "asteroids" and op.climate != "gas_giant":
													if not Habitability.is_good_for(db, other_traits, op.climate):
														comp_cand = op
														break
									if comp_cand != null:
										break
								if comp_cand != null:
									compensations.append({"planet": comp_cand, "climate": other_best_climate})
								else:
									safe_to_convert = false
									break

				if safe_to_convert:
					if not compensations.is_empty():
						for comp in compensations:
							var cp: Planet = comp["planet"]
							cp.climate = comp["climate"]
							cp.size = "medium"
							cp.gravity = Habitability.gravity_for(cp.size, cp.minerals)
					p.climate = "barren"
					p.gravity = Habitability.gravity_for(p.size, p.minerals)
					excess -= 1

	# 10. Wormhole (wormhole_pairs > 0)
	var wormhole_pairs: int = int(preset_def.get("wormhole_pairs", 0))
	if wormhole_pairs > 0:
		var wormhole_min_width_pct: int = int(gen_def.get("wormhole_min_width_pct", 60))
		var min_wh_dist: int = IntMath.pct(W, wormhole_min_width_pct)
		var wh_candidates: Array[Dictionary] = []
		for a_idx in range(total_stars):
			var sa: StarSystem = gs.systems[a_idx]
			if sa.is_orn or sa.home_of != -1:
				continue
			for b_idx in range(a_idx + 1, total_stars):
				var sb: StarSystem = gs.systems[b_idx]
				if sb.is_orn or sb.home_of != -1:
					continue
				if IntMath.dist(sa.x, sa.y, sb.x, sb.y) >= min_wh_dist:
					wh_candidates.append({"a": sa, "b": sb})

		# Sorted by (a.id, b.id)
		wh_candidates.sort_custom(func(p1: Dictionary, p2: Dictionary) -> bool:
			if p1["a"].id != p2["a"].id:
				return p1["a"].id < p2["a"].id
			return p1["b"].id < p2["b"].id
		)

		if wh_candidates.is_empty():
			SimLog.warn("no_wormhole")
		else:
			var wh_idx: int = rng.range_i(0, wh_candidates.size() - 1)
			var pair: Dictionary = wh_candidates[wh_idx]
			(pair["a"] as StarSystem).wormhole_to = (pair["b"] as StarSystem).id
			(pair["b"] as StarSystem).wormhole_to = (pair["a"] as StarSystem).id

	# 11. Monsters
	gs.monster_spawns.append({
		"kind": "guardian",
		"system_id": orn_sys.id
	})

	var leviathan_count: int = int(preset_def.get("leviathans", 2))
	var leviathan_min_home_dpc: int = int(gen_def.get("leviathan_min_home_dpc", 100))
	var lev_candidates: Array[Dictionary] = []
	var minerals_def: Dictionary = galaxy_table.get("minerals", {})

	for s in gs.systems:
		if s.is_orn or s.home_of != -1:
			continue
		var far_from_all_home: bool = true
		for hw in chosen_homeworlds:
			if IntMath.dist(s.x, s.y, hw.x, hw.y) < leviathan_min_home_dpc:
				far_from_all_home = false
				break
		if not far_from_all_home:
			continue

		var richness: int = 0
		for pid in s.planet_ids:
			var p: Planet = gs.planets[pid]
			var min_rank: int = int(minerals_def.get(p.minerals, {}).get("rank", 0))
			var sz_val: int = int(sizes_def.get(p.size, {}).get("value", 0))
			richness += min_rank + sz_val

		lev_candidates.append({
			"sys": s,
			"richness": richness
		})

	# Sort by richness descending, ties lower id
	lev_candidates.sort_custom(func(c1: Dictionary, c2: Dictionary) -> bool:
		if c1["richness"] != c2["richness"]:
			return c1["richness"] > c2["richness"]
		return c1["sys"].id < c2["sys"].id
	)

	for lev_idx in range(min(leviathan_count, lev_candidates.size())):
		var ls: StarSystem = lev_candidates[lev_idx]["sys"]
		gs.monster_spawns.append({
			"kind": "leviathan",
			"system_id": ls.id
		})

	# 12. Names (NAMES stream shuffles 1..64; star i takes element i; Orn name_id = -2)
	var name_ids: Array[int] = []
	for i in range(1, 65):
		name_ids.append(i)
	names_rng.shuffle(name_ids)

	for i in range(total_stars):
		var s: StarSystem = gs.systems[i]
		if s.is_orn:
			s.name_id = -2
		else:
			s.name_id = name_ids[i]

	return gs

static func _pick_weighted(rng: Rng, weight_map: Dictionary) -> String:
	var total: int = 0
	for k in weight_map.keys():
		var val: Variant = weight_map[k]
		if val is Dictionary:
			total += int((val as Dictionary).get("weight", 0))
		else:
			total += int(val)
	if total <= 0:
		return ""
	var roll: int = rng.range_i(1, total)
	var acc: int = 0
	for k in weight_map.keys():
		var val: Variant = weight_map[k]
		if val is Dictionary:
			acc += int((val as Dictionary).get("weight", 0))
		else:
			acc += int(val)
		if roll <= acc:
			return str(k)
	return str(weight_map.keys()[-1])

static func _pick_size(rng: Rng, sizes_def: Dictionary) -> String:
	var total: int = 0
	for k in sizes_def.keys():
		total += int(sizes_def[k].get("weight", 0))
	if total <= 0:
		return "medium"
	var roll: int = rng.range_i(1, total)
	var acc: int = 0
	for k in sizes_def.keys():
		acc += int(sizes_def[k].get("weight", 0))
		if roll <= acc:
			return str(k)
	return "medium"
