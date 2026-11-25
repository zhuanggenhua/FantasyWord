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
	print("%s 原工作台 Dmg2 / Jump / SoulDie：%d/%d" % ["FAIL" if failures else "PASS",checks-failures,checks])
	quit(1 if failures else 0)

func run() -> void:
	if OS.get_environment("FORMAL_WORKBENCH_MOVES_TEST")!="1":
		print("SKIP 需要锁定源工作台私有图集与 Dmg2 / Jump / SoulDie 合同")
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
	for action in ["Jump","Dmg2","SoulDie","Jump"]:
		await click(action)
		var single: bool = action=="SoulDie"
		var count: int = 12 if single else 4
		var duration: float = 1.5 if single else .5
		var source: Dictionary = input.actions[action]
		var anim: Animation = human.animator.get_animation(action)
		check(human.driver.current_animation_key==action and human.driver.locked_key.is_empty()
			and anim.length==duration and anim.loop_mode==Animation.LOOP_NONE, "原非循环预览 "+action)
		var maps: Dictionary = human.material_binding._actions[action]
		var shared: Array[Texture2D] = []
		for side in 4:
			await click(["SE","SW","NE","NW"][side])
			human.animator.pause()
			var row: int = 0 if single else side
			for label in count:
				human.animator.seek(.125*label,true)
				var view: AtlasTexture = human.sprite.texture
				var r: Array = source.directions[side][label].rect
				if single and side==0: shared.append(view)
				if single and side!=0: check(view==shared[label],"四向均复用原 SoulDie Sprite")
				check(human.playback.current_label==label and human.playback.current_direction==side
					and view.region==Rect2(r[0],row*32,32,32), "原向、行和帧 %s:%d:%d"%[action,side,label])
				check(mat.get_shader_parameter("repeat_action_uv")== (action in ["Jump","SoulDie"])
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
		human.animator.seek(duration,true)
		await process_frame
		check(human.playback.current_label==count-1 and human.driver.current_animation_key==action,"停在原末帧")
	await click("SE")
	await click("Idle")
	check(human.playback.current_action=="Idle" and mat.get_shader_parameter("weapon0_enabled")
		and mat.get_shader_parameter("weapon1_enabled") and not mat.get_shader_parameter("repeat_action_uv"),
		"回待机恢复装备和 Clamp")
	await finish()
