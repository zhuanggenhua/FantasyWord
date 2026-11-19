extends "res://tests/test_clickmovetest_trainer_transit.gd"

class TrainerOwner extends TransitOwner:
	var unlocked := true
	var target_direction := Vector2.ZERO
	func can_move() -> bool: return unlocked
	func set_target_direction(value: Vector2) -> void: target_direction = value

class Draws extends RefCounted:
	var calls: Array = []
	var sign_sample := 0.5
	func read_value() -> float:
		calls.append("value")
		return sign_sample
	func read_range(minimum: float, maximum: float) -> float:
		calls.append([minimum,maximum])
		return minimum

func run() -> void:
	var scene = Entry.instantiate()
	root.add_child(scene)
	var owner := TrackingOwner.new()
	var player := Player.new()
	player.actor = scene.actor
	var events := MapEvents.new()
	var private_rules := OS.get_environment("FORMAL_SURFACE_RULES")
	var art_dir := OS.get_environment("FORMAL_TRAINER_ATTACK_TEXTURES")
	var attack_file := OS.get_environment("FORMAL_TRAINER_ATTACK_ANIMATION")
	var material_file := OS.get_environment("FORMAL_TRAINER_ATTACK_MATERIAL")
	var fixture_dir := ProjectSettings.globalize_path("user://trainer-wander")
	var pack: Array = []
	if private_rules.is_empty() or attack_file.is_empty(): pack = fixtures(scene,fixture_dir)
	var rules: Dictionary = read(private_rules) if not private_rules.is_empty() else pack[0]
	if not scene.start_logic(owner,rules,func():return player,func():return null,events,func(_p):return false):
		check(false,"原 Entry 启动")
		_end_wander(scene)
		return
	var trainer_owner := TrainerOwner.new()
	var trainer = scene.start_training_damage_target(trainer_owner,trainer_owner.hooks(),7752)
	if not is_instance_valid(trainer):
		check(false,"原场景活动假人")
		_end_wander(scene)
		return
	var world_owner := Node2D.new()
	scene.add_child(world_owner)
	var stats := Attributes.new()
	check(stats.configure(PackedInt32Array([100,40,10,6,6,4,8,4,100]),Combat.Alignment.GOOD,
		func():return false),"原玩家正式属性")
	var draws := Draws.new()
	check(not scene.start_training_combat_wander(draws.read_value,draws.read_range),"不另开一个游走求解世界")
	check(scene.start_training_target_tracking(stats.stats,world_owner)
		and scene.start_training_transit_steering(),"同一实际玩家、原地图和单体转向")
	check(not scene.start_training_combat_wander(draws.read_value,Callable()),"需要两项源抽样入口")
	if not scene.start_training_combat_wander(draws.read_value,draws.read_range):
		check(false,"有效源抽样入口可绑定")
		_end_wander(scene)
		return
	check(not scene.start_training_combat_wander(draws.read_value,draws.read_range),"不替换活动游走状态")
	var ai = trainer.ai_controller
	var spawn: Vector2 = trainer.get_movement_position()
	check(spawn==trainer.SOURCE_POSITION and scene.actor.get_movement_position()==Vector2.ZERO,
		"真实原始出生点，不预置目标或游走位置")
	var saw_transit := false
	var first_wander: Dictionary = {}
	var prior: Dictionary = {}
	for i in range(110):
		await physics_frame
		var step: Dictionary = ai.transit_latest
		if step.get("group")=="combat-wander":
			first_wander = step
			break
		if step.get("group")=="transit": saw_transit = true
		prior = step
	check(saw_transit and not first_wander.is_empty() and trainer.get_movement_position()!=spawn,
		"从原出生点走真实路径，自然进入三米内的原游走优先分支")
	if first_wander.is_empty():
		_end_wander(scene)
		return
	check(draws.calls==["value",[1.0,3.0]] and first_wander.wander_intent=={"side_sign":-1.0,"follow_distance":1.0},
		"在源分支第一次进入时按 value→Range 顺序，0.5 仍选负侧")
	check(ai.current_target()==scene.actor and first_wander.detected_colliders.has(scene.actor)
		and first_wander.neighbour_count==0 and first_wander.push_correction==Vector2.ZERO
		and first_wander.max_speed==4.0 and first_wander.arrival_stop_radius==-1.0,
		"真实角色被感知但未注册为互避邻居，不伪造推力或套用停止半径")
	var first_safe: Vector2 = first_wander.safe_direction
	var transitioned_from: Vector2 = prior.get("safe_direction",Vector2.ZERO)
	var first_at: Vector2 = trainer.get_movement_position()
	var first_look: Vector2 = trainer_owner.look_at
	if prior.has("origin"):
		check((first_at-Vector2(prior.origin)).normalized().dot(transitioned_from)>.99
			and not first_safe.is_equal_approx(transitioned_from),
			"同拍提交新组但仍用上一拍的实际安全方向")
	await physics_frame
	var next_at: Vector2 = trainer.get_movement_position()
	check((next_at-first_at).normalized().dot(first_safe)>.99 and trainer_owner.look_at==first_look,
		"下一步应用游走安全方向，KeepCurrent 不抢朝向")
	trainer_owner.unlocked = false
	var direction: Vector2 = (scene.actor.get_movement_position()-next_at).normalized()
	scene.actor.request_move_position(next_at+direction*3.6)
	var left := false
	for i in range(12):
		await physics_frame
		if ai.steering_target.get("group")!="combat-wander":
			left = true
			break
	check(left,"玩家的实际身体移出游走组")
	var remaining: float = ai._wander.wander.direction_change_timer
	await ticks(82)
	check(draws.calls.size()==2 and ai._wander.wander.direction_change_timer==remaining
		and remaining>0.0,"离开分支超过1.5秒也不消耗或重置游走缓存")
	scene.actor.request_move_position(Vector2.ZERO)
	var returned := false
	for i in range(12):
		await physics_frame
		if ai.transit_latest.get("group")=="combat-wander":
			returned = true
			break
	check(returned and draws.calls.size()==2 and ai._wander.wander.direction_change_timer<remaining,
		"实际角色回到三米内，沿用原意图并从冻结计时继续")
	draws.sign_sample = 1.1
	for i in range(90):
		await physics_frame
		if draws.calls.size()>2: break
	check(draws.calls==["value",[1.0,3.0],"value"] and ai.steering_target.get("group")=="combat-wander"
		and ai.transit_latest.is_empty(),"到源续期收到不合法样本时，不补抽距离、不复用旧结果、不退为追击")
	draws.sign_sample = 1.0
	await physics_frame
	check(draws.calls.size()==5 and ai.transit_latest.get("wander_intent",{}).get("side_sign")==1.0,
		"调用方下一拍恢复合法抽样后，原组恢复并接收闭区间另一端")
	# 从同一个持续运行的控制器接原正式攻击。近身操作只用于验证射程，
	# 不假定固定玩家必然被源码游走轨迹逼进严格小于 1 的攻击半径。
	var animation: Dictionary
	var material := {}
	if not attack_file.is_empty() and not art_dir.is_empty():
		animation = read(attack_file)
		if not material_file.is_empty():
			material = {"data":read(material_file),"uv_directory":art_dir.path_join("uv"),
				"appearance_directory":art_dir.path_join("appearance")}
	else:
		art_dir = fixture_dir
		animation = pack[1]
		animation.actions["Dmg"] = animation.actions.Idle.duplicate(true)
		animation.actions.Dmg.loop = false
		animation.actions.Dmg.duration = .5
		animation.actions["Attack"] = animation.actions.Dmg.duplicate(true)
		animation.training_target = {"prefab_guid":trainer.VISUAL_PREFAB,
			"runtime_libraries":trainer.VISUAL_LIBRARIES,"body_local_position":[0,0]}
	var view: Node2D = scene.start_training_target_presentation(animation,art_dir,material)
	var hooks := {"provoke":func(_source):pass,"has_formal_stats":stats.has_formal_stats,
		"current_health":stats.current_health,"prepare":func(_source,_hit):pass,
		"apply_current_health_delta":stats.apply_current_health_delta,
		"complete":func(_source,_hit,_before,_amount):pass}
	var ability: Node = scene.start_training_basic_attack(func():return Vector2(0,1),hooks,func():return 50)
	check(is_instance_valid(view) and is_instance_valid(ability),"同一假人绑定原动作与正式 20001")
	if is_instance_valid(ability):
		scene.set_process(false)
		trainer_owner.set_look_at_direction(Vector2.LEFT)
		scene.actor.request_move_position(trainer.get_movement_position()+Vector2(0,-.72))
		var waiting := false
		for i in range(12):
			await physics_frame
			waiting = waiting or ai.behaviour.waiting_for_attack_facing
			if ability.runtime.local_active: break
		check(waiting and ability.runtime.local_active and ai.transit_latest.get("group")=="combat-wander"
			and trainer_owner.look_at.is_equal_approx(Vector2(0,-1)),
			"真实角色进入射程，先对准后出手，来源仍为活动游走假人")
		ability.advance(.02)
		ability.advance(.04)
		ability.advance(.08)
		check(ability.timeline.frame==7 and stats.current_health()==100,"同场演进至原命中前第7帧")
		ability.advance(.02)
		check(ability.timeline.frame==8 and stats.current_health()==97,
			"原第8帧用实际子受击盒命中，未替换玩家或写死扣血")
	ai.stop()
	check(not ai.running and ai._wander==null and ai.transit_latest.is_empty(),"正式停控制器清游走意图及世界结果")
	_end_wander(scene)

func _end_wander(scene: Node) -> void:
	scene.free()
	if failed==0: print("PASS ClickMoveTest trainer Wander runtime: %d checks" % n)
	quit(0 if failed==0 else 1)
