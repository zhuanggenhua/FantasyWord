extends SceneTree
## Opt-in integration of the real primary actor and its locked original material.
const Boot := preload("res://gameplay/clickmovetest/source_startup.gd")
const Gear := preload("res://game_core/inventory/source_character_equipment.gd")
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> bool:
	if not ok: failed += 1
	print(("PASS " if ok else "FAIL ") + label)
	return ok

func witness(mat: ShaderMaterial, mode: float, hit: float, sequence: float) -> bool:
	return mat.get_shader_parameter("outline_stage_enabled") and mat.get_shader_parameter("shadow_stage_enabled") \
		and mat.get_shader_parameter("outline_default")==1.0 and mat.get_shader_parameter("outline_hit")==hit \
		and mat.get_shader_parameter("outline_extra")==0.0 and mat.get_shader_parameter("weapon0_is_sequence")==sequence \
		and mat.get_shader_parameter("shadow_enabled")==1.0 and mat.get_shader_parameter("shadow_mode")==mode \
		and mat.get_shader_parameter("outline_base_y")==0.421875

func sample(view: Node2D, action: StringName, label: int) -> void:
	view.animator.play(action)
	view.animator.advance(0.0)
	view.animator.seek(label / 8.0 + 0.001,true)

func crop_actor(sprite: Sprite2D) -> Image:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var bounds := sprite.get_global_transform_with_canvas()*sprite.get_rect()
	var region := Rect2i(bounds.position.floor(),bounds.size.ceil()).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
	var crop := image.get_region(region)
	crop.convert(Image.FORMAT_RGBA8)
	return crop

func pixel_change(first: Image, second: Image, compare: Callable) -> int:
	if first.get_size()!=second.get_size(): return 0
	var count:=0
	for y in first.get_height():
		for x in first.get_width():
			if compare.call(first.get_pixel(x,y),second.get_pixel(x,y)): count+=1
	return count

func run() -> void:
	if OS.get_environment("FORMAL_PLAYER_EFFECTS_SOURCE").is_empty():
		print("SKIP 正式主角轮廓/阴影须提供锁定原始帧合同。")
		quit()
		return
	root.size=Vector2i(960,540)
	if not check(change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))==OK,"从正常入口启动"):
		quit(1);return
	await scene_changed
	await process_frame
	var host := current_scene as Boot
	if not check(host!=null and host.scene!=null and host.scene.human_presentation!=null,"关卡原主角已装配"):
		quit(1);return
	var view: Node2D=host.scene.human_presentation
	var sprite: Sprite2D=view.sprite
	var mat := sprite.material as ShaderMaterial
	var gear:=host.player.source_equipment()
	var spear:=gear.item_for_guid(Gear.SPEAR)
	var owner:=host.primary_bag_owner(host.scene.actor)
	var weapons_present:=not OS.get_environment("FORMAL_PLAYER_SPEAR_SOURCE").is_empty()
	if not check(mat!=null and witness(mat,0.0,0.0,0.0) and not mat.get_shader_parameter("weapon1_enabled"),
		"原 Idle 初始材质轮廓和地面模式 0；不借用工作台或副手"):
		quit(1);return
	view.animator.speed_scale=0
	check(view.playback.set_direction(0),"实际四向库定位到 SE")
	check(host.inventory_bags.try_unequip(owner,gear,Gear.Slot.WEAPON)==Gear.Result.VALID \
		and not mat.get_shader_parameter("weapon0_enabled") and witness(mat,0.0,0.0,0.0),
		"正式卸下长矛后，同一主角材质轮廓和阴影仍在")
	sample(view,&"Walk",1)
	check(view.playback.current_label==1 and witness(mat,1.0,0.0,0.0) \
		and mat.get_shader_parameter("shadow_left_x")==14.0/32.0 and mat.get_shader_parameter("shadow_right_x")==14.0/32.0,
		"Walk 第 1 帧源右脚(14,17)，原离地模式和范围")
	sample(view,&"Walk",2)
	check(view.playback.current_label==2 and witness(mat,0.0,0.0,0.0),"Walk 第 2 帧返回地面分支")
	sample(view,&"Dmg",0)
	check(witness(mat,0.0,1.0,0.0),"Dmg 第 0 帧原红轮廓")
	if DisplayServer.get_name()!="headless":
		var dmg:=await crop_actor(sprite)
		# Change only the hit flag on the same frozen sprite for the pixel oracle.
		mat.set_shader_parameter("outline_hit",0.0)
		var ordinary:=await crop_actor(sprite)
		var count:=pixel_change(dmg,ordinary,func(a: Color,b: Color)->bool:
			return a.r8>=178 and a.r8<=182 and a.g8<=11 and a.b8<=11 and b.r8<=1 and b.g8<=1 and b.b8<=1)
		check(count>=20,"正常关卡同帧从红到黑的原描边像素：%d"%count)
	sample(view,&"Dmg",1)
	check(witness(mat,0.0,0.0,0.0),"下一原受伤帧恢复普通轮廓")
	if DisplayServer.get_name()!="headless":
		sample(view,&"Idle",0)
		var with_shadow:=await crop_actor(sprite)
		mat.set_shader_parameter("shadow_enabled",0.0)
		var without_shadow:=await crop_actor(sprite)
		var darkened:=pixel_change(with_shadow,without_shadow,func(a: Color,b: Color)->bool:
			return b.r8>=60 and absi(a.r8-roundi(b.r8*0.4))<=2 and absi(a.g8-roundi(b.g8*0.4))<=2 \
				and absi(a.b8-roundi(b.b8*0.4))<=2)
		check(darkened>=20,"正常关卡同帧程序阴影按原 alpha .6 变暗的像素：%d"%darkened)
	check(host.inventory_bags.try_equip(owner,gear,spear)==Gear.Result.VALID,"正式装备服务恢复长矛")
	sample(view,&"Attack",0)
	check(witness(mat,0.0,0.0,float(weapons_present))
		and mat.get_shader_parameter("weapon0_enabled")==weapons_present,
		"原攻击序列与轮廓/阴影共用实际帧，序列武器不加入轮廓探针")
	sample(view,&"SpinDie",0)
	check(witness(mat,0.0,0.0,0.0) and not mat.get_shader_parameter("weapon0_enabled"),"死亡首帧有脚、无武器锚点")
	sample(view,&"SpinDie",6)
	check(view.playback.current_label==6 and witness(mat,-1.0,0.0,0.0)
		and mat.get_shader_parameter("outline_frame_size")==Vector2(32,32)
		and gear.equipped(Gear.Slot.WEAPON)==spear,"无脚只写模式 -1，保留原基线、尺寸与实际装备")
	quit(int(failed>0))
