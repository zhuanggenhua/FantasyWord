extends SceneTree
## 从正常入口，用原地图地表伤害检查同一主角的 HUD；不创建测试专有玩家。
const Boot := preload("res://gameplay/clickmovetest/source_startup.gd")
const Bars := preload("res://gameplay/clickmovetest/source_resource_bars.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var dir:=OS.get_environment("FORMAL_PAUSE_SOURCE")
	if dir.is_empty() or not FileAccess.file_exists(dir.path_join("abilities-layout.json")):
		print("SKIP 原 HUD 资源条需要私有原场景、字体与 GUI 图集。")
		quit(0)
		return
	root.size=Vector2i(960,540)
	if change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))!=OK:
		quit(1)
		return
	await scene_changed
	await process_frame
	var startup:=current_scene as Boot
	_check(is_instance_valid(startup.ability_hud) and is_instance_valid(startup.ability_hud.resource_bars),
		"原 HUD 资源条从项目正常入口装配")
	if failures>0: _finish(); return
	var bars:=startup.ability_hud.resource_bars
	var player:=startup.player
	var scene:=startup.scene
	var actor: Node2D=scene.actor
	scene.training_target.ai_controller.stop()
	scene.set_process(false)
	_check(bars._values==PackedInt32Array([100,100,40,40]) and bars._actor==actor
		and bars._fills[0].size.x==384.0 and bars._fills[1].size.x==384.0,
		"非占位：同一主角当前与上限分别为 100/100、40/40")
	var name_lines: Array=bars._name_art[0].get_meta("lines")
	var glyph_counts:=PackedInt32Array()
	for line in name_lines: glyph_counts.append(line.glyphs.size())
	var hp_lines: Array=bars._number_art[0].get_meta("lines")
	var mp_lines: Array=bars._number_art[1].get_meta("lines")
	_check(glyph_counts==PackedInt32Array([8,7,4]) and bars._name_art[0].position==Vector2(24,20)
		and bars._name_art[0].get_meta("baseline").x==48.0
		and hp_lines[0].glyphs.size()==7 and mp_lines[0].glyphs.size()==5,
		"原缺失术语按名字框换行且顶对齐，数值使用原字形")
	_check(bars._sliders[0].position==Vector2(232,36) and bars._sliders[1].position==Vector2(232,100)
		and startup._over_native_ui(Vector2(113.5,15.5))
		and not startup._over_native_ui(Vector2(112.5,15.5))
		and startup._over_native_ui(Vector2(14,22))
		and not startup._over_native_ui(Vector2(313,45)),
		"原透明边缘及名称矩形挡地图，容器空白不挡")
	var command_count: int=scene.command_count
	_click(Vector2(113.5,15.5))
	_check(scene.command_count==command_count and scene.click_observation.latest.over_ui,
		"真实点地命中资源条，只拦截而不修改资源")
	var native:=DisplayServer.get_name()!="headless"
	var before:Image=null
	if native:
		await RenderingServer.frame_post_draw
		before=root.get_texture().get_image()
		# 原 ClickMoveTest 测试面板排序高于正式 HUD，此处透过其 0.88 暗底取样。
		var tint: Color=scene.control_panel.color
		_check(scene.control_panel.is_visible_in_tree() and _near(before.get_pixel(295,21),_over(Color("#e43b44"),tint))
			and _near(before.get_pixel(295,53),_over(Color("#0095e9"),tint)),"原生窗口显示测试面板下的原始填充纹理")
	var grass:=Vector2(.5,.5)
	actor.request_move_position(grass)
	await physics_frame
	await physics_frame
	await process_frame
	scene.set_physics_process(false)
	var terrain:RefCounted=scene.surface_elements
	_check(actor.get_movement_position().is_equal_approx(grass)
		and terrain.apply_point(terrain.FIRE,grass,1,.1),"原地图主角踏入正式 Fire 草格")
	scene.advance_surface_contact(.5)
	scene.run_surface_contact_effects()
	var hp_after: Array=bars._number_art[0].get_meta("lines")
	_check(player.current_health()==99 and bars._values==PackedInt32Array([99,100,40,40])
		and hp_after[0].glyphs.size()==6 and is_equal_approx(bars._fills[0].size.x,384.0*.99)
		and bars._fills[1].size.x==384.0,"真实受击后生命数值与填充刷新，法力不变")
	_check(bars._shake_time==0.0 and bars.is_processing() and bars._sliders[0].position==Bars.SLIDER_RECT.position,
		"正式下降触发生命 Slider 原摇动的首步")
	# 实际帧驱动；测量发生摆动的同时原名、法力条不动。
	await process_frame
	await process_frame
	var elapsed:float=bars._shake_time
	var moved:Vector2=bars._sliders[0].position
	_check(elapsed>0 and elapsed<.2 and moved.is_equal_approx(Bars.SLIDER_RECT.position+Bars.shake_offset(elapsed))
		and bars._name_art[0].position==Vector2(24,20) and bars._sliders[1].position==Vector2(232,100),
		"生命滑条按实际缩放时间位移，术语及魔力条保持原位")
	# 第二次正式受击取消在途摇动，并用同一个位置作为新起点。
	scene.advance_surface_contact(.5)
	scene.run_surface_contact_effects()
	_check(player.current_health()==98 and bars._shake_time==0.0 and bars._sliders[0].position==Bars.SLIDER_RECT.position,
		"第二次真实掉血重开摇动，不叠加偏移")
	# 等缩放帧执行完毕，避免对比位移或上一击的全屏反馈。
	await create_timer(.3,true,false,true).timeout
	_check(bars._sliders[0].position==Bars.SLIDER_RECT.position and not bars.is_processing(),
		"缩放 0.2 秒后恢复作者位置，不维持每帧刷新")
	if native:
		await RenderingServer.frame_post_draw
		var after:=root.get_texture().get_image()
		_check(_near(after.get_pixel(307,24),_over(Bars.BACKGROUND,scene.control_panel.color))
			and _near(after.get_pixel(295,53),before.get_pixel(295,53))
			and not _near(after.get_pixel(307,24),before.get_pixel(307,24)),
			"真实窗口中受击后血条右端露出深色底，法力像素保持")
	_check(player.set_current_controlled(false) and bars._values.is_empty()
		and bars._number_bounds[0].size==Vector2.ZERO and not bars._fills[0].visible
		and not player._attributes.current_health_changed.is_connected(bars._on_health_changed),
		"实际控制解除后解绑旧属性、清零填充与数值，名称框保留")
	_check(player.set_current_controlled(true) and bars._values==PackedInt32Array([98,100,40,40])
		and not bars.is_processing(),"同一角色重新绑定立即读最新属性，不误播下降反馈")
	_finish()

func _over(base:Color, overlay:Color) -> Color:
	return base.lerp(overlay,overlay.a)

func _near(a:Color,b:Color) -> bool:
	return absf(a.r-b.r)<.012 and absf(a.g-b.g)<.012 and absf(a.b-b.b)<.012

func _click(point: Vector2) -> void:
	var e:=InputEventMouseMotion.new()
	e.device=0
	e.position=point
	e.relative=Vector2.ONE
	root.push_input(e,true)
	for down in [true,false]:
		var press:=InputEventMouseButton.new()
		press.device=0
		press.position=point
		press.button_index=MOUSE_BUTTON_LEFT
		press.pressed=down
		root.push_input(press,true)

func _check(ok:bool, label:String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL ",label)

func _finish() -> void:
	print("%s 原战斗生命与魔力条：%d/%d（%s）"%[
		"PASS" if failures==0 else "FAIL",checks-failures,checks,DisplayServer.get_name()])
	quit(int(failures!=0))
