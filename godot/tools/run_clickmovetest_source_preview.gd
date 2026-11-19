extends SceneTree
## 显式预览和验收入口；启动装配由原场景宿主完成。
const Startup = preload("res://gameplay/clickmovetest/source_startup.gd")
const DamageScreenFlash = preload("res://gameplay/clickmovetest/source_damage_screen_flash.gd")
const PlayerOwner = preload("res://gameplay/clickmovetest/single_player_actor.gd")
const TrainerOwner = preload("res://gameplay/clickmovetest/training_actor_owner.gd")
const Point = preload("res://game_core/input/mouse_point_actions.gd")
const Movement = preload("res://game_core/movement/character_movement.gd")
const Terrain = preload("res://game_core/movement/terrain_cast.gd")
const Filter = preload("res://game_core/movement/motion_filter.gd")
const Commands = preload("res://game_core/movement/movement_commands.gd")
const PersistenceRegistry = preload("res://game_core/persistence/persistable_identity_registry.gd")
const MapRegistry = preload("res://game_core/maps/active_map_registry.gd")

var _startup: Startup
var _scene: Node2D:
	get: return _startup.scene
var _player: PlayerOwner:
	get: return _startup.player
var _trainer_owner: TrainerOwner:
	get: return _startup.trainer_owner
var _maps: MapRegistry:
	get: return _startup.maps
var _persistables: PersistenceRegistry:
	get: return _startup.persistables
var _point: Point:
	get: return _startup.point
var _damage_screen_flash: DamageScreenFlash:
	get: return _startup.damage_screen_flash


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not "--source-preview" in args or Array(args).any(func(arg):
			return arg not in ["--source-preview","--trainer-diagnostic","--player-combat-diagnostic","--trainer-death-diagnostic","--player-death-diagnostic","--water-reflection","--control-panel","--damage-screen-flash","--smoke"]):
		_refuse("仅接受 --source-preview [--trainer-diagnostic [--player-combat-diagnostic [--trainer-death-diagnostic] [--player-death-diagnostic]]] [--water-reflection] [--control-panel] [--damage-screen-flash] [--smoke]；不默认启动测试或新关卡。")
		return
	_startup = Startup.new()
	root.add_child(_startup)
	if not _startup.open(args):
		_refuse(_startup.refusal)
		return
	var trainer_diagnostic := "--trainer-diagnostic" in args
	var player_combat := "--player-combat-diagnostic" in args
	var _trainer_death := "--trainer-death-diagnostic" in args
	var _player_death := "--player-death-diagnostic" in args
	var _water_reflection := "--water-reflection" in args
	if "--smoke" in args:
		if _water_reflection:
			await _smoke_water_reflection()
		elif _player_death:
			await _smoke_player_death()
		elif _trainer_death:
			await _smoke_trainer_death()
		elif player_combat:
			await _smoke_player_combat()
		elif trainer_diagnostic and is_instance_valid(_damage_screen_flash):
			await _smoke_damage_screen_flash()
		elif trainer_diagnostic:
			await _smoke_trainer()
		else:
			await _smoke()
		return
	print("原 ClickMoveTest 玩家移动预览已启动：鼠标左键点击移动，Tab 切换，WASD 移动。")
	if trainer_diagnostic:
		print("已启用原场景活动训练假人诊断；游走与战斗使用固定样本，不代表 Unity 随机流。")
	if player_combat: print("玩家 1 普攻，Q 或 2 喷火；其余原槽为空。")
	if _trainer_death: print("原训练假人归零进入 SpinDie。")
	if _player_death: print("原主角死亡后保留实体及镜头；此原场景没有配置死亡命令。")
	if _water_reflection: print("原树与主角本体倒影已启用，当前预览没有动态武器或游泳宿主。")
	print("预览不含完整战斗、菜单或存档。")


