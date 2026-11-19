extends "res://tests/test_clickmovetest_training_tracking.gd"

class TransitOwner extends TargetMotion:
	func set_look_at_direction(value: Vector2) -> void:
		look_at = value
		look_at_direction_changed.emit(value)

func run() -> void:
	var scene = Entry.instantiate()
	root.add_child(scene)
	var owner := TrackingOwner.new()
	var player := Player.new()
	player.actor = scene.actor
	var events := MapEvents.new()
	var private_rules := OS.get_environment("FORMAL_SURFACE_RULES")
	var rules: Dictionary = (read(private_rules) if not private_rules.is_empty()
		else fixtures(scene,ProjectSettings.globalize_path("user://trainer-transit"))[0])
	if not scene.start_logic(owner,rules,func():return player,func():return null,events,func(_p):return false):
		check(false,"原 Entry 启动")
		_end(scene)
		return
	var trainer_owner := TransitOwner.new()
	var trainer = scene.start_training_damage_target(trainer_owner,trainer_owner.hooks(),7752)
	if not is_instance_valid(trainer):
		check(false,"原活动假人装配")
		_end(scene)
		return
	var world_owner := Node2D.new()
	scene.add_child(world_owner)
	var stats := Attributes.new()
	check(stats.configure(PackedInt32Array([100,40,10,6,6,4,8,4,100]),Combat.Alignment.GOOD,
		func():return false),"原玩家正式属性")
	check(not scene.start_training_transit_steering(),"未绑定正式碰撞世界和玩家时不启动")
	await ticks(3)
	check(scene.start_training_target_tracking(stats.stats,world_owner),"真实 Entry 选敌和地图")
	if not scene.start_training_transit_steering():
		check(false,"启动原单假人 Transit")
		_end(scene)
		return
	check(not scene.start_training_transit_steering(),"同一假人不重复注册")
	var ai = trainer.ai_controller
	for i in range(6):
		await physics_frame
		if ai.steering_target.get("group")=="transit" and Vector2(ai.transit_latest.get("safe_velocity",Vector2.ZERO))!=Vector2.ZERO: break
	check(ai.current_target()==scene.actor and ai.steering_target.get("group")=="transit","实际双角色初态进入中间路点 Transit")
	check(trainer.get_movement_position()==trainer.SOURCE_POSITION,"首次求出安全速度时尚未把同帧结果写进身体")
	var safe: Vector2 = ai.transit_latest.get("safe_velocity",Vector2.ZERO)
	check(safe.length()>0.0 and safe.length()<=4.00001
		and ai.transit_latest.get("max_speed")==4.0,"单人安全速度真实求出且不超过源 4")
	check(ai.transit_latest.get("detected_colliders",[]).has(scene.actor)
		and ai.transit_latest.get("neighbour_count")==0
		and ai.transit_latest.get("push_correction")==Vector2.ZERO,
		"实际物理发现玩家但未注册为 RVO 邻居，不生成角色对修正")
	if not private_rules.is_empty():
		check(ai.steering_target.get("position")==Vector2(.5,-2.5),"锁定场景首路点")
		var direct: Vector2 = (Vector2.ZERO-Vector2(trainer.SOURCE_POSITION)).normalized()
		check(safe.x<0.0 and safe.y>0.0 and safe.normalized().dot(direct)<.90,
			"合成速度沿原首路点而不是终点直推")
	for i in range(5):
		await physics_frame
		if trainer.get_movement_position()!=trainer.SOURCE_POSITION: break
	var moved: Vector2 = trainer.get_movement_position()-trainer.SOURCE_POSITION
	check(moved.length()>0.0 and moved.length()<=4.0*.02*4.0
		and moved.normalized().dot(safe.normalized())>.99,"上一拍的安全速度驱动真实原生身体、沿原路线")
	world_owner.free()
	await ticks(2)
	check(ai.steering_target.is_empty() and ai.transit_latest.is_empty(),
		"碰撞世界撤销后不再保留安全结果")
	# 原 Stop 置方向为零但不跳过 10/s 输入减速；等原输入平滑收尾。
	await ticks(7)
	var stopped: Vector2 = trainer.get_movement_position()
	await ticks(3)
	check(ai.steering_target.is_empty() and stopped==trainer.get_movement_position(),"碰撞世界撤销后不还在写旧方向")
	_end(scene)

func _end(scene: Node) -> void:
	scene.free()
	if failed==0: print("PASS ClickMoveTest trainer Transit runtime: %d checks" % n)
	quit(0 if failed==0 else 1)
