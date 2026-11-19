extends SceneTree
## 普通项目入口、原按键、原世界 Fire 轨与实际玩家接触受击。
const Startup := preload("res://gameplay/clickmovetest/source_startup.gd")
const Terrain := preload("res://game_core/movement/terrain_cast.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	if OS.get_environment("FORMAL_SURFACE_RULES").is_empty():
		print("SKIP 普通入口喷火验证：需要同一原图合同与私有视听")
		quit()
		return
	root.size=Vector2i(800,600)
	if change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))!=OK:
		quit(1)
		return
	await scene_changed
	await process_frame
	var startup := current_scene as Startup
	var scene := startup.scene
	var player := startup.player
	var actor: Node2D = scene.actor
	var runtime: Node = scene._charged_actor_runtime
	var terrain: RefCounted = scene.surface_elements
	var health := player.current_health()
	var target_cell := Vector3i(0,0,0)
	var safe := Vector2(1.5,.5)
	var target := Vector2(.5,.5)
	_check(actor.get_movement_position()==Vector2.ZERO and is_instance_valid(runtime)
		and is_instance_valid(runtime.resolve(20001)) and is_instance_valid(runtime.resolve(20010))
		and not is_instance_valid(scene.training_target) and terrain.sample(target_cell).flags==0,
		"正常出生、已有实际两项能力，没有假人或预烧地表")
	if failures:
		quit(1)
		return
	# 原 x=1 没有可燃覆盖。用实际鼠标点击原地图移动到这个施法点。
	_click(safe)
	for i in range(140):
		await physics_frame
		if not actor.execution.has_move_order(): break
	_check(actor.get_movement_position().distance_to(safe)<.15,"实际点击移动到源无草格")
	var fire: Node=runtime.resolve(20010)
	var feedbacks := []
	player.damage_completed.connect(func(_source,_input,previous,applied):
		feedbacks.append([previous,applied,startup.player.current_health(),startup.damage_screen_flash.color.a]))
	_mouse(target)
	await process_frame
	await process_frame
	_key(KEY_Q,true)
	var observed_attack := false
	var burned := false
	for i in range(120):
		await physics_frame
		observed_attack = observed_attack or scene.human_presentation.driver.current_animation_key=="Attack"
		burned = (terrain.sample(target_cell).flags & 2)!=0
		if burned and observed_attack: break
	_key(KEY_Q,false)
	var burn: Dictionary=terrain.sample(target_cell).states.get(2,{})
	_check(observed_attack and burned and burn.get("source_ability",0)==20010
		and is_instance_valid(scene.flamethrower_visual),
		"Q 经实际第二槽、原攻击动作和表现进入 20010 世界 Fire 轨")
	_check(feedbacks.is_empty() and player.current_health()==health,
		"空命中不产生自击的 2003，玩家在安全地表")
	for i in range(120):
		await physics_frame
		if not fire.spec.active: break
	_check(not fire.spec.active,"松开 Q 正常结束同一技能")
	_click(target)
	for i in range(140):
		await physics_frame
		if not feedbacks.is_empty(): break
	_check(actor.get_movement_position().distance_to(target)<.34
		and not feedbacks.is_empty() and feedbacks[0].slice(0,3)==[health,1,health-1]
		and feedbacks[0][3]>0.0,"实际移入刚才由 Q 点燃的原格，按接触时钟减一命及闪屏")
	# 原 Cue 移除不停止音频；等待独立声道释放再销毁，避免混音线程未清队列。
	var wait_until := Time.get_ticks_msec()+5000
	while scene.flamethrower_audio.active_voice_count()>0 and Time.get_ticks_msec()<wait_until:
		await process_frame
	_check(scene.flamethrower_audio.active_voice_count()==0,"原声道自然结束并回收")
	await process_frame
	if not failures: print("PASS 默认项目 Q 到原地表与玩家接触：%d 项（%s）" % [checks,DisplayServer.get_name()])
	quit(1 if failures else 0)

func _screen(point: Vector2) -> Vector2:
	return root.get_canvas_transform()*Terrain.to_physics(point)

func _mouse(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.device=0
	event.position=_screen(point)
	event.relative=Vector2(1,1)
	root.push_input(event,true)

func _click(point: Vector2) -> void:
	_mouse(point)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=_screen(point)
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=down
		root.push_input(event,true)

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=pressed
	root.push_input(event,true)

func _check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",label)
