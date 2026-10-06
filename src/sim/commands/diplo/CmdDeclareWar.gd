class_name CmdDeclareWar
extends Cmd

var target_empire: int = -1

func kind() -> StringName:
	return &"declare_war"

func validate(gs: GameState, _db: ContentDB) -> String:
	if target_empire < 0 or target_empire >= gs.empires.size() or target_empire == empire_id:
		return "refuse.unknown"
	if target_empire == gs.monsters_empire:
		return "refuse.unknown"
	var knw: Knowledge = gs.knowledge.get(empire_id)
	if knw == null or not knw.met.has(target_empire):
		return "refuse.not_met"
	if Wars.is_at_war(gs, empire_id, target_empire):
		return "refuse.already_at_war"
	if Wars.is_in_truce(gs, empire_id, target_empire):
		return "refuse.truce"
	return ""

func apply(gs: GameState, _db: ContentDB) -> void:
	Wars.set_war(gs, empire_id, target_empire, true)
	var key: String = Wars._pair_key(empire_id, target_empire)
	gs.war_started_turn[key] = gs.turn
	gs.war_declarer[key] = empire_id

	var race_a: String = gs.empires[empire_id].race if (empire_id >= 0 and empire_id < gs.empires.size()) else str(empire_id)
	var race_b: String = gs.empires[target_empire].race if (target_empire >= 0 and target_empire < gs.empires.size()) else str(target_empire)

	gs.news.append({
		"key": "news.war",
		"args": {"a": race_a, "b": race_b},
		"turn": gs.turn
	})

func to_dict() -> Dictionary:
	var d: Dictionary = super.to_dict()
	d["target_empire"] = target_empire
	return d

func load_dict(d: Dictionary) -> void:
	super.load_dict(d)
	target_empire = int(d.get("target_empire", -1))
