extends RefCounted
## 锁定 31629d5 的 TrySampleWeaponGeneric。输入主图 UV 为 Godot 顶原点；
## 其余作者参数保留 Unity 底原点。这里不自定武器位、方向、锚点或颜色域。
const Sampler = preload("res://game_core/presentation/equipment_uv_sampler.gd")

static func sample_uv(sheet_uv_top: Vector2, frame_bottom: Rect2, weapon_bottom: Rect2,
		anchor_frame_bottom: Vector2, local_pivot_bottom: Vector2, cos_sin: Vector2,
		flip_x: bool, enabled: bool) -> Variant:
	if not enabled or not sheet_uv_top.is_finite() or not anchor_frame_bottom.is_finite() 			or not local_pivot_bottom.is_finite() or not cos_sin.is_finite():
		return null
	if not _valid_rect(frame_bottom) or not _valid_rect(weapon_bottom) 			or frame_bottom.size.x <= 0.0001 or frame_bottom.size.y <= 0.0001:
		return null
	var sheet_bottom := Vector2(sheet_uv_top.x, 1.0 - sheet_uv_top.y)
	var frame_uv := (sheet_bottom - frame_bottom.position) / frame_bottom.size
	if not _inside_unit(frame_uv):
		return null
	var offset := frame_uv - anchor_frame_bottom
	var rotated := Vector2(offset.x * cos_sin.x - offset.y * cos_sin.y,
			offset.x * cos_sin.y + offset.y * cos_sin.x)
	if flip_x: rotated.x = -rotated.x
	var local_weapon := local_pivot_bottom + rotated
	if not _inside_unit(local_weapon):
		return null
	return Sampler.equipment_uv(local_weapon, weapon_bottom)

static func sample_pixel(image: Image, uv_top: Variant) -> Variant:
	if image == null or image.is_empty() or not uv_top is Vector2 or not uv_top.is_finite():
		return null
	var sampled := Sampler.sample_point(image,uv_top)
	# 此阶段不是二值 alpha 输出：严格命中后保留完整原 alpha 给合成。
	return sampled if sampled.a > 0.5 else null

static func _inside_unit(uv: Vector2) -> bool:
	return uv.x >= 0.0 and uv.x <= 1.0 and uv.y >= 0.0 and uv.y <= 1.0

static func _valid_rect(rect: Rect2) -> bool:
	return rect.position.is_finite() and rect.size.is_finite() and rect.end.is_finite() 		and rect.size.x > 0.0 and rect.size.y > 0.0
