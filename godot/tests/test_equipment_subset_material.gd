extends SceneTree
const Binder = preload("res://gameplay/presentation/equipment_subset_material.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func tex(size: int) -> ImageTexture:
	var image := Image.create(size,size,false,Image.FORMAT_RGBA8)
	image.fill(Color(0.2,0.4,0.1,0))
	return ImageTexture.create_from_image(image)
func _initialize() -> void:
	var t := tex(4)
	check(not Binder.create(null,t,t,false,{},{},{}).ok,"缺少底图明确失败")
	check(not Binder.create(t,tex(2),t,false,{},{},{}).ok,"拒绝不同整图尺寸")
	var atlas := AtlasTexture.new()
	atlas.atlas=t
	atlas.region=Rect2(0,0,2,2)
	check(not Binder.create(atlas,t,t,false,{},{},{}).ok,"拒绝局部坐标贴图")
	check(not Binder.create(t,t,t,false,{&"hair":true},{},{}).ok,"启用头发缺引用失败")
	check(not Binder.create(t,t,t,false,{&"gloves":true},{},{}).ok,"启用颜色缺作者颜色失败")
	var r := Binder.create(t,t,t,true,{&"hair":true},{&"hair":{"texture":t,"rect":Rect2(0.2,0.3,0.4,0.5)}},{})
	check(r.ok,"有效显式整图与区域")
	if r.ok:
		var mat: ShaderMaterial=r.material
		check(mat.get_shader_parameter("hair_rect").is_equal_approx(Vector4(0.2,0.3,0.6,0.8)),"绑定 min/max 而不是 size")
		check(mat.get_shader_parameter("body_in_front")==true,"绑定独立身体深度")
		check(mat.get_shader_parameter("head_map")==t,"保持透明 RGB 数据图引用")
		var other := Binder.create(t,t,t,false,{},{},{})
		check(other.ok and other.material != mat,"每次返回独立材质而非共享可变状态")
		check(not other.material.get_shader_parameter("enabled_hair"),"第二角色不遗留第一角色外观")
	check(not Binder.create(t,t,t,false,{&"hair":true},{&"hair":{"texture":t,"rect":Rect2(0.9,0.1,0.2,0.3)}},{}).ok,"超界区域拒绝")
	check(not Binder.create(t,t,t,false,{&"hair":true},{&"hair":7},{}).ok,"拒绝非字典槽配置")
	check(not Binder.create(t,t,t,false,{&"hair":true},{&"hair":{"texture":7,"rect":Rect2(0,0,1,1)}},{}).ok,"拒绝错误纹理类型")
	check(not Binder.create(t,t,t,false,{&"hair":true},{&"hair":{"texture":t,"rect":Rect2(NAN,0,1,1)}},{}).ok,"拒绝非有限区域")
	check(not Binder.create(t,t,t,false,{&"hair":true},{&"hair":{"texture":t,"rect":Rect2(1,1,-1,-1)}},{}).ok,"拒绝负区域")
	if failures==0: print("PASS equipment_subset_material: ",checks)
	quit(1 if failures else 0)
