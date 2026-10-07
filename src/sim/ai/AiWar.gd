class_name AiWar
extends RefCounted

static func plan(view: AiView, _memory: AiMemory = null) -> Array[Cmd]:
	var cmds: Array[Cmd] = []
	var met: Dictionary = view.met_empires()
	if met.is_empty():
		return cmds

	# 1. Check peace proposals for existing wars
	for other_id in met.keys():
		var eid: int = int(other_id)
		if eid == view.empire_id:
			continue
		if eid < 0 or eid >= view.raw_game_state_DO_NOT_USE_EXCEPT_SIM().empires.size():
			continue
		if view.is_at_war(eid):
			if wants_peace(view, eid) and not view.has_proposed_peace(eid):
				var peace_cmd: CmdProposePeace = CmdProposePeace.new()
				peace_cmd.empire_id = view.empire_id
				peace_cmd.target_empire = eid
				cmds.append(peace_cmd)

	# 2. Check war declarations
	var p: Dictionary = view.personality()
	var rules: Array = p.get("rules", [])
	var aggr: int = int(p.get("aggression", 5))
	var base_war_ratio: int = int(p.get("war_ratio_pct", 100))

	var diff_str: String = "flighted"
	var settings = view.raw_game_state_DO_NOT_USE_EXCEPT_SIM().settings
	if settings != null and settings.difficulty != "":
		diff_str = settings.difficulty
	var diff_row: Dictionary = view.db.def("difficulty", diff_str)
	var diff_thresh: int = int(diff_row.get("war_threshold_pct", 100))
	var never_first: bool = bool(diff_row.get("never_first", false))

	var rel_thresh: int = view.db.bal("war_relation_threshold")
	var aggr_thresh: int = view.db.bal("war_aggression_threshold")

	# Sort candidates by ID for determinism
	var candidates: Array[int] = []
	for k in met.keys():
		candidates.append(int(k))
	candidates.sort()

	for eid in candidates:
		if eid == view.empire_id:
			continue
		if eid < 0 or eid >= view.raw_game_state_DO_NOT_USE_EXCEPT_SIM().empires.size():
			continue
		if view.is_at_war(eid) or view.is_in_truce(eid):
			continue

		# Difficulty check: never declare on player first
		if never_first and eid == 0:
			continue

		# Personality rules
		if rules.has("never_declare_war"):
			continue
		if rules.has("war_only_below_minus_50_or_attacked"):
			var rel_val: int = view.relations_value(eid).value
			if rel_val > -50:
				continue

		var rel: int = view.relations_value(eid).value
		if not (rel <= rel_thresh or aggr >= aggr_thresh):
			continue

		# Power ratio check
		var own_p: int = view.own_power()
		var enemy_p: int = view.estimated_enemy_power(eid)
		var req_ratio: int = IntMath.pct(base_war_ratio, diff_thresh)
		if enemy_p > 0 and own_p * 100 < req_ratio * enemy_p:
			continue

		var war_cmd: CmdDeclareWar = CmdDeclareWar.new()
		war_cmd.empire_id = view.empire_id
		war_cmd.target_empire = eid
		cmds.append(war_cmd)
		break # Declare at most one war per turn

	return cmds

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
			ratio = IntMath.floor_div(own_p * 100, enemy_p)
		elif own_p > 0:
			ratio = 100

	if ratio < peace_ratio_pct:
		return true

	return false
