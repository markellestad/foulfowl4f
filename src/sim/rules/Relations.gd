class_name Relations
extends RefCounted

static func value(db: ContentDB, gs: GameState, a: int, b: int) -> ModResult:
	var res: ModResult = ModResult.new()
	if gs == null or a == b or a < 0 or b < 0:
		return res
	if a >= gs.empires.size() or b >= gs.empires.size():
		return res

	# 1. Base traits of B as seen by A
	var emp_b: Empire = gs.empires[b]
	var base_val: int = 0
	for t in emp_b.traits:
		var tdef: Dictionary = db.def("traits", t)
		for eff in tdef.get("effects", []):
			if eff.get("stat") == "relations_base":
				var val: int = int(eff.get("value", 0))
				base_val += val
				res.lines.append({
					"source_key": "trait." + t + ".name",
					"op": "add",
					"value": val
				})

	# 2. Border tension (pairs of colonies within border_pair_dpc)
	var border_pair_dpc: int = db.bal("border_pair_dpc")
	var border_tension_per_pair: int = db.bal("border_tension_per_pair")
	var border_tension_cap: int = db.bal("border_tension_cap")

	var cols_a: Array[Colony] = []
	var cols_b: Array[Colony] = []
	for cid in Ids.sorted_keys(gs.colonies):
		var col: Colony = gs.colonies[cid]
		if col.owner == a:
			cols_a.append(col)
		elif col.owner == b:
			cols_b.append(col)

	var pair_count: int = 0
	for ca in cols_a:
		var pa: Planet = gs.planets[ca.planet_id]
		var sa: StarSystem = gs.systems[pa.system_id]
		for cb in cols_b:
			var pb: Planet = gs.planets[cb.planet_id]
			var sb: StarSystem = gs.systems[pb.system_id]
			if IntMath.dist(sa.x, sa.y, sb.x, sb.y) <= border_pair_dpc:
				pair_count += 1

	var tension: int = 0
	if pair_count > 0:
		tension = pair_count * border_tension_per_pair
		if tension < border_tension_cap:
			tension = border_tension_cap
		res.lines.append({
			"source_key": "diplo.relations.border_tension",
			"op": "add",
			"value": tension
		})

	# 3. War penalty
	var war_val: int = 0
	if Wars.is_at_war(gs, a, b):
		war_val = db.bal("relation_base_war")
		res.lines.append({
			"source_key": "diplo.relations.war",
			"op": "add",
			"value": war_val
		})

	var total: int = base_val + tension + war_val
	res.value = clampi(total, -100, 100)
	return res
