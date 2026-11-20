extends SceneTree
const Atlas := preload("res://gameplay/clickmovetest/source_menu_glyph_atlas.gd")
const Line := preload("res://gameplay/clickmovetest/source_pause_text_line.gd")
const Column := preload("res://gameplay/clickmovetest/source_pause_entry_column.gd")

var checks := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		printerr("FAIL ", label)

func rect(fields: Array) -> Rect2:
	return Rect2(fields[0],fields[1],fields[2],fields[3])

func run() -> void:
	var atlas := Atlas.new()
	check(Line.layout(atlas,"Pause",Rect2(704,508,512,64),{"style":17,"size":80,"horizontal":2,"vertical":512}).is_empty(),
		"缺原字形时不替换")
	var directory := OS.get_environment("FORMAL_PAUSE_SOURCE")
	if directory.is_empty():
		print("SKIP 原暂停标题字体")
		finish()
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("pause-contract.json")))
	if not atlas.bind(data,directory.path_join("pause-font-atlas.bin")):
		check(false,"原字体成功加载")
		finish()
		return
	var title: Dictionary = data.text_layout.title
	var box := rect(title.rect)
	var visible := Line.layout(atlas,title.text,box,title)
	check(box==Rect2(704,508,512,64) and visible.get("text")=="PAUSE","原标题框及大写")
	if visible.is_empty():
		finish()
		return
	check(is_equal_approx(visible.width,186.84444444) and visible.baseline.is_equal_approx(Vector2(866.577778,562.5)),
		"中间基线与实际行宽，非墨迹框居中或尾端加一格")
	var p: Dictionary = atlas.layout_glyph(80,90,Vector2.ZERO,true)
	check(p.destination.is_equal_approx(Rect2(-2.9375,-52.25,39.875,53.5))
		and p.region.is_equal_approx(Rect2(58.0625,703.0625,39.875,56.875)),
		"粗体 UV 两轴新增 padding，网格只增加横向")
	var q: Dictionary = atlas.layout_glyph(80,90,Vector2.ZERO,false)
	check(q.destination.is_equal_approx(Rect2(-1.25,-52.25,36.5,53.5))
		and q.region.is_equal_approx(Rect2(59.75,704.75,36.5,53.5)),
		"实际纯面材质 padding 1.25，非图集分配的 9")
	var col := Column.new()
	var admitted := col.bind(data,directory.path_join("SPS_GUI.png"))
	check(admitted,"真实背景、边框和图标")
	if not admitted:
		col.free()
		finish()
		return
	var entries := col.entries()
	var widths := [231.11111111,128.0,175.64444444,171.37777778,107.37777778,183.46666667,87.46666667]
	for i in range(entries.size()):
		var e: Dictionary = entries[i]
		var label := Line.layout(atlas,e.label,e.label_rect,data.text_layout.entry)
		check(not label.is_empty() and not label.bold and label.text==e.label
			and label.baseline.is_equal_approx(Vector2(168,318+80*i)) and is_equal_approx(label.width,widths[i]),
			"入口从左起且原字距不换行："+e.label)
	var title_view := Line.new()
	var label_view := Line.new()
	check(title_view.configure(atlas,title.text,box,title)
		and label_view.configure(atlas,entries[0].label,entries[0].label_rect,data.text_layout.entry),
		"原 SDF 材质应用于标题和条目")
	if DisplayServer.get_name()!="headless":
		root.size = Vector2i(1920,1080)
		root.add_child(col)
		root.add_child(title_view)
		root.add_child(label_view)
		await RenderingServer.frame_post_draw
		var rendered := root.get_texture().get_image()
		check(white_pixels(rendered,Rect2i(858,506,208,64))>1900,"原生中心标题完整呈现")
		check(white_pixels(rendered,Rect2i(165,270,238,57))>1200,"原生入口标签呈现于左对齐基线")
		check(white_pixels(rendered,Rect2i(168,348,235,64))==0,"没有为未选中的下一行绘制标签")
	else:
		title_view.free(); label_view.free(); col.free()
	finish()

func white_pixels(rendered: Image, area: Rect2i) -> int:
	var count := 0
	for y in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):
			var c := rendered.get_pixel(x,y)
			if c.r>.9 and c.g>.9 and c.b>.9: count += 1
	return count

func finish() -> void:
	if failed==0: print("PASS 原暂停标题和条目文字：",checks," 项（",DisplayServer.get_name(),"）")
	quit(1 if failed else 0)
