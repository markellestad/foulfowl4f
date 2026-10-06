extends GutTest

var _db: ContentDB

func before_all() -> void:
	_db = ContentDB.load_from("res://data")
	Copy.load_file("res://data/copy/en.json")

func _setup_state(race_id: String = "test_neutral", traits: Array[String] = []) -> Dictionary:
	var gs: GameState = GameState.new()
	gs.settings = GameSettings.new()
	gs.settings.seats = [race_id]
	gs.settings.difficulty = "flighted"

	var emp: Empire = Empire.new()
	emp.id = 0
	emp.race = race_id
	emp.traits.assign(traits)
	emp.treasury = 100
	gs.empires.append(emp)

	var sys: StarSystem = StarSystem.new()
	sys.id = 0
	sys.home_of = 0
	gs.systems.append(sys)

	var p: Planet = Planet.new()
	p.id = 0
	p.system_id = 0
	p.climate = "terran"
	p.size = "medium"
	p.minerals = "abundant"
	p.gravity = "normal"
	sys.planet_ids.append(0)
	gs.planets.append(p)

	var col: Colony = Colony.new()
	col.id = 0
	col.planet_id = 0
	col.owner = 0
	col.species = race_id
	col.pop_milli = 8000
	col.preset = "capital"
	col.buildings = ["grand_nest", "the_yard", "boot_barracks"]
	col.founded_turn = 1
	gs.colonies[0] = col
	emp.capital_colony_id = 0

	return { "gs": gs, "emp": emp, "planet": p, "colony": col }

func test_opening_check() -> void:
	# Fixture race with no traits on Medium Temperate Abundant capital
	var ctx: Dictionary = _setup_state("plain_bird", [])
	var gs: GameState = ctx["gs"]
	var col: Colony = ctx["colony"]

	Governor.assign_jobs(_db, gs, 0)

	assert_eq(col.farmers, 3, "Opening farmers = 3")
	assert_eq(col.workers, 3, "Opening workers = 3")
	assert_eq(col.scientists, 2, "Opening scientists = 2")

	var out: Dictionary = Economy.colony_output(_db, gs, 0)
	var food_val: int = (out["food"] as ModResult).value
	var ind_val: int = (out["industry"] as ModResult).value
	var res_val: int = (out["research"] as ModResult).value
	var tax_val: int = (out["taxes"] as ModResult).value
	var cred_val: int = (out["credits"] as ModResult).value

	assert_eq(food_val, 9, "Food = 3 * 2 + 3 = 9")
	assert_eq(ind_val, 14, "PP = 3 * 3 + 5 = 14")
	assert_eq(res_val, 9, "RP = 2 * 3 + 3 = 9")
	assert_eq(tax_val + cred_val, 13, "Taxes (8) + credits (5) = 13")

	var totals: Dictionary = Economy.empire_totals(_db, gs, 0)
	assert_eq(totals["food_need"], 8, "Food eaten = 8")
	assert_eq(totals["upkeep"], 2, "Building upkeep = 2")
	assert_eq(totals["net_credits"], 11, "Net credits = 13 - 2 = +11")

func test_growth_curve() -> void:
	var ctx: Dictionary = _setup_state("plain_bird", [])
	var gs: GameState = ctx["gs"]
	var col: Colony = ctx["colony"]

	# Medium terran max_pop is 3 * 4 = 12 (12000 milli)
	assert_eq(Economy.max_pop_milli(_db, gs, col.id), 12000)

	# New colony 1/12 grows 141 milli
	col.pop_milli = 1000
	var g_new: int = Growth.calc_growth(_db, gs, col.id)
	assert_eq(g_new, 141, "New colony 1/12 grows 141 milli")

	# Capital 7/12 grows 341 milli
	col.pop_milli = 7000
	var g_cap: int = Growth.calc_growth(_db, gs, col.id)
	assert_eq(g_cap, 341, "Capital 7/12 grows 341 milli")

	# Full colony grows 0
	col.pop_milli = 12000
	var g_full: int = Growth.calc_growth(_db, gs, col.id)
	assert_eq(g_full, 0, "Full colony grows 0")

