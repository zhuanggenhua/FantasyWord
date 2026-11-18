extends "res://tests/test_basic_training_timeline.gd"
## 验收真实 Entry 输入/槽位/形状链；设私有目录时使用锁定原四向图集和规则。
func run() -> void:
	var scene = Entry.instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var owner := FacingOwner.new()
	var control := ControlHost.new()
	root.add_child(control)
	var player := Player.new()
	player.actor = scene.actor
	var events := MapEvents.new()
	var directory := OS.get_environment("FORMAL_BASIC_BATCH")
	var source := not directory.is_empty()
	var pack: Array
	if source:
		pack = [read(directory.path_join("rules.json")),read(directory.path_join("animation-combat.json"))]
	else:
		directory = ProjectSettings.globalize_path("user://basic-combat-batch")
		pack = fixtures(scene,directory)
		for key in ["Attack","ChargedAttack","Dmg"]:
			var action: Dictionary = pack[1].actions.Idle.duplicate(true)
			action.duration = .75 if key=="ChargedAttack" else .5
			action.loop = false
			pack[1].actions[key] = action
	var view: Node2D = scene.start_human_presentation(pack[1],directory)
	if view==null or not scene.start_human_logic(owner,pack[0],func():return player,func():return null,events,func(_p):return false):
		printerr("实际玩家表现或逻辑未装配")
		quit(1)
		return
	check(scene.start_human_aim(owner,control) and scene.start_human_interaction(owner,func():pass),"玩家命令拥有者")
	var target_owner := TargetDirection.new()
	var target: Node2D = scene.start_training_damage_target(target_owner,target_owner.hooks(),7752)
	var target_data: Dictionary = read(directory.path_join("animation-trainer.json")) if source else pack[1].duplicate(true)
	if not source:
		target_data.training_target={"prefab_guid":target.VISUAL_PREFAB,
			"runtime_libraries":target.VISUAL_LIBRARIES,"body_local_position":[0,0]}
	var target_view: Node2D=scene.start_training_target_presentation(target_data,directory)
	check(is_instance_valid(target_view),"同一假人身体挂载受击动作")
	var caster := Attributes.new()
	check(caster.configure(PackedInt32Array([100,40,10,6,6,4,8,4,100]),Combat.Alignment.GOOD,
		func():return false,func():return false),"锁定原玩家属性")
	owner.set_look_at_direction(Vector2.RIGHT)
	scene.actor.request_move_position(Vector2(1.75,-2.35))
	await physics_frame
	await physics_frame
	await process_frame
	view.driver.set_process(false)
	target_view.driver.set_process(false)
	var slots:=Loadout.new(5)
	var rejected: Array=[]
	var charged: Node=scene.start_human_charged_training_combat(owner,slots,caster.stats,func():return 50,
		func(_t):return Vector3.ZERO,func(_t):return null,func(code,reason):rejected.append([code,reason]),true)
	if not is_instance_valid(charged):
		printerr("缺少真实双技能宿主")
		quit(1)
		return
	var basic: Node = charged.resolve(20001)
	check(is_instance_valid(basic) and basic.spec.attacking_tags == charged.spec.attacking_tags,"不同实例共享唯一角色标签")
	check(scene.bind_human_gameplay_actions(func():return {"actor":owner,"command_context":{"actor":owner,"issuer_kind":1}},
		func():return false,func(_r,_f):pass),"同一实际归一化动作入口")
	var press:=func(i):return scene.receive_human_gameplay_action("Gameplay","FireAbility%d" % i,"performed")
	var release:=func(i):return scene.receive_human_gameplay_action("Gameplay","FireAbility%d" % i,"canceled")
	press.call(1)
	check(not basic.gate.is_busy(),"未装备不默认出招")
	slots.try_assign_formal_gas_ability_code_to_slot(0,20001)
	slots.try_assign_formal_gas_ability_code_to_slot(1,20004)
	owner.set_target_direction(Vector2.UP)
	check(press.call(1)==Executor.Failure.NONE and owner.get_look_at_direction()==Vector2.RIGHT,"普攻起手不对请求方向自动转向")
	release.call(1)
	scene.advance_human_charged_combat(.2)
	check(not basic.spec.active and target.health==220 and not basic.local_active,"准备阶段松手不出招")
	check(press.call(1)==Executor.Failure.NONE,"重新按下可出招")
	scene.advance_human_charged_combat(.018)
	check(basic.spec.activate_requested and target.health==220,"过准备才提交，非同步激活")
	scene.advance_human_charged_combat(.04)
	check(basic.spec.owns_attacking_tag() and charged.spec.has_attacking_tag() and view.driver.current_animation_key=="Attack",
		"第2帧的实际表现与同角色攻击标签")
	check(press.call(2)==Executor.Failure.ABILITY_REJECTED and not charged.gate.is_charging(),
		"攻击期间另一个槽位真实被 3003 拦截")
	scene.advance_human_charged_combat(.08)
	check(target.health==220,"第8帧前不扣血")
	scene.advance_human_charged_combat(.02)
	check(target.health==206 and not target.body.is_pushed() and target_view.driver.current_animation_key=="Dmg",
		"实际输入经过原多边形、伤害、真实假人Dmg且无推力")
	check(scene.training_hit_cue.activation_count==1,"一次命中仅一个源Cue")
	release.call(1)
	scene.advance_human_charged_combat(0)
	check(not basic.spec.active and not basic.local_active and not charged.spec.has_attacking_tag()
		and view.driver.current_animation_key=="Idle","后摇松手按生命周期清理动作和自身标签")
	owner.set_target_direction(Vector2.RIGHT)
	check(press.call(2)==Executor.Failure.NONE and release.call(2)==Executor.Failure.NONE,"蓄力原有入口可继续执行")
	scene.advance_human_charged_combat(.21)
	check(target.health==184 and charged.spec.owns_attacking_tag(),"恢复普攻未破坏原蓄力伤害和标签")
	check(press.call(1)==Executor.Failure.ABILITY_REJECTED and not basic.gate.is_busy(),"蓄力激活反向拦截普通攻击")
	check(rejected.size()==2,"互斥两次均走真实命令拒绝回调")
	scene.free()
	control.free()
	await process_frame
	if failed==0: print("PASS ClickMoveTest 普攻与蓄力批次：%d 项（原图=%s）" % [n,str(source)])
	quit(0 if failed==0 else 1)
