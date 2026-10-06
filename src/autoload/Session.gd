extends Node

signal state_changed(scope: String, ids: Array)

var db: ContentDB = null

func _ready() -> void:
	db = ContentDB.load_from("res://data")
