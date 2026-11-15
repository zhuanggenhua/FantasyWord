extends SceneTree

const Execution = preload("res://game_core/movement/motion_execution.gd")
const Filter = preload("res://game_core/movement/motion_filter.gd")
const C = Execution.Completion
const CharacterMovement = preload("res://game_core/movement/character_movement.gd")
var checks := 0
var failures := 0

# 此宿主只记录物理请求，不伪装成 Godot 或 Unity 碰撞验收。
class Host extends RefCounted:
	var position := Vector2.ZERO
	var requested: Array[Vector2] = []
	var probes: Array = []
	var replies: Array = []
	var animations: Array[Vector2] = []
	var facings: Array[Vector2] = []
	var contacts: Array = []
	var allowed := true
	var speed := 4.0
	var multiplier := 1.0
	var clears := 0
	var immediate := false

	func get_movement_position() -> Vector2:
		return position

	func request_move_position(next: Vector2) -> void:
		requested.append(next)
		if immediate:
			position = next

	func cast_motion_hits(direction: Vector2, distance: float) -> Array:
		probes.append([direction, distance])
		return replies.pop_front() if not replies.is_empty() else []

	func can_move() -> bool:
		return allowed

	func calculate_move_speed() -> float:
		return speed

	func calculate_speed_multiplier() -> float:
		return multiplier

	func clear_velocity() -> void:
		clears += 1

	func update_movement_animation(velocity: Vector2) -> void:
		animations.append(velocity)

	func update_facing_from_intent(direction: Vector2) -> void:
		facings.append(direction)

	func register_collision(hit: Variant) -> void:
		contacts.append(hit)


# 仅测试中把已有角色命令接到本轮执行器，未宣称正式角色已接入。
class Actor extends Host:
	var execution: RefCounted
	var task: RefCounted

	func set_movement_direction(direction: Vector2) -> void:
		execution.set_movement_direction(direction)

	func reset_movement() -> void:
		execution.reset_movement()

	func move_along_path(route: PackedVector2Array, stopping: float) -> void:
		task = execution.move_along_path(route, stopping)

class Navigation extends RefCounted:
	var route := PackedVector2Array([Vector2(1, 0), Vector2(1, 1)])

	func try_build_world_path(_start: Vector2, _end: Vector2) -> Variant:
		return route


func _initialize() -> void:
	_orders()
	_fallbacks()
	_gates_and_steering()
	_input_chain()
	_character_chain()
	if failures == 0:
		print("PASS 移动命令执行与位移请求：%d 项" % checks)
	quit(1 if failures else 0)


func _new(h: Host):
	return Execution.new(h, Filter.new(Filter.Mode.FREE, false, 0.05, 0, 0))


func _orders() -> void:
	var h := Host.new()
	var e = _new(h)
	var first = e.move_to(Vector2(2, 0))
	var empty = e.move_along_path(PackedVector2Array(), 0.05)
	_check(empty.state == C.FAILED and first.state == C.PENDING and e.has_move_order(), "空路由失败但保留旧命令")
	var second = e.move_to(Vector2(3, 0))
	_check(first.state == C.CANCELED and second.state == C.PENDING, "替换取消不等于失败")
	e.set_movement_direction(Vector2.ZERO)
	_check(second.state == C.PENDING, "零方向不取消导航")
	e.set_movement_direction(Vector2(1e-7, 0))
	_check(second.state == C.PENDING, "Unity 近零方向不取消导航")
	e.set_movement_direction(Vector2.RIGHT)
	_check(second.state == C.FAILED and not e.has_move_order(), "有效直控结束导航为失败结果")
	var third = e.move_to(Vector2(3, 0))
	e.reset_movement()
	_check(third.state == C.FAILED and h.clears == 1 and h.animations.back() == Vector2.ZERO, "重置失败结果和速度动画清零")
	var close = e.move_to(Vector2(0.09, 0), -5)
	e.handle_movement(0.02)
	_check(close.state == C.SUCCEEDED and h.requested.is_empty() and h.probes.is_empty(), "负请求容差仍按执行下限到点")
	var route := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2(1, 0)])
	var path = e.move_along_path(route, 0.05)
	route[2] = Vector2(99, 99)
	e.handle_movement(0.02)
	_check(path.state == C.PENDING and h.probes.is_empty(), "首个已到路点每步只推进一项")
	e.handle_movement(0.02)
	_check(path.state == C.PENDING and h.probes.is_empty(), "重合第二路点不在同一步跳过")
	e.handle_movement(0.02)
	_check(h.requested.back().is_equal_approx(Vector2(0.08, 0)), "路由复制后外部修改不改变目标")
	_check(path.state == C.PENDING and h.position == Vector2.ZERO, "位置请求不等于物理位置已提交")
	h.position = Vector2(1, 0)
	e.handle_movement(0.02)
	_check(path.state == C.SUCCEEDED, "宿主观察到最终位置后成功")

	h = Host.new()
	e = _new(h)
	var deferred = e.move_to(Vector2(0.15, 0))
	e.handle_movement(0.02)
	_check(deferred.state == C.PENDING and h.requested.back().is_equal_approx(Vector2(0.08, 0)), "请求进入容差但延迟宿主不提前成功")
	h.position = h.requested.back()
	e.handle_movement(0.02)
	_check(deferred.state == C.SUCCEEDED and h.requested.size() == 1, "下一步读取提交位置成功且不再移动")
	h = Host.new()
	h.immediate = true
	e = _new(h)
	var observed = e.move_to(Vector2(0.15, 0))
	e.handle_movement(0.02)
	_check(observed.state == C.SUCCEEDED, "移动后重新读取宿主位置并判到点")
	h = Host.new()
	e = _new(h)
	e.move_to(Vector2(2, 0), 0.1, 2.0)
	e.handle_movement(0.02)
	_check(h.requested.back().is_equal_approx(Vector2(0.04, 0)), "订单速度覆盖宿主速度")


