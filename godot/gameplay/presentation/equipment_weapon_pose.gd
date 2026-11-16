extends RefCounted
## 31629d5 RenderWeaponSlot 的绑定分支。纹理、帧选择和非法素材判定由明确的调用方提供。
## 返回 write_slot=false 表示原函数直接返回；调用方必须先执行 Refresh 的清槽，不能保留旧帧。
const Appearance = preload("res://gameplay/presentation/equipment_base_appearance.gd")
const ANGLES := [0.0, -45.0, -90.0, -135.0, 180.0, 135.0, 90.0, 45.0]

static func resolve(torso_facing: int, main_hand: bool, frame_size: Vector2,
		anchor: Variant, equipment: Dictionary, sequence_configured: bool,
		sequence_sample: Dictionary = {}) -> Dictionary:
	var result := {"enabled":false, "write_slot":false, "disable_generated_renderer":false}
	if equipment.is_empty():
		return result
	var sprite: Variant = null
	var front := static_slot_in_front(torso_facing, main_hand)
	if sequence_configured:
		sprite = sequence_sample.get("sprite")
		if not valid_texture(sprite) or sprite.get("invalid_layer", false):
			return clear_slot()
		front = not sequence_sample.get("depth_back", false)
	else:
		sprite = Appearance.directional_sprite(torso_facing, equipment.get("sprites", {}))
		if not valid_texture(sprite):
			return result
		if sprite.get("ui_icon", false) or sprite.get("whole_character_action", false):
			return result
	var west := torso_facing == 1 or torso_facing == 3
	# 源规则检查 SW 是否配置，而不是本次所选 NW 是否存在。
	var flip := not sequence_configured and west and equipment.get("sprites", {}).get("sw") == null
	var size := Vector2(maxf(frame_size.x, 1.0), maxf(frame_size.y, 1.0))
	var pixel: Vector2
	if anchor != null:
		pixel = Vector2(anchor.position) + Vector2(0.5, 0.5)
	elif sequence_configured:
		pixel = size * 0.5
	else:
		return clear_slot()
	var angle := 0.0
	if not sequence_configured:
		var direction: int = anchor.get("direction", 0)
		angle = ANGLES[direction] if direction >= 0 and direction < ANGLES.size() else 0.0
		if flip:
			angle = -angle
	var radians := deg_to_rad(angle)
	var weapon_size: Vector2 = sprite.rect.size
	# 注释曾描述东西不同偏移；以源配置表实际四行 (-0.5,-0.5) 为准。
	return {
		"enabled":true, "write_slot":true, "disable_generated_renderer":true,
		"sprite":sprite,
		"anchor_frame_uv":Vector2(pixel.x / size.x, 1.0 - pixel.y / size.y),
		"hand_local_uv":Vector2(0.5 - 0.5 / maxf(weapon_size.x, 1.0),
			0.5 - 0.5 / maxf(weapon_size.y, 1.0)),
		"rot_cos_sin":Vector2(cos(radians), sin(radians)),
		"flip_x":flip, "slot_is_front":front,
		"hand_in_front":not equipment.get("is_shield", false) or (torso_facing != 0 and torso_facing != 1),
		"is_sequence":sequence_configured,
		"hide_outline_on_body":equipment.get("hide_outline_on_body", false),
	}

static func static_slot_in_front(facing: int, main_hand: bool) -> bool:
	var main_on_left := facing == 0 or facing == 3
	var is_left := main_hand == main_on_left
	var left_delta := 1 if facing == 1 or facing == 3 else -1
	return (left_delta if is_left else -left_delta) > 0

static func valid_texture(sprite: Variant) -> bool:
	return sprite != null and sprite.get("texture") != null

static func clear_slot() -> Dictionary:
	return {"enabled":false, "write_slot":true, "disable_generated_renderer":true}