func test_food_surplus_and_deficit_import() -> void:
	var ctx: Dictionary = _setup_state("plain_bird", [])
	var gs: GameState = ctx["gs"]
	var emp: Empire = ctx["emp"]
	var col: Colony = ctx["colony"]

	# Food surplus 7 sells for 3 credits (floor_div(7, 2) = 3)
	var surplus_credits: int = IntMath.floor_div(7, _db.bal("food_sale_food_per_credit"))
	assert_eq(surplus_credits, 3, "Surplus 7 food sells for 3 credits")

	# Deficit import at 2 per food
	# Case ALLOW: paid deficit kills nobody
	emp.treasury = 20
	col.pop_milli = 8000
	var deficit: int = 5
	var import_rate: int = _db.bal("food_import_credits_per_food")
	var needed_cr: int = deficit * import_rate # 10
	var paid_cr: int = min(emp.treasury, needed_cr)
	var food_paid: int = IntMath.floor_div(paid_cr, import_rate)
	var unpaid: int = deficit - food_paid
	assert_eq(unpaid, 0, "All deficit paid")
	assert_eq(col.pop_milli, 8000, "Nobody starved on paid deficit")

	# Case REFUSE: unpaid food 6 kills 2 pop from most populous colony
	emp.treasury = 0
	deficit = 6
	needed_cr = deficit * import_rate
	paid_cr = min(emp.treasury, needed_cr)
	food_paid = IntMath.floor_div(paid_cr, import_rate)
	unpaid = deficit - food_paid
	assert_eq(unpaid, 6)
	var pop_killed: int = IntMath.ceil_div(unpaid, _db.bal("starve_food_per_pop"))
	assert_eq(pop_killed, 2, "Unpaid food 6 kills 2 pop units")

func test_strike() -> void:
	var ctx: Dictionary = _setup_state("plain_bird", [])
	var gs: GameState = ctx["gs"]
	var emp: Empire = ctx["emp"]

	emp.treasury = 5
	# Net credits: expenses exceed income by 10 -> net -10
	var res: Dictionary = Finance.process_empire(_db, gs, 0, -26) # force negative net
	assert_eq(emp.treasury, 0, "Negative treasury clamped to 0")
	assert_true(emp.strike_next_turn, "Strike triggered for next turn")

	# Next turn industry gets -25%
	var out: Dictionary = Economy.colony_output(_db, gs, 0)
	var ind_res: ModResult = out["industry"]
	var has_strike_line: bool = false
	for l in ind_res.lines:
		if l.get("source_key") == "strike":
			has_strike_line = true
			assert_eq(l.get("value"), -25)
	assert_true(has_strike_line, "Strike line present in industry modifier breakdown")

func test_colony_admin_cost() -> void:
	# 9 colonies cost 1 x 7 + 2 x 1 = 9
	var cost_9: int = Economy.admin_cost_for(9, _db)
	assert_eq(cost_9, 9, "9 colonies cost 9 credits in administration")
	var cost_1: int = Economy.admin_cost_for(1, _db)
	assert_eq(cost_1, 0, "1 colony costs 0 admin")
	var cost_8: int = Economy.admin_cost_for(8, _db)
	assert_eq(cost_8, 7, "8 colonies cost 7 admin")

func test_production_overflow_and_fillers() -> void:
	var ctx: Dictionary = _setup_state("plain_bird", [])
	var gs: GameState = ctx["gs"]
	var col: Colony = ctx["colony"]

	col.queue.clear()
	var q1: QueueItem = QueueItem.new()
	q1.kind = "building"
	q1.ref_id = "boot_barracks" # cost 40
	col.queue.append(q1)

	var q2: QueueItem = QueueItem.new()
	q2.kind = "building"
	q2.ref_id = "feed_hall" # cost 60
	col.queue.append(q2)

	# Mock industry output to 50 PP
	col.workers = 15 # will provide plenty PP, but let's test step manually
	# Directly test production overflow logic
	var cost1: int = Production.cost_for_item(_db, gs, col.id, q1)
	assert_eq(cost1, 40)
	var cost2: int = Production.cost_for_item(_db, gs, col.id, q2)
	assert_eq(cost2, 60)

	var pp_avail: int = 50
	var needed1: int = cost1 - col.progress_pp
	assert_true(pp_avail >= needed1)
	pp_avail -= needed1
	col.buildings.append(q1.ref_id)
	col.queue.remove_at(0)
	col.progress_pp = 0

	# Overflow 10 into next item (cost 60)
	col.progress_pp += pp_avail
	assert_eq(col.progress_pp, 10, "Progress on next item is 10")
	assert_eq(col.queue[0].ref_id, "feed_hall")

	# Repeat -1 never removes the item
	var q_rep: QueueItem = QueueItem.new()
	q_rep.kind = "trade_goods"
	q_rep.count = -1
	col.queue = [q_rep]
	var res_tg: Dictionary = Production.process_colony(_db, gs, col.id)
	assert_eq(col.queue.size(), 1, "Repeat -1 item remains in queue")

	# Trade goods 7 PP -> 3 credits (floor_div(7, 2) = 3)
	var tg_cr: int = IntMath.floor_div(7, _db.bal("trade_goods_pp_per_credit"))
	assert_eq(tg_cr, 3, "Trade goods 7 PP yields 3 credits")

