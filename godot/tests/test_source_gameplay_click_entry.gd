extends SceneTree
## 真实项目入口的 Gameplay/Click：不用替代角色、测试命令执行器或合成关卡。
const Point := preload("res://game_core/input/mouse_point_actions.gd")
const SourceProjection := preload("res://game_core/presentation/orthographic_screen_projection.gd")
const Command := preload("res://game_core/interaction/character_command_executor.gd")
const SharedClick := preload("res://game_core/input/source_shared_mouse_click.gd")
const Settings := preload("res://gameplay/clickmovetest/source_settings_view.gd")
var _checks := 0
var _failures := 0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	_verify_edges()
	if OS.get_environment("FORMAL_PAUSE_SOURCE").is_empty():
		_check(ProjectSettings.get_setting("application/run/main_scene")=="res://gameplay/clickmovetest/source_startup.tscn",
			"仅在私有原图资源就绪时运行正式入口")
		print("SKIP 正式 F5 点击：需要锁定素材与原暂停合同")
		_finish()
		return
	root.size=Vector2i(800,600)
	_check(change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))==OK,"正式 F5 加载")
	await scene_changed
	await process_frame
	var boot := current_scene
	var screen := Vector2(430,245)
	var other := Vector2(150,340)
	var scene: Variant=boot.scene
	var actor: Variant=scene.actor
	_check(is_instance_valid(boot.pause_root) and scene.command_count==0 and scene._normalized_click_bound
		and boot.point.read_active(Point.Map.GAMEPLAY)==null,"正式启动已装配命令且 Point 未激活")
	# 按钮坐标不是 Point；没有鼠标移动时原 ReadValue 返回屏幕左下角。
	_button(screen,true)
	_button(screen,false)
	var default_world: Vector2=SourceProjection.project(scene.camera,Vector2(0,600))
	_check(scene.command_count==1 and scene.click_observation.latest.world_position.is_equal_approx(default_world)
		and boot.point.read_active(Point.Map.GAMEPLAY)==null,
		"初次静止点击使用原左下默认投影，且不激活瞄准 Point")
	await process_frame
	_motion(screen)
	var before: int=scene.command_count
	_button(other,true,2)
	_button(other,false,2)
	_check(scene.command_count==before,"未配对鼠标不会提交命令")
	# 暂时让实际角色命令执行者不可用，以区分原链与旧直接移动执行。
	scene.human_commands.enabled=false
	_button(other,true)
	_check(scene.command_count==before+1 and scene.last_result==Command.Failure.NOT_RUNNING
		and scene.click_observation.latest.screen_position==screen,
		"已激活时使用独立 Point 并执行真实角色命令门禁")
	_button(other,true)
	_check(scene.command_count==before+1,"同一按压不重复提交")
	_button(other,false)
	scene.human_commands.enabled=true
	_button(other,true)
	var projected: Vector2=SourceProjection.project(scene.camera,screen)
	_check(scene.command_count==before+2 and scene.last_result==Command.Failure.NONE
		and actor.execution.has_move_order() and scene.click_observation.latest.world_position.is_equal_approx(projected),
		"同一入口的真实角色命令一次接受并生成原导航路线")
	_key(KEY_ESCAPE)
	_check(paused and boot.point.read_active(Point.Map.GAMEPLAY)==null,"按住鼠标打开真实暂停时清除 Gameplay Point")
	var current: Variant=boot.pause_root.stack.top()
	var panel_point:=Vector2(40,350)*(600.0/540.0)
	_check(current.reference_hit(current.viewport_to_design(panel_point))==7,"真实设置按钮命中")
	_check(current.choose(7),"为正式面板设置独立的已知焦点")
	_key_edge(KEY_UP,true)
	await process_frame
	await process_frame
	_check(current.selected_action()==3,"进入 UI 前的左键不禁止同图新的方向输入；未挂载的 Abilities 跳过")
	_key_edge(KEY_UP,false)
	current.choose(7)
	_key(KEY_F)
	await process_frame
	await process_frame
	_check(boot.pause_root.stack.depth()==2 and boot.pause_root.stack.top() is Settings,
		"进入 UI 前的左键不禁止同图新的确认输入")
	if boot.pause_root.stack.depth()==2: _key(KEY_ESCAPE)
	_motion(panel_point)
	_button(panel_point,true)
	_check(not boot.pause_root._left_down and boot.pause_root.stack.top()==current,
		"旧 Gameplay 按压不穿入已打开的原暂停层")
	_key(KEY_ESCAPE)
	_check(not paused and boot.point.read_active(Point.Map.GAMEPLAY)==null,
		"按住鼠标退出暂停时不继承 UI Point")
	_motion(screen)
	before=scene.command_count
	_button(other,true)
	_button(other,false)
	_check(scene.command_count==before,"恢复后的旧按压和松开均不提交")
	_button(other,true)
	_button(other,false)
	_check(scene.command_count==before+1 and scene.last_result==Command.Failure.NONE,
		"共享按键释放后下一次实际按压恢复同一正式命令")
	_button(other,true)
	_key(KEY_ESCAPE)
	_motion(panel_point)
	before=scene.command_count
	_button(panel_point,false)
	await process_frame
	await process_frame
	_check(boot.pause_root.stack.depth()==1 and boot.pause_root.stack.top()==current,
		"在 UI 内释放旧 Gameplay Click 不触发或排队打开设置")
	_button(panel_point,true)
	_button(panel_point,false)
	_check(boot.pause_root.stack.depth()==2 and boot.pause_root.stack.top() is Settings and scene.command_count==before,
		"释放后新点击真正打开原设置，不触发 Gameplay")
	_key(KEY_ESCAPE)
	_key(KEY_ESCAPE)
	_key(KEY_ESCAPE)
	_motion(panel_point)
	_button(panel_point,true)
	_check(paused and boot.pause_root._left_down,"新的真实 UI 按压进入设置按钮捕获")
	_key(KEY_ESCAPE)
	_motion(screen)
	before=scene.command_count
	_button(other,true)
	_button(other,false)
	_check(not paused and scene.command_count==before,"原 UI 按压也不穿入已恢复的 Gameplay")
	_finish()

