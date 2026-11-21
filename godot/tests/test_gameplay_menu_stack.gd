extends SceneTree
const Startup := preload("res://gameplay/clickmovetest/source_startup.gd")
const Point := preload("res://game_core/input/mouse_point_actions.gd")
const MenuStack = preload("res://game_core/ui/gameplay_menu_stack.gd")
class MenuPointer extends Node:
	var entry: Node
	func _init(scene: Node) -> void:
		entry = scene
		process_mode = Node.PROCESS_MODE_ALWAYS
	func _input(event: InputEvent) -> void:
		entry.observe_source_ui_pointer(event)

class Probe extends Node:
	var fixed_steps := 0
	func _physics_process(_delta: float) -> void: fixed_steps += 1

class TestPanel extends Control:
	var button := Button.new()
	var can_close := true
	var consume_back := false
	var back_count := 0
	func _ready() -> void: add_child(button)
	func apply_stack_interactions(enabled: bool) -> void: button.disabled = not enabled
	func try_focus_default_target() -> void: button.grab_focus()
	func try_handle_back_request() -> bool:
		back_count += 1
		return consume_back
	func allows_stack_close() -> bool: return can_close

var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",label)

func escape(pressed: bool, echo := false) -> void:
	key_edge(KEY_ESCAPE,pressed,echo)

func key_edge(code: Key, pressed: bool, echo := false) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = pressed
	key.echo = echo
	root.push_input(key)

func run() -> void:
	var menu := MenuStack.new()
	var probe := Probe.new()
	root.add_child(probe)
	root.add_child(menu)
	var state := {"may_open":false,"mount":false,"requests":0,"dialogue":false}
	var maps: Array[int] = []
	check(menu.configure(func():
		if not state.may_open: return
		state.requests += 1
		if state.mount: menu.push_panel(TestPanel.new()),
		func(map):maps.append(map),
		func():return state.dialogue),"注册明确的宿主与命令门禁")
	escape(true)
	check(state.requests==0 and menu.depth()==0 and not paused,"不可交互不发请求")
	state.may_open = true
	escape(true)
	escape(true,true)
	check(state.requests==0,"拒绝的同次按压也不补发")
	escape(false)
	escape(true)
	check(state.requests==1 and menu.depth()==0 and maps.is_empty() and not paused,"面板未挂载不切输入图")
	escape(false)
	var invalid := Control.new()
	check(not menu.push_panel(invalid) and invalid.get_parent()==null,"非正式面板不进入栈")
	invalid.free()
	state.mount = true
	escape(true)
	var first := menu.top() as TestPanel
	check(menu.depth()==1 and maps==[MenuStack.ActionLayer.UI] and paused and Engine.time_scale==0.0,"首个面板挂载后切 UI 和暂停")
	check(first != null and root.gui_get_focus_owner()==first.button,"首层获得默认按钮焦点")
	escape(true)
	escape(true,true)
	check(menu.depth()==1 and first.back_count==0,"同一 Esc 不关闭自己打开的面板")
	var frozen := probe.fixed_steps
	await create_timer(0.08,true,false,true).timeout
	check(probe.fixed_steps==frozen,"真实 Godot 暂停阻断常量固定步推进")
	var next := TestPanel.new()
	check(menu.push_panel(next) and first.button.disabled and not next.button.disabled,"成功压入子菜单才禁用上一层")
	check(maps.size()==1 and root.gui_get_focus_owner()==next.button,"子菜单沿用 UI 动作图并取得焦点")
	escape(false)
	state.dialogue = true
	escape(true)
	check(menu.top()==next and next.back_count==0,"对话阻止返回")
	escape(false)
	state.dialogue = false
	next.consume_back = true
	escape(true)
	check(menu.top()==next and next.back_count==1,"面板先消化返回")
	escape(false)
	next.consume_back = false
	next.can_close = false
	escape(true)
	check(menu.top()==next and next.back_count==2,"面板可以拒绝被栈关闭")
	escape(false)
	next.can_close = true
	escape(true)
	check(menu.top()==first and paused and maps.size()==1 and root.gui_get_focus_owner()==first.button,"弹出子层恢复原焦点但继续暂停")
	escape(true)
	check(menu.top()==first,"子层关闭的同次按压不穿透")
	escape(false)
	escape(true)
	check(not paused and Engine.time_scale==1.0 and menu.depth()==0 and maps==[MenuStack.ActionLayer.UI,MenuStack.ActionLayer.GAMEPLAY],"最后一层才回 Gameplay 和正常时间")
	escape(true,true)
	check(state.requests==2,"关闭动作不立即重开")
	await create_timer(0.08,true,false,true).timeout
	check(probe.fixed_steps>frozen,"真实固定步恢复")
	escape(false)
	escape(true)
	check(menu.depth()==1,"释放再按可重复打开")
	var forced := TestPanel.new()
	forced.can_close=false
	forced.consume_back=true
	state.dialogue=true
	check(menu.push_panel(forced),"准备拒绝手动返回的子菜单")
	menu.close_all()
	check(menu.depth()==0 and not paused and Engine.time_scale==1.0 and forced.back_count==0
		and maps.slice(-2)==[MenuStack.ActionLayer.UI,MenuStack.ActionLayer.GAMEPLAY],
		"程序请求逐层关闭，不走手动返回门禁，最后一层只恢复一次")
	var map_count := maps.size()
	menu.close_all()
	check(map_count==maps.size(),"空栈重复关闭不重复切换动作图")
	menu.free()
	check(not paused and Engine.time_scale==1.0,"退出场景不会遗留暂停时钟")
	if not failures and not OS.get_environment("FORMAL_SURFACE_RULES").is_empty():
		await _check_source_entry()
	if not failures: print("PASS ",checks," 项原源码菜单栈切片")
	else: printerr("原源码菜单栈切片失败 ",failures," / ",checks)
	quit(1 if failures else 0)

