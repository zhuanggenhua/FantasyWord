extends SceneTree
const Body = preload("res://game_core/movement/native_motion_body.gd")
const Filter = preload("res://game_core/movement/motion_filter.gd")
const Execution = preload("res://game_core/movement/motion_execution.gd")
const CharacterMovement = preload("res://game_core/movement/character_movement.gd")
const Terrain = preload("res://game_core/movement/terrain_cast.gd")
var checks := 0
var failures := 0

class MotionOwner extends RefCounted:
	var allowed := true
	var collisions: Array = []
	var animations: Array[Vector2] = []
	var facing: Array[Vector2] = []
	func can_move(): return allowed
	func calculate_move_speed(): return 4.0
	func calculate_speed_multiplier(): return 1.0
	func update_movement_animation(value): animations.append(value)
	func update_facing_from_intent(value): facing.append(value)
	func register_collision(value): collisions.append(value)

class Route extends RefCounted:
	func try_build_world_path(_start, destination): return PackedVector2Array([destination])

class RejectedRoute extends RefCounted:
	func try_build_world_path(_start, _destination): return null

class Driver extends Node:
	signal stepped
	var action := Callable()
	func _physics_process(_delta):
		if action.is_valid():
			var current := action
			action = Callable()
			current.call()
		stepped.emit()

var driver: Driver

func _initialize() -> void:
	call_deferred("_run")

func _step(action := Callable()) -> void:
	driver.action = action
	await driver.stepped

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL ", label)

func _body(source_position: Vector2, owner: MotionOwner, wall_distance := 0.0):
	var body := Body.new()
	body.position = Terrain.to_physics(source_position)
	body.collision_layer = 256
	# 正式地形查询已有排除 Character 的掩码；此测试不接入动态碰撞响应。
	body.collision_mask = 7752
	var collision := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 0.39
	capsule.height = 0.86
	collision.shape = capsule
	collision.position = Vector2(0, -0.42)
	body.add_child(collision)
	root.add_child(body)
	body.configure_movement(collision, Filter.new(Filter.Mode.FREE, false, 0.05, 10.0, 10.0), owner, 7752, wall_distance)
	return body

func _wall(source_position: Vector2, size: Vector2):
	var wall := StaticBody2D.new()
	wall.position = Terrain.to_physics(source_position)
	wall.collision_layer = 8
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	wall.add_child(collision)
	root.add_child(wall)
	return wall

