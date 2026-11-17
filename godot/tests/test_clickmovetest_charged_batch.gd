extends "res://tests/test_resolved_ability_fire.gd"
## 组合验证必须从正式 Entry、Actor、原生动画驱动和有主人的物理目标经过。
## 公开分支只验证引擎接线，私有分支另外核实源图集与导航；不伪造正式存档装配。
const Hit = preload("res://gameplay/combat/charged_attack_hit.gd")
const Combat = preload("res://game_core/combat/combat_rules.gd")
const Apply = preload("res://game_core/combat/formal_damage_application.gd")
const Diagnostic = preload("res://validation/scenes/charged_attack_fixture.gd")
var hit_frames := 0
var target: Diagnostic.Actor
var effects: Array = []
var exact_owner: Object
var native_caster: Node2D

func _role_stats(attack: int, defense: int) -> Dictionary:
	return {"snapshot":{"physical_attack":attack,"physical_defense":defense,"magical_attack":0,"magical_defense":0,"luck":0,"agility":0},"dead":false,"invincible":false}

func _hit() -> void:
	hit_frames += 1
	var point: Vector2 = native_caster.get_movement_position()
	var result: Dictionary = Hit.run(native_caster.get_world_2d(), native_caster, point, exact_owner.get_look_at_direction(),
		func(collider): return collider.get_meta("actor",null),
		func(caster, receiver, effect_id):
			effects.append([caster,receiver,effect_id])
			var descriptor := {"flat_damage":7,"scale":1.5,"damage_type":Combat.DamageType.PHYSICAL,
				"critical_behavior":Combat.Resolution.DEFAULT,"miss_behavior":Combat.Resolution.DEFAULT,
				"ignore_defense":false,"silent":false}
			var output := Combat.solve_damage_output(_role_stats(10,0),descriptor,true,func():return 50)
			Apply.execute_damage_output(receiver.stats,output,true,func():return 50,receiver.hooks(),receiver.source_position()-point))
	check(result.ok,"实际世界命中组件可用")

