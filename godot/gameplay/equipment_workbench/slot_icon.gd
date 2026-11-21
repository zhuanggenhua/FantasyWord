extends RefCounted

static func from_sprite(sprite: Image) -> ImageTexture:
	# Unity GetSequenceFramePreviewSprite: crop visible pixels, fit edge 30 into 32.
	var lo := Vector2i(32, 32)
	var hi := Vector2i(-1, -1)
	for y in 32:
		for x in 32:
			if sprite.get_pixel(x, y).a > 0.01:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	var canvas := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	if hi.x >= lo.x:
		var size := hi - lo + Vector2i.ONE
		var factor := 30.0 / float(maxi(size.x, size.y))
		var target := Vector2i(maxi(1, roundi(size.x * factor)), maxi(1, roundi(size.y * factor)))
		var offset := Vector2i((32 - target.x) >> 1, (32 - target.y) >> 1)
		# Source floors in the bottom-origin frame and only writes alpha above 0.01.
		for y in target.y:
			for x in target.x:
				var sx := lo.x + mini(floori(x / factor), size.x - 1)
				var sy := hi.y - mini(floori(y / factor), size.y - 1)
				var color := sprite.get_pixel(sx, sy)
				if color.a > 0.01:
					canvas.set_pixel(offset.x + x, 31 - offset.y - y, color)
	return ImageTexture.create_from_image(canvas)
