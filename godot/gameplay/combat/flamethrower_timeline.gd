extends "res://game_core/combat/attack_hit_frame.gd"
## 31629d53 的 20010 原时间轴：只调度，不代持输入、位置、伤害或地表状态。
## 命中与地表回调须读取执行帧的实际位置和 Movable 朝向，不能捕获起手快照。
## 喷流与音效由可选原资产表现主机处理，玩法与私有素材加载解耦。
const Cue = preload("res://game_core/presentation/cue_play_character_animation.gd")
const SOURCE_ABILITY := 20010
const EFFECT_ID := 2003
const HIT_MASK := 128
const ATTACK_POLYGON := [Vector2(.2,-.3), Vector2(1.2,-.7), Vector2(3.2,-1.8),
	Vector2(3.2,1.8), Vector2(1.2,.7), Vector2(.2,.3)]
const HIT_FRAMES := [1, 10, 20, 30, 40, 50, 60]
const CONE_RANGE := 3.5
const HALF_ANGLE := 30.0
const INTENSITY := 1.0
const EXPOSURE := 0.1
var _world_element: Callable
var _driver: WeakRef
var _cue := Cue.new()
var _cue_live := false
var _cue_requested := false
var _start_spray: Callable
var _stop_spray: Callable
var _spray_active := false

func _init(hit: Callable, world_element: Callable, driver: Node) -> void:
	# 单帧基类只提供同一个 float32 时间轴时钟，多命中片段在下方调度。
	super(-1, 65, hit)
	assert(hit.is_valid() and world_element.is_valid(), "喷火时间轴缺少角色命中或世界元素入口")
	_world_element = world_element
	if is_instance_valid(driver): _driver = weakref(driver)

## Only the source mounting/audio host binds this pair; removal must not stop audio.
func bind_spray_cues(start: Callable, remove: Callable) -> bool:
	if playing or not start.is_valid() or not remove.is_valid(): return false
	if _start_spray.is_valid() or _stop_spray.is_valid(): return false
	_start_spray = start
	_stop_spray = remove
	return true

func _on_frame_crossed(current_frame: int) -> void:
	# 保持原 Tracks 顺序：角色表现、世界元素、角色命中。
	if current_frame == 1:
		_cue.on_add(_driver.get_ref() if _driver != null else null)
		_cue_live = true
		_cue_requested = true
	elif current_frame == 60:
		_remove_cue()
	# TaskApplyWorldElement.OnBegin 立即提交；OnTick 只提交之后每隔 3 帧。
	if current_frame >= 1 and current_frame <= 60 and (current_frame - 1) % 3 == 0:
		_world_element.call()
	if current_frame in HIT_FRAMES:
		_hit.call()

func flush_display() -> bool:
	if not _cue_requested: return true
	_cue_requested = false
	var started := _cue.on_activate("Attack")
	if not started: push_error(_cue.last_error)
	if _start_spray.is_valid():
		_spray_active = true
		_start_spray.call()
	return started

func stop() -> void:
	_remove_cue()
	super.stop()

func _remove_cue() -> void:
	_cue_requested = false
	if not _cue_live: return
	_cue_live = false
	if _spray_active:
		_spray_active = false
		_stop_spray.call()
	if not _cue.on_remove(): push_error(_cue.last_error)
