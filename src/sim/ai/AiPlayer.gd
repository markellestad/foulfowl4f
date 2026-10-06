class_name AiPlayer
extends RefCounted

static func plan_economy(view: AiView) -> Array[Cmd]:
	var cmds: Array[Cmd] = []
	cmds.append_array(AiColonies.plan(view))
	cmds.append_array(AiDesign.plan(view))
	cmds.append_array(AiProduction.plan(view))
	return cmds

static func war_substeps() -> Array[StringName]:
	return [&"assess", &"expansion", &"military", &"war", &"diplomacy", &"espionage"]

static func plan_war_substep(view: AiView, substep: StringName, memory: AiMemory) -> Array[Cmd]:
	match substep:
		&"assess":
			return AiAssess.plan(view, memory)
		&"expansion":
			return AiExpansion.plan(view, memory)
		&"military":
			return AiMilitary.plan(view, memory)
		&"war":
			return AiWar.plan(view, memory)
		&"diplomacy":
			return []
		&"espionage":
			return []
		_:
			return []
