extends "res://tests/test_clickmovetest_trainer_wander.gd"

func _mount(routing: String) -> Dictionary:
	var scene = Entry.instantiate()
	root.add_child(scene)
	var owner := TrackingOwner.new()
	var player := Player.new()
	player.actor = scene.actor
	var events := MapEvents.new()
	var private_rules := OS.get_environment("FORMAL_SURFACE_RULES")
	var rules: Dictionary = (read(private_rules) if not private_rules.is_empty()
		else fixtures(scene,ProjectSettings.globalize_path("user://trainer-home"))[0])
	if not scene.start_logic(owner,rules,func():return player,func():return null,events,func(_p):return false):
		scene.free()
		return {}
	var trainer_owner := TrainerOwner.new()
	var trainer = scene.start_training_damage_target(trainer_owner,trainer_owner.hooks(),7752)
	var world_owner := Node2D.new()
	scene.add_child(world_owner)
	var stats := Attributes.new()
	if not is_instance_valid(trainer) or not stats.configure(
			PackedInt32Array([100,40,10,6,6,4,8,4,100]),Combat.Alignment.GOOD,func():return false):
		scene.free()
		return {}
	var ai = trainer.ai_controller
	var provider_calls: Array = []
	var provider := {"can_build":false}
	var bound: bool
	if routing == "entry":
		bound = scene.start_training_target_tracking(stats.stats,world_owner)
	else:
		# 存在的地图拒绝构路；空入口则表示当前根本没有活动地图。
		var path := Callable()
		if routing == "no_path":
			path = func(a,b):
				provider_calls.append([a,b])
				return PackedVector2Array([b]) if provider.can_build else null
		bound = ai.bind_player(scene.actor,stats.stats,world_owner,path)
	if not bound or not scene.start_training_transit_steering():
		scene.free()
		return {}
	var draws := Draws.new()
	if routing == "entry" and not scene.start_training_combat_wander(draws.read_value,draws.read_range):
		scene.free()
		return {}
	return {"scene":scene,"trainer":trainer,"ai":ai,"owner":trainer_owner,"stats":stats,
		"draws":draws,"provider_calls":provider_calls,"world_owner":world_owner,
		"provider":provider,
		# 保留真实宿主的引用直到场景卸载。
		"player":player,"player_owner":owner,"events":events}

func run() -> void:
	var host := _mount("entry")
	check(not host.is_empty(),"真实 Entry 连接实际原场景与归位求解")
	if not host.is_empty(): await _exercise_home(host)
	await _exercise_navigation_boundary("no_map")
	await _exercise_navigation_boundary("no_path")
	if failed==0: print("PASS ClickMoveTest trainer return home runtime: %d checks" % n)
	quit(0 if failed==0 else 1)

