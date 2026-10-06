extends GutTest

func _assert_no_floats(v: Variant, path: String) -> void:
	match typeof(v):
		TYPE_FLOAT:
			fail_test("Found float at %s: %s" % [path, str(v)])
		TYPE_ARRAY:
			for i in range((v as Array).size()):
				_assert_no_floats(v[i], "%s[%d]" % [path, i])
		TYPE_DICTIONARY:
			for k in (v as Dictionary).keys():
				_assert_no_floats(v[k], "%s.%s" % [path, str(k)])

func test_content_db_load() -> void:
	var db: ContentDB = ContentDB.load_from("res://data")
	assert_true(db.is_ok(), "ContentDB loaded without errors: %s" % str(db.errors))
	assert_eq(db.errors.size(), 0)
	
	for manifest_file in ["balance", "audio", "credits", "galaxy", "climates", "traits", "races", "difficulty", "buildings", "presets"]:
		var t: Dictionary = db.table(manifest_file)
		assert_false(t.is_empty(), "Table %s is not empty" % manifest_file)
		_assert_no_floats(t, manifest_file)

func test_ints_only_refuse_and_allow() -> void:
	var errs: Array[String] = []
	var refused: Variant = DefLoader.ints_only({"x": 1.5}, "", errs)
	assert_eq(errs.size(), 1)
	assert_true(errs[0].contains("x"), "Error names x: %s" % errs[0])

	var errs2: Array[String] = []
	var allowed: Variant = DefLoader.ints_only({"x": 2.0}, "", errs2)
	assert_eq(errs2.size(), 0)
	assert_eq(typeof(allowed["x"]), TYPE_INT)
	assert_eq(allowed["x"], 2)

func test_bal_refuse_missing_key() -> void:
	var db: ContentDB = ContentDB.load_from("res://data")
	var val: int = db.bal("missing_key")
	assert_eq(val, 0)
	assert_true(db.errors.size() > 0)
	assert_true(db.errors[db.errors.size() - 1].contains("missing balance key missing_key"))

func test_stats_snake_case() -> void:
	var regex := RegEx.new()
	var err: Error = regex.compile("^[a-z][a-z0-9_]*$")
	assert_eq(err, OK)
	for stat_id in Stats.STATS.keys():
		var match_res := regex.search(stat_id)
		assert_not_null(match_res, "Stat id %s is snake_case" % stat_id)

func test_races_and_traits_validation() -> void:
	var db: ContentDB = ContentDB.load_from("res://data")
	var races_table: Dictionary = db.table("races")
	var race_rows: Dictionary = races_table.get("rows", {})
	var traits_table: Dictionary = db.table("traits")
	var trait_rows: Dictionary = traits_table.get("rows", {})
	var climates_table: Dictionary = db.table("climates")
	var climate_rows: Dictionary = climates_table.get("rows", {})
	var galaxy_table: Dictionary = db.table("galaxy")

	# Every race's trait costs sum to its picks (swans 13, others 10)
	for race_id in race_rows.keys():
		var race: Dictionary = race_rows[race_id]
		var picks: int = int(race.get("picks", 0))
		if race_id == "swans":
			assert_eq(picks, 13, "Swans picks == 13")
		else:
			assert_eq(picks, 10, "%s picks == 10" % race_id)

		var cost_sum: int = 0
		var trait_ids: Array = race.get("traits", [])
		for tid in trait_ids:
			assert_true(trait_rows.has(tid), "Trait %s in race %s exists in traits.json" % [tid, race_id])
			var tdef: Dictionary = trait_rows.get(tid, {})
			cost_sum += int(tdef.get("cost", 0))
		assert_eq(cost_sum, picks, "Trait costs for %s sum to picks %d" % [race_id, picks])

		var hw: Dictionary = race.get("homeworld", {})
		var hw_climate: String = hw.get("climate", "")
		assert_true(climate_rows.has(hw_climate), "Homeworld climate %s exists" % hw_climate)
		var best_climate: String = race.get("best_climate", "")
		assert_true(climate_rows.has(best_climate), "Best climate %s exists" % best_climate)

	# Every effect stat is in Stats.STATS and op is one of add/pct/floor/cap
	var valid_ops: Array[String] = ["add", "pct", "floor", "cap"]
	for trait_id in trait_rows.keys():
		var tdef: Dictionary = trait_rows[trait_id]
		var effects: Array = tdef.get("effects", [])
		for eff in effects:
			var stat: String = eff.get("stat", "")
			assert_true(Stats.is_stat(stat), "Effect stat %s in trait %s is valid" % [stat, trait_id])
			var op: String = eff.get("op", "")
			assert_true(valid_ops.has(op), "Effect op %s in trait %s is valid" % [op, trait_id])

	# Every climate referenced by galaxy.json star_types exists
	var star_types: Dictionary = galaxy_table.get("star_types", {})
	for st_id in star_types.keys():
		var st: Dictionary = star_types[st_id]
		var hab: Dictionary = st.get("habitable", {})
		for c in hab.keys():
			assert_true(climate_rows.has(c), "Habitable climate %s for star %s exists" % [c, st_id])
		var host: Dictionary = st.get("hostile", {})
		for c in host.keys():
			assert_true(climate_rows.has(c), "Hostile climate %s for star %s exists" % [c, st_id])
