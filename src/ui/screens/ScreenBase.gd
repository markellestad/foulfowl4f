class_name ScreenBase
extends Control

var router: UiRouter = null
var params: Dictionary = {}

func setup(p: Dictionary) -> void:
	params = p

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	build()

func build() -> void:
	pass

func on_back() -> void:
	if router != null:
		router.back()
