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

func test_autopsy_card_copy_wire() -> void:
	Copy.load_file("res://data/copy/en.json")
	var card: AutopsyCard = AutopsyCard.new()
	var blog := BattleLog.new()
	blog.system_id = 1
	blog.turn = 4
	blog.winner_empire_id = 0
	blog.deciding_band = "talon"
	blog.standout_ship_uid = 101
	blog.receipt_lines.append({"name_key": "Sparrow", "hull_id": "small"})
	blog.final_units.append({"uid": 101, "name_key": "Peregrine Flag", "damage_dealt": 84})
	var auto_data: Dictionary = Autopsy.analyze(blog)
	card.setup(auto_data, "Pheasants", false, blog)

	assert_eq(card.title_label.text, "Battle Autopsy")
	assert_true(card.winner_label.text.begins_with("Victor: "))
	assert_true(card.band_label.text.begins_with("Deciding band: "))
	assert_true(card.standout_label.text.contains("Peregrine Flag"))
	assert_true(card.standout_label.text.contains("84 damage"))
	assert_true(card.receipt_label.text.begins_with("Lost on retreat: "))
	assert_false(card.flavor_label.text.contains("{"), "Flavor text must have no raw placeholders: " + card.flavor_label.text)
	assert_false(card.flavor_label.text.contains("}"), "Flavor text must have no raw placeholders: " + card.flavor_label.text)
	assert_gt(card.flavor_label.text.length(), 0)
	card.free()

func test_autopsy_two_named_empires_no_third_empire() -> void:
	Copy.load_file("res://data/copy/en.json")
	var blog := BattleLog.new()
	blog.system_id = 10
	blog.turn = 12
	blog.winner_empire_id = 4
	blog.deciding_band = "talon"
	blog.initial_units.append({
		"uid": 401,
		"empire_id": 4,
		"name_key": "Owl Cruiser"
	})
	blog.initial_units.append({
		"uid": 601,
		"empire_id": 6,
		"name_key": "Crow Raider"
	})
	blog.final_units.append({
		"uid": 401,
		"name_key": "Owl Cruiser",
		"damage_dealt": 50
	})
	var auto_data: Dictionary = Autopsy.analyze(blog)
	var card := AutopsyCard.new()

	var victor_name := Copy.empire_name(4)
	var loser_name := Copy.empire_name(6)

	assert_ne(victor_name, loser_name)
	assert_ne(victor_name, "")
	assert_ne(loser_name, "")

	var third_party_names: Array[String] = [
		Copy.empire_name(0),
		Copy.empire_name(1),
		Copy.empire_name(2),
		Copy.empire_name(3),
		Copy.empire_name(5),
		Copy.empire_name(7),
	]

	# Test across turns 0..11 to cover all 12 flavor keys
	for t in range(12):
		blog.turn = t
		card.setup(auto_data, victor_name, false, blog)
		var text := card.flavor_label.text

		# Must not contain unreplaced placeholders
		assert_false(text.contains("{"), "Flavor text must have no unreplaced { token: %s" % text)
		assert_false(text.contains("}"), "Flavor text must have no unreplaced } token: %s" % text)

		# Must never contain a third empire's name
		for third in third_party_names:
			assert_false(text.contains(third), "Flavor text '%s' must not contain third party '%s'" % [text, third])

	# Assert that a flavor using {loser} actually contains the loser's real name
	var loser_flavor_tested := false
	for t in range(24):
		blog.turn = t
		var seed_val: int = abs(blog.system_id * 31 + blog.turn * 17 + blog.winner_empire_id * 7 + blog.standout_ship_uid + blog.rounds.size())
		var idx: int = (seed_val % 12) + 1
		var key: String = AutopsyCard.AUTOPSY_FLAVOR_KEYS[idx - 1]
		var template: String = Copy.t(key)
		if template.contains("{loser}"):
			card.setup(auto_data, victor_name, false, blog)
			assert_true(card.flavor_label.text.contains(loser_name), "Flavor text must contain loser's real name '%s': %s" % [loser_name, card.flavor_label.text])
			loser_flavor_tested = true
			break
	assert_true(loser_flavor_tested, "A flavor containing {loser} was exercised")

	card.free()

