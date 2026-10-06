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
		_:
			return null

	cmd.load_dict(d)
	return cmd
