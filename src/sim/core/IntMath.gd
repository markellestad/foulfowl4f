class_name IntMath
extends RefCounted

const MASK32 := 0xFFFFFFFF

static func mul32(a: int, b: int) -> int:
	return ((a * (b & 0xFFFF)) + (((a * (b >> 16)) & 0xFFFF) << 16)) & MASK32

static func floor_div(a: int, b: int) -> int:
	if b == 0:
		SimLog.warn("floor_div by zero")
		return 0
	@warning_ignore("integer_division")
	var q: int = a / b
	var rem: int = a % b
	if rem != 0 and ((a < 0) != (b < 0)):
		q -= 1
	return q

static func ceil_div(a: int, b: int) -> int:
	if b == 0:
		SimLog.warn("floor_div by zero")
		return 0
	return -floor_div(-a, b)

static func floor_mod(a: int, b: int) -> int:
	return a - b * floor_div(a, b)

static func pct(value: int, percent: int) -> int:
	return floor_div(value * percent, 100)

static func clamp_i(v: int, lo: int, hi: int) -> int:
	if v < lo:
		return lo
	if v > hi:
		return hi
	return v

static func isqrt(n: int) -> int:
	if n <= 0:
		return 0
	var x0: int = n >> 1
	if x0 == 0:
		return 1
	var x1: int = floor_div(x0 + floor_div(n, x0), 2)
	while x1 < x0:
		x0 = x1
		x1 = floor_div(x0 + floor_div(n, x0), 2)
	return x0

static func lerp_i(a: int, b: int, num: int, den: int) -> int:
	return a + floor_div((b - a) * num, den)

static func dist(x1: int, y1: int, x2: int, y2: int) -> int:
	var dx: int = x2 - x1
	var dy: int = y2 - y1
	return isqrt(dx * dx + dy * dy)
