extends "res://tests/test_clickmovetest_training_tracking.gd"

class TrainerOwner extends TargetMotion:
	var target_direction := Vector2.ZERO
	func set_look_at_direction(value: Vector2) -> void:
		look_at=value
		look_at_direction_changed.emit(value)
	func set_target_direction(value: Vector2) -> void:
		target_direction=value

func run() -> void:
	var scene = Entry.instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var owner := TrackingOwner.new()
	var player := Player.new()
	player.actor = scene.actor
	var events := MapEvents.new()
	var private_rules := OS.get_environment("FORMAL_SURFACE_RULES")
	var private_pack := OS.get_environment("FORMAL_TRAINER_ATTACK_ANIMATION")
	var art_dir := OS.get_environment("FORMAL_TRAINER_ATTACK_TEXTURES")
	var pack: Array
	var animation: Dictionary
	if not private_pack.is_empty() and not art_dir.is_empty() and not private_rules.is_empty():
		animation = read(private_pack)
		pack=[read(private_rules),animation]
	else:
		art_dir=ProjectSettings.globalize_path("user://trainer-attack")
		pack=fixtures(scene,art_dir)
		animation=pack[1]
		animation.actions["Dmg"]=animation.actions.Idle.duplicate(true)
		animation.actions.Dmg.loop=false
		animation.actions.Dmg.duration=.5
		animation.actions["Attack"]=animation.actions.Dmg.duplicate(true)
		animation.training_target={"prefab_guid":"dca23ea6afacc0647bfd10c5cefa4099","runtime_libraries":["62c4a52ab213438419c93cc2d8427623","0602b79d46e41504a8117d1fdcc863b2","aaefe509e84579b4782b521a1d156e71","9ea72d0165623924d891e3222ac25d48"],"body_local_position":[0,0]}
	var player_animation_file := OS.get_environment("FORMAL_PLAYER_DAMAGE_ANIMATION")
	var player_material_file := OS.get_environment("FORMAL_PLAYER_DAMAGE_MATERIAL")
	var player_pack: Dictionary = animation.duplicate(true)
	player_pack.erase("training_target")
	player_pack.actions.erase("SpinDie")
	if not player_animation_file.is_empty(): player_pack = read(player_animation_file)
	var player_view: Node2D = scene.start_human_presentation(player_pack,art_dir)
	if not is_instance_valid(player_view):
		printerr("玩家原动作入口装配失败")
		scene.free()
		quit(1)
		return
	if not player_material_file.is_empty():
		check(player_view.bind_base_material(read(player_material_file),art_dir.path_join("uv"),
			art_dir.path_join("appearance")),"玩家绑定独立原始 Dmg 双 UV")
	player_view.driver.set_process(false)
	check(scene.start_human_logic(owner,pack[0],func():return player,func():return null,events,func(_p):return false),"原 Entry 玩家绑定")
	var trainer_owner := TrainerOwner.new()
	trainer_owner.look_at=Vector2.LEFT
	var trainer = scene.start_training_damage_target(trainer_owner,trainer_owner.hooks(),7752)
	check(is_instance_valid(trainer),"活动训练假人")
	var stats := Attributes.new()
	var health := []
	check(stats.configure(PackedInt32Array([100,40,10,6,6,4,8,4,100]),Combat.Alignment.GOOD,
		func():return false),"实际角色配置")
	var collision_owner := Node2D.new()
	scene.add_child(collision_owner)
	var hooks := {"provoke":func(source):health.append(["provoke",source.alignment]),
		"has_formal_stats":stats.has_formal_stats,"current_health":stats.current_health,
		"prepare":func(_s,input):health.append(["prepare",input.damage]),
		"apply_current_health_delta":stats.apply_current_health_delta,
		"complete":func(_s,_input,previous,amount):health.append(["complete",previous,amount])}
	var reaction: Array = []
	player_view.driver.animation_selected.connect(func(key):reaction.append([key,stats.current_health()]))
	check(scene.bind_human_damage_lifecycle(func():return false,
		func():reaction.append(["interrupt",stats.current_health()])), "绑定实际玩家 Dmg 与宿主延迟打断")
	var read_direction := func():return Vector2(0,1)
	var roll := func():return 50
	check(scene.actor.get_node("受击盒").get_meta("actor")==scene.actor,"原玩家受击盒登记同一实际根")
	check(scene.start_training_basic_attack(read_direction,hooks,roll)==null,"无正式视线绑定，不创建能力")
	scene.actor.request_move_position(Vector2(2.5,-3.47))
	await ticks(4)
	check(scene.start_training_target_tracking(stats.stats,collision_owner),"在实际 0.72 间距绑定玩家与视线世界")
	check(scene.start_training_basic_attack(read_direction,hooks,roll)==null,"无 Attack 图集不以占位动画发招")
	var material_file := OS.get_environment("FORMAL_TRAINER_ATTACK_MATERIAL")
	var material := {}
	if not material_file.is_empty():
		material={"data":read(material_file),"uv_directory":art_dir.path_join("uv"),
			"appearance_directory":art_dir.path_join("appearance")}
	var view: Node2D=scene.start_training_target_presentation(animation,art_dir,material)
	check(is_instance_valid(view),"绑定同一训练假人的动作图集")
	var ability: Node=scene.start_training_basic_attack(read_direction,hooks,roll)
	check(is_instance_valid(ability),"原 20001 装在活动训练假人，不用玩家槽位")
	if not is_instance_valid(view) or not is_instance_valid(ability):
		scene.free()
		quit(1)
		return
	check(scene.start_training_basic_attack(read_direction,hooks,roll)==null,"单一实际能力实例")
	await ticks(2)
	check(trainer.ai_controller.current_target()==scene.actor and trainer_owner.look_at==Vector2.LEFT,
		"新获目标不先攻击，也不跳过转向")
	await ticks(1)
	check(trainer.ai_controller.behaviour.waiting_for_attack_facing and trainer_owner.look_at.is_equal_approx(Vector2(0,-1))
		and not ability.runtime.local_active,"先按源门禁转身，不在同一固定步出手")
	await ticks(1)
	check(ability.runtime.local_active and ability.runtime.context.command_context
		=={"actor":trainer,"issuer_kind":2,"issuer_id":"ai"}
		and trainer.ai_controller.behaviour.attack_cooldown==1.,"下一步以实际假人身份成功出手并设置原冷却")
	scene.set_physics_process(false)
	ability.advance(.02)
	check(not ability.timeline.playing and stats.current_health()==100,"输入门控只入队，未提前启动时间轴")
	ability.advance(.04)
	check(ability.timeline.frame==2 and view.driver.current_animation_key=="Attack","第2帧启动同一假人 Attack")
	var first_texture: Texture2D=view.sprite.texture
	if not material.is_empty():
		var shader: ShaderMaterial = view.sprite.material
		var source_body := Image.load_from_file(art_dir.path_join("uv/Minifantasy_CreaturesHumanAttack_BodyUV.png"))
		var source_head := Image.load_from_file(art_dir.path_join("uv/Minifantasy_CreaturesHumanAttack_HeadUV.png"))
		check(shader!=null and shader.get_shader_parameter("body_map").get_image().get_data()==source_body.get_data()
			and shader.get_shader_parameter("head_map").get_image().get_data()==source_head.get_data(),
			"假人实际 Attack 绑定原双 UV，不降级成原图直显")
	ability.advance(.08)
	check(ability.timeline.frame==7 and stats.current_health()==100 and health.is_empty() and reaction.is_empty(),"第8帧前无伤害及受击动作")
	ability.advance(.02)
	check(ability.timeline.frame==8 and stats.current_health()==97
		and health==[["provoke",Combat.Alignment.EVIL],["prepare",3],["complete",100,3]],
		"真实玩家子受击盒命中，Effect2003 按原角色防御结算且无背刺/推力")
	check(reaction==[["Dmg",100]] and player_view.driver.current_animation_key=="Dmg",
		"实际玩家在扣血之前进入原 Dmg，结算期间不打断动作")
	if not player_animation_file.is_empty():
		var player_texture: Texture2D = player_view.sprite.texture
		var original_dmg := Image.load_from_file(art_dir.path_join("Minifantasy_CreaturesHumanDmg.png"))
		check(player_texture is AtlasTexture and player_texture.atlas.get_image().get_data()==original_dmg.get_data(),
			"实际玩家 Dmg 取原本体图集")
	scene.advance_human_damage_lifecycle()
	scene.advance_human_damage_lifecycle()
	check(reaction==[["Dmg",100],["interrupt",97]],"安全阶段在扣血后仅打断一次")
	scene.human_motion_binding.update_movement_animation(Vector2.RIGHT)
	var dmg_duration: float = player_view.driver.resolve_current_animation_duration_seconds()
	player_view.driver.advance_game_time(dmg_duration-.001)
	check(player_view.driver.current_animation_key=="Dmg" and player_view.driver.pending_fallback_key=="Walk",
		"移动只更新退出目标，仍保持 Dmg 至原时长")
	player_view.driver.advance_game_time(.002)
	check(player_view.driver.current_animation_key=="Walk" and reaction.back()==["Walk",97],
		"原时长后从 Dmg 恢复到当前 Walk")
	scene.human_motion_binding.update_movement_animation(Vector2.ZERO)
	check(player_view.driver.current_animation_key=="Idle","停止移动后由真实表现驱动回到 Idle")
	check(ability.hit_feedback.activation_count==1 and not ability.hit_feedback.last_activation.feedback_slot_configured,
		"玩家作者反馈槽为空，原命中 Cue 独立消费一次")
	if not private_pack.is_empty():
		var atlas_file := Image.load_from_file(art_dir.path_join("Minifantasy_CreaturesHumanAttack.png"))
		check(first_texture is AtlasTexture and first_texture.atlas.get_image().get_data()==atlas_file.get_data(),
			"Attack 播放真实原本体图集")
	ability.advance(.27)
	check(ability.timeline.frame>=24 and view.driver.current_animation_key=="Idle","第24帧移除 Attack 恢复 Idle")
	ability.advance(.2)
	ability.advance(0)
	check(not ability.runtime.spec.active and stats.current_health()==97,"原时间轴自然结束不重复命中")
	scene.free()
	await process_frame
	if failed==0: print("PASS ClickMoveTest trainer formal basic: %d checks" % n)
	quit(0 if failed==0 else 1)
