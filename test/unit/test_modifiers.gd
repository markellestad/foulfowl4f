extends GutTest

var _db: ContentDB

func before_all() -> void:
	_db = ContentDB.load_from("res://data")

func test_precedence_hand_made_ctx() -> void:
	# base 2, floor 3, add +1, cap 3, pct -50 -> 1
	var gs: GameState = GameState.new()
	var ctx: Dictionary = {
		"empire_id": -1,
		"effects": [
			{ "stat": "custom_stat", "op": "floor", "value": 3, "source_key": "src_floor" },
			{ "stat": "custom_stat", "op": "add", "value": 1, "source_key": "src_add" },
			{ "stat": "custom_stat", "op": "cap", "value": 3, "source_key": "src_cap" },
			{ "stat": "custom_stat", "op": "pct", "value": -50, "source_key": "src_pct" }
		]
	}
	var res: ModResult = Modifiers.eval(_db, gs, "custom_stat", 2, ctx)
	assert_eq(res.value, 1, "Precedence yields 1: (max(2,3) + 1 = 4 -> min(4,3) = 3 -> 3 * 50% = 1)")
	assert_eq(res.lines.size(), 5, "Base + 4 effects = 5 lines")
	assert_eq(res.lines[0]["source_key"], "base")
	assert_eq(res.lines[0]["value"], 2)

func test_filters_band_filtered() -> void:
	var gs: GameState = GameState.new()
	var eff: Dictionary = {
		"stat": "damage",
		"op": "add",
		"value": 5,
		"filter": { "band": "talon" },
		"source_key": "talon_bonus"
	}
	var ctx_beak: Dictionary = { "band": "beak", "effects": [eff] }
	var res_beak: ModResult = Modifiers.eval(_db, gs, "damage", 10, ctx_beak)
	assert_eq(res_beak.value, 10, "Talon-filtered effect does not apply to beak")
	assert_eq(res_beak.lines.size(), 1, "Only base line present")

	var ctx_talon: Dictionary = { "band": "talon", "effects": [eff] }
	var res_talon: ModResult = Modifiers.eval(_db, gs, "damage", 10, ctx_talon)
	assert_eq(res_talon.value, 15, "Talon-filtered effect applies to talon")
	assert_eq(res_talon.lines.size(), 2, "Base + talon bonus lines present")

func test_min_clamp_industry_per_worker() -> void:
	var gs: GameState = GameState.new()
	var emp: Empire = Empire.new()
	emp.id = 0
	emp.race = "pheasants"
	emp.traits = ["poor_industry"]
	gs.empires.append(emp)

	var ctx: Dictionary = { "empire_id": 0 }
	# Ultra poor base for industry_per_worker is 1
	var res: ModResult = Modifiers.eval(_db, gs, "industry_per_worker", 1, ctx)
	assert_eq(res.value, 1, "industry_per_worker never drops below 1 even with poor_industry (-1)")
	assert_eq(res.lines.size(), 2)
	assert_eq(res.lines[1]["source_key"], "poor_industry")
	assert_eq(res.lines[1]["value"], -1)

func test_lines_sum_before_rounding() -> void:
	var gs: GameState = GameState.new()
	var ctx: Dictionary = {
		"effects": [
			{ "stat": "pp", "op": "add", "value": 3, "source_key": "add_a" },
			{ "stat": "pp", "op": "add", "value": 5, "source_key": "add_b" }
		]
	}
	var res: ModResult = Modifiers.eval(_db, gs, "pp", 2, ctx)
	assert_eq(res.value, 10)
	var sum_lines: int = 0
	for line in res.lines:
		sum_lines += int(line["value"])
	assert_eq(sum_lines, res.value, "Every line sums to the value before rounding")

func test_strike_and_gravity_modifiers() -> void:
	var gs: GameState = GameState.new()
	var emp: Empire = Empire.new()
	emp.id = 0
	emp.race = "pheasants"
	emp.traits = []
	emp.strike_next_turn = true
	gs.empires.append(emp)

	var col: Colony = Colony.new()
	col.id = 0
	col.owner = 0
	col.species = "pheasants"
	col.planet_id = 0
	gs.colonies[0] = col

	var planet: Planet = Planet.new()
	planet.id = 0
	planet.gravity = "heavy"
	gs.planets.append(planet)

	var ctx: Dictionary = { "empire_id": 0, "colony_id": 0 }
	# Normal pheasant on heavy world gets -25% gravity penalty, plus strike -25% industry
	var ind_res: ModResult = Modifiers.eval(_db, gs, "industry", 100, ctx)
	# 100 * (100 - 25 - 25)% = 50
	assert_eq(ind_res.value, 50, "Industry has -25% strike and -25% gravity")

	# If colony builds gravity_manners, gravity penalty disappears
	col.buildings.append("gravity_manners")
	var ind_res_g: ModResult = Modifiers.eval(_db, gs, "industry", 100, ctx)
	# 100 * (100 - 25)% = 75
	assert_eq(ind_res_g.value, 75, "gravity_manners removes gravity penalty")
