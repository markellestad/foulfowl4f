extends Node

var missing: Dictionary = {}
var _strings: Dictionary = {}

func _ready() -> void:
	pass

func t(key: String, fallback: String = "") -> String:
	return fallback if fallback != "" else key

func f(key: String, args: Dictionary, fallback: String = "") -> String:
	return fallback if fallback != "" else key

func has(key: String) -> bool:
	return _strings.has(key)

func count() -> int:
	return _strings.size()

func missing_keys() -> Array[String]:
	var res: Array[String] = []
	for k in missing.keys():
		res.append(str(k))
	return res
