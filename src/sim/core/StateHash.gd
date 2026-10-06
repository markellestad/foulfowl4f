class_name StateHash
extends RefCounted

const MASK32 := 0xFFFFFFFF
const FNV_OFFSET := 0x811C9DC5
const FNV_PRIME := 0x01000193

static func of_bytes(b: PackedByteArray) -> int:
	var h: int = FNV_OFFSET
	for byte in b:
		h = ((h ^ int(byte)) * FNV_PRIME) & MASK32
	return h

static func of_value(v: Variant) -> int:
	var s: String = JSON.stringify(v, "", true)
	return of_bytes(s.to_utf8_buffer())

static func hash_dict(d: Dictionary) -> int:
	return of_value(d)
