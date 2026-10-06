class_name Colony
extends RefCounted

var id: int = -1
var planet_id: int = -1
var owner: int = -1
var species: String = ""
var pop_milli: int = 0
var farmers: int = 0
var workers: int = 0
var scientists: int = 0
var jobs_locked: bool = false
var preset: String = "frontier"
var buildings: Array[String] = []
var queue: Array[QueueItem] = []
var progress_pp: int = 0
var occupied_until: int = -1
var garrison: int = 0
var defense_hp: int = 0
var blockaded: bool = false
var bombarded_by: Array[int] = []
var founded_turn: int = 1
var is_outpost: bool = false

func pop_units() -> int:
	return int(IntMath.floor_div(pop_milli, 1000))

func to_dict() -> Dictionary:
	var b_arr: Array = []
	for b in buildings:
		b_arr.append(str(b))
	var q_arr: Array = []
	for qi in queue:
		q_arr.append(qi.to_dict())
	return {
		"id": id,
		"planet_id": planet_id,
		"owner": owner,
		"species": species,
		"pop_milli": pop_milli,
		"farmers": farmers,
		"workers": workers,
		"scientists": scientists,
		"jobs_locked": jobs_locked,
		"preset": preset,
		"buildings": b_arr,
		"queue": q_arr,
		"progress_pp": progress_pp,
		"occupied_until": occupied_until,
		"garrison": garrison,
		"defense_hp": defense_hp,
		"blockaded": blockaded,
		"bombarded_by": bombarded_by.duplicate(),
		"founded_turn": founded_turn,
		"is_outpost": is_outpost
	}

static func from_dict(d: Dictionary) -> Colony:
	var c: Colony = Colony.new()
	c.id = int(d.get("id", -1))
	c.planet_id = int(d.get("planet_id", -1))
	c.owner = int(d.get("owner", -1))
	c.species = str(d.get("species", ""))
	c.pop_milli = int(d.get("pop_milli", 0))
	c.farmers = int(d.get("farmers", 0))
	c.workers = int(d.get("workers", 0))
	c.scientists = int(d.get("scientists", 0))
	c.jobs_locked = bool(d.get("jobs_locked", false))
	c.preset = str(d.get("preset", "frontier"))
	c.buildings.clear()
	var raw_b: Array = d.get("buildings", [])
	for b in raw_b:
		c.buildings.append(str(b))
	c.queue.clear()
	var raw_q: Array = d.get("queue", [])
	for qi_data in raw_q:
		if qi_data is Dictionary:
			c.queue.append(QueueItem.from_dict(qi_data))
	c.progress_pp = int(d.get("progress_pp", 0))
	c.occupied_until = int(d.get("occupied_until", -1))
	c.garrison = int(d.get("garrison", 0))
	c.defense_hp = int(d.get("defense_hp", 0))
	c.blockaded = bool(d.get("blockaded", false))
	c.bombarded_by.clear()
	var raw_bb: Array = d.get("bombarded_by", [])
	for x in raw_bb:
		c.bombarded_by.append(int(x))
	c.founded_turn = int(d.get("founded_turn", 1))
	c.is_outpost = bool(d.get("is_outpost", false))
	return c
