class_name CmdAcceptCapitulation
extends Cmd

var offer_id: int = -1
var accept: bool = true

func kind() -> StringName:
	return &"accept_capitulation"

func _find_offer_index(gs: GameState) -> int:
	for i in range(gs.capitulation_offers.size()):
		if int(gs.capitulation_offers[i].get("id", -1)) == offer_id:
			return i
	return -1

func validate(gs: GameState, _db: ContentDB) -> String:
	var idx: int = _find_offer_index(gs)
	if idx < 0:
		return "refuse.unknown"
	var offer: Dictionary = gs.capitulation_offers[idx]
	if int(offer.get("to_empire", -1)) != empire_id:
		return "refuse.not_owner"
	return ""

func apply(gs: GameState, db: ContentDB) -> void:
	var idx: int = _find_offer_index(gs)
	if idx < 0:
		return
	var offer: Dictionary = gs.capitulation_offers[idx]
	var from_id: int = int(offer.get("from_empire", -1))
	var to_id: int = int(offer.get("to_empire", -1))
	gs.capitulation_offers.remove_at(idx)

	if accept:
		Capitulation.transfer_and_eliminate(db, gs, from_id, to_id)

func to_dict() -> Dictionary:
	var d: Dictionary = super.to_dict()
	d["offer_id"] = offer_id
	d["accept"] = accept
	return d

func load_dict(d: Dictionary) -> void:
	super.load_dict(d)
	offer_id = int(d.get("offer_id", -1))
	accept = bool(d.get("accept", true))
