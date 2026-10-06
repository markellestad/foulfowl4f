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

	# Controls overlay at bottom
	var bottom_panel := PanelContainer.new()
	bottom_panel.anchor_left = 0.0
	bottom_panel.anchor_right = 1.0
	bottom_panel.anchor_top = 1.0
	bottom_panel.anchor_bottom = 1.0
	bottom_panel.offset_top = -64
	add_child(bottom_panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	bottom_panel.add_child(hbox)

	round_lbl = Label.new()
	round_lbl.text = "Round: 0 / 8"
	hbox.add_child(round_lbl)

	status_lbl = Label.new()
	status_lbl.text = "Combat In Progress"
	hbox.add_child(status_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var pause_btn := Button.new()
	pause_btn.text = "Pause (Space)"
	pause_btn.pressed.connect(func(): is_paused = not is_paused; pause_btn.text = "Resume" if is_paused else "Pause (Space)")
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
	autopsy_card.offset_left = -200
	autopsy_card.offset_top = -130
	autopsy_card.offset_right = 200
	autopsy_card.offset_bottom = 130
	autopsy_card.visible = false
	autopsy_card.closed.connect(func(): on_back())
	add_child(autopsy_card)

	_init_battle()

func _init_battle() -> void:
	if battle_log == null:
		return

	# Separate initial units into left (party 0 / player) and right (enemy)
	var left_units: Array = []
	var right_units: Array = []
	var first_emp_id: int = -1

	for u in battle_log.initial_units:
		var eid: int = int(u.get("empire_id", 0))
		if first_emp_id == -1:
			first_emp_id = eid
		if eid == first_emp_id:
			left_units.append(u)
		else:
			right_units.append(u)

	var col_l: Color = Color(0.4, 0.7, 1.0)
	var col_r: Color = Color(0.9, 0.4, 0.4)
	stage.setup_parties(left_units, right_units, col_l, col_r)

	current_round_idx = 0
	round_timer = 0.0
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
	round_lbl.text = "Round: %d / %d" % [r_num, battle_log.rounds.size()]

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
		var band: String = str(s.get("band", "talon"))
		var p_from: Vector2 = stage.get_unit_pos(shooter_uid)
		var p_to: Vector2 = stage.get_unit_pos(target_uid)

		stage.vfx.add_shot(p_from, p_to, band)
		if hit:
			stage.vfx.add_hit(p_to, true, (p_to - p_from).normalized())

	# Visual effects for Swat intercepts
	var swat_arr: Array = r.get("swat_intercepts", [])
	for sw in swat_arr:
		var sw_uid: int = int(sw.get("swat_uid", -1))
		var pos: Vector2 = stage.get_unit_pos(sw_uid) + Vector2(randf_range(-30, 30), randf_range(-30, 30))
		stage.vfx.add_swat_flash(pos)

	# Update glyph HP & death effects
	var dead_uids: Array = r.get("destroyed_uids", [])
	for duid_val in dead_uids:
		var uid: int = int(duid_val)
		var g = stage.get_glyph(uid)
		if g != null and not g.is_destroyed:
			g.set_hp(0)
			stage.vfx.add_death(g.position)

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
	var auto_data: Dictionary = Autopsy.analyze(battle_log)
	var winner_name: String = ""
	if battle_log.winner_empire_id >= 0:
		winner_name = "Empire %d" % battle_log.winner_empire_id
	autopsy_card.setup(auto_data, winner_name, battle_log.is_stalemate)
	autopsy_card.visible = true

func _restart() -> void:
	autopsy_card.visible = false
	status_lbl.text = "Combat In Progress"
	_init_battle()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var key = event.keycode
		if key == KEY_SPACE:
			is_paused = not is_paused
		elif key == KEY_1:
			playback_speed = 1.0
		elif key == KEY_2:
			playback_speed = 2.0
		elif key == KEY_3:
			playback_speed = 4.0
		elif key == KEY_S:
			_skip_to_end()
