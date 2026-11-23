extends SceneTree
## 锁定地图坡道上的真实角色输入；不创建替代碰撞体或角色。
const Boot := preload("res://gameplay/clickmovetest/source_startup.gd")
const Move := preload("res://game_core/movement/character_movement.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL ",label)

func _key(code: Key, pressed: bool) -> void:
	var event:=InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=pressed
	root.push_input(event,true)

func _axis(axis: JoyAxis, value: float) -> void:
	var event:=InputEventJoypadMotion.new()
	event.axis=axis
	event.axis_value=value
	event.device=0
	root.push_input(event,true)

func _click_source_world(world: Vector2) -> void:
	var point:=root.get_canvas_transform()*Vector2(world.x,-world.y)
	var move:=InputEventMouseMotion.new()
	move.device=0
	move.position=point
	move.relative=Vector2.ONE
	root.push_input(move,true)
	for down in [true,false]:
		var event:=InputEventMouseButton.new()
		event.device=0
		event.button_index=MOUSE_BUTTON_LEFT
		event.position=point
		event.pressed=down
		root.push_input(event,true)

func _prepare(actor: Node2D, at: Vector2) -> void:
	# 夹具只把主角置于已知的作者格，运动由正常固定步与输入驱动。
	actor.request_move_position(at)
	for i in 3: await physics_frame
	_check(actor.get_movement_position().is_equal_approx(at),"作者测试坐标上的实际主角物理根")

func _run() -> void:
	if OS.get_environment("FORMAL_SURFACE_RULES").is_empty():
		print("SKIP 原坡道实际 F5 需要私有地图规则与正式角色资源。")
		quit()
		return
	root.size=Vector2i(960,540)
	_check(change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))==OK,"实际 F5 主场景")
	await scene_changed
	await process_frame
	var boot:=current_scene as Boot
	_check(is_instance_valid(boot) and is_instance_valid(boot.scene),"实际地图、角色与碰撞装配")
	if failures>0: _finish(); return
	var scene:=boot.scene
	var actor: Node2D=scene.actor
	scene.training_target.ai_controller.stop()
	var lower:=Vector2(.5,2.5)
	await _prepare(actor,lower)
	_key(KEY_TAB,true); _key(KEY_TAB,false)
	_check(scene.movement.mode==Move.Mode.DIRECTIONAL,"真实 Tab 切换原方向模式")
	_key(KEY_W,true); _key(KEY_A,true)
	for i in 7: await physics_frame
	var walked: Vector2=actor.get_movement_position()-lower
	_check(walked.y>.12 and absf(walked.x)<.001 and
		actor.execution._direction.is_equal_approx(Vector2(-1,1).normalized()),
		"坡道左上输入在实体地图只向合法上侧，原方向命令未被改写")
	_check(scene.human_presentation.driver.current_animation_key=="Walk"
		and actor.execution._last_successful_movement.y>0,
		"真实 Walk 继续由已发生的位移驱动，不由格子或直接动画调用生成")
	_key(KEY_W,false); _key(KEY_A,false)
	for i in 12: await physics_frame
	await _prepare(actor,lower)
	_axis(JOY_AXIS_LEFT_X,0.8); _axis(JOY_AXIS_LEFT_Y,-0.8)
	for i in 7: await physics_frame
	var moved: Vector2=actor.get_movement_position()-lower
	_check(moved.x>.12 and absf(moved.y)<.001,
		"原同分方向先选右邻；已选边随当前实际身体位置继续评分")
	_axis(JOY_AXIS_LEFT_X,0); _axis(JOY_AXIS_LEFT_Y,0)
	for i in 12: await physics_frame
	var plain:=Vector2(.5,.5)
	await _prepare(actor,plain)
	_key(KEY_W,true); _key(KEY_A,true)
	for i in 7: await physics_frame
	var diagonal: Vector2=actor.get_movement_position()-plain
	_check(diagonal.y>.12 and diagonal.x<-.12 and is_equal_approx(diagonal.y,-diagonal.x),
		"邻接平地仍按普通斜向移动，不把坡道规则套到任何格子")
	_key(KEY_W,false); _key(KEY_A,false)
	for i in 12: await physics_frame
	await _prepare(actor,lower)
	_key(KEY_TAB,true); _key(KEY_TAB,false)
	var goal:=Vector2(.25,2.75)
	_click_source_world(goal)
	_check(scene.movement.mode==Move.Mode.CLICK_TO_MOVE and actor.execution.has_move_order()
		and actor.execution._route[-1].is_equal_approx(goal),"真实点地仍产生原坡道格内精确目标")
	for i in 4: await physics_frame
	var click_step: Vector2=actor.get_movement_position()-lower
	_check(click_step.x<-.06 and click_step.y>.06,
		"已建路径的物理跟随保持斜线，不误套方向输入的坡道投影")
	_finish()

func _finish() -> void:
	print("%s 原 ClickMoveTest 方向坡道：%d/%d（%s）"%[
		"PASS" if failures==0 else "FAIL", checks-failures,checks,DisplayServer.get_name()])
	quit(int(failures!=0))
