extends "res://tests/test_clickmovetest_single_player_actor.gd"
const Point = preload("res://game_core/input/mouse_point_actions.gd")


func run() -> void:
	var silver := OS.get_environment("FORMAL_PANEL_SILVER")
	var cjk := OS.get_environment("FORMAL_PANEL_CJK")
	if silver.is_empty() or cjk.is_empty():
		print("SKIP 原静态测试面板：需要原 Silver 与 CJK 字体。")
		quit()
		return
	root.size=Vector2i(800,600)
	var scene = Entry.instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.set_physics_process(false)
	var owner := ActorOwner.new()
	var events := MapEvents.new()
	var directory := ProjectSettings.globalize_path("user://clickmovetest-control-panel")
	var rule_path := OS.get_environment("FORMAL_SURFACE_RULES")
	var animation_path := OS.get_environment("FORMAL_PLAYER_DAMAGE_ANIMATION")
	var material_path := OS.get_environment("FORMAL_PLAYER_DAMAGE_MATERIAL")
	var actual := not rule_path.is_empty() and not animation_path.is_empty() and not material_path.is_empty() \
		and not OS.get_environment("FORMAL_PLAYER_TEXTURES").is_empty()
	var pack := [read(rule_path),read(animation_path)] if actual else fixtures(scene,directory)
	if actual: directory=OS.get_environment("FORMAL_PLAYER_TEXTURES")
	var rules: Dictionary = pack[0] if rule_path.is_empty() else read(rule_path)
	var source_view: Node2D = scene.start_human_presentation(pack[1],directory)
	if actual:
		check(is_instance_valid(source_view) and source_view.bind_base_material(read(material_path),
			directory.path_join("uv"),directory.path_join("appearance")),"同场主角使用实际私有源图与材质")
	var point := Point.new(0)
	point.enable(Point.Map.GAMEPLAY)
	check(is_instance_valid(source_view) and owner.configure(scene.actor)
		and scene.start_human_logic(owner,rules,owner.get_player_provider,func():return null,
			events,func(_p):return is_instance_valid(root.gui_get_hovered_control()))
		and scene.start_human_aim(owner,owner) and scene.bind_mouse_point_actions(point),
		"有真实角色、相机和当前控制者的测试场景")
	if failed>0:
		_finish_panel(scene)
		return
	check(not scene.bind_source_control_panel("res://missing.ttf",cjk)
		and scene.control_panel==null,"缺原字节时不显示替代字体")
	check(scene.bind_source_control_panel(silver,cjk) and not scene.bind_source_control_panel(silver,cjk),
		"实际按源字体装配唯一面板")
	if failed>0:
		_finish_panel(scene)
		return
	var panel: ColorRect=scene.control_panel
	check(panel.size.is_equal_approx(Vector2(1120,520))
		and panel.position.is_equal_approx(Vector2(28,28)*root.size.y/1080.0),
		"左上 28 边距及 1120×520 参考矩形按高缩放")
	check(panel.mouse_filter==Control.MOUSE_FILTER_IGNORE
		and panel.title.mouse_filter==Control.MOUSE_FILTER_IGNORE and panel.body.mouse_filter==Control.MOUSE_FILTER_IGNORE,
		"原底图与两个文本均不阻挡点击")
	check(panel.body.text.begins_with("当前移动模式：点击移动") and panel.body.text.contains("还没有收到 Gameplay 点击输入"),
		"首次显示当前真实控制状态")
	await process_frame
	var inside := Vector2(430,245)
	_click_inside(inside)
	check(not scene.click_observation.latest.get("over_ui",true)
		and scene.click_observation.latest.get("source_screen_position")==Vector2(inside.x,root.size.y-inside.y)
		and scene.actor.execution.has_move_order() and not scene.click_observation.latest.has("order_after_updates"),
		"面板内原生按钮事件实际生成路线，读数不能抢在派发前：%s / %s" % [scene.click_observation.latest,scene.last_result])
	scene._process(0)
	check(not scene.click_observation.latest.has("order_after_updates"),"经过第一轮更新先倒计时")
	scene._process(0)
	check(scene.click_observation.latest.get("order_after_updates",false)
		and panel.body.text.contains("点击后生成移动指令=是"),"后续更新报告同一角色的实际路线")
	var key := InputEventKey.new()
	key.physical_keycode=KEY_TAB
	key.pressed=true
	root.push_input(key,true)
	scene._process(0)
	check(panel.body.text.begins_with("当前移动模式：方向移动"),"Tab 使用当前控制拥有者而不是面板开关")
	_click_inside(Vector2(440,395))
	scene._process(0)
	scene._process(0)
	check(not scene.click_observation.latest.get("order_after_updates",true)
		and panel.body.text.contains("点击后生成移动指令=否"),"另一种移动模式，原面板外点击也不伪造路线")
	owner.set_current_controlled(false)
	_click_inside(inside)
	scene._process(0)
	check(not scene.click_observation.latest.had_input_target and panel.body.text.contains("输入目标=无"),
		"主角可回退，但不冒充当前有输入目标")
	if DisplayServer.get_name()!="headless":
		await process_frame
		await RenderingServer.frame_post_draw
		var with_body := root.get_texture().get_image()
		panel.body.hide()
		await process_frame
		await RenderingServer.frame_post_draw
		var without_body := root.get_texture().get_image()
		var changed := 0
		for y in range(60,mini(306, with_body.get_height()),2):
			for x in range(25,mini(628,with_body.get_width()),2):
				if with_body.get_pixel(x,y)!=without_body.get_pixel(x,y): changed+=1
		check(changed>200,"中文 Body 真正绘制非空像素，而不只是设置文本属性")
		print("原生 Body 可见变化采样：",changed)
		panel.body.show()
		root.size=Vector2i(1000,720)
		await process_frame
		await process_frame
		var factor: float = scene.get_viewport_rect().size.y/1080.0
		check(panel.scale.is_equal_approx(Vector2.ONE*factor)
			and panel.position.is_equal_approx(Vector2(28,28)*factor) and panel.body.get_line_count()>7,
			"另一窗口比例仍按 Unity 高度缩放、保留原多行")
	_finish_panel(scene)


func _click_inside(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.device=0
	move.position=at
	move.relative=at
	root.push_input(move,true)
	var click := InputEventMouseButton.new()
	click.position=at
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=true
	root.push_input(click,true)


func _finish_panel(scene: Node) -> void:
	scene.free()
	if failed==0: print("PASS ClickMoveTest 原诊断面板：%d 项" % n)
	quit(1 if failed else 0)