## 使用真实 ClickMoveTest 入口和同图角色，替身面板只验证生命周期，不作为原 UI 取证。
func _check_source_entry() -> void:
	root.size = Vector2i(800,600)
	var path: String = ProjectSettings.get_setting("application/run/main_scene")
	check(change_scene_to_file(path)==OK,"打开正式原场景")
	await scene_changed
	await process_frame
	var startup := current_scene as Startup
	if not is_instance_valid(startup) or not is_instance_valid(startup.scene):
		check(false,"正式原场景成功装配")
		return
	var scene := startup.scene
	var actor: Node2D = scene.actor
	var trainer: Node2D = scene.training_target
	var pointer := startup.point
	startup.add_child(MenuPointer.new(scene))
	var menu := MenuStack.new()
	startup.add_child(menu)
	check(menu.configure(func():
		if startup.player.is_current_controlled(actor) and startup.player.can_interact(): menu.push_panel(TestPanel.new()),
		func(layer): scene.set_source_ui_action_layer(layer==MenuStack.ActionLayer.UI),
		func():return false),"真实启动宿主注入控制角色门禁及两套 Point")
	var motion := InputEventMouseMotion.new()
	motion.device = 0
	motion.position = Vector2(460,255)
	motion.relative = Vector2.ONE
	root.push_input(motion,true)
	var click := InputEventMouseButton.new()
	click.position = motion.position
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click,true)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click,true)
	check(actor.execution.has_move_order(),"正常角色在暂停前已收到路径")
	var audio: Node = scene.flamethrower_audio
	check(is_instance_valid(audio) and audio.activate(),"正式火焰音轨已开始播放")
	var voice := audio.get_child(0) as AudioStreamPlayer
	await create_timer(0.07,true,false,true).timeout
	var playback_before := voice.get_playback_position()
	check(voice.playing and playback_before>0.0,"进入菜单前音轨正在前进")
	escape(false)
	escape(true)
	var before: Vector2 = actor.get_movement_position()
	var trainer_before: Vector2 = trainer.get_movement_position()
	var commands: int = scene.command_count
	check(paused and menu.depth()==1 and pointer.read_active(Point.Map.GAMEPLAY)==null,"实际角色可打开，旧 Gameplay Point 清空")
	await process_frame
	await process_frame
	var flash := startup.damage_screen_flash
	# 初次 yield 之前已消耗本帧；慢速软件渲染的一帧可能超过完整时长。
	var initial_alpha := flash.NORMAL.a * clampf(1.0 - flash._frame_delta / flash.DURATION,0.0,1.0)
	check(flash.present(actor,actor,{"flags":0,"silent":false})
		and is_equal_approx(flash.color.a,initial_alpha),"同一真实闪屏按当帧非缩放步长开始淡出")
	var ui_motion := InputEventMouseMotion.new()
	ui_motion.device = 0
	ui_motion.position = Vector2(540,330)
	ui_motion.relative = Vector2.ONE
	root.push_input(ui_motion,true)
	check(pointer.read_active(Point.Map.UI)==ui_motion.position
		and pointer.read_active(Point.Map.GAMEPLAY)==null,"暂停期间仅 UI Point 观察配对鼠标")
	var ui_click := InputEventMouseButton.new()
	ui_click.position = ui_motion.position
	ui_click.button_index = MOUSE_BUTTON_LEFT
	ui_click.pressed = true
	root.push_input(ui_click,true)
	ui_click = ui_click.duplicate()
	ui_click.pressed = false
	root.push_input(ui_click,true)
	await create_timer(0.22,true,false,true).timeout
	check(actor.execution.has_move_order() and actor.get_movement_position()==before
		and trainer.get_movement_position()==trainer_before and scene.command_count==commands,
		"场景实际玩家、假人及 Gameplay 点击在暂停中未继续")
	check(startup.damage_screen_flash.color.a==0.0,"实际原闪屏在玩法冻结时完整淡出")
	check(voice.playing and not voice.stream_paused and voice.get_playback_position()>playback_before+.08,
		"菜单只冻结玩法，不冻结已开始的原音轨")
	escape(false)
	escape(true)
	for i in range(8): await physics_frame
	check(not paused and Engine.time_scale==1.0 and actor.get_movement_position().distance_to(before)>.05
		and scene.command_count==commands,"释放后返回，存量点击路线续跑且没有补发命令")
	escape(false)
	check(pointer.read_active(Point.Map.UI)==null and pointer.read_active(Point.Map.GAMEPLAY)==null,
		"返回不把最后的 UI Point 当成新的 Gameplay Point")
	key_edge(KEY_TAB,true)
	key_edge(KEY_TAB,false)
	key_edge(KEY_D,true)
	key_edge(KEY_Q,true)
	key_edge(KEY_2,true)
	var active_count: int = scene.command_count
	check(scene.keyboard.get_direction()==Vector2.RIGHT,"第二次暂停前持续按住真实 Move")
	escape(true)
	check(paused and scene.command_count==active_count+2 and scene.keyboard.get_direction()==Vector2.ZERO,
		"动作图退出只发一次 StopMove、一次别名共享槽 StopFireAbility")
	check(startup.player.is_current_controlled(actor) and startup.player.accepts_player_input(actor),
		"切动作图没有撤销原角色所有权或输入资格")
	scene.set_source_ui_action_layer(true)
	scene.receive_human_gameplay_action("Gameplay","FireAbility2","performed")
	scene.receive_human_gameplay_action("Gameplay","FireAbility2","canceled")
	key_edge(KEY_D,false); key_edge(KEY_Q,false); key_edge(KEY_2,false)
	check(scene.command_count==active_count+2,"UI 期间不重复取消也不接收玩法边沿")
	escape(false)
	escape(true)
	escape(false)
	key_edge(KEY_D,true)
	check(not paused and scene.keyboard.get_direction()==Vector2.RIGHT
		and scene.command_count==active_count+3,"返回后新的物理按下正常发出 Move")
	key_edge(KEY_D,false)
	await create_timer(2.2,true,false,true).timeout
	check(audio.active_voice_count()==0,"已开始的原音轨自然回收")
