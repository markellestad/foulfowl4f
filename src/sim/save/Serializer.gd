class_name Serializer
extends RefCounted

static func to_bytes(gs: GameState, summary: Dictionary = {}) -> PackedByteArray:
	var seed_str: String = ""
	if gs.settings != null:
		seed_str = gs.settings.seed_string
	var env: Dictionary = {
		"format": "foulfowl-save",
		"version": gs.version,
		"game_version": "0.1.0",
		"created_unix": 0,
		"turn": gs.turn,
		"seed_string": seed_str,
		"summary": summary,
		"state": gs.to_dict()
	}
	var json_str: String = JSON.stringify(env)
	var raw_bytes: PackedByteArray = json_str.to_utf8_buffer()
	return raw_bytes.compress(FileAccess.COMPRESSION_GZIP)

static func from_bytes(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty():
		return {
			"ok": false,
			"error": "empty_bytes",
			"state": null,
			"envelope": {}
		}
	# Validate gzip magic header (0x1f, 0x8b) and minimum size (18 bytes) to avoid C++ decompress error logging
	if bytes.size() < 18 or bytes[0] != 0x1f or bytes[1] != 0x8b:
		return {
			"ok": false,
			"error": "invalid_gzip_header",
			"state": null,
			"envelope": {}
		}

	var decompressed: PackedByteArray = bytes.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	if decompressed.is_empty():
		return {
			"ok": false,
			"error": "decompression_failed",
			"state": null,
			"envelope": {}
		}
	var text: String = decompressed.get_string_from_utf8()
	var json: JSON = JSON.new()
	var err: Error = json.parse(text)
	if err != OK:
		return {
			"ok": false,
			"error": "json_parse_error: %s" % json.get_error_message(),
			"state": null,
			"envelope": {}
		}
	if not (json.data is Dictionary):
		return {
			"ok": false,
			"error": "envelope_not_dictionary",
			"state": null,
			"envelope": {}
		}

	var ints_errs: Array[String] = []
	var norm_data: Variant = DefLoader.ints_only(json.data, "", ints_errs)
	if not (norm_data is Dictionary):
		return {
			"ok": false,
			"error": "envelope_ints_only_failed",
			"state": null,
			"envelope": {}
		}

	var env: Dictionary = norm_data as Dictionary
	if env.get("format", "") != "foulfowl-save":
		return {
			"ok": false,
			"error": "invalid_format",
			"state": null,
			"envelope": {}
		}

	var migrated: Dictionary = Migrations.migrate(env)
	if not bool(migrated.get("ok", false)):
		return {
			"ok": false,
			"error": str(migrated.get("error", "migration_failed")),
			"state": null,
			"envelope": env
		}
	var final_env: Dictionary = migrated.get("envelope", {}) as Dictionary
	var state_dict: Dictionary = final_env.get("state", {}) as Dictionary
	var gs: GameState = GameState.from_dict(state_dict)
	return {
		"ok": true,
		"error": "",
		"state": gs,
		"envelope": final_env
	}
