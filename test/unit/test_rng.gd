extends GutTest

func test_goldens() -> void:
	assert_eq(Rng.seed_from_string("FOWL"), 582433017)
	assert_eq(Rng.seed_from_string(""), 2166136261)
	assert_eq(Rng.hash_ints([1, 2, 3]), 1095553189)
	assert_eq(Rng.hash_ints([-1]), 1823345245)

	var r1: Rng = Rng.keyed(12345, 1, 2, 0, 0)
	var u32s: Array[int] = []
	for i in 5:
		u32s.append(r1.next_u32())
	assert_eq(u32s, [1693814098, 297055945, 585350584, 3175262707, 3717602762])

	var r2: Rng = Rng.keyed(12345, 1, 2, 0, 0)
	var ranges: Array[int] = []
	for i in 10:
		ranges.append(r2.range_i(1, 6))
	assert_eq(ranges, [5, 2, 5, 2, 3, 2, 4, 2, 2, 5])

	var r3: Rng = Rng.new(0)
	var r3_u32s: Array[int] = []
	for i in 3:
		r3_u32s.append(r3.next_u32())
	assert_eq(r3_u32s, [3809008728, 1133695204, 53579671])

	var r4: Rng = Rng.keyed(Rng.seed_from_string("FOWL"), 0, 1, 7, -1)
	var r4_ranges: Array[int] = []
	for i in 8:
		r4_ranges.append(r4.range_i(0, 99))
	assert_eq(r4_ranges, [81, 12, 92, 38, 44, 45, 30, 86])

func test_range_i_boundaries() -> void:
	var r: Rng = Rng.keyed(999, 1, 1)
	# ALLOW: lo == hi returns lo
	assert_eq(r.range_i(5, 5), 5)
	# REFUSE: hi < lo returns lo without error
	assert_eq(r.range_i(10, 5), 10)

func test_distribution_and_coverage() -> void:
	var r: Rng = Rng.keyed(42, 1, 1)
	var counts: Dictionary = {}
	for i in 10:
		counts[i] = 0
	for i in 10000:
		var v: int = r.range_i(0, 9)
		assert_true(v >= 0 and v <= 9, "Value in range [0, 9]")
		counts[v] += 1
	for i in 10:
		assert_true(counts[i] > 0, "Hit value %d at least once" % i)

func test_keyed_determinism_and_divergence() -> void:
	var r1: Rng = Rng.keyed(100, 2, 3, 4, 5)
	var r2: Rng = Rng.keyed(100, 2, 3, 4, 5)
	for i in 20:
		assert_eq(r1.next_u32(), r2.next_u32())

	var base: int = Rng.keyed(100, 2, 3, 4, 5).next_u32()
	assert_ne(Rng.keyed(101, 2, 3, 4, 5).next_u32(), base)
	assert_ne(Rng.keyed(100, 3, 3, 4, 5).next_u32(), base)
	assert_ne(Rng.keyed(100, 2, 4, 4, 5).next_u32(), base)
	assert_ne(Rng.keyed(100, 2, 3, 5, 5).next_u32(), base)
	assert_ne(Rng.keyed(100, 2, 3, 4, 6).next_u32(), base)

func test_shuffle_is_permutation() -> void:
	var r: Rng = Rng.keyed(777, 1, 1)
	var arr: Array = [1, 2, 2, 3, 4, 5, 5, 6, 7, 8, 9]
	var orig: Array = arr.duplicate()
	r.shuffle(arr)
	var sorted_arr: Array = arr.duplicate()
	sorted_arr.sort()
	assert_eq(sorted_arr, orig)
