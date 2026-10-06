extends GutTest

const DO_NOT_SHIP: Array[String] = [
	"Merculite", "Pulson", "Zeon", "Zortrium", "Neutronium", "Hellbore",
	"Adamantium", "Tritanium", "Phasor", "Phaser", "Death Ray", "Galactic Cybernet",
	"Recyclotron", "Autolab", "Time Warp Facilitator", "Inertial Stabilizer",
	"Inertial Nullifier", "Inertial Damper", "Aegis", "Psilon", "Silicoid",
	"Darlok", "Klackon", "Alkari", "Mrrshan", "Bulrathi", "Sakkra",
	"Meklar", "Gnolam", "Antaran", "Orion"
]

func test_en_json_values_are_strings() -> void:
	var text: String = FileAccess.get_file_as_string("res://data/copy/en.json")
	var json: JSON = JSON.new()
	var err: Error = json.parse(text)
	assert_eq(err, OK)
	assert_eq(typeof(json.data), TYPE_DICTIONARY)
	for k in json.data.keys():
		assert_eq(typeof(json.data[k]), TYPE_STRING, "Value for %s is string" % str(k))

func test_copy_known_keys() -> void:
	assert_eq(Copy.t("menu.splash.3"), "Swans OP.")

func test_missing_key_refuse_prettify_and_missing_keys() -> void:
	var result: String = Copy.t("ui.label.new_game_x")
	assert_eq(result, "New Game X")
	var missing: Array[String] = Copy.missing_keys()
	assert_true(missing.has("ui.label.new_game_x"))
	# Call again to verify it appears once
	Copy.t("ui.label.new_game_x")
	var missing2: Array[String] = Copy.missing_keys()
	var count: int = 0
	for m in missing2:
		if m == "ui.label.new_game_x":
			count += 1
	assert_eq(count, 1)

func test_copy_format_tokens() -> void:
	var formatted: String = Copy.f("nonexistent.token_test", {"a": "FOO"}, "{a} and {unknown}")
	assert_eq(formatted, "FOO and {unknown}")

func test_no_do_not_ship_terms() -> void:
	var text: String = FileAccess.get_file_as_string("res://data/copy/en.json")
	var json: JSON = JSON.new()
	json.parse(text)
	for term in DO_NOT_SHIP:
		var pattern: String = "\\b%s\\b" % term
		var regex: RegEx = RegEx.new()
		regex.compile(pattern)
		for k in json.data.keys():
			var val: String = json.data[k]
			var m: RegExMatch = regex.search(val)
			assert_null(m, "Value of %s contains forbidden term %s" % [k, term])
