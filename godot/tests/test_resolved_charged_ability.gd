extends "res://tests/test_resolved_ability_fire.gd"
const Charged = preload("res://gameplay/combat/resolved_charged_ability.gd")
const Clock = preload("res://game_core/combat/attack_hit_frame.gd")
var hits := 0
func _hit() -> void: hits+=1
func run() -> void:
	var scene=Entry.instantiate();root.add_child(scene)
	var control:=ControlHost.new();root.add_child(control)
	var owner:=FacingOwner.new();var player:=Player.new();player.actor=scene.actor;var events:=MapEvents.new()
	var directory:=ProjectSettings.globalize_path("user://resolved-charge")
	var data: Array
	var private_dir:=OS.get_environment("FORMAL_HUMAN_PRIVATE")
	if private_dir.is_empty(): data=fixtures(scene,directory)
	else:
		directory=private_dir.path_join("private-human-source")
		data=[read(private_dir.path_join("private-clickmove-audit/rules.json")),read(private_dir.path_join("private-formal-human-verification/animation-final.json"))]
	check(scene.start_human_presentation(data[1],directory)!=null and scene.start_human_logic(owner,data[0],func():return player,func():return null,events,func(_p):return false),"同一原生角色启动")
	check(scene.start_human_aim(owner,control) and scene.start_human_interaction(owner,func():pass),"真实命令入口")
	var clock:=Clock.new(12,36,_hit)
	var ability:=Charged.new();scene.add_child(ability)
	check(ability.configure(scene.actor,owner,clock,scene.actor.get_movement_position),"绑定实际角色、唯一正式规则和外部时钟")
	var slots:=Loadout.new(5)
	check(scene.start_human_resolved_equipped_abilities(owner,slots,ability.resolve,ability,func(_t):return Vector3.ZERO,func(_t):return null,func(_c,_r):pass,true),"生产resolved入口")
	await process_frame
	var request={"kind":Executor.Kind.FIRE_ABILITY,"ability_index":1,"actor":owner,"command_context":{"actor":owner,"issuer_kind":1},"direction":Vector2.RIGHT}
	scene.submit_human_command(request)
	check(not ability.local_active and not ability.gate.is_busy(),"没有默认装配20004")
	slots.try_assign_formal_gas_ability_code_to_slot(1,20004)
	ability.spec.set_fixed_attacking(true)
	check(scene.submit_human_command(request)==Executor.Failure.ABILITY_REJECTED and not ability.local_active,"同一3003规则阻止起手")
	ability.spec.set_fixed_attacking(false)
	check(scene.submit_human_command(request)==Executor.Failure.NONE and ability.local_active and ability.context.casting,"命令设置本地active再进入唯一门控")
	check(not ability.spec.active and not clock.playing and not ability.spec.activate_requested,"蓄力不提前请求或播放")
	var a=ability.context.activation_context
	request.direction=Vector2.UP
	check(scene.submit_human_command(request)==Executor.Failure.NONE and ability.context.activation_context!=a,"忙碌Fire仍替换同一实例上下文")
	var b=ability.context.activation_context
	request.kind=Executor.Kind.STOP_FIRE_ABILITY
	check(scene.submit_human_command(request)==Executor.Failure.NONE and ability.spec.activate_requested,"真实Stop命令投递Begin")
	check(ability.spec.pending_context==b and not ability.spec.active and not clock.playing,"只提交最新上下文，不同步播放")
	ability.spec.set_fixed_attacking(true);ability.process_requests()
	check(not ability.spec.active and not clock.playing and ability.spec.pending_context==null,"后续标签改变真实拒绝激活")
	ability.advance_input(0.61);ability.process_requests();ability.advance_input(0)
	check(not ability.local_active and not ability.context.casting,"门控停止完成同一实例本地active")
	ability.spec.set_fixed_attacking(false);request.kind=Executor.Kind.FIRE_ABILITY
	check(scene.submit_human_command(request)==Executor.Failure.NONE,"新序列重启")
	request.kind=Executor.Kind.STOP_FIRE_ABILITY;scene.submit_human_command(request)
	ability.process_requests()
	check(ability.spec.active and clock.playing and ability.spec.owns_attacking_tag(),"后续请求启动实际同一时钟")
	clock.advance(0.19);check(hits==0,"原12帧前无命中回调")
	clock.advance(0.02);check(hits==1,"原12帧任务回调一次，不声明伤害")
	slots.try_assign_formal_gas_ability_code_to_slot(1,20001)
	ability.advance_input(0.61);ability.process_requests()
	check(not ability.local_active and not ability.spec.active and not clock.playing and not ability.spec.has_attacking_tag(),"换槽不影响原实例完成与正式End")
	# 正式归一化动作入口，不调用旧诊断Q键桥，不默认启动第二时钟。
	ability.advance_input(0)
	slots.try_assign_formal_gas_ability_code_to_slot(1,20004)
	check(scene.bind_human_gameplay_actions(func():return {"actor":owner,"command_context":{"actor":owner,"issuer_kind":1}},func():return false,func(_q,_r):pass),"绑定正式归一化输入")
	check(ability.take_clock_tick_ownership(clock) and not ability.take_clock_tick_ownership(clock),"同一时钟只接管一次")
	check(scene.receive_human_gameplay_action("Gameplay","FireAbility2","performed")==Executor.Failure.NONE and ability.gate.is_charging(),"归一化按下抵达同一门控")
	check(scene.receive_human_gameplay_action("Gameplay","FireAbility2","canceled")==Executor.Failure.NONE and ability.spec.activate_requested and not clock.playing,"归一化释放仍仅投递请求")
	ability.process_requests();ability.advance_owned_clock(0.61)
	check(hits==2 and not clock.playing and ability.spec.active and ability.spec.end_requested,"唯一时钟自然终止只请求后续End")
	ability.process_requests()
	check(not ability.spec.active and not ability.spec.has_attacking_tag() and ability.local_active,"GAS结束不冒充本地门控完成")
	ability.advance_input(0.61);ability.process_requests()
	check(not ability.local_active and not ability.context.casting,"本地门控独立完成同实例回调")
	scene.free();control.free();await process_frame
	if failed==0: print("PASS resolved charged ability: %d checks" % n)
	quit(0 if failed==0 else 1)
