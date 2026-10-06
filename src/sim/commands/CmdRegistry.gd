class_name CmdRegistry
extends RefCounted

static func from_dict(d: Dictionary) -> Cmd:
	var kind: String = str(d.get("kind", ""))
	var cmd: Cmd = null
	match kind:
		"set_preset":
			cmd = CmdSetPreset.new()
		"set_jobs":
			cmd = CmdSetJobs.new()
		"queue_add":
			cmd = CmdQueueAdd.new()
		"queue_remove":
			cmd = CmdQueueRemove.new()
		"queue_move":
			cmd = CmdQueueMove.new()
		"queue_set_repeat":
			cmd = CmdQueueSetRepeat.new()
		"buy":
			cmd = CmdBuy.new()
		"design_save":
			cmd = CmdDesignSave.new()
		"design_delete":
			cmd = CmdDesignDelete.new()
		"fleet_move":
			cmd = CmdFleetMove.new()
		"fleet_split":
			cmd = CmdFleetSplit.new()
		"fleet_merge":
			cmd = CmdFleetMerge.new()
		"fleet_auto_explore":
			cmd = CmdFleetAutoExplore.new()
		"colonize":
			cmd = CmdColonize.new()
		"outpost":
			cmd = CmdOutpost.new()
		"set_battle_plan":
			cmd = CmdSetBattlePlan.new()
		"set_line_order":
			cmd = CmdSetLineOrder.new()
		"fleet_bombard":
			cmd = CmdFleetBombard.new()
		"fleet_invade":
			cmd = CmdFleetInvade.new()
		"battle_orders":
			cmd = CmdBattleOrders.new()
		"declare_war":
			cmd = CmdDeclareWar.new()
		"propose_peace":
			cmd = CmdProposePeace.new()
		"answer_proposal":
			cmd = CmdAnswerProposal.new()
		"set_military_budget":
			cmd = CmdSetMilitaryBudget.new()
		"accept_capitulation":
			cmd = CmdAcceptCapitulation.new()
		_:
			return null

	cmd.load_dict(d)
	return cmd
