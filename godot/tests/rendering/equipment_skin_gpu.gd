extends SceneTree
## 真实 Godot 兼容图形驱动辅助判据；不是原图或正式场景验收。
const Binder = preload("res://gameplay/presentation/equipment_subset_material.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func texture(color: Color) -> ImageTexture:
	var image := Image.create(1,1,false,Image.FORMAT_RGBAF)
	image.fill(color)
	return ImageTexture.create_from_image(image)
func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("需要真实 Godot 图形驱动；无头模式不能验证肤色输出")
		quit(2)
		return
	var base := Color(0.51,0.72,0.24,1.0)
	var dst := Color(0.82,0.31,0.64,1.0)
	var source_linear := base.srgb_to_linear()
	var target_linear := dst.srgb_to_linear()
	var zero := texture(Color.TRANSPARENT)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1,1)
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var plane := ColorRect.new()
	plane.size=Vector2.ONE
	viewport.add_child(plane)
	var cases := [
		{"name":"首个匹配优先于更近的第二项","enabled":true,"domain":1,"head":false,"expected":dst},
		{"name":"同 RGB 的头发不染色","enabled":true,"domain":1,"head":true,"expected":base},
		{"name":"未知色域禁止映射","enabled":true,"domain":0,"head":false,"expected":base},
		{"name":"关闭保留旧输出","enabled":false,"domain":1,"head":false,"expected":base},
		{"name":"不推测线性视口色域","enabled":true,"domain":2,"head":false,"expected":base},
	]
	for entry in cases:
		var bound := Binder.create(texture(base),zero,texture(Color(0,0,0.1,1)),false,
			{&"hair":entry.head},{&"hair":{"texture":texture(base),"rect":Rect2(0,0,1,1)}},{})
		var mat: ShaderMaterial=bound.material
		mat.set_shader_parameter("skin_palette_enabled",entry.enabled)
		mat.set_shader_parameter("skin_color_domain",entry.domain)
		mat.set_shader_parameter("skin_color_count",2)
		var src := PackedVector4Array()
		var dest := PackedVector4Array()
		for i in 16:
			src.append(Vector4(source_linear.r+0.001 if i==0 else source_linear.r,source_linear.g,source_linear.b,1))
			dest.append(Vector4(target_linear.r,target_linear.g,target_linear.b,1) if i==0 else Vector4(1,0,0,1))
		mat.set_shader_parameter("skin_src_colors",src)
		mat.set_shader_parameter("skin_dst_colors",dest)
		plane.material=mat
		await process_frame
		await RenderingServer.frame_post_draw
		var actual: Color=viewport.get_texture().get_image().get_pixel(0,0)
		var expected: Color=entry.expected
		checks+=1
		if (Vector3(actual.r,actual.g,actual.b)-Vector3(expected.r,expected.g,expected.b)).length()>0.015 or abs(actual.a-1)>0.01:
			failures+=1
			push_error("%s actual=%s expected=%s"%[entry.name,actual,expected])
	viewport.queue_free()
	await process_frame
	if failures==0: print("PASS equipment_skin_gpu: ",checks)
	quit(1 if failures else 0)
