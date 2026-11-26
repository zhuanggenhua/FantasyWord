extends SceneTree
const Scene := preload("res://gameplay/equipment_workbench/equipment_system_demo.tscn")
var failures := 0
var count := 0
var demo: Control
func _initialize() -> void: call_deferred("run")
func check(ok: bool, msg: String) -> void:
	count+=1
	if not ok:
		failures+=1
		printerr("FAIL ",msg)

func press(key: String) -> void:
	var b := demo.find_child(key,true,false) as Button
	check(b!=null and b.is_visible_in_tree() and not b.disabled,"可操作 "+key)
	if b!=null and b.is_visible_in_tree() and not b.disabled: b.pressed.emit()

func pose(actor: Node2D, side: int, label := 0) -> void:
	demo._select_direction(side)
	actor.animator.pause()
	var stamps: Array = actor.playback._actions[actor.playback.current_action].times
	actor.animator.seek(float(stamps[label])+0.00001,true)

func pixels(actor: Node2D) -> PackedByteArray:
	await process_frame
	await RenderingServer.frame_post_draw
	var center := Vector2i(actor.sprite.get_global_transform_with_canvas().origin)
	return root.get_texture().get_image().get_region(Rect2i(center-Vector2i(100,100),Vector2i(200,200))).get_data()

func run() -> void:
	if OS.get_environment("FANTASYWORD_WORKBENCH_RACE_WEAPONS").is_empty():
		print("SKIP 原四族武器盾牌需要锁定私有帧与贴图")
		quit()
		return
	demo=Scene.instantiate()
	root.add_child(demo)
	await process_frame
	check(demo.ready_for_preview,"锁定工作台")
	if not demo.ready_for_preview:
		quit(1)
		return
	var gfx := DisplayServer.get_name()!="headless"
	for race in ["Elf","Goblin","Orc","Dwarf"]:
		press(race)
		var actor: Node2D = demo._race_views[race]
		var mat: ShaderMaterial = actor.composite
		check(demo._weapons.worn==[-1,-1],"角色默认两手空 "+race)
		press("ShieldCategory")
		press("EquipShield")
		check(demo._weapons.worn[1]>=0 and "重盾" in demo._details.text,"装备重盾与框面 "+race)
		if race=="Elf":
			pose(actor,0)
			check(not mat.get_shader_parameter("weapon1_enabled"),"精灵 SE 待机无盾锚点")
			pose(actor,1)
			check(mat.get_shader_parameter("weapon1_enabled"),"精灵 SW 待机有盾锚点")
			press("Walk")
			for label in 4:
				pose(actor,0,label)
				var expected: Variant = [null,Vector2(.453125,.515625),null,Vector2(.453125,.484375)][label]
				var on: bool = mat.get_shader_parameter("weapon1_enabled")
				var uv: Variant = mat.get_shader_parameter("weapon1_anchor_frame_uv")
				check((not on and mat.get_shader_parameter("weapon1_map")==null) if expected==null else on and Vector2(uv.x,uv.y).is_equal_approx(expected), "精灵走路换帧盾牌 "+str(label))
		elif race in ["Goblin","Orc"]:
			pose(actor,1)
			check(not mat.get_shader_parameter("weapon1_enabled") and demo._weapons.worn[1]>=0,"绿皮无锚点静态盾不补绘 "+race)
		press("WeaponCategory")
		press("EquipSpear")
		check(demo._weapons.worn[0]>=0 and demo._weapons.worn[1]>=0,"双槽不会彼此卸下 "+race)
		press("Idle")
		pose(actor,0)
		if race!="Dwarf": check(not mat.get_shader_parameter("weapon0_enabled"),"长矛待机无锚点 "+race)
		else:
			var main_uv: Vector4 = mat.get_shader_parameter("weapon0_anchor_frame_uv")
			var off_uv: Vector4 = mat.get_shader_parameter("weapon1_anchor_frame_uv")
			check(mat.get_shader_parameter("weapon0_enabled") and mat.get_shader_parameter("weapon1_enabled") and
				Vector2(main_uv.x,main_uv.y)==Vector2(.578125,.453125) and
				Vector2(off_uv.x,off_uv.y)==Vector2(.390625,.453125),"矮人待机双手采自己的原挂点")
			pose(actor,1)
			check(not mat.get_shader_parameter("weapon0_enabled") and mat.get_shader_parameter("weapon1_enabled"),
				"矮人西南无静态主手挂点、副手保持")
		press("Attack")
		pose(actor,0)
		var uv: Vector4 = mat.get_shader_parameter("weapon0_anchor_frame_uv")
		check(mat.get_shader_parameter("weapon0_enabled") and demo._weapons.binding_error.is_empty(),"实际攻击采样长矛 "+race)
		if race!="Dwarf":
			check(Vector2(uv.x,uv.y).is_equal_approx(Vector2(.5,.5)) and mat.get_shader_parameter("weapon0_rot_cos_sin")==Vector2(1,0)
				and not mat.get_shader_parameter("weapon0_flip_x"),"序列无手锚点用原帧中心 "+race)
		var on := PackedByteArray()
		if gfx: on=await pixels(actor)
		press("RemoveSpear")
		check(demo._weapons.worn[0]==-1 and demo._weapons.worn[1]>=0 and not mat.get_shader_parameter("weapon0_enabled")
			and mat.get_shader_parameter("weapon0_map")==null,"卸下武器只清主手 "+race)
		if gfx: check(on!=await pixels(actor),"原攻击长矛像素 "+race)
		press("EquipAxe")
		pose(actor,0)
		check(mat.get_shader_parameter("weapon0_enabled"),"同一真实动作切换原战斧 "+race)
		press("ShieldCategory")
		press("EquipRoundShield")
		check("圆盾" in demo._details.text and demo._weapons.worn[0]>=0,"换圆盾不影响战斧 "+race)
		press("RemoveShield")
		check(demo._weapons.worn[1]==-1 and demo._weapons.worn[0]>=0 and not mat.get_shader_parameter("weapon1_enabled"),"独立卸盾 "+race)
		press("WeaponCategory")
		press(race)
		check(demo._weapons.worn==[-1,-1] and demo._weapon_lists[0].visible
			and not mat.get_shader_parameter("weapon0_enabled"),"重选恢复布衣、两槽清空且保留栏 "+race)
	press("Human")
	press("EquipSpear")
	check(demo._weapons.worn[0]>=0 and demo._weapons._playback==demo._human.playback,"回到人类不引用他族帧")
	demo.queue_free()
	await process_frame
	print("PASS 原四族工作台武器盾牌：%d/%d，显示驱动 %s" % [count-failures,count,DisplayServer.get_name()])
	quit(1 if failures else 0)
