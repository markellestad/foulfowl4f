class_name Capitulation
extends RefCounted

static func check_candidate(db: ContentDB, gs: GameState, empire_id: int) -> int:
	if empire_id < 0 or empire_id >= gs.empires.size():
		return -1

	# Player never auto-capitulates
	var is_player: bool = (empire_id == 0 and (gs.settings == null or not gs.settings.all_ai))
	if is_player:
		return -1

	var emp: Empire = gs.empires[empire_id]
	if emp.eliminated_turn >= 0:
		return -1

	# Must have lost capital
	if emp.capital_colony_id != -1:
		return -1

	# Must hold <= capitulate_max_colonies (non-outposts)
	var col_count: int = 0
	for cid in Ids.sorted_keys(gs.colonies):
		var col: Colony = gs.colonies[cid]
		if col.owner == empire_id and not col.is_outpost:
			col_count += 1

	if col_count > db.bal("capitulate_max_colonies"):
		return -1

	# Must be at war, and find strongest enemy
	var strongest_enemy: int = -1
	var max_enemy_power: int = -1

	for other_id in range(gs.empires.size()):
		if other_id == empire_id:
			continue
		if Wars.is_at_war(gs, empire_id, other_id):
			var epower: int = Power.empire_military_power(db, gs, other_id)
			if epower > max_enemy_power:
				max_enemy_power = epower
				strongest_enemy = other_id

	if strongest_enemy < 0 or max_enemy_power <= 0:
		return -1

	var enemy_emp: Empire = gs.empires[strongest_enemy]
	var enemy_rdef: Dictionary = db.def("races", enemy_emp.race)
	var is_floor: bool = (str(enemy_rdef.get("personality", "")) == "floor")

	var threshold_pct: int = db.bal("capitulate_power_pct_floor") if is_floor else db.bal("capitulate_power_pct")
	var own_power: int = Power.empire_military_power(db, gs, empire_id)

	# Strict inequality: power < threshold_pct of strongest enemy's
	if own_power * 100 < threshold_pct * max_enemy_power:
		return strongest_enemy

	return -1

static func transfer_and_eliminate(db: ContentDB, gs: GameState, from_id: int, to_id: int) -> void:
	if from_id < 0 or from_id >= gs.empires.size() or to_id < 0 or to_id >= gs.empires.size():
		return

	var from_emp: Empire = gs.empires[from_id]
	var to_emp: Empire = gs.empires[to_id]

	# Transfer colonies
	for cid in Ids.sorted_keys(gs.colonies):
		var col: Colony = gs.colonies[cid]
		if col.owner == from_id:
			col.owner = to_id
			for qi in col.queue:
				qi.added_by = "governor"

	# Transfer fleets and ships
	for fid in Ids.sorted_keys(gs.fleets):
		var f: Fleet = gs.fleets[fid]
		if f.owner == from_id:
			f.owner = to_id

	for sid in Ids.sorted_keys(gs.ships):
		var s: Ship = gs.ships[sid]
		if s.owner == from_id:
			s.owner = to_id

	# Eliminate from_empire
	from_emp.eliminated_turn = gs.turn
	from_emp.capital_colony_id = -1

	# End all wars and truces involving from_id
	for eid in range(gs.empires.size()):
		if eid != from_id:
			Wars.set_war(gs, from_id, eid, false)
			Wars.clear_truce(gs, from_id, eid)

	# News item
	gs.news.append({
		"kind": "capitulation",
		"turn": gs.turn,
		"from_race": from_emp.race,
		"to_race": to_emp.race
	})
