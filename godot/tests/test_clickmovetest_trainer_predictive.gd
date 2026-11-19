extends "res://tests/test_clickmovetest_trainer_transit.gd"

const Solver = preload("res://game_core/ai/predictive_target_steering.gd")

class LockedTrainer extends TransitOwner:
	var unlocked := false
	func can_move() -> bool: return unlocked

func run() -> void:
	var scene = Entry.instantiate()
	root.add_child(scene)
	var owner := TrackingOwner.new()
	var player := Player.new()
	player.actor = scene.actor
	var events := MapEvents.new()
	var private_rules := OS.get_environment("FORMAL_SURFACE_RULES")
	var rules: Dictionary = (read(private_rules) if not private_rules.is_empty()
		else fixtures(scene,ProjectSettings.globalize_path("user://trainer-predictive"))[0])
	if not scene.start_logic(owner,rules,func():return player,func():return null,events,func(_p):return false):
		check(false,"原 Entry 启动")
		_end_predictive(scene)
		return
	var trainer_owner := LockedTrainer.new()
	var trainer = scene.start_training_damage_target(trainer_owner,trainer_owner.hooks(),7752)
	if not is_instance_valid(trainer):
		check(false,"原活动假人身体")
		_end_predictive(scene)
		return
	var world_owner := Node2D.new()
	scene.add_child(world_owner)
	var stats := Attributes.new()
	check(stats.configure(PackedInt32Array([100,40,10,6,6,4,8,4,100]),Combat.Alignment.GOOD,
		func():return false),"原玩家正式属性")
	# 只移玩家来隔离最终路点；保留训练假人原出生点和真实寻路。
	var from: Vector2 = trainer.SOURCE_POSITION
	var goal := Vector2(-1.75,-2.5) if not private_rules.is_empty() else from + Vector2(3.5,0)
	var direction := (goal-from).normalized().orthogonal()
	if not private_rules.is_empty():
		var authored: Variant = scene.route.try_build_world_path(from,goal)
		check(authored is PackedVector2Array and authored.size()==1 and authored[0].is_equal_approx(goal),
			"原地图返回对应真实最终路点")
	scene.actor.request_move_position(goal)
	await ticks(4)
	var ai = trainer.ai_controller
	var tracking: bool
	if private_rules.is_empty():
		tracking = ai.bind_player(scene.actor,stats.stats,world_owner,
			func(_origin, destination): return PackedVector2Array([destination]))
	else:
		tracking = scene.start_training_target_tracking(stats.stats,world_owner)
	check(tracking and scene.start_training_transit_steering(),"入口路径转向接管")
	for i in range(6):
		await physics_frame
		if ai.transit_latest.get("group")=="predictive-target": break
	check(ai.current_target()==scene.actor and ai.steering_target.get("mode")=="route"
		and ai.steering_target.get("final",false),"超出游走半径的最终路点用 Predictive Target")
	check(ai.transit_latest.get("arrival_stop_radius")==1.0
		and ai.transit_latest.get("target_velocity")==Vector2.ZERO,"原正式停止半径 1，静止活体速度零")
	scene.actor.set_movement_direction(direction)
	var diagnostic: Dictionary = {}
	var moving_samples := 0
	var largest_velocity := 0.0
	for i in range(6):
		await physics_frame
		var observed: Dictionary = ai.transit_latest
		var velocity: Vector2 = observed.get("target_velocity",Vector2.ZERO)
		if velocity.length() > largest_velocity:
			diagnostic = observed
			largest_velocity = velocity.length()
		if velocity.length() > 0.0: moving_samples += 1
	if diagnostic.is_empty():
		check(false,"最终追击使用角色上一物理步的真实速度")
		_end_predictive(scene)
		return
	var sampled: Vector2 = diagnostic.target_velocity
	check(moving_samples >= 3 and sampled.length()>.5 and sampled.length()<4.0001
		and sampled.normalized().dot(direction)>.999,
		"持续移动产生多个真实物理速度读数，保持 Unity XY")
	var scoring_frame := {"position":from,"target":diagnostic.target,"target_velocity":sampled,
		"forward":Vector2.RIGHT,"arrival_stop_radius":1.0}
	var predicted: Vector2 = Solver.solve(scoring_frame,4.0).preferred_velocity
	scoring_frame.target_velocity = Vector2.ZERO
	var unpredicted: Vector2 = Solver.solve(scoring_frame,4.0).preferred_velocity
	check(Vector2(diagnostic.target).is_equal_approx(goal)
		and scene.actor.get_movement_position().distance_to(goal) > .05,
		"缓存路径仍用原终点，目标预测同时读取活动玩家速度")
	var safe: Vector2 = diagnostic.safe_velocity
	check(safe.is_equal_approx(predicted) and safe.distance_to(unpredicted)>.2,
		"转向落在带活体速度的原预测目标，不退化成固定终点")
	trainer_owner.unlocked = true
	for i in range(4):
		await physics_frame
		if trainer.get_movement_position()!=from: break
	check((trainer.get_movement_position()-from).normalized().dot(safe.normalized())>.99,
		"下一步才读取上一拍预测结果并作用实际身体")
	_end_predictive(scene)

func _end_predictive(scene: Node) -> void:
	scene.free()
	if failed==0: print("PASS ClickMoveTest trainer Predictive runtime: %d checks" % n)
	quit(0 if failed==0 else 1)
