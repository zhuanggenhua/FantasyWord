extends RefCounted

## 原 EquipmentWornPreviewComposer：输入已取到实际 Sprite 矩形。
## 和角色格不同，保留所有可见像素的包围盒，水平和垂直同时居中。
static func from_sprite(sprite: Image) -> ImageTexture:
	if sprite == null or sprite.is_empty(): return null
	var normalized := _normalized(sprite)
	return ImageTexture.create_from_image(normalized if normalized != null else sprite)

static func from_texture(sprite: Texture2D) -> Texture2D:
	if sprite == null: return null
	var normalized := _normalized(sprite.get_image())
	return ImageTexture.create_from_image(normalized) if normalized != null else sprite

static func _normalized(sprite: Image) -> Image:
	if sprite == null or sprite.is_empty(): return null
	var lo := sprite.get_size()
	var hi := Vector2i(-1, -1)
	for y in sprite.get_height():
		for x in sprite.get_width():
			if sprite.get_pixel(x, y).a > 0.01:
				lo = lo.min(Vector2i(x,y))
				hi = hi.max(Vector2i(x,y))
	# Unity 的包装层在正规化没有输出时使用同一个源 Sprite。
	if hi.x < lo.x: return null
	var size := hi - lo + Vector2i.ONE
	var factor := _f32(30.0 / float(maxi(size.x, size.y)))
	var target := Vector2i(maxi(1, _round_even(_f32(size.x * factor))),
		maxi(1, _round_even(_f32(size.y * factor))))
	var offset := Vector2i((32 - target.x) >> 1, (32 - target.y) >> 1)
	var canvas := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	# Unity 使用单精度、左下原点取整，仅写入 alpha > .01 的像素。
	for y in target.y:
		for x in target.x:
			var sx := lo.x + mini(floori(_f32(x / factor)), size.x - 1)
			var sy := hi.y - mini(floori(_f32(y / factor)), size.y - 1)
			var color := sprite.get_pixel(sx, sy)
			if color.a > 0.01:
				canvas.set_pixel(offset.x + x, 31 - offset.y - y, color)
	return canvas

static func _f32(value: float) -> float:
	return PackedFloat32Array([value])[0]

static func _round_even(value: float) -> int:
	var lower := floori(value)
	return lower if value - lower == 0.5 and lower % 2 == 0 else roundi(value)
