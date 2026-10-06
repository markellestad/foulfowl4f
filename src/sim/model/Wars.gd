class_name Wars
extends RefCounted

const MONSTERS_FACTION := 100

static func _pair_key(a: int, b: int) -> String:
	return "%d_%d" % [mini(a, b), maxi(a, b)]

static func is_at_war(gs: GameState, a: int, b: int) -> bool:
	if a == b:
		return false
	if a == MONSTERS_FACTION or b == MONSTERS_FACTION:
		return true
	if gs == null:
		return false
	var key := _pair_key(a, b)
	return bool(gs.wars.get(key, false))

static func set_war(gs: GameState, a: int, b: int, on: bool) -> void:
	if gs == null or a == b:
		return
	var key := _pair_key(a, b)
	if on:
		gs.wars[key] = true
	else:
		gs.wars.erase(key)
