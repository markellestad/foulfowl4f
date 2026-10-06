class_name Knowledge
extends RefCounted

var explored: Dictionary = {}                # system_id (int) -> turn explored (int)
var seen_colonies: Dictionary = {}           # colony_id (int) -> {"owner": int, "species": String, "pop_units": int, "buildings": Array or null, "is_outpost": bool, "turn_seen": int}
var visible_fleets: Dictionary = {}          # fleet_id (int) -> {"owner": int, "x": int, "y": int, "ship_count": int, "design_ids": Array[int], "dest_system_id": int}
var known_designs: Dictionary = {}           # design_id (int) -> design.to_dict() snapshot
var met: Dictionary = {}                     # empire_id (int) -> turn met (int)

func to_dict() -> Dictionary:
	var exp_dict: Dictionary = {}
	for sid in Ids.sorted_keys(explored):
		exp_dict[str(sid)] = int(explored[sid])

	var col_dict: Dictionary = {}
	for cid in Ids.sorted_keys(seen_colonies):
		var c_info: Dictionary = seen_colonies[cid]
		var b_copy: Variant = null
		if c_info.get("buildings") != null:
			var b_arr: Array = []
			for b in c_info["buildings"]:
				b_arr.append(str(b))
			b_copy = b_arr
		col_dict[str(cid)] = {
			"owner": int(c_info.get("owner", -1)),
			"species": str(c_info.get("species", "")),
			"pop_units": int(c_info.get("pop_units", 0)),
			"buildings": b_copy,
			"is_outpost": bool(c_info.get("is_outpost", false)),
			"turn_seen": int(c_info.get("turn_seen", 0))
		}

	var flt_dict: Dictionary = {}
	for fid in Ids.sorted_keys(visible_fleets):
		var f_info: Dictionary = visible_fleets[fid]
		var d_arr: Array = []
		if f_info.has("design_ids") and f_info["design_ids"] is Array:
			for did in f_info["design_ids"]:
				d_arr.append(int(did))
		flt_dict[str(fid)] = {
			"owner": int(f_info.get("owner", -1)),
			"x": int(f_info.get("x", 0)),
			"y": int(f_info.get("y", 0)),
			"ship_count": int(f_info.get("ship_count", 0)),
			"design_ids": d_arr,
			"dest_system_id": int(f_info.get("dest_system_id", -1))
		}

	var des_dict: Dictionary = {}
	for did in Ids.sorted_keys(known_designs):
		des_dict[str(did)] = (known_designs[did] as Dictionary).duplicate(true)

	var met_dict: Dictionary = {}
	for eid in Ids.sorted_keys(met):
		met_dict[str(eid)] = int(met[eid])

	return {
		"explored": exp_dict,
		"seen_colonies": col_dict,
		"visible_fleets": flt_dict,
		"known_designs": des_dict,
		"met": met_dict
	}

static func from_dict(d: Dictionary) -> Knowledge:
	var k: Knowledge = Knowledge.new()

	k.explored.clear()
	var raw_exp: Dictionary = d.get("explored", {})
	for sid_str in raw_exp.keys():
		k.explored[int(sid_str)] = int(raw_exp[sid_str])

	k.seen_colonies.clear()
	var raw_cols: Dictionary = d.get("seen_colonies", {})
	for cid_str in raw_cols.keys():
		var c_data: Dictionary = raw_cols[cid_str]
		var b_val: Variant = null
		if c_data.get("buildings") != null:
			var b_arr: Array[String] = []
			for b in c_data["buildings"]:
				b_arr.append(str(b))
			b_val = b_arr
		k.seen_colonies[int(cid_str)] = {
			"owner": int(c_data.get("owner", -1)),
			"species": str(c_data.get("species", "")),
			"pop_units": int(c_data.get("pop_units", 0)),
			"buildings": b_val,
			"is_outpost": bool(c_data.get("is_outpost", false)),
			"turn_seen": int(c_data.get("turn_seen", 0))
		}

	k.visible_fleets.clear()
	var raw_flts: Dictionary = d.get("visible_fleets", {})
	for fid_str in raw_flts.keys():
		var f_data: Dictionary = raw_flts[fid_str]
		var d_arr: Array[int] = []
		if f_data.has("design_ids") and f_data["design_ids"] is Array:
			for did in f_data["design_ids"]:
				d_arr.append(int(did))
		k.visible_fleets[int(fid_str)] = {
			"owner": int(f_data.get("owner", -1)),
			"x": int(f_data.get("x", 0)),
			"y": int(f_data.get("y", 0)),
			"ship_count": int(f_data.get("ship_count", 0)),
			"design_ids": d_arr,
			"dest_system_id": int(f_data.get("dest_system_id", -1))
		}

	k.known_designs.clear()
	var raw_des: Dictionary = d.get("known_designs", {})
	for did_str in raw_des.keys():
		k.known_designs[int(did_str)] = (raw_des[did_str] as Dictionary).duplicate(true)

	k.met.clear()
	var raw_met: Dictionary = d.get("met", {})
	for eid_str in raw_met.keys():
		k.met[int(eid_str)] = int(raw_met[eid_str])

	return k
