class_name Stats
extends RefCounted

const STATS: Dictionary = {
	"pop_per_size": { "scope": "colony", "min": 0 },
	"max_pop_flat": { "scope": "colony", "min": 0 },
	"food_per_farmer": { "scope": "colony", "min": 0 },
	"food_flat": { "scope": "colony", "min": 0 },
	"food_pct": { "scope": "colony", "min": -1000000 },
	"industry_per_worker": { "scope": "colony", "min": 1 },
	"industry_flat": { "scope": "colony", "min": 0 },
	"industry_pct": { "scope": "colony", "min": -1000000 },
	"research_per_scientist": { "scope": "colony", "min": 1 },
	"research_flat": { "scope": "colony", "min": 0 },
	"research_pct": { "scope": "colony", "min": -1000000 },
	"job_yield_all": { "scope": "colony", "min": 0 },
	"taxes_pct": { "scope": "colony", "min": -1000000 },
	"credits_flat": { "scope": "colony", "min": 0 },
	"growth_pct": { "scope": "colony", "min": -1000000 },
	"building_cost_pct": { "scope": "empire", "min": -1000000 },
	"building_upkeep_pct": { "scope": "empire", "min": -1000000 },
	"ship_cost_pct": { "scope": "empire / colony", "min": -1000000 },
	"ship_upkeep_pct": { "scope": "empire", "min": -1000000 },
	"fuel_range": { "scope": "empire", "min": 0 },
	"nest_range_add": { "scope": "empire", "min": 0 },
	"map_speed_add": { "scope": "empire", "min": 0 },
	"combat_speed_add": { "scope": "empire", "min": 0 },
	"scan_add": { "scope": "empire / colony", "min": 0 },
	"ship_hp_pct": { "scope": "empire", "min": -1000000 },
	"evasion_add": { "scope": "empire", "min": -1000000 },
	"accuracy_add": { "scope": "empire", "min": -1000000 },
	"band_damage_pct": { "scope": "empire", "min": -1000000 },
	"marine_str_add": { "scope": "empire", "min": 0 },
	"militia_str_add": { "scope": "empire", "min": 0 },
	"troops_pct": { "scope": "empire", "min": -1000000 },
	"ground_def_pct": { "scope": "empire", "min": -1000000 },
	"planet_def_hp_pct": { "scope": "empire", "min": -1000000 },
	"planet_horizon_pct": { "scope": "empire", "min": -1000000 },
	"trade_income_pct": { "scope": "empire", "min": -1000000 },
	"spy_score_add": { "scope": "empire", "min": -1000000 },
	"security_add": { "scope": "empire", "min": -1000000 },
	"relations_base": { "scope": "empire", "min": -1000000 }
}

const FLAGS: Array[String] = [
	"dome_perches_1",
	"dome_perches_2",
	"crackle_shutters",
	"gravity_manners",
	"plague_immune",
	"two_chick_pods",
	"see_fleet_destinations",
	"scouts_read_planets_3pc",
	"reveal_enemy_designs",
	"autopsy_loadouts",
	"beak_ignores_shields_100",
	"beak_ignores_shields_75",
	"talon_extra_shot_alternate",
	"early_mantle",
	"enemy_retreat_plus_2",
	"no_exit_home",
	"two_steps_back_home",
	"instant_regret",
	"overpreen",
	"scatter_molt",
	"line_slots_plus_1",
	"toxic_preening",
	"drill_roost",
	"rock_picking",
	"placid_trigger"
]

static func is_stat(id: String) -> bool:
	return STATS.has(id)

static func is_flag(id: String) -> bool:
	return FLAGS.has(id)

static func min_of(stat: String) -> int:
	if STATS.has(stat):
		return int(STATS[stat]["min"])
	return -1000000
