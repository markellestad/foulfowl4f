class_name AutoDesign
extends RefCounted

static func roles() -> Array[String]:
	return [
		"talon_line",
		"beak_line",
		"horizon_boat",
		"swat_escort",
		"boot_ship",
		"nest_ship",
		"stake_ship",
		"glance"
	]

static func _knows(emp: Empire, tech: String) -> bool:
	if tech == "start":
		return true
	if emp == null or emp.tech == null:
		return false
	return emp.tech.knows(tech)

static func design_for_role(db: ContentDB, gs: GameState, empire_id: int, role: String) -> ShipDesign:
	var emp: Empire = null
	if gs != null and empire_id >= 0 and empire_id < gs.empires.size():
		emp = gs.empires[empire_id]

	var sd: ShipDesign = ShipDesign.new()
	sd.empire_id = empire_id
	sd.role = role

	# Best Drive
	var drives: Array[String] = ["migration_drive", "fold_drive", "current_drive", "walk_drive"]
	for d in drives:
		var tech: String = str(db.def("parts", d).get("tech", "start"))
		if _knows(emp, tech):
			sd.drive = d
			break

	# Best Plate
	var plates: Array[String] = ["unsinkable_plate", "marrow_plate", "keel_plate", "joined_plate", "pinfeather_plate"]
	for p in plates:
		var tech: String = str(db.def("parts", p).get("tech", "start"))
		if _knows(emp, tech):
			sd.plate = p
			break

	match role:
		"glance":
			sd.hull = "small"
			sd.name = "Glance"
			sd.specials = ["glance_pod"]
			if DesignRules.validate(db, gs, sd) != "":
				return null
			return sd

		"stake_ship":
			sd.hull = "small"
			sd.name = "Stake Ship"
			sd.specials = ["perch_pod"]
			if DesignRules.validate(db, gs, sd) != "":
				return null
			return sd

		"boot_ship":
			sd.hull = "small"
			sd.name = "Boot Ship"
			sd.specials = ["boot_pod"]
			if DesignRules.validate(db, gs, sd) != "":
				return null
			return sd

		"nest_ship":
			sd.hull = "medium"
			sd.name = "Nest Ship"
			sd.specials = ["nest_pod"]
			if DesignRules.validate(db, gs, sd) != "":
				return null
			return sd

		"swat_escort":
			# Requires swat_mount
			var sm_tech: String = str(db.def("parts", "swat_mount").get("tech", "start"))
			if not _knows(emp, sm_tech):
				return null
			sd.hull = "small"
			sd.name = "Sparrow Swat Escort"

			# Best Talon
			var best_talon: String = ""
			for t in ["last_glare", "banded_glare", "sun_quill", "wick_talon"]:
				var t_tech: String = str(db.def("parts", t).get("tech", "start"))
				if _knows(emp, t_tech):
					best_talon = t
					break
			if best_talon == "":
				return null

			var hull_space: int = int(db.def("hulls", sd.hull).get("space", 0))
			var drive_space: int = DesignRules.part_space(db, gs, sd, sd.drive, "")
			var rem_space: int = hull_space - drive_space
			var w_space: int = DesignRules.part_space(db, gs, sd, best_talon, "swat_mount")
			var cnt: int = IntMath.floor_div(rem_space, w_space)
			if cnt <= 0:
				return null
			sd.weapons = [{"part": best_talon, "mount": "swat_mount", "count": cnt}]
			if DesignRules.validate(db, gs, sd) != "":
				return null
			return sd

		"talon_line":
			# Best warship hull
			var hulls: Array[String] = ["titan", "huge", "large", "medium", "small"]
			for h in hulls:
				var h_tech: String = str(db.def("hulls", h).get("tech", "start"))
				if _knows(emp, h_tech):
					sd.hull = h
					break
			sd.name = "%s Talon Line" % str(db.def("hulls", sd.hull).get("name", "Kestrel"))
			if sd.hull == "medium":
				sd.name = "Kestrel Talon Line"
			elif sd.hull == "small":
				sd.name = "Sparrow Talon Line"

			# Best Talon
			var best_talon: String = ""
			for t in ["last_glare", "banded_glare", "sun_quill", "wick_talon"]:
				var t_tech: String = str(db.def("parts", t).get("tech", "start"))
				if _knows(emp, t_tech):
					best_talon = t
					break
			if best_talon == "":
				return null

			# Fit mantle / computer if space permits
			_fit_systems(db, gs, sd)

			var hull_space: int = int(db.def("hulls", sd.hull).get("space", 0))
			var st: Dictionary = DesignRules.stats(db, gs, sd)
			var rem_space: int = hull_space - int(st["space_used"])
			var w_space: int = DesignRules.part_space(db, gs, sd, best_talon, "")
			var cnt: int = IntMath.floor_div(rem_space, w_space)
			if cnt <= 0:
				return null
			sd.weapons = [{"part": best_talon, "mount": "", "count": cnt}]
			if DesignRules.validate(db, gs, sd) != "":
				return null
			return sd

		"beak_line":
			var hulls: Array[String] = ["titan", "huge", "large", "medium", "small"]
			for h in hulls:
				var h_tech: String = str(db.def("hulls", h).get("tech", "start"))
				if _knows(emp, h_tech):
					sd.hull = h
					break
			sd.name = "Kestrel Beak Line" if sd.hull == "medium" else "Beak Line"

			var best_beak: String = ""
			for b in ["anvil_beak", "gizzard_bore", "clatter_bill", "peck_driver"]:
				var b_tech: String = str(db.def("parts", b).get("tech", "start"))
				if _knows(emp, b_tech):
					best_beak = b
					break
			if best_beak == "":
				return null

			_fit_systems(db, gs, sd)

			var hull_space: int = int(db.def("hulls", sd.hull).get("space", 0))
			var st: Dictionary = DesignRules.stats(db, gs, sd)
			var rem_space: int = hull_space - int(st["space_used"])
			var w_space: int = DesignRules.part_space(db, gs, sd, best_beak, "")
			var cnt: int = IntMath.floor_div(rem_space, w_space)
			if cnt <= 0:
				return null
			sd.weapons = [{"part": best_beak, "mount": "", "count": cnt}]
			if DesignRules.validate(db, gs, sd) != "":
				return null
			return sd

		"horizon_boat":
			var hulls: Array[String] = ["titan", "huge", "large", "medium", "small"]
			for h in hulls:
				var h_tech: String = str(db.def("hulls", h).get("tech", "start"))
				if _knows(emp, h_tech):
					sd.hull = h
					break
			sd.name = "Kestrel Horizon Boat" if sd.hull == "medium" else "Horizon Boat"

			var best_horizon: String = ""
			for hz in ["indoor_torpedo", "cited_dart", "ink_dart", "hatch_dart"]:
				var hz_tech: String = str(db.def("parts", hz).get("tech", "start"))
				if _knows(emp, hz_tech):
					best_horizon = hz
					break
			if best_horizon == "":
				return null

			_fit_systems(db, gs, sd)

			var hull_space: int = int(db.def("hulls", sd.hull).get("space", 0))
			var st: Dictionary = DesignRules.stats(db, gs, sd)
			var rem_space: int = hull_space - int(st["space_used"])
			var w_space: int = DesignRules.part_space(db, gs, sd, best_horizon, "")
			var cnt: int = IntMath.floor_div(rem_space, w_space)
			if cnt <= 0:
				return null
			sd.weapons = [{"part": best_horizon, "mount": "", "count": cnt}]
			if DesignRules.validate(db, gs, sd) != "":
				return null
			return sd

		_:
			return null

static func _fit_systems(db: ContentDB, gs: GameState, sd: ShipDesign) -> void:
	var emp: Empire = null
	if gs != null and sd.empire_id >= 0 and sd.empire_id < gs.empires.size():
		emp = gs.empires[sd.empire_id]

	# Best Mantle
	for m in ["closed_season", "full_mantle", "half_mantle", "dust_cover"]:
		var m_tech: String = str(db.def("parts", m).get("tech", "start"))
		if _knows(emp, m_tech):
			sd.mantle = m
			break

	# Best Computer
	for c in ["preened_cognition", "grudge_ledger", "predictive_peck", "pecking_logs"]:
		var c_tech: String = str(db.def("parts", c).get("tech", "start"))
		if _knows(emp, c_tech):
			sd.computer = c
			break
