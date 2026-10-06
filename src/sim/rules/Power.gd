class_name Power
extends RefCounted

static func fleet_power(units: Array) -> int:
	var sum_term: int = 0
	for u in units:
		var hp: int = 0
		var dps: int = 0
		if u is CombatUnit:
			if not (u as CombatUnit).is_alive():
				continue
			hp = (u as CombatUnit).hp
			if (u as CombatUnit).is_armed:
				dps = CombatMath.unit_expected_damage(u as CombatUnit, 3, 2, 5)
		elif u is Dictionary:
			hp = int((u as Dictionary).get("hp", 0))
			dps = int((u as Dictionary).get("expected_dps", 1))
		sum_term += IntMath.isqrt(maxi(1, dps) * hp)
	return sum_term * sum_term

static func ship_power(db: ContentDB, gs: GameState, ship: Ship, baseline_shield: int = 2) -> int:
	if ship == null or ship.hp <= 0:
		return 0
	var des: ShipDesign = gs.designs.get(ship.design_id)
	if des == null:
		return ship.hp
	var dps: int = CombatMath.expected_damage(db, gs, des, 3, baseline_shield, 5)
	return maxi(1, dps) * ship.hp

static func fleet_obj_power(db: ContentDB, gs: GameState, flt: Fleet, baseline_shield: int = 2) -> int:
	if flt == null or flt.ship_ids.is_empty():
		return 0
	var sum_term: int = 0
	for sid in flt.ship_ids:
		var s: Ship = gs.ships.get(sid)
		if s == null or s.hp <= 0:
			continue
		var des: ShipDesign = gs.designs.get(s.design_id)
		var dps: int = 1
		if des != null:
			dps = maxi(1, CombatMath.expected_damage(db, gs, des, 3, baseline_shield, 5))
		sum_term += IntMath.isqrt(dps * s.hp)
	return sum_term * sum_term

static func empire_military_power(db: ContentDB, gs: GameState, empire_id: int) -> int:
	var total: int = 0
	for fid in Ids.sorted_keys(gs.fleets):
		var f: Fleet = gs.fleets[fid]
		if f.owner == empire_id:
			total += fleet_obj_power(db, gs, f)
	return total
