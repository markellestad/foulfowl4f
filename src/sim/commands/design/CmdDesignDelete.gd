class_name CmdDesignDelete
extends Cmd

var design_id: int = -1

func kind() -> StringName:
	return &"design_delete"

func validate(gs: GameState, _db: ContentDB) -> String:
	if not gs.designs.has(design_id):
		return "refuse.unknown"
	var des: ShipDesign = gs.designs[design_id]
	if des.empire_id != empire_id:
		return "refuse.not_owner"

	for col in gs.colonies.values():
		for item in col.queue:
			if item.kind == "ship" and item.ref_id == str(design_id):
				return "refuse.design_in_use"

	return ""

func apply(gs: GameState, _db: ContentDB) -> void:
	if gs.designs.has(design_id):
		gs.designs[design_id].obsolete = true

func to_dict() -> Dictionary:
	var d: Dictionary = super.to_dict()
	d["design_id"] = design_id
	return d

func load_dict(d: Dictionary) -> void:
	super.load_dict(d)
	design_id = int(d.get("design_id", -1))
