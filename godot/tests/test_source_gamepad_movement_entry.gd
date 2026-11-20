extends SceneTree
const Boot := preload("res://gameplay/clickmovetest/source_startup.gd")
const Move := preload("res://game_core/movement/character_movement.gd")
const Router := preload("res://game_core/movement/keyboard_movement_input.gd")
const Commands := preload("res://game_core/movement/movement_commands.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("FAIL ",label)

func axis(id: JoyAxis,value: float,device := 0) -> InputEventJoypadMotion:
	var e:=InputEventJoypadMotion.new()
	e.axis=id; e.axis_value=value; e.device=device
	return e

func pad(id: JoyButton,down: bool,device := 0) -> void:
	var e:=InputEventJoypadButton.new()
	e.button_index=id; e.pressed=down; e.device=device
	root.push_input(e,true)

func key(id: Key,down: bool) -> void:
	var e:=InputEventKey.new()
	e.keycode=id; e.physical_keycode=id; e.pressed=down
	root.push_input(e,true)

func click(point: Vector2) -> void:
	var motion:=InputEventMouseMotion.new()
	motion.position=point; motion.global_position=point; motion.relative=Vector2.ONE
	root.push_input(motion,true)
	for down in [true,false]:
		var e:=InputEventMouseButton.new()
		e.position=point; e.global_position=point; e.pressed=down; e.button_index=MOUSE_BUTTON_LEFT
		root.push_input(e,true)

func unit() -> void:
	var r:=Router.new()
	var trace: Array=[]
	var receive:=func(k: int,d: Vector2,_p: Variant): trace.append([k,d])
	r.observe_move(axis(JOY_AXIS_LEFT_X,.125),true,false,receive)
	r.observe_move(axis(JOY_AXIS_LEFT_X,.08),true,false,receive)
	r.observe_move(axis(JOY_AXIS_LEFT_Y,-.08),true,false,receive)
	_check(trace.is_empty(),"原径向死区拒绝边界和不足半径")
	r.observe_move(axis(JOY_AXIS_LEFT_Y,-.10),true,false,receive)
	_check(trace.size()==1 and trace[0][1].is_equal_approx(Vector2(.08,.10).normalized()),
		"每轴低于阈值但联合半径合格，输出归一化")
	var w:=InputEventKey.new()
	w.physical_keycode=KEY_W; w.pressed=true
	r.handle_key(w,false,receive)
	r.observe_move(axis(JOY_AXIS_LEFT_X,1.0),true,false,receive)
	_check(trace.size()==2 and r.get_direction()==Vector2(0,1),
		"未配对的 Godot 混合输入仍按控制量级和当前驱动平手规则，不合并")
	w.pressed=false
	r.handle_key(w,false,receive)
	_check(trace.size()==3 and r.get_direction().x>.99,"松开键盘后交接到原左摇杆")
	r.deactivate(receive,true)
	r.observe_move(axis(JOY_AXIS_LEFT_Y,1),false)
	_check(trace.size()==4 and trace[-1][0]==Commands.Kind.STOP_MOVE,
		"禁用取消一次，UI 仅跟踪物理值")
	r.sample_enabled_action(false,receive)
	_check(trace.size()==5 and trace[-1][1].is_equal_approx(Vector2(1,-1).normalized()),
		"重启 Value 在后续采样求最新物理方向")

func _run() -> void:
	unit()
	var fixture:=OS.get_environment("FORMAL_PAUSE_SOURCE")
	if fixture.is_empty() or not FileAccess.file_exists(fixture.path_join("abilities-layout.json")):
		print("SKIP 真实场景移动与暂停需要私有素材；仅验源动作合同。")
		_finish()
		return
	root.size=Vector2i(800,600)
	_check(change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))==OK,"真实项目入口")
	await scene_changed
	await process_frame
	await process_frame
	var boot:=current_scene as Boot
	if boot==null or boot.pause_root==null:
		_check(false,"原暂停未绑定"); _finish(); return
	var s:=boot.scene
	var actor: Node2D=s.actor
	s.training_target.ai_controller.stop()
	_check(s.movement.mode==Move.Mode.CLICK_TO_MOVE,"原测试面板启动成点击移动")
	click(Vector2(430,245))
	_check(actor.execution.has_move_order(),"实际点击建立路径")
	pad(JOY_BUTTON_RIGHT_STICK,true,1)
	_check(actor.execution.has_move_order() and s.movement.mode==Move.Mode.CLICK_TO_MOVE,"另一个设备无控制权")
	pad(JOY_BUTTON_RIGHT_STICK,true)
	pad(JOY_BUTTON_RIGHT_STICK,true)
	_check(s.movement.mode==Move.Mode.DIRECTIONAL and not actor.execution.has_move_order(),
		"实际右摇杆按下切同一主角，清正在运行的点击路径，重复 press 不切回")
	key(KEY_TAB,true)
	pad(JOY_BUTTON_RIGHT_STICK,false)
	key(KEY_TAB,false)
	_check(s.movement.mode==Move.Mode.DIRECTIONAL,"原 Tab 别名重叠不重复切换")
	var pos: Vector2=actor.get_movement_position()
	root.push_input(axis(JOY_AXIS_LEFT_X,.08),true); root.push_input(axis(JOY_AXIS_LEFT_Y,-.08),true)
	_check(actor.execution._direction==Vector2.ZERO,"微小偏移不移动")
	root.push_input(axis(JOY_AXIS_LEFT_X,.60),true); root.push_input(axis(JOY_AXIS_LEFT_Y,-.60),true)
	_check(actor.execution._direction.is_equal_approx(Vector2.ONE.normalized()),
		"真实角色执行单位斜向，不用比例速度")
	var walked:=false
	for i in range(12):
		await physics_frame
		walked=walked or s.human_presentation.driver.current_animation_key=="Walk"
	var advanced: Vector2=actor.get_movement_position()
	_check(advanced.x>pos.x+.1 and advanced.y>pos.y+.1 and walked,
		"原角色真实斜向位移并播放 Walk")
	root.push_input(axis(JOY_AXIS_LEFT_X,0),true); root.push_input(axis(JOY_AXIS_LEFT_Y,0),true)
	_check(actor.execution._direction==Vector2.ZERO,"回中对同一角色 StopMove")
	for i in 3: await physics_frame
	pos=actor.get_movement_position()
	for i in 7: await physics_frame
	_check(actor.get_movement_position().is_equal_approx(pos),"回中后无持续位移")
	click(Vector2(430,245))
	_check(not actor.execution.has_move_order(),"方向模式中点击不重开路径")
	root.push_input(axis(JOY_AXIS_LEFT_X,.55),true)
	key(KEY_TAB,true); key(KEY_TAB,false)
	key(KEY_TAB,true); key(KEY_TAB,false)
	root.push_input(axis(JOY_AXIS_LEFT_X,.55),true)
	_check(s.movement.mode==Move.Mode.DIRECTIONAL and actor.execution._direction==Vector2.ZERO,
		"同一动作图切模式清空意图，不重采样不变的摇杆")
	root.push_input(axis(JOY_AXIS_LEFT_X,.58),true)
	_check(actor.execution._direction==Vector2.RIGHT,"摇杆真实变化后同一控制链恢复")
	pad(JOY_BUTTON_START,true); pad(JOY_BUTTON_START,false)
	_check(paused and actor.execution._direction==Vector2.ZERO,"Pause 禁用 Move 并停止当前意图")
	pad(JOY_BUTTON_B,true); pad(JOY_BUTTON_B,false)
	for i in 3: await physics_frame
	_check(not paused and actor.execution._direction==Vector2.RIGHT,
		"恢复后 Value 初采样接续一直偏转的原摇杆")
	pad(JOY_BUTTON_START,true); pad(JOY_BUTTON_START,false)
	root.push_input(axis(JOY_AXIS_LEFT_X,0),true)
	root.push_input(axis(JOY_AXIS_LEFT_Y,.60),true)
	pad(JOY_BUTTON_B,true); pad(JOY_BUTTON_B,false)
	for i in 3: await physics_frame
	_check(not paused and actor.execution._direction==Vector2(0,-1),"暂停时改变偏转使用最新方向")
	pad(JOY_BUTTON_START,true); pad(JOY_BUTTON_START,false)
	root.push_input(axis(JOY_AXIS_LEFT_Y,0),true)
	pad(JOY_BUTTON_B,true); pad(JOY_BUTTON_B,false)
	for i in 3: await physics_frame
	_check(not paused and actor.execution._direction==Vector2.ZERO,"暂停中松回中则恢复后不重启移动")
	_finish()

func _finish() -> void:
	print("%s 原手柄移动与暂停：%d/%d（%s）"%[
		"PASS" if failures==0 else "FAIL",checks-failures,checks,DisplayServer.get_name()])
	quit(int(failures!=0))