func _smoke_player_combat() -> void:
	if DisplayServer.get_name()=="headless": root.size=Vector2i(800,600)
	if _scene.actor.get_movement_position()!=Vector2.ZERO or _scene.training_target.get_movement_position()!=_scene.training_target.SOURCE_POSITION:
		_refuse("玩家技能诊断改变了原出生点。")
		return
	await process_frame
	var runtime: Node = _scene._charged_actor_runtime
	var fire: Node = runtime.resolve(20010)
	_key(KEY_Q,true)
	if not fire.gate.trigger_held or runtime.resolve(20004)!=null or _scene.camera.follow!=_scene.actor:
		_refuse("Q 未进入同一原玩家的 20010 输入门控。")
		return
	for i in range(90):
		await process_frame
		if fire.spec.active: break
	if not fire.spec.active or _scene.human_presentation.driver.current_animation_key!="Attack":
		_refuse("同图原玩家喷火未走实际激活与表现。")
		return
	_key(KEY_2,true)
	_key(KEY_Q,false)
	if not fire.gate.trigger_held:
		_refuse("源 Q/2 别名过早停止喷火。")
		return
	_key(KEY_2,false)
	if fire.gate.trigger_held:
		_refuse("源 Q/2 最后松开未进原 StopFire。")
		return
	# The authored audio cue is a one-shot. Quit only after its real channel
	# has recycled the voice, not while the mixer owns its Ogg playback.
	var deadline := Time.get_ticks_msec()+5000
	while (fire.spec.active or _scene.flamethrower_audio.active_voice_count()>0) and Time.get_ticks_msec()<deadline:
		await process_frame
	if fire.spec.active or _scene.flamethrower_audio.active_voice_count()!=0:
		_refuse("原喷火录音或技能未自然回收。")
		return
	print("PASS 原 ClickMoveTest 玩家技能诊断：出生点、实际 20010 激活、Attack 与 Q/2 释放。")
	_scene.free()
	quit()


func _smoke_trainer_death() -> void:
	if DisplayServer.get_name()=="headless": root.size=Vector2i(800,600)
	var trainer: Node2D = _scene.training_target
	if _scene.actor.get_movement_position()!=Vector2.ZERO or trainer.get_movement_position()!=trainer.SOURCE_POSITION:
		_refuse("死亡诊断改变了实际开局的出生点。")
		return
	# 仅验证入口布置真实物理命中和一次剩余生命，不改可玩入口的出生或生命。
	_scene.set_process(false)
	_scene.actor.request_move_position(Vector2(1.75,-2.35))
	await physics_frame
	await physics_frame
	_player.set_target_direction(Vector2.RIGHT)
	_player.set_look_at_direction(Vector2.RIGHT)
	_trainer_owner.set_target_direction(Vector2.LEFT)
	_trainer_owner.set_look_at_direction(Vector2.LEFT)
	# 让原假人自身的 20001 已到第 7 帧，验证死亡安全阶段不准它再命中。
	var counter: Node = trainer.formal_attack
	if not counter._fire(20001):
		_refuse("原假人反击诊断无法正式激活 20001。")
		return
	counter.advance(.018)
	counter.advance(.12)
	if counter.timeline.frame!=7 or not counter.runtime.spec.active:
		_refuse("原假人 20001 未停在真实伤害帧前：%s（激活 %s）。" % [counter.timeline.frame,counter.runtime.spec.active])
		return
	var player_health := _player.current_health()
	var death_trace: Array = []
	_trainer_owner.death_committed.connect(func():
		death_trace.append([trainer.health,trainer.ai_controller.running,
			trainer.presentation.driver.locked_key,trainer.body.execution.has_move_order()]))
	var attributes = _scene.training_attributes
	if attributes.apply_current_health_delta(-206,0,null,_player.stats())!=14:
		_refuse("实际假人的验证生命无法准备。")
		return
	_key(KEY_1,true)
	_scene.advance_human_charged_combat(.018)
	_scene.advance_human_charged_combat(.12)
	if trainer.health!=14 or not death_trace.is_empty():
		_refuse("原普攻第 8 帧前不能触发死亡。")
		return
	_scene.advance_human_charged_combat(.02)
	_key(KEY_1,false)
	if trainer.health!=0 or not trainer.lifecycle.pending_death or not death_trace.is_empty():
		_refuse("原普攻第 8 帧未写入同一假人的待处理死亡。")
		return
	_scene._process(.02)
	trainer.advance_damage_lifecycle()
	if death_trace!=[[0,false,"SpinDie",false]] or trainer.can_move() or not is_instance_valid(trainer.hitbox) \
			or counter.timeline.frame!=7 or counter.timeline.playing or counter.runtime.spec.active or _player.current_health()!=player_health:
		_refuse("死亡收尾未在原身体上停止 AI 并且只锁定一次 SpinDie。")
		return
	var view: Node2D = trainer.presentation
	var material: ShaderMaterial = view.sprite.material
	if not is_instance_valid(material) or material.get_shader_parameter("body_map").get_size()!=Vector2(384,32) \
			or material.get_shader_parameter("head_map").get_size()!=Vector2(384,32):
		_refuse("原 SpinDie 未绑定单行身体与头部 UV。")
		return
	view.animator.advance(1.6)
	if view.playback.current_label!=11 or view.driver.locked_key!="SpinDie" \
			or view.sprite.texture.region!=Rect2(352,0,32,32):
		_refuse("原 12 帧 SpinDie 未保留末帧。")
		return
	print("PASS 原 ClickMoveTest 假人死亡：实际 1 普攻第 8 帧、一次安全收尾、原 SpinDie 双 UV 和末帧。")
	_scene.free()
	quit()


