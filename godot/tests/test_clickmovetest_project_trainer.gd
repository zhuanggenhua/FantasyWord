extends SceneTree
## 由正式项目入口加载唯一原活动假人；不使用 CLI 诊断或替身血条。
const Startup := preload("res://gameplay/clickmovetest/source_startup.gd")
const Terrain := preload("res://game_core/movement/terrain_cast.gd")
const Gear := preload("res://game_core/inventory/source_character_equipment.gd")
const Draws := preload("res://gameplay/clickmovetest/source_session_draws.gd")
const Commands := preload("res://game_core/interaction/character_command_executor.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var probe:=RandomNumberGenerator.new()
	probe.seed=31629
	var local_draws:=Draws.new(probe)
	var replay:=RandomNumberGenerator.new()
	replay.seed=31629
	var in_range:=true
	for i in range(50):
		var sign_value := local_draws.value()
		var range_value := local_draws.inclusive_range(1,3)
		var hit_roll := local_draws.resolve_damage()
		var first := float(replay.randi_range(0,Draws.CLOSED_STEPS))/float(Draws.CLOSED_STEPS)
		var second: float = PackedFloat32Array([lerpf(1,3,float(replay.randi_range(0,Draws.CLOSED_STEPS))/Draws.CLOSED_STEPS)])[0]
		in_range=in_range and sign_value==first and range_value==second and hit_roll==replay.randi_range(1,99) \
			and sign_value>=0 and sign_value<=1 and range_value>=1 and range_value<=3 and hit_roll>=1 and hit_roll<=99
	_check(in_range,"共享随机流每次只取对应用途的一次抽样，不使用固定诊断值")
	if OS.get_environment("FORMAL_SURFACE_RULES").is_empty():
		print("SKIP 正常项目实际假人；需要原资源")
		_finish()
		return
	root.size=Vector2i(800,600)
	if change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))!=OK:
		quit(1)
		return
	await scene_changed
	await process_frame
	var start := current_scene as Startup
	var scene := start.scene
	var trainer: Node2D=scene.training_target
	var actor: Node2D=scene.actor
	var trainer_pivot := trainer.body.get_node_or_null("Polydirectional Pivot") as Node2D
	var player_pivot := actor.get_node_or_null("Polydirectional Pivot") as Node2D
	var with_atlas := not OS.get_environment("FORMAL_MOVEMENT_INDICATOR_ATLAS").is_empty() \
		or not OS.get_environment("FORMAL_PAUSE_SOURCE").is_empty()
	var trainer_arrow: Sprite2D
	var player_arrow: Sprite2D
	if with_atlas:
		_check(is_instance_valid(trainer_pivot) and is_instance_valid(player_pivot),
			"正式入口按原预制体绑定两份独立提示")
		if not is_instance_valid(trainer_pivot) or not is_instance_valid(player_pivot):
			_finish();return
		trainer_arrow=trainer_pivot.get_node("Movement Indicator") as Sprite2D
		player_arrow=player_pivot.get_node("Movement Indicator") as Sprite2D
	var render_check:=not OS.get_environment("FORMAL_TRAINER_EFFECTS_SOURCE").is_empty()
	var mat: ShaderMaterial=trainer.presentation.sprite.material
	var spear: Resource
	var cloth: Resource
	var corpse: String
	var corpse_inputs: Array = []
	var changes: Array = []
	var observe_slots: Callable
	var observe_corpse: Callable
	if render_check:
		var own: Gear=trainer.source_gear
		if own==null:
			_check(false,"缺少同一正式假人的真实装备槽")
			_finish();return
		spear=own.equipped(Gear.Slot.WEAPON)
		cloth=own.equipped(Gear.Slot.TORSO)
		corpse=start.inventory_bags.corpse_owner(trainer.SOURCE_IDENTIFIER)
		_check(own.belongs_to(trainer) and own!=start.player.source_equipment() and spear!=null and cloth!=null
			and spear==start.player.source_equipment().item_for_guid(Gear.SPEAR)
			and cloth==start.player.source_equipment().item_for_guid(Gear.CLOTH)
			and mat!=scene.human_presentation.sprite.material and mat.get_shader_parameter("weapon0_enabled")
			and mat.get_shader_parameter("enabled_cloth") and mat.get_shader_parameter("outline_stage_enabled")
			and mat.get_shader_parameter("shadow_stage_enabled") and start.inventory_bags.entries(corpse).is_empty(),
			"假人自己的初装槽、服装和长矛，共享物品身份，不共享主角槽或材质")
		observe_corpse=func(owner: String,item: Resource,qty: int,reason: int):
			if owner==corpse: corpse_inputs.append([item,qty,reason,trainer.presentation.driver.current_animation_key])
		start.inventory_bags.item_added.connect(observe_corpse)
		observe_slots=func():
			changes.append([own.equipped(Gear.Slot.TORSO),own.equipped(Gear.Slot.WEAPON),
				bool(mat.get_shader_parameter("enabled_cloth")),bool(mat.get_shader_parameter("weapon0_enabled"))])
		own.loadout_changed.connect(observe_slots)
	var health:=start.player.current_health()
	var trainer_start: Vector2=trainer.get_movement_position()
	var controller: Object=trainer.ai_controller
	_check(Terrain.to_physics(trainer.position)==trainer.SOURCE_POSITION and trainer.health==220 \
		and controller.running and is_instance_valid(trainer.formal_attack)
		and trainer.presentation.driver.resolve_playable_state("SpinDie")=="SpinDie",
		"正常启动原出生点、220 HP、正式 20001、原死亡图 %s/HP%s/run%s/atk%s/death%s" % [trainer_start,trainer.health,controller.running,is_instance_valid(trainer.formal_attack),trainer.presentation.driver.resolve_playable_state("SpinDie")])
	_check(start._source_draws!=null and controller._wander_random_value.get_object()==start._source_draws
		and trainer.formal_attack._roll.get_object()==start._source_draws,
		"普通场景同一抽样来源同时供原假人游走和角色攻击")
	start.trainer_owner.set_target_direction(Vector2.LEFT)
	_check(start.trainer_owner.get_target_direction()==Vector2.LEFT,
		"原假人未攻击前可更新逻辑目标方向")
	if with_atlas:
		_check(trainer_arrow!=player_arrow and is_equal_approx(trainer_arrow.self_modulate.a,.4509804)
			and (trainer_pivot.transform*trainer_arrow.position-trainer_pivot.position).is_equal_approx(Vector2.LEFT*.682),
			"假人自己的原箭头转至目标方向，未攻击时保持原透明度")
	var repath := false
	for i in range(140):
		await physics_frame
		repath = repath or not controller.transit_latest.is_empty()
		if repath and controller.current_target()==actor: break
	_check(repath and controller.current_target()==actor,"不先移动主角也由实际原地图取得玩家并提交移动")
	# 仅缩短测试路程；留给原 AI 真正取得转向与 20001，绝不直接结算伤害。
	var seen_damage := []
	start.player.damage_completed.connect(func(_src,_input,previous,applied):
		seen_damage.append([previous,applied,start.damage_screen_flash.color.a]))
	for i in range(230):
		if i%12==0:
			var current: Vector2=trainer.get_movement_position()
			actor.request_move_position(current+Vector2(0,-.63))
		await physics_frame
		if not seen_damage.is_empty(): break
	_check(not seen_damage.is_empty() and seen_damage.front()[0]==health
		and seen_damage.front()[1]>0 and seen_damage.front()[2]>0.0,
		"原 AI 普攻确实通过同一角色的受击盒及闪屏，不是测试直接写血")
	var old_aim := start.trainer_owner.get_target_direction()
	var turned := Vector2(-old_aim.y,old_aim.x) if old_aim != Vector2.ZERO else Vector2.UP
	start.trainer_owner.set_target_direction(turned)
	_check(trainer.formal_attack.runtime.spec.owns_attacking_tag()
		and start.trainer_owner.get_target_direction()==old_aim,
		"假人实际普攻拥有原 Attacking 标签时拒绝更新逻辑目标方向")
	start.trainer_owner.set_look_at_direction(turned)
	_check(start.trainer_owner.get_look_at_direction()==turned and start.player.can_update_target_direction(),
		"假人的攻击门不拦身体转向，也不锁主角的逻辑目标方向")
	# 第二段用作者验证站位隔离移动时序，不新增角色或直接触发伤害。
	# 保留当前假人的真实状态，但让它上一刀自然结束再观察玩家原第一槽。
	scene.set_process(false)
	scene.set_physics_process(false)
	if with_atlas:
		await create_timer(.30,true,false,true).timeout
		_check(trainer_pivot.global_position.is_equal_approx(trainer.body.global_position+Vector2(0,-.4))
			and trainer.formal_attack.runtime.spec.owns_attacking_tag()
			and trainer_arrow.self_modulate.a<.015 and is_equal_approx(player_arrow.self_modulate.a,.4509804),
			"实际 AI 普攻淡出，只影响随移动身体的假人箭头")
	trainer.body.request_move_position(Vector2(2.5,-2.75))
	actor.request_move_position(Vector2(1.75,-2.35))
	await physics_frame
	await physics_frame
	trainer.formal_attack.advance(.5)
	trainer.formal_attack.advance(.02)
	start.trainer_owner.set_target_direction(turned)
	_check(not trainer.formal_attack.runtime.spec.owns_attacking_tag()
		and start.trainer_owner.get_target_direction()==turned,
		"实际普攻自然结束后恢复假人的逻辑目标方向更新")
	if with_atlas:
		await create_timer(.30,true,false,true).timeout
		_check(absf(trainer_arrow.self_modulate.a-.4509804)<.01,"实际 AI 普攻自然结束后提示恢复原透明度")
	scene.advance_human_damage_lifecycle()
	scene.advance_human_charged_combat(.1)
	start.player.set_target_direction(Vector2.RIGHT)
	start.player.set_look_at_direction(Vector2.RIGHT)
	if render_check:
		trainer.presentation.playback.set_direction(0)
		scene._execute_basic_training_damage(actor,trainer,start.player.stats,func():return 50)
		_check(trainer.health<220 and trainer.health>0 and trainer.presentation.driver.current_animation_key=="Dmg"
			and mat.get_shader_parameter("outline_hit")==1.0 and mat.get_shader_parameter("weapon0_enabled")
			and mat.get_shader_parameter("enabled_cloth"),"正式非致命受击触发 Dmg 轮廓，装备仍在")
		if DisplayServer.get_name()!="headless":
			trainer.presentation.animator.speed_scale=0
			trainer.presentation.driver.set_process(false)
			# Test-only framing: the fixture repositioned the actors while the
			# normal follow camera was paused. Restore it after pixel sampling.
			var camera_position: Vector2=scene.camera.global_position
			scene.camera.global_position=trainer.presentation.sprite.global_position
			scene.camera.reset_smoothing()
			scene.camera.force_update_scroll()
			var overlay_was_visible: bool=start.damage_screen_flash.visible
			start.damage_screen_flash.hide()
			var red:=await _actor_crop(trainer.presentation.sprite)
			mat.set_shader_parameter("outline_hit",0.0)
			var black:=await _actor_crop(trainer.presentation.sprite)
			var toggled:=_red_to_black(red,black)
			start.damage_screen_flash.visible=overlay_was_visible
			scene.camera.global_position=camera_position
			scene.camera.reset_smoothing()
			scene.camera.force_update_scroll()
			_check(toggled>=20,"原生关卡同一假人受击帧红黑轮廓切换像素 %d"%toggled)
			print("原假人红到黑同帧像素：",toggled)
			trainer.presentation.animator.speed_scale=1
			trainer.presentation.driver.set_process(true)
		scene.advance_human_damage_lifecycle()
		# Source may still have the test blow's recovery/interrupt pending.
		trainer.advance_damage_lifecycle()
	var old_health: int=trainer.health
	scene.training_attributes.apply_current_health_delta(1-old_health,0,null,null)
	var outgoing := []
	start.trainer_owner.damage_completed.connect(func(_src,_input,previous,applied):
		outgoing.append([previous,applied]))
	for attack in range(5):
		_key(KEY_1,true)
		scene.advance_human_charged_combat(.018)
		scene.advance_human_charged_combat(.12)
		scene.advance_human_charged_combat(.02)
		_key(KEY_1,false)
		if trainer.health==0: break
		scene.advance_human_charged_combat(.5)
		scene.advance_human_charged_combat(.018)
		# 短间隔多次取样，不改变随机供应器。
	_check(trainer.health==0 and outgoing==[[1,1]],"玩家真实普攻键及正式碰撞结算使活假人归零一次")
	scene.advance_human_damage_lifecycle()
	trainer.advance_damage_lifecycle()
	await process_frame
	_check(not trainer.ai_controller.running and trainer.presentation.driver.current_animation_key=="SpinDie"
		and trainer==scene.training_target and trainer.is_inside_tree(),
		"原安全死亡停止 AI 并保留 SpinDie 身体，不发明复活")
	var corpse_aim := start.trainer_owner.get_target_direction()
	start.trainer_owner.set_target_direction(-turned)
	_check(start.trainer_owner.get_target_direction()==corpse_aim,"安全死亡后不再接受目标方向更新")
	if with_atlas:
		await create_timer(.30,true,false,true).timeout
		_check(trainer_arrow.self_modulate.a<.015,"原安全死亡后假人提示按既有门控淡出")
	if render_check:
		trainer.advance_damage_lifecycle()
		var bags:=start.inventory_bags
		var own: Gear=trainer.source_gear
		_check(changes==[[null,spear,false,false],[null,null,false,false]]
			and corpse_inputs==[[cloth,1,bags.Transfer.CORPSE,"SpinDie"],[spear,1,bags.Transfer.CORPSE,"SpinDie"]]
			and bags.count(corpse,spear)==1 and bags.count(corpse,cloth)==1
			and own.equipped(Gear.Slot.WEAPON)==null and own.equipped(Gear.Slot.TORSO)==null
			and start.player.source_equipment().equipped(Gear.Slot.WEAPON)==spear
			and mat.get_shader_parameter("outline_stage_enabled") and mat.get_shader_parameter("shadow_stage_enabled"),
			"死亡先锁 SpinDie，再按原事件移两件到此尸体背包，不影响主角")
		own.loadout_changed.disconnect(observe_slots)
		bags.item_added.disconnect(observe_corpse)
	await _verify_nonlethal_interrupt()
	_finish()

