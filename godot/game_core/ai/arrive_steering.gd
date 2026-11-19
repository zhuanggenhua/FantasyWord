extends RefCounted
## 锁定源 ArriveSteeringBehaviour2D：基于当前目标限速，不改兴趣和约束。
const Transit = preload("res://game_core/ai/transit_steering.gd")
const SLOW_RADIUS := 1.5
const STOP_RADIUS := 0.1


static func speed_scale(frame: Dictionary) -> float:
	if frame.get("target") == null:
		return 1.0
	var position: Vector2 = frame.get("position", Vector2.ZERO)
	var target: Vector2 = frame.target
	var distance := position.distance_to(target)
	var requested_stop: float = frame.get("arrival_stop_radius", -1.0)
	var stop := Transit.f32(requested_stop if requested_stop >= 0.0 else STOP_RADIUS)
	var slow := maxf(SLOW_RADIUS, Transit.f32(stop + Transit.f32(0.01)))
	return 0.0 if distance <= stop else clampf(
		Transit.f32(Transit.f32(distance - stop) / Transit.f32(slow - stop)), 0.0, 1.0)


static func apply_limit(result: Dictionary, frame: Dictionary, max_speed: float) -> void:
	var scale := speed_scale(frame)
	var speed := max_speed if max_speed >= 0.0 else 1.0
	result.speed_scale = scale
	# 原求解器乘法顺序为朝向、速度、到达限速、方向强度。
	result.preferred_velocity = Vector2(result.direction) * speed * scale * float(result.strength)
