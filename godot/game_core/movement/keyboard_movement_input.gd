extends RefCounted
## Gameplay/Move 的有序键盘子集，不是 PlayerInput 或完整设备仲裁替代品。
## 作者源：Assets/InputSystem_Actions.inputactions 的独立 WASD、方向键 2DVector。
## 方向沿用 Unity 命令坐标（上为 +Y），物理世界坐标转换不属于此层。
const Commands = preload("res://game_core/movement/movement_commands.gd")
const GROUPS = [[KEY_W, KEY_S, KEY_A, KEY_D], [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]]
var _held: Dictionary = {}
var _active_group: int = -1
var _direction: Vector2 = Vector2.ZERO

func get_direction() -> Vector2:
	return _direction

# 仅接收已经按系统顺序交付的物理键状态变化，不自行重排同帧事件。
# 同值换组的 performed 次数及平台同时按键顺序尚未完成 Unity 原生对照。
func handle_key(event: InputEventKey, blocked: bool, submit: Callable) -> Variant:
	if event.echo:
		return null
	var key: int = event.physical_keycode
	var changed_group: int = -1
	for index in range(GROUPS.size()):
		if key in GROUPS[index]:
			changed_group = index
			break
	if changed_group < 0 or bool(_held.get(key, false)) == event.pressed:
		return null
	_held[key] = event.pressed
	var candidate: Vector2 = _read_group(changed_group)
	if changed_group != _active_group:
		# 两组都是 DigitalNormalized：非零等强，不能相加，也不能后来者抢占。
		if _active_group >= 0 or candidate == Vector2.ZERO:
			return null
		_active_group = changed_group
	else:
		if candidate == Vector2.ZERO:
			_active_group = -1
			# 当前驱动归零才按原 binding 次序交接。
			for index in range(GROUPS.size()):
				var alternate: Vector2 = _read_group(index)
				if alternate != Vector2.ZERO:
					_active_group = index
					candidate = alternate
					break
	_direction = candidate
	if _active_group < 0:
		return Commands.on_move_canceled(submit)
	return Commands.on_move_performed(_direction, blocked, submit)

## 禁用 Gameplay/Move 时，只取消活跃的方向动作，不把点击路径当成键盘动作。
func deactivate(submit: Callable) -> Variant:
	var had_move := _active_group >= 0
	_held.clear()
	_active_group = -1
	_direction = Vector2.ZERO
	return Commands.on_move_canceled(submit) if had_move else null

func _read_group(index: int) -> Vector2:
	var keys: Array = GROUPS[index]
	return Vector2(
		int(bool(_held.get(keys[3], false))) - int(bool(_held.get(keys[2], false))),
		int(bool(_held.get(keys[0], false))) - int(bool(_held.get(keys[1], false)))
	).normalized()
