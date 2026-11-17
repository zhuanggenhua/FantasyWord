extends RefCounted
## InputSystem_Actions 的两个独立 Point：仅迁移显式配对鼠标的位置变化。
## 宿主负责设备配对、动作图启停；不伪造 PlayerInput 或初始鼠标状态。
enum Map { GAMEPLAY, UI }
var _device: int
var _enabled := [false, false]
var _points: Array = [null, null]
var _last_position: Variant = null

func _init(paired_mouse_device: int) -> void:
	_device = paired_mouse_device

func enable(map: Map) -> void:
	assert(map in [Map.GAMEPLAY, Map.UI])
	_enabled[map] = true

func disable(map: Map) -> void:
	assert(map in [Map.GAMEPLAY, Map.UI])
	_enabled[map] = false
	_points[map] = null

## 显式设备重置：动作失去 activeControl；不会用旧坐标重新触发。
func reset_device() -> void:
	_points = [null, null]
	_last_position = null

func observe(event: InputEvent) -> void:
	# 触屏模拟鼠标不是原 <Mouse> 配对设备；按钮事件也不是位置变化。
	if not event is InputEventMouseMotion or event.device < 0 or event.device != _device: return
	if not event.position.is_finite() or not event.relative.is_finite(): return
	var changed: bool = event.relative != Vector2.ZERO
	if _last_position is Vector2: changed = event.position != _last_position
	_last_position = event.position
	if not changed: return
	for map in [Map.GAMEPLAY, Map.UI]:
		if _enabled[map]: _points[map] = event.position

## PassThrough 在首次变化后保持 Performed，静止和零坐标均不使其失效。
func read_active(map: Map) -> Variant:
	assert(map in [Map.GAMEPLAY, Map.UI])
	return _points[map]
