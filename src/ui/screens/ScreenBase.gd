class_name ScreenBase
extends Control

var router: UiRouter = null
var params: Dictionary = {}

func setup(p: Dictionary) -> void:
	params = p

func _ready() -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	build()

func build() -> void:
	pass

func on_back() -> void:
	if router != null:
		router.back()
