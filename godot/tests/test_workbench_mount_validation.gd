extends SceneTree
## 独立走工作台的坐骑按钮和正式槽，并核对两个实际绘制层。
const Demo = preload("res://gameplay/equipment_workbench/equipment_system_demo.tscn")
const Equipment = preload("res://game_core/inventory/source_character_equipment.gd")
var demo: Control
var count := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var directory := OS.get_environment("FANTASYWORD_WORKBENCH_MOUNT_VALIDATION")
	if directory.is_empty():
		demo = Demo.instantiate()
		root.add_child(demo)
		await process_frame
		check(demo.find_child("MountCategory", true, false) == null, "普通入口没有正式坐骑按钮")
		finish()
		return
	root.size = Vector2i(1600, 900)
	demo = Demo.instantiate()
	root.add_child(demo)
	await process_frame
	await process_frame
	check(demo.ready_for_preview, "原图合同齐备：" + demo.last_error)
	if not demo.ready_for_preview:
		finish()
		return
	var player: Node2D = demo.get_node("MountValidationPlayer")
	var riding: Node2D = player.get_node("MountedCharacterPresentation")
	var owner: Equipment = demo._mount_owner
	var with_cloth := not OS.get_environment("FANTASYWORD_WORKBENCH_MOUNT_CLOTH").is_empty()
	check(owner.equipped(Equipment.Slot.MOUNT) == null and not riding.visible, "正式槽初始为空")
	await click("MountCategory")
	if with_cloth:
		check(not button("EquipWarHorse").disabled, "有真实骑手换装合同，默认布衣无需卸下")
		await click("EquipWarHorse")
		check(riding.rider_sprite.material != null and riding.mount_sprite.material == null,
			"穿布衣上马只切换骑手材质")
		await click("RemoveMount")
	else:
		check(button("EquipWarHorse").disabled, "默认布衣不能冒充无装备直显")
		await click("EquipWarHorse")
		check(owner.equipped(Equipment.Slot.MOUNT) == null, "有普通装备时不会写入直显版坐骑槽")
	await click("ClothCategory")
	await click("RemoveCloth")
	await click("MountCategory")
	var standing_material: Material = player.sprite.material
	await click("EquipWarHorse")
	check(owner.equipped(Equipment.Slot.MOUNT) == owner.item_for_guid(Equipment.WAR_HORSE)
		and riding.visible and not player.sprite.visible, "真实按钮→正式 Mount 槽→直显马与骑手")
	check(riding.mount_sprite.z_index == -1 and riding.rider_sprite.z_index == 0
		and riding.mount_sprite.position == Vector2.ZERO and riding.rider_sprite.position == Vector2.ZERO
		and riding.mount_sprite.material == null and riding.rider_sprite.material == null, "同一锚点、原双层顺序、无换装材质")
	await create_timer(0.25).timeout
	check(riding.frame_index > 0, "Godot 实际画面随自己的坐骑时钟前进")
	riding.set_process(false)
	for req in ["Idle", "Walk"]:
		await click(req)
		for dir in 4:
			await click(["SE", "SW", "NE", "NW"][dir])
			check(player.driver.current_animation_key == req and player.playback.current_direction == dir, "工作台原动作及方向")
			var cycle := 2.4 if req == "Idle" else 0.8
			if riding.action == ("Stand" if req == "Idle" else "Move") and riding.facing == dir:
				riding.tick(req, (dir + 1) % 4, 0.0)
			riding.tick(req, dir, 0.61)
			check(riding.frame_index == 0 and riding.elapsed == 0.0, "变更动作或方向时丢弃本 tick 的增量")
			for frame in 2:
				if frame == 1: riding.tick(req, dir, 0.201)
				var name := "待机" if req == "Idle" else "行走"
				check(riding.frame_index == frame
					and riding.mount_frame_name == "%s_stallion_%s_0%s" % [name, dir, frame]
					and riding.rider_frame_name == "War马%s袭击者_人类_%s_0%s" % [name, dir, frame], "双层对应原连续帧名")
				if DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					check(visible_pair(riding), "原生全景中的马、骑手像素与图集对应")
			riding.tick(req, dir, cycle - 0.201 + 0.01)
			check(riding.frame_index == 0, "同一节拍循环双层")
	await click("Idle")
	riding.tick("Idle", 3, 1.0)
	riding.tick("Idle", 3, 0.25)
	await click("Attack")
	riding.tick("Attack", 3, 0.01)
	check(riding.used_fallback and riding.action == "Stand" and riding.frame_index == 1
		and is_equal_approx(riding.elapsed, 0.26), "攻击回退到正在播的 Stand，不重复重置")
	await click("EquipWarHorse")
	check(is_equal_approx(riding.elapsed, 0.26), "同一战马重复选择不重播")
	await click("Walk")
	riding.tick("Walk", 3, 0.3)
	riding.tick("Walk", 3, 0.25)
	await click("Dmg")
	riding.tick("Dmg", 3, 0.1)
	check(riding.used_fallback and riding.action == "Stand" and riding.frame_index == 0, "Move→伤害回退到 Stand 从第零帧开始")
	await click("RemoveMount")
	check(owner.equipped(Equipment.Slot.MOUNT) == null and not riding.visible and player.sprite.visible
		and player.sprite.material == standing_material and riding.mount_sprite.texture == null
		and riding.rider_sprite.texture == null, "卸下只清坐骑槽并恢复原步行渲染器")
	if with_cloth:
		await check_mounted_cloth(player, riding, owner, standing_material)
	finish()

