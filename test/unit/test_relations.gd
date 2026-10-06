extends GutTest

var _db: ContentDB

func before_all() -> void:
	_db = ContentDB.load_from("res://data")

func _create_game(seed_str: String = "REL_TEST") -> GameState:
	var s: GameSettings = (GameSettings as Variant).call(&"new")
	s.preset = "evening_standard"
	s.seed_string = seed_str
	s.seed = Rng.seed_from_string(seed_str)
	s.player_race = "pheasants"
	s.seat_swans = true
	var game: SimGame = SimGame.create(s, _db)
	return game.gs

func test_relations_base_from_traits() -> void:
	var gs: GameState = _create_game("REL_TEST")
	# Make sure empire 0 has no relations traits, empire 1 (ducks) has charismatic
	# In data/races.json, ducks has "charismatic" (+20)
	var ducks_id: int = -1
	for e in gs.empires:
		if e.race == "ducks":
			ducks_id = e.id
			break
	assert_true(ducks_id >= 0, "Ducks empire found")

	# Relations.value(db, gs, 0, ducks_id) should include charismatic +20
	var res: ModResult = Relations.value(_db, gs, 0, ducks_id)
	var found_charismatic: bool = false
	for line in res.lines:
		if line.get("source_key") == "trait.charismatic.name" and int(line.get("value")) == 20:
			found_charismatic = true
			break
	assert_true(found_charismatic, "Charismatic +20 seen in relations lines")
	assert_true(res.value >= 20, "Charismatic adds +20 to base relations")

func test_relations_border_tension_and_cap() -> void:
	var gs: GameState = GameState.new()
	var e0: Empire = Empire.new()
	e0.id = 0
	e0.race = "pheasants"
	var e1: Empire = Empire.new()
	e1.id = 1
	e1.race = "swans"
	gs.empires.append(e0)
	gs.empires.append(e1)

	# System 0 at (0, 0), System 1 at (40, 0) -> dist = 40 dpc (within 60)
	var s0: StarSystem = StarSystem.new()
	s0.id = 0
	s0.x = 0
	s0.y = 0
	var s1: StarSystem = StarSystem.new()
	s1.id = 1
	s1.x = 40
	s1.y = 0
	gs.systems.append(s0)
	gs.systems.append(s1)

	var p0: Planet = Planet.new()
	p0.id = 0
	p0.system_id = 0
	var p1: Planet = Planet.new()
	p1.id = 1
	p1.system_id = 1
	gs.planets.append(p0)
	gs.planets.append(p1)

	var c0: Colony = Colony.new()
	c0.id = 0
	c0.owner = 0
	c0.planet_id = 0
	var c1: Colony = Colony.new()
	c1.id = 1
	c1.owner = 1
	c1.planet_id = 1
	gs.colonies[0] = c0
	gs.colonies[1] = c1

	# 1 pair within 60 dpc -> tension = -2
	var res1: ModResult = Relations.value(_db, gs, 0, 1)
	assert_eq(res1.value, -2, "1 close pair gives -2 border tension")

	# Add 14 more pairs by adding colonies in system 0 and 1
	for i in range(2, 16):
		var pi: Planet = Planet.new()
		pi.id = i
		pi.system_id = 1
		gs.planets.append(pi)
		var ci: Colony = Colony.new()
		ci.id = i
		ci.owner = 1
		ci.planet_id = i
		gs.colonies[i] = ci

	# 15 pairs -> 15 * -2 = -30, capped at -20
	var res_capped: ModResult = Relations.value(_db, gs, 0, 1)
	assert_eq(res_capped.value, -20, "Border tension capped at -20")

func test_relations_war_penalty() -> void:
	var gs: GameState = GameState.new()
	var e0: Empire = Empire.new()
	e0.id = 0
	e0.race = "pheasants"
	var e1: Empire = Empire.new()
	e1.id = 1
	e1.race = "pheasants"
	gs.empires.append(e0)
	gs.empires.append(e1)

	assert_eq(Relations.value(_db, gs, 0, 1).value, 0, "Peace relations zero")
	Wars.set_war(gs, 0, 1, true)
	assert_eq(Relations.value(_db, gs, 0, 1).value, -30, "War gives -30 relation penalty")

func test_declare_war_refuses_truce_and_allows_after() -> void:
	var gs: GameState = _create_game("TRUCE_TEST")
	gs.turn = 10
	var knw: Knowledge = gs.knowledge[0]
	knw.met[1] = 5

	var cmd: CmdDeclareWar = CmdDeclareWar.new()
	cmd.empire_id = 0
	cmd.target_empire = 1

	# Set truce ending at turn 25
	Wars.set_truce(gs, 0, 1, 15) # turn 10 + 15 = 25
	assert_eq(cmd.validate(gs, _db), "refuse.truce", "Declare war refused during truce (REFUSE)")

	# Advance turn past truce
	gs.turn = 26
	assert_eq(cmd.validate(gs, _db), "", "Declare war allowed after truce expires (ALLOW)")

func test_peace_accepted_at_ratio_69_and_declined_at_70() -> void:
	var gs: GameState = _create_game("PEACE_TEST")
	gs.turn = 10
	Wars.set_war(gs, 0, 1, true)

	var view: AiView = AiView.build(gs, _db, 1) # Empire 1 (non-librarian in default fixture: swans/ducks/geese)
	# At ratio 69% (< 70% peace_ratio_pct), AI wants peace
	assert_true(AiWar.wants_peace(view, 0, 69), "Peace accepted at ratio 69%")
	# At ratio 70% (>= 70%), AI declines peace
	assert_false(AiWar.wants_peace(view, 0, 70), "Peace declined at ratio 70%")

func test_librarian_refuses_peace_for_20_turns_when_attacked() -> void:
	var gs: GameState = GameState.new()
	var e0: Empire = Empire.new()
	e0.id = 0
	e0.race = "pheasants"
	var e1: Empire = Empire.new()
	e1.id = 1
	e1.race = "owls" # Librarian personality
	gs.empires.append(e0)
	gs.empires.append(e1)

	gs.turn = 15
	Wars.set_war(gs, 0, 1, true)
	var key: String = Wars._pair_key(0, 1)
	gs.war_started_turn[key] = 10
	gs.war_declarer[key] = 0 # 0 attacked 1

	var view: AiView = AiView.build(gs, _db, 1)
	# Librarian was attacked at turn 10, current turn 15 (< 10 + 20), refuses peace even with ratio 20
	assert_false(AiWar.wants_peace(view, 0, 20), "Librarian refuses peace for 20 turns after being attacked")

	# At turn 30 (turn - 10 >= 20), Librarian can accept if ratio is low
	gs.turn = 30
	view = AiView.build(gs, _db, 1)
	assert_true(AiWar.wants_peace(view, 0, 20), "Librarian accepts peace after 20 turns")
