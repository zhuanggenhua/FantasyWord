extends SceneTree
const Boot := preload("res://gameplay/clickmovetest/source_startup.gd")
const Pause := preload("res://gameplay/clickmovetest/source_pause_focus_view.gd")
const Settings := preload("res://gameplay/clickmovetest/source_settings_view.gd")
const Gamepad := preload("res://game_core/input/source_gamepad_navigate.gd")
const Dpad := preload("res://game_core/input/source_dpad_navigate.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("FAIL ",label)

func _button(id: JoyButton, down: bool, device := 0) -> InputEventJoypadButton:
	var e:=InputEventJoypadButton.new()
	e.button_index=id; e.pressed=down; e.device=device
	return e

func _pad(id: JoyButton, down: bool, device := 0) -> void:
	root.push_input(_button(id,down,device),true)

func _axis_event(id: JoyAxis, value: float, device := 0) -> InputEventJoypadMotion:
	var e:=InputEventJoypadMotion.new()
	e.axis=id; e.axis_value=value; e.device=device
	return e

func _axis(id: JoyAxis, value: float, device := 0) -> void:
	root.push_input(_axis_event(id,value,device),true)

func _tap(id: JoyButton) -> void:
	_pad(id,true); _pad(id,false)

func _point(at: Vector2) -> void:
	var e:=InputEventMouseMotion.new()
	e.device=0; e.position=at; e.global_position=at; e.relative=Vector2.ONE
	root.push_input(e,true)

func _settle() -> void:
	await process_frame
	await process_frame

func _focus_then_leave(view: Pause, action: int) -> void:
	for row: Dictionary in view._entries:
		if row.action==action: _point(row.icon.get_center()*(root.get_visible_rect().size.y/1080.0))
	await _settle()
	_check(view.selected_action()==action,"点中真实原菜单条目 %s"%action)
	_point(Vector2(280,148))
	await _settle()

func _unit() -> void:
	var d := Dpad.new()
	_check(d.observe(_button(JOY_BUTTON_DPAD_UP,true),false) and d.take_direction()==null,
		"Gameplay 只持有物理状态，启用 PassThrough 无初采样")
	d.observe(_button(JOY_BUTTON_DPAD_RIGHT,true),true)
	_check(d.take_direction()==Vector2i.UP,"切图后的真实改变读取整个 D-pad，斜向垂直优先")
	d.observe(_button(JOY_BUTTON_DPAD_RIGHT,false),true)
	d.observe(_button(JOY_BUTTON_DPAD_DOWN,true),true)
	_check(d.take_direction()==Vector2i.ZERO and d.take_direction()==null,
		"同更新取最终合成零，和无回调区分")
	d.observe(_button(JOY_BUTTON_DPAD_UP,false),true)
	_check(d.take_direction()==Vector2i.DOWN,"松一侧保留对向实际值")
	d.observe(_button(JOY_BUTTON_DPAD_DOWN,true),true)
	_check(d.take_direction()==null and not d.observe(_button(JOY_BUTTON_DPAD_LEFT,true,1),true),
		"重复同边沿和未配对设备不改变方向")
	d.observe(_button(JOY_BUTTON_DPAD_LEFT,true),true)
	d.reset_device()
	d.observe(_button(JOY_BUTTON_DPAD_RIGHT,true),true)
	_check(d.take_direction()==Vector2i.RIGHT,"失焦清理物理值和未处理动作")

func _unit_stick() -> void:
	var g:=Gamepad.new()
	_check(g.observe(_axis_event(JOY_AXIS_LEFT_X,.52),false) and g.take_direction()==null,
		"在 Gameplay 记录物理轴，不发布菜单 Navigate")
	g.observe(_axis_event(JOY_AXIS_TRIGGER_LEFT,.8),true)
	_check(g.take_direction()==null and not g.observe(_axis_event(JOY_AXIS_LEFT_X,.8,1),true),
		"扳机和其他设备不是原 Navigate 方向")
	g.observe(_axis_event(JOY_AXIS_LEFT_X,.521),true)
	_check(g.take_direction()==Vector2i.ZERO,"半轴阈值下仍可发布原零向量")
	g.observe(_axis_event(JOY_AXIS_LEFT_X,.53),true)
	_check(g.take_direction()==Vector2i.RIGHT,"默认数字半轴大约 .525 触发")
	g.observe(_button(JOY_BUTTON_DPAD_LEFT,true),true)
	g.observe(_axis_event(JOY_AXIS_LEFT_X,.53),true)
	_check(g.take_direction()==Vector2i.LEFT,"不变的轴记录不覆盖真实 D-pad")
	g.observe(_axis_event(JOY_AXIS_LEFT_X,.531),true)
	_check(g.take_direction()==Vector2i.RIGHT,"同一数字区的新原始轴记录仍覆盖 D-pad")
	g.observe(_axis_event(JOY_AXIS_RIGHT_Y,-.8),true)
	_check(g.take_direction()==Vector2i.UP,"两只摇杆共享复合向量并以纵向平手优先")
	g.reset_device()
	g.observe(_axis_event(JOY_AXIS_RIGHT_Y,.2),true)
	_check(g.take_direction()==Vector2i.ZERO,"失焦清除左右杆和待派发方向")

func _stick_cases(boot: Boot) -> void:
	var stack:=boot.pause_root.stack
	_axis(JOY_AXIS_RIGHT_Y,.8)
	_tap(JOY_BUTTON_START)
	var pause:=stack.top() as Pause
	if pause==null:
		_check(false,"Start 未打开原暂停（摇杆）"); return
	await _settle()
	await _focus_then_leave(pause,3)
	_axis(JOY_AXIS_RIGHT_Y,.8)
	await _settle()
	_check(pause.selected_action()==3,"预偏转和重复原始状态均无初始菜单 Move")
	_tap(JOY_BUTTON_A)
	_axis(JOY_AXIS_RIGHT_Y,.81)
	await _settle()
	var settings:=stack.top() as Settings
	_check(settings!=null and stack.depth()==2,"右杆变化先移到真实 Settings，再执行同帧南键")
	if settings==null: return
	_axis(JOY_AXIS_RIGHT_Y,0)
	await _settle()
	var before: float=settings._prefs.volume(-1)
	_axis(JOY_AXIS_LEFT_X,.52)
	_axis(JOY_AXIS_RIGHT_X,.9,1)
	await _settle()
	_check(settings.selected_action()==1,"半轴低于阈值或别的设备均不改变真实焦点")
	_axis(JOY_AXIS_LEFT_X,.53)
	_tap(JOY_BUTTON_A)
	await _settle()
	_check(settings.selected_action()==2 and is_equal_approx(settings._prefs.volume(-1),minf(1.0,before+.1)),
		"左杆跨阈值并提交后，原 Master 数值真的增加一档")
	_axis(JOY_AXIS_RIGHT_X,.83)
	_axis(JOY_AXIS_LEFT_X,0)
	await _settle()
	_check(settings.selected_action()==2,"同向由右杆继续保持，不重新启动移动")
	_axis(JOY_AXIS_LEFT_X,-.8)
	await _settle()
	_check(settings.selected_action()==2,"异侧摇杆方向对抗时抵消")
	_axis(JOY_AXIS_RIGHT_X,0)
	await _settle()
	_check(settings.selected_action()==1,"松开一侧后剩余的左向移动实际焦点")
	_axis(JOY_AXIS_LEFT_X,.8)
	_axis(JOY_AXIS_RIGHT_Y,.84)
	await _settle()
	_check(settings.selected_action()==3,"跨杆同更新斜向优先 Down，只有一次移动")
	_axis(JOY_AXIS_LEFT_X,0)
	_axis(JOY_AXIS_RIGHT_Y,0)
	await _settle()
	_axis(JOY_AXIS_LEFT_X,.2)
	_axis(JOY_AXIS_LEFT_Y,.2)
	await _settle()
	_check(settings.selected_action()==3,"小斜向不是玩法径向阈值，不移动菜单")
	_axis(JOY_AXIS_LEFT_X,0); _axis(JOY_AXIS_LEFT_Y,0)
	await _settle()

	var started:=Time.get_ticks_usec()
	_pad(JOY_BUTTON_DPAD_DOWN,true)
	await _settle()
	_check(settings.selected_action()==5,"D-pad 输入仍覆盖摇杆零方向")
	var repeated:=await _wait_for(settings,7,started+1200000)
	_check(repeated!=0,"真实连发开始后才能检查摇杆原始零向量")
	_axis(JOY_AXIS_LEFT_X,.25)
	_axis(JOY_AXIS_LEFT_X,.25)
	var next:=await _wait_for(settings,9,Time.get_ticks_usec()+230000)
	_check(next==0 and settings.selected_action()==7,"零向量覆盖仍按住的 D-pad 并终止连发")
	_pad(JOY_BUTTON_DPAD_DOWN,false)
	await _settle()
	_axis(JOY_AXIS_RIGHT_X,.8)
	await _settle()
	_check(settings.selected_action()==8,"右杆重新发送方向")
	_pad(JOY_BUTTON_DPAD_LEFT,true)
	await _settle()
	_check(settings.selected_action()==7,"D-pad 不与仍偏转的右杆合成")
	_axis(JOY_AXIS_RIGHT_X,.8)
	await _settle()
	_check(settings.selected_action()==7,"同原始值不能从真实 D-pad 抢回方向")
	_axis(JOY_AXIS_RIGHT_X,.81)
	await _settle()
	_check(settings.selected_action()==8,"同数字区的真实原始变化可从 D-pad 重新接管")
	_pad(JOY_BUTTON_DPAD_LEFT,false)
	_axis(JOY_AXIS_RIGHT_X,0)
	await _settle()
	_tap(JOY_BUTTON_B)
	_check(stack.top()==pause and pause.selected_action()==7,"East 仍只退出真实一层并恢复焦点")
	var original_pause_id := pause.get_instance_id()
	_axis(JOY_AXIS_RIGHT_Y,.8)
	_tap(JOY_BUTTON_B)
	_check(stack.depth()==0 and not stack.get_tree().paused and is_instance_valid(pause) and not pause.visible
		and pause.process_mode==Node.PROCESS_MODE_DISABLED and pause.selected_action()==0 and not pause.label_visible(7),
		"正常关闭令原 Pause 退出动作图、停止参与输入，不销毁缓存")
	_tap(JOY_BUTTON_START)
	var reopened:=stack.top() as Pause
	if reopened==null:
		_check(false,"快速重开失败"); return
	await _settle()
	_check(reopened.get_instance_id()==original_pause_id and reopened.selected_action()==7
		and reopened.label_visible(7) and not reopened.label_visible(3),
		"完全重开后由同一缓存原面板恢复最后选择，不等鼠标或新方向")
	await _focus_then_leave(reopened,3)
	_axis(JOY_AXIS_RIGHT_Y,.8)
	await _settle()
	_check(reopened.selected_action()==3,"重用面板仍清待派发和连发，不重采样物理轴")
	_axis(JOY_AXIS_RIGHT_Y,.81)
	await _settle()
	_check(reopened.selected_action()==7,"快速重开后确有原始变化才重新移动")
	_axis(JOY_AXIS_RIGHT_Y,0)
	_tap(JOY_BUTTON_B)
	_check(not paused and stack.depth()==0,"复位关闭后返回 Gameplay")

func _wait_for(panel: Control, action: int, deadline: int) -> int:
	while Time.get_ticks_usec()<deadline:
		await process_frame
		if panel.selected_action()==action: return Time.get_ticks_usec()
	return 0

func _run() -> void:
	_unit()
	_unit_stick()
	var fixture:=OS.get_environment("FORMAL_PAUSE_SOURCE")
	if fixture.is_empty() or not FileAccess.file_exists(fixture.path_join("settings-contract.json")):
		print("SKIP 真实 Pause 与 Settings 需要私有源资源；仅验原手柄方向合成合同。")
		_finish(); return
	root.size=Vector2i(960,540)
	_check(change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))==OK,"真实 F5 入口")
	await scene_changed
	await _settle()
	var boot:=current_scene as Boot
	if boot==null or boot.pause_root==null:
		_check(false,"正式原菜单缺失"); _finish(); return
	boot.scene.training_target.ai_controller.stop()
	var stack:=boot.pause_root.stack
	_pad(JOY_BUTTON_DPAD_UP,true) # still held when UI becomes active
	_tap(JOY_BUTTON_START)
	var pause:=stack.top() as Pause
	if pause==null:
		_check(false,"Start 未打开原 Pause"); _finish(); return
	await _settle()
	_check(pause.selected_action()==0,"冷启动没有焦点，不猜默认条目")
	_tap(JOY_BUTTON_A)
	await _settle()
	_check(stack.top()==pause and pause.selected_action()==0,"冷启动南键不发虚构提交")
	await _focus_then_leave(pause,4)
	_check(pause.selected_action()==4,"切图前按住 UP 不重采样")
	_pad(JOY_BUTTON_DPAD_RIGHT,true)
	await _settle()
	_check(pause.selected_action()==1,"改变右键后整合原先按住的 UP，而不是只取新按钮")
	_pad(JOY_BUTTON_DPAD_RIGHT,false); _pad(JOY_BUTTON_DPAD_UP,false)
	await _settle()
	await _focus_then_leave(pause,3)
	_tap(JOY_BUTTON_DPAD_DOWN)
	_pad(JOY_BUTTON_DPAD_DOWN,true,1)
	await _settle()
	_check(pause.selected_action()==3,"同帧按下松回中无位移，别的设备独立")
	_pad(JOY_BUTTON_DPAD_DOWN,true); _pad(JOY_BUTTON_DPAD_UP,true)
	await _settle()
	_check(pause.selected_action()==3,"正反同时按在帧末为零")
	_pad(JOY_BUTTON_DPAD_UP,false)
	await _settle()
	_check(pause.selected_action()==7,"仅撤掉反向，实际焦点走到 Settings")
	_pad(JOY_BUTTON_DPAD_DOWN,false)
	await _settle()

	for south_first: bool in [true,false]:
		await _focus_then_leave(pause,3)
		if south_first: _tap(JOY_BUTTON_A)
		_pad(JOY_BUTTON_DPAD_DOWN,true)
		if not south_first: _tap(JOY_BUTTON_A)
		await _settle()
		var panel:=stack.top() as Settings
		_check(panel!=null and stack.depth()==2,"两种边沿顺序均先 Move 再 Submit，进入真实 Settings")
		_pad(JOY_BUTTON_DPAD_DOWN,false)
		await _settle()
		if panel==null: _finish(); return
		_check(panel.selected_action()==1,"原 Settings 指定 Master 减少为默认焦点")
		_pad(JOY_BUTTON_DPAD_RIGHT,true)
		await _settle()
		_check(panel.selected_action()==2,"D-pad 右键实际水平移动到 Master 增加")
		_pad(JOY_BUTTON_DPAD_RIGHT,false)
		await _settle()
		if south_first:
			var started:=Time.get_ticks_usec()
			_pad(JOY_BUTTON_DPAD_DOWN,true)
			await _settle()
			_check(panel.selected_action()==4,"第一次 Down 立即进入下一设置行")
			var first:=await _wait_for(panel,6,started+1150000)
			_check(first-started>=490000,"原 .5 秒首次连发（用未缩放计时）")
			var second:=await _wait_for(panel,8,Time.get_ticks_usec()+500000)
			_check(second-first>=90000 and second!=0,"后续按原 .1 秒节奏")
			_pad(JOY_BUTTON_DPAD_DOWN,false)
			var stopped:=Time.get_ticks_usec()
			var extra:=await _wait_for(panel,10,stopped+230000)
			_check(extra==0 and panel.selected_action()==8,"回中停止，不再移动")
		_tap(JOY_BUTTON_B)
		_check(stack.top()==pause and pause.selected_action()==7,"独立 Cancel 返回一层并恢复根原记忆焦点")
	_tap(JOY_BUTTON_B)
	_check(not paused and stack.depth()==0,"独立 Cancel 可正常返回 Gameplay")
	await _stick_cases(boot)
	if paused: _finish(); return
	var previous:=boot.get_instance_id()
	_check(change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))==OK,"重新加载真实项目不继承旧场景缓存")
	await scene_changed
	await _settle()
	var next:=current_scene as Boot
	_tap(JOY_BUTTON_START)
	_check(next!=null and next.get_instance_id()!=previous and next.pause_root.stack.top() is Pause
		and next.pause_root.stack.top().selected_action()==0,"新场景的首开仍冷启动、没有猜测焦点")
	_tap(JOY_BUTTON_B)
	_finish()

func _finish() -> void:
	print("%s 原手柄十字键与双摇杆暂停导航：%d/%d（%s）"%[
		"PASS" if failures==0 else "FAIL",checks-failures,checks,DisplayServer.get_name()])
	quit(int(failures!=0))
