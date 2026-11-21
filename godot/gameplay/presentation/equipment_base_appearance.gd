extends RefCounted
## 31629d5 EquipmentRenderer 的基础外观绑定决策；不采样、不生成纹理。
## 调用方先执行原 Refresh 的重置，再消费本次结果。区域键仅接受显式归一化数据。

static func resolve(row_index: int, frame: Dictionary, appearance: Variant, head_equipment: Dictionary = {}) -> Dictionary:
	var regions: Dictionary = frame.get("body_regions", {})
	var torso_facing: int = regions.get("torso", {}).get("sprite_facing", row_index)
	var head_facing: int = regions.get("head", {}).get("sprite_facing", row_index)
	# 原身体深度独立校正非法朝向；头部外观不能沿用该校正。
	if torso_facing < 0 or torso_facing > 3:
		torso_facing = 0
	var result := {
		"body_in_front": torso_facing >= 2,
		"body_in_east": torso_facing == 0 or torso_facing == 2,
		"head_facing": head_facing,
		"appearance_applied": appearance != null,
		"hair": null, "beard": null, "eye_decoration": null,
		"enable_left_eye": false, "enable_right_eye": false,
	}
	if appearance == null:
		return result
	var front := head_facing == 0 or head_facing == 1
	result.left_eye_color = appearance.left_eye_color
	result.right_eye_color = appearance.right_eye_color
	result.enable_left_eye = front and not frame.get("left_eye_closed", false)
	result.enable_right_eye = front and not frame.get("right_eye_closed", false)
	# HasHair/HasBeard 先检查 SE，不能因为其他方向有图就启用。
	for part in ["hair", "beard"]:
		var sprites: Dictionary = appearance.get(part, {})
		if sprites.get("se") != null and not head_equipment.get("hide_" + part, false):
			result[part] = directional_sprite(head_facing, sprites)
	# 眼饰不依赖单眼闭合，且没有东西方向互相回退。
	if head_facing == 0:
		result.eye_decoration = appearance.get("eye_decoration_east")
	elif head_facing == 1:
		result.eye_decoration = appearance.get("eye_decoration_west")
	return result

static func directional_sprite(facing: int, sprites: Dictionary) -> Variant:
	# DirectionalSpriteHelper：NW -> SW -> SE，NE -> SE，SW -> SE。
	match facing:
		1:
			return sprites.get("sw") if sprites.get("sw") != null else sprites.get("se")
		2:
			return sprites.get("ne") if sprites.get("ne") != null else sprites.get("se")
		3:
			if sprites.get("nw") != null:
				return sprites.nw
			return sprites.get("sw") if sprites.get("sw") != null else sprites.get("se")
		_:
			return sprites.get("se")

## 原 Refresh 的基础层材质写入；不修改衣物、武器或 UV 图。
static func apply_material_layers(material: ShaderMaterial, flags: Dictionary) -> void:
	for layer in ["hair", "beard", "eye_decoration"]:
		var entry = flags[layer]
		material.set_shader_parameter("enabled_" + layer, entry != null)
		if entry == null: continue
		material.set_shader_parameter(layer + "_map", entry.texture)
		material.set_shader_parameter(layer + "_rect", Vector4(0, 0, 1, 1))
	for side in ["left", "right"]:
		material.set_shader_parameter(side + "_eye_color", flags[side + "_eye_color"])
		material.set_shader_parameter("enabled_" + side + "_eye", flags["enable_" + side + "_eye"])
