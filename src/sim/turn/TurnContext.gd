class_name TurnContext
extends RefCounted

var gs: GameState
var db: ContentDB
var report: TurnReport
var trade_goods_by_empire: Dictionary = {}
var orders_mode: String = "big" # "always" | "big" | "never"
var is_headless: bool = false
var requests: Array[Dictionary] = []
var auto_systems: Array[int] = []
var pending_orders: Dictionary = {} # system_id -> Dictionary
var tp = null
