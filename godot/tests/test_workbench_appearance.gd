extends SceneTree

const Scene := preload("res://gameplay/equipment_workbench/equipment_system_demo.tscn")
const Palette := preload("res://gameplay/presentation/equipment_skin_palette.gd")
const Preview := preload("res://gameplay/equipment_workbench/nonhuman_preview.gd")
var passed := 0
var failed := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		printerr("FAIL ",label)

func button(parent: Node, key: String) -> Button:
	return parent.find_child(key,true,false) as Button

func click(parent: Node, key: String) -> void:
	var control := button(parent,key)
	check(is_instance_valid(control) and not control.disabled and control.is_visible_in_tree(), "available button "+key)
	if is_instance_valid(control) and not control.disabled: control.pressed.emit()

func state(actor: Node2D, material: ShaderMaterial) -> Array:
	return [actor.playback.current_action, actor.playback.current_direction, actor.playback.current_label,
		actor.animator.current_animation_position, actor.sprite.texture,
		material.get_shader_parameter("enabled_cloth"), material.get_shader_parameter("enabled_cloak"),
		material.get_shader_parameter("cloak_map")]

func run() -> void:
	if OS.get_environment("FANTASYWORD_WORKBENCH_NONHUMAN").is_empty() or OS.get_environment("FANTASYWORD_WORKBENCH_DWARF_ELF").is_empty():
		print("SKIP original five-race workbench appearance inputs not configured")
		quit()
		return
	var screen := Scene.instantiate()
	root.add_child(screen)
	await process_frame
	var category := button(screen,"AppearanceCategory")
	check(screen.ready_for_preview and category != null and not category.disabled, "actual workbench has original appearance entry")
	if category == null:
		quit(1)
		return
	var picker := screen.find_child("SourceCharacterPicker",true,false)
	for race in ["Human","Dwarf","Elf","Goblin","Orc"]:
		click(picker,race)
		var actor: Node2D = screen._human if race == "Human" else screen._race_views[race]
		var material: ShaderMaterial = actor.sprite.material
		var green: bool = race in ["Goblin","Orc"]
		check(material.get_shader_parameter("skin_palette_enabled") == green,"catalog default palette "+race)
		click(screen,"Attack")
		actor.animator.seek(0.25,true)
		screen._select_direction(1)
		screen._set_cloth(false)
		if not green:
			click(screen,"CloakCategory")
			click(screen,"EquipTravelCloak")
		click(screen,"AppearanceCategory")
		var base := button(screen,"BaseHumanoidAppearance")
		var alternate := button(screen,"GreenSkinAppearance")
		check(base.get_index() == 0 and alternate.get_index() == 1 and base.icon != null and alternate.icon == null,
			"deduplicated source order and raw/empty icons")
		check(base.icon == screen._human.material_binding.workbench_base_appearance().hair.se.texture,
			"unmodified original Base hairSE thumbnail")
		var before := state(actor,material)
		click(screen,"GreenSkinAppearance")
		check(state(actor,material) == before, "green changed appearance only "+race)
		check(material.get_shader_parameter("skin_palette_enabled") and material.get_shader_parameter("skin_color_count") == 5
			and material.get_shader_parameter("skin_color_domain") == 1, "five linear palette rows "+race)
		check(not material.get_shader_parameter("enabled_hair") and not material.get_shader_parameter("enabled_beard")
			and not material.get_shader_parameter("enabled_eye_decoration"), "green clears authored base appearance layers "+race)
		check(screen._appearance_badges[1].visible and not screen._appearance_badges[0].visible
			and screen._details.text.contains("形象 绿皮外观"), "single current indicator and details "+race)
		click(screen,"BaseHumanoidAppearance")
		check(state(actor,material) == before, "base changed appearance only "+race)
		check(not material.get_shader_parameter("skin_palette_enabled") and material.get_shader_parameter("skin_color_count") == 0
			and material.get_shader_parameter("skin_color_domain") == 0 and material.get_shader_parameter("enabled_hair"),
			"base resets palette and restores authored directional hair "+race)
		check(screen._appearance_badges[0].visible and not screen._appearance_badges[1].visible
			and screen._details.text.contains("形象 基础人形外观"), "base selection visible "+race)
		screen._select_direction(3)
		check(not material.get_shader_parameter("enabled_left_eye") and not material.get_shader_parameter("enabled_right_eye"),
			"source back-facing fallback or head-facing disables eyes "+race)
	var fixture := Preview.read_locked(OS.get_environment("FANTASYWORD_WORKBENCH_NONHUMAN"))
	var look := Preview.green_appearance(fixture.base_appearance)
	var binding := Palette.bind_palette(look.skin_src,look.skin_dst,true)
	var exact := Color8(187,158,121).srgb_to_linear()
	var neighbor := Color8(188,158,121).srgb_to_linear()
	check(Palette.apply(exact,1,binding).linear_to_srgb().is_equal_approx(Color8(46,109,52)), "source positive linear palette coordinate")
	check(Palette.apply(neighbor,1,binding) == neighbor and Palette.apply(exact,9,binding) == exact,
		"adjacent skin color and same-color gear stay unchanged")
	click(picker,"Human")
	check(screen._appearance_slots.visible and screen._appearance_index == 0,"race switch retains appearance list and resets own default")
	if not OS.get_environment("FANTASYWORD_WORKBENCH_HEADWEAR").is_empty():
		await check_headwear(screen,picker)
	screen.free()
	print("PASS Workbench appearance: ",passed," passed / ",passed+failed," total")
	quit(1 if failed else 0)

