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

func configure(character: Object, gate: RefCounted) -> bool:
	if _gate != null or not is_instance_valid(character) or gate == null: return false
	for method in ["request_use","release_use"]:
		if not gate.has_method(method): return false
	for event in ["sequence_started","sequence_stopped"]:
		if not gate.has_signal(event): return false
	_character = character
	_gate = gate
	_gate.sequence_started.connect(_on_sequence_started)
	_gate.sequence_stopped.connect(terminate_casting)
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
