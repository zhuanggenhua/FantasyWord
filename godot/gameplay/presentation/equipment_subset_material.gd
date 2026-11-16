extends RefCounted
## 本体合成阶段显式绑定，不自动接入场景或补造缺失资源。
const SUBSET = preload("res://gameplay/presentation/equipment_character_subset.gdshader")
const LAYERS: Array[StringName] = [&"bag",&"pants",&"cloth",&"cloak",&"helmet",&"beard",&"face_accessory",&"hair",&"eye_decoration",&"mask"]
const COLORS: Array[StringName] = [&"left_hand",&"right_hand",&"left_foot",&"right_foot",&"left_eye",&"right_eye"]

static func create(main: Texture2D, body: Texture2D, head: Texture2D,
		front: bool, enabled: Dictionary, layers: Dictionary, colors: Dictionary) -> Dictionary:
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
	material.shader = SUBSET
	_reset_skin_palette(material)
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
	if material == null or material.shader != SUBSET:
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
