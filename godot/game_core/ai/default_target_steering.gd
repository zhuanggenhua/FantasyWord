extends RefCounted
## 锁定源 default 组：Seek、Arrive、ObstacleAvoidance、Separation、SideStep。
## 与 Transit 共享方向合成，只增加 Arrive 限速；不预测目标速度。
const Transit = preload("res://game_core/ai/transit_steering.gd")
const Arrive = preload("res://game_core/ai/arrive_steering.gd")


static func solve(frame: Dictionary, max_speed: float = 1.0) -> Dictionary:
	var result := Transit.solve(frame, max_speed)
	Arrive.apply_limit(result, frame, max_speed)
	return result
