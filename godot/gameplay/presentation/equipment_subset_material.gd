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
