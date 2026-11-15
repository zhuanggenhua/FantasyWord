extends SceneTree
const Binding = preload("res://game_core/presentation/player_camera_binding.gd")
var checks := 0
var failures := 0

class CameraBackend extends RefCounted:
	var follow: Node2D
	var priority := -1
	var previous_state_is_valid := true

class ConfinerBackend extends RefCounted:
	var bounding_shape: Object
	var invalidations := 0
	func invalidate_bounding_shape_cache() -> void:
		invalidations += 1

class Character extends Node2D:
	signal teleported

class Player extends RefCounted:
	signal controlled_character_changed(character)
	var current: Node2D
	var default_player: Node2D
	func get_current_controlled_character_or_player_instance() -> Node2D:
		return current if is_instance_valid(current) else default_player
	func change(character: Node2D) -> void:
		current = character
		controlled_character_changed.emit(character)

class MapInfo extends RefCounted:
	var target: Node2D
	var bounds: Object
	var use_bounds := false
	func get_camera_target() -> Node2D:
		return target
	func get_level_bounds() -> Object:
		return bounds if use_bounds else null

class MapEvents extends RefCounted:
	signal map_loaded(event)
	signal map_unloaded(event)

var player: Player
var map_info: MapInfo
func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL ", label)

func _run() -> void:
	var a := Character.new()
	var b := Character.new()
	var target := Node2D.new()
	var bounds := Node2D.new()
	root.add_child(a)
	root.add_child(b)
	root.add_child(target)
	root.add_child(bounds)
	player = Player.new()
	player.default_player = a
	map_info = MapInfo.new()
	var events := MapEvents.new()
	var camera := CameraBackend.new()
	var confiner := ConfinerBackend.new()
	var rig = Binding.new(camera, confiner, func(): return player, func(): return map_info, events)
	rig.on_enable()
	check(camera.follow == a, "默认玩家跟随")
	check(camera.priority == 10, "默认优先级")
	check(not camera.previous_state_is_valid, "首个身份使旧状态失效")
	check(a.teleported.get_connections().size() == 1, "订阅角色瞬移")
	camera.previous_state_is_valid = true
	rig.start_binding()
	check(camera.previous_state_is_valid, "Start 同身份不使状态失效")
	check(a.teleported.get_connections().size() == 1, "Start 不重复订阅瞬移")
	check(player.controlled_character_changed.get_connections().size() == 1, "Start 去重玩家事件")
	check(confiner.invalidations == 0, "初始空边界不清缓存")
	rig.live_priority = 17
	rig.refresh_camera_binding()
	check(camera.priority == 17, "身份未变仍刷新优先级")
	map_info.target = target
	events.map_loaded.emit(null)
	check(camera.follow == target, "地图目标优先")
	camera.previous_state_is_valid = true
	a.teleported.emit()
	check(not camera.previous_state_is_valid, "地图覆盖期间角色瞬移仍失效")
	camera.previous_state_is_valid = true
	player.change(b)
	check(camera.follow == target and camera.previous_state_is_valid, "地图覆盖下换角色不换镜头身份")
	check(a.teleported.get_connections().is_empty(), "旧角色解除瞬移订阅")
	check(b.teleported.get_connections().size() == 1, "新角色接收瞬移订阅")
	a.teleported.emit()
	check(camera.previous_state_is_valid, "旧角色瞬移不影响镜头")
	b.teleported.emit()
	check(not camera.previous_state_is_valid, "新角色瞬移使镜头失效")
	rig.allow_map_camera_target_override = false
	rig.refresh_camera_binding()
	check(camera.follow == b, "禁用地图覆盖后跟随绑定角色")
	map_info.bounds = bounds
	rig.refresh_camera_binding()
	check(confiner.bounding_shape == null, "未启用边界不能绑定")
	map_info.use_bounds = true
	events.map_loaded.emit(null)
	check(confiner.bounding_shape == bounds and confiner.invalidations == 1, "新边界身份绑定清缓存")
	events.map_loaded.emit(null)
	check(confiner.invalidations == 1, "同边界身份不重复清缓存")
	map_info = null
	events.map_unloaded.emit(null)
	check(confiner.bounding_shape == null and confiner.invalidations == 2, "地图卸载清边界")
	player.change(null)
	check(camera.follow == a, "空控制角色采用默认玩家回退")
	check(a.teleported.get_connections().is_empty(), "目标回退不偷偷绑定瞬移")
	camera.previous_state_is_valid = true
	rig.on_disable()
	check(camera.follow == null, "禁用清跟随")
	check(camera.previous_state_is_valid, "禁用不额外失效相机状态")
	check(confiner.invalidations == 3, "禁用即使空边界也清缓存")
	check(player.controlled_character_changed.get_connections().is_empty(), "禁用解除玩家事件")
	check(events.map_loaded.get_connections().is_empty() and events.map_unloaded.get_connections().is_empty(), "禁用解除地图事件")
	# Enable 时系统尚不存在，Start 重试；地图事件只刷新、不尝试补绑定。
	player = null
	rig.on_enable()
	check(camera.follow == null, "无系统无地图跟随为空")
	player = Player.new()
	player.current = b
	events.map_loaded.emit(null)
	check(camera.follow == b, "地图刷新解析回退玩家")
	check(b.teleported.get_connections().is_empty(), "地图刷新不冒充系统绑定")
	rig.start_binding()
	check(b.teleported.get_connections().size() == 1, "Start 成功补绑定")
	camera.previous_state_is_valid = true
	b.teleported.emit()
	check(not camera.previous_state_is_valid, "补绑定瞬移正常")
	rig.on_disable()
	check(b.teleported.get_connections().is_empty(), "禁用解除当前角色瞬移")
	var optional = Binding.new(camera, null, func(): return player, func(): return map_info, events)
	optional.on_enable()
	check(camera.follow == b, "允许无边界后端")
	optional.on_disable()
	a.free()
	b.free()
	target.free()
	bounds.free()
	if failures == 0:
		print("PASS player_camera_binding ", checks, " checks")
	quit(1 if failures else 0)
