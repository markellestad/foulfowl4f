class_name BattlePlayer
extends RefCounted

var log: BattleLog
var current_round: int = 0
var is_finished: bool = false
var units: Dictionary = {} # uid -> Dictionary

func _init(p_log: BattleLog = null) -> void:
	if p_log != null:
		load_log(p_log)

func load_log(p_log: BattleLog) -> void:
	log = p_log
	current_round = 0
	is_finished = false
	units.clear()
	for u in log.initial_units:
		units[int(u["uid"])] = u.duplicate(true)

func step() -> bool:
	if is_finished or log == null:
		return false
	if current_round >= log.rounds.size():
		is_finished = true
		return false

	var r: Dictionary = log.rounds[current_round]

	# 1. Horizon hits
	for hh in r.get("horizon_hits", []):
		var tuid: int = int(hh.get("target_uid", -1))
		var dmg: int = int(hh.get("damage", 0))
		if units.has(tuid):
			units[tuid]["hp"] = maxi(0, int(units[tuid]["hp"]) - dmg)

	# 2. Direct shots
	for s in r.get("shots", []):
		if bool(s.get("hit", false)):
			var tuid: int = int(s.get("target_uid", -1))
			var dmg: int = int(s.get("damage", 0))
			if units.has(tuid):
				units[tuid]["hp"] = maxi(0, int(units[tuid]["hp"]) - dmg)

	# 3. Heals
	for h in r.get("heals", []):
		var tuid: int = int(h.get("uid", -1))
		var amt: int = int(h.get("amount", 0))
		if units.has(tuid):
			units[tuid]["hp"] = mini(int(units[tuid]["hp_max"]), int(units[tuid]["hp"]) + amt)

	# 4. Destroyed uids
	for duid in r.get("destroyed_uids", []):
		var uid: int = int(duid)
		if units.has(uid):
			units[uid]["hp"] = 0

	current_round += 1
	if current_round >= log.rounds.size():
		is_finished = true
	return true

func play_all() -> void:
	while step():
		pass

func get_unit_hp(uid: int) -> int:
	if units.has(uid):
		return int(units[uid].get("hp", 0))
	return 0
