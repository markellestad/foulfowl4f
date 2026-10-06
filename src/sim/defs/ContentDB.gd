class_name ContentDB
extends RefCounted

var errors: Array[String] = []
var _tables: Dictionary = {}

static func load_from(root: String) -> ContentDB:
	var db: ContentDB = ContentDB.new()
	var manifest_path: String = root.path_join("manifest.json")
	var manifest_data: Variant = DefLoader.load_json(manifest_path, db.errors)
	if manifest_data == null or typeof(manifest_data) != TYPE_DICTIONARY or not (manifest_data as Dictionary).has("files"):
		db.errors.append("Invalid or missing manifest at %s" % manifest_path)
		return db
	for file_name in manifest_data["files"]:
		var fpath: String = root.path_join("%s.json" % file_name)
		var table_data: Variant = DefLoader.load_json(fpath, db.errors)
		if table_data != null and typeof(table_data) == TYPE_DICTIONARY:
			db._tables[str(file_name)] = table_data
		else:
			db.errors.append("Failed to load table %s from %s" % [file_name, fpath])
	return db

func table(name: String) -> Dictionary:
	if _tables.has(name):
		return _tables[name]
	return {}

func bal(key: String) -> int:
	var b: Dictionary = table("balance")
	if b.has(key):
		return int(b[key])
	errors.append("missing balance key %s" % key)
	return 0

func def(kind: String, id: String) -> Dictionary:
	var t: Dictionary = table(kind)
	if t.has("rows") and typeof(t["rows"]) == TYPE_DICTIONARY:
		var rows: Dictionary = t["rows"]
		if rows.has(id) and typeof(rows[id]) == TYPE_DICTIONARY:
			return rows[id]
	return {}

func ids(kind: String) -> Array[String]:
	var t: Dictionary = table(kind)
	var res: Array[String] = []
	if t.has("rows") and typeof(t["rows"]) == TYPE_DICTIONARY:
		for k in t["rows"].keys():
			res.append(str(k))
		res.sort()
	return res

func is_ok() -> bool:
	return errors.is_empty()
