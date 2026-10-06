extends Node

var _slots: Dictionary = {}
var _stream_cache: Dictionary = {}
var _last_played_ms: Dictionary = {}

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_idx: int = 0

var _ui_players: Array[AudioStreamPlayer] = []
var _ui_idx: int = 0

var _music_players: Array[AudioStreamPlayer] = []
var _active_music_idx: int = 0
var _music_tween: Tween = null

func _ready() -> void:
	_ensure_buses()
	update_volumes()
	_load_audio_defs()
	_init_players()

func _ensure_buses() -> void:
	for bus_name in ["Music", "SFX", "UI"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			var idx: int = AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, &"Master")

func update_volumes() -> void:
	if not Engine.is_editor_hint():
		_set_bus_vol("Master", Settings.vol_master)
		_set_bus_vol("Music", Settings.vol_music)
		_set_bus_vol("SFX", Settings.vol_sfx)
		_set_bus_vol("UI", Settings.vol_ui)

func _set_bus_vol(bus_name: String, vol_pct: int) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		if vol_pct <= 0:
			AudioServer.set_bus_volume_db(idx, -80.0)
		else:
			AudioServer.set_bus_volume_db(idx, linear_to_db(float(vol_pct) / 100.0))

func _load_audio_defs() -> void:
	var errs: Array[String] = []
	var data: Variant = DefLoader.load_json("res://data/audio.json", errs)
	if data != null and typeof(data) == TYPE_DICTIONARY and (data as Dictionary).has("slots"):
		_slots = (data as Dictionary)["slots"]

func _init_players() -> void:
	for i in 10:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_sfx_players.append(p)
	for i in 2:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = &"UI"
		add_child(p)
		_ui_players.append(p)
	for i in 2:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = &"Music"
		add_child(p)
		_music_players.append(p)

func resolve(slot: String) -> String:
	if not _slots.has(slot):
		return ""
	var info: Dictionary = _slots[slot]
	var licensed: Variant = info.get("licensed")
	if licensed != null and typeof(licensed) == TYPE_STRING and ResourceLoader.exists(str(licensed)):
		return str(licensed)
	var open_path: Variant = info.get("open")
	if open_path != null and typeof(open_path) == TYPE_STRING:
		return str(open_path)
	return ""

func licensed_count() -> int:
	var count: int = 0
	for slot in _slots.keys():
		var info: Dictionary = _slots[slot]
		var licensed: Variant = info.get("licensed")
		if licensed != null and typeof(licensed) == TYPE_STRING and ResourceLoader.exists(str(licensed)):
			count += 1
	return count

func play(slot: String) -> void:
	var now: int = Time.get_ticks_msec()
	if _last_played_ms.has(slot) and (now - int(_last_played_ms[slot])) < 50:
		return
	_last_played_ms[slot] = now

	var path: String = resolve(slot)
	if path == "":
		return

	var stream: AudioStream = _get_stream(path)
	if stream == null:
		return

	var info: Dictionary = _slots.get(slot, {})
	var bus_name: String = str(info.get("bus", "SFX"))

	if bus_name == "UI":
		if _ui_players.is_empty():
			return
		var p: AudioStreamPlayer = _ui_players[_ui_idx]
		_ui_idx = (_ui_idx + 1) % _ui_players.size()
		p.stream = stream
		p.play()
	else:
		if _sfx_players.is_empty():
			return
		var p: AudioStreamPlayer = _sfx_players[_sfx_idx]
		_sfx_idx = (_sfx_idx + 1) % _sfx_players.size()
		p.stream = stream
		p.play()

func music(slot: String) -> void:
	var path: String = resolve(slot)
	if path == "":
		return
	var stream: AudioStream = _get_stream(path)
	if stream == null or _music_players.size() < 2:
		return

	var cur_p: AudioStreamPlayer = _music_players[_active_music_idx]
	var next_idx: int = 1 - _active_music_idx
	var next_p: AudioStreamPlayer = _music_players[next_idx]

	if cur_p.playing and cur_p.stream == stream:
		return

	next_p.stream = stream
	next_p.volume_db = -80.0
	next_p.play()

	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.set_parallel(true)
	if cur_p.playing:
		_music_tween.tween_property(cur_p, "volume_db", -80.0, 1.0)
	_music_tween.tween_property(next_p, "volume_db", 0.0, 1.0)
	_music_tween.chain().tween_callback(func() -> void:
		if cur_p.playing:
			cur_p.stop()
	)

	_active_music_idx = next_idx

func _get_stream(path: String) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path]
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is AudioStream:
			_stream_cache[path] = res
			return res as AudioStream
	return null
