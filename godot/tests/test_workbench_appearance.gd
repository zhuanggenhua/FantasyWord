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
	screen.free()
	print("PASS Workbench appearance: ",passed," passed / ",passed+failed," total")
	quit(1 if failed else 0)
