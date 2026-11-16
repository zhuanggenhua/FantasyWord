extends RefCounted
## Locked 31629d5 ContextSteering2D "transit" scoring, not world simulation.
## All positions/directions use Unity XY (Y up); reflect Y only at adapter boundary.
## Frame supplies position, forward, nullable target, obstacles [{point,radius}],
## neighbours [{position,radius}]. No physics detection or avoidance is invented.
const SAMPLE_COUNT := 16
const AGENT_RADIUS := 0.35
const PROBE_RADIUS := 1.0
const NEIGHBOUR_RADIUS := 1.0

static func f32(value: float) -> float:
	return PackedFloat32Array([value])[0]

static func directions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	var step := f32(f32(PI) * 2.0 / SAMPLE_COUNT)
	for i in SAMPLE_COUNT:
		var radians := f32(f32(f32(PI) * 0.5) - f32(step * i))
		result.append(Vector2(cos(radians), sin(radians)).normalized())
	return result

static func _empty() -> PackedFloat32Array:
	var values := PackedFloat32Array()
	values.resize(SAMPLE_COUNT)
	return values

static func _add(values: PackedFloat32Array, samples: Array[Vector2], direction: Vector2, weight: float) -> void:
	if direction.length_squared() <= 0.0001 or weight <= 0.0:
		return
	var normalized := direction.normalized()
	for i in SAMPLE_COUNT:
		var dot := normalized.dot(samples[i])
		if dot > 0.0:
			values[i] = maxf(values[i], f32(dot * weight))

static func _proximity(distance: float, combined: float, probe: float) -> float:
	if distance <= combined:
		return 1.0
	var span := maxf(probe, f32(combined + 0.01))
	return f32(1.0 - clampf(f32(f32(distance - combined) / f32(span - combined)), 0.0, 1.0))

static func solve(frame: Dictionary, max_speed: float = 1.0) -> Dictionary:
	var samples := directions()
	var seek := _empty()
	var obstacle_interest := _empty()
	var obstacle_constraint := _empty()
	var separation := _empty()
	var side_step := _empty()
	var position: Vector2 = frame.get("position", Vector2.ZERO)
	var forward: Vector2 = frame.get("forward", Vector2.RIGHT)
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector2.RIGHT
	if frame.get("target") != null:
		_add(seek, samples, Vector2(frame.target) - position, 1.0)
	for obstacle: Dictionary in frame.get("obstacles", []):
		var offset: Vector2 = Vector2(obstacle.point) - position
		var distance := offset.length()
		if distance <= 0.0001:
			continue
		var proximity := _proximity(distance, f32(f32(AGENT_RADIUS) + f32(float(obstacle.radius))), PROBE_RADIUS)
		if proximity <= 0.0:
			continue
		var direction := offset / distance
		_add(obstacle_constraint, samples, direction, proximity)
		if direction.dot(forward) > 0.0:
			var side_sign := -1.0 if forward.cross(direction) >= 0.0 else 1.0
			var side := Vector2(-forward.y * side_sign, forward.x * side_sign)
			_add(obstacle_interest, samples, side, f32(proximity * f32(0.35)))
	for neighbour: Dictionary in frame.get("neighbours", []):
		var offset: Vector2 = Vector2(neighbour.position) - position
		var distance := offset.length()
		var radius := f32(float(neighbour.radius))
		var proximity := _proximity(distance, f32(f32(AGENT_RADIUS) + radius), NEIGHBOUR_RADIUS)
		var away := -offset / distance if distance > 0.0001 else -forward
		_add(separation, samples, away, proximity)
		if distance <= 0.0001:
			continue
		var direction := offset / distance
		if forward.dot(direction) < f32(0.15):
			continue
		var span := maxf(NEIGHBOUR_RADIUS, f32(f32(f32(AGENT_RADIUS) + radius) + 0.01))
		var side_proximity := f32(1.0 - clampf(f32(distance / span), 0.0, 1.0))
		if side_proximity <= 0.0:
			continue
		var cross := forward.cross(direction)
		var sign_value := -signf(cross) if absf(cross) > 0.001 else -1.0
		_add(side_step, samples, Vector2(-forward.y * sign_value, forward.x * sign_value), side_proximity)
	# Source WeightedSumMinusConstraints is multiplicative attenuation, not subtraction.
	var interest := _empty()
	var combined := _empty()
	var weighted := Vector2.ZERO
	var strength := 0.0
	for i in SAMPLE_COUNT:
		interest[i] = f32(f32(f32(seek[i] + obstacle_interest[i]) + separation[i]) + side_step[i])
		combined[i] = f32(clampf(interest[i], 0.0, 1.0) * f32(1.0 - clampf(obstacle_constraint[i], 0.0, 1.0)))
		weighted += samples[i] * combined[i]
		strength = maxf(strength, combined[i])
	var chosen := weighted.normalized() if weighted.length_squared() > 0.0001 else Vector2.ZERO
	# Source transit has no LimitSpeed behaviour. Solver's -1 means profile max speed.
	var speed := max_speed if max_speed >= 0.0 else 1.0
	var preferred := chosen * speed * strength
	return {"direction": chosen, "strength": strength, "speed_scale": 1.0,
		"preferred_velocity": preferred, "interest": interest, "constraint": obstacle_constraint,
		"combined": combined, "seek": seek, "obstacle_interest": obstacle_interest,
		"separation": separation, "side_step": side_step}
