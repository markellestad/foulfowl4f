class_name DesignRules
extends RefCounted

static func mini_pct(_db: ContentDB, _gs: GameState, _empire_id: int, _part_id: String) -> int:
	# 100 until P06
	return 100

static func part_space(db: ContentDB, gs: GameState, design: ShipDesign, part_id: String, mount: String = "") -> int:
	if part_id == "":
		return 0
	var pdef: Dictionary = db.def("parts", part_id)
	if pdef.is_empty():
		return 0
	var hdef: Dictionary = db.def("hulls", design.hull)
	var hull_space: int = int(hdef.get("space", 0))

	if pdef.has("space_pct"):
		var pct_val: int = int(pdef["space_pct"])
		return IntMath.ceil_div(hull_space * pct_val, 100)
	elif pdef.has("space"):
		var base_sp: int = int(pdef["space"])
		var m_pct: int = mini_pct(db, gs, design.empire_id, part_id)
		var sp: int = IntMath.ceil_div(base_sp * m_pct, 100)
		if mount != "":
			var mdef: Dictionary = db.def("parts", mount)
			var mount_pct: int = int(mdef.get("space_pct", 100))
			sp = IntMath.ceil_div(sp * mount_pct, 100)
		return sp
	return 0

static func part_pp(db: ContentDB, gs: GameState, design: ShipDesign, part_id: String, mount: String = "") -> int:
	if part_id == "":
		return 0
	var pdef: Dictionary = db.def("parts", part_id)
	if pdef.is_empty():
		return 0
	var hdef: Dictionary = db.def("hulls", design.hull)
	var hull_pp: int = int(hdef.get("pp", 0))

	if pdef.has("pp_pct"):
		var pct_val: int = int(pdef["pp_pct"])
		return IntMath.ceil_div(hull_pp * pct_val, 100)
	elif pdef.has("pp"):
		var base_pp: int = int(pdef["pp"])
		var m_pct: int = mini_pct(db, gs, design.empire_id, part_id)
		var pp_val: int = IntMath.ceil_div(base_pp * m_pct, 100)
		if mount != "":
			var mdef: Dictionary = db.def("parts", mount)
			var mount_pct: int = int(mdef.get("pp_pct", 100))
			pp_val = IntMath.ceil_div(pp_val * mount_pct, 100)
		return pp_val
	return 0

