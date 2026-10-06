class_name Rng
extends RefCounted
## Keyed deterministic RNG. xoshiro128** state seeded by splitmix32 from an FNV-1a hash.
## Format contract: matches docs/engineering/reference/rng_reference.py exactly.

const GALAXY := 1
const COMBAT := 2
const GROUND := 3
const EVENTS := 4
const ESPIONAGE := 5
const AI := 6
const RESEARCH := 7
const COLONIZE := 8
const LOOT := 9
const LINEUP := 10
const NAMES := 11

const MASK32 := 0xFFFFFFFF
const FNV_OFFSET := 0x811C9DC5
const FNV_PRIME := 0x01000193

var _s0: int = 0
var _s1: int = 0
var _s2: int = 0
var _s3: int = 0

func _init(seed32: int = 0) -> void:
	var x: int = seed32 & MASK32
	var lanes: Array[int] = []
	for i in 4:
		x = (x + 0x9E3779B9) & MASK32
		var z: int = x
		z = IntMath.mul32(z ^ (z >> 16), 0x85EBCA6B)
		z = IntMath.mul32(z ^ (z >> 13), 0xC2B2AE35)
		z = z ^ (z >> 16)
		lanes.append(z)
	_s0 = lanes[0]
	_s1 = lanes[1]
	_s2 = lanes[2]
	_s3 = lanes[3]
	if _s0 == 0 and _s1 == 0 and _s2 == 0 and _s3 == 0:
		_s0 = 1

static func keyed(seed: int, turn: int, stream: int, a: int = 0, b: int = 0) -> Rng:
	return Rng.new(hash_ints([seed, turn, stream, a, b]))

static func hash_ints(values: Array) -> int:
	var h: int = FNV_OFFSET
	for v in values:
		var n: int = int(v)
		for i in 8:
			h = ((h ^ ((n >> (8 * i)) & 0xFF)) * FNV_PRIME) & MASK32
	return h

static func seed_from_string(s: String) -> int:
	var h: int = FNV_OFFSET
	for b in s.to_utf8_buffer():
		h = ((h ^ int(b)) * FNV_PRIME) & MASK32
	return h

static func _rotl(x: int, k: int) -> int:
	return ((x << k) | (x >> (32 - k))) & MASK32

func next_u32() -> int:
	var result: int = (_rotl((_s1 * 5) & MASK32, 7) * 9) & MASK32
	var t: int = (_s1 << 9) & MASK32
	_s2 = _s2 ^ _s0
	_s3 = _s3 ^ _s1
	_s1 = _s1 ^ _s2
	_s0 = _s0 ^ _s3
	_s2 = _s2 ^ t
	_s3 = _rotl(_s3, 11)
	return result

## Inclusive. Returns lo when hi < lo (no assert).
func range_i(lo: int, hi: int) -> int:
	if hi < lo:
		return lo
	var span: int = hi - lo + 1
	var limit: int = IntMath.floor_div(0x100000000, span) * span
	var r: int = next_u32()
	while r >= limit:
		r = next_u32()
	return lo + r % span

func chance_pct(p: int) -> bool:
	return range_i(0, 99) < p

func pick_index(n: int) -> int:
	if n <= 0:
		return -1
	return range_i(0, n - 1)

## Fisher-Yates, in place.
func shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = range_i(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
