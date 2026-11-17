extends RefCounted
## CharacterAbilitySet 的 Fire/Stop 槽位查询。每次读取当前槽，不缓存按下时的技能。
const Loadout = preload("res://game_core/combat/equipped_ability_loadout.gd")
var _loadout: RefCounted
var _resolve_active: Callable
var _fire_resolved: Callable
var _stop_resolved: Callable

## resolve_active 必须执行原运行时查找和 ActiveAbilityBase 类型判定；失败返回 null。
## fire_resolved 仍由正式能力宿主执行 CanFire/朝向/生命周期，返回原检查结果整数。
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
