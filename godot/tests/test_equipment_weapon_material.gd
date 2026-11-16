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
	var image := Image.create(8,8,false,Image.FORMAT_RGBA8)
	var texture := ImageTexture.create_from_image(image)
	var material: ShaderMaterial = Binder.create(texture,texture,texture,false,{},{},{},true).material
	check(not material.get_shader_parameter("weapon_fill_enabled"),"变体也默认不启用后续填充")
	var original: ShaderMaterial = Binder.create(texture,texture,texture,false,{},{},{}).material
	check(original.shader == Binder.SUBSET,"旧调用保持原 shader")
	check(not Binder.apply_weapon_fill(original,Rect2(0,0,1,1),[{},{}]).ok,"旧材质不能偷偷变武器路径")
	var default_samplers := 0
	var weapon_samplers := 0
	for item in Binder.SUBSET.get_shader_uniform_list():
		if item.hint_string == "Texture2D": default_samplers += 1
	for item in Binder.WEAPON_SUBSET.get_shader_uniform_list():
		if item.hint_string == "Texture2D": weapon_samplers += 1
	check(default_samplers == 13,"默认变体保持十三个 sampler")
	check(weapon_samplers == 15,"武器变体单独增加双槽")
	var frame := Rect2(0.25,0.5,0.25,0.5)
	var slot := {"enabled":true,"texture":texture,"rect":Rect2(0.1,0.2,0.3,0.4),
		"anchor_frame_uv":Vector2(0.3,0.7),"hand_local_uv":Vector2(0.2,0.8),
		"rot_cos_sin":Vector2(0,-1),"flip_x":true,"depth_mode":0.5,"hand_in_front":0.7}
	check(Binder.apply_weapon_fill(material,frame,[slot,{}]).ok,"有效单槽")
	check(material.get_shader_parameter("weapon_fill_enabled"),"填充显式启用")
	check(material.get_shader_parameter("weapon0_enabled") and not material.get_shader_parameter("weapon1_enabled"),"主副手独立")
	check(material.get_shader_parameter("weapon0_map")==texture,"保留整图身份")
	check(material.get_shader_parameter("char_frame_rect")==Vector4(0.25,0.5,0.5,1),"帧范围 size 转 min/max")
	check(material.get_shader_parameter("weapon0_rect").is_equal_approx(Vector4(0.1,0.2,0.4,0.6)),"精灵范围 size 转 min/max")
	check(material.get_shader_parameter("weapon0_anchor_frame_uv").is_equal_approx(Vector4(0.3,0.7,0.2,0.8)),"角色与武器锚点不交换")
	check(material.get_shader_parameter("weapon0_rot_cos_sin")==Vector2(0,-1),"不重算旋转")
	check(material.get_shader_parameter("weapon0_flip_x"),"不重算镜像")
	check(material.get_shader_parameter("weapon0_depth_mode")==0.5,"保留恰半深度")
	check(is_equal_approx(material.get_shader_parameter("weapon0_hand_in_front"),0.7),"保留原手部阈值")
	check(Binder.apply_weapon_fill(material,frame,[{},slot]).ok,"换到副手")
	check(not material.get_shader_parameter("weapon0_enabled") and material.get_shader_parameter("weapon1_enabled"),"换槽清旧启用")
	check(material.get_shader_parameter("weapon0_map")==null,"换槽释放旧纹理引用")
	var malformed: Array = [[],[{},{} ,{}],[7,{}],[{"enabled":1},{}]]
	for slots in malformed:
		check(not Binder.apply_weapon_fill(material,frame,slots).ok,"拒绝无依据槽结构")
		check(not material.get_shader_parameter("weapon_fill_enabled"),"无效槽不能保留旧帧")
	for field in ["texture","rect","anchor_frame_uv","hand_local_uv","rot_cos_sin","flip_x","depth_mode","hand_in_front"]:
		var bad: Dictionary = slot.duplicate()
		bad.erase(field)
		check(not Binder.apply_weapon_fill(material,frame,[slot,bad]).ok,"拒绝缺失："+field)
		check(not material.get_shader_parameter("weapon0_enabled"),"双槽原子失败："+field)
	for field in ["anchor_frame_uv","hand_local_uv","rot_cos_sin"]:
		var bad := slot.duplicate()
		bad[field]=Vector2(NAN,0)
		check(not Binder.apply_weapon_fill(material,frame,[bad,{}]).ok,"拒绝非有限姿态")
	for field in ["depth_mode","hand_in_front"]:
		var bad := slot.duplicate()
		bad[field]=NAN
		check(not Binder.apply_weapon_fill(material,frame,[bad,{}]).ok,"拒绝非有限层级")
	for bad in [Rect2(0,0,0,1),Rect2(0,0,0.0001,1),Rect2(0,0,NAN,1),Rect2(0,0,2,1)]:
		check(not Binder.apply_weapon_fill(material,bad,[slot,{}]).ok,"拒绝错误帧范围")
	var atlas := AtlasTexture.new()
	atlas.atlas=texture
	atlas.region=Rect2(0,0,4,4)
	var bad := slot.duplicate()
	bad.texture=atlas
	check(not Binder.apply_weapon_fill(material,frame,[bad,{}]).ok,"拒绝局部 AtlasTexture")
	check(Binder.apply_weapon_fill(material,frame,[{},{}]).ok,"空双槽仍启用北包末次覆盖阶段")
	check(material.get_shader_parameter("weapon_fill_enabled"),"不能把无武器误当未启用此阶段")
	var integer_slot := slot.duplicate()
	integer_slot.depth_mode=1
	integer_slot.hand_in_front=0
	check(Binder.apply_weapon_fill(material,frame,[integer_slot,{}]).ok,"接受源整数零一参数")
	check(material.get_shader_parameter("weapon0_depth_mode") is float and material.get_shader_parameter("weapon0_depth_mode")==1.0,"整数深度明确转换 float")
	check(material.get_shader_parameter("weapon0_hand_in_front") is float and material.get_shader_parameter("weapon0_hand_in_front")==0.0,"整数手部门槛明确转换 float")
	Binder.reset_weapon_fill(material)
	check(not material.get_shader_parameter("weapon_fill_enabled"),"显式退回旧子集")
	check(not Binder.apply_weapon_fill(null,frame,[{},{}]).ok,"拒绝空材质")
	var foreign := ShaderMaterial.new()
	check(not Binder.apply_weapon_fill(foreign,frame,[{},{}]).ok,"拒绝外部材质")
	if failures==0: print("PASS equipment_weapon_material: ",checks)
	quit(1 if failures else 0)
