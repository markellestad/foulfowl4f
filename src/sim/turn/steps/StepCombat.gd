class_name StepCombat
extends TurnStep

var _contested_systems: Array[int] = []
var _resolved_index: int = 0

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

func begin(ctx: TurnContext) -> void:
	_contested_systems = find_contested_systems(ctx.gs, ctx.db)
	_resolved_index = 0

func next(ctx: TurnContext) -> bool:
	if _resolved_index >= _contested_systems.size():
		return true

	var sys_id: int = _contested_systems[_resolved_index]
	var input: CombatInput = CombatBuilder.build(ctx.gs, ctx.db, sys_id)
	var log: BattleLog = CombatResolver.resolve(input)
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
	return _resolved_index >= _contested_systems.size()
