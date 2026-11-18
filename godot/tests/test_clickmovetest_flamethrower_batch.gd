extends "res://tests/test_basic_training_timeline.gd"
## Q 对应归一化 FireAbility1；用同一个 Entry、Actor、原地图状态和训练假人。
const SurfaceFixture = preload("res://tests/test_clickmovetest_element_surface.gd")
class SprayFacingOwner extends FacingOwner:
	signal target_direction_changed(value: Vector2)
	func _init() -> void:
		super()
		state.target_direction_changed.connect(_forward_target)
	func _forward_target(value: Vector2) -> void: target_direction_changed.emit(value)

func surface_fixture(scene: Node) -> Dictionary:
	return SurfaceFixture.smoke_contract(scene)
func run() -> void:
	var scene = Entry.instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var owner := SprayFacingOwner.new()
	var control := ControlHost.new()
	root.add_child(control)
	var player := Player.new()
	player.actor = scene.actor
	var events := MapEvents.new()
	var directory := OS.get_environment("FORMAL_FIRE_BATCH")
	var source := not directory.is_empty()
	var pack: Array
	if source:
		pack = [read(directory.path_join("rules.json")),read(directory.path_join("animation-combat.json"))]
	else:
		directory = ProjectSettings.globalize_path("user://fire-combat-batch")
		pack = fixtures(scene,directory)
		for key in ["Attack","ChargedAttack","Dmg"]:
			var action: Dictionary = pack[1].actions.Idle.duplicate(true)
			action.duration = .75 if key=="ChargedAttack" else .5
			action.loop = false
			pack[1].actions[key] = action
	var areas_file := OS.get_environment("FORMAL_SURFACE_ASSETS")
	var assets := read(areas_file) if source and not areas_file.is_empty() else surface_fixture(scene)
	if not source:
		for row in pack[0].rows: row.surface = 2
	var view: Node2D = scene.start_human_presentation(pack[1],directory)
	if view==null or not scene.start_human_logic(owner,pack[0],func():return player,func():return null,events,func(_p):return false):
		printerr("实际玩家表现或逻辑未装配")
		quit(1)
		return
	if not scene.start_surface_elements(assets):
		printerr("喷火场景缺少地表数据")
		quit(1)
		return
	check(scene.start_human_aim(owner,control) and scene.start_human_interaction(owner,func():pass),"玩家命令拥有者")
	var ground_path := OS.get_environment("FORMAL_GROUND_LAYERS")
	var ground_enabled := source and not ground_path.is_empty()
	if ground_enabled:
		check(scene.bind_ground_layers(ground_path),"同一 Q 验证装配真实重叠地表")
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
	var player_impact: Array = []
	var contact_hooks := {"impact":func(_in,velocity):player_impact.append(velocity),
		"provoke":func(_source):pass,"has_formal_stats":caster.has_formal_stats,"current_health":caster.current_health,
		"prepare":func(_source,_input):pass,"apply_current_health_delta":caster.apply_current_health_delta,
		"complete":func(_source,_input,_previous,_damage):pass}
	check(scene.start_surface_contact_damage(caster.stats,contact_hooks),"实际玩家属性和训练假人装配原地表接触伤害")
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
		func(_t):return Vector3.ZERO,func(_t):return null,func(code,reason):rejected.append([code,reason]),true,true)
	if not is_instance_valid(charged):
		printerr("缺少原多技能宿主")
		quit(1)
		return
	var cue_dir := OS.get_environment("FORMAL_FLAMETHROWER_CUE")
	var cue_enabled := not cue_dir.is_empty()
	if cue_enabled:
		check(not scene.bind_flamethrower_cues(owner,cue_dir.path_join("bad.png"),cue_dir.path_join("bad.ogg")),
			"缺失原素材不生成替代视听")
		check(scene.bind_flamethrower_cues(owner,cue_dir.path_join("FlamethrowerJet.png"),
			cue_dir.path_join("Flamethrower_FireSpell03_CC0.ogg")), "同一个实际喷火技能绑定锁定原视听")
	var basic: Node = charged.resolve(20001)
	check(is_instance_valid(basic) and basic.spec.attacking_tags == charged.spec.attacking_tags,"不同实例共享唯一角色标签")
	check(scene.bind_human_gameplay_actions(func():return {"actor":owner,"command_context":{"actor":owner,"issuer_kind":1}},
		func():return false,func(_r,_f):pass),"同一实际归一化动作入口")
	var press:=func(i):return scene.receive_human_gameplay_action("Gameplay","FireAbility%d" % i,"performed")
	var release:=func(i):return scene.receive_human_gameplay_action("Gameplay","FireAbility%d" % i,"canceled")
	var fire: Node = charged.resolve(20010)
	check(is_instance_valid(fire) and fire.spec.attacking_tags == basic.spec.attacking_tags,"喷火与其他两个槽共享同一角色标签")
	var terrain: RefCounted = scene.surface_elements
	var changed: Array = []
	terrain.cell_changed.connect(func(cell,_before,after,_notice): changed.append([cell,after]))
	press.call(1)
	check(not fire.gate.is_busy(),"未装备时 Q 不发起虚构喷火")
	slots.try_assign_formal_gas_ability_code_to_slot(0,20010)
	slots.try_assign_formal_gas_ability_code_to_slot(1,20001)
	var start: Vector2 = scene.actor.get_movement_position()
	# 同一体素局部原地图+原图集模式的起点，世界目标位置始终是真实训练假人。
	owner.set_target_direction(Vector2.RIGHT)
	check(press.call(1)==Executor.Failure.NONE and owner.get_look_at_direction()==Vector2.RIGHT,"Q 用当前瞄准方向起手")
	release.call(1)
	scene.advance_human_charged_combat(.05)
	check(not fire.spec.active and target.health==220 and changed.is_empty(),"前摇松开取消，不产生伤害或点火")
	if cue_enabled:
		check(scene.flamethrower_visual==null and scene.flamethrower_audio.active_voice_count()==0,
			"出手前取消没有创建喷流或声音")
	press.call(1)
	scene.advance_human_charged_combat(.018)
	check(fire.spec.activate_requested and not fire.spec.active,"时间轴激活在后续能力阶段")
	scene.advance_human_charged_combat(.018)
	check(fire.spec.owns_attacking_tag() and target.health==206 and not target.body.is_pushed(),"同一第1帧原多边形造成2003无推力伤害")
	check(view.driver.current_animation_key=="Attack" and target_view.driver.current_animation_key=="Dmg","同一真实角色动作与假人反应")
	if cue_enabled:
		check(is_instance_valid(scene.flamethrower_visual) and scene.flamethrower_visual.get_parent()==scene.actor
			and scene.flamethrower_audio.active_voice_count()==1,"Q 实际第 1 帧在 ASC 根挂原喷流并发一条音轨")
		if is_instance_valid(scene.flamethrower_visual):
			var visual: Node2D = scene.flamethrower_visual
			check(is_zero_approx(visual.rotation),"初次挂载保留原 ApplyTransform 覆盖旋转的顺序")
			owner.set_target_direction(Vector2(0,1)) # Source-space +Y.
			check(is_equal_approx(visual.rotation,-PI*.5),"原表现只监听逻辑目标朝向")
			owner.set_look_at_direction(Vector2(0,-1))
			check(is_equal_approx(visual.rotation,-PI*.5),"身体朝向变化不能替换已明示目标朝向")
			visual.advance(.15)
			check(visual.current_frame()==2,"原喷流 14 帧每秒，不使用技能 60 帧时钟")
	check(press.call(2)==Executor.Failure.ABILITY_REJECTED,"攻击期间拦截第二个已装备槽")
	owner.set_look_at_direction(Vector2.LEFT)
	scene.advance_human_charged_combat(.15)
	check(target.health==206,"间隔命中使用实时朝向，不用 Q 起手缓存")
	scene.actor.request_move_position(Vector2(.5,.5))
	await physics_frame
	await physics_frame
	owner.set_look_at_direction(Vector2.RIGHT)
	scene.advance_human_charged_combat(.05)
	var burn: Dictionary = terrain.sample(Vector3i.ZERO)
	check(scene.actor.get_movement_position().distance_to(start)>1.0 and burn.flags==2
		and burn.states[2].source_ability==20010,"后续原锥形点火使用实际角色新位置")
	var fire_tile_path := OS.get_environment("FORMAL_BURNING_TILE_PNG")
	var tile_enabled := not fire_tile_path.is_empty()
	var effects_layer: TileMapLayer
	if tile_enabled:
		check(not scene.bind_surface_presentation("res://project.godot"),"拒绝非锁定临时 Tile 图")
		check(scene.bind_surface_presentation(fire_tile_path),"真实 Entry 绑定原地表火焰")
		effects_layer = scene.surface_fire_tiles
		if is_instance_valid(effects_layer):
			var at := Vector2i(0,-1)
			var atlas: TileSetAtlasSource = effects_layer.tile_set.get_source(0)
			check(effects_layer.get_cell_source_id(at)==0 and effects_layer.position==Vector2.ZERO
				and (effects_layer.map_to_local(at)*effects_layer.scale).is_equal_approx(Vector2(.5,-.5)),
				"启用时刷新已有 Q 点燃格、原 .5/.5 锚点与单位网格")
			check(atlas.get_tile_animation_frames_count(Vector2i.ZERO)==8
				and atlas.get_tile_animation_speed(Vector2i.ZERO)==8.0 and effects_layer.z_index==-1
				and not effects_layer.collision_enabled and not effects_layer.navigation_enabled,
				"锁定原 8 帧 8FPS 与表现层排序，绝不生成碰撞/寻路")
	release.call(1)
	scene.advance_human_charged_combat(.30)
	check(not fire.spec.active and not fire.local_active and not basic.spec.has_attacking_tag() \
		and view.driver.current_animation_key=="Idle","后摇松手清除源时间轴及其角色标签")
	if cue_enabled:
		check(scene.flamethrower_visual==null and scene.flamethrower_audio.active_voice_count()==1,
			"停止技能销毁喷流，但不截断此前已播放的音轨")
	var target_at := Vector2(3.5,.5) if source else Vector2(1.5,.5)
	target.body.request_move_position(target_at)
	await physics_frame
	await physics_frame
	check(target.get_movement_position().distance_to(target_at)<.01 and terrain.sample(Vector3i(floori(target_at.x),0,0)).flags==2,
		"同一实际角色进入 Q 点燃的另一格")
	scene.advance_surface_contact(.5,0)
	scene.run_surface_contact_effects()
	check(caster.current_health()==100 and target.health==206,"暂停不推进地表伤害时间")
	scene.advance_surface_contact(.49)
	scene.run_surface_contact_effects()
	check(caster.current_health()==100 and target.health==206,"未达到 .5 秒不扣血")
	scene.advance_surface_contact(.01)
	check(caster.current_health()==100 and target.health==206,"Update 只提交，正式效果阶段才扣血")
	scene.run_surface_contact_effects()
	check(caster.current_health()==99 and target.health==205 and player_impact.is_empty(),
		"玩家自伤与注册假人各 1 点魔法伤害，自伤不推")
	check(scene.training_hit_cue.activation_count==1,"地表正式伤害未额外派发普攻 Cue")
	check(terrain.apply_point(terrain.WATER,Vector2(.5,.5),1,.1),"已有燃烧按原验证器水反应熄灭")
	if is_instance_valid(effects_layer):
		check(effects_layer.get_cell_source_id(Vector2i(0,-1))==-1
			and effects_layer.get_cell_source_id(Vector2i(floori(target_at.x),-1))==0,
			"原水信号没有 Steam Tile，删除一格火，其余仍保持")
	scene.advance_surface_contact(.5)
	scene.run_surface_contact_effects()
	check(caster.current_health()==99 and target.health==204,"水熄火仅停止该格后续伤害")
	if ground_enabled and tile_enabled and is_instance_valid(scene.ground_layers) and is_instance_valid(effects_layer):
		for overlap: Vector3i in [Vector3i(5,0,0), Vector3i(3,-2,0), Vector3i(0,-10,0), Vector3i(8,6,0), Vector3i(-4,3,0)]:
			var address := Vector2i(overlap.x,-overlap.y-1)
			var expected := {0:[0,10],-2:[0,30,31],-10:[0],6:[0],3:[10,20]}[overlap.y] as Array
			check(scene.ground_layers.mapped_cover_sources(overlap)==expected,"同场景原格有实际作者覆盖：%s" % overlap)
			var decoration: AnimatedSprite2D = scene.ground_layers.lakegrass_sprite(overlap)
			if overlap.y==-10:
				check(is_instance_valid(decoration) and decoration.is_playing() and decoration.self_modulate.a==1,
					"同格原 LakeGrass 动画不加入映射草")
			var road: Sprite2D = scene.ground_layers.static_decoration_sprite(10,overlap)
			var road_texture: Texture2D = road.texture if road != null else null
			if overlap.y==6:
				check(road!=null and road.self_modulate.a==1,"同格原固定石路不是可燃覆盖")
			var covers: Array[Sprite2D] = []
			for source_id in expected:
				var sprite: Sprite2D = scene.ground_layers.source_sprite(source_id,overlap)
				if is_instance_valid(sprite): covers.append(sprite)
			if covers.size()!=expected.size():
				check(false,"所有原草、植被或阴影精灵实际存在")
				continue
			terrain.clear()
			# The west neighbor of (-4,3) is the cliff wall. Cast from the
			# same original elevation instead of forcing a cross-cliff cone.
			var facing := Vector2.LEFT if overlap.y==3 else Vector2.RIGHT
			var caster_x := overlap.x+.5-2.0*facing.x
			scene.actor.request_move_position(Vector2(caster_x,overlap.y+.5))
			target.body.request_move_position(Vector2(caster_x,overlap.y-4.0))
			await physics_frame
			await physics_frame
			owner.set_target_direction(facing)
			owner.set_look_at_direction(facing)
			check(press.call(1)==Executor.Failure.NONE,"同一玩家从键位再次发动原喷火")
			scene.advance_human_charged_combat(.018)
			scene.advance_human_charged_combat(.018)
			var overlap_sample: Dictionary = terrain.sample(overlap)
			check(overlap_sample.flags==2 and overlap_sample.states[2].source_ability==20010
				and effects_layer.get_cell_source_id(address)==0,"Q 实际锥形点燃原覆盖格：%s" % overlap)
			check(covers.all(func(sprite):return sprite.self_modulate.a==1),"点火阶段保留所有作者覆盖格")
			release.call(1)
			scene.advance_human_charged_combat(.30)
			for step in 51: terrain.advance(.1)
			check(terrain.sample(overlap).cover_lifecycle==3 and effects_layer.get_cell_source_id(address)==-1
				and covers.all(func(sprite):return sprite.self_modulate.a==0),"实际 Q 燃尽隐藏而非替换所有作者覆盖格")
			if overlap.y==-10:
				check(is_instance_valid(decoration) and decoration.is_playing() and decoration.self_modulate.a==1,
					"实际 Q 烧尽同格覆盖后湖岸动画仍播放，保留原透明度")
			if overlap.y==6:
				check(road!=null and road.self_modulate.a==1 and road.texture==road_texture,
					"实际 Q 烧尽叠加的草，但不变更原石路透明度或作者纹理")
			terrain.clear()
			check(covers.all(func(sprite):return sprite.self_modulate.a==1),"重置恢复所有原作者覆盖")
	scene.advance_surface_contact(.5)
	events.map_unloaded.emit()
	scene.run_surface_contact_effects()
	check(scene.surface_elements==null and target.health==204,"卸载清空场景待执行效果和运行时")
	if is_instance_valid(effects_layer):
		check(scene.surface_fire_tiles==null and scene.surface_presentation==null
			and effects_layer.get_used_cells().is_empty() and not effects_layer.visible,
			"真实场景卸载同步清空效果 Tile 并解除绑定")
	check(scene.surface_contact_damage.accumulated_time==0,"重新绑定地图不继承上一张地图的计时")
	scene.free()
	control.free()
	await process_frame
	if cue_enabled: await create_timer(.12).timeout # Drain stopped audio mixer references.
	if failed==0: print("PASS ClickMoveTest Q 喷火阶段：%d 项（原图=%s，原视听=%s）" % [n,str(source),str(cue_enabled)])
	quit(0 if failed==0 else 1)
