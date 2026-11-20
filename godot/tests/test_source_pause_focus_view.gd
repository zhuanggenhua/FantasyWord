extends SceneTree
const View := preload("res://gameplay/clickmovetest/source_pause_focus_view.gd")
const Line := preload("res://gameplay/clickmovetest/source_pause_text_line.gd")
const Atlas := preload("res://gameplay/clickmovetest/source_menu_glyph_atlas.gd")
var n := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(pass_check: bool, label: String) -> void:
	n+=1
	if not pass_check:
		failed+=1
		printerr("FAIL ",label)

func run() -> void:
	var directory := OS.get_environment("FORMAL_PAUSE_SOURCE")
	var view := View.new()
	check(not view.bind({},""),"无原素材不生成面板")
	if directory.is_empty():
		print("SKIP 私有原菜单素材")
		view.free()
		finish()
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("pause-contract.json")))
	var ok := view.bind(data,directory)
	check(ok,"真实参考面板")
	if not ok:
		view.free()
		finish()
		return
	var atlas := Atlas.new()
	check(atlas.bind(data,directory.path_join("pause-font-atlas.bin")),"页脚共享原 RPGSystem 字体")
	var specs: Array = data.text_layout.default_footer.labels
	var select := Line.layout(atlas,"Select",Rect2(692,996,180,64),specs[0])
	var close := Line.layout(atlas,"Close",Rect2(1048,996,180,64),specs[1])
	check(not select.is_empty() and not close.is_empty()
		and select.baseline.distance_to(Vector2(736.177778,1046))<.001
		and close.baseline.distance_to(Vector2(1048,1046))<.001,"原字号与各自靠内的基线")
	var bad := data.duplicate(true)
	bad.text_layout.default_footer.icons_visible=true
	var invalid := View.new()
	check(not invalid.bind(bad,directory),"未经迁移的原显示图标变体不降级冒充默认")
	invalid.free()
	root.size = Vector2i(1920,1080)
	root.add_child(view)
	view.set_process(false)
	view.apply_stack_interactions(true)
	check(view.reference_footer_blocks(Vector2(692,1000)) and view.reference_footer_blocks(Vector2(1048,1000))
		and not view.reference_footer_blocks(Vector2(691,1000)) and not view.reference_footer_blocks(Vector2(872,1000))
		and not view.reference_footer_blocks(Vector2(900,1000)) and not view.reference_footer_blocks(Vector2(1000,1000))
		and view.reference_hit(Vector2(760,1030))==0,"整块页脚文字参与遮挡，默认空图标不遮挡，也不构成可点条目")
	check(not view.try_focus_default_target() and view.selected_action()==0 and not view.label_visible(5),"首次打开没有记忆焦点")
	check(view.reference_hit(Vector2(44,300))==0 and view.reference_hit(Vector2(80,300))==5
		and view.reference_hit(Vector2(190,300))==0,"行边空白和隐藏标签不可命中，图标可命中")
	view.sample_point(5,5,false)
	view.advance_unscaled(.05)
	check(view.entry_tint(5).is_equal_approx(View.NORMAL.lerp(View.BRIGHT,.5)) and not view.label_visible(5),
		"单独高亮只有颜色，不开启标签")
	view.sample_point(5,5,true)
	view.advance_unscaled(.05)
	check(view.entry_tint(5).is_equal_approx(View.BRIGHT) and view.label_visible(5)
		and view.reference_hit(Vector2(190,300))==5,"同一静止点进入有效 Point 后选中且可点击标签")
	view.set_pressed(5)
	view.sample_point(0,0,true)
	view.advance_unscaled(.1)
	check(view.entry_tint(5).is_equal_approx(Color.WHITE) and view.label_visible(5),"按压离开仍捕获，颜色优先")
	view.set_pressed(0)
	view.advance_unscaled(.1)
	check(view.entry_tint(5).is_equal_approx(View.BRIGHT) and view.label_visible(5),"阴影不清焦点")
	view.sample_point(7,7,true)
	view.advance_unscaled(.1)
	check(view.selected_action()==7 and view.label_visible(7) and not view.label_visible(5),"改选只显示一个标签")
	view.apply_stack_interactions(false)
	view.advance_unscaled(.1)
	check(view.selected_action()==0 and view.entry_tint(7).is_equal_approx(Color.WHITE)
		and not view.label_visible(7) and view.reference_hit(Vector2(80,700))==0
		and not view.reference_footer_blocks(Vector2(760,1030)),"覆盖后禁交互但保留入口记忆")
	view.apply_stack_interactions(true)
	check(view.try_focus_default_target() and view.selected_action()==7 and view.label_visible(7),"还原同一面板的真实选中入口")
	view.advance_unscaled(.1)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var pixels := root.get_texture().get_image()
		check(white_pixels(pixels,Rect2i(168,668,240,64))>500
			and white_pixels(pixels,Rect2i(168,268,240,64))==0,
			"原生设置焦点恢复，只出现设置标签")
		check(white_pixels(pixels,Rect2i(733,996,145,64))>400
			and white_pixels(pixels,Rect2i(1045,996,125,64))>350
			and white_pixels(pixels,Rect2i(892,996,64,64))==0
			and white_pixels(pixels,Rect2i(964,996,64,64))==0,"原生 Select/Close 保持原对齐且两个插槽无图标")
	view.set_process(true)
	Engine.time_scale=0.0
	paused=true
	view.set_pressed(7)
	var end := Time.get_ticks_usec()+140000
	while Time.get_ticks_usec()<end:
		await process_frame
	await process_frame
	check(view.entry_tint(7).is_equal_approx(Color.WHITE),"引擎真暂停期间颜色仍推进")
	paused=false
	Engine.time_scale=1.0
	finish()

func white_pixels(pixels: Image, area: Rect2i) -> int:
	var count := 0
	for y in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):
			var p := pixels.get_pixel(x,y)
			if p.r>.9 and p.g>.9 and p.b>.9: count+=1
	return count

func finish() -> void:
	if failed==0: print("PASS 原暂停菜单焦点状态：",n," 项")
	quit(1 if failed else 0)
