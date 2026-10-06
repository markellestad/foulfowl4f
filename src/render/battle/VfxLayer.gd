class_name VfxLayer
extends Node2D

var beams: Array[Dictionary] = [] # {from, to, color, width, ttl, band}
var missiles: Array[Dictionary] = [] # {pos, dir, trail, ttl}
var sparks: Array[Dictionary] = [] # {pos, vel, ttl, color}
var feathers: Array[Dictionary] = [] # {pos, vel, rot, ttl}
var shards: Array[Dictionary] = [] # {pos, vel, rot, ttl}
var shields: Array[Dictionary] = [] # {pos, dir, radius, ttl}
var flashes: Array[Dictionary] = [] # {pos, radius, ttl}

var reduce_motion: bool = false

func clear_all() -> void:
	beams.clear()
	missiles.clear()
	sparks.clear()
	feathers.clear()
	shards.clear()
	shields.clear()
	flashes.clear()
	queue_redraw()

func add_shot(from_pos: Vector2, to_pos: Vector2, band: String) -> void:
	match band:
		"talon":
			beams.append({
				"from": from_pos,
				"to": to_pos,
				"color": Color(1.0, 0.8, 0.2, 0.9),
				"width": 3.0,
				"ttl": 0.25,
				"band": "talon"
			})
		"beak":
			beams.append({
				"from": from_pos,
				"to": to_pos,
				"color": Color(0.9, 0.3, 0.3, 0.9),
				"width": 2.0,
				"ttl": 0.20,
				"band": "beak"
			})
		_: # horizon or other
			var dir: Vector2 = (to_pos - from_pos).normalized()
			missiles.append({
				"pos": from_pos,
				"dir": dir,
				"target": to_pos,
				"progress": 0.0,
				"speed": 800.0,
				"ttl": 1.0
			})
	queue_redraw()

func add_hit(pos: Vector2, was_shield: bool, shooter_dir: Vector2) -> void:
	if was_shield:
		# Jagged arc segment (~60 deg) facing shooter
		shields.append({
			"pos": pos,
			"dir": -shooter_dir,
			"radius": 24.0,
			"ttl": 0.3
		})

	var spark_count: int = 4 if reduce_motion else 8
	for i in range(spark_count):
		var ang: float = randf() * TAU
		var spd: float = randf_range(40.0, 120.0)
		sparks.append({
			"pos": pos,
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"ttl": 0.25,
			"color": Color(1.0, 0.85, 0.4)
		})

	var feather_count: int = 1 if reduce_motion else 3
	for i in range(feather_count):
		var ang: float = randf() * TAU
		feathers.append({
			"pos": pos,
			"vel": Vector2(cos(ang), sin(ang)) * randf_range(20.0, 60.0),
			"rot": randf() * TAU,
			"ttl": 0.45
		})
	queue_redraw()

func add_swat_flash(pos: Vector2) -> void:
	flashes.append({
		"pos": pos,
		"radius": 14.0,
		"ttl": 0.2
	})
	queue_redraw()

func add_death(pos: Vector2) -> void:
	var shard_count: int = 4 if reduce_motion else 8
	for i in range(shard_count):
		var ang: float = randf() * TAU
		shards.append({
			"pos": pos,
			"vel": Vector2(cos(ang), sin(ang)) * randf_range(50.0, 180.0),
			"rot": randf() * TAU,
			"ttl": 0.6
		})
	queue_redraw()

