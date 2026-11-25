extends RefCounted
## 对齐锁定的 EquipmentWorkbenchRuntimeUI 首格角色图标裁剪。
## 与装备图标不同：保留最大连通块的包围盒，再复制其中所有像素。
const CELL := 32
const FIT := 30
const VISIBILITY := 0.01

static func normalized(atlas: Image) -> Image:
	if atlas == null or atlas.is_empty() or atlas.get_width() < CELL or atlas.get_height() < CELL: return null
	var visited := PackedByteArray()
	visited.resize(CELL*CELL)
	var best_count := 0
	var best_lo := Vector2i.ZERO
	var best_hi := Vector2i(CELL-1,CELL-1)
	# 在左上首格内按 Unity 的左下原点扫描；同面积时保留先遇到的轮廓。
	for y in CELL:
		for x in CELL:
			var point := Vector2i(x,y)
			var index := y*CELL+x
			if visited[index] != 0: continue
			visited[index] = 1
			if atlas.get_pixel(x,CELL-1-y).a <= VISIBILITY: continue
			var pending: Array[Vector2i] = [point]
			var count := 0
			var lo := point
			var hi := point
			while not pending.is_empty():
				var p: Vector2i = pending.pop_back()
				count += 1
				lo = lo.min(p)
				hi = hi.max(p)
				for n in [p+Vector2i.RIGHT,p+Vector2i.LEFT,p+Vector2i.DOWN,p+Vector2i.UP]:
					if n.x < 0 or n.y < 0 or n.x >= CELL or n.y >= CELL: continue
					var i: int = n.y*CELL+n.x
					if visited[i] != 0: continue
					visited[i] = 1
					if atlas.get_pixel(n.x,CELL-1-n.y).a > VISIBILITY: pending.append(n)
			if count > best_count:
				best_count = count
				best_lo = lo
				best_hi = hi
	var size := best_hi-best_lo+Vector2i.ONE
	# Mathf 使用单精度且中点舍入到偶数；仅在原运算边界转为 float32。
	var scale := _f32(float(FIT)/maxi(size.x,size.y))
	var target := Vector2i(_nearest_even(_f32(size.x*scale)),_nearest_even(_f32(size.y*scale)))
	var offset_x := (CELL-target.x)>>1
	var image := Image.create_empty(CELL,CELL,false,Image.FORMAT_RGBA8)
	for y in target.y:
		var sy := CELL-1 - (best_lo.y + mini(floori(_f32(y/scale)),size.y-1))
		for x in target.x:
			var sx := best_lo.x + mini(floori(_f32(x/scale)),size.x-1)
			image.set_pixel(offset_x+x,CELL-2-y,atlas.get_pixel(sx,sy))
	return image

static func _f32(value: float) -> float:
	return PackedFloat32Array([value])[0]

static func _nearest_even(value: float) -> int:
	var lower := floori(value)
	return lower if value-lower == .5 and lower%2 == 0 else roundi(value)
