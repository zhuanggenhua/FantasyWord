extends SceneTree
## 原地图上的实际假人归位；夹具只布置已有双方的刚体，不写 AI 输出。
const Boot := preload("res://gameplay/clickmovetest/source_startup.gd")
const RAMP := Vector2i(0,3)
const DOWNHILL := Vector2i(1,3)
const START := Vector2(.25,3.85)
const EAST := Vector2(1.5,3.5)
const WAYPOINT := Vector2(2.5,3.5)
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL ",label)

func _cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x),floori(point.y))

func _run() -> void:
	if OS.get_environment("FORMAL_SURFACE_RULES").is_empty():
		print("SKIP 原假人坡道需要私有正式地图规则与角色资源。")
		quit()
		return
	_check(change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))==OK,"正式 F5 入口启动")
	await scene_changed
	await process_frame
	var boot:=current_scene as Boot
	if not is_instance_valid(boot) or not is_instance_valid(boot.scene):
		_check(false,"正式地图未装配")
		_finish()
		return
	var scene:=boot.scene
	var trainer: Node2D=scene.training_target
	var player: Node2D=scene.actor
	_check(is_instance_valid(trainer) and is_instance_valid(player),"正式角色有原摄像机、地图及假人")
	if failures>0: _finish(); return
	var ai: RefCounted=trainer.ai_controller
	var body: Node2D=trainer.body
	var execution: RefCounted=body.execution
	scene.set_physics_process(false)
	body.request_move_position(START)
	# 原玩家先程可能已被探测，远于 10 的追击半径才触发原失距归位。
	player.request_move_position(Vector2(12.5,-2.5))
	for i in 3: await physics_frame
	var ramp_key:=Vector4i(0,RAMP.x,RAMP.y,0)
	var downhill_key:=Vector4i(0,DOWNHILL.x,DOWNHILL.y,0)
	var ramp: Dictionary=scene.route.graph.get_node(ramp_key)
	var downhill: Dictionary=scene.route.graph.get_node(downhill_key)
	_check(body.get_movement_position().is_equal_approx(START) and ramp.get("elevation")==1
		and downhill.get("elevation")==0 and not scene.route.graph.get_edge(ramp_key,downhill_key).is_empty()
		and body.get_movement_position().distance_to(player.get_movement_position())>10.0,
		"真实物理根放在原高坡，东侧为合法低处，主角不在感知半径")
	_check(ai.running and ai._home==Vector2(2.5,-2.75) and not execution.has_move_order() and not execution.is_pushed(),
		"保持正式 AI 的原出生归位点，无点地 MoveOrder 或推力")
	var saw_route:=false
	var saw_distinction:=false
	var sampled_steps:=0
	var direction_matches:=0
	var scales_match:=true
	var consumption_matches:=true
	var crossed:=false
	scene.set_physics_process(true)
	for i in 50:
		var before: Vector2=body.get_movement_position()
		var prior: Dictionary=ai.transit_latest
		await physics_frame
		var after: Vector2=body.get_movement_position()
		var next: Dictionary=ai.transit_latest
		if next.get("target")==WAYPOINT and next.get("group")=="transit" and next.get("arrival_stop_radius")==-1.0 \
				and ai.current_target()==null and ai.steering_target.get("mode")=="route" and not ai.steering_target.get("final",true):
			saw_route=true
		if _cell(before)==RAMP and prior.get("target")==WAYPOINT and prior.get("group")=="transit" \
				and not execution.has_move_order() and not execution.is_pushed():
			var safe: Vector2=prior.safe_direction
			var applied: Vector2=execution.get_last_successful_movement()
			var oracle: Vector2=(EAST-before).normalized()
			if applied.length()>.1 and oracle.distance_to(safe)>.05:
				sampled_steps+=1
				var scale:=clampf(Vector2(prior.safe_velocity).length()/float(prior.max_speed),0.0,1.0)
				var expected_speed: float=body.calculate_move_speed()*body.calculate_speed_multiplier()*scale*execution._filter._smoothed.length()
				if applied.normalized().distance_to(oracle)<.004: direction_matches+=1
				scales_match=scales_match and is_equal_approx(float(prior.speed_scale),scale) \
					and absf(applied.length()-expected_speed)<.003 and prior.push_correction==Vector2.ZERO \
					and prior.neighbour_count==0 and execution._steering_scale==1.0 and execution._steering_correction==Vector2.ZERO
				consumption_matches=consumption_matches and execution._direction.is_equal_approx(safe) \
					and not execution._intent_updates_facing and trainer.get_transit_look().is_equal_approx(safe)
				saw_distinction=saw_distinction or (after.distance_to(before)>.006 and
					(after-before).normalized().distance_to(oracle)<.008 and not applied.normalized().is_equal_approx(safe))
				if sampled_steps==1:
					print("坡道追踪: 原根=%s，安全方向=%s，倍率=%.5f，校正=%s，实际位移速度=%s，预期方向=%s"%
						[before,safe,scale,prior.push_correction,applied,oracle])
		if _cell(after)==DOWNHILL:
			crossed=true
			break
	_check(saw_route,"没有敌人时实际原 AI 用中间路线组归位，首个原压缩路点匹配")
	_check(sampled_steps>=3 and consumption_matches,"持续消费上一真实安全方向，AI 朝向不被坡道替代")
	_check(sampled_steps>=3 and scales_match,"原安全速度倍率、零单体校正与每拍清理各自保持")
	_check(sampled_steps>=3 and direction_matches==sampled_steps and saw_distinction,
		"实际身体位移朝合法东侧低处，而非直接复制上一帧的 AI 安全方向")
	_check(crossed and ai.current_target()==null and not execution.has_move_order() and not execution.is_pushed(),
		"跨入原低层普通格仍是 AI 归位，不是点地命令、战斗或推力")
	_finish()

func _finish() -> void:
	print("%s 原 ClickMoveTest 假人坡道：%d/%d（%s）"%[
		"PASS" if failures==0 else "FAIL",checks-failures,checks,DisplayServer.get_name()])
	quit(int(failures!=0))
