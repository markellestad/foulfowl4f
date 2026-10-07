class_name StepCombat
extends TurnStep

enum Phase { CHECK_STOP, RESOLVE }

var _phase: Phase = Phase.CHECK_STOP
var _contested_systems: Array[int] = []
var _resolved_index: int = 0
var _ai_orders_by_sys: Dictionary = {} # sys_id -> { emp_id -> Dictionary }
var _player_standing_by_sys: Dictionary = {} # sys_id -> Dictionary
var _requests_built: bool = false

func id() -> StringName:
	return &"combat"

static func find_contested_systems(gs: GameState, db: ContentDB) -> Array[int]:
	var contested: Array[int] = []
	for sys in gs.systems:
		var empires_present: Array[int] = []
		var has_armed: bool = false

		for f in gs.fleets.values():
			if f.system_id == sys.id:
				if not empires_present.has(f.owner):
					empires_present.append(f.owner)
				for sid in f.ship_ids:
					if gs.ships.has(sid):
						var s: Ship = gs.ships[sid]
						if s.hp > 0:
							if s.owner == Monsters.MONSTER_EMPIRE_ID:
								has_armed = true
							elif s.design_id >= 0 and gs.designs.has(s.design_id):
								var des: ShipDesign = gs.designs[s.design_id]
								var st: Dictionary = DesignRules.stats(db, gs, des)
								if bool(st.get("is_armed", false)):
									has_armed = true

		for col in gs.colonies.values():
			var c_sys: StarSystem = gs.system_of_planet(col.planet_id)
			if c_sys != null and c_sys.id == sys.id:
				if not empires_present.has(col.owner):
					empires_present.append(col.owner)
				if col.defense_hp > 0:
					has_armed = true

		if not has_armed or empires_present.size() < 2:
			continue

		var at_war: bool = false
		for i in range(empires_present.size()):
			for j in range(i + 1, empires_present.size()):
				if Wars.is_at_war(gs, empires_present[i], empires_present[j]):
					at_war = true
					break
			if at_war:
				break

		if at_war:
			contested.append(sys.id)

	contested.sort()
	return contested

static func count_armed_ships(gs: GameState, db: ContentDB, sys_id: int, emp_id: int) -> int:
	var count: int = 0
	for f in gs.fleets.values():
		if f.system_id == sys_id and f.owner == emp_id:
			for sid in f.ship_ids:
				if gs.ships.has(sid):
					var s: Ship = gs.ships[sid]
					if s.hp > 0:
						if s.owner == Monsters.MONSTER_EMPIRE_ID:
							count += 1
						elif s.design_id >= 0 and gs.designs.has(s.design_id):
							var des: ShipDesign = gs.designs[s.design_id]
							var st: Dictionary = DesignRules.stats(db, gs, des)
							if bool(st.get("is_armed", false)):
								count += 1
	return count

static func count_enemy_armed_ships(gs: GameState, db: ContentDB, sys_id: int, own_emp_id: int) -> int:
	var count: int = 0
	for f in gs.fleets.values():
		if f.system_id == sys_id and f.owner != own_emp_id and Wars.is_at_war(gs, own_emp_id, f.owner):
			for sid in f.ship_ids:
				if gs.ships.has(sid):
					var s: Ship = gs.ships[sid]
					if s.hp > 0:
						if s.owner == Monsters.MONSTER_EMPIRE_ID:
							count += 1
						elif s.design_id >= 0 and gs.designs.has(s.design_id):
							var des: ShipDesign = gs.designs[s.design_id]
							var st: Dictionary = DesignRules.stats(db, gs, des)
							if bool(st.get("is_armed", false)):
								count += 1
	return count

static func has_bomb_parts_in_system(gs: GameState, db: ContentDB, sys_id: int) -> bool:
	for f in gs.fleets.values():
		if f.system_id == sys_id:
			for sid in f.ship_ids:
				if gs.ships.has(sid):
					var s: Ship = gs.ships[sid]
					if s.hp > 0 and s.design_id >= 0 and gs.designs.has(s.design_id):
						var des: ShipDesign = gs.designs[s.design_id]
						for sp in des.specials:
							var pdef: Dictionary = db.def("parts", sp) if db != null else {}
							if pdef.has("bomb_milli"):
								return true
						for w in des.weapons:
							var pid: String = str(w.get("part", ""))
							var pdef: Dictionary = db.def("parts", pid) if db != null else {}
							if pdef.has("bomb_milli"):
								return true
	return false

