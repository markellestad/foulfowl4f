extends SceneTree

func _init() -> void:
	var scenario_arg: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			scenario_arg = arg.substr("--scenario=".length())
			break

	if scenario_arg == "":
		print("SCENARIO FAIL missing scenario")
		quit(1)
		return

	if not FileAccess.file_exists(scenario_arg):
		print("SCENARIO FAIL missing scenario")
		quit(1)
		return

	print("SCENARIO SKIP runner arrives in P02")
	quit(0)
