extends SceneTree
## 由正式项目入口加载唯一原活动假人；不使用 CLI 诊断或替身血条。
const Startup := preload("res://gameplay/clickmovetest/source_startup.gd")
const Terrain := preload("res://game_core/movement/terrain_cast.gd")
const Draws := preload("res://gameplay/clickmovetest/source_session_draws.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var probe:=RandomNumberGenerator.new()
	probe.seed=31629
	var local_draws:=Draws.new(probe)
	var replay:=RandomNumberGenerator.new()
	replay.seed=31629
	var in_range:=true
	for i in range(50):
		var sign_value := local_draws.value()
		var range_value := local_draws.inclusive_range(1,3)
		var hit_roll := local_draws.resolve_damage()
		var first := float(replay.randi_range(0,Draws.CLOSED_STEPS))/float(Draws.CLOSED_STEPS)
		var second: float = PackedFloat32Array([lerpf(1,3,float(replay.randi_range(0,Draws.CLOSED_STEPS))/Draws.CLOSED_STEPS)])[0]
		in_range=in_range and sign_value==first and range_value==second and hit_roll==replay.randi_range(1,99) \
			and sign_value>=0 and sign_value<=1 and range_value>=1 and range_value<=3 and hit_roll>=1 and hit_roll<=99
	_check(in_range,"共享随机流每次只取对应用途的一次抽样，不使用固定诊断值")
	if OS.get_environment("FORMAL_SURFACE_RULES").is_empty():
		print("SKIP 正常项目实际假人；需要原资源")
		_finish()
		return
	root.size=Vector2i(800,600)
	if change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))!=OK:
		quit(1)
		return
	await scene_changed
	await process_frame
	var start := current_scene as Startup
	var scene := start.scene
	var trainer: Node2D=scene.training_target
	var actor: Node2D=scene.actor
	var health:=start.player.current_health()
	var trainer_start: Vector2=trainer.get_movement_position()
	var controller: Object=trainer.ai_controller
	_check(Terrain.to_physics(trainer.position)==trainer.SOURCE_POSITION and trainer.health==220 \
		and controller.running and is_instance_valid(trainer.formal_attack)
		and trainer.presentation.driver.resolve_playable_state("SpinDie")=="SpinDie",
		"正常启动原出生点、220 HP、正式 20001、原死亡图 %s/HP%s/run%s/atk%s/death%s" % [trainer_start,trainer.health,controller.running,is_instance_valid(trainer.formal_attack),trainer.presentation.driver.resolve_playable_state("SpinDie")])
	_check(start._source_draws!=null and controller._wander_random_value.get_object()==start._source_draws
		and trainer.formal_attack._roll.get_object()==start._source_draws,
		"普通场景同一抽样来源同时供原假人游走和角色攻击")
	var repath := false
	for i in range(140):
		await physics_frame
		repath = repath or not controller.transit_latest.is_empty()
		if repath and controller.current_target()==actor: break
	_check(repath and controller.current_target()==actor,"不先移动主角也由实际原地图取得玩家并提交移动")
	# 仅缩短测试路程；留给原 AI 真正取得转向与 20001，绝不直接结算伤害。
	var seen_damage := []
	start.player.damage_completed.connect(func(_src,_input,previous,applied):
		seen_damage.append([previous,applied,start.damage_screen_flash.color.a]))
	for i in range(230):
		if i%12==0:
			var current: Vector2=trainer.get_movement_position()
			actor.request_move_position(current+Vector2(0,-.63))
		await physics_frame
		if not seen_damage.is_empty(): break
	_check(not seen_damage.is_empty() and seen_damage.front()[0]==health
		and seen_damage.front()[1]>0 and seen_damage.front()[2]>0.0,
		"原 AI 普攻确实通过同一角色的受击盒及闪屏，不是测试直接写血")
	# 第二段用作者验证站位隔离移动时序，不新增角色或直接触发伤害。
	# 保留当前假人的真实状态，但让它上一刀自然结束再观察玩家原第一槽。
	scene.set_process(false)
	scene.set_physics_process(false)
	trainer.body.request_move_position(Vector2(2.5,-2.75))
	actor.request_move_position(Vector2(1.75,-2.35))
	await physics_frame
	await physics_frame
	trainer.formal_attack.advance(.5)
	scene.advance_human_damage_lifecycle()
	scene.advance_human_charged_combat(.1)
	start.player.set_target_direction(Vector2.RIGHT)
	start.player.set_look_at_direction(Vector2.RIGHT)
	var old_health: int=trainer.health
	scene.training_attributes.apply_current_health_delta(1-old_health,0,null,null)
	var outgoing := []
	start.trainer_owner.damage_completed.connect(func(_src,_input,previous,applied):
		outgoing.append([previous,applied]))
	for attack in range(5):
		_key(KEY_1,true)
		scene.advance_human_charged_combat(.018)
		scene.advance_human_charged_combat(.12)
		scene.advance_human_charged_combat(.02)
		_key(KEY_1,false)
		if trainer.health==0: break
		scene.advance_human_charged_combat(.5)
		scene.advance_human_charged_combat(.018)
		# 短间隔多次取样，不改变随机供应器。
	_check(trainer.health==0 and outgoing==[[1,1]],"玩家真实普攻键及正式碰撞结算使活假人归零一次")
	scene.advance_human_damage_lifecycle()
	trainer.advance_damage_lifecycle()
	await process_frame
	_check(not trainer.ai_controller.running and trainer.presentation.driver.current_animation_key=="SpinDie"
		and trainer==scene.training_target and trainer.is_inside_tree(),
		"原安全死亡停止 AI 并保留 SpinDie 身体，不发明复活")
	_finish()

func _mouse(at: Vector2) -> void:
	var event:=InputEventMouseMotion.new()
	event.device=0
	event.position=root.get_canvas_transform()*Terrain.to_physics(at)
	event.relative=Vector2(1,1)
	root.push_input(event,true)

func _key(code: Key, down: bool) -> void:
	var event:=InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=down
	root.push_input(event,true)

func _check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",label)

func _finish() -> void:
	if not failures: print("PASS 正常入口活动假人：%d 项（%s）" % [checks,DisplayServer.get_name()])
	quit(1 if failures else 0)
