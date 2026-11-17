extends RefCounted
## FormalAbilityInputGateRuntime 的20004 HoldRelease无弹匣/无连发切片。
## 源31629d5：AbilityGameCore20004 HoldRelease；Timeline36/60秒间隔。
## CreateTimelineGate关闭弹匣/连发；HoldRelease跳过前摇且永不缓冲输入。
## 回调release_use_fn代表 ActiveAbilityBase.OnInputGateUsePerformed 独立释放验证/
## lifecycle begin/commit；这些真实GAS规则由宿主负责，不能拿起手结果代替。
enum State { IDLE, START, CHARGING, USE, DELAY_BETWEEN_USES, STOP, INTERRUPTED }
signal state_changed(value: int)
signal sequence_started
signal sequence_stopped
signal interrupted
var state: int = State.IDLE
var timer := 0.0
var trigger_held := false
var _time_scale := 1.0
var _can_start: Callable
var _release_use: Callable
const RELEASE_INTERVAL = 5033165.0 / 8388608.0 # Unity float32(36/60)

func _init(can_start: Callable, release_use_fn: Callable):
	_can_start = can_start
	_release_use = release_use_fn

func is_charging() -> bool: return state == State.CHARGING
func set_time_scale(value: float) -> void: _time_scale = _f32(maxf(0.05,value))
func request_use() -> bool:
	trigger_held = true
	if state != State.IDLE and state != State.STOP: return false
	if _can_start.is_valid() and not _can_start.call(): return false
	sequence_started.emit()
	_change(State.START)
	_change(State.CHARGING)
	return true

func release_use() -> bool:
	trigger_held = false
	if state == State.CHARGING:
		_change(State.USE)
		# 原宿主验证/上下文/BeginLifecycle/Commit失败均Interrupt。
		var accepted: bool = _release_use.call()
		if not accepted:
			if state != State.INTERRUPTED: interrupt()
			return false
		if state == State.USE:
			timer = RELEASE_INTERVAL
			_change(State.DELAY_BETWEEN_USES)
		return true
	if state == State.DELAY_BETWEEN_USES: _stop()
	return false

func interrupt() -> void:
	_change(State.INTERRUPTED)
	interrupted.emit()
	sequence_stopped.emit()

func advance(delta: float) -> void:
	var scaled := _f32(_f32(maxf(0.0,delta))*_time_scale)
	match state:
		State.DELAY_BETWEEN_USES:
			timer = _f32(timer-scaled)
			if timer <= 0.0:
				timer = 0.0
				_stop()
		State.STOP, State.INTERRUPTED:
			_change(State.IDLE)

func _stop() -> void:
	if state != State.IDLE and state != State.STOP:
		_change(State.STOP)
		sequence_stopped.emit()
func _change(value: int) -> void:
	if state != value:
		state = value
		state_changed.emit(value)
static func _f32(value: float) -> float:
	return PackedFloat32Array([value])[0]

## 原输入门控的忙碌判定；后摇也是忙碌，不等同于正在蓄力。
func is_busy() -> bool:
	return state not in [State.IDLE, State.STOP, State.INTERRUPTED]
