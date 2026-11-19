extends "res://tests/test_clickmovetest_flamethrower_batch.gd"
## 原角色新槽组合的入口验证：不设 20004、不手工指定槽位，沿用原能力和受击盒。
const PlayerActor = preload("res://gameplay/clickmovetest/single_player_actor.gd")
const TrainerActor = preload("res://gameplay/clickmovetest/training_actor_owner.gd")


func _finish(scene: Node) -> void:
	scene.free()
	if failed==0: print("PASS ClickMoveTest 新玩家普攻/喷火: %d 项" % n)
	quit(1 if failed else 0)


func _key(code: Key, down: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	event.echo = echo
	root.push_input(event,true)


func run() -> void:
	var scene = Entry.instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var player := PlayerActor.new()
	var trainer_owner := TrainerActor.new()
	var events := MapEvents.new()
	var source := OS.get_environment("FORMAL_TEST_FRESH_PLAYER_ASSETS")
	var trainer_dir := OS.get_environment("FORMAL_TRAINER_ATTACK_TEXTURES")
	var private_rules := OS.get_environment("FORMAL_SURFACE_RULES")
	var private_surface := OS.get_environment("FORMAL_SURFACE_ASSETS")
	var exact := not source.is_empty() and not trainer_dir.is_empty() and not private_rules.is_empty() \
		and not private_surface.is_empty() and not OS.get_environment("FORMAL_TRAINER_ATTACK_ANIMATION").is_empty()
	var art := source if exact else ProjectSettings.globalize_path("user://fresh-combat-fixture")
	var pack := [read(private_rules),read(art.path_join("animation-player-combat.json"))] if exact else fixtures(scene,art)
	if exact: art = trainer_dir
	if not exact:
		for key in ["Attack","Dmg"]:
			var action: Dictionary = pack[1].actions.Idle.duplicate(true)
			action.duration = .5
			action.loop = false
			pack[1].actions[key] = action
		for row in pack[0].rows: row.surface = 2
	pack[1].actions.erase("ChargedAttack")
	var view: Node2D = scene.start_human_presentation(pack[1],art)
	if exact:
		check(is_instance_valid(view) and view.bind_base_material(read(source.path_join("material-player-combat.json")),
			art.path_join("uv"),art.path_join("appearance")),"原玩家独立的 Attack、Dmg 双 UV")
	var surfaces: Dictionary = read(private_surface) if exact else surface_fixture(scene)
	check(is_instance_valid(view) and player.configure(scene.actor)
		and scene.start_human_logic(player,pack[0],player.get_player_provider,func():return null,events,func(_p):return false)
		and scene.start_surface_elements(surfaces) and scene.start_human_aim(player,player)
		and scene.start_human_command_execution(player) and scene.human_interaction==null,"相同原玩家、地表和命令拥有者装配")
	if failed>0:
		_finish(scene)
		return
	view.driver.set_process(false)
	var trainer: Node2D = scene.start_training_damage_target(trainer_owner,trainer_owner.hooks(),7752)
	var trainer_animation: Dictionary
	if exact:
		trainer_animation = read(OS.get_environment("FORMAL_TRAINER_ATTACK_ANIMATION"))
	else:
		trainer_dir = art
		trainer_animation = pack[1].duplicate(true)
		trainer_animation.training_target = {"prefab_guid":trainer.VISUAL_PREFAB,
			"runtime_libraries":trainer.VISUAL_LIBRARIES,"body_local_position":[0,0]}
	var trainer_material := {}
	if exact:
		trainer_material = {"data":read(OS.get_environment("FORMAL_TRAINER_ATTACK_MATERIAL")),
			"uv_directory":trainer_dir.path_join("uv"),"appearance_directory":trainer_dir.path_join("appearance")}
	check(trainer_owner.bind_target(trainer)
		and is_instance_valid(scene.start_training_target_presentation(trainer_animation,trainer_dir,trainer_material)),
		"训练假人是同世界实际碰撞对象，有原伤害反应，不用替代属性快照")
	var notifies: Array = []
	var runtime: Node = scene.start_human_fresh_training_combat(player,func():return 50,
		func(_target):return null,func(_target):return null,func(code,reason):notifies.append([code,reason]))
	check(is_instance_valid(runtime),"没有 20004 与 ChargedAttack 状态也能绑定")
	if failed>0:
		_finish(scene)
		return
	var slots: RefCounted = scene._equipped_ability_dispatch._loadout
	check(runtime.resolve(20001)==runtime and is_instance_valid(runtime.resolve(20010))
		and runtime.resolve(20004)==null and scene._charged_timeline==null
		and slots.get_formal_gas_ability_code(0)==20001 and slots.get_formal_gas_ability_code(1)==20010
		and slots.get_formal_gas_ability_code(2)==0,"作者表成功解析后才占槽，不注入蓄力")
	var fire: Node = runtime.resolve(20010)
	check(runtime.spec.attacking_tags==fire.spec.attacking_tags and view.driver.resolve_playable_state("ChargedAttack").is_empty(),
		"两个真实技能共用唯一攻击标签，不借不存在的第三种动画")
	check(scene.bind_human_gameplay_actions(func():
		return {"actor":player,"command_context":{"actor":player,"issuer_kind":1,"issuer_id":"local"}},
		func():return false,func(_request,_failure):pass),"通过正式归一化命令而非直接激活")
	var command_before: int = scene.command_count
	_key(KEY_1,true)
	_key(KEY_1,false)
	check(scene.command_count==command_before and scene.bind_human_ability_keyboard()
		and not scene.bind_human_ability_keyboard(),"正式键盘须明确接入且不可重复绑定")
	# 仅受击盒隔离验证布局，不是原实际出生或默认获得第三技能。
	scene.actor.request_move_position(Vector2(1.75,-2.35))
	await physics_frame
	await physics_frame
	await process_frame
	player.set_target_direction(Vector2.RIGHT)
	player.set_look_at_direction(Vector2.RIGHT)
	trainer_owner.set_target_direction(Vector2.LEFT)
	_key(KEY_E,true)
	check(scene.last_result==Executor.Failure.MISSING_ABILITY and notifies.is_empty(),"原第三槽空，不派发替代技能")
	_key(KEY_E,false)
	_key(KEY_1,true)
	check(scene.last_result==Executor.Failure.NONE and not runtime.spec.active,"原 1 发给本体普攻，不同步当作已激活")
	player.set_target_direction(Vector2.LEFT)
	check(player.get_target_direction()==Vector2.RIGHT,"20001 虽无转身配置，但此指令用当前目标方向构造显式瞄准，前摇锁定")
	player.set_target_direction(Vector2.RIGHT)
	scene.advance_human_charged_combat(.018)
	check(runtime.spec.activate_requested and trainer.health==220,"原输入门禁随后才投递正式请求")
	scene.advance_human_charged_combat(.12)
	check(runtime.spec.owns_attacking_tag() and trainer.health==220
		and scene._basic_timeline.frame==7,"普攻独占原时钟，第 8 帧前未扣血")
	scene.advance_human_charged_combat(.02)
	check(trainer.health==206 and view.driver.current_animation_key=="Attack"
		and scene.training_hit_cue.activation_count==1,"同一实际目标第 8 帧受击，玩家播放原 Attack")
	_key(KEY_Q,true)
	check(scene.last_result==Executor.Failure.ABILITY_REJECTED and notifies.size()==1 and notifies[0][0]==20010,
		"普攻中拦住同一角色 Q 所对应的喷火")
	_key(KEY_Q,false)
	_key(KEY_1,false)
	scene.advance_human_charged_combat(.55)
	check(not runtime.spec.has_attacking_tag(),"原技能结束才释放该角色的攻击标签")
	player.set_target_direction(Vector2.RIGHT)
	_key(KEY_Q,true)
	check(scene.last_result==Executor.Failure.NONE and not fire.spec.active,"Q/2 对应的原槽派发到喷火")
	player.set_target_direction(Vector2.LEFT)
	check(not player.can_update_target_direction() and player.get_target_direction()==Vector2.RIGHT,
		"20010 源配置锁前摇，普通瞄准不覆盖已确认的方向")
	scene.advance_human_charged_combat(.018)
	check(player.can_update_target_direction() and not fire.spec.active,
		"后摇本身不锁瞄准；待下一阶段的正式标签独立裁决")
	scene.advance_human_charged_combat(.018)
	check(not player.can_update_target_direction(),"正式攻击标签即使在后摇也不能改目标朝向")
	check(fire.spec.owns_attacking_tag() and trainer.health==192 and scene._fire_timeline.frame==1
		and scene.training_hit_cue.activation_count==2 and not trainer.body.is_pushed(),"喷火第 1 帧正式 2003 命中，同一目标无默认推力")
	var before_alias: int = scene.command_count
	_key(KEY_Q,true,true)
	_key(KEY_2,true)
	_key(KEY_Q,false)
	check(scene.command_count==before_alias and fire.gate.trigger_held,
		"重复 Q 与别名 2 保持同一 Action，Q 松开不提前 StopFire")
	_key(KEY_2,false)
	check(scene.command_count==before_alias+1 and not fire.gate.trigger_held,
		"最后一个别名松开后经同一拥有者派发 StopFire")
	scene.advance_human_charged_combat(1.2)
	scene.advance_human_charged_combat(.02)
	check(not fire.spec.active and not runtime.spec.has_attacking_tag(),"同上下文释放清理喷流时钟与标签")
	# 真实 Entry 的受击延迟模块：受击回调不当场终止，下一安全槽通知两个实际实例。
	check(scene.bind_human_damage_lifecycle(player.is_destroyed,runtime.interrupt_owned_actions),
		"安全中断接入同一个真实角色的全部已持有 Timeline")
	_key(KEY_Q,true)
	scene.advance_human_charged_combat(.018)
	scene.advance_human_charged_combat(.018)
	check(fire.spec.active and fire.spec.owns_attacking_tag(),"供受击中断的当前真实喷火实例")
	scene._prepare_human_training_damage(trainer,{"silent":false},func(_source,_input):pass)
	check(fire.spec.active and not fire.spec.cancel_requested,"非静默受击在准备阶段不抢先取消")
	scene.advance_human_damage_lifecycle()
	check(fire.spec.active and fire.spec.cancel_requested and runtime.spec.cancel_requested,
		"下一安全阶段通知活跃与空闲实例，不直接代替 GAS 结束")
	scene.advance_human_charged_combat(.018)
	check(not fire.spec.active and not runtime.spec.has_attacking_tag() and player.can_update_target_direction(),
		"正式取消清理时钟和角色攻击标签，恢复瞄准")
	_key(KEY_Q,false)
	_finish(scene)
