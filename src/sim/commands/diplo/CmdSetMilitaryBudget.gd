class_name CmdSetMilitaryBudget
extends Cmd

var policy: String = "guarded"

func kind() -> StringName:
	return &"set_military_budget"

func validate(gs: GameState, _db: ContentDB) -> String:
	if empire_id < 0 or empire_id >= gs.empires.size():
		return "refuse.unknown"
	if not (policy in ["peace", "guarded", "war"]):
		return "refuse.invalid_policy"
	return ""

func apply(gs: GameState, _db: ContentDB) -> void:
	gs.empires[empire_id].military_budget = policy

func to_dict() -> Dictionary:
	var d: Dictionary = super.to_dict()
	d["policy"] = policy
	return d

func load_dict(d: Dictionary) -> void:
	super.load_dict(d)
	policy = str(d.get("policy", "guarded"))
