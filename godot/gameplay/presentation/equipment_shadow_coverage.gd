extends RefCounted
## 锁定 Unity 31629d53 的阴影写入与片元判据；仅 CPU 合同，不接入渲染器。
## 脚像素为作者顶原点；阴影判断与回调使用帧内底原点。
static func height_writes(left_foot: Array, right_foot: Array, ground_y: int,
		frame_size: Vector2i = Vector2i(32,32), has_material := true,
		has_frame_data := true, has_cached_frame := true) -> Dictionary:
	if not has_material:
		return {}
	if not has_frame_data or not has_cached_frame or (left_foot.is_empty() and right_foot.is_empty()):
		return {"mode":-1.0}
	var min_y := 2147483647
	var mins := [2147483647,2147483647]
	var maxs := [-2147483648,-2147483648]
	var ys := [2147483647,2147483647]
	for side in range(2):
		for pixel in [left_foot,right_foot][side]:
			min_y = mini(min_y,pixel.y)
			ys[side] = mini(ys[side],pixel.y)
			mins[side] = mini(mins[side],pixel.x)
			maxs[side] = maxi(maxs[side],pixel.x)
	var diff := ground_y - min_y
	var writes := {"frame_size":Vector2(frame_size),"mode":0.0,"left_x":0.0,
		"right_x":0.0,"center_x":0.0,"base_y":1.0-(ground_y+0.5)/frame_size.y}
	if diff > 0 and diff <= 2:
		writes.mode = 1.0
		# 保留源代码缺侧时的 ±999，而非改为数学无穷。
		writes.left_x = minf(mins[0] if not left_foot.is_empty() else 999,mins[1] if not right_foot.is_empty() else 999)/frame_size.x
		writes.right_x = maxf(maxs[0] if not left_foot.is_empty() else -999,maxs[1] if not right_foot.is_empty() else -999)/frame_size.x
	elif diff > 2 and diff <= 9:
		writes.mode = 2.0
		if ys[0] <= ys[1] and not left_foot.is_empty():
			writes.center_x = float(maxs[0])/frame_size.x
		elif not right_foot.is_empty():
			writes.center_x = float(mins[1])/frame_size.x
	elif diff > 9:
		writes.mode = 3.0
		writes.center_x = 0.5
	return writes

static func apply_writes(previous: Dictionary, writes: Dictionary) -> Dictionary:
	var result := previous.duplicate(true)
	result.merge(writes,true)
	return result

static func ground_probe(x: float, params: Dictionary, sample_caster: Callable) -> float:
	var alpha := 0.0
	var step_x := 1.0/float(params.frame_size.x)
	for tap in [x,x+step_x,x-step_x]:
		# 只筛选 X，不裁基线 Y，也不先裁整个三点中心。
		if tap >= 0.0 and tap <= 1.0:
			alpha = maxf(alpha,float(sample_caster.call(Vector2(tap,params.base_y))))
	return alpha

static func mask(uv: Vector2, params: Dictionary, sample_caster: Callable) -> bool:
	var step := Vector2.ONE/Vector2(params.frame_size)
	var base_y := float(params.base_y)
	var mode := float(params.mode)
	if mode < 0.5:
		var dy := uv.y-base_y
		if dy > 0.5*step.y or dy < -1.5*step.y:
			return false
		var alpha := 0.0
		if dy < -0.5*step.y:
			alpha = ground_probe(uv.x,params,sample_caster)
		else:
			alpha = maxf(ground_probe(uv.x-step.x,params,sample_caster),
				ground_probe(uv.x+step.x,params,sample_caster))
		return alpha > 0.001
	if mode < 1.5:
		return not (uv.x < params.left_x-step.x or uv.x > params.right_x+step.x or uv.y < base_y-step.y or uv.y > base_y+step.y)
	var dx := (uv.x-float(params.center_x))/step.x
	var dy := (uv.y-base_y)/step.y
	if mode < 2.5:
		var in_rect := dx >= -1.0 and dx <= 2.0 and dy >= -1.0 and dy <= 1.0
		var in_corner := (dx < -0.5 or dx > 1.5) and (dy < -0.5 or dy > 0.5)
		return in_rect and not in_corner
	return (absf(dx) <= 0.5 and absf(dy) <= 0.5
		or absf(dx) <= 0.5 and (absf(dy-1.0) <= 0.5 or absf(dy+1.0) <= 0.5)
		or absf(dy) <= 0.5 and (absf(dx-1.0) <= 0.5 or absf(dx+1.0) <= 0.5))

static func apply_shadow(final_color: Color, final_alpha: float, enabled: float,
		shadow_color: Color, uv: Vector2, params: Dictionary, sample_caster: Callable) -> Color:
	# 原片元先做遮罩判断，再仅在阴影 alpha>0 时整色替换；最终顶点乘色不在本函数。
	if final_alpha <= 0.5 and enabled > 0.5:
		if mask(uv,params,sample_caster) and shadow_color.a > 0.0:
			return shadow_color
	return final_color
