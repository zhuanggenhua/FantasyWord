extends SceneTree
const Binder = preload("res://gameplay/presentation/equipment_subset_material.gd")
const EPS := 0.000001
var count := 0
var failed := 0

func check(condition: bool, label: String) -> void:
	count += 1
	if condition: return
	failed += 1
	printerr("FAIL: ",label)

func _initialize() -> void:
	var map := ImageTexture.create_from_image(Image.create(4,4,false,Image.FORMAT_RGBA8))
	var record := Binder.create(map,map,map,false,{},{},{})
	check(record.ok,"可建立验证材质")
	if not record.ok: quit(1); return
	var material: ShaderMaterial = record.material
	var original := PackedColorArray([Color(0.73,0.51,0.38,0.83), Color(0.91,0.63,0.40)])
	var target := PackedColorArray([Color(0.23,0.65,0.31,0.76)])
	var result := Binder.apply_skin_palette(material,original,target)
	check(not result.ok and not result.enabled and material.get_shader_parameter("skin_color_count")==0,"来源颜色域须显式声明")
	result = Binder.apply_skin_palette(material,original,target,Binder.SKIN_DOMAIN_RAW_SRGB)
	check(result.ok and result.enabled and material.get_shader_parameter("skin_palette_enabled"),"现有非HDR颜色域已绑定")
	check(material.get_shader_parameter("skin_color_count")==1 and material.get_shader_parameter("skin_color_domain")==1,"短表长度与域传入")
	var src: PackedVector4Array = material.get_shader_parameter("skin_src_colors")
	var dst: PackedVector4Array = material.get_shader_parameter("skin_dst_colors")
	var l := original[0].srgb_to_linear()
	var t := target[0].srgb_to_linear()
	check(src.size()==16 and dst.size()==16,"GPU 固定长度向量数组")
	if src.size()==16 and dst.size()==16:
		check(src[0].distance_to(Vector4(l.r,l.g,l.b,l.a))<EPS and dst[0].distance_to(Vector4(t.r,t.g,t.b,t.a))<EPS,
			"对两表非线性中值仅转换一次，不改透明通道")
	result = Binder.apply_skin_palette(material,PackedColorArray(),PackedColorArray(),Binder.SKIN_DOMAIN_RAW_SRGB)
	check(result.ok and not result.enabled and not material.get_shader_parameter("skin_palette_enabled")
		and material.get_shader_parameter("skin_color_count")==0,"同实例由有到空清除启用和计数")
	check(not Binder.apply_skin_palette(ShaderMaterial.new(),original,target,1).ok,"不篡改其他材质")
	if failed==0: print("PASS equipment_skin_material_link: ",count)
	quit(1 if failed else 0)
