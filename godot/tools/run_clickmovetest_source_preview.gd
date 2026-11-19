extends SceneTree
## 原 ClickMoveTest 单玩家场景预览：私有原图、真实角色、地图、相机和输入。
## 不修改 Godot 主场景，不搜索任意角色，也不在这里创建回退素材或完整系统。
const Entry = preload("res://gameplay/clickmovetest/entry.tscn")
const EntryScript = preload("res://gameplay/clickmovetest/entry.gd")
const PlayerOwner = preload("res://gameplay/clickmovetest/single_player_actor.gd")
const TrainerOwner = preload("res://gameplay/clickmovetest/training_actor_owner.gd")
const Point = preload("res://game_core/input/mouse_point_actions.gd")
const Movement = preload("res://game_core/movement/character_movement.gd")
const Terrain = preload("res://game_core/movement/terrain_cast.gd")
const Filter = preload("res://game_core/movement/motion_filter.gd")
const Commands = preload("res://game_core/movement/movement_commands.gd")
## 原 Player System 983130465 的主角色为 735002000000000004；只绑定 Entry 明确的 actor。

const PersistenceRegistry = preload("res://game_core/persistence/persistable_identity_registry.gd")
const MapRegistry = preload("res://game_core/maps/active_map_registry.gd")
const MapInfo = preload("res://game_core/maps/registered_map_info.gd")

const REQUIRED_FILES := ["FORMAL_SURFACE_RULES","FORMAL_SURFACE_ASSETS",
	"FORMAL_BURNING_TILE_PNG"]
