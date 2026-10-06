class_name CombatUnit
extends RefCounted

var uid: int = 0
var name_key: String = ""
var empire_id: int = -1
var ship_id: int = -1
var design_id: String = ""
var hull_id: String = ""
var hull_space: int = 0
var hp: int = 0
var hp_max: int = 0
var shield: int = 0
var evasion: int = 0
var acc: int = 0
var combat_speed: int = 1
var line_slots: int = 1
var is_planet: bool = false
var is_armed: bool = false
var is_swat: bool = false
var has_pods: bool = false
var main_band: String = ""
var weapons: Array[Dictionary] = []
var specials: Array[String] = []

var miss_field: int = 0
var scatter_molt: bool = false
var gone_to_molt: bool = false
var not_this_feather: bool = false
var self_sealing: bool = false
var ignores_shields_pct: int = 0

var damage_dealt: int = 0
var kills: int = 0
var rounds_survived: int = 0

func is_alive() -> bool:
	return hp > 0

func to_dict() -> Dictionary:
	return {
		"uid": uid,
		"name_key": name_key,
		"empire_id": empire_id,
		"ship_id": ship_id,
		"design_id": design_id,
		"hull_id": hull_id,
		"hull_space": hull_space,
		"hp": hp,
		"hp_max": hp_max,
		"shield": shield,
		"evasion": evasion,
		"acc": acc,
		"combat_speed": combat_speed,
		"line_slots": line_slots,
		"is_planet": is_planet,
		"is_armed": is_armed,
		"is_swat": is_swat,
		"has_pods": has_pods,
		"main_band": main_band,
		"weapons": weapons.duplicate(true),
		"specials": specials.duplicate(),
		"miss_field": miss_field,
		"scatter_molt": scatter_molt,
		"gone_to_molt": gone_to_molt,
		"not_this_feather": not_this_feather,
		"self_sealing": self_sealing,
		"ignores_shields_pct": ignores_shields_pct,
		"damage_dealt": damage_dealt,
		"kills": kills,
		"rounds_survived": rounds_survived
	}

static func from_dict(d: Dictionary) -> CombatUnit:
	var u := CombatUnit.new()
	u.uid = int(d.get("uid", 0))
	u.name_key = str(d.get("name_key", ""))
	u.empire_id = int(d.get("empire_id", -1))
	u.ship_id = int(d.get("ship_id", -1))
	u.design_id = str(d.get("design_id", ""))
	u.hull_id = str(d.get("hull_id", ""))
	u.hull_space = int(d.get("hull_space", 0))
	u.hp = int(d.get("hp", 0))
	u.hp_max = int(d.get("hp_max", 0))
	u.shield = int(d.get("shield", 0))
	u.evasion = int(d.get("evasion", 0))
	u.acc = int(d.get("acc", 0))
	u.combat_speed = int(d.get("combat_speed", 1))
	u.line_slots = int(d.get("line_slots", 1))
	u.is_planet = bool(d.get("is_planet", false))
	u.is_armed = bool(d.get("is_armed", false))
	u.is_swat = bool(d.get("is_swat", false))
	u.has_pods = bool(d.get("has_pods", false))
	u.main_band = str(d.get("main_band", ""))
	u.weapons = []
	for w in d.get("weapons", []):
		u.weapons.append((w as Dictionary).duplicate(true))
	u.specials = []
	for s in d.get("specials", []):
		u.specials.append(str(s))
	u.miss_field = int(d.get("miss_field", 0))
	u.scatter_molt = bool(d.get("scatter_molt", false))
	u.gone_to_molt = bool(d.get("gone_to_molt", false))
	u.not_this_feather = bool(d.get("not_this_feather", false))
	u.self_sealing = bool(d.get("self_sealing", false))
	u.ignores_shields_pct = int(d.get("ignores_shields_pct", 0))
	u.damage_dealt = int(d.get("damage_dealt", 0))
	u.kills = int(d.get("kills", 0))
	u.rounds_survived = int(d.get("rounds_survived", 0))
	return u
