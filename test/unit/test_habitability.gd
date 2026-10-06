extends GutTest

var _db: ContentDB

func before_all() -> void:
	_db = ContentDB.load_from("res://data")

func test_terran_base() -> void:
	var empty_traits: Array[String] = []
	var empty_flags: Array[String] = []
	var pop: int = Habitability.pop_per_size(_db, empty_traits, "terran", empty_flags)
	assert_eq(pop, 4, "Terran base pop_per_size is 4")

func test_aquatic() -> void:
	var traits: Array[String] = ["aquatic"]
	var flags: Array[String] = []
	assert_eq(Habitability.pop_per_size(_db, traits, "ocean", flags), 5, "Aquatic on ocean = 5")
	assert_eq(Habitability.pop_per_size(_db, traits, "desert", flags), 2, "Aquatic on desert = 2")

func test_any_puddle_allow_and_refuse() -> void:
	var traits: Array[String] = ["any_puddle"]
	var flags: Array[String] = []
	assert_eq(Habitability.pop_per_size(_db, traits, "desert", flags), 3, "any_puddle on desert = 3 (ALLOW floor)")
	assert_eq(Habitability.pop_per_size(_db, traits, "barren", flags), 0, "any_puddle on barren without dome = 0 (REFUSE hostile)")

func test_hostile_with_flag() -> void:
	var traits: Array[String] = []
	var flags_with_dome: Array[String] = ["dome_perches_1"]
	assert_eq(Habitability.pop_per_size(_db, traits, "barren", flags_with_dome), 1, "Barren with dome_perches_1 = 1")

func test_tolerant_allow_and_cap() -> void:
	var tolerant_traits: Array[String] = ["tolerant"]
	var empty_flags: Array[String] = []
	assert_eq(Habitability.pop_per_size(_db, tolerant_traits, "barren", empty_flags), 3, "Tolerant on barren without flag = 3 (ALLOW)")

	var tol_heat_traits: Array[String] = ["tolerant", "heat_intolerant"]
	assert_eq(Habitability.pop_per_size(_db, tol_heat_traits, "desert", empty_flags), 1, "Tolerant + heat_intolerant on desert = 1 (cap after floor)")

func test_radiated_refuse_wrong_flag() -> void:
	var traits: Array[String] = []
	var dome_only: Array[String] = ["dome_perches_1"]
	assert_eq(Habitability.pop_per_size(_db, traits, "radiated", dome_only), 0, "Radiated with dome_perches_1 only = 0 (REFUSE needs crackle_shutters)")
	var crackle_flags: Array[String] = ["crackle_shutters"]
	assert_eq(Habitability.pop_per_size(_db, traits, "radiated", crackle_flags), 1, "Radiated with crackle_shutters = 1 (ALLOW)")

func test_asteroids_zero() -> void:
	var traits: Array[String] = ["tolerant", "aquatic", "any_puddle"]
	var flags: Array[String] = ["dome_perches_1", "crackle_shutters"]
	assert_eq(Habitability.pop_per_size(_db, traits, "asteroids", flags), 0, "Asteroids = 0 for everyone")

func test_gravity_for() -> void:
	assert_eq(Habitability.gravity_for("small", "rich"), "normal")
	assert_eq(Habitability.gravity_for("small", "abundant"), "low")
	assert_eq(Habitability.gravity_for("large", "rich"), "heavy")
	assert_eq(Habitability.gravity_for("huge", "poor"), "heavy")

func test_max_pop_and_is_good_for() -> void:
	var p: Planet = Planet.new()
	p.size = "medium" # value 3
	p.climate = "terran" # base 4
	var empty_traits: Array[String] = []
	var empty_flags: Array[String] = []
	assert_eq(Habitability.max_pop(_db, empty_traits, p, empty_flags), 12, "Medium terran max_pop = 3 * 4 = 12")
	assert_true(Habitability.is_good_for(_db, empty_traits, "terran"), "Terran is good for standard species (4 >= 3)")
	assert_false(Habitability.is_good_for(_db, empty_traits, "tundra"), "Tundra is not good for standard species (2 < 3)")
