class_name BattleScreen
extends ScreenBase

const RangeStripClass = preload("res://src/render/battle/RangeStrip.gd")
const BattleStageClass = preload("res://src/render/battle/BattleStage.gd")
const AutopsyCardClass = preload("res://src/ui/screens/AutopsyCard.gd")
const ShipGlyphClass = preload("res://src/render/battle/ShipGlyph.gd")

var battle_log: BattleLog
var range_strip = null
var stage = null
var autopsy_card = null

var current_round_idx: int = 0
var playback_speed: float = 1.0 # 1.0, 2.0, 4.0
var is_paused: bool = false
var round_timer: float = 0.0
const ROUND_DURATION: float = 1.2

var status_lbl: Label
var round_lbl: Label
var pause_btn: Button
var ticker_lbl: Label
var event_log: Array[String] = []
var unit_names: Dictionary = {}

func setup(p: Dictionary) -> void:
	super.setup(p)
	if p.has("log"):
		var raw_log = p["log"]
		if raw_log is BattleLog:
			battle_log = raw_log
		elif raw_log is Dictionary:
			battle_log = BattleLog.from_dict(raw_log)

func build() -> void:
	# Dark space background
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.07, 1.0)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	# Battle Stage (ships and VFX)
	stage = BattleStageClass.new()
	add_child(stage)

	# Range strip at top
	range_strip = RangeStripClass.new()
	range_strip.anchor_left = 0.0
	range_strip.anchor_right = 1.0
	range_strip.offset_top = 10
	range_strip.offset_left = 40
	range_strip.offset_right = -40
	range_strip.offset_bottom = 58
	add_child(range_strip)

	# Battle event ticker line (last 3 events)
	ticker_lbl = Label.new()
	ticker_lbl.anchor_left = 0.0
	ticker_lbl.anchor_right = 1.0
	ticker_lbl.anchor_top = 1.0
	ticker_lbl.anchor_bottom = 1.0
	ticker_lbl.offset_left = 40
	ticker_lbl.offset_right = -40
	ticker_lbl.offset_top = -120
	ticker_lbl.offset_bottom = -68
	ticker_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ticker_lbl.add_theme_font_size_override("font_size", 12)
	ticker_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 0.85))
	add_child(ticker_lbl)

	# Controls overlay at bottom (padded away from screen edges)
	var bottom_panel := PanelContainer.new()
	bottom_panel.anchor_left = 0.0
	bottom_panel.anchor_right = 1.0
	bottom_panel.anchor_top = 1.0
	bottom_panel.anchor_bottom = 1.0
	bottom_panel.offset_left = 40
	bottom_panel.offset_right = -40
	bottom_panel.offset_top = -60
	bottom_panel.offset_bottom = -10
	add_child(bottom_panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	bottom_panel.add_child(hbox)

	var tot_r: int = battle_log.rounds.size() if battle_log != null else 8
	round_lbl = Label.new()
	round_lbl.text = "Round: 1 / %d" % tot_r
	hbox.add_child(round_lbl)

	status_lbl = Label.new()
	status_lbl.text = "Combat In Progress"
	hbox.add_child(status_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	pause_btn = Button.new()
	pause_btn.text = "Pause (Space)"
	pause_btn.pressed.connect(func():
		is_paused = not is_paused
		pause_btn.text = "Resume" if is_paused else "Pause (Space)"
	)
	hbox.add_child(pause_btn)

	var spd1_btn := Button.new()
	spd1_btn.text = "1x"
	spd1_btn.pressed.connect(func(): playback_speed = 1.0)
	hbox.add_child(spd1_btn)

	var spd2_btn := Button.new()
	spd2_btn.text = "2x"
	spd2_btn.pressed.connect(func(): playback_speed = 2.0)
	hbox.add_child(spd2_btn)

	var spd4_btn := Button.new()
	spd4_btn.text = "4x"
	spd4_btn.pressed.connect(func(): playback_speed = 4.0)
	hbox.add_child(spd4_btn)

	var skip_btn := Button.new()
	skip_btn.text = "Skip to End (S)"
	skip_btn.pressed.connect(_skip_to_end)
	hbox.add_child(skip_btn)

	var replay_btn := Button.new()
	replay_btn.text = "Replay"
	replay_btn.pressed.connect(_restart)
	hbox.add_child(replay_btn)

	# Autopsy modal container (hidden initially)
	autopsy_card = AutopsyCardClass.new()
	autopsy_card.anchor_left = 0.5
	autopsy_card.anchor_top = 0.5
	autopsy_card.anchor_right = 0.5
	autopsy_card.anchor_bottom = 0.5
	autopsy_card.offset_left = -210
	autopsy_card.offset_top = -100
	autopsy_card.offset_right = 210
	autopsy_card.offset_bottom = 100
	autopsy_card.visible = false
	autopsy_card.closed.connect(func(): on_back())
	add_child(autopsy_card)

	_init_battle()

func add_ticker_event(msg: String) -> void:
	event_log.append(msg)
	if event_log.size() > 3:
		event_log.pop_front()
	var lines: Array[String] = []
	for evt in event_log:
		lines.append("• " + evt)
	if ticker_lbl != null:
		ticker_lbl.text = "\n".join(lines)

func _init_battle() -> void:
	if battle_log == null:
		return

	# Cache ship names
	unit_names.clear()
	for u in battle_log.initial_units:
		var uid: int = int(u.get("uid", -1))
		unit_names[uid] = str(u.get("name_key", "Ship"))

	# Separate initial units into left (party 0 / player) and right (enemy)
	var left_units: Array = []
	var right_units: Array = []
	var first_emp_id: int = -1
	var second_emp_id: int = -1

	for u in battle_log.initial_units:
		var eid: int = int(u.get("empire_id", 0))
		if first_emp_id == -1:
			first_emp_id = eid
		elif second_emp_id == -1 and eid != first_emp_id:
			second_emp_id = eid
		if eid == first_emp_id:
			left_units.append(u)
		else:
			right_units.append(u)

	if second_emp_id == -1:
		second_emp_id = 1 if first_emp_id == 0 else 0

	var col_l: Color = Color(0.4, 0.7, 1.0)
	var col_r: Color = Color(0.95, 0.45, 0.45)
	stage.setup_parties(left_units, right_units, col_l, col_r)

	var left_race: String = Copy.empire_name(first_emp_id)
	var right_race: String = Copy.empire_name(second_emp_id)
	stage.set_headers(left_race + " • 1st Flock", col_l, right_race + " • 2nd Flock", col_r)

	current_round_idx = 0
	round_timer = 0.0
	event_log.clear()
	if ticker_lbl != null:
		ticker_lbl.text = ""

	var tot_r: int = maxi(1, battle_log.rounds.size())
	round_lbl.text = "Round: 1 / %d" % tot_r
	if not battle_log.rounds.is_empty():
		_apply_round(0)

func _process(delta: float) -> void:
	if is_paused or battle_log == null or autopsy_card.visible:
		return

	round_timer += delta * playback_speed
	if round_timer >= ROUND_DURATION:
		round_timer = 0.0
		current_round_idx += 1
		if current_round_idx < battle_log.rounds.size():
			_apply_round(current_round_idx)
		else:
			_show_autopsy()

func _apply_round(idx: int) -> void:
	if battle_log == null or idx >= battle_log.rounds.size():
		return

	var r: Dictionary = battle_log.rounds[idx]
	var r_num: int = int(r.get("round_num", idx + 1))
	var tot_r: int = maxi(1, battle_log.rounds.size())
	round_lbl.text = "Round: %d / %d" % [r_num, tot_r]

	# Update distance
	var dist_map: Dictionary = r.get("distances", {})
	var d_val: int = 10
	if not dist_map.is_empty():
		d_val = int(dist_map.values()[0])
	range_strip.set_distance(d_val)
	stage.set_distance(d_val)

	# Visual effects for direct shots
	var shots: Array = r.get("shots", [])
	for s in shots:
		var shooter_uid: int = int(s.get("shooter_uid", -1))
		var target_uid: int = int(s.get("target_uid", -1))
		var hit: bool = bool(s.get("hit", false))
		var dmg: int = int(s.get("damage", 0))
		var band: String = str(s.get("band", "talon"))
		var p_from: Vector2 = stage.get_unit_pos(shooter_uid)
		var p_to: Vector2 = stage.get_unit_pos(target_uid)

		stage.vfx.add_shot(p_from, p_to, band)
		if hit:
			stage.vfx.add_hit(p_to, true, (p_to - p_from).normalized())

		var s_name: String = unit_names.get(shooter_uid, "Ship")
		var t_name: String = unit_names.get(target_uid, "Ship")
		if hit and dmg > 0:
			add_ticker_event("%s hits %s for %d" % [s_name, t_name, dmg])
		elif hit:
			add_ticker_event("%s hits %s (shields held)" % [s_name, t_name])

	# Visual effects for Swat intercepts
	var swat_arr: Array = r.get("swat_intercepts", [])
	for sw in swat_arr:
		var sw_uid: int = int(sw.get("swat_uid", -1))
		var pos: Vector2 = stage.get_unit_pos(sw_uid) + Vector2(randf_range(-25, 25), randf_range(-25, 25))
		stage.vfx.add_swat_flash(pos)
		var sw_name: String = unit_names.get(sw_uid, "Swat Escort")
		add_ticker_event("%s intercepts incoming dart" % sw_name)

	# Update glyph HP & death effects
	var dead_uids: Array = r.get("destroyed_uids", [])
	for duid_val in dead_uids:
		var uid: int = int(duid_val)
		var g = stage.get_glyph(uid)
		if g != null and not g.is_destroyed:
			g.set_hp(0)
			stage.vfx.add_death(g.position)
			var d_name: String = unit_names.get(uid, "Ship")
			add_ticker_event("%s is destroyed" % d_name)

func _skip_to_end() -> void:
	if battle_log == null:
		return
	for i in range(current_round_idx, battle_log.rounds.size()):
		_apply_round(i)
	_show_autopsy()

func _show_autopsy() -> void:
	if battle_log == null:
		return
	status_lbl.text = "Combat Concluded"
	var tot_r: int = battle_log.rounds.size()
	round_lbl.text = "Round: %d / %d" % [tot_r, tot_r]
	if pause_btn != null:
		pause_btn.disabled = true
	var auto_data: Dictionary = Autopsy.analyze(battle_log)
	var winner_name: String = ""
	if battle_log.winner_empire_id >= 0:
		winner_name = Copy.empire_name(battle_log.winner_empire_id)
	autopsy_card.setup(auto_data, winner_name, battle_log.is_stalemate)
	autopsy_card.visible = true

func _restart() -> void:
	autopsy_card.visible = false
	status_lbl.text = "Combat In Progress"
	if pause_btn != null:
		pause_btn.disabled = false
		pause_btn.text = "Pause (Space)"
	is_paused = false
	_init_battle()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var key = event.keycode
		if key == KEY_SPACE:
			if not autopsy_card.visible and pause_btn != null and not pause_btn.disabled:
				is_paused = not is_paused
				pause_btn.text = "Resume" if is_paused else "Pause (Space)"
		elif key == KEY_1:
			playback_speed = 1.0
		elif key == KEY_2:
			playback_speed = 2.0
		elif key == KEY_3:
			playback_speed = 4.0
		elif key == KEY_S:
			_skip_to_end()
