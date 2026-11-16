extends RefCounted
## 原面部装饰绑定合同。sprite 记录必须由真实作者源提供，不能按名称猜测。
## rect_pixels_bottom 是 Unity Sprite.rect 的底原点像素矩形；纹理必须为整图。
const Appearance = preload("res://gameplay/presentation/equipment_base_appearance.gd")

static func resolve(row_index: int, frame: Dictionary, appearance: Variant) -> Dictionary:
	var regions: Dictionary = frame.get("body_regions", {})
	var facing: int = regions.get("head", {}).get("sprite_facing", row_index)
	var result := {"enabled":false, "head_facing":facing, "sprite":null, "texture":null, "rect_bottom":null}
	if appearance == null:
		return result
	var sprites: Dictionary = appearance.get("face_accessory", {})
	# 原注释声称只朝南、不回退，但实际 GetFaceAccessorySprite 调用通用四向回退。
	# 依据实际执行代码迁移，不能把注释中的规则当作新增行为。
	var sprite: Variant = Appearance.directional_sprite(facing, sprites)
	if sprite == null or sprite.get("texture") == null:
		return result
	var texture: Texture2D = sprite.texture
	if not sprite.has("rect_pixels_bottom"):
		result["error"] = "缺少原 Sprite.rect，不能猜测整图矩形"
		return result
	var rect: Rect2 = sprite.rect_pixels_bottom
	var size := Vector2(texture.get_width(), texture.get_height())
	if size.x <= 0 or size.y <= 0:
		result["error"] = "整图纹理尺寸无效"
		return result
	result.enabled = true
	result.sprite = sprite
	result.texture = texture
	result.rect_bottom = Rect2(rect.position / size, rect.size / size)
	return result
