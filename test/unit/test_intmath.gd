extends GutTest

func test_floor_div() -> void:
	assert_eq(IntMath.floor_div(-7, 2), -4)
	assert_eq(IntMath.floor_div(7, -2), -4)
	assert_eq(IntMath.floor_div(7, 2), 3)

func test_ceil_div() -> void:
	assert_eq(IntMath.ceil_div(7, 2), 4)
	assert_eq(IntMath.ceil_div(-7, 2), -3)

func test_floor_mod() -> void:
	assert_eq(IntMath.floor_mod(-1, 5), 4)

func test_pct() -> void:
	assert_eq(IntMath.pct(-5, 50), -3)

func test_isqrt() -> void:
	for n in range(2001):
		var s: int = IntMath.isqrt(n)
		assert_true(s * s <= n, "s*s <= n for %d" % n)
		assert_true(n < (s + 1) * (s + 1), "n < (s+1)^2 for %d" % n)
	var big: int = 1000000000000
	var s_big: int = IntMath.isqrt(big)
	assert_eq(s_big, 1000000)

func test_mul32() -> void:
	assert_eq(IntMath.mul32(0xFFFFFFFF, 0xFFFFFFFF), 1)
	var rng: Rng = Rng.keyed(42, 1, 1)
	for i in range(200):
		var a: int = rng.range_i(0, 0x7FFFFFFF)
		var b: int = rng.range_i(0, 0x7FFFFFFF)
		var expected: int = (a * b) & IntMath.MASK32
		assert_eq(IntMath.mul32(a, b), expected)

func test_floor_div_zero_refuse() -> void:
	SimLog.clear()
	var res: int = IntMath.floor_div(5, 0)
	assert_eq(res, 0)
	var logs: Array[String] = SimLog.take()
	assert_true(logs.size() > 0, "logs not empty")
	assert_true(logs[0].begins_with("floor_div by zero"))
