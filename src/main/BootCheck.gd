class_name BootCheck
extends RefCounted

static func run(main: Node) -> void:
	if Session.db == null or not Session.db.is_ok():
		var err_str: String = "Session.db errors: %s" % (str(Session.db.errors) if Session.db != null else "null")
		print("BOOT_FAIL ", err_str)
		main.get_tree().quit(1)
		return

	if Copy.count() < 10 or not Copy.has("menu.splash.3"):
		print("BOOT_FAIL Copy count < 10 or missing menu.splash.3")
		main.get_tree().quit(1)
		return

	var font_res: Resource = load("res://assets/fonts/AtkinsonHyperlegible-Regular.ttf")
	if not (font_res is FontFile):
		print("BOOT_FAIL Atkinson Regular is not FontFile")
		main.get_tree().quit(1)
		return

	var audio_table: Dictionary = Session.db.table("audio")
	var slots: Dictionary = audio_table.get("slots", {})
	for slot_name in slots.keys():
		var res_path: String = Sfx.resolve(slot_name)
		if res_path == "" or not ResourceLoader.exists(res_path):
			print("BOOT_FAIL Audio slot %s failed to resolve to existing resource: %s" % [slot_name, res_path])
			main.get_tree().quit(1)
			return

	print("BOOT_OK")
	main.get_tree().quit(0)
