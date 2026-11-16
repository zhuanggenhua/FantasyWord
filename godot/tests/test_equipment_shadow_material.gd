extends SceneTree
const Binder = preload("res://gameplay/presentation/equipment_subset_material.gd")
const Shadow = preload("res://gameplay/presentation/equipment_shadow_coverage.gd")
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
	var params := Shadow.height_writes([Vector2i(12,18)],[Vector2i(16,18)],18)
	var color := Color(0.1,0.2,0.3,0.4)
	check(not m.get_shader_parameter("shadow_stage_enabled"),"默认关闭")
	check(not Binder.apply_shadow(body,r,params,1.0,color).ok,"默认十三采样变体不允许阴影")
	check(not Binder.apply_shadow(null,r,params,1.0,color).ok,"无材质拒绝")
	check(not Binder.apply_shadow(m,r,params,1.0,color).ok,"未绑定帧不启用")
	check(Binder.apply_weapon_fill(m,r,[{},{}]).ok,"明确双空槽")
	check(not Binder.apply_shadow(m,r,params,1.0,color).ok,"必须明确序列旗标与共享几何")
	check(Binder.apply_outline(m,r,params.frame_size,params.base_y,sf,Vector3.ZERO,Color.RED,Color.GREEN).ok,"轮廓关闭但明确同帧输入")
	check(Binder.apply_shadow(m,r,params,1.0,color).ok,"合法源数据")
	for pair in [["shadow_stage_enabled",true],["shadow_enabled",1.0],["shadow_mode",0.0],["shadow_left_x",0.0],["shadow_right_x",0.0],["shadow_center_x",0.0],["shadow_color",Vector4(color.r,color.g,color.b,color.a)],["outline_default",0.0],["weapon0_hide_outline_on_body",1.0],["weapon1_is_sequence",0.5]]:
		check(m.get_shader_parameter(pair[0]) == pair[1],"原数值绑定："+pair[0])
	for height in [17,15,8]:
		var next := Shadow.height_writes([Vector2i(12,height)],[Vector2i(16,height)],18)
		check(Binder.apply_shadow(m,r,next,1.0,color).ok,"四模式绑定")
		check(m.get_shader_parameter("shadow_mode") == next.mode,"模式不归一")
		check(m.get_shader_parameter("shadow_center_x") == next.center_x,"中心不加半格")
		check(m.get_shader_parameter("shadow_left_x") == next.left_x,"左界不修正")
		check(m.get_shader_parameter("shadow_right_x") == next.right_x,"右界不修正")
	var retained := Shadow.apply_writes(params,Shadow.height_writes([],[],18))
	check(Binder.apply_shadow(m,r,retained,1.0,color).ok,"空脚完整旧字段允许")
	check(m.get_shader_parameter("shadow_mode") == -1.0,"负模式保留而非禁用")
	check(not Binder.apply_shadow(m,r,{"mode":-1.0},1.0,color).ok,"不猜首次空脚未知历史")
	check(not m.get_shader_parameter("shadow_stage_enabled"),"失败关闭旧阴影")
	check(m.get_shader_parameter("shadow_color") == Vector4.ZERO,"失败不留旧色")
	for key in ["mode","base_y","left_x","right_x","center_x","frame_size"]:
		var invalid := params.duplicate()
		invalid.erase(key)
		check(not Binder.apply_shadow(m,r,invalid,1.0,color).ok,"完整状态不能缺字段："+key)
	for key in ["mode","base_y","left_x","right_x","center_x"]:
		var invalid := params.duplicate()
		invalid[key] = NAN
		check(not Binder.apply_shadow(m,r,invalid,1.0,color).ok,"拒绝非有限状态："+key)
	for size in [Vector2.ZERO,Vector2(-1,32),Vector2(INF,32),Vector2(64,32)]:
		var invalid := params.duplicate()
		invalid.frame_size = size
		check(not Binder.apply_shadow(m,r,invalid,1.0,color).ok,"拒绝无效或不共享尺寸")
	var other_base := params.duplicate()
	other_base.base_y += 0.03125
	check(not Binder.apply_shadow(m,r,other_base,1.0,color).ok,"不同基线拒绝")
	check(not Binder.apply_shadow(m,Rect2(0,0,0.5,1),params,1.0,color).ok,"不混帧")
	check(not Binder.apply_shadow(m,r,params,NAN,color).ok,"有限开关")
	check(not Binder.apply_shadow(m,r,params,1.0,Color(INF,0,0,1)).ok,"有限颜色")
	check(Binder.apply_shadow(m,r,params,0.5,Color(0.2,0.3,0.4,0.0)).ok,"半阈值与零 alpha 仍原值绑定")
	check(m.get_shader_parameter("shadow_enabled") == 0.5,"开关不布尔化")
	check(m.get_shader_parameter("shadow_color") == Vector4(0.2,0.3,0.4,0.0),"颜色全量保留")
	Binder.reset_outline(m)
	check(not m.get_shader_parameter("shadow_stage_enabled"),"轮廓刷新使阴影失效")
	check(Binder.apply_outline(m,r,params.frame_size,params.base_y,sf,Vector3.ZERO,Color.RED,Color.GREEN).ok,"重绑同帧")
	check(Binder.apply_shadow(m,r,params,1.0,color).ok,"恢复绑定")
	Binder.reset_weapon_fill(m)
	check(not m.get_shader_parameter("shadow_stage_enabled"),"填充刷新使阴影失效")
	for shader in [Binder.SUBSET,Binder.WEAPON_SUBSET]:
		var count := 0
		for item in shader.get_shader_uniform_list():
			if item.hint_string == "Texture2D": count += 1
		check(count == (13 if shader == Binder.SUBSET else 15),"无新增采样器")
	if failures == 0: print("PASS equipment_shadow_material ",checks)
	quit(0 if failures == 0 else 1)
