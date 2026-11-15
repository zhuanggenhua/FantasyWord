extends RefCounted
## Movable 的方向意图过滤，不拥有位置、碰撞或角色速度。

enum Mode { FREE, HORIZONTAL, VERTICAL, FOUR_WAY, EIGHT_WAY }

const ACCEPTABLE_DISTANCE_FROM_TARGET := 0.1
const UNITY_VECTOR_EPSILON := 0.00001

var _mode: Mode
var _analog: bool
var _idle: float
var _acceleration: float
var _deceleration: float
var _amount := 0.0
var _smoothed := Vector2.ZERO


func _init(mode: Mode, use_analog: bool, idle: float, acceleration: float, deceleration: float) -> void:
	_mode = mode
	_analog = use_analog
	_idle = idle
	_acceleration = acceleration
	_deceleration = deceleration


func reset() -> void:
	_amount = 0.0
	_smoothed = Vector2.ZERO


func resolve(raw: Vector2, fixed_delta: float, ramp_direction: Callable = Callable()) -> Vector2:
	var direction := _restrict(raw)
	# 地图解析成功时采用坡道方向，但保留输入强度。null 表示地图无改写。
	if direction.length_squared() > 0.000001 and ramp_direction.is_valid():
		var ramp = ramp_direction.call(direction)
		if ramp is Vector2:
			direction = ramp * direction.length()

	var length := direction.length()
	var target := direction.limit_length(1.0) if _analog else (
		direction / length if length > UNITY_VECTOR_EPSILON else Vector2.ZERO)
	if target.length() <= _idle:
		target = Vector2.ZERO

	var zero_intent := target.length_squared() < UNITY_VECTOR_EPSILON * UNITY_VECTOR_EPSILON
	if _acceleration <= 0.0 or _deceleration <= 0.0:
		_smoothed = target
		_amount = 0.0 if zero_intent else 1.0
		return _smoothed

	if zero_intent:
		var t := clampf(_deceleration * fixed_delta, 0.0, 1.0)
		_amount = lerpf(_amount, 0.0, t)
		_smoothed = _smoothed.lerp(_smoothed * _amount, t)
	else:
		_amount = lerpf(_amount, 1.0, clampf(_acceleration * fixed_delta, 0.0, 1.0))
		_smoothed = target.limit_length(_amount)

	if _smoothed.length() <= _idle:
		_smoothed = Vector2.ZERO
	return _smoothed


static func effective_stop_distance(requested: float) -> float:
	return maxf(ACCEPTABLE_DISTANCE_FROM_TARGET, requested)


func _restrict(input: Vector2) -> Vector2:
	match _mode:
		Mode.HORIZONTAL:
			input.y = 0.0
		Mode.VERTICAL:
			input.x = 0.0
		Mode.FOUR_WAY:
			if absf(input.x) > absf(input.y):
				input.y = 0.0
			else:
				input.x = 0.0
		Mode.EIGHT_WAY:
			input = Vector2(_round_even(input.x), _round_even(input.y))
	return input


static func _round_even(value: float) -> float:
	var lower := floorf(value)
	var fraction := value - lower
	if fraction < 0.5:
		return lower
	if fraction > 0.5:
		return lower + 1.0
	return lower if int(lower) % 2 == 0 else lower + 1.0
