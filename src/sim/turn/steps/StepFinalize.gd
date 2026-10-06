class_name StepFinalize
extends TurnStep

func id() -> StringName:
	return &"finalize"

func begin(_ctx: TurnContext) -> void:
	pass

func next(ctx: TurnContext) -> bool:
	# Collect ships that fought in a battle this turn
	var ships_in_battle_this_turn: Array[int] = []
	for blog in ctx.gs.battle_logs:
		if int(blog.get("turn", -1)) == ctx.gs.turn:
			var init_units: Array = blog.get("initial_units", [])
			for u in init_units:
				var s_id: int = int(u.get("ship_id", u.get("uid", -1)))
				if s_id >= 0:
					ships_in_battle_this_turn.append(s_id)

	# Ship repair
	for s in ctx.gs.ships.values():
		if s.hp <= 0:
			continue
		if ships_in_battle_this_turn.has(s.id):
			continue
		if not ctx.gs.fleets.has(s.fleet_id):
			continue
		var flt: Fleet = ctx.gs.fleets[s.fleet_id]
		if flt.system_id < 0:
			# Deep space / in transit: 0 repair
			continue

		# Check own colonies at this system
		var has_own_colony: bool = false
		var has_yard_colony: bool = false
		for col in ctx.gs.colonies.values():
			var sys: StarSystem = ctx.gs.system_of_planet(col.planet_id)
			if sys != null and sys.id == flt.system_id and col.owner == s.owner:
				has_own_colony = true
				for bid in col.buildings:
					var bdef: Dictionary = ctx.db.def("buildings", bid)
					if bool(bdef.get("counts_as_yard", false)):
						has_yard_colony = true
						break

		if not has_own_colony:
			continue

		var is_huddle: bool = false
		if s.owner >= 0 and s.owner < ctx.gs.empires.size():
			var emp: Empire = ctx.gs.empires[s.owner]
			if emp.traits.has("huddle"):
				is_huddle = true

		var repair_pct: int = 20
		if has_yard_colony or is_huddle:
			repair_pct = 100

		var max_hp: int = s.hp
		if s.design_id >= 0 and ctx.gs.designs.has(s.design_id):
			var des: ShipDesign = ctx.gs.designs[s.design_id]
			var st: Dictionary = DesignRules.stats(ctx.db, ctx.gs, des)
			max_hp = int(st.get("hp", s.hp))

		var heal: int = IntMath.floor_div(max_hp * repair_pct, 100)
		s.hp = mini(max_hp, s.hp + heal)

	for emp in ctx.gs.empires:
		var kept: Array[TimedMod] = []
		for tm in emp.timed_mods:
			if ctx.gs.turn <= tm.until_turn:
				kept.append(tm)
		emp.timed_mods = kept

	ctx.gs.turn += 1
	ctx.gs.report = ctx.report
	return true
