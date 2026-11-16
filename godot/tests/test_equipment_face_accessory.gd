extends SceneTree
const Face = preload("res://gameplay/presentation/equipment_face_accessory.gd")
var checks := 0
var failures := 0

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(detail)

func _initialize() -> void:
	# 人工小图只检查引用与矩形，不作为角色资源或视觉验收图。
	var sprites := []
	for i in range(4):
		var texture := ImageTexture.create_from_image(Image.create_empty(40, 80, false, Image.FORMAT_RGBA8))
		sprites.append({"texture":texture, "rect_pixels_bottom":Rect2(4 + i, 16, 8, 24)})
	var keys := ["se", "sw", "ne", "nw"]
	# 独立期望表，不调用实现的 directional_sprite。
	var priorities := {0:[0], 1:[1,0], 2:[2,0], 3:[3,1,0], -1:[0], 7:[0]}
	for mask in range(16):
		var directions := {}
		for i in range(4):
			if mask & (1 << i):
				directions[keys[i]] = sprites[i]
		for facing in priorities:
			var expected: Variant = null
			for index in priorities[facing]:
				if mask & (1 << index):
					expected = sprites[index]
					break
			var result := Face.resolve(0, {"body_regions":{"head":{"sprite_facing":facing}, "torso":{"sprite_facing":1}}}, {"face_accessory":directions})
			check(result.enabled == (expected != null), "启用状态保持实际四向回退")
			check(result.sprite == expected, "四向缺图组合与非法方向引用正确")
			if expected != null:
				check(result.texture == expected.texture, "绑定原整图，不截取替换")
				check(result.rect_bottom == Rect2(expected.rect_pixels_bottom.position / Vector2(40,80), Vector2(0.2,0.3)), "矩形是底原点最小值及尺寸")
	check(Face.resolve(3, {}, {"face_accessory":{"nw":sprites[3]}}).enabled, "无 SE 仍允许已有 NW")
	check(Face.resolve(2, {}, {"face_accessory":{"se":sprites[0]}}).enabled, "背向不擅自关闭")
	check(Face.resolve(3, {}, {"face_accessory":{"sw":sprites[1]}}).sprite == sprites[1], "NW 依实际代码回退 SW")
	check(not Face.resolve(0, {}, null).enabled, "空外观禁用")
	check(not Face.resolve(0, {}, {}).enabled, "清空方向后无旧引用")
	var result := Face.resolve(0, {}, {"face_accessory":{"se":{"texture":null}}})
	check(not result.enabled and result.texture == null, "空纹理不启用")
	result = Face.resolve(0, {}, {"face_accessory":{"se":{"texture":sprites[0].texture}}})
	check(not result.enabled and result.has("error"), "缺作者矩形不伪造")
	if failures == 0:
		print("PASS equipment_face_accessory %d checks" % checks)
	quit(0 if failures == 0 else 1)
