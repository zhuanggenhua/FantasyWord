extends RefCounted
## Locked 31629d5 predictive-target group: pursuit + arrive + shared transit
## avoidance/separation/side-step. Unity XY inputs, no physics or actor control.
const Transit = preload("res://game_core/ai/transit_steering.gd")
const Arrive = preload("res://game_core/ai/arrive_steering.gd")
const PREDICTION_SECONDS := 0.75


static func solve(frame: Dictionary, max_speed: float = 1.0) -> Dictionary:
	var predicted_frame := frame.duplicate()
	if frame.get("target") != null:
		var target: Vector2 = frame.target
		var velocity: Vector2 = frame.get("target_velocity", Vector2.ZERO)
		predicted_frame.target = target + velocity * PREDICTION_SECONDS
	var result := Transit.solve(predicted_frame, max_speed)
	result["pursuit"] = result.seek
	result.erase("seek")
	# 限速使用当前位置到实际目标的距离，而不是预测落点。
	Arrive.apply_limit(result, frame, max_speed)
	return result
