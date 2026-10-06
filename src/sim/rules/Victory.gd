class_name Victory
extends RefCounted

static func check_elimination(db: ContentDB, gs: GameState, empire_id: int) -> bool:
	if empire_id < 0 or empire_id >= gs.empires.size():
		return false
	var emp: Empire = gs.empires[empire_id]
	if emp.eliminated_turn >= 0:
		return true

	var colony_count: int = 0
	for cid in Ids.sorted_keys(gs.colonies):
		var col: Colony = gs.colonies[cid]
		if col.owner == empire_id and not col.is_outpost:
			colony_count += 1

	if colony_count == 0:
		emp.eliminated_turn = gs.turn
		emp.capital_colony_id = -1

		var ships_to_remove: Array[int] = []
		for sid in Ids.sorted_keys(gs.ships):
			var s: Ship = gs.ships[sid]
			if s.owner == empire_id:
				ships_to_remove.append(sid)
		for sid in ships_to_remove:
			gs.ships.erase(sid)

		var fleets_to_remove: Array[int] = []
		for fid in Ids.sorted_keys(gs.fleets):
			var f: Fleet = gs.fleets[fid]
			if f.owner == empire_id:
				fleets_to_remove.append(fid)
		for fid in fleets_to_remove:
			gs.fleets.erase(fid)

		for eid in range(gs.empires.size()):
			if eid != empire_id:
				Wars.set_war(gs, empire_id, eid, false)
				Wars.clear_truce(gs, empire_id, eid)

		return true

	return false

static func check_victory(db: ContentDB, gs: GameState) -> void:
	if gs.one_more_turn:
		return
	if gs.game_over:
		return

	# 1. Elimination check for all empires
	for eid in range(gs.empires.size()):
		check_elimination(db, gs, eid)

	# 2. Capitulation check for all active AI empires
	for eid in range(gs.empires.size()):
		var emp: Empire = gs.empires[eid]
		if emp.eliminated_turn >= 0:
			continue
		var target_enemy: int = Capitulation.check_candidate(db, gs, eid)
		if target_enemy >= 0:
			var target_is_player: bool = (target_enemy == 0 and (gs.settings == null or not gs.settings.all_ai))
			if target_is_player:
				var already_offered: bool = false
				for off in gs.capitulation_offers:
					if int(off.get("from_empire", -1)) == eid and int(off.get("to_empire", -1)) == 0:
						already_offered = true
						break
				if not already_offered:
					var offer_id: int = gs.alloc_id("capitulation")
					gs.capitulation_offers.append({
						"id": offer_id,
						"from_empire": eid,
						"to_empire": 0,
						"turn": gs.turn
					})
			else:
				# AI-to-AI accepted automatically
				Capitulation.transfer_and_eliminate(db, gs, eid, target_enemy)

	# 3. Check again eliminations after capitulations
	for eid in range(gs.empires.size()):
		check_elimination(db, gs, eid)

	# 4. Check Conquest: all rivals eliminated or capitulated
	var active_empires: Array[int] = []
	for eid in range(gs.empires.size()):
		var emp: Empire = gs.empires[eid]
		if emp.eliminated_turn < 0:
			active_empires.append(eid)

	if active_empires.size() == 1:
		gs.game_over = true
		gs.winner = active_empires[0]
		gs.victory_type = "conquest"
		return

	# 5. Check Called Game: at turn_cap, highest Score.of(empire)
	var turn_cap: int = 200
	if gs.settings != null and gs.settings.turn_cap > 0:
		turn_cap = gs.settings.turn_cap

	if gs.turn >= turn_cap:
		var best_score: int = -1
		var best_id: int = -1
		for eid in active_empires:
			var sc: int = Score.of(db, gs, eid)
			if sc > best_score:
				best_score = sc
				best_id = eid
			elif sc == best_score and best_id >= 0 and eid < best_id:
				best_id = eid

		if best_id >= 0:
			gs.game_over = true
			gs.winner = best_id
			gs.victory_type = "called_game"
			return

	# 6. Check Defeat: player has no colonies or eliminated
	var player_eliminated: bool = false
	if gs.settings == null or not gs.settings.all_ai:
		var p_emp: Empire = gs.empires[0]
		if p_emp.eliminated_turn >= 0:
			player_eliminated = true

	if player_eliminated:
		gs.game_over = true
		gs.victory_type = "defeat"
		var best_score: int = -1
		var best_id: int = -1
		for eid in active_empires:
			var sc: int = Score.of(db, gs, eid)
			if sc > best_score:
				best_score = sc
				best_id = eid
		gs.winner = best_id
		return
