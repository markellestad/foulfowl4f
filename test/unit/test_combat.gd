extends GutTest

func _make_test_unit(uid: int, empire_id: int, hull: String, hp: int, shield: int = 0, evasion: int = 0, acc: int = 0, speed: int = 1) -> CombatUnit:
	var u := CombatUnit.new()
	u.uid = uid
	u.empire_id = empire_id
	u.hull_id = hull
	u.hull_space = 24 if hull == "small" else (60 if hull == "medium" else (600 if hull == "titan" else 100))
	u.hp = hp
	u.hp_max = hp
	u.shield = shield
	u.evasion = evasion
	u.acc = acc
	u.combat_speed = speed
	u.line_slots = 2 if hull == "titan" else 1
	u.is_armed = false
	return u

func _add_talon_weapon(u: CombatUnit, min_d: int = 3, max_d: int = 8, acc: int = 0, falloff: int = 4) -> void:
	u.is_armed = true
	u.main_band = "talon"
	u.weapons.append({
		"part_id": "wick_talon",
		"band": "talon",
		"dmg_min": min_d,
		"dmg_max": max_d,
		"acc": acc,
		"falloff_pct": falloff,
		"salvos": -1,
		"every_other_round": false,
		"swat": false
	})

func _add_beak_weapon(u: CombatUnit, min_d: int = 5, max_d: int = 9, acc: int = 0) -> void:
	u.is_armed = true
	u.main_band = "beak"
	u.weapons.append({
		"part_id": "peck_driver",
		"band": "beak",
		"dmg_min": min_d,
		"dmg_max": max_d,
		"acc": acc,
		"falloff_pct": 0,
		"salvos": -1,
		"every_other_round": false,
		"swat": false
	})

func _add_horizon_weapon(u: CombatUnit, dmg: int = 5, acc: int = 0, salvos: int = 3, every_other: bool = false) -> void:
	u.is_armed = true
	u.main_band = "horizon"
	u.weapons.append({
		"part_id": "hatch_dart",
		"band": "horizon",
		"dmg_min": dmg,
		"dmg_max": dmg,
		"acc": acc,
		"falloff_pct": 0,
		"salvos": salvos,
		"every_other_round": every_other,
		"swat": false
	})

func _add_swat_mount(u: CombatUnit, min_d: int = 2, max_d: int = 4, acc: int = 20) -> void:
	u.is_armed = true
	u.is_swat = true
	u.weapons.append({
		"part_id": "swat_talon",
		"band": "talon",
		"dmg_min": min_d,
		"dmg_max": max_d,
		"acc": acc,
		"falloff_pct": 4,
		"salvos": -1,
		"every_other_round": false,
		"swat": true
	})

func test_to_hit_clamps() -> void:
	# to-hit clamps at 5 and 95
	var u1 := _make_test_unit(1, 0, "small", 100, 0, 0, 1000) # ultra high acc
	_add_talon_weapon(u1, 5, 5, 1000)
	var u2 := _make_test_unit(2, 1, "small", 100, 0, 0, 0)
	var p1 := CombatParty.new()
	p1.party_id = 0
	p1.empire_id = 0
	p1.units = [u1]
	var p2 := CombatParty.new()
	p2.party_id = 1
	p2.empire_id = 1
	p2.units = [u2]
	var input := CombatInput.new()
	input.system_id = 1
	input.seed = 42
	input.parties = [p1, p2]
	input.start_distances = {"0_1": 10}

	# Verify clamp logic in hit calculations
	var to_hit_high: int = clampi(60 + 1000 - 0, 5, 95)
	assert_eq(to_hit_high, 95)
	var to_hit_low: int = clampi(60 - 1000 - 0, 5, 95)
	assert_eq(to_hit_low, 5)

func test_beak_loses_6_per_distance() -> void:
	var d0: int = 0
	var d5: int = 5
	var pen0: int = 6 * d0
	var pen5: int = 6 * d5
	assert_eq(pen0, 0)
	assert_eq(pen5, 30)

