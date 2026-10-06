class_name CombatParty
extends RefCounted

var party_id: int = 0
var empire_id: int = -1
var is_colony_defense: bool = false
var colony_id: int = -1
var fleet_ids: Array[int] = []

var posture: String = "auto"
var target_priority: String = "auto"
var swat_mode: String = "missiles_first"
var retreat_threshold: String = "never"
var line_order: Array[int] = []

var units: Array[CombatUnit] = []
var max_line_slots: int = 8
var planet_shield: int = 0
var traits: Array[String] = []
var is_attacker: bool = false
var is_first_battle_of_war: bool = false

var retreating: bool = false
var escaped: bool = false
var receipt_unit_uid: int = -1
var auto_band: String = "talon"

func get_armed_line_units(line_uids: Array[int]) -> Array[CombatUnit]:
	var result: Array[CombatUnit] = []
	var lookup: Dictionary = {}
	for u in units:
		lookup[u.uid] = u
	for uid in line_uids:
		if lookup.has(uid):
			var u: CombatUnit = lookup[uid]
			if u.is_alive() and u.is_armed:
				result.append(u)
	return result

func get_combat_speed(line_uids: Array[int]) -> int:
	if is_colony_defense:
		return 0
	var armed_line := get_armed_line_units(line_uids)
	if armed_line.is_empty():
		return 1
	var min_s: int = 999
	for u in armed_line:
		if u.combat_speed < min_s:
			min_s = u.combat_speed
	return maxi(1, min_s)

func has_horizon_ammo() -> bool:
	for u in units:
		if not u.is_alive():
			continue
		for w in u.weapons:
			if w.get("band", "") == "horizon":
				var salvos: int = int(w.get("salvos", -1))
				if salvos != 0:
					return true
	return false

func has_live_armed() -> bool:
	for u in units:
		if u.is_alive() and u.is_armed:
			return true
	return false

func to_dict() -> Dictionary:
	var u_arr: Array = []
	for u in units:
		u_arr.append(u.to_dict())
	return {
		"party_id": party_id,
		"empire_id": empire_id,
		"is_colony_defense": is_colony_defense,
		"colony_id": colony_id,
		"fleet_ids": fleet_ids.duplicate(),
		"posture": posture,
		"target_priority": target_priority,
		"swat_mode": swat_mode,
		"retreat_threshold": retreat_threshold,
		"line_order": line_order.duplicate(),
		"units": u_arr,
		"max_line_slots": max_line_slots,
		"planet_shield": planet_shield,
		"traits": traits.duplicate(),
		"is_attacker": is_attacker,
		"is_first_battle_of_war": is_first_battle_of_war,
		"retreating": retreating,
		"escaped": escaped,
		"receipt_unit_uid": receipt_unit_uid,
		"auto_band": auto_band
	}

static func from_dict(d: Dictionary) -> CombatParty:
	var p := CombatParty.new()
	p.party_id = int(d.get("party_id", 0))
	p.empire_id = int(d.get("empire_id", -1))
	p.is_colony_defense = bool(d.get("is_colony_defense", false))
	p.colony_id = int(d.get("colony_id", -1))
	p.fleet_ids = []
	for f in d.get("fleet_ids", []):
		p.fleet_ids.append(int(f))
	p.posture = str(d.get("posture", "auto"))
	p.target_priority = str(d.get("target_priority", "auto"))
	p.swat_mode = str(d.get("swat_mode", "missiles_first"))
	p.retreat_threshold = str(d.get("retreat_threshold", "never"))
	p.line_order = []
	for lo in d.get("line_order", []):
		p.line_order.append(int(lo))
	p.units = []
	for ud in d.get("units", []):
		p.units.append(CombatUnit.from_dict(ud as Dictionary))
	p.max_line_slots = int(d.get("max_line_slots", 8))
	p.planet_shield = int(d.get("planet_shield", 0))
	p.traits = []
	for t in d.get("traits", []):
		p.traits.append(str(t))
	p.is_attacker = bool(d.get("is_attacker", false))
	p.is_first_battle_of_war = bool(d.get("is_first_battle_of_war", false))
	p.retreating = bool(d.get("retreating", false))
	p.escaped = bool(d.get("escaped", false))
	p.receipt_unit_uid = int(d.get("receipt_unit_uid", -1))
	p.auto_band = str(d.get("auto_band", "talon"))
	return p
