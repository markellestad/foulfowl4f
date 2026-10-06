class_name GameSettings
extends RefCounted

var preset: String = "evening_standard"
var seed_string: String = ""
var seed: int = 0
var difficulty: String = "flighted"
var player_race: String = "pheasants"
var seat_swans: bool = true
var seats: Array[String] = []

func to_dict() -> Dictionary:
	return {
		"preset": preset,
		"seed_string": seed_string,
		"seed": seed,
		"difficulty": difficulty,
		"player_race": player_race,
		"seat_swans": seat_swans,
		"seats": seats.duplicate()
	}

static func from_dict(d: Dictionary) -> GameSettings:
	var s: GameSettings = (GameSettings as Variant).call(&"new")
	s.preset = str(d.get("preset", "evening_standard"))
	s.seed_string = str(d.get("seed_string", ""))
	s.seed = int(d.get("seed", 0))
	s.difficulty = str(d.get("difficulty", "flighted"))
	s.player_race = str(d.get("player_race", "pheasants"))
	s.seat_swans = bool(d.get("seat_swans", true))
	var raw_seats: Array = d.get("seats", [])
	s.seats.clear()
	for r in raw_seats:
		s.seats.append(str(r))
	return s