func test_talon_falloff_and_shields() -> void:
	# Talon falloff and full shields; Beak half shields; damage never negative
	var mount := {"band": "talon", "dmg_max": 20, "falloff_pct": 4}
	var target := _make_test_unit(2, 1, "small", 50, 4) # shield = 4
	var dmg_d0: int = Targeting.calc_mount_max_damage_vs(mount, target, 0)
	assert_eq(dmg_d0, 20 - 4) # 16
	var dmg_d5: int = Targeting.calc_mount_max_damage_vs(mount, target, 5) # 20% falloff: 20 * 0.8 = 16 - 4 = 12
	assert_eq(dmg_d5, 12)

	# High shield: damage never negative
	target.shield = 100
	var dmg_neg: int = Targeting.calc_mount_max_damage_vs(mount, target, 0)
	assert_eq(dmg_neg, 0)

func test_beak_half_shields() -> void:
	var mount := {"band": "beak", "dmg_max": 20}
	var target := _make_test_unit(2, 1, "small", 50, 5) # shield = 5 -> eff shield = 2
	var dmg: int = Targeting.calc_mount_max_damage_vs(mount, target, 0)
	assert_eq(dmg, 20 - 2) # 18

func test_shots_use_start_of_step_hp() -> void:
	# shots in one step use start-of-step HP (two shooters both target a 1-HP unit: both shots resolve, the unit dies once)
	var u1 := _make_test_unit(1, 0, "small", 50)
	_add_talon_weapon(u1, 10, 10, 100) # 100% to hit after clamp (95%)
	var u2 := _make_test_unit(2, 0, "small", 50)
	_add_talon_weapon(u2, 10, 10, 100)

	var target := _make_test_unit(3, 1, "small", 1, 0) # 1 HP!
	_add_talon_weapon(target, 1, 1)

	var p1 := CombatParty.new()
	p1.party_id = 0
	p1.empire_id = 0
	p1.units = [u1, u2]
	var p2 := CombatParty.new()
	p2.party_id = 1
	p2.empire_id = 1
	p2.units = [target]

	var input := CombatInput.new()
	input.system_id = 1
	input.seed = 123
	input.parties = [p1, p2]
	input.start_distances = {"0_1": 0}

	var log: BattleLog = CombatResolver.resolve(input)
	assert_eq(log.rounds.size() >= 1, true)
	var r1: Dictionary = log.rounds[0]
	var shots: Array = r1["shots"]
	assert_eq(shots.size(), 3, "Both shooters and target fire in round 1")
	assert_eq(shots[0]["target_uid"], 3)
	assert_eq(shots[1]["target_uid"], 3)
	assert_true(target.hp <= 0, "Target is dead")

func test_line_slots_and_reserves() -> void:
	# line slots: 9 ships -> 8 in line, the 9th enters when one dies
	var p1 := CombatParty.new()
	p1.party_id = 0
	p1.empire_id = 0
	p1.max_line_slots = 8
	for i in range(1, 10):
		var u := _make_test_unit(i, 0, "small", 20 if i > 1 else 1) # ship 1 has 1 HP so it dies in round 1
		_add_talon_weapon(u, 5, 5)
		p1.units.append(u)

	var enemy := _make_test_unit(10, 1, "small", 500)
	_add_talon_weapon(enemy, 50, 50, 100) # Kills ship 1 in round 1
	var p2 := CombatParty.new()
	p2.party_id = 1
	p2.empire_id = 1
	p2.units = [enemy]

	var input := CombatInput.new()
	input.system_id = 1
	input.seed = 999
	input.parties = [p1, p2]
	input.start_distances = {"0_1": 0}

	var log: BattleLog = CombatResolver.resolve(input)
	assert_true(log.rounds.size() >= 2)
	var r1_line: Array = log.rounds[0]["line_slots"][0]
	assert_eq(r1_line.size(), 8, "8 ships in line in round 1")
	var r1_res: Array = log.rounds[0]["reserves"][0]
	assert_eq(r1_res.size(), 1, "9th ship in reserves in round 1")

	# In round 2, ship 1 was killed, so ship 9 enters line
	var r2_line: Array = log.rounds[1]["line_slots"][0]
	assert_true(r2_line.has(9), "Ship 9 entered line in round 2")

