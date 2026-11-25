extends SceneTree

const Demo := preload("res://gameplay/equipment_workbench/equipment_system_demo.tscn")
const Human := preload("res://gameplay/clickmovetest/human_presentation.gd")
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
	print("%s 原工作台旋转死亡：%d/%d" % ["FAIL" if failures else "PASS",checks-failures,checks])
	quit(1 if failures else 0)

func run() -> void:
	if OS.get_environment("FORMAL_WORKBENCH_SPIN_TEST")!="1":
		print("SKIP 需要锁定源工作台私有图集与 SpinDie 合同")
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
	var source: Dictionary=input.actions.SpinDie
	var formal_human:=Human.new()
	root.add_child(formal_human)
	check(not formal_human.configure(input,OS.get_environment("FANTASYWORD_WORKBENCH_HUMAN_ART"),true),
		"工作台的 SpinDie 不能绕过实际场景死亡所有权")
	formal_human.free()
	var human:=panel.get_node("EquipmentSystemDemoCharacter")
	var mat: ShaderMaterial=human.sprite.material
	await click("CloakCategory")
	await click("EquipHeavyCloak")
	await click("BagCategory")
	await click("EquipBag")
	await click("ShieldCategory")
	await click("EquipShield")
	await click("WeaponCategory")
	await click("EquipAxe")
	await click("NE")
	check(mat.get_shader_parameter("weapon0_enabled") and mat.get_shader_parameter("weapon1_enabled"),
		"开演前确实佩戴并显示主副手")
	await click("SpinDie")
	check(human.driver.current_animation_key=="SpinDie" and human.driver.locked_key.is_empty()
		and human.animator.get_animation("SpinDie").length==1.5
		and human.animator.get_animation("SpinDie").loop_mode==Animation.LOOP_NONE,
		"真实选择原非循环预览，不置玩法死亡锁")
	var cape: String=panel._cloak.options[1].sprite_sets[0][0]
	var same_frames: Array[Texture2D]=[]
	for i in 4:
		await click(["SE","SW","NE","NW"][i])
		human.animator.pause()
		for label in 12:
			human.animator.seek(.125*label,true)
			var view: AtlasTexture=human.sprite.texture
			var rect: Array=source.directions[i][label].rect
			if i==0: same_frames.append(view)
			check(human.playback.current_label==label and human.playback.current_direction==i
				and same_frames[label]==view and view.region==Rect2(rect[0],0,32,32),
				"实际精灵按原四库使用同一行 %d:%d"%[i,label])
			check(not mat.get_shader_parameter("weapon0_enabled") and not mat.get_shader_parameter("weapon1_enabled")
				and mat.get_shader_parameter("enabled_cloth") and mat.get_shader_parameter("enabled_cloak")
				and panel._cloak.last_texture_guid==cape and mat.get_shader_parameter("enabled_bag")
				and not mat.get_shader_parameter("body_in_front"),
				"无原武器锚点；披风与背包取原行 0（包括无区域的末两帧）%d:%d"%[i,label])
	human.animator.seek(1.5,true)
	await process_frame
	check(human.playback.current_label==11 and human.driver.current_animation_key=="SpinDie",
		"停在原末帧，未自动切回待机")
	await click("Idle")
	check(human.playback.current_action=="Idle" and mat.get_shader_parameter("weapon0_enabled")
		and mat.get_shader_parameter("weapon1_enabled") and mat.get_shader_parameter("enabled_bag"),
		"回到待机后原装备重新显示，不需要穿第二次")
	await finish()
