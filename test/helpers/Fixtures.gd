class_name Fixtures
extends RefCounted

static func galaxy(preset: String = "evening_standard", seed_string: String = "TEST", player_race: String = "pheasants") -> GameState:
	var db: ContentDB = ContentDB.load_from("res://data")
	var s: GameSettings = (GameSettings as Variant).call(&"new")
	s.preset = preset
	s.seed_string = seed_string
	s.seed = Rng.seed_from_string(seed_string)
	s.player_race = player_race
	s.seat_swans = true
	return GalaxyGenerator.generate(s, db)
