extends RefCounted
## Ability 20001 的本地 SemiAuto gate，不负责正式属性、技能开销和冷却。
## 源：AbilityGameCore 20001、Timeline 101、FormalAbilityInputGateRuntime。
enum State { IDLE, START, WINDUP, USE, RECOVERY, STOP, INTERRUPTED }
signal state_changed(value: int)
signal sequence_started
signal sequence_stopped
signal interrupted

const WINDUP_SECONDS := 8947849.0 / 536870912.0 # Unity float32(1/60)
const RECOVERY_SECONDS := 0.5 # Timeline LifeTime 30/60.
const BUFFER_SECONDS := 0.25
var state := State.IDLE
var timer := 0.0
var buffered := false
var _buffer_timer := 0.0
var _trigger_released := true
var _time_scale := 1.0
var _can_start: Callable
var _commit_fire: Callable

func _init(can_start: Callable, commit_fire: Callable) -> void:
	_can_start = can_start
	_commit_fire = commit_fire

func set_time_scale(value: float) -> void:
	_time_scale = _f32(maxf(0.05, value))

func request_use() -> bool:
	if not _trigger_released:
		_buffer()
		return false
	if state in [State.IDLE, State.STOP]:
		return _start()
	_buffer()
	return buffered

func release_use() -> bool:
	_trigger_released = true
	match state:
		State.WINDUP:
			interrupt()
		State.RECOVERY:
			_stop()
	# 松手只作打断/停止，不像蓄力一样提交出手。
	return false

func advance(delta: float) -> void:
	var elapsed := _f32(_f32(maxf(0.0, delta)) * _time_scale)
	# 原 Tick 先执行缓冲过期，再处理当前状态；过期与可消费同帧时不会发招。
	if buffered:
		_buffer_timer = _f32(_buffer_timer - elapsed)
		if _buffer_timer <= 0.0:
			_clear_buffer()
	match state:
		State.WINDUP, State.RECOVERY:
			timer = _f32(timer - elapsed)
			if timer <= 0.0:
				timer = 0.0
				if state == State.WINDUP:
					_fire()
				else:
					_stop()
		State.STOP, State.INTERRUPTED:
			_change(State.IDLE)
			if buffered and _trigger_released:
				buffered = false
				_start() # 立即按当前资格重检，不能沿用入缓冲时的资格。

func interrupt() -> void:
	_clear_buffer()
	_change(State.INTERRUPTED)
	interrupted.emit()
	sequence_stopped.emit()

# Only used after the owning formal Timeline is already quiescent.
func restore_no_ammo_idle() -> void:
	state = State.IDLE
	timer = 0.0
	_trigger_released = true
	_clear_buffer()

func _start() -> bool:
	if _can_start.is_valid() and not _can_start.call():
		return false
	_clear_buffer()
	_trigger_released = false
	sequence_started.emit()
	_change(State.START)
	timer = WINDUP_SECONDS
	_change(State.WINDUP)
	return true

func _fire() -> void:
	_change(State.USE)
	if not _commit_fire.call():
		if state != State.INTERRUPTED:
			interrupt()
		return
	if state == State.USE:
		timer = RECOVERY_SECONDS
		_change(State.RECOVERY)

func _buffer() -> void:
	buffered = true
	_buffer_timer = BUFFER_SECONDS

func _clear_buffer() -> void:
	buffered = false
	_buffer_timer = 0.0

func _stop() -> void:
	if state not in [State.IDLE, State.STOP]:
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
