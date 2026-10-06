class_name SimLog
extends RefCounted

static var _entries: Array[String] = []

static func warn(code: String, detail: String = "") -> void:
	var msg: String = "%s %s" % [code, detail]
	_entries.append(msg)
	print("SIMLOG ", code, " ", detail)

static func take() -> Array[String]:
	var copy: Array[String] = _entries.duplicate()
	_entries.clear()
	return copy

static func clear() -> void:
	_entries.clear()
