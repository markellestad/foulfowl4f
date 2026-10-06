class_name StepGovernor
extends TurnStep

var _work_empires: Array = []
var _cursor: int = 0

func id() -> StringName:
	return &"governor"

func begin(ctx: TurnContext) -> void:
	_work_empires = []
	for i in range(ctx.gs.empires.size()):
		_work_empires.append(i)
	_cursor = 0

func next(ctx: TurnContext) -> bool:
	if _work_empires.is_empty():
		return true

	var slice_count: int = ctx.db.bal("slice_items")
	var end_idx: int = min(_cursor + slice_count, _work_empires.size())
	for i in range(_cursor, end_idx):
		var eid: int = int(_work_empires[i])
		Governor.assign_jobs(ctx.db, ctx.gs, eid)
		Governor.fill_queues(ctx.db, ctx.gs, eid, ctx.report)

	_cursor = end_idx
	return _cursor >= _work_empires.size()
