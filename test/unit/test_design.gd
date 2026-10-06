extends GutTest

var _db: ContentDB

func before_all() -> void:
	_db = ContentDB.load_from("res://data")
	Copy.load_file("res://data/copy/en.json")

func _make_test_gs() -> GameState:
	var gs: GameState = GameState.new()
	var emp: Empire = Empire.new()
	emp.id = 0
	emp.tech = TechState.new()
	emp.tech.known = ["start", "second_sun", "primary_mount", "peck_driver", "hatch_dart"]
	gs.empires.append(emp)
	return gs

func test_sparrow_starting_stats_and_cost() -> void:
	var gs: GameState = _make_test_gs()
	var d: ShipDesign = ShipDesign.new()
	d.empire_id = 0
	d.hull = "small"
	d.drive = "walk_drive"
	d.plate = "pinfeather_plate"
	d.weapons = [{"part": "wick_talon", "mount": "", "count": 4}]

	var st: Dictionary = DesignRules.stats(_db, gs, d)
	# Sparrow space: 24. Walk drive: 15% of 24 = 4 (ceil). 4 Wick talons: 4 * 5 = 20. Total 24.
	assert_eq(st["space_used"], 24, "Sparrow space used == 24")
	assert_eq(st["space_max"], 24, "Sparrow space max == 24")

	# Sparrow cost: 8 (hull) + 1 (drive 10% of 8, ceil) + 12 (4 * 3) = 21 PP
	assert_eq(st["pp"], 21, "Sparrow total PP == 21")
	assert_eq(st["armed"], true, "Sparrow is armed")
	assert_eq(st["upkeep"], 1, "Sparrow upkeep == 1")

	var valid: String = DesignRules.validate(_db, gs, d)
	assert_eq(valid, "", "Sparrow design validates")

func test_nest_ship_stats_and_cost() -> void:
	var gs: GameState = _make_test_gs()
	var d: ShipDesign = ShipDesign.new()
	d.empire_id = 0
	d.hull = "medium"
	d.drive = "walk_drive"
	d.plate = "pinfeather_plate"
	d.specials = ["nest_pod"]

	var st: Dictionary = DesignRules.stats(_db, gs, d)
	# Nest Ship: medium hull PP 22. Drive: 10% of 22 = ceil(2.2) = 3 PP. Nest pod: 40 PP. Total = 22 + 3 + 40 = 65 PP
	assert_eq(st["pp"], 65, "Nest Ship total PP == 65")
	assert_eq(st["colonize"], true, "Nest Ship has colonize == true")
	assert_eq(st["armed"], false, "Nest Ship is unarmed")
	assert_eq(st["upkeep"], 0, "Unarmed Nest Ship upkeep == 0")

	var valid: String = DesignRules.validate(_db, gs, d)
	assert_eq(valid, "", "Nest Ship design validates")

func test_design_space_allows_4_talons_refuses_5_talons() -> void:
	var gs: GameState = _make_test_gs()
	var d4: ShipDesign = ShipDesign.new()
	d4.empire_id = 0
	d4.hull = "small"
	d4.drive = "walk_drive"
	d4.plate = "pinfeather_plate"
	d4.weapons = [{"part": "wick_talon", "mount": "", "count": 4}]
	assert_eq(DesignRules.validate(_db, gs, d4), "", "Sparrow with 4 Wick Talons ALLOW")

	var d5: ShipDesign = ShipDesign.new()
	d5.empire_id = 0
	d5.hull = "small"
	d5.drive = "walk_drive"
	d5.plate = "pinfeather_plate"
	d5.weapons = [{"part": "wick_talon", "mount": "", "count": 5}]
	assert_eq(DesignRules.validate(_db, gs, d5), "refuse.design_space", "Sparrow with 5 Wick Talons REFUSE design_space")

func test_design_mount_allows_talon_refuses_beak() -> void:
	var gs: GameState = _make_test_gs()
	var dt: ShipDesign = ShipDesign.new()
	dt.empire_id = 0
	dt.hull = "medium"
	dt.drive = "walk_drive"
	dt.plate = "pinfeather_plate"
	dt.weapons = [{"part": "wick_talon", "mount": "primary_mount", "count": 1}]
	assert_eq(DesignRules.validate(_db, gs, dt), "", "Primary mount on Talon weapon ALLOW")

	var dbk: ShipDesign = ShipDesign.new()
	dbk.empire_id = 0
	dbk.hull = "medium"
	dbk.drive = "walk_drive"
	dbk.plate = "pinfeather_plate"
	dbk.weapons = [{"part": "peck_driver", "mount": "primary_mount", "count": 1}]
	assert_eq(DesignRules.validate(_db, gs, dbk), "refuse.design_mount", "Mount on Beak weapon REFUSE design_mount")

