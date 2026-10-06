class_name Migrations
extends RefCounted

static func migrate(env: Dictionary) -> Dictionary:
	var ver: int = int(env.get("version", 0))
	if ver == 1:
		return {
			"ok": true,
			"error": "",
			"envelope": env
		}
	return {
		"ok": false,
		"error": "unsupported_save_version: %d" % ver,
		"envelope": env
	}
