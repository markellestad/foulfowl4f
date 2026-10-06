class_name AiWar
extends RefCounted

static func wants_peace(view: AiView, other_empire_id: int, custom_ratio: int = -1) -> bool:
	var p: Dictionary = view.personality()
	var rules: Array = p.get("rules", [])

	# 1. Librarian rule: refuse peace for 20 turns when attacked
	if rules.has("refuse_peace_20_when_attacked"):
		var declarer: int = view.war_declarer(other_empire_id)
		if declarer == other_empire_id:
			var started: int = view.war_started_turn(other_empire_id)
			if view.turn - started < 20:
				return false

	# 2. Second front: at war with more than 1 empire
	if view.active_wars_count() > 1:
		return true

	# 3. Quiet turns: peace_quiet_turns without battle
	var peace_quiet_turns: int = view.db.bal("peace_quiet_turns")
	var last_btl: int = view.last_battle_turn(other_empire_id)
	if last_btl > 0:
		if view.turn - last_btl >= peace_quiet_turns:
			return true
	else:
		var started: int = view.war_started_turn(other_empire_id)
		if started > 0 and view.turn - started >= peace_quiet_turns:
			return true

	# 4. Power ratio: own power / enemy power < peace_ratio_pct (70%)
	var peace_ratio_pct: int = view.db.bal("peace_ratio_pct")
	var ratio: int = 100
	if custom_ratio >= 0:
		ratio = custom_ratio
	else:
		var own_p: int = view.own_power()
		var enemy_p: int = view.estimated_enemy_power(other_empire_id)
		if enemy_p > 0:
			ratio = IntMath.pct(own_p, enemy_p)
		elif own_p > 0:
			ratio = 100

	if ratio < peace_ratio_pct:
		return true

	return false
