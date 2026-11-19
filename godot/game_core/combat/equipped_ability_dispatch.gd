extends RefCounted
## CharacterAbilitySet 的 Fire/Stop 槽位查询。每次读取当前槽，不缓存按下时的技能。
const Loadout = preload("res://game_core/combat/equipped_ability_loadout.gd")
var _loadout: RefCounted
var _resolve_active: Callable
var _fire_resolved: Callable
var _stop_resolved: Callable

## resolve_active 必须执行原运行时查找和 ActiveAbilityBase 类型判定；失败返回 null。
## fire_resolved 可由正式宿主提供，或使用下方已迁移的 resolved 调度。
func configure(loadout: RefCounted, resolve_active: Callable, fire_resolved: Callable, stop_resolved: Callable) -> bool:
	if not loadout is Loadout or not resolve_active.is_valid() or not fire_resolved.is_valid() or not stop_resolved.is_valid(): return false
	_loadout = loadout
	_resolve_active = resolve_active
	_fire_resolved = fire_resolved
	_stop_resolved = stop_resolved
	return true

func fire(index: int, command_context: Variant, activation_context: Variant) -> Dictionary:
	var code: int = _loadout.get_formal_gas_ability_code(index)
	var ability: Object = _resolve_active.call(code) if code > 0 else null
	if not is_instance_valid(ability):
		return {"has_ability_source":false,"result":4,"formal_gas_ability_code":0}
	return {"has_ability_source":true,"result":_fire_resolved.call(ability,command_context,activation_context),"formal_gas_ability_code":code}

func stop(index: int) -> bool:
	var code: int = _loadout.get_formal_gas_ability_code(index)
	var ability: Object = _resolve_active.call(code) if code > 0 else null
	if not is_instance_valid(ability): return false
	_stop_resolved.call(ability)
	return true


var _character: Object
var _ability_host: Object
var _use_source_start_rules := false

## 宿主仅提供实际能力操作；不缓存 CanFire、flags 或 GameObject 状态。
## 方向由现有角色唯一 owner 持有，SetTargetDirection 自行执行原 gate 和 TargetBased。
func configure_resolved_fire(loadout: RefCounted, resolve_active: Callable, character: Object, host: Object, use_source_start_rules: bool = false) -> bool:
	if not is_instance_valid(character) or not is_instance_valid(host): return false
	for method in ["set_target_direction","get_target_direction","set_look_at_direction"]:
		if not character.has_method(method): return false
	for method in ["should_update_look_at_direction_on_fire","uses_automatic_runtime_state_management","set_ability_active","fire","stop_fire"]:
		if not host.has_method(method): return false
	if use_source_start_rules:
		for method in ["get_input_gate","get_formal_gas_ability_code","evaluate_start_rule","get_ability_debug_name","report_start_rule_error"]:
			if not host.has_method(method): return false
	elif not host.has_method("can_fire"): return false
	if not configure(loadout,resolve_active,_fire_resolved_source,host.stop_fire): return false
	_use_source_start_rules = use_source_start_rules
	_character = character
	_ability_host = host
	return true

## CharacterAbilitySet.FireResolvedAbility：检查失败时无方向或生命周期副作用。
func _fire_resolved_source(ability: Object, command_context: Variant, activation_context: Variant) -> int:
	return fire_resolved(ability,_character,_ability_host,_use_source_start_rules,command_context,activation_context)

## 同一正式技能可由装备位或原 NPC 能力集合提交；都执行同一个 CanFire 口径。
static func can_fire_resolved(ability: Object, host: Object, use_source_start_rules: bool) -> int:
	if use_source_start_rules:
		var gate: Object = host.get_input_gate(ability)
		if gate != null and gate.is_busy():
			return 0
		else:
			return preload("res://game_core/combat/active_ability_start_rules.gd").evaluate(
				host.get_formal_gas_ability_code(ability),
				host.evaluate_start_rule.bind(ability),host.get_ability_debug_name.bind(ability),
				host.report_start_rule_error.bind(ability))
	else:
		return host.can_fire(ability)

static func fire_resolved(ability: Object, character: Object, host: Object,
		use_source_start_rules: bool, command_context: Variant, activation_context: Variant) -> int:
	var result := can_fire_resolved(ability,host,use_source_start_rules)
	if result != 0: return result
	var requested := Vector2.ZERO
	var has_requested := false
	if activation_context != null:
		var aim: Dictionary = activation_context.try_get_aim_direction()
		if aim.has_direction:
			requested = Vector2(aim.direction.x,aim.direction.y)
			if _source_sqr(requested) > PackedFloat32Array([0.0001])[0]:
				has_requested = true
				requested = requested.normalized()
				character.set_target_direction(requested)
	if host.should_update_look_at_direction_on_fire(ability):
		var target: Vector2 = character.get_target_direction()
		if has_requested: target = requested
		if _source_sqr(target) > PackedFloat32Array([0.0001])[0]:
			character.set_look_at_direction(target)
	if host.uses_automatic_runtime_state_management(ability):
		host.set_ability_active(ability,true)
		host.fire(ability,command_context,activation_context,_completion(ability,host))
	else:
		host.fire(ability,command_context,activation_context,null)
	return result

static func _source_sqr(value: Vector2) -> float:
	return preload("res://game_core/interaction/ability_activation_context.gd").source_sqr_magnitude(Vector3(value.x,value.y,0))

## 捕获同一实例而非槽位；弱引用避免原生 RefCounted 能力保存结束回调时成环。
## 已释放的对象不再有可关闭状态；不解析替代对象，不修改当前槽位。
static func _completion(ability: Object, host: Object) -> Callable:
	var ability_ref: WeakRef = weakref(ability)
	var host_ref: WeakRef = weakref(host)
	return func():
		var live_ability: Object = ability_ref.get_ref()
		var live_host: Object = host_ref.get_ref()
		if is_instance_valid(live_ability) and is_instance_valid(live_host):
			live_host.set_ability_active(live_ability,false)
