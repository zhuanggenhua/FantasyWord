extends SceneTree

const Demo := preload("res://gameplay/equipment_workbench/equipment_system_demo.tscn")
var panel: Control
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL ",label)

func click(id: String) -> void:
	var button := panel.find_child(id,true,false) as Button
	check(button!=null and button.is_visible_in_tree() and not button.disabled,"实际工作台按钮 "+id)
	if button==null or not button.is_visible_in_tree() or button.disabled: return
	var point := button.get_global_transform_with_canvas() * (button.size*.5)
	for down in [true,false]:
		var e:=InputEventMouseButton.new()
		e.button_index=MOUSE_BUTTON_LEFT
		e.position=point
		e.global_position=point
		e.pressed=down
		root.push_input(e,true)
		await process_frame

func finish() -> void:
	if is_instance_valid(panel):
		panel.queue_free()
		await process_frame
	print("%s 原工作台蓄力：%d/%d" % ["FAIL" if failures else "PASS",checks-failures,checks])
	quit(1 if failures else 0)

func run() -> void:
	if OS.get_environment("FORMAL_WORKBENCH_CHARGED_TEST")!="1":
		print("SKIP 需要锁定源工作台私有图集与 ChargedAttack 合同")
		quit()
		return
	root.size=Vector2i(1600,900)
	panel=Demo.instantiate()
	root.add_child(panel)
	await process_frame
	await process_frame
	check(panel.ready_for_preview,"原工作台已装配："+panel.last_error)
	if not panel.ready_for_preview:
		await finish()
		return
	var path:=OS.get_environment("FANTASYWORD_WORKBENCH_SOURCE").path_join("animation.json")
	var input: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var source: Dictionary=input.actions.ChargedAttack
	var human := panel.get_node("EquipmentSystemDemoCharacter")
	var mat: ShaderMaterial = human.sprite.material
	await click("CloakCategory")
	await click("EquipHeavyCloak")
	await click("BagCategory")
	await click("EquipBag")
	await click("ShieldCategory")
	await click("EquipShield")
	await click("WeaponCategory")
	await click("EquipAxe")
	await click("SE")
	check(mat.get_shader_parameter("weapon0_enabled") and mat.get_shader_parameter("weapon1_enabled"),
		"开始前主副手实际显示")
	await click("ChargedAttack")
	var anim: Animation = human.animator.get_animation("ChargedAttack")
	check(human.driver.current_animation_key=="ChargedAttack" and human.driver.locked_key.is_empty()
		and anim.length==0.75 and anim.loop_mode==Animation.LOOP_NONE, "原非循环预览")
	var maps: Dictionary = human.material_binding._actions.ChargedAttack
	var southeast: Array[Texture2D] = []
	for i in 4:
		await click(["SE","SW","NE","NW"][i])
		var row: int = [0,1,2,0][i]
		human.animator.pause()
		for label in 6:
			human.animator.seek(.125*label,true)
			var view: AtlasTexture = human.sprite.texture
			var r: Array = source.directions[i][label].rect
			if i==0: southeast.append(view)
			if i==3: check(view==southeast[label], "西北复用同一原东南 Sprite 身份 %d"%label)
			check(human.playback.current_label==label and human.playback.current_direction==i
				and view.region==Rect2(r[0],row*32,32,32), "精灵原方向、行和帧 %d:%d"%[i,label])
			check(mat.get_shader_parameter("repeat_action_uv") and mat.get_shader_parameter("body_map")==maps.body
				and mat.get_shader_parameter("head_map")==maps.head
				and mat.get_shader_parameter("main_map")==view.atlas, "原主图与 Repeat 双 UV %d:%d"%[i,label])
			var cape = panel._cloak.options[1].sprite_sets[0][row]
			if cape == null: cape = panel._cloak.options[1].sprite_sets[0][0]
			check(not mat.get_shader_parameter("weapon0_enabled") and not mat.get_shader_parameter("weapon1_enabled")
				and mat.get_shader_parameter("enabled_cloth") and mat.get_shader_parameter("enabled_cloak")
				and panel._cloak.last_texture_guid==cape and mat.get_shader_parameter("enabled_bag")
				and mat.get_shader_parameter("bag_rect")==panel._bag._rectangles[row],
				"原空武器挂点、披风和背包沿躯干行 %d:%d"%[i,label])
	human.animator.seek(.75,true)
	await process_frame
	check(human.playback.current_label==5 and human.driver.current_animation_key=="ChargedAttack",
		"停在原末帧")
	await click("SE")
	await click("Idle")
	check(human.playback.current_action=="Idle" and mat.get_shader_parameter("weapon0_enabled")
		and mat.get_shader_parameter("weapon1_enabled") and not mat.get_shader_parameter("repeat_action_uv"),
		"回待机恢复装备和 Clamp")
	await finish()
