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
	
	for manifest_file in ["balance", "audio", "credits"]:
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
