class_name ModResult
extends RefCounted

var value: int = 0
var lines: Array[Dictionary] = [] # {"source_key": String, "op": String, "value": int}

func _to_string() -> String:
	return "ModResult(val=%d, lines=%s)" % [value, str(lines)]
