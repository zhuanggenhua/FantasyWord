extends RefCounted
## PlayerCameraRig 的绑定与生命周期合同；不是 Cinemachine 运动算法。
## 真相源：31629d5 / Assets/Scripts/GameCore/Runtime/Presentation/PlayerCameraRig.cs。
## 宿主须配对调用 on_enable/on_disable，并在首帧调用 start_binding。
## 后端负责 follow、priority、previous_state_is_valid；边界后端负责
## bounding_shape 与 invalidate_bounding_shape_cache。这里不模拟阻尼或约束计算。

var live_priority: int = 10
var allow_map_camera_target_override: bool = true
var _camera: Object
var _confiner: Object
var _player_provider: Callable
var _map_provider: Callable
var _map_events: Object
var _bound_character: Node2D
var _tracking_target: Node2D

func _init(camera: Object, confiner: Object, player_provider: Callable,
		map_provider: Callable, map_events: Object) -> void:
	assert(is_instance_valid(camera), "玩家相机绑定缺少相机后端。")
	_camera = camera
	_confiner = confiner
	_player_provider = player_provider
	_map_provider = map_provider
	_map_events = map_events

func on_enable() -> void:
	_map_events.map_loaded.connect(_on_map_changed)
	_map_events.map_unloaded.connect(_on_map_changed)
	_try_bind_player_system()
	refresh_camera_binding()

func start_binding() -> void:
	_try_bind_player_system()
	refresh_camera_binding()

func on_disable() -> void:
	_map_events.map_loaded.disconnect(_on_map_changed)
	_map_events.map_unloaded.disconnect(_on_map_changed)
	var player: Object = _player_provider.call()
	if is_instance_valid(player) and player.controlled_character_changed.is_connected(_on_character_changed):
		player.controlled_character_changed.disconnect(_on_character_changed)
	_bind_character(null)
	if is_instance_valid(_camera):
		_camera.follow = null
	if is_instance_valid(_confiner):
		_confiner.bounding_shape = null
		_confiner.invalidate_bounding_shape_cache()
	_tracking_target = null

func _try_bind_player_system() -> void:
	var player: Object = _player_provider.call()
	if not is_instance_valid(player):
		return
	if player.controlled_character_changed.is_connected(_on_character_changed):
		player.controlled_character_changed.disconnect(_on_character_changed)
	player.controlled_character_changed.connect(_on_character_changed)
	_bind_character(player.get_current_controlled_character_or_player_instance())

func _bind_character(character: Node2D) -> void:
	if _bound_character == character:
		return
	if is_instance_valid(_bound_character):
		_bound_character.teleported.disconnect(_on_character_teleported)
	_bound_character = character
	if is_instance_valid(_bound_character):
		_bound_character.teleported.connect(_on_character_teleported)

func _on_character_changed(character: Node2D) -> void:
	_bind_character(character)
	refresh_camera_binding()

func _on_character_teleported() -> void:
	if is_instance_valid(_camera):
		_camera.previous_state_is_valid = false

func _on_map_changed(_event = null) -> void:
	refresh_camera_binding()

func refresh_camera_binding() -> void:
	if not is_instance_valid(_camera):
		return
	var target: Node2D = _resolve_tracking_target()
	if _tracking_target != target:
		_tracking_target = target
		_camera.follow = target
		_camera.previous_state_is_valid = false
	_camera.priority = live_priority
	_refresh_confiner()

func _resolve_tracking_target() -> Node2D:
	var map_info: Object = _map_provider.call()
	if allow_map_camera_target_override and is_instance_valid(map_info):
		var target: Node2D = map_info.get_camera_target()
		if is_instance_valid(target):
			return target
	if is_instance_valid(_bound_character):
		return _bound_character
	var player: Object = _player_provider.call()
	if is_instance_valid(player):
		var fallback: Node2D = player.get_current_controlled_character_or_player_instance()
		return fallback if is_instance_valid(fallback) else null
	return null

func _refresh_confiner() -> void:
	if not is_instance_valid(_confiner):
		return
	var map_info: Object = _map_provider.call()
	# MapInfo 的 get_level_bounds 必须保留原 TryGetLevelBounds 的启用门禁。
	var bounds: Object = map_info.get_level_bounds() if is_instance_valid(map_info) else null
	if not is_instance_valid(bounds):
		bounds = null
	if _confiner.bounding_shape == bounds:
		return
	_confiner.bounding_shape = bounds
	_confiner.invalidate_bounding_shape_cache()
