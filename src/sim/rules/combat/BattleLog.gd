class_name BattleLog
extends RefCounted

var system_id: int = -1
var turn: int = 0
var winner_empire_id: int = -1
var is_stalemate: bool = false
var deciding_band: String = ""
var standout_ship_uid: int = -1
var receipt_lines: Array[Dictionary] = []
var final_distances: Dictionary = {}
var initial_units: Array[Dictionary] = []
var rounds: Array[Dictionary] = []
var final_units: Array[Dictionary] = []
var losses: Dictionary = {}

func to_dict() -> Dictionary:
	return {
		"system_id": system_id,
		"turn": turn,
		"winner_empire_id": winner_empire_id,
		"is_stalemate": is_stalemate,
		"deciding_band": deciding_band,
		"standout_ship_uid": standout_ship_uid,
		"receipt_lines": receipt_lines.duplicate(true),
		"final_distances": final_distances.duplicate(),
		"initial_units": initial_units.duplicate(true),
		"rounds": rounds.duplicate(true),
		"final_units": final_units.duplicate(true),
		"losses": losses.duplicate(true)
	}

static func from_dict(d: Dictionary) -> BattleLog:
	var bl := BattleLog.new()
	bl.system_id = int(d.get("system_id", -1))
	bl.turn = int(d.get("turn", 0))
	bl.winner_empire_id = int(d.get("winner_empire_id", -1))
	bl.is_stalemate = bool(d.get("is_stalemate", false))
	bl.deciding_band = str(d.get("deciding_band", ""))
	bl.standout_ship_uid = int(d.get("standout_ship_uid", -1))
	bl.receipt_lines = []
	for r in d.get("receipt_lines", []):
		bl.receipt_lines.append((r as Dictionary).duplicate(true))
	bl.final_distances = (d.get("final_distances", {}) as Dictionary).duplicate()
	bl.initial_units = []
	for u in d.get("initial_units", []):
		bl.initial_units.append((u as Dictionary).duplicate(true))
	bl.rounds = []
	for r in d.get("rounds", []):
		bl.rounds.append((r as Dictionary).duplicate(true))
	bl.final_units = []
	for u in d.get("final_units", []):
		bl.final_units.append((u as Dictionary).duplicate(true))
	bl.losses = (d.get("losses", {}) as Dictionary).duplicate(true)
	return bl