static func stats(db: ContentDB, gs: GameState, design: ShipDesign) -> Dictionary:
	var hdef: Dictionary = db.def("hulls", design.hull)
	var hull_space: int = int(hdef.get("space", 0))
	var hull_hp: int = int(hdef.get("hp", 0))
	var hull_pp: int = int(hdef.get("pp", 0))
	var hull_evasion: int = int(hdef.get("evasion", 0))
	var hull_upkeep: int = int(hdef.get("upkeep", 0))
	var line_slots: int = int(hdef.get("line_slots", 1))

	var space_used: int = 0
	var total_pp: int = hull_pp

	# Drive
	space_used += part_space(db, gs, design, design.drive, "")
	total_pp += part_pp(db, gs, design, design.drive, "")

	# Plate
	space_used += part_space(db, gs, design, design.plate, "")
	total_pp += part_pp(db, gs, design, design.plate, "")

	# Mantle
	if design.mantle != "":
		space_used += part_space(db, gs, design, design.mantle, "")
		total_pp += part_pp(db, gs, design, design.mantle, "")

	# Computer
	if design.computer != "":
		space_used += part_space(db, gs, design, design.computer, "")
		total_pp += part_pp(db, gs, design, design.computer, "")

	# Weapons
	for w in design.weapons:
		var w_part: String = str(w.get("part", ""))
		var w_mount: String = str(w.get("mount", ""))
		var w_cnt: int = int(w.get("count", 1))
		space_used += w_cnt * part_space(db, gs, design, w_part, w_mount)
		total_pp += w_cnt * part_pp(db, gs, design, w_part, w_mount)

	# Specials
	for s in design.specials:
		space_used += part_space(db, gs, design, s, "")
		total_pp += part_pp(db, gs, design, s, "")

	# HP: pct(hull hp, plate hp_pct) + special hp_pct sums
	var plate_hp_pct: int = 100
	if design.plate != "":
		var pldef: Dictionary = db.def("parts", design.plate)
		plate_hp_pct = int(pldef.get("hp_pct", 100))

	var special_hp_pct: int = 0
	for s in design.specials:
		var sdef: Dictionary = db.def("parts", s)
		if sdef.has("hp_pct"):
			special_hp_pct += int(sdef["hp_pct"])

	var total_hp: int = IntMath.ceil_div(hull_hp * (plate_hp_pct + special_hp_pct), 100)

	# Accuracy
	var accuracy: int = 0
	if design.computer != "":
		accuracy += int(db.def("parts", design.computer).get("acc", 0))
	for w in design.weapons:
		var m_id: String = str(w.get("mount", ""))
		if m_id != "":
			accuracy += int(db.def("parts", m_id).get("acc", 0))
	for s in design.specials:
		accuracy += int(db.def("parts", s).get("acc", 0))

	# Shield
	var shield: int = 0
	if design.mantle != "":
		shield += int(db.def("parts", design.mantle).get("shield", 0))
	for s in design.specials:
		shield += int(db.def("parts", s).get("shield", 0))

	# Speed
	var map_speed: int = 0
	var combat_speed: int = 0
	if design.drive != "":
		var drv_def: Dictionary = db.def("parts", design.drive)
		map_speed = int(drv_def.get("map_speed", 0))
		combat_speed = int(drv_def.get("combat_speed", 0))
	for s in design.specials:
		var sdef: Dictionary = db.def("parts", s)
		if sdef.has("combat_speed"):
			combat_speed += int(sdef["combat_speed"])

	# Range, Scan, Armed, Marines, Bomb, Colonize, Outpost
	var range_dpc: int = 0
	var scan_dpc: int = 0
	var armed: bool = not design.weapons.is_empty()
	var marines: int = 0
	var bomb_milli: int = 0
	var colonize: bool = false
	var outpost: bool = false

	for s in design.specials:
		var sdef: Dictionary = db.def("parts", s)
		if sdef.has("range_dpc"):
			range_dpc += int(sdef["range_dpc"])
		if sdef.has("scan_dpc"):
			scan_dpc += int(sdef["scan_dpc"])
		if sdef.has("marines"):
			marines += int(sdef["marines"])
		if sdef.has("bomb_milli"):
			bomb_milli += int(sdef["bomb_milli"])
			armed = true
		if bool(sdef.get("colonize", false)):
			colonize = true
		if bool(sdef.get("outpost", false)):
			outpost = true

	var upkeep: int = hull_upkeep if armed else 0

	return {
		"space_used": space_used,
		"space_max": hull_space,
		"pp": total_pp,
		"upkeep": upkeep,
		"hp": total_hp,
		"evasion": hull_evasion,
		"accuracy": accuracy,
		"shield": shield,
		"map_speed": map_speed,
		"combat_speed": combat_speed,
		"range_dpc": range_dpc,
		"scan_dpc": scan_dpc,
		"armed": armed,
		"marines": marines,
		"bomb_milli": bomb_milli,
		"colonize": colonize,
		"outpost": outpost,
		"line_slots": line_slots
	}

