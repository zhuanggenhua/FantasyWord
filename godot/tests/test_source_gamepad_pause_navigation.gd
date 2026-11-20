extends SceneTree
const Boot := preload("res://gameplay/clickmovetest/source_startup.gd")
const Pause := preload("res://gameplay/clickmovetest/source_pause_focus_view.gd")
const Settings := preload("res://gameplay/clickmovetest/source_settings_view.gd")
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

func _wait_for(panel: Control, action: int, deadline: int) -> int:
	while Time.get_ticks_usec()<deadline:
		await process_frame
		if panel.selected_action()==action: return Time.get_ticks_usec()
	return 0

func _run() -> void:
	_unit()
	var fixture:=OS.get_environment("FORMAL_PAUSE_SOURCE")
	if fixture.is_empty() or not FileAccess.file_exists(fixture.path_join("settings-contract.json")):
		print("SKIP 真实 Pause 与 Settings 需要私有源资源；仅验原 D-pad 合成合同。")
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
	_finish()

func _finish() -> void:
	print("%s 原手柄 D-pad 暂停导航：%d/%d（%s）"%[
		"PASS" if failures==0 else "FAIL",checks-failures,checks,DisplayServer.get_name()])
	quit(int(failures!=0))