func test_design_specials_allows_2_refuses_3_on_kestrel() -> void:
	var gs: GameState = _make_test_gs()
	var d2: ShipDesign = ShipDesign.new()
	d2.empire_id = 0
	d2.hull = "medium"
	d2.drive = "walk_drive"
	d2.plate = "pinfeather_plate"
	d2.specials = ["glance_pod", "perch_pod"]
	assert_eq(DesignRules.validate(_db, gs, d2), "", "Kestrel with 2 specials ALLOW")

	var d3: ShipDesign = ShipDesign.new()
	d3.empire_id = 0
	d3.hull = "medium"
	d3.drive = "walk_drive"
	d3.plate = "pinfeather_plate"
	d3.specials = ["glance_pod", "perch_pod", "boot_pod"]
	assert_eq(DesignRules.validate(_db, gs, d3), "refuse.design_specials", "Kestrel with 3 specials REFUSE design_specials")

func test_swat_mount_halves_space_with_ceil() -> void:
	var gs: GameState = _make_test_gs()
	var d: ShipDesign = ShipDesign.new()
	d.empire_id = 0
	d.hull = "small"
	# Wick Talon base space is 5. Swat mount is 50%. ceil(5 * 50 / 100) = 3
	var sp: int = DesignRules.part_space(_db, gs, d, "wick_talon", "swat_mount")
	assert_eq(sp, 3, "Swat mount halves space with ceil: 5 -> 3")

func test_unarmed_designs_upkeep_zero() -> void:
	var gs: GameState = _make_test_gs()
	var d: ShipDesign = ShipDesign.new()
	d.empire_id = 0
	d.hull = "small"
	d.drive = "walk_drive"
	d.plate = "pinfeather_plate"
	d.specials = ["glance_pod"]
	var st: Dictionary = DesignRules.stats(_db, gs, d)
	assert_eq(st["armed"], false, "Glance is unarmed")
	assert_eq(st["upkeep"], 0, "Unarmed design upkeep is 0")

func test_tech_unknown_refuse_and_allow() -> void:
	var gs: GameState = _make_test_gs()
	var d: ShipDesign = ShipDesign.new()
	d.empire_id = 0
	d.hull = "small"
	d.drive = "migration_drive" # tech: hyper_preened_kinematics (not known)
	d.plate = "pinfeather_plate"
	assert_eq(DesignRules.validate(_db, gs, d), "refuse.tech_unknown", "Unknown drive tech REFUSE tech_unknown")

	d.drive = "walk_drive" # tech: start
	assert_eq(DesignRules.validate(_db, gs, d), "", "Known drive tech ALLOW")

func test_loot_only_refuse_and_allow() -> void:
	var gs: GameState = _make_test_gs()
	var d: ShipDesign = ShipDesign.new()
	d.empire_id = 0
	d.hull = "medium"
	d.drive = "walk_drive"
	d.plate = "pinfeather_plate"
	d.specials = ["orn_plating"] # loot_only: true
	assert_eq(DesignRules.validate(_db, gs, d), "refuse.design_loot", "Loot part without guardian loot REFUSE design_loot")

	gs.empires[0].traits.append("guardian_loot")
	assert_eq(DesignRules.validate(_db, gs, d), "", "Loot part with guardian loot ALLOW")

func test_max_designs_limit_refuse_and_allow() -> void:
	var gs: GameState = _make_test_gs()
	var max_des: int = _db.bal("max_designs")
	for i in range(max_des):
		var existing: ShipDesign = ShipDesign.new()
		existing.id = i
		existing.empire_id = 0
		existing.hull = "small"
		existing.drive = "walk_drive"
		existing.plate = "pinfeather_plate"
		existing.obsolete = false
		gs.designs[i] = existing

	var new_d: ShipDesign = ShipDesign.new()
	new_d.id = -1
	new_d.empire_id = 0
	new_d.hull = "small"
	new_d.drive = "walk_drive"
	new_d.plate = "pinfeather_plate"
	assert_eq(DesignRules.validate(_db, gs, new_d), "refuse.design_limit", "Exceeding max designs REFUSE design_limit")

	# Obsolete design does not count toward limit
	gs.designs[0].obsolete = true
	assert_eq(DesignRules.validate(_db, gs, new_d), "", "With one obsolete design, new design ALLOW")

func test_auto_design_always_validates_for_non_null() -> void:
	var gs: GameState = _make_test_gs()
	for role in AutoDesign.roles():
		var des: ShipDesign = AutoDesign.design_for_role(_db, gs, 0, role)
		if des != null:
			var err: String = DesignRules.validate(_db, gs, des)
			assert_eq(err, "", "AutoDesign for role %s validates (got %s)" % [role, err])