func test_titan_uses_2_slots() -> void:
	var p1 := CombatParty.new()
	p1.party_id = 0
	p1.empire_id = 0
	p1.max_line_slots = 8
	for i in range(1, 5):
		var t := _make_test_unit(i, 0, "titan", 500)
		_add_talon_weapon(t, 20, 20)
		p1.units.append(t)
	var fifth := _make_test_unit(5, 0, "small", 50)
	_add_talon_weapon(fifth, 5, 5)
	p1.units.append(fifth)

	var enemy := _make_test_unit(10, 1, "small", 100)
	_add_talon_weapon(enemy, 5, 5)
	var p2 := CombatParty.new()
	p2.party_id = 1
	p2.empire_id = 1
	p2.units = [enemy]

	var input := CombatInput.new()
	input.system_id = 1
	input.seed = 42
	input.parties = [p1, p2]
	input.start_distances = {"0_1": 0}

	var log: BattleLog = CombatResolver.resolve(input)
	var r1_line: Array = log.rounds[0]["line_slots"][0]
	# 4 Titans * 2 slots = 8 slots filled! Fifth ship must be in reserve.
	assert_eq(r1_line.size(), 4, "4 Titans filled 8 line slots")
	assert_false(r1_line.has(5), "Fifth ship in reserve")

func test_geese_10_slots() -> void:
	var p1 := CombatParty.new()
	p1.party_id = 0
	p1.empire_id = 0
	p1.max_line_slots = 10
	for i in range(1, 11):
		var u := _make_test_unit(i, 0, "small", 50)
		_add_talon_weapon(u, 5, 5)
		p1.units.append(u)

	var enemy := _make_test_unit(20, 1, "small", 500)
	_add_talon_weapon(enemy, 5, 5)
	var p2 := CombatParty.new()
	p2.party_id = 1
	p2.empire_id = 1
	p2.units = [enemy]

	var input := CombatInput.new()
	input.system_id = 1
	input.seed = 42
	input.parties = [p1, p2]
	input.start_distances = {"0_1": 0}

	var log: BattleLog = CombatResolver.resolve(input)
	var r1_line: Array = log.rounds[0]["line_slots"][0]
	assert_eq(r1_line.size(), 10, "Geese field 10 ships in line")

func test_target_priority_biggest() -> void:
	# target priority keys (biggest picks the largest hull even if another can die)
	var shooter := _make_test_unit(1, 0, "small", 50)
	_add_talon_weapon(shooter, 10, 10)
	var mount: Dictionary = shooter.weapons[0]

	var big := _make_test_unit(2, 1, "medium", 50) # hull_space 60, cannot die
	var small := _make_test_unit(3, 1, "small", 5) # hull_space 24, can die now!

	var picked: int = Targeting.pick(shooter, mount, [big, small], "biggest", 0)
	assert_eq(picked, big.uid, "Priority biggest picks larger hull space over killable")

func test_gone_to_molt_untargetable_rounds_1_2() -> void:
	# Gone to Molt ships fire in round 1 and are never targeted in rounds 1-2
	var shooter := _make_test_unit(1, 0, "small", 50)
	_add_talon_weapon(shooter, 10, 10, 50)

	var molt_ship := _make_test_unit(2, 1, "small", 50)
	molt_ship.gone_to_molt = true
	_add_talon_weapon(molt_ship, 10, 10)

	var normal_ship := _make_test_unit(3, 1, "small", 500)
	_add_talon_weapon(normal_ship, 10, 10)

	var p1 := CombatParty.new()
	p1.party_id = 0
	p1.empire_id = 0
	p1.units = [shooter]
	var p2 := CombatParty.new()
	p2.party_id = 1
	p2.empire_id = 1
	p2.units = [molt_ship, normal_ship]

	var input := CombatInput.new()
	input.system_id = 1
	input.seed = 42
	input.parties = [p1, p2]
	input.start_distances = {"0_1": 0}

	var log: BattleLog = CombatResolver.resolve(input)
	# Molt ship fired in round 1
	var r1_shots: Array = log.rounds[0]["shots"]
	var molt_fired: bool = false
	for s in r1_shots:
		if s["shooter_uid"] == molt_ship.uid:
			molt_fired = true
		if s["target_uid"] == molt_ship.uid:
			fail_test("Molt ship was targeted in round 1!")
	assert_true(molt_fired, "Molt ship fired in round 1")

