class_name CombatMath
extends RefCounted

static func expected_damage(db: ContentDB, gs: GameState, design: Variant, d: int, shield: int, target_evasion: int = 5) -> int:
	var weapons: Array = []
	var computer_id: String = ""
	if design is ShipDesign:
		weapons = design.weapons
		computer_id = design.computer
	elif design is Dictionary:
		weapons = design.get("weapons", [])
		computer_id = str(design.get("computer", ""))

	var computer_acc: int = 0
	if db != null and computer_id != "":
		var comp_row: Dictionary = db.row("parts", computer_id)
		computer_acc = int(comp_row.get("acc", 0))

	var total: int = 0
	for w in weapons:
		var part_id: String = str(w.get("part", ""))
		var mount_id: String = str(w.get("mount", ""))
		var count: int = int(w.get("count", 1))
		if part_id == "" or count <= 0:
			continue
		var part_row: Dictionary = db.row("parts", part_id) if db != null else {}
		var mount_row: Dictionary = db.row("parts", mount_id) if (db != null and mount_id != "") else {}

		var band: String = str(part_row.get("band", ""))
		var dmg_min: int = int(part_row.get("dmg_min", 0))
		var dmg_max: int = int(part_row.get("dmg_max", 0))
		var acc: int = int(part_row.get("acc", 0)) + computer_acc

		if not mount_row.is_empty():
			acc += int(mount_row.get("acc", 0))
			var dmg_pct: int = int(mount_row.get("dmg_pct", 100))
			dmg_min = IntMath.floor_div(dmg_min * dmg_pct, 100)
			dmg_max = IntMath.floor_div(dmg_max * dmg_pct, 100)

		var avg_dmg_2x: int = dmg_min + dmg_max
		var hit_chance: int = 0
		var eff_dmg_2x: int = 0

		if band == "talon":
			var falloff: int = int(mount_row.get("falloff_pct", -1))
			if falloff == -1:
				falloff = int(part_row.get("falloff_pct", 4))
			hit_chance = clampi(60 + acc - target_evasion, 5, 95)
			var after_falloff: int = IntMath.floor_div(avg_dmg_2x * (100 - falloff * d), 100)
			eff_dmg_2x = maxi(0, after_falloff - (shield * 2))
		elif band == "beak":
			hit_chance = clampi(60 + acc - target_evasion - (6 * d), 5, 95)
			var eff_shield: int = IntMath.floor_div(shield, 2)
			eff_dmg_2x = maxi(0, avg_dmg_2x - (eff_shield * 2))
		elif band == "horizon":
			var salvos: int = int(part_row.get("salvos", -1))
			var every_other: bool = bool(part_row.get("every_other_round", false))
			hit_chance = clampi(70 + acc - IntMath.floor_div(target_evasion, 2), 5, 95)
			eff_dmg_2x = maxi(0, avg_dmg_2x - (shield * 2))
			if salvos > 0:
				eff_dmg_2x = IntMath.floor_div(eff_dmg_2x * salvos, 8)
			elif every_other:
				eff_dmg_2x = IntMath.floor_div(eff_dmg_2x, 2)

		var expected_per_mount: int = IntMath.floor_div(hit_chance * eff_dmg_2x, 200)
		total += expected_per_mount * count

	return total

static func unit_expected_damage(unit: CombatUnit, d: int, shield: int, target_evasion: int = 5) -> int:
	var total: int = 0
	for w in unit.weapons:
		var band: String = str(w.get("band", ""))
		var dmg_min: int = int(w.get("dmg_min", 0))
		var dmg_max: int = int(w.get("dmg_max", 0))
		var acc: int = unit.acc + int(w.get("acc", 0))
		var avg_dmg_2x: int = dmg_min + dmg_max
		var hit_chance: int = 0
		var eff_dmg_2x: int = 0

		if band == "talon":
			var falloff: int = int(w.get("falloff_pct", 4))
			hit_chance = clampi(60 + acc - target_evasion, 5, 95)
			var after_falloff: int = IntMath.floor_div(avg_dmg_2x * (100 - falloff * d), 100)
			eff_dmg_2x = maxi(0, after_falloff - (shield * 2))
		elif band == "beak":
			hit_chance = clampi(60 + acc - target_evasion - (6 * d), 5, 95)
			var eff_shield: int = IntMath.floor_div(shield, 2)
			eff_dmg_2x = maxi(0, avg_dmg_2x - (eff_shield * 2))
		elif band == "horizon":
			var salvos: int = int(w.get("salvos", -1))
			var every_other: bool = bool(w.get("every_other_round", false))
			hit_chance = clampi(70 + acc - IntMath.floor_div(target_evasion, 2), 5, 95)
			eff_dmg_2x = maxi(0, avg_dmg_2x - (shield * 2))
			if salvos > 0:
				eff_dmg_2x = IntMath.floor_div(eff_dmg_2x * salvos, 8)
			elif every_other:
				eff_dmg_2x = IntMath.floor_div(eff_dmg_2x, 2)

		var expected_per_mount: int = IntMath.floor_div(hit_chance * eff_dmg_2x, 200)
		total += expected_per_mount
	return total

static func party_strength(party: CombatParty, enemy_avg_shield: int) -> int:
	var total_hp: int = 0
	var total_dmg: int = 0
	for u in party.units:
		if not u.is_alive():
			continue
		total_hp += u.hp
		if u.is_armed:
			total_dmg += unit_expected_damage(u, 3, enemy_avg_shield, 5)
	return IntMath.isqrt(total_hp * maxi(1, total_dmg))

static func odds_pct(own: CombatParty, enemy: CombatParty) -> int:
	var own_shield_sum: int = 0
	for u in own.units:
		own_shield_sum += u.shield
	var own_avg_shield: int = IntMath.floor_div(own_shield_sum, maxi(1, own.units.size()))

	var enemy_shield_sum: int = 0
	for u in enemy.units:
		enemy_shield_sum += u.shield
	var enemy_avg_shield: int = IntMath.floor_div(enemy_shield_sum, maxi(1, enemy.units.size()))

	var s_own: int = party_strength(own, enemy_avg_shield)
	var s_enemy: int = party_strength(enemy, own_avg_shield)
	if s_own + s_enemy == 0:
		return 50
	return IntMath.floor_div(s_own * 100, s_own + s_enemy)