func _smoke_player_death() -> void:
	if DisplayServer.get_name()=="headless": root.size=Vector2i(800,600)
	var trainer: Node2D = _scene.training_target
	var body: Node2D = _scene.actor
	if _player.current_health()!=100 or body.get_movement_position()!=Vector2.ZERO \
			or trainer.get_movement_position()!=trainer.SOURCE_POSITION:
		_refuse("主角死亡诊断不能改变正式开局数据。")
		return
	# 仅布置一次实际物理命中；平常启动不减少玩家生命或移动角色。
	_scene.set_process(false)
	body.request_move_position(Vector2(2.5,-3.47))
	await physics_frame
	await physics_frame
	_scene.set_physics_process(false)
	_player.set_target_direction(Vector2.UP)
	_trainer_owner.set_target_direction(Vector2.DOWN)
	_trainer_owner.set_look_at_direction(Vector2.DOWN)
	var damage := _player.damage_hooks()
	if damage.apply_current_health_delta.call(-97,0,null,trainer.stats)!=3:
		_refuse("无法布置只剩一次真实命中的主角。")
		return
	var changes: Array = []
	_player.controlled_character_changed.connect(func(current): changes.append(current))
	var attack: Node = trainer.formal_attack
	if not attack._fire(20001):
		_refuse("同场假人的正式反击无法提交。")
		return
	attack.advance(.018)
	attack.advance(.12)
	if _player.current_health()!=3 or attack.timeline.frame!=7:
		_refuse("原反击未到第 8 帧时不能掉血。")
		return
	attack.advance(.02)
	if _player.current_health()!=0 or _player.is_destroyed() or _player.can_be_player_controlled(body) \
			or not _player.is_current_controlled(body) or not changes.is_empty():
		_refuse("实际原主角未经历归零与死亡提交之间的独立状态。")
		return
	_scene._process(0)
	_scene.advance_human_damage_lifecycle()
	var view: Node2D = _scene.human_presentation
	if not _player.is_destroyed() or _player.is_current_controlled(body) or _player.can_move() \
			or changes!=[null] or body.execution.has_active_movement_intent() \
			or _scene.camera.follow!=body or _persistables.resolve("player")!=body:
		_refuse("安全死亡未清控制或错误替换了原身体、镜头或标识。")
		return
	var count: int = _scene.command_count
	_key(KEY_1,true)
	_key(KEY_1,false)
	_key(KEY_D,true)
	_key(KEY_D,false)
	var body_map: Texture2D = view.sprite.material.get_shader_parameter("body_map")
	var head_map: Texture2D = view.sprite.material.get_shader_parameter("head_map")
	view.animator.advance(1.6)
	if _scene.command_count!=count or body.execution.has_active_movement_intent() \
			or view.driver.locked_key!="SpinDie" or view.playback.current_label!=11 \
			or body_map.get_size()!=Vector2(384,32) or head_map.get_size()!=Vector2(384,32):
		_refuse("死亡输入仍能执行，或主角缺失原 SpinDie 双 UV 末帧。")
		return
	print("PASS 原 ClickMoveTest 主角死亡：实际反击归零、释放控制、保留原身体、镜头、标识与 SpinDie 末帧。")
	_scene.free()
	quit()


