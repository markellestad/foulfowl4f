class_name TurnStep
extends RefCounted

func id() -> StringName:
	return &""

func begin(_ctx: TurnContext) -> void:
	pass

func next(_ctx: TurnContext) -> bool:
	return true
