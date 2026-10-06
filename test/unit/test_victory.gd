extends GutTest

var _db: ContentDB

func before_all() -> void:
	_db = ContentDB.load_from("res://data")

func _create_game(seed_str: String = "VICTORY_TEST") -> GameState:
	var s: GameSettings = (GameSettings as Variant).call(&"new")
	s.preset = "evening_standard"
	s.seed_string = seed_str
	s.seed = Rng.seed_from_string(seed_str)
	s.player_race = "pheasants"
	s.seat_swans = true
	var game: SimGame = SimGame.create(s, _db)
	return game.gs

func _spawn_fleet_with_power(gs: GameState, owner: int, target_power: int) -> Fleet:
	# Spawns a fleet for owner with the given power
	# If target_power is a perfect square, 1 ship with hp = sqrt(target_power)^2
	var f: Fleet = Fleet.new()
	f.id = gs.alloc_id("fleet")
	f.owner = owner
	var s: Ship = Ship.new()
	s.id = gs.alloc_id("ship")
	s.owner = owner
	# Power = sum_term * sum_term where sum_term = isqrt(1 * hp)
	# So if hp = target_power, power = isqrt(hp)^2
	s.hp = target_power
	gs.ships[s.id] = s
	f.ship_ids.append(s.id)
	gs.fleets[f.id] = f
	return f

func _set_empire_exact_power(gs: GameState, owner: int, exact_power: int) -> void:
	# Clear existing fleets for owner
	var to_remove: Array[int] = []
	for fid in gs.fleets.keys():
		if gs.fleets[fid].owner == owner:
			to_remove.append(fid)
	for fid in to_remove:
		for sid in gs.fleets[fid].ship_ids:
			gs.ships.erase(sid)
		gs.fleets.erase(fid)

	# Decompose exact_power into squares
	var rem: int = exact_power
	while rem > 0:
		var root: int = IntMath.isqrt(rem)
		var sq: int = root * root
		_spawn_fleet_with_power(gs, owner, sq)
		rem -= sq

func test_capitulation_boundary_and_refuse_pairs() -> void:
	var gs: GameState = _create_game("CAP_TEST1")
	# Empire 1 (AI) at war with Empire 2 (AI, swans)
	Wars.set_war(gs, 1, 2, true)

	# Set Empire 2 power to 100
	_set_empire_exact_power(gs, 2, 100)
	assert_eq(Power.empire_military_power(_db, gs, 2), 100, "Enemy power is 100")

	# Set Empire 1 colonies to exactly 3 non-outpost colonies
	var e1_cols: Array[Colony] = []
	for cid in gs.colonies.keys():
		var c: Colony = gs.colonies[cid]
		if c.owner == 1 and not c.is_outpost:
			e1_cols.append(c)

	while e1_cols.size() < 3:
		var c_new: Colony = Colony.new()
		c_new.id = gs.alloc_id("colony")
		c_new.owner = 1
		c_new.farmers = 1
		gs.colonies[c_new.id] = c_new
		e1_cols.append(c_new)

	while e1_cols.size() > 3:
		var c_del: Colony = e1_cols.pop_back()
		gs.colonies.erase(c_del.id)

	# 1. Capital lost (-1), 3 colonies, 24% power (< 25%) -> ALLOW
	gs.empires[1].capital_colony_id = -1
	_set_empire_exact_power(gs, 1, 24)
	assert_eq(Power.empire_military_power(_db, gs, 1), 24, "Empire 1 power is 24")
	var cand: int = Capitulation.check_candidate(_db, gs, 1)
	assert_eq(cand, 2, "ALLOW: Surrender offered at 24% power with lost capital and 3 colonies")

	# 2. At 25% power -> REFUSE boundary
	_set_empire_exact_power(gs, 1, 25)
	assert_eq(Power.empire_military_power(_db, gs, 1), 25, "Empire 1 power is 25")
	assert_eq(Capitulation.check_candidate(_db, gs, 1), -1, "REFUSE: Surrender refused at 25% power")

	# 3. At 24% power but 4 colonies -> REFUSE boundary
	_set_empire_exact_power(gs, 1, 24)
	var c4: Colony = Colony.new()
	c4.id = gs.alloc_id("colony")
	c4.owner = 1
	c4.farmers = 1
	gs.colonies[c4.id] = c4
	assert_eq(Capitulation.check_candidate(_db, gs, 1), -1, "REFUSE: Surrender refused with 4 colonies")
	gs.colonies.erase(c4.id)

	# 4. At 24% power and 3 colonies but capital NOT lost -> REFUSE
	gs.empires[1].capital_colony_id = e1_cols[0].id
	assert_eq(Capitulation.check_candidate(_db, gs, 1), -1, "REFUSE: Surrender refused when capital not lost")

