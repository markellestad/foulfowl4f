class_name AiDesign
extends RefCounted

static func plan(view: AiView) -> Array[Cmd]:
	var cmds: Array[Cmd] = []
	var own_designs: Array[ShipDesign] = view.own_designs()
	var active_count: int = 0
	for d in own_designs:
		if not d.obsolete:
			active_count += 1

	var max_designs: int = view.db.bal("max_designs")
	var roles_to_check: Array[String] = [
		"talon_line",
		"nest_ship",
		"stake_ship",
		"boot_ship",
		"glance",
		"swat_escort",
		"beak_line"
	]

	for role in roles_to_check:
		if active_count >= max_designs:
			break

		var auto_des: ShipDesign = AutoDesign.design_for_role(view.db, view.raw_game_state_DO_NOT_USE_EXCEPT_SIM(), view.empire_id, role)
		if auto_des == null:
			continue

		var exists: bool = false
		for d in own_designs:
			if not d.obsolete and _matches(d, auto_des):
				exists = true
				break

		if not exists:
			var cmd: CmdDesignSave = CmdDesignSave.new()
			cmd.empire_id = view.empire_id
			cmd.design_data = auto_des.to_dict()
			cmds.append(cmd)
			active_count += 1

	return cmds

static func _matches(a: ShipDesign, b: ShipDesign) -> bool:
	return a.hull == b.hull and a.drive == b.drive and a.plate == b.plate and \
		a.mantle == b.mantle and a.computer == b.computer and \
		a.specials == b.specials and a.weapons == b.weapons
