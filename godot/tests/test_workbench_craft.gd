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
	if button.get_parent().get_parent() is ScrollContainer:
		var scroller := button.get_parent().get_parent() as ScrollContainer
		scroller.ensure_control_visible(button)
		await process_frame
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
	print("%s 原工作台 铁砧 / 珠宝 / 炼金 / 木工：%d/%d" % ["FAIL" if failures else "PASS",checks-failures,checks])
	quit(1 if failures else 0)

func run() -> void:
	if OS.get_environment("FORMAL_WORKBENCH_CRAFT_TEST")!="1":
		print("SKIP 需要锁定源工作台私有图集与 铁砧 / 珠宝 / 炼金 / 木工 合同")
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
	var formal: Dictionary = input.duplicate(true)
	formal.actions.erase("SpinDie")
	formal.actions.erase("SlashAttack")
	for key in ["Dmg2","Jump","SoulDie","Harvest","Chopping","Mining"]: formal.actions.erase(key)
	var isolated := Human.new()
	root.add_child(isolated)
	check(not isolated.configure(formal,OS.get_environment("FANTASYWORD_WORKBENCH_HUMAN_ART")),
		"实际工作台动作不会进入默认玩法入口")
	isolated.free()
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
		"开始前实际显示主副手")
	var counts := {"AnvilWorking":6,"JewelryWorkshopWorking":11,"LaboratoryWorking":11,"WoodworkBenchWorking":6}
	for action: String in counts:
		await click(action)
		var count: int = counts[action]
		var duration := count/8.0
		var source: Dictionary = input.actions[action]
		var anim: Animation = human.animator.get_animation(action)
		check(human.driver.current_animation_key==action and human.driver.locked_key.is_empty()
			and anim.length==duration and anim.loop_mode==Animation.LOOP_LINEAR, "原循环预览 "+action)
		var maps: Dictionary = human.material_binding._actions[action]
		human.animator.seek(0,true)
		human.animator.advance(.8125)
		check(human.playback.current_label==(0 if count==6 else 6),"0.8125 秒后两种原循环长度 "+action)
		human.animator.pause()
		var position: float = human.animator.current_animation_position
		var label_at_switch: int = human.playback.current_label
		var sprite_at_switch: Texture2D = human.sprite.texture
		await click("SW")
		check(human.playback.current_direction==1 and human.playback.current_label==label_at_switch
			and human.driver.current_animation_key==action and human.animator.current_animation_position==position
			and human.sprite.texture==sprite_at_switch,
			"共用图像的方向切换不重播 "+action)
		for side in 4:
			await click(["SE","SW","NE","NW"][side])
			human.animator.pause()
			var row := 0
			for label in count:
				human.animator.seek(.125*label,true)
				var view: AtlasTexture = human.sprite.texture
				var r: Array = source.directions[side][label].rect
				check(human.playback.current_label==label and human.playback.current_direction==side
					and view.region==Rect2(r[0],row*32,32,32), "原向、行和帧 %s:%d:%d"%[action,side,label])
				check(mat.get_shader_parameter("repeat_action_uv")
					and mat.get_shader_parameter("body_map")==maps.body and mat.get_shader_parameter("head_map")==maps.head
					and mat.get_shader_parameter("main_map")==view.atlas, "原主图及 Repeat/Clamp %s:%d:%d"%[action,side,label])
				var sprites: Array = panel._cloak.options[1].sprite_sets[0]
				var cape = sprites[row]
				if cape == null: cape = sprites[1 if row==3 else 0]
				check(not mat.get_shader_parameter("weapon0_enabled") and not mat.get_shader_parameter("weapon1_enabled")
					and mat.get_shader_parameter("enabled_cloth") and mat.get_shader_parameter("enabled_cloak")
					and panel._cloak.last_texture_guid==cape and mat.get_shader_parameter("enabled_bag")
					and mat.get_shader_parameter("bag_rect")==panel._bag._rectangles[row],
					"原无武器挂点、披风和背包随原躯干 %s:%d:%d"%[action,side,label])
		human.animator.play(action)
		human.animator.seek(duration-.01,true)
		check(human.playback.current_label==count-1,"原循环收尾一帧")
		human.animator.advance(.04)
		check(human.playback.current_label==0 and human.driver.current_animation_key==action,
			"真实 AnimationPlayer 跨过原长度回到首帧，不切到待机")
	await click("SE")
	await click("Idle")
	check(human.playback.current_action=="Idle" and mat.get_shader_parameter("weapon0_enabled")
		and mat.get_shader_parameter("weapon1_enabled") and not mat.get_shader_parameter("repeat_action_uv"),
		"回待机恢复装备和 Clamp")
	await finish()
