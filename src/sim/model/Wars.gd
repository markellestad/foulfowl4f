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

static func is_in_truce(gs: GameState, a: int, b: int) -> bool:
	if gs == null or a == b:
		return false
	var key := _pair_key(a, b)
	return gs.truces.has(key) and gs.turn <= int(gs.truces[key])

static func set_truce(gs: GameState, a: int, b: int, duration: int) -> void:
	if gs == null or a == b:
		return
	var key := _pair_key(a, b)
	gs.truces[key] = gs.turn + duration

static func clear_truce(gs: GameState, a: int, b: int) -> void:
	if gs == null or a == b:
		return
	var key := _pair_key(a, b)
	gs.truces.erase(key)

static func record_battle(gs: GameState, a: int, b: int) -> void:
	if gs == null or a == b:
		return
	var key := _pair_key(a, b)
	gs.last_battle_turn[key] = gs.turn

static func last_battle(gs: GameState, a: int, b: int) -> int:
	if gs == null or a == b:
		return 0
	var key := _pair_key(a, b)
	return int(gs.last_battle_turn.get(key, 0))

static func war_started(gs: GameState, a: int, b: int) -> int:
	if gs == null or a == b:
		return 0
	var key := _pair_key(a, b)
	return int(gs.war_started_turn.get(key, 0))