static func validate(db: ContentDB, gs: GameState, design: ShipDesign) -> String:
	# 1. Hull exists
	var hdef: Dictionary = db.def("hulls", design.hull)
	if hdef.is_empty():
		return "refuse.design_space"

	# 2. Exactly one drive
	if design.drive == "":
		return "refuse.design_drive"
	var drv: Dictionary = db.def("parts", design.drive)
	if drv.is_empty() or str(drv.get("category", "")) != "drive":
		return "refuse.design_drive"

	# 3. Plate slot
	if design.plate == "":
		return "refuse.design_slot"
	var plt: Dictionary = db.def("parts", design.plate)
	if plt.is_empty() or str(plt.get("category", "")) != "plate":
		return "refuse.design_slot"

	# 4. Mantle / computer slot
	if design.mantle != "":
		var mnt: Dictionary = db.def("parts", design.mantle)
		if mnt.is_empty() or str(mnt.get("category", "")) != "mantle":
			return "refuse.design_slot"
	if design.computer != "":
		var cmp: Dictionary = db.def("parts", design.computer)
		if cmp.is_empty() or str(cmp.get("category", "")) != "computer":
			return "refuse.design_slot"

	# 5. Specials count <= hull specials
	var max_specials: int = int(hdef.get("specials", 0))
	if design.specials.size() > max_specials:
		return "refuse.design_specials"

	# 6. Mounts only on Talon weapons
	for w in design.weapons:
		var w_part: String = str(w.get("part", ""))
		var w_mount: String = str(w.get("mount", ""))
		var pdef: Dictionary = db.def("parts", w_part)
		if pdef.is_empty():
			return "refuse.tech_unknown"
		if w_mount != "":
			if str(pdef.get("band", "")) != "talon":
				return "refuse.design_mount"
			var mdef: Dictionary = db.def("parts", w_mount)
			if mdef.is_empty() or str(mdef.get("category", "")) != "mount":
				return "refuse.design_mount"

	# 7. Space used <= hull space
	var st: Dictionary = stats(db, gs, design)
	if int(st["space_used"]) > int(st["space_max"]):
		return "refuse.design_space"

	# 8. Tech known
	var all_techs: Array[String] = []
	all_techs.append(str(hdef.get("tech", "start")))
	all_techs.append(str(drv.get("tech", "start")))
	all_techs.append(str(plt.get("tech", "start")))
	if design.mantle != "":
		all_techs.append(str(db.def("parts", design.mantle).get("tech", "start")))
	if design.computer != "":
		all_techs.append(str(db.def("parts", design.computer).get("tech", "start")))
	for w in design.weapons:
		var w_def: Dictionary = db.def("parts", str(w.get("part", "")))
		if not bool(w_def.get("loot_only", false)):
			all_techs.append(str(w_def.get("tech", "start")))
		var w_mount: String = str(w.get("mount", ""))
		if w_mount != "":
			all_techs.append(str(db.def("parts", w_mount).get("tech", "start")))
	for s in design.specials:
		var s_def: Dictionary = db.def("parts", s)
		if not bool(s_def.get("loot_only", false)):
			all_techs.append(str(s_def.get("tech", "start")))

	if gs != null and design.empire_id >= 0 and design.empire_id < gs.empires.size():
		var emp: Empire = gs.empires[design.empire_id]
		for t in all_techs:
			if t != "start" and (emp.tech == null or not emp.tech.knows(t)):
				return "refuse.tech_unknown"

	# 9. Loot only
	for s in design.specials:
		var sdef: Dictionary = db.def("parts", s)
		if bool(sdef.get("loot_only", false)):
			if gs == null or design.empire_id < 0 or design.empire_id >= gs.empires.size():
				return "refuse.design_loot"
			var emp: Empire = gs.empires[design.empire_id]
			if not emp.traits.has("guardian_loot") and not (emp.tech != null and emp.tech.knows("guardian_loot")):
				return "refuse.design_loot"

	# 10. Max designs limit
	if gs != null and design.empire_id >= 0:
		var active_count: int = 0
		var max_des: int = db.bal("max_designs")
		for did in gs.designs.keys():
			var d: ShipDesign = gs.designs[did]
			if d.empire_id == design.empire_id and not d.obsolete and d.id != design.id:
				active_count += 1
		if not design.obsolete and active_count >= max_des:
			return "refuse.design_limit"

	return ""
