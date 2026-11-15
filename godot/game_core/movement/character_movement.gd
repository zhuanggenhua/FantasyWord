extends RefCounted
## 角色侧移动命令；角色本体拥有速度和位置，地图拥有导航资料。

enum Mode { DIRECTIONAL, CLICK_TO_MOVE }

var mode: Mode:
	get:
		return _mode
var _mode: Mode = Mode.DIRECTIONAL
var _stopping_distance: float
var _character: Object


func _init(character: Object, stopping_distance: float) -> void:
	_character = character
	_stopping_distance = stopping_distance


func handle_directional_move(direction: Vector2) -> bool:
	if not is_instance_valid(_character) or mode != Mode.DIRECTIONAL:
		return false
	_character.set_movement_direction(direction)
	return true


func stop_movement() -> bool:
	if not is_instance_valid(_character):
		return false
	_character.reset_movement()
	return true


func handle_click_move(world_position: Vector2, terrain_map: Object) -> bool:
	if not is_instance_valid(_character) or mode != Mode.CLICK_TO_MOVE or not _character.can_move():
		return false
	if is_instance_valid(terrain_map):
		# null 表示导航查找失败；有图但不可达时，不退回直线。
		var world_path = terrain_map.try_build_world_path(_character.get_movement_position(), world_position)
		if world_path == null:
			_character.reset_movement()
			return false
		_character.set_movement_direction(Vector2.ZERO)
		_character.move_along_path(world_path, _stopping_distance)
		return true

	var destination: Vector2 = _character.nearest_valid_destination(world_position)
	_character.set_movement_direction(Vector2.ZERO)
	_character.move_to(destination, _stopping_distance)
	return true


func toggle_movement_control_mode() -> bool:
	return set_movement_control_mode(Mode.CLICK_TO_MOVE if mode == Mode.DIRECTIONAL else Mode.DIRECTIONAL)


func set_movement_control_mode(next_mode: Mode) -> bool:
	if not is_instance_valid(_character) or mode == next_mode:
		return false
	_mode = next_mode
	_character.reset_movement()
	return true
