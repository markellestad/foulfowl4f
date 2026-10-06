class_name CmdAnswerProposal
extends Cmd

var proposal_id: int = -1
var accept: bool = false

func kind() -> StringName:
	return &"answer_proposal"

func validate(gs: GameState, _db: ContentDB) -> String:
	var found: Dictionary = {}
	for p in gs.proposals:
		if int(p.get("id", -1)) == proposal_id:
			found = p
			break
	if found.is_empty():
		return "refuse.unknown"
	if int(found.get("to_empire", -1)) != empire_id:
		return "refuse.not_owner"
	return ""

func apply(gs: GameState, db: ContentDB) -> void:
	var idx: int = -1
	var found: Dictionary = {}
	for i in range(gs.proposals.size()):
		if int(gs.proposals[i].get("id", -1)) == proposal_id:
			idx = i
			found = gs.proposals[i]
			break
	if idx >= 0:
		gs.proposals.remove_at(idx)
		if accept and str(found.get("kind", "")) == "peace":
			var from_emp: int = int(found.get("from_empire", -1))
			Wars.set_war(gs, from_emp, empire_id, false)
			var truce_turns: int = db.bal("truce_turns")
			Wars.set_truce(gs, from_emp, empire_id, truce_turns)

func to_dict() -> Dictionary:
	var d: Dictionary = super.to_dict()
	d["proposal_id"] = proposal_id
	d["accept"] = accept
	return d

func load_dict(d: Dictionary) -> void:
	super.load_dict(d)
	proposal_id = int(d.get("proposal_id", -1))
	accept = bool(d.get("accept", false))
