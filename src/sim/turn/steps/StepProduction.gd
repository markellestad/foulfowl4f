class_name StepProduction
extends TurnStep

var _work_list: Array = []
var _cursor: int = 0

func id() -> StringName:
	return &"production"

func begin(ctx: TurnContext) -> void:
	_work_list = Ids.sorted_keys(ctx.gs.colonies)
	_cursor = 0

func next(ctx: TurnContext) -> bool:
	if _work_list.is_empty():
		return true
	var slice_count: int = ctx.db.bal("slice_items")
	var end_idx: int = min(_cursor + slice_count, _work_list.size())
	for i in range(_cursor, end_idx):
		var cid: int = int(_work_list[i])
		var col: Colony = ctx.gs.colonies[cid]
		var res: Dictionary = Production.process_colony(ctx.db, ctx.gs, cid)

		var comps: Array = res.get("completed_buildings", [])
		for b in comps:
			var planet: Planet = ctx.gs.planets[col.planet_id]
			ctx.report.add_entry("production", "notify.building_done", {
				"building": str(b),
				"place": "Star %d Orbit %d" % [planet.system_id, planet.orbit + 1]
			}, "colony", cid)

		var tg_cr: int = int(res.get("trade_goods_credits", 0))
		if tg_cr > 0:
			var cur: int = int(ctx.trade_goods_by_empire.get(col.owner, 0))
			ctx.trade_goods_by_empire[col.owner] = cur + tg_cr

	_cursor = end_idx
	return _cursor >= _work_list.size()
