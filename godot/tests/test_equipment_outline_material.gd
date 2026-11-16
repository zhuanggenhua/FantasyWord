extends SceneTree
const Binder = preload("res://gameplay/presentation/equipment_subset_material.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	var texture := ImageTexture.create_from_image(Image.create(32,32,false,Image.FORMAT_RGBA8))
	var m: ShaderMaterial = Binder.create(texture,texture,texture,false,{},{},{},true).material
	var body: ShaderMaterial = Binder.create(texture,texture,texture,false,{},{},{}).material
	var r := Rect2(0,0,1,1)
	var sf := [{"is_sequence":0,"hide_outline_on_body":1},{"is_sequence":0.5,"hide_outline_on_body":0}]
	check(not m.get_shader_parameter("outline_stage_enabled"),"默认关闭")
	check(not Binder.apply_outline(body,r,Vector2(32,32),0.4,sf,Vector3.ONE,Color.RED,Color.GREEN).ok,"默认十三采样变体不允许轮廓")
	check(not Binder.apply_outline(m,r,Vector2(32,32),0.4,sf,Vector3.ONE,Color.RED,Color.GREEN).ok,"未绑定帧不启用")
	check(Binder.apply_weapon_fill(m,r,[{},{}]).ok,"明确双空槽")
	check(Binder.apply_outline(m,r,Vector2(32,32),0.421875,sf,Vector3(0,1,1),Color.RED,Color.GREEN).ok,"合法源数据")
	for pair in [["outline_stage_enabled",true],["outline_frame_rect",Vector4(0,0,1,1)],["outline_frame_size",Vector2(32,32)],["outline_base_y",0.421875],["outline_default",0.0],["outline_hit",1.0],["outline_extra",1.0],["weapon0_hide_outline_on_body",1.0],["weapon1_is_sequence",0.5],["outline_hit_color",Vector4(1,0,0,1)]]:
		check(m.get_shader_parameter(pair[0]) == pair[1],"原数值绑定："+pair[0])
	check(not Binder.apply_outline(m,r,Vector2(16,32),0.4,sf,Vector3.ONE,Color.RED,Color.GREEN).ok,"作者帧范围与像素尺寸必须一致")
	check(not Binder.apply_outline(m,r,Vector2.ZERO,0.4,sf,Vector3.ONE,Color.RED,Color.GREEN).ok,"无尺寸拒绝")
	check(not m.get_shader_parameter("outline_stage_enabled"),"失败清除旧开关")
	check(m.get_shader_parameter("outline_hit_color") == Vector4.ZERO,"失败清除旧颜色")
	check(m.get_shader_parameter("weapon0_hide_outline_on_body") == 0.0,"失败清除旧隐藏")
	check(not Binder.apply_outline(m,r,Vector2(32,32),0.4,[{},{}],Vector3.ONE,Color.RED,Color.GREEN).ok,"禁止推断序列旗标")
	check(not Binder.apply_outline(m,Rect2(0,0,0.5,1),Vector2(32,32),0.4,sf,Vector3.ONE,Color.RED,Color.GREEN).ok,"不混合新帧和旧姿态")
	check(Binder.apply_outline(m,r,Vector2(32,32),0.4,sf,Vector3.ONE,Color.RED,Color.GREEN).ok,"恢复绑定")
	Binder.reset_weapon_fill(m)
	check(not m.get_shader_parameter("outline_stage_enabled"),"帧刷新同步失效轮廓")
	check(not Binder.apply_outline(m,r,Vector2(32,32),NAN,sf,Vector3.ONE,Color.RED,Color.GREEN).ok,"无效基线")
	for shader in [Binder.SUBSET,Binder.WEAPON_SUBSET]:
		var count := 0
		for item in shader.get_shader_uniform_list():
			if item.hint_string == "Texture2D": count += 1
		check(count == (13 if shader == Binder.SUBSET else 15),"无新增采样器")
	if failures == 0: print("PASS equipment_outline_material ",checks)
	quit(0 if failures == 0 else 1)
