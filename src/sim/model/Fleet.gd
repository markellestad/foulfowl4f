class_name Fleet
extends RefCounted

var id: int = -1
var owner: int = -1
var system_id: int = -1                           # -1 while in transit
var x: int = 0                                    # current position, deci-parsecs
var y: int = 0
var dest_system_id: int = -1
var from_x: int = 0
var from_y: int = 0
var depart_turn: int = 0
var arrive_turn: int = 0
var ship_ids: Array[int] = []
var auto_explore: bool = false
var order: Dictionary = {}                   # {"type": "colonize"|"outpost"|"bombard"|"invade", "planet_id": int}
var plan: BattlePlan = null
var line_order: Array[int] = []              # ship ids; empty = default order (P04)
var name: String = ""

func _init() -> void:
	plan = BattlePlan.new()

func get_display_name() -> String:
	if name != "":
		return name
	return format_flock_name(id + 1)

static func format_flock_name(n: int) -> String:
	var mod100 := n % 100
	if mod100 >= 11 and mod100 <= 13:
		return "%dth Flock" % n
	match n % 10:
		1: return "%dst Flock" % n
		2: return "%dnd Flock" % n
		3: return "%drd Flock" % n
		_: return "%dth Flock" % n

func to_dict() -> Dictionary:
	var s_arr: Array = []
	for sid in ship_ids:
		s_arr.append(int(sid))
	var lo_arr: Array = []
	for sid in line_order:
		lo_arr.append(int(sid))
	return {
		"id": id,
		"owner": owner,
		"name": name,
		"system_id": system_id,
		"x": x,
		"y": y,
		"dest_system_id": dest_system_id,
		"from_x": from_x,
		"from_y": from_y,
		"depart_turn": depart_turn,
		"arrive_turn": arrive_turn,
		"ship_ids": s_arr,
		"auto_explore": auto_explore,
		"order": order.duplicate(true),
		"plan": plan.to_dict() if plan != null else null,
		"line_order": lo_arr
	}

static func from_dict(d: Dictionary) -> Fleet:
	var f: Fleet = Fleet.new()
	f.id = int(d.get("id", -1))
	f.owner = int(d.get("owner", -1))
	f.name = str(d.get("name", ""))
	f.system_id = int(d.get("system_id", -1))
	f.x = int(d.get("x", 0))
	f.y = int(d.get("y", 0))
	f.dest_system_id = int(d.get("dest_system_id", -1))
	f.from_x = int(d.get("from_x", 0))
	f.from_y = int(d.get("from_y", 0))
	f.depart_turn = int(d.get("depart_turn", 0))
	f.arrive_turn = int(d.get("arrive_turn", 0))

	f.ship_ids.clear()
	var raw_s: Array = d.get("ship_ids", [])
	for sid in raw_s:
		f.ship_ids.append(int(sid))

	f.auto_explore = bool(d.get("auto_explore", false))
	f.order = (d.get("order", {}) as Dictionary).duplicate(true)

	if d.has("plan") and d["plan"] is Dictionary:
		f.plan = BattlePlan.from_dict(d["plan"])
	else:
		f.plan = BattlePlan.new()

	f.line_order.clear()
	var raw_lo: Array = d.get("line_order", [])
	for sid in raw_lo:
		f.line_order.append(int(sid))

	return f