func _fallbacks() -> void:
	var h := Host.new()
	var e = _new(h)
	h.replies = [["wall"], []]
	var task = e.move_to(Vector2(1, 1))
	e.handle_movement(0.02)
	var component := sqrt(0.5)
	_check(h.probes.size() == 2 and h.probes[0][0].is_equal_approx(Vector2(component, component)), "完整方向先尝试")
	_check(h.probes[1][0].is_equal_approx(Vector2(component, 0)), "横轴回退不归一化")
	_check(is_equal_approx(h.probes[0][1], 0.10) and is_equal_approx(h.probes[1][1], 0.10), "回退探测距离仍完整速度乘时间加偏移")
	_check(h.requested.back().is_equal_approx(Vector2(component * 0.08, 0)), "轴回退保持真实分量位移")
	_check(task.state == C.PENDING and h.contacts == ["wall"], "轴回退成功保留命令并发送失败探测碰撞")
	_check(e.get_last_successful_movement().is_equal_approx(Vector2(component * 4, 0)), "成功移动记录速度而非位移")

	h = Host.new()
	e = _new(h)
	h.replies = [["a", "a"], ["a", "b"], []]
	e.move_to(Vector2(-1, 1))
	e.handle_movement(0.02)
	_check(h.probes.size() == 3 and h.probes[2][0].is_equal_approx(Vector2(0, component)), "横轴失败才试纵轴")
	_check(h.requested.back().is_equal_approx(Vector2(0, component * 0.08)), "纵轴保持速度分量")
	_check(h.contacts.size() == 2 and h.contacts.has("a") and h.contacts.has("b"), "同一步碰撞对象去重")
	h = Host.new()
	e = _new(h)
	h.replies = [["a"], ["b"], ["c"]]
	var blocked = e.move_to(Vector2(1, 1))
	e.handle_movement(0.02)
	_check(blocked.state == C.FAILED and not e.has_move_order() and h.requested.is_empty(), "全部方向失败才结束命令")
	_check(h.contacts.size() == 3 and h.animations.back() == Vector2.ZERO, "失败仍发送所有碰撞并停止动画")
	h = Host.new()
	e = _new(h)
	h.replies = [["wall"], ["wall"]]
	e.move_to(Vector2.RIGHT)
	e.handle_movement(0.02)
	_check(h.probes.size() == 2, "零纵轴不调用碰撞探测")


