extends "res://game_core/combat/attack_hit_frame.gd"
## 31629d53 的 Timeline 101。开始/结束由实际能力实例持有；这里只调度任务。
const Cue = preload("res://game_core/presentation/cue_play_character_animation.gd")
const ATTACK_POLYGON := [Vector2(.175,-.25), Vector2(1.125,-.25), Vector2(1.125,.55), Vector2(.175,.55)]
const HIT_MASK := 128
var _driver: WeakRef
var _cue := Cue.new()
var _cue_live := false
var _cue_requested := false

func _init(hit_task: Callable, driver: Node) -> void:
	super(8, 30, hit_task)
	if is_instance_valid(driver): _driver = weakref(driver)

func _on_frame_crossed(current_frame: int) -> void:
	match current_frame:
		1:
			# TaskDoCost 在原 20001 的 Cost=0 且没有 CAbilityCost 时直接返回。
			pass
		2:
			_cue.on_add(_driver.get_ref() if _driver != null else null)
			_cue_live = true
			_cue_requested = true
		24:
			_remove_cue()

## 显示阶段独立消费；一帧跨过整个 Cue 窗口时不补播已经移除的动作。
func flush_display() -> bool:
	if not _cue_requested: return true
	_cue_requested = false
	var started := _cue.on_activate("Attack")
	if not started: push_error(_cue.last_error)
	return started

func stop() -> void:
	_remove_cue()
	super.stop()

func _remove_cue() -> void:
	_cue_requested = false
	if not _cue_live: return
	_cue_live = false
	if not _cue.on_remove(): push_error(_cue.last_error)
