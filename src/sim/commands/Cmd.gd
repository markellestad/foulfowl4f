class_name Cmd
extends RefCounted

var empire_id: int = -1

func kind() -> StringName:
	return &""

func validate(_gs: GameState, _db: ContentDB) -> String:
	return ""

func apply(_gs: GameState, _db: ContentDB) -> void:
	pass

func to_dict() -> Dictionary:
	return {
		"kind": str(kind()),
		"empire_id": empire_id
	}

func load_dict(d: Dictionary) -> void:
	empire_id = int(d.get("empire_id", -1))
