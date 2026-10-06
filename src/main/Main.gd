class_name Main
extends Node

var world: Node2D = null
var battle_layer: CanvasLayer = null
var ui_layer: CanvasLayer = null
var ui_root: UiRouter = null
var perf_overlay: PerfOverlay = null

static func apply_theme_and_environment(tree: SceneTree) -> void:
	RenderingServer.set_default_clear_color(Palette.BG)
	tree.root.theme = ThemeFactory.build(Settings.ui_scale_pct)

func _ready() -> void:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	for arg in user_args:
		if arg == "--boot-check":
			BootCheck.run(self)
			return

	apply_theme_and_environment(get_tree())
	_build_scene_tree()

	var capture_id: String = ""
	var capture_out: String = ""
	for arg in user_args:
		if arg.begins_with("--capture="):
			capture_id = arg.substr("--capture=".length())
		elif arg.begins_with("--out="):
			capture_out = arg.substr("--out=".length())

	if capture_id != "" and capture_out != "":
		CaptureMode.run(self, capture_id, capture_out)
		return

	ui_root.show_screen(&"main_menu")

func _build_scene_tree() -> void:
	world = Node2D.new()
	world.name = "World"
	add_child(world)

	battle_layer = CanvasLayer.new()
	battle_layer.name = "BattleLayer"
	battle_layer.layer = 5
	add_child(battle_layer)

	ui_layer = CanvasLayer.new()
	ui_layer.name = "UiLayer"
	ui_layer.layer = 10
	add_child(ui_layer)

	ui_root = UiRouter.new()
	ui_root.name = "UiRoot"
	ui_layer.add_child(ui_root)

	perf_overlay = PerfOverlay.new()
	perf_overlay.name = "PerfOverlay"
	add_child(perf_overlay)
