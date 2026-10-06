class_name Ids
extends RefCounted

const NONE := -1

static func sorted_keys(d: Dictionary) -> Array:
	var keys: Array = d.keys()
	keys.sort()
	return keys

static func sorted_ints(a: Array) -> Array[int]:
	var res: Array[int] = []
	for v in a:
		res.append(int(v))
	res.sort()
	return res