func _smoke_water_reflection() -> void:
	var native := DisplayServer.get_name()!="headless"
	if not native: root.size=Vector2i(800,600)
	var actor: Node2D = _scene.actor
	var capture = _scene.water_reflection
	var view = _scene.human_presentation
	var layers = _scene.ground_layers
	if actor.get_movement_position()!=Vector2.ZERO or layers.water_base_count()!=87 or capture._color_target.get_child_count()!=2:
		_refuse("倒影诊断改变出生点，或捕获了作者未配置的对象。")
		return
	_scene.set_process(false)
	# 只为水面验证把实际角色移动到 (5,-9) 水边，不变更地图或正常出生点。
	actor.request_move_position(Vector2(4.75,-4.5))
	await physics_frame
	await physics_frame
	_scene.set_physics_process(false)
	for child in layers.get_children():
		if child is AnimatedSprite2D:
			child.pause()
			child.set_frame_and_progress(0,0)
	view.animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	view.driver.set_process(false)
	view.playback.set_direction(0)
	view.animator.seek(0,true)
	var center: Vector2 = view.sprite.global_position
	var initial_anchor: Variant = view.reflection_ground_anchor()
	if not center.is_equal_approx(Vector2(5.5,7.6)) or initial_anchor==null \
			or not initial_anchor.is_equal_approx(center+Vector2(0,.3125)):
		_refuse("原主角脚底或测试水边位置不符：%s / %s。" % [center,initial_anchor])
		return
	_scene.camera.global_position=Vector2(5.5,8.2)
	_scene.camera.force_update_scroll()
	_scene.advance_static_tree_reflection(0)
	if capture._player_quality!=Vector2.ONE or not capture._player_proxy.visible \
			or capture._player_proxy.texture!=view.sprite.texture \
			or capture._player_proxy.material==view.sprite.material:
		_refuse("捕获代理未独立跟随实际主角材质和精灵。")
		return
	if native:
		await process_frame
		await RenderingServer.frame_post_draw
		var with_capture: Image = capture._color_target.get_texture().get_image()
		var with_composite := root.get_texture().get_image()
		layers.set_water_capture_material(null)
		await process_frame
		await RenderingServer.frame_post_draw
		var without_composite := root.get_texture().get_image()
		layers.set_water_capture_material(capture.water_material())
		capture._player_proxy.hide()
		await process_frame
		await RenderingServer.frame_post_draw
		var without_capture := root.get_texture().get_image()
		if not with_capture.get_used_rect().has_area() or without_capture.get_data()!=without_composite.get_data():
			_refuse("捕获／合成分离失败，移除主角捕获仍影响真实主画布。")
			return
		var inverse := _scene.get_canvas_transform().affine_inverse()
		var checked := _check_water_rgb(with_composite,without_composite,inverse,layers)
		if checked<=0:
			_refuse("实际主角倒影未产生水格内部 RGB 变化，或越过水格/改变 alpha：%s。" % checked)
			return
		print("原主角水面 RGB 变化：%d px，局限于真实水格。" % checked)
	if view.driver.resolve_playable_state("Attack")!="":
		view.driver.try_play_animation("Attack")
		view.playback.set_direction(1)
		view.animator.advance(.26)
		_scene.advance_static_tree_reflection(0)
		if view.playback.current_label!=2 or not view.reflection_ground_anchor().is_equal_approx(initial_anchor) \
				or capture._player_proxy.texture!=view.sprite.texture:
			_refuse("实际 Attack 动作换帧或换方向未延续脚底和捕获身份。")
			return
	if view.driver.resolve_playable_state("SpinDie")!="":
		view.driver.try_lock_animation("SpinDie")
		view.animator.advance(1.6)
		_scene.advance_static_tree_reflection(0)
		if view.playback.current_label!=11 or not view.reflection_ground_anchor().is_equal_approx(initial_anchor) \
				or capture._player_proxy.texture!=view.sprite.texture:
			_refuse("实际 SpinDie 末帧的脚底与捕获身份不符。")
			return
	capture.set_player_swimming(true)
	_scene.advance_static_tree_reflection(0)
	if capture._player_proxy.visible:
		_refuse("原游泳关闭配置未即时停用完整站立倒影。")
		return
	print("PASS 原主角与原树水面捕获；%s。" % ("原生渲染水色验证" if native else "无头不验画面"))
	_scene.free()
	quit()


