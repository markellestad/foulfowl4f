class_name DefLoader
extends RefCounted

static func ints_only(v: Variant, path: String, errors: Array[String]) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			if v == int(v):
				return int(v)
			else:
				var p: String = path if path != "" else "root"
				errors.append("non-integer number at %s" % p)
				return v
		TYPE_INT:
			return v
		TYPE_ARRAY:
			var arr: Array = []
			for idx in range((v as Array).size()):
				var item_path: String = ("%s[%d]" % [path, idx]) if path != "" else str(idx)
				arr.append(ints_only(v[idx], item_path, errors))
			return arr
		TYPE_DICTIONARY:
			var d: Dictionary = {}
			for k in (v as Dictionary).keys():
				var key_str: String = str(k)
				var val_path: String = ("%s.%s" % [path, key_str]) if path != "" else key_str
				d[key_str] = ints_only(v[k], val_path, errors)
			return d
		_:
			return v

static func load_json(path: String, errors: Array[String]) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("File not found: %s" % path)
		return null
	var text: String = FileAccess.get_file_as_string(path)
	var json: JSON = JSON.new()
	var err: Error = json.parse(text)
	if err != OK:
		errors.append("JSON parse error at line %d: %s (in %s)" % [json.get_error_line(), json.get_error_message(), path])
		return null
	return ints_only(json.data, "", errors)