func run() -> void:
	var scene=Entry.instantiate()
	root.add_child(scene)
	var control:=ControlHost.new()
	root.add_child(control)
	var owner:=FacingOwner.new()
	exact_owner=owner
	native_caster=scene.actor
	var player:=Player.new()
	player.actor=scene.actor
	var events:=MapEvents.new()
	var directory:=ProjectSettings.globalize_path("user://charged-batch")
	var pack: Array
	var private_path:=OS.get_environment("FORMAL_CHARGED_HUMAN")
	var private_root:=OS.get_environment("FORMAL_HUMAN_PRIVATE")
	if not private_path.is_empty() and not private_root.is_empty():
		directory=private_path
		pack=[read(private_root.path_join("private-clickmove-audit/rules.json")),read(directory.path_join("animation-charged.json"))]
	else:
		pack=fixtures(scene,directory)
		var action: Dictionary=pack[1].actions.Idle.duplicate(true)
		action.duration=0.75
		action.loop=false
		pack[1].actions["ChargedAttack"]=action
	var presentation: Node2D=scene.start_human_presentation(pack[1],directory)
	if presentation==null or not scene.start_human_logic(owner,pack[0],func():return player,func():return null,events,func(_p):return false):
		printerr("正式组合验证未能启动 ClickMoveTest。")
		scene.free()
		control.free()
		quit(1)
		return
	scene.set_process(false)
	presentation.animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	check(scene.start_human_aim(owner,control) and scene.start_human_interaction(owner,func():pass),"绑定实际角色的命令拥有者")
	owner.set_target_direction(Vector2.RIGHT)
	# 用既有诊断目标属性和 Hitbox 族验证真实命中，不声明此目标为正式存档默认演员。
	target=Diagnostic.Actor.new()
	target.position=scene.actor.global_position + Vector2(0.75,-0.15)
	target.health=50
	target.max_health=50
	target.stats=_role_stats(0,2)
	target.facing=Vector2.LEFT
	scene.add_child(target)
	await physics_frame
	await physics_frame
	var slots:=Loadout.new(5)
	var pos:=func(_target):return Vector3.ZERO
	var cell:=func(_target):return null
	var rejected:=func(_code,_result):pass
	var ability: Node=scene.start_human_charged_combat(owner,slots,_hit,pos,cell,rejected)
	check(is_instance_valid(ability),"显式装配一个真实 20004 与实际 Actor/驱动")
	if not is_instance_valid(ability):
		scene.free()
		control.free()
		quit(1)
		return
	check(scene.start_human_charged_combat(owner,slots,_hit,pos,cell,rejected)==null,"禁止抢占已经绑定的实例")
	check(scene.bind_human_gameplay_actions(func():return {"actor":owner,"command_context":{"actor":owner,"issuer_kind":1}},func():return false,func(_r,_f):pass),"使用正常归一化 Gameplay 入口")
	await process_frame
	var press:=func():return scene.receive_human_gameplay_action("Gameplay","FireAbility2","performed")
	var release:=func():return scene.receive_human_gameplay_action("Gameplay","FireAbility2","canceled")
	press.call()
	check(not ability.local_active and not ability.gate.is_charging(),"没有默认装备；入口不制造技能授予")
	slots.try_assign_formal_gas_ability_code_to_slot(1,20004)
	check(press.call()==Executor.Failure.NONE and ability.gate.is_charging(),"显式槽位通过正常动作链进入蓄力")
	check(presentation.driver.current_animation_key=="Idle" and hit_frames==0,"蓄力未开始释放动作")
	check(release.call()==Executor.Failure.NONE and ability.spec.activate_requested and not ability.spec.active,"松手只排队")
	ability.spec.set_fixed_attacking(true)
	scene.advance_human_charged_combat(0.1)
	check(not ability.spec.active and not ability.spec.activate_requested and hit_frames==0 and target.health==50 and presentation.driver.current_animation_key=="Idle","晚拒绝不触发播放或命中")
	scene.advance_human_charged_combat(0.6)
	scene.advance_human_charged_combat(0)
	ability.spec.set_fixed_attacking(false)
	check(not ability.local_active and not ability.context.casting,"失败后独立门控清理")
	check(press.call()==Executor.Failure.NONE and release.call()==Executor.Failure.NONE,"同一角色再次释放")
	scene.advance_human_charged_combat(0.02)
	check(ability.spec.active and presentation.driver.current_animation_key=="Idle","逻辑更新激活但帧2之前不播放")
	scene.advance_human_charged_combat(0.02)
	check(presentation.driver.current_animation_key=="ChargedAttack" and presentation.playback.current_label==0,"实际驱动显示阶段开始作者动作")
	presentation.animator.advance(0.14)
	if not private_path.is_empty():
		check(presentation.playback.current_label==1 and presentation.sprite.texture is AtlasTexture,"实际原图集在显示驱动推进到第二个精灵")
	presentation.set_movement(Vector2.RIGHT)
	check(presentation.driver.current_animation_key=="ChargedAttack","记录新 locomotion 不抢占正在播放的动作")
	scene.advance_human_charged_combat(0.15)
	check(hit_frames==0 and target.health==50,"第12帧之前保持无命中")
	scene.advance_human_charged_combat(0.02)
	check(hit_frames==1 and effects==[[native_caster,target,2004]],"第12帧用实际持有者和原生 Hitbox 派发一次 2004")
	check(target.health==29 and target.max_health==50 and target.push_requests==1,"既有伤害/推力拥有者实测 50→29，最大生命不变")
	scene.advance_human_charged_combat(0.31)
	check(presentation.driver.current_animation_key=="Walk","Cue结束恢复最新移动动作")
	scene.advance_human_charged_combat(0.11)
	scene.advance_human_charged_combat(0)
	check(not ability.spec.active and not ability.local_active and hit_frames==1,"自然结束与本地结束均完成，无重复命中")
	presentation.set_movement(Vector2.ZERO)
	check(press.call()==Executor.Failure.NONE and release.call()==Executor.Failure.NONE,"第三次释放")
	scene.advance_human_charged_combat(0.52)
	check(hit_frames==2 and presentation.driver.current_animation_key=="Idle","同次逻辑追帧已越过Cue创建和移除，不补播旧动作")
	scene.stop_human_aim()
	check(scene._charged_timeline==null and scene._equipped_ability_dispatch==null,"场景宿主解除唯一组合")
	scene.free()
	control.free()
	await process_frame
	if failed==0: print("PASS ClickMoveTest charged batch: %d checks" % n)
	quit(0 if failed==0 else 1)
