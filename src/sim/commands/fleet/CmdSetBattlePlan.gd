class_name CmdSetBattlePlan
extends Cmd

var fleet_id: int = -1
var posture: String = "auto"
var target_priority: String = "auto"
var swat_mode: String = "missiles"
var retreat_threshold: String = "never"

const VALID_POSTURES: Array[String] = ["auto", "close", "talon", "standoff", "retreat"]
const VALID_TARGET_PRIORITIES: Array[String] = ["auto", "biggest", "swat", "band_talon", "band_beak", "band_horizon", "defenses", "transports"]
const VALID_SWAT_MODES: Array[String] = ["missiles", "ships"]
const VALID_RETREATS: Array[String] = ["never", "half", "even"]

func kind() -> StringName:
	return &"set_battle_plan"

func validate(gs: GameState, _db: ContentDB) -> String:
	if not gs.fleets.has(fleet_id):
		return "refuse.unknown"
	var flt: Fleet = gs.fleets[fleet_id]
	if flt.owner != empire_id:
		return "refuse.not_owner"
	if not VALID_POSTURES.has(posture):
		return "refuse.unknown"
	if not VALID_TARGET_PRIORITIES.has(target_priority):
		return "refuse.unknown"
	if not VALID_SWAT_MODES.has(swat_mode):
		return "refuse.unknown"
	if not VALID_RETREATS.has(retreat_threshold):
		return "refuse.unknown"
	return ""

func apply(gs: GameState, _db: ContentDB) -> void:
	if gs.fleets.has(fleet_id):
		var flt: Fleet = gs.fleets[fleet_id]
		if flt.plan == null:
			flt.plan = BattlePlan.new()
		flt.plan.posture = posture
		flt.plan.target_priority = target_priority
		flt.plan.swat_mode = swat_mode
		flt.plan.retreat_threshold = retreat_threshold

func to_dict() -> Dictionary:
	var d: Dictionary = super.to_dict()
	d["fleet_id"] = fleet_id
	d["posture"] = posture
	d["target_priority"] = target_priority
	d["swat_mode"] = swat_mode
	d["retreat_threshold"] = retreat_threshold
	return d

func load_dict(d: Dictionary) -> void:
	super.load_dict(d)
	fleet_id = int(d.get("fleet_id", -1))
	posture = str(d.get("posture", "auto"))
	target_priority = str(d.get("target_priority", "auto"))
	swat_mode = str(d.get("swat_mode", "missiles"))
	retreat_threshold = str(d.get("retreat_threshold", "never"))