func test_floor_enemy_uses_35_pct() -> void:
	var gs: GameState = _create_game("FLOOR_TEST")
	# Set Empire 2 race to chickens (personality: floor)
	gs.empires[2].race = "chickens"
	Wars.set_war(gs, 1, 2, true)

	_set_empire_exact_power(gs, 2, 100)

	# Set Empire 1 to lost capital, 3 colonies
	gs.empires[1].capital_colony_id = -1
	var e1_cols: Array[Colony] = []
	for cid in gs.colonies.keys():
		var c: Colony = gs.colonies[cid]
		if c.owner == 1 and not c.is_outpost:
			e1_cols.append(c)
	while e1_cols.size() < 3:
		var c_new: Colony = Colony.new()
		c_new.id = gs.alloc_id("colony")
		c_new.owner = 1
		c_new.farmers = 1
		gs.colonies[c_new.id] = c_new
		e1_cols.append(c_new)
	while e1_cols.size() > 3:
		var c_del: Colony = e1_cols.pop_back()
		gs.colonies.erase(c_del.id)

	# At 34% power -> ALLOW vs Floor (< 35%)
	_set_empire_exact_power(gs, 1, 34)
	assert_eq(Power.empire_military_power(_db, gs, 1), 34, "Empire 1 power is 34")
	assert_eq(Capitulation.check_candidate(_db, gs, 1), 2, "ALLOW: Surrender offered to Floor enemy at 34% power")

	# At 35% power -> REFUSE vs Floor
	_set_empire_exact_power(gs, 1, 35)
	assert_eq(Power.empire_military_power(_db, gs, 1), 35, "Empire 1 power is 35")
	assert_eq(Capitulation.check_candidate(_db, gs, 1), -1, "REFUSE: Surrender refused to Floor enemy at 35% power")

func test_conquest_when_last_rival_capitulates() -> void:
	var gs: GameState = _create_game("CONQUEST_TEST")
	# Eliminate all empires except 0 and 1
	for eid in range(2, gs.empires.size()):
		gs.empires[eid].eliminated_turn = 1
		for cid in gs.colonies.keys():
			if gs.colonies[cid].owner == eid:
				gs.colonies.erase(cid)

	assert_false(gs.game_over, "Game not over yet")

	# Capitulate empire 1 to empire 0
	Capitulation.transfer_and_eliminate(_db, gs, 1, 0)
	assert_true(gs.empires[1].eliminated_turn >= 0, "Empire 1 eliminated")

	# Check victory
	Victory.check_victory(_db, gs)
	assert_true(gs.game_over, "Game is over")
	assert_eq(gs.winner, 0, "Empire 0 is winner")
	assert_eq(gs.victory_type, "conquest", "Victory type is conquest")

func test_called_game_picks_highest_score() -> void:
	var gs: GameState = _create_game("CALLED_GAME_TEST")
	gs.settings.turn_cap = 50
	gs.turn = 50

	# Give empire 1 high pop and tech so its score is clearly highest
	gs.empires[1].tech.grant("star_charts")
	gs.empires[1].tech.grant("fold_drive")
	gs.empires[1].tech.grant("closed_season")
	for cid in gs.colonies.keys():
		var c: Colony = gs.colonies[cid]
		if c.owner == 1:
			c.farmers = 10
			c.workers = 10

	var s0: int = Score.of(_db, gs, 0)
	var s1: int = Score.of(_db, gs, 1)
	assert_true(s1 > s0, "Empire 1 score (%d) > Empire 0 score (%d)" % [s1, s0])

	Victory.check_victory(_db, gs)
	assert_true(gs.game_over, "Game is over at turn_cap")
	assert_eq(gs.winner, 1, "Empire 1 won Called Game with highest score")
	assert_eq(gs.victory_type, "called_game", "Victory type is called_game")

func test_one_more_turn_disables_victory_checks() -> void:
	var gs: GameState = _create_game("ONE_MORE_TURN_TEST")
	gs.settings.turn_cap = 50
	gs.turn = 50
	gs.one_more_turn = true

	Victory.check_victory(_db, gs)
	assert_false(gs.game_over, "One more turn prevents game_over check")
	assert_eq(gs.victory_type, "", "No victory type set")

func test_player_never_auto_capitulates() -> void:
	var gs: GameState = _create_game("PLAYER_NO_CAP_TEST")
	# Put player (empire 0) in capitulation conditions
	Wars.set_war(gs, 0, 1, true)
	gs.empires[0].capital_colony_id = -1
	_set_empire_exact_power(gs, 1, 100)
	_set_empire_exact_power(gs, 0, 5) # 5% power

	# Verify check_candidate returns -1 for player
	var cand: int = Capitulation.check_candidate(_db, gs, 0)
	assert_eq(cand, -1, "Player never auto-capitulates")
