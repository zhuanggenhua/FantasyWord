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
	var unknown := ShaderMaterial.new()
	unknown.shader = Shader.new()
	unknown.shader.code = "shader_type canvas_item;"
	check(not Binder.apply_final_tint(null,Color.WHITE,1).ok,"缺材质拒绝")
	check(not Binder.apply_final_tint(unknown,Color.WHITE,1).ok,"未知材质拒绝")
	Binder.reset_final_tint(null)
	Binder.reset_final_tint(unknown)
	for weapon in [false,true]:
		var m: ShaderMaterial = Binder.create(texture,texture,texture,false,{},{},{},weapon).material
		check(not m.get_shader_parameter("final_tint_enabled"),"默认关闭，不改旧路径")
		check(m.get_shader_parameter("final_material_tint")==Vector4.ONE,"默认白色")
		var count := 0
		for uniform in m.shader.get_shader_uniform_list():
			if uniform.hint_string == "Texture2D": count += 1
		check(count==(15 if weapon else 13),"采样器数量不变")
		for tint in [Color(0.3,0.6,0.9,0.4),Color(1,1,1,0),Color(1.25,-0.2,0.5,0.8)]:
			check(Binder.apply_final_tint(m,tint,1).ok,"明确颜色域允许有限数值")
			check(m.get_shader_parameter("final_tint_enabled"),"显式启用")
			check(m.get_shader_parameter("final_material_tint")==Vector4(tint.r,tint.g,tint.b,tint.a),"RGBA 不裁切、不变色域")
		for domain in [0,2,-1]:
			check(not Binder.apply_final_tint(m,Color.WHITE,domain).ok,"未知或未支持颜色域拒绝")
			check(not m.get_shader_parameter("final_tint_enabled"),"失败关闭旧乘色")
			check(m.get_shader_parameter("final_material_tint")==Vector4.ONE,"失败清空旧 tint")
		for tint in [Color(NAN,1,1,1),Color(1,INF,1,1),Color(1,1,-INF,1),Color(1,1,1,NAN)]:
			check(not Binder.apply_final_tint(m,tint,1).ok,"RGBA 任一非有限拒绝")
		check(Binder.apply_final_tint(m,Color(0.5,0.25,0.75,0.5),1).ok,"恢复合法乘色")
		Binder.reset_weapon_fill(m)
		Binder.reset_outline(m)
		Binder.reset_shadow(m)
		check(m.get_shader_parameter("final_tint_enabled"),"逐帧阶段刷新不重置材质独立 tint")
		Binder.reset_final_tint(m)
		check(not m.get_shader_parameter("final_tint_enabled"),"显式关闭")
		check(m.get_shader_parameter("final_material_tint")==Vector4.ONE,"关闭恢复白色")
	var source := FileAccess.get_file_as_string("res://gameplay/presentation/equipment_character_shared.gdshaderinc")
	check(source.contains("final_vertex_color = COLOR;"),"vertex 捕获纹理之前的颜色")
	check(source.contains("value *= final_vertex_color * final_material_tint;"),"最终 RGBA 乘顶点与材质色")
	check(source.rfind("apply_procedural_shadow(UV,value);") < source.rfind("value *= final_vertex_color"),"必须在阴影之后")
	check(source.rfind("value *= final_vertex_color") < source.rfind("COLOR = value;"),"最后才输出")
	if failures==0: print("PASS equipment_final_tint ",checks," checks")
	quit(0 if failures==0 else 1)
