class_name CaptureMode
extends RefCounted

static func run(main: Node, id: String, out_path: String) -> void:
	var router: UiRouter = main.get_node_or_null("UiLayer/UiRoot") as UiRouter
	if router == null:
		print("CAPTURE_FAIL missing UiRouter")
		main.get_tree().quit(1)
		return

	match id:
		"main_menu":
			_cap_main_menu(router)
		"credits":
			_cap_credits(router)
		_:
			print("CAPTURE_FAIL unknown id: ", id)
			main.get_tree().quit(1)
			return

	_capture_and_save(main, out_path)

static func _cap_main_menu(router: UiRouter) -> void:
	router.show_screen(&"main_menu", {"splash_index": 3})

static func _cap_credits(router: UiRouter) -> void:
	router.show_screen(&"credits")

static func _capture_and_save(main: Node, out_path: String) -> void:
	var tree: SceneTree = main.get_tree()
	for i in 6:
		await tree.process_frame
	await RenderingServer.frame_post_draw

	var img: Image = main.get_viewport().get_texture().get_image()
	var full_path: String = ProjectSettings.globalize_path("res://").path_join(out_path)
	var dir_path: String = full_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)

	var err: Error = img.save_png(full_path)
	if err == OK:
		print("CAPTURE_OK ", out_path)
		tree.quit(0)
	else:
		print("CAPTURE_FAIL failed to save png: ", err)
		tree.quit(1)