static func calc_total_armed_pp(gs: GameState, db: ContentDB, sys_id: int) -> int:
	var total_pp: int = 0
	for f in gs.fleets.values():
		if f.system_id == sys_id:
			for sid in f.ship_ids:
				if gs.ships.has(sid):
					var s: Ship = gs.ships[sid]
					if s.hp > 0 and s.design_id >= 0 and gs.designs.has(s.design_id):
						var des: ShipDesign = gs.designs[s.design_id]
						var st: Dictionary = DesignRules.stats(db, gs, des)
						if bool(st.get("is_armed", false)):
							total_pp += int(st.get("cost_pp", 0))
	return total_pp

func begin(ctx: TurnContext) -> void:
	_contested_systems = find_contested_systems(ctx.gs, ctx.db)
	_resolved_index = 0
	_phase = Phase.CHECK_STOP
	_ai_orders_by_sys.clear()
	_player_standing_by_sys.clear()
	_requests_built = false

func _build_request(ctx: TurnContext, sys_id: int) -> Dictionary:
	var gs: GameState = ctx.gs
	var db: ContentDB = ctx.db

	var hulls: Dictionary = {}
	var known_designs: Array[String] = []
	var knw: Knowledge = gs.knowledge.get(0)

	for f in gs.fleets.values():
		if f.system_id == sys_id and f.owner != 0 and Wars.is_at_war(gs, 0, f.owner):
			for sid in f.ship_ids:
				if gs.ships.has(sid):
					var s: Ship = gs.ships[sid]
					if s.hp > 0:
						if s.owner == Monsters.MONSTER_EMPIRE_ID:
							var m_name: String = f.name.to_lower()
							hulls[m_name] = int(hulls.get(m_name, 0)) + 1
							var cap_name: String = f.name.capitalize()
							if not known_designs.has(cap_name):
								known_designs.append(cap_name)
						elif s.design_id >= 0 and gs.designs.has(s.design_id):
							var des: ShipDesign = gs.designs[s.design_id]
							hulls[des.hull] = int(hulls.get(des.hull, 0)) + 1
							if knw != null and knw.known_designs.has(s.design_id):
								if not known_designs.has(des.name):
									known_designs.append(des.name)

	var preview_input: CombatInput = CombatBuilder.build(gs, db, sys_id)
	var own_party: CombatParty = null
	var enemy_party: CombatParty = null
	for p in preview_input.parties:
		if p.empire_id == 0 and not p.is_colony_defense:
			own_party = p
		elif p.empire_id != 0 and Wars.is_at_war(gs, 0, p.empire_id):
			if enemy_party == null or p.units.size() > enemy_party.units.size():
				enemy_party = p

	var odds: int = 50
	if own_party != null and enemy_party != null:
		odds = CombatMath.odds_pct(own_party, enemy_party)

	var d0: int = 10
	if own_party != null and enemy_party != null:
		var key: String = "%d_%d" % [mini(own_party.party_id, enemy_party.party_id), maxi(own_party.party_id, enemy_party.party_id)]
		d0 = int(preview_input.start_distances.get(key, 10))

	var s_own: int = 1
	var s_enemy: int = 1
	var p_own: int = 5
	if own_party != null:
		var own_uids: Array[int] = []
		for u in own_party.units: own_uids.append(u.uid)
		s_own = own_party.get_combat_speed(own_uids)
		p_own = RangeTrack.preferred(own_party.posture, own_party.auto_band, own_party.has_horizon_ammo())
	if enemy_party != null:
		var en_uids: Array[int] = []
		for u in enemy_party.units: en_uids.append(u.uid)
		s_enemy = enemy_party.get_combat_speed(en_uids)

	var proj: Dictionary = RangeTrack.project(d0, p_own, s_own, s_enemy)
	var plan: Dictionary = _player_standing_by_sys.get(sys_id, {
		"posture": "auto",
		"target_priority": "auto",
		"swat_mode": "missiles_first",
		"retreat_threshold": "never",
		"line_order": []
	}).duplicate(true)

	return {
		"system_id": sys_id,
		"enemy_visible": {
			"hulls": hulls,
			"designs": known_designs
		},
		"odds_pct": odds,
		"plan": plan,
		"projection": proj
	}

