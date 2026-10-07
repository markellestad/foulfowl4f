extends SceneTree

func _init() -> void:
	var db: ContentDB = ContentDB.load_from("res://data")
	var postures: Array[String] = ["close", "talon", "retreat"]
	var target_priorities: Array[String] = ["biggest", "swat", "closest", "auto"]

	var battles_tested: int = 40
	var battles_mattered: int = 0

	for b_idx in range(battles_tested):
		var seed_str: String = "P9_SEED_%d" % b_idx
		var s: GameSettings = (GameSettings as Variant).call(&"new")
		s.preset = "tiny"
		s.seed_string = seed_str
		s.seed = Rng.seed_from_string(seed_str)
		s.player_race = "pheasants"
		s.seats = ["pheasants", "swans"]
		s.seat_swans = true
		s.all_ai = true

		var game: SimGame = SimGame.create(s, db)
		var gs: GameState = game.gs
		Wars.set_war(gs, 0, 1, true)

		# Setup designs
		var d0: ShipDesign = ShipDesign.new()
		d0.id = gs.alloc_id("design")
		d0.empire_id = 0
		d0.name = "P_War"
		d0.hull = "medium"
		d0.weapons = [
			{"part": "peck_driver", "mount": "", "count": 2},
			{"part": "wick_talon", "mount": "", "count": 1}
		]
		gs.designs[d0.id] = d0

		var d1: ShipDesign = ShipDesign.new()
		d1.id = gs.alloc_id("design")
		d1.empire_id = 1
		d1.name = "AI_War"
		d1.hull = "medium"
		d1.weapons = [
			{"part": "peck_driver", "mount": "", "count": 2}
		]
		gs.designs[d1.id] = d1

		var sys_id: int = 0
		var flt0: Fleet = Fleet.new()
		flt0.id = gs.alloc_id("fleet")
		flt0.owner = 0
		flt0.system_id = sys_id
		var p_count: int = 2 + (b_idx % 3)
		for i in range(p_count):
			var shp: Ship = Ship.new()
			shp.id = gs.alloc_id("ship")
			shp.owner = 0
			shp.design_id = d0.id
			shp.hp = 30
			gs.ships[shp.id] = shp
			flt0.ship_ids.append(shp.id)
		gs.fleets[flt0.id] = flt0

		var flt1: Fleet = Fleet.new()
		flt1.id = gs.alloc_id("fleet")
		flt1.owner = 1
		flt1.system_id = sys_id
		var ai_count: int = 2 + ((b_idx + 1) % 3)
		for i in range(ai_count):
			var shp: Ship = Ship.new()
			shp.id = gs.alloc_id("ship")
			shp.owner = 1
			shp.design_id = d1.id
			shp.hp = 30
			gs.ships[shp.id] = shp
			flt1.ship_ids.append(shp.id)
		gs.fleets[flt1.id] = flt1

		var winners: Array[int] = []
		var pp_lost_list: Array[int] = []

		for posture in postures:
			for prio in target_priorities:
				var custom_orders: Dictionary = {
					0: {
						"posture": posture,
						"target_priority": prio,
						"swat_mode": "missiles_first",
						"retreat_threshold": "never",
						"line_order": []
					},
					1: {
						"posture": "auto",
						"target_priority": "auto",
						"swat_mode": "missiles_first",
						"retreat_threshold": "never",
						"line_order": []
					}
				}

				var input: CombatInput = CombatBuilder.build(gs, db, sys_id, custom_orders)
				if input != null:
					var log: BattleLog = CombatResolver.resolve(input)
					winners.append(log.winner_empire_id)
					var lost_0: int = 0
					if log.losses.has(0):
						var l_val = log.losses[0]
						if l_val is Array:
							lost_0 = (l_val as Array).size()
						elif l_val is int:
							lost_0 = l_val
					pp_lost_list.append(lost_0)

		if not winners.is_empty():
			var first_winner: int = winners[0]
			var winner_differed: bool = false
			for w in winners:
				if w != first_winner:
					winner_differed = true
					break

			var min_l: int = pp_lost_list[0]
			var max_l: int = pp_lost_list[0]
			for l in pp_lost_list:
				if l < min_l: min_l = l
				if l > max_l: max_l = l

			var diff_pct: float = float(max_l - min_l) / max(1.0, float(max_l)) * 100.0
			if winner_differed or diff_pct >= 15.0:
				battles_mattered += 1

	var pct_mattered: float = (float(battles_mattered) / float(battles_tested)) * 100.0
	print("PROBE REPORT P9 Orders matter: %.1f%% (%d/%d differ in winner or PP lost >= 15%%)" % [
		pct_mattered, battles_mattered, battles_tested
	])
	quit(0)
