extends GutTest

func test_purity_refuse_and_allow() -> void:
	var flagged: Array[String] = Purity.scan("var x = randi()")
	assert_eq(flagged.size(), 1)
	assert_true(flagged.has("randi("))

	var clean: Array[String] = Purity.scan("var x: int = 42\nfunc foo() -> int:\n\treturn x")
	assert_eq(clean.size(), 0)

func test_sim_code_is_pure() -> void:
	var files: Array[String] = []
	_find_gd_files("res://src/sim", files)
	assert_true(files.size() > 0, "Found sim files to test: %d" % files.size())

	for file_path in files:
		var text: String = FileAccess.get_file_as_string(file_path)
		var flagged: Array[String] = Purity.scan(text)
		assert_eq(flagged.size(), 0, "File %s had forbidden tokens: %s" % [file_path, str(flagged)])

func _find_gd_files(dir_path: String, out_files: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not file_name.begins_with("."):
			var full_path: String = dir_path.path_join(file_name)
			if dir.current_is_dir():
				_find_gd_files(full_path, out_files)
			elif file_name.ends_with(".gd"):
				out_files.append(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()
