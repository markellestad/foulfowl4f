class_name TurnRunner
extends Node

var tp: TurnProcessor = null
var running: bool = false
var worst_turn_frame_ms: int = 0
var slice_budget_us: int = 6000

func _ready() -> void:
	set_process(false)

func is_running() -> bool:
	return running

func start_turn() -> void:
	if running or Session.game == null:
		return
	running = true
	worst_turn_frame_ms = 0
	if Session.db != null:
		slice_budget_us = Session.db.bal("turn_slice_budget_us")
	tp = Session.game.begin_end_turn()
	set_process(true)

func _process(_delta: float) -> void:
	if not running or tp == null:
		set_process(false)
		return

	var frame_start: int = Time.get_ticks_usec()
	while running and tp != null:
		var st: int = tp.run_next_substep()
		Session.turn_processing.emit(tp.progress_pct())

		if st == TurnProcessor.Status.DONE:
			running = false
			set_process(false)
			Session.game.finish_end_turn()
			var rep: TurnReport = tp.report
			tp = null
			Session.autosave_on_turn_end()
			Session.state_changed.emit("turn", [])
			Session.turn_started.emit(rep)
			break

		var elapsed: int = Time.get_ticks_usec() - frame_start
		if elapsed >= slice_budget_us:
			break

	var frame_dur_us: int = Time.get_ticks_usec() - frame_start
	var frame_ms: int = IntMath.ceil_div(frame_dur_us, 1000)
	if frame_ms > worst_turn_frame_ms:
		worst_turn_frame_ms = frame_ms
		if PerfOverlay.instance != null:
			PerfOverlay.instance.end_turn_worst_ms = worst_turn_frame_ms
