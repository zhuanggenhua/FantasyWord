extends "res://tests/test_resolved_ability_fire.gd"
const StartRules = preload("res://game_core/combat/active_ability_start_rules.gd")
const Semi = preload("res://game_core/combat/basic_semi_auto_gate.gd")
const Hold = preload("res://game_core/combat/hold_release_gate.gd")
class ActiveAbility extends RefCounted:
	var code: int
	var gate: Object
class StartHost extends AbilityHost:
	var available := true
	var evaluations: Array=[]
	var errors: Array=[]
	var reads: Array=[]
	func evaluate_rule(code: int) -> Dictionary:
		evaluations.append(code)
		return {"available":available,"result":result}
	func report_error(message: String) -> void: errors.append(message)
	func get_input_gate(a: Object) -> Object: calls.append(["can",a]);return a.gate
	func get_formal_gas_ability_code(a: Object) -> int: reads.append("code");return a.code
	func evaluate_start_rule(code: int,_a: Object) -> Dictionary: return evaluate_rule(code)
	func get_ability_debug_name(_a: Object) -> String: reads.append("name");return "原技能"
	func report_start_rule_error(message: String,_a: Object) -> void: report_error(message)
	func can_start(a: Object) -> bool:
		return StartRules.can_start(a.code,evaluate_rule,"原技能",report_error)

func run() -> void:
	var scene=Entry.instantiate();root.add_child(scene)
	var control:=ControlHost.new();root.add_child(control)
	var owner:=FacingOwner.new();var player:=Player.new();player.actor=scene.actor;var events:=MapEvents.new()
	var directory:=ProjectSettings.globalize_path("user://start-rule-test")
	var data:=fixtures(scene,directory)
	check(scene.start_human_presentation(data[1],directory)!=null and scene.start_human_logic(owner,data[0],func():return player,func():return null,events,func(_p):return false),"原生角色启动")
	check(scene.start_human_aim(owner,control) and scene.start_human_interaction(owner,func():pass),"同一命令宿主")
	var slots:=Loadout.new(5);slots.try_assign_formal_gas_ability_code_to_slot(0,20001)
	var ability:=ActiveAbility.new();ability.code=20004
	var host:=StartHost.new();host.automatic=false
	var rejected: Array=[]
	check(scene.start_human_resolved_equipped_abilities(owner,slots,func(_code):return ability,host,func(_t):return Vector3.ZERO,func(_t):return null,func(code,result):rejected.append([code,result]),true),"真实 resolved 入口绑定")
	await process_frame
	var request: Dictionary={"kind":Executor.Kind.FIRE_ABILITY,"ability_index":0,"actor":owner,"command_context":{"actor":owner},"direction":Vector2.RIGHT}
	for rejection in [1,2,3,4]:
		host.result=rejection;host.calls.clear();owner.calls.clear()
		check(scene.submit_human_command(request)==Executor.Failure.ABILITY_REJECTED,"拒绝传播 %d" % rejection)
		check(host.calls==[["can",ability]] and not owner.calls.has("target") and not owner.calls.has("look"),"拒绝无方向和 Fire 副作用")
	check(host.evaluations==[20004,20004,20004,20004] and rejected.back()==[20001,4],"规则取实例代码，通知仍使用槽位代码")
	check(not host.reads.has("name"),"真实规则拒绝不读诊断名称")
	host.result=0;host.calls.clear()
	check(scene.submit_human_command(request)==Executor.Failure.NONE and host.calls.back()==["fire",ability],"有效规则抵达 Fire")
	for mode in ["semi","hold"]:
		var gate: Object=Semi.new(func():return host.can_start(ability),func():return true) if mode=="semi" else Hold.new(func():return host.can_start(ability),func():return true)
		ability.gate=gate
		host.result=2
		check(not gate.request_use() and not gate.is_busy(),"起手独立拒绝 "+mode)
		host.result=0
		check(gate.request_use() and gate.is_busy(),"真实状态机进入忙碌 "+mode)
		host.result=3;host.evaluations.clear();host.reads.clear()
		check(scene.submit_human_command(request)==Executor.Failure.NONE and host.evaluations.is_empty() and host.reads.is_empty(),"忙碌 CanFire 不重复检查 "+mode)
		check(not host.can_start(ability) and host.evaluations==[20004],"新序列仍重评估 "+mode)
		if mode=="semi": gate.advance(0.02)
		else: gate.release_use()
		host.evaluations.clear()
		check(gate.is_busy() and scene.submit_human_command(request)==Executor.Failure.NONE and host.evaluations.is_empty(),"后摇也是忙碌 "+mode)
		gate.interrupt();host.evaluations.clear()
		check(not gate.is_busy() and scene.submit_human_command(request)==Executor.Failure.ABILITY_REJECTED and host.evaluations==[20004],"打断回到正式规则 "+mode)
		gate.advance(0.0)
		check(not gate.is_busy(),"空闲不是忙碌 "+mode)
		host.result=0;gate.release_use();gate.request_use()
		if mode=="semi": gate.advance(0.02)
		else: gate.release_use()
		gate.release_use()
		check(not gate.is_busy(),"停止不是忙碌 "+mode)
		ability.gate=null
	host.available=false;host.errors.clear()
	check(scene.submit_human_command(request)==Executor.Failure.ABILITY_REJECTED and host.errors==["原技能 已绑定 EX-GAS Ability，但没有可用的正式规则绑定。"],"正式绑定缺失不是成功")
	ability.code=0;host.errors.clear();host.evaluations.clear()
	check(scene.submit_human_command(request)==Executor.Failure.ABILITY_REJECTED and host.evaluations.is_empty() and host.errors==["原技能 尚未绑定 EX-GAS Ability；主动能力缺少启动规则。"],"未绑定 code 不调用规则")
	host.errors.clear()
	check(StartRules.evaluate(20004,Callable(),"原技能",host.report_error)==4 and host.errors.size()==1,"角色规则 owner 缺失明确诊断")
	scene.free();control.free();await process_frame
	if failed==0: print("PASS active ability start rules: %d checks" % n)
	quit(0 if failed==0 else 1)
