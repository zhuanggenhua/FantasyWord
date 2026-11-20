extends SceneTree
const Boot := preload("res://gameplay/clickmovetest/source_startup.gd")
const Commands := preload("res://game_core/interaction/character_command_executor.gd")
const Gate := preload("res://game_core/combat/active_ability_start_rules.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL ",label)

func key(code: Key, down: bool) -> void:
	var e:=InputEventKey.new()
	e.keycode=code
	e.physical_keycode=code
	e.pressed=down
	root.push_input(e,true)

func tap(code: Key) -> void:
	key(code,true); key(code,false)

func mouse(pos: Vector2) -> void:
	var e:=InputEventMouseMotion.new()
	e.device=0
	e.position=pos; e.relative=Vector2.ONE
	root.push_input(e,true)
	for down in [true,false]:
		var press:=InputEventMouseButton.new()
		press.device=0
		press.position=pos; press.button_index=MOUSE_BUTTON_LEFT; press.pressed=down
		root.push_input(press,true)

func finish() -> void:
	print("%s 原战斗失败提示：%d/%d"%["PASS" if failures==0 else "FAIL",checks-failures,checks])
	quit(int(failures!=0))

func run() -> void:
	var dir:=OS.get_environment("FORMAL_PAUSE_SOURCE")
	if dir.is_empty() or not FileAccess.file_exists(dir.path_join("abilities-layout.json")):
		print("SKIP 原战斗提示需要私有作者字体与技能 HUD。")
		finish()
		return
	root.size=Vector2i(960,540)
	check(change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))==OK,"从真实 F5 启动")
	await scene_changed
	await process_frame
	var startup:=current_scene as Boot
	check(startup!=null and is_instance_valid(startup.ability_hud),"实际场景挂载 HUD 与失败提示")
	if startup==null or not is_instance_valid(startup.ability_hud): finish(); return
	startup.scene.training_target.ai_controller.stop()
	var hud:=startup.ability_hud
	var message:=hud.message
	var blocked_point:=Vector2(130,454)
	check(message.value.is_empty() and not message.visible and not hud.blocks_map_pointer(blocked_point),
		"启动不显示作者占位文本，不拦射线")
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	var before: Image=root.get_texture().get_image() if DisplayServer.get_name()!="headless" else null
	key(KEY_3,true)
	check(message.value=="这个槽位没有装备技能。" and message.visible and message.modulate.a==1.0,
		"真实第三空槽的施放失败发送原文")
	if not message.visible: finish(); return
	check(message.get_rect()==Rect2(0,899,1920,32) and hud.blocks_map_pointer(blocked_point)
		and not hud.blocks_map_pointer(Vector2(130,443)) and not hud.blocks_map_pointer(Vector2(130,470)),
		"与条目无关的全宽原文本 Rect 才是额外射线区域")
	var glyphs: Array=message._label._line.glyphs
	check(glyphs.size()==11 and glyphs[0].silver and is_equal_approx(message._label._line.baseline.y,18.526315),
		"原 Silver 动态字形及居中基线")
	await process_frame
	if before!=null:
		await RenderingServer.frame_post_draw
		var after:=root.get_texture().get_image()
		var changed:=0
		var outside:=0
		for y in range(446,469):
			for x in range(415,545):
				if before.get_pixel(x,y)!=after.get_pixel(x,y):
					if after.get_pixel(x,y).r>.7 and after.get_pixel(x,y).g>.7: changed+=1
		for y in range(450,464):
			for x in range(273,302):
				if before.get_pixel(x,y)!=after.get_pixel(x,y): outside+=1
		check(changed>50 and outside==0,"原生窗口实际渲染白字，文本框不是全屏实色")
	var last_shown: int=message._shown_frame
	key(KEY_3,false)
	check(message._shown_frame==last_shown,"实际空槽松键不显示或刷新提示")
	var hits: int=startup.scene.command_count
	mouse(blocked_point)
	check(startup.scene.command_count==hits and message._shown_frame==last_shown
		and startup.scene.click_observation.latest.over_ui,"提示区域挡真实点地，未编造移动失败")
	message.set_process(false)
	message.advance(false,.6,.6)
	check(message._hold_left>0.0 and message.modulate.a==1.0,"等待阶段不预先淡出")
	tap(KEY_ESCAPE)
	var remaining: float=message._hold_left
	message.advance(paused,2.0,2.0)
	check(paused and message._hold_left==remaining and message.modulate.a==1.0,"实际 Pause 停住等待，保留 HUD")
	tap(KEY_ESCAPE)
	message.advance(paused,1.5,1.5)
	check(not paused and message._fading and message.modulate.a==1.0,"恢复游戏后才进入不缩放的淡出")
	tap(KEY_ESCAPE)
	message.advance(paused,0.0,.25)
	check(paused and is_equal_approx(message.modulate.a,.5),"已开始的淡出在真正 Pause 内照常推进")
	message.advance(paused,0.0,.25)
	check(not message.visible and message.value.is_empty() and not hud.blocks_map_pointer(blocked_point),
		"透明结束时同时清空文字和提示射线")
	tap(KEY_ESCAPE)
	message.set_process(true)
	key(KEY_3,true); key(KEY_3,false)
	await create_timer(.25,true,false,true).timeout
	check(message._hold_left < 1.49 and message._hold_left > .5 and message.visible,
		"真实帧驱动缩短展示时间，不只测手动调度")
	key(KEY_4,true); key(KEY_4,false)
	check(message._hold_left==1.5 and message.modulate.a==1.0,"第二次真实失败重置旧定时器")
	# 此初始角色没有有效非零冷却/法力拒绝。以下只核对两条事件的展示契约，
	# 不把直接注入拒绝 reason 当成战斗中自然触发。
	startup._on_source_ability_rejected(20010,Gate.Result.NOT_ENOUGH_MANA)
	check(message.value=="Not enough mana" and not message._label._line.glyphs[0].silver,
		"独立 GAS reason 使用原 RPGSystem 字体与原文")
	startup._on_source_gameplay_command_failed({"kind":Commands.Kind.FIRE_ABILITY},Commands.Failure.ABILITY_REJECTED)
	startup._on_source_ability_rejected(20010,Gate.Result.UNKNOWN)
	check(message.value=="Not enough mana","泛化 AbilityRejected 与未知 reason 均不覆盖已经显示的提示")
	startup._on_source_ability_rejected(20010,Gate.Result.ON_COOLDOWN)
	check(message.value=="Ability on cooldown","冷却专用文案从源枚举映射")
	startup._on_source_ability_rejected(20010,Gate.Result.INCAPACITATED)
	check(message.value=="You cannot use abilities right now","无法施法专用文案从源枚举映射")
	finish()
