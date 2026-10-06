class_name StepVictory
extends TurnStep

func id() -> StringName:
	return &"victory"

func begin(_ctx: TurnContext) -> void:
	pass

func next(ctx: TurnContext) -> bool:
	Victory.check_victory(ctx.db, ctx.gs)
	return true
