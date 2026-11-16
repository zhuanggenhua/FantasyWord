extends RefCounted
## 换装着色器的 CPU 坐标合同，不是最终渲染器。
## 入口整图 UV 和 Image 使用顶原点；作者装备矩形及编码 RG 保持 Unity 底原点。

static func rect_from_unity_bounds(bounds: Vector4) -> Rect2:
	return Rect2(bounds.x, bounds.y, bounds.z - bounds.x, bounds.w - bounds.y)

static func frame_local_uv(sheet_uv_top: Vector2, frame_rect_top: Rect2) -> Vector2:
	assert(frame_rect_top.size.x > 0.0 and frame_rect_top.size.y > 0.0, "当前帧矩形尺寸必须为正")
	var local := (sheet_uv_top - frame_rect_top.position) / frame_rect_top.size
	return Vector2(local.x, 1.0 - local.y)

static func equipment_uv(encoded_rg: Vector2, rect_bottom: Rect2) -> Vector2:
	# 编码 RG 不是当前帧局部 UV；先按作者装备矩形重映射，再翻转最终 V。
	var bottom := rect_bottom.position + rect_bottom.size * encoded_rg
	return Vector2(bottom.x, 1.0 - bottom.y)

static func sample_point(image: Image, uv_top: Vector2) -> Color:
	assert(image != null and not image.is_empty(), "点采样缺少可读纹理")
	# 对应原 UV 图的 Point / Clamp / 无 mip；保留线性数据字节，不做 sRGB 转换。
	var x := clampi(int(floor(uv_top.x * image.get_width())), 0, image.get_width() - 1)
	var y := clampi(int(floor(uv_top.y * image.get_height())), 0, image.get_height() - 1)
	return image.get_pixel(x, y)

static func sample_sheet(main: Image, body: Image, head: Image, sheet_uv_top: Vector2) -> Dictionary:
	# 三张图共享整图布局；禁止误用 frame_local_uv 或各自裁切后的 UV。
	return {"main": sample_point(main, sheet_uv_top),
		"body": sample_point(body, sheet_uv_top),
		"head": sample_point(head, sheet_uv_top)}
