extends "res://tests/test_clickmovetest_aim_pivot.gd"

const ActorOwner = preload("res://gameplay/clickmovetest/single_player_actor.gd")
const Damage = preload("res://game_core/combat/formal_damage_application.gd")
const CombatRules = preload("res://game_core/combat/combat_rules.gd")

func run() -> void:
	root.size = Vector2i(800,600)
	var scene = Entry.instantiate()
	root.add_child(scene)
	var owner := ActorOwner.new()
	var events := MapEvents.new()
	var control_events: Array = []
	var collision_events: Array = []
	var io := {"point":null,"refresh":0,"reset":0,"destroyed":false}
	owner.controlled_character_changed.connect(func(body): control_events.append(body))
	owner.collision_reported.connect(func(body): collision_events.append(body))
	check(not owner.configure(scene.visual_body),"表现节点不能冒充序列化玩家 Actor")
	check(owner.configure(scene.actor,func():return io.point,
		func(_actor):io.refresh+=1,func(_actor):io.reset+=1,func():return io.destroyed),
		"只绑定原入口导出的玩家身体")
	check(control_events==[scene.actor] and owner.get_player_provider()==owner
		and owner.get_current_controlled_character_or_player_instance()==scene.actor
		and owner.is_current_controlled(scene.actor) and owner.accepts_player_input(scene.actor)
		and owner.can_be_player_controlled(scene.actor) and not owner.configure(scene.actor),
		"原启动选择显式主角，首次身份通知只来自同一所有者")
	var properties := owner.stats()
	check(owner.current_health()==100 and properties.snapshot=={"physical_attack":10,"magical_attack":6,
		"physical_defense":6,"magical_defense":4,"agility":8,"luck":4}
		and properties.alignment==CombatRules.Alignment.GOOD and not properties.dead and not properties.invincible,
		"原角色表非动态属性同一份权威初态")
	var directory := ProjectSettings.globalize_path("user://clickmovetest-single-player")
	var pack := fixtures(scene,directory)
	var rule_source := OS.get_environment("FORMAL_SURFACE_RULES")
	var rules: Dictionary = pack[0] if rule_source.is_empty() else read(rule_source)
	var view: Node2D = scene.start_human_presentation(pack[1],directory)
	if not is_instance_valid(view) or not scene.start_human_logic(owner,rules,owner.get_player_provider,
			func():return null,events,func(_point):return false) or not scene.start_human_aim(owner,owner):
		check(false,"实际 Entry 的同一对象同时提供指针、角色身份与运动")
		scene.free()
		quit(1)
		return
	owner.player_input_disabled.connect(scene.notify_human_aim_input_disabled)
	check(scene.camera.follow==scene.actor and owner.get_look_at_direction()==Vector2.ZERO
		and owner.calculate_move_speed()==4.0 and owner.calculate_speed_multiplier()==1.0,
		"真实相机跟随、原初始朝向和移动配置")
	var actor := owner.get_current_controlled_character_or_player_instance()
	var source_direction := Vector2(0,-1)
	var pivot: Vector2 = scene.aim_pivot.global_position
	var opposite_pointer: Vector2 = pivot+Vector2(1,0)
	io.point = root.get_canvas_transform()*opposite_pointer
	for i in range(3): await process_frame
	check(io.refresh>0 and owner.get_target_direction().is_equal_approx(Vector2.RIGHT)
		and owner.get_look_at_direction()==Vector2.ZERO,"实际闲置鼠标改变目标方向但不偷改身体朝向")
	owner.update_facing_from_intent(Vector2(.05,0))
	check(owner.get_look_at_direction()==Vector2.ZERO,"源 .05 边界不触发朝向改变")
	actor.set_movement_direction(source_direction)
	await physics_frame
	await physics_frame
	check(owner.get_look_at_direction()==source_direction and actor.get_movement_position()!=Vector2.ZERO,
		"原身体真实移动，MovementBased 方向由同一所有者更新")
	owner.set_accepts_player_input(false)
	check(not owner.accepts_player_input(actor) and owner.is_current_controlled(actor)
		and not actor.execution.has_move_order() and owner.get_target_direction()==owner.get_look_at_direction()
		and owner.read_active_gameplay_pointer()==null and io.reset>0,
		"拒绝输入立即清理订单、瞄准和交互，仍保留主角身份")
	await physics_frame
	await physics_frame
	check(not actor.has_active_movement_intent(),"物理步后不保留之前玩家输入的移动方向")
	var before: int = scene.command_count
	var key := InputEventKey.new()
	key.physical_keycode = KEY_D
	key.pressed = true
	root.push_input(key,true)
	await process_frame
	check(scene.command_count==before,"实际输入被控制门禁拦下")
	owner.set_accepts_player_input(true)
	check(owner.set_current_controlled(false) and not owner.is_current_controlled(actor)
		and owner.get_current_controlled_character_or_player_instance()==actor and control_events.back()==null,
		"相机主角回退不代表仍持有输入控制")
	check(owner.set_current_controlled(true) and control_events.back()==actor and owner.is_current_controlled(actor),
		"同一实际主角可重新被设为控制对象")
	owner.register_collision(scene.actor_shape)
	check(collision_events==[scene.actor_shape],"转交实际原生碰撞对象而不制造世界交互结果")
	var damage_events: Array = []
	var weak_owner: WeakRef = weakref(owner)
	owner.damage_prepared.connect(func(_source,_packet):damage_events.append(["准备",weak_owner.get_ref().current_health()]))
	owner.damage_completed.connect(func(_source,_packet,previous,applied):
		damage_events.append(["完成",previous,applied,weak_owner.get_ref().current_health()]))
	var hooks := owner.damage_hooks()
	var output := {"source":null,"damage":100,"flags":0,"silent":false,"snapshot":null}
	check(Damage.execute_damage_output(owner.stats(),output,false,Callable(),hooks)
		and damage_events==[["准备",100],["完成",100,100,0]],
		"正式接收执行器使用同一个实际属性所有者，不预造血量或通知")
	check(owner.stats().dead and not owner.can_be_player_controlled(actor) and not owner.set_current_controlled(true)
		and not owner.is_destroyed(),"生命归零锁住输入，不冒充安全阶段已执行正式死亡")
	io.destroyed=true
	check(owner.is_destroyed() and not owner.can_move() and not owner.can_update_target_direction(),
		"接受实际外部销毁门禁，而不把死状态与销毁当同一值")
	scene.free()
	await process_frame
	check(owner.get_current_controlled_character_or_player_instance()==null and not owner.can_move()
		and control_events.back()==null,"实体卸载结束切片，身份通知与回退同时清除")
	if failed==0: print("PASS ClickMoveTest single player owner: %d checks" % n)
	quit(0 if failed==0 else 1)
