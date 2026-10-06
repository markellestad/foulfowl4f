class_name CmdBattleOrders
extends Cmd

var system_id: int = -1
var posture: String = "auto"
var target_priority: String = "auto"
var swat_mode: String = "missiles_first"
var retreat_threshold: String = "never"
var line_order: Array[int] = []

func kind() -> StringName:
	return &"battle_orders"

func validate(gs: GameState, _db: ContentDB) -> String:
	if gs == null or system_id < 0 or system_id >= gs.systems.size():
		return "refuse.unknown"
	if not gs.pending_battle_requests.has(system_id):
		return "refuse.no_pending_request"
	const VALID_POSTURES := ["auto", "close", "talon", "standoff", "retreat"]
	if not VALID_POSTURES.has(posture):
		return "refuse.unknown"
	const VALID_PRIORITIES := ["auto", "biggest", "swat", "band_talon", "band_beak", "band_horizon", "defenses", "transports", "band"]
	if not VALID_PRIORITIES.has(target_priority):
		return "refuse.unknown"
	const VALID_SWAT := ["missiles_first", "ships_first", "missiles", "ships"]
	if not VALID_SWAT.has(swat_mode):
		return "refuse.unknown"
	const VALID_RETREAT := ["never", "half", "even"]
	if not VALID_RETREAT.has(retreat_threshold):
		return "refuse.unknown"
	return ""

func apply(_gs: GameState, _db: ContentDB) -> void:
	pass

func to_dict() -> Dictionary:
	var d: Dictionary = super.to_dict()
	d["system_id"] = system_id
	d["posture"] = posture
	d["target_priority"] = target_priority
	d["swat_mode"] = swat_mode
	d["retreat_threshold"] = retreat_threshold
	var lo: Array = []
	for x in line_order:
		lo.append(int(x))
	d["line_order"] = lo
	return d

func load_dict(d: Dictionary) -> void:
	super.load_dict(d)
	system_id = int(d.get("system_id", -1))
	posture = str(d.get("posture", "auto"))
	target_priority = str(d.get("target_priority", "auto"))
	swat_mode = str(d.get("swat_mode", "missiles_first"))
	retreat_threshold = str(d.get("retreat_threshold", "never"))
	line_order.clear()
	var raw_lo: Array = d.get("line_order", [])
	for x in raw_lo:
		line_order.append(int(x))

func to_orders_dict() -> Dictionary:
	return {
		"posture": posture,
		"target_priority": target_priority,
		"swat_mode": swat_mode,
		"retreat_threshold": retreat_threshold,
		"line_order": line_order.duplicate()
	}