func _check_water_rgb(shown: Image, hidden: Image, screen_to_world: Transform2D, layers: Node) -> int:
	if shown.get_size()!=hidden.get_size(): return -1
	var count := 0
	for y in shown.get_height():
		for x in shown.get_width():
			var a := shown.get_pixel(x,y)
			var b := hidden.get_pixel(x,y)
			if a==b: continue
			if a.a!=b.a: return -2
			var world := screen_to_world*Vector2(x+.5,y+.5)
			if layers.water_base_sprite(Vector3i(floori(world.x),-floori(world.y)-1,0))==null:
				return -3
			count+=1
	return count


func _smoke_damage_screen_flash() -> void:
	if DisplayServer.get_name()=="headless": root.size = Vector2i(800,600)
	var trainer: Node2D = _scene.training_target
	var initial := _player.current_health()
	var observations := []
	_player.damage_completed.connect(func(_source, _input, previous, applied):
		observations.append([previous,applied,_player.current_health(),_damage_screen_flash.color]))
	if _scene.actor.get_movement_position()!=Vector2.ZERO or trainer.get_movement_position()!=trainer.SOURCE_POSITION:
		_refuse("原闪屏装配改变出生点。")
		return
	await process_frame
	await process_frame
	if _damage_screen_flash.size!=Vector2(root.size) or _damage_screen_flash.color.a!=0.0 \
			or _damage_screen_flash.mouse_filter!=Control.MOUSE_FILTER_IGNORE:
		_refuse("原闪屏没有全屏透明且穿透指针。")
		return
	# 仅 smoke 固定站位；伤害必须由原假人的 20001、Effect2003 和玩家正式受击盒产生。
	_scene.actor.request_move_position(Vector2(2.5,-3.10))
	for i in range(200):
		await physics_frame
		if not observations.is_empty(): break
	var first: Array = observations.front() if not observations.is_empty() else []
	if first.is_empty() or first[0]!=initial or first[1]<=0 or first[2]!=initial-first[1] \
			or first[3].a<=0.0 or first[3].a>DamageScreenFlash.NORMAL.a \
			or not is_equal_approx(first[3].r,DamageScreenFlash.NORMAL.r):
		_refuse("实际假人未在同一玩家减血后触发原普通红色闪屏。初始生命=%s，结算=%s，非缩放步长=%s，玩家=%s，假人=%s，攻击帧=%s" % [initial,first,_damage_screen_flash._frame_delta,_scene.actor.get_movement_position(),trainer.get_movement_position(),trainer.formal_attack.timeline.frame])
		return
	await create_timer(.20,true,false,true).timeout
	if _damage_screen_flash.color.a!=0.0:
		_refuse("实际闪屏未按非缩放计时清除。")
		return
	print("PASS 原 ClickMoveTest 假人 20001 实际命中、玩家减血、非阻塞全屏闪现及消退。")
	_scene.free()
	quit()


func _smoke_trainer() -> void:
	if DisplayServer.get_name()=="headless": root.size = Vector2i(800,600)
	var trainer: Node2D = _scene.training_target
	# 原启动位置，不采用测试验证器摆位或预置仇恨。
	if trainer.get_movement_position()!=trainer.SOURCE_POSITION or _scene.actor.get_movement_position()!=Vector2.ZERO:
		_refuse("原活动假人与玩家出生位置不符。")
		return
	var transit := false
	var wander := false
	for i in range(110):
		await physics_frame
		var frame: Dictionary = trainer.ai_controller.transit_latest
		transit = transit or frame.get("group")=="transit"
		wander = frame.get("group")=="combat-wander"
		if wander: break
	if not transit or not wander or trainer.ai_controller.current_target()!=_scene.actor \
			or _scene.camera.follow!=_scene.actor or not is_instance_valid(trainer.formal_attack):
		_refuse("原图同场未从初始路径进入游走，或同一玩家与能力入口失配。")
		return
	_key(KEY_TAB,true)
	_key(KEY_TAB,false)
	var previous: Vector2 = _scene.actor.get_movement_position()
	_key(KEY_D,true)
	for i in range(16): await physics_frame
	_key(KEY_D,false)
	if _scene.actor.get_movement_position().x<=previous.x+.15 or trainer.ai_controller.current_target()!=_scene.actor:
		_refuse("同场真实新输入未驱动假人所追踪的同一个玩家。")
		return
	print("PASS 原 ClickMoveTest 假人诊断：原出生点、实际路径转入游走、同一玩家镜头/输入、20001 装配。")
	_scene.free()
	quit()