func _run() -> void:
	driver = Driver.new()
	root.add_child(driver)
	var owner := MotionOwner.new()
	var body = _body(Vector2.ZERO, owner)
	var slide_owner := MotionOwner.new()
	var slide_body = _body(Vector2(0,10), slide_owner)
	var corner = _wall(Vector2(0.38,10.82), Vector2(0.08,0.08))
	await _step()
	await _step()
	_check(body.sync_to_physics and body.get_movement_position() == Vector2.ZERO, "原生同步身体保留初始姿态")
	await _step(func():
		body.request_move_position(Vector2(1,0))
		_check(body.get_movement_position() == Vector2.ZERO, "提交不会立即改动观察位置")
		body.request_move_position(Vector2(2,0))
		_check(body.get_movement_position() == Vector2.ZERO, "第二次提交仍读旧姿态"))
	await _step()
	_check(body.get_movement_position().is_equal_approx(Vector2(2,0)), "同一物理步最后目标成为实际姿态")
	_check(body.global_position.is_equal_approx(Vector2(2,0)), "真正Node位置更新而非测试记录")
	var order = body.execution.move_to(Vector2(2.15,0))
	await _step(func():
		body.advance_movement(0.02)
		_check(body.get_movement_position().is_equal_approx(Vector2(2,0)), "执行器到点复查仍读提交前姿态")
		_check(order.state == Execution.Completion.PENDING, "物理尚未回写时不得提前完成"))
	await _step(func():
		_check(body.get_movement_position().is_equal_approx(Vector2(2.08,0)), "物理步实际应用执行器速度乘步长")
		body.advance_movement(0.02))
	_check(order.state == Execution.Completion.SUCCEEDED, "下一物理步观察到点后才完成")
	var old = body.execution.move_to(Vector2(5,0))
	var replacement = body.execution.move_to(Vector2(2.5,0))
	_check(old.state == Execution.Completion.CANCELED, "替换尚未执行的路径取消旧任务")
	await _step(func(): body.advance_movement(0.02))
	await _step(func():
		_check(body.get_movement_position().is_equal_approx(Vector2(2.16,0)), "新路径驱动实际身体")
		body.execution.reset_movement()
		body.advance_movement(0.02))
	_check(replacement.state == Execution.Completion.FAILED, "明确停止以失败结束当前路线")
	await _step()
	_check(body.get_movement_position().is_equal_approx(Vector2(2.16,0)), "在已完成物理步后停止不会继续前行")
	var locked = body.execution.move_to(Vector2(3,0))
	owner.allowed = false
	await _step(func(): body.advance_movement(0.02))
	await _step()
	_check(locked.state == Execution.Completion.PENDING and body.get_movement_position().is_equal_approx(Vector2(2.16,0)), "移动门禁保留路线但不移动")
	body.execution.reset_movement()
	owner.allowed = true
	await _step(func(): body.request_move_position(Vector2(2.16,1)))
	await _step()
	_check(body.get_movement_position().is_equal_approx(Vector2(2.16,1)) and body.global_position.is_equal_approx(Vector2(2.16,-1)), "真实身体坐标显式反转Y")
	var slide = slide_body.execution.move_to(Vector2(1,11))
	await _step(func(): slide_body.advance_movement(0.02))
	await _step()
	_check(slide_body.get_movement_position().is_equal_approx(Vector2(0.08/sqrt(2),10)), "真实身体只应用通过地形查询的轴向请求")
	_check(slide_owner.collisions.has(corner), "整向阻挡仍交给角色碰撞通知")
	_check(slide.state == Execution.Completion.PENDING, "轴向试走成功保持原路线")
	_check(owner.facing.size() > 0 and owner.animations.size() > 0, "姿态与动画请求交回原角色owner")

	var controller = CharacterMovement.new(body, 0.05)
	var before: Vector2 = body.get_movement_position()
	_check(controller.handle_directional_move(Vector2.RIGHT), "真实角色命令入口接入原生身体")
	await _step(func(): body.advance_movement(0.02))
	await _step()
	_check(body.get_movement_position().is_equal_approx(before + Vector2(0.016,0)), "角色方向命令经滤波与执行后真正移动")
	_check(controller.stop_movement(), "真实角色停令接入原生身体")
	var stopped: Vector2 = body.get_movement_position()
	await _step(func(): body.advance_movement(0.02))
	await _step()
	_check(body.get_movement_position().is_equal_approx(stopped), "停令清除平滑输入且后续物理步不滑行")

	_check(controller.set_movement_control_mode(CharacterMovement.Mode.CLICK_TO_MOVE), "同一身体切换点击控制")
	_check(controller.handle_click_move(stopped + Vector2(0.15,0), Route.new()), "地图路由经真实角色命令创建订单")
	await _step(func(): body.advance_movement(0.02))
	await _step(func(): body.advance_movement(0.02))
	_check(not body.execution.has_move_order() and body.get_movement_position().is_equal_approx(stopped + Vector2(0.08,0)), "地图点击链经过真实物理位移后完成")
	var trapped_owner := MotionOwner.new()
	var trapped_base := Vector2(20,20)
	var idle = _body(trapped_base, trapped_owner, 5.0)
	var routed = _body(trapped_base+Vector2(10,0), trapped_owner, 5.0)
	var pushed = _body(trapped_base+Vector2(20,0), trapped_owner, 5.0)
	var blocked_body = _body(trapped_base+Vector2(40,0), trapped_owner, 5.0)
	for x in [0,10,20]:
		_wall(trapped_base+Vector2(x,.42),Vector2(.1,.1))
	_wall(trapped_base+Vector2(40,.42),Vector2(13,13))
	await _step()
	await _step()
	var up := Vector2(0,.625)
	var near = routed.move_to(trapped_base+Vector2(10,0)+up)
	pushed.push_motion(Vector2.RIGHT,5.0,10.0)
	await _step(func():
		idle.advance_movement(.02)
		routed.advance_movement(.02)
		pushed.advance_movement(.02)
		blocked_body.advance_movement(.02)
		_check(idle.get_movement_position()==trapped_base,"脱墙调用结束后观察位置仍须等物理回写")
		_check(near.state==Execution.Completion.SUCCEEDED,"同一步路线先读脱墙后的原点"))
	await _step()
	_check(idle.get_movement_position().is_equal_approx(trapped_base+up),"静止时按 16 圈、原 +Y 优先规则脱墙")
	_check(routed.get_movement_position().is_equal_approx(trapped_base+Vector2(10,0)+up),"到达脱墙点的命令不取消已提交的位置")
	_check(pushed.get_movement_position().is_equal_approx(trapped_base+Vector2(20.1,.625)),"推力使用同一步脱墙原点，不重新贴回墙体")
	_check(blocked_body.get_movement_position()==trapped_base+Vector2(40,0),"搜索半径内无空位时不移动")
	_check(trapped_owner.collisions.is_empty(),"静态脱墙探测不伪造玩法碰撞事件")
	var fallback_owner:=MotionOwner.new()
	var fallback_actor=_body(Vector2(75,20),fallback_owner,5.0)
	var no_map=CharacterMovement.new(fallback_actor,.05)
	no_map.set_movement_control_mode(CharacterMovement.Mode.CLICK_TO_MOVE)
	var open_point:=Vector2(75.15,20)
	await _step()
	await _step(func():
		_check(no_map.handle_click_move(open_point,null)
			and fallback_actor.execution._route==PackedVector2Array([open_point]),
			"没有导航图时保留原空地点，走真实身体的直线移动命令")
		fallback_actor.advance_movement(.02))
	await _step(func():
		fallback_actor.advance_movement(.02))
	_check(fallback_actor.get_movement_position().is_equal_approx(Vector2(75.08,20))
		and not fallback_actor.execution.has_move_order(),"无导航图的有效点击真实驱动身体")
	await _step(func():
		_check(no_map.handle_click_move(trapped_base,null)
			and fallback_actor.execution._route==PackedVector2Array([trapped_base+up]),
			"只在没有导航图时，点击阻挡点按原圈和方向顺序修正")
		var solid:=trapped_base+Vector2(40,0)
		_check(no_map.handle_click_move(solid,null)
			and fallback_actor.execution._route==PackedVector2Array([solid]),
			"半径内无空位时保留原点击，而不是跳到另一条路线")
		_check(not no_map.handle_click_move(trapped_base,RejectedRoute.new())
			and not fallback_actor.execution.has_move_order(),"有导航图但路径失败时停止，不回退到直线")
		_check(fallback_actor.get_movement_position().is_equal_approx(Vector2(75.08,20))
			and fallback_owner.collisions.is_empty(),"落点探测不瞬移、不发送玩法碰撞"))
	print("PASS 原生角色姿态与固定步位移：%d 项，失败 %d" % [checks,failures])
	quit(int(failures > 0))