const REQUIRED_DIRS := ["FORMAL_GROUND_LAYERS","FORMAL_PLAYER_TEXTURES"]
const TRAINER_FILES := ["FORMAL_TRAINER_ATTACK_ANIMATION","FORMAL_TRAINER_ATTACK_MATERIAL"]
const TRAINER_DIRS := ["FORMAL_TRAINER_ATTACK_TEXTURES"]
var _scene: Node2D
var _player: PlayerOwner
var _trainer_owner: TrainerOwner
var _maps := MapRegistry.new()
var _persistables := PersistenceRegistry.new()
var _point: Point


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not "--source-preview" in args or Array(args).any(func(arg):
			return arg not in ["--source-preview","--trainer-diagnostic","--player-combat-diagnostic","--smoke"]):
		_refuse("仅接受 --source-preview [--trainer-diagnostic [--player-combat-diagnostic]] [--smoke]；不默认启动测试或新关卡。")
		return
	var trainer_diagnostic := "--trainer-diagnostic" in args
	var player_combat := "--player-combat-diagnostic" in args
	if player_combat and not trainer_diagnostic:
		_refuse("玩家技能诊断需要同图原训练假人。")
		return
	var player_files: Array = ["FORMAL_PLAYER_COMBAT_ANIMATION","FORMAL_PLAYER_COMBAT_MATERIAL"] if player_combat \
		else ["FORMAL_PLAYER_DAMAGE_ANIMATION","FORMAL_PLAYER_DAMAGE_MATERIAL"]
	var paths := {}
	for key in REQUIRED_FILES + player_files + (TRAINER_FILES if trainer_diagnostic else []):
		var path := OS.get_environment(key)
		if path.is_empty() or not FileAccess.file_exists(path):
			_refuse("缺少明确的原作者输入：" + key)
			return
		paths[key] = path
	for key in REQUIRED_DIRS + (TRAINER_DIRS if trainer_diagnostic else []) + (["FORMAL_FLAMETHROWER_CUE"] if player_combat else []):
		var path := OS.get_environment(key)
		if path.is_empty() or not DirAccess.dir_exists_absolute(path):
			_refuse("缺少明确的原作者资源目录：" + key)
			return
		paths[key] = path
	var rules := _read(paths.FORMAL_SURFACE_RULES)
	var surface := _read(paths.FORMAL_SURFACE_ASSETS)
	var animation := _read(paths[player_files[0]])
	var material := _read(paths[player_files[1]])
	if not EntryScript.valid_rules(rules) or surface.is_empty() or animation.is_empty() or material.is_empty() \
			or animation.has("training_target") or material.has("training_target"):
		_refuse("原场景规则、地表或玩家动画合同无效；不能借训练假人资料启动玩家。")
		return
	_scene = Entry.instantiate()
	root.add_child(_scene)
	_player = PlayerOwner.new()
	if not _player.configure(_scene.actor,Callable(),Callable(),Callable()):
		_refuse("缺少原序列化玩家角色或当前输入所有者。")
		return
	# Source local actor 735002000000000004 first has an authored pre-instanced
	# identifier; original primary startup replaces the handler with player.
	if not _persistables.register_pre_instanced(_scene.actor,PlayerOwner.SOURCE_PREINSTANCED_IDENTIFIER,false) \
			or not _player.register_primary_persistence(_persistables):
		_refuse("原玩家正式持久化标识未绑定。")
		return
	var art: String = paths.FORMAL_PLAYER_TEXTURES
	var view: Node2D = _scene.start_human_presentation(animation,art)
	if not is_instance_valid(view) or not view.bind_base_material(material,art.path_join("uv"),art.path_join("appearance")):
		_refuse("原玩家角色动画与身体、头部 UV 无法绑定。")
		return
	# 原 ClickMoveTest MapInfo 没有相机目标覆盖，也没有启用地图相机边界。
	if not _maps.configure(func(_name):return null,func():return _scene) \
			or not _scene.start_human_logic(_player,rules,_player.get_player_provider,
			_maps.resolve_active_map_info,_maps,_over_native_ui):
		_refuse("原 PlayerSystem、地图规则或镜头绑定未成立。")
		return
	# ClickMoveTest: enabled authored MapInfo 6951708 owns terrain 1148507052,
	# with no checkpoints, camera target, or level bounds. Direct open is not map-loaded.
	var authored_map := MapInfo.new()
	if not authored_map.configure(_scene,_scene.route):
		_refuse("原 ClickMoveTest 地图配置未绑定。")
		return
	_maps.register(authored_map)
	_maps.on_system_start()
	_scene.binding.start_binding()
	if not _scene.bind_active_terrain(_maps.get_active_terrain_navigation_map):
		_refuse("点击导航与原 MapInfo 不属于同一地图。")
		return
	if not _scene.start_surface_elements(surface) or not _scene.bind_ground_layers(paths.FORMAL_GROUND_LAYERS) \
			or not _scene.bind_surface_presentation(paths.FORMAL_BURNING_TILE_PNG):
		_refuse("原底图、固定装饰或地表效果未通过来源检查。")
		return
	_point = Point.new(0)
	_point.enable(Point.Map.GAMEPLAY)
	if not _scene.bind_mouse_point_actions(_point) or not _scene.start_human_aim(_player,_player):
		_refuse("原玩家 Point 与 Static Pivot 未绑定。")
		return
	_player.player_input_disabled.connect(_scene.notify_human_aim_input_disabled)
	if trainer_diagnostic and not _mount_trainer_diagnostic(paths,player_combat):
		_refuse("原活动假人的素材、同图路径或 20001 入口未通过来源与装配检查。")
		return
	if "--smoke" in args:
		if player_combat:
			await _smoke_player_combat()
		elif trainer_diagnostic:
			await _smoke_trainer()
		else:
			await _smoke()
		return
	print("原 ClickMoveTest 玩家移动预览已启动：鼠标左键点击移动，Tab 切换，WASD 移动。")
	if trainer_diagnostic:
		print("已启用原场景活动训练假人诊断；游走与战斗使用固定样本，不代表 Unity 随机流。")
	if player_combat: print("玩家 1 普攻，Q 或 2 喷火；其余原槽为空。")
	print("不含正式主场景、完整战斗、菜单或存档。")


