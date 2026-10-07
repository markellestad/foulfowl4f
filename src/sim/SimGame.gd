class_name SimGame
extends RefCounted

var gs: GameState
var db: ContentDB
var turn_cmds: Array[Cmd] = []
var redo_cmds: Array[Cmd] = []
var checkpoints: Dictionary = {} # index -> GameState.to_dict()
var oldest_undoable_index: int = 0
var last_report: TurnReport = null
var metadata: Dictionary = {}
var current_tp: TurnProcessor = null
var ai_held: Dictionary = {} # empire_id -> Array[Cmd]

static func create(settings: GameSettings, db: ContentDB) -> SimGame:
	var game: SimGame = SimGame.new()
	game.db = db
	game.gs = GalaxyGenerator.generate(settings, db)
	StartState.apply(game.gs, db)
	game.checkpoints[0] = game.gs.to_dict()
	return game

static func from_state(p_gs: GameState, p_db: ContentDB) -> SimGame:
	var game: SimGame = SimGame.new()
	game.db = p_db
	game.gs = p_gs
	game.checkpoints[0] = game.gs.to_dict()
	return game

func submit(cmd: Cmd) -> String:
	var refusal: String = cmd.validate(gs, db)
	if refusal != "":
		return refusal

	cmd.apply(gs, db)
	turn_cmds.append(cmd)
	redo_cmds.clear()

	var undo_every: int = db.bal("undo_checkpoint_every")
	if undo_every > 0 and turn_cmds.size() % undo_every == 0:
		checkpoints[turn_cmds.size()] = gs.to_dict()

	var undo_max: int = db.bal("undo_max")
	if undo_max > 0 and turn_cmds.size() - oldest_undoable_index > undo_max:
		oldest_undoable_index = turn_cmds.size() - undo_max

	return ""

func submit_ai(cmd: Cmd) -> String:
	if cmd == null:
		return "refuse.null"
	var refusal: String = cmd.validate(gs, db)
	if refusal != "":
		SimLog.warn("AI_REJECT: %s %s" % [cmd.kind(), refusal])
		return refusal
	cmd.apply(gs, db)
	return ""

func can_undo() -> bool:
	return turn_cmds.size() > oldest_undoable_index

func can_redo() -> bool:
	return not redo_cmds.is_empty()

func undo() -> bool:
	if not can_undo():
		return false

	ai_held.clear()
	var last_cmd: Cmd = turn_cmds.pop_back()
	redo_cmds.append(last_cmd)
	var target_size: int = turn_cmds.size()

	for k in checkpoints.keys():
		if int(k) > target_size:
			checkpoints.erase(k)

	var best_k: int = 0
	for k in checkpoints.keys():
		var ik: int = int(k)
		if ik <= target_size and ik > best_k:
			best_k = ik

	gs = GameState.from_dict(checkpoints[best_k])
	for i in range(best_k, target_size):
		var c: Cmd = turn_cmds[i]
		var v_err: String = c.validate(gs, db)
		if v_err != "":
			SimLog.warn("UNDO_DIVERGED: %s" % v_err)
		c.apply(gs, db)

	return true

func redo() -> bool:
	if not can_redo():
		return false

	ai_held.clear()
	var cmd: Cmd = redo_cmds.pop_back()
	var err: String = cmd.validate(gs, db)
	if err != "":
		SimLog.warn("REDO_DIVERGED: %s" % err)
		return false

	cmd.apply(gs, db)
	turn_cmds.append(cmd)

	var undo_every: int = db.bal("undo_checkpoint_every")
	if undo_every > 0 and turn_cmds.size() % undo_every == 0:
		checkpoints[turn_cmds.size()] = gs.to_dict()

	var undo_max: int = db.bal("undo_max")
	if undo_max > 0 and turn_cmds.size() - oldest_undoable_index > undo_max:
		oldest_undoable_index = turn_cmds.size() - undo_max

	return true

func precompute_step() -> bool:
	if gs == null or gs.game_over:
		return false

	var all_ai: bool = (gs.settings != null and gs.settings.all_ai)
	for eid in range(gs.empires.size()):
		if eid == 0 and not all_ai:
			continue
		if ai_held.has(eid):
			continue

		var view: AiView = AiView.build(gs, db, eid)
		ai_held[eid] = AiPlayer.plan_economy(view)
		return true

	return false

func begin_end_turn() -> TurnProcessor:
	for c in turn_cmds:
		gs.cmd_log.append({
			"turn": gs.turn,
			"source": "player",
			"cmd": c.to_dict()
		})
	turn_cmds.clear()
	redo_cmds.clear()
	checkpoints.clear()
	oldest_undoable_index = 0
	current_tp = TurnProcessor.new(gs, db, ai_held)
	ai_held.clear()
	return current_tp

func finish_end_turn() -> void:
	current_tp = null
	if gs.settings == null or not gs.settings.all_ai:
		checkpoints[0] = gs.to_dict()

func end_turn_headless() -> void:
	var tp: TurnProcessor = begin_end_turn()
	tp.run_all()
	last_report = tp.report
	finish_end_turn()

func answer_battle_orders(cmds: Array) -> String:
	for c in cmds:
		var cmd: CmdBattleOrders = c as CmdBattleOrders
		if cmd == null:
			return "refuse.unknown"
		var err: String = cmd.validate(gs, db)
		if err != "":
			return err
	for c in cmds:
		var cmd: CmdBattleOrders = c as CmdBattleOrders
		gs.cmd_log.append({
			"turn": gs.turn,
			"source": "battle",
			"cmd": cmd.to_dict()
		})
	if current_tp != null:
		return current_tp.answer_battle_orders(cmds)
	return ""

func state_hash() -> int:
	return StateHash.of_value(gs.to_dict())
