class_name Retreat
extends RefCounted

static func should_retreat(party: CombatParty, enemy: CombatParty) -> bool:
	if party.posture == "retreat":
		return true
	if party.retreat_threshold == "never":
		return false

	var odds: int = CombatMath.odds_pct(party, enemy)
	if party.retreat_threshold == "half":
		return odds < 50
	elif party.retreat_threshold == "even":
		return odds < 100
	return false

static func calc_escape_round(own_instant_regret: bool, enemy_tractor: bool, enemy_flush_first_battle: bool, enemy_no_exit_home: bool) -> int:
	if enemy_no_exit_home:
		return 8
	var r: int = 1 if own_instant_regret else 2
	if enemy_tractor:
		r += 2
	if enemy_flush_first_battle:
		r += 1
	return mini(8, r)

static func pick_receipt_unit(units: Array[CombatUnit]) -> CombatUnit:
	var live_ships: Array[CombatUnit] = []
	for u in units:
		if u.is_alive() and not u.is_planet:
			live_ships.append(u)
	if live_ships.is_empty():
		return null

	live_ships.sort_custom(func(a: CombatUnit, b: CombatUnit) -> bool:
		# Key 1: slowest ship (lowest combat_speed)
		if a.combat_speed != b.combat_speed:
			return a.combat_speed < b.combat_speed
		# Key 2: most damaged (highest hp_max - hp)
		var dmg_a: int = a.hp_max - a.hp
		var dmg_b: int = b.hp_max - b.hp
		if dmg_a != dmg_b:
			return dmg_a > dmg_b
		# Key 3: lowest id
		return a.uid < b.uid
	)
	return live_ships[0]

static func apply_receipt(party: CombatParty) -> CombatUnit:
	var receipt: CombatUnit = pick_receipt_unit(party.units)
	if receipt != null:
		receipt.hp = 0
		party.receipt_unit_uid = receipt.uid
	return receipt

static func apply_guardian_marked_if_eligible(gs: GameState, retreating_party: CombatParty, enemy_party: CombatParty, turn: int) -> void:
	if gs == null or retreating_party == null or enemy_party == null:
		return
	if not retreating_party.retreating:
		return

	var is_guardian: bool = false
	for u in enemy_party.units:
		if u.name_key == "guardian" or u.design_id == "guardian" or u.hull_id == "guardian":
			is_guardian = true
			break
	if not is_guardian:
		return

	var emp_id: int = retreating_party.empire_id
	if emp_id < 0 or emp_id >= gs.empires.size():
		return
	var emp: Empire = gs.empires[emp_id]

	var tm := TimedMod.new()
	tm.source_key = "guardian_marked"
	tm.effects = [
		{"stat": "band_damage_pct", "op": "pct", "value": -10}
	]
	tm.until_turn = turn + 10
	emp.timed_mods.append(tm)

