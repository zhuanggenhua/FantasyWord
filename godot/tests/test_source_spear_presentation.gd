extends SceneTree
## Normally configured ClickMoveTest with original source contracts, not the Workbench.
const Boot := preload("res://gameplay/clickmovetest/source_startup.gd")
const Gear := preload("res://game_core/inventory/source_character_equipment.gd")
var total := 0
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, msg: String) -> bool:
	total+=1
	if not ok: failed+=1
	print(("PASS " if ok else "FAIL ")+msg)
	return ok

func finish() -> void:
	print("正式玩家长矛：%d/%d"%[total-failed,total])
	quit(int(failed>0))

func key(code: Key, pressed: bool) -> void:
	var ev:=InputEventKey.new()
	ev.physical_keycode=code
	ev.pressed=pressed
	root.push_input(ev,true)

func actor_crop(sprite: Sprite2D) -> PackedByteArray:
	await RenderingServer.frame_post_draw
	var bounds: Rect2=sprite.get_global_transform_with_canvas()*sprite.get_rect()
	var screen:=root.get_texture().get_image()
	var cropped:=Rect2i(bounds.position.floor(),bounds.size.ceil()).intersection(Rect2i(Vector2i.ZERO,screen.get_size()))
	if not cropped.has_area(): return []
	var area:=screen.get_region(cropped)
	area.convert(Image.FORMAT_RGBA8)
	return area.get_data()

# The actual map may animate under transparent texels. Only compare pixels
# that return to the original equipped RGB and match an opaque spear color.
func restored_spear_pixels(first: PackedByteArray, empty: PackedByteArray,
		again: PackedByteArray, texture: Image) -> int:
	if first.size()!=empty.size() or first.size()!=again.size(): return 0
	var palette := {}
	for y in texture.get_height():
		for x in texture.get_width():
			var color:=texture.get_pixel(x,y)
			if color.a>.5:
				palette[(color.r8<<16)|(color.g8<<8)|color.b8]=true
	var count := 0
	for i in range(0,first.size(),4):
		if first[i]==again[i] and first[i+1]==again[i+1] and first[i+2]==again[i+2] \
				and (first[i]!=empty[i] or first[i+1]!=empty[i+1] or first[i+2]!=empty[i+2]) \
				and palette.has((first[i]<<16)|(first[i+1]<<8)|first[i+2]):
			count+=1
	return count

func run() -> void:
	if OS.get_environment("FORMAL_PLAYER_SPEAR_SOURCE").is_empty():
		print("SKIP 原主角长矛图及正式关卡合同需要私有输入。")
		quit()
		return
	root.size=Vector2i(960,540)
	if not check(change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))==OK,
		"同一正常项目启动入口"): finish();return
	await scene_changed
	await process_frame
	var host:=current_scene as Boot
	if not check(host!=null and host.scene!=null and host.player!=null and host.trainer_owner!=null
		and host.scene.ground_layers!=null and host.scene.human_presentation!=null,
		"实际玩家、原图、原假人与材质均已装配"):finish();return
	var actor: Node=host.scene.actor
	var view: Node2D=host.scene.human_presentation
	var gear:=host.player.source_equipment()
	var spear:=gear.item_for_guid(Gear.SPEAR)
	var mat: ShaderMaterial=view.sprite.material
	var owner:=host.primary_bag_owner(actor)
	var bags:=host.inventory_bags
	var cloth_before: bool=mat.get_shader_parameter("enabled_cloth")==true
	var stand: Texture2D=mat.get_shader_parameter("weapon0_map")
	if not check(gear.belongs_to(actor) and gear.equipped(Gear.Slot.WEAPON)==spear
		and bags.entries(owner).is_empty() and stand!=null and mat.get_shader_parameter("weapon0_enabled")
		and not mat.get_shader_parameter("weapon1_enabled"),"原主角自带长矛，未平白生成副手或背包物"):
		finish();return
	check(view.playback.set_direction(1) and mat.get_shader_parameter("weapon0_flip_x")
		and mat.get_shader_parameter("weapon0_map")==stand,"静态西向只沿原镜像分支")
	check(view.playback.set_direction(2) and not mat.get_shader_parameter("weapon0_flip_x"),"静态东北保留原图不镜像")
	if DisplayServer.get_name()!="headless":
		view.animator.speed_scale=0
		var armed:=await actor_crop(view.sprite)
		var remove:=bags.try_unequip(owner,gear,Gear.Slot.WEAPON)
		var unarmed:=await actor_crop(view.sprite)
		var restore:=bags.try_equip(owner,gear,spear)
		var armed_again:=await actor_crop(view.sprite)
		var restored:=restored_spear_pixels(armed,unarmed,armed_again,stand.get_image())
		check(remove==Gear.Result.VALID and restore==Gear.Result.VALID and not armed.is_empty()
			and restored>=8 and view.sprite.material==mat,
			"正式原生场景同帧有 %d 个原长矛色像素随实际装备恢复"%restored)
		view.animator.speed_scale=1.0
	var animation_names: Array[String] = []
	var sampled:=func(anim: String, _label: int, _dir: int, _tex: Texture2D):
		if anim=="Attack" and anim not in animation_names: animation_names.append(anim)
	view.playback.sample_resolved.connect(sampled)
	key(KEY_1,true)
	var limit:=Time.get_ticks_msec()+1200
	while animation_names.is_empty() and Time.get_ticks_msec()<limit: await process_frame
	key(KEY_1,false)
	check(animation_names==["Attack"] and mat.get_shader_parameter("weapon0_map")!=stand,
		"真实键位 1 的原普攻切入长矛攻击序列")
	view.playback.sample_resolved.disconnect(sampled)
	await create_timer(1.15).timeout
	check(view.driver.try_play_damage_animation() and mat.get_shader_parameter("weapon0_map")==stand,
		"Dmg 回到原静态锚点，没沿用攻击图")
	check(view.driver.try_lock_animation("SpinDie") and view.sprite.texture.region.size==Vector2(32,32)
		and view.sprite.texture.atlas.get_size()==Vector2(384,32)
		and not mat.get_shader_parameter("weapon0_enabled") and mat.get_shader_parameter("weapon0_map")==null
		and gear.equipped(Gear.Slot.WEAPON)==spear
		and (mat.get_shader_parameter("enabled_cloth")==true)==cloth_before,
		"原死亡动作无武器挂点，只关闭显示，不卸装备或改布衣")
	check(bags.try_unequip(owner,gear,Gear.Slot.WEAPON)==Gear.Result.VALID and bags.count(owner,spear)==1
		and gear.equipped(Gear.Slot.WEAPON)==null and not mat.get_shader_parameter("weapon0_enabled"),
		"正式装备服务卸下长矛回原包")
	check(bags.try_equip(owner,gear,spear)==Gear.Result.VALID and bags.entries(owner).is_empty()
		and not mat.get_shader_parameter("weapon0_enabled") and view.sprite.material==mat,
		"同一材质按当前实际帧判断可见性，不抢死亡动作或重播")
	finish()
