extends SceneTree
const Context = preload("res://game_core/combat/active_ability_fire_context.gd")
const Hold = preload("res://game_core/combat/hold_release_gate.gd")
const Activation = preload("res://game_core/interaction/ability_activation_context.gd")
var n:=0
var failed:=0
func check(value: bool, message: String) -> void:
	n+=1
	if not value: failed+=1;printerr(message)
class RuleHost extends RefCounted:
	# 显式规则/请求测试接缝，不是 EX-GAS ECS 或默认玩法数据。
	var trace: Array=[]
	var dry_result:=0
	var commit_result:=0
	var dry_available:=true
	var commit_available:=true
	var begin_ok:=true
	var context_ok:=true
	var received: Variant
	var requests: Array=[]
	func validate_fire_point(code: int) -> Dictionary:
		trace.append(["dry",code]);return {"available":dry_available,"result":dry_result}
	func create_activation_context(pending: Variant) -> Variant:
		trace.append(["context",pending]);received=pending
		return pending if context_ok else null
	func request_begin(code: int, activation: Variant) -> bool:
		trace.append(["begin",code,activation])
		if begin_ok: requests.append(["activate",code,activation])
		return begin_ok
	func commit_rule_use(code: int) -> Dictionary:
		trace.append(["commit",code]);return {"available":commit_available,"result":commit_result}
	func request_cancel(code: int) -> void:
		trace.append(["cancel",code]);requests.append(["cancel",code])
	func request_end(code: int) -> void:
		trace.append(["end",code]);requests.append(["end",code])
	func get_ability_debug_name() -> String: return "蓄力技能"
	func report_error(message: String) -> void: trace.append(["error",message])
func _initialize() -> void: call_deferred("run")
func make_case(owner: Node2D) -> Array:
	var host:=RuleHost.new()
	var context:=Context.new()
	check(context.configure_timeline_rules(host,20004),"配置明确正式规则宿主")
	var gate:=Hold.new(func():return true,context.perform_timeline_use)
	check(context.configure(owner,gate),"绑定唯一既有 HoldRelease")
	gate.interrupted.connect(func():host.trace.append(["interrupted_observed"]))
	return [host,context,gate]
func names(trace: Array) -> Array:
	var result: Array=[]
	for row in trace: result.append(row[0])
	return result
func run() -> void:
	var owner:=Node2D.new();root.add_child(owner)
	var activation:=Activation.new(Vector3(3,4,0),null,Vector3.RIGHT)
	for result in [1,2,3,4]:
		var parts:=make_case(owner)
		var host: RuleHost=parts[0];var context: RefCounted=parts[1];var gate: RefCounted=parts[2]
		check(context.fire({"actor":owner},activation,func():host.trace.append(["done",context.activation_context,context.casting])),"起手可用")
		host.dry_result=result
		check(not context.stop_fire(),"出手点重新拒绝 %d" % result)
		check(names(host.trace)==["dry","cancel","interrupted_observed","end","done"],"早拒绝没有上下文构造或 Begin/Commit")
		check(host.trace.back()==["done",null,false] and not context.casting,"End 之后清理再完成")
		check(gate.state==Hold.State.INTERRUPTED,"真实门控已打断")
		check(host.requests==[["cancel",20004],["end",20004]],"即使未 Begin 也发送 Cancel 和 End 请求")
		gate._release_use=Callable()
	for failure in ["dry_unavailable","context","begin","commit","commit_unavailable"]:
		var parts:=make_case(owner)
		var host: RuleHost=parts[0];var context: RefCounted=parts[1];var gate: RefCounted=parts[2]
		context.fire({"actor":owner},activation,func():host.trace.append(["done"]))
		match failure:
			"dry_unavailable": host.dry_available=false
			"context": host.context_ok=false
			"begin": host.begin_ok=false
			"commit": host.commit_result=2
			"commit_unavailable": host.commit_available=false
		check(not context.stop_fire(),"各失败路径实际打断 "+failure)
		var expected: Array
		match failure:
			"dry_unavailable": expected=["dry","error","cancel","interrupted_observed","end","done"]
			"context": expected=["dry","context","error","cancel","interrupted_observed","end","done"]
			"begin": expected=["dry","context","begin","cancel","cancel","interrupted_observed","end","done"]
			"commit": expected=["dry","context","begin","commit","cancel","cancel","interrupted_observed","end","done"]
			"commit_unavailable": expected=["dry","context","begin","commit","error","cancel","cancel","interrupted_observed","end","done"]
		check(names(host.trace)==expected,"保持原失败请求顺序 "+failure)
		check(context.activation_context==null,"失败已清除激活引用 "+failure)
		gate._release_use=Callable()
	var parts:=make_case(owner)
	var host: RuleHost=parts[0];var context: RefCounted=parts[1];var gate: RefCounted=parts[2]
	context.fire({"actor":owner,"issuer_id":"A"},activation,func():host.trace.append(["old"]))
	var b:=Activation.new(Vector3(8,9,0),null,Vector3.UP)
	check(not context.fire({"actor":owner,"issuer_id":"B"},b,func():host.trace.append(["done"])),"忙碌替换 B 不重启")
	check(context.stop_fire() and names(host.trace)==["dry","context","begin","commit"],"真实 USE 同步顺序")
	check(host.received==b and host.requests==[["activate",20004,b]],"Begin 使用 B 上下文且仅排队")
	check(gate.state==Hold.State.DELAY_BETWEEN_USES and context.casting,"请求后进入原后摇")
	gate.advance(0.7)
	check(names(host.trace)==["dry","context","begin","commit","end","done"],"正常结束请求先于完成")
	check(context.command_context.issuer_id=="B" and context.activation_context==null,"保留命令，清理激活引用")
	gate.advance(0.0);host.trace.clear();host.dry_result=2
	context.fire({"actor":owner},activation,null)
	check(not context.stop_fire() and names(host.trace)==["dry","cancel","interrupted_observed","end"],"新序列清除已提交标志，重新 dry-check")
	gate._release_use=Callable()
	owner.free();await process_frame
	if failed==0: print("PASS timeline fire point: %d checks" % n)
	quit(0 if failed==0 else 1)
