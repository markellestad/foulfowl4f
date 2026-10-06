class_name RangeTrack

static func _want(d: int, p: int, s: int) -> int:
	return maxi(-s, mini(s, p - d))

static func step(d: int, p_a: int, s_a: int, p_b: int, s_b: int) -> int:
	if p_a == p_b or s_a == 0 or s_b == 0:
		return clampi(d + _want(d, p_a, s_a) + _want(d, p_b, s_b), 0, 12)

	var p_c: int = 0
	var s_c: int = 0
	var p_o: int = 0
	var s_o: int = 0
	if p_a < p_b or (p_a == p_b and s_a <= s_b):
		p_c = p_a
		s_c = s_a
		p_o = p_b
		s_o = s_b
	else:
		p_c = p_b
		s_c = s_b
		p_o = p_a
		s_o = s_a

	if d > p_c:
		var gain: int = 0
		if d > p_o:
			gain = s_c + mini(s_o, d - p_o)
		else:
			gain = maxi(1, s_c - mini(s_o, 12 - d))
		return maxi(p_c, d - gain)
	if d == p_c:
		return mini(12, d + maxi(0, mini(s_o, mini(p_o - d, 12 - d)) - s_c))
	return mini(p_c, d + s_c + mini(s_o, maxi(0, p_o - d)))

static func project(d0: int, p_own: int, s_own: int, s_enemy: int) -> Dictionary:
	var d: int = d0
	var talon_round: int = -1
	var beak_round: int = -1
	for rnd in range(0, 13):
		if talon_round == -1 and d <= 7:
			talon_round = rnd
		if beak_round == -1 and d <= 3:
			beak_round = rnd
		d = step(d, p_own, s_own, 12, s_enemy)
	return {
		"talon_round": talon_round,
		"beak_round": beak_round
	}

static func preferred(posture: String, auto_band: String, has_horizon_ammo: bool) -> int:
	match posture:
		"close":
			return 0
		"talon":
			return 5
		"standoff", "stand_off":
			return 12
		"retreat":
			return 12
		"auto":
			match auto_band:
				"beak":
					return 1
				"talon":
					return 5
				"horizon":
					if has_horizon_ammo:
						return 12
					else:
						return 5
				_:
					return 5
		_:
			return 5
