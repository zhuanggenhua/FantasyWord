extends RefCounted
## 锁定 ClickMoveTest 的 TerrainSurfaceDamageSystem：只定时提交正式伤害效果。
## 地图、角色身份、根位置与效果宿主均显式注入；不直接改生命或构造角色。
const Combat = preload("res://game_core/combat/combat_rules.gd")
const INTERVAL := 0.5
const BURNING := 2
var accumulated_time := 0.0
var _registered: Dictionary = {}
var _map: WeakRef
var _map_provider: Callable
var _current_player: Callable
var _read_target: Callable
var _submit_damage: Callable
var _resolve_character: Callable
var _configured := false

## read_target 返回真实 CharacterBase 的 {dead:bool,position:Vector2}，缺失身份返回空。
## submit_damage 只建立正式瞬时效果请求；来源可以为空或与目标相同。
func configure(map_provider: Callable, current_player: Callable, read_target: Callable,
		submit_damage: Callable, resolve_character: Callable) -> bool:
	if _configured: return false
	for callback in [map_provider,current_player,read_target,submit_damage,resolve_character]:
		if not callback.is_valid(): return false
	_map_provider=map_provider
	_current_player=current_player
	_read_target=read_target
	_submit_damage=submit_damage
	_resolve_character=resolve_character
	_configured=true
	_bind_active_map()
	return true

func _bind_active_map() -> Object:
	var live: Object = _map.get_ref() if _map!=null else null
	if is_instance_valid(live): return live
	if not _configured: return null
	live=_map_provider.call()
	if not is_instance_valid(live) or not live.has_method("sample"): return null
	_map=weakref(live)
	return live

func on_map_loaded() -> void:
	_bind_active_map()

## 原卸载只清本帧目标与地图，不抹除仍存活角色的注册集合。
func on_map_unloading() -> void:
	_map=null
	accumulated_time=0.0

func stop() -> void:
	on_map_unloading()
	_registered.clear()

func register_target(target: Object) -> void:
	if is_instance_valid(target): _registered[target.get_instance_id()]=weakref(target)

func unregister_target(target: Object) -> void:
	if is_instance_valid(target): _registered.erase(target.get_instance_id())

## delta 已经是 scaled deltaTime；time_scale 只做原暂停门禁，不能再乘一次。
func advance(delta: float, time_scale: float = 1.0) -> int:
	if not _configured or time_scale<=0 or not is_finite(delta) or delta<0 or _bind_active_map()==null:
		return 0
	accumulated_time=_f32(accumulated_time+_f32(delta))
	var submitted := 0
	while accumulated_time>=INTERVAL:
		accumulated_time=_f32(accumulated_time-INTERVAL)
		submitted+=_apply_contacts()
	return submitted

func _apply_contacts() -> int:
	var targets: Array[Object] = []
	for id in _registered.keys():
		var target: Object = _registered[id].get_ref()
		if not is_instance_valid(target):
			_registered.erase(id)
			continue
		targets.append(target)
	var player: Object = _current_player.call()
	if is_instance_valid(player) and not targets.has(player): targets.append(player)
	var count := 0
	for target in targets:
		if try_apply_contact(target): count+=1
	return count

func try_apply_contact(target: Object) -> bool:
	if not _configured or not is_instance_valid(target): return false
	var map: Object = _map.get_ref() if _map!=null else null
	if not is_instance_valid(map): return false
	var target_data: Variant = _read_target.call(target)
	if not target_data is Dictionary or not target_data.get("dead") is bool \
			or not target_data.get("position") is Vector2 or target_data.dead:
		return false
	var at: Vector2=target_data.position
	if not at.is_finite(): return false
	# 当前已迁移地图是原默认层正交单位网格；输入是 Unity 根坐标。
	var sample: Dictionary = map.sample(Vector3i(floori(at.x),floori(at.y),0))
	if (int(sample.get("flags",0)) & BURNING)==0: return false
	var state: Dictionary=sample.get("states",{}).get(BURNING,{})
	var source_entity: Variant=state.get("source_entity")
	if source_entity is WeakRef: source_entity=source_entity.get_ref()
	var source: Object=null
	if is_instance_valid(source_entity): source=_resolve_character.call(source_entity)
	return bool(_submit_damage.call(source,target,payload()))

static func payload() -> Dictionary:
	return {"descriptor":{"damage_type":Combat.DamageType.MAGICAL,"flat_damage":1,"scale":0.0,
		"critical_behavior":Combat.Resolution.NEVER,"miss_behavior":Combat.Resolution.NEVER,
		"ignore_defense":true,"silent":false},"visual_flags":0,"impact_velocity":Vector2.ZERO}

static func _f32(value: float) -> float:
	return PackedFloat32Array([value])[0]