func _process(delta: float) -> void:
	var needs_redraw: bool = false

	# Update beams
	var alive_beams: Array[Dictionary] = []
	for b in beams:
		b["ttl"] -= delta
		if b["ttl"] > 0:
			alive_beams.append(b)
			needs_redraw = true
	beams = alive_beams

	# Update missiles
	var alive_missiles: Array[Dictionary] = []
	for m in missiles:
		m["ttl"] -= delta
		m["pos"] += m["dir"] * m["speed"] * delta
		if m["ttl"] > 0:
			alive_missiles.append(m)
			needs_redraw = true
	missiles = alive_missiles

	# Update sparks
	var alive_sparks: Array[Dictionary] = []
	for s in sparks:
		s["ttl"] -= delta
		s["pos"] += s["vel"] * delta
		if s["ttl"] > 0:
			alive_sparks.append(s)
			needs_redraw = true
	sparks = alive_sparks

	# Update feathers
	var alive_feathers: Array[Dictionary] = []
	for f in feathers:
		f["ttl"] -= delta
		f["pos"] += f["vel"] * delta
		if f["ttl"] > 0:
			alive_feathers.append(f)
			needs_redraw = true
	feathers = alive_feathers

	# Update shards
	var alive_shards: Array[Dictionary] = []
	for sh in shards:
		sh["ttl"] -= delta
		sh["pos"] += sh["vel"] * delta
		if sh["ttl"] > 0:
			alive_shards.append(sh)
			needs_redraw = true
	shards = alive_shards

	# Update shields
	var alive_shields: Array[Dictionary] = []
	for shld in shields:
		shld["ttl"] -= delta
		if shld["ttl"] > 0:
			alive_shields.append(shld)
			needs_redraw = true
	shields = alive_shields

	# Update flashes
	var alive_flashes: Array[Dictionary] = []
	for fl in flashes:
		fl["ttl"] -= delta
		if fl["ttl"] > 0:
			alive_flashes.append(fl)
			needs_redraw = true
	flashes = alive_flashes

	if needs_redraw:
		queue_redraw()

func _draw() -> void:
	# 1. Beams
	for b in beams:
		var c: Color = b["color"]
		c.a *= clampf(b["ttl"] / 0.25, 0.0, 1.0)
		draw_line(b["from"], b["to"], c, b["width"])

	# 2. Missiles (darts with trail)
	for m in missiles:
		var p: Vector2 = m["pos"]
		var d: Vector2 = m["dir"]
		draw_line(p - d * 16.0, p, Color(0.4, 0.8, 1.0, 0.9), 2.5)
		draw_circle(p, 3.0, Color(1.0, 1.0, 1.0, 0.95))

	# 3. Flashes (swat intercepts)
	for fl in flashes:
		var a: float = clampf(fl["ttl"] / 0.2, 0.0, 1.0)
		draw_circle(fl["pos"], fl["radius"], Color(1.0, 0.9, 0.3, a * 0.8))

	# 4. Shield arc segment (~60 deg facing shot)
	for sh in shields:
		var a: float = clampf(sh["ttl"] / 0.3, 0.0, 1.0)
		var center: Vector2 = sh["pos"]
		var forward: Vector2 = sh["dir"]
		var base_ang: float = forward.angle()
		var arc_pts := PackedVector2Array()
		var rad: float = sh["radius"]
		for step_i in range(-3, 4):
			var ang: float = base_ang + deg_to_rad(float(step_i) * 10.0)
			# Faceted jagged arc
			var r_jitter: float = rad + (float(abs(step_i) % 2) * 2.0)
			arc_pts.append(center + Vector2(cos(ang), sin(ang)) * r_jitter)
		draw_polyline(arc_pts, Color(0.3, 0.8, 1.0, a), 2.5)

	# 5. Sparks
	for s in sparks:
		draw_circle(s["pos"], 1.5, s["color"])

	# 6. Feathers
	for f in feathers:
		var a: float = clampf(f["ttl"] / 0.45, 0.0, 1.0)
		var p: Vector2 = f["pos"]
		draw_line(p - Vector2(4, 2), p + Vector2(4, 2), Color(0.95, 0.95, 0.95, a), 1.5)

	# 7. Shards
	for sh in shards:
		var a: float = clampf(sh["ttl"] / 0.6, 0.0, 1.0)
		var p: Vector2 = sh["pos"]
		draw_line(p - Vector2(3, 0), p + Vector2(3, 3), Color(0.7, 0.7, 0.8, a), 2.0)