func next(ctx: TurnContext) -> bool:
	var f := FileAccess.open("res://build/debug_out.txt", FileAccess.READ_WRITE if FileAccess.file_exists("res://build/debug_out.txt") else FileAccess.WRITE)
	if f != null:
		f.seek_end()
		f.store_line("SC_NEXT: phase=%d, cont_size=%d, res_idx=%d" % [_phase, _contested_systems.size(), _resolved_index])
		f.flush()
		f.close()

	if _phase == Phase.CHECK_STOP:
		# Fix AI orders and player standing plans for all contested systems
		for sys_id in _contested_systems:
			_ai_orders_by_sys[sys_id] = {}
			var empires_at_sys: Dictionary = {}
			for fl in ctx.gs.fleets.values():
				if fl.system_id == sys_id:
					if not empires_at_sys.has(fl.owner):
						empires_at_sys[fl.owner] = []
					empires_at_sys[fl.owner].append(fl)

			for emp_id in empires_at_sys.keys():
				var flist: Array = empires_at_sys[emp_id]
				var ranked_fleets: Array = flist.duplicate()
				ranked_fleets.sort_custom(func(a: Fleet, b: Fleet) -> bool:
					var pp_a: int = CombatBuilder.fleet_armed_pp(ctx.gs, ctx.db, a)
					var pp_b: int = CombatBuilder.fleet_armed_pp(ctx.gs, ctx.db, b)
					if pp_a != pp_b:
						return pp_a > pp_b
					return a.id < b.id
				)
				var best_fleet: Fleet = ranked_fleets[0] if not ranked_fleets.is_empty() else null
				var ords: Dictionary = CombatBuilder.ai_orders(best_fleet)
				var combined_lo: Array[int] = []
				for rf in ranked_fleets:
					for x in rf.line_order:
						if not combined_lo.has(int(x)):
							combined_lo.append(int(x))
				ords["line_order"] = combined_lo

				var is_ai_emp: bool = (emp_id != 0 or (ctx.gs.settings != null and ctx.gs.settings.all_ai)) and emp_id >= 0 and emp_id < ctx.gs.empires.size()
				if is_ai_emp:
					var view: AiView = AiView.build(ctx.gs, ctx.db, emp_id)
					var enemy_horizon: bool = false
					var enemy_shield: bool = false
					var own_swat: bool = false
					var faster_beak: bool = false
					var slower_talon: bool = false

					for other_fl in ctx.gs.fleets.values():
						if other_fl.system_id == sys_id and Wars.is_at_war(ctx.gs, emp_id, other_fl.owner):
							for sid in other_fl.ship_ids:
								var s: Ship = ctx.gs.ships.get(sid)
								if s != null and s.hp > 0 and ctx.gs.designs.has(s.design_id):
									var des: ShipDesign = ctx.gs.designs[s.design_id]
									for w in des.weapons:
										var pdef: Dictionary = ctx.db.def("parts", str(w.get("part", "")))
										if str(pdef.get("band", "")) == "horizon":
											enemy_horizon = true
										if str(pdef.get("band", "")) == "beak":
											slower_talon = true

					for col in ctx.gs.colonies.values():
						var cs: StarSystem = ctx.gs.system_of_planet(col.planet_id)
						if cs != null and cs.id == sys_id and Wars.is_at_war(ctx.gs, emp_id, col.owner):
							if col.defense_hp > 0:
								for b in col.buildings:
									var bdef: Dictionary = ctx.db.def("buildings", str(b))
									var dblk: Dictionary = bdef.get("defense", {})
									if dblk.has("launchers"):
										enemy_horizon = true
									if dblk.has("planet_shield"):
										enemy_shield = true

					var req: Dictionary = {
						"standing_plan": ords,
						"odds": 50,
						"enemy_horizon_heavy": enemy_horizon,
						"enemy_high_shield": enemy_shield,
						"own_swat_mounts": own_swat,
						"faster_beak": faster_beak,
						"slower_talon_vs_beak": slower_talon and not enemy_shield,
						"own_horizon_heavy": false
					}
					ords = AiBattle.choose_orders(view, req)

				if emp_id == 0 and not is_ai_emp:
					_player_standing_by_sys[sys_id] = ords
				else:
					_ai_orders_by_sys[sys_id][emp_id] = ords

		# Check qualification
		var big_battle_armed: int = ctx.db.bal("big_battle_armed") if ctx.db != null else 3
		var orders_stop_cards: int = ctx.db.bal("orders_stop_cards") if ctx.db != null else 3

		var qualifying: Array[Dictionary] = []
		for sys_id in _contested_systems:
			var own_armed: int = count_armed_ships(ctx.gs, ctx.db, sys_id, 0)
			var enemy_armed: int = count_enemy_armed_ships(ctx.gs, ctx.db, sys_id, 0)
			var has_bombs: bool = has_bomb_parts_in_system(ctx.gs, ctx.db, sys_id)

			var qualifies: bool = false
			if ctx.orders_mode == "always" and own_armed >= 1:
				qualifies = true
			elif ctx.orders_mode == "big" and own_armed >= 1 and (own_armed >= big_battle_armed or enemy_armed >= big_battle_armed or has_bombs):
				qualifies = true

			if qualifies:
				var total_pp: int = calc_total_armed_pp(ctx.gs, ctx.db, sys_id)
				qualifying.append({
					"system_id": sys_id,
					"pp": total_pp
				})

		qualifying.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if a["pp"] != b["pp"]:
				return a["pp"] > b["pp"]
			return a["system_id"] < b["system_id"]
		)

		if not qualifying.is_empty() and not ctx.is_headless and ctx.orders_mode != "never" and not _requests_built:
			_requests_built = true
			ctx.requests.clear()
			ctx.auto_systems.clear()
			ctx.gs.pending_battle_requests.clear()

			for i in range(qualifying.size()):
				var q_sys_id: int = int(qualifying[i]["system_id"])
				if i < orders_stop_cards:
					var req: Dictionary = _build_request(ctx, q_sys_id)
					ctx.requests.append(req)
					ctx.gs.pending_battle_requests.append(q_sys_id)
				else:
					ctx.auto_systems.append(q_sys_id)

			if not ctx.requests.is_empty():
				if ctx.tp != null:
					ctx.tp.requests = ctx.requests.duplicate(true)
					ctx.tp.auto_systems = ctx.auto_systems.duplicate()
					ctx.tp.status = TurnProcessor.Status.NEEDS_INPUT
				_phase = Phase.RESOLVE
				return false

		_phase = Phase.RESOLVE

	# Phase.RESOLVE
	if _resolved_index >= _contested_systems.size():
		ctx.gs.pending_battle_requests.clear()
		return true

	var sys_id: int = _contested_systems[_resolved_index]
	var custom_orders: Dictionary = {}
	if _ai_orders_by_sys.has(sys_id):
		for emp_id in _ai_orders_by_sys[sys_id].keys():
			custom_orders[emp_id] = _ai_orders_by_sys[sys_id][emp_id]

	if _ai_orders_by_sys.has(sys_id) and _ai_orders_by_sys[sys_id].has(0):
		custom_orders[0] = _ai_orders_by_sys[sys_id][0]
	elif ctx.pending_orders.has(sys_id):
		custom_orders[0] = ctx.pending_orders[sys_id]
	elif _player_standing_by_sys.has(sys_id):
		custom_orders[0] = _player_standing_by_sys[sys_id]

	var input: CombatInput = CombatBuilder.build(ctx.gs, ctx.db, sys_id, custom_orders)
	if input != null:
		var log: BattleLog = CombatResolver.resolve(input)
		if log != null:
			CombatApply.apply(ctx.gs, ctx.db, log)

			if ctx.report != null:
				var autopsy: Dictionary = Autopsy.analyze(log)
				var sys_name: String = "System %d" % sys_id
				if sys_id >= 0 and sys_id < ctx.gs.systems.size():
					sys_name = ctx.gs.systems[sys_id].name
				ctx.report.add_entry("military", "military.battle", {
					"system": sys_name,
					"winner": log.winner_empire_id,
					"is_stalemate": log.is_stalemate,
					"deciding_band": autopsy["deciding_band"],
					"standout": autopsy["standout_name"],
					"log_index": ctx.gs.battle_logs.size() - 1
				}, "system", sys_id)

	_resolved_index += 1
	if _resolved_index >= _contested_systems.size():
		ctx.gs.pending_battle_requests.clear()
		return true
	return false
