class_name CmdProposePeace
extends Cmd

var target_empire: int = -1

func kind() -> StringName:
	return &"propose_peace"

func validate(gs: GameState, _db: ContentDB) -> String:
	if target_empire < 0 or target_empire >= gs.empires.size() or target_empire == empire_id:
		return "refuse.unknown"
	if not Wars.is_at_war(gs, empire_id, target_empire):
		return "refuse.not_at_war"
	for prop in gs.proposals:
		if str(prop.get("kind", "")) == "peace" and int(prop.get("from_empire", -1)) == empire_id and int(prop.get("to_empire", -1)) == target_empire:
			return "refuse.already_proposed"
	return ""

func apply(gs: GameState, _db: ContentDB) -> void:
	var pid: int = gs.alloc_id("proposal")
	gs.proposals.append({
		"id": pid,
		"kind": "peace",
		"from_empire": empire_id,
		"to_empire": target_empire,
		"turn": gs.turn
	})

func to_dict() -> Dictionary:
	var d: Dictionary = super.to_dict()
	d["target_empire"] = target_empire
	return d

func load_dict(d: Dictionary) -> void:
	super.load_dict(d)
	target_empire = int(d.get("target_empire", -1))