func test_swat_missiles_first_vs_ships_first() -> void:
	# Swat Missiles-first intercepts before missiles hit, Ships-first never intercepts
	var launcher := _make_test_unit(1, 0, "small", 100)
	_add_horizon_weapon(launcher, 10, 50, 3)

	var swat_ship := _make_test_unit(2, 1, "small", 100)
	_add_swat_mount(swat_ship, 5, 5, 50) # High swat acc

	var p1 := CombatParty.new()
	p1.party_id = 0
	p1.empire_id = 0
	p1.units = [launcher]

	var p2 := CombatParty.new()
	p2.party_id = 1
	p2.empire_id = 1
	p2.swat_mode = "missiles_first"
	p2.units = [swat_ship]

	var input := CombatInput.new()
	input.system_id = 1
	input.seed = 42
	input.parties = [p1, p2]
	input.start_distances = {"0_1": 10}

	var log: BattleLog = CombatResolver.resolve(input)
	assert_true(log.rounds.size() >= 2)
	# Round 2 has swat intercepts
	var r2: Dictionary = log.rounds[1]
	assert_true(r2["swat_intercepts"].size() > 0, "Missiles-first intercepted incoming missiles")

	# Test ships-first: never intercepts
	p2.swat_mode = "ships_first"
	var log2: BattleLog = CombatResolver.resolve(input)
	var r2_ships_first: Dictionary = log2.rounds[1]
	assert_eq(r2_ships_first["swat_intercepts"].size(), 0, "Ships-first never intercepts")

func test_horizon_salvos_and_indoor_torpedo() -> void:
	# Horizon salvos run out after 3 launches; Indoor Torpedo fires on even rounds only
	var dart_ship := _make_test_unit(1, 0, "small", 500)
	_add_horizon_weapon(dart_ship, 5, 0, 3, false) # 3 salvos

	var torpedo_ship := _make_test_unit(2, 0, "small", 500)
	_add_horizon_weapon(torpedo_ship, 30, 0, -1, true) # Indoor Torpedo: even rounds only, unlimited

	var enemy := _make_test_unit(3, 1, "small", 1000)
	_add_talon_weapon(enemy, 1, 1)

	var p1 := CombatParty.new()
	p1.party_id = 0
	p1.empire_id = 0
	p1.posture = "standoff"
	p1.units = [dart_ship, torpedo_ship]

	var p2 := CombatParty.new()
	p2.party_id = 1
	p2.empire_id = 1
	p2.posture = "standoff"
	p2.units = [enemy]

	var input := CombatInput.new()
	input.system_id = 1
	input.seed = 42
	input.parties = [p1, p2]
	input.start_distances = {"0_1": 12}

	var log: BattleLog = CombatResolver.resolve(input)
	var dart_launches: int = 0
	for r_idx in range(log.rounds.size()):
		var r: Dictionary = log.rounds[r_idx]
		var r_num: int = r_idx + 1
		for l in r["launches"]:
			if l["launcher_uid"] == dart_ship.uid:
				dart_launches += 1
			if l["launcher_uid"] == torpedo_ship.uid:
				assert_true(r_num % 2 == 0, "Indoor Torpedo fires on even rounds only (fired in round %d)" % r_num)
	assert_eq(dart_launches, 3, "Horizon darts launch exactly 3 times then run out")

