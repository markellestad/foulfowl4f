class_name StepAiPlan
extends TurnStep

var _substep_queue: Array[Dictionary] = []

func id() -> StringName:
	return &"ai_plan"

func begin(ctx: TurnContext) -> void:
	_substep_queue.clear()
	var all_ai: bool = ctx.gs.settings != null and ctx.gs.settings.all_ai

	for eid in range(ctx.gs.empires.size()):
		if eid == 0 and not all_ai:
			continue
		if ctx.gs.empires[eid].eliminated_turn >= 0:
			continue

		var view: AiView = AiView.build(ctx.gs, ctx.db, eid)
		var eco_cmds: Array[Cmd] = []
		if ctx.tp != null and ctx.tp.ai_held.has(eid):
			eco_cmds = ctx.tp.ai_held[eid]
			ctx.tp.ai_held.erase(eid)
		else:
			eco_cmds = AiPlayer.plan_economy(view)

		for cmd in eco_cmds:
			var err: String = cmd.validate(ctx.gs, ctx.db)
			if err != "":
				SimLog.warn("AI_REJECT: %s %s" % [cmd.kind(), err])
			else:
				cmd.apply(ctx.gs, ctx.db)

		for w_sub in AiPlayer.war_substeps():
			_substep_queue.append({
				"empire_id": eid,
				"substep": w_sub
			})

func next(ctx: TurnContext) -> bool:
	if _substep_queue.is_empty():
		return true

	var item: Dictionary = _substep_queue.pop_front()
	var eid: int = int(item["empire_id"])
	var substep: StringName = item["substep"]

	if ctx.gs.empires[eid].eliminated_turn >= 0:
		return _substep_queue.is_empty()

	if not ctx.gs.ai_memory.has(eid):
		ctx.gs.ai_memory[eid] = AiMemory.new()
	var memory: AiMemory = ctx.gs.ai_memory[eid]

	var view: AiView = AiView.build(ctx.gs, ctx.db, eid)
	var cmds: Array[Cmd] = AiPlayer.plan_war_substep(view, substep, memory)

	for cmd in cmds:
		var err: String = cmd.validate(ctx.gs, ctx.db)
		if err != "":
			SimLog.warn("AI_REJECT: %s %s" % [cmd.kind(), err])
		else:
			cmd.apply(ctx.gs, ctx.db)

	return _substep_queue.is_empty()
