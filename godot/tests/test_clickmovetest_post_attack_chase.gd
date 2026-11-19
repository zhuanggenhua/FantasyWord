extends "res://tests/test_clickmovetest_trainer_basic_attack.gd"
## 原验收器的同场 Dmg → 拉开 → 恢复追击；不等同 Unity PlayMode 或正式宿主验收。
## 只用真实 Entry 驱动动作、导航与身体，不手动推进能力时间轴。
const Chase = preload("res://validation/post_attack_chase_contract.gd")


func run() -> void:
	# 锁定诊断的渲染帧上限，避免无窗口高速空帧在物理步之前耗尽 240 帧。
	Engine.max_fps = 60
	var scene = Entry.instantiate()
	root.add_child(scene)
	var owner := TrackingOwner.new()
	var player := Player.new()
	player.actor = scene.actor
	var events := MapEvents.new()
	var trainer_owner := TrainerOwner.new()
	var stats := Attributes.new()
	if not stats.configure(PackedInt32Array([100,40,10,6,6,4,8,4,100]),Combat.Alignment.GOOD,
			func():return false):
		_fail_entry(scene,"正式玩家属性无法装配")
		return
	var art := OS.get_environment("FORMAL_TRAINER_ATTACK_TEXTURES")
	var source_attack := OS.get_environment("FORMAL_TRAINER_ATTACK_ANIMATION")
	var source_rules := OS.get_environment("FORMAL_SURFACE_RULES")
	var player_file := OS.get_environment("FORMAL_PLAYER_DAMAGE_ANIMATION")
	var fixture_dir := ProjectSettings.globalize_path("user://post-attack-chase")
	var exact := not art.is_empty() and not source_attack.is_empty() and not source_rules.is_empty() \
		and not player_file.is_empty() and not OS.get_environment("FORMAL_TRAINER_ATTACK_MATERIAL").is_empty() \
		and not OS.get_environment("FORMAL_PLAYER_DAMAGE_MATERIAL").is_empty()
	var pack := [read(source_rules),read(source_attack)] if exact else fixtures(scene,fixture_dir)
	var terrain: Dictionary = pack[0]
	var trainer_animation: Dictionary = pack[1]
	if not exact:
		art = fixture_dir
		var dmg: Dictionary = trainer_animation.actions.Idle.duplicate(true)
		dmg.duration = .5
		dmg.loop = false
		trainer_animation.actions["Dmg"] = dmg
		trainer_animation.actions["Attack"] = dmg.duplicate(true)
		trainer_animation.training_target = {"prefab_guid":"dca23ea6afacc0647bfd10c5cefa4099",
			"runtime_libraries":["62c4a52ab213438419c93cc2d8427623","0602b79d46e41504a8117d1fdcc863b2",
			"aaefe509e84579b4782b521a1d156e71","9ea72d0165623924d891e3222ac25d48"],
			"body_local_position":[0,0]}
	var player_animation: Dictionary = trainer_animation.duplicate(true)
	player_animation.erase("training_target")
	player_animation.actions.erase("SpinDie")
	if exact: player_animation = read(player_file)
	var player_view: Node2D = scene.start_human_presentation(player_animation,art)
	if not is_instance_valid(player_view) or not scene.start_human_logic(owner,terrain,
			func():return player,func():return null,events,func(_p):return false):
		_fail_entry(scene,"实际玩家身体与 Dmg 表现入口无法启动")
		return
	var trainer = scene.start_training_damage_target(trainer_owner,trainer_owner.hooks(),7752)
	if not is_instance_valid(trainer):
		_fail_entry(scene,"缺少实际活动训练假人")
		return
	var trainer_material := _material(exact,art,"FORMAL_TRAINER_ATTACK_MATERIAL")
	var player_material := _material(exact,art,"FORMAL_PLAYER_DAMAGE_MATERIAL")
	if not player_material.is_empty() and not player_view.bind_base_material(player_material.data,
			player_material.uv_directory,player_material.appearance_directory):
		_fail_entry(scene,"原玩家 Dmg 双 UV 无法绑定")
		return
	if not is_instance_valid(scene.start_training_target_presentation(trainer_animation,art,trainer_material)):
		_fail_entry(scene,"原假人 Attack 无法绑定")
		return
	var world_owner := Node2D.new()
	scene.add_child(world_owner)
	var player_start: Vector2 = scene.actor.get_movement_position()
	# 仅在验收中按原脚本布置；随后让实际检测自然选敌，不注入 AI 目标。
	trainer.body.request_move_position(Chase.setup_npc_position(player_start))
	await ticks(3)
	check(trainer.get_movement_position().is_equal_approx(Chase.setup_npc_position(player_start)),
		"用源 +Y .72 布置实际身体")
	if not scene.start_training_target_tracking(stats.stats,world_owner) or not scene.start_training_transit_steering():
		_fail_entry(scene,"实际原路径与单体转向无法绑定")
		return
	if not scene.start_training_combat_wander(func():return .5,func(_minimum,_maximum):return 1.0):
		_fail_entry(scene,"受控闭区间抽样入口无法绑定")
		return
	var interrupts: Array[int] = []
	if not scene.bind_human_damage_lifecycle(func():return false,func():interrupts.append(stats.current_health())):
		_fail_entry(scene,"实际玩家 Dmg 生命周期无法绑定")
		return
	var hooks := {"provoke":func(_source):pass,"has_formal_stats":stats.has_formal_stats,
		"current_health":stats.current_health,"prepare":func(_source,_hit):pass,
		"apply_current_health_delta":stats.apply_current_health_delta,
		"complete":func(_source,_hit,_before,_amount):pass}
	if not is_instance_valid(scene.start_training_basic_attack(func():return Vector2(0,1),hooks,func():return 50)):
		_fail_entry(scene,"实际假人无法释放 20001")
		return
	var wait_frames := 0
	while Chase.await_hit(wait_frames,player_view.driver.current_animation_key)=="pending":
		await process_frame
		wait_frames += 1
	var hit_frame := Engine.get_process_frames()
	if player_view.driver.current_animation_key!="Dmg":
		_fail_entry(scene,"240 帧窗口未观察到真实玩家进入 Dmg")
		return
	check(stats.current_health()==97 and trainer.ai_controller.current_target()==scene.actor,
		"真实 Dmg 且场景中同一玩家收到了三点伤害")
	var npc_at_relocation: Vector2 = trainer.get_movement_position()
	var relocation := Chase.relocation(scene.actor.get_movement_position(),npc_at_relocation,
		scene.route.try_build_world_path)
	check(relocation.status in ["desired_path","fallback_path"]
		and npc_at_relocation.distance_to(relocation.position)>=Chase.MIN_RELOCATION_DISTANCE,
		"按源拉开顺序选真实路点，不能用无路径位置冒充可达")
	var chase_start_frame := Engine.get_process_frames()
	scene.actor.request_move_position(relocation.position)
	await physics_frame
	await physics_frame
	check(scene.actor.get_movement_position().is_equal_approx(relocation.position),
		"拉开使用真实角色同步位置")
	var npc_displacement := 0.0
	var chased_player := false
	while Engine.get_process_frames()-chase_start_frame<=Chase.OBSERVATION_FRAMES:
		await process_frame
		npc_displacement = maxf(npc_displacement,trainer.get_movement_position().distance_to(npc_at_relocation))
		chased_player = chased_player or (trainer.ai_controller.current_target()==scene.actor
			and trainer.ai_controller.transit_latest.get("group","") in ["transit","combat-wander","predictive-target"])
	var evaluation := Chase.evaluate(Engine.get_process_frames()-chase_start_frame,hit_frame,player_view.driver.current_animation_key,
		trainer.can_move(),trainer.ai_controller.current_target()!=null,npc_at_relocation,
		trainer.get_movement_position(),scene.actor.get_movement_position())
	check(evaluation.success,"原追击判据未满足：%s" % [evaluation])
	check(chased_player and npc_displacement>=Chase.REQUIRED_NPC_DISPLACEMENT
		and trainer.ai_controller.current_target()==scene.actor,
		"实际 NPC 移动且仍追同一玩家，不以最终相距较近代替运动")
	check(interrupts==[97] and player_view.driver.current_animation_key!="Dmg",
		"拉开后实际安全阶段只打断一次，受击动画自行恢复")
	scene.free()
	if failed==0:
		print("PASS ClickMoveTest 攻击后追击：%d 项，原地图与原动画 %s，最终位移 %.3f，最终间距 %.3f" \
			% [n,exact,evaluation.npc_displacement,evaluation.final_distance])
	quit(0 if failed==0 else 1)


func _material(exact: bool, art: String, variable: String) -> Dictionary:
	var path := OS.get_environment(variable)
	if not exact or path.is_empty(): return {}
	return {"data":read(path),"uv_directory":art.path_join("uv"),"appearance_directory":art.path_join("appearance")}


func _fail_entry(scene: Node, reason: String) -> void:
	scene.free()
	printerr(reason)
	quit(1)