func _mount_trainer_diagnostic(paths: Dictionary, player_combat: bool) -> bool:
	var art: String = paths.FORMAL_TRAINER_ATTACK_TEXTURES
	var animation := _read(paths.FORMAL_TRAINER_ATTACK_ANIMATION)
	var material := _read(paths.FORMAL_TRAINER_ATTACK_MATERIAL)
	if animation.is_empty() or material.is_empty(): return false
	_trainer_owner = TrainerOwner.new()
	var trainer: Node2D = _scene.start_training_damage_target(_trainer_owner,_trainer_owner.hooks(),7752)
	if not is_instance_valid(trainer) or not _trainer_owner.bind_target(trainer): return false
	if not is_instance_valid(_scene.start_training_target_presentation(animation,art,
			{"data":material,"uv_directory":art.path_join("uv"),"appearance_directory":art.path_join("appearance")})):
		return false
	if not _scene.start_training_target_tracking(_player.stats,_scene) or not _scene.start_training_transit_steering():
		return false
	# 仅命令行显式诊断复用定向验证的样本；不把 Godot 随机或固定值当成原运行时随机源。
	if not _scene.start_training_combat_wander(func():return .5,func(minimum,_maximum):return minimum):
		return false
	var interrupt := _interrupt_diagnostic_player_abilities
	if player_combat:
		var combat := _mount_player_combat(paths.FORMAL_FLAMETHROWER_CUE)
		if not is_instance_valid(combat): return false
		interrupt = combat.interrupt_owned_actions
	if not _scene.bind_human_damage_lifecycle(_player.is_destroyed,interrupt):
		return false
	_player.damage_completed.connect(_end_diagnostic_on_zero_health)
	return is_instance_valid(_scene.start_training_basic_attack(
		_player.get_target_direction,_player.damage_hooks(),func():return 50))


func _mount_player_combat(cue_dir: String) -> Node:
	if not _scene.start_human_command_execution(_player): return null
	# 原热键只提交槽位，无目标、Cell 或显式朝向。
	var combat: Node = _scene.start_human_fresh_training_combat(_player,func():return 50,
		func(_target):return null,func(_target):return null,func(_code,_reason):pass)
	if not is_instance_valid(combat) or not _scene.bind_human_gameplay_actions(func():
		if not _player.is_current_controlled(_scene.actor): return null
		return {"actor":_player,"command_context":{"actor":_player,"issuer_kind":1,"issuer_id":"local"}},
		func():return false,func(_request,_failure):pass) or not _scene.bind_human_ability_keyboard():
		return null
	if not _scene.bind_flamethrower_cues(_player,cue_dir.path_join("FlamethrowerJet.png"),
			cue_dir.path_join("Flamethrower_FireSpell03_CC0.ogg")):
		return null
	return combat


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


func _interrupt_diagnostic_player_abilities() -> void:
	# 原安全阶段只通知能力拥有者；此入口未赋予玩家能力，不清移动或输入。
	pass


func _end_diagnostic_on_zero_health(_source: Variant,_input: Dictionary,_previous: int,_applied: int) -> void:
	if _player.current_health()==0:
		# 不继续伪造尚无正式来源接线的玩家死亡生命周期。
		call_deferred("_finish_at_unsupported_death")


func _finish_at_unsupported_death() -> void:
	print("玩家生命归零；诊断结束，未装配正式死亡流程。")
	if is_instance_valid(_scene): _scene.free()
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


func _read(path: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path))!=OK or not json.data is Dictionary: return {}
	return json.data


func _over_native_ui(_point_in_viewport: Vector2) -> bool:
	# 此预览没有另造 UIRoot；已有原生 Control 继续在 _unhandled_input 前消费。
	return is_instance_valid(root.gui_get_hovered_control())


func _refuse(reason: String) -> void:
	if is_instance_valid(_scene): _scene.free()
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
