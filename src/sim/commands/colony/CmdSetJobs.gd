class_name CmdSetJobs
extends Cmd

var colony_id: int = -1
var farmers: int = 0
var workers: int = 0
var scientists: int = 0
var lock: bool = false

func kind() -> StringName:
	return &"set_jobs"

func validate(gs: GameState, _db: ContentDB) -> String:
	if not gs.colonies.has(colony_id):
		return "refuse.unknown"
	var col: Colony = gs.colonies[colony_id]
	if col.owner != empire_id:
		return "refuse.not_owner"
	if farmers < 0 or workers < 0 or scientists < 0:
		return "refuse.invalid_jobs"
	var sum_jobs: int = farmers + workers + scientists
	if sum_jobs != col.pop_units():
		return "refuse.jobs_sum"
	return ""

func apply(gs: GameState, _db: ContentDB) -> void:
	var col: Colony = gs.colonies[colony_id]
	col.farmers = farmers
	col.workers = workers
	col.scientists = scientists
	col.jobs_locked = lock

func to_dict() -> Dictionary:
	var d: Dictionary = super.to_dict()
	d["colony_id"] = colony_id
	d["farmers"] = farmers
	d["workers"] = workers
	d["scientists"] = scientists
	d["lock"] = lock
	return d

func load_dict(d: Dictionary) -> void:
	super.load_dict(d)
	colony_id = int(d.get("colony_id", -1))
	farmers = int(d.get("farmers", 0))
	workers = int(d.get("workers", 0))
	scientists = int(d.get("scientists", 0))
	lock = bool(d.get("lock", false))
