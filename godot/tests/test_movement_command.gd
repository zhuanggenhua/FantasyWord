extends SceneTree

const Movement = preload("res://game_core/movement/character_movement.gd")

class Character:
	extends RefCounted
	var movement_allowed := true
	var trace: Array = []

	func can_move() -> bool:
		return movement_allowed

	func get_movement_position() -> Vector2:
		return Vector2(1, 2)

	func nearest_valid_destination(point: Vector2) -> Vector2:
		trace.append(["resolve", point])
		return point + Vector2(1, 0)

	func set_movement_direction(direction: Vector2) -> void:
		trace.append(["direction", direction])

	func reset_movement() -> void:
		trace.append(["reset"])

	func move_to(point: Vector2, distance: float) -> void:
		trace.append(["straight", point, distance])

	func move_along_path(route: PackedVector2Array, distance: float) -> void:
		trace.append(["path", route, distance])


class Terrain:
	extends RefCounted
	var route: Variant = PackedVector2Array([Vector2(2, 3), Vector2(8, 9)])
	var origin: Vector2
	var requested: Vector2

	func try_build_world_path(from: Vector2, to: Vector2) -> Variant:
		origin = from
		requested = to
		return route


var checks := 0
var failures := 0


func _initialize() -> void:
	var unit := Character.new()
	var terrain := Terrain.new()
	var target := Vector2(8, 9)
	var movement = Movement.new(unit, 0.05)
	_check(movement.mode == Movement.Mode.DIRECTIONAL, "角色预制体默认方向模式")
	_check(not movement.handle_click_move(target, terrain) and unit.trace.is_empty(), "方向模式拒绝点击")
	_check(movement.handle_directional_move(Vector2.RIGHT), "方向模式接收方向")
	_check(movement.handle_directional_move(Vector2.ZERO), "方向模式接收松键归零")
	_check(unit.trace == [["direction", Vector2.RIGHT], ["direction", Vector2.ZERO]], "方向命令次序")
	unit.trace.clear()

	_check(movement.toggle_movement_control_mode(), "切到点击模式")
	_check(unit.trace == [["reset"]], "切换清理旧移动")
	_check(not movement.set_movement_control_mode(Movement.Mode.CLICK_TO_MOVE), "设置相同模式无动作")
	_check(not movement.handle_directional_move(Vector2.RIGHT) and unit.trace == [["reset"]], "点击模式不写方向")
	unit.trace.clear()

	unit.movement_allowed = false
	_check(not movement.handle_click_move(target, terrain) and unit.trace.is_empty(), "移动动作锁拒绝点击")
	unit.movement_allowed = true
	terrain.route = null
	_check(not movement.handle_click_move(target, terrain), "有导航图且不可达，拒绝命令")
	_check(terrain.origin == Vector2(1, 2) and terrain.requested == target, "导航接收真实起点与目标")
	_check(unit.trace == [["reset"]], "有图不可达只清空旧意图")
	unit.trace.clear()

	terrain.route = PackedVector2Array([Vector2(2, 3), target])
	_check(movement.handle_click_move(target, terrain), "有路径时提交")
	_check(unit.trace == [["direction", Vector2.ZERO], ["path", terrain.route, 0.05]], "清空方向再提交路径、保留停止距离")
	unit.trace.clear()

	_check(movement.handle_click_move(target, null), "无导航图使用合法点和直线")
	_check(unit.trace == [["resolve", target], ["direction", Vector2.ZERO], ["straight", Vector2(9, 9), 0.05]], "直线回退顺序与坐标")
	unit.trace.clear()
	_check(movement.stop_movement() and movement.toggle_movement_control_mode(), "停止与切回方向")
	_check(unit.trace == [["reset"], ["reset"]] and movement.mode == Movement.Mode.DIRECTIONAL, "停止与切换分别清除")
	var absent = Movement.new(null, 0.05)
	_check(not absent.stop_movement() and not absent.toggle_movement_control_mode() and
		not absent.handle_directional_move(Vector2.RIGHT) and not absent.handle_click_move(target, null),
		"缺少角色时拒绝所有移动命令")
	if failures == 0:
		print("PASS 移动命令：%d 项" % checks)
	quit(1 if failures else 0)


func _check(condition: bool, detail: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("移动命令断言失败：" + detail)
