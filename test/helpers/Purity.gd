class_name Purity
extends RefCounted

const FORBIDDEN_TOKENS: Array[String] = [
	"randi(",
	"randf(",
	"randomize(",
	"RandomNumberGenerator",
	"Time.",
	"OS.",
	"extends Node",
	"get_tree(",
	"float(",
	": float",
	"-> float",
	"Session.",
	"Settings.",
	"Copy.",
	"Sfx.",
	"push_error(",
	"assert("
]

static func scan(text: String) -> Array[String]:
	var flagged: Array[String] = []
	for token in FORBIDDEN_TOKENS:
		if text.contains(token):
			flagged.append(token)
	return flagged
