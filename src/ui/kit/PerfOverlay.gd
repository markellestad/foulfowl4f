class_name PerfOverlay
extends CanvasLayer

var end_turn_worst_ms: int = 0

var _label: Label = null
var _recent_deltas: Array[float] = []
var _time_accum: float = 0.0

func _init() -> void:
	layer = 100

func _ready() -> void:
	visible = _should_show()

	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_label.offset_left = -220
	_label.offset_top = 10
	_label.offset_right = -10
	_label.offset_bottom = 80
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.theme_type_variation = &"Muted"
	add_child(_label)

func _should_show() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg == "--perf":
			return true
	if OS.has_feature("web"):
		var search: Variant = JavaScriptBridge.eval("window.location.search", true)
		if search != null and str(search).contains("perf=1"):
			return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_QUOTELEFT:
			visible = not visible
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not visible:
		return

	_recent_deltas.append(delta)
	_time_accum += delta
	while _time_accum > 5.0 and not _recent_deltas.is_empty():
		_time_accum -= _recent_deltas.pop_front()

	var worst_ms: float = 0.0
	for d in _recent_deltas:
		var ms: float = d * 1000.0
		if ms > worst_ms:
			worst_ms = ms

	var fps: int = Engine.get_frames_per_second()
	_label.text = "FPS: %d\nWorst (5s): %.1f ms\nEndTurn: %d ms" % [fps, worst_ms, end_turn_worst_ms]
