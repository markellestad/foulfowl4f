class_name StepMovement
extends TurnStep

var _work_list: Array = []
var _cursor: int = 0

func id() -> StringName:
	return &"movement"

func begin(ctx: TurnContext) -> void:
	_work_list = Ids.sorted_keys(ctx.gs.fleets)
	_cursor = 0

func next(ctx: TurnContext) -> bool:
	if _work_list.is_empty():
		return true
	var slice_count: int = ctx.db.bal("slice_items")
	var end_idx: int = min(_cursor + slice_count, _work_list.size())
	for i in range(_cursor, end_idx):
		var fid: int = int(_work_list[i])
		if not ctx.gs.fleets.has(fid):
			continue
		var flt: Fleet = ctx.gs.fleets[fid]
		if flt.dest_system_id >= 0:
			Movement.advance(ctx.gs, flt)
			if ctx.gs.turn >= flt.arrive_turn:
				flt.system_id = flt.dest_system_id
				var dest_sys: StarSystem = ctx.gs.systems[flt.system_id]
				flt.x = dest_sys.x
				flt.y = dest_sys.y
				flt.dest_system_id = -1
				if ctx.gs.knowledge.has(flt.owner):
					var knw: Knowledge = ctx.gs.knowledge[flt.owner]
					if not knw.explored.has(flt.system_id):
						knw.explored[flt.system_id] = ctx.gs.turn

	_cursor = end_idx
	return _cursor >= _work_list.size()