func check_mounted_cloth(player: Node2D, riding: Node2D, owner: Equipment, standing_material: Material) -> void:
	await click("Idle")
	await click("SE")
	await click("EquipWarHorse")
	riding.set_process(false)
	riding.tick("Idle", 0, 0.25)
	var current: int = riding.frame_index
	var time: float = riding.elapsed
	var body_texture: Texture2D = riding.mount_sprite.texture
	var rider_texture: Texture2D = riding.rider_sprite.texture
	await click("ClothCategory")
	await click("EquipCloth")
	var mat: ShaderMaterial = riding.rider_sprite.material
	check(mat != null and mat != standing_material and mat.get_shader_parameter("enabled_cloth"), "原布衣按钮启用独立骑手换装材质")
	check(riding.frame_index == current and riding.elapsed == time and riding.mount_sprite.texture == body_texture
		and riding.rider_sprite.texture == rider_texture and riding.mount_sprite.material == null,
		"换装保留当前双层帧、坐骑时钟和原马身材质")
	if mat == null: return
	var have_native := DisplayServer.get_name() != "headless"
	for req in ["Idle", "Walk"]:
		await click(req)
		for dir in 4:
			await click(["SE", "SW", "NE", "NW"][dir])
			riding.tick(req, (dir+1)%4, 0.0)
			riding.tick(req, dir, 0.0)
			for f in (12 if req == "Idle" else 4):
				if f > 0: riding.tick(req, dir, 0.201)
				var sprite: AtlasTexture = riding.rider_sprite.texture
				var body: Texture2D = mat.get_shader_parameter("body_map")
				var head: Texture2D = mat.get_shader_parameter("head_map")
				var dimensions := Vector2(384 if req == "Idle" else 128, 128)
				check(riding.frame_index == f and mat.get_shader_parameter("main_map") == sprite.atlas
					and sprite.atlas.get_size() == dimensions and body.get_size() == dimensions and head.get_size() == dimensions
					and sprite.region.position == Vector2(f*32, dir*32)
					and bool(mat.get_shader_parameter("body_in_front")) == (dir >= 2)
					and bool(mat.get_shader_parameter("enabled_left_eye")) == (dir < 2),
					"骑手实际原帧、专用整张 UV 和身体/眼部方向同步")
				check(cloth_coverage(mat, sprite) == 0, "原骑乘 Body UV 采样到原布衣透明区域，不自行重排作者 UV")
				if have_native and f < 2:
					await RenderingServer.frame_post_draw
					var with_layer := frame_pixels(riding.rider_sprite)
					mat.set_shader_parameter("enabled_cloth", false)
					await RenderingServer.frame_post_draw
					check(with_layer == frame_pixels(riding.rider_sprite), "同帧原布衣无可见像素：保留正式材质而非补造衣服")
					mat.set_shader_parameter("enabled_cloth", true)
	if have_native:
		await click("Idle")
		await click("SE")
		riding.tick("Idle", 0, 0.0)
		await RenderingServer.frame_post_draw
		var equipped_eye := sample_pixel(riding.rider_sprite, Vector2i(14, 10))
		var configured_eye: Color = mat.get_shader_parameter("right_eye_color")
		await click("RemoveCloth")
		await RenderingServer.frame_post_draw
		var direct_eye := sample_pixel(riding.rider_sprite, Vector2i(14, 10))
		check(absf(equipped_eye.r - configured_eye.r) < 0.012 and absf(equipped_eye.g - configured_eye.g) < 0.012
			and absf(equipped_eye.b - configured_eye.b) < 0.012 and equipped_eye != direct_eye,
			"原 Idle-SE 第零帧实际骑手右眼吃到骑乘 UV；非衣物像素")
		await click("EquipCloth")
	var previous: float = riding.elapsed
	await click("RemoveCloth")
	check(riding.rider_sprite.material == null and riding.elapsed == previous
		and owner.equipped(Equipment.Slot.MOUNT) == owner.item_for_guid(Equipment.WAR_HORSE), "骑乘卸布衣原帧直显，不卸马不跳帧")
	await click("EquipCloth")
	await click("MountCategory")
	await click("RemoveMount")
	check(player.sprite.visible and player.sprite.material == standing_material
		and standing_material.get_shader_parameter("enabled_cloth"), "穿布衣下马恢复站立外观和原材质")

