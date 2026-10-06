class_name AiProduction
extends RefCounted

static func plan(view: AiView) -> Array[Cmd]:
	var cmds: Array[Cmd] = []
	var emp: Empire = view.own_empire()
	var desired_policy: String = "peace"

	if view.active_wars_count() > 0:
		desired_policy = "war"
	else:
		# Check contact with rival colony within budget_switch_contact_dpc
		var contact_dpc: int = view.db.bal("budget_switch_contact_dpc")
		var close_rival_contact: bool = false
		var own_cols: Array[Colony] = view.own_colonies()
		var seen_cols: Dictionary = view.seen_colonies()

		for cid in seen_cols.keys():
			var c_data: Dictionary = seen_cols[cid]
			var owner: int = int(c_data.get("owner", -1))
			if owner >= 0 and owner != view.empire_id:
				# Find planet and system of seen colony
				var p: Planet = view.planet(cid) # cid is colony id, planet_id? Wait, in seen_colonies cid is colony_id
				var target_sys: StarSystem = null
				if p != null:
					target_sys = view.system(p.system_id)
				if target_sys != null:
					for o_col in own_cols:
						var op: Planet = view.planet(o_col.planet_id)
						if op != null:
							var os: StarSystem = view.system(op.system_id)
							if os != null and IntMath.dist(os.x, os.y, target_sys.x, target_sys.y) <= contact_dpc:
								close_rival_contact = true
								break
				if close_rival_contact:
					break

		if close_rival_contact:
			desired_policy = "war"
		elif view.met_empires().size() > 0:
			desired_policy = "guarded"
		else:
			desired_policy = "peace"

	if emp.military_budget != desired_policy:
		var cmd: CmdSetMilitaryBudget = CmdSetMilitaryBudget.new()
		cmd.empire_id = view.empire_id
		cmd.policy = desired_policy
		cmds.append(cmd)

	return cmds
