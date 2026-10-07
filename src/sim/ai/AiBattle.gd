class_name AiBattle
extends RefCounted

static func choose_orders(_view: AiView, request: Dictionary) -> Dictionary:
	var standing: Dictionary = request.get("standing_plan", {
		"posture": "auto",
		"target_priority": "auto",
		"swat_mode": "missiles",
		"retreat_threshold": "never"
	}).duplicate(true)

	var odds: int = int(request.get("odds", 50))
	var retreat_thresh: int = int(request.get("retreat_threshold_val", -1))
	if retreat_thresh < 0:
		var thresh_str: String = str(request.get("retreat_threshold", standing.get("retreat_threshold", "never")))
		if thresh_str == "half":
			retreat_thresh = 50
		elif thresh_str == "even":
			retreat_thresh = 100
		else:
			retreat_thresh = 0

	# 1. Odds below retreat threshold -> Retreat
	if retreat_thresh > 0 and odds < retreat_thresh:
		standing["posture"] = "retreat"
		return standing

	# 2. Enemy Horizon-heavy -> Missiles first + Close
	var enemy_horizon_heavy: bool = bool(request.get("enemy_horizon_heavy", false))
	var own_swat_mounts: bool = bool(request.get("own_swat_mounts", false))
	var enemy_high_shield: bool = bool(request.get("enemy_high_shield", false))
	if enemy_high_shield or (enemy_horizon_heavy and own_swat_mounts) or enemy_horizon_heavy:
		standing["posture"] = "close"
		standing["swat_mode"] = "missiles"
		return standing

	# 3. Faster Beak fleet -> Close
	var faster_beak: bool = bool(request.get("faster_beak", false))
	if faster_beak:
		standing["posture"] = "close"
		return standing

	# 4. Slower Talon fleet vs Beak -> Talon range
	var slower_talon_vs_beak: bool = bool(request.get("slower_talon_vs_beak", false))
	if slower_talon_vs_beak:
		standing["posture"] = "talon"
		return standing

	# 5. Own Horizon-heavy -> target Swat Escorts first
	var own_horizon_heavy: bool = bool(request.get("own_horizon_heavy", false))
	if own_horizon_heavy:
		standing["target_priority"] = "swat"
		return standing

	# 6. Else standing plan
	return standing
