extends SceneTree
## 实际 ClickMoveTest（原场景没有 Interaction 层目标），经过原输入、同一角色和 HUD。
const Bootstrap := preload("res://gameplay/clickmovetest/source_startup.gd")
const Commands := preload("res://game_core/interaction/character_command_executor.gd")
const PauseView := preload("res://gameplay/clickmovetest/source_pause_focus_view.gd")
const Inventory := preload("res://gameplay/clickmovetest/source_inventory_view.gd")
const Letters := preload("res://game_core/input/source_shared_interact_submit.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("_run")

func _key(code: Key, down: bool, echo := false) -> void:
	var e:=InputEventKey.new()
	e.keycode=code; e.physical_keycode=code; e.pressed=down; e.echo=echo
	root.push_input(e,true)

func _tap(code: Key) -> void:
	_key(code,true); _key(code,false)

func _move(p: Vector2) -> void:
	var e:=InputEventMouseMotion.new()
	e.device=0; e.position=p; e.relative=Vector2.ONE
	root.push_input(e,true)

func _pad(down: bool, index := JOY_BUTTON_A, device := 0) -> void:
	var e:=InputEventJoypadButton.new()
	e.button_index=index; e.pressed=down; e.device=device
	root.push_input(e,true)

func _run() -> void:
	var unit:=Letters.new()
	var test_event:=InputEventKey.new()
	test_event.physical_keycode=KEY_F; test_event.pressed=true
	_check(unit.observe(test_event)==Letters.Edge.FIRST_PRESS and unit.observe(test_event)==Letters.Edge.HELD_OR_RELEASE,
		"共用动作按下只产生一个 performed")
	unit.reset_device_state()
	_check(unit.observe(test_event)==Letters.Edge.FIRST_PRESS,"设备失焦清理不会遗留压键")
	var fixture:=OS.get_environment("FORMAL_PAUSE_SOURCE")
	if fixture.is_empty() or not FileAccess.file_exists(fixture.path_join("abilities-layout.json")):
		print("SKIP：实际交互与 HUD 需要私有原场景和字体；已检查独立动作边沿。")
		_exit()
		return
	root.size=Vector2i(960,540)
	if change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))!=OK:
		quit(1)
		return
	await scene_changed
	await process_frame
	var startup:=current_scene as Bootstrap
	var scene:=startup.scene
	var player:=startup.player
	var menu:=startup.pause_root
	var message:=startup.ability_hud.message
	scene.training_target.ai_controller.stop()
	_check(scene.human_commands.character==player and scene.human_interaction.character==player
		and scene.human_interaction.pivot==scene.aim_pivot and scene.uses_source_interact_submit(),
		"实际 F5 安装同一原主角与 Static Pivot")
	var baseline: Image=null
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		baseline=root.get_texture().get_image()
	var count: int=scene.command_count
	_key(KEY_F,true)
	_check(scene.command_count==count+1 and scene.last_result==Commands.Failure.BLOCKED_BY_STATE
		and scene.human_interaction.current_target==null and not scene.human_interaction.interacted_this_frame
		and message.value=="没有可交互对象。","真实 F 走原未命中失败，不假造接收者或成功")
	if baseline!=null:
		await process_frame
		await RenderingServer.frame_post_draw
		var rendered:=root.get_texture().get_image()
		var lit:=0
		for y in range(448,468):
			for x in range(420,540):
				if rendered.get_pixel(x,y)!=baseline.get_pixel(x,y) and rendered.get_pixel(x,y).r>.7:
					lit+=1
		_check(lit>30,"真实命令失败在原生窗口绘制原字")
	_key(KEY_F,true,true); _key(KEY_ENTER,true); _key(KEY_F,false)
	_key(KEY_SPACE,true); _key(KEY_ENTER,false); _key(KEY_SPACE,false)
	_check(scene.command_count==count+1,"键盘别名重叠、回声和释放不重复")
	_tap(KEY_ENTER); _tap(KEY_SPACE)
	_pad(true); _pad(false)
	_check(scene.command_count==count+4 and message.visible,"Enter、Space、手柄南键走同一原命令")
	_pad(true,JOY_BUTTON_BACK); _pad(false,JOY_BUTTON_BACK)
	_pad(true,JOY_BUTTON_A,1); _pad(false,JOY_BUTTON_A,1)
	_check(scene.command_count==count+4,"其他方向和未绑定手柄不抢该设备的交互")
	_key(KEY_F,true)
	_tap(KEY_ESCAPE)
	_check(paused and menu.stack.top() is PauseView and menu.stack.depth()==1,"按住交互时实际切到暂停菜单")
	_move(Vector2(40,190))
	await process_frame
	await process_frame
	_check(menu.stack.top().selected_action()==1,"Point 真正选中原 Inventory 入口")
	_key(KEY_ENTER,true); _key(KEY_F,false)
	_check(menu.stack.depth()==1 and scene.command_count==count+5,"保持一项物理控制时不会穿入 UI Submit")
	_key(KEY_ENTER,false)
	_pad(true)
	await process_frame
	await process_frame
	_check(menu.stack.top() is Inventory and scene.command_count==count+5,
		"全松后新按的共用南键在 UI 只提交选中的 Inventory")
	_tap(KEY_ESCAPE)
	_check(paused and menu.stack.top() is PauseView and menu.stack.depth()==1,"实际返回暂停根")
	_tap(KEY_ESCAPE)
	_check(not paused and menu.stack.top()==null and scene.command_count==count+5,"按着原确认键恢复时不误交互")
	_key(KEY_SPACE,true)
	_pad(false)
	_key(KEY_SPACE,false)
	_check(scene.command_count==count+5,"从 UI 返回后直至所有共享控制松开才会再按")
	_tap(KEY_F)
	_check(scene.command_count==count+6 and message.value=="没有可交互对象。","恢复后真实新按重新解析正式目标")
	_check(player.set_current_controlled(false),"实际解除原控制角色")
	_tap(KEY_F)
	_check(scene.command_count==count+6 and message.value=="当前没有可控制角色。","无当前目标由实际 InputSystem 路径报告，不用上次角色")
	_check(player.set_current_controlled(true),"实际重新选择主角")
	_tap(KEY_3)
	_check(scene.command_count==count+8 and message.value=="这个槽位没有装备技能。","同一角色原技能按下和松手仍独立，不被交互失败标为本帧成功")
	_exit()

func _check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL ",label)

func _exit() -> void:
	print("%s 原场景交互与共用确认：%d/%d（%s）"%[
		"PASS" if failures==0 else "FAIL",checks-failures,checks,DisplayServer.get_name()])
	quit(int(failures!=0))
