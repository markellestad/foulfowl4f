class_name StepDiplomacy
extends TurnStep

func id() -> StringName:
	return &"diplomacy"

func begin(_ctx: TurnContext) -> void:
	pass

func next(ctx: TurnContext) -> bool:
	var gs: GameState = ctx.gs
	var db: ContentDB = ctx.db

	# 1. Clean up expired truces
	var expired_truces: Array = []
	for k in gs.truces.keys():
		if int(gs.truces[k]) < gs.turn:
			expired_truces.append(k)
	for k in expired_truces:
		gs.truces.erase(k)

	# 2. Resolve proposals targeted at AI empires
	var remaining_proposals: Array[Dictionary] = []
	for prop in gs.proposals:
		var to_emp: int = int(prop.get("to_empire", -1))
		if to_emp < 0 or to_emp >= gs.empires.size():
			continue

		var emp: Empire = gs.empires[to_emp]
		var is_ai_emp: bool = emp.is_ai or (gs.settings != null and gs.settings.all_ai)
		if is_ai_emp:
			if str(prop.get("kind", "")) == "peace":
				var from_emp: int = int(prop.get("from_empire", -1))
				var view: AiView = AiView.build(gs, db, to_emp)
				if AiWar.wants_peace(view, from_emp):
					Wars.set_war(gs, from_emp, to_emp, false)
					var truce_turns: int = db.bal("truce_turns")
					Wars.set_truce(gs, from_emp, to_emp, truce_turns)
			# AI resolved proposal (accepted or rejected); do not keep
		else:
			# Player proposal: keep for player to answer
			remaining_proposals.append(prop)

	gs.proposals = remaining_proposals
	return true
