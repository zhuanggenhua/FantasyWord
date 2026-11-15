extends Camera2D
## ClickMoveTest 的有界 Cinemachine 3.1.6 Follow 后端，不是通用 Cinemachine 替代。
## 依据：CinemachineFollow.MutateCameraState、TargetTracking.InitStateInfo /
## TrackTarget、CinemachineVirtualCameraBase.DetachedFollowTargetDamp、Damper.StandardDamp。
## 锁定：WorldSpace、全附着、目标 Z=0、恒定 offset=(0,0,-10)、等轴阻尼=1。
## 世界单位保留，Unity Y 反射在调用方边界完成。Godot 原生平滑不参与。
## 宿主在目标更新后显式调用 advance_follow；不冒充 Brain SmartUpdate、混合或 Confiner。
## priority 仅承接 PlayerCameraRig 作者值，不实现多虚拟相机仲裁。

const POSITION_DAMPING := 1.0
const EPSILON := 0.0001
const LOG_NEGLIGIBLE_RESIDUAL := -4.605170186
var follow: Node2D
var priority: int = 10
var previous_state_is_valid: bool = false
var _previous_target_position := Vector2.ZERO

func _init() -> void:
	position_smoothing_enabled = false
	rotation_smoothing_enabled = false

## 源算法按每个分量判断 epsilon，不能用 Vector2 长度阈值代替。
static func standard_damp(initial: float, damp_time: float, delta_time: float) -> float:
	if damp_time < EPSILON or absf(initial) < EPSILON:
		return initial
	if delta_time < EPSILON:
		return 0.0
	return initial * (1.0 - exp(LOG_NEGLIGIBLE_RESIDUAL * delta_time / damp_time))

func advance_follow(delta_time: float) -> bool:
	if not is_instance_valid(follow) or not is_inside_tree() or not follow.is_inside_tree():
		return false
	if not is_finite(delta_time) or not follow.global_position.is_finite():
		return false
	var target := follow.global_position
	if delta_time < 0.0 or not previous_state_is_valid:
		_previous_target_position = target
	else:
		var displacement := target - _previous_target_position
		_previous_target_position += Vector2(
			standard_damp(displacement.x, POSITION_DAMPING, delta_time),
			standard_damp(displacement.y, POSITION_DAMPING, delta_time))
	# WorldSpace 恒定后向 offset 的 XY 为零；等轴阻尼下 dampingSpace 反射可消去。
	# minimum-distance：去掉 up 分量后，真实/阻尼目标 Z 都为0、camera Z=-10，
	# d=dot(actual-camera,+Z)=10，minDistance=|offset|*0.2=2，永不进入校正。
	global_position = _previous_target_position
	previous_state_is_valid = true
	force_update_scroll()
	return true
