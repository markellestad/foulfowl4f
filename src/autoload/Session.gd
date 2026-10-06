extends Node

signal state_changed(scope: String, ids: Array)
signal turn_processing(pct: int)
signal turn_started(report: TurnReport)

var db: ContentDB = null
var game: SimGame = null
var turn_runner: TurnRunner = null
var _settings: GameSettings = null
var _state: GameState = null

var settings: GameSettings:
	get:
		if game != null and game.gs != null:
			return game.gs.settings
		return _settings
	set(v):
		_settings = v

var state: GameState:
	get:
		if game != null and game.gs != null:
			return game.gs
		return _state
	set(v):
		_state = v

func _ready() -> void:
	db = ContentDB.load_from("res://data")
	turn_runner = TurnRunner.new()
	turn_runner.name = "TurnRunner"
	add_child(turn_runner)

func new_game(p_settings: GameSettings) -> void:
	_settings = p_settings
	game = SimGame.create(p_settings, db)
	_state = game.gs
	state_changed.emit("all", [])

func start_galaxy(p_settings: GameSettings) -> void:
	new_game(p_settings)

func submit(cmd: Cmd) -> String:
	if game == null:
		return "no_game"
	var err: String = game.submit(cmd)
	if err == "":
		state_changed.emit("cmd", [cmd.kind])
	return err

func can_undo() -> bool:
	return game != null and game.can_undo()

func can_redo() -> bool:
	return game != null and game.can_redo()

func undo() -> bool:
	if game == null or not can_undo():
		return false
	var ok: bool = game.undo()
	if ok:
		state_changed.emit("undo", [])
	return ok

func redo() -> bool:
	if game == null or not can_redo():
		return false
	var ok: bool = game.redo()
	if ok:
		state_changed.emit("redo", [])
	return ok

func end_turn() -> void:
	if is_turn_running() or game == null:
		return
	turn_runner.start_turn()

func end_turn_sync() -> void:
	if game == null:
		return
	game.end_turn_headless()
	autosave_on_turn_end()
	state_changed.emit("turn", [])
	turn_started.emit(game.gs.report)

func is_turn_running() -> bool:
	return turn_runner != null and turn_runner.is_running()

func _ensure_saves_dir() -> void:
	DirAccess.make_dir_recursive_absolute("user://saves")

func save_game(slot: String) -> String:
	if game == null or game.gs == null:
		return "no_game"
	_ensure_saves_dir()
	var summary: Dictionary = {
		"turn": game.gs.turn,
		"player_race": game.gs.settings.player_race if game.gs.settings != null else ""
	}
	var bytes: PackedByteArray = Serializer.to_bytes(game.gs, summary)
	var tmp_path: String = "user://saves/%s.tmp" % slot
	var sav_path: String = "user://saves/%s.sav" % slot

	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return "cannot_open_write"
	file.store_buffer(bytes)
	file.close()

	if FileAccess.file_exists(sav_path):
		DirAccess.remove_absolute(sav_path)
	var ren_err: Error = DirAccess.rename_absolute(tmp_path, sav_path)
	if ren_err != OK:
		return "rename_failed"
	return ""

func load_game(slot: String) -> String:
	var sav_path: String = "user://saves/%s.sav" % slot
	if not FileAccess.file_exists(sav_path):
		return "file_not_found"

	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(sav_path)
	var res: Dictionary = Serializer.from_bytes(bytes)
	if not bool(res.get("ok", false)):
		return str(res.get("error", "corrupt_save"))

	var loaded_gs: GameState = res.get("state") as GameState
	if loaded_gs == null:
		return "null_state"

	game = SimGame.from_state(loaded_gs, db)
	_settings = loaded_gs.settings
	_state = game.gs
	state_changed.emit("all", [])
	return ""

func _autosave_slots() -> Array[String]:
	var keep: int = 3
	if db != null:
		keep = db.bal("autosave_keep")
	var slots: Array[String] = []
	for i in range(1, keep + 1):
		slots.append("auto_%d" % i)
	return slots

func latest_autosave() -> String:
	var slots: Array[String] = _autosave_slots()
	var best_slot: String = ""
	var best_time: int = -1
	for slot in slots:
		var path: String = "user://saves/%s.sav" % slot
		if FileAccess.file_exists(path):
			var mtime: int = FileAccess.get_modified_time(path)
			if mtime > best_time:
				best_time = mtime
				best_slot = slot
	return best_slot

func autosave_on_turn_end() -> void:
	var slots: Array[String] = _autosave_slots()
	if slots.is_empty():
		return

	# First check for any empty slot
	for slot in slots:
		var path: String = "user://saves/%s.sav" % slot
		if not FileAccess.file_exists(path):
			save_game(slot)
			return

	# All exist: pick the oldest modified
	var oldest_slot: String = slots[0]
	var oldest_time: int = FileAccess.get_modified_time("user://saves/%s.sav" % slots[0])
	for i in range(1, slots.size()):
		var slot: String = slots[i]
		var mtime: int = FileAccess.get_modified_time("user://saves/%s.sav" % slot)
		if mtime < oldest_time:
			oldest_time = mtime
			oldest_slot = slot

	save_game(oldest_slot)
