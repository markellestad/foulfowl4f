class_name Seating
extends RefCounted

static func resolve(settings: GameSettings, db: ContentDB) -> Array[String]:
	var seats: Array[String] = []
	seats.append(settings.player_race)

	var galaxy_table: Dictionary = db.table("galaxy")
	var presets: Dictionary = galaxy_table.get("presets", {})
	var preset_def: Dictionary = presets.get(settings.preset, {})
	var total_empires: int = int(preset_def.get("empires", 4))

	var races_table: Dictionary = db.table("races")
	var race_rows: Dictionary = races_table.get("rows", {})

	# Helper to check if a race is playable
	var is_playable = func(rid: String) -> bool:
		if not race_rows.has(rid):
			return false
		return bool(race_rows[rid].get("playable", false))

	# Slot 1: swans (if seat_swans)
	if settings.seat_swans:
		if is_playable.call("swans") and not seats.has("swans"):
			seats.append("swans")

	# Slot 2: one early-war (geese | pheasants)
	var early_war_cands: Array[String] = ["geese", "pheasants"]
	for cand in early_war_cands:
		if is_playable.call(cand) and not seats.has(cand):
			seats.append(cand)
			break

	# Slot 3: one schemer (crows | ducks) if preset has >= 4 empires
	if total_empires >= 4:
		var schemer_cands: Array[String] = ["crows", "ducks"]
		for cand in schemer_cands:
			if is_playable.call(cand) and not seats.has(cand):
				seats.append(cand)
				break

	# Refill missing seats in races.json id order
	for rid in race_rows.keys():
		if seats.size() >= total_empires:
			break
		if not is_playable.call(rid):
			continue
		if not settings.seat_swans and rid == "swans":
			continue
		if not seats.has(rid):
			seats.append(rid)

	return seats
