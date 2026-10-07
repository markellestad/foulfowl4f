class_name MilitaryBudget
extends RefCounted

static func budget_pct(db: ContentDB, policy: String) -> int:
	match policy:
		"peace":
			return db.bal("budget_peace_pct")
		"guarded":
			return db.bal("budget_guarded_pct")
		"war":
			return db.bal("budget_war_pct")
		_:
			return db.bal("budget_guarded_pct")

static func next_role(view: AiView) -> String:
	var db: ContentDB = view.db
	var knw: Knowledge = view.knowledge()
	var emp: Empire = view.own_empire()

	var enemy_horizon_seen: bool = false
	var highest_enemy_shield: int = 0

	for did in knw.known_designs.keys():
		var d_data: Dictionary = knw.known_designs[did]
		if int(d_data.get("empire_id", -1)) == view.empire_id:
			continue

		var weapons: Array = d_data.get("weapons", [])
		for w in weapons:
			var p_id: String = str(w.get("part", ""))
			var pdef: Dictionary = db.def("parts", p_id)
			if str(pdef.get("band", "")) == "horizon":
				enemy_horizon_seen = true
				break
		if str(d_data.get("role", "")) == "horizon_boat":
			enemy_horizon_seen = true

		var mantle: String = str(d_data.get("mantle", ""))
		if mantle != "":
			var mdef: Dictionary = db.def("parts", mantle)
			var s_val: int = int(mdef.get("shield", 0))
			if s_val > highest_enemy_shield:
				highest_enemy_shield = s_val

	for cid in knw.seen_colonies.keys():
		var c_data: Dictionary = knw.seen_colonies[cid]
		if int(c_data.get("owner", -1)) == view.empire_id:
			continue
		if c_data.get("buildings") is Array:
			for b in c_data.get("buildings"):
				var bdef: Dictionary = db.def("buildings", str(b))
				var dblk: Dictionary = bdef.get("defense", {})
				var sh: int = int(dblk.get("planet_shield", 0))
				if sh > highest_enemy_shield:
					highest_enemy_shield = sh

	# Check own swat share among warships
	var own_warships: int = 0
	var own_swat: int = 0

	for s in view.own_ships():
		var des: ShipDesign = null
		for d in view.own_designs():
			if d.id == s.design_id:
				des = d
				break
		if des != null:
			var st: Dictionary = DesignRules.stats(db, view.raw_game_state_DO_NOT_USE_EXCEPT_SIM(), des)
			if bool(st.get("armed", false)):
				own_warships += 1
				if des.role == "swat_escort":
					own_swat += 1

	for col in view.own_colonies():
		for qi in col.queue:
			if qi.kind == "ship":
				var did: int = int(qi.ref_id)
				var des: ShipDesign = null
				for d in view.own_designs():
					if d.id == did:
						des = d
						break
				if des != null:
					var st: Dictionary = DesignRules.stats(db, view.raw_game_state_DO_NOT_USE_EXCEPT_SIM(), des)
					if bool(st.get("armed", false)):
						own_warships += 1
						if des.role == "swat_escort":
							own_swat += 1

	var swat_share_under_25: bool = (own_warships == 0 or (own_swat * 100 < 25 * own_warships))

	var sm_tech: String = str(db.def("parts", "swat_mount").get("tech", "start"))
	var can_build_swat: bool = (sm_tech == "start" or (emp.tech != null and emp.tech.knows(sm_tech)))

	if enemy_horizon_seen and swat_share_under_25 and can_build_swat:
		return "swat_escort"

	var beak_known: bool = false
	for b in ["anvil_beak", "gizzard_bore", "clatter_bill", "peck_driver"]:
		var b_tech: String = str(db.def("parts", b).get("tech", "start"))
		if b_tech == "start" or (emp.tech != null and emp.tech.knows(b_tech)):
			beak_known = true
			break

	if highest_enemy_shield >= 4 and beak_known:
		return "beak_line"

	return "talon_line"
