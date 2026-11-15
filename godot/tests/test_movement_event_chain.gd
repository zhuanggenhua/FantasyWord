extends SceneTree

const Commands = preload("res://game_core/movement/movement_commands.gd")
const Movement = preload("res://game_core/movement/character_movement.gd")
const K = Commands.Kind
const F = Commands.Failure

class Character:
	extends RefCounted
	var trace: Array = []
	var can_move_value := true

	func can_move() -> bool:
		return can_move_value

	func get_movement_position() -> Vector2:
		return Vector2.ZERO

	func nearest_valid_destination(point: Vector2) -> Vector2:
		trace.append(["resolve", point])
		return point

	func set_movement_direction(direction: Vector2) -> void:
		trace.append(["intent", direction])

	func reset_movement() -> void:
		trace.append(["reset"])

	func move_to(point: Vector2, stop: float) -> void:
		trace.append(["move_to", point, stop])


var character := Character.new()
var target := RefCounted.new()
var camera := RefCounted.new()
var movement = Movement.new(character, 0.05)
var recorded: Array = []
var over_ui := false
var can_player_control := true
var checks := 0
var failures := 0


func _initialize() -> void:
	var p := Vector2(12, 34)
	_check(Commands.on_move_performed(Vector2.RIGHT, true, _submit) == null, "屏蔽方向事件不发命令")
	_check(recorded.is_empty() and character.trace.is_empty(), "方向屏蔽无副作用")
	_check(Commands.on_move_performed(Vector2.UP, false, _submit) == F.NONE, "方向事件执行")
	_check(recorded == [["command", K.MOVE]] and character.trace == [["intent", Vector2.UP]], "方向值不改写")
	recorded.clear()
	character.trace.clear()
	_check(Commands.on_move_canceled(_submit) == F.NONE, "释放事件提交成功")
	_check(recorded == [["command", K.STOP_MOVE]] and character.trace == [["reset"]], "释放发停止而不是零方向")

	recorded.clear()
	_check(_click(p, true, camera, character) == null, "屏蔽点击")
	_check(_click(p, false, null, character) == null, "缺相机拒绝点击")
	_check(_click(p, false, camera, null) == null, "缺受控角色拒绝点击")
	_check(recorded.is_empty(), "前置门禁不调用 UI 或投影")
	over_ui = true
	_check(_click(p, false, camera, character) == null and recorded == [["ui", p]], "点击 UI 不投影不发令")
	over_ui = false
	recorded.clear()
	character.trace.clear()

	_check(_click(p, false, camera, character) == F.BLOCKED_BY_STATE, "方向模式拒绝已投影点击")
	_check(recorded == [["ui", p], ["project", p], ["command", K.CLICK_MOVE]], "UI、投影、角色命令严格顺序")
	_check(character.trace.is_empty(), "方向模式拒绝不改角色")
	_check(Commands.on_toggle_performed(_submit) == F.NONE and movement.mode == Movement.Mode.CLICK_TO_MOVE, "切换使用同一命令链")
	character.trace.clear()
	_check(_click(p, false, camera, character) == F.NONE, "点击模式执行成功")
	_check(character.trace == [["resolve", p + Vector2(1, 2)], ["intent", Vector2.ZERO],
		["move_to", p + Vector2(1, 2), 0.05]], "合法落点和停止距离由移动模块消费")
	can_player_control = false
	_check(Commands.on_toggle_performed(_submit) == F.CONTROL_LOCKED, "输入切换仍须经过角色门禁")

	_check(Commands.submit_single_character(K.MOVE, p, null, null, true, character, true,
		true, character, movement, null) == F.MISSING_INPUT_TARGET, "无输入目标")
	_check(Commands.submit_single_character(K.MOVE, p, null, target, false, character, true,
		true, character, movement, null) == F.CONTROL_LOCKED, "输入关闭")
	_check(Commands.execute(K.CLICK_MOVE, Vector2.ZERO, null, null, false, target,
		null, null) == F.INVALID_CONTROLLED_CHARACTER, "角色缺失优先")
	_check(Commands.execute(K.CLICK_MOVE, Vector2.ZERO, null, character, false, target,
		null, null) == F.NOT_RUNNING, "停用优先于 actor 校验")
	_check(Commands.execute(K.CLICK_MOVE, Vector2.ZERO, null, character, true, target,
		null, null) == F.ACTOR_MISMATCH, "显式 actor 不符优先于目标校验")
	_check(Commands.execute(K.CLICK_MOVE, Vector2.ZERO, null, character, true, null,
		null, null) == F.INVALID_TARGET, "缺点击坐标优先于移动组件检查")
	_check(Commands.execute(K.CLICK_MOVE, Vector2.ZERO, p, character, true, null,
		null, null) == F.BLOCKED_BY_STATE, "有效坐标但缺移动组件")
	_check(Commands.execute(-1, Vector2.ZERO, null, character, true, null,
		movement, null) == F.INVALID_COMMAND, "未知命令")

	if failures == 0:
		print("PASS 移动事件到角色命令：%d 项" % checks)
	quit(1 if failures else 0)


func _click(p: Vector2, blocked: bool, view: Object, unit: Object) -> Variant:
	return Commands.on_click_performed(p, blocked, view, unit, _is_over_ui, _project, _submit)


func _is_over_ui(p: Vector2) -> bool:
	recorded.append(["ui", p])
	return over_ui


func _project(view: Object, unit: Object, p: Vector2) -> Vector2:
	_check(view == camera and unit == character, "投影使用选定相机和角色")
	recorded.append(["project", p])
	return p + Vector2(1, 2)


func _submit(kind: int, direction: Vector2, world_point: Variant) -> int:
	recorded.append(["command", kind])
	return Commands.submit_single_character(kind, direction, world_point, target, true,
		character, can_player_control, true, character, movement, null)


func _check(condition: bool, detail: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("移动事件断言失败：" + detail)
