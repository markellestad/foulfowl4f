class_name TurnProcessor
extends RefCounted

enum Status { RUNNING, NEEDS_INPUT, DONE }

const STEP_ORDER: Array[StringName] = [
	&"movement",
	&"production",
	&"population",
	&"finance",
	&"governor",
	&"finalize"
]

var gs: GameState
var db: ContentDB
var report: TurnReport
var ctx: TurnContext
var status: Status = Status.RUNNING
var step_index: int = 0
var current_step: TurnStep = null

func _init(p_gs: GameState, p_db: ContentDB) -> void:
	gs = p_gs
	db = p_db
	report = TurnReport.new()
	report.turn = gs.turn
	ctx = TurnContext.new()
	ctx.gs = gs
	ctx.db = db
	ctx.report = report
	status = Status.RUNNING
	step_index = 0
	_advance_to_step(0)

func _create_step(step_name: StringName) -> TurnStep:
	match step_name:
		&"movement":
			return StepMovement.new()
		&"production":
			return StepProduction.new()
		&"population":
			return StepPopulation.new()
		&"finance":
			return StepFinance.new()
		&"governor":
			return StepGovernor.new()
		&"finalize":
			return StepFinalize.new()
		_:
			return null

func _advance_to_step(idx: int) -> void:
	if idx >= STEP_ORDER.size():
		status = Status.DONE
		current_step = null
		return
	step_index = idx
	var sname: StringName = STEP_ORDER[idx]
	current_step = _create_step(sname)
	if current_step != null:
		current_step.begin(ctx)
	else:
		_advance_to_step(idx + 1)

func run_next_substep() -> int:
	if status == Status.DONE:
		return Status.DONE

	if current_step != null:
		var step_done: bool = current_step.next(ctx)
		if step_done:
			var errs: Array[String] = Invariants.check(gs, db)
			for err in errs:
				SimLog.warn("INVARIANT: %s" % err)
			_advance_to_step(step_index + 1)

	return status

func run_all() -> void:
	while status != Status.DONE:
		run_next_substep()

func progress_pct() -> int:
	if status == Status.DONE:
		return 100
	return IntMath.floor_div(step_index * 100, STEP_ORDER.size())
