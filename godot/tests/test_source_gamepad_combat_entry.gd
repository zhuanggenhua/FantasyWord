extends SceneTree
const Boot := preload("res://gameplay/clickmovetest/source_startup.gd")
const Router := preload("res://game_core/combat/ability_slot_keyboard_input.gd")
const Pause := preload("res://gameplay/clickmovetest/source_pause_focus_view.gd")
const Inventory := preload("res://gameplay/clickmovetest/source_inventory_view.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL ",label)

func _button(index: JoyButton,down: bool,device := 0) -> InputEventJoypadButton:
	var event:=InputEventJoypadButton.new()
	event.button_index=index; event.pressed=down; event.device=device
	return event

func _pad(index: JoyButton,down: bool,device := 0) -> void:
	root.push_input(_button(index,down,device),true)

func _key(code: Key,down: bool) -> void:
	var e:=InputEventKey.new()
	e.keycode=code; e.physical_keycode=code; e.pressed=down
	root.push_input(e,true)

func _run() -> void:
	var r:=Router.new()
	var edges: Array=[]
	var record:=func(slot: int,down: bool): edges.append([slot,down])
	var buttons: Array[JoyButton]=[JOY_BUTTON_X,JOY_BUTTON_Y,JOY_BUTTON_B,JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER]
	for i in buttons.size():
		r.observe(_button(buttons[i],true),true,record)
		r.observe(_button(buttons[i],false),true,record)
	_check(edges==[[0,true],[0,false],[1,true],[1,false],[2,true],[2,false],[3,true],[3,false],[4,true],[4,false]],
		"锁定的原手柄五键")
	edges.clear()
	r.observe(_button(JOY_BUTTON_Y,true),true,record)
	r.deactivate(record)
	r.observe(_button(JOY_BUTTON_Y,true),false)
	r.observe(_button(JOY_BUTTON_Y,true),true,record)
	r.observe(_button(JOY_BUTTON_Y,false),true,record)
	r.observe(_button(JOY_BUTTON_Y,true,1),true,record)
	_check(edges==[[1,true],[1,false]],"禁用只取消一次，按住跨动作图、释放以及非本地设备不再激活")
	var fixture:=OS.get_environment("FORMAL_PAUSE_SOURCE")
	if fixture.is_empty() or not FileAccess.file_exists(fixture.path_join("abilities-layout.json")):
		print("SKIP 原窗口与原技能、HUD 需要私有素材；仅运行边沿合同。")
		_finish()
		return
	root.size=Vector2i(960,540)
	_check(change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))==OK,"正式项目入口")
	await scene_changed
	await process_frame
	var s:=current_scene as Boot
	if s==null or s.pause_root==null or s.ability_hud==null:
		_check(false,"原 HUD 与暂停未绑定"); _finish(); return
	var scene:=s.scene
	var menu:=s.pause_root
	var message:=s.ability_hud.message
	scene.training_target.ai_controller.stop()
	var baseline: Image=null
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		baseline=root.get_texture().get_image()
	var count: int=scene.command_count
	_pad(JOY_BUTTON_X,true,1)
	_pad(JOY_BUTTON_START,true,1)
	_check(scene.command_count==count and not paused,"非本地设备不能施放或唤起菜单")
	_pad(JOY_BUTTON_B,true)
	_check(not paused and scene.command_count==count+1 and message.value=="这个槽位没有装备技能。","Gameplay East 只发真实第三槽")
	if baseline!=null:
		await process_frame
		await RenderingServer.frame_post_draw
		var frame:=root.get_texture().get_image()
		var ink:=0
		for y in range(448,468):
			for x in range(420,540):
				if frame.get_pixel(x,y)!=baseline.get_pixel(x,y) and frame.get_pixel(x,y).r>.7:
					ink+=1
		_check(ink>30,"手柄实际失败在原生窗口绘出槽位提示")
	_pad(JOY_BUTTON_START,true)
	_check(paused and menu.stack.top() is Pause and scene.command_count==count+2,"Start 打开原暂停，取消已有技能只一次")
	_pad(JOY_BUTTON_B,true)
	_pad(JOY_BUTTON_START,true)
	_pad(JOY_BUTTON_START,false)
	_check(paused and menu.stack.depth()==1,"跨动作图的 East 与已按过 Start 不弹出 Pause")
	_pad(JOY_BUTTON_B,false)
	_pad(JOY_BUTTON_START,true); _pad(JOY_BUTTON_START,false)
	_check(paused,"新按 Start 在 UI 也不是 Cancel")
	var pause:=menu.stack.top() as Pause
	for row: Dictionary in pause._entries:
		if row.action==1:
			var e:=InputEventMouseMotion.new()
			e.device=0; e.position=row.icon.get_center()*.5; e.relative=Vector2.ONE
			root.push_input(e,true)
	await process_frame
	await process_frame
	_pad(JOY_BUTTON_A,true); _pad(JOY_BUTTON_A,false)
	_check(menu.stack.depth()==2 and menu.stack.top() is Inventory,"打开真实背包作为二级菜单")
	_pad(JOY_BUTTON_B,true); _pad(JOY_BUTTON_B,true)
	_check(paused and menu.stack.top()==pause,"一次 East 只关一层")
	_pad(JOY_BUTTON_B,false)
	_pad(JOY_BUTTON_B,true); _pad(JOY_BUTTON_B,true)
	_check(not paused and scene.command_count==count+2,"East 从 UI 返回时不误发第三槽")
	_pad(JOY_BUTTON_B,false)
	_check(scene.command_count==count+2,"UI 开始的 East 释放不误发取消")
	_pad(JOY_BUTTON_B,true); _pad(JOY_BUTTON_B,false)
	_pad(JOY_BUTTON_LEFT_SHOULDER,true); _pad(JOY_BUTTON_LEFT_SHOULDER,false)
	_pad(JOY_BUTTON_RIGHT_SHOULDER,true); _pad(JOY_BUTTON_RIGHT_SHOULDER,false)
	_check(scene.command_count==count+8 and message.value=="这个槽位没有装备技能。","返回后 East、双肩发原空槽命令")
	_pad(JOY_BUTTON_X,true)
	for i in range(35):
		await physics_frame
		if scene.human_presentation.driver.current_animation_key=="Attack": break
	_check(scene.human_presentation.driver.current_animation_key=="Attack","West 启动真实原版普攻动画")
	_pad(JOY_BUTTON_X,false)
	for i in range(80):
		await physics_frame
		if scene.human_presentation.driver.current_animation_key!="Attack": break
	var before: int=scene.command_count
	_pad(JOY_BUTTON_Y,true)
	_key(KEY_Q,true)
	_pad(JOY_BUTTON_Y,false)
	_check(scene.command_count==before+1,"North 与 Q 同槽同一次 performed，前一个松手不取消")
	for i in range(70):
		await physics_frame
		if is_instance_valid(scene.flamethrower_visual) and scene.flamethrower_visual.visible: break
	_check(is_instance_valid(scene.flamethrower_visual) and scene.flamethrower_visual.visible,"North 实际触发原喷火，而不仅是命令数")
	_key(KEY_Q,false)
	_check(scene.command_count==before+2,"同槽最后一个按键释放才取消")
	# The original cue intentionally outlives the cast. Let the native audio
	# mixer drain its stopped playback before tearing down this test scene.
	scene.flamethrower_audio.stop_channel()
	await create_timer(.2).timeout
	_finish()

func _finish() -> void:
	print("%s 原手柄战斗/菜单：%d/%d（%s）"%[
		"PASS" if failures==0 else "FAIL",checks-failures,checks,DisplayServer.get_name()])
	quit(int(failures!=0))