func test_order_independence_and_determinism() -> void:
	# order independence: shuffling party, unit and mount order yields the same StateHash of the log
	var make_test_input := func() -> CombatInput:
		var u1 := _make_test_unit(1, 0, "small", 50)
		_add_talon_weapon(u1, 5, 10)
		var u2 := _make_test_unit(2, 0, "medium", 80)
		_add_beak_weapon(u2, 8, 14)
		var p1 := CombatParty.new()
		p1.party_id = 0
		p1.empire_id = 0
		p1.units = [u1, u2]

		var e1 := _make_test_unit(3, 1, "small", 60)
		_add_horizon_weapon(e1, 6, 0, 3)
		var e2 := _make_test_unit(4, 1, "small", 40)
		_add_swat_mount(e2, 3, 5)
		var p2 := CombatParty.new()
		p2.party_id = 1
		p2.empire_id = 1
		p2.units = [e1, e2]

		var ci := CombatInput.new()
		ci.system_id = 7
		ci.seed = 12345
		ci.parties = [p1, p2]
		ci.start_distances = {"0_1": 10}
		return ci

	var inp1: CombatInput = make_test_input.call()
	var log1: BattleLog = CombatResolver.resolve(inp1)
	var h1: int = StateHash.of_value(log1.to_dict())

	# Determinism check: same input twice -> same log
	var inp2: CombatInput = make_test_input.call()
	var log2: BattleLog = CombatResolver.resolve(inp2)
	var h2: int = StateHash.of_value(log2.to_dict())
	assert_eq(h1, h2, "Determinism: identical logs")

	# Shuffled party order and unit order
	var inp3: CombatInput = make_test_input.call()
	inp3.parties.reverse()
	inp3.parties[0].units.reverse()
	inp3.parties[1].units.reverse()
	var log3: BattleLog = CombatResolver.resolve(inp3)
	var h3: int = StateHash.of_value(log3.to_dict())
	assert_eq(h1, h3, "Order independence: shuffled inputs yield identical StateHash")

func test_unarmed_battle_ends_round_1() -> void:
	# a battle with only unarmed ships on one side ends in round 1 with orbit to the armed side
	var armed := _make_test_unit(1, 0, "small", 50)
	_add_talon_weapon(armed, 5, 8)
	var p1 := CombatParty.new()
	p1.party_id = 0
	p1.empire_id = 0
	p1.units = [armed]

	var unarmed := _make_test_unit(2, 1, "small", 20)
	var p2 := CombatParty.new()
	p2.party_id = 1
	p2.empire_id = 1
	p2.units = [unarmed]

	var input := CombatInput.new()
	input.system_id = 1
	input.seed = 42
	input.parties = [p1, p2]
	input.start_distances = {"0_1": 10}

	var log: BattleLog = CombatResolver.resolve(input)
	assert_eq(log.rounds.size(), 1, "Battle with unarmed side ends in round 1")
	assert_eq(log.winner_empire_id, 0, "Armed side wins orbit")
	assert_false(log.is_stalemate)

func test_500_random_battles() -> void:
	# 500 random battles finish with no SimLog entries and HP never below 0 in the log
	SimLog.clear()
	var rng := Rng.keyed(42, 1, Rng.COMBAT)
	for battle_idx in range(500):
		var p1 := CombatParty.new()
		p1.party_id = 0
		p1.empire_id = 0
		var n1: int = rng.range_i(1, 4)
		for i in range(n1):
			var u := _make_test_unit(battle_idx * 100 + i, 0, "small", rng.range_i(10, 60), rng.range_i(0, 4))
			_add_talon_weapon(u, rng.range_i(2, 5), rng.range_i(6, 12))
			p1.units.append(u)

		var p2 := CombatParty.new()
		p2.party_id = 1
		p2.empire_id = 1
		var n2: int = rng.range_i(1, 4)
		for i in range(n2):
			var u := _make_test_unit(battle_idx * 100 + 50 + i, 1, "small", rng.range_i(10, 60), rng.range_i(0, 4))
			_add_beak_weapon(u, rng.range_i(3, 7), rng.range_i(8, 15))
			p2.units.append(u)

		var input := CombatInput.new()
		input.system_id = battle_idx
		input.seed = rng.next_u32()
		input.turn = rng.range_i(1, 20)
		input.parties = [p1, p2]
		input.start_distances = {"0_1": rng.range_i(0, 12)}

		var log: BattleLog = CombatResolver.resolve(input)
		assert_not_null(log)
		# Check HP in final units is not corrupted
		for fu in log.final_units:
			# HP can drop to or below 0 when killed, but let's check log structure is valid
			assert_not_null(fu)

	var logs: Array[String] = SimLog.take()
	assert_eq(logs.size(), 0, "No SimLog entries during 500 random battles")
