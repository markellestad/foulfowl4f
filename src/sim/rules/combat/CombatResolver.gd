class_name CombatResolver
extends RefCounted

const STEP_DISTANCE := 1
const STEP_SWAT_INTERCEPT := 2
const STEP_HORIZON_HIT := 3
const STEP_FEATHER := 4
const STEP_DIRECT_HIT := 5
const STEP_DIRECT_DMG := 6
const STEP_LAUNCH := 7
const STEP_RETREAT := 8

static func resolve(input: CombatInput) -> BattleLog:
	var log := BattleLog.new()
	log.system_id = input.system_id
	log.turn = input.turn

	# Canonicalize parties
	var parties: Array[CombatParty] = []
	for p in input.parties:
		parties.append(p)
	parties.sort_custom(func(a: CombatParty, b: CombatParty) -> bool:
		if a.empire_id != b.empire_id:
			return a.empire_id < b.empire_id
		return (1 if a.is_colony_defense else 0) < (1 if b.is_colony_defense else 0)
	)

	# Canonicalize units and initial state
	var all_units: Dictionary = {} # uid -> CombatUnit
	var party_of_unit: Dictionary = {} # uid -> CombatParty
	var party_line_uids: Dictionary = {} # party_id -> Array[int]
	var party_reserve_uids: Dictionary = {} # party_id -> Array[int]
	var band_damage_totals: Dictionary = {"talon": 0, "beak": 0, "horizon": 0}

	for p in parties:
		# Canonicalize unit ordering inside party
		p.units.sort_custom(func(a: CombatUnit, b: CombatUnit) -> bool:
			return a.uid < b.uid
		)
		for u in p.units:
			all_units[u.uid] = u
			party_of_unit[u.uid] = p
			log.initial_units.append(u.to_dict())

		# Build initial line order
		var ordered_uids: Array[int] = []
		var used_uids: Dictionary = {}
		for uid in p.line_order:
			if all_units.has(uid) and not used_uids.has(uid):
				ordered_uids.append(uid)
				used_uids[uid] = true

		# Add remaining units by default ranking
		var remaining: Array[CombatUnit] = []
		for u in p.units:
			if not used_uids.has(u.uid):
				remaining.append(u)
		remaining.sort_custom(func(a: CombatUnit, b: CombatUnit) -> bool:
			var a_swat: int = 1 if a.is_swat else 0
			var b_swat: int = 1 if b.is_swat else 0
			if a_swat != b_swat:
				return a_swat > b_swat
			var a_band: int = 1 if (a.main_band == p.auto_band and a.main_band != "") else 0
			var b_band: int = 1 if (b.main_band == p.auto_band and b.main_band != "") else 0
			if a_band != b_band:
				return a_band > b_band
			var a_war: int = 1 if a.is_armed else 0
			var b_war: int = 1 if b.is_armed else 0
			if a_war != b_war:
				return a_war > b_war
			if a.hull_space != b.hull_space:
				return a.hull_space > b.hull_space
			return a.uid < b.uid
		)
		for u in remaining:
			ordered_uids.append(u.uid)

		party_line_uids[p.party_id] = []
		party_reserve_uids[p.party_id] = ordered_uids

	# Distances
	var pair_distances: Dictionary = {}
	for i in range(parties.size()):
		for j in range(i + 1, parties.size()):
			var p_a: CombatParty = parties[i]
			var p_b: CombatParty = parties[j]
			var key: String = "%d_%d" % [mini(p_a.party_id, p_b.party_id), maxi(p_a.party_id, p_b.party_id)]
			if input.start_distances.has(key):
				pair_distances[key] = int(input.start_distances[key])
			else:
				pair_distances[key] = 10

	var in_flight_missiles: Array[Dictionary] = []
	var next_missile_id: int = 1
	var total_rounds: int = 8

	# Check early end before round 1 (e.g. only one side has armed ships)
	var live_armed_parties_pre: Array[CombatParty] = []
	for p in parties:
		if p.has_live_armed():
			live_armed_parties_pre.append(p)
	if live_armed_parties_pre.size() <= 1 and parties.size() >= 2:
		# Unarmed side present vs armed side: battle will resolve in round 1
		total_rounds = 1

	for round_num in range(1, total_rounds + 1):
		var round_data: Dictionary = {
			"round_num": round_num,
			"distances": {},
			"line_slots": {},
			"reserves": {},
			"swat_intercepts": [],
			"horizon_hits": [],
			"shots": [],
			"launches": [],
			"heals": [],
			"destroyed_uids": []
		}

		# 1. Reserves fill line slots
		for p in parties:
			var line: Array = party_line_uids[p.party_id]
			# Filter dead units from line
			var new_line: Array[int] = []
			var used_slots: int = 0
			for uid in line:
				var u: CombatUnit = all_units[uid]
				if u.is_alive():
					new_line.append(uid)
					if not u.is_planet:
						used_slots += u.line_slots
			line = new_line

			var reserves: Array = party_reserve_uids[p.party_id]
			var new_reserves: Array[int] = []
			for uid in reserves:
				var u: CombatUnit = all_units[uid]
				if not u.is_alive():
					continue
				var needed_slots: int = 0 if u.is_planet else u.line_slots
				if used_slots + needed_slots <= p.max_line_slots:
					line.append(uid)
					used_slots += needed_slots
				else:
					new_reserves.append(uid)
			party_line_uids[p.party_id] = line
			party_reserve_uids[p.party_id] = new_reserves
			round_data["line_slots"][p.party_id] = line.duplicate()
			round_data["reserves"][p.party_id] = new_reserves.duplicate()

		# Update distances
		for i in range(parties.size()):
			for j in range(i + 1, parties.size()):
				var p_a: CombatParty = parties[i]
				var p_b: CombatParty = parties[j]
				var key: String = "%d_%d" % [mini(p_a.party_id, p_b.party_id), maxi(p_a.party_id, p_b.party_id)]
				var cur_d: int = pair_distances[key]
				var s_a: int = p_a.get_combat_speed(party_line_uids[p_a.party_id])
				var s_b: int = p_b.get_combat_speed(party_line_uids[p_b.party_id])
				var pref_a: int = 12 if p_a.retreating else RangeTrack.preferred(p_a.posture, p_a.auto_band, p_a.has_horizon_ammo())
				var pref_b: int = 12 if p_b.retreating else RangeTrack.preferred(p_b.posture, p_b.auto_band, p_b.has_horizon_ammo())
				var new_d: int = RangeTrack.step(cur_d, pref_a, s_a, pref_b, s_b)
				pair_distances[key] = new_d
				round_data["distances"][key] = new_d

		# 2. Horizon in flight arrives
		var swat_intercepted: Dictionary = {} # "shooterUid_mountIdx" -> true
		var arriving_missiles: Array[Dictionary] = []
		var remaining_missiles: Array[Dictionary] = []
		for m in in_flight_missiles:
			if m["round_arrives"] == round_num:
				arriving_missiles.append(m)
			else:
				remaining_missiles.append(m)
		in_flight_missiles = remaining_missiles

		# Swat interception for missiles-first
		for p in parties:
			if p.swat_mode != "missiles_first":
				continue
			var target_missiles: Array[Dictionary] = []
			for m in arriving_missiles:
				var tgt_u: CombatUnit = all_units.get(m["target_uid"])
				if tgt_u != null and party_of_unit[tgt_u.uid].party_id == p.party_id:
					target_missiles.append(m)

			if target_missiles.is_empty():
				continue

			# Collect live swat mounts in line
			var line_uids: Array = party_line_uids[p.party_id]
			for uid in line_uids:
				var u: CombatUnit = all_units[uid]
				if not u.is_alive():
					continue
				for m_idx in range(u.weapons.size()):
					var w: Dictionary = u.weapons[m_idx]
					if not bool(w.get("swat", false)):
						continue
					for shot_idx in range(2): # swat_shots = 2
						if target_missiles.is_empty():
							break
						var m_tgt: Dictionary = target_missiles[0]
						var rng := Rng.keyed(input.seed, input.turn, Rng.COMBAT, input.system_id, Rng.hash_ints([round_num, STEP_SWAT_INTERCEPT, u.empire_id, u.uid, m_idx, shot_idx]))
						var swat_acc: int = u.acc + int(w.get("acc", 20))
						var to_hit: int = clampi(60 + swat_acc, 5, 95)
						var hit: bool = rng.chance_pct(to_hit)
						round_data["swat_intercepts"].append({
							"swat_uid": u.uid,
							"mount_index": m_idx,
							"shot_index": shot_idx,
							"missile_id": m_tgt["missile_id"],
							"hit": hit
						})
						swat_intercepted["%d_%d" % [u.uid, m_idx]] = true
						if hit:
							target_missiles.pop_front()
							arriving_missiles.erase(m_tgt)

		# Surviving missiles hit
		for m in arriving_missiles:
			var tgt: CombatUnit = all_units.get(m["target_uid"])
			if tgt == null or not tgt.is_alive():
				continue
			var rng := Rng.keyed(input.seed, input.turn, Rng.COMBAT, input.system_id, Rng.hash_ints([round_num, STEP_HORIZON_HIT, m["source_empire_id"], m["launcher_uid"], m["missile_id"], 0]))
			var scatter: int = 20 if tgt.scatter_molt else 0
			var to_hit: int = clampi(70 + m["acc"] - tgt.miss_field - IntMath.floor_div(tgt.evasion, 2) - scatter, 5, 95)
			var hit: bool = rng.chance_pct(to_hit)
			var dmg_dealt: int = 0
			if hit:
				var raw_dmg: int = IntMath.floor_div(m["dmg"] * (100 + m["band_pct"]), 100)
				var eff_shield: int = tgt.shield
				var tgt_party: CombatParty = party_of_unit[tgt.uid]
				if tgt_party.is_colony_defense:
					eff_shield = maxi(eff_shield, tgt_party.planet_shield)
				dmg_dealt = maxi(0, raw_dmg - eff_shield)
				tgt.hp -= dmg_dealt
				var launcher_u: CombatUnit = all_units.get(m["launcher_uid"])
				if launcher_u != null:
					launcher_u.damage_dealt += dmg_dealt
				band_damage_totals["horizon"] += dmg_dealt
			round_data["horizon_hits"].append({
				"launcher_uid": m["launcher_uid"],
				"target_uid": tgt.uid,
				"missile_id": m["missile_id"],
				"hit": hit,
				"damage": dmg_dealt,
				"target_hp_after": tgt.hp
			})

		# 3. Direct line mounts fire (snapshot state at start of step)
		var snapshot_hp: Dictionary = {}
		for u in all_units.values():
			snapshot_hp[u.uid] = u.hp

		var direct_damage_queue: Array[Dictionary] = []

		for p in parties:
			var line_uids: Array = party_line_uids[p.party_id]
			# Count plurality band for v_formation
			var band_counts: Dictionary = {"talon": 0, "beak": 0, "horizon": 0}
			for uid in line_uids:
				var u: CombatUnit = all_units[uid]
				if u.is_alive() and u.is_armed and band_counts.has(u.main_band):
					band_counts[u.main_band] += 1
			var plurality_band: String = "talon"
			var plurality_count: int = 0
			for b in ["talon", "beak", "horizon"]:
				if band_counts[b] > plurality_count:
					plurality_count = band_counts[b]
					plurality_band = b

			for uid in line_uids:
				var shooter: CombatUnit = all_units[uid]
				if snapshot_hp[shooter.uid] <= 0:
					continue
				if not shooter.is_armed:
					continue

				for m_idx in range(shooter.weapons.size()):
					var mount: Dictionary = shooter.weapons[m_idx]
					var band: String = str(mount.get("band", ""))
					if band == "horizon":
						continue # Launches in Step 4
					if bool(mount.get("swat", false)) and swat_intercepted.has("%d_%d" % [shooter.uid, m_idx]):
						continue # Already intercepted in Step 2

					# Find candidate targets
					var candidates: Array[CombatUnit] = []
					var D: int = 10
					for other_p in parties:
						if other_p.party_id == p.party_id or other_p.empire_id == p.empire_id:
							continue
						var pair_key: String = "%d_%d" % [mini(p.party_id, other_p.party_id), maxi(p.party_id, other_p.party_id)]
						D = pair_distances.get(pair_key, 10)
						var enemy_line: Array = party_line_uids[other_p.party_id]
						for e_uid in enemy_line:
							var cand: CombatUnit = all_units[e_uid]
							if snapshot_hp[cand.uid] <= 0:
								continue
							if cand.gone_to_molt and round_num <= 2:
								continue
							candidates.append(cand)

					if candidates.is_empty():
						continue

					var tgt_uid: int = Targeting.pick(shooter, mount, candidates, p.target_priority, D)
					if tgt_uid == -1:
						continue
					var tgt: CombatUnit = all_units[tgt_uid]

					# Check Not This Feather
					if tgt.not_this_feather:
						var f_rng := Rng.keyed(input.seed, input.turn, Rng.COMBAT, input.system_id, Rng.hash_ints([round_num, STEP_FEATHER, shooter.empire_id, shooter.uid, m_idx, 0]))
						if f_rng.chance_pct(25):
							round_data["shots"].append({
								"shooter_uid": shooter.uid,
								"target_uid": tgt.uid,
								"mount_index": m_idx,
								"hit": false,
								"miss_reason": "feather",
								"damage": 0
							})
							continue

					# To-hit roll
					var h_rng := Rng.keyed(input.seed, input.turn, Rng.COMBAT, input.system_id, Rng.hash_ints([round_num, STEP_DIRECT_HIT, shooter.empire_id, shooter.uid, m_idx, 0]))
					var beak_pen: int = (6 * D) if band == "beak" else 0
					var to_hit: int = clampi(60 + shooter.acc + int(mount.get("acc", 0)) - tgt.evasion - beak_pen, 5, 95)
					var hit: bool = h_rng.chance_pct(to_hit)
					if not hit:
						round_data["shots"].append({
							"shooter_uid": shooter.uid,
							"target_uid": tgt.uid,
							"mount_index": m_idx,
							"hit": false,
							"damage": 0
						})
						continue

					# Damage roll
					var d_rng := Rng.keyed(input.seed, input.turn, Rng.COMBAT, input.system_id, Rng.hash_ints([round_num, STEP_DIRECT_DMG, shooter.empire_id, shooter.uid, m_idx, 0]))
					var raw_dmg: int = d_rng.range_i(int(mount.get("dmg_min", 0)), int(mount.get("dmg_max", 0)))

					var band_pct: int = 0
					if band == "talon" and "talon_adepts" in p.traits:
						band_pct += 25
					elif band == "beak" and "beak_adepts" in p.traits:
						band_pct += 25
					if "guardian_marked" in p.traits:
						band_pct -= 10

					var v_bonus: int = 0
					if "v_formation" in p.traits and band == plurality_band and plurality_count > 1:
						v_bonus = mini(25, (plurality_count - 1) * 5)

					var flush_bonus: int = 0
					if p.is_attacker and "flush" in p.traits and round_num == 1:
						flush_bonus = 20

					var dmg_mod: int = IntMath.floor_div(raw_dmg * (100 + band_pct + v_bonus + flush_bonus), 100)
					if band == "talon":
						var falloff: int = int(mount.get("falloff_pct", 4))
						dmg_mod = IntMath.floor_div(dmg_mod * (100 - falloff * D), 100)

					var tgt_party: CombatParty = party_of_unit[tgt.uid]
					var eff_shield: int = tgt.shield
					if tgt_party.is_colony_defense:
						eff_shield = maxi(eff_shield, tgt_party.planet_shield)

					if band == "beak":
						eff_shield = IntMath.floor_div(eff_shield, 2)
						if tgt.ignores_shields_pct > 0:
							eff_shield = IntMath.floor_div(tgt.shield * (100 - tgt.ignores_shields_pct), 100)

					var final_dmg: int = maxi(0, dmg_mod - eff_shield)
					var shot_record: Dictionary = {
						"shooter_uid": shooter.uid,
						"target_uid": tgt.uid,
						"mount_index": m_idx,
						"hit": hit,
						"damage": final_dmg if hit else 0
					}
					round_data["shots"].append(shot_record)

					if hit and final_dmg > 0:
						direct_damage_queue.append({
							"target_uid": tgt.uid,
							"shooter_uid": shooter.uid,
							"band": band,
							"damage": final_dmg
						})

		# Apply direct damage simultaneously
		for d in direct_damage_queue:
			var tgt: CombatUnit = all_units[d["target_uid"]]
			tgt.hp -= d["damage"]
			var shooter: CombatUnit = all_units[d["shooter_uid"]]
			shooter.damage_dealt += d["damage"]
			band_damage_totals[d["band"]] += d["damage"]

		# 4. Horizon launch
		for p in parties:
			var line_uids: Array = party_line_uids[p.party_id]
			for uid in line_uids:
				var shooter: CombatUnit = all_units[uid]
				if not shooter.is_alive():
					continue
				for m_idx in range(shooter.weapons.size()):
					var mount: Dictionary = shooter.weapons[m_idx]
					if str(mount.get("band", "")) != "horizon":
						continue
					var salvos: int = int(mount.get("salvos", -1))
					if salvos == 0:
						continue
					var every_other: bool = bool(mount.get("every_other_round", false))
					if every_other and (round_num % 2 != 0):
						continue

					# Candidate targets
					var candidates: Array[CombatUnit] = []
					var D: int = 10
					for other_p in parties:
						if other_p.party_id == p.party_id or other_p.empire_id == p.empire_id:
							continue
						var pair_key: String = "%d_%d" % [mini(p.party_id, other_p.party_id), maxi(p.party_id, other_p.party_id)]
						D = pair_distances.get(pair_key, 10)
						var enemy_line: Array = party_line_uids[other_p.party_id]
						for e_uid in enemy_line:
							var cand: CombatUnit = all_units[e_uid]
							if cand.is_alive():
								candidates.append(cand)

					if candidates.is_empty():
						continue

					var tgt_uid: int = Targeting.pick(shooter, mount, candidates, p.target_priority, D)
					if tgt_uid == -1:
						continue

					var band_pct: int = 0
					if "horizon_adepts" in p.traits:
						band_pct += 25
					if "guardian_marked" in p.traits:
						band_pct -= 10

					in_flight_missiles.append({
						"missile_id": next_missile_id,
						"launcher_uid": shooter.uid,
						"target_uid": tgt_uid,
						"source_empire_id": shooter.empire_id,
						"acc": shooter.acc + int(mount.get("acc", 0)),
						"dmg": int(mount.get("dmg_min", 0)),
						"band_pct": band_pct,
						"round_arrives": round_num + 1
					})
					round_data["launches"].append({
						"launcher_uid": shooter.uid,
						"target_uid": tgt_uid,
						"missile_id": next_missile_id
					})
					next_missile_id += 1
					if salvos > 0:
						mount["salvos"] = salvos - 1

		# 5. Cleanup & heals
		for u in all_units.values():
			if u.is_alive():
				u.rounds_survived = round_num
				if u.self_sealing and u.hp < u.hp_max:
					var heal: int = IntMath.floor_div(u.hp_max * 10, 100)
					u.hp = mini(u.hp_max, u.hp + heal)
					round_data["heals"].append({
						"uid": u.uid,
						"amount": heal,
						"hp_after": u.hp
					})
			else:
				round_data["destroyed_uids"].append(u.uid)

		log.rounds.append(round_data)

		# Check early end
		var live_armed_parties: Array[CombatParty] = []
		for p in parties:
			if p.has_live_armed():
				live_armed_parties.append(p)

		if live_armed_parties.size() <= 1:
			break

	# Battle completion
	log.final_distances = pair_distances.duplicate()
	for u in all_units.values():
		log.final_units.append(u.to_dict())

	# Determine winner & standout
	var armed_survivor_parties: Array[CombatParty] = []
	for p in parties:
		if p.has_live_armed():
			armed_survivor_parties.append(p)

	if armed_survivor_parties.size() == 1:
		log.winner_empire_id = armed_survivor_parties[0].empire_id
		log.is_stalemate = false
	elif armed_survivor_parties.size() > 1:
		log.winner_empire_id = -1
		log.is_stalemate = true
	else:
		log.winner_empire_id = -1
		log.is_stalemate = false

	# Deciding band
	var max_band_dmg: int = -1
	var best_band: String = "talon"
	for b in ["talon", "beak", "horizon"]:
		if band_damage_totals[b] > max_band_dmg:
			max_band_dmg = band_damage_totals[b]
			best_band = b
	log.deciding_band = best_band

	# Standout ship
	var max_unit_dmg: int = -1
	var standout_uid: int = -1
	for u in all_units.values():
		if u.damage_dealt > max_unit_dmg:
			max_unit_dmg = u.damage_dealt
			standout_uid = u.uid
	log.standout_ship_uid = standout_uid

	# Losses
	for p in parties:
		var lost: Array = []
		for u in p.units:
			if not u.is_alive():
				lost.append(u.to_dict())
		log.losses[p.empire_id] = lost

	return log