func _gates_and_steering() -> void:
	var h := Host.new()
	var e = _new(h)
	h.allowed = false
	var task = e.move_to(Vector2(1, 0))
	e.handle_movement(0.02)
	_check(task.state == C.PENDING and h.probes.is_empty() and h.facings.is_empty(), "移动锁保持命令且不变朝向")
	h.allowed = true
	h.speed = 0
	e.handle_movement(0.02)
	_check(task.state == C.PENDING and h.probes.is_empty(), "零基础速度保持命令")
	h.speed = 4
	h.multiplier = 0
	e.handle_movement(0.02)
	_check(task.state == C.PENDING and h.probes.is_empty(), "零倍率解析为零速度且保持命令")
	h.multiplier = 0.5
	e.set_steering_motion(0.5, Vector2(0, 0.04))
	e.handle_movement(0.02)
	_check(h.requested.back().is_equal_approx(Vector2(0.02, 0.04)), "速度倍率和 steering 位移合成")
	_check(is_equal_approx(h.probes.back()[1], sqrt(5.0) * 0.02 + 0.02), "合成速度决定探测长度")
	e.handle_movement(0.02)
	_check(h.requested.back().is_equal_approx(Vector2(0.04, 0)), "steering 每步消费后复原")
	h = Host.new()
	e = _new(h)
	e.set_movement_direction(Vector2.ZERO)
	e.set_steering_motion(0, Vector2(0.05, 0))
	e.handle_movement(0.02)
	_check(h.requested.back().is_equal_approx(Vector2(0.05, 0)), "零输入仍可应用修正位移")
	e.handle_movement(0.02)
	_check(e.get_last_successful_movement() == Vector2.ZERO and h.requested.size() == 1, "下一步清除上一成功移动")
	e.set_steering_motion(5, Vector2.ZERO)
	e.set_movement_direction(Vector2.RIGHT, false)
	e.handle_movement(0.02)
	_check(h.requested.back().is_equal_approx(Vector2(0.08, 0)), "steering 倍率夹到一")
	e.set_steering_motion(-1, Vector2.ZERO)
	e.handle_movement(0.02)
	_check(h.requested.size() == 2, "steering 负倍率夹到零")


func _input_chain() -> void:
	var h := Host.new()
	var e = Execution.new(h, Filter.new(Filter.Mode.FREE, false, 0.05, 10, 10))
	e.set_movement_direction(Vector2.RIGHT, false)
	e.handle_movement(0.02)
	_check(h.requested.back().is_equal_approx(Vector2(0.016, 0)), "真实过滤器首步加速接入位移请求")
	_check(h.facings.is_empty(), "明确关闭意图朝向时不转向")
	h.allowed = false
	e.handle_movement(0.02)
	h.allowed = true
	e.handle_movement(0.02)
	_check(h.requested.back().is_equal_approx(Vector2(0.488 * 0.08, 0)), "移动锁期间继续推进过滤器")
	e.reset_movement()
	e.handle_movement(0.02)
	_check(h.requested.size() == 2 and h.animations.back() == Vector2.ZERO, "重置清除方向及过滤器状态")
	e.set_movement_direction(Vector2.RIGHT, false)
	e.handle_movement(0.02, func(_v): return Vector2.DOWN)
	_check(h.requested.back().is_equal_approx(Vector2(0, 0.016)), "坡道回调穿过已有过滤器进入位移请求")


func _character_chain() -> void:
	var actor := Actor.new()
	actor.execution = _new(actor)
	var controller = CharacterMovement.new(actor, 0.05)
	var nav := Navigation.new()
	_check(controller.set_movement_control_mode(CharacterMovement.Mode.CLICK_TO_MOVE), "角色命令切到点击模式")
	_check(controller.handle_click_move(Vector2(1, 1), nav) and actor.execution.has_move_order(), "角色点击命令沿地图路由创建执行订单")
	actor.execution.handle_movement(0.02)
	_check(actor.requested.back().is_equal_approx(Vector2(0.08, 0)), "角色链执行首段不切角直奔终点")
	actor.position = Vector2(1, 0)
	actor.execution.handle_movement(0.02)
	actor.execution.handle_movement(0.02)
	_check(actor.requested.back().is_equal_approx(Vector2(1, 0.08)), "角色链通过首路点后执行第二段")
	actor.position = Vector2(1, 1)
	actor.execution.handle_movement(0.02)
	_check(actor.task.state == C.SUCCEEDED, "角色链最后路点观察到点才成功")
	controller.handle_click_move(Vector2(1, 1), nav)
	controller.stop_movement()
	_check(actor.task.state == C.FAILED and not actor.execution.has_move_order(), "角色停令执行到清除订单")
	# 测试宿主与执行器互相引用；测试退出前显式断开。
	actor.execution = null


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL ", label)
