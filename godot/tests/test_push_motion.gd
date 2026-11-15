extends SceneTree
const Execution = preload("res://game_core/movement/motion_execution.gd")
const Filter = preload("res://game_core/movement/motion_filter.gd")
const Scene = preload("res://validation/scenes/keyboard_motion_fixture.tscn")
var checks := 0
var failures := 0
class Host extends RefCounted:
	var position := Vector2.ZERO
	var requests: Array = []
	var hits: Array = []
	var collisions: Array = []
	var animations: Array = []
	var clears := 0
	func get_movement_position(): return position
	func request_move_position(value): requests.append(value)
	func cast_motion_hits(_direction, _distance): return hits
	func clear_velocity(): clears += 1
	func can_move(): return false # 推力不受 CanMove 门禁影响。
	func calculate_move_speed(): return 4.0
	func calculate_speed_multiplier(): return 10.0 # 推力不吃普通移动倍率。
	func update_movement_animation(value): animations.append(value)
	func update_facing_from_intent(_value): pass
	func register_collision(value): collisions.append(value)
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _run() -> void:
	var host := Host.new()
	var executor := Execution.new(host, Filter.new(Filter.Mode.FREE, false, 0.05, 10, 10))
	executor.push_motion(Vector2.RIGHT, 5, 10, 0, 1)
	_check(not executor.is_pushed() and host.clears == 0, "不可推动时无副作用")
	var task = executor.move_to(Vector2(10,0))
	executor.push_motion(Vector2(2,0), 5, 10, 1, 1)
	_check(executor.is_pushed() and host.clears == 1 and executor.has_move_order(), "推动清速度但不取消路线")
	executor.handle_push(0.02)
	_check(host.requests.back().is_equal_approx(Vector2(0.2,0)), "方向不归一化且不使用普通速度倍率")
	_check(host.animations.is_empty(), "推力不更新动画")
	executor.handle_push(0.02)
	_check(host.requests.back().is_equal_approx(Vector2(0.16,0)), "原线性衰减 5 到 4")
	executor.reset_movement()
	_check(executor.is_pushed() and task.state == Execution.Completion.FAILED, "停止移动不打断推力")
	executor.interrupt_push()
	_check(not executor.is_pushed(), "显式打断推力")
	executor.push_motion(Vector2.RIGHT, 0.2, 10, 1, 1)
	var previous := host.requests.size()
	executor.handle_push(0.02)
	_check(not executor.is_pushed() and host.requests.size() == previous, "强度等于 0.2 不再移动")
	executor.push_motion(Vector2.RIGHT, 5, 100, 1, 1)
	executor.handle_push(0.02)
	previous = host.requests.size()
	executor.handle_push(0.02)
	_check(not executor.is_pushed() and host.requests.size() == previous, "不夹紧 lerp，负强度下步清除")
	var obstacle := Node.new()
	root.add_child(obstacle)
	host.hits = [obstacle, obstacle]
	executor.push_motion(Vector2.RIGHT, 5, 0, 1, 1)
	executor.handle_push(0.02)
	executor.handle_push(0.02)
	_check(host.collisions == [obstacle], "同一推力碰撞身份仅通知一次")
	executor.push_motion(Vector2.RIGHT, 5, 0, 1, 1)
	executor.handle_push(0.02)
	_check(host.collisions == [obstacle, obstacle], "替换推力开启新的去重集合")
	executor.interrupt_push()
	host.hits.clear()
	executor.push_motion(Vector2.RIGHT, 2, 5, 2, 2)
	executor.handle_push(0.02)
	_check(host.requests.back().is_equal_approx(Vector2(0.08,0)), "角色强度缩放")
	executor.handle_push(0.02)
	_check(host.requests.back().is_equal_approx(Vector2(0.064,0)), "角色阻力缩放")
	obstacle.queue_free()
	# 同一可运行诊断场景，而非替身坐标：其物理回调调用原生身体。
	var scene := Scene.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	var before: Vector2 = scene.body.get_movement_position()
	scene.body.push_motion(Vector2.RIGHT)
	_check(not scene.body.can_move(), "原生推动期间普通移动门禁关闭")
	await physics_frame
	await physics_frame
	_check(scene.body.get_movement_position().x > before.x, "推力写入真实同步物理身体")
	for step in range(60): await physics_frame
	_check(not scene.body.is_pushed() and scene.body.can_move(), "衰减结束恢复正常移动门禁")
	var resting: Vector2 = scene.body.get_movement_position()
	for step in range(4): await physics_frame
	_check(scene.body.get_movement_position() == resting, "推力结束后身体稳定")
	scene.body.push_motion(Vector2.LEFT)
	scene.body.interrupt_push()
	for step in range(4): await physics_frame
	_check(scene.body.get_movement_position() == resting, "下一物理步前中断不移动")
	var wall := StaticBody2D.new()
	wall.collision_layer = 8
	wall.collision_mask = 0
	wall.position = scene.body.position + Vector2(0.5, 0)
	var wall_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(0.2, 4)
	wall_shape.shape = rectangle
	wall.add_child(wall_shape)
	root.add_child(wall)
	await physics_frame
	scene.body.push_motion(Vector2(1, 1), 5, 10)
	for step in range(4): await physics_frame
	_check(scene.body.get_movement_position() == resting, "真实地形挡住推力，不能擅自轴向滑动")
	scene.body.interrupt_push()
	wall.queue_free()
	scene.queue_free()
	await process_frame
	if failures == 0: print("PASS 推力执行和原生身体：%d 项" % checks)
	quit(1 if failures else 0)
