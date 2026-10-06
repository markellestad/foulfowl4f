extends GutTest

var _db: ContentDB

func before_all() -> void:
	_db = ContentDB.load_from("res://data")

func test_evening_standard_player_pheasants_seat_swans() -> void:
	var s: GameSettings = GameSettings.new()
	s.preset = "evening_standard"
	s.player_race = "pheasants"
	s.seat_swans = true
	var seats: Array[String] = Seating.resolve(s, _db)
	assert_eq(seats.size(), 4)
	assert_eq(seats[0], "pheasants")
	assert_eq(seats[1], "swans")
	assert_eq(seats[2], "geese")
	assert_eq(seats[3], "ducks")

func test_evening_standard_player_swans_no_repeat() -> void:
	var s: GameSettings = GameSettings.new()
	s.preset = "evening_standard"
	s.player_race = "swans"
	s.seat_swans = true
	var seats: Array[String] = Seating.resolve(s, _db)
	assert_eq(seats.size(), 4)
	assert_eq(seats[0], "swans")
	# Assert swans not repeated and all 4 distinct
	var distinct: Dictionary = {}
	for r in seats:
		distinct[r] = true
	assert_eq(distinct.size(), 4, "All 4 seats are distinct")
	assert_false(seats.slice(1).has("swans"), "Swans not repeated in AI seats")

func test_seat_swans_false_no_swans_unless_player() -> void:
	var s: GameSettings = GameSettings.new()
	s.preset = "tiny"
	s.player_race = "pheasants"
	s.seat_swans = false
	var seats: Array[String] = Seating.resolve(s, _db)
	assert_false(seats.has("swans"), "No swans seated when seat_swans is false")

	var s2: GameSettings = GameSettings.new()
	s2.preset = "tiny"
	s2.player_race = "swans"
	s2.seat_swans = false
	var seats2: Array[String] = Seating.resolve(s2, _db)
	assert_eq(seats2[0], "swans", "Swans allowed when player picked them")
	assert_false(seats2.slice(1).has("swans"), "Swans not added to AI seats when seat_swans is false")

func test_tiny_preset_3_seats() -> void:
	var s: GameSettings = GameSettings.new()
	s.preset = "tiny"
	s.player_race = "ducks"
	s.seat_swans = true
	var seats: Array[String] = Seating.resolve(s, _db)
	assert_eq(seats.size(), 3, "Tiny preset has 3 seats")
	var distinct: Dictionary = {}
	for r in seats:
		distinct[r] = true
	assert_eq(distinct.size(), 3, "All 3 seats distinct")

func test_all_seats_playable() -> void:
	var races_table: Dictionary = _db.table("races")
	var rows: Dictionary = races_table.get("rows", {})
	for preset in ["tiny", "evening_standard"]:
		for p_race in ["swans", "pheasants", "ducks", "geese"]:
			for seat_sw in [true, false]:
				var s: GameSettings = GameSettings.new()
				s.preset = preset
				s.player_race = p_race
				s.seat_swans = seat_sw
				var seats: Array[String] = Seating.resolve(s, _db)
				for r in seats:
					assert_true(bool(rows[r].get("playable", false)), "Seat %s is playable" % r)
