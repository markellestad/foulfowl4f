class_name Bombardment
extends RefCounted

static func apply_bombardment(gs: GameState, db: ContentDB, fleet: Fleet, colony: Colony, report: TurnReport = null) -> int:
	if gs == null or db == null or fleet == null or colony == null:
		return 0

	if not colony.bombarded_by.has(fleet.owner):
		colony.bombarded_by.append(fleet.owner)

	var has_toxic_preening: bool = false
	if fleet.owner >= 0 and fleet.owner < gs.empires.size():
		var emp: Empire = gs.empires[fleet.owner]
		if emp.tech != null and emp.tech.known.has("toxic_preening"):
			has_toxic_preening = true

	var best_bomb_pct: int = 0
	for bid in colony.buildings:
		var bdef: Dictionary = db.def("buildings", bid)
		var def_blk: Dictionary = bdef.get("defense", {})
		if def_blk.has("bomb_pct"):
			var bp: int = int(def_blk["bomb_pct"])
			if bp < best_bomb_pct:
				best_bomb_pct = bp

	var normal_milli: int = 0
	var ignore_shield_milli: int = 0

	for sid in fleet.ship_ids:
		var s: Ship = gs.ships.get(sid)
		if s == null or s.hp <= 0 or s.design_id < 0 or not gs.designs.has(s.design_id):
			continue
		var des: ShipDesign = gs.designs[s.design_id]
		for sp in des.specials:
			var pdef: Dictionary = db.def("parts", sp)
			if pdef.has("bomb_milli"):
				var bm: int = int(pdef["bomb_milli"])
				if bool(pdef.get("bomb_ignores_shield", false)):
					ignore_shield_milli += bm
				else:
					normal_milli += bm

	if has_toxic_preening:
		normal_milli *= 2
		ignore_shield_milli *= 2

	var reduced_normal: int = IntMath.floor_div(normal_milli * (100 + best_bomb_pct), 100)
	var total_killed: int = reduced_normal + ignore_shield_milli

	colony.pop_milli = maxi(0, colony.pop_milli - total_killed)

	var new_units: int = colony.pop_units()
	var excess_jobs: int = (colony.farmers + colony.workers + colony.scientists) - new_units
	if excess_jobs > 0:
		var rw: int = mini(colony.workers, excess_jobs)
		colony.workers -= rw
		excess_jobs -= rw
		if excess_jobs > 0:
			var rs: int = mini(colony.scientists, excess_jobs)
			colony.scientists -= rs
			excess_jobs -= rs
		if excess_jobs > 0:
			var rf: int = mini(colony.farmers, excess_jobs)
			colony.farmers -= rf

	if colony.pop_milli <= 0:
		var pid: int = colony.planet_id
		if pid >= 0 and pid < gs.planets.size():
			gs.planets[pid].colony_id = -1
		gs.colonies.erase(colony.id)

	return total_killed
