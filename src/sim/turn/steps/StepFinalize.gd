class_name StepFinalize
extends TurnStep

func id() -> StringName:
	return &"finalize"

func begin(_ctx: TurnContext) -> void:
	pass

func next(ctx: TurnContext) -> bool:
	for emp in ctx.gs.empires:
		var kept: Array[TimedMod] = []
		for tm in emp.timed_mods:
			if ctx.gs.turn <= tm.until_turn:
				kept.append(tm)
		emp.timed_mods = kept

	ctx.gs.turn += 1
	ctx.gs.report = ctx.report
	return true
