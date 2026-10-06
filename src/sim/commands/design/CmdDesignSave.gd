class_name CmdDesignSave
extends Cmd

var design_data: Dictionary = {}

func kind() -> StringName:
	return &"design_save"

func validate(gs: GameState, db: ContentDB) -> String:
	if empire_id < 0 or empire_id >= gs.empires.size():
		return "refuse.unknown"
	if design_data.is_empty():
		return "refuse.unknown"

	var des: ShipDesign = ShipDesign.from_dict(design_data)
	des.empire_id = empire_id

	if des.id >= 0:
		if not gs.designs.has(des.id):
			return "refuse.unknown"
		if gs.designs[des.id].empire_id != empire_id:
			return "refuse.not_owner"
	else:
		var active_count: int = 0
		for d in gs.designs.values():
			if d.empire_id == empire_id and not d.obsolete:
				active_count += 1
		if active_count >= db.bal("max_designs"):
			return "refuse.design_limit"

	var err: String = DesignRules.validate(db, gs, des)
	if err != "":
		return err

	return ""

func apply(gs: GameState, _db: ContentDB) -> void:
	var des: ShipDesign = ShipDesign.from_dict(design_data)
	des.empire_id = empire_id
	if des.id < 0:
		des.id = gs.alloc_id("design")
	gs.designs[des.id] = des

func to_dict() -> Dictionary:
	var d: Dictionary = super.to_dict()
	d["design_data"] = design_data.duplicate(true)
	return d

func load_dict(d: Dictionary) -> void:
	super.load_dict(d)
	design_data = (d.get("design_data", {}) as Dictionary).duplicate(true)