func _verify_nonlethal_interrupt() -> void:
	# 独立重开正式场景：不把前一段自然结束、死亡或装备验证误当成受击取消。
	if reload_current_scene()!=OK:
		_check(false,"重开正式 ClickMoveTest 以验证非致命打断")
		return
	await scene_changed
	await process_frame
	var boot := current_scene as Startup
	if not is_instance_valid(boot) or not is_instance_valid(boot.scene):
		_check(false,"重开后正式 ClickMoveTest 启动并挂载原场景")
		return
	var scene := boot.scene
	var trainer: Node2D = scene.training_target
	var actor: Node2D = scene.actor
	var spec: RefCounted = trainer.formal_attack.runtime.spec
	for i in range(230):
		if i%12==0:
			actor.request_move_position(trainer.get_movement_position()+Vector2(0,-.63))
		await physics_frame
		if spec.owns_attacking_tag(): break
	_check(spec.owns_attacking_tag() and not boot.trainer_owner.can_update_target_direction(),
		"另一局真实 AI 普攻启动并锁住假人目标方向")
	_check(not trainer.body.can_move() and actor.can_move(),
		"活动假人的 20001 Attacking 只锁本身移动，不锁主角")
	if not spec.owns_attacking_tag(): return
	# 隔离时间步，只推进玩家技能，保留假人本次攻击至首次真实受击。
	scene.set_process(false)
	scene.set_physics_process(false)
	trainer.body.request_move_position(Vector2(2.5,-2.75))
	actor.request_move_position(Vector2(1.75,-2.35))
	await physics_frame
	await physics_frame
	var events: Array[String] = []
	spec.cancelled.connect(func(): events.append("cancelled"))
	spec.ended.connect(func(): events.append("ended"))
	var before: int = trainer.health
	boot.player.set_target_direction(Vector2.RIGHT)
	boot.player.set_look_at_direction(Vector2.RIGHT)
	var primary_runtime: Node = scene._charged_actor_runtime
	var checked_player_attack := false
	var player_blocked := true
	for attempt in range(5):
		_key(KEY_1,true)
		scene.advance_human_charged_combat(.018)
		scene.advance_human_charged_combat(.12)
		if primary_runtime.spec.owns_attacking_tag():
			checked_player_attack = true
			player_blocked = player_blocked and not actor.can_move()
		scene.advance_human_charged_combat(.02)
		_key(KEY_1,false)
		if trainer.health<before: break
		scene.advance_human_charged_combat(.5)
		scene.advance_human_charged_combat(.018)
	_check(trainer.health>0 and trainer.health<before and spec.owns_attacking_tag()
		and events.is_empty() and not boot.trainer_owner.can_update_target_direction(),
		"玩家正式普攻命中并扣血，但尚未进入假人安全打断阶段")
	# 同一已存在的移动路径既不执行位移，也不因攻击期间的新鼠标命令被覆盖。
	var path_start: Vector2 = actor.get_movement_position()
	actor.move_to(path_start+Vector2.UP)
	var rejected: int = scene.submit_human_command({"kind":Commands.Kind.CLICK_MOVE,
		"actor":boot.player,"world_position":path_start+Vector2.LEFT})
	actor.advance_movement(1.0/60.0)
	_check(primary_runtime.spec.owns_attacking_tag() and rejected==Commands.Failure.BLOCKED_BY_STATE
		and actor.execution.has_move_order() and actor.execution.get_last_successful_movement()==Vector2.ZERO,
		"普攻进行中拒绝新的点击路径，已有路径保留但不执行")
	actor.reset_movement()
	var previous_aim := boot.trainer_owner.get_target_direction()
	var next_aim := Vector2.LEFT if previous_aim.is_equal_approx(Vector2.RIGHT) else Vector2.RIGHT
	trainer.advance_damage_lifecycle()
	boot.trainer_owner.set_target_direction(next_aim)
	_check(events==["cancelled"] and not spec.owns_attacking_tag()
		and boot.trainer_owner.can_update_target_direction()
		and boot.trainer_owner.get_target_direction().is_equal_approx(next_aim),
		"非致命受击安全处理取消本次能力，立即恢复假人目标朝向可写")
	_check(checked_player_attack and player_blocked,
		"主角正式第一槽激活，所属 Attacking 标签锁住同一真实移动身体")
	scene.advance_human_charged_combat(.5)
	scene.advance_human_charged_combat(.02)
	_check(not primary_runtime.spec.owns_attacking_tag() and actor.can_move() and trainer.body.can_move(),
		"主角普攻自然结束和假人安全取消分别恢复各自的移动")

