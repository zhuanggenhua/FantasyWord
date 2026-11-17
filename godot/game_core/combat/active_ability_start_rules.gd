extends RefCounted
## ActiveAbilityBase 的起手检查切片。调用方传入同一能力实例的当前字段，
## 不用槽位代码代替能力代码，不在这里创建门控或缓存规则结果。
enum Result { VALID, ON_COOLDOWN, NOT_ENOUGH_MANA, INCAPACITATED, UNKNOWN }

static func can_fire(input_gate: Object, ability_code: int, evaluate_rule: Callable, debug_name: Variant, report_error: Callable) -> int:
	if input_gate != null and input_gate.is_busy():
		return Result.VALID
	return evaluate(ability_code,evaluate_rule,debug_name,report_error)

## 新序列必须独立重评估；不能通过 CanFire 的忙碌短路绕过正式规则。
static func can_start(ability_code: int, evaluate_rule: Callable, debug_name: Variant, report_error: Callable) -> bool:
	return evaluate(ability_code,evaluate_rule,debug_name,report_error) == Result.VALID

## evaluate_rule 对应 CharacterAbilitySet.TryEvaluateFormalGasAbilityRuleActivation；
## 返回 {available: bool, result: EAbilityFireCheckResult}，available=false 不是规则拒绝。
## 角色组合所有权、规则绑定、资源和标签由原正式规则 owner 判定，不在这里补成功。
static func evaluate(ability_code: int, evaluate_rule: Callable, debug_name: Variant, report_error: Callable) -> int:
	if ability_code > 0:
		if evaluate_rule.is_valid():
			var evaluated: Dictionary = evaluate_rule.call(ability_code)
			if evaluated.available:
				return evaluated.result
		_error("%s 已绑定 EX-GAS Ability，但没有可用的正式规则绑定。" % _debug_name(debug_name),report_error)
		return Result.UNKNOWN
	_error("%s 尚未绑定 EX-GAS Ability；主动能力缺少启动规则。" % _debug_name(debug_name),report_error)
	return Result.UNKNOWN

static func _error(message: String, report_error: Callable) -> void:
	if report_error.is_valid(): report_error.call(message)
	else: push_error(message)

## 宿主可传延迟名称查询；成功或真实拒绝时不读取诊断元数据。
static func _debug_name(value: Variant) -> String:
	return value.call() if value is Callable else value