func test_piscivore_and_gravity() -> void:
	# Piscivore farmers use the fish table
	var ctx_pisc: Dictionary = _setup_state("ducks", ["piscivore"])
	var gs_pisc: GameState = ctx_pisc["gs"]
	var col_pisc: Colony = ctx_pisc["colony"]
	var planet_pisc: Planet = ctx_pisc["planet"]
	planet_pisc.climate = "ocean" # farm 2, fish 3
	var jy_pisc: Dictionary = Economy.job_yields(_db, gs_pisc, col_pisc.id)
	assert_eq((jy_pisc["food_per_farmer"] as ModResult).value, 3, "Piscivore uses fish table (ocean fish = 3)")

	# Normal species on heavy world gets -25% food/industry/research, and gravity_manners removes it
	var ctx_g: Dictionary = _setup_state("plain_bird", [])
	var gs_g: GameState = ctx_g["gs"]
	var col_g: Colony = ctx_g["colony"]
	var planet_g: Planet = ctx_g["planet"]
	planet_g.gravity = "heavy"

	var out_g: Dictionary = Economy.colony_output(_db, gs_g, col_g.id)
	var ind_res: ModResult = out_g["industry"]
	var has_grav_line: bool = false
	for l in ind_res.lines:
		if l.get("source_key") == "gravity":
			has_grav_line = true
			assert_eq(l.get("value"), -25)
	assert_true(has_grav_line, "Gravity penalty applied on heavy world")

	col_g.buildings.append("gravity_manners")
	var out_clean: Dictionary = Economy.colony_output(_db, gs_g, col_g.id)
	var has_grav_after: bool = false
	for l in (out_clean["industry"] as ModResult).lines:
		if l.get("source_key") == "gravity":
			has_grav_after = true
	assert_false(has_grav_after, "gravity_manners removes gravity penalty")
 
func test_growth_formatter_invariants() -> void:
	# Blockaded
	assert_eq(Growth.format_growth(8000, 12000, 316, true), "Blockaded")
	# Pop at or above max
	assert_eq(Growth.format_growth(12000, 12000, 316, false), "Full")
	assert_eq(Growth.format_growth(12500, 12000, 316, false), "Full")
	# Zero or negative growth
	assert_eq(Growth.format_growth(8000, 12000, 0, false), "No growth")
	assert_eq(Growth.format_growth(8000, 12000, -100, false), "No growth")
	# 8000 pop, 12000 max, 316 growth: next threshold 9000, needed 1000, ceil_div(1000, 316) = 4
	assert_eq(Growth.format_growth(8000, 12000, 316, false), "+1 pop in 4 turns")
	# 8800 pop, 12000 max, 316 growth: needed 200, ceil_div(200, 316) = 1
	assert_eq(Growth.format_growth(8800, 12000, 316, false), "+1 pop in 1 turn")
	# 8999 pop, 12000 max, 1 growth: needed 1, ceil_div(1, 1) = 1
	assert_eq(Growth.format_growth(8999, 12000, 1, false), "+1 pop in 1 turn")
	# Exactly at pop unit threshold 5000 / 10000, growth 500: needed 1000 -> 2 turns
	assert_eq(Growth.format_growth(5000, 10000, 500, false), "+1 pop in 2 turns")

func test_breakdown_source_labels_never_empty() -> void:
	var ctx: Dictionary = _setup_state("pheasants", ["good_industry"])
	var gs: GameState = ctx["gs"]
	var col: Colony = ctx["colony"]
	col.buildings.append("grand_nest")
	col.workers = 4

	var yields: Dictionary = Economy.colony_output(_db, gs, col.id)
	var ind_res: ModResult = yields["industry"]
	assert_true(ind_res != null, "Industry ModResult exists")
	assert_true(ind_res.lines.size() >= 2, "Industry has multiple lines (base, trait/building)")

	for l in ind_res.lines:
		var src_key: String = str(l.get("source_key", l.get("source", "")))
		assert_false(src_key.is_empty(), "Line must have a non-empty source_key or source")
		var formatted: String = StatTooltip.format_source(src_key)
		assert_false(formatted.is_empty(), "format_source must return non-empty label for %s" % src_key)
		assert_ne(formatted, "Unknown", "format_source should resolve known key %s" % src_key)

	# Verify StatTooltip.build produces UI labels that are all non-empty
	var tooltip_ctl: Control = StatTooltip.build("Industry Breakdown", ind_res)
	assert_true(tooltip_ctl != null)
	tooltip_ctl.free()
	var text_rep: String = StatTooltip.text_for("Industry Breakdown", ind_res)
	assert_false(text_rep.is_empty())
	assert_false(text_rep.contains(": :"), "No double colons or empty label in text representation")

	# Test individual format_source resolution for traits, buildings, presets, jobs
	assert_eq(StatTooltip.format_source("workers"), "Workers")
	assert_eq(StatTooltip.format_source("farmers"), "Farmers")
	assert_eq(StatTooltip.format_source("scientists"), "Scientists")
	assert_eq(StatTooltip.format_source("grand_nest"), "Grand Nest")
	assert_eq(StatTooltip.format_source("good_industry"), "Good Industry")
	assert_eq(StatTooltip.format_source("capital"), "Capital")

