extends "res://tests/test_clickmovetest_aim_pivot.gd"
const Loadout = preload("res://game_core/combat/equipped_ability_loadout.gd")
const Executor = preload("res://game_core/interaction/character_command_executor.gd")
const Activation = preload("res://game_core/interaction/ability_activation_context.gd")
class FacingOwner extends Owner:
	var calls: Array=[]
	func set_target_direction(v: Vector2) -> void:
		calls.append("target")
		super.set_target_direction(v)
	func get_target_direction() -> Vector2:
		calls.append("read")
		return super.get_target_direction()
	func set_look_at_direction(v: Vector2) -> void:
		calls.append("look")
		state.set_look_at_direction(v)
class AbilityHost extends RefCounted:
	var calls: Array=[]
	var result := 0
	var look := true
	var automatic := true
	var completion: Variant
	var fired: Array=[]
	func can_fire(a: Object) -> int: calls.append(["can",a]);return result
	func should_update_look_at_direction_on_fire(a: Object) -> bool: calls.append(["look",a]);return look
	func uses_automatic_runtime_state_management(a: Object) -> bool: calls.append(["auto",a]);return automatic
	func set_ability_active(a: Object,v: bool) -> void: calls.append(["active",a,v])
	func fire(a: Object,c: Variant,x: Variant,done: Variant) -> void:
		calls.append(["fire",a]);fired=[a,c,x];completion=done
	func stop_fire(a: Object) -> void: calls.append(["stop",a])
