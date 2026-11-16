extends RefCounted
## 本体与可选武器填充阶段显式绑定，不自动接入场景或补造缺失资源。
const SUBSET = preload("res://gameplay/presentation/equipment_character_subset.gdshader")
const WEAPON_SUBSET = preload("res://gameplay/presentation/equipment_weapon_subset.gdshader")
const LAYERS: Array[StringName] = [&"bag",&"pants",&"cloth",&"cloak",&"helmet",&"beard",&"face_accessory",&"hair",&"eye_decoration",&"mask"]
const COLORS: Array[StringName] = [&"left_hand",&"right_hand",&"left_foot",&"right_foot",&"left_eye",&"right_eye"]

static func create(main: Texture2D, body: Texture2D, head: Texture2D,
		front: bool, enabled: Dictionary, layers: Dictionary, colors: Dictionary,
		using_weapon_stage: bool = false) -> Dictionary:
	# 必须显式传入整图，不能把 AtlasTexture 的局部坐标当作整图坐标。
	for texture in [main,body,head]:
		if texture == null or texture is AtlasTexture or texture.get_width() <= 0 or texture.get_height() <= 0:
			return {"ok":false,"reason":"角色底图与两张 UV 数据图必须是有效整图"}
	if main.get_size() != body.get_size() or main.get_size() != head.get_size():
		return {"ok":false,"reason":"角色底图与 UV 数据图尺寸不一致"}
	for key in LAYERS:
		if not enabled.get(key,false): continue
		var entry = layers.get(key,{})
		if not entry is Dictionary:
			return {"ok":false,"reason":"装备层配置不是字典："+str(key)}
		var texture = entry.get("texture")
		var rect = entry.get("rect")
		if not texture is Texture2D or texture is AtlasTexture or not rect is Rect2:
			return {"ok":false,"reason":"启用的装备层缺少整图或作者 UV 范围："+str(key)}
		if texture.get_width() <= 0 or texture.get_height() <= 0 or not rect.position.is_finite() or not rect.size.is_finite() or rect.size.x <= 0.0 or rect.size.y <= 0.0:
			return {"ok":false,"reason":"启用的装备层缺少整图或作者 UV 范围："+str(key)}
		if rect.position.x < 0.0 or rect.position.y < 0.0 or rect.end.x > 1.0 or rect.end.y > 1.0:
			return {"ok":false,"reason":"装备作者 UV 范围超出整图："+str(key)}
	for key in COLORS:
		var gate: StringName = &"gloves" if key in [&"left_hand",&"right_hand"] else &"shoes" if key in [&"left_foot",&"right_foot"] else key
		if enabled.get(gate,false) and not colors.get(key) is Color:
			return {"ok":false,"reason":"启用的颜色层缺少作者颜色："+str(key)}
	var material := ShaderMaterial.new()
	material.shader = WEAPON_SUBSET if using_weapon_stage else SUBSET
	_reset_skin_palette(material)
	reset_weapon_fill(material)
	material.set_shader_parameter("main_map",main)
	material.set_shader_parameter("body_map",body)
	material.set_shader_parameter("head_map",head)
	material.set_shader_parameter("body_in_front",front)
	for key in LAYERS:
		material.set_shader_parameter("enabled_"+str(key),bool(enabled.get(key,false)))
		if not enabled.get(key,false): continue
		var entry: Dictionary = layers[key]
		var rect: Rect2 = entry.rect
		material.set_shader_parameter(str(key)+"_map",entry.texture)
		# 原 Unity rect 是左下原点的 min/max；不把 size 直接写到 zw。
		material.set_shader_parameter(str(key)+"_rect",Vector4(rect.position.x,rect.position.y,rect.end.x,rect.end.y))
	for key in [&"gloves",&"shoes",&"left_eye",&"right_eye"]:
		material.set_shader_parameter("enabled_"+str(key),bool(enabled.get(key,false)))
	for key in COLORS:
		if colors.get(key) is Color: material.set_shader_parameter(str(key)+"_color",colors[key])
	return {"ok":true,"material":material}

## 仅在调用方已确认贴图输入/输出域为当前非 HDR Compatibility 约定时启用。
## 此处不检测或替换渲染器，也不推断 Unity 装备或作者颜色。
const Palette = preload("res://gameplay/presentation/equipment_skin_palette.gd")
const SKIN_DOMAIN_UNKNOWN := 0
const SKIN_DOMAIN_RAW_SRGB := 1

static func apply_skin_palette(material: ShaderMaterial, source: Variant, target: Variant,
		color_domain: int = SKIN_DOMAIN_UNKNOWN) -> Dictionary:
	if material == null or material.shader not in [SUBSET,WEAPON_SUBSET]:
		return {"ok":false,"enabled":false,"reason":"材质未使用本体合成着色器"}
	# 沿用原 Refresh 的 fail-closed reset；未确认颜色域时绝不染色。
	_reset_skin_palette(material)
	var binding := Palette.bind_palette(source,target,true)
	if not binding.ok or not binding.enabled:
		return binding
	if color_domain != SKIN_DOMAIN_RAW_SRGB:
		return {"ok":false,"enabled":false,"reason":"主贴图采样与本体输出颜色域未确认"}
	material.set_shader_parameter("skin_src_colors",_color_vectors(binding.source))
	material.set_shader_parameter("skin_dst_colors",_color_vectors(binding.target))
	material.set_shader_parameter("skin_color_domain",color_domain)
	material.set_shader_parameter("skin_color_count",binding.count)
	material.set_shader_parameter("skin_palette_enabled",true)
	return binding