func _verify_edges() -> void:
	var shared:=SharedClick.new(0)
	var down:=InputEventMouseButton.new()
	down.device=2
	down.button_index=MOUSE_BUTTON_LEFT
	down.pressed=true
	_check(shared.observe(down)==SharedClick.Edge.OTHER,"无私有资源也可核实未配对设备")
	down.device=0
	_check(shared.observe(down)==SharedClick.Edge.PRESS and not shared.is_blocked(),"无需初始化采样即可识别首个真实按压")
	shared.arm_action_map()
	_check(shared.is_blocked() and shared.observe(down)==SharedClick.Edge.HELD,"跨图不产生新动作")
	var release: InputEventMouseButton=down.duplicate()
	release.pressed=false
	release.device=2
	_check(shared.observe(release)==SharedClick.Edge.OTHER and shared.is_blocked(),"其他设备的释放不解除门禁")
	release.device=0
	_check(shared.observe(release)==SharedClick.Edge.RELEASE and not shared.is_blocked() and shared.observe(down)==SharedClick.Edge.PRESS,
		"同一配对设备释放才允许下一按压")
	shared.arm_action_map()
	shared.reset_device_state()
	_check(not shared.is_blocked() and shared.observe(release)==SharedClick.Edge.HELD,
		"焦点丢失重置而未匹配的释放不补发点击")

func _motion(point: Vector2) -> void:
	var event:=InputEventMouseMotion.new()
	event.device=0
	event.position=point
	event.relative=Vector2(1,1)
	root.push_input(event,true)

func _button(point: Vector2,down: bool,device:=0) -> void:
	var event:=InputEventMouseButton.new()
	event.device=device
	event.position=point
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=down
	root.push_input(event,true)

func _key(code: Key) -> void:
	for down in [true,false]: _key_edge(code,down)

func _key_edge(code: Key,down: bool) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=code
	event.pressed=down
	root.push_input(event,true)

func _check(ok: bool,label: String) -> void:
	_checks+=1
	if not ok:
		_failures+=1
		printerr("FAIL ",label)

func _finish() -> void:
	print("%s 正式 Gameplay Click：%d/%d"%["PASS" if _failures==0 else "FAIL",_checks-_failures,_checks])
	quit(int(_failures!=0))
