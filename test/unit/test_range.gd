extends GutTest

func test_range_table_fixture() -> void:
	var file := FileAccess.open("res://test/fixtures/range_table.json", FileAccess.READ)
	assert_not_null(file, "range_table.json should exist")
	var text: String = file.get_as_text()
	var json: Variant = JSON.parse_string(text)
	assert_true(json is Dictionary, "json is dictionary")
	var rows: Array = json["rows"]
	assert_eq(rows.size(), 7488, "7488 fixture rows")
	for row in rows:
		var d: int = int(row[0])
		var p_a: int = int(row[1])
		var s_a: int = int(row[2])
		var p_b: int = int(row[3])
		var s_b: int = int(row[4])
		var expected: int = int(row[5])
		var actual: int = RangeTrack.step(d, p_a, s_a, p_b, s_b)
		if actual != expected:
			assert_eq(actual, expected, "Mismatch at d=%d p_a=%d s_a=%d p_b=%d s_b=%d" % [d, p_a, s_a, p_b, s_b])
			return
	pass_test("All 7,488 rows match RangeTrack.step")

func test_closer_reaches_property() -> void:
	# property: for P in {0,1,5,12}, s in 0..5 (fleets >= 1), D0 in 0..12,
	# whenever D > P_c the next D is strictly lower and P_c is reached within D0 - P_c rounds
	var postures: Array[int] = [0, 1, 5, 12]
	for p_a in postures:
		for p_b in postures:
			var p_c: int = mini(p_a, p_b)
			for s_a in range(1, 6):
				for s_b in range(1, 6):
					for d0 in range(0, 13):
						var d: int = d0
						var rounds: int = 0
						while d > p_c and rounds < 20:
							var next_d: int = RangeTrack.step(d, p_a, s_a, p_b, s_b)
							assert_true(next_d < d, "D must strictly decrease when D > P_c (d=%d -> next_d=%d)" % [d, next_d])
							d = next_d
							rounds += 1
						if d0 > p_c:
							assert_true(rounds <= (d0 - p_c), "P_c reached within D0 - P_c rounds (d0=%d, p_c=%d, took=%d)" % [d0, p_c, rounds])
							assert_true(d <= p_c, "Reached P_c")

func test_project_reproduces_gdd_table() -> void:
	var expected_table: Dictionary = {
		1: [[3, 7], [3, 7], [3, 7], [3, 7], [3, 7]],
		2: [[2, 4], [3, 7], [3, 7], [3, 7], [3, 7]],
		3: [[1, 3], [2, 4], [3, 7], [3, 7], [3, 7]],
		4: [[1, 2], [1, 3], [2, 4], [2, 6], [2, 6]],
	}
	for s_c in range(1, 5):
		for s_o in range(0, 5):
			var res: Dictionary = RangeTrack.project(10, 0, s_c, s_o)
			var exp: Array = expected_table[s_c][s_o]
			assert_eq(res["talon_round"], exp[0], "Talon round mismatch for s_c=%d, s_o=%d" % [s_c, s_o])
			assert_eq(res["beak_round"], exp[1], "Beak round mismatch for s_c=%d, s_o=%d" % [s_c, s_o])

func test_refuse_regression_equal_speed_close_vs_standoff() -> void:
	# REFUSE-style regression: equal-speed Close vs Stand Off from 10 does not stay at 10 (the old freeze)
	var next_d: int = RangeTrack.step(10, 0, 2, 12, 2)
	assert_ne(next_d, 10, "Equal-speed Close vs Stand Off must not freeze at 10")
	assert_eq(next_d, 9, "Advances by 1")

func test_allow_talon_range_hold() -> void:
	# ALLOW: two Talon-range parties at 5 hold 5
	var next_d: int = RangeTrack.step(5, 5, 2, 5, 2)
	assert_eq(next_d, 5, "Two Talon-range parties at 5 hold 5")

func test_preferred() -> void:
	assert_eq(RangeTrack.preferred("close", "beak", true), 0)
	assert_eq(RangeTrack.preferred("talon", "beak", true), 5)
	assert_eq(RangeTrack.preferred("standoff", "beak", true), 12)
	assert_eq(RangeTrack.preferred("retreat", "beak", true), 12)
	assert_eq(RangeTrack.preferred("auto", "beak", true), 1)
	assert_eq(RangeTrack.preferred("auto", "talon", true), 5)
	assert_eq(RangeTrack.preferred("auto", "horizon", true), 12)
	assert_eq(RangeTrack.preferred("auto", "horizon", false), 5)
