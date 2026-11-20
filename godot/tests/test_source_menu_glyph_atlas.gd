extends SceneTree
## 专项验证原字形数据和实际绘制；不把独立字形当作完整菜单。
const Atlas := preload("res://gameplay/clickmovetest/source_menu_glyph_atlas.gd")
class GlyphProbe extends Control:
	var atlas: RefCounted
	var glyph: Dictionary
	func _draw() -> void:
		draw_texture_rect_region(atlas.texture,glyph.destination,glyph.region)

var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",label)

func run() -> void:
	var atlas := Atlas.new()
	check(not atlas.bind({},"res://project.godot") and atlas.glyph(80,90.0,Vector2.ZERO).is_empty(),
		"缺少原字体明确失败，不替代")
	var directory := OS.get_environment("FORMAL_PAUSE_SOURCE")
	if directory.is_empty():
		print("SKIP 私有原 Alpha8 字形与原生绘制")
		_finish()
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("pause-contract.json")))
	var path := directory.path_join("pause-font-atlas.bin")
	check(not Atlas.new().bind(data,"res://project.godot"),"拒绝不匹配的图集内容")
	check(atlas.bind(data,path) and atlas.texture.get_size()==Vector2(1024,1024),"锁定原始 Alpha8")
	if atlas.texture==null:
		_finish()
		return
	var p := atlas.glyph("P".unicode_at(0),90.0,Vector2(30,80))
	check(p.advance==39 and p.destination==Rect2(21,20,52,69) and p.region==Rect2(52,697,52,69),
		"原 P 的字距、基线、9 像素 padding 与翻转的 atlas 区域")
	var l := atlas.glyph("L".unicode_at(0),90.0,Vector2.ZERO)
	check(l.destination.size.x==47 and l.region.size.x==46,"L 保留几何与取样宽度的原差异")
	var zero := atlas.glyph(32,45.0,Vector2.ZERO)
	check(zero.advance==14.0 and not zero.region.has_area() and atlas.glyph(0x6c49,90.0,Vector2.ZERO).is_empty(),
		"空格只有 advance，缺少的 glyph 不借默认字体")
	var image := atlas.texture.get_image()
	var raw := FileAccess.get_file_as_bytes(path)
	var checked := 0
	for x in [0,61,75,85,700]:
		for y in [0,267,290,318,900,1023]:
			var c := int(round(image.get_pixel(x,1023-y).r*255.0))
			if c==raw[y*1024+x]: checked+=1
	check(checked==30,"自下而上的原 Alpha8 逐样点保持")
	var normal := atlas.face_material(false,p.glyph_scale)
	var bold := atlas.face_material(true,p.glyph_scale)
	check(is_equal_approx(normal.get_shader_parameter("screen_distance_scale"),sqrt(2.0)*10.0)
		and normal.get_shader_parameter("face_weight")==0
		and is_equal_approx(bold.get_shader_parameter("face_weight"),.084375),
		"材料从原梯度、正常权重与粗体权重派生")
	if DisplayServer.get_name()!="headless":
		root.size = Vector2i(320,220)
		var backdrop := ColorRect.new()
		backdrop.color = Color.BLACK
		backdrop.size = Vector2(320,220)
		root.add_child(backdrop)
		var probe := GlyphProbe.new()
		probe.atlas = atlas
		probe.glyph = p
		probe.material = normal
		probe.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		root.add_child(probe)
		await RenderingServer.frame_post_draw
		var rendered := root.get_texture().get_image()
		var expected_on := 0
		var checked_on := 0
		var checked_off := 0
		for y in range(69):
			for x in range(52):
				var source := image.get_pixel(52+x,697+y).r
				var actual := rendered.get_pixel(21+x,20+y).r
				if source >= .60:
					expected_on+=1
					if actual>.9: checked_on+=1
				elif source<=.40 and actual<.05: checked_off+=1
		check(expected_on>100 and checked_on>=expected_on*.97 and checked_off>800,
			"原生 framebuffer 按原字形显现且 SDF 外部透明")
		print("原生原字形 SDF 实像素：",checked_on," / ",expected_on,"，外部 ",checked_off)
	_finish()

func _finish() -> void:
	if not failures: print("PASS 原暂停菜单字形材料：",checks," 项（",DisplayServer.get_name(),"）")
	quit(1 if failures else 0)
