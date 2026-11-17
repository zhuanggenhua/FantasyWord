extends "res://tests/test_resolved_ability_fire.gd"
const Attributes = preload("res://gameplay/clickmovetest/training_damage_attributes.gd")
const Combat = preload("res://game_core/combat/combat_rules.gd")
class TargetMotion extends RefCounted:
	var destroyed := false
	var dead := false
	var invincible := false
	var trace: Array = []
	func can_move() -> bool: return not dead
	func calculate_move_speed() -> float: return 4
	func calculate_speed_multiplier() -> float: return 1
	func update_movement_animation(_v: Vector2) -> void: pass
	func update_facing_from_intent(_v: Vector2) -> void: pass
	func register_collision(_obj: Object) -> void: pass
	func read_destroyed(): return destroyed
	func read_dead(): return dead
	func read_invincible(): return invincible
	func provoke(source): trace.append(["provoke",source])
	func prepare(_source, input): trace.append(["prepare",input.damage])
	func complete(_source, _input, previous, applied): trace.append(["complete",previous,applied])
	func interrupt_actions(): trace.append("interrupt")
	func mark_death():
		dead = true
		trace.append("death")
	func hooks() -> Dictionary:
		return {"is_destroyed":read_destroyed,"is_dead":read_dead,"is_invincible":read_invincible,
			"provoke":provoke,"prepare":prepare,"complete":complete,
			"interrupt_actions":interrupt_actions,"mark_death":mark_death}

func run() -> void:
	var scene = Entry.instantiate()
	root.add_child(scene)
	var control := ControlHost.new()
	root.add_child(control)
	var owner := FacingOwner.new()
	var player := Player.new()
	player.actor=scene.actor
	var events := MapEvents.new()
	var native_target := TargetMotion.new()
	var directory := ProjectSettings.globalize_path("user://training-damage")
	var pack: Array
	var asset_dir := OS.get_environment("FORMAL_CHARGED_HUMAN")
	var private_dir := OS.get_environment("FORMAL_HUMAN_PRIVATE")
	if not asset_dir.is_empty() and not private_dir.is_empty():
		directory = asset_dir
		pack=[read(private_dir.path_join("private-clickmove-audit/rules.json")),read(directory.path_join("animation-charged.json"))]
	else:
		pack=fixtures(scene,directory)
		var animation: Dictionary=pack[1].actions.Idle.duplicate(true)
		animation.duration=0.75
		animation.loop=false
		pack[1].actions["ChargedAttack"]=animation
	var view: Node2D=scene.start_human_presentation(pack[1],directory)
	if view==null or not scene.start_human_logic(owner,pack[0],func():return player,func():return null,events,func(_p):return false):
		printerr("未能启动训练假人受击入口")
		scene.free()
		control.free()
		quit(1)
		return
	scene.set_process(false)
	check(scene.start_human_aim(owner,control) and scene.start_human_interaction(owner,func():pass),"原生玩家命令拥有者")
	check(scene.start_training_damage_target(native_target,{},7752)==null,"无控制生命周期不能装配")
	var target: Node2D=scene.start_training_damage_target(native_target,native_target.hooks(),7752)
	check(is_instance_valid(target),"装配源场景活动训练假人")
	if not is_instance_valid(target):
		scene.free()
		control.free()
		quit(1)
		return
	check(scene.start_training_damage_target(native_target,native_target.hooks(),7752)==null,"不创建第二个场景活动假人")
	check(target.get_movement_position()==Vector2(2.5,-2.75) and target.health==220,"原始出生点及220生命")
	check(target.body.collision_layer==256 and target.hitbox.collision_layer==128,"身体与受击盒不是同层")
	check(target.stats.alignment==Combat.Alignment.EVIL and target.stats.snapshot.physical_defense==0,
		"属性快照来自源假人表")
	check(scene.training_attributes.max_health()==220 and scene.training_attributes.apply_current_health_delta(1,0,null,null)==null,
		"不代替治疗或上限")
	var caster := Attributes.new()
	check(caster.configure(PackedInt32Array([100,40,10,6,6,4,8,4,100]),Combat.Alignment.GOOD,
		func():return false,func():return false),"锁定原玩家初值供当前测试的属性拥有者")
	scene.actor.request_move_position(Vector2(1.75,-2.35))
	await physics_frame
	await physics_frame
	await process_frame
	check(scene.actor.get_movement_position().is_equal_approx(Vector2(1.75,-2.35)),"测试布置使真实世界命中盒够得到")
	owner.set_target_direction(Vector2.RIGHT)
	var slots:=Loadout.new(5)
	var ability: Node=scene.start_human_charged_training_combat(owner,slots,caster.stats,func():return 50,
		func(_t):return Vector3.ZERO,func(_t):return null,func(_code,_error):pass)
	check(is_instance_valid(ability),"接通 20004 与真实场景受击者")
	if not is_instance_valid(ability):
		scene.free()
		control.free()
		quit(1)
		return
	check(scene.bind_human_gameplay_actions(func():return {"actor":owner,"command_context":{"actor":owner,"issuer_kind":1}},
		func():return false,func(_r,_f):pass),"通过既有归一化玩法动作")
	var press := func():return scene.receive_human_gameplay_action("Gameplay","FireAbility2","performed")
	var release := func():return scene.receive_human_gameplay_action("Gameplay","FireAbility2","canceled")
	press.call()
	check(not ability.gate.is_charging(),"不默认装备20004")
	slots.try_assign_formal_gas_ability_code_to_slot(1,20004)
	check(press.call()==Executor.Failure.NONE and release.call()==Executor.Failure.NONE,"实际进入蓄力释放")
	scene.advance_human_charged_combat(.19)
	check(target.health==220 and native_target.trace.is_empty(),"第12帧前无负伤")
	var previous: Vector2=target.get_movement_position()
	scene.advance_human_charged_combat(.02)
	check(target.health==198 and scene.training_attributes.max_health()==220,"原数值伤害 7+10×1.5，220→198")
	check(native_target.trace.size()==3 and native_target.trace[1]==["prepare",22] and native_target.trace[2]==["complete",220,22],
		"实际结算回调顺序与扣减")
	check(target.body.is_pushed() and target.lifecycle.pending_interrupt,"唯一原生推力与延迟打断")
	target.advance_damage_lifecycle()
	check(native_target.trace.back()=="interrupt" and not target.lifecycle.pending_interrupt,"安全阶段执行一次打断")
	await physics_frame
	await physics_frame
	await physics_frame
	check(target.get_movement_position().x>previous.x,"原生运动步实际推进假人物理身体")
	scene.advance_human_charged_combat(.7)
	scene.advance_human_charged_combat(0)
	check(target.health==198 and not ability.spec.active and not ability.local_active,"收招仅结算一次")
	var hits: Array=[]
	scene.training_attributes.current_health_changed.connect(func(a,b,_s):hits.append([a,b]))
	check(scene.training_attributes.apply_current_health_delta(-400,0,null,caster.stats())==0 and hits==[[198,0]],
		"同一实际生命属性下限与真实变更信号")
	check(scene.training_attributes.apply_current_health_delta(-1,0,null,caster.stats())==0 and hits==[[198,0]],
		"钳制后无有效增量不重复变更")
	scene.stop_human_aim()
	scene.free()
	control.free()
	await process_frame
	if failed==0: print("PASS ClickMoveTest 训练假人实际受击流程：%d 项" % n)
	quit(0 if failed==0 else 1)
