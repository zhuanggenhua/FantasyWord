extends "res://tests/test_resolved_ability_fire.gd"
const Attributes = preload("res://gameplay/clickmovetest/training_damage_attributes.gd")
const Combat = preload("res://game_core/combat/combat_rules.gd")
class TargetMotion extends RefCounted:
	signal look_at_direction_changed(value: Vector2)
	var look_at := Vector2.DOWN
	var destroyed := false
	var dead := false
	var invincible := false
	var trace: Array = []
	func can_move() -> bool: return true # movement permission now changes on the real target
	func calculate_move_speed() -> float: return 4
	func calculate_speed_multiplier() -> float: return 1
	func update_movement_animation(_v: Vector2) -> void: pass
	func update_facing_from_intent(_v: Vector2) -> void: pass
	func get_look_at_direction() -> Vector2: return look_at
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
	var target_dir := directory
	var target_animation: Dictionary
	if not asset_dir.is_empty() and not private_dir.is_empty():
		target_dir = private_dir.path_join("private-human-source")
		target_animation = read(private_dir.path_join("private-dmg-verification/trainer-animation.json"))
	else:
		target_animation = pack[1].duplicate(true)
		var dmg: Dictionary = target_animation.actions.Idle.duplicate(true)
		dmg.duration = .5
		dmg.loop = false
		target_animation.actions["Dmg"] = dmg
		target_animation.training_target = {"prefab_guid":target.VISUAL_PREFAB,
			"runtime_libraries":target.VISUAL_LIBRARIES,"body_local_position":[0,0]}
	var exact_death := OS.get_environment("FORMAL_TRAINER_DEATH")
	var exact_material := OS.get_environment("FORMAL_TRAINER_DEATH_MATERIAL")
	if not exact_death.is_empty():
		target_dir = exact_death
		target_animation = read(exact_death.path_join("animation-trainer-death.json"))
	var material_package := {}
	if not exact_material.is_empty():
		material_package = {"data":read(exact_material.path_join("material-trainer-death.json")),
			"uv_directory":exact_material.path_join("uv"),"appearance_directory":exact_material.path_join("appearance")}
		var wrong_material := material_package.duplicate(true)
		wrong_material.data.erase("training_target")
		check(scene.start_training_target_presentation(target_animation,target_dir,wrong_material)==null,
			"同名 Human 动作不能代替训练假人的原材质合同")
		wrong_material = material_package.duplicate(true)
		wrong_material.data.actions.SpinDie.frames.pop_back()
		check(scene.start_training_target_presentation(target_animation,target_dir,wrong_material)==null,
			"缺少末帧配置时不静默降级直显，也不保留无效表现")
	var wrong_target := target_animation.duplicate(true)
	wrong_target.erase("training_target")
	check(scene.start_training_target_presentation(wrong_target,target_dir)==null,
		"相同动画名不代表原训练假人绑定")
	var target_view: Node2D = scene.start_training_target_presentation(target_animation,target_dir,material_package)
	check(is_instance_valid(target_view),"同一假人身体挂载原动作表现")
	if not is_instance_valid(target_view):
		scene.free()
		control.free()
		quit(1)
		return
	check(target_view.get_parent()==target.body and target_view.position==Vector2.ZERO and target_view.driver.current_animation_key=="Idle",
		"不把表现偏到碰撞中心，不提前播放 Dmg")
	var idle_body_map: Texture2D
	if not material_package.is_empty():
		var material: ShaderMaterial = target_view.sprite.material
		idle_body_map = material.get_shader_parameter("body_map")
		check(material != null and idle_body_map.get_size()==Vector2(512,128),
			"同一假人启动时就绑定原 Idle 材质，未替换人物或丢失外观")
	elif not asset_dir.is_empty() and exact_death.is_empty():
		var material := read(private_dir.path_join("private-dmg-verification/material.json"))
		check(target_view.bind_base_material(material,target_dir,private_dir.path_join("private-formal-player-appearance")),
			"同一原训练假人绑定原 UV 和无装备初始外观")
	target_view.animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	target_view.driver.set_process(false)
	var damage_trace: Array = []
	target_view.driver.animation_selected.connect(func(key):
		if key=="Dmg": damage_trace.append([target.health,scene.training_hit_cue.activation_count]))
	check(scene.training_attributes.max_health()==220 and scene.training_attributes.apply_current_health_delta(1,0,null,null)==null,
		"不代替治疗或上限")
	var caster := Attributes.new()
	check(caster.configure(PackedInt32Array([100,40,10,6,6,4,8,4,100]),Combat.Alignment.GOOD,
		func():return false),"锁定原玩家初值供当前测试的属性拥有者")
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
	check(damage_trace==[[220,0]] and target_view.driver.current_animation_key=="Dmg","Dmg 在提交生命变更前真实播放")
	check(scene.training_hit_cue.activation_count==1 and scene.training_hit_cue.last_activation.cue_id==20001
		and not scene.training_hit_cue.last_activation.feedback_slot_configured,"耗用瞬时效果后 Display 处理真实 20001 空槽")
	var first_dmg: Texture2D = target_view.sprite.texture
	target_view.animator.advance(.14)
	if not asset_dir.is_empty():
		check(target_view.playback.current_label==1 and target_view.sprite.texture is AtlasTexture
			and target_view.sprite.texture!=first_dmg,"原 Dmg 图集帧随实际 AnimationPlayer 改变")
	target_view.driver.advance_game_time(.49)
	check(target_view.driver.current_animation_key=="Dmg","恢复不能提前")
	target_view.driver.advance_game_time(.02)
	check(target_view.driver.current_animation_key=="Idle","原 .5 秒 Dmg 自然恢复 Idle")
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
	check(target.health==198 and not ability.spec.active and not ability.local_active and scene.training_hit_cue.activation_count==1,
		"收招不重复结算或播放已用 Cue")
	var hits: Array=[]
	scene.training_attributes.current_health_changed.connect(func(a,b,_s):hits.append([a,b]))
	# Stage a living target at one hit from death, then use the same actual
	# normalized action/timeline/effect route to drive the fatal subtraction.
	check(scene.training_attributes.apply_current_health_delta(-176,0,null,caster.stats())==22,
		"测试先将实际生命置为一次蓄力可击倒")
	target.body.request_move_position(Vector2(2.5,-2.75))
	await physics_frame
	await process_frame
	check(press.call()==Executor.Failure.NONE and release.call()==Executor.Failure.NONE,
		"第二次仍经正式归一化输入")
	scene.advance_human_charged_combat(.21)
	check(target.health==0 and hits==[[198,22],[22,0]] and target.lifecycle.pending_death,
		"实际致命效果记录正式生命变化，延迟处理死亡")
	check(target.stats.dead and target.stats.invincible and not native_target.dead and is_instance_valid(target.body),
		"原 dead 当场读零血，死亡收尾仍待安全阶段")
	var trace_before := native_target.trace.duplicate()
	scene._execute_training_damage(scene.actor,target,caster.stats,func():return 50)
	check(native_target.trace==trace_before and hits.size()==2,
		"同帧后续有来源攻击不再唤起受击或扣血")
	target.body.move_to(Vector2(5,-2.75))
	check(target.body.execution.has_move_order(),"安全阶段前存在真实待完成的移动命令")
	var prior_count := native_target.trace.size()
	target.advance_damage_lifecycle()
	target.advance_damage_lifecycle()
	check(native_target.trace.slice(prior_count)==["interrupt","death"] and native_target.dead
		and not target.lifecycle.pending_death and is_instance_valid(target.body),
		"安全阶段先打断再进入宿主死亡回调，重复推进不重放，不擅自删除 Actor")
	check(not target.can_move() and not target.body.execution.has_move_order(),
		"保留 Actor 身体但停止其自发移动")
	if not exact_death.is_empty():
		check(target_view.driver.locked_key=="SpinDie" and target_view.playback.current_label==0,
			"正式死亡安全阶段锁定原 SpinDie，不等动画结束才回调")
		var death_material: ShaderMaterial = target_view.sprite.material
		if not material_package.is_empty():
			var body_map: Texture2D = death_material.get_shader_parameter("body_map")
			var head_map: Texture2D = death_material.get_shader_parameter("head_map")
			check(body_map!=idle_body_map and body_map.get_size()==Vector2(384,32)
				and head_map.get_size()==Vector2(384,32)
				and death_material.get_shader_parameter("main_map")==target_view.sprite.texture.atlas,
				"进入死亡时本体及两张原 UV 一同切换到 384×32 单行动作")
		target_view.animator.advance(0.65)
		check(target_view.playback.current_label==5 and target_view.sprite.texture is AtlasTexture,
			"实际 AnimationPlayer 进入原 8 FPS SpinDie 第5帧")
		if not material_package.is_empty():
			var sampled: AtlasTexture = target_view.sprite.texture
			check(sampled.region==Rect2(160,0,32,32)
				and death_material.get_shader_parameter("enabled_hair")
				and death_material.get_shader_parameter("enabled_beard")
				and death_material.get_shader_parameter("enabled_eye_decoration"),
				"实际第 5 帧采样第 0 行，使用作者头部朝向与原基础外观")
			var same_sprite := true
			for facing in range(4):
				target_view.playback.set_direction(facing)
				same_sprite = same_sprite and target_view.sprite.texture==sampled
			check(same_sprite,"SpinDie 四个方向库切换仍引用同一组精灵")
		target_view.driver.advance_game_time(2)
		target_view.driver.try_play_animation("Idle")
		target_view.animator.advance(1.0)
		check(target_view.playback.current_label==11 and target_view.driver.current_animation_key=="SpinDie",
			"非循环原死亡末帧保留，延迟恢复或待机请求不覆盖")
		if not material_package.is_empty():
			check(target_view.sprite.material==death_material
				and target_view.sprite.texture.region==Rect2(352,0,32,32)
				and death_material.get_shader_parameter("body_map").get_size()==Vector2(384,32)
				and death_material.get_shader_parameter("head_map").get_size()==Vector2(384,32),
				"末帧有原数据且沿用同一材质，不能把未使用行的缺帧误当成运行时缺帧")
	check(scene.training_attributes.apply_current_health_delta(-1,0,null,caster.stats())==0 and hits.size()==2
		and not target.lifecycle.pending_death,
		"已零血无有效增量，不再请求死亡")
	scene.stop_human_aim()
	scene.free()
	control.free()
	await process_frame
	if failed==0: print("PASS ClickMoveTest 训练假人实际受击流程：%d 项" % n)
	quit(0 if failed==0 else 1)
