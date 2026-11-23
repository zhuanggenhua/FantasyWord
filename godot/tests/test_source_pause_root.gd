extends SceneTree
const Boot := preload("res://gameplay/clickmovetest/source_startup.gd")
const Settings := preload("res://gameplay/clickmovetest/source_settings_view.gd")
const Points := preload("res://game_core/input/mouse_point_actions.gd")
var count := 0
var failures := 0
var actions: Array[int] = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	count+=1
	if not ok:
		failures+=1
		printerr("FAIL ",label)
func key(k: Key, on: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode=k
	event.pressed=on
	root.push_input(event,true)
func settle() -> void:
	await process_frame
	await process_frame

func direction(k: Key) -> void:
	key(k,true)
	await settle()
	key(k,false)
	await settle()

func button(b: MouseButton, on: bool, p: Vector2, device := 0) -> void:
	var event := InputEventMouseButton.new()
	event.device=device
	event.button_index=b
	event.pressed=on
	event.position=p
	root.push_input(event,true)
func move(p: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.device=0
	event.position=p
	event.relative=Vector2.ONE
	root.push_input(event,true)
func finish() -> void:
	print("%s ClickMoveTest source pause root and Settings: %d/%d" % ["PASS" if failures==0 else "FAIL",count-failures,count])
	quit(1 if failures else 0)

func run() -> void:
	if OS.get_environment("FORMAL_PAUSE_SOURCE").is_empty():
		print("SKIP locked private pause source")
		finish()
		return
	root.size=Vector2i(960,540)
	var main: String = ProjectSettings.get_setting("application/run/main_scene")
	check(change_scene_to_file(main)==OK,"start default project path")
	await scene_changed
	await process_frame
	var startup := current_scene as Boot
	check(startup!=null and startup.pause_root!=null,"real source pause mounted in normal F5 launch")
	if startup==null or startup.pause_root==null:
		finish()
		return
	var shell := startup.pause_root
	shell.action_requested.connect(func(a): actions.append(a))
	startup.player.set_accepts_player_input(false)
	key(KEY_ESCAPE,true)
	check(shell.stack.depth()==0 and not paused,"original input owner gate")
	key(KEY_ESCAPE,false)
	startup.player.set_accepts_player_input(true)
	move(Vector2(460,255))
	button(MOUSE_BUTTON_LEFT,true,Vector2(460,255))
	button(MOUSE_BUTTON_LEFT,false,Vector2(460,255))
	var actor = startup.scene.actor
	check(actor.execution.has_move_order(),"real click route before pause")
	key(KEY_ESCAPE,true)
	var panel = shell.stack.top()
	check(panel!=null and paused and Engine.time_scale==0.0 and panel.selected_action()==0
		and actor.execution.has_move_order(),"ESC opens real root without invented selection or dropping route")
	if panel==null:
		finish()
		return
	check(panel.viewport_to_design(Vector2(40,350)).is_equal_approx(Vector2(80,700)),
		"Match Height maps reference geometry")
	key(KEY_S,true); key(KEY_S,false)
	key(KEY_ENTER,true); key(KEY_ENTER,false)
	await settle()
	check(panel.selected_action()==0 and actions.is_empty(),"no default selected control for nav or submit")
	move(Vector2(40,350))
	await process_frame
	await process_frame
	check(startup.point.read_active(Points.Map.UI)==Vector2(40,350) and panel.selected_action()==7,
		"actual root Point hit chooses original Settings")
	button(MOUSE_BUTTON_LEFT,true,Vector2(40,350))
	move(Vector2(200,410))
	button(MOUSE_BUTTON_LEFT,false,Vector2(200,410))
	check(actions.is_empty() and panel.selected_action()==7,"releasing outside clears capture only")
	button(MOUSE_BUTTON_LEFT,true,Vector2(40,350))
	button(MOUSE_BUTTON_LEFT,false,Vector2(40,350))
	if FileAccess.file_exists(OS.get_environment("FORMAL_PAUSE_SOURCE").path_join("settings-contract.json")):
		var settings := shell.stack.top() as Settings
		check(actions==[7] and shell.stack.depth()==2 and settings!=null and paused and not panel.visible,
			"matching release mounts original registered Settings")
		if settings==null:
			finish()
			return
		await check_settings(startup,settings)
		key(KEY_ESCAPE,false)
		key(KEY_ESCAPE,true); key(KEY_ESCAPE,false)
		check(shell.stack.depth()==1 and shell.stack.top()==panel and panel.visible
			and panel.selected_action()==7 and paused,"back returns to same Settings focus without resuming gameplay")
	else:
		check(actions==[7] and shell.stack.depth()==1,"without Settings contract, no fake submenu")
		key(KEY_ENTER,true); key(KEY_F,true); key(KEY_ENTER,false); key(KEY_F,false)
		await settle()
		check(actions==[7,7],"Submit aliases dispatch only once")
	root.size=Vector2i(1200,540)
	await process_frame
	await process_frame
	if root.get_visible_rect().size==Vector2(1200,540):
		check(panel.reference_hit(Vector2(80,700))==7 and panel.reference_footer_blocks(Vector2(932,1000))
			and not panel.reference_footer_blocks(Vector2(692,1000)),
			"wide viewport keeps left anchor and moves footer by half of design-width difference")
	# A fresh right-button edge closes original Pause. The root-only case
	# additionally holds old Gameplay ESC until this transition.
	button(MOUSE_BUTTON_RIGHT,true,Vector2(440,420))
	check(shell.stack.depth()==0 and not paused and Engine.time_scale==1.0,
		"independent right edge closes without reusing original ESC press")
	button(MOUSE_BUTTON_RIGHT,false,Vector2(440,420)); key(KEY_ESCAPE,false)
	button(MOUSE_BUTTON_RIGHT,true,Vector2(440,420))
	check(shell.stack.depth()==1 and paused,"original right mouse binding also opens the root")
	button(MOUSE_BUTTON_RIGHT,false,Vector2(440,420))
	key(KEY_ESCAPE,true); key(KEY_ESCAPE,false)
	check(shell.stack.depth()==0 and not paused and actor.execution.has_move_order()
		and startup.point.read_active(Points.Map.UI)==null,"close restores gameplay route and clears UI Point")
	# 同一 Mouse 设备拥有右键、左键和 Point。其他设备不能触发或释放它。
	var right_pos := Vector2(440,420)
	button(MOUSE_BUTTON_RIGHT,true,right_pos,2)
	check(shell.stack.depth()==0 and not paused,"未配对的鼠标右键不能打开真实暂停")
	button(MOUSE_BUTTON_RIGHT,false,right_pos,2)
	if paused: shell.stack.close_all() # 保持后续断言独立。
	button(MOUSE_BUTTON_RIGHT,true,right_pos)
	check(shell.stack.depth()==1 and paused,"配对右键仍能打开原暂停")
	button(MOUSE_BUTTON_RIGHT,false,right_pos,2)
	button(MOUSE_BUTTON_RIGHT,true,right_pos)
	check(shell.stack.depth()==1 and paused,"未配对的释放不使原按压穿透为返回")
	button(MOUSE_BUTTON_RIGHT,false,right_pos)
	if not paused:
		key(KEY_ESCAPE,true); key(KEY_ESCAPE,false)
	button(MOUSE_BUTTON_RIGHT,true,right_pos,2)
	check(shell.stack.depth()==1 and paused,"未配对的鼠标右键不能返回")
	button(MOUSE_BUTTON_RIGHT,false,right_pos,2)
	if not paused:
		key(KEY_ESCAPE,true); key(KEY_ESCAPE,false)
	button(MOUSE_BUTTON_RIGHT,true,right_pos)
	button(MOUSE_BUTTON_RIGHT,false,right_pos)
	check(shell.stack.depth()==0 and not paused,"真实释放后的配对新右键仍可返回")
	finish()


func check_settings(startup: Boot, settings: Settings) -> void:
	var prefs := startup.audio_preferences
	var master := prefs.volume(-1)
	var channel := prefs.volume(3)
	check(settings.selected_action()==1,"authored default focuses Master decrease")
	check(settings._background.patches(Vector2(1920,1080)).size()==240
		and settings._lines[0]._line.baseline.distance_to(Vector2(788,190))<.001
		and settings._lines[5]._line.baseline.distance_to(Vector2(527,554))<.001,
		"original tiles, Title Top baseline, and terminal-LF label")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var pixels := root.get_texture().get_image()
		check(dark_pixels(pixels,Rect2i(390,50,180,53))>200
			and dark_pixels(pixels,Rect2i(390,135,180,53))<20,"native Settings title is present over the tiled panel")
	var hit := settings.position + Vector2(1020,470)*settings.scale
	var blank := settings.position + Vector2(1170,470)*settings.scale
	button(MOUSE_BUTTON_LEFT,true,hit)
	button(MOUSE_BUTTON_LEFT,false,blank)
	check(is_equal_approx(prefs.volume(-1),master),"outside release changes no gain")
	var adjustment := -1 if master>0.0 else 1
	if adjustment==1: hit=settings.position+Vector2(1350,470)*settings.scale
	button(MOUSE_BUTTON_LEFT,true,hit)
	button(MOUSE_BUTTON_LEFT,false,hit)
	check(is_equal_approx(prefs.volume(-1),master+adjustment*.1)
		and is_equal_approx(AudioServer.get_bus_volume_linear(0),prefs.volume(-1))
		and settings._values[0]._line.text==prefs.display(-1),"real button writes live master and label")
	await direction(KEY_RIGHT if adjustment<0 else KEY_LEFT)
	check(settings.selected_action()==(2 if adjustment<0 else 1),"automatic horizontal neighbor")
	var selected := settings.selected_action()
	key(KEY_ENTER,true); key(KEY_F,true); key(KEY_ENTER,false); key(KEY_F,false)
	await settle()
	check(is_equal_approx(prefs.volume(-1),master),"Submit physical aliases make only one change")
	for i in range(4): await direction(KEY_DOWN)
	check(settings.selected_action()==selected+8,"automatic vertical nearest neighbor")
	await direction(KEY_DOWN)
	check(settings.selected_action()==selected+8,"no focus wrap at final row")
	if selected==1: await direction(KEY_RIGHT)
	key(KEY_ENTER,true); key(KEY_ENTER,false)
	await settle()
	var next := minf(channel+.1,1.0)
	check(is_equal_approx(prefs.volume(3),next) and is_equal_approx(prefs.volume(-1),master)
		and settings._values[4]._line.text==prefs.display(3),"last row changes only source GameplaySoundFX")
	# 原设置按钮再次从同一个 AudioSystem 读取五行，不把其余标签当真相。
	for id in range(4):
		check(prefs.adjust(id,-1),"正式共享音量状态可独立修改通道 %d"%id)
	var expected_focus := settings.reference_hit(settings.viewport_to_design(hit))
	button(MOUSE_BUTTON_LEFT,true,hit)
	button(MOUSE_BUTTON_LEFT,false,hit)
	for id in range(-1,4):
		check(settings._values[id+1]._line.text==prefs.display(id),
			"主音量回调刷新实际共享音量行 %d"%id)
	check(settings.selected_action()==expected_focus
		and is_equal_approx(AudioServer.get_bus_volume_linear(0),prefs.volume(-1)),
		"重新取值不替换已选中的原按钮，也不改监听器音量映射")
	var channel_hit := settings.position+Vector2(1350,726)*settings.scale
	check(prefs.adjust(-1,1),"正式共享音量状态可独立修改主音量")
	button(MOUSE_BUTTON_LEFT,true,channel_hit)
	button(MOUSE_BUTTON_LEFT,false,channel_hit)
	check(settings._values[0]._line.text==prefs.display(-1)
		and settings._values[4]._line.text==prefs.display(3),
		"通道按钮也重读主音量及目标通道")

func dark_pixels(pixels: Image, region: Rect2i) -> int:
	var n := 0
	for y in range(region.position.y,region.end.y):
		for x in range(region.position.x,region.end.x):
			var color := pixels.get_pixel(x,y)
			if color.r<.37 and color.g<.28 and color.b<.32: n+=1
	return n
