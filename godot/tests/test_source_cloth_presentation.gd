extends SceneTree
## 原 ClickMoveTest 演员及其背包事务；私有输入下可在真窗口验证同帧布衣像素。
const Entry := preload("res://gameplay/clickmovetest/entry.tscn")
const Player := preload("res://gameplay/clickmovetest/single_player_actor.gd")
const Gear := preload("res://game_core/inventory/source_character_equipment.gd")
const Bags := preload("res://game_core/inventory/source_inventory_bags.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks+=1
	if ok: return
	failures+=1
	printerr("FAIL ",label)

func _run() -> void:
	var path := OS.get_environment("FORMAL_PLAYER_CLOTH_PNG")
	var contracts := OS.get_environment("FORMAL_CLOTH_TEST_CONTRACTS")
	var art := OS.get_environment("FORMAL_PLAYER_TEXTURES")
	if path.is_empty() or contracts.is_empty() or art.is_empty():
		print("SKIP 原布衣、原站立帧及 UV 为私有输入。")
		quit()
		return
	var scene := Entry.instantiate()
	root.add_child(scene)
	var view: Node2D = scene.start_human_presentation(_read(contracts.path_join("animation.json")),art)
	check(is_instance_valid(view),"原站立角色图集")
	if view==null:
		quit(1)
		return
	var material_data := _read(contracts.path_join("material.json"))
	check(view.bind_base_material(material_data,art.path_join("uv"),art.path_join("appearance")),"原站立 UV 与外观材质")
	if view.material_binding==null:
		quit(1)
		return
	var player := Player.new()
	var gear_ok := player.configure(scene.actor) and player.start_source_equipment()
	check(gear_ok,"原主角的正式装备宿主")
	if not gear_ok:
		quit(1)
		return
	var gear := player.source_equipment()
	var other := Node2D.new()
	root.add_child(other)
	var other_gear := Gear.new()
	check(other_gear.start(other,func():return 100,func():return true) and not view.bind_source_cloth(other_gear,path),"拒绝其他演员的装备")
	check(not view.bind_source_cloth(gear,path+".invalid"),"拒绝错误原图路径")
	check(view.bind_source_cloth(gear,path) and not view.bind_source_cloth(gear,path),"实际装备只绑定一次")
	var mat: ShaderMaterial = view.sprite.material
	var cloth := gear.item_for_guid(Gear.CLOTH)
	var bag := Bags.new()
	var owner := bag.character_owner("player")
	var actor_texture: Texture2D = view.sprite.texture
	view.animator.speed_scale=0.0
	scene.camera.zoom=Vector2.ONE*48.0
	scene.camera.position=view.global_position
	scene.camera.make_current()
	check(mat.get_shader_parameter("enabled_cloth")==true and bag.count(owner,cloth)==0,"启动装备立即投影到实际材质")
	player.set_change_equipment_enabled(false)
	check(bag.try_unequip(owner,gear,Gear.Slot.TORSO)==Gear.Result.ACTION_LOCKED
		and mat.get_shader_parameter("enabled_cloth")==true,"动作锁拒绝卸下，不清布衣像素")
	player.set_change_equipment_enabled(true)
	var native := DisplayServer.get_name()!="headless"
	var dressed := PackedByteArray()
	if native: dressed=await _capture()
	check(bag.try_unequip(owner,gear,Gear.Slot.TORSO)==Gear.Result.VALID
		and mat.get_shader_parameter("enabled_cloth")==false and mat.get_shader_parameter("cloth_map")==null
		and bag.count(owner,cloth)==1,"原背包事务将布衣回包，同时关闭材质布衣")
	if native: check(dressed!=await _capture(),"同帧真窗口取样确有布衣差异")
	check(bag.try_equip(owner,gear,cloth)==Gear.Result.VALID
		and mat.get_shader_parameter("enabled_cloth")==true and bag.count(owner,cloth)==0
		and view.sprite.texture==actor_texture and view.sprite.material==mat,"恢复布衣不换帧、不替换材质，不重复入包")
	if native: check(dressed==await _capture(),"同一实际帧的着装像素完全恢复")
	check(view.driver.try_play_animation("Walk") and mat.get_shader_parameter("enabled_cloth")==true,"行走换原图集后同一装备态保留")
	view.free()
	check(not gear.loadout_changed.has_connections(),"表现节点退出时对称退订")
	scene.free()
	other.free()
	print("%s 基础布衣装备与原角色表现：%d/%d"%["PASS" if failures==0 else "FAIL",checks-failures,checks])
	quit(1 if failures else 0)

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func _capture() -> PackedByteArray:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var center := Vector2i(image.get_size()/2)
	return image.get_region(Rect2i(center-Vector2i(110,110),Vector2i(220,220))).get_data()
