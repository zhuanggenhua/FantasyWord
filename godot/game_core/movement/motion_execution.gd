extends RefCounted
## 原 Movable 的 MoveOrder 与逐步位移执行；位置和碰撞仍由显式宿主提供。
## 宿主须实现 get_movement_position、request_move_position、cast_motion_hits、
## can_move、calculate_move_speed、calculate_speed_multiplier、clear_velocity、
## update_movement_animation、update_facing_from_intent、register_collision。
## request_move_position 不承诺立即更新位置；到点复查必须重新读取宿主实际位置。

const Filter = preload("res://game_core/movement/motion_filter.gd")
const COLLISION_OFFSET := 0.02

enum Completion { PENDING, SUCCEEDED, FAILED, CANCELED }

class MoveResult extends RefCounted:
	var state: Completion = Completion.PENDING

var _host: Object
var _filter: RefCounted
var _direction := Vector2.ZERO
var _intent_updates_facing := true
var _route := PackedVector2Array()
var _waypoint_index := 0
var _stopping_distance := 0.0
var _speed_override: Variant = null
var _result: MoveResult
var _last_successful_movement := Vector2.ZERO
var _steering_scale := 1.0
var _steering_correction := Vector2.ZERO
var _cast_hits: Dictionary = {}


func _init(host: Object, input_filter: RefCounted) -> void:
	assert(is_instance_valid(host) and is_instance_valid(input_filter), "移动执行缺少宿主或方向过滤器")
	_host = host
	_filter = input_filter


func has_move_order() -> bool:
	return _result != null


func get_last_successful_movement() -> Vector2:
	return _last_successful_movement


func set_movement_direction(direction: Vector2, update_facing := true) -> void:
	if direction.length_squared() >= Filter.UNITY_VECTOR_EPSILON * Filter.UNITY_VECTOR_EPSILON and has_move_order():
		_complete(false)
	_direction = direction
	_intent_updates_facing = update_facing
	if update_facing:
		_host.update_facing_from_intent(direction)


func reset_movement() -> void:
	_direction = Vector2.ZERO
	_intent_updates_facing = true
	_filter.reset()
	if has_move_order():
		_result.state = Completion.FAILED
		_result = null
	_host.clear_velocity()
	_host.update_movement_animation(Vector2.ZERO)


func set_steering_motion(scale: float, correction: Vector2) -> void:
	_steering_scale = clampf(scale, 0.0, 1.0)
	_steering_correction = correction


func move_to(destination: Vector2, stopping_distance: float = 0.1, speed_override: Variant = null) -> MoveResult:
	return move_along_path(PackedVector2Array([destination]), stopping_distance, speed_override)


func move_along_path(waypoints: PackedVector2Array, stopping_distance: float, speed_override: Variant = null) -> MoveResult:
	# 空路由不会取消仍在执行的旧命令，和原 MoveAlongPath 保持一致。
	if waypoints.is_empty():
		var failure := MoveResult.new()
		failure.state = Completion.FAILED
		return failure
	if has_move_order():
		_result.state = Completion.CANCELED
	_route = waypoints.duplicate()
	_waypoint_index = 0
	_stopping_distance = maxf(0.0, stopping_distance)
	_speed_override = speed_override
	_result = MoveResult.new()
	return _result


func handle_movement(fixed_delta: float, ramp_direction: Callable = Callable()) -> void:
	if has_move_order():
		_execute_order(fixed_delta)
	else:
		_move_in_direction(_direction, _host.calculate_move_speed(), fixed_delta,
			true, _intent_updates_facing, ramp_direction)
	# 原 HandleMovement 的每步 steering 只消费一次，不能泄露到下一步。
	_steering_scale = 1.0
	_steering_correction = Vector2.ZERO


func _execute_order(fixed_delta: float) -> void:
	var stopping := Filter.effective_stop_distance(_stopping_distance)
	var delta: Vector2 = _route[_waypoint_index] - _host.get_movement_position()
	if delta.length() <= stopping:
		_complete_waypoint()
		return
	var speed: float = _host.calculate_move_speed() if _speed_override == null else _speed_override
	if not _move_in_direction(_normalized(delta), speed, fixed_delta, false, true):
		_complete(false)
		return
	# 不用请求写入的位置冒充物理步已经完成的位置。
	var observed: Vector2 = _host.get_movement_position()
	if observed.distance_to(_route[_waypoint_index]) <= stopping:
		_complete_waypoint()


func _complete_waypoint() -> void:
	if _waypoint_index + 1 < _route.size():
		_waypoint_index += 1
		return
	_complete(true)


func _complete(success: bool) -> void:
	if not has_move_order():
		return
	_result.state = Completion.SUCCEEDED if success else Completion.FAILED
	_result = null
	_host.update_movement_animation(Vector2.ZERO)


func _move_in_direction(direction: Vector2, move_speed: float, fixed_delta: float,
		apply_input: bool, update_facing: bool, ramp_direction: Callable = Callable()) -> bool:
	_last_successful_movement = Vector2.ZERO
	_cast_hits.clear()
	var can_apply: bool = _host.can_move()
	if can_apply and update_facing:
		_host.update_facing_from_intent(direction)
	# 原逻辑即使被移动门禁阻挡，也推进输入平滑。
	var resolved: Vector2 = _filter.resolve(direction, fixed_delta, ramp_direction) if apply_input else _normalized(direction)
	if can_apply and move_speed > 0.0 and (resolved.length_squared() > 0.0 or _steering_correction.length_squared() > 0.0):
		var speed: float = move_speed * _host.calculate_speed_multiplier() * _steering_scale
		var velocity := resolved * speed
		if fixed_delta > 0.0 and _steering_correction.length_squared() > 0.0:
			velocity += _steering_correction / fixed_delta
		resolved = _normalized(velocity)
		speed = velocity.length()
		if not _try_move(resolved, speed, fixed_delta):
			if not _try_move(Vector2(resolved.x, 0.0), speed, fixed_delta):
				_try_move(Vector2(0.0, resolved.y), speed, fixed_delta)
	for hit in _cast_hits:
		_host.register_collision(hit)
	_host.update_movement_animation(_last_successful_movement)
	return not can_apply or move_speed <= 0.0 or resolved.length() <= 0.0 or _last_successful_movement.length_squared() > 0.0


func _try_move(direction: Vector2, speed: float, fixed_delta: float) -> bool:
	if direction.length() <= 0.0:
		return false
	# 原 Cast 的探测距离使用完整速度，轴回退不重算速度，也不归一化轴分量。
	var hits: Array = _host.cast_motion_hits(direction, speed * fixed_delta + COLLISION_OFFSET)
	for hit in hits:
		_cast_hits[hit] = true
	if not hits.is_empty():
		return false
	_last_successful_movement = direction * speed
	_host.request_move_position(_host.get_movement_position() + direction * speed * fixed_delta)
	return true


static func _normalized(value: Vector2) -> Vector2:
	var magnitude := value.length()
	return value / magnitude if magnitude > Filter.UNITY_VECTOR_EPSILON else Vector2.ZERO
