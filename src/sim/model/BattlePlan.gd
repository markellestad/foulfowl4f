class_name BattlePlan
extends RefCounted

var posture: String = "auto"                 # auto | close | talon | standoff | retreat
var target_priority: String = "auto"         # auto | biggest | swat | band_talon | band_beak | band_horizon | defenses | transports
var swat_mode: String = "missiles"           # missiles | ships
var retreat_threshold: String = "never"      # never | half | even

func to_dict() -> Dictionary:
	return {
		"posture": posture,
		"target_priority": target_priority,
		"swat_mode": swat_mode,
		"retreat_threshold": retreat_threshold
	}

static func from_dict(d: Dictionary) -> BattlePlan:
	var bp: BattlePlan = BattlePlan.new()
	bp.posture = str(d.get("posture", "auto"))
	bp.target_priority = str(d.get("target_priority", "auto"))
	bp.swat_mode = str(d.get("swat_mode", "missiles"))
	bp.retreat_threshold = str(d.get("retreat_threshold", "never"))
	return bp
