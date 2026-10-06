class_name AiMemory
extends RefCounted

var failed_strikes: Dictionary = {}      # target_colony_id (int) -> Array[int] (turn numbers)
var last_defense_met: Dictionary = {}    # target_colony_id (int) -> int
var re_scout_sent: Dictionary = {}       # target_colony_id (int) -> int (turn sent)

func record_strike_failure(target_cid: int, turn: int, defense_met: int = 0) -> void:
	if not failed_strikes.has(target_cid):
		failed_strikes[target_cid] = []
	(failed_strikes[target_cid] as Array).append(turn)
	if defense_met > 0:
		last_defense_met[target_cid] = defense_met

func failures_in_window(target_cid: int, current_turn: int, window: int) -> int:
	if not failed_strikes.has(target_cid):
		return 0
	var count: int = 0
	var arr: Array = failed_strikes[target_cid] as Array
	for t in arr:
		if current_turn - int(t) <= window and current_turn >= int(t):
			count += 1
	return count

func get_last_defense_met(target_cid: int) -> int:
	return int(last_defense_met.get(target_cid, 0))

func to_dict() -> Dictionary:
	var fs_dict: Dictionary = {}
	for k in failed_strikes.keys():
		var t_arr: Array = []
		for t in failed_strikes[k]:
			t_arr.append(int(t))
		fs_dict[str(k)] = t_arr

	var ldm_dict: Dictionary = {}
	for k in last_defense_met.keys():
		ldm_dict[str(k)] = int(last_defense_met[k])

	var rs_dict: Dictionary = {}
	for k in re_scout_sent.keys():
		rs_dict[str(k)] = int(re_scout_sent[k])

	return {
		"failed_strikes": fs_dict,
		"last_defense_met": ldm_dict,
		"re_scout_sent": rs_dict
	}

static func from_dict(d: Dictionary) -> AiMemory:
	var m: AiMemory = AiMemory.new()
	m.failed_strikes.clear()
	var raw_fs: Dictionary = d.get("failed_strikes", {})
	for k_str in raw_fs.keys():
		var arr: Array[int] = []
		for t in raw_fs[k_str]:
			arr.append(int(t))
		m.failed_strikes[int(k_str)] = arr

	m.last_defense_met.clear()
	var raw_ldm: Dictionary = d.get("last_defense_met", {})
	for k_str in raw_ldm.keys():
		m.last_defense_met[int(k_str)] = int(raw_ldm[k_str])

	m.re_scout_sent.clear()
	var raw_rs: Dictionary = d.get("re_scout_sent", {})
	for k_str in raw_rs.keys():
		m.re_scout_sent[int(k_str)] = int(raw_rs[k_str])

	return m
