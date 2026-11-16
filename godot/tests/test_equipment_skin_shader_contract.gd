extends SceneTree
## 只检验无头环境中的着色器接口与默认状态，不作像素验收。
const ShaderCode = preload("res://gameplay/presentation/equipment_character_subset.gdshader")
func _initialize() -> void:
	var uniforms := {}
	for item in ShaderCode.get_shader_uniform_list():
		uniforms[item.name]=true
	for required in ["skin_palette_enabled","skin_color_domain","skin_color_count","skin_src_colors","skin_dst_colors"]:
		if not uniforms.has(required):
			push_error("缺少着色器参数："+required)
			quit(1)
			return
	# Dummy 渲染器不返回着色器默认值；只检查声明，不谎称真实材质像素验证。
	for declaration in ["uniform bool skin_palette_enabled = false;", "uniform int skin_color_domain = 0;", "uniform int skin_color_count = 0;"]:
		if not ShaderCode.code.contains(declaration):
			push_error("缺少默认禁用声明")
			quit(1)
			return
	print("PASS equipment_skin_shader_contract: interface and disabled defaults only")
	quit(0)
