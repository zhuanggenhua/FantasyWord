extends RefCounted
## ActiveAbilityBase.Fire/TerminateCasting 的实例上下文；不持有第二套输入状态机。
## 宿主先连接原 sequenceStarted/sequenceStopped 业务，再配置本对象，保留业务先后顺序。
## 使用点须读取本对象当前值；GAS 验证、上下文构造、Begin/Commit/End 仍由真实宿主负责。
var command_context: Dictionary = {"actor":null,"issuer_kind":3,"issuer_id":""}
var activation_context: Variant
var casting := false
var _completion: Variant
var _character: Object
var _gate: RefCounted
var _timeline_host_ref: WeakRef
var _timeline_host: Object:
	get: return _timeline_host_ref.get_ref() if _timeline_host_ref != null else null
var _ability_code := 0
var _effect_cost_paid := false

func configure(character: Object, gate: RefCounted) -> bool:
	if _gate != null or not is_instance_valid(character) or gate == null: return false
	for method in (["request_use","release_use","interrupt"] if _ability_code > 0 else ["request_use","release_use"]):
		if not gate.has_method(method): return false
	for event in (["sequence_started","sequence_stopped","interrupted"] if _ability_code > 0 else ["sequence_started","sequence_stopped"]):
		if not gate.has_signal(event): return false
	_character = character
	_gate = gate
	_gate.sequence_started.connect(_on_sequence_started)
	_gate.sequence_stopped.connect(_on_sequence_stopped)
	if _ability_code > 0: _gate.interrupted.connect(_on_interrupted)
	return true

## bool 仅暴露门控原返回值作诊断，不是 CanFire/命令执行结果。
## 即使门控忙碌拒绝本次请求，三项上下文仍按原 Fire 顺序替换。
func fire(context: Dictionary, activation: Variant, completion: Variant) -> bool:
	assert(_gate != null, "主动能力上下文尚未绑定实际角色和输入门控。")
	_completion = completion
	command_context = context.duplicate() if is_instance_valid(context.get("actor")) else _recreate(context)
	activation_context = activation
	return _gate.request_use()

func stop_fire() -> bool:
	return _gate.release_use() if _gate != null else false

func _on_sequence_started() -> void:
	casting = true
	_effect_cost_paid = false

func _on_sequence_stopped() -> void:
	if is_instance_valid(_timeline_host):
		_timeline_host.request_end(_ability_code)
	terminate_casting()

func _on_interrupted() -> void:
	if is_instance_valid(_timeline_host):
		_timeline_host.request_cancel(_ability_code)


# ActiveAbilityBase.ReadFormalRuntimeState clears these without completing a cast.
# The caller must already have verified no active or pending formal execution.
func restore_timeline_persistent_idle() -> void:
	casting = false
	_effect_cost_paid = false
	_completion = null

func terminate_casting() -> void:
	activation_context = null
	if not casting: return
	casting = false
	if _completion != null: _completion.call()
	_completion = null

## GameCommandContext.Recreate 的已解码字段投影；不是任意字典原样添加角色。
func _recreate(context: Dictionary) -> Dictionary:
	var kind: int = int(context.get("issuer_kind",0))
	var issuer: String = str(context.get("issuer_id",""))
	match kind:
		0: issuer = ""
		1: issuer = "local"
		2: issuer = "ai"
		3,4: pass
		_: kind = 3
	if issuer.strip_edges().is_empty(): issuer = ""
	return {"actor":_character,"issuer_kind":kind,"issuer_id":issuer}

## 仅 TimelineActiveAbility：原 ExecuteAbilityUse 和内部序列钩子均为空。
## 宿主实现真实 CharacterAbilitySet 规则/请求；本对象不模拟 ECS，也不支付本地费用。
## 必须先配置，再绑定原门控；门控 USE 回调传入 perform_timeline_use。
func configure_timeline_rules(host: Object, ability_code: int) -> bool:
	if _gate != null or _timeline_host_ref != null or not is_instance_valid(host) or ability_code <= 0: return false
	for method in ["validate_fire_point","create_activation_context","request_begin","commit_rule_use","request_cancel","request_end","get_ability_debug_name","report_error"]:
		if not host.has_method(method): return false
	_timeline_host_ref = weakref(host)
	_ability_code = ability_code
	return true

## true 仅表示本次同步校验/请求编排完成，不表示 EX-GAS 已经激活或效果发生。
func perform_timeline_use() -> bool:
	assert(_gate != null and _ability_code > 0, "Timeline 主动能力尚未绑定正式规则与输入门控。")
	if not _effect_cost_paid and not _validate_or_commit(false):
		_gate.interrupt()
		return false
	if not is_instance_valid(_timeline_host):
		_gate.interrupt()
		return false
	var resolved: Variant = _timeline_host.create_activation_context(activation_context)
	if resolved == null:
		_timeline_host.report_error("%s 无法激活：角色实例缺失，无法创建本次 GAS 激活上下文。" % _timeline_host.get_ability_debug_name())
		_gate.interrupt()
		return false
	if not _timeline_host.request_begin(_ability_code, resolved):
		_timeline_host.request_cancel(_ability_code)
		_gate.interrupt()
		return false
	if not _effect_cost_paid and not _validate_or_commit(true):
		_timeline_host.request_cancel(_ability_code)
		_gate.interrupt()
		return false
	# TimelineActiveAbility.ExecuteAbilityUse 为空；真实 Timeline 由稍后的 GAS 激活处理启动。
	return true

func _validate_or_commit(commit: bool) -> bool:
	if not is_instance_valid(_timeline_host): return false
	var result: Dictionary = _timeline_host.commit_rule_use(_ability_code) if commit else _timeline_host.validate_fire_point(_ability_code)
	if not result.get("available",false):
		var point := "出手提交" if commit else "命中帧校验"
		_timeline_host.report_error("%s 已绑定 EX-GAS Ability，但%s时没有可用的正式规则绑定。" % [_timeline_host.get_ability_debug_name(),point])
		return false
	if int(result.get("result",4)) != 0: return false
	if commit: _effect_cost_paid = true
	return true
