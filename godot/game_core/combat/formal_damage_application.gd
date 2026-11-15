extends RefCounted
## FormalDamageExecutor.TryExecuteDamageOutput 的有序执行，不建立属性或 GAS。
## 调用方拥有角色、属性储存、目标碰撞体与效果生命周期；本层只负责流程。
const Combat = preload("res://game_core/combat/combat_rules.gd")

# hooks 中必需的目标回调：
# provoke(source); impact(input, velocity) 仅在 impact_velocity 存在时;
# has_formal_stats() -> bool; current_health() -> int; prepare(source, input);
# apply_current_health_delta(delta, min_value, max_value, source) -> int 或失败 null;
# complete(source, input, previous_health, applied_damage).
static func execute_damage_output(defender: Variant, output: Dictionary, can_miss: bool,
		roll: Callable, hooks: Dictionary, impact_velocity: Variant = null) -> bool:
	if defender == null or not Combat.can_target_output(output, defender):
		return false
	var source: Variant = output.source
	var input: Dictionary = Combat.solve_damage_input(defender, output, can_miss, roll)
	if impact_velocity != null:
		hooks.impact.call(input, impact_velocity)
	hooks.provoke.call(source)
	if input.damage > 0:
		if not hooks.has_formal_stats.call():
			return false
		var previous: int = hooks.current_health.call()
		hooks.prepare.call(source, input)
		var current: Variant = hooks.apply_current_health_delta.call(-input.damage, 0, null, source)
		if not current is int:
			return false
		hooks.complete.call(source, input, previous, maxi(0, previous - int(current)))
	return (int(input.flags) & Combat.MISS) == 0
