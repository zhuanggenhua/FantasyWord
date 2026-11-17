extends "res://tests/test_clickmovetest_aim_pivot.gd"
const Loadout = preload("res://game_core/combat/equipped_ability_loadout.gd")
const Executor = preload("res://game_core/interaction/character_command_executor.gd")
func run() -> void:
	var slots := Loadout.new(5)
	check(slots.get_slot_count()==5 and slots.get_formal_gas_ability_code(-1)==0 and slots.get_formal_gas_ability_code(5)==0,"五槽和越界返回零")
	check(not slots.clear_slot(0) and not slots.try_auto_assign_formal_gas_ability_code(0),"空槽不清，零代码不分配")
	check(slots.try_auto_assign_formal_gas_ability_code(101) and slots.get_formal_gas_ability_code(0)==101,"自动找第一空槽")
	check(not slots.try_auto_assign_formal_gas_ability_code(101),"自动分配不重复")
	check(slots.try_assign_formal_gas_ability_code_to_slot(2,101) and slots.get_formal_gas_ability_code(0)==0,"指定槽移走首次旧占位")
	var snapshot := slots.create_slot_data_snapshot()
	snapshot[2].formalGasAbilityCode=999
	check(slots.get_formal_gas_ability_code(2)==101,"数据快照隔离")
	var view := slots.create_slot_view_snapshot()
	check(view[2].has_display_source and not view[0].has_formal_gas_ability,"展示快照只声明正代码")
	check(slots.restore_from_slot_data([null,{"slotIndex":1,"formalGasAbilityCode":102},{"slotIndex":1,"formalGasAbilityCode":0},{"slotIndex":3,"formalGasAbilityCode":102},{"slotIndex":9,"formalGasAbilityCode":999}]),"恢复原槽位数据")
	check(slots.get_formal_gas_ability_code(2)==0 and slots.get_formal_gas_ability_code(1)==102 and slots.get_formal_gas_ability_code(3)==102,"先清空，非正后项不覆盖，重复代码保留")
	check(slots.try_assign_formal_gas_ability_code_to_slot(4,102) and slots.get_formal_gas_ability_code(1)==0 and slots.get_formal_gas_ability_code(3)==102,"指定赋值只清第一个其它同码槽")
	check(slots.remove_formal_gas_ability_code_from_all_slots(102) and not slots.contains_formal_gas_ability_code(102),"删除同码的所有槽")
	check(not slots.restore_from_slot_data([{"wrong":1}]) and slots.get_formal_gas_ability_code(0)==0,"未知输入形状不转索引零")
	for code in range(1,6): check(slots.try_auto_assign_formal_gas_ability_code(code),"逐个空槽")
	check(not slots.try_auto_assign_formal_gas_ability_code(6),"满槽拒绝自动分配")
	check(slots.restore_from_slot_data(null) and slots.get_formal_gas_ability_code(0)==0,"空恢复清全部")

	var scene = Entry.instantiate(); root.add_child(scene)
	var control := ControlHost.new();root.add_child(control)
	var owner := Owner.new();var player := Player.new();player.actor=scene.actor;var events:=MapEvents.new()
	var private_dir := OS.get_environment("FORMAL_HUMAN_PRIVATE")
	var directory := ProjectSettings.globalize_path("user://slot-test")
	var data: Array
	if private_dir.is_empty(): data=fixtures(scene,directory)
	else:
		directory=private_dir.path_join("private-human-source")
		data=[read(private_dir.path_join("private-clickmove-audit/rules.json")),read(private_dir.path_join("private-formal-human-verification/animation-final.json"))]
	check(scene.start_human_presentation(data[1],directory)!=null and scene.start_human_logic(owner,data[0],func():return player,func():return null,events,func(_p):return false),"真实角色原生入口启动")
	check(scene.start_human_aim(owner,control) and scene.start_human_interaction(owner,func():pass),"同一角色和交互宿主")
	var a:=RefCounted.new();var b:=RefCounted.new()
	var runtime: Dictionary={101:a,102:b}
	var resolved: Array=[];var fired: Array=[];var stopped: Array=[];var rejected: Array=[]
	var result: Array=[0]
	check(scene.start_human_equipped_abilities(owner,slots,
		func(code):resolved.append(code);return runtime.get(code),
		func(ability,context,activation):fired.append([ability,context,activation]);return result[0],
		func(ability):stopped.append(ability),
		func(_target):return Vector3.ZERO,func(_target):return null,
		func(code,reason):rejected.append([code,reason])),"将槽位解析接入原命令链")
	await process_frame
	var context: Dictionary={"actor":owner,"original":17}
	var request: Dictionary={"kind":Executor.Kind.FIRE_ABILITY,"ability_index":0,"actor":owner,"command_context":context,"direction":Vector2(1,0)}
	check(scene.submit_human_command(request)==Executor.Failure.MISSING_ABILITY and resolved.is_empty() and fired.is_empty() and rejected.is_empty(),"空槽不解析，不发拒绝通知")
	slots.try_assign_formal_gas_ability_code_to_slot(0,101)
	check(scene.submit_human_command(request)==Executor.Failure.NONE and fired[0][0]==a and fired[0][1]==context,"命令交付实际已解析对象和原上下文")
	check(fired[0][2].try_get_aim_direction().direction==Vector3.RIGHT,"原激活上下文仍由当前角色入口构造")
	result[0]=1
	check(scene.submit_human_command(request)==Executor.Failure.ABILITY_REJECTED and rejected==[[101,1]],"已解析但冷却拒绝保留原正代码")
	slots.try_assign_formal_gas_ability_code_to_slot(0,102)
	request.kind=Executor.Kind.STOP_FIRE_ABILITY
	check(scene.submit_human_command(request)==Executor.Failure.NONE and stopped==[b],"松手重新读取当前槽，不停之前技能")
	runtime.erase(102)
	check(scene.submit_human_command(request)==Executor.Failure.MISSING_ABILITY and stopped==[b],"停止时运行时实例丢失不伪成功")
	request.kind=Executor.Kind.FIRE_ABILITY
	check(scene.submit_human_command(request)==Executor.Failure.MISSING_ABILITY and rejected==[[101,1]],"未解析代码回零而非能力拒绝")
	var held_dispatch: WeakRef = weakref(scene._equipped_ability_dispatch)
	check(held_dispatch.get_ref()!=null,"绑定持有分派对象，跨帧不被回收")
	check(not scene.start_human_abilities(owner,Callable(),Callable(),func(_t):return Vector3.ZERO,func(_t):return null,func(_c,_r):pass) and held_dispatch.get_ref()!=null,"失败重绑定不拆当前槽位宿主")
	check(scene.start_human_abilities(owner,func(_i,_c,_a):return {"has_ability_source":false,"result":4,"formal_gas_ability_code":0},func(_i):return false,func(_t):return Vector3.ZERO,func(_t):return null,func(_c,_r):pass) and held_dispatch.get_ref()==null,"成功切回显式能力宿主释放原槽位分派")
	scene.free();control.free()
	await process_frame
	if failed==0: print("PASS equipped ability loadout and native command: %d checks" % n)
	quit(0 if failed==0 else 1)