func avatar_pixels(actor: Node2D) -> PackedByteArray:
	actor.animator.pause()
	actor.animator.seek(0.0,true)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var center := Vector2i(actor.sprite.get_global_transform_with_canvas().origin)
	return image.get_region(Rect2i(center-Vector2i(104,104),Vector2i(208,208))).get_data()

func check_headwear(screen: Control, picker: Node) -> void:
	var graphics := DisplayServer.get_name()!="headless"
	var helmet := button(screen,"HelmetCategory")
	var mask := button(screen,"MaskCategory")
	for race in ["Dwarf","Elf","Goblin","Orc"]:
		click(picker,race)
		var actor: Node2D = screen._race_views[race]
		var material: ShaderMaterial = actor.composite
		var green: bool = race in ["Goblin","Orc"]
		click(screen,"MaskCategory")
		check(not mask.disabled and screen._headwear.equipped<0 and not material.get_shader_parameter("enabled_mask"), "原角色默认无头饰 "+race)
		if green: check(material.get_shader_parameter("head_map").get_image().is_invisible(), "原头部 UV 全透明 "+race)
		for d in 4:
			screen._select_direction(d)
			var plain := PackedByteArray()
			if graphics: plain = await avatar_pixels(actor)
			click(screen,"EquipGoggles")
			check(material.get_shader_parameter("enabled_mask") and not material.get_shader_parameter("enabled_helmet") and
				"智力 +2" in screen._details.text and "魔力 +2" in screen._details.text, "原面罩选项及属性 "+race+"/"+str(d))
			if graphics:
				var painted := await avatar_pixels(actor)
				# 四个族的初始待机帧没有与原护目镜有效像素相交的头部 UV。
				check(plain==painted, "原待机 UV 不命中护目镜，未补画像素 "+race+"/"+str(d))
			click(screen,"RemoveMask")
			check(not material.get_shader_parameter("enabled_mask") and material.get_shader_parameter("mask_map")==null, "卸下只清原面罩 "+race)
			if graphics: check(plain==await avatar_pixels(actor), "卸下恢复整人同帧 "+race+"/"+str(d))
		click(screen,"EquipGoggles")
		click(screen,"HelmetCategory")
		click(screen,"RemoveHelmet")
		check(material.get_shader_parameter("enabled_mask"), "空头盔分类不卸面罩 "+race)
		click(screen,"EquipIronHelmetI")
		check(screen._headwear.equipped_in(5)>=0 and material.get_shader_parameter("enabled_helmet")
			and not material.get_shader_parameter("enabled_mask") and material.get_shader_parameter("mask_map")==null
			and not material.get_shader_parameter("enabled_hair") and not material.get_shader_parameter("enabled_beard"),
			"原铁盔 I 替换面罩并隐藏发须 "+race)
		if graphics and race=="Dwarf":
			screen._select_direction(0)
			await avatar_pixels(actor)
			var sprite: Sprite2D = actor.sprite
			var sample := Vector2i(sprite.get_global_transform_with_canvas()*(sprite.get_rect().position+Vector2(15.5,15.5)))
			var color := root.get_texture().get_image().get_pixelv(sample)
			var actual := Vector3(color.r8,color.g8,color.b8)
			check(actual.distance_to(Vector3(113,132,148))<=2, "矮人东南待机铁盔采样到原图像素 "+str(actual))
		click(screen,"Walk")
		for d in 4:
			screen._select_direction(d)
			actor.animator.pause()
			actor.animator.seek(0.125,true)
			var row: int = actor._green_row if green else actor._cursor.row_index
			var frame: Dictionary = {} if green else actor._cursor.cached_frame
			var facing: int = frame.get("body_regions",{}).get("head",{}).get("sprite_facing",row)
			var rect := Vector4(0,(18-facing)*32.0/608,32.0/512,(19-facing)*32.0/608)
			check(material.get_shader_parameter("helmet_rect").is_equal_approx(rect)
				and material.get_shader_parameter("enabled_helmet"), "行走重采样原铁盔 I 朝向/裁切 "+race+"/"+str(d))
		click(screen,"EquipIronHelmetII")
		check(is_equal_approx(material.get_shader_parameter("helmet_rect").x,64.0/512) and
			"生命 +6" in screen._details.text, "铁盔 II 选择另一原图集列 "+race)
		click(screen,"EquipHornedHelmet")
		check(material.get_shader_parameter("helmet_rect").is_equal_approx(Vector4(0,0,1,1)) and
			"力量 +2" in screen._details.text, "角饰头盔换回独立原贴图 "+race)
		click(screen,"HatCategory")
		click(screen,"EquipLightHat")
		check(screen._headwear.equipped_in(6)>=0 and screen._headwear.equipped_in(5)<0 and
			material.get_shader_parameter("enabled_helmet"), "原帽子替换铁盔 "+race)
		click(picker,race)
		check(not helmet.disabled and screen._headwear.equipped<0 and not material.get_shader_parameter("enabled_helmet")
			and material.get_shader_parameter("helmet_map")==null and screen._head_lists[6].visible
			and material.get_shader_parameter("enabled_cloth"), "重选保留当前栏、还原原布衣与空头饰 "+race)
