extends SceneTree

const Demo := preload("res://gameplay/equipment_workbench/equipment_system_demo.tscn")
var panel: Control
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",text)

func click(id: String) -> void:
	var button := panel.find_child(id,true,false) as Button
	check(button!=null and button.is_visible_in_tree(),"workbench button "+id)
	if button==null or not button.is_visible_in_tree(): return
	var center := button.get_global_transform_with_canvas() * (button.size * 0.5)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.position=center; event.global_position=center; event.pressed=down
		root.push_input(event,true)
		await process_frame

func finish() -> void:
	if is_instance_valid(panel):
		panel.queue_free()
		await process_frame
	print("%s workbench original SlashAttack: %d/%d" % ["PASS" if failures==0 else "FAIL",checks-failures,checks])
	quit(0 if failures==0 else 1)

func run() -> void:
	if OS.get_environment("FORMAL_WORKBENCH_SLASH_TEST")!="1":
		print("SKIP locked source workbench SlashAttack inputs not requested")
		quit(0)
		return
	root.size=Vector2i(1600,900)
	panel=Demo.instantiate(); root.add_child(panel)
	await process_frame; await process_frame
	check(panel.ready_for_preview,"real workbench fully admitted: "+panel.last_error)
	if not panel.ready_for_preview:
		await finish()
		return
	var human := panel.get_node("EquipmentSystemDemoCharacter")
	var mat: ShaderMaterial = human.sprite.material
	var animation: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		OS.get_environment("FANTASYWORD_WORKBENCH_SOURCE").path_join("animation.json")))
	var source: Dictionary = animation.actions.SlashAttack
	var with_cloak := FileAccess.file_exists(OS.get_environment("FANTASYWORD_WORKBENCH_SOURCE").path_join("cloak.json"))
	var with_bag := not OS.get_environment("FANTASYWORD_WORKBENCH_BAG").is_empty()
	check((panel.find_child("Dmg", true, false) != null) == animation.actions.has("Dmg"), "only authored damage clip exposes Dmg")
	var cloak_names := {}
	if with_cloak:
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			OS.get_environment("FANTASYWORD_WORKBENCH_SOURCE").path_join("cloak.json")))
		for guid in manifest.textures:
			cloak_names[guid] = manifest.textures[guid].file
		await click("CloakCategory")
		await click("EquipHeavyCloak")
	if with_bag:
		await click("BagCategory")
		await click("EquipBag")
	await click("ShieldCategory")
	await click("EquipShield")
	await click("WeaponCategory")
	await click("EquipAxe")
	var static_axe: Texture2D = mat.get_shader_parameter("weapon0_map")
	var idle_atlas: Texture2D = human.sprite.texture.atlas
	await click("SlashAttack")
	check(human.driver.current_animation_key=="SlashAttack" and human.sprite.texture.atlas!=idle_atlas,
		"separate original SlashAttack action, not renamed basic Attack")
	for i in 4:
		await click(["SE","SW","NE","NW"][i])
		human.animator.pause()
		for label in 4:
			human.animator.seek(.125*label,true)
			var box: Array = source.directions[i][label].rect
			var view: AtlasTexture = human.sprite.texture
			check(human.playback.current_label==label and human.playback.current_direction==i and
				view.region==Rect2(box[0],view.atlas.get_height()-box[1]-32,32,32),
				"actual body sample matches original source rect %d:%d"%[i,label])
			var pivot: Vector4 = mat.get_shader_parameter("weapon0_anchor_frame_uv")
			check(pivot.x==0.5 and pivot.y==0.5 and mat.get_shader_parameter("weapon0_enabled")
				and mat.get_shader_parameter("weapon0_map")!=static_axe
				and mat.get_shader_parameter("enabled_cloth")
				and not mat.get_shader_parameter("weapon1_enabled"),
				"unanchored axe sequence overlays cloth but unanchored static shield is hidden %d:%d"%[i,label])
			if with_cloak:
				check(mat.get_shader_parameter("enabled_cloak") and
					cloak_names.get(panel._cloak.last_texture_guid) == ["斗篷.png", "斗篷1.png", "斗篷.png", "斗篷1.png"][i],
					"heavy cloak base direction/fallback %d:%d" % [i, label])
			if with_bag:
				check(mat.get_shader_parameter("enabled_bag") and mat.get_shader_parameter("bag_rect").is_equal_approx(
					Vector4(0, (3-i)/4.0, 0.2, (4-i)/4.0)) and mat.get_shader_parameter("body_in_front") == (i>=2),
					"independent original bag rect and body depth %d:%d" % [i, label])
	if with_cloak and animation.actions.has("Dmg"):
		await click("Dmg")
		await click("NE")
		human.animator.pause(); human.animator.seek(0.0,true)
		check(cloak_names.get(panel._cloak.last_texture_guid) == "clock7.png", "Dmg enters heavy cloak left-variant")
		await click("SlashAttack")
		human.animator.pause(); human.animator.seek(0.0,true)
		check(cloak_names.get(panel._cloak.last_texture_guid) == "斗篷.png", "SlashAttack clears preceding Dmg variant")
	if with_bag:
		await click("BagCategory")
		await click("RemoveBag")
		check(not mat.get_shader_parameter("enabled_bag") and mat.get_shader_parameter("enabled_cloak"),
			"unequipping bag during SlashAttack preserves cloak")
	await click("NE")
	human.animator.pause(); human.animator.seek(0.0,true)
	var front: Texture2D = mat.get_shader_parameter("weapon0_map")
	check(mat.get_shader_parameter("weapon0_rect").is_equal_approx(Vector4(.25,.25,.5,.5))
		and mat.get_shader_parameter("weapon0_depth_mode")==1.0,"original NE strip starts at x=32")
	human.animator.seek(.125,true)
	check(mat.get_shader_parameter("weapon0_rect").is_equal_approx(Vector4(0,.25,.25,.5)),
		"original NE strip reads x=0 after x=32")
	human.animator.seek(.25,true)
	check(mat.get_shader_parameter("weapon0_map")!=front and mat.get_shader_parameter("weapon0_depth_mode")==0.0,
		"original NE frame 2 selects back texture/depth")
	human.animator.seek(.5,true)
	check(human.playback.current_label==3 and human.driver.current_animation_key=="SlashAttack",
		"nonlooping dedicated preview holds its last source frame")
	if with_bag: await click("WeaponCategory")
	await click("EquipSpear")
	human.animator.seek(.125,true)
	check(not mat.get_shader_parameter("weapon0_enabled"),
		"static long spear has no SlashAttack anchor and cannot borrow an axe strip")
	await click("Idle")
	check(human.playback.current_action=="Idle" and mat.get_shader_parameter("weapon0_enabled")
		and mat.get_shader_parameter("weapon1_enabled"),"Idle restores both equipped items without re-equipping")
	await finish()
