extends Node

signal state_changed(scope: String, ids: Array)

var db: ContentDB = null
var settings: GameSettings = null
var state: GameState = null

func _ready() -> void:
	db = ContentDB.load_from("res://data")

func start_galaxy(p_settings: GameSettings) -> void:
	settings = p_settings
	state = GalaxyGenerator.generate(settings, db)
	state_changed.emit("galaxy", [])