func _refuse(reason: String) -> void:
	if is_instance_valid(_startup) and is_instance_valid(_scene): _scene.free()
	printerr("ClickMoveTest 预览拒绝启动：" + reason)
	quit(1)


func _smoke() -> void:
	if DisplayServer.get_name()=="headless": root.size = Vector2i(800,600)
	await process_frame
	await physics_frame
	var actor: Node2D = _scene.actor
	if _scene.camera.follow!=actor or actor.get_movement_position()!=Vector2.ZERO \
			or _maps.get_active_terrain_navigation_map()!=_scene.route or _scene.route.graph.node_count()!=649 or _scene.ground_layers.cell_count(-1)!=900 \
			or _scene.human_presentation.driver.current_animation_key!="Idle":
		_refuse("启动未正确绑定原演员、相机、649 节点规则图或 900 格原地面。")
		return
	if _persistables.resolve(PlayerOwner.UNIQUE_PLAYER_IDENTIFIER)!=actor \
			or _persistables.resolve(PlayerOwner.SOURCE_PREINSTANCED_IDENTIFIER)!=null \
			or _persistables.automatically_persisted(actor):
		_refuse("原玩家身份未替换预摆标识或错误进入通用自动存档。")
		return
	var destination := Vector2(4.5,0)
	var screen: Vector2 = root.get_canvas_transform()*Terrain.to_physics(destination)
	_mouse_motion(screen)
	await process_frame
	await process_frame
	var aim: Vector2 = _player.get_target_direction()
	var pivot: Vector2 = Terrain.to_physics(_scene.aim_pivot.global_position)
	if _point.read_active(Point.Map.GAMEPLAY)!=screen or not aim.is_equal_approx((destination-pivot).normalized()):
		_refuse("原 Static Pivot 瞄准失配：Point %s / %s，朝向 %s / %s。" % [
			_point.read_active(Point.Map.GAMEPLAY),screen,aim,(destination-pivot).normalized()])
		return
	_mouse_button(screen,true)
	_mouse_button(screen,false)
	var walking := false
	for i in 220:
		await physics_frame
		walking = walking or _scene.human_presentation.driver.current_animation_key=="Walk"
		if not actor.execution.has_move_order(): break
	if _scene.command_count!=1 or not walking or actor.execution.has_move_order() \
			or actor.get_movement_position().distance_to(destination)>Filter.effective_stop_distance(.05)+.001:
		_refuse("实际鼠标点击没有沿原地图走出 Walk 并到达原停止距离。")
		return
	_key(KEY_TAB,true)
	_key(KEY_TAB,false)
	if _scene.movement.mode!=Movement.Mode.DIRECTIONAL:
		_refuse("真实 Tab 未启用原方向移动。")
		return
	var before: Vector2 = actor.get_movement_position()
	_key(KEY_D,true)
	for i in 12: await physics_frame
	_key(KEY_D,false)
	if actor.get_movement_position().x<=before.x+.15 or _scene.camera.follow!=actor:
		_refuse("真实方向控制未移动同一个角色，或镜头意外解绑。")
		return
	var before_block := int(_scene.command_count)
	_player.set_accepts_player_input(false)
	_key(KEY_D,true)
	_key(KEY_D,false)
	# 原 ResetMovement 清当前命令，不倒改最后一次成功移动的物理样本。
	await physics_frame
	await physics_frame
	if _scene.command_count!=before_block or _scene.last_result!=Commands.Failure.CONTROL_LOCKED \
			or _scene.camera.follow!=actor or actor.has_active_movement_intent():
		_refuse("失去输入权限后状态不符：命令 %d/%d，最后结果 %s，活动移动 %s。" % [
			before_block,_scene.command_count,_scene.last_result,actor.has_active_movement_intent()])
		return
	print("PASS ClickMoveTest 原图预览：实际启动、Point 瞄准、点击寻路、Idle/Walk、Tab/WASD、镜头及输入门禁。")
	_scene.free()
	quit()


func _mouse_motion(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.device = 0
	event.position = position
	event.relative = position
	root.push_input(event,true)


func _mouse_button(position: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	root.push_input(event,true)


func _key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	root.push_input(event,true)