func cloth_coverage(mat: ShaderMaterial, sprite: AtlasTexture) -> int:
	var body: Image = mat.get_shader_parameter("body_map").get_image()
	var cloth: Image = mat.get_shader_parameter("cloth_map").get_image()
	var covered := 0
	for y in 32:
		for x in 32:
			var encoded := body.get_pixelv(Vector2i(sprite.region.position) + Vector2i(x, y))
			var u := clampi(floori(encoded.r * cloth.get_width()), 0, cloth.get_width()-1)
			var v := clampi(floori((1.0-encoded.g) * cloth.get_height()), 0, cloth.get_height()-1)
			if cloth.get_pixel(u, v).a > 0.5: covered += 1
	return covered

func sample_pixel(sprite: Sprite2D, point: Vector2i) -> Color:
	var screen := root.get_texture().get_image()
	return screen.get_pixelv(Vector2i(sprite.to_global(Vector2(point) + Vector2(0.5,0.5) - Vector2(16,16))))

func frame_pixels(sprite: Sprite2D) -> PackedByteArray:
	var screen := root.get_texture().get_image()
	var left:= Vector2i(sprite.to_global(Vector2(-16,-16)))
	var right:= Vector2i(sprite.to_global(Vector2(16,16)))
	return screen.get_region(Rect2i(left,right-left)).get_data()

func visible_pair(riding: Node2D) -> bool:
	var frame := root.get_texture().get_image()
	var horse: AtlasTexture = riding.mount_sprite.texture
	var rider: AtlasTexture = riding.rider_sprite.texture
	var horse_image := horse.get_image()
	var rider_image := rider.get_image()
	var seen := [0, 0]
	for y in 32:
		for x in 32:
			var underlying := horse_image.get_pixel(x, y)
			var over := rider_image.get_pixel(x, y)
			var layer := 1 if over.a > 0.999 else (0 if over.a == 0.0 and underlying.a > 0.999 else -1)
			if layer < 0: continue
			var source := over if layer == 1 else underlying
			var rendered_at: Vector2 = riding.rider_sprite.to_global(Vector2(x + 0.5, y + 0.5) - Vector2(16, 16))
			var got := frame.get_pixelv(Vector2i(rendered_at))
			if absf(got.r - source.r) > 0.012 or absf(got.g - source.g) > 0.012 or absf(got.b - source.b) > 0.012:
				return false
			seen[layer] += 1
	return seen[0] > 0 and seen[1] > 0

func button(id: String) -> Button:
	return demo.find_child(id, true, false)

func click(id: String) -> void:
	var target := button(id)
	var center := target.get_global_transform_with_canvas() * (target.size * 0.5)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = center
		event.global_position = center
		event.pressed = down
		root.push_input(event, true)
		await process_frame

func check(value: bool, label: String) -> void:
	count += 1
	if not value:
		failed += 1
		push_error(label)

func finish() -> void:
	print("战马无装备直显：%d/%d；%s" % [count - failed, count, DisplayServer.get_name()])
	quit(int(failed > 0))
