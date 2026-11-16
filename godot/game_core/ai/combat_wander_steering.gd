extends RefCounted
## Locked 31629d5 combat-wander profile. Unity XY inputs; preferred, not safe velocity.
const Transit = preload("res://game_core/ai/transit_steering.gd")

static func resolve_side(frame: Dictionary, requested: float, right: Vector2) -> float:
	var danger := Vector2.ZERO
	var position: Vector2 = frame.get("position", Vector2.ZERO)
	for obstacle: Dictionary in frame.get("obstacles", []):
		var offset := Vector2(obstacle.point) - position
		var distance := offset.length()
		if distance <= 0.0001:
			continue
		var combined := Transit.f32(Transit.f32(Transit.AGENT_RADIUS) + Transit.f32(float(obstacle.radius)))
		var proximity := Transit._proximity(distance, combined, Transit.PROBE_RADIUS)
		danger += offset / distance * proximity
	# This is deliberately > 1, not > 0: one fully close obstacle cannot flip.
	if danger.length() <= 1.0:
		return requested
	var side := right * requested
	return requested if side.dot(danger) <= (-side).dot(danger) else -requested

static func solve(frame: Dictionary, max_speed: float = 1.0) -> Dictionary:
	var samples := Transit.directions()
	var wander := Transit._empty()
	var resolved_side := 0.0
	var intent: Variant = frame.get("wander_intent")
	if frame.get("target") != null and intent != null:
		var position: Vector2 = frame.get("position", Vector2.ZERO)
		var offset := Vector2(frame.target) - position
		var distance := offset.length()
		if distance > 0.0001:
			var radial := offset / distance
			var right := Vector2(radial.y, -radial.x)
			resolved_side = resolve_side(frame, float(intent.side_sign), right)
			Transit._add(wander, samples, right * resolved_side, 1.0)
			var follow := maxf(Transit.f32(float(intent.follow_distance)), Transit.f32(0.0001))
			var distance_weight := Transit.f32(Transit.f32(distance - follow) / follow)
			if distance_weight > 0.0:
				# Same contribution uses per-bin MAX, not additive tangent + radial.
				Transit._add(wander, samples, radial, distance_weight)
	# Reuse exactly shared obstacle and separation contributions, not transit's
	# seek, side-step or combined output. Combat-wander has neither seek nor side-step.
	var shared := Transit.solve(frame, max_speed)
	var interest := Transit._empty()
	var combined := Transit._empty()
	var weighted := Vector2.ZERO
	var strength := 0.0
	for i in Transit.SAMPLE_COUNT:
		interest[i] = Transit.f32(Transit.f32(shared.obstacle_interest[i] + wander[i]) + shared.separation[i])
		combined[i] = Transit.f32(clampf(interest[i], 0.0, 1.0) * Transit.f32(1.0 - clampf(shared.constraint[i], 0.0, 1.0)))
		weighted += samples[i] * combined[i]
		strength = maxf(strength, combined[i])
	var chosen := weighted.normalized() if weighted.length_squared() > 0.0001 else Vector2.ZERO
	var speed := max_speed if max_speed >= 0.0 else 1.0
	return {"direction": chosen, "strength": strength, "speed_scale": 1.0,
		"preferred_velocity": chosen * speed * strength, "interest": interest,
		"constraint": shared.constraint, "combined": combined, "wander": wander,
		"obstacle_interest": shared.obstacle_interest, "separation": shared.separation,
		"resolved_side": resolved_side}
