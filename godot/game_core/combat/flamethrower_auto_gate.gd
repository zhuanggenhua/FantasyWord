extends RefCounted
## 20010 的原 Auto、无弹匣、无缓冲门控；只提交请求，不自行执行伤害或表现。
## 源31629d5：FormalAbilityInputGateRuntime、TimelineActiveAbility、表20010。
## 前摇为首个玩法任务1/60，间隔为整条Timeline的65/60；一次Tick只走一次分支。
enum State { IDLE, START, WINDUP, USE, RECOVERY, STOP, INTERRUPTED }
signal state_changed(value: int)
signal sequence_started
signal sequence_stopped
signal interrupted
const WINDUP_SECONDS := 8947849.0 / 536870912.0
const RECOVERY_SECONDS := 9087659.0 / 8388608.0 # float32(65/60)
var state := State.IDLE
var timer := 0.0
var trigger_held := false
var _time_scale := 1.0
var _can_start: Callable
var _commit_fire: Callable

func _init(can_start: Callable, commit_fire: Callable) -> void:
	_can_start = can_start
	_commit_fire = commit_fire

func set_time_scale(value: float) -> void:
	_time_scale = _f32(maxf(0.05, value))

func is_busy() -> bool:
	return state not in [State.IDLE, State.STOP, State.INTERRUPTED]

func request_use() -> bool:
	trigger_held = true
	if state in [State.IDLE, State.STOP]:
		return _start()
	# 原表BufferInput=false；忙碌时绝不缓存，但保持按住事实。
	return false

func release_use() -> bool:
	trigger_held = false
	match state:
		State.WINDUP:
			interrupt()
		State.RECOVERY:
			_stop()
	return false

func advance(delta: float) -> void:
	var elapsed := _f32(_f32(maxf(0.0, delta)) * _time_scale)
	match state:
		State.WINDUP, State.RECOVERY:
			timer = _f32(timer - elapsed)
			if timer <= 0.0:
				timer = 0.0
				if state == State.WINDUP:
					_fire()
				elif not (trigger_held and _start()):
					_stop()
		State.STOP, State.INTERRUPTED:
			# 起手资格失败不会在Idle自行重试，需新的输入请求。
			_change(State.IDLE)

func interrupt() -> void:
	_change(State.INTERRUPTED)
	interrupted.emit()
	sequence_stopped.emit()

# Only used after the owning formal Timeline is already quiescent.
func restore_no_ammo_idle() -> void:
	state = State.IDLE
	timer = 0.0
	trigger_held = false

func _start() -> bool:
	if _can_start.is_valid() and not _can_start.call():
		return false
	sequence_started.emit()
	_change(State.START)
	timer = WINDUP_SECONDS
	_change(State.WINDUP)
	return true

func _fire() -> void:
	_change(State.USE)
	# 宿主执行原出手点验证；失败对应OnInputGateUsePerformed里的Interrupt。
	if not _commit_fire.call():
		if state != State.INTERRUPTED:
			interrupt()
		return
	if state == State.USE:
		timer = RECOVERY_SECONDS
		_change(State.RECOVERY)

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
