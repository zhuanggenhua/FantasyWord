extends RefCounted
## MapInfo scene-owner projection. Scene root must be explicit; no group/tree scan.
var _scene: WeakRef
var _camera_target: WeakRef
var _bounds: WeakRef
var _terrain: RefCounted
var _respawn_delay := 0.0


func configure(scene: Node, terrain: RefCounted, camera_target: Node2D = null,
		use_bounds := false, bounds: Node2D = null, respawn_delay := 0.0) -> bool:
	if _scene != null or not is_instance_valid(scene) or not scene.is_inside_tree():
		return false
	_scene = weakref(scene)
	_terrain = terrain
	_camera_target = weakref(camera_target) if is_instance_valid(camera_target) else null
	_bounds = weakref(bounds) if use_bounds and is_instance_valid(bounds) else null
	_respawn_delay = respawn_delay
	return true


func get_scene_root() -> Node:
	return _scene.get_ref() if _scene != null else null


func get_camera_target() -> Node2D:
	return _camera_target.get_ref() if _camera_target != null else null


func get_level_bounds() -> Node2D:
	return _bounds.get_ref() if _bounds != null else null


func get_terrain_navigation_map() -> RefCounted:
	return _terrain


func get_respawn_delay() -> float:
	return _respawn_delay
