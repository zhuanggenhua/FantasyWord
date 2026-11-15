extends SceneTree
## 只验证原输入与移动模块的真实调用链，角色物理在此仍是测试替身。
const Keyboard = preload("res://game_core/movement/keyboard_movement_input.gd")
const Commands = preload("res://game_core/movement/movement_commands.gd")
const Movement = preload("res://game_core/movement/character_movement.gd")
const Filter = preload("res://game_core/movement/motion_filter.gd")

class Driver:
	extends Node
	var keyboard = Keyboard.new()
	var motion = Filter.new(Filter.Mode.FREE, false, 0.05, 10, 10)
	var movement = Movement.new(self, 0.05)
	var direction := Vector2.ZERO
	var events: Array = []
	var blocked := false

	func _input(event: InputEvent) -> void:
		if event is InputEventKey:
			keyboard.handle_key(event, blocked, _submit)

	func _submit(kind: int, value: Vector2, point: Variant) -> int:
		events.append(kind)
		return Commands.submit_single_character(kind, value, point, self, true,
			self, true, true, self, movement, null)

	func set_movement_direction(value: Vector2) -> void:
		direction = value

	func reset_movement() -> void:
		direction = Vector2.ZERO
		motion.reset()

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var node := Driver.new()
	root.add_child(node)
	await process_frame
	_key(KEY_W, true)
	_check(node.direction == Vector2(0, 1), "Godot Viewport 投递物理 W，当前意图用 Unity 坐标")
	_check(node.motion.resolve(node.direction, 0.02).is_equal_approx(Vector2(0, 0.2)), "移动意图进入原版加速计算")
	_key(KEY_RIGHT, true)
	_check(node.events == [Commands.Kind.MOVE] and node.direction == Vector2(0, 1), "跨组不混合方向")
	_key(KEY_W, false)
	_check(node.events == [Commands.Kind.MOVE, Commands.Kind.MOVE] and node.direction == Vector2.RIGHT, "松开当前来源向另一组交接")
	_check(node.motion.resolve(node.direction, 0.02).is_equal_approx(Vector2(0.36, 0)), "交接保留已有加速量")
	node.blocked = true
	_key(KEY_RIGHT, false)
	_check(node.events.back() == Commands.Kind.STOP_MOVE and node.direction == Vector2.ZERO, "输入屏蔽下仍发送释放停止")
	_check(node.motion.resolve(node.direction, 0.02) == Vector2.ZERO, "明确停令立即清掉移动缓动")
	if failures == 0:
		print("PASS Viewport 移动链：%d 项" % checks)
	quit(1 if failures else 0)


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	root.push_input(event, true)


func _check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("Viewport 移动链断言失败：" + detail)