func _actor_crop(sprite: Sprite2D) -> Image:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var bounds := sprite.get_global_transform_with_canvas()*sprite.get_rect()
	var region := Rect2i(bounds.position.floor(),bounds.size.ceil()).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
	if not region.has_area(): return Image.new()
	var crop := image.get_region(region)
	crop.convert(Image.FORMAT_RGBA8)
	return crop

func _red_to_black(a: Image,b: Image) -> int:
	if a.get_size()!=b.get_size(): return 0
	var count:=0
	for y in a.get_height():
		for x in a.get_width():
			var first:=a.get_pixel(x,y)
			var second:=b.get_pixel(x,y)
			if first.r8>=178 and first.r8<=182 and first.g8<=11 and first.b8<=11 \
					and second.r8<=1 and second.g8<=1 and second.b8<=1: count+=1
	return count

func _mouse(at: Vector2) -> void:
	var event:=InputEventMouseMotion.new()
	event.device=0
	event.position=root.get_canvas_transform()*Terrain.to_physics(at)
	event.relative=Vector2(1,1)
	root.push_input(event,true)

func _key(code: Key, down: bool) -> void:
	var event:=InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=down
	root.push_input(event,true)

func _check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",label)

func _finish() -> void:
	if not failures: print("PASS 正常入口活动假人：%d 项（%s）" % [checks,DisplayServer.get_name()])
	quit(1 if failures else 0)
