extends "res://tests/test_active_ability_start_rules.gd"
const FireContext = preload("res://game_core/combat/active_ability_fire_context.gd")
class ChargeAbility extends ActiveAbility:
	var context = FireContext.new()
	var uses: Array=[]
	var starts := 0
	func capture_use() -> bool:
		uses.append([context.command_context.duplicate(),context.activation_context])
		return true
	func started() -> void: starts += 1
class ContextHost extends StartHost:
	var gate_results: Array=[]
	func fire(a: Object,c: Variant,x: Variant,done: Variant) -> void:
		calls.append(["fire",a])
		gate_results.append(a.context.fire(c,x,done))
	func stop_fire(a: Object) -> void:
		calls.append(["stop",a]);a.context.stop_fire()

func run() -> void:
	var scene=Entry.instantiate();root.add_child(scene)
	var control:=ControlHost.new();root.add_child(control)
	var owner:=FacingOwner.new();var player:=Player.new();player.actor=scene.actor;var events:=MapEvents.new()
	var directory:=ProjectSettings.globalize_path("user://fire-context-test")
	var data: Array
	var private_dir:=OS.get_environment("FORMAL_HUMAN_PRIVATE")
	if private_dir.is_empty(): data=fixtures(scene,directory)
	else:
		directory=private_dir.path_join("private-human-source")
		data=[read(private_dir.path_join("private-clickmove-audit/rules.json")),read(private_dir.path_join("private-formal-human-verification/animation-final.json"))]
	check(scene.start_human_presentation(data[1],directory)!=null and scene.start_human_logic(owner,data[0],func():return player,func():return null,events,func(_p):return false),"同一角色正式入口")
	check(scene.start_human_aim(owner,control) and scene.start_human_interaction(owner,func():pass),"同一命令 owner")
	var slots:=Loadout.new(5);slots.try_assign_formal_gas_ability_code_to_slot(0,20004)
	var ability:=ChargeAbility.new();ability.code=20004
	var host:=ContextHost.new()
	ability.gate=Hold.new(func():return host.can_start(ability),ability.capture_use)
	ability.gate.sequence_started.connect(ability.started)
	check(ability.context.configure(owner,ability.gate),"绑定唯一既有门控")
	check(not ability.context.configure(owner,ability.gate),"不重复订阅")
	check(scene.start_human_resolved_equipped_abilities(owner,slots,func(_code):return ability,host,func(_t):return Vector3.ZERO,func(_t):return null,func(_c,_r):pass,true),"resolved 原流程使用真实上下文 owner")
	await process_frame
	var a: Dictionary={"kind":Executor.Kind.FIRE_ABILITY,"ability_index":0,"actor":owner,"command_context":{"actor":owner,"issuer_kind":1,"issuer_id":"local","marker":"A"},"direction":Vector2.RIGHT}
	check(scene.submit_human_command(a)==Executor.Failure.NONE and host.gate_results==[true],"A 启动一条真实蓄力")
	var original_activation: Variant=ability.context.activation_context
	var b: Dictionary=a.duplicate(true);b.command_context={"actor":owner,"issuer_kind":3,"issuer_id":"B"};b.direction=Vector2.UP
	host.result=2;host.evaluations.clear()
	check(scene.submit_human_command(b)==Executor.Failure.NONE and host.gate_results==[true,false],"B 忙碌预检有效但不另起序列")
	check(host.evaluations.is_empty() and ability.starts==1 and ability.gate.is_charging(),"不重评估起手，不重复蓄力")
	check(ability.context.command_context.issuer_id=="B" and ability.context.activation_context!=original_activation,"拒绝新请求不阻止替换上下文")
	check(ability.uses.is_empty(),"蓄力期间未伪造效果")
	var stop:=a.duplicate();stop.kind=Executor.Kind.STOP_FIRE_ABILITY
	check(scene.submit_human_command(stop)==Executor.Failure.NONE and ability.uses.size()==1,"实际 Stop 释放已有蓄力")
	check(ability.uses[0][0].issuer_id=="B" and ability.uses[0][1].try_get_aim_direction().direction==Vector3(0,-1,0),"USE 消费最新 B 命令与激活信息")
	check(ability.context.casting,"后摇尚未完成")
	ability.gate.advance(0.7)
	check(not ability.context.casting and ability.context.activation_context==null and host.calls.back()==["active",ability,false],"结束清激活信息后关闭原实例")
	check(ability.context.command_context.issuer_id=="B","结束保留最后命令")

	# 直接能力 Fire 验证覆盖 null 回调及不带 actor 的 Recreate，不经命令入口投影。
	host.result=0;ability.gate.advance(0.0)
	var completed: Array=[]
	check(ability.context.fire({"actor":null,"issuer_kind":1,"issuer_id":"not-local"},null,func():completed.append("A")),"无 actor 的输入启动")
	check(ability.context.command_context=={"actor":owner,"issuer_kind":1,"issuer_id":"local"},"Recreate 本地发起方固定标识")
	check(not ability.context.fire({"actor":null,"issuer_kind":2,"issuer_id":"bad"},null,null),"忙碌 null 替换")
	ability.context.stop_fire();ability.gate.advance(0.7)
	check(completed.is_empty() and ability.context.command_context.issuer_id=="ai","null 删除原结束回调，AI 标识规范化")
	for kind in [0,3,4,99]:
		ability.gate.advance(0.0)
		check(ability.context.fire({"actor":null,"issuer_kind":kind,"issuer_id":"tag"},null,func():completed.append(kind)),"重新启动 %d" % kind)
		var expected_kind: int=3 if kind==99 else kind
		var expected_id:="" if kind==0 else "tag"
		check(ability.context.command_context=={"actor":owner,"issuer_kind":expected_kind,"issuer_id":expected_id},"保留合法来源或降级脚本 %d" % kind)
		ability.context.stop_fire();ability.gate.advance(0.7)
	check(completed==[0,3,4,99],"完成回调按当前序列各一次")
	ability.context.terminate_casting()
	check(completed.size()==4,"已结束不再次通知")
	ability.gate.advance(0.0)
	var retained: Dictionary={"actor":owner,"issuer_kind":4,"issuer_id":"original"}
	ability.context.fire(retained,null,func():completed.append("old"))
	retained.issuer_id="mutated"
	check(ability.context.command_context.issuer_id=="original","命令结构值拷贝不被调用方修改")
	var replacement:=Activation.new(Vector3.ONE,null,Vector3.RIGHT)
	check(not ability.context.fire({"actor":owner,"issuer_kind":4,"issuer_id":"new"},replacement,func():completed.append("new")),"忙碌仍替换为新的非空回调")
	check(ability.context.activation_context==replacement,"激活上下文保留原引用")
	ability.context.stop_fire();ability.gate.advance(0.7)
	check(completed.back()=="new" and not completed.has("old"),"只调用最后的非空结束回调")
	# 清除测试闭包捕获；这不改变运行时输入门控。
	ability.gate._can_start=Callable()
	ability.gate._release_use=Callable()
	scene.free();control.free();await process_frame
	if failed==0: print("PASS active ability fire context: %d checks" % n)
	quit(0 if failed==0 else 1)
