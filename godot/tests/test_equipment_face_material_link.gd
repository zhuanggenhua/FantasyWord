extends SceneTree
## 源逻辑的方向和矩形输出可由材质直接消费；非真图形验收。
const Face = preload("res://gameplay/presentation/equipment_face_accessory.gd")
const Binder = preload("res://gameplay/presentation/equipment_subset_material.gd")

func _initialize() -> void:
	var base := ImageTexture.create_from_image(Image.create(32, 32, false, Image.FORMAT_RGBA8))
	var atlas := ImageTexture.create_from_image(Image.create(64, 32, false, Image.FORMAT_RGBA8))
	var appearance := {"face_accessory": {&"sw": {"texture": atlas, "rect_pixels_bottom": Rect2(8, 4, 32, 16)}}}
	var bind := Face.resolve(0, {"body_regions": {"head": {"sprite_facing": 3}}}, appearance)
	if not bind.enabled or bind.head_facing != 3:
		push_error("必须独立使用头朝向，且 NW 按原代码回退至 SW")
		quit(1)
		return
	var attached := Binder.create(base, base, base, false, {&"face_accessory": bind.enabled},
		{&"face_accessory": {"texture": bind.texture, "rect": bind.rect_bottom}}, {})
	var empty := Binder.create(base, base, base, false, {}, {}, {})
	if not attached.ok or not empty.ok:
		push_error("面饰绑定参数不能被材质消费")
		quit(1)
		return
	var mat: ShaderMaterial = attached.material
	if (mat.get_shader_parameter("face_accessory_map") != atlas
			or mat.get_shader_parameter("face_accessory_rect") != Vector4(0.125, 0.125, 0.625, 0.625)
			or not mat.get_shader_parameter("enabled_face_accessory")
			or empty.material.get_shader_parameter("enabled_face_accessory")):
		push_error("面饰整图、底原点 min/max 或逐角色启用状态错误")
		quit(1)
		return
	print("PASS equipment_face_material_link: authored direction, texture, rect and isolation")
	quit(0)
