extends SceneTree
const Scene = preload("res://validation/scenes/delayed_charge_fixture.tscn")
const Spec = preload("res://gameplay/combat/charged_timeline_spec.gd")
const Activation = preload("res://game_core/interaction/ability_activation_context.gd")
var n:=0
var failed:=0
class ObservedSpec extends Spec:
	var calls: Array=[]
	func validate_fire_point(code: int) -> Dictionary:
		calls.append("check");return super.validate_fire_point(code)
	func request_begin(code: int, context: Variant) -> bool:
		calls.append("begin");return super.request_begin(code,context)
	func commit_rule_use(code: int) -> Dictionary:
		calls.append("commit");return super.commit_rule_use(code)
func check(value: bool, why: String) -> void:
	n+=1
	if not value: failed+=1;printerr(why)
func key(code: Key, down: bool) -> void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=down
	root.push_input(event,true)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var fixture=Scene.instantiate()
	fixture.automatic_clock=false;fixture.automatic_spec_update=false
	fixture.charge_spec=ObservedSpec.new()
	root.add_child(fixture)
	fixture.set_process(false)
	await physics_frame;await physics_frame
	var spec: RefCounted=fixture.charge_spec
	var results: Array=[];var closures: Array=[]
	spec.activation_result.connect(func(value):results.append([value,fixture.charge_spec.active,fixture.timeline.playing,fixture.charge_spec.activate_requested,fixture.charge_spec.activation_context,fixture.charge_spec.pending_context]))
	spec.cancelled.connect(func():closures.append(["cancel",fixture.charge_spec.active,fixture.charge_spec.activation_context,fixture.charge_spec.owns_attacking_tag()]))
	spec.ended.connect(func():closures.append(["end",fixture.charge_spec.active,fixture.charge_spec.activation_context,fixture.charge_spec.owns_attacking_tag()]))
	key(KEY_Q,true);key(KEY_Q,false)
	check(spec.calls==["check","check","begin","commit","check"],"真实起手/出手/Begin/独立提交顺序")
	check(spec.activate_requested and not spec.active and not fixture.timeline.playing,"松开仅排队，不立即播放")
	check(spec.pending_context.aim_origin==Vector3.ZERO and fixture.defender.health==50,"实际角色创建默认上下文，未发命中")
	spec.set_fixed_attacking(true)
	spec.process_update()
	check(results.size()==1 and results[0].slice(0,4)==[Spec.ActivationResult.TAG_REQUIREMENT,false,false,true],"入队后3003变化真实晚拒绝，事件先于标记移除")
	check(not spec.activate_requested and spec.pending_context==null and spec.activation_context==null and not spec.owns_attacking_tag(),"拒绝清pending但不创建临时标签")
	fixture.timeline.advance(1.0)
	check(fixture.hit_count==0 and fixture.defender.health==50,"拒绝没有启动现有Timeline，无实际扣血")
	check(fixture.charge_context.casting,"晚拒绝不是同步门控打断")
	fixture.charge_gate.advance(0.7)
	check(spec.end_requested and closures.is_empty(),"门控结束仅投递End")
	spec.process_update()
	check(closures.is_empty() and not spec.end_requested,"未激活的End只消耗标记")
	spec.set_fixed_attacking(false);fixture.charge_gate.advance(0.0)
	key(KEY_2,true);key(KEY_2,false)
	var accepted: Variant=spec.pending_context
	spec.process_update()
	check(results.back().slice(0,4)==[Spec.ActivationResult.SUCCESS,false,true,true],"成功先启动Timeline，通知时active尚未提交")
	check(spec.active and fixture.timeline.playing and spec.activation_context==accepted and spec.pending_context==null,"同次更新提交active及激活上下文")
	check(spec.owns_attacking_tag() and spec.has_attacking_tag(),"正式3003临时标签按自身来源登记")
	check(spec.check_activation()==Spec.ActivationResult.ALREADY_ACTIVE,"活跃检查先于标签拒绝")
	fixture.timeline.advance(0.19)
	check(fixture.defender.health==50,"原命中帧之前无伤害")
	fixture.timeline.advance(0.02)
	check(fixture.hit_count==1 and fixture.defender.health==29 and fixture.defender.max_health==50,"后续更新启动真实命中时钟，实际扣21")
	# 已激活时请求B：后续拒绝只清pending，保留之前的ActivationContext。
	var replacement:=Activation.new(Vector3.ONE,null,Vector3.RIGHT)
	spec.request_begin(20004,replacement);spec.process_update()
	check(results.back()[0]==Spec.ActivationResult.ALREADY_ACTIVE and spec.activation_context==accepted and spec.pending_context==null,"失败不擦除先前活动上下文")
	spec.add_temporary_attacking(98765)
	fixture.charge_gate.interrupt()
	check(spec.cancel_requested and spec.end_requested and fixture.timeline.playing,"Interrupt仅投递Cancel/End，尚未停止Timeline")
	spec.process_update()
	check(not spec.active and not fixture.timeline.playing and spec.activation_context==null,"后续取消处理真实停止并清上下文")
	check(closures==[["cancel",true,null,false]],"Cancel通知在active移除前；随后End不重复回调")
	check(spec.has_attacking_tag() and not spec.owns_attacking_tag(),"清自身来源不移除其他来源3003")
	spec.remove_temporary_attacking(98765)
	check(not spec.has_attacking_tag(),"外部来源独立移除")
	fixture.charge_gate.advance(0.0)
	key(KEY_Q,true);key(KEY_Q,false)
	fixture.charge_gate.interrupt()
	spec.process_update()
	check(results.back()[0]==Spec.ActivationResult.SUCCESS and not spec.active and not fixture.timeline.playing,"同一边界先Activate再Cancel再End")
	check(not spec.activate_requested and not spec.cancel_requested and not spec.end_requested,"原标记一次消费")
	check(closures.size()==2 and closures.back()[0]=="cancel","非活动End不重复触发生命周期")
	fixture.charge_gate.advance(0.0)
	key(KEY_Q,true)
	var older:=Activation.new(Vector3(2,0,0),null,Vector3.RIGHT)
	var newer:=Activation.new(Vector3(3,0,0),null,Vector3.UP)
	fixture.charge_context.fire({"actor":fixture.attacker,"issuer_id":"A"},older,null)
	fixture.charge_context.fire({"actor":fixture.attacker,"issuer_id":"B"},newer,null)
	key(KEY_Q,false)
	check(spec.pending_context==newer,"入队使用已有Fire最新上下文B")
	spec.process_update()
	check(spec.activation_context==newer,"后续激活提交B")
	spec.request_end(20004)
	check(spec.active and fixture.timeline.playing,"正常End仍不立即执行")
	spec.process_update()
	check(closures.back()==["end",true,null,false] and not spec.active and not fixture.timeline.playing,"正常End恢复标签清上下文并停止")
	spec.request_cancel(20004);spec.request_end(20004);var before:=closures.size();spec.process_update()
	check(closures.size()==before,"空闲Cancel/End不触发逻辑或通知")
	check(not spec.request_begin(20001,newer) and not spec.activate_requested,"明确拒绝未迁移的其他spec代码")
	fixture.queue_free();await process_frame
	if failed==0: print("PASS delayed native 20004 activation: %d checks" % n)
	quit(0 if failed==0 else 1)
