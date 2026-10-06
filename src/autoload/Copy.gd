extends Node

var missing: Dictionary = {}
var _strings: Dictionary = {}

func _ready() -> void:
	load_file("res://data/copy/en.json")

func load_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var text: String = FileAccess.get_file_as_string(path)
	var json: JSON = JSON.new()
	var err: Error = json.parse(text)
	if err != OK or typeof(json.data) != TYPE_DICTIONARY:
		return
	for k in json.data.keys():
		var v: Variant = json.data[k]
		if typeof(v) == TYPE_STRING:
			_strings[str(k)] = str(v)

func prettify(key: String) -> String:
	var segment: String = key
	var dot_pos: int = key.rfind(".")
	if dot_pos >= 0:
		segment = key.substr(dot_pos + 1)
	var words: PackedStringArray = segment.split("_")
	var cap_words: Array[String] = []
	for w in words:
		if w.length() > 0:
			cap_words.append(w.substr(0, 1).to_upper() + w.substr(1))
		else:
			cap_words.append("")
	return " ".join(cap_words)

func t(key: String, fallback: String = "") -> String:
	if _strings.has(key):
		return _strings[key]
	if not missing.has(key):
		missing[key] = true
	if fallback != "":
		return fallback
	return prettify(key)

func f(key: String, args: Dictionary, fallback: String = "") -> String:
	var base: String = t(key, fallback)
	for k in args.keys():
		var token: String = "{%s}" % str(k)
		base = base.replace(token, str(args[k]))
	return base

func has(key: String) -> bool:
	return _strings.has(key)

func count() -> int:
	return _strings.size()

func missing_keys() -> Array[String]:
	var res: Array[String] = []
	for k in missing.keys():
		res.append(str(k))
	return res
