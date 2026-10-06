class_name Targeting
extends RefCounted

static func calc_mount_max_damage_vs(mount: Dictionary, target: CombatUnit, d: int) -> int:
	var band: String = str(mount.get("band", ""))
	var max_raw: int = int(mount.get("dmg_max", 0))
	var target_shield: int = target.shield

	if band == "talon":
		var falloff: int = int(mount.get("falloff_pct", 4))
		max_raw = IntMath.floor_div(max_raw * (100 - falloff * d), 100)
		return maxi(0, max_raw - target_shield)
	elif band == "beak":
		var eff_shield: int = IntMath.floor_div(target_shield, 2)
		if target.ignores_shields_pct > 0:
			eff_shield = IntMath.floor_div(target_shield * (100 - target.ignores_shields_pct), 100)
		return maxi(0, max_raw - eff_shield)
	elif band == "horizon":
		return maxi(0, max_raw - target_shield)
	return maxi(0, max_raw - target_shield)

static func pick(shooter_unit: CombatUnit, mount: Dictionary, candidates: Array[CombatUnit], priority: String, d: int) -> int:
	if candidates.is_empty():
		return -1

	var best_uid: int = -1
	var best_k1: int = -999999
	var best_k2_tier: int = 999
	var best_k2_hp: int = 999999

	for c in candidates:
		if not c.is_alive():
			continue

		# Key 1: Priority
		var k1: int = 0
		match priority:
			"biggest":
				k1 = c.hull_space
			"swat":
				k1 = 1 if c.is_swat else 0
			"band_talon":
				k1 = 1 if c.main_band == "talon" else 0
			"band_beak":
				k1 = 1 if c.main_band == "beak" else 0
			"band_horizon":
				k1 = 1 if c.main_band == "horizon" else 0
			"defenses":
				k1 = 1 if c.is_planet else 0
			"transports":
				k1 = 1 if (not c.is_armed and c.has_pods) else 0
			"auto", _:
				k1 = 0

		# Key 2: Auto score
		var max_dmg: int = calc_mount_max_damage_vs(mount, c, d)
		var k2_tier: int = 2
		if max_dmg > 0 and c.hp <= max_dmg:
			k2_tier = 0 # Can die now
		elif max_dmg > 0:
			k2_tier = 1 # Can damage
		else:
			k2_tier = 2 # Cannot damage
		var k2_hp: int = c.hp

		# Compare: higher k1, lower k2_tier, lower k2_hp, lower uid
		var is_better: bool = false
		if best_uid == -1:
			is_better = true
		elif k1 != best_k1:
			is_better = k1 > best_k1
		elif k2_tier != best_k2_tier:
			is_better = k2_tier < best_k2_tier
		elif k2_hp != best_k2_hp:
			is_better = k2_hp < best_k2_hp
		elif c.uid != best_uid:
			is_better = c.uid < best_uid

		if is_better:
			best_uid = c.uid
			best_k1 = k1
			best_k2_tier = k2_tier
			best_k2_hp = k2_hp

	return best_uid
