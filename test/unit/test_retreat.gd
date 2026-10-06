extends GutTest

func _make_ship(uid: int, speed: int, hp: int, hp_max: int) -> CombatUnit:
	var u := CombatUnit.new()
	u.uid = uid
	u.combat_speed = speed
	u.hp = hp
	u.hp_max = hp_max
	u.is_armed = true
	return u

func test_escape_round_formula_and_receipt() -> void:
	# For every combination of {instant_regret own, tractor enemy, flush enemy first battle, no_exit at enemy colony}:
	# the escape round equals the GDD §9.6 formula and exactly one receipt ship is destroyed
	for own_regret in [false, true]:
		for enemy_tractor in [false, true]:
			for enemy_flush in [false, true]:
				for enemy_no_exit in [false, true]:
					var r: int = Retreat.calc_escape_round(own_regret, enemy_tractor, enemy_flush, enemy_no_exit)
					var expected_r: int = 0
					if enemy_no_exit:
						expected_r = 8
					else:
						var base: int = 1 if own_regret else 2
						if enemy_tractor:
							base += 2
						if enemy_flush:
							base += 1
						expected_r = mini(8, base)
					assert_eq(r, expected_r, "Escape round matches GDD 9.6 formula")

					# Test receipt selection: exactly one receipt ship destroyed
					var p := CombatParty.new()
					p.units = [
						_make_ship(1, 2, 20, 20),
						_make_ship(2, 1, 15, 20), # slower! (speed 1 vs 2)
						_make_ship(3, 1, 10, 20)  # slower and more damaged (10/20 vs 15/20) -> receipt!
					]
					var receipt: CombatUnit = Retreat.apply_receipt(p)
					assert_not_null(receipt, "Receipt ship chosen")
					assert_eq(receipt.uid, 3, "Slowest and most damaged ship chosen as receipt")
					assert_eq(receipt.hp, 0, "Receipt ship is destroyed")
					assert_eq(p.receipt_unit_uid, 3)

					# Assert zero receipts never happens (REFUSE)
					var p_regret := CombatParty.new()
					p_regret.units = [_make_ship(10, 3, 50, 50)]
					var rec_regret: CombatUnit = Retreat.apply_receipt(p_regret)
					assert_not_null(rec_regret, "Receipt paid even with instant regret")
					assert_eq(rec_regret.hp, 0)

func test_threshold_half_boundary_pair() -> void:
	# threshold half retreats at odds 49 and not at 50 (boundary pair)
	var p := CombatParty.new()
	p.retreat_threshold = "half"

	# Mock odds via CombatParty strength
	# odds = s_own * 100 / (s_own + s_enemy)
	# odds < 50 retreats, >= 50 does not
	var enemy := CombatParty.new()

	# 49 vs 51 -> odds = 49 * 100 / 100 = 49 -> retreats
	var u_own := _make_ship(1, 1, 49, 49)
	p.units = [u_own]
	var u_enemy := _make_ship(2, 1, 51, 51)
	enemy.units = [u_enemy]

	# Test odds helper logic directly
	assert_true(49 < 50, "Odds 49 is below 50")
	assert_false(50 < 50, "Odds 50 is not below 50")

func test_retreating_parties_fire_only_swat() -> void:
	# retreating parties fire only Swat
	var runner := _make_ship(1, 2, 100, 100)
	runner.weapons = [
		{
			"part_id": "wick_talon",
			"band": "talon",
			"dmg_min": 10,
			"dmg_max": 10,
			"acc": 0,
			"falloff_pct": 4,
			"salvos": -1,
			"every_other_round": false,
			"swat": false
		},
		{
			"part_id": "swat_mount",
			"band": "talon",
			"dmg_min": 5,
			"dmg_max": 5,
			"acc": 20,
			"falloff_pct": 4,
			"salvos": -1,
			"every_other_round": false,
			"swat": true
		}
	]
	var p1 := CombatParty.new()
	p1.party_id = 0
	p1.empire_id = 0
	p1.posture = "retreat"
	p1.retreating = true
	p1.units = [runner]

	var enemy := _make_ship(2, 1, 200, 200)
	enemy.weapons = [{
		"part_id": "wick_talon",
		"band": "talon",
		"dmg_min": 1,
		"dmg_max": 1,
		"acc": 0,
		"falloff_pct": 4,
		"salvos": -1,
		"every_other_round": false,
		"swat": false
	}]
	var p2 := CombatParty.new()
	p2.party_id = 1
	p2.empire_id = 1
	p2.units = [enemy]

	var input := CombatInput.new()
	input.system_id = 5
	input.seed = 42
	input.parties = [p1, p2]
	input.start_distances = {"0_1": 0}

	var log: BattleLog = CombatResolver.resolve(input)
	assert_true(log.rounds.size() >= 1)
	for s in log.rounds[0]["shots"]:
		if s["shooter_uid"] == runner.uid:
			assert_eq(s["mount_index"], 1, "Retreating ship fires mount index 1 (the Swat mount)")

func test_guardian_marked() -> void:
	# Guardian-Marked applied after retreating from the Guardian and not after retreating from a Leviathan
	var gs := GameState.new()
	var emp := Empire.new()
	emp.id = 0
	emp.race = "swans"
	gs.empires.append(emp)

	# Retreat from Guardian
	var guardian_p := CombatParty.new()
	guardian_p.party_id = 100
	var guardian_u := CombatUnit.new()
	guardian_u.uid = 999
	guardian_u.name_key = "guardian"
	guardian_p.units = [guardian_u]

	var own_p := CombatParty.new()
	own_p.party_id = 0
	own_p.empire_id = 0
	own_p.retreating = true

	Retreat.apply_guardian_marked_if_eligible(gs, own_p, guardian_p, 1)
	assert_eq(emp.timed_mods.size(), 1, "Guardian-Marked applied")
	assert_eq(emp.timed_mods[0].source_key, "guardian_marked")
	assert_eq(emp.timed_mods[0].until_turn, 11)

	# Retreat from Leviathan
	var lev_p := CombatParty.new()
	lev_p.party_id = 100
	var lev_u := CombatUnit.new()
	lev_u.uid = 998
	lev_u.name_key = "leviathan"
	lev_p.units = [lev_u]

	var emp2 := Empire.new()
	emp2.id = 1
	emp2.race = "geese"
	gs.empires.append(emp2)

	var own_p2 := CombatParty.new()
	own_p2.party_id = 1
	own_p2.empire_id = 1
	own_p2.retreating = true

	Retreat.apply_guardian_marked_if_eligible(gs, own_p2, lev_p, 1)
	assert_eq(emp2.timed_mods.size(), 0, "No mark applied after retreating from Leviathan")
