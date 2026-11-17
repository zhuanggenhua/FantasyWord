extends "res://game_core/combat/attack_hit_frame.gd"
## 锁定 31629d5 的 20004 时间轴：36 帧、12 帧命中、2–30 帧 Cue。
## 仅此动作、非重入。命中、角色表现和后续 GAS 请求由既有拥有者负责。
const Cue = preload("res://game_core/presentation/cue_play_character_animation.gd")
const ACTION := "ChargedAttack"
var _driver: WeakRef
var _cue = Cue.new()
var _cue_live := false
var _cue_requested := false

func _init(hit: Callable, driver: Node) -> void:
	super(12, 36, hit)
	if is_instance_valid(driver): _driver = weakref(driver)

func _on_frame_crossed(current_frame: int) -> void:
	match current_frame:
		2:
			var driver: Node = _driver.get_ref() if _driver != null else null
			_cue.on_add(driver)
			_cue_live = true
			_cue_requested = true
		30:
			_remove_cue()

## 源 TaskPlayCue 只置可播放标记；SCueStart 在显示系统阶段激活。
## 同一逻辑更新跨过帧 2 和 30 时，已移除的 Cue 不得随后播放。
func flush_display() -> bool:
	if not _cue_requested:
		return true
	_cue_requested = false
	var activated: bool = _cue.on_activate(ACTION)
	if not activated: push_error(_cue.last_error)
	return activated

func stop() -> void:
	_remove_cue()
	super.stop()

func _remove_cue() -> void:
	_cue_requested = false
	if not _cue_live: return
	_cue_live = false
	if not _cue.on_remove(): push_error(_cue.last_error)