static func _reset_skin_palette(material: ShaderMaterial) -> void:
	material.set_shader_parameter("skin_palette_enabled",false)
	material.set_shader_parameter("skin_color_count",0)
	material.set_shader_parameter("skin_color_domain",SKIN_DOMAIN_UNKNOWN)

static func _color_vectors(colors: PackedColorArray) -> PackedVector4Array:
	var values := PackedVector4Array()
	for color in colors:
		values.append(Vector4(color.r,color.g,color.b,color.a))
	return values

## 绑定本体合成后的双武器填充。rect/frame_rect 都是底原点归一化 Rect2。
## 槽来自原姿态与精灵数据；本层不选择方向、不推进序列、不推断装备。
static func apply_weapon_fill(material: ShaderMaterial, frame_rect: Rect2,
		slots: Array) -> Dictionary:
	if material == null or material.shader != WEAPON_SUBSET:
		return {"ok":false,"reason":"必须显式创建武器填充变体，默认本体不增加 sampler"}
	# 失败也清除前次显示，不能把旧武器带到新的角色帧。
	reset_weapon_fill(material)
	if not _weapon_rect_valid(frame_rect) or frame_rect.size.x <= 0.0001 or frame_rect.size.y <= 0.0001:
		return {"ok":false,"reason":"缺少有效角色帧整图范围"}
	if slots.size() != 2:
		return {"ok":false,"reason":"必须显式提供主副手两个槽，空槽使用空字典"}
	for i in range(2):
		var entry = slots[i]
		if not entry is Dictionary:
			return {"ok":false,"reason":"武器槽不是字典"}
		if entry.is_empty(): continue
		if not entry.get("enabled") is bool:
			return {"ok":false,"reason":"武器槽缺少启用状态"}
		if not entry.enabled: continue
		var texture = entry.get("texture")
		var rect = entry.get("rect")
		if not texture is Texture2D or texture is AtlasTexture or texture.get_width() <= 0 or texture.get_height() <= 0:
			return {"ok":false,"reason":"武器槽缺少有效整图"}
		if not rect is Rect2 or not _weapon_rect_valid(rect):
			return {"ok":false,"reason":"武器槽缺少作者精灵整图范围"}
		for field in ["anchor_frame_uv","hand_local_uv","rot_cos_sin"]:
			if not entry.get(field) is Vector2 or not entry[field].is_finite():
				return {"ok":false,"reason":"武器槽缺少有限姿态："+field}
		if not entry.get("flip_x") is bool:
			return {"ok":false,"reason":"武器槽缺少镜像配置"}
		for field in ["depth_mode","hand_in_front"]:
			var value = entry.get(field)
			if not (value is float or value is int) or not is_finite(float(value)):
				return {"ok":false,"reason":"武器槽缺少有限深度或手部配置："+field}
	material.set_shader_parameter("char_frame_rect",_weapon_rect_vector(frame_rect))
	for i in range(2):
		var entry: Dictionary = slots[i]
		if not entry.get("enabled",false): continue
		var prefix := "weapon"+str(i)+"_"
		var anchor: Vector2 = entry.anchor_frame_uv
		var hand: Vector2 = entry.hand_local_uv
		material.set_shader_parameter(prefix+"map",entry.texture)
		material.set_shader_parameter(prefix+"rect",_weapon_rect_vector(entry.rect))
		material.set_shader_parameter(prefix+"anchor_frame_uv",Vector4(anchor.x,anchor.y,hand.x,hand.y))
		material.set_shader_parameter(prefix+"rot_cos_sin",entry.rot_cos_sin)
		material.set_shader_parameter(prefix+"flip_x",entry.flip_x)
		for field in ["depth_mode","hand_in_front"]:
			material.set_shader_parameter(prefix+field,float(entry[field]))
		material.set_shader_parameter(prefix+"enabled",true)
	material.set_shader_parameter("weapon_fill_enabled",true)
	return {"ok":true}

static func reset_weapon_fill(material: ShaderMaterial) -> void:
	if material == null or material.shader != WEAPON_SUBSET: return
	material.set_shader_parameter("weapon_fill_enabled",false)
	for i in range(2):
		var prefix := "weapon"+str(i)+"_"
		material.set_shader_parameter(prefix+"enabled",false)
		material.set_shader_parameter(prefix+"map",null)

static func _weapon_rect_valid(rect: Rect2) -> bool:
	return (
		rect.position.is_finite() and rect.size.is_finite() and rect.end.is_finite()
		and rect.size.x > 0.0 and rect.size.y > 0.0
		and rect.position.x >= 0.0 and rect.position.y >= 0.0
		and rect.end.x <= 1.0 and rect.end.y <= 1.0
	)

static func _weapon_rect_vector(rect: Rect2) -> Vector4:
	return Vector4(rect.position.x,rect.position.y,rect.end.x,rect.end.y)
