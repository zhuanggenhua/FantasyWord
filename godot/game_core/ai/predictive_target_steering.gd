extends RefCounted
## Locked 31629d5 predictive-target group: pursuit + arrive + shared transit
## avoidance/separation/side-step. Unity XY inputs, no physics or actor control.
const Transit = preload("res://game_core/ai/transit_steering.gd")
const PREDICTION_SECONDS := 0.75
const SLOW_RADIUS := 1.5
const STOP_RADIUS := 0.1


static func solve(frame: Dictionary, max_speed: float = 1.0) -> Dictionary:
	var predicted_frame := frame.duplicate()
	var speed_scale := 1.0
	if frame.get("target") != null:
		var position: Vector2 = frame.get("position", Vector2.ZERO)
		var target: Vector2 = frame.target
		var velocity: Vector2 = frame.get("target_velocity", Vector2.ZERO)
		predicted_frame.target = target + velocity * PREDICTION_SECONDS
		# Arrive uses current target, NOT the predicted pursuit target.
		var distance := position.distance_to(target)
		var requested_stop: float = frame.get("arrival_stop_radius", -1.0)
		var stop := requested_stop if requested_stop >= 0.0 else Transit.f32(STOP_RADIUS)
		var slow := maxf(SLOW_RADIUS, Transit.f32(stop + Transit.f32(0.01)))
		speed_scale = 0.0 if distance <= stop else clampf(
			Transit.f32(Transit.f32(distance - stop) / Transit.f32(slow - stop)), 0.0, 1.0)
	var result := Transit.solve(predicted_frame, max_speed)
	result["pursuit"] = result.seek
	result.erase("seek")
	result.speed_scale = speed_scale
	var speed := max_speed if max_speed >= 0.0 else 1.0
	# Match solver multiply order: direction * speed * scale * strength.
	result.preferred_velocity = Vector2(result.direction) * speed * speed_scale * float(result.strength)
	return result
