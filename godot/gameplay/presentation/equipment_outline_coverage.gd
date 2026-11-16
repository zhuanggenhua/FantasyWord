extends RefCounted
## Unity 31629d5 EquipmentUV.shader 的轮廓判据；独立于填色，不是渲染器接入。
## 帧局部与矩形是底原点，采样器整图坐标是顶原点。武器采样器保留自身帧界限。
const BODY_KEYS := [&"pants", &"cloth", &"cloak"]
const HEAD_KEYS := [&"helmet", &"hair", &"beard", &"face_accessory", &"mask"]
const CUTOFF := 0.5

static func coverage(frame_uv_bottom: Vector2, frame_rect_bottom: Rect2,
		sample_sheet: Callable, enabled: Dictionary, sample_equip: Callable,
		weapons: Array, sample_weapon: Callable) -> Dictionary:
	assert(weapons.size() == 2, "轮廓判据需要两个明确的武器槽")
	# 不夹到当前帧：相邻帧的非零像素也会进入本体和背包轮廓。
	var sheet_bottom := frame_rect_bottom.position + frame_rect_bottom.size * frame_uv_bottom
	var sheet_top := Vector2(sheet_bottom.x, 1.0 - sheet_bottom.y)
	var sheet: Dictionary = sample_sheet.call(sheet_top)
	var body: Color = sheet.body
	var head: Color = sheet.head
	var base: Color = sheet.main
	var body_alpha := base.a
	for key in BODY_KEYS:
		if float(enabled.get(key, 0.0)) > CUTOFF:
			var texel: Color = sample_equip.call(key, Vector2(body.r, body.g))
			if texel.a > CUTOFF:
				body_alpha = maxf(body_alpha, 1.0)
	for key in HEAD_KEYS:
		if float(enabled.get(key, 0.0)) > CUTOFF:
			var texel: Color = sample_equip.call(key, Vector2(head.r, head.g))
			if texel.a > CUTOFF:
				body_alpha = maxf(body_alpha, 1.0)
	var bag_alpha := 0.0
	# 原函数在 <0.5 时退出，因此恰好 0.5 仍采样；不同于其它装备的 >0.5。
	if float(enabled.get(&"bag", 0.0)) >= CUTOFF:
		var bag: Color = sample_equip.call(&"bag", Vector2(body.r, body.g))
		if bag.a > CUTOFF:
			bag_alpha = 1.0
	var hide := maxf(float(weapons[0].get("hide_outline_on_body", 0.0)), float(weapons[1].get("hide_outline_on_body", 0.0))) > CUTOFF
	var blocked := hide and body_alpha > CUTOFF
	var weapon_alpha := [0.0, 0.0]
	var caster_alpha := body_alpha
	for slot in range(2):
		# 源码严格 <0.5；恰好 0.5 也不参与轮廓和 Mode0 投影。
		if float(weapons[slot].get("is_sequence", 0.0)) < CUTOFF:
			var sampled: Variant = sample_weapon.call(slot, sheet_top)
			if sampled != null and sampled.a > CUTOFF:
				caster_alpha = maxf(caster_alpha, sampled.a)
				if not blocked:
					weapon_alpha[slot] = sampled.a
	return {"body_alpha":body_alpha, "bag_alpha":bag_alpha,
		"weapon0_alpha":weapon_alpha[0], "weapon1_alpha":weapon_alpha[1],
		"weapon_alpha":maxf(weapon_alpha[0],weapon_alpha[1]), "caster_alpha":caster_alpha,
		"body_uv":body, "head_uv":head}

static func layer_priority(source_id: int, body_in_front: float, weapons: Array) -> float:
	assert(weapons.size() == 2, "层级判据需要两个明确的武器槽")
	if source_id == 10:
		return 100.0 if body_in_front > CUTOFF else 0.0
	if source_id == 7:
		return 80.0 if float(weapons[0].get("depth_mode", 0.0)) > CUTOFF else 10.0
	if source_id == 8:
		return 70.0 if float(weapons[1].get("depth_mode", 0.0)) > CUTOFF else 5.0
	if source_id in [1,2,3,4,5,6,9,11]:
		return 50.0
	return -1.0

static func outline(frame_uv_bottom: Vector2, frame_size: Vector2, shadow_base_y: float,
		source_id: int, body_in_front: float, weapons: Array, sample_coverage: Callable) -> Dictionary:
	assert(frame_size.x > 0.0 and frame_size.y > 0.0, "轮廓步长需要正数帧尺寸")
	var step := Vector2.ONE / frame_size
	var best := -1.0
	if frame_uv_bottom.y + 0.5 * step.y < shadow_base_y:
		return {"is_outline":false,"best_priority":best}
	var center: Dictionary = sample_coverage.call(frame_uv_bottom)
	var current := layer_priority(source_id,body_in_front,weapons)
	var bp := layer_priority(1,body_in_front,weapons)
	var bagp := layer_priority(10,body_in_front,weapons)
	var hide := float(weapons[0].get("hide_outline_on_body",0.0)) > CUTOFF or float(weapons[1].get("hide_outline_on_body",0.0)) > CUTOFF
	for offset in [Vector2(step.x,0),Vector2(-step.x,0),Vector2(0,step.y),Vector2(0,-step.y)]:
		var neighbor: Dictionary = sample_coverage.call(frame_uv_bottom + offset)
		if not (hide and center.body_alpha > CUTOFF) and center.weapon_alpha <= CUTOFF:
			for slot in range(2):
				var wp := layer_priority(7+slot,body_in_front,weapons)
				var wa: float = neighbor.weapon0_alpha if slot == 0 else neighbor.weapon1_alpha
				var blocked: bool = (neighbor.body_alpha > CUTOFF and bp > wp) or (neighbor.bag_alpha > CUTOFF and bagp > wp)
				if wa > CUTOFF and not blocked and wp >= current and wp > best:
					best = wp
		if center.body_alpha <= CUTOFF and neighbor.body_alpha > CUTOFF:
			var body: Color = neighbor.body_uv
			var head: Color = neighbor.head_uv
			var hand := absf(body.b - 0.4) < 0.025 or absf(body.b - 0.5) < 0.025
			var core := hand and ((absf(head.b - 0.1) < 0.025 and head.a > CUTOFF) or body.a > CUTOFF)
			var weapon_blocks := hand and (source_id == 7 or source_id == 8)
			if not core and not weapon_blocks and bp >= current and bp > best:
				best = bp
		if center.bag_alpha <= CUTOFF and neighbor.bag_alpha > CUTOFF and bagp >= current and bagp > best:
			best = bagp
	return {"is_outline":best >= 0.0,"best_priority":best}

static func apply_outline(color: Color, decision: Dictionary, default_enabled: float,
		hit: float, extra: float, hit_color: Color, extra_color: Color) -> Color:
	# 后续阴影只能覆盖结果 alpha<=0.5；顶点颜色乘法仍由外部最终渲染阶段负责。
	if not decision.is_outline or not (default_enabled > CUTOFF or hit > CUTOFF or extra > CUTOFF):
		return color
	var rgb := hit_color if hit > CUTOFF else extra_color if extra > CUTOFF else Color.BLACK
	return Color(rgb.r,rgb.g,rgb.b,1.0)
