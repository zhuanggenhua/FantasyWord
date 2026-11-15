extends SceneTree
const Keyboard = preload("res://game_core/movement/keyboard_movement_input.gd")
const Commands = preload("res://game_core/movement/movement_commands.gd")
var keyboard = Keyboard.new()
var trace: Array = []
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	key(KEY_W, true)
	expect(last_direction() == Vector2.UP * -1, "W 使用 Unity 正 Y")
	key(KEY_D, true)
	expect(last_direction().is_equal_approx(Vector2(1, 1).normalized()), "同组斜向归一化")
	key(KEY_D, false)
	expect(last_direction() == Vector2(0, 1), "释放 D 恢复 W")
	key(KEY_S, true)
	expect(last_kind() == Commands.Kind.STOP_MOVE, "组内反向取消")
	key(KEY_S, false)
	expect(last_direction() == Vector2(0, 1), "释放反向键恢复")
	key(KEY_RIGHT, true)
	expect(trace.size() == 5, "等强方向键不抢占也不发命令")
	expect(keyboard.get_direction() == Vector2(0, 1), "跨组不合并")
	key(KEY_W, false)
	expect(last_kind() == Commands.Kind.MOVE and last_direction() == Vector2(1, 0), "释放当前组交接而不停止")
	key(KEY_RIGHT, false)
	expect(last_kind() == Commands.Kind.STOP_MOVE, "最后组释放停止")
	fresh()
	key(KEY_RIGHT, true)
	key(KEY_W, true)
	expect(trace.size() == 1 and last_direction() == Vector2(1, 0), "反序先方向键保持所有权")
	key(KEY_RIGHT, false)
	expect(last_direction() == Vector2(0, 1), "反序释放交接")
	fresh()
	key(KEY_W, true)
	key(KEY_DOWN, true)
	expect(last_direction() == Vector2(0, 1) and trace.size() == 1, "跨组反向不取消")
	key(KEY_W, false)
	expect(last_direction() == Vector2(0, -1), "跨组反向交接")
	fresh()
	key(KEY_W, true)
	key(KEY_RIGHT, true)
	key(KEY_S, true)
	expect(last_direction() == Vector2(1, 0), "活跃组内抵消触发交接")
	key(KEY_S, false)
	expect(last_direction() == Vector2(1, 0) and trace.size() == 2, "恢复等强旧组不抢回")
	key(KEY_RIGHT, false)
	expect(last_direction() == Vector2(0, 1), "交还仍按住旧组")
	fresh()
	key(KEY_W, true, true)
	expect(trace.is_empty() and keyboard.get_direction() == Vector2(0, 1), "门禁阻止 performed 命令而非设备状态")
	key(KEY_W, false, true)
	expect(last_kind() == Commands.Kind.STOP_MOVE, "门禁不吞 canceled")
	fresh()
	key(KEY_W, true)
	key(KEY_W, true)
	key(KEY_W, true, false, true)
	key(KEY_Q, true)
	expect(trace.size() == 1, "重复状态 echo 无关键不产生新命令")
	var logical := InputEventKey.new()
	logical.keycode = KEY_D
	logical.pressed = true
	keyboard.handle_key(logical, false, capture)
	expect(trace.size() == 1, "不把逻辑字符冒充物理键")
	key(KEY_W, false)
	key(KEY_W, false)
	expect(trace.size() == 2, "重复释放不重复停止")
	fresh()
	key(KEY_A, true)
	key(KEY_LEFT, true)
	key(KEY_A, false)
	expect(keyboard.get_direction() == Vector2(-1, 0) and last_kind() != Commands.Kind.STOP_MOVE,
		"同值换组仅验状态不验回调次数")
	key(KEY_LEFT, false)
	expect(last_kind() == Commands.Kind.STOP_MOVE, "同值交接后最后释放")
	if failures == 0:
		print("PASS 有序物理键盘子集：%d 项" % checks)
	quit(failures)

func key(code: Key, pressed: bool, blocked: bool = false, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	keyboard.handle_key(event, blocked, capture)

func capture(kind: int, direction: Vector2, _world: Variant) -> Variant:
	trace.append([kind, direction])
	return kind

func last_direction() -> Vector2:
	return trace[-1][1]

func last_kind() -> int:
	return trace[-1][0]

func fresh() -> void:
	keyboard = Keyboard.new()
	trace.clear()

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL " + message)
