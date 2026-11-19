extends "res://tests/test_clickmovetest_training_tracking.gd"

func run() -> void:
	var scene=Entry.instantiate()
	root.add_child(scene)
	var owner := TrackingOwner.new()
	var player := Player.new()
	player.actor=scene.actor
	var events := MapEvents.new()
	var private_rules := OS.get_environment("FORMAL_SURFACE_RULES")
	var rules: Dictionary = (read(private_rules) if not private_rules.is_empty()
		else fixtures(scene,ProjectSettings.globalize_path("user://training-route"))[0])
	if not scene.start_logic(owner,rules,func():return player,func():return null,events,func(_p):return false):
		scene.free()
		quit(1)
		return
	var trainer_owner := TargetMotion.new()
	var target = scene.start_training_damage_target(trainer_owner,trainer_owner.hooks(),7752)
	check(is_instance_valid(target),"原 Entry 活动假人")
	var player_stats := Attributes.new()
	check(player_stats.configure(PackedInt32Array([100,40,10,6,6,4,8,4,100]),Combat.Alignment.GOOD,
		func():return false),"正式角色属性")
	var collision_owner := Node2D.new()
	scene.add_child(collision_owner)
	await ticks(3)
	check(scene.start_training_target_tracking(player_stats.stats,collision_owner),"实际控制器绑定既有 Entry 路线")
	var ai = target.ai_controller
	await ticks(2)
	check(ai.current_target()==scene.actor and scene.actor.get_movement_position()==Vector2.ZERO
		and target.get_movement_position()==target.SOURCE_POSITION,"原著出生位自动找到实际玩家")
	var points: Variant = scene.route.try_build_world_path(target.SOURCE_POSITION,Vector2.ZERO)
	var received: Dictionary = ai.steering_target
	check(points is PackedVector2Array and not points.is_empty() and received.mode=="route"
		and received.active and received.position==points[0],"物理步选用原规则地图的路径点，而非直线位移")
	if not private_rules.is_empty():
		check(points==PackedVector2Array([Vector2(.5,-2.5),Vector2(.5,-.5),Vector2.ZERO])
			and received.group=="transit" and not received.final,"原 649 节点的锁定路径和行为组")
	var original_timer: float = ai.behaviour.navigation_repath_timer
	await ticks(2)
	check(ai.steering_target==received and ai.behaviour.navigation_repath_timer<original_timer
		and ai.behaviour.navigation_repath_timer>0.,"实际控制器在冷却未尽前使用原光标")
	scene.actor.request_move_position(Vector2(.5,0))
	await ticks(4)
	check(ai.behaviour.target_position.is_equal_approx(Vector2(.5,0))
		and ai.behaviour.navigation_repath_timer > original_timer-.065,"真实玩家越过 .5 重算门限，不等过期")
	scene.actor.request_move_position(Vector2(2.5,-3.47))
	await ticks(4)
	check(ai.steering_target.group=="combat-wander" and ai.steering_target.mode=="wander",
		"实际近敌分支优先于导航，当前仅提交原目标描述")
	check(target.get_movement_position()==target.SOURCE_POSITION,"没有用直推替代缺失的转向/避让")
	collision_owner.free()
	await ticks(2)
	check(ai.steering_target.is_empty(),"碰撞世界卸载时失效导航目标")
	scene.free()
	await process_frame
	if failed==0: print("PASS ClickMoveTest trainer route: %d checks" % n)
	quit(0 if failed==0 else 1)
