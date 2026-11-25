extends RefCounted
## MapSystem's explicitly registered MapInfo subset at locked 31629d53.
## Scene lookup and additive transition belong to the real host; no inferred map loading.
const Info = preload("res://game_core/maps/registered_map_info.gd")
signal map_loaded
signal map_unloaded
var _named_root: Callable
var _active_root: Callable
var _reported_name := ""
var _records: Array[Info] = []
var _active_info: Info


func configure(named_root: Callable, active_root: Callable) -> bool:
	if _active_root.is_valid() or not named_root.is_valid() or not active_root.is_valid(): return false
	_named_root = named_root
	_active_root = active_root
	return true


func register(info: Info) -> void:
	if info == null or not is_instance_valid(info.get_scene_root()): return
	if not _records.has(info): _records.append(info)
	refresh()


func unregister(info: Info) -> void:
	if info == null: return
	_records.erase(info)
	if _active_info == info: _active_info = null
	refresh()


## Projection after actual host activation; this does not itself change Tree.current_scene.
## Direct startup without a named map leaves the original empty name intact.
func record_current_map_name(value: String) -> void:
	_reported_name = value
	refresh()


func on_system_start() -> void:
	refresh()


func notify_map_loaded() -> void:
	refresh()
	map_loaded.emit()


func notify_map_unloaded() -> void:
	_active_info = null
	map_unloaded.emit()


func refresh() -> void:
	if not _active_root.is_valid() or not _named_root.is_valid(): return
	var tracked: Variant = _named_root.call(_reported_name) if not _reported_name.is_empty() else null
	if not is_instance_valid(tracked): tracked = _active_root.call()
	_active_info = null
	# Unity's Scene can be valid yet unloaded. Such a named Scene doesn't fall
	# back to active; distinguish that from a missing name.
	if not is_instance_valid(tracked) or not tracked is Node or not tracked.is_inside_tree(): return
	for index in range(_records.size()-1,-1,-1):
		if not is_instance_valid(_records[index].get_scene_root()): _records.remove_at(index)
	for info in _records:
		if info.get_scene_root() == tracked:
			_active_info = info
			break


func resolve_active_map_info() -> Info:
	if _active_info == null or not is_instance_valid(_active_info.get_scene_root()): refresh()
	return _active_info


func get_active_terrain_navigation_map() -> RefCounted:
	var info := resolve_active_map_info()
	return info.get_terrain_navigation_map() if info != null else null


func get_respawn_delay() -> float:
	# Source accessor reads the cache, unlike ResolveActiveMapInfo used by terrain.
	return _active_info.get_respawn_delay() if _active_info != null else 0.0


## Source MapSystem.CreateDataBlock, limited to this checkpoint-free owner.
## Active MapInfo lookup can fall back to the current scene, but that fallback
## cannot certify a previously reported, unresolved name for save capture.
func capture_source_map_save_block(required_root: Node) -> Dictionary:
	if not is_instance_valid(required_root) or not required_root.is_inside_tree() \
			or not _named_root.is_valid() or not _active_root.is_valid():
		return {"ok":false,"reason":"map_owner_unavailable"}
	refresh()
	if _active_info==null or _active_info.get_scene_root()!=required_root:
		return {"ok":false,"reason":"map_owner_unavailable"}
	if not _reported_name.is_empty() and _named_root.call(_reported_name)!=required_root:
		return {"ok":false,"reason":"reported_map_unresolved"}
	# The registry currently represents only the source's empty checkpoint
	# stack and unset order, not a save after a teleport/checkpoint visit.
	return {"ok":true,"fields":{"currentMap":_reported_name,"checkpoints":[],
		"hasOrderedCheckpoint":false,"currentCheckpointOrder":-2147483648,"playtest":false}}


## 只预检当前迁移能采集的逻辑地图块，不执行原地图过场，不接受 Unity 线格式。
## 空地图名是原首次进入分支；当前 F5 的空检查点栈没有可供传送的出生点。
func preflight_source_map_load_block(block: Variant, required_root: Node) -> Dictionary:
	if not block is Dictionary:
		return {"ok":false,"reason":"invalid_map_block"}
	if block.size()!=5 or not block.get("currentMap") is String \
			or not block.get("checkpoints") is Array or not block.get("playtest") is bool \
			or not block.get("hasOrderedCheckpoint") is bool or not block.get("currentCheckpointOrder") is int:
		return {"ok":false,"reason":"invalid_map_block"}
	if block.playtest or not block.checkpoints.is_empty() or block.hasOrderedCheckpoint \
			or block.currentCheckpointOrder!=-2147483648:
		return {"ok":false,"reason":"unsupported_map_checkpoint_state"}
	if not is_instance_valid(required_root) or not required_root.is_inside_tree() \
			or not _named_root.is_valid() or not _active_root.is_valid() or _active_root.call()!=required_root:
		return {"ok":false,"reason":"map_owner_unavailable"}
	# 直接确认登记关系，不刷新活动缓存，也不发布 MapLoaded/MapUnloaded。
	if not _records.any(func(info: Info): return info.get_scene_root()==required_root):
		return {"ok":false,"reason":"map_owner_unavailable"}
	var name: String=block.currentMap
	if name.is_empty():
		return {"ok":false,"reason":"initial_checkpoint_required"}
	if _named_root.call(name)!=required_root:
		return {"ok":false,"reason":"named_map_unavailable"}
	# 原具名地图也走 RequestTransition，再检查命中的主角是否处于有效出生点。
	return {"ok":false,"reason":"named_map_transition_required"}
