class_name CmdSetPreset
extends Cmd

var colony_id: int = -1
var preset: String = ""

func kind() -> StringName:
	return &"set_preset"

func validate(gs: GameState, db: ContentDB) -> String:
	if not gs.colonies.has(colony_id):
		return "refuse.unknown"
	var col: Colony = gs.colonies[colony_id]
	if col.owner != empire_id:
		return "refuse.not_owner"
	var pdef: Dictionary = db.def("presets", preset)
	if pdef.is_empty():
		return "refuse.unknown"
	return ""

func apply(gs: GameState, _db: ContentDB) -> void:
	var col: Colony = gs.colonies[colony_id]
	col.preset = preset
	if preset != "manual":
		col.jobs_locked = false

func to_dict() -> Dictionary:
	var d: Dictionary = super.to_dict()
	d["colony_id"] = colony_id
	d["preset"] = preset
	return d

func load_dict(d: Dictionary) -> void:
	super.load_dict(d)
	colony_id = int(d.get("colony_id", -1))
	preset = str(d.get("preset", ""))
