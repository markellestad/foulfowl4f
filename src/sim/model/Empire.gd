class_name Empire
extends RefCounted

var id: int = -1
var race: String = ""
var traits: Array[String] = []
var is_ai: bool = false
var alive: bool = true
var treasury: int = 0
var capital_colony_id: int = -1
var tech: TechState = null
var timed_mods: Array[TimedMod] = []
var strike_next_turn: bool = false
var food_last: Dictionary = {}
var ai_memory: Dictionary = {}
var military_budget: String = "guarded"
var eliminated_turn: int = -1

func _init() -> void:
	tech = TechState.new()

func has_trait(t: String) -> bool:
	return traits.has(t)

func species_traits(db: ContentDB) -> Array[String]:
	var result: Array[String] = []
	for t in traits:
		var tdef: Dictionary = db.def("traits", t)
		if bool(tdef.get("species", false)):
			result.append(t)
	return result

func to_dict() -> Dictionary:
	var tr_arr: Array = []
	for t in traits:
		tr_arr.append(str(t))
	var tm_arr: Array = []
	for tm in timed_mods:
		tm_arr.append(tm.to_dict())
	var fl: Dictionary = {}
	for k in food_last.keys():
		fl[str(k)] = int(food_last[k])
	return {
		"id": id,
		"race": race,
		"traits": tr_arr,
		"is_ai": is_ai,
		"alive": alive,
		"treasury": treasury,
		"capital_colony_id": capital_colony_id,
		"tech": tech.to_dict() if tech != null else TechState.new().to_dict(),
		"timed_mods": tm_arr,
		"strike_next_turn": strike_next_turn,
		"food_last": fl,
		"ai_memory": ai_memory.duplicate(true),
		"military_budget": military_budget,
		"eliminated_turn": eliminated_turn
	}

static func from_dict(d: Dictionary) -> Empire:
	var emp: Empire = Empire.new()
	emp.id = int(d.get("id", -1))
	emp.race = str(d.get("race", ""))
	emp.traits.clear()
	var raw_tr: Array = d.get("traits", [])
	for t in raw_tr:
		emp.traits.append(str(t))
	emp.is_ai = bool(d.get("is_ai", false))
	emp.alive = bool(d.get("alive", true))
	emp.treasury = int(d.get("treasury", 0))
	emp.capital_colony_id = int(d.get("capital_colony_id", -1))
	var t_dict: Dictionary = d.get("tech", {})
	emp.tech = TechState.from_dict(t_dict)
	emp.timed_mods.clear()
	var raw_tm: Array = d.get("timed_mods", [])
	for tm_data in raw_tm:
		if tm_data is Dictionary:
			emp.timed_mods.append(TimedMod.from_dict(tm_data))
	emp.strike_next_turn = bool(d.get("strike_next_turn", false))
	emp.food_last.clear()
	var raw_fl: Dictionary = d.get("food_last", {})
	for k in raw_fl.keys():
		emp.food_last[str(k)] = int(raw_fl[k])
	emp.ai_memory = (d.get("ai_memory", {}) as Dictionary).duplicate(true)
	emp.military_budget = str(d.get("military_budget", "guarded"))
	emp.eliminated_turn = int(d.get("eliminated_turn", -1))
	return emp