func run() -> void:
	var scene = Entry.instantiate();root.add_child(scene)
	var control:=ControlHost.new();root.add_child(control)
	var owner:=FacingOwner.new();var player:=Player.new();player.actor=scene.actor;var events:=MapEvents.new()
	var directory:=ProjectSettings.globalize_path("user://resolved-test")
	var data: Array
	var private_dir:=OS.get_environment("FORMAL_HUMAN_PRIVATE")
	if private_dir.is_empty(): data=fixtures(scene,directory)
	else:
		directory=private_dir.path_join("private-human-source")
		data=[read(private_dir.path_join("private-clickmove-audit/rules.json")),read(private_dir.path_join("private-formal-human-verification/animation-final.json"))]
	check(scene.start_human_presentation(data[1],directory)!=null and scene.start_human_logic(owner,data[0],func():return player,func():return null,events,func(_p):return false),"同一原生角色启动")
	check(scene.start_human_aim(owner,control) and scene.start_human_interaction(owner,func():pass),"同一角色命令宿主")
	var slots:=Loadout.new(5);slots.try_assign_formal_gas_ability_code_to_slot(0,20001)
	var ability:=RefCounted.new();var second:=RefCounted.new();var runtime: Dictionary={20001:ability,20002:second}
	var host:=AbilityHost.new();var rejected: Array=[]
	check(scene.start_human_resolved_equipped_abilities(owner,slots,func(code):return runtime.get(code),host,func(_t):return Vector3.ZERO,func(_t):return null,func(code,result):rejected.append([code,result])),"绑定真实槽位到 resolved 流程")
	await process_frame
	var context: Dictionary={"actor":owner,"marker":37}
	var request: Dictionary={"kind":Executor.Kind.FIRE_ABILITY,"ability_index":0,"actor":owner,"command_context":context,"direction":Vector2(3,4)}
	host.result=1;owner.calls.clear();host.calls.clear()
	check(scene.submit_human_command(request)==Executor.Failure.ABILITY_REJECTED and rejected==[[20001,1]],"CanFire 拒绝保留代码")
	check(host.calls==[["can",ability]] and not owner.calls.has("target") and not owner.calls.has("look"),"拒绝不读 flags 不改方向不激活")
	host.result=0;owner.calls.clear();host.calls.clear()
	check(scene.submit_human_command(request)==Executor.Failure.NONE,"真实命令 Fire")
	check(owner.get_target_direction().is_equal_approx(Vector2(0.6,0.8)) and owner.get_look_at_direction().is_equal_approx(Vector2(0.6,0.8)),"XY 归一方向写同一 owner")
	check(host.calls==[["can",ability],["look",ability],["auto",ability],["active",ability,true],["fire",ability]],"自动启用在 Fire 前且同一实例")
	check(host.fired[0]==ability and host.fired[1]==context and host.fired[2] is Activation,"原上下文透传")
	slots.try_assign_formal_gas_ability_code_to_slot(0,20002)
	host.completion.call()
	check(host.calls.back()==["active",ability,false],"结束关闭原实例而非当前槽")
	host.completion=null
	slots.try_assign_formal_gas_ability_code_to_slot(0,20001)
	var dispatch=scene._equipped_ability_dispatch
	owner.allow_aim=false;owner.state.set_look_at_direction(Vector2.LEFT);owner.calls.clear()
	dispatch.fire(0,context,Activation.new(Vector3.ZERO,null,Vector3.RIGHT))
	check(owner.get_target_direction().is_equal_approx(Vector2(0.6,0.8)) and owner.get_look_at_direction()==Vector2.RIGHT,"目标 gate 拒绝但独立请求仍更新 look")
	check(owner.calls.slice(0,3)==["target","read","look"],"有请求仍先读取当前 target")
	host.look=false;owner.allow_aim=true;owner.state.target_based=true
	dispatch.fire(0,context,Activation.new(Vector3.ZERO,null,Vector3.UP))
	check(owner.get_look_at_direction()==Vector2(0,1),"不要求转向仍保留 TargetBased setter 副作用")
	host.automatic=false;host.calls.clear()
	dispatch.fire(0,context,null)
	check(host.completion==null and host.calls==[["can",ability],["look",ability],["auto",ability],["fire",ability]],"手动分支不激活，传 null 完成回调")
	host.look=true;owner.state.target_based=false;owner.calls.clear()
	dispatch.fire(0,context,Activation.new(Vector3.ZERO,null,Vector3(0,0,1)))
	check(not owner.calls.has("target") and owner.calls==["read","look"],"纯 Z 请求不写目标，look 使用已有目标")
	owner.state.set_target_direction(Vector2.ZERO,true);owner.calls.clear()
	dispatch.fire(0,context,null)
	check(owner.calls==["read"],"零目标不写 look")
	owner.calls.clear()
	dispatch.fire(0,context,Activation.new(Vector3.ZERO,null,Vector3(0.01,0,1)))
	check(owner.calls==["read"],"三维合法但 XY 小于原阈值不更新")
	owner.calls.clear()
	dispatch.fire(0,context,Activation.new(Vector3.ZERO,null,Vector3(0.011,0,1)))
	check(owner.calls==["target","read","look"] and owner.get_target_direction()==Vector2.RIGHT,"XY 超过阈值后单独归一化，不沿用三维长度")
	host.automatic=true
	dispatch.fire(0,context,null)
	var completion: Callable=host.completion
	host.completion=null
	runtime.erase(20001)
	ability=null
	host.calls.clear();host.fired.clear()
	completion.call()
	check(host.calls.is_empty(),"结束回调不持有已释放能力，不找替代实例")
	host.calls.clear();control.local=false
	check(scene.submit_human_command(request)==Executor.Failure.MISSING_INPUT_TARGET and host.calls.is_empty(),"非当前操控角色不能调用能力")
	control.local=true
	request.kind=Executor.Kind.STOP_FIRE_ABILITY;slots.try_assign_formal_gas_ability_code_to_slot(0,20002)
	check(scene.submit_human_command(request)==Executor.Failure.NONE and host.calls==[["stop",second]],"Stop 仍重读当前槽")
	host.completion=null;dispatch=null;scene.free();control.free()
	await process_frame
	if failed==0: print("PASS resolved ability fire: %d checks" % n)
	quit(0 if failed==0 else 1)