func _exercise_home(host: Dictionary) -> void:
	var scene = host.scene
	var trainer = host.trainer
	var ai = host.ai
	var home: Vector2 = trainer.SOURCE_POSITION
	var departed := false
	for i in range(175):
		await physics_frame
		if ai.current_target()==scene.actor and trainer.get_movement_position().distance_to(home)>1.75:
			departed = true
			break
	check(departed,"原始双角色场景自然移动到归位直接范围之外")
	if not departed:
		scene.free()
		return
	var far: Vector2 = trainer.get_movement_position()-Vector2(12,0)
	scene.actor.request_move_position(far)
	var prior: Dictionary = ai.transit_latest
	var departure: Dictionary = {}
	for i in range(10):
		await physics_frame
		if ai.current_target()==null:
			departure = ai.transit_latest
			break
		prior = ai.transit_latest
	check(ai.current_target()==null and ai.behaviour.retarget_cooldown==3.0
		and ai.behaviour.target_position==home,"超过原始界限，归位目标同拍恢复原出生点并设置原3秒冷却")
	check(not departure.is_empty() and ai.steering_target.get("mode")=="route"
		and departure.get("group") in ["transit","default"],
		"超过直接靠近距离先走真实地图路径，使用正式路点组")
	if prior.has("origin") and departure.has("origin"):
		var actual: Vector2 = departure.origin-prior.origin
		var previous_direction: Vector2 = prior.safe_direction
		check(actual.normalized().dot(previous_direction)>.98 and host.owner.look_at.is_equal_approx(previous_direction),
			"退回同一拍仍用上一安全结果，无目标时按实际安全方向转身")
	var reached_default := false
	var approached := false
	var ever_closer := false
	var minimum_distance := INF
	var prior_dist: float = trainer.get_movement_position().distance_to(home)
	for i in range(180):
		await physics_frame
		var frame: Dictionary = ai.transit_latest
		var dist: float = trainer.get_movement_position().distance_to(home)
		var safe: Vector2 = frame.get("safe_velocity",Vector2.ZERO)
		minimum_distance = minf(minimum_distance,dist)
		ever_closer = ever_closer or dist < prior_dist-.1
		if frame.get("group")=="default":
			reached_default = reached_default or (frame.target.is_equal_approx(home)
				and frame.target_velocity==Vector2.ZERO and frame.arrival_stop_radius==1.0)
			approached = approached or (ai.steering_target.get("mode")=="approach"
				and safe.length()>.01 and safe.length()<frame.max_speed)
		if dist <= 1.035 and safe.length()<.22: break
	check(reached_default and approached and ever_closer,"归位的最终点进入默认 Seek/Arrive，目标速度为零且实际降速")
	check(minimum_distance>=.99 and minimum_distance<1.035,"按源距家1单位停车，不把归位误作移到出生原点")
	await ticks(45)
	var stopped: Vector2 = trainer.get_movement_position()
	var stopped_look: Vector2 = host.owner.look_at
	await ticks(7)
	check(trainer.get_movement_position().is_equal_approx(stopped) and ai.current_target()==null
		and ai.transit_latest.get("safe_direction")==Vector2.ZERO and host.owner.look_at==stopped_look,
		"归位停止后不反复移动，零安全方向保留此前朝向，远处玩家不自动重选")
	for i in range(152):
		if ai.behaviour.retarget_cooldown==0.0: break
		await physics_frame
	scene.actor.request_move_position(Vector2.ZERO)
	for i in range(12):
		await physics_frame
		if ai.current_target()==scene.actor: break
	check(ai.current_target()==scene.actor and ai.transit_latest.get("detected_colliders",[]).has(scene.actor),
		"归位静止仍在检测，冷却结束后重新发现进入范围的真实玩家")
	scene.free()
	await process_frame

func _exercise_navigation_boundary(routing: String) -> void:
	var host := _mount(routing)
	check(not host.is_empty(),"同一物理场景对导航边界的独立绑定")
	if host.is_empty(): return
	var ai = host.ai
	var scene = host.scene
	var trainer = host.trainer
	var spawn: Vector2 = trainer.SOURCE_POSITION
	await ticks(6)
	if routing=="no_map":
		var frame: Dictionary = ai.transit_latest
		var forward := (Vector2.ZERO-spawn).normalized()
		check(ai.current_target()==scene.actor and ai.steering_target.get("mode")=="no_map"
			and frame.get("group")=="default" and frame.get("target")==Vector2.ZERO
			and frame.get("arrival_stop_radius")==1.0 and is_equal_approx(Vector2(frame.forward).dot(forward),1.0)
			and trainer.get_movement_position()!=spawn,
			"没有活动地图走源码默认组，而非预测组或拒绝移动")
	else:
		check(ai.current_target()==scene.actor and ai.steering_target.get("mode")=="no_path"
			and not host.provider_calls.is_empty() and ai.transit_latest.is_empty()
			and trainer.get_movement_position()==spawn,
			"有地图但初始不能构路，提交停止而非转直追")
		host.provider.can_build = true
		await ticks(6)
		var moving_at: Vector2 = trainer.get_movement_position()
		check(ai.transit_latest.get("group")=="predictive-target" and moving_at!=spawn,
			"提供可用路径后，从同一入口恢复并产生实际安全运动")
		host.provider.can_build = false
		# 变更真实目的地触发原重寻路阈值，不篡改已缓存的计时器。
		scene.actor.request_move_position(Vector2(-1.0,0))
		for i in range(12):
			await physics_frame
			if ai.steering_target.get("mode")=="no_path": break
		check(ai.steering_target.get("mode")=="no_path" and ai.transit_latest.is_empty(),
			"重新构路失败时同拍撤回先前安全速度，不转直追")
		await ticks(30)
		var stopped: Vector2 = trainer.get_movement_position()
		await ticks(5)
		check(ai.steering_target.get("mode")=="no_path" and ai.transit_latest.is_empty()
			and trainer.get_movement_position().is_equal_approx(stopped),
			"先前物理移动经过原输入制动后停止，不立即截断真实位移")
	scene.free()
	await process_frame
