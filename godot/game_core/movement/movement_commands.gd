extends RefCounted
## 已解析的玩法输入与单角色移动执行，不负责原始设备状态或玩家目标选择。

enum Kind { MOVE = 2, STOP_MOVE, CLICK_MOVE, TOGGLE_MOVEMENT_CONTROL_MODE }
enum Failure {
	NONE,
	INVALID_COMMAND,
	MISSING_INPUT_TARGET,
	INVALID_CONTROLLED_CHARACTER,
	INVALID_TARGET,
	ACTOR_MISMATCH,
	NOT_RUNNING,
	CONTROL_LOCKED,
	BLOCKED_BY_STATE = 9,
}

# 下列四个入口只负责从已解析的输入动作发命令。null 表示未发命令。
static func on_move_performed(direction: Vector2, blocked: bool, submit: Callable) -> Variant:
	if blocked:
		return null
	return submit.call(Kind.MOVE, direction, null)


static func on_move_canceled(submit: Callable) -> Variant:
	return submit.call(Kind.STOP_MOVE, Vector2.ZERO, null)


static func on_click_performed(screen_point: Vector2, blocked: bool, camera: Object,
		controlled_character: Object, is_over_ui: Callable, screen_to_world: Callable,
		submit: Callable) -> Variant:
	if blocked or not is_instance_valid(camera) or not is_instance_valid(controlled_character):
		return null
	if is_over_ui.call(screen_point):
		return null
	var world_point: Vector2 = screen_to_world.call(camera, controlled_character, screen_point)
	return submit.call(Kind.CLICK_MOVE, Vector2.ZERO, world_point)


static func on_toggle_performed(submit: Callable) -> Variant:
	return submit.call(Kind.TOGGLE_MOVEMENT_CONTROL_MODE, Vector2.ZERO, null)


# 接收已选中的输入目标。当前只覆盖原版单角色的提交与执行门禁，
# 不承担 PlayerSystem 的队伍选择、生命周期、事件广播和存档。
static func submit_single_character(kind: int, direction: Vector2, world_point: Variant,
		input_target: Object, accepts_input: bool, character: Object, can_player_control: bool,
		executor_enabled: bool, requested_actor: Object, movement: Object,
		terrain_map: Object) -> Failure:
	if not is_instance_valid(input_target):
		return Failure.MISSING_INPUT_TARGET
	if not accepts_input or not is_instance_valid(character) or not can_player_control:
		return Failure.CONTROL_LOCKED
	return execute(kind, direction, world_point, character, executor_enabled, requested_actor,
		movement, terrain_map)


static func execute(kind: int, direction: Vector2, world_point: Variant, character: Object,
		executor_enabled: bool, requested_actor: Object, movement: Object, terrain_map: Object) -> Failure:
	if not is_instance_valid(character):
		return Failure.INVALID_CONTROLLED_CHARACTER
	if not executor_enabled:
		return Failure.NOT_RUNNING
	if is_instance_valid(requested_actor) and requested_actor != character:
		return Failure.ACTOR_MISMATCH

	var ok := false
	match kind:
		Kind.MOVE:
			ok = is_instance_valid(movement) and movement.handle_directional_move(direction)
		Kind.STOP_MOVE:
			ok = is_instance_valid(movement) and movement.stop_movement()
		Kind.CLICK_MOVE:
			if world_point == null:
				return Failure.INVALID_TARGET
			ok = is_instance_valid(movement) and movement.handle_click_move(world_point, terrain_map)
		Kind.TOGGLE_MOVEMENT_CONTROL_MODE:
			ok = is_instance_valid(movement) and movement.toggle_movement_control_mode()
		_:
			return Failure.INVALID_COMMAND
	return Failure.NONE if ok else Failure.BLOCKED_BY_STATE
